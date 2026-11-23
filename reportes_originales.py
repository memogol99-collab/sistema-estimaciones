"""
Saca el texto original de los "Reporte de actividades" de WhatsApp: una columna por
persona, renglón por renglón, como se escribió en el chat.

Ejemplos:
    python reportes_originales.py --fecha 2026-09-29                    # todos los reportes de ese día
    python reportes_originales.py --fecha 29/09/2026 --autor teran      # solo los de Edgar Terán
    python reportes_originales.py --fecha 2026-11-16 --hasta 2026-11-21 --autor marco
    python reportes_originales.py --fecha 2026-11-20 --autor "torres chompa" --autor david

El nombre puede ir incompleto, sin acentos y en minúsculas ("teran", "marco", "chompa").
La fecha es la del reporte (la que viene escrita en el mensaje). Si no viene, se usa la
del mensaje. Genera reportes_originales/reportes_<fechas>.xlsx (una hoja por día) y un .txt.
"""

import argparse
import re
import sys
from datetime import date, datetime, timedelta
from pathlib import Path

import pandas as pd
from openpyxl import Workbook
from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
from openpyxl.utils import get_column_letter

import whatsapp_resumen as w

AZUL, AZUL2, CLARO = "1F3864", "2F5597", "EEF3FB"
DIAS = ["Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado", "Domingo"]
MESES = ["", "enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre",
         "octubre", "noviembre", "diciembre"]


def leer_fecha(texto: str) -> date:
    for fmt in ("%Y-%m-%d", "%d/%m/%Y", "%d/%m/%y", "%d-%m-%Y"):
        try:
            return datetime.strptime(texto.strip(), fmt).date()
        except ValueError:
            pass
    raise argparse.ArgumentTypeError(f"Fecha no reconocida: {texto} (usa AAAA-MM-DD o DD/MM/AAAA)")


def cargar_reportes(carpeta: Path) -> pd.DataFrame:
    archivos = w.quitar_exportaciones_viejas(sorted(p for p in carpeta.iterdir() if p.suffix.lower() in (".zip", ".txt")))
    grupos = [g for g in (w.cargar_grupo(a, None, None) for a in archivos) if g is not None]
    if not grupos:
        sys.exit(f"No hay chats en {carpeta}")
    df = w.consolidar(grupos) if len(grupos) > 1 else grupos[0]
    r = df[df["es_reporte"]].copy()
    filas = []
    for _, m in r.iterrows():
        resumen, _ = w.parsear_reporte(m.to_dict())
        filas.append({"fecha_reporte": resumen["fecha"], "obra": resumen["obra"], "autor": m["autor"],
                      "enviado": m["fecha_hora"], "grupo": m.get("grupo", ""), "texto": m["texto"]})
    return pd.DataFrame(filas)


def coincide(autor: str, buscados: list[str]) -> bool:
    if not buscados:
        return True
    a = w.sin_acentos(autor)
    return any(all(p in a for p in w.sin_acentos(b).split()) for b in buscados)


def _fecha_larga(d: date) -> str:
    return f"{DIAS[d.weekday()]} {d.day} de {MESES[d.month]} de {d.year}"


def escribir(reportes: pd.DataFrame, ruta_xlsx: Path, ruta_txt: Path) -> None:
    wb = Workbook()
    wb.remove(wb.active)
    borde = Border(left=Side(style="thin", color="D0D5DD"), right=Side(style="thin", color="D0D5DD"))
    txt = []
    for dia, g in reportes.groupby("fecha_reporte"):
        g = g.sort_values(["autor", "enviado"])
        ws = wb.create_sheet(f"{dia:%d-%m-%Y}")
        ws.sheet_view.showGridLines = False
        ws.cell(row=1, column=1, value=f"Reportes de actividades — {_fecha_larga(dia)}").font = Font(bold=True, size=14, color=AZUL)
        ws.row_dimensions[1].height = 24
        txt.append(f"{'=' * 70}\n{_fecha_larga(dia).upper()}\n{'=' * 70}")
        for j, (_, r) in enumerate(g.iterrows(), 1):
            col = get_column_letter(j)
            ws.column_dimensions[col].width = 62
            enc = ws.cell(row=3, column=j, value=r["autor"])
            enc.font = Font(bold=True, color="FFFFFF", size=12)
            enc.fill = PatternFill("solid", fgColor=AZUL)
            enc.alignment = Alignment(horizontal="center")
            sub = ws.cell(row=4, column=j, value=f"{r['obra']} · enviado {r['enviado']:%d/%m/%Y %H:%M}")
            sub.font = Font(italic=True, size=9, color="FFFFFF")
            sub.fill = PatternFill("solid", fgColor=AZUL2)
            sub.alignment = Alignment(horizontal="center")
            for i, linea in enumerate(r["texto"].splitlines(), 6):
                c = ws.cell(row=i, column=j, value=linea)
                n = w.sin_acentos(linea.strip(" ◦•*-"))
                es_seccion = bool(w.RE_SECCION.match(n)) or bool(w.RE_FRENTE.match(n)) or n.startswith("reporte de actividades")
                c.font = Font(size=10, bold=es_seccion, color=AZUL if es_seccion else "1D2330", italic=not es_seccion and i < 8)
                if w.RE_FRENTE.match(n):
                    c.fill = PatternFill("solid", fgColor=CLARO)
                if "inactiv" in n:
                    c.font = Font(size=10, bold=True, color="A4161A")
                c.border = borde
            txt.append(f"\n--- {r['autor']} · {r['obra']} · enviado {r['enviado']:%d/%m/%Y %H:%M} ---\n{r['texto']}")
        ws.freeze_panes = "A5"
        ws.page_setup.orientation = "landscape"
        ws.page_setup.fitToWidth = 1
        ws.page_setup.fitToHeight = 0
        ws.sheet_properties.pageSetUpPr.fitToPage = True
        ws.print_title_rows = "3:4"
    wb.save(ruta_xlsx)
    ruta_txt.write_text("\n".join(txt) + "\n", encoding="utf-8")


def main() -> None:
    for flujo in (sys.stdout, sys.stderr):
        try:
            flujo.reconfigure(encoding="utf-8", errors="replace")
        except Exception:
            pass
    ap = argparse.ArgumentParser(description="Texto original de los 'Reporte de actividades' por fecha y persona.")
    ap.add_argument("--fecha", type=leer_fecha, required=True, help="Fecha del reporte (AAAA-MM-DD o DD/MM/AAAA)")
    ap.add_argument("--hasta", type=leer_fecha, help="Fecha final, para sacar varios días")
    ap.add_argument("--autor", action="append", default=[], help="Nombre o parte del nombre (se puede repetir)")
    ap.add_argument("--chats", type=Path, default=Path("whatsapp"), help="Carpeta con los chats exportados")
    ap.add_argument("--salida", type=Path, default=Path("reportes_originales"), help="Carpeta de salida")
    args = ap.parse_args()

    hasta = args.hasta or args.fecha
    todos = cargar_reportes(args.chats)
    sel = todos[(todos["fecha_reporte"] >= args.fecha) & (todos["fecha_reporte"] <= hasta)
                & todos["autor"].apply(lambda a: coincide(a, args.autor))]
    # El mismo reporte reenviado el mismo día por la misma persona: queda el último
    sel = sel.sort_values("enviado").drop_duplicates(["fecha_reporte", "autor", "obra"], keep="last")
    if sel.empty:
        cerca = todos[(todos["fecha_reporte"] >= args.fecha - timedelta(days=2)) & (todos["fecha_reporte"] <= hasta + timedelta(days=2))]
        print("No encontré reportes con esos datos.")
        if not cerca.empty:
            print("Reportes en fechas cercanas:")
            for _, r in cerca.sort_values("fecha_reporte").iterrows():
                print(f"   {r['fecha_reporte']:%d/%m/%Y} · {r['autor']} · {r['obra']}")
        print("Autores con reportes:", ", ".join(sorted(todos["autor"].unique())))
        sys.exit(1)
    args.salida.mkdir(parents=True, exist_ok=True)
    etiqueta = f"{args.fecha:%Y-%m-%d}" + (f"_a_{hasta:%Y-%m-%d}" if hasta != args.fecha else "")
    if args.autor:
        etiqueta += "_" + "_".join(re.sub(r"\W+", "-", w.sin_acentos(a)) for a in args.autor)
    xlsx, txt = args.salida / f"reportes_{etiqueta}.xlsx", args.salida / f"reportes_{etiqueta}.txt"
    escribir(sel, xlsx, txt)
    for _, r in sel.sort_values(["fecha_reporte", "autor"]).iterrows():
        print(f"✅ {r['fecha_reporte']:%d/%m/%Y} · {r['autor']} · {r['obra']} (enviado {r['enviado']:%d/%m %H:%M})")
    print(f"   → {xlsx}\n   → {txt}")


if __name__ == "__main__":
    main()
