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

VERSION = "2.4.0"
AQUI = os.path.dirname(os.path.abspath(__file__))
BASE = os.path.dirname(AQUI)                       # autocad/
ORIG = os.path.join(BASE, "originales", "MEMO_SISTEMA")
BUNDLE = os.path.join(BASE, "MEMO_SISTEMA.bundle")
CONT = os.path.join(BUNDLE, "Contents")
MENU = "MEMO_SISTEMA"

MAX_SIMBOLO = 32
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
            usados = set()
            for f in funciones_auxiliares(texto):
                nuevo_ = pref + f
                if len(nuevo_) > MAX_SIMBOLO:
                    # nombres largos: AutoLISP dio "error de sintaxis" con 37 caracteres
                    h = hashlib.md5(f.lower().encode()).hexdigest()[:3]
                    nuevo_ = pref + f[:MAX_SIMBOLO - len(pref) - 4] + "_" + h
                if nuevo_.lower() in usados:
                    raise SystemExit("Nombre repetido al acortar: " + nuevo_)
                usados.add(nuevo_.lower())
                texto, n = renombrar_simbolo(texto, f, nuevo_)
                bitacora.append("  - función interna %s -> %s (%d usos)" % (f, nuevo_, n))
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
        elif p.startswith("portapapeles:"):
            ncols = p.split(":")[1]
            patron = (r'\(setq entradaCompleta ""\)\s*\(setq linea \(getstring T "\\n>>> "\)\)\s*'
                      r'\(while \(and linea \(/= linea ""\)\)\s*'
                      r'\(setq entradaCompleta \(strcat entradaCompleta linea "\\n"\)\)\s*'
                      r'\(setq linea \(getstring T "[^"]*"\)\)\s*\)')
            texto, n = re.subn(patron, '(setq entradaCompleta (memo:leer-datos-tabla %s))' % ncols, texto)
            if n != 1:
                raise SystemExit("Parche portapapeles fallido en %s (%d)" % (nombre, n))
            texto, n = re.subn(r'\(princ "\\n\(?Pega los datos[^"]*"\)', '', texto)
            if n < 1:
                raise SystemExit("Parche portapapeles (mensaje) fallido en " + nombre)
            bitacora.append("  - toma los datos del PORTAPAPELES (%s columnas); si no hay, se pegan a mano" % ncols)
        elif p == "ctx-portapapeles":
            texto = reemplazar(texto, '(setq texto_nuevo (getstring T "\\nNuevo texto: "))',
                               '(setq texto_nuevo (memo:pedir-texto "\\nNuevo texto"))', nombre)
            bitacora.append("  - propone como nuevo texto lo copiado en el portapapeles (Enter = usarlo)")
        elif p in CFG_PARCHES:
            for viejo, nuevo_ in CFG_PARCHES[p]:
                texto = reemplazar(texto, viejo, nuevo_, nombre)
            bitacora.append("  - valores configurables con MEMO_CONFIG (%s)" % p)
        elif p.startswith("renombrar:"):
            viejo, nuevo_ = p.split(":", 1)[1].split("=")
            texto, n = renombrar_simbolo(texto, "c:" + viejo, "c:" + nuevo_)
            if n < 1:
                raise SystemExit("Parche %s fallido en %s" % (p, nombre))
            bitacora.append("  - comando %s renombrado a %s (chocaba con tu acad.pgp)" % (viejo, nuevo_))
        elif p == "corm-princ":
            texto, n = re.subn(r'\(princ "\\n"(\s*\r?\n(?:\s*"(?:[^"\\]|\\.)*"\s*\r?\n)+)\)',
                               r'(princ (strcat "\\n"\1))', texto)
            if n != 1:
                raise SystemExit("Parche corm-princ fallido")
            bitacora.append("  - mensaje de carga: princ con varios textos (error al cargar) -> princ + strcat")
        elif p == "malla-entrecurvas":
            anexo, _ = leer_fuente("@fuente/MEMO_MallaInterp.lsp")
            texto = anexo + "\r\n" + texto
            texto, n = re.subn(r'\(setq sum_w 0\.0 sum_we 0\.0 pt \(list gx gy\)\).*?\(setq gz \(/ sum_we sum_w\)\)',
                               '(setq pt (list gx gy))\r\n              (setq gz (mpi:elevacion pt prepared-curves power))\r\n'
                               '              (if gz\r\n                (progn', texto, count=1, flags=re.S)
            if n != 1:
                raise SystemExit("Parche malla-entrecurvas (bucle) fallido")
            texto = reemplazar(texto, "(setq prepared-curves (mp-prepare-curves contour-data))",
                               "(setq prepared-curves (mp-prepare-curves contour-data))\r\n"
                               "              (princ (strcat \"\\nMetodo: \" (mpi:metodo) \" (cambiar con MEMO_CONFIG)\"))\r\n"
                               "              (mpi:preparar contour-data)", nombre)
            texto = reemplazar(texto, "(/= (cdr (assoc 38 edata-cont)) 0.0)",
                               '(or (/= (cdr (assoc 38 edata-cont)) 0.0) (= (strcase (memo:cfg "MALLA_CURVA_CERO")) "SI"))', nombre)
            texto, n = re.subn(r'\(\* \(fix \(\+ \(\* gz \(expt 10\.0 decimals\)\) 0\.5\)\)\s*\(/ 1\.0 \(expt 10\.0 decimals\)\)\)',
                               '(/ (fix (+ (* gz (expt 10.0 decimals)) (if (< gz 0.0) -0.5 0.5))) (expt 10.0 decimals))', texto)
            if n != 1:
                raise SystemExit("Parche malla-entrecurvas (redondeo) fallido")
            texto = reemplazar(texto, "MALLA DE PUNTOS POR INTERPOLACION IDW - v4.7", "MALLA DE PUNTOS v4.7 + MEMO (entre curvas)", nombre)
            bitacora.append("  - interpolación ENTRE CURVAS (lineal entre la curva más cercana y la del otro lado) con índice espacial; IDW opcional")
            bitacora.append("  - redondeo correcto de elevaciones negativas (batimetría)")
        elif p == "quitar-mp":
            texto = reemplazar(texto, "(defun c:MP  () (c:MALLA-PUNTOS))", ";; MP eliminado: chocaba con EMPALME (acad.pgp). Use MLL.", nombre)
            bitacora.append("  - alias MP eliminado (era EMPALME en tu acad.pgp); queda MLL")
        else:
            raise SystemExit("Parche desconocido: " + p)
    for viejo, nuevo_ in cat.MENSAJES.get(nombre, []):
        # el texto está en bytes Windows-1252 vistos como latin-1
        a_ = lambda t: t.encode("cp1252").decode("latin-1")
        texto = reemplazar(texto, a_(viejo), a_(nuevo_), nombre)
    return texto


def _cfg(clave):
    return '(memo:cfg-num "%s")' % clave


CFG_PARCHES = {
    "cfg-cop": [
        ("(setq ancho_no 0.5)", "(setq ancho_no %s)" % _cfg("COP_ANCHO_NO")),
        ("(setq ancho_codigo_original 4.6641)", "(setq ancho_codigo_original %s)" % _cfg("COP_ANCHO_CODIGO")),
        ("(setq ancho_concepto 21.1083)", "(setq ancho_concepto %s)" % _cfg("COP_ANCHO_CONCEPTO")),
        ("(setq ancho_unidad 2.0596)", "(setq ancho_unidad %s)" % _cfg("COP_ANCHO_UNIDAD")),
        ("(setq ancho_precio 2.0596)", "(setq ancho_precio %s)" % _cfg("COP_ANCHO_PRECIO")),
    ],
    "cfg-asi": [
        (a, b) for k, v, g in [
            ("NO", "0.9841", "no"), ("CODIGO", "1.7887", "codigo"), ("DESCRIPCION", "14.8620", "descripcion"),
            ("UNIDAD", "1.1700", "unidad"), ("PU", "1.7250", "pu"), ("CANTIDAD", "1.6997", "cantidad"),
            ("IMPORTE", "1.9849", "importe")]
        for a, b in [
            ("(setq *mp-ancho-%s* %s)" % (g, v), "(setq *mp-ancho-%s* %s)" % (g, _cfg("ASI_ANCHO_" + k))),
            ("(setq ancho_%s *mp-ancho-%s*)" % (g, g),
             "(setq ancho_%s (setq *mp-ancho-%s* %s))" % (g, g, _cfg("ASI_ANCHO_" + k))),
        ]
    ],
    "cfg-cssa": [("(setq ancho_total 24.0964)", "(setq ancho_total %s)" % _cfg("CSSA_ANCHO_TOTAL"))],
    "cfg-espesor": [("(* area 0.10)", "(* area %s)" % _cfg("BACHEO_ESPESOR"))],
}


# ---------------------------------------------------------------------------
# 1. LISP
# ---------------------------------------------------------------------------
FUENTE = os.path.join(BASE, "fuente")


def leer_fuente(origen):
    """Devuelve el texto (bytes Windows-1252 vistos como latin-1) con CRLF.
    Los archivos UTF-8 se convierten a Windows-1252 (ANSI): así TODOS los
    LISP quedan en la misma codificación, la que ya funcionaba en AutoCAD."""
    ruta = os.path.join(FUENTE, origen[8:]) if origen.startswith("@fuente/") else os.path.join(ORIG, origen)
    crudo = open(ruta, "rb").read()
    convertido = False
    if any(b > 127 for b in crudo):
        try:
            crudo = crudo.decode("utf-8").encode("cp1252")
            convertido = True
        except UnicodeDecodeError:
            pass   # ya es ANSI
    texto = crudo.decode("latin-1").replace("\r\n", "\n").replace("\n", "\r\n")
    return texto, convertido


def escribir_lisp(destino, texto, origen, parches):
    nl = "\r\n"
    cab = (";;; MEMO SISTEMA %s - archivo generado por construir_bundle.py%s"
           ";;; Origen: %s%s" % (VERSION, nl, origen.encode("ascii", "replace").decode(), nl))
    if parches:
        cab += ";;; Parches aplicados: %s%s" % (", ".join(parches), nl)
    texto = cab + nl + texto
    salida = os.path.join(CONT, "LISP", destino)
    os.makedirs(os.path.dirname(salida), exist_ok=True)
    open(salida, "wb").write(texto.encode("latin-1"))
    return texto


def construir_lisp():
    mapa = []          # (destino, [comandos])
    bitacora = []
    dueño = {}
    bases = set()
    origen, destino = cat.BIBLIOTECA
    texto, _ = leer_fuente(origen)
    if not parentesis_balanceados(texto):
        raise SystemExit("Paréntesis desbalanceados en " + destino)
    escribir_lisp(destino, texto, origen, [])
    for origen, destino, parches in cat.ARCHIVOS:
        base = os.path.splitext(os.path.basename(destino))[0].lower()
        if base in bases:
            raise SystemExit("Nombre de archivo repetido: " + destino)
        bases.add(base)
        texto, convertido = leer_fuente(origen)
        if convertido:
            bitacora.append("%s: convertido de UTF-8 a ANSI (Windows-1252)" % destino)
        if parches or destino in cat.MENSAJES:
            bitacora.append("%s:" % destino)
            texto = aplicar_parches(texto, parches, destino, bitacora)
        if not parentesis_balanceados(texto):
            raise SystemExit("Paréntesis desbalanceados en " + destino)
        texto = escribir_lisp(destino, texto, origen, parches)

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
    for viejo, (nuevo_, _alias) in cat.RENOMBRADOS.items():
        if viejo in dueño:
            raise SystemExit("El comando %s debía renombrarse pero sigue definido en %s" % (viejo, dueño[viejo]))
    return mapa, dueño, bitacora


# ---------------------------------------------------------------------------
# 2. Cargador
# ---------------------------------------------------------------------------
def lisp_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


def ascii_lisp(s):
    """Antes se quitaban acentos; ahora todo el sistema está en Windows-1252."""
    return s


CARGADOR = r""";;; =====================================================================
;;;  MEMO_Cargador.lsp  -  MEMO SISTEMA @VERSION@
;;;  ARCHIVO GENERADO: no editar a mano; edite herramientas/catalogo.py
;;;
;;;  Un solo cargador para todos los LISP. NO carga los @NARCH@ archivos al
;;;  abrir cada dibujo: define cada comando como "stub" y el archivo real
;;;  se carga la primera vez que se usa el comando (carga bajo demanda).
;;;  Si existen versiones compiladas (MEMO_COMPILAR) de esta misma versión,
;;;  carga los .fas en lugar de los .lsp.
;;; =====================================================================
(vl-load-com)

(if (not memo:cargado)
  (progn
    (setq memo:version "@VERSION@")
    (setq memo:raiz (findfile "MEMO_Cargador.lsp"))
    (if memo:raiz
      (setq memo:raiz (vl-string-translate "\\" "/" (vl-filename-directory memo:raiz))))
    (setq memo:archivos-cargados nil memo:num-comandos 0 memo:*mapa* nil memo:*stubs* nil memo:*ya-definidos* nil
          memo:*envueltos* nil memo:*marca-abierta* nil)
    (setq memo:dir-fas (strcat (vl-string-translate "\\" "/" (getenv "APPDATA")) "/MEMO_SISTEMA/FAS/"))

    ;; Valores configurables: (CLAVE "defecto" "descripción" "NUM|TXT" "opciones")
    (setq memo:*cfg-def* '(
@CFG@
    ))

    ;; ¿Hay FAS compilados para ESTA versión?
    (defun memo:fas-vigente-p (/ f v)
      (if (and (setq f (findfile (strcat memo:dir-fas "version.txt")))
               (setq f (open f "r")))
        (progn (setq v (read-line f)) (close f) (= v memo:version))))
    (setq memo:usar-fas (memo:fas-vigente-p))

    ;; Ruta real a cargar (.fas compilado o .lsp)
    (defun memo:ruta (rel / fas)
      (setq fas (strcat memo:dir-fas (vl-filename-base rel) ".fas"))
      (if (and memo:usar-fas (findfile fas))
        fas
        (strcat memo:raiz "/LISP/" rel ".lsp")))

    ;; Carga el archivo real y ejecuta el comando solicitado
    (defun memo:cargar (rel cmd / ruta res)
      (setq ruta (memo:ruta rel))
      (cond
        ((member rel memo:archivos-cargados)
         (princ (strcat "\nMEMO: " rel " se cargó pero no define el comando " cmd)))
        ((not (findfile ruta))
         (princ (strcat "\nMEMO: no se encuentra " ruta)))
        (T
         (setq memo:archivos-cargados (cons rel memo:archivos-cargados))
         (setq res (vl-catch-all-apply 'load (list ruta)))
         (if (vl-catch-all-error-p res)
           (princ (strcat "\nMEMO: error al cargar " rel ": " (vl-catch-all-error-message res)))
           (progn
             (memo:envolver (cadr (assoc rel memo:*mapa*)))
             (eval (list (read (strcat "C:" cmd))))))))
      (princ))

    ;; Define los comandos de un archivo como stubs que lo cargan al primer uso
    (defun memo:al (rel cmds / sym)
      (setq memo:*mapa* (cons (list rel cmds) memo:*mapa*))
      (foreach cmd cmds
        (setq sym (read (strcat "C:" cmd)))
        ;; Si otro LISP cargado antes ya definía el comando, se reemplaza por
        ;; la versión MEMO (la que esperan los botones) y se avisa.
        (if (eval sym) (setq memo:*ya-definidos* (cons cmd memo:*ya-definidos*)))
        (eval (list 'defun sym nil (list 'memo:cargar rel cmd)))
        (setq memo:*stubs* (cons (cons cmd (vl-princ-to-string (eval sym))) memo:*stubs*))
        (setq memo:num-comandos (1+ memo:num-comandos))))

    ;; T si el comando todavía es el stub (su archivo no lo definió)
    (defun memo:es-stub-p (cmd / s)
      (and (setq s (assoc cmd memo:*stubs*))
           (= (cdr s) (vl-princ-to-string (eval (read (strcat "C:" cmd)))))))

    (if memo:raiz
      (progn
        ;; Biblioteca común (siempre)
        (if (vl-catch-all-error-p (vl-catch-all-apply 'load (list (memo:ruta "@LIB@"))))
          (princ "\nMEMO: no se pudo cargar la biblioteca MEMO_Lib."))
@AUTOLOADS@
        (setq memo:*mapa* (reverse memo:*mapa*))
        (if memo:*ya-definidos*
          (progn
            (princ "\nMEMO: otro LISP cargado antes ya definía estos comandos; se usa la versión MEMO:")
            (princ "\n      ")
            (foreach c (reverse memo:*ya-definidos*) (princ (strcat c " ")))
            (princ "\n      (revise APPLOAD > Conjunto de inicio y quite los LISP viejos)")))
        (setq memo:cargado T)
        (princ (strcat "\nMEMO SISTEMA " memo:version " listo: " (itoa memo:num-comandos)
                       " comandos" (if memo:usar-fas " (compilados)" "")
                       ". Escriba MEMO_AYUDA para ver la lista.")))
      (princ "\nMEMO: no se encontró MEMO_Cargador.lsp en las rutas de soporte."))))

;;; ---------------------------------------------------------------------
;;; Comandos propios del sistema
;;; ---------------------------------------------------------------------
(defun c:MEMO_AYUDA ()
  (textscr)
  (princ (strcat "\n========== MEMO SISTEMA " memo:version " =========="))
@AYUDA@
  (princ "\n\nComandos renombrados por chocar con tu acad.pgp:")
@RENOMBRES@
  (princ "\n\nTip: pase el cursor sobre los botones de las fichas MEMO para ver la descripción.")
  (princ))

(defun c:MEMO_INFO ()
  (princ (strcat "\nMEMO SISTEMA " memo:version))
  (princ (strcat "\nCarpeta: " (if memo:raiz memo:raiz "(no encontrada)")))
  (princ (strcat "\nComandos registrados: " (itoa memo:num-comandos)))
  (if memo:*ya-definidos*
    (progn
      (princ "\nYa los definía otro LISP (ahora usan la versión MEMO):")
      (foreach c (reverse memo:*ya-definidos*) (princ (strcat " " c)))))
  (princ (strcat "\nCompilados (FAS): " (if memo:usar-fas (strcat "SÍ, en " memo:dir-fas) "no (se usan los .lsp)")))
  (princ (strcat "\nBiblioteca MEMO_Lib: " (if memo:portapapeles "cargada" "NO cargada")))
  (princ (strcat "\nDeshacer agrupado y ESC seguro: "
                 (if (= (strcase (memo:cfg "DESHACER_AGRUPADO")) "NO") "desactivado" "activo")
                 "  |  Portapapeles en tablas: " (memo:cfg "TABLA_PORTAPAPELES")))
  (princ "\nArchivos ya cargados en este dibujo:")
  (if memo:archivos-cargados
    (foreach a (reverse memo:archivos-cargados) (princ (strcat "\n  " a)))
    (princ "\n  (ninguno todavía: se cargan al usar cada comando)"))
  (princ (strcat "\nMenú @MENU@: " (if (menugroup "@MENU@") "cargado" "NO cargado")))
  (princ))

(defun c:MEMO_QUITAR_ANTERIOR (/ old)
  ;; Descarga el menú viejo 'MEMO' (Memo.cuix con rutas fijas a AutoCAD 2024/2026)
  (if (menugroup "MEMO")
    (progn
      (setq old (getvar "CMDECHO"))
      (setvar "CMDECHO" 0)
      (command "_.CUIUNLOAD" "MEMO")
      (setvar "CMDECHO" old)
      (princ "\nMenú anterior MEMO descargado. Sus LISP ya no se cargarán al abrir dibujos."))
    (princ "\nEl menú anterior MEMO no está cargado. Nada que hacer."))
  (princ))

;;; Carga y muestra el menú MEMO (fichas y menú desplegable)
(defun c:MEMO_MENU (/ cuix old r)
  (setq cuix (strcat memo:raiz "/@MENU@.cuix"))
  (princ "\n=== MEMO_MENU ===")
  (if (not (menugroup "@MENU@"))
    (progn
      (princ (strcat "\nEl menú @MENU@ no está cargado. Cargando " cuix " ..."))
      (if (not (findfile cuix))
        (princ "\nNO se encuentra el archivo del menú. Reinstale con INSTALAR.bat.")
        (progn
          (setq old (getvar "FILEDIA"))
          (setvar "FILEDIA" 0)
          (setq r (vl-catch-all-apply 'command (list "_.CUILOAD" (vl-string-translate "/" "\\" cuix))))
          (setvar "FILEDIA" old)
          (if (menugroup "@MENU@")
            (princ "\nMenú cargado correctamente.")
            (progn
              (princ "\n*** AutoCAD NO pudo cargar el menú. ***")
              (princ "\nCopie el mensaje de error que aparece arriba (o en la ventana) y envíelo.")))))))
  (if (menugroup "@MENU@")
    (progn
      (initget "Si No")
      (if (/= (getkword "\n¿Mostrar también la barra de menús clásica con el menú MEMO? [Si/No] <Si>: ") "No")
        (setvar "MENUBAR" 1))
      (vl-catch-all-apply 'command (list "_.RIBBON"))
      (princ "\nSi las fichas MEMO no aparecen en la cinta:")
      (princ "\n  1. Clic derecho sobre la cinta > Mostrar fichas > marque MEMO Estimaciones, MEMO Topografía y MEMO Dibujo.")
      (princ "\n  2. Si no están en esa lista: escriba IUP (o CUI) > arriba a la izquierda, 'Espacios de trabajo' >")
      (princ "\n     su espacio actual > 'Personalizar espacio de trabajo' > abajo, en Archivos parciales,")
      (princ "\n     @MENU@ > Fichas de cinta > marque las 3 fichas MEMO > Hecho > Aceptar.")))
  (princ))

;;; Carga TODOS los archivos y comprueba que cada comando quede definido.
(defun c:MEMO_VERIFICAR (/ ok n res err faltan)
  (princ "\nMEMO_VERIFICAR carga TODOS los archivos en este dibujo")
  (princ "\n(algunos crean estilos o capas al cargarse): úselo en un dibujo nuevo.")
  (initget "Si No")
  (if (/= (getkword "\n¿Continuar? [Si/No] <Si>: ") "No")
    (progn
      (setq ok 0 n 0)
      (foreach par memo:*mapa*
        (setq res nil)
        (if (not (member (car par) memo:archivos-cargados))
          (progn
            (setq res (vl-catch-all-apply 'load (list (memo:ruta (car par)))))
            (setq memo:archivos-cargados (cons (car par) memo:archivos-cargados))
            (if (not (vl-catch-all-error-p res)) (memo:envolver (cadr par)))))
        (if (vl-catch-all-error-p res)
          (setq err (cons (strcat (car par) " -> " (vl-catch-all-error-message res)) err))
          (foreach c (cadr par)
            (setq n (1+ n))
            (if (memo:es-stub-p c)
              (setq faltan (cons (strcat c "  (" (car par) ")") faltan))
              (setq ok (1+ ok))))))
      (textscr)
      (princ "\n\n=========== RESULTADO MEMO_VERIFICAR ===========")
      (princ (strcat "\nArchivos: " (itoa (length memo:*mapa*))
                     "    Comandos correctos: " (itoa ok) " de " (itoa n)))
      (princ (strcat "\nBiblioteca MEMO_Lib: " (if memo:portapapeles "OK" "NO CARGADA")))
      (foreach e (reverse err) (princ (strcat "\n  ERROR AL CARGAR: " e)))
      (foreach f (reverse faltan) (princ (strcat "\n  NO DEFINIDO:     " f)))
      (if (and (not err) (not faltan)) (princ "\n  Todo correcto."))
      (princ "\n================================================")))
  (princ))

;;; Compila todos los LISP a FAS (carga más rápida, código protegido).
(defun c:MEMO_COMPILAR (/ base ok mal res f lista)
  (if (not vlisp-compile)
    (princ "\nEsta versión de AutoCAD no tiene vlisp-compile; se siguen usando los .lsp.")
    (progn
      (setq base (strcat (vl-string-translate "\\" "/" (getenv "APPDATA")) "/MEMO_SISTEMA"))
      (vl-mkdir base)
      (vl-mkdir (strcat base "/FAS"))
      (setq ok 0 lista (cons "@LIB@" (mapcar 'car memo:*mapa*)))
      (foreach rel lista
        (princ (strcat "\nCompilando " rel "..."))
        (setq res (vl-catch-all-apply 'vlisp-compile
                    (list 'st (strcat memo:raiz "/LISP/" rel ".lsp")
                              (strcat memo:dir-fas (vl-filename-base rel) ".fas"))))
        (if (and res (not (vl-catch-all-error-p res)))
          (setq ok (1+ ok))
          (setq mal (cons rel mal))))
      (if (and (> ok 0) (setq f (open (strcat memo:dir-fas "version.txt") "w")))
        (progn (write-line memo:version f) (close f)))
      (textscr)
      (princ (strcat "\n\nCompilados: " (itoa ok) " de " (itoa (length lista)) " en " memo:dir-fas))
      (foreach m (reverse mal) (princ (strcat "\n  No se compiló (se usará el .lsp): " m)))
      (princ "\nLos FAS se usan desde el próximo dibujo que abras.")
      (princ "\nPara volver a los .lsp, borre la carpeta FAS. Al actualizar el sistema se ignoran solos.")))
  (princ))

(princ)
"""


def construir_cargador(mapa):
    autoloads = []
    for destino, cmds in mapa:
        if cmds:
            autoloads.append("        (memo:al %s '(%s))" % (lisp_str(destino[:-4]), " ".join(lisp_str(c) for c in cmds)))
    cfg = ["      (%s)" % " ".join(lisp_str(x) for x in e) for e in cat.CONFIG]
    ayuda = []
    for tab, _kt, paneles in cat.FICHAS:
        ayuda.append("  (princ %s)" % lisp_str("\n\n### " + tab.upper()))
        for panel, items in paneles:
            ayuda.append("  (princ %s)" % lisp_str("\n  -- " + panel))
            for it in items:
                for c in (it if isinstance(it, list) else [it]):
                    desc = cat.COMANDOS[c][1]
                    ayuda.append("  (princ %s)" % lisp_str("\n   %-16s %s" % (c, desc)))
    ren = ["  (princ %s)" % lisp_str("\n   %-5s -> %-22s (tu alias %s)" % (v, n, a))
           for v, (n, a) in cat.RENOMBRADOS.items()]
    texto = (CARGADOR.replace("@VERSION@", VERSION).replace("@NARCH@", str(len(mapa)))
             .replace("@CFG@", "\n".join(cfg)).replace("@AUTOLOADS@", "\n".join(autoloads))
             .replace("@AYUDA@", "\n".join(ayuda)).replace("@RENOMBRES@", "\n".join(ren))
             .replace("@LIB@", cat.BIBLIOTECA[1][:-4]).replace("@MENU@", MENU))
    if not parentesis_balanceados(texto):
        raise SystemExit("Cargador desbalanceado")
    texto = texto.replace("\r\n", "\n").replace("\n", "\r\n")
    open(os.path.join(CONT, "MEMO_Cargador.lsp"), "wb").write(texto.encode("cp1252"))

    mnl = (";;; MEMO_SISTEMA.mnl - AutoCAD lo carga junto con MEMO_SISTEMA.cuix\r\n"
           "(if (and (not memo:cargado) (findfile \"MEMO_Cargador.lsp\"))\r\n"
           "  (load (findfile \"MEMO_Cargador.lsp\")))\r\n(princ)\r\n")
    open(os.path.join(CONT, MENU + ".mnl"), "wb").write(mnl.encode("ascii"))


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
        # Los iconos NO se incrustan: AutoCAD los toma de Contents/Iconos (ruta
        # de soporte del bundle). Así el CUIX tiene sólo las partes estándar.
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


PRUEBAS_CABECERA = """# Lista de pruebas - MEMO SISTEMA @VERSION@

> Archivo generado por `herramientas/construir_bundle.py`, a partir de `catalogo.py`.
> Imprime esta lista o cópiala a Excel y marca cada prueba.

## 0. Prueba automática (2 minutos)

1. Abre un **dibujo nuevo** (con plantilla vacía).
2. Escribe `MEMO_INFO`: debe mostrar la carpeta del bundle, *Biblioteca MEMO_Lib: cargada* y *Menú MEMO_SISTEMA: cargado*.
3. Escribe `MEMO_VERIFICAR` y presiona Enter: al final debe decir **Todo correcto**.
   Si aparece *ERROR AL CARGAR* o *NO DEFINIDO*, copia ese texto y envíamelo.

## 1. Lo nuevo en 2.4: EA (probar primero)

| # | Prueba | Resultado esperado | OK |
|---|---|---|---|
| 1 | `EA` → *Exportar a Excel* en un dibujo con secciones | En Excel, las columnas PROMEDIO, VOLUMEN y TOTAL muestran **números** (antes salía #¿NOMBRE? por las fórmulas en español) | |
| 2 | Compara 5 áreas del Excel contra los textos del dibujo, sobre todo SUB-BASE, textos con "(M2)" y MTEXT con formato | Coinciden (antes podían salir negativas, 2.0 en vez de 12.50, etc.) | |
| 3 | Un cadenamiento escrito como `KM 1+020` o con texto antes | Columna CAD = 1+020 y la distancia entre secciones es correcta | |
| 4 | Un CAD escrito dos veces en el dibujo (arriba y abajo de la sección) | Aparece **una sola fila** con sus áreas (antes se duplicaban) | |
| 5 | `EA` → desmarca *Carpeta* → Exportar | No sale la columna CARPETA (antes las casillas no hacían nada) | |
| 6 | `EA` → *Exportar* con *Seleccionar secciones* | Pide seleccionar con ventana y exporta sólo eso | |
| 7 | `EA` → *Etiquetar* en MTEXT con formato | Cambia sólo el número del área; el formato del texto queda intacto | |
| 8 | Un texto "AREA..." en el membrete o en la capa NOTAS | Se ignora | |
| 9 | `MEMO_CONFIG` → *EA: decimales* = 3 → `EA-HA` | El área se escribe con 3 decimales (12.500) aunque DIMZIN suprima ceros | |

## 1a. Versión 2.3: malla de puntos

| # | Prueba | Resultado esperado | OK |
|---|---|---|---|
| 1 | En tu dibujo con curvas de nivel: `MLL` con la misma separación de siempre | Dice *Metodo: ENTRECURVAS*; la malla **cubre todo el espacio entre curvas, sin huecos**, y las Z cambian de forma pareja de una curva a la siguiente (sin escalones pegados a cada curva) | |
| 2 | Revisa 3 o 4 puntos a la mitad entre dos curvas (ej. 100 y 101) | Su Z es ≈ 100.50; cerca de la curva de 100, ≈ 100.1 | |
| 3 | Curvas muy separadas (más de 20 m) | Ya no quedan franjas vacías entre ellas | |
| 4 | Cima de un cerro o fondo de una hondonada | Toma la Z de la última curva (plano), sin huecos | |
| 5 | `MEMO_CONFIG` → *Malla de puntos* = `IDW` → `MLL` | Sale igual que antes, para comparar | |
| 6 | Batimetría con Z negativas y etiquetas a 2 decimales | Redondea bien (−1.234 → −1.23; antes daba −1.22) | |
| 7 | Batimetría con curva de nivel 0: `MEMO_CONFIG` → *usar curvas con elevación 0* = `SI` | La curva 0 se toma en cuenta (antes se ignoraba siempre) | |
| 8 | Compara el tiempo con la versión anterior en el mismo dibujo | Igual o más rápido (en las pruebas fue unas 9 veces más rápido) | |

## 1b. Versión 2.2

| # | Prueba | Resultado esperado | OK |
|---|---|---|---|
| 1 | En Excel copia 3 filas de 5 columnas (No., Código, Concepto, Unidad, Precio). En AutoCAD: `COP`, elige el punto | **Sin pegar nada**: dice *Datos del portapapeles: 3 fila(s), 5 columna(s)*, muestra la 1a fila y dibuja la tabla **igual que antes** | |
| 2 | Después de la prueba 1, escribe `U` una sola vez | Desaparece **toda** la tabla (textos, rectángulos y vistas) de un solo paso | |
| 3 | Copia 7 columnas (formato ASI) y ejecuta `COP` | Avisa *esta tabla espera 5 columnas* y pregunta si usar los datos; con Enter (No) pide pegar a mano | |
| 4 | Una celda del Concepto con salto de línea (Alt+Enter en Excel) | La fila sale completa, con el concepto en una sola línea | |
| 5 | `COP` con el portapapeles vacío (copia una imagen o nada) | Pide pegar los datos a mano, como antes | |
| 6 | Copia 7 columnas y ejecuta `MTABLA` | Propone *Asipona* y con Enter dibuja la tabla ASI | |
| 7 | `COP`, elige el punto y presiona ESC; luego revisa OSMODE y la capa actual | Quedan **igual que antes** de ejecutar COP (antes podía quedar OSMODE=0 y capa CONCEPTOS) | |
| 8 | `CTF` (factor de ancho) y presiona ESC a la mitad | REGENMODE vuelve a 1 (antes se quedaba en 0) | |
| 9 | Copia una palabra (ej. `PAVIMENTO`) → `CTX` → Enter → selecciona textos | Los textos cambian a `PAVIMENTO`; si escribes otro texto, usa el que escribiste | |
| 10 | `RS` dibuja 3 rectángulos → `U` | Deshace todo lo que hizo RS en un paso | |
| 11 | `MEMO_INFO` | Dice *Deshacer agrupado y ESC seguro: activo, Portapapeles en tablas: SI* | |
| 12 | `MEMO_CONFIG` → *Tablas: tomar datos del portapapeles* = `PREGUNTAR` → `COP` | Vuelve a preguntar antes de usar lo copiado | |
| 13 | `MEMO_CONFIG` → *Un solo Deshacer...* = `NO` → abre otro dibujo → `COP` → `U` | Deshace paso por paso, como antes (sirve si algún comando se comportara raro) | |

## 1c. Versión 2.1

| # | Prueba | Resultado esperado | OK |
|---|---|---|---|
| 1 | `MAREA` → Enter | Ejecuta la opción por defecto (*Prefijo* = HA2); la segunda vez propone la última usada | |
| 2 | `MBACHEO` | Propone *Dibujar*; después de cada paso propone el siguiente (Numerar, Cotar, Exportar, Salir) | |
| 3 | `MEMO_CONFIG` → *Bacheo: espesor* = 0.15 → `EXR` | El volumen del CSV = área × 0.15 | |
| 4 | `MP`, `EL`, `RV`, `PV`, `TM`, `CL`, `LC`, `CT`, `CTT`, `CC` | Hacen lo que dice tu acad.pgp (EMPALME, ELIPSE, REVOLUCION...) | |
| 5 | `MLL`, `ELTN`, `RNB`, `IBPV`, `IBTM`, `CLO`, `LCO`, `CTB`, `CTX`, `RSC` | Hacen lo que antes hacían los nombres viejos | |
| 6 | `BPOL` y ESC a la mitad; después otro comando con ESC | AutoCAD queda normal | |
| 7 | `MEMO_COMPILAR` → otro dibujo → `MEMO_INFO` | *Compilados (FAS): SÍ* y los comandos funcionan igual | |

## 2. Todos los comandos

Una prueba rápida por comando: ejecútalo en `Ejercicio COMANDOS NUEVOS.dwg` y compara con lo que hacía antes.
"""


def construir_pruebas():
    t = [PRUEBAS_CABECERA.replace("@VERSION@", VERSION)]
    for tab, _k, paneles in cat.FICHAS:
        t.append("\n### %s\n" % tab)
        t.append("| Panel | Comando | Qué debe hacer | OK |")
        t.append("|---|---|---|---|")
        for panel, items in paneles:
            for it in items:
                for c in (it if isinstance(it, list) else [it]):
                    t.append("| %s | `%s` | %s | |" % (panel, c, cat.COMANDOS[c][1].replace("|", "\\|")))
    open(os.path.join(BASE, "LISTA_DE_PRUEBAS.md"), "w", encoding="utf-8").write("\n".join(t) + "\n")


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
    construir_pruebas()
    z = construir_zip()
    print("Archivos LISP: %d   Comandos: %d   En menú: %d" % (len(mapa), len(dueño) + len(cat.COMANDOS_CARGADOR), len(en_menu)))
    print("Parches:")
    print("\n".join(bitacora))
    print("Bundle: %s\nZIP:    %s" % (BUNDLE, z))


if __name__ == "__main__":
    main()
