"""
Hojas de Excel con el formato de exportación de NEODATA P.U.:
  - PRESUPUESTO DE OBRA (partidas, conceptos y totales por partida)
  - ANALISIS DE PRECIOS UNITARIOS (un análisis por página)
  - ANALISIS DE BÁSICOS (básicos y cuadrillas, uno por página)
Todas con el recuadro de encabezado (empresa, cliente, concurso, obra, lugar, duración,
fechas y documento) y la tabla con encabezados enmarcados.
"""

import math

from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
from openpyxl.worksheet.pagebreak import Break

FUENTE = "Arial"
NARANJA = "FCE4D6"
FINA = Side(style="thin", color="000000")
GRUESA = Side(style="medium", color="000000")
MONEDA = '"$"#,##0.00'
PCT = '0.00"%"'


def F(size=8, **kw):
    return Font(name=FUENTE, size=size, **kw)


def _escribe(ws, fila, col, valor, fuente=None, fmt=None, alin=None, borde=None, relleno=None):
    c = ws.cell(row=fila, column=col, value=valor)
    c.font = fuente or F()
    if fmt:
        c.number_format = fmt
    if alin:
        c.alignment = alin
    if borde:
        c.border = borde
    if relleno:
        c.fill = PatternFill("solid", fgColor=relleno)
    return c


def _marco(ws, f1, f2, c1, c2):
    for f in range(f1, f2 + 1):
        for c in range(c1, c2 + 1):
            celda = ws.cell(row=f, column=c)
            celda.border = Border(left=GRUESA if c == c1 else None, right=GRUESA if c == c2 else None,
                                  top=GRUESA if f == f1 else None, bottom=GRUESA if f == f2 else None)


def encabezado(ws, fila, cab, titulo, columnas, ncol):
    """Recuadro de encabezado + título + renglón de títulos de columna. Devuelve la fila siguiente."""
    f0 = fila
    der = ncol - 2  # columna de etiquetas de la derecha; el valor ocupa las dos últimas columnas

    def valor(f, texto, fuente=None, centro=False):
        ws.merge_cells(start_row=f, start_column=ncol - 1, end_row=f, end_column=ncol)
        _escribe(ws, f, ncol - 1, texto, fuente or F(8), alin=Alignment(horizontal="center" if centro else "left"))
    _escribe(ws, fila, 1, cab["empresa"], F(12, bold=True))
    ws.merge_cells(start_row=fila, start_column=1, end_row=fila, end_column=ncol)
    ws.cell(row=fila, column=1).alignment = Alignment(horizontal="left", indent=1, wrap_text=True, vertical="center")
    ws.row_dimensions[fila].height = 30
    fila += 2
    _escribe(ws, fila, 1, "Cliente:", F(9, bold=True), alin=Alignment(horizontal="right"))
    _escribe(ws, fila, 2, cab["cliente"], F(9, bold=True))
    fila += 2
    _escribe(ws, fila, 1, "Concurso No.", F(9, bold=True), alin=Alignment(horizontal="right"))
    _escribe(ws, fila, 2, cab["concurso"], F(8))
    _escribe(ws, fila, der, "Duración:", F(9, bold=True), alin=Alignment(horizontal="right"))
    valor(fila, cab["duracion"])
    fila += 1
    _escribe(ws, fila, 1, "Obra:", F(9, bold=True), alin=Alignment(horizontal="right", vertical="top"))
    ws.merge_cells(start_row=fila, start_column=2, end_row=fila + 3, end_column=max(2, der - 1))
    _escribe(ws, fila, 2, cab["obra"], F(7), alin=Alignment(wrap_text=True, vertical="top"))
    _escribe(ws, fila, der, "Fecha:", F(9, bold=True), alin=Alignment(horizontal="right"))
    valor(fila, cab["fecha"])
    fila += 2
    _escribe(ws, fila, der, "Inicio Obra:", F(9, bold=True), alin=Alignment(horizontal="right"))
    valor(fila, cab["inicio"])
    fila += 1
    _escribe(ws, fila, der, "Fin Obra:", F(9, bold=True), alin=Alignment(horizontal="right"))
    valor(fila, cab["fin"])
    fila += 1
    valor(fila, "DOCUMENTO", F(9, bold=True), centro=True)
    fila += 1
    _escribe(ws, fila, 1, "Lugar:", F(9, bold=True), alin=Alignment(horizontal="right"))
    _escribe(ws, fila, 2, cab["lugar"], F(8))
    valor(fila, cab["documento"], F(9, bold=True), centro=True)
    _marco(ws, f0, fila, 1, ncol)
    fila += 2
    ws.merge_cells(start_row=fila, start_column=1, end_row=fila, end_column=ncol)
    _escribe(ws, fila, 1, titulo, F(10, bold=True), alin=Alignment(horizontal="center"))
    fila += 2
    for j, t in enumerate(columnas, 1):
        _escribe(ws, fila, j, t, F(9, bold=True), alin=Alignment(horizontal="center"),
                 borde=Border(left=FINA, right=FINA, top=GRUESA, bottom=GRUESA))
    return fila + 1


def _alto(texto: str, ancho_chars: float) -> float:
    return 11.5 * max(1, math.ceil(len(texto or "") / max(ancho_chars, 10)))


def _impresion(ws, titulo_filas=None):
    ws.page_setup.orientation = "portrait"
    ws.page_setup.paperSize = ws.PAPERSIZE_LETTER
    ws.page_setup.fitToWidth = 1
    ws.page_setup.fitToHeight = 0
    ws.sheet_properties.pageSetUpPr.fitToPage = True
    ws.page_margins.left = ws.page_margins.right = 0.35
    ws.page_margins.top = ws.page_margins.bottom = 0.5
    ws.sheet_view.showGridLines = False
    ws.oddFooter.center.text = "Página &P de &N"
    if titulo_filas:
        ws.print_title_rows = titulo_filas


# --------------------------------------------------------------------------
# PRESUPUESTO
# --------------------------------------------------------------------------
def hoja_presupuesto(wb, nombre, cab, partidas, celda_pu):
    """partidas: [(código, nombre, [ext, …])] con ext['cantidad'] para este presupuesto."""
    ws = wb.create_sheet(nombre)
    for col, w in zip("ABCDEFG", (13, 52, 7, 11, 12, 14, 8)):
        ws.column_dimensions[col].width = w
    fila = encabezado(ws, 1, cab, "PRESUPUESTO DE OBRA — CONCEPTOS EXTRAORDINARIOS",
                      ["Código", "Concepto", "Unidad", "Cantidad", "P. Unitario", "Importe", "%"], 7)
    _impresion(ws, f"1:{fila - 1}")
    fila_total = None
    filas_tot_partida, filas_conceptos = [], []
    for cod, titulo, exts in partidas:
        _escribe(ws, fila, 1, cod, F(9, bold=True))
        _escribe(ws, fila, 2, titulo, F(9, bold=True))
        fila += 1
        f0 = fila
        for e in exts:
            _escribe(ws, fila, 1, e["clave"], F(8), alin=Alignment(vertical="top"))
            _escribe(ws, fila, 2, e["descripcion"], F(7.5, italic=True), alin=Alignment(wrap_text=True, vertical="top",
                                                                                         horizontal="justify"))
            _escribe(ws, fila, 3, e["unidad"], F(8), alin=Alignment(vertical="top"))
            _escribe(ws, fila, 4, e["cantidad"], F(8), "#,##0.0000", Alignment(vertical="top"))
            _escribe(ws, fila, 5, f"={celda_pu[e['clave']]}", F(8), MONEDA, Alignment(vertical="top"))
            _escribe(ws, fila, 6, f"=ROUND(D{fila}*E{fila},2)", F(8), MONEDA, Alignment(vertical="top"))
            ws.row_dimensions[fila].height = _alto(e["descripcion"], 95)
            filas_conceptos.append(fila)
            fila += 1
        fila += 1
        _escribe(ws, fila, 1, cod, F(9, bold=True))
        _escribe(ws, fila, 2, f"TOTAL {titulo}", F(9, bold=True))
        _escribe(ws, fila, 6, f"=SUM(F{f0}:F{fila - 2})", F(9, bold=True), MONEDA, borde=Border(top=FINA))
        _escribe(ws, fila, 7, None, F(9, bold=True), borde=Border(top=FINA))
        filas_tot_partida.append(fila)
        fila += 2
    fila_total = fila
    _escribe(ws, fila, 2, "TOTAL DEL PRESUPUESTO (SIN I.V.A.)", F(9, bold=True))
    _escribe(ws, fila, 6, "=" + "+".join(f"F{r}" for r in filas_tot_partida) if filas_tot_partida else 0, F(9, bold=True),
             MONEDA, borde=Border(top=GRUESA))
    _escribe(ws, fila + 1, 2, "I.V.A. 16%", F(9, bold=True))
    _escribe(ws, fila + 1, 6, f"=ROUND(F{fila}*0.16,2)", F(9, bold=True), MONEDA)
    _escribe(ws, fila + 2, 2, "TOTAL CON I.V.A.", F(9, bold=True))
    _escribe(ws, fila + 2, 6, f"=F{fila}+F{fila + 1}", F(9, bold=True), MONEDA, borde=Border(top=FINA, bottom=GRUESA))
    for r in filas_conceptos + filas_tot_partida:
        _escribe(ws, r, 7, f"=IFERROR(F{r}/$F${fila_total}*100,0)", F(8, bold=r in filas_tot_partida), PCT,
                 Alignment(vertical="top"), borde=Border(top=FINA) if r in filas_tot_partida else None)
    return ws, f"'{nombre}'!F{fila_total}"


# --------------------------------------------------------------------------
# ANÁLISIS DE PRECIOS UNITARIOS
# --------------------------------------------------------------------------
SECCIONES = [("MAT", "MATERIALES"), ("MO", "MANO DE OBRA"), ("EQ", "EQUIPO Y HERRAMIENTA"), ("BAS", "BASICOS"),
             ("AUX", "AUXILIARES (P.U. DE CONTRATO A COSTO DIRECTO)")]


def _renglon(ws, fila, cod, desc, unidad, precio_formula, op, cant, nuevo=False, k=None):
    _escribe(ws, fila, 1, cod, F(8), alin=Alignment(vertical="top"))
    _escribe(ws, fila, 2, desc, F(8), alin=Alignment(wrap_text=True, vertical="top"))
    _escribe(ws, fila, 3, unidad, F(8), alin=Alignment(horizontal="center", vertical="top"))
    _escribe(ws, fila, 4, precio_formula, F(8), MONEDA, Alignment(vertical="top"))
    _escribe(ws, fila, 5, op, F(8), alin=Alignment(horizontal="center", vertical="top"))
    _escribe(ws, fila, 6, cant, F(8), "0.000000", Alignment(vertical="top"))
    _escribe(ws, fila, 7, f"=ROUND(D{fila}{'/' if op == '/' else '*'}F{fila},2)", F(8), MONEDA, Alignment(vertical="top"))
    if k is not None:
        ws.cell(row=fila, column=10, value=k)
    if nuevo:
        for j in range(1, 9):
            ws.cell(row=fila, column=j).fill = PatternFill("solid", fgColor=NARANJA)
    ws.row_dimensions[fila].height = _alto(desc, 44)


def apu(ws, fila, cab, ext, calc, ref_ins, partida, no_analisis, letra):
    """Escribe un análisis completo desde 'fila'. Devuelve (fila siguiente, fila del P.U.)."""
    fila = encabezado(ws, fila, cab, "ANALISIS DE PRECIOS UNITARIOS",
                      ["Código", "Concepto", "Unidad", "P. Unitario", "Op.", "Cantidad", "Importe", "%"], 8)
    _escribe(ws, fila, 1, "Partida:", F(8))
    _escribe(ws, fila, 2, partida, F(8))
    _escribe(ws, fila, 3, "Análisis No.:", F(8))
    _escribe(ws, fila, 6, no_analisis, F(8), alin=Alignment(horizontal="center"))
    fila += 1
    _escribe(ws, fila, 1, "Análisis:", F(9, bold=True))
    _escribe(ws, fila, 2, ext["clave"], F(9, bold=True))
    _escribe(ws, fila, 4, ext["unidad"], F(9, bold=True), alin=Alignment(horizontal="center"))
    _escribe(ws, fila, 6, ext["cantidad"], F(9, bold=True), "#,##0.0000")
    fila_an = fila
    fila += 1
    ws.merge_cells(start_row=fila, start_column=1, end_row=fila, end_column=8)
    _escribe(ws, fila, 1, ext["descripcion"], F(8), alin=Alignment(wrap_text=True, vertical="top"))
    ws.row_dimensions[fila].height = _alto(ext["descripcion"], 150)
    fila += 2

    sub, filas_reng, k_filas, sub_mo = [], [], [], None
    for secc, titulo in SECCIONES:
        ls = [l for l in calc["lineas"] if l["tipo"] == secc]
        if not ls:
            continue
        _escribe(ws, fila, 1, titulo, F(9, bold=True))
        fila += 1
        f0 = fila
        for l in ls:
            es_pct = l["cod"].startswith("%MO")
            usar_div = l["tipo"] in ("MO", "EQ") and not es_pct and 0 < l["cant"] < 1
            precio = f"=G{sub_mo}" if es_pct else f"={ref_ins(l['cod'])}"
            _renglon(ws, fila, l["cod"].replace("%MO5", "%MO5").replace("%MO", "%MO"), l["desc"],
                     "%mo" if es_pct else l["unidad"], precio, "/" if usar_div else "*",
                     round(1 / l["cant"], 6) if usar_div else l["cant"], l.get("nuevo"), l["k"])
            filas_reng.append(fila)
            k_filas.append(fila)
            fila += 1
        fila += 1
        _escribe(ws, fila, 1, "SUBTOTAL:", F(9, bold=True))
        _escribe(ws, fila, 2, titulo, F(9, bold=True))
        _escribe(ws, fila, 7, f"=SUM(G{f0}:G{fila - 2})", F(9, bold=True), MONEDA, borde=Border(top=FINA))
        if secc == "MO":
            sub_mo = fila
            # el % de herramienta se calcula sobre este subtotal: corrige las referencias ya escritas
        sub.append(fila)
        fila += 1
    # %MO va en EQUIPO Y HERRAMIENTA, después del subtotal de MO: actualizar referencias
    if sub_mo:
        for r in filas_reng:
            c = ws.cell(row=r, column=4)
            if isinstance(c.value, str) and c.value == "=GNone":
                c.value = f"=G{sub_mo}"
    t = {}

    def cargo(etq, formula, pct=None, negrita=False, italica=False, clave=None, borde=None):
        nonlocal fila
        _escribe(ws, fila, 2, etq, F(9 if negrita else 8, bold=negrita, italic=italica))
        if pct is not None:
            _escribe(ws, fila, 6, pct, F(8), alin=Alignment(horizontal="right"))
        _escribe(ws, fila, 7, formula, F(9 if negrita else 8, bold=negrita), MONEDA, borde=borde)
        if clave:
            t[clave] = fila
        fila += 1

    cargo("(CD) COSTO DIRECTO", "=" + "+".join(f"G{r}" for r in sub), negrita=True, clave="CD")
    _escribe(ws, t["CD"], 8, 100, F(9, bold=True), PCT)
    cargo("(CI) INDIRECTOS", f"=G{t['CD']}*(Parametros!$C$5+Parametros!$C$6)",
          '=TEXT((Parametros!$C$5+Parametros!$C$6)*100,"0.0000")&"%"', italica=True, clave="CI", borde=Border(bottom=FINA))
    cargo("SUBTOTAL1", f"=G{t['CD']}+G{t['CI']}", clave="S1")
    cargo("(CF) FINANCIAMIENTO", f"=G{t['S1']}*Parametros!$C$7", '=TEXT(Parametros!$C$7*100,"0.0000")&"%"',
          italica=True, clave="CF", borde=Border(bottom=FINA))
    cargo("SUBTOTAL2", f"=G{t['S1']}+G{t['CF']}", clave="S2")
    cargo("(CU) UTILIDAD", f"=G{t['S2']}*Parametros!$C$8", '=TEXT(Parametros!$C$8*100,"0.0000")&"%"',
          italica=True, clave="CU", borde=Border(bottom=FINA))
    cargo("SUBTOTAL3", f"=G{t['S2']}+G{t['CU']}", clave="S3")
    cargo("CARGOS ADICIONALES", None)
    cargo("(CA1) 5 AL MILLAR S.F.P. = SUBTOTAL3/(1-0.005) - SUBTOTAL3",
          f"=G{t['S3']}/(1-Parametros!$C$9)-G{t['S3']}", "0.5025%", italica=True, clave="CA1")
    base = "(" + "+".join(f"G{r}*J{r}" for r in k_filas) + ")" if k_filas else "0"
    cargo("(CA2) ISN=IMPUESTO SOBRE NOMINA", f"=ROUND({base}*Parametros!$C$10,2)",
          f'=TEXT(Parametros!$C$10*100,"0")&"% x "&TEXT({base},"#,##0.00")', italica=True, clave="CA2",
          borde=Border(bottom=FINA))
    cargo("PRECIO UNITARIO    (CD+ CI+ CF+ CU+ CA1+CA2)",
          f"=ROUND(ROUND(G{t['S3']},2)+ROUND(G{t['CA1']},2)+G{t['CA2']},2)", negrita=True, clave="PU")
    _escribe(ws, fila, 2, letra, F(8, bold=True))
    fila += 1
    for r in filas_reng + sub:
        _escribe(ws, r, 8, f"=IFERROR(G{r}/G${t['CD']}*100,0)", F(8, bold=r in sub), PCT, Alignment(vertical="top"))
    _escribe(ws, fila_an, 7, f"=ROUND(G{t['PU']}*F{fila_an},2)", F(9, bold=True), MONEDA)
    fila += 2
    _escribe(ws, fila, 2, "ELABORÓ: _________________________", F(8))
    _escribe(ws, fila, 4, "REVISÓ: _____________________", F(8))
    _escribe(ws, fila, 7, "AUTORIZÓ: ______________", F(8))
    fila += 1
    ws.row_breaks.append(Break(id=fila))
    return fila + 1, t["PU"]


# --------------------------------------------------------------------------
# ANÁLISIS DE BÁSICOS
# --------------------------------------------------------------------------
SECC_BAS = [("MAT", "MATERIALES"), ("MO", "MANO DE OBRA"), ("EQ", "EQUIPO Y HERRAMIENTA"), ("BAS", "BASICOS")]


def basico(ws, fila, cab, codigo, b, ref_ins, precio_nuevo=None):
    """Un básico del Doc. 14c con sus componentes (los sub-básicos van en un renglón, como en NEODATA).
    Devuelve (fila siguiente, fila del costo directo)."""
    fila = encabezado(ws, fila, cab, "ANALISIS DE BÁSICOS",
                      ["Código", "Concepto", "Unidad", "P. Unitario", "Op.", "Cantidad", "Importe", "%"], 8)
    fila += 1
    _escribe(ws, fila, 1, "Análisis:", F(9, bold=True))
    _escribe(ws, fila, 2, codigo, F(9, bold=True))
    _escribe(ws, fila, 4, b["unidad"], F(9, bold=True), alin=Alignment(horizontal="center"))
    fila += 1
    ws.merge_cells(start_row=fila, start_column=1, end_row=fila, end_column=8)
    _escribe(ws, fila, 1, b["descripcion"], F(8), alin=Alignment(wrap_text=True))
    fila += 1
    secciones = {}
    for r in b["renglones"]:
        secciones.setdefault(r["seccion"], []).append(r)
    sub, filas, sub_mo = [], [], None
    for secc, titulo in SECC_BAS:
        rs = secciones.get(secc)
        if not rs:
            continue
        _escribe(ws, fila, 1, titulo, F(9, bold=True))
        fila += 1
        f0 = fila
        for r in rs:
            cod = r["codigo"]
            if cod.startswith("%"):
                precio = f"=G{sub_mo}" if sub_mo else r["precio"]
            else:
                precio = f"=IFERROR({ref_ins(cod)},{r['precio']})"
            _renglon(ws, fila, cod, r["descripcion"], r["unidad"], precio, r["op"], r["cantidad"])
            filas.append(fila)
            fila += 1
        fila += 1
        _escribe(ws, fila, 1, "SUBTOTAL:", F(9, bold=True))
        _escribe(ws, fila, 2, titulo, F(9, bold=True))
        _escribe(ws, fila, 7, f"=SUM(G{f0}:G{fila - 2})", F(9, bold=True), MONEDA, borde=Border(top=FINA))
        if secc == "MO":
            sub_mo = fila
        sub.append(fila)
        fila += 1
    _escribe(ws, fila, 2, "Costo Directo:", F(9, bold=True))
    _escribe(ws, fila, 7, "=" + "+".join(f"G{r}" for r in sub), F(9, bold=True), MONEDA, borde=Border(top=FINA))
    _escribe(ws, fila, 8, 100, F(9, bold=True), PCT)
    cd = fila
    for r in filas + sub:
        _escribe(ws, r, 8, f"=IFERROR(G{r}/G${cd}*100,0)", F(8, bold=r in sub), PCT)
    fila += 2
    ws.row_breaks.append(Break(id=fila))
    return fila + 1, cd
