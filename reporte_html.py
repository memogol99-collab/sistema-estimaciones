"""
Reporte de obra en HTML con formato (se abre en cualquier navegador y se puede
imprimir o guardar como PDF). Si Playwright está instalado, también genera el PDF.
"""

import html
from datetime import datetime
from pathlib import Path

import pandas as pd

DIAS = ["Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado", "Domingo"]
MESES = ["", "enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre",
         "octubre", "noviembre", "diciembre"]

CSS = """
:root{--azul:#1f3864;--azul2:#2f5597;--claro:#eef3fb;--gris:#5b6270;--borde:#dde3ec;--verde:#1e7b34;
--verde-f:#e3f4e8;--ambar:#8a6100;--ambar-f:#fff4d6;--rojo:#a4161a;--rojo-f:#fde8e8;--garzas:#e2efda;--gaviotas:#ddebf7}
*{box-sizing:border-box}
body{margin:0;font:14px/1.45 "Segoe UI",Roboto,Helvetica,Arial,sans-serif;color:#1d2330;background:#f4f6fa}
.hoja{max-width:1180px;margin:0 auto;background:#fff;padding:0 0 40px}
header{background:linear-gradient(120deg,var(--azul),var(--azul2));color:#fff;padding:28px 36px 22px}
header h1{margin:0 0 4px;font-size:26px;letter-spacing:.2px}
header .sub{opacity:.85;font-size:13px}
section{padding:6px 36px}
h2{color:var(--azul);font-size:18px;border-bottom:2px solid var(--azul);padding-bottom:4px;margin:26px 0 12px}
h3{color:var(--azul2);font-size:15px;margin:16px 0 8px}
.kpis{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:12px;margin:18px 0 4px}
.kpi{background:var(--claro);border:1px solid var(--borde);border-radius:10px;padding:12px 14px}
.kpi .v{font-size:24px;font-weight:700;color:var(--azul)}
.kpi .e{font-size:12px;color:var(--gris)}
.contratos{display:grid;grid-template-columns:repeat(auto-fit,minmax(320px,1fr));gap:12px}
.contrato{border:1px solid var(--borde);border-left:6px solid var(--azul2);border-radius:8px;padding:10px 14px;font-size:13px}
.contrato.garzas{border-left-color:#548235}.contrato.gaviotas{border-left-color:#2e75b6}
.contrato b{color:var(--azul)}
table{width:100%;border-collapse:collapse;font-size:12.5px;margin:6px 0 10px}
th{background:var(--azul);color:#fff;text-align:left;padding:7px 8px;font-weight:600;position:sticky;top:0}
td{border-bottom:1px solid var(--borde);padding:6px 8px;vertical-align:top}
tr:nth-child(even) td{background:#fafbfd}
td.n{text-align:right;white-space:nowrap;font-variant-numeric:tabular-nums}
tr.total td{font-weight:700;background:var(--claro)!important;border-top:2px solid var(--azul)}
.chip{display:inline-block;padding:1px 8px;border-radius:999px;font-size:11.5px;font-weight:600;white-space:nowrap}
.ok{background:var(--verde-f);color:var(--verde)}.warn{background:var(--ambar-f);color:var(--ambar)}
.bad{background:var(--rojo-f);color:var(--rojo)}.garzas{background:var(--garzas);color:#375623}
.gaviotas{background:var(--gaviotas);color:#1f4e78}
.alerta{background:var(--rojo-f);border-left:4px solid var(--rojo);padding:8px 12px;border-radius:6px;margin:6px 0;font-size:13px}
.nota{color:var(--gris);font-size:12px}
details{border:1px solid var(--borde);border-radius:8px;margin:8px 0;background:#fff}
summary{cursor:pointer;padding:9px 14px;font-weight:600;color:var(--azul);list-style:none}
summary::-webkit-details-marker{display:none}
summary::before{content:"▸ ";color:var(--azul2)}details[open] summary::before{content:"▾ "}
.dia{padding:0 16px 10px}
.dia ul{margin:4px 0 10px;padding-left:20px}.dia li{margin:2px 0}
.meta{color:var(--gris);font-size:12px}
.msg{font-size:13px}
footer{color:var(--gris);font-size:11px;padding:18px 36px 0;border-top:1px solid var(--borde);margin-top:24px}
@media print{body{background:#fff}.hoja{max-width:none}header{-webkit-print-color-adjust:exact;print-color-adjust:exact}
th,.chip,.kpi,tr.total td{-webkit-print-color-adjust:exact;print-color-adjust:exact}
details{break-inside:avoid}details:not([open]){display:none}h2{break-after:avoid}table{break-inside:auto}tr{break-inside:avoid}}
"""


def _e(x) -> str:
    if x is None or (isinstance(x, float) and pd.isna(x)) or x is pd.NaT:
        return ""
    return html.escape(str(x))


def _num(x, dec: int = 2) -> str:
    if x is None or (isinstance(x, float) and pd.isna(x)):
        return ""
    return f"{x:,.{dec}f}"


def _fecha(d) -> str:
    if d is None or d is pd.NaT or (isinstance(d, float) and pd.isna(d)):
        return ""
    return f"{d:%d/%m/%Y}"


def _fecha_larga(d) -> str:
    return f"{DIAS[d.weekday()]} {d.day} de {MESES[d.month]} de {d.year}"


def _chip(texto: str) -> str:
    clase = {"Colada": "ok", "Concluido": "ok", "Alta": "ok", "En proceso": "warn", "Media": "warn",
             "En perforación": "warn", "Baja": "bad", "Con relleno fluido (por reperforar)": "bad",
             "Garzas (2ª etapa)": "garzas", "Gaviotas (Barrio V)": "gaviotas"}.get(texto, "")
    return f'<span class="chip {clase}">{_e(texto)}</span>' if texto else ""


def _tabla(encabezados: list[str], filas: list[list[str]], numericas: set[int] = frozenset(),
           total: list[str] | None = None) -> str:
    h = "".join(f"<th>{_e(c)}</th>" for c in encabezados)
    cuerpo = "".join("<tr>" + "".join(f'<td class="{"n" if i in numericas else ""}">{v}</td>'
                                       for i, v in enumerate(f)) + "</tr>" for f in filas)
    if total:
        cuerpo += '<tr class="total">' + "".join(f'<td class="{"n" if i in numericas else ""}">{v}</td>'
                                               for i, v in enumerate(total)) + "</tr>"
    return f"<table><thead><tr>{h}</tr></thead><tbody>{cuerpo}</tbody></table>"


def _corto(t: str, n: int = 320) -> str:
    t = str(t or "").replace("\n", " ")
    return t if len(t) <= n else t[:n].rsplit(" ", 1)[0] + " …"


def escribir_html(ruta: Path, nombre: str, df: pd.DataFrame, actividades: pd.DataFrame,
                  reportes: pd.DataFrame, pilas: pd.DataFrame | None, por_eje: pd.DataFrame | None,
                  por_concepto: pd.DataFrame | None, contratos: list[dict], extra: dict | None = None) -> None:
    texto = df[~df["adjunto"] & ~df["es_reporte"]]
    inicio, fin = df["fecha"].min(), df["fecha"].max()
    grupos = sorted({g.strip() for gs in df["grupo"].astype(str) for g in gs.split(",")})
    partes = [f"<!doctype html><html lang='es'><head><meta charset='utf-8'>"
              f"<meta name='viewport' content='width=device-width,initial-scale=1'>"
              f"<title>Resumen de obra — {_e(nombre)}</title><style>{CSS}</style></head><body><div class='hoja'>"]
    partes.append(f"<header><h1>Resumen de obra — {_e(nombre)}</h1>"
                  f"<div class='sub'>Periodo del {_fecha_larga(inicio).lower()} al {_fecha_larga(fin).lower()} · "
                  f"Grupos: {_e(', '.join(grupos))}</div></header>")

    # Indicadores
    coladas = int((pilas["estado"] == "Colada").sum()) if pilas is not None and not pilas.empty else 0
    m3 = float(pilas["volumen_colado_m3"].fillna(0).sum()) if pilas is not None and not pilas.empty else 0.0
    rf = float(pilas["relleno_fluido_m3"].fillna(0).sum()) if pilas is not None and not pilas.empty else 0.0
    kpis = [(f"{len(df):,}", "mensajes analizados"), (str(reportes["fecha"].nunique()) if not reportes.empty else "0",
                                                      "días con reporte de actividades"),
            (str(coladas), "pilas coladas"), (_num(m3, 1), "m³ de concreto en pilas"),
            (_num(rf, 1), "m³ de relleno fluido"), (str(int(texto["incidencia"].sum())), "mensajes con incidencias")]
    partes.append("<section><div class='kpis'>" + "".join(
        f"<div class='kpi'><div class='v'>{v}</div><div class='e'>{e}</div></div>" for v, e in kpis) + "</div></section>")

    if contratos:
        tarjetas = []
        for c in contratos:
            clase = "garzas" if c["puente"].startswith("Garzas") else "gaviotas"
            monto = f"${c['monto_con_iva']:,.2f} c/IVA" if isinstance(c.get("monto_con_iva"), (int, float)) else ""
            tarjetas.append(f"<div class='contrato {clase}'><b>{_e(c['puente'])}</b> · Contrato {_e(c['contrato'])}<br>"
                            f"{_e(monto)} · {_e(c['periodo'])}<br><span class='nota'>{_e(_corto(c['obra'], 230))}</span></div>")
        partes.append("<section><h2>Contratos</h2><div class='contratos'>" + "".join(tarjetas) + "</div></section>")

    # Pilas
    if pilas is not None and not pilas.empty:
        partes.append("<section><h2>Pilas de cimentación</h2>")
        if por_eje is not None and not por_eje.empty:
            filas = [[_chip(r["puente"]), _e(r["eje"]), _e(r["pilas coladas"]), _e(r["pilas sin colar"]),
                      _num(r["concreto colado m3"]), _num(r["relleno fluido m3"])] for _, r in por_eje.iterrows()]
            total = ["<b>Total</b>", "", str(coladas) + " coladas", "", _num(por_eje["concreto colado m3"].sum()),
                     _num(por_eje["relleno fluido m3"].sum())]
            partes.append(_tabla(["Puente", "Eje", "Pilas coladas", "Sin colar", "Concreto (m³)", "Relleno fluido (m³)"],
                                 filas, {4, 5}, total))
        obs = pilas[pilas["observaciones"].fillna("").ne("")]
        if len(obs):
            partes.append("<h3>⚠️ Datos a verificar antes de estimar</h3>")
            partes += [f"<div class='alerta'><b>{_e(r['elemento'])}</b> — {_e(r['observaciones'])}</div>"
                       for _, r in obs.iterrows()]
        filas = [[_e(r["elemento"]), _chip(r["estado"]), _fecha(r["inicio_perforación"]),
                  _num(r["última_profundidad_reportada_m"]), _e(r["intentos_perforación"]),
                  _num(r["relleno_fluido_m3"] or None), _fecha(r["fecha_colado"]), _num(r["volumen_colado_m3"])]
                 for _, r in pilas.iterrows()]
        partes.append("<h3>Detalle por pila</h3>" + _tabla(
            ["Pila", "Estado", "Inicio perforación", "Última prof. (m)", "Intentos", "Relleno fluido (m³)",
             "Fecha colado", "Concreto (m³)"], filas, {3, 4, 5, 7}))
        partes.append("</section>")

    # Avance por concepto
    if por_concepto is not None and not por_concepto.empty:
        partes.append("<section><h2>Actividades por concepto de catálogo</h2>"
                      "<p class='nota'>Cada actividad de los reportes diarios se asignó al concepto más parecido del "
                      "catálogo de su contrato (confianza media o alta). La cantidad reportada solo suma lo que "
                      "viene en la misma unidad del concepto; es referencial y no sustituye a los generadores.</p>")
        for pte, g in por_concepto.groupby("puente"):
            filas = []
            for _, r in g.sort_values("días_con_actividad", ascending=False).iterrows():
                cant = _num(r["cantidad_reportada_whatsapp"])
                cat = r["cantidad_catálogo"]
                if cant and isinstance(cat, (int, float)) and r["cantidad_reportada_whatsapp"] > cat:
                    cant = f"<span class='chip bad' title='Supera la cantidad del catálogo'>{cant}</span>"
                if cant and r.get("nota"):
                    cant += " *"
                filas.append([_e(r["concepto"]), _e(_corto(r["descripción"], 150)), _e(r["unidad"]),
                              _e(r["días_con_actividad"]), f"{_fecha(r['primera_fecha'])} – {_fecha(r['última_fecha'])}",
                              cant, _num(cat)])
            partes.append(f"<h3>{_chip(pte)}</h3>" + _tabla(
                ["No.", "Concepto", "Unidad", "Días", "Periodo", "Cant. reportada", "Cant. catálogo"],
                filas, {0, 3, 5, 6}))
        partes.append("<p class='nota'>* En pilas, la cifra depurada (sin reportes repetidos ni colados duplicados) "
                      "es la de la sección <b>Pilas de cimentación</b>. En rojo: cantidad que supera la del catálogo "
                      "(posible doble conteo en los reportes o concepto mal asignado; revisar).</p></section>")

    # Pilas con caídos
    extra = extra or {}
    c_res, c_det = extra.get("caidos", (pd.DataFrame(), pd.DataFrame()))
    if c_res is not None and not c_res.empty:
        partes.append("<section><h2>Pilas con caídos</h2><p class='nota'>Publicaciones que informan caídos en los "
                      "reportes diarios y en los mensajes de cualquier grupo.</p>")
        filas = [[f"<span class='chip bad'>{_e(r['pila'])}</span>", _chip(r["puente"]) if r["puente"] else "",
                  _e(r["días_con_caídos"]), _e(r["fechas"]), _num(r["máxima_profundidad_reportada_m"]),
                  _num(r.get("relleno_fluido_total_m3_tabla_pilas")), _chip(r.get("estado_actual", "") or ""),
                  _e(r["quién_publicó"])] for _, r in c_res.iterrows()]
        partes.append(_tabla(["Pila", "Puente", "Días", "Fechas", "Prof. máx. (m)", "Relleno fluido total (m³)", "Estado",
                              "Publicó"], filas, {2, 4, 5}))
        filas = [[_fecha(r["fecha"]), _e(r["hora"]), _e(r["pila"]), _e(r["fuente"]), _e(r["publicó"]), _e(r["grupo"]),
                  f"<span class='msg'>{_e(_corto(r['texto'], 300))}</span>"] for _, r in c_det.iterrows()]
        partes.append("<h3>Publicaciones</h3>" + _tabla(["Fecha", "Hora", "Pila", "Fuente", "Publicó", "Grupo", "Texto"], filas)
                      + "</section>")

    # Recursos, propuesta y extraordinarios
    det, rend, prop, corte = extra.get("det"), extra.get("rend"), extra.get("propuesta"), extra.get("corte")
    if det is not None and not det.empty:
        import recursos as _rec
        partes.append("<section><h2>Recursos en obra y propuesta</h2>")
        from datetime import timedelta as _td
        desde = corte - _td(days=13)
        for clase, titulo in (("Mano de obra", "Personal promedio por día (últimas 2 semanas)"),
                              ("Maquinaria", "Maquinaria activa promedio por día (últimas 2 semanas)")):
            p = _rec.plantilla_diaria(det, clase)
            if p.empty:
                continue
            p = p[p["fecha"] >= desde]
            if p.empty:
                continue
            tipos = [c for c in p.columns if c not in ("fecha", "puente", "TOTAL")]
            filas = []
            for pte, g in p.groupby("puente"):
                prom = g[tipos].mean().sort_values(ascending=False)
                prom = prom[prom >= 0.5]
                filas.append([_chip(pte), _num(g["TOTAL"].mean(), 1),
                              _e(", ".join(f"{v:.0f} {t.lower()}" for t, v in prom.items()))])
            partes.append(f"<h3>{titulo}</h3>" + _tabla(["Puente", "Total promedio", "Por tipo"], filas, {1}))
        ina = _rec.equipo_inactivo(det)
        if ina is not None and not ina.empty:
            ina = ina[ina["último_día"] >= corte - _td(days=7)]
            if len(ina):
                partes.append("<h3>Equipo inactivo en la última semana</h3>" + "".join(
                    f"<div class='alerta'><b>{_e(r['tipo'])}</b> — {_e(r['descripción'])}: inactivo {r['días_inactivo']} días "
                    f"(del {_fecha(r['primer_día'])} al {_fecha(r['último_día'])})</div>" for _, r in ina.iterrows()))
        if prop is not None and not prop.empty:
            atr = prop[prop["situación"] == "Atrasado"]
            if len(atr):
                filas = [[_chip(r["puente"]), _e(r["concepto"]), _e(_corto(r["descripción"], 70)), _e(r["unidad"]),
                          f"{r['avance_vs_programa_%']:.0%}" if pd.notna(r["avance_vs_programa_%"]) else "",
                          _num(r["ritmo_observado_por_día"]), _num(r["ritmo_necesario_por_día"]),
                          _e(r["recurso_que_manda"]), _num(r["recurso_actual_promedio_4_sem"], 1),
                          _e("" if pd.isna(r["recurso_necesario"]) else int(r["recurso_necesario"])),
                          _e(r["comentario"])] for _, r in atr.iterrows()]
                partes.append(f"<h3>Conceptos atrasados contra el programa al {_fecha(corte)}</h3>"
                              "<p class='nota'>Ritmos por día hábil (lunes a sábado). Recurso necesario = recurso actual × "
                              "ritmo necesario ÷ ritmo observado, para terminar en el plazo del contrato.</p>" + _tabla(
                                  ["Puente", "No.", "Concepto", "Unidad", "Avance vs programa", "Ritmo actual/día",
                                   "Ritmo necesario/día", "Recurso que manda", "Actual", "Necesario", "Comentario"],
                                  filas, {1, 4, 5, 6, 8, 9}))
            falt = _rec.frentes_faltantes(prop)
            if not falt.empty:
                filas = []
                for pte, g in falt.groupby("puente"):
                    for _, r in g.head(8).iterrows():
                        filas.append([_chip(pte), _e(r["partida"]), _e(r["conceptos"]),
                                      "$" + _num(r["importe_programado_al_corte"]), _e(_corto(r["principales"], 160))])
                partes.append("<h3>Partidas programadas al corte sin actividad en los reportes</h3>"
                              "<p class='nota'>Solo refleja lo que se reporta en WhatsApp; confirmar en campo antes de "
                              "proponer. Se muestran las 8 de mayor importe por puente.</p>" + _tabla(
                                  ["Puente", "Partida", "Conceptos", "Importe programado al corte", "Principales conceptos"],
                                  filas, {2, 3}))
        if rend is not None and not rend.empty:
            ext = rend[rend["posible_extraordinario"] == "Sí"].sort_values("jornadas_de_frente", ascending=False).head(15)
            if len(ext):
                filas = [[_chip(r["puente"]), _e(r["agrupación"].replace("Actividad: ", "").capitalize()),
                          _e(r["jornadas_de_frente"]), _e(r["cuadrilla_típica"]), _e(r["equipo_típico"]),
                          _e(r["hombres_día"]),
                          (_num(r["rendimiento_por_jornada"]) + " " + _e(r["unidad"])) if pd.notna(r["rendimiento_por_jornada"]) else ""]
                         for _, r in ext.iterrows()]
                partes.append("<h3>Posibles conceptos extraordinarios (sin concepto claro en catálogo)</h3>"
                              "<p class='nota'>Cuadrilla y equipo típicos por jornada de frente, según los reportes: base "
                              "para integrar la tarjeta de precio unitario. Detalle completo en recursos_*.xlsx.</p>" + _tabla(
                                  ["Puente", "Actividad", "Jornadas", "Cuadrilla típica", "Equipo típico", "Hombres-día",
                                   "Rendimiento/jornada"], filas, {2, 5}))
        partes.append("</section>")

    # Incidencias y pendientes
    inc = texto[texto["incidencia"]].sort_values("fecha_hora", ascending=False)
    pen = texto[texto["pendiente"]].sort_values("fecha_hora", ascending=False)
    if len(inc) or len(pen):
        partes.append("<section><h2>Incidencias y pendientes</h2>")
        for titulo, sub, n in (("⚠️ Incidencias", inc, 40), ("📌 Pendientes recientes", pen, 30)):
            if len(sub):
                filas = [[_fecha(r["fecha"]), _chip(r.get("puente") or ""), _e(r["autor"]), _e(r.get("grupo", "")),
                          f"<span class='msg'>{_e(_corto(r['texto']))}</span>"] for _, r in sub.head(n).iterrows()]
                partes.append(f"<h3>{titulo} <span class='nota'>({len(sub)} en total, se muestran {min(n, len(sub))})</span></h3>"
                              + _tabla(["Fecha", "Puente", "Autor", "Grupo", "Mensaje"], filas))
        partes.append("</section>")

    # Bitácora por día (más reciente primero)
    partes.append("<section><h2>Bitácora por día</h2><p class='nota'>Haz clic en un día para ver el detalle. "
                  "Los días abiertos son los que se imprimen.</p>")
    for k, (dia, g) in enumerate(sorted(df.groupby("fecha"), key=lambda x: x[0], reverse=True)):
        a = actividades[actividades["fecha"] == dia] if not actividades.empty else actividades
        t = g[~g["adjunto"] & ~g["es_reporte"]]
        n_fotos = int(g["adjunto"].sum())
        partes.append(f"<details{' open' if k < 3 else ''}><summary>{_fecha_larga(dia)} "
                      f"<span class='meta'>· {len(a)} actividades · {len(t)} mensajes · {n_fotos} fotos</span>"
                      f"</summary><div class='dia'>")
        if len(a):
            for pte, ga in a.groupby("puente"):
                partes.append(f"<h3>{_chip(pte)}</h3><ul>")
                for _, r in ga.iterrows():
                    cant = f" <b>[{_e(r['cantidades'])}]</b>" if r.get("cantidades") else ""
                    conc = (f" <span class='meta'>→ concepto {_e(r['concepto_no'])}</span>"
                            if r.get("confianza") in ("Alta", "Media") and pd.notna(r.get("concepto_no")) else "")
                    partes.append(f"<li><b>{_e(r['frente'])}:</b> {_e(_corto(r['actividad'], 260))}{cant}{conc}</li>")
                partes.append("</ul>")
        rel = t[t["categorias"].ne("") | t["incidencia"] | t["pendiente"]]
        if len(rel):
            partes.append("<h3>Mensajes relevantes</h3><ul>")
            for _, r in rel.head(25).iterrows():
                marca = "⚠️ " if r["incidencia"] else "📌 " if r["pendiente"] else ""
                partes.append(f"<li class='msg'>{marca}<span class='meta'>{_e(r['hora'])} · {_e(r['autor'])}"
                              f"{' · ' + _e(r['grupo']) if r.get('grupo') else ''}:</span> {_e(_corto(r['texto'], 280))}</li>")
            if len(rel) > 25:
                partes.append(f"<li class='meta'>… y {len(rel) - 25} mensajes más en el Excel.</li>")
            partes.append("</ul>")
        partes.append("</div></details>")
    partes.append("</section>")
    partes.append(f"<footer>Generado el {datetime.now():%d/%m/%Y %H:%M} con whatsapp_resumen.py a partir de los "
                  "chats exportados de WhatsApp. Las clasificaciones son automáticas: revisar contra bitácora, "
                  "formatos de liberación y números generadores.</footer></div></body></html>")
    ruta.write_text("".join(partes), encoding="utf-8")


NAVEGADORES = [
    "google-chrome", "chromium", "chromium-browser", "msedge", "/opt/pw-browsers/chromium",
    r"C:\Program Files\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
    r"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
]


def _pdf_con_navegador(html_ruta: Path, pdf_ruta: Path) -> bool:
    """Imprime a PDF con Chrome/Edge instalado (modo sin ventana)."""
    import shutil
    import subprocess
    for nav in NAVEGADORES:
        exe = shutil.which(nav) or (nav if Path(nav).exists() else None)
        if not exe:
            continue
        try:
            subprocess.run([exe, "--headless", "--no-sandbox", "--disable-gpu", "--no-pdf-header-footer",
                            f"--print-to-pdf={pdf_ruta.resolve()}", html_ruta.resolve().as_uri()],
                           check=True, capture_output=True, timeout=120)
            return pdf_ruta.exists()
        except Exception:
            continue
    return False


def html_a_pdf(html_ruta: Path, pdf_ruta: Path) -> bool:
    """Convierte el HTML a PDF con Playwright o, si no está, con Chrome/Edge. Devuelve True si lo logró."""
    try:
        from playwright.sync_api import sync_playwright
    except ImportError:
        return _pdf_con_navegador(html_ruta, pdf_ruta)
    try:
        with sync_playwright() as p:
            nav = p.chromium.launch()
            pag = nav.new_page()
            pag.goto(html_ruta.resolve().as_uri())
            pag.pdf(path=str(pdf_ruta), format="Letter", landscape=False, print_background=True,
                    margin={"top": "12mm", "bottom": "14mm", "left": "10mm", "right": "10mm"},
                    display_header_footer=True, header_template="<span></span>",
                    footer_template="<div style='font-size:8px;color:#777;width:100%;text-align:center'>"
                                    "Página <span class='pageNumber'></span> de <span class='totalPages'></span></div>")
            nav.close()
        return True
    except Exception as exc:
        print(f"   (no se generó el PDF: {exc})")
        return False
