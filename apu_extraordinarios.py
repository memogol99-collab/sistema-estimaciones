"""
Análisis de precios unitarios EXTRAORDINARIOS en el formato de NEODATA (como el Doc. 14
del concurso), integrados con los insumos, básicos, cuadrillas y cargos del contrato y con
rendimientos observados en las bitácoras de WhatsApp.

Entradas (carpeta contratos/concurso_garzas/):
  14a_Precios.pdf, 14c_Basicos.pdf, 15_Insumos.pdf      documentos del concurso
  PU_Contrato_y_Extraordinarios_Manzanillo.xlsx          extraordinarios ya definidos (drenaje)
Salida: reportes_whatsapp/APU_Extraordinarios_NEODATA.xlsx

    python apu_extraordinarios.py
"""

import math
import re
import sys
from datetime import date
from pathlib import Path

import openpyxl
from openpyxl import Workbook
from openpyxl.styles import Alignment, Border, Font, PatternFill, Side

import formato_neodata as fmt_neo
import neodata_concurso as nc

CARPETA = Path("contratos/concurso_garzas")
SALIDA = Path("reportes_whatsapp/APU_Extraordinarios_NEODATA.xlsx")
FUENTE = "Arial"
NARANJA = "FCE4D6"
AZUL = "1F3864"

# Cargos del concurso (Doc. 14a)
CARGOS = {"oc": 0.024102, "campo": 0.080817, "fin": 0.005358, "util": 0.081, "sfp": 0.005, "isn": 0.03}

# --------------------------------------------------------------------------
# INSUMOS NUEVOS (no existen en el Doc. 15) — precio estimado, requieren 3 cotizaciones
# --------------------------------------------------------------------------
NUEVOS_OBRA = {
    "N-MARTELEC": ("MARTILLO DEMOLEDOR ELECTRICO 25 KG (COSTO HORARIO)", "HORA", 65.00, "EQ"),
    "N-BSUM2": ("BOMBA SUMERGIBLE ELECTRICA 2\" PARA ACHIQUE (COSTO HORARIO)", "HORA", 35.00, "EQ"),
    "N-ESPAMB": ("ESPECIALISTA AMBIENTAL / ARBORISTA (SALARIO REAL)", "JOR", 1850.00, "MO"),
    "N-MATARB": ("MATERIALES PARA TRASPLANTE DE ARBOL MAYOR (ENRAIZADOR, CICATRIZANTE, ARPILLA, TIERRA PREPARADA, TUTORES)",
                 "LOTE", 18000.00, "MAT"),
}

# --------------------------------------------------------------------------
# EXTRAORDINARIOS NUEVOS DETECTADOS EN LAS BITÁCORAS (contrato Garzas)
# Cada renglón: (código, cantidad). La cantidad es por unidad del concepto.
# --------------------------------------------------------------------------
EXT_OBRA = [
    {
        "clave": "EXT OBR-01", "unidad": "PZA", "cant_garzas": 32, "partida": "SUBESTRUCTURA",
        "descripcion": ("Descabece de pila de cimentación de concreto reforzado de 1.20 m de diámetro, hasta 1.00 m de "
                        "longitud, por medios manuales y mecánicos, con martillo demoledor eléctrico, conservando y limpiando "
                        "el acero de refuerzo para su anclaje; incluye: mano de obra, equipo, herramienta, carga y acarreo del "
                        "producto a banco de tiro, limpieza del área y todo lo necesario para su correcta ejecución. P.U.O.T."),
        "renglones": [("MOCU22", 2.5), ("N-MARTELEC", 20.0), ("EQ-GENERA", 10.0), ("EQ-RETRO", 3.0), ("BA-AYCTT", 1.131)],
        "rendimiento": "1.25 jornadas de cuadrilla de 4 ayudantes por pila",
        "evidencia": ("Eje 8 (Garzas): descabece del 26/10 al 10/11/2026, 10 jornadas con 4 ayudantes en promedio, "
                      "retroexcavadora 3 de los 10 días y 2 martillos demoledores Dewalt de 25 kg con generador (equipo menor "
                      "del reporte) para 8 pilas → 1.25 jornadas/pila. Caballete 1: 6 jornadas y Caballete 9: 4 jornadas "
                      "(número de pilas por confirmar). Volumen demolido: π·0.60²·1.00 = 1.131 m³/pila."),
        "cantidad_nota": "Cantidad estimada: 8 pilas por eje × 4 apoyos (ejes 1, 8 y caballetes) — ajustar con el generador.",
    },
    {
        "clave": "EXT OBR-02", "unidad": "JOR", "cant_garzas": 6, "partida": "SUBESTRUCTURA",
        "descripcion": ("Abatimiento del nivel freático en excavaciones para zapatas, con equipo de bombeo (2 motobombas "
                        "autocebantes de 3\" a gasolina y 1 bomba sumergible eléctrica de 2\" con planta generadora), por "
                        "jornada de 8 horas de operación; incluye: operación, combustibles, lubricantes, mangueras, vigilancia, "
                        "mano de obra, herramienta y todo lo necesario para mantener la excavación en seco. P.U.O.T."),
        "renglones": [("MOCU22", 1.0), ("N-BOMBA3", 16.0), ("N-BSUM2", 8.0), ("EQ-GENERA", 8.0)],
        "rendimiento": "1 jornada = 8 h de bombeo con 2 motobombas de 3\" + 1 sumergible de 2\"",
        "evidencia": ("Zapata Eje 8 (Garzas): abatimiento del 12 al 14/11/2026, 3 jornadas con 2 a 3 ayudantes; equipo menor "
                      "en obra: 2 motobombas Husky 500 L/min a gasolina, 1 motobomba eléctrica y 1 bomba sumergible de 2\"."),
        "cantidad_nota": "Cantidad estimada: 3 jornadas observadas en Eje 8 + 3 para las siguientes zapatas — ajustar.",
    },
    {
        "clave": "EXT OBR-03", "unidad": "PZA", "cant_garzas": 1, "partida": "TRABAJOS DIVERSOS",
        "descripcion": ("Trasplante de árbol de gran porte (ceiba) con cepellón, del sitio de afectación a su nueva ubicación "
                        "dentro de la obra; incluye: sondeo y localización de raíces principales, demolición y retiro de "
                        "pavimento perimetral, poda técnica, formación y protección del cepellón, aplicación de enraizador y "
                        "cicatrizante, izaje y traslado con grúa, excavación de la cepa, plantación, tutoreo, riegos de "
                        "establecimiento, supervisión de especialista ambiental, mano de obra, equipo y herramienta. P.U.O.T."),
        "renglones": [("N-ESPAMB", 15.0), ("MOCU22", 9.5), ("EQ-RETRO", 48.0), ("EQ-HIAB", 8.0), ("EQ-GRUA80", 6.0),
                      ("EQ-PIPA", 6.0), ("N-MATARB", 1.0)],
        "rendimiento": "15 jornadas de especialista, 19 de ayudante, 6 días de retroexcavadora (observado) + izaje (estimado)",
        "evidencia": ("Ceiba de Av. Elías Zamora (Garzas): 08/10 sondeo de raíces (2 especialistas, 3 ayudantes, retro); "
                      "29/10, 06, 07, 09 y 10/11 preparación (1 a 3 especialistas, 2 a 6 ayudantes, retro diario, HIAB el 06/11). "
                      "Total observado: 15 jornadas-especialista, 19 jornadas-ayudante, 6 días de retro (48 h), 8 h de HIAB. "
                      "El izaje y traslado aún no se reporta: grúa 80 t 6 h y pipa 6 h son estimados."),
        "cantidad_nota": "1 pieza (la ceiba de Av. Elías Zamora). El catálogo de Garzas solo tiene derribo (No. 4).",
    },
]

# Ajustes de rendimiento a extraordinarios ya existentes, con base en la bitácora
AJUSTES = {
    "EXT HID-02": {
        "renglones": [("N-HD24", 1.02), ("MOT111", 5 / 36), ("MO043", 0.5 / 36), ("%MO", 0.03), ("%MO5", 0.02),
                      ("EQ-EXCAVA", 8 / 36)],
        "rendimiento": "36 m por jornada (6 tramos de 6 m) con 5 técnicos instaladores",
        "antes": "20 m por jornada con cuadrilla 034 (1 maniobrista + 2 ayudantes especializados); excavadora 0.20 h/m",
        "evidencia": ("Garzas 18/11/2026: 'Instalación de tubería de 24\" en Av. Elías Zamora cruce con Av. Las Garzas. "
                      "6 tramos de tubo' con 5 técnicos instaladores (segurista, topógrafo y bandereras se pagan aparte). "
                      "Tramo HD estándar de 6 m → 36 m/jornada; excavadora para bajar tubería 8 h/36 m = 0.222 h/m."),
    },
}
CONFIRMADOS = {
    "EXT PRE-03": ("Sondeo de trayectoria (23/10/2026): 1 jornada con 3 ayudantes + topógrafo; sondeo de fibra (20–21/11): "
                   "2 jornadas con 4 ayudantes. El APU (1.5 jornadas de cuadrilla de 2 ayudantes + 4 h de retro) queda "
                   "dentro de lo observado; se conserva."),
    "EXT PRE-05": ("Corte de losa en zapatas Ejes 6, 7 y 4 (21/10–18/11): 1 jornada por zapata con 2 a 3 ayudantes, sin "
                   "metros reportados. No hay cantidad para recalcular el rendimiento; se conserva el del APU."),
    "EXT TER-01": ("Abatimiento en zapata Eje 8 (12–14/11) se paga aparte con EXT OBR-02 cuando sea excavación estructural; "
                   "en zanjas de tubería se conserva el bombeo de 0.111 h/m³ del APU."),
}


# --------------------------------------------------------------------------
# NÚMEROS A LETRA
# --------------------------------------------------------------------------
_U = ["", "UN", "DOS", "TRES", "CUATRO", "CINCO", "SEIS", "SIETE", "OCHO", "NUEVE", "DIEZ", "ONCE", "DOCE", "TRECE",
      "CATORCE", "QUINCE", "DIECISEIS", "DIECISIETE", "DIECIOCHO", "DIECINUEVE", "VEINTE", "VEINTIUN", "VEINTIDOS",
      "VEINTITRES", "VEINTICUATRO", "VEINTICINCO", "VEINTISEIS", "VEINTISIETE", "VEINTIOCHO", "VEINTINUEVE"]
_D = ["", "", "", "TREINTA", "CUARENTA", "CINCUENTA", "SESENTA", "SETENTA", "OCHENTA", "NOVENTA"]
_C = ["", "CIENTO", "DOSCIENTOS", "TRESCIENTOS", "CUATROCIENTOS", "QUINIENTOS", "SEISCIENTOS", "SETECIENTOS",
      "OCHOCIENTOS", "NOVECIENTOS"]


def _cientos(n: int) -> str:
    if n == 0:
        return ""
    if n == 100:
        return "CIEN"
    c, r = divmod(n, 100)
    partes = [_C[c]] if c else []
    if r < 30:
        partes.append(_U[r])
    else:
        d, u = divmod(r, 10)
        partes.append(_D[d] + (f" Y {_U[u]}" if u else ""))
    return " ".join(p for p in partes if p)


def letra(x: float) -> str:
    x = round(x + 1e-9, 2)
    entero, cent = int(x), int(round((x - int(x)) * 100))
    mill, resto = divmod(entero, 1_000_000)
    miles, unidades = divmod(resto, 1000)
    partes = []
    if mill:
        partes.append("UN MILLON" if mill == 1 else f"{_cientos(mill)} MILLONES")
    if miles:
        partes.append("MIL" if miles == 1 else f"{_cientos(miles)} MIL")
    if unidades:
        partes.append(_cientos(unidades))
    texto = " ".join(partes) or "CERO"
    de = " DE" if mill and not miles and not unidades else ""
    return f"(* {texto}{de} PESOS {cent:02d}/100 M.N. *)"


# --------------------------------------------------------------------------
# DATOS
# --------------------------------------------------------------------------
def leer_libro_ext(ruta: Path) -> tuple[list[dict], dict, dict]:
    """Extraordinarios ya definidos (hoja 'APU Extraordinarios'), insumos nuevos y descripciones/cantidades."""
    wb = openpyxl.load_workbook(ruta)
    ws = wb["APU Extraordinarios"]
    exts, actual = [], None
    for r in ws.iter_rows(values_only=True):
        a = r[0]
        if isinstance(a, str) and a.startswith("EXT "):
            actual = {"clave": a, "corta": r[1], "unidad": r[2], "renglones": []}
            exts.append(actual)
        elif actual and isinstance(a, str) and r[4] is not None and a not in ("Código",) and not a.startswith(("Costo", "  de", "Compon", "ISN", "PRECIO")):
            actual["renglones"].append((a, float(r[4])))
    wbv = openpyxl.load_workbook(ruta, data_only=True)
    nuevos = {}
    for r in wbv["Insumos"].iter_rows(min_row=4, values_only=True):
        if r[0] and str(r[0]).startswith("N-"):
            nuevos[r[0]] = (r[1], r[2], float(r[3]), r[4])
    cat = {}
    for hoja, col in (("Cat Garzas", "garzas"), ("Cat Barrio V DS24", "bv")):
        for r in wbv[hoja].iter_rows(min_row=4, values_only=True):
            if not r[8] or r[6] != "EXTRAORDINARIO":
                continue
            clave = "EXT " + r[8]
            d = cat.setdefault(clave, {"descripcion": r[3], "garzas": 0.0, "bv": 0.0, "partida": r[9]})
            if len(str(r[3])) > len(str(d["descripcion"])):
                d["descripcion"] = r[3]
            d[col] += float(r[5] or 0)
    return exts, nuevos, cat


class Base:
    """Precios, datos y factor de ISN de cualquier código (insumo, básico, cuadrilla, nuevo o P.U. de contrato)."""

    def __init__(self, concurso: dict, nuevos: dict):
        self.c = concurso
        self.nuevos = {**nuevos, **NUEVOS_OBRA}
        isn = concurso["isn"]
        self.k_mo = isn["MO"]
        self.k_eq_prom = sum(v for k, v in isn.items() if k.startswith("EQ-") and v > 0) / max(
            1, sum(1 for k, v in isn.items() if k.startswith("EQ-") and v > 0))

    def info(self, cod: str) -> dict:
        ins, bas, mat = self.c["insumos"], self.c["basicos"], self.c["matrices"]
        if cod in ins:
            i = ins[cod]
            return {"desc": i["descripcion"], "unidad": i["unidad"], "precio": i["precio"], "tipo": i["tipo"],
                    "origen": "Doc. 15 (insumo del concurso)", "k": self._k(cod, i["tipo"])}
        if cod in bas:
            b = bas[cod]
            tipo = "MO" if cod.startswith("MOCU") else "BAS"
            k = nc.base_isn(b["renglones"], bas, self.c["isn"]) / b["cd"] if b["cd"] else 0
            return {"desc": b["descripcion"], "unidad": b["unidad"], "precio": self._precio_basico(b), "tipo": tipo,
                    "origen": "Doc. 14c (cuadrilla del concurso)" if tipo == "MO" else "Doc. 14c (básico del concurso)",
                    "k": k, "basico": b}
        if cod.startswith("PU-"):
            m = mat[int(cod[3:])]
            return {"desc": f"P.U. DE CONTRATO No. {m['no']}: {m['descripcion'][:90]}", "unidad": m["unidad"], "precio": m["cd"],
                    "tipo": "AUX", "origen": f"Doc. 14a matriz {m['no']} (costo directo)",
                    "k": (m["base_isn"] or 0) / m["cd"] if m["cd"] else 0}
        if cod in self.nuevos:
            d, u, p, t = self.nuevos[cod]
            t = {"BAS": "MAT"}.get(t, t)
            return {"desc": str(d).upper(), "unidad": u, "precio": p, "tipo": t, "origen": "NUEVO — requiere 3 cotizaciones",
                    "k": self.k_mo if t == "MO" else self.k_eq_prom if t == "EQ" else 0.0, "nuevo": True}
        raise KeyError(f"Código sin precio: {cod}")

    def _precio_basico(self, b: dict) -> float:
        """Como en la hoja: suma de los componentes con importe redondeado (precio de la hoja Insumos)."""
        total = 0.0
        for r in b["renglones"]:
            precio = r["precio"]
            if not r["codigo"].startswith("%"):
                try:
                    precio = self.info(r["codigo"])["precio"]
                except KeyError:
                    pass
            total += r2(precio / r["cantidad"]) if r["op"] == "/" else r2(precio * r["cantidad"])
        return r2(total)

    def _k(self, cod, tipo):
        if cod.startswith("%"):
            return 0.0
        if tipo == "MO":
            return self.k_mo
        if tipo == "EQ":
            return self.c["isn"].get(cod, self.k_eq_prom)
        return 0.0


# --------------------------------------------------------------------------
# CÁLCULO
# --------------------------------------------------------------------------
SECC_ORDEN = [("MAT", "MATERIALES"), ("MO", "MANO DE OBRA"), ("EQ", "EQUIPO Y HERRAMIENTA"), ("BAS", "BASICOS"),
              ("AUX", "AUXILIARES (P.U. DE CONTRATO A COSTO DIRECTO)")]


def r2(x: float) -> float:
    """Redondeo a centavos como Excel (mitad hacia arriba), no el de Python."""
    return math.floor(abs(x) * 100 + 0.5 + 1e-9) / 100 * (1 if x >= 0 else -1)


def _importe(l: dict) -> float:
    """Importe redondeado a centavos como NEODATA; los rendimientos (<1) se dividen."""
    if l["tipo"] in ("MO", "EQ") and not l["cod"].startswith("%") and 0 < l["cant"] < 1:
        return r2(l["precio"] / round(1 / l["cant"], 6))
    return r2(l["precio"] * l["cant"])


def calcular(ext: dict, base: Base) -> dict:
    lineas = [{"cod": cod, "cant": cant, **base.info(cod)} for cod, cant in ext["renglones"]]
    for l in lineas:
        if not l["cod"].startswith("%MO"):
            l["importe"] = _importe(l)
    mo = sum(l["importe"] for l in lineas if l["tipo"] == "MO" and "importe" in l)
    for l in lineas:
        if l["cod"].startswith("%MO"):
            l["precio"], l["tipo"] = mo, "EQ"
            l["importe"] = r2(mo * l["cant"])
    cd = sum(l["importe"] for l in lineas)
    base_isn = sum(l["importe"] * l["k"] for l in lineas)
    oc, campo = cd * CARGOS["oc"], cd * CARGOS["campo"]
    d = cd + oc + campo
    f = d + d * CARGOS["fin"]
    h = f + f * CARGOS["util"]
    i_ = h / (1 - CARGOS["sfp"]) - h
    j = r2(base_isn * CARGOS["isn"])
    pu = r2(r2(h) + r2(i_) + j)
    return {"lineas": lineas, "cd": cd, "base_isn": base_isn, "pu": pu}


# --------------------------------------------------------------------------
# EXCEL
# --------------------------------------------------------------------------
def F(**kw):
    return Font(name=FUENTE, size=kw.pop("size", 8), **kw)


LINEA = Side(style="thin", color="000000")


def main() -> None:
    for flujo in (sys.stdout, sys.stderr):
        try:
            flujo.reconfigure(encoding="utf-8", errors="replace")
        except Exception:
            pass
    concurso = nc.cargar_concurso(CARPETA)
    libro = next(CARPETA.glob("*PU_Contrato_y_Extraordinarios*.xlsx"))
    exts_libro, nuevos, cat = leer_libro_ext(libro)
    base = Base(concurso, nuevos)
    isn = concurso["isn"]
    print(f"Concurso: {len(concurso['insumos'])} insumos, {len(concurso['basicos'])} básicos, "
          f"{len(concurso['matrices'])} matrices. ISN: base = {isn['MO']:.4f}×salarios + factor por equipo "
          f"(error mediano {isn['_error_mediana']:.2%}).")

    # Definiciones finales
    exts = []
    for e in exts_libro:
        d = cat.get(e["clave"], {})
        ext = {"clave": e["clave"], "unidad": e["unidad"], "descripcion": d.get("descripcion") or e["corta"],
               "partida": d.get("partida", ""), "cant_garzas": d.get("garzas", 0), "cant_bv": d.get("bv", 0),
               "renglones": e["renglones"], "origen_rend": "APU previo (sin observación en bitácora)",
               "rendimiento": "", "evidencia": ""}
        if e["clave"] in AJUSTES:
            a = AJUSTES[e["clave"]]
            ext["renglones"] = a["renglones"]
            ext["origen_rend"] = "AJUSTADO con bitácora"
            ext["rendimiento"] = a["rendimiento"]
            ext["evidencia"] = a["evidencia"]
            ext["antes"] = a["antes"]
        elif e["clave"] in CONFIRMADOS:
            ext["origen_rend"] = "CONFIRMADO con bitácora"
            ext["evidencia"] = CONFIRMADOS[e["clave"]]
        exts.append(ext)
    for e in EXT_OBRA:
        exts.append({**e, "cant_bv": 0, "origen_rend": "OBSERVADO en bitácora (extraordinario nuevo)"})

    calcs = {e["clave"]: calcular(e, base) for e in exts}

    # ---------------- Libro ----------------
    wb = Workbook()
    wb.remove(wb.active)
    cab = {"empresa": ("GRUPO CONSTRUCTOR TRANSPORTIEREN, S.A. DE C.V. EN ASOCIACIÓN CON "
                       "OPERADORA Y ADMINISTRACIÓN TÉCNICA, S.A. DE C.V."),
           "cliente": "SECRETARÍA DE INFRAESTRUCTURA, COMUNICACIONES Y TRANSPORTES — DIRECCIÓN GENERAL DE CARRETERAS",
           "concurso": "LO-09-210-009000999-T-873-2026", "fecha": f"{date.today():%d/%m/%Y}",
           "obra": ("CONSTRUCCIÓN DEL PSV COMPLEMENTO BARRIO V (2DA ETAPA), QUE CONSISTE EN LA CONSTRUCCIÓN DE UNA ESTRUCTURA "
                    "TIPO PSV EN LA INTERSECCIÓN DE LA AV. PASEO DE LAS GARZAS CON LA AV. ELÍAS ZAMORA VERDUZCO ASÍ COMO LA "
                    "CONSTRUCCIÓN DEL RETORNO DEL PSV PASEO DE LAS GAVIOTAS UBICADO EN EL KM 11+225 DEL LIBRAMIENTO MANZANILLO "
                    "(CONTRATO 2026-06-CF-A-035-W-00-2026)."),
           "lugar": "MANZANILLO, COLIMA", "inicio": "30/07/2026", "fin": "30/12/2026",
           "duracion": "154 días naturales", "documento": "EXTRAORDINARIOS"}
    fmt = {"$": '"$"#,##0.00'}
    for e in exts:
        e["cantidad"] = (e.get("cant_garzas") or 0) + (e.get("cant_bv") or 0)

    # Partidas (A1, A2, …) en el orden en que aparecen
    orden_partidas = []
    for e in exts:
        e["partida"] = (e.get("partida") or "OTROS").upper()
        if e["partida"] not in orden_partidas:
            orden_partidas.append(e["partida"])
    cod_partida = {p: f"A{k}" for k, p in enumerate(orden_partidas, 1)}

    # Básicos y cuadrillas que intervienen (con sus sub-básicos)
    bas = concurso["basicos"]
    usados_bas = []

    def agregar_basico(cod):
        if cod in bas and cod not in usados_bas:
            usados_bas.append(cod)
            for r in bas[cod]["renglones"]:
                agregar_basico(r["codigo"])
    for e in exts:
        for l in calcs[e["clave"]]["lineas"]:
            agregar_basico(l["cod"])
    usados_bas.sort(key=lambda c: (not c.startswith("MOCU"), c))

    # Insumos: todo lo que aparece en análisis y básicos
    usados = {}
    for e in exts:
        for l in calcs[e["clave"]]["lineas"]:
            if not l["cod"].startswith("%"):
                usados[l["cod"]] = l
    for cod in usados_bas:
        usados.setdefault(cod, {"cod": cod, **base.info(cod)})
        for r in bas[cod]["renglones"]:
            c = r["codigo"]
            if c.startswith("%") or c in usados:
                continue
            try:
                usados[c] = {"cod": c, **base.info(c)}
            except KeyError:
                usados[c] = {"cod": c, "desc": r["descripcion"], "unidad": r["unidad"], "precio": r["precio"],
                             "tipo": "MAT", "origen": "Doc. 14c (componente)", "k": 0}
    codigos_ins = sorted(usados)
    n_ins = len(codigos_ins) + 1
    fila_ins = {c: k for k, c in enumerate(codigos_ins, 2)}

    def ref_ins(cod):
        return f"Insumos!$D${fila_ins[cod]}" if cod in fila_ins else "0"

    # Parámetros
    wp = wb.create_sheet("Parametros")
    wp["A1"] = "CARGOS DEL CONTRATO (Doc. 14a del concurso) — editar solo en esta hoja"
    wp["A1"].font = F(size=11, bold=True, color=AZUL)
    filas_p = [("Indirecto oficina central", CARGOS["oc"]), ("Indirecto de campo", CARGOS["campo"]),
               ("Financiamiento", CARGOS["fin"]), ("Utilidad", CARGOS["util"]), ("SFP 5 al millar", CARGOS["sfp"]),
               ("ISN (impuesto sobre nómina)", CARGOS["isn"])]
    for k, (et, v) in enumerate(filas_p, 5):
        wp.cell(row=k, column=2, value=et).font = F(size=9)
        c = wp.cell(row=k, column=3, value=v)
        c.number_format = "0.0000%"
        c.font = F(size=9, color="0000FF")
    wp["B12"] = "FSC = (1+OC+Campo)(1+Fin)(1+Util)/(1−SFP)"
    wp["C12"] = "=(1+C5+C6)*(1+C7)*(1+C8)/(1-C9)"
    wp["C12"].number_format = "0.000000"
    wp["B14"] = "Base del ISN"
    wp["B15"] = (f"Como en NEODATA: 3% sobre la parte de salarios. Calibrado con las {len(concurso['matrices'])} matrices del "
                 f"concurso: {isn['MO']:.4f} × importe de mano de obra + un factor por equipo (columna J oculta de cada "
                 f"análisis). Error mediano contra el concurso: {isn['_error_mediana']:.2%}.")
    for r in wp.iter_rows(min_row=12, max_row=16):
        for c in r:
            c.font = F(size=9)
            c.alignment = Alignment(wrap_text=True, vertical="top")
    wp.column_dimensions["B"].width = 110
    wp.column_dimensions["C"].width = 14

    # Básicos (formato NEODATA)
    wbas = wb.create_sheet("Basicos")
    for col, w in zip("ABCDEFGHIJ", (11, 44, 7, 11, 4, 10, 12, 9, 2, 7)):
        wbas.column_dimensions[col].width = w
    fmt_neo._impresion(wbas)
    fila, cd_bas = 1, {}
    for cod in usados_bas:
        fila, cd_bas[cod] = fmt_neo.basico(wbas, fila, cab, cod, bas[cod], ref_ins)

    # Insumos
    wi = wb.create_sheet("Insumos")
    wi.append(["Código", "Descripción", "Unidad", "Precio", "Tipo", "Origen", "Factor ISN"])
    for cod in codigos_ins:
        l = usados[cod]
        precio = f"=Basicos!$G${cd_bas[cod]}" if cod in cd_bas else l["precio"]
        wi.append([cod, l["desc"], l["unidad"], precio, l["tipo"], l["origen"], round(l["k"], 6)])
        for c in wi[wi.max_row]:
            c.font = F(size=9)
        wi.cell(row=wi.max_row, column=4).number_format = fmt["$"]
        if l.get("nuevo"):
            for c in wi[wi.max_row]:
                c.fill = PatternFill("solid", fgColor=NARANJA)
            wi.cell(row=wi.max_row, column=4).font = F(size=9, color="0000FF", bold=True)
    for c in wi[1]:
        c.font = F(size=9, bold=True, color="FFFFFF")
        c.fill = PatternFill("solid", fgColor=AZUL)
    for col, w in zip("ABCDEFG", (14, 90, 9, 14, 7, 34, 10)):
        wi.column_dimensions[col].width = w
    wi.freeze_panes = "A2"
    wi.auto_filter.ref = wi.dimensions

    # Análisis de precios unitarios (formato NEODATA)
    wa = wb.create_sheet("Analisis PU")
    for col, w in zip("ABCDEFGHIJ", (11, 44, 7, 11, 4, 10, 12, 9, 2, 7)):
        wa.column_dimensions[col].width = w
    wa.column_dimensions["J"].hidden = True
    wbas.column_dimensions["J"].hidden = True
    fmt_neo._impresion(wa)
    fila, celdas_pu = 1, {}
    for k, e in enumerate(exts, 1):
        fila, fila_pu = fmt_neo.apu(wa, fila, cab, e, calcs[e["clave"]], ref_ins, cod_partida[e["partida"]], k * 10,
                                    letra(calcs[e["clave"]]["pu"]))
        celdas_pu[e["clave"]] = f"'Analisis PU'!$G${fila_pu}"

    # Presupuestos por catálogo (formato NEODATA)
    totales = {}
    for nombre, campo in (("Presupuesto Garzas", "cant_garzas"), ("Presupuesto Barrio V DS24", "cant_bv")):
        partidas = []
        for p in orden_partidas:
            lista = [{**e, "cantidad": e.get(campo) or 0} for e in exts if e["partida"] == p and (e.get(campo) or 0) > 0]
            if lista:
                partidas.append((cod_partida[p], p, lista))
        if partidas:
            _, totales[nombre] = fmt_neo.hoja_presupuesto(wb, nombre, cab, partidas, celdas_pu)

    # Resumen con origen de rendimientos
    wc = wb.create_sheet("Resumen EXT")
    wc["A1"] = "RESUMEN DE CONCEPTOS EXTRAORDINARIOS — origen del rendimiento y evidencia en bitácora"
    wc["A1"].font = F(size=12, bold=True, color=AZUL)
    wc["A2"] = ("Precios sin IVA. Renglones naranja en los análisis = insumo NUEVO: requiere 3 cotizaciones "
                "(cambiar el precio en la hoja Insumos y todo se recalcula).")
    wc["A2"].font = F(size=9, italic=True)
    enc = ["Clave", "Descripción", "Unidad", "Cant. Garzas", "Cant. Barrio V DS24", "Cantidad total", "P.U.", "Importe",
           "Origen del rendimiento", "Rendimiento", "Evidencia en bitácora", "Insumos nuevos"]
    wc.append([])
    wc.append(enc)
    for c in wc[4]:
        c.font = F(size=9, bold=True, color="FFFFFF")
        c.fill = PatternFill("solid", fgColor=AZUL)
        c.alignment = Alignment(wrap_text=True, horizontal="center", vertical="center")
    for e in exts:
        r = wc.max_row + 1
        nuevos_n = sum(1 for l in calcs[e["clave"]]["lineas"] if l.get("nuevo"))
        wc.append([e["clave"], e["descripcion"], e["unidad"], e.get("cant_garzas") or 0, e.get("cant_bv") or 0,
                   f"=D{r}+E{r}", f"={celdas_pu[e['clave']]}", f"=ROUND(F{r}*G{r},2)", e["origen_rend"],
                   e.get("rendimiento", ""), e.get("evidencia", ""), nuevos_n or ""])
        for c in wc[r]:
            c.font = F(size=8)
            c.alignment = Alignment(wrap_text=True, vertical="top")
        wc.cell(row=r, column=7).number_format = fmt["$"]
        wc.cell(row=r, column=8).number_format = fmt["$"]
        if e["origen_rend"].startswith(("AJUSTADO", "OBSERVADO", "CONFIRMADO")):
            wc.cell(row=r, column=9).fill = PatternFill("solid", fgColor="E2EFDA")
    ult = wc.max_row
    wc.append(["", "SUBTOTAL", "", "", "", "", "", f"=SUM(H5:H{ult})"])
    wc.append(["", "IVA 16%", "", "", "", "", "", f"=ROUND(H{ult + 1}*0.16,2)"])
    wc.append(["", "TOTAL", "", "", "", "", "", f"=H{ult + 1}+H{ult + 2}"])
    for r in range(ult + 1, ult + 4):
        wc.cell(row=r, column=2).font = F(size=9, bold=True)
        c = wc.cell(row=r, column=8)
        c.font = F(size=9, bold=True)
        c.number_format = fmt["$"]
    for col, w in zip("ABCDEFGHIJKL", (11, 70, 7, 9, 9, 9, 12, 14, 20, 28, 60, 8)):
        wc.column_dimensions[col].width = w
    wc.freeze_panes = "C5"
    wc.auto_filter.ref = f"A4:L{ult}"

    # Rendimientos (bitácora)
    wr = wb.create_sheet("Rendimientos bitacora")
    wr["A1"] = "RENDIMIENTOS DETERMINADOS CON LAS ACTIVIDADES DIARIAS (reportes de WhatsApp)"
    wr["A1"].font = F(size=12, bold=True, color=AZUL)
    wr.append([])
    wr.append(["Clave", "Concepto", "Situación", "Rendimiento anterior", "Rendimiento adoptado", "Evidencia (fechas, cuadrilla, equipo)",
               "Nota sobre la cantidad"])
    for c in wr[3]:
        c.font = F(size=9, bold=True, color="FFFFFF")
        c.fill = PatternFill("solid", fgColor=AZUL)
        c.alignment = Alignment(wrap_text=True)
    for e in exts:
        if e["origen_rend"].startswith("APU previo"):
            continue
        wr.append([e["clave"], e["descripcion"][:160], e["origen_rend"], e.get("antes", ""), e.get("rendimiento", ""),
                   e.get("evidencia", ""), e.get("cantidad_nota", "")])
        for c in wr[wr.max_row]:
            c.font = F(size=8)
            c.alignment = Alignment(wrap_text=True, vertical="top")
    wr.append([])
    wr.append(["", "Comparativo de rendimientos del CONCURSO contra lo observado en obra (conceptos de catálogo)"])
    wr.cell(row=wr.max_row, column=2).font = F(size=10, bold=True, color=AZUL)
    wr.append(["No.", "Concepto", "Rendimiento del concurso", "Observado en obra (bitácora)", "Diferencia", "Comentario"])
    for c in wr[wr.max_row]:
        c.font = F(size=9, bold=True, color="FFFFFF")
        c.fill = PatternFill("solid", fgColor=AZUL)
    mt = concurso["matrices"]
    perf = mt[41]["renglones"][0]
    vol = perf["cantidad"]
    h_m3 = next(c["cantidad"] for c in perf["componentes"] if c["codigo"] == "EQ-PERFO")
    ml_jor_conc = 8 / (h_m3 * vol)
    filas_cmp = [
        (41, "Perforación para pilas (ml)", f"{ml_jor_conc:.1f} ml por jornada de 8 h (perforadora {h_m3:.4f} h/m³ × {vol:.3f} m³/ml)",
         "11.6 ml por jornada de frente (418.2 ml en 36 jornadas, 29/09–21/11)", f"{11.6 / ml_jor_conc - 1:+.0%}",
         "Caídos y reperforaciones bajan el rendimiento; perforadoras inactivas por días."),
        (44, "Concreto en pilas (m³)", "25 m³ por jornada (cuadrilla 034 0.04 jor/m³; grúa 80 t 0.04 h/m³)",
         "15.0 m³ por jornada de frente (571 m³ en 38 jornadas)", f"{15.0 / 25 - 1:+.0%}",
         "El colado depende de terminar la perforación; la grúa de orugas estuvo inactiva 13 días."),
    ]
    for f_ in filas_cmp:
        wr.append(list(f_))
        for c in wr[wr.max_row]:
            c.font = F(size=8)
            c.alignment = Alignment(wrap_text=True, vertical="top")
    for col, w in zip("ABCDEFG", (11, 60, 24, 34, 34, 70, 40)):
        wr.column_dimensions[col].width = w

    orden = ["Presupuesto Garzas", "Presupuesto Barrio V DS24", "Analisis PU", "Basicos", "Insumos", "Parametros",
             "Rendimientos bitacora", "Resumen EXT"]
    wb._sheets = [wb[n] for n in orden if n in wb.sheetnames]
    SALIDA.parent.mkdir(parents=True, exist_ok=True)
    wb.save(SALIDA)
    total = sum(calcs[e["clave"]]["pu"] * ((e.get("cant_garzas") or 0) + (e.get("cant_bv") or 0)) for e in exts)
    print(f"✅ {len(exts)} análisis → {SALIDA}  (importe estimado sin IVA ${total:,.2f})")
    for e in exts:
        if not e["origen_rend"].startswith("APU previo"):
            print(f"   {e['clave']}: P.U. ${calcs[e['clave']]['pu']:,.2f} / {e['unidad']} — {e['origen_rend']}")


if __name__ == "__main__":
    main()
