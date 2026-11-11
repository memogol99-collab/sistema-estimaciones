# -*- coding: utf-8 -*-
"""
Genera el paquete MEMO_SISTEMA.bundle a partir de autocad/originales.

    python construir_bundle.py

Produce:
  autocad/MEMO_SISTEMA.bundle/
      PackageContents.xml           -> lo lee AutoCAD al arrancar (Autoloader)
      Contents/MEMO_Cargador.lsp    -> UN solo cargador con carga bajo demanda
      Contents/MEMO_SISTEMA.cuix    -> menú con 3 fichas (Ribbon) + menú desplegable
      Contents/MEMO_SISTEMA.mnl     -> se carga junto con el CUIX (respaldo)
      Contents/Iconos/*.png         -> iconos 16 y 32 px
      Contents/LISP/<categoría>/*.lsp
  autocad/MEMO_SISTEMA_bundle.zip   -> todo lo anterior + instaladores .bat

Requiere Python 3.8+ y Pillow (pip install pillow).
"""
import hashlib
import io
import os
import re
import shutil
import sys
import uuid
import zipfile
from xml.sax.saxutils import escape, quoteattr

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import catalogo as cat  # noqa: E402
import iconos  # noqa: E402

VERSION = "2.0.0"
AQUI = os.path.dirname(os.path.abspath(__file__))
BASE = os.path.dirname(AQUI)                       # autocad/
ORIG = os.path.join(BASE, "originales", "MEMO_SISTEMA")
BUNDLE = os.path.join(BASE, "MEMO_SISTEMA.bundle")
CONT = os.path.join(BUNDLE, "Contents")
MENU = "MEMO_SISTEMA"

SIMB = r"[\w\-*:!?.$&]"   # caracteres válidos en un símbolo AutoLISP


# ---------------------------------------------------------------------------
# Utilidades
# ---------------------------------------------------------------------------
def sin_comentarios_ni_cadenas(s):
    s = re.sub(r";\|.*?\|;", "", s, flags=re.S)
    s = re.sub(r'"(?:[^"\\]|\\.)*"', '""', s)
    return re.sub(r";[^\n]*", "", s)


def comandos_definidos(texto):
    codigo = sin_comentarios_ni_cadenas(texto)
    vistos = []
    for m in re.finditer(r"\(defun\s+c:([^\s()]+)", codigo, re.I):
        c = m.group(1).upper()
        if c not in vistos:
            vistos.append(c)
    return vistos


def funciones_auxiliares(texto):
    codigo = sin_comentarios_ni_cadenas(texto)
    out = []
    for m in re.finditer(r"\(defun\s+([^\s()]+)", codigo, re.I):
        n = m.group(1)
        if n.lower().startswith("c:") or n.lower() == "*error*":
            continue
        if n.lower() not in [x.lower() for x in out]:
            out.append(n)
    return out


def renombrar_simbolo(texto, viejo, nuevo):
    patron = r"(?<!" + SIMB + r")" + re.escape(viejo) + r"(?!" + SIMB + r")"
    return re.subn(patron, nuevo, texto, flags=re.I)


def reemplazar(texto, viejo, nuevo, nombre, minimo=1):
    n = texto.count(viejo)
    if n < minimo:
        raise SystemExit("Parche fallido en %s: no se encontró %r" % (nombre, viejo))
    return texto.replace(viejo, nuevo)


def parentesis_balanceados(s):
    d = 0
    i = 0
    n = len(s)
    en_cad = False
    while i < n:
        c = s[i]
        if en_cad:
            if c == "\\":
                i += 2
                continue
            if c == '"':
                en_cad = False
        elif c == '"':
            en_cad = True
        elif c == ";":
            if s.startswith(";|", i):
                j = s.find("|;", i + 2)
                i = j + 2 if j >= 0 else n
                continue
            j = s.find("\n", i)
            i = j if j >= 0 else n
            continue
        elif c == "(":
            d += 1
        elif c == ")":
            d -= 1
            if d < 0:
                return False
        i += 1
    return d == 0 and not en_cad


# ---------------------------------------------------------------------------
# Parches (correcciones mínimas y documentadas)
# ---------------------------------------------------------------------------
def aplicar_parches(texto, parches, nombre, bitacora):
    for p in parches:
        if p.startswith("prefijo:"):
            pref = p.split(":", 1)[1] + ":"
            for f in funciones_auxiliares(texto):
                texto, n = renombrar_simbolo(texto, f, pref + f)
                bitacora.append("  - función interna %s -> %s%s (%d usos)" % (f, pref, f, n))
        elif p == "bpol-error":
            texto = reemplazar(texto, "(defun *error* (msg)", "(defun bpol:*error* (msg)", nombre)
            texto = reemplazar(texto, "(setq old_error *error*)",
                               "(setq old_error *error* *error* bpol:*error*)", nombre)
            bitacora.append("  - el *error* global que se definía AL CARGAR ahora es bpol:*error* y sólo se activa dentro de BPOL")
        elif p == "ea-ha":
            texto = reemplazar(texto, "(defun c:HA (", "(defun c:EA-HA (", nombre)
            texto = reemplazar(texto, '"\\n  HA          -> Etiquetado manual"',
                               '"\\n  EA-HA       -> Etiquetado manual"', nombre)
            bitacora.append("  - comando HA de EA renombrado a EA-HA (chocaba con HA de 'Area Pref')")
        elif p == "msg-hr":
            texto = reemplazar(texto, "Escribe HATCHRECTANGULOS para ejecutar", "Escribe HR para ejecutar", nombre)
            bitacora.append("  - mensaje de carga corregido: el comando es HR")
        elif p == "getfiled-c":
            texto, n = re.subn(r'\(getfiled ("[^"]*") "C:/"', r'(getfiled \1 (getvar "DWGPREFIX")', texto)
            if not n:
                raise SystemExit("Parche getfiled-c fallido en " + nombre)
            bitacora.append('  - getfiled abre en la carpeta del dibujo en lugar de "C:/"')
        else:
            raise SystemExit("Parche desconocido: " + p)
    return texto


# ---------------------------------------------------------------------------
# 1. LISP
# ---------------------------------------------------------------------------
def construir_lisp():
    destino_lisp = os.path.join(CONT, "LISP")
    mapa = []          # (destino, [comandos])
    bitacora = []
    dueño = {}
    for origen, destino, parches in cat.ARCHIVOS:
        ruta = os.path.join(ORIG, origen)
        crudo = open(ruta, "rb").read()
        # latin-1 permite ida y vuelta sin perder ningún byte (ANSI o UTF-8)
        texto = crudo.decode("latin-1")
        if parches:
            bitacora.append("%s:" % destino)
            texto = aplicar_parches(texto, parches, destino, bitacora)
        if not parentesis_balanceados(texto):
            raise SystemExit("Paréntesis desbalanceados en " + destino)
        nl = "\r\n" if "\r\n" in texto else "\n"
        cab = (";;; MEMO SISTEMA %s - archivo generado por construir_bundle.py%s"
               ";;; Origen: %s%s" % (VERSION, nl, origen.encode("ascii", "replace").decode(), nl))
        if parches:
            cab += ";;; Parches aplicados: %s%s" % (", ".join(parches), nl)
        texto = cab + nl + texto
        salida = os.path.join(destino_lisp, destino)
        os.makedirs(os.path.dirname(salida), exist_ok=True)
        open(salida, "wb").write(texto.encode("latin-1"))

        cmds = comandos_definidos(texto)
        propios = []
        for c in cmds:
            if c in dueño:
                permitido = cat.DUPLICADOS_PERMITIDOS.get(c)
                if not permitido:
                    raise SystemExit("Comando %s duplicado en %s y %s" % (c, dueño[c], destino))
                if permitido == destino:
                    mapa = [(d, [x for x in cs if x != c]) for d, cs in mapa]
                    dueño[c] = destino
                    propios.append(c)
                continue
            dueño[c] = destino
            propios.append(c)
        mapa.append((destino, propios))
    return mapa, dueño, bitacora


# ---------------------------------------------------------------------------
# 2. Cargador
# ---------------------------------------------------------------------------
def lisp_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


def ascii_lisp(s):
    """Texto ASCII seguro para un .lsp (evita problemas ANSI/UTF-8)."""
    import unicodedata
    s = s.replace("²", "2").replace("ñ", "n").replace("Ñ", "N")
    return unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode()


def construir_cargador(mapa):
    L = []
    w = L.append
    w(";;; =====================================================================")
    w(";;;  MEMO_Cargador.lsp  -  MEMO SISTEMA %s" % VERSION)
    w(";;;  ARCHIVO GENERADO: no editar a mano; edite herramientas/catalogo.py")
    w(";;;")
    w(";;;  Un solo cargador para todos los LISP. NO carga los %d archivos al" % len(mapa))
    w(";;;  abrir cada dibujo: define cada comando como \"stub\" y el archivo")
    w(";;;  real se carga la primera vez que se usa el comando (carga bajo")
    w(";;;  demanda). Arranque mas rapido y sin choques entre archivos.")
    w(";;; =====================================================================")
    w("(vl-load-com)")
    w("")
    w("(if (not memo:cargado)")
    w("  (progn")
    w("    (setq memo:version %s)" % lisp_str(VERSION))
    w("    (setq memo:raiz (findfile \"MEMO_Cargador.lsp\"))")
    w("    (if memo:raiz")
    w("      (setq memo:raiz (vl-string-translate \"\\\\\" \"/\" (vl-filename-directory memo:raiz))))")
    w("    (setq memo:archivos-cargados nil memo:num-comandos 0)")
    w("")
    w("    ;; Carga el archivo real y ejecuta el comando solicitado")
    w("    (defun memo:cargar (rel cmd / ruta res)")
    w("      (setq ruta (strcat memo:raiz \"/LISP/\" rel))")
    w("      (cond")
    w("        ((member rel memo:archivos-cargados)")
    w("         (princ (strcat \"\\nMEMO: \" rel \" se cargo pero no define el comando \" cmd)))")
    w("        ((not (or (findfile (strcat ruta \".lsp\")) (findfile (strcat ruta \".fas\")) (findfile (strcat ruta \".vlx\"))))")
    w("         (princ (strcat \"\\nMEMO: no se encuentra \" ruta \".lsp\")))")
    w("        (T")
    w("         (setq memo:archivos-cargados (cons rel memo:archivos-cargados))")
    w("         (setq res (vl-catch-all-apply 'load (list ruta)))")
    w("         (if (vl-catch-all-error-p res)")
    w("           (princ (strcat \"\\nMEMO: error al cargar \" rel \": \" (vl-catch-all-error-message res)))")
    w("           (eval (list (read (strcat \"C:\" cmd)))))))")
    w("      (princ))")
    w("")
    w("    ;; Define un comando que carga su archivo al primer uso")
    w("    (defun memo:al (rel cmds)")
    w("      (foreach cmd cmds")
    w("        (if (not (eval (read (strcat \"C:\" cmd))))")
    w("          (progn")
    w("            (eval (list 'defun (read (strcat \"C:\" cmd)) nil (list 'memo:cargar rel cmd)))")
    w("            (setq memo:num-comandos (1+ memo:num-comandos))))))")
    w("")
    w("    (if memo:raiz")
    w("      (progn")
    for destino, cmds in mapa:
        if not cmds:
            continue
        w("        (memo:al %s '(%s))" % (lisp_str(destino[:-4]), " ".join(lisp_str(c) for c in cmds)))
    w("        (setq memo:cargado T)")
    w("        (princ (strcat \"\\nMEMO SISTEMA \" memo:version \" listo: \" (itoa memo:num-comandos)")
    w("                       \" comandos. Escriba MEMO_AYUDA para ver la lista.\")))")
    w("      (princ \"\\nMEMO: no se encontro MEMO_Cargador.lsp en las rutas de soporte.\"))))")
    w("")
    # Ayuda
    w(";;; ---------------------------------------------------------------------")
    w(";;; Comandos propios del sistema")
    w(";;; ---------------------------------------------------------------------")
    w("(defun c:MEMO_AYUDA ()")
    w("  (textscr)")
    w("  (princ (strcat \"\\n========== MEMO SISTEMA \" memo:version \" ==========\"))")
    for tab, _kt, paneles in cat.FICHAS:
        w("  (princ %s)" % lisp_str("\n\n### " + ascii_lisp(tab).upper()))
        for panel, items in paneles:
            w("  (princ %s)" % lisp_str("\n  -- " + ascii_lisp(panel)))
            for it in items:
                for c in (it if isinstance(it, list) else [it]):
                    et, desc, _g, _c = cat.COMANDOS[c]
                    w("  (princ %s)" % lisp_str("\n   %-16s %s" % (c, ascii_lisp(desc))))
    w("  (princ \"\\n\\nTip: pase el cursor sobre los botones de las fichas MEMO para ver la descripcion.\")")
    w("  (princ))")
    w("")
    w("(defun c:MEMO_INFO ()")
    w("  (princ (strcat \"\\nMEMO SISTEMA \" memo:version))")
    w("  (princ (strcat \"\\nCarpeta: \" (if memo:raiz memo:raiz \"(no encontrada)\")))")
    w("  (princ (strcat \"\\nComandos registrados: \" (itoa memo:num-comandos)))")
    w("  (princ \"\\nArchivos ya cargados en este dibujo:\")")
    w("  (if memo:archivos-cargados")
    w("    (foreach a (reverse memo:archivos-cargados) (princ (strcat \"\\n  \" a)))")
    w("    (princ \"\\n  (ninguno todavia: se cargan al usar cada comando)\"))")
    w("  (princ (strcat \"\\nMenu \" %s \": \" (if (menugroup %s) \"cargado\" \"NO cargado\")))" % (lisp_str(MENU), lisp_str(MENU)))
    w("  (princ))")
    w("")
    w("(defun c:MEMO_QUITAR_ANTERIOR (/ old)")
    w("  ;; Descarga el menu viejo 'MEMO' (Memo.cuix con rutas fijas a AutoCAD 2024/2026)")
    w("  (if (menugroup \"MEMO\")")
    w("    (progn")
    w("      (setq old (getvar \"CMDECHO\"))")
    w("      (setvar \"CMDECHO\" 0)")
    w("      (command \"_.CUIUNLOAD\" \"MEMO\")")
    w("      (setvar \"CMDECHO\" old)")
    w("      (princ \"\\nMenu anterior MEMO descargado. Sus LISP ya no se cargaran al abrir dibujos.\"))")
    w("    (princ \"\\nEl menu anterior MEMO no esta cargado. Nada que hacer.\"))")
    w("  (princ))")
    w("")
    w("(princ)")
    texto = "\r\n".join(L) + "\r\n"
    open(os.path.join(CONT, "MEMO_Cargador.lsp"), "wb").write(texto.encode("ascii"))

    mnl = (";;; MEMO_SISTEMA.mnl - AutoCAD lo carga junto con MEMO_SISTEMA.cuix\r\n"
           "(if (and (not memo:cargado) (findfile \"MEMO_Cargador.lsp\"))\r\n"
           "  (load (findfile \"MEMO_Cargador.lsp\")))\r\n(princ)\r\n")
    open(os.path.join(CONT, MENU + ".mnl"), "wb").write(mnl.encode("ascii"))
    if not parentesis_balanceados(texto):
        raise SystemExit("Cargador desbalanceado")


# ---------------------------------------------------------------------------
# 3. CUIX
# ---------------------------------------------------------------------------
AVISO = """<?xml version="1.0" encoding="utf-8"?>
<!--
Archivo generado por construir_bundle.py (MEMO SISTEMA %s).
Para cambiar el menu edite autocad/herramientas/catalogo.py y vuelva a generar.
-->
""" % VERSION
NS = 'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"'
REV = '<ModifiedRev MajorVersion="24" MinorVersion="3" UserVersion="1" />'


def uid(prefijo, clave):
    return "%s_900_%s" % (prefijo, hashlib.md5(clave.encode("utf-8")).hexdigest()[:8].upper())


def nombre_icono(cmd, tam):
    limpio = re.sub(r"[^A-Za-z0-9]", "_", cmd)
    return "MEMO_%s_%d.png" % (limpio, tam)


def raiz_vacia(nombre):
    return AVISO + "<%s %s />\n" % (nombre, NS)


def construir_cuix(dueño):
    usados = []
    for _t, _k, paneles in cat.FICHAS:
        for _p, items in paneles:
            for it in items:
                for c in (it if isinstance(it, list) else [it]):
                    if c not in usados:
                        usados.append(c)
    disponibles = set(dueño) | set(cat.COMANDOS_CARGADOR)
    for c in usados:
        if c not in disponibles:
            raise SystemExit("El menú usa %s pero ningún archivo lo define" % c)
        if c not in cat.COMANDOS:
            raise SystemExit("Falta describir %s en COMANDOS" % c)
    # Todos los comandos (para el menú desplegable), aunque no estén en Ribbon
    todos = list(usados) + sorted(c for c in disponibles if c not in usados and c not in cat.OCULTOS)
    for c in todos:
        if c not in cat.COMANDOS:
            raise SystemExit("Falta describir %s en COMANDOS" % c)

    # --- MenuGroup (macros) ---
    mg = [AVISO, '<MenuGroup %s Name="%s" DisplayName="MEMO SISTEMA">' % (NS, MENU), '  <MacroGroup Name="MEMO">']
    for c in todos:
        et, desc, _g, _cat = cat.COMANDOS[c]
        mg.append('    <MenuMacro UID="%s">' % uid("MMU", c))
        mg.append('      <Macro type="Any">')
        mg.append('        <Revision MajorVersion="16" MinorVersion="2" UserVersion="1" />')
        mg.append("        " + REV)
        mg.append('        <Name xlate="true" UID="%s">%s (%s)</Name>' % (uid("XLS", "n" + c), escape(et), escape(c)))
        mg.append("        <Command>^C^C%s</Command>" % escape(c))
        mg.append('        <HelpString xlate="true" UID="%s">%s</HelpString>' % (uid("XLS", "h" + c), escape(desc)))
        mg.append('        <SmallImage Name=%s />' % quoteattr(nombre_icono(c, 16)))
        mg.append('        <LargeImage Name=%s />' % quoteattr(nombre_icono(c, 32)))
        mg.append("      </Macro>")
        mg.append("    </MenuMacro>")
    mg.append("  </MacroGroup>")
    mg.append("</MenuGroup>")

    # --- Ribbon ---
    rb = [AVISO, "<RibbonRoot %s>" % NS, "  <RibbonPanelSourceCollection>"]
    tabs = ["  <RibbonTabSourceCollection>"]

    def boton(c, estilo, ind):
        et = cat.COMANDOS[c][0]
        return '%s<RibbonCommandButton UID="%s" Text=%s ButtonStyle="%s" MenuMacroID="%s" KeyTip=%s />' % (
            ind, uid("RBN", "b" + c + estilo), quoteattr(et), estilo, uid("MMU", c), quoteattr(re.sub(r"[^A-Z0-9]", "", c)[:3]))

    for tab, keytip, paneles in cat.FICHAS:
        tid = uid("RBN", "tab" + tab)
        tabs.append('    <RibbonTabSource UID="%s" Text=%s KeyTip="%s">' % (tid, quoteattr(tab), keytip))
        tabs.append('      <Name xlate="true" UID="%s">%s</Name>' % (uid("XLS", "tab" + tab), escape(tab)))
        tabs.append("      <Aliases><Alias>ID_MEMO_%s</Alias></Aliases>" % keytip)
        for panel, items in paneles:
            pid = uid("RBN", "pan" + tab + panel)
            rb.append('    <RibbonPanelSource UID="%s" Text=%s>' % (pid, quoteattr(panel)))
            rb.append('      <Name xlate="true" UID="%s">%s</Name>' % (uid("XLS", "pan" + tab + panel), escape(panel)))
            rb.append("      <Aliases><Alias>ID_MEMO_%s</Alias></Aliases>" % re.sub(r"\W", "", uid("P", tab + panel)))
            rb.append('      <RibbonRow UID="%s">' % uid("RBN", "row" + tab + panel))
            for k, it in enumerate(items):
                if isinstance(it, list):
                    rp = uid("RBN", "rp%s%s%d" % (tab, panel, k))
                    rb.append('        <RibbonRowPanel UID="%s">' % rp)
                    for j, c in enumerate(it):
                        rb.append('          <RibbonRow UID="%s">' % uid("RBN", "rr%s%d" % (rp, j)))
                        rb.append(boton(c, "SmallWithText", "            "))
                        rb.append("          </RibbonRow>")
                    rb.append("        </RibbonRowPanel>")
                else:
                    rb.append(boton(it, "LargeWithText", "        "))
            rb.append("      </RibbonRow>")
            rb.append("    </RibbonPanelSource>")
            tabs.append('      <RibbonPanelSourceReference UID="%s" PanelId="%s" />' % (uid("RBN", "ref" + tab + panel), pid))
        tabs.append("    </RibbonTabSource>")
    rb.append("  </RibbonPanelSourceCollection>")
    tabs.append("  </RibbonTabSourceCollection>")
    rb += tabs
    rb.append("</RibbonRoot>")

    # --- Menú desplegable clásico (MENUBAR=1) ---
    pm = [AVISO, "<PopMenuRoot %s>" % NS]
    raiz = uid("PMU", "raiz")
    subs = []
    for tab, _k, paneles in cat.FICHAS:
        for panel, items in paneles:
            subs.append((tab, panel, [c for it in items for c in (it if isinstance(it, list) else [it])]))
    en_menu = {c for _t, _p, cs in subs for c in cs}
    extra = [c for c in todos if c not in en_menu]
    if extra:
        subs.append(("MEMO", "Otros comandos", extra))
    pm.append('  <PopMenu hasDiesel="false" UID="%s">' % raiz)
    pm.append("    " + REV)
    pm.append("    <Alias>POP901</Alias>")
    pm.append('    <Name xlate="true" UID="%s">MEMO</Name>' % uid("XLS", "raiz"))
    for tab, panel, _cs in subs:
        pm.append('    <PopMenuRef pUID="%s" UID="%s">' % (uid("PMU", tab + panel), uid("PMRU", tab + panel)))
        pm.append("      " + REV)
        pm.append("    </PopMenuRef>")
    pm.append("  </PopMenu>")
    for tab, panel, cs in subs:
        pm.append('  <PopMenu hasDiesel="false" UID="%s">' % uid("PMU", tab + panel))
        pm.append("    " + REV)
        pm.append('    <Name xlate="true" UID="%s">%s</Name>' % (uid("XLS", "pm" + tab + panel), escape(panel)))
        for c in cs:
            et = cat.COMANDOS[c][0]
            pm.append('    <PopMenuItem IsSeparator="false" hasDiesel="false" UID="%s">' % uid("PMIU", tab + panel + c))
            pm.append("      " + REV)
            pm.append('      <NameRef UID="%s" xlate="true">%s (%s)</NameRef>' % (uid("XLS", "pmi" + tab + panel + c), escape(et), escape(c)))
            pm.append("      <MenuItem>")
            pm.append('        <MacroRef MenuMacroID="%s" />' % uid("MMU", c))
            pm.append("      </MenuItem>")
            pm.append("    </PopMenuItem>")
        pm.append("  </PopMenu>")
    pm.append("</PopMenuRoot>")

    header = AVISO + """<CustSection %s>
  <FileVersion MajorVersion="0" MinorVersion="6" IncrementalVersion="1" UserVersion="1" />
  <Header>
    <CommonConfiguration>
      <CommonItems>
        %s
      </CommonItems>
    </CommonConfiguration>
  </Header>
</CustSection>
""" % (NS, REV)

    partes = [
        ("Header.cui", header),
        ("WorkspaceRoot.cui", AVISO + "<WorkspaceRoot %s>\n  <WorkspaceConfigRoot />\n</WorkspaceRoot>\n" % NS),
        ("MenuGroup.cui", "\n".join(mg) + "\n"),
        ("AcceleratorRoot.cui", raiz_vacia("AcceleratorRoot")),
        ("OverrideRoot.cui", raiz_vacia("OverrideRoot")),
        ("MouseButtonRoot.cui", raiz_vacia("MouseButtonRoot")),
        ("PopMenuRoot.cui", "\n".join(pm) + "\n"),
        ("ToolbarRoot.cui", raiz_vacia("ToolbarRoot")),
        ("DoubleClickRoot.cui", raiz_vacia("DoubleClickRoot")),
        ("QuickPropertiesRoot.cui", raiz_vacia("QuickPropertiesRoot")),
        ("RolloverTooltipRoot.cui", raiz_vacia("RolloverTooltipRoot")),
        ("RibbonRoot.cui", "\n".join(rb) + "\n"),
        ("QuickAccessToolbarRoot.cui", raiz_vacia("QuickAccessToolbarRoot")),
        ("ToolPanelRoot.cui", raiz_vacia("ToolPanelRoot")),
        ("PanelSetRoot.cui", raiz_vacia("PanelSetRoot")),
        ("ScreenMenuRoot.cui", raiz_vacia("ScreenMenuRoot")),
        ("ImageMenuRoot.cui", raiz_vacia("ImageMenuRoot")),
        ("TabletMenuRoot.cui", raiz_vacia("TabletMenuRoot")),
        ("DigitizerButtonRoot.cui", raiz_vacia("DigitizerButtonRoot")),
        ("LSPFiles.cui", AVISO + "<LSPFiles %s />\n" % NS),
    ]
    # Validar XML
    import xml.dom.minidom
    for n, x in partes:
        xml.dom.minidom.parseString(x.encode("utf-8"))

    bom = "\ufeff"
    ctypes = (bom + '<?xml version="1.0" encoding="utf-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
              '<Default Extension="cui" ContentType="text/xml" /><Default Extension="xml" ContentType="text/xml" />'
              '<Default Extension="png" ContentType="image/png" />'
              '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml" /></Types>')
    rels = bom + '<?xml version="1.0" encoding="utf-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    for n, _x in partes:
        rels += '<Relationship Type="CUI" Target="/%s" Id="R%s" />' % (n, hashlib.md5(n.encode()).hexdigest()[:16])
    rels += "</Relationships>"
    info = ['<?xml version="1.0" encoding="utf-8"?>', "<MenuPackageParts>"]
    for n, _x in partes:
        info.append('  <PartData PartData_Name="/%s" PartData_Modified="2026-11-11T12:00:00.0000000-06:00" />' % n)
    info.append("</MenuPackageParts>")

    ruta = os.path.join(CONT, MENU + ".cuix")
    with zipfile.ZipFile(ruta, "w", zipfile.ZIP_DEFLATED) as z:
        for n, x in partes:
            z.writestr(n, x.encode("utf-8"))
        z.writestr("Menu_Package_Info.xml", "\n".join(info).encode("utf-8"))
        z.writestr("_rels/.rels", rels.encode("utf-8"))
        # Iconos incrustados (AutoCAD también los busca en Contents/Iconos)
        for c in todos:
            for t in (16, 32):
                z.write(os.path.join(CONT, "Iconos", nombre_icono(c, t)), nombre_icono(c, t))
        z.writestr("[Content_Types].xml", ctypes.encode("utf-8"))
    return todos


# ---------------------------------------------------------------------------
# 4. PackageContents.xml
# ---------------------------------------------------------------------------
def construir_package():
    pc = """<?xml version="1.0" encoding="utf-8"?>
<!-- MEMO SISTEMA %(v)s - Autoloader de AutoCAD.
     Copie la carpeta MEMO_SISTEMA.bundle a:
       %%ProgramFiles%%\\Autodesk\\ApplicationPlugins   (recomendado, ubicación de confianza)
       o %%APPDATA%%\\Autodesk\\ApplicationPlugins       (sin permisos de administrador)
     y reinicie AutoCAD. No hace falta APPLOAD, CUILOAD ni Startup Suite. -->
<ApplicationPackage SchemaVersion="1.0" AutodeskProduct="AutoCAD" ProductType="Application"
    Name="MEMO SISTEMA" AppVersion="%(v)s" Author="MEMO"
    Description="Rutinas LISP para estimaciones, secciones, topografía y batimetría con menú de fichas."
    AppNameSpace="memo.sistema" HelpFile="./Contents/LEEME.txt"
    ProductCode="{%(pc)s}" UpgradeCode="{%(uc)s}">
  <CompanyDetails Name="MEMO" />
  <RuntimeRequirements OS="Win64" Platform="AutoCAD*" SeriesMin="R20.0"
      SupportPath="./Contents;./Contents/Iconos" />
  <Components Description="MEMO SISTEMA">
    <RuntimeRequirements OS="Win64" Platform="AutoCAD*" SeriesMin="R20.0" />
    <ComponentEntry AppName="MEMO_Menu" Version="%(v)s" ModuleName="./Contents/%(m)s.cuix"
        AppDescription="Menú MEMO con fichas e iconos" />
    <ComponentEntry AppName="MEMO_Cargador" Version="%(v)s" ModuleName="./Contents/MEMO_Cargador.lsp"
        AppDescription="Cargador bajo demanda de los comandos MEMO" LoadOnAutoCADStartup="True" PerDocument="True" />
  </Components>
</ApplicationPackage>
""" % {"v": VERSION, "m": MENU,
       "pc": str(uuid.uuid5(uuid.NAMESPACE_URL, "memo-sistema-product-" + VERSION)).upper(),
       "uc": str(uuid.uuid5(uuid.NAMESPACE_URL, "memo-sistema-upgrade")).upper()}
    import xml.dom.minidom
    xml.dom.minidom.parseString(pc.encode("utf-8"))
    open(os.path.join(BUNDLE, "PackageContents.xml"), "wb").write(pc.encode("utf-8"))


def construir_leeme(mapa):
    t = ["MEMO SISTEMA %s" % VERSION, "=" * 40, "",
         "Escriba MEMO_AYUDA en AutoCAD para ver todos los comandos.",
         "Escriba MEMO_INFO para ver la carpeta y los archivos cargados.", "",
         "Archivos LISP incluidos y sus comandos:", ""]
    for d, cs in mapa:
        t.append("  %-45s %s" % (d, " ".join(cs)))
    open(os.path.join(CONT, "LEEME.txt"), "wb").write("\r\n".join(t).encode("utf-8-sig"))


def construir_zip():
    ruta = os.path.join(BASE, "MEMO_SISTEMA_bundle.zip")
    with zipfile.ZipFile(ruta, "w", zipfile.ZIP_DEFLATED) as z:
        for raiz, _d, archivos in os.walk(BUNDLE):
            for a in sorted(archivos):
                p = os.path.join(raiz, a)
                z.write(p, os.path.relpath(p, BASE))
        for a in ("INSTALAR.bat", "DESINSTALAR.bat", "LEEME_INSTALACION.txt"):
            z.write(os.path.join(BASE, "instaladores", a), a)
    return ruta


def main():
    if os.path.isdir(BUNDLE):
        shutil.rmtree(BUNDLE)
    os.makedirs(os.path.join(CONT, "Iconos"))
    mapa, dueño, bitacora = construir_lisp()
    construir_cargador(mapa)
    todos = [c for c in cat.COMANDOS if c in set(dueño) | set(cat.COMANDOS_CARGADOR)]
    faltan = sorted(set(dueño) - set(cat.COMANDOS))
    if faltan:
        raise SystemExit("Comandos sin describir en catalogo.COMANDOS: %s" % faltan)
    iconos.generar(todos, cat, os.path.join(CONT, "Iconos"), nombre_icono)
    en_menu = construir_cuix(dueño)
    construir_package()
    construir_leeme(mapa)
    z = construir_zip()
    print("Archivos LISP: %d   Comandos: %d   En menú: %d" % (len(mapa), len(dueño) + len(cat.COMANDOS_CARGADOR), len(en_menu)))
    print("Parches:")
    print("\n".join(bitacora))
    print("Bundle: %s\nZIP:    %s" % (BUNDLE, z))


if __name__ == "__main__":
    main()
