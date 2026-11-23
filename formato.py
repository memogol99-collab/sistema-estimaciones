"""
Formato de los entregables en Excel: portada, encabezados, colores por estado,
formatos de número y fecha, totales y configuración de impresión.
"""

from datetime import date, datetime
from pathlib import Path

import pandas as pd
from openpyxl import Workbook
from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
from openpyxl.utils import get_column_letter

AZUL = "1F3864"
AZUL_CLARO = "D9E2F3"
GRIS = "595959"
FRANJA = "F5F7FB"
BORDE = Side(style="thin", color="D0D5DD")

COLORES = {  # texto de la celda → (relleno, color de letra)
    "Colada": ("C6EFCE", "006100"), "Concluido": ("C6EFCE", "006100"), "Alta": ("C6EFCE", "006100"),
    "En proceso": ("FFEB9C", "7F6000"), "En perforación": ("FFEB9C", "7F6000"), "Media": ("FFEB9C", "7F6000"),
    "Con relleno fluido (por reperforar)": ("FCE4D6", "843C0C"), "Baja": ("FCE4D6", "843C0C"),
    "Aviso de terminado": ("C6EFCE", "006100"), "Cancelado / suspendido": ("FFC7CE", "9C0006"),
    "Garzas (2ª etapa)": ("E2EFDA", "375623"), "Gaviotas (Barrio V)": ("DDEBF7", "1F4E78"),
}

PALABRAS_DINERO = ("importe", "precio", "monto")
PALABRAS_TEXTO_LARGO = ("texto", "actividad", "descripción", "observaciones", "concepto_sugerido",
                        "otras_opciones", "aviso", "ejemplo", "menciones", "equipo", "categor", "autores",
                        "maquinaria_inactiva", "fechas_relleno", "base_del", "quién", "pilas coladas", "pilas sin colar")


def _es(col: str, palabras) -> bool:
    c = col.lower()
    return any(p in c for p in palabras)


def _titulo_col(col: str) -> str:
    t = col.replace("_", " ").strip()
    return t[:1].upper() + t[1:]


def _valor(v):
    if v is None:
        return None
    if isinstance(v, float) and pd.isna(v):
        return None
    if v is pd.NaT:
        return None
    if isinstance(v, (bool,)) or type(v).__name__ == "bool_":
        return "Sí" if v else ""
    if isinstance(v, pd.Timestamp):
        return v.to_pydatetime()
    if hasattr(v, "item") and not isinstance(v, (str, bytes)):
        try:
            return v.item()
        except Exception:
            return v
    return v


def escribir_hoja(wb: Workbook, nombre: str, df: pd.DataFrame, titulo: str, subtitulo: str = "",
                  totales: list[str] | None = None, nota: str = "") -> None:
    ws = wb.create_sheet(nombre[:31])
    ws.sheet_view.showGridLines = False
    ws["A1"] = titulo
    ws["A1"].font = Font(bold=True, size=14, color=AZUL)
    ws["A2"] = subtitulo
    ws["A2"].font = Font(italic=True, size=9, color=GRIS)
    if nota:
        ws["A3"] = nota
        ws["A3"].font = Font(size=9, color="9C5700")
    fila_enc = 5
    cols = list(df.columns)
    for j, c in enumerate(cols, 1):
        celda = ws.cell(row=fila_enc, column=j, value=_titulo_col(str(c)))
        celda.font = Font(bold=True, color="FFFFFF", size=10)
        celda.fill = PatternFill("solid", fgColor=AZUL)
        celda.alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)
        celda.border = Border(left=BORDE, right=BORDE, top=BORDE, bottom=BORDE)
    ws.row_dimensions[fila_enc].height = 32

    anchos = [len(_titulo_col(str(c))) for c in cols]
    # Formato numérico por columna (todas las celdas de la columna con el mismo formato)
    fmt_col = {}
    for c in cols:
        serie = pd.to_numeric(df[c], errors="coerce") if df[c].dtype != bool else pd.Series(dtype=float)
        if _es(str(c), PALABRAS_DINERO):
            fmt_col[c] = '"$"#,##0.00'
        elif "%" in str(c):
            fmt_col[c] = "0.0%"
        elif serie.notna().any():
            fmt_col[c] = "#,##0" if (serie.dropna() % 1 == 0).all() else "#,##0.00"
    for i, fila in enumerate(df.itertuples(index=False), fila_enc + 1):
        franja = PatternFill("solid", fgColor=FRANJA) if (i - fila_enc) % 2 == 0 else None
        for j, (c, v) in enumerate(zip(cols, fila), 1):
            v = _valor(v)
            celda = ws.cell(row=i, column=j, value=v)
            celda.border = Border(left=BORDE, right=BORDE, top=BORDE, bottom=BORDE)
            largo = _es(c, PALABRAS_TEXTO_LARGO)
            celda.alignment = Alignment(vertical="top", wrap_text=largo)
            celda.font = Font(size=9)
            if franja:
                celda.fill = franja
            if isinstance(v, (datetime, date)):
                celda.number_format = "dd/mm/yyyy"
                celda.alignment = Alignment(horizontal="center", vertical="top")
            elif isinstance(v, (int, float)) and not isinstance(v, bool):
                celda.number_format = fmt_col.get(c, "#,##0.##")
            if isinstance(v, str) and v in COLORES:
                relleno, letra = COLORES[v]
                celda.fill = PatternFill("solid", fgColor=relleno)
                celda.font = Font(size=9, bold=True, color=letra)
                celda.alignment = Alignment(horizontal="center", vertical="top", wrap_text=True)
            if c.lower() in ("observaciones", "aviso_contrato") and v:
                celda.font = Font(size=9, color="9C0006")
            if v == "Sí" and c.lower() in ("incidencia", "pendiente", "posible_repetido", "suspendida", "caidos"):
                celda.font = Font(size=9, bold=True, color="9C0006")
            texto = str(v) if v is not None else ""
            if isinstance(v, (datetime, date)):
                texto = "00/00/0000"
            anchos[j - 1] = max(anchos[j - 1], min(len(texto), 200))

    ultima = fila_enc + len(df)
    if totales and len(df):
        ft = ultima + 1
        ws.cell(row=ft, column=1, value="TOTAL").font = Font(bold=True, color=AZUL)
        for j, c in enumerate(cols, 1):
            celda = ws.cell(row=ft, column=j)
            celda.fill = PatternFill("solid", fgColor=AZUL_CLARO)
            celda.border = Border(top=Side(style="medium", color=AZUL))
            if c in totales:
                letra = get_column_letter(j)
                celda.value = f"=SUM({letra}{fila_enc + 1}:{letra}{ultima})"
                celda.font = Font(bold=True, size=10)
                celda.number_format = fmt_col.get(c, "#,##0.00")

    for j, c in enumerate(cols, 1):
        tope = 60 if _es(c, PALABRAS_TEXTO_LARGO) else 28
        ws.column_dimensions[get_column_letter(j)].width = max(9, min(anchos[j - 1] + 2, tope))
    if cols:
        ws.freeze_panes = ws.cell(row=fila_enc + 1, column=1)
        ws.auto_filter.ref = f"A{fila_enc}:{get_column_letter(len(cols))}{max(ultima, fila_enc)}"
    ws.page_setup.orientation = "landscape"
    ws.page_setup.fitToWidth = 1
    ws.page_setup.fitToHeight = 0
    ws.sheet_properties.pageSetUpPr.fitToPage = True
    ws.print_title_rows = f"{fila_enc}:{fila_enc}"
    ws.oddFooter.center.text = "Página &P de &N"
    ws.oddHeader.left.text = titulo


def guardar_libro(ruta: Path, titulo: str, datos_generales: list[tuple[str, str]],
                  hojas: list[dict], previas: list | None = None) -> None:
    """hojas: [{"nombre", "df", "descripcion", "totales"?, "nota"?}] — las vacías se omiten.
    previas: funciones f(wb) -> (nombre, descripción) que crean hojas con diseño propio; van primero."""
    wb = Workbook()
    portada = wb.active
    portada.title = "Portada"
    portada.sheet_view.showGridLines = False
    portada["B2"] = titulo
    portada["B2"].font = Font(bold=True, size=18, color=AZUL)
    portada["B3"] = f"Generado el {datetime.now():%d/%m/%Y %H:%M} a partir de los grupos de WhatsApp de la obra"
    portada["B3"].font = Font(italic=True, size=9, color=GRIS)
    fila = 5
    for etiqueta, valor in datos_generales:
        portada.cell(row=fila, column=2, value=etiqueta).font = Font(bold=True, size=10, color=AZUL)
        c = portada.cell(row=fila, column=3, value=valor)
        c.font = Font(size=10)
        c.alignment = Alignment(wrap_text=True, vertical="top")
        fila += 1
    fila += 1
    portada.cell(row=fila, column=2, value="Contenido").font = Font(bold=True, size=12, color=AZUL)
    fila += 1
    for f in previas or []:
        try:
            nombre_h, desc_h = f(wb)
        except Exception as exc:  # una hoja de diseño que falle no debe impedir el resto del libro
            print(f"   (no se pudo crear una hoja de resumen: {exc})")
            continue
        c = portada.cell(row=fila, column=2, value=nombre_h)
        c.hyperlink = f"#'{nombre_h[:31]}'!A1"
        c.font = Font(size=10, bold=True, color="0563C1", underline="single")
        d = portada.cell(row=fila, column=3, value=desc_h)
        d.font = Font(size=9, color=GRIS)
        d.alignment = Alignment(wrap_text=True, vertical="top")
        fila += 1
    for h in hojas:
        if h["df"] is None or h["df"].empty:
            continue
        c = portada.cell(row=fila, column=2, value=h["nombre"])
        c.hyperlink = f"#'{h['nombre'][:31]}'!A1"
        c.font = Font(size=10, color="0563C1", underline="single")
        d = portada.cell(row=fila, column=3, value=f"{h.get('descripcion', '')}  ({len(h['df'])} filas)")
        d.font = Font(size=9, color=GRIS)
        d.alignment = Alignment(wrap_text=True, vertical="top")
        fila += 1
    fila += 1
    aviso = portada.cell(row=fila, column=2, value=(
        "Nota: la información proviene de mensajes de WhatsApp y de asignaciones automáticas por palabras "
        "clave. Es un apoyo para el seguimiento y la estimación; no sustituye a la bitácora ni a los números generadores."))
    aviso.font = Font(italic=True, size=9, color="9C5700")
    portada.merge_cells(start_row=fila, start_column=2, end_row=fila + 1, end_column=3)
    aviso.alignment = Alignment(wrap_text=True, vertical="top")
    portada.column_dimensions["A"].width = 3
    portada.column_dimensions["B"].width = 30
    portada.column_dimensions["C"].width = 100
    portada.page_setup.orientation = "landscape"
    portada.sheet_properties.pageSetUpPr.fitToPage = True
    portada.page_setup.fitToWidth = 1
    portada.page_setup.fitToHeight = 1

    for h in hojas:
        if h["df"] is None or h["df"].empty:
            continue
        escribir_hoja(wb, h["nombre"], h["df"], h.get("titulo", h["nombre"]), h.get("descripcion", ""),
                      totales=h.get("totales"), nota=h.get("nota", ""))
    wb.save(ruta)
