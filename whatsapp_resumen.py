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
                            "aleros", "diafragma*", "parapeto*", "junta* de dilatacion"],
    "Terracerías / Excavación": ["excavacion*", "excavad*", "terraplen*", "relleno*", "compact*",
                                 "terraceria*", "despalme", "corte", "cortes", "acarreo*",
                                 "subrasante", "base hidraulica", "subbase"],
    "Pavimentos": ["carpeta", "asfalt*", "riego de liga", "riego de impregnacion", "pavimento*",
                   "fresado", "bacheo"],
    "Drenaje / Obras complementarias": ["alcantarilla*", "cuneta*", "lavadero*", "tubo*",
                                        "drenaje", "contracuneta*", "bordillo*", "señalamiento"],
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
INCIDENCIAS = ["problema*", "falla*", "fallo", "retraso*", "atras*", "detenid*", "paro", "parado",
               "suspend*", "no se pudo", "no llego", "no llegaron", "se descompuso", "descompuest*",
               "averia*", "urge", "urgente", "reclamo*", "rechaz*", "derrumbe*", "fuga*", "bloqueo*"]
PENDIENTES = ["pendiente*", "falta", "faltan", "manana", "programad*", "se requiere", "requerimos",
              "hay que", "necesitamos", "necesito", "por hacer", "se va a", "vamos a",
              "favor de", "solicito", "solicitamos"]

UNIDADES = r"(m3|m³|m2|m²|ml|m\.l\.|mts?|km|ton|tons|kg|pzas?|piezas|ollas?|viajes|lts?|litros|%|metros|hrs?|horas)"

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
RE_CANTIDAD = re.compile(r"(\d+(?:[.,]\d+)?)\s*" + UNIDADES + r"(?![a-z])(?!\.?\s*\d{1,3}\s?\+)", re.IGNORECASE)
RE_CADENAMIENTO = re.compile(r"\b(?:km\.?\s*)?(\d{1,3}\s?\+\s?\d{3}(?:\.\d+)?)\b", re.IGNORECASE)
RE_ELEMENTO = re.compile(
    r"\b(pila|pilas|zapata|cabezal|columna|trabe|losa|caballete|estribo|apoyo|eje|tramo|claro|frente)"
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
        "incidencia": bool(PATRON_INCIDENCIAS.search(normal)),
        "pendiente": bool(PATRON_PENDIENTES.search(normal)),
        "cantidades": ", ".join(cantidades),
        "cadenamientos": ", ".join(cadenamientos),
        "elementos": ", ".join(elementos),
        "adjunto": es_adjunto,
    }


# --------------------------------------------------------------------------
# REPORTES
# --------------------------------------------------------------------------
COLUMNAS = ["fecha", "hora", "autor", "texto", "categorias", "elementos", "cadenamientos",
            "cantidades", "incidencia", "pendiente", "adjunto"]


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
            "incidencias": int(g["incidencia"].sum()),
            "pendientes": int(g["pendiente"].sum()),
            "fotos/archivos": int(g["adjunto"].sum()),
        })
    return pd.DataFrame(filas)


def escribir_excel(df: pd.DataFrame, ruta: Path) -> None:
    texto_df = df[~df["adjunto"] | df["categorias"].ne("")]
    hojas = {
        "Resumen diario": resumen_diario(df),
        "Mensajes": df[COLUMNAS],
        "Incidencias": texto_df[texto_df["incidencia"]][COLUMNAS],
        "Pendientes": texto_df[texto_df["pendiente"]][COLUMNAS],
        "Cantidades": df[df["cantidades"].ne("")][["fecha", "hora", "autor", "cantidades", "elementos",
                                                    "cadenamientos", "categorias", "texto"]],
        "Por autor": df.groupby("autor").agg(mensajes=("texto", "size"),
                                             fotos_archivos=("adjunto", "sum"),
                                             primer_mensaje=("fecha", "min"),
                                             ultimo_mensaje=("fecha", "max")).reset_index()
                       .sort_values("mensajes", ascending=False),
        "Adjuntos": df[df["adjunto"]][["fecha", "hora", "autor", "texto"]],
    }
    with pd.ExcelWriter(ruta, engine="openpyxl") as writer:
        for nombre, hoja in hojas.items():
            hoja.to_excel(writer, sheet_name=nombre, index=False)
            ws = writer.sheets[nombre]
            ws.freeze_panes = "A2"
            ws.auto_filter.ref = ws.dimensions
            for col in ws.columns:
                letra = col[0].column_letter
                ancho = max((len(str(c.value)) if c.value is not None else 0) for c in col[:200])
                ws.column_dimensions[letra].width = min(max(10, ancho + 2), 80)


DIAS = ["Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado", "Domingo"]


def escribir_markdown(df: pd.DataFrame, grupo: str, ruta: Path) -> None:
    lineas = [f"# Resumen de obra — {grupo}", "",
              f"Periodo: **{df['fecha'].min():%d/%m/%Y}** al **{df['fecha'].max():%d/%m/%Y}** · "
              f"{len(df)} mensajes · {df['autor'].nunique()} participantes · "
              f"{int(df['adjunto'].sum())} fotos/archivos", ""]
    for dia, g in df.groupby("fecha"):
        lineas += [f"## {DIAS[dia.weekday()]} {dia:%d/%m/%Y}", ""]
        por_cat = defaultdict(list)
        for _, r in g[g["categorias"].ne("") & ~g["adjunto"]].iterrows():
            por_cat[r["categorias"].split(", ")[0]].append(r)
        for cat in CATEGORIAS:
            if cat in por_cat:
                lineas.append(f"**{cat}**")
                for r in por_cat[cat]:
                    lineas.append(f"- {r['hora']} · {r['autor']}: {r['texto'].replace(chr(10), ' ')}")
                lineas.append("")
        inc = g[g["incidencia"] & ~g["adjunto"]]
        if len(inc):
            lineas.append("**⚠️ Incidencias**")
            lineas += [f"- {r['hora']} · {r['autor']}: {r['texto'].replace(chr(10), ' ')}" for _, r in inc.iterrows()]
            lineas.append("")
        pen = g[g["pendiente"] & ~g["adjunto"]]
        if len(pen):
            lineas.append("**📌 Pendientes**")
            lineas += [f"- {r['hora']} · {r['autor']}: {r['texto'].replace(chr(10), ' ')}" for _, r in pen.iterrows()]
            lineas.append("")
        n_adj = int(g["adjunto"].sum())
        if n_adj:
            lineas += [f"_📷 {n_adj} fotos/archivos compartidos ese día._", ""]
    ruta.write_text("\n".join(lineas), encoding="utf-8")


# --------------------------------------------------------------------------
# PROGRAMA PRINCIPAL
# --------------------------------------------------------------------------
def procesar_archivo(ruta: Path, desde: date | None, hasta: date | None, salida: Path) -> None:
    grupo, lineas = leer_lineas(ruta)
    mensajes = parsear_chat(lineas)
    if not mensajes:
        print(f"⚠️  {ruta.name}: no se reconocieron mensajes (¿es una exportación de WhatsApp?)")
        return
    df = pd.DataFrame([clasificar(m) for m in mensajes])
    if desde:
        df = df[df["fecha"] >= desde]
    if hasta:
        df = df[df["fecha"] <= hasta]
    df = df[df["autor"] != "(sistema)"]
    if df.empty:
        print(f"⚠️  {grupo}: no hay mensajes en el periodo indicado")
        return
    base = re.sub(r"[^\w\- ]", "_", grupo).strip()
    xlsx, md = salida / f"resumen_{base}.xlsx", salida / f"resumen_{base}.md"
    escribir_excel(df, xlsx)
    escribir_markdown(df, grupo, md)
    print(f"✅ {grupo}: {len(df)} mensajes ({df['fecha'].min()} a {df['fecha'].max()}), "
          f"{int(df['incidencia'].sum())} incidencias, {int(df['pendiente'].sum())} pendientes")
    print(f"   → {xlsx}\n   → {md}")


def main() -> None:
    ap = argparse.ArgumentParser(description="Resume avances de obra de chats exportados de WhatsApp.")
    ap.add_argument("entradas", nargs="+", help="Archivos .txt/.zip exportados, o carpetas que los contengan")
    ap.add_argument("--desde", type=date.fromisoformat, help="Fecha inicial AAAA-MM-DD")
    ap.add_argument("--hasta", type=date.fromisoformat, help="Fecha final AAAA-MM-DD")
    ap.add_argument("--salida", type=Path, default=Path("reportes_whatsapp"), help="Carpeta de salida")
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
    for ruta in archivos:
        try:
            procesar_archivo(ruta, args.desde, args.hasta, args.salida)
        except Exception as exc:  # un archivo dañado no detiene a los demás
            print(f"❌ {ruta.name}: {exc}")


if __name__ == "__main__":
    main()
