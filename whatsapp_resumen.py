"""
Resumen de avances de obra a partir de chats exportados de WhatsApp.

Uso rápido:
    python whatsapp_resumen.py whatsapp/                # procesa todos los .txt / .zip de la carpeta
    python whatsapp_resumen.py "Chat de WhatsApp con Frente 1.zip" --desde 2026-11-01
    python whatsapp_resumen.py whatsapp/ --desde 2026-11-16 --hasta 2026-11-22 --salida reportes/

Genera por cada grupo:
    - resumen_<grupo>.xlsx  (hojas: Resumen diario, Mensajes, Incidencias, Pendientes,
                             Cantidades, Por autor, Adjuntos)
    - resumen_<grupo>.md    (reporte legible, día por día, agrupado por categoría)

Acepta exportaciones de Android y iPhone, en español o inglés, formato 12 h o 24 h.
Las categorías y palabras clave se pueden ajustar en el diccionario CATEGORIAS.
"""

import argparse
import difflib
import re
import sys
import unicodedata
import zipfile
from collections import Counter, defaultdict
from datetime import datetime, date
from pathlib import Path

import pandas as pd

# --------------------------------------------------------------------------
# CONFIGURACIÓN: categorías y palabras clave (sin acentos, en minúsculas).
# Una palabra que termina en "*" coincide como prefijo (ej. "colad*" -> colado, colada).
# --------------------------------------------------------------------------
CATEGORIAS = {
    "Colado / Concreto": ["colad*", "colar", "concreto", "revenimiento", "olla*", "bombeo",
                          "cilindro*", "f'c", "fc", "vibrad*", "curado"],
    "Acero / Armado": ["armad*", "acero", "varilla*", "habilitad*", "estribos", "traslape*",
                       "parrilla*", "anclaje*"],
    "Cimbra": ["cimbra*", "descimbr*", "molde*", "obra falsa"],
    "Pilas / Cimentación": ["pila", "pilas", "perforacion*", "perforad*", "ademe", "bentonit*",
                            "zapata*", "cabezal*", "pilote*", "cimentacion", "dado*"],
    "Estructura / Puente": ["trabe*", "losa*", "columna*", "caballete*", "neopreno*", "montaje",
                            "aleros", "diafragma*", "parapeto*", "junta* de dilatacion", "apoyo*", "spandeck", "mensula*",
                            "muro respaldo", "descabece", "izad*", "izaje", "plantilla"],
    "Terracerías / Excavación": ["excavacion*", "excavad*", "terraplen*", "relleno*", "compact*",
                                 "terraceria*", "despalme", "corte", "cortes", "acarreo*",
                                 "subrasante", "base hidraulica", "subbase"],
    "Pavimentos": ["carpeta", "asfalt*", "riego de liga", "riego de impregnacion", "pavimento*",
                   "fresado", "bacheo"],
    "Instalaciones / Obras complementarias": ["alcantarilla*", "cuneta*", "lavadero*", "tubo*", "tuberia*",
                                              "drenaje", "contracuneta*", "bordillo*", "ducto*", "registro*",
                                              "cfe", "fibra optica", "valvula*", "sanitari*", "agua potable",
                                              "banqueta*", "guarnicion*", "alumbrado"],
    "Demolición": ["demolicion*", "demoler", "demolid*"],
    "Vialidad / Desvíos": ["desvio*", "banderer*", "señalamiento", "barrera*", "transito", "cierre de"],
    "Materiales / Suministros": ["llego", "llegaron", "suministro*", "entrega*", "material*",
                                 "pedido*", "remision*", "proveedor*", "cemento", "agregado*",
                                 "grava", "arena"],
    "Maquinaria / Equipo": ["maquinaria", "grua*", "retro*", "excavadora*", "motoconformadora*",
                            "vibrocompactador*", "pipa*", "volteo*", "camion*", "equipo",
                            "perforadora*", "planta"],
    "Personal": ["cuadrilla*", "personal", "trabajadores", "peon*", "oficial*", "destajo*",
                 "faltaron", "falto personal"],
    "Calidad / Laboratorio": ["laboratorio", "prueba*", "muestra*", "resistencia", "densidad*",
                              "calidad", "ensaye*", "topografia", "nivelacion", "trazo"],
    "Seguridad": ["accidente*", "incidente*", "epp", "seguridad", "lesion*", "lesionad*",
                  "riesgo*", "casco*"],
    "Clima": ["lluvia*", "llovio", "llueve", "lloviendo", "tormenta", "viento*"],
    "Estimación / Volúmenes": ["estimacion*", "generador*", "volumen*", "avance*", "cuantificacion",
                               "concepto*", "precio unitario"],
}

# Categorías especiales (se listan en hojas aparte)
INCIDENCIAS = ["problema*", "falla*", "fallo", "retraso*", "atras*", "detenid*", "paro", "parad*", "falta de pago", "sin pago", "se fue a la zanja",
               "suspend*", "no se pudo", "no llego", "no llegaron", "se descompuso", "descompuest*",
               "averia*", "urge", "urgente", "reclamo*", "rechaz*", "derrumbe*", "fuga*", "bloqueo*"]
PENDIENTES = ["pendiente*", "falta", "faltan", "manana", "programad*", "se requiere", "requerimos",
              "hay que", "necesitamos", "necesito", "por hacer", "se va a", "vamos a",
              "favor de", "solicito", "solicitamos"]

UNIDADES = r"(m3|m³|m2|m²|ml|m\.l\.|mts?|m|km|ton|tons|kg|pzas?|piezas|ollas?|viajes|lts?|litros|%|metros|hrs?|horas)"

# --------------------------------------------------------------------------
# PARSEO DE LA EXPORTACIÓN
# --------------------------------------------------------------------------
CARACTERES_INVISIBLES = dict.fromkeys(map(ord, "‎‏‪‫‬‭‮﻿"), None)

# Android: "22/11/26, 8:15 a. m. - Juan: texto"  |  "22/11/2026 08:15 - Juan: texto"
RE_ANDROID = re.compile(
    r"^(?P<fecha>\d{1,2}[/.\-]\d{1,2}[/.\-]\d{2,4}),?\s+"
    r"(?P<hora>\d{1,2}:\d{2}(?::\d{2})?)\s*(?P<ampm>[ap]\.?\s?m\.?)?\s+-\s+"
    r"(?P<resto>.*)$",
    re.IGNORECASE,
)
# iPhone: "[22/11/26, 8:15:30 a. m.] Juan: texto"
RE_IPHONE = re.compile(
    r"^\[(?P<fecha>\d{1,2}[/.\-]\d{1,2}[/.\-]\d{2,4}),?\s+"
    r"(?P<hora>\d{1,2}:\d{2}(?::\d{2})?)\s*(?P<ampm>[ap]\.?\s?m\.?)?\]\s+"
    r"(?P<resto>.*)$",
    re.IGNORECASE,
)

RE_ADJUNTO = re.compile(
    r"(<multimedia omitido>|<media omitted>|archivo adjunto|file attached|<adjunto:|<attached:|"
    r"imagen omitida|image omitted|video omitido|video omitted|audio omitido|audio omitted|"
    r"sticker omitido|sticker omitted|documento omitido|document omitted|\.(jpg|jpeg|png|mp4|opus|pdf|webp)\b)",
    re.IGNORECASE,
)


def sin_acentos(texto: str) -> str:
    texto = unicodedata.normalize("NFD", texto.lower())
    return "".join(c for c in texto if unicodedata.category(c) != "Mn")


def parsear_fecha(fecha: str, hora: str, ampm: str | None, mes_primero: bool) -> datetime | None:
    partes = re.split(r"[/.\-]", fecha)
    a, b, anio = (int(p) for p in partes)
    dia, mes = (b, a) if mes_primero else (a, b)
    if anio < 100:
        anio += 2000
    h_partes = [int(x) for x in hora.split(":")]
    h, m = h_partes[0], h_partes[1]
    s = h_partes[2] if len(h_partes) > 2 else 0
    if ampm:
        es_pm = ampm.lower().startswith("p")
        if es_pm and h < 12:
            h += 12
        if not es_pm and h == 12:
            h = 0
    try:
        return datetime(anio, mes, dia, h, m, s)
    except ValueError:
        return None


def leer_lineas(ruta: Path) -> tuple[str, list[str]]:
    """Devuelve (nombre_del_grupo, líneas) para un .txt o un .zip exportado."""
    if ruta.suffix.lower() == ".zip":
        with zipfile.ZipFile(ruta) as z:
            txts = [n for n in z.namelist() if n.lower().endswith(".txt")]
            if not txts:
                raise ValueError(f"{ruta.name}: el .zip no contiene ningún .txt de chat")
            contenido = z.read(txts[0]).decode("utf-8", errors="replace")
    else:
        contenido = ruta.read_text(encoding="utf-8", errors="replace")
    contenido = contenido.translate(CARACTERES_INVISIBLES).replace(" ", " ").replace(" ", " ")
    return nombre_grupo(ruta), contenido.splitlines()


def nombre_grupo(ruta: Path) -> str:
    nombre = ruta.stem
    for prefijo in ("Chat de WhatsApp con ", "WhatsApp Chat with ", "WhatsApp Chat - ", "Chat de WhatsApp - "):
        if nombre.startswith(prefijo):
            nombre = nombre[len(prefijo):]
    return nombre.strip() or "chat"


def detectar_mes_primero(lineas: list[str]) -> bool:
    """Por defecto día/mes (México). Solo usa mes/día si alguna fecha lo exige (segundo número > 12)."""
    primero_mayor, segundo_mayor = 0, 0
    for linea in lineas[:5000]:
        m = RE_ANDROID.match(linea) or RE_IPHONE.match(linea)
        if not m:
            continue
        a, b = (int(x) for x in re.split(r"[/.\-]", m["fecha"])[:2])
        primero_mayor += a > 12
        segundo_mayor += b > 12
    return segundo_mayor > 0 and primero_mayor == 0


def parsear_chat(lineas: list[str]) -> list[dict]:
    mes_primero = detectar_mes_primero(lineas)
    mensajes: list[dict] = []
    for linea in lineas:
        m = RE_ANDROID.match(linea) or RE_IPHONE.match(linea)
        if m:
            fecha = parsear_fecha(m["fecha"], m["hora"], m["ampm"], mes_primero)
            if fecha is None:
                continue
            resto = m["resto"]
            if ": " in resto:
                autor, texto = resto.split(": ", 1)
            else:  # mensaje de sistema (alguien se unió, cambió el nombre, etc.)
                autor, texto = "(sistema)", resto
            mensajes.append({"fecha_hora": fecha, "autor": autor.strip(), "texto": texto.strip()})
        elif mensajes and linea.strip():
            mensajes[-1]["texto"] += "\n" + linea.strip()  # continuación de mensaje multilínea
    return mensajes


# --------------------------------------------------------------------------
# CLASIFICACIÓN Y EXTRACCIÓN
# --------------------------------------------------------------------------
def compilar(palabras: list[str]) -> re.Pattern:
    partes = []
    for p in palabras:
        p = sin_acentos(p)
        if p.endswith("*"):
            partes.append(r"\b" + re.escape(p[:-1]) + r"\w*")
        else:
            partes.append(r"\b" + re.escape(p) + r"\b")
    return re.compile("|".join(partes))


PATRONES = {cat: compilar(pal) for cat, pal in CATEGORIAS.items()}
PATRON_INCIDENCIAS = compilar(INCIDENCIAS)
PATRON_PENDIENTES = compilar(PENDIENTES)
# Frases que niegan el problema ("no hay problema", "sin problema") no cuentan como incidencia
RE_NEGACION = re.compile(r"\b(no hay|sin|no (va|vaya) (a )?(ver|haber)|no ve|ningun)\s+(ningun\s+)?problema\w*")
RE_CANTIDAD = re.compile(r"(\d+(?:[.,]\d+)?)\s*" + UNIDADES + r"(?![a-z])(?!\.?\s*\d{1,3}\s?\+)", re.IGNORECASE)
RE_CADENAMIENTO = re.compile(r"\b(?:km\.?\s*)?(\d{1,3}\s?\+\s?\d{3}(?:\.\d+)?)\b", re.IGNORECASE)
RE_ELEMENTO = re.compile(
    r"\b(pila|pilas|zapata|cabezal|columna|trabe|losa|caballete|estribo|apoyo|eje|tramo|claro|mensula|ménsula)"
    r"(?:\s*(?:no\.?|num\.?|#)?\s*(\d+[a-z]?)|\s+([a-z])(?![\w.]))",
    re.IGNORECASE,
)


def clasificar(mensaje: dict) -> dict:
    texto = mensaje["texto"]
    normal = sin_acentos(texto)
    es_adjunto = bool(RE_ADJUNTO.search(texto))
    categorias = [cat for cat, pat in PATRONES.items() if pat.search(normal)]
    cantidades = [f"{num} {uni}" for num, uni in RE_CANTIDAD.findall(texto)]
    cadenamientos = sorted({c.replace(" ", "") for c in RE_CADENAMIENTO.findall(texto)})
    elementos = sorted({f"{e.capitalize()} {(n or l).upper()}" for e, n, l in RE_ELEMENTO.findall(texto)})
    return {
        **mensaje,
        "fecha": mensaje["fecha_hora"].date(),
        "hora": mensaje["fecha_hora"].strftime("%H:%M"),
        "categorias": ", ".join(categorias),
        "incidencia": bool(PATRON_INCIDENCIAS.search(RE_NEGACION.sub(" ", normal))),
        "pendiente": bool(PATRON_PENDIENTES.search(normal)),
        "cantidades": ", ".join(cantidades),
        "cadenamientos": ", ".join(cadenamientos),
        "elementos": ", ".join(elementos),
        "adjunto": es_adjunto,
        "es_reporte": es_reporte(texto),
    }


# --------------------------------------------------------------------------
# REPORTES DIARIOS ESTRUCTURADOS ("Reporte de actividades <obra>")
# Formato esperado: encabezado con Personal / Equipo menor / Maquinaria y luego
# bloques "Frente N" con la actividad, su Personal y su Equipo y maquinaria.
# --------------------------------------------------------------------------
MESES = {m: i for i, m in enumerate(["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto",
                                      "septiembre", "octubre", "noviembre", "diciembre"], 1)}
RE_FECHA_LARGA = re.compile(r"(\d{1,2})\s+de\s+([a-z]+)\s+(?:de|del)\s+(\d{4})")
RE_FRENTE = re.compile(r"^frente\b", re.IGNORECASE)
RE_SECCION = re.compile(r"^(personal|mano de obra|equipo menor|equipo y maquinaria|maquinaria)\s*:?\s*$")
RE_NUM_INICIAL = re.compile(r"^(\d+)\s")
RE_VIÑETA = re.compile(r"^[\s•◦·\-–*]+")


def es_reporte(texto: str) -> bool:
    return sin_acentos(texto[:120]).lstrip("* ").startswith("reporte de actividades")


def _sumar_personal(lineas: list[str]) -> int:
    return sum(int(m[1]) for l in lineas if (m := RE_NUM_INICIAL.match(l)))


def _estado(actividad: str) -> str:
    a = sin_acentos(actividad)
    if re.search(r"\b(conclu|termin|finaliz)", a):
        return "Concluido"
    if re.search(r"\b(continua|continuacion|sigue|seguimiento)", a):
        return "En proceso"
    return "Ejecutado / inicio"


def parsear_reporte(mensaje: dict) -> tuple[dict, list[dict]]:
    """Devuelve (fila de resumen del reporte, filas de actividades por frente)."""
    lineas = [RE_VIÑETA.sub("", l).strip() for l in mensaje["texto"].splitlines()]
    lineas = [l for l in lineas if l]
    obra = re.sub(r"(?i)^\**\s*reporte de actividades\s*(de|del)?\s*", "", lineas[0]).strip(" *:") or "(sin nombre)"
    obra = re.split(r"(?i)\s+(?:lunes|martes|mi[eé]rcoles|jueves|viernes|s[aá]bado|domingo)?\s*\d{1,2}\s+de\s", obra)[0].strip(" ,.-")
    fecha = mensaje["fecha_hora"].date()
    for l in lineas[0:3]:
        m = RE_FECHA_LARGA.search(sin_acentos(l))
        mes = m and (difflib.get_close_matches(m[2], MESES, n=1, cutoff=0.7) or [None])[0]
        if mes:
            try:
                fecha = date(int(m[3]), MESES[mes], int(m[1]))
            except ValueError:
                pass
            break

    # Encabezado general (antes del primer frente)
    secciones: dict[str, list[str]] = defaultdict(list)
    actual, i = None, 1
    while i < len(lineas) and not RE_FRENTE.match(lineas[i]):
        if m := RE_SECCION.match(sin_acentos(lineas[i]).replace("maquinaria", "maquinaria")):
            actual = m[1]
        elif actual:
            secciones[actual].append(lineas[i])
        i += 1
    maquinaria = secciones.get("maquinaria", [])
    inactivos = [l for l in secciones["personal"] + secciones.get("equipo menor", []) + maquinaria
                 if "inactiv" in sin_acentos(l) and l in maquinaria]
    resumen = {"fecha": fecha, "obra": obra, "grupo": mensaje.get("grupo", ""), "autor": mensaje["autor"],
               "personal_total": _sumar_personal(secciones.get("personal", []) + secciones.get("mano de obra", [])),
               "maquinaria": _sumar_personal(maquinaria),
               "maquinaria_inactiva": "; ".join(inactivos),
               "frentes": 0}

    # Bloques por frente
    actividades: list[dict] = []
    while i < len(lineas):
        frente = lineas[i].rstrip(":")
        i += 1
        desc, pers, equipo, actual = [], [], [], "actividad"
        while i < len(lineas) and not RE_FRENTE.match(lineas[i]):
            n = sin_acentos(lineas[i])
            if m := RE_SECCION.match(n):
                actual = "personal" if m[1] in ("personal", "mano de obra") else "equipo"
            elif actual == "actividad":
                desc.append(lineas[i])
            elif actual == "personal":
                pers.append(lineas[i])
            else:
                equipo.append(lineas[i])
            i += 1
        actividad = " ".join(desc)
        if not actividad:
            continue
        info = clasificar({"fecha_hora": mensaje["fecha_hora"], "autor": mensaje["autor"], "texto": actividad})
        actividades.append({
            "fecha": fecha, "obra": obra, "frente": frente, "actividad": actividad,
            "estado": _estado(actividad), "cantidades": info["cantidades"], "elementos": info["elementos"],
            "cadenamientos": info["cadenamientos"], "categorias": info["categorias"],
            "personal": _sumar_personal(pers),
            "equipo": " ".join(equipo).replace("Herramienta menor.", "").strip(" .") or "Herramienta menor",
            "reportó": mensaje["autor"], "grupo": mensaje.get("grupo", ""),
        })
    resumen["frentes"] = len(actividades)
    return resumen, actividades


def extraer_reportes(df: pd.DataFrame) -> tuple[pd.DataFrame, pd.DataFrame]:
    resumenes, actividades = [], []
    for _, r in df[df["es_reporte"]].iterrows():
        res, act = parsear_reporte(r.to_dict())
        resumenes.append(res)
        actividades += act
    res_df = pd.DataFrame(resumenes)
    act_df = pd.DataFrame(actividades)
    if not res_df.empty:  # unifica mayúsculas/minúsculas del nombre de la obra
        nombres = {}
        for o in res_df["obra"]:
            nombres.setdefault(o.upper(), o)
        res_df["obra"] = res_df["obra"].str.upper().map(nombres)
        act_df["obra"] = act_df["obra"].str.upper().map(nombres)
    if not res_df.empty:  # si un reporte se reenvió o corrigió, queda el último de ese día y obra
        res_df = res_df.drop_duplicates(["fecha", "obra"], keep="last").sort_values(["fecha", "obra"])
        act_df = (act_df.drop_duplicates(["fecha", "obra", "frente", "actividad"], keep="last")
                  .sort_values(["fecha", "obra"], kind="stable"))
    return res_df, act_df


# --------------------------------------------------------------------------
# REPORTES
# --------------------------------------------------------------------------
COLUMNAS = ["fecha", "hora", "grupo", "autor", "texto", "categorias", "elementos", "cadenamientos",
            "cantidades", "incidencia", "pendiente", "adjunto", "es_reporte"]


def resumen_diario(df: pd.DataFrame) -> pd.DataFrame:
    filas = []
    for dia, g in df.groupby("fecha"):
        conteo = Counter(c for cats in g["categorias"] if cats for c in cats.split(", "))
        filas.append({
            "fecha": dia,
            "mensajes": len(g),
            "autores": ", ".join(sorted(g["autor"].unique())),
            "categorías (n.º de mensajes)": ", ".join(f"{c} ({n})" for c, n in conteo.most_common()),
            "elementos mencionados": ", ".join(sorted({e for x in g["elementos"] if x for e in x.split(", ")})),
            "cadenamientos": ", ".join(sorted({e for x in g["cadenamientos"] if x for e in x.split(", ")})),
            "incidencias": int((g["incidencia"] & ~g["es_reporte"]).sum()),
            "pendientes": int((g["pendiente"] & ~g["es_reporte"]).sum()),
            "fotos/archivos": int(g["adjunto"].sum()),
        })
    return pd.DataFrame(filas)


def escribir_excel(df: pd.DataFrame, reportes: pd.DataFrame, actividades: pd.DataFrame, ruta: Path) -> None:
    texto_df = df[~df["adjunto"] & ~df["es_reporte"]]
    hojas = {
        "Resumen diario": resumen_diario(df),
        "Avance por frente": actividades,
        "Personal y equipo": reportes,
        "Mensajes": df[COLUMNAS],
        "Incidencias": texto_df[texto_df["incidencia"]][COLUMNAS],
        "Pendientes": texto_df[texto_df["pendiente"]][COLUMNAS],
        "Cantidades": texto_df[texto_df["cantidades"].ne("")][["fecha", "hora", "autor", "cantidades", "elementos",
                                                    "cadenamientos", "categorias", "texto"]],
        "Por autor": df.groupby(["autor", "grupo"]).agg(mensajes=("texto", "size"),
                                             fotos_archivos=("adjunto", "sum"),
                                             primer_mensaje=("fecha", "min"),
                                             ultimo_mensaje=("fecha", "max")).reset_index()
                       .sort_values("mensajes", ascending=False),
        "Adjuntos": df[df["adjunto"]][["fecha", "hora", "grupo", "autor", "texto"]],
    }
    with pd.ExcelWriter(ruta, engine="openpyxl") as writer:
        for nombre, hoja in hojas.items():
            if hoja.empty and nombre in ("Avance por frente", "Personal y equipo"):
                continue
            hoja.to_excel(writer, sheet_name=nombre, index=False)
            ws = writer.sheets[nombre]
            ws.freeze_panes = "A2"
            ws.auto_filter.ref = ws.dimensions
            for col in ws.columns:
                letra = col[0].column_letter
                ancho = max((len(str(c.value)) if c.value is not None else 0) for c in col[:200])
                ws.column_dimensions[letra].width = min(max(10, ancho + 2), 80)


DIAS = ["Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado", "Domingo"]


def _corto(texto: str, n: int = 400) -> str:
    texto = texto.replace("\n", " ")
    return texto if len(texto) <= n else texto[:n].rsplit(" ", 1)[0] + " …"


def _etiqueta(r) -> str:
    """Nombre corto del grupo entre corchetes, solo en el reporte consolidado."""
    return f"[{r['grupo_corto']}] " if r.get("grupo_corto") else ""


def escribir_markdown(df: pd.DataFrame, actividades: pd.DataFrame, reportes: pd.DataFrame,
                      grupo: str, ruta: Path) -> None:
    lineas = [f"# Resumen de obra — {grupo}", "",
              f"Periodo: **{df['fecha'].min():%d/%m/%Y}** al **{df['fecha'].max():%d/%m/%Y}** · "
              f"{len(df)} mensajes · {df['autor'].nunique()} participantes · "
              f"{int(df['adjunto'].sum())} fotos/archivos", ""]
    for dia, g in df.groupby("fecha"):
        lineas += [f"## {DIAS[dia.weekday()]} {dia:%d/%m/%Y}", ""]
        if not actividades.empty:
            for obra, a in actividades[actividades["fecha"] == dia].groupby("obra", sort=False):
                rep = reportes[(reportes["fecha"] == dia) & (reportes["obra"] == obra)]
                extra = f" · {int(rep['personal_total'].iloc[0])} personas en obra" if len(rep) and rep["personal_total"].iloc[0] else ""
                lineas.append(f"**🏗️ Reporte de actividades — {obra}**{extra}")
                for _, r in a.iterrows():
                    cant = f" **[{r['cantidades']}]**" if r["cantidades"] else ""
                    lineas.append(f"- {r['frente']}: {_corto(r['actividad'], 250)}{cant}")
                lineas.append("")
        n_adj = int(g["adjunto"].sum())
        g = g[~g["es_reporte"]]
        por_cat = defaultdict(list)
        for _, r in g[g["categorias"].ne("") & ~g["adjunto"]].iterrows():
            por_cat[r["categorias"].split(", ")[0]].append(r)
        for cat in CATEGORIAS:
            if cat in por_cat:
                lineas.append(f"**{cat}**")
                for r in por_cat[cat]:
                    lineas.append(f"- {r['hora']} · {_etiqueta(r)}{r['autor']}: {_corto(r['texto'])}")
                lineas.append("")
        inc = g[g["incidencia"] & ~g["adjunto"]]
        if len(inc):
            lineas.append("**⚠️ Incidencias**")
            lineas += [f"- {r['hora']} · {_etiqueta(r)}{r['autor']}: {_corto(r['texto'])}" for _, r in inc.iterrows()]
            lineas.append("")
        pen = g[g["pendiente"] & ~g["adjunto"]]
        if len(pen):
            lineas.append("**📌 Pendientes**")
            lineas += [f"- {r['hora']} · {_etiqueta(r)}{r['autor']}: {_corto(r['texto'])}" for _, r in pen.iterrows()]
            lineas.append("")
        if n_adj:
            lineas += [f"_📷 {n_adj} fotos/archivos compartidos ese día._", ""]
    ruta.write_text("\n".join(lineas), encoding="utf-8")


# --------------------------------------------------------------------------
# TABLA DE PILAS POR EJE / APOYO
# Fuente principal: actividades de los "Reporte de actividades" (lo ejecutado).
# Fuente secundaria: mensajes sueltos tipo "colado de pila 3 apoyo 8 Garzas"
# (programas del día o avisos; se listan aparte, no se suman al avance).
# --------------------------------------------------------------------------
RE_PILA_EJE = re.compile(r"\bpila\s*(?:no\.?|#)?\s*(\d+)\b[^.;]{0,25}?\b(eje|apoyo)\s*(?:no\.?|#)?\s*(\d+)\b", re.IGNORECASE)
RE_PILA_COD = re.compile(r"\bP(\d)-0?(\d{1,2})\b")  # nomenclatura P<eje>-<pila>, ej. P4-03
RE_APOYO_PILA = re.compile(r"\bpila\s*(\d+)\s*(?:de\s+|del\s+|en\s+(?:el\s+)?)?(apoyo|eje)\s*(\d+)\s*,?\s*(garzas|gaviotas)?", re.IGNORECASE)
RE_M3 = re.compile(r"(\d+(?:[.,]\d+)?)\s*m(?:3|³)", re.IGNORECASE)
RE_PROF = re.compile(r"(?:profundidad(?: a perforar)?(?: a| de)?|llega(?:r)? a|lleg[oó] a|avanz[oó] a|avance(?: de)?|perfora a|a los)\s*(\d+(?:[.,]\d+)?)\s*(?:m\b|metros)", re.IGNORECASE)


def _num(x: str) -> float:
    return float(x.replace(",", "."))


def eventos_pilas(actividades: pd.DataFrame) -> pd.DataFrame:
    filas = []
    for _, r in actividades.iterrows():
        texto = r["actividad"]
        n = sin_acentos(texto)
        pilas = [(int(e), int(p)) for p, _, e in RE_PILA_EJE.findall(texto)]
        if not pilas:
            continue
        if "relleno fluido" in n:
            tipo = "Perforación + relleno fluido" if "perfora" in n else "Relleno fluido"
        elif re.search(r"\bcolad|\bizaj|\bizad", n):
            tipo = "Colado"
        elif "perfora" in n:
            tipo = "Reperforación" if "reperfora" in n else "Perforación"
        elif re.search(r"armad|habilitad", n):
            tipo = "Armado"
        else:
            tipo = "Otro"
        m3 = [_num(v) for v in RE_M3.findall(texto)]
        prof = [_num(v) for v in RE_PROF.findall(texto)]
        for eje, pila in pilas:
            filas.append({
                "obra": r["obra"], "eje": eje, "pila": pila, "fecha": r["fecha"], "evento": tipo,
                "volumen_m3": m3[0] if m3 else None,
                "profundidad_m": max(prof) if prof and "perfora" in n else None,
                "caidos": bool(re.search(r"caido|se cae|cae la pared|no se recupero|se recupero|recupera", n)),
                "suspendida": bool(re.search(r"suspend", n)),
                "actividad": texto, "reportó": r.get("reportó", ""),
            })
    ev = pd.DataFrame(filas)
    if ev.empty:
        return ev
    ev = ev.sort_values(["obra", "eje", "pila", "fecha"], kind="stable")
    # Mismo evento con el mismo texto en días seguidos: casi siempre es un reporte copiado del día anterior
    ev["posible_repetido"] = (ev.duplicated(["obra", "eje", "pila", "evento", "actividad"], keep="first")
                              & ev["evento"].isin(["Colado", "Relleno fluido"]))
    return ev


def resumen_pilas(ev: pd.DataFrame) -> pd.DataFrame:
    filas = []
    for (obra, eje, pila), g in ev.groupby(["obra", "eje", "pila"]):
        validos = g[~g["posible_repetido"]]
        col = validos[validos["evento"] == "Colado"]
        rf = validos[validos["evento"].str.contains("Relleno")]
        perf = g[g["evento"].str.contains("erforaci")]
        obs = []
        if len(col) > 1:
            obs.append(f"Colado reportado {len(col)} veces ({', '.join(f'{d:%d/%m}' for d in col['fecha'])}): verificar")
        if g["posible_repetido"].any():
            rep = g[g["posible_repetido"]]
            obs.append("Texto repetido de un día anterior el " + ", ".join(f"{d:%d/%m}" for d in rep["fecha"]) + " (no se sumó)")
        if len(col) and col["volumen_m3"].isna().any():
            obs.append("Colado sin volumen reportado")
        if g["suspendida"].any() and not len(col):
            obs.append("Perforación suspendida")
        if len(col):
            estado = "Colada"
        elif len(rf):
            estado = "Con relleno fluido (por reperforar)"
        elif len(perf):
            estado = "En perforación"
        else:
            estado = "Armado / preparación"
        filas.append({
            "obra": obra, "eje": eje, "pila": pila, "elemento": f"E{eje}-P{pila}", "estado": estado,
            "inicio_perforación": perf["fecha"].min() if len(perf) else None,
            "última_profundidad_reportada_m": perf["profundidad_m"].dropna().iloc[-1] if perf["profundidad_m"].notna().any() else None,
            "fecha_última_profundidad": perf.loc[perf["profundidad_m"].notna(), "fecha"].iloc[-1] if perf["profundidad_m"].notna().any() else None,
            "intentos_perforación": len(perf),
            "eventos_con_caídos": int(g["caidos"].sum()),
            "relleno_fluido_m3": rf["volumen_m3"].sum() if len(rf) else 0.0,
            "fechas_relleno_fluido": ", ".join(f"{d:%d/%m}" for d in rf["fecha"]),
            "fecha_colado": col["fecha"].iloc[-1] if len(col) else None,
            "volumen_colado_m3": col["volumen_m3"].iloc[-1] if len(col) else None,
            "observaciones": "; ".join(obs),
        })
    res = pd.DataFrame(filas)
    # Misma profundidad exacta que otra pila reportada uno o dos días antes: posible texto copiado
    prof = res.dropna(subset=["última_profundidad_reportada_m"])
    for i, r in prof.iterrows():
        otras = prof[(prof.index != i) & (prof["obra"] == r["obra"])
                     & (prof["última_profundidad_reportada_m"] == r["última_profundidad_reportada_m"])]
        otras = otras[otras["fecha_última_profundidad"].apply(lambda d: 0 < (r["fecha_última_profundidad"] - d).days <= 2)]
        if len(otras):
            nota = f"Profundidad idéntica a {', '.join(otras['elemento'])} del día anterior: verificar"
            res.loc[i, "observaciones"] = "; ".join(x for x in [res.loc[i, "observaciones"], nota] if x)
    return res


def resumen_por_eje(res: pd.DataFrame) -> pd.DataFrame:
    g = res.groupby(["obra", "eje"])
    return pd.DataFrame({
        "pilas con registro": g.size(),
        "coladas": g["estado"].apply(lambda s: (s == "Colada").sum()),
        "pendientes de colar": g["estado"].apply(lambda s: (s != "Colada").sum()),
        "pilas coladas": g.apply(lambda x: ", ".join(f"P{p}" for p in x.loc[x["estado"] == "Colada", "pila"]), include_groups=False),
        "pilas sin colar": g.apply(lambda x: ", ".join(f"P{p}" for p in x.loc[x["estado"] != "Colada", "pila"]), include_groups=False),
        "concreto colado m3": g["volumen_colado_m3"].sum(),
        "relleno fluido m3": g["relleno_fluido_m3"].sum(),
    }).reset_index()


def menciones_pilas(df: pd.DataFrame) -> pd.DataFrame:
    """Pilas mencionadas en mensajes normales (programas de la contratista, avisos de campo)."""
    filas = []
    for _, r in df[~df["adjunto"] & ~df["es_reporte"]].iterrows():
        texto = r["texto"]
        for parte in re.split(r"[\n*•]|\s-(?=\S)|\.-", texto):
            n = sin_acentos(parte)
            hallazgos = [(p, a, (o or "").capitalize(), ref.lower()) for p, ref, a, o in RE_APOYO_PILA.findall(parte)]
            hallazgos += [(p, e, "", "eje") for e, p in RE_PILA_COD.findall(parte)]
            for pila, ap, obra, ref in hallazgos:
                if not obra:
                    obra = "Garzas" if "garza" in n else "Gaviotas" if "gaviota" in n else ""
                if re.search(r"se termin|termin[oó]|conclu|qued[oó] colad|ya se col", n):
                    tipo = "Aviso de terminado"
                elif re.search(r"cancel|suspend", n):
                    tipo = "Cancelado / suspendido"
                else:
                    tipo = "Programa / mención"
                filas.append({"fecha": r["fecha"], "grupo": r.get("grupo", ""), "autor": r["autor"],
                              "obra/tramo": obra, "referencia": ref, "apoyo/eje": int(ap), "pila": int(pila),
                              "tipo": tipo, "texto": parte.strip()})
    m = pd.DataFrame(filas)
    return m.drop_duplicates(["fecha", "apoyo/eje", "pila", "texto"]) if not m.empty else m


def resumen_apoyos(menciones: pd.DataFrame) -> pd.DataFrame:
    """Pilas por apoyo (Garzas / Gaviotas) a partir de los mensajes. Son programas o avisos,
    no reportes de lo ejecutado: sirven para ubicar fechas y cruzar con la bitácora."""
    if menciones.empty:
        return menciones
    ap = menciones[menciones["referencia"] == "apoyo"]
    filas = []
    for (obra, apoyo, pila), g in ap.groupby(["obra/tramo", "apoyo/eje", "pila"]):
        term = g[g["tipo"] == "Aviso de terminado"]
        filas.append({"obra/tramo": obra or "(sin indicar)", "apoyo": apoyo, "pila": pila,
                      "elemento": f"A{apoyo}-P{pila}",
                      "primera_mención": g["fecha"].min(), "última_mención": g["fecha"].max(),
                      "veces_programada": int((g["tipo"] == "Programa / mención").sum()),
                      "aviso_de_terminado": ", ".join(f"{d:%d/%m}" for d in term["fecha"]),
                      "quién_reporta": ", ".join(dict.fromkeys(g["autor"]))})
    return pd.DataFrame(filas).sort_values(["obra/tramo", "apoyo", "pila"])


def escribir_pilas(df: pd.DataFrame, actividades: pd.DataFrame, ruta: Path) -> pd.DataFrame | None:
    ev = eventos_pilas(actividades) if not actividades.empty else pd.DataFrame()
    menciones = menciones_pilas(df)
    if ev.empty and menciones.empty:
        return None
    res = resumen_pilas(ev) if not ev.empty else pd.DataFrame()
    if not res.empty and not menciones.empty:  # avisos de otros grupos que hablan de la misma pila por eje
        por_eje = menciones[menciones["referencia"] == "eje"]
        avisos = por_eje.groupby(["apoyo/eje", "pila"]).apply(
            lambda g: "; ".join(f"{f:%d/%m} {t} ({gr})" for f, t, gr in zip(g["fecha"], g["tipo"], g["grupo"])),
            include_groups=False)
        res["menciones_en_grupos"] = [avisos.get((e, p), "") for e, p in zip(res["eje"], res["pila"])]
    hojas = {
        "Resumen por eje": resumen_por_eje(res) if not res.empty else pd.DataFrame(),
        "Pilas": res,
        "Eventos (reportes)": ev,
        "Apoyos (según grupos)": resumen_apoyos(menciones),
        "Menciones en grupos": menciones,
    }
    with pd.ExcelWriter(ruta, engine="openpyxl") as writer:
        for nombre, hoja in hojas.items():
            if hoja.empty:
                continue
            hoja.to_excel(writer, sheet_name=nombre, index=False)
            ws = writer.sheets[nombre]
            ws.freeze_panes = "A2"
            ws.auto_filter.ref = ws.dimensions
            for col in ws.columns:
                ancho = max((len(str(c.value)) if c.value is not None else 0) for c in col[:200])
                ws.column_dimensions[col[0].column_letter].width = min(max(9, ancho + 2), 70)
    return res


# --------------------------------------------------------------------------
# PROGRAMA PRINCIPAL
# --------------------------------------------------------------------------
def cargar_grupo(ruta: Path, desde: date | None, hasta: date | None) -> pd.DataFrame | None:
    grupo, lineas = leer_lineas(ruta)
    mensajes = parsear_chat(lineas)
    if not mensajes:
        print(f"⚠️  {ruta.name}: no se reconocieron mensajes (¿es una exportación de WhatsApp?)")
        return None
    df = pd.DataFrame([clasificar(m) for m in mensajes])
    df.insert(0, "grupo", grupo)
    if desde:
        df = df[df["fecha"] >= desde]
    if hasta:
        df = df[df["fecha"] <= hasta]
    df = df[(df["autor"] != "(sistema)") & df["texto"].str.strip().ne("")]
    if df.empty:
        print(f"⚠️  {grupo}: no hay mensajes en el periodo indicado")
        return None
    return df


def generar(df: pd.DataFrame, nombre: str, salida: Path) -> None:
    base = re.sub(r"[^\w\- ]", "_", nombre).strip()
    xlsx, md = salida / f"resumen_{base}.xlsx", salida / f"resumen_{base}.md"
    reportes, actividades = extraer_reportes(df)
    escribir_excel(df, reportes, actividades, xlsx)
    escribir_markdown(df, actividades, reportes, nombre, md)
    pilas = escribir_pilas(df, actividades, salida / f"pilas_{base}.xlsx")
    texto = df[~df["adjunto"] & ~df["es_reporte"]]
    print(f"✅ {nombre}: {len(df)} mensajes ({df['fecha'].min()} a {df['fecha'].max()}), "
          f"{len(reportes)} reportes diarios con {len(actividades)} actividades por frente, "
          f"{int(texto['incidencia'].sum())} incidencias, {int(texto['pendiente'].sum())} pendientes")
    print(f"   → {xlsx}\n   → {md}")
    if pilas is not None:
        coladas = int((pilas["estado"] == "Colada").sum()) if not pilas.empty else 0
        print(f"   → {salida / f'pilas_{base}.xlsx'} ({len(pilas)} pilas con registro, {coladas} coladas)")


def consolidar(grupos: list[pd.DataFrame]) -> pd.DataFrame:
    """Une varios grupos en una sola línea de tiempo. Un mensaje reenviado o repetido
    en otro grupo (mismo día y mismo texto) se deja una sola vez y se anotan los grupos."""
    df = pd.concat(grupos, ignore_index=True).sort_values("fecha_hora", kind="stable")
    df["grupo_corto"] = df["grupo"].str.replace(r"(?i)\s*-?\s*barrio\s*(v|5)\b", "", regex=True).str.strip(" -") \
        .replace("", pd.NA).fillna(df["grupo"])
    clave = df["texto"].str.lower().str.replace(r"\W+", " ", regex=True).str.strip()
    largo = ~df["adjunto"] & clave.str.len().ge(40)
    df["_clave"] = df["fecha"].astype(str) + "|" + clave.where(largo, df.index.astype(str))
    grupos_por_clave = df.groupby("_clave")["grupo_corto"].agg(lambda g: ", ".join(dict.fromkeys(g)))
    df = df.drop_duplicates("_clave", keep="first").copy()
    df["grupo_corto"] = df["_clave"].map(grupos_por_clave)
    df["grupo"] = df["grupo_corto"]
    return df.drop(columns="_clave")


def main() -> None:
    ap = argparse.ArgumentParser(description="Resume avances de obra de chats exportados de WhatsApp.")
    ap.add_argument("entradas", nargs="+", help="Archivos .txt/.zip exportados, o carpetas que los contengan")
    ap.add_argument("--desde", type=date.fromisoformat, help="Fecha inicial AAAA-MM-DD")
    ap.add_argument("--hasta", type=date.fromisoformat, help="Fecha final AAAA-MM-DD")
    ap.add_argument("--salida", type=Path, default=Path("reportes_whatsapp"), help="Carpeta de salida")
    ap.add_argument("--nombre", default="CONSOLIDADO", help="Nombre del reporte que une todos los grupos")
    ap.add_argument("--sin-consolidado", action="store_true", help="No generar el reporte que une los grupos")
    args = ap.parse_args()

    archivos: list[Path] = []
    for e in map(Path, args.entradas):
        if e.is_dir():
            archivos += sorted(p for p in e.iterdir() if p.suffix.lower() in (".txt", ".zip"))
        elif e.exists():
            archivos.append(e)
        else:
            print(f"⚠️  No existe: {e}")
    if not archivos:
        sys.exit("No se encontraron archivos .txt o .zip para procesar.")

    args.salida.mkdir(parents=True, exist_ok=True)
    cargados = []
    for ruta in archivos:
        try:
            df = cargar_grupo(ruta, args.desde, args.hasta)
            if df is not None:
                generar(df, df["grupo"].iloc[0], args.salida)
                cargados.append(df)
        except Exception as exc:  # un archivo dañado no detiene a los demás
            print(f"❌ {ruta.name}: {exc}")
    if len(cargados) > 1 and not args.sin_consolidado:
        print(f"\n📚 Consolidado de {len(cargados)} grupos:")
        generar(consolidar(cargados), args.nombre, args.salida)


if __name__ == "__main__":
    main()
