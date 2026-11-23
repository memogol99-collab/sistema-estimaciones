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
from openpyxl.worksheet.pagebreak import Break

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


def _cabecera(ws, fila, cab, ancho_col="H"):
    for txt, tam, neg in ((cab["empresa1"], 10, True), (cab["empresa2"], 10, True), (cab["cliente1"], 8, True),
                          (cab["cliente2"], 8, True)):
        ws.merge_cells(f"A{fila}:H{fila}")
        c = ws.cell(row=fila, column=1, value=txt)
        c.font = F(size=tam, bold=neg)
        c.alignment = Alignment(horizontal="center")
        fila += 1
    fila += 1
    ws.cell(row=fila, column=1, value=f"Concurso No. {cab['concurso']}").font = F(bold=True)
    ws.cell(row=fila, column=7, value="Fecha:").font = F(bold=True)
    ws.cell(row=fila, column=8, value=cab["fecha"]).font = F()
    fila += 1
    ws.cell(row=fila, column=1, value="Obra:").font = F(bold=True)
    ws.merge_cells(start_row=fila, start_column=2, end_row=fila + 3, end_column=5)
    c = ws.cell(row=fila, column=2, value=cab["obra"])
    c.font = F(size=7)
    c.alignment = Alignment(wrap_text=True, vertical="top")
    for k, (et, v) in enumerate((("Inicio Obra:", cab["inicio"]), ("Fin Obra:", cab["fin"]), ("Duración:", cab["duracion"]),
                                 ("DOCUMENTO", "EXT"))):
        ws.cell(row=fila + k, column=7, value=et).font = F(bold=True)
        ws.cell(row=fila + k, column=8, value=v).font = F()
    fila += 5
    ws.merge_cells(f"A{fila}:H{fila}")
    c = ws.cell(row=fila, column=1, value="ANALISIS DE PRECIOS UNITARIOS EXTRAORDINARIOS")
    c.font = F(size=10, bold=True)
    c.alignment = Alignment(horizontal="center")
    fila += 1
    for j, t in enumerate(["Código", "Concepto", "Unidad", "P. Unitario", "Op.", "Cantidad", "Importe", "%"], 1):
        c = ws.cell(row=fila, column=j, value=t)
        c.font = F(bold=True)
        c.border = Border(top=LINEA, bottom=LINEA)
        c.alignment = Alignment(horizontal="center")
    return fila + 1


def escribir_apu(ws, fila, ext, calc, cab, ref_ins, fmt):
    inicio = fila
    fila = _cabecera(ws, fila, cab)
    # Análisis: clave, unidad, cantidad, importe
    cant_total = (ext.get("cant_garzas") or 0) + (ext.get("cant_bv") or 0)
    ws.cell(row=fila, column=1, value="Análisis:").font = F(bold=True)
    ws.cell(row=fila, column=2, value=ext["clave"]).font = F(bold=True)
    ws.cell(row=fila, column=5, value=ext["unidad"]).font = F(bold=True)
    c = ws.cell(row=fila, column=6, value=cant_total)
    c.number_format = "#,##0.0000"
    c.font = F(bold=True)
    fila_analisis = fila
    fila += 1
    ws.merge_cells(start_row=fila, start_column=1, end_row=fila, end_column=8)
    c = ws.cell(row=fila, column=1, value=ext["descripcion"])
    c.font = F()
    c.alignment = Alignment(wrap_text=True, vertical="top")
    ws.row_dimensions[fila].height = 11 * max(1, math.ceil(len(ext["descripcion"]) / 150))
    fila += 1

    subtot_celdas, k_rango = [], []
    sub_mo = None
    lineas_pct = []
    for secc, titulo in SECC_ORDEN:
        ls = [l for l in calc["lineas"] if l["tipo"] == secc]
        if not ls:
            continue
        ws.cell(row=fila, column=1, value=titulo).font = F(bold=True)
        fila += 1
        primera = fila
        for l in ls:
            es_pct = l["cod"].startswith("%MO")
            if l.get("basico") and secc == "BAS":
                # Básico expandido como en el concurso: encabezado, componentes, Importe y Volumen
                b = l["basico"]
                ws.cell(row=fila, column=1, value=l["cod"]).font = F(bold=True)
                ws.cell(row=fila, column=2, value=b["descripcion"]).font = F(bold=True)
                ws.cell(row=fila, column=3, value=b["unidad"]).font = F()
                fila += 1
                p0 = fila
                for r in b["renglones"]:
                    ws.cell(row=fila, column=1, value=r["codigo"]).font = F()
                    ws.cell(row=fila, column=2, value=r["descripcion"]).font = F()
                    ws.cell(row=fila, column=3, value=r["unidad"]).font = F()
                    pc = ws.cell(row=fila, column=4, value=f'=IFERROR({ref_ins(r["codigo"])},{r["precio"]})'
                                 if not r["codigo"].startswith("%") else r["precio"])
                    pc.number_format = fmt["$"]
                    pc.font = F()
                    ws.cell(row=fila, column=5, value=r["op"]).font = F()
                    cc = ws.cell(row=fila, column=6, value=r["cantidad"])
                    cc.number_format = "0.000000"
                    cc.font = F()
                    op = "/" if r["op"] == "/" else "*"
                    ic = ws.cell(row=fila, column=7, value=f"=ROUND(D{fila}{op}F{fila},2)")
                    ic.number_format = fmt["$"]
                    ic.font = F()
                    fila += 1
                ws.cell(row=fila, column=2, value="Importe:").font = F(italic=True)
                c = ws.cell(row=fila, column=7, value=f"=SUM(G{p0}:G{fila - 1})")
                c.number_format = fmt["$"]
                c.font = F(italic=True)
                fila_imp = fila
                fila += 1
                ws.cell(row=fila, column=2, value="Volumen:").font = F(italic=True)
                c = ws.cell(row=fila, column=6, value=l["cant"])
                c.number_format = "0.000000"
                c.font = F()
                c = ws.cell(row=fila, column=7, value=f"=ROUND(G{fila_imp}*F{fila},2)")
                c.number_format = fmt["$"]
                c.font = F()
                ws.cell(row=fila, column=10, value=l["k"])
                k_rango.append(fila)
                lineas_pct.append(fila)
                fila += 1
                continue
            ws.cell(row=fila, column=1, value=l["cod"]).font = F()
            ws.cell(row=fila, column=2, value=l["desc"]).font = F()
            ws.cell(row=fila, column=3, value=l["unidad"]).font = F()
            if es_pct:
                pc = ws.cell(row=fila, column=4, value=f"=G{sub_mo}" if sub_mo else 0)
            else:
                pc = ws.cell(row=fila, column=4, value=f"={ref_ins(l['cod'])}")
            pc.number_format = fmt["$"]
            pc.font = F()
            # Como NEODATA: rendimientos (cantidad < 1 en mano de obra y equipo) se expresan con "/"
            usar_div = l["tipo"] in ("MO", "EQ") and not es_pct and 0 < l["cant"] < 1
            oc = ws.cell(row=fila, column=5, value="/" if usar_div else "*")
            oc.font = F()
            oc.alignment = Alignment(horizontal="center")
            cc = ws.cell(row=fila, column=6, value=round(1 / l["cant"], 6) if usar_div else l["cant"])
            cc.number_format = "0.000000"
            cc.font = F()
            ic = ws.cell(row=fila, column=7, value=f"=ROUND(D{fila}/F{fila},2)" if usar_div else f"=ROUND(D{fila}*F{fila},2)")
            ic.number_format = fmt["$"]
            ic.font = F()
            if l.get("nuevo"):
                for j in range(1, 9):
                    ws.cell(row=fila, column=j).fill = PatternFill("solid", fgColor=NARANJA)
            ws.cell(row=fila, column=10, value=l["k"])
            k_rango.append(fila)
            lineas_pct.append(fila)
            fila += 1
        fila += 1
        ws.cell(row=fila, column=1, value="SUBTOTAL:").font = F(bold=True)
        ws.cell(row=fila, column=2, value=titulo).font = F(bold=True)
        celdas = [f"G{r}" for r in k_rango if primera <= r < fila]
        c = ws.cell(row=fila, column=7, value=f"=SUM({','.join(celdas)})" if celdas else 0)
        c.number_format = fmt["$"]
        c.font = F(bold=True)
        c.border = Border(top=LINEA)
        if secc == "MO":
            sub_mo = fila
        subtot_celdas.append((fila, secc))
        fila += 1

    # (A) … (K) como el concurso
    cd_fila = fila
    filas_tot = {}

    def tot(etq, formula, pct=None, negrita=False, clave=None):
        nonlocal fila
        ws.cell(row=fila, column=2, value=etq).font = F(bold=negrita)
        if pct is not None:
            c = ws.cell(row=fila, column=6, value=pct)
            c.font = F()
            c.alignment = Alignment(horizontal="right")
        c = ws.cell(row=fila, column=7, value=formula)
        c.number_format = fmt["$"]
        c.font = F(bold=negrita)
        if clave:
            filas_tot[clave] = fila
        fila += 1

    sub_refs = ",".join(f"G{r}" for r, _ in subtot_celdas)
    tot("(A) COSTO DIRECTO", f"=SUM({sub_refs})", None, True, "A")
    ws.cell(row=filas_tot["A"], column=8, value=1).number_format = "0.00%"
    tot("(B) INDIRECTO OFICINA CENTRAL", f"=G{filas_tot['A']}*Parametros!$C$5", "=Parametros!$C$5", clave="B")
    tot("(C) INDIRECTO DE CAMPO", f"=G{filas_tot['A']}*Parametros!$C$6", "=Parametros!$C$6", clave="C")
    tot("INDIRECTO TOTAL", f"=G{filas_tot['B']}+G{filas_tot['C']}", "=Parametros!$C$5+Parametros!$C$6", clave="IT")
    tot("(D) SUBTOTAL (A+B+C)", f"=G{filas_tot['A']}+G{filas_tot['IT']}", clave="D")
    tot("(E) FINANCIAMIENTO", f"=G{filas_tot['D']}*Parametros!$C$7", "=Parametros!$C$7", clave="E")
    tot("(F) SUBTOTAL (D+E)", f"=G{filas_tot['D']}+G{filas_tot['E']}", clave="F")
    tot("(G) UTILIDAD", f"=G{filas_tot['F']}*Parametros!$C$8", "=Parametros!$C$8", clave="G")
    tot("(H) SUBTOTAL (F+G)", f"=G{filas_tot['F']}+G{filas_tot['G']}", clave="H")
    ws.cell(row=fila, column=2, value="CARGOS ADICIONALES").font = F(bold=True)
    fila += 1
    tot("(I) SFP 5 al millar = [ H / (1-0.005) - H ]", f"=G{filas_tot['H']}/(1-Parametros!$C$9)-G{filas_tot['H']}",
        "0.5025%", clave="I")
    rk = ",".join(f"G{r}*J{r}" for r in k_rango)
    base_formula = f"({'+'.join(f'G{r}*J{r}' for r in k_rango)})" if k_rango else "0"
    ws.cell(row=fila, column=2, value="(J) ISN = IMPUESTO SOBRE NOMINA").font = F()
    c = ws.cell(row=fila, column=6, value=f'="3.00% x "&TEXT({base_formula},"#,##0.00")')
    c.font = F()
    c.alignment = Alignment(horizontal="right")
    c = ws.cell(row=fila, column=7, value=f"=ROUND({base_formula}*Parametros!$C$10,2)")
    c.number_format = fmt["$"]
    c.font = F()
    filas_tot["J"] = fila
    fila += 1
    tot("(K) PRECIO UNITARIO (H+I+J)",
        f"=ROUND(ROUND(G{filas_tot['H']},2)+ROUND(G{filas_tot['I']},2)+G{filas_tot['J']},2)", None, True, "K")
    ws.cell(row=fila, column=2, value=letra(calc["pu"])).font = F(bold=True)
    fila += 1
    # % de cada renglón y de los subtotales
    for r in lineas_pct + [s for s, _ in subtot_celdas]:
        c = ws.cell(row=r, column=8, value=f"=IFERROR(G{r}/G${filas_tot['A']},0)")
        c.number_format = "0.00%"
        c.font = F()
    # importe total del concepto en el renglón Análisis
    c = ws.cell(row=fila_analisis, column=7, value=f"=G{filas_tot['K']}*F{fila_analisis}")
    c.number_format = fmt["$"]
    c.font = F(bold=True)
    fila += 2
    ws.cell(row=fila, column=2, value="ELABORÓ: ____________________").font = F()
    ws.cell(row=fila, column=4, value="REVISÓ: ____________________").font = F()
    ws.cell(row=fila, column=7, value="AUTORIZÓ: ________________").font = F()
    fila += 1
    return fila, filas_tot["K"], inicio


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
    m1 = concurso["matrices"][1]
    cab = {"empresa1": "GRUPO CONSTRUCTOR TRANSPORTIEREN, S.A. de C.V. EN ASOCIACIÓN CON OPERADORA Y",
           "empresa2": "ADMINISTRACIÓN TÉCNICA, S.A. DE C.V.",
           "cliente1": "Cliente: SECRETARÍA DE INFRAESTRUCTURA, COMUNICACIONES Y TRANSPORTES",
           "cliente2": "DIRECCIÓN GENERAL DE CARRETERAS", "concurso": "LO-09-210-009000999-T-873-2026",
           "fecha": f"{date.today():%d-%b-%Y}".lower(),
           "obra": ("CONSTRUCCIÓN DEL PSV COMPLEMENTO BARRIO V (2DA ETAPA), QUE CONSISTE EN LA CONSTRUCCIÓN DE UNA ESTRUCTURA "
                    "TIPO PSV EN LA INTERSECCIÓN DE LA AV. PASEO DE LAS GARZAS CON LA AV. ELÍAS ZAMORA VERDUZCO ASÍ COMO LA "
                    "CONSTRUCCIÓN DEL RETORNO DEL PSV PASEO DE LAS GAVIOTAS UBICADO EN EL KM 11+225 DEL LIBRAMIENTO MANZANILLO, "
                    "LOS TRABAJOS INCLUYEN TERRACERÍAS, MUROS MECÁNICAMENTE ESTABILIZADOS, OBRAS DE DRENAJE, ESTRUCTURAS DE "
                    "CONCRETO HIDRÁULICO REFORZADAS Y PRESFORZADAS, ESTRUCTURAS DE CONCRETO HIDRAULICO PREFABRICADAS, "
                    "PAVIMENTACIÓN, SEÑALAMIENTO HORIZONTAL Y VERTICAL, ASÍ COMO LA REUBICACIÓN DE OBRAS INDUCIDAS Y "
                    "RECONSTRUCCIÓN DE CALLES LATERALES EN EL MUNICIPIO DE MANZANILLO, ESTADO DE COLIMA."),
           "inicio": "30-jul-2026", "fin": "30-dic-2026", "duracion": "154 Días Naturales"}
    fmt = {"$": '"$"#,##0.00'}

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
                 f"concurso: {isn['MO']:.4f} × importe de mano de obra + un factor por equipo (columna J de cada análisis). "
                 f"Error mediano contra el concurso: {isn['_error_mediana']:.2%}.")
    wp["B17"] = "Comprobación con el concurso"
    filas_c = 18
    for no in (323, 288, 44, 41):
        m = concurso["matrices"][no]
        wp.cell(row=filas_c, column=2, value=f"Matriz {no}: CD ${m['cd']:,.2f} → P.U. concurso ${m['pu']:,.2f}")
        filas_c += 1
    for r in wp.iter_rows(min_row=14, max_row=filas_c):
        for c in r:
            c.font = F(size=9)
            c.alignment = Alignment(wrap_text=True, vertical="top")
    wp.column_dimensions["B"].width = 110
    wp.column_dimensions["C"].width = 14

    # Insumos
    wi = wb.create_sheet("Insumos")
    wi.append(["Código", "Descripción", "Unidad", "Precio", "Tipo", "Origen", "Factor ISN"])
    usados = {}
    for e in exts:
        for l in calcs[e["clave"]]["lineas"]:
            usados[l["cod"]] = l
            if l.get("basico"):
                for r in l["basico"]["renglones"]:
                    if r["codigo"] not in usados and not r["codigo"].startswith("%"):
                        try:
                            usados[r["codigo"]] = {"cod": r["codigo"], **base.info(r["codigo"])}
                        except KeyError:
                            usados[r["codigo"]] = {"cod": r["codigo"], "desc": r["descripcion"], "unidad": r["unidad"],
                                                   "precio": r["precio"], "tipo": "MAT", "origen": "Doc. 14c (componente)", "k": 0}
    for cod in sorted(usados):
        l = usados[cod]
        if cod.startswith("%"):
            continue
        wi.append([cod, l["desc"], l["unidad"], l["precio"], l["tipo"], l["origen"], round(l["k"], 6)])
        if l.get("nuevo"):
            for c in wi[wi.max_row]:
                c.fill = PatternFill("solid", fgColor=NARANJA)
            wi.cell(row=wi.max_row, column=4).font = F(size=9, color="0000FF")
    for c in wi[1]:
        c.font = F(size=9, bold=True, color="FFFFFF")
        c.fill = PatternFill("solid", fgColor=AZUL)
    for r in wi.iter_rows(min_row=2):
        for c in r:
            if c.font.color is None or c.column != 4:
                c.font = F(size=9)
        r[3].number_format = fmt["$"]
    for col, w in zip("ABCDEFG", (14, 90, 9, 14, 7, 34, 10)):
        wi.column_dimensions[col].width = w
    wi.freeze_panes = "A2"
    wi.auto_filter.ref = wi.dimensions
    n_ins = wi.max_row

    def ref_ins(cod):
        return f'INDEX(Insumos!$D$2:$D${n_ins},MATCH("{cod}",Insumos!$A$2:$A${n_ins},0))'

    # Análisis
    wa = wb.create_sheet("Analisis PU")
    for col, w in zip("ABCDEFGHIJ", (11, 56, 7, 11, 3, 10, 12, 9, 2, 7)):
        wa.column_dimensions[col].width = w
    wa.column_dimensions["J"].hidden = True
    fila = 1
    celdas_pu = {}
    for e in exts:
        fila_fin, fila_k, ini = escribir_apu(wa, fila, e, calcs[e["clave"]], cab, ref_ins, fmt)
        celdas_pu[e["clave"]] = f"'Analisis PU'!G{fila_k}"
        wa.row_breaks.append(Break(id=fila_fin))
        fila = fila_fin + 1
    wa.page_setup.orientation = "portrait"
    wa.page_setup.paperSize = wa.PAPERSIZE_LETTER
    wa.page_setup.fitToWidth = 1
    wa.page_setup.fitToHeight = 0
    wa.sheet_properties.pageSetUpPr.fitToPage = True
    wa.page_margins.left = wa.page_margins.right = 0.4
    wa.oddFooter.center.text = "Página &P de &N"
    wa.oddFooter.center.font = FUENTE

    # Catálogo / resumen
    wc = wb.create_sheet("Catalogo EXT", 0)
    wc["A1"] = "CATÁLOGO DE CONCEPTOS EXTRAORDINARIOS — análisis integrados con insumos, básicos y cargos del concurso"
    wc["A1"].font = F(size=12, bold=True, color=AZUL)
    wc["A2"] = ("Contrato 2026-06-CF-A-035-W-00-2026 (Concurso LO-09-210-009000999-T-873-2026). Precios sin IVA. "
                "Renglones naranja = insumo NUEVO, requiere 3 cotizaciones (cambiar el precio en la hoja Insumos).")
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
    wr = wb.create_sheet("Rendimientos bitacora", 1)
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

    SALIDA.parent.mkdir(parents=True, exist_ok=True)
    wb.save(SALIDA)
    total = sum(calcs[e["clave"]]["pu"] * ((e.get("cant_garzas") or 0) + (e.get("cant_bv") or 0)) for e in exts)
    print(f"✅ {len(exts)} análisis → {SALIDA}  (importe estimado sin IVA ${total:,.2f})")
    for e in exts:
        if not e["origen_rend"].startswith("APU previo"):
            print(f"   {e['clave']}: P.U. ${calcs[e['clave']]['pu']:,.2f} / {e['unidad']} — {e['origen_rend']}")


if __name__ == "__main__":
    main()
