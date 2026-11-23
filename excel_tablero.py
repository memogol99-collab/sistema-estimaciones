"""
Hojas de Excel con el mismo contenido del reporte HTML:
  - "Tablero": indicadores, contratos, pilas, datos a verificar, recursos, atrasos,
    partidas sin abrir, posibles extraordinarios, incidencias y pendientes.
  - "Bitácora por día": cada día con sus actividades por puente y los mensajes
    relevantes; los días se pliegan y despliegan con los botones +/- de Excel.
"""

from datetime import timedelta

import pandas as pd
from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
from openpyxl.utils import get_column_letter

import recursos
from reporte_html import _corto, _fecha_larga

AZUL, AZUL2, CLARO, GRIS = "1F3864", "2F5597", "EEF3FB", "5B6270"
VERDE_F, VERDE = "E3F4E8", "1E7B34"
AMBAR_F, AMBAR = "FFF4D6", "8A6100"
ROJO_F, ROJO = "FDE8E8", "A4161A"
PUENTE_F = {"Garzas (2ª etapa)": ("E2EFDA", "375623"), "Gaviotas (Barrio V)": ("DDEBF7", "1F4E78")}
ESTADO_F = {"Colada": (VERDE_F, VERDE), "En perforación": (AMBAR_F, AMBAR),
            "Con relleno fluido (por reperforar)": (ROJO_F, ROJO), "Atrasado": (ROJO_F, ROJO)}
LINEA = Side(style="thin", color="DDE3EC")
NCOL = 12  # rejilla de columnas B..M del tablero


def _relleno(c):
    return PatternFill("solid", fgColor=c)


def _celda(ws, fila, col, valor, *, negrita=False, color="1D2330", fondo=None, tam=10, wrap=True,
           horiz="left", fmt=None, span=1, borde=True, italica=False):
    if span > 1:
        ws.merge_cells(start_row=fila, start_column=col, end_row=fila, end_column=col + span - 1)
    c = ws.cell(row=fila, column=col, value=valor)
    c.font = Font(bold=negrita, color=color, size=tam, italic=italica)
    c.alignment = Alignment(wrap_text=wrap, vertical="top", horizontal=horiz)
    if fondo:
        for k in range(span):
            ws.cell(row=fila, column=col + k).fill = _relleno(fondo)
    if borde:
        for k in range(span):
            ws.cell(row=fila, column=col + k).border = Border(bottom=LINEA)
    if fmt:
        c.number_format = fmt
    return c


def _titulo(ws, fila, texto, nivel=1):
    if nivel == 1:
        _celda(ws, fila, 2, texto, negrita=True, color=AZUL, tam=13, span=NCOL, borde=False, wrap=False)
        for k in range(NCOL):
            ws.cell(row=fila, column=2 + k).border = Border(bottom=Side(style="medium", color=AZUL))
        ws.row_dimensions[fila].height = 22
        return fila + 2
    _celda(ws, fila, 2, texto, negrita=True, color=AZUL2, tam=11, span=NCOL, borde=False, wrap=False)
    return fila + 1


def _nota(ws, fila, texto):
    _celda(ws, fila, 2, texto, color=GRIS, tam=9, italica=True, span=NCOL, borde=False)
    ws.row_dimensions[fila].height = max(15, 13 * (1 + len(texto) // 170))
    return fila + 1


def _alto(textos_y_anchos) -> float:
    """Altura de fila aproximada según el texto más largo para su ancho (en caracteres)."""
    lineas = 1
    for t, ancho in textos_y_anchos:
        if t:
            lineas = max(lineas, sum(1 + len(p) // max(ancho, 8) for p in str(t).split("\n")))
    return min(15 * lineas, 300)


def _tabla(ws, fila, columnas, filas, formatos=None, total=None):
    """columnas: [(encabezado, span)]. filas: listas de valores (str, número o (valor, fondo, color))."""
    formatos = formatos or {}
    col = 2
    for enc, span in columnas:
        _celda(ws, fila, col, enc, negrita=True, color="FFFFFF", fondo=AZUL, tam=9, span=span, horiz="center")
        col += span
    ws.row_dimensions[fila].height = 28
    fila += 1
    anchos = [sum(ws.column_dimensions[get_column_letter(2 + sum(s for _, s in columnas[:i]) + k)].width or 12
                  for k in range(span)) for i, (_, span) in enumerate(columnas)]
    for n, valores in enumerate(filas + ([total] if total else [])):
        es_total = total is not None and n == len(filas)
        col = 2
        textos = []
        for i, ((_, span), v) in enumerate(zip(columnas, valores)):
            fondo, color = (CLARO if es_total else ("F8FAFD" if n % 2 else None)), "1D2330"
            if isinstance(v, tuple):
                v, fondo, color = v
            if isinstance(v, float) and pd.isna(v):
                v = None
            num = isinstance(v, (int, float)) and not isinstance(v, bool)
            _celda(ws, fila, col, v, negrita=es_total or (color != "1D2330"), color=color, fondo=fondo, tam=9,
                   span=span, horiz="right" if num else "left", fmt=formatos.get(i))
            textos.append((v, anchos[i] * 1.1))
            col += span
        ws.row_dimensions[fila].height = _alto(textos)
        fila += 1
    return fila + 1


def _chip_puente(p):
    f, c = PUENTE_F.get(p, (None, "1D2330"))
    return (p, f, c)


# --------------------------------------------------------------------------
# TABLERO
# --------------------------------------------------------------------------
def hoja_tablero(wb, nombre, df, actividades, reportes, pilas, por_eje, por_concepto, contratos, extra):
    ws = wb.create_sheet("Tablero")
    ws.sheet_view.showGridLines = False
    ws.column_dimensions["A"].width = 2
    for k in range(NCOL):
        ws.column_dimensions[get_column_letter(2 + k)].width = 14
    texto = df[~df["adjunto"] & ~df["es_reporte"]]
    inicio, fin = df["fecha"].min(), df["fecha"].max()
    grupos = sorted({g.strip() for gs in df["grupo"].astype(str) for g in gs.split(",")})

    _celda(ws, 1, 2, f"Resumen de obra — {nombre}", negrita=True, color="FFFFFF", fondo=AZUL, tam=16, span=NCOL,
           borde=False, wrap=False)
    ws.row_dimensions[1].height = 30
    _celda(ws, 2, 2, f"Periodo del {_fecha_larga(inicio).lower()} al {_fecha_larga(fin).lower()} · Grupos: "
                     f"{', '.join(grupos)}", color="FFFFFF", fondo=AZUL2, tam=9, span=NCOL, borde=False)
    fila = 4

    # Indicadores
    coladas = int((pilas["estado"] == "Colada").sum()) if pilas is not None and not pilas.empty else 0
    m3 = float(pilas["volumen_colado_m3"].fillna(0).sum()) if pilas is not None and not pilas.empty else 0.0
    rf = float(pilas["relleno_fluido_m3"].fillna(0).sum()) if pilas is not None and not pilas.empty else 0.0
    kpis = [(len(df), "mensajes analizados", "#,##0"),
            (int(reportes["fecha"].nunique()) if not reportes.empty else 0, "días con reporte de actividades", "#,##0"),
            (coladas, "pilas coladas", "#,##0"), (m3, "m³ de concreto en pilas", "#,##0.0"),
            (rf, "m³ de relleno fluido", "#,##0.0"), (int(texto["incidencia"].sum()), "mensajes con incidencias", "#,##0")]
    for i, (v, etq, fmt) in enumerate(kpis):
        col = 2 + i * 2
        _celda(ws, fila, col, v, negrita=True, color=AZUL, fondo=CLARO, tam=18, span=2, fmt=fmt, borde=False)
        _celda(ws, fila + 1, col, etq, color=GRIS, fondo=CLARO, tam=9, span=2, borde=False)
    ws.row_dimensions[fila].height = 28
    ws.row_dimensions[fila + 1].height = 26
    fila += 3

    if contratos:
        fila = _titulo(ws, fila, "Contratos")
        filas = [[_chip_puente(c["puente"]), c["contrato"], c.get("monto_con_iva"), c["periodo"], _corto(c["obra"], 260)]
                 for c in contratos]
        fila = _tabla(ws, fila, [("Puente", 2), ("Contrato", 2), ("Monto c/IVA", 2), ("Periodo", 2), ("Obra", 4)],
                      filas, {2: '"$"#,##0.00'})

    # Pilas
    if pilas is not None and not pilas.empty:
        fila = _titulo(ws, fila, "Pilas de cimentación")
        if por_eje is not None and not por_eje.empty:
            filas = [[_chip_puente(r["puente"]), r["eje"], r["pilas coladas"], r["pilas sin colar"],
                      r["concreto colado m3"], r["relleno fluido m3"]] for _, r in por_eje.iterrows()]
            total = ["Total", "", f"{coladas} coladas", "", por_eje["concreto colado m3"].sum(), por_eje["relleno fluido m3"].sum()]
            fila = _tabla(ws, fila, [("Puente", 2), ("Eje", 1), ("Pilas coladas", 3), ("Sin colar", 2),
                                     ("Concreto (m³)", 2), ("Relleno fluido (m³)", 2)], filas,
                          {4: "#,##0.00", 5: "#,##0.00"}, total)
        obs = pilas[pilas["observaciones"].fillna("").ne("")]
        if len(obs):
            fila = _titulo(ws, fila, "⚠️ Datos a verificar antes de estimar", 2)
            for _, r in obs.iterrows():
                _celda(ws, fila, 2, r["elemento"], negrita=True, color=ROJO, fondo=ROJO_F, tam=9)
                _celda(ws, fila, 3, r["observaciones"], color=ROJO, fondo=ROJO_F, tam=9, span=NCOL - 1)
                ws.row_dimensions[fila].height = _alto([(r["observaciones"], 150)])
                fila += 1
            fila += 1
        fila = _titulo(ws, fila, "Detalle por pila", 2)
        filas = [[r["elemento"], (r["estado"], *ESTADO_F.get(r["estado"], (None, "1D2330"))), r["inicio_perforación"],
                  r["última_profundidad_reportada_m"], r["intentos_perforación"], r["relleno_fluido_m3"] or None,
                  r["fecha_colado"], r["volumen_colado_m3"]] for _, r in pilas.iterrows()]
        fila = _tabla(ws, fila, [("Pila", 1), ("Estado", 3), ("Inicio perforación", 2), ("Última prof. (m)", 1),
                                 ("Intentos", 1), ("Relleno fluido (m³)", 1), ("Fecha colado", 2), ("Concreto (m³)", 1)],
                      filas, {2: "dd/mm/yyyy", 3: "#,##0.00", 5: "#,##0.00", 6: "dd/mm/yyyy", 7: "#,##0.00"})

    # Pilas con caídos
    extra = extra or {}
    c_res, c_det = extra.get("caidos", (pd.DataFrame(), pd.DataFrame()))
    if c_res is not None and not c_res.empty:
        fila = _titulo(ws, fila, "Pilas con caídos")
        fila = _nota(ws, fila, "Publicaciones que informan caídos (reportes diarios y mensajes de cualquier grupo). "
                               "Detalle completo en las hojas 'Pilas con caídos' y 'Caídos (publicaciones)'.")
        filas = [[(r["pila"], ROJO_F, ROJO), _chip_puente(r["puente"]) if r["puente"] in PUENTE_F else r["puente"],
                  r["días_con_caídos"], r["fechas"], r["máxima_profundidad_reportada_m"],
                  r.get("relleno_fluido_total_m3_tabla_pilas"),
                  (r.get("estado_actual", ""), *ESTADO_F.get(r.get("estado_actual", ""), (None, "1D2330"))),
                  r["quién_publicó"]] for _, r in c_res.iterrows()]
        fila = _tabla(ws, fila, [("Pila", 1), ("Puente", 2), ("Días", 1), ("Fechas", 2), ("Prof. máx. (m)", 1),
                                 ("Relleno fluido total (m³)", 1), ("Estado", 2), ("Publicó", 2)], filas,
                      {4: "#,##0.00", 5: "#,##0.00"})
        fila = _titulo(ws, fila, "Publicaciones", 2)
        filas = [[r["fecha"], r["hora"] or "", r["pila"], r["fuente"], r["publicó"], _corto(r["texto"], 300)]
                 for _, r in c_det.iterrows()]
        fila = _tabla(ws, fila, [("Fecha", 1), ("Hora", 1), ("Pila", 1), ("Fuente", 2), ("Publicó", 2), ("Texto", 5)],
                      filas, {0: "dd/mm/yyyy"})

    # Recursos y propuesta
    det, rend, prop, corte = extra.get("det"), extra.get("rend"), extra.get("propuesta"), extra.get("corte")
    if det is not None and not det.empty:
        fila = _titulo(ws, fila, "Recursos en obra y propuesta")
        for clase, titulo in (("Mano de obra", "Personal promedio por día (últimas 2 semanas)"),
                              ("Maquinaria", "Maquinaria activa promedio por día (últimas 2 semanas)")):
            p = recursos.plantilla_diaria(det, clase)
            if p.empty:
                continue
            p = p[p["fecha"] >= corte - timedelta(days=13)]
            if p.empty:
                continue
            tipos = [c for c in p.columns if c not in ("fecha", "puente", "TOTAL")]
            filas = []
            for pte, g in p.groupby("puente"):
                prom = g[tipos].mean().sort_values(ascending=False)
                prom = prom[prom >= 0.5]
                filas.append([_chip_puente(pte), round(float(g["TOTAL"].mean()), 1),
                              ", ".join(f"{v:.0f} {t.lower()}" for t, v in prom.items())])
            fila = _titulo(ws, fila, titulo, 2)
            fila = _tabla(ws, fila, [("Puente", 2), ("Total promedio", 1), ("Por tipo", 9)], filas, {1: "#,##0.0"})
        ina = recursos.equipo_inactivo(det)
        if ina is not None and not ina.empty:
            ina = ina[ina["último_día"] >= corte - timedelta(days=7)]
            if len(ina):
                fila = _titulo(ws, fila, "Equipo inactivo en la última semana", 2)
                filas = [[(r["tipo"], ROJO_F, ROJO), r["descripción"], r["días_inactivo"], r["primer_día"], r["último_día"]]
                         for _, r in ina.iterrows()]
                fila = _tabla(ws, fila, [("Tipo", 2), ("Descripción", 6), ("Días inactivo", 1), ("Desde", 1),
                                         ("Hasta", 2)], filas, {3: "dd/mm/yyyy", 4: "dd/mm/yyyy"})
        if prop is not None and not prop.empty:
            atr = prop[prop["situación"] == "Atrasado"]
            if len(atr):
                fila = _titulo(ws, fila, f"Conceptos atrasados contra el programa al {corte:%d/%m/%Y}", 2)
                fila = _nota(ws, fila, "Ritmos por día hábil (lunes a sábado). Recurso necesario = recurso actual × ritmo "
                                       "necesario ÷ ritmo observado, para terminar en el plazo del contrato.")
                filas = [[_chip_puente(r["puente"]), r["concepto"], _corto(r["descripción"], 90), r["unidad"],
                          r["avance_vs_programa_%"], r["ritmo_observado_por_día"], r["ritmo_necesario_por_día"],
                          r["recurso_que_manda"], r["recurso_actual_promedio_4_sem"],
                          None if pd.isna(r["recurso_necesario"]) else int(r["recurso_necesario"]), r["comentario"]]
                         for _, r in atr.iterrows()]
                fila = _tabla(ws, fila, [("Puente", 1), ("No.", 1), ("Concepto", 2), ("Unidad", 1), ("Avance vs programa", 1),
                                         ("Ritmo actual/día", 1), ("Ritmo necesario/día", 1), ("Recurso que manda", 1),
                                         ("Actual", 1), ("Necesario", 1), ("Comentario", 1)],
                              filas, {4: "0%", 5: "#,##0.00", 6: "#,##0.00", 8: "#,##0.0"})
            falt = recursos.frentes_faltantes(prop)
            if not falt.empty:
                fila = _titulo(ws, fila, "Partidas programadas al corte sin actividad en los reportes", 2)
                fila = _nota(ws, fila, "Solo refleja lo que se reporta en WhatsApp; confirmar en campo antes de proponer. "
                                       "Se muestran las 8 de mayor importe por puente.")
                filas = [[_chip_puente(pte), r["partida"], r["conceptos"], r["importe_programado_al_corte"],
                          _corto(r["principales"], 200)]
                         for pte, g in falt.groupby("puente") for _, r in g.head(8).iterrows()]
                fila = _tabla(ws, fila, [("Puente", 2), ("Partida", 3), ("Conceptos", 1), ("Importe programado", 2),
                                         ("Principales conceptos", 4)], filas, {3: '"$"#,##0.00'})
        if rend is not None and not rend.empty:
            ext = rend[rend["posible_extraordinario"] == "Sí"].sort_values("jornadas_de_frente", ascending=False).head(15)
            if len(ext):
                fila = _titulo(ws, fila, "Posibles conceptos extraordinarios (sin concepto claro en catálogo)", 2)
                fila = _nota(ws, fila, "Cuadrilla y equipo típicos por jornada de frente según los reportes: base para la "
                                       "tarjeta de precio unitario. Detalle completo en recursos_*.xlsx.")
                filas = [[_chip_puente(r["puente"]), r["agrupación"].replace("Actividad: ", "").capitalize(),
                          r["jornadas_de_frente"], r["cuadrilla_típica"], r["equipo_típico"], r["hombres_día"]]
                         for _, r in ext.iterrows()]
                fila = _tabla(ws, fila, [("Puente", 2), ("Actividad", 2), ("Jornadas", 1), ("Cuadrilla típica", 4),
                                         ("Equipo típico", 2), ("Hombres-día", 1)], filas)

    # Actividades por concepto
    if por_concepto is not None and not por_concepto.empty:
        fila = _titulo(ws, fila, "Actividades por concepto de catálogo")
        fila = _nota(ws, fila, "Cada actividad se asignó al concepto más parecido del catálogo de su contrato (confianza "
                               "media o alta). Cantidades referenciales; en pilas usar las cifras de la sección de pilas.")
        for pte, g in por_concepto.groupby("puente"):
            filas = [[r["concepto"], _corto(r["descripción"], 150), r["unidad"], r["días_con_actividad"],
                      r["primera_fecha"], r["última_fecha"], r["cantidad_reportada_whatsapp"], r["cantidad_catálogo"]]
                     for _, r in g.sort_values("días_con_actividad", ascending=False).iterrows()]
            fila = _titulo(ws, fila, pte, 2)
            fila = _tabla(ws, fila, [("No.", 1), ("Concepto", 5), ("Unidad", 1), ("Días", 1), ("Desde", 1), ("Hasta", 1),
                                     ("Cant. reportada", 1), ("Cant. catálogo", 1)], filas,
                          {4: "dd/mm/yyyy", 5: "dd/mm/yyyy", 6: "#,##0.00", 7: "#,##0.00"})

    # Incidencias y pendientes
    inc = texto[texto["incidencia"]].sort_values("fecha_hora", ascending=False)
    pen = texto[texto["pendiente"]].sort_values("fecha_hora", ascending=False)
    if len(inc) or len(pen):
        fila = _titulo(ws, fila, "Incidencias y pendientes")
        for titulo, sub, n in (("⚠️ Incidencias", inc, 40), ("📌 Pendientes recientes", pen, 30)):
            if len(sub):
                fila = _titulo(ws, fila, f"{titulo} ({len(sub)} en total, se muestran {min(n, len(sub))})", 2)
                filas = [[r["fecha"], _chip_puente(r.get("puente") or ""), r["autor"], r.get("grupo", ""),
                          _corto(r["texto"], 400)] for _, r in sub.head(n).iterrows()]
                fila = _tabla(ws, fila, [("Fecha", 1), ("Puente", 2), ("Autor", 2), ("Grupo", 1), ("Mensaje", 6)],
                              filas, {0: "dd/mm/yyyy"})

    ws.freeze_panes = "A3"
    ws.page_setup.orientation = "landscape"
    ws.page_setup.fitToWidth = 1
    ws.page_setup.fitToHeight = 0
    ws.sheet_properties.pageSetUpPr.fitToPage = True
    ws.oddFooter.center.text = "Página &P de &N"
    return "Tablero", "Lo mismo que el reporte HTML: indicadores, contratos, pilas, recursos, atrasos, extraordinarios e incidencias"


# --------------------------------------------------------------------------
# BITÁCORA POR DÍA
# --------------------------------------------------------------------------
def hoja_bitacora(wb, nombre, df, actividades, dias_abiertos: int = 3):
    ws = wb.create_sheet("Bitácora por día")
    ws.sheet_view.showGridLines = False
    anchos = {"A": 2, "B": 11, "C": 20, "D": 24, "E": 95, "F": 16, "G": 48}
    for k, v in anchos.items():
        ws.column_dimensions[k].width = v
    ws.sheet_properties.outlinePr.summaryBelow = False  # el botón +/- queda en el renglón del día

    _celda(ws, 1, 2, f"Bitácora por día — {nombre}", negrita=True, color="FFFFFF", fondo=AZUL, tam=15, span=6,
           borde=False, wrap=False)
    ws.row_dimensions[1].height = 28
    _celda(ws, 2, 2, "Usa los botones + / − a la izquierda (o Datos › Agrupar) para abrir o cerrar cada día. "
                     "Los 3 días más recientes quedan abiertos.", color="FFFFFF", fondo=AZUL2, tam=9, span=6, borde=False)
    fila = 4
    for k, (dia, g) in enumerate(sorted(df.groupby("fecha"), key=lambda x: x[0], reverse=True)):
        a = actividades[actividades["fecha"] == dia] if not actividades.empty else actividades
        t = g[~g["adjunto"] & ~g["es_reporte"]]
        n_fotos = int(g["adjunto"].sum())
        _celda(ws, fila, 2, f"{_fecha_larga(dia)}   ·   {len(a)} actividades · {len(t)} mensajes · {n_fotos} fotos",
               negrita=True, color="FFFFFF", fondo=AZUL2, tam=11, span=6, borde=False, wrap=False)
        ws.row_dimensions[fila].height = 20
        fila += 1
        oculto = k >= dias_abiertos
        inicio_det = fila

        if len(a):
            _celda(ws, fila, 2, "Actividades del reporte diario", negrita=True, color=AZUL, fondo=CLARO, tam=9, span=6)
            fila += 1
            for col, enc in zip("BCDEFG", ["", "Puente", "Frente", "Actividad", "Cantidades", "Concepto de catálogo"]):
                _celda(ws, fila, ord(col) - 64, enc, negrita=True, color=GRIS, tam=8)
            fila += 1
            for pte, ga in a.groupby("puente"):
                for _, r in ga.iterrows():
                    f, c = PUENTE_F.get(pte, (None, "1D2330"))
                    conc = r.get("concepto_sugerido", "") if r.get("confianza") in ("Alta", "Media") else ""
                    _celda(ws, fila, 3, pte, fondo=f, color=c, negrita=True, tam=8)
                    _celda(ws, fila, 4, r["frente"], negrita=True, tam=9)
                    _celda(ws, fila, 5, r["actividad"], tam=9)
                    _celda(ws, fila, 6, r.get("cantidades") or "", tam=9, negrita=True)
                    _celda(ws, fila, 7, conc, tam=8, color=GRIS)
                    ws.row_dimensions[fila].height = _alto([(r["actividad"], 105), (conc, 55)])
                    fila += 1

        rel = t[t["categorias"].ne("") | t["incidencia"] | t["pendiente"]]
        if len(rel):
            _celda(ws, fila, 2, "Mensajes relevantes", negrita=True, color=AZUL, fondo=CLARO, tam=9, span=6)
            fila += 1
            for col, enc in zip("BCDEFG", ["Hora", "Puente", "Autor", "Mensaje", "Tipo", "Grupo"]):
                _celda(ws, fila, ord(col) - 64, enc, negrita=True, color=GRIS, tam=8)
            fila += 1
            for _, r in rel.iterrows():
                tipo = "⚠️ Incidencia" if r["incidencia"] else "📌 Pendiente" if r["pendiente"] else ""
                fondo = ROJO_F if r["incidencia"] else AMBAR_F if r["pendiente"] else None
                f, c = PUENTE_F.get(r.get("puente") or "", (None, "1D2330"))
                _celda(ws, fila, 2, r["hora"], tam=9, horiz="center")
                _celda(ws, fila, 3, r.get("puente") or "", fondo=f, color=c, negrita=bool(f), tam=8)
                _celda(ws, fila, 4, r["autor"], tam=9)
                _celda(ws, fila, 5, r["texto"], tam=9, fondo=fondo)
                _celda(ws, fila, 6, tipo, tam=9, fondo=fondo,
                       color=ROJO if r["incidencia"] else AMBAR if r["pendiente"] else "1D2330")
                _celda(ws, fila, 7, r.get("grupo", ""), tam=8, color=GRIS)
                ws.row_dimensions[fila].height = _alto([(r["texto"], 100)])
                fila += 1

        if n_fotos and not len(a) and not len(rel):
            _celda(ws, fila, 5, f"Solo se compartieron {n_fotos} fotos/archivos.", tam=9, italica=True, color=GRIS)
            fila += 1
        for rr in range(inicio_det, fila):
            ws.row_dimensions[rr].outlineLevel = 1
            ws.row_dimensions[rr].hidden = oculto
        fila += 1

    ws.freeze_panes = "A3"
    ws.page_setup.orientation = "landscape"
    ws.page_setup.fitToWidth = 1
    ws.page_setup.fitToHeight = 0
    ws.sheet_properties.pageSetUpPr.fitToPage = True
    ws.print_title_rows = "1:1"
    ws.oddFooter.center.text = "Página &P de &N"
    return "Bitácora por día", "Cada día con sus actividades por puente y los mensajes relevantes (se pliegan con +/−)"
