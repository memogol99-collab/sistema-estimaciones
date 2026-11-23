"""
Personal y maquinaria por tipo, rendimientos por actividad y propuesta de
recursos para recuperar el programa de obra.

Todo sale de los "Reporte de actividades" de WhatsApp. Los rendimientos son
observados (cantidad reportada entre jornadas de frente) y sirven como base
para analizar precios extraordinarios y proponer recursos; hay que validarlos
con bitácora, generadores y tarjetas de precios.
"""

import math
import re
import unicodedata
from collections import Counter, defaultdict
from datetime import date, timedelta

import pandas as pd


def _norm(t: str) -> str:
    t = unicodedata.normalize("NFD", str(t or "").lower())
    return "".join(c for c in t if unicodedata.category(c) != "Mn")


# --------------------------------------------------------------------------
# TIPOS DE PERSONAL Y DE EQUIPO
# --------------------------------------------------------------------------
# (patrón, tipo normalizado). Se revisan en orden; gana el primero que coincida.
MAQUINAS = [
    (r"perforadora", "Perforadora de pilas"),
    (r"gr[uú]a.*(spandeck|mantis|oruga)|(spandeck|mantis).*gr[uú]a", "Grúa de orugas"),
    (r"hiab", "Grúa HIAB (articulada)"),
    (r"gr[uú]a", "Grúa"),
    (r"retroexcavadora|retro\b", "Retroexcavadora"),
    (r"excavadora", "Excavadora"),
    (r"motoconformadora|motoniveladora", "Motoconformadora"),
    (r"vibro\s*compact|vibrocompac|rodillo", "Vibrocompactador"),
    (r"volteo|cami[oó]n", "Camión volteo"),
    (r"pipa", "Pipa de agua"),
    (r"cisterna", "Cisterna"),
    (r"bailarina|apisonador", "Bailarina (compactador manual)"),
    (r"rotomartillo", "Rotomartillo"),
    (r"martillo", "Martillo demoledor"),
    (r"generador|planta de luz", "Generador"),
    (r"bomba sumergible", "Bomba sumergible"),
    (r"motobomba|bomba", "Motobomba"),
    (r"cortadora de acero|dobladora", "Cortadora/dobladora de acero"),
    (r"cortadora", "Cortadora de concreto"),
    (r"sierra", "Sierra"),
    (r"revolvedora", "Revolvedora"),
    (r"compresor", "Compresor"),
    (r"soldadora|planta de soldar", "Máquina de soldar"),
    (r"vactor", "Camión vactor"),
    (r"cama baja|plataforma", "Cama baja / plataforma"),
    (r"herramienta menor|palas|picos|carretilla", "Herramienta menor"),
]
EQUIPO_MAYOR = {"Perforadora de pilas", "Grúa de orugas", "Grúa HIAB (articulada)", "Grúa", "Retroexcavadora",
                "Excavadora", "Motoconformadora", "Vibrocompactador", "Camión volteo", "Pipa de agua",
                "Camión vactor", "Cama baja / plataforma"}

PERSONAS = [
    (r"operador|\bop\.?\s", None),  # se arma como "Operador de <máquina>"
    (r"residente de perforaci", "Residente de perforación"),
    (r"residente de demolici", "Residente de demolición"),
    (r"auxiliar(es)? de residente", "Auxiliar de residente"),
    (r"residente", "Residente de obra"),
    (r"auxiliar(es)? de top[oó]grafo|cadenero|estadalero", "Auxiliar de topografía"),
    (r"top[oó]grafo", "Topógrafo"),
    (r"auxiliar(es)? de segurista", "Auxiliar de seguridad"),
    (r"segurista|seguridad", "Segurista"),
    (r"auxiliar(es)? de perforaci", "Auxiliar de perforación"),
    (r"auxiliar(es)?( de)? gr[uú]a|maniobrista", "Auxiliar de grúa / maniobrista"),
    (r"pailer", "Pailero"),
    (r"bi[oó]log|ambiental", "Especialista ambiental"),
    (r"fierrer|armador", "Oficial fierrero"),
    (r"carpinter", "Carpintero"),
    (r"alba[nñ]il", "Albañil"),
    (r"soldador", "Soldador"),
    (r"ayudantes? de liniero", "Ayudante de liniero"),
    (r"liniero", "Liniero"),
    (r"especialista|t[eé]cnicos? instalador|plomer|tuber", "Técnico instalador de tubería"),
    (r"banderer", "Banderero(a)"),
    (r"almacenista", "Almacenista"),
    (r"checador", "Checador"),
    (r"laboratorista", "Laboratorista"),
    (r"electricista", "Electricista"),
    (r"acarrer", "Acarreador"),
    (r"y?udante|pe[oó]n", "Ayudante general"),
    (r"oficial", "Oficial"),
]
NO_ES_PERSONAL = re.compile(r"armad|pilas?\b|colad|m3|viaje|complet|apoyo")

RE_CANT = re.compile(r"^(\d+)\s+(.*)$")


def tipo_maquina(texto: str) -> str | None:
    n = _norm(texto)
    for patron, tipo in MAQUINAS:
        if re.search(patron, n):
            return tipo
    return None


def tipo_persona(texto: str) -> str | None:
    """Tipo de persona; None si la línea no es de personal (un avance o un equipo puesto en la lista)."""
    n = _norm(texto)
    for patron, tipo in PERSONAS:
        if re.search(patron, n):
            if tipo is None:
                maq = tipo_maquina(re.sub(r".*(operador(es)?|\bop\.?)\s+(de\s+)?", "", n).replace("exacadora", "excavadora"))
                return f"Operador de {maq.lower()}" if maq else "Operador de equipo"
            return tipo
    if NO_ES_PERSONAL.search(n) or tipo_maquina(n):
        return None
    return texto.strip().capitalize()[:40]


def _partir_equipo(lineas: list[str]) -> list[tuple[int, str]]:
    """Las líneas de equipo vienen como '1 Excavadora' o 'Herramienta menor. Perforadora SANY. Retro CAT 416.'"""
    out = []
    for l in lineas:
        for parte in re.split(r"\.\s+|,\s*(?=[A-ZÁÉÍÓÚ])", l):
            parte = parte.strip(" .,;")
            if not parte or parte.endswith(":") or len(parte) < 3 or re.fullmatch(r"\(?inactiv[oa]s?\)?", _norm(parte)):
                continue
            m = RE_CANT.match(parte)
            out.append((int(m[1]), m[2]) if m else (1, parte))
    return out


def _filas(lineas: list[str], clase_por_defecto: str) -> list[dict]:
    filas = []
    if clase_por_defecto == "Mano de obra":
        for l in lineas:
            m = RE_CANT.match(l.strip(" .,;"))
            if not m:
                continue
            inactivo = "inactiv" in _norm(l)
            tipo = tipo_persona(m[2])
            if tipo is None:
                maq = tipo_maquina(m[2])
                if maq and maq != "Herramienta menor":  # equipo anotado en la lista de personal
                    filas.append({"clase": "Maquinaria" if maq in EQUIPO_MAYOR else "Equipo menor", "tipo": maq,
                                  "cantidad": int(m[1]), "descripción": m[2].strip(" .,;"), "inactivo": inactivo})
                continue
            filas.append({"clase": "Mano de obra", "tipo": tipo, "cantidad": int(m[1]),
                          "descripción": m[2].strip(" .,;"), "inactivo": inactivo})
    else:
        for cant, desc in _partir_equipo(lineas):
            tipo = tipo_maquina(desc) or desc.strip().capitalize()[:40]
            clase = ("Herramienta menor" if tipo == "Herramienta menor"
                     else "Maquinaria" if tipo in EQUIPO_MAYOR else "Equipo menor")
            filas.append({"clase": clase, "tipo": tipo, "cantidad": cant, "descripción": desc,
                          "inactivo": "inactiv" in _norm(desc)})
    return filas


def detalle_recursos(reportes: pd.DataFrame, actividades: pd.DataFrame) -> pd.DataFrame:
    """Una fila por línea de personal o equipo, del encabezado general o de cada frente."""
    filas = []
    for _, r in reportes.iterrows():
        sec = r.get("secciones") or {}
        for nombre, clase in (("personal", "Mano de obra"), ("mano de obra", "Mano de obra"),
                              ("maquinaria", "Maquinaria"), ("equipo menor", "Equipo menor"),
                              ("equipo y maquinaria", "Maquinaria")):
            for f in _filas(sec.get(nombre, []), clase):
                filas.append({"fecha": r["fecha"], "puente": r["puente"], "obra": r["obra"], "reportó": r["autor"], "nivel": "General",
                              "frente": "", "actividad": "", **f})
    for _, a in actividades.iterrows():
        for lineas, clase in ((a.get("personal_lineas") or [], "Mano de obra"), (a.get("equipo_lineas") or [], "Maquinaria")):
            for f in _filas(lineas, clase):
                filas.append({"fecha": a["fecha"], "puente": a["puente"], "obra": a["obra"], "reportó": a["reportó"], "nivel": "Frente",
                              "frente": a["frente"], "actividad": a["actividad"], **f})
    return pd.DataFrame(filas)


def plantilla_diaria(det: pd.DataFrame, clase: str) -> pd.DataFrame:
    """Recursos activos por día y tipo. Usa el encabezado general del reporte; si ese día y obra
    no lo trae, suma lo reportado en los frentes."""
    if det.empty:
        return pd.DataFrame()
    d = det[(det["clase"] == clase) & ~det["inactivo"]]
    gen = d[d["nivel"] == "General"]
    con_general = set(zip(gen["fecha"], gen["obra"], gen["reportó"]))
    fre = d[(d["nivel"] == "Frente") & ~pd.Series([k in con_general for k in zip(d["fecha"], d["obra"], d["reportó"])],
                                                    index=d.index)]
    base = pd.concat([gen, fre])
    if base.empty:
        return pd.DataFrame()
    tabla = base.pivot_table(index=["fecha", "puente"], columns="tipo", values="cantidad", aggfunc="sum", fill_value=0)
    tabla["TOTAL"] = tabla.sum(axis=1)
    return tabla.reset_index().sort_values(["fecha", "puente"])


def resumen_semanal(det: pd.DataFrame) -> pd.DataFrame:
    filas = []
    for clase in ("Mano de obra", "Maquinaria", "Equipo menor"):
        p = plantilla_diaria(det, clase)
        if p.empty:
            continue
        p["semana"] = p["fecha"].apply(lambda f: f - timedelta(days=f.weekday()))
        tipos = [c for c in p.columns if c not in ("fecha", "puente", "semana", "TOTAL")]
        for (sem, pte), g in p.groupby(["semana", "puente"]):
            for t in tipos + ["TOTAL"]:
                v = g[t]
                if v.sum() == 0:
                    continue
                filas.append({"semana_del": sem, "puente": pte, "clase": clase, "tipo": t,
                              "promedio_diario": round(v.mean(), 1), "máximo": int(v.max()),
                              "días_presente": int((v > 0).sum()), "días_reportados": len(v)})
    return pd.DataFrame(filas)


def equipo_inactivo(det: pd.DataFrame) -> pd.DataFrame:
    if det.empty:
        return pd.DataFrame()
    d = det[det["inactivo"] & (det["clase"] != "Mano de obra")]
    if d.empty:
        return pd.DataFrame()
    g = d.groupby(["puente", "tipo", "descripción"])["fecha"]
    out = pd.DataFrame({"días_inactivo": g.nunique(), "primer_día": g.min(), "último_día": g.max()}).reset_index()
    return out.sort_values("días_inactivo", ascending=False)


# --------------------------------------------------------------------------
# RENDIMIENTOS
# --------------------------------------------------------------------------
_RUIDO = re.compile(r"\b(continua(cion)?( de| con)?|se continua|inicia(mos)?|inicio de|reinicio de|termina|"
                    r"concluye|sigue)\b")


def clave_actividad(texto: str) -> str:
    """'Continúa armado de pilas para Eje #5' → 'armado de pilas'."""
    t = _norm(texto)
    t = re.split(r"[.;(:]|,\s", t)[0]
    t = _RUIDO.sub(" ", t)
    t = re.sub(r"\b(en|para|del|de la|de los|entre|sobre)\s+(el\s+|la\s+|los\s+)?(eje|apoyo|zapata|pila|caballete|"
               r"tramo|frente|av|avenida|calle|area|cruce|km)\b.*", "", t)
    t = re.sub(r"#\s*\d+|\b\d+([.,]\d+)?\s*(m3|m|ml|plgs?|plg|''|\")?", " ", t)
    t = re.sub(r"\s+", " ", t).strip(" -,")
    palabras = t.split()
    return " ".join(palabras[:6]) or _norm(texto)[:40]


_UNIDAD = {"m3": "m3", "m³": "m3", "m2": "m2", "m²": "m2", "ml": "m", "m": "m", "mts": "m", "metros": "m",
           "viajes": "viajes", "kg": "kg", "ton": "ton", "pzas": "pza", "piezas": "pza", "tramos": "tramo"}


def _cantidades(texto: str) -> list[tuple[float, str]]:
    out = []
    for num, uni in re.findall(r"(\d+(?:[.,]\d+)?)\s*(m3|m³|m2|m²|ml|mts|metros|viajes|kg|ton|pzas|piezas|tramos|m)"
                               r"(?![a-z0-9²³])", str(texto), re.IGNORECASE):
        out.append((float(num.replace(",", ".")), _UNIDAD[uni.lower()]))
    return out


def _cuadrilla(det_frentes: pd.DataFrame, n_jornadas: int, clase: str) -> str:
    """Cuadrilla típica: promedio por jornada de cada tipo presente en al menos 1/3 de las jornadas."""
    d = det_frentes[(det_frentes["clase"] == clase) & ~det_frentes["inactivo"]]
    if d.empty or not n_jornadas:
        return ""
    por_tipo = d.groupby("tipo").agg(total=("cantidad", "sum"), jornadas=("clave_jornada", "nunique"))
    por_tipo = por_tipo[por_tipo["jornadas"] >= max(1, n_jornadas / 3)]
    por_tipo["prom"] = por_tipo["total"] / por_tipo["jornadas"]
    por_tipo = por_tipo.sort_values("prom", ascending=False)
    return ", ".join(f"{p:.0f} {t.lower()}" if p >= 1 else f"{p:.1f} {t.lower()}"
                     for t, p in zip(por_tipo.index, por_tipo["prom"]))


def rendimientos(actividades: pd.DataFrame, det: pd.DataFrame, pilas_vs_cat: pd.DataFrame | None = None) -> pd.DataFrame:
    """Agrupa las actividades por concepto (si la asignación es confiable) o por tipo de actividad
    y calcula jornadas, cuadrilla típica, equipo típico y rendimiento observado."""
    if actividades.empty:
        return pd.DataFrame()
    a = actividades.copy()
    a["clave_jornada"] = a["fecha"].astype(str) + "|" + a["obra"] + "|" + a["reportó"] + "|" + a["frente"]
    confiable = a.get("confianza", pd.Series("", index=a.index)).isin(["Alta", "Media"])
    a["grupo_rend"] = [
        f"Concepto {int(n)}" if ok and pd.notna(n) else f"Actividad: {clave_actividad(t)}"
        for ok, n, t in zip(confiable, a.get("concepto_no", pd.Series(None, index=a.index)), a["actividad"])]
    dfr = det[det["nivel"] == "Frente"].copy() if not det.empty else pd.DataFrame()
    if not dfr.empty:
        dfr["clave_jornada"] = dfr["fecha"].astype(str) + "|" + dfr["obra"] + "|" + dfr["reportó"] + "|" + dfr["frente"]
    filas = []
    for (pte, grupo), g in a.groupby(["puente", "grupo_rend"]):
        jornadas = g["clave_jornada"].nunique()
        dg = dfr[dfr["clave_jornada"].isin(set(g["clave_jornada"]))] if not dfr.empty else dfr
        hombres_dia = int(dg[(dg["clase"] == "Mano de obra") & ~dg["inactivo"]]["cantidad"].sum()) if not dg.empty else 0
        unidades = Counter()
        sumas = defaultdict(float)
        for t in g["actividad"]:
            for v, u in _cantidades(t):
                unidades[u] += 1
                sumas[u] += v
        unidad = ""
        if unidades:
            unidad = max(unidades, key=lambda u: (u == "m3", unidades[u]))
        cantidad = sumas.get(unidad) if unidad else None
        if unidad == "m":  # en perforación los metros son profundidad acumulada, no avance del día
            cantidad = None
        concepto = g["concepto_sugerido"].iloc[0] if "concepto_sugerido" in g and grupo.startswith("Concepto") else ""
        unidad_conc = g["unidad_concepto"].iloc[0] if "unidad_concepto" in g and grupo.startswith("Concepto") else ""
        u_conc = _UNIDAD.get(_norm(unidad_conc).strip(), _norm(unidad_conc).strip()) if unidad_conc else ""
        if grupo.startswith("Concepto") and u_conc and unidad and unidad != u_conc:
            cantidad, unidad = None, u_conc  # la cantidad del texto no está en la unidad del concepto
        # Perforación de pilas: usar los metros depurados de la tabla de pilas
        if pilas_vs_cat is not None and not pilas_vs_cat.empty and grupo.startswith("Concepto"):
            fila = pilas_vs_cat[(pilas_vs_cat["puente"] == pte) & (pilas_vs_cat["concepto"] == int(grupo.split()[1]))]
            if len(fila) and pd.notna(fila["cantidad_según_whatsapp"].iloc[0]):
                cantidad, unidad = float(fila["cantidad_según_whatsapp"].iloc[0]), str(fila["unidad"].iloc[0])
        ejemplo = g.sort_values("fecha")["actividad"].iloc[-1]
        filas.append({
            "puente": pte, "agrupación": grupo, "concepto_catálogo": concepto,
            "posible_extraordinario": "Sí" if not grupo.startswith("Concepto") else "",
            "primera_fecha": g["fecha"].min(), "última_fecha": g["fecha"].max(),
            "días_con_actividad": g["fecha"].nunique(), "jornadas_de_frente": jornadas,
            "cuadrilla_típica": _cuadrilla(dg, jornadas, "Mano de obra") if not dg.empty else "",
            "equipo_típico": (_cuadrilla(dg, jornadas, "Maquinaria") + (", " if not dg.empty and _cuadrilla(dg, jornadas, "Equipo menor") and _cuadrilla(dg, jornadas, "Maquinaria") else "")
                              + _cuadrilla(dg, jornadas, "Equipo menor")) if not dg.empty else "",
            "hombres_día": hombres_dia, "cantidad_reportada": cantidad, "unidad": unidad or unidad_conc,
            "rendimiento_por_jornada": (cantidad / jornadas) if cantidad and jornadas else None,
            "rendimiento_por_hombre_día": (cantidad / hombres_dia) if cantidad and hombres_dia else None,
            "ejemplo_de_actividad": ejemplo,
        })
    out = pd.DataFrame(filas)
    return out.sort_values(["puente", "posible_extraordinario", "jornadas_de_frente"], ascending=[True, False, False])


# --------------------------------------------------------------------------
# PROGRAMA VS REAL Y PROPUESTA DE RECURSOS
# --------------------------------------------------------------------------
def dias_habiles(desde: date, hasta: date) -> int:
    """Días de lunes a sábado entre dos fechas (incluye ambas)."""
    if hasta < desde:
        return 0
    return sum(1 for i in range((hasta - desde).days + 1) if (desde + timedelta(days=i)).weekday() < 6)


def programado_al_corte(programa: pd.DataFrame, corte: date) -> pd.DataFrame:
    """Cantidad programada acumulada por concepto a la fecha de corte (el mes en curso se prorratea por días)."""
    if programa.empty:
        return pd.DataFrame()
    p = programa.copy()

    def factor(mes: date) -> float:
        fin_mes = (mes.replace(day=28) + timedelta(days=4)).replace(day=1) - timedelta(days=1)
        if corte >= fin_mes:
            return 1.0
        if corte < mes:
            return 0.0
        return corte.day / fin_mes.day

    p["factor"] = p["mes"].apply(factor)
    p["al_corte"] = p["cantidad_programada"] * p["factor"]
    return p.groupby(["puente", "no"]).agg(programado_total=("cantidad_programada", "sum"),
                                           programado_al_corte=("al_corte", "sum")).reset_index()


# Recurso que "manda" el ritmo de cada concepto (para proponer cuántos más hacen falta)
RECURSO_CLAVE = [
    (r"perforaci[oó]n para alojar pilas", "Perforadora de pilas", "Maquinaria"),
    (r"pilas de cimentaci[oó]n", "Perforadora de pilas", "Maquinaria"),  # concreto y acero de pilas siguen a la perforación
    (r"concreto fluido", "Perforadora de pilas", "Maquinaria"),
    (r"zapatas|columnas|cabezales", "Oficial fierrero", "Mano de obra"),
    (r"terraplen|subrasante|subyacente", "Camión volteo", "Maquinaria"),
    (r"tuber[ií]a", "Técnico instalador de tubería", "Mano de obra"),
    (r"ductos|registro|media tension|baja tension", "Liniero", "Mano de obra"),
]


def _recurso_en_frentes(det: pd.DataFrame, actividades: pd.DataFrame, puente: str, no: int, recurso: str,
                        desde: date) -> float | None:
    """Promedio diario del recurso en los frentes que ejecutaron el concepto (días con actividad)."""
    if det.empty or actividades.empty or "concepto_no" not in actividades:
        return None
    a = actividades[(actividades["puente"] == puente) & (actividades["concepto_no"] == no) & (actividades["fecha"] >= desde)]
    if a.empty:
        return None
    claves = set(zip(a["fecha"], a["obra"], a["reportó"], a["frente"]))
    d = det[(det["nivel"] == "Frente") & (det["tipo"] == recurso) & ~det["inactivo"]]
    d = d[[k in claves for k in zip(d["fecha"], d["obra"], d["reportó"], d["frente"])]]
    if d.empty:
        return None
    por_dia = d.groupby("fecha")["cantidad"].sum().reindex(sorted(set(a["fecha"])), fill_value=0)
    return float(por_dia.mean())


def propuesta_recursos(conceptos: pd.DataFrame, programa: pd.DataFrame, avance: pd.DataFrame,
                       det: pd.DataFrame, contratos: list[dict], corte: date, fin_por_puente: dict,
                       actividades: pd.DataFrame | None = None) -> pd.DataFrame:
    """Para cada concepto programado al corte: avance según WhatsApp, atraso, ritmo necesario para
    terminar en plazo y recursos adicionales sugeridos (si se conoce el recurso que manda)."""
    if programa.empty:
        return pd.DataFrame()
    prog = programado_al_corte(programa, corte)
    prog = prog[prog["programado_al_corte"] > 0]
    c = conceptos.merge(prog, on=["puente", "no"], how="inner")
    if avance is not None and not avance.empty:
        c = c.merge(avance.rename(columns={"concepto": "no"})[["puente", "no", "ejecutado_whatsapp", "fuente_avance",
                                                               "días_con_actividad", "primera_fecha", "última_fecha"]],
                    on=["puente", "no"], how="left")
    else:
        for k in ("ejecutado_whatsapp", "fuente_avance", "días_con_actividad", "primera_fecha", "última_fecha"):
            c[k] = None
    activos = plantilla_diaria(det, "Maquinaria") if not det.empty else pd.DataFrame()
    personal = plantilla_diaria(det, "Mano de obra") if not det.empty else pd.DataFrame()
    filas = []
    for _, r in c.iterrows():
        pu = r["precio_unitario"] if isinstance(r["precio_unitario"], (int, float)) else 0
        prog_imp = r["programado_al_corte"] * pu
        ejec = r["ejecutado_whatsapp"] if pd.notna(r.get("ejecutado_whatsapp")) else None
        dias_act = r.get("días_con_actividad")
        if ejec is None and (pd.isna(dias_act) or not dias_act):
            situacion = "Sin actividad reportada"
        elif ejec is None:
            situacion = "Con actividad, sin cantidad reportada"
        elif ejec + 1e-9 >= r["programado_al_corte"]:
            situacion = "Al corriente"
        else:
            situacion = "Atrasado"
        fin = fin_por_puente.get(r["puente"])
        dias_rest = dias_habiles(corte + timedelta(days=1), fin) if fin else None
        restante = (r["cantidad"] - ejec) if (ejec is not None and isinstance(r["cantidad"], (int, float))) else None
        ritmo_req = (restante / dias_rest) if restante and dias_rest else None
        ritmo_obs, recurso, actual, necesarios, nota = None, "", None, None, ""
        if ejec and pd.notna(r.get("primera_fecha")):
            dias_obs = dias_habiles(r["primera_fecha"], corte)
            ritmo_obs = ejec / dias_obs if dias_obs else None
        desc = _norm(f"{r['texto_padre']} {r['descripción']}")
        for patron, rec, clase in RECURSO_CLAVE:
            if re.search(patron, desc):
                recurso = rec
                acts = actividades if actividades is not None else pd.DataFrame()
                desde = corte - timedelta(days=28)
                en_frentes = _recurso_en_frentes(det, acts, r["puente"], int(r["no"]), rec, desde)
                if not en_frentes and clase == "Maquinaria":  # a veces solo se anota el operador
                    en_frentes = _recurso_en_frentes(det, acts, r["puente"], int(r["no"]), f"Operador de {rec.lower()}", desde)
                general = None
                tabla = activos if clase == "Maquinaria" else personal
                if not tabla.empty and rec in tabla.columns:
                    t = tabla[(tabla["puente"] == r["puente"]) & (tabla["fecha"] >= desde)]
                    if len(t) and t[rec].mean() > 0:
                        general = float(t[rec].mean())
                # Maquinaria: manda lo que hay en obra (encabezado del reporte); personal: lo que trabaja en esos frentes
                actual = (max(x for x in (general, en_frentes) if x) if (general or en_frentes) else None) \
                    if clase == "Maquinaria" else (en_frentes or general)
                actual = round(actual, 1) if actual else None
                break
        if ritmo_req and ritmo_obs:
            factor = ritmo_req / ritmo_obs
            if factor <= 1:
                nota = "El ritmo actual alcanza para terminar en plazo"
            elif factor > 6:
                nota = (f"El ritmo actual cubre {1 / factor:.0%} de lo necesario: hace falta abrir frentes completos "
                        "(cuadrilla + equipo), no solo reforzar")
            elif actual:
                necesarios = math.ceil(actual * factor)
                nota = f"Multiplicar el ritmo actual × {factor:.1f}"
                if not det.empty:
                    ina = det[det["inactivo"] & (det["tipo"] == recurso) & (det["puente"] == r["puente"])
                              & (det["fecha"] >= corte - timedelta(days=7))]
                    if len(ina):
                        n_ina = int(ina.groupby("fecha")["cantidad"].sum().max())  # inactivas a la vez
                        nota += (f". En la última semana hubo hasta {n_ina} {recurso.lower()} inactiva(s) en obra: "
                                 "reactivarla(s) cubre parte del adicional")
        elif situacion == "Sin actividad reportada":
            nota = "Frente sin abrir según los reportes: programar cuadrilla y equipo"
        filas.append({
            "puente": r["puente"], "concepto": int(r["no"]), "descripción": (f"{r['texto_padre']} {r['descripción']}".strip()
                                                                           if len(str(r["descripción"])) < 40 else r["descripción"]),
            "unidad": r["unidad"], "cantidad_catálogo": r["cantidad"],
            "programado_al_corte": round(r["programado_al_corte"], 2),
            "importe_programado_al_corte": prog_imp,
            "ejecutado_según_whatsapp": ejec, "fuente_del_avance": r.get("fuente_avance") or "",
            "avance_vs_programa_%": (ejec / r["programado_al_corte"]) if ejec is not None and r["programado_al_corte"] else None,
            "situación": situacion, "días_con_actividad": dias_act if pd.notna(dias_act) else 0,
            "ritmo_observado_por_día": ritmo_obs, "días_hábiles_restantes": dias_rest,
            "ritmo_necesario_por_día": ritmo_req, "recurso_que_manda": recurso,
            "recurso_actual_promedio_4_sem": actual, "recurso_necesario": necesarios,
            "recurso_adicional_sugerido": (necesarios - math.ceil(actual)) if necesarios and actual and necesarios > actual else None,
            "comentario": nota, "partida": r["partida"] or r["bloque"],
        })
    out = pd.DataFrame(filas)
    orden = {"Atrasado": 0, "Sin actividad reportada": 1, "Con actividad, sin cantidad reportada": 2, "Al corriente": 3}
    out["_o"] = out["situación"].map(orden)
    return out.sort_values(["puente", "_o", "importe_programado_al_corte"], ascending=[True, True, False]).drop(columns="_o")


def frentes_faltantes(propuesta: pd.DataFrame) -> pd.DataFrame:
    """Partidas que ya deberían llevar avance según el programa y no tienen actividad en los reportes,
    agrupadas por partida y ordenadas por importe programado."""
    if propuesta.empty:
        return propuesta
    p = propuesta[propuesta["situación"] == "Sin actividad reportada"]
    g = p.groupby(["puente", "partida"]).agg(conceptos=("concepto", "count"),
                                             importe_programado_al_corte=("importe_programado_al_corte", "sum"),
                                             principales=("descripción", lambda d: " | ".join(
                                                 str(x)[:70] for x in d.head(3)))).reset_index()
    return g.sort_values(["puente", "importe_programado_al_corte"], ascending=[True, False])
