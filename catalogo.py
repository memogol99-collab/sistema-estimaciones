"""
Lectura de catálogos de conceptos (forma E-7 de SICT) y asignación de cada
actividad reportada al concepto más parecido del contrato de su puente.

La asignación es una SUGERENCIA por similitud de texto: sirve para ordenar el
avance por concepto y preparar la estimación, no sustituye a los generadores.
"""

import math
import re
import unicodedata
from collections import Counter
from pathlib import Path

import openpyxl
import pandas as pd


def _norm(texto: str) -> str:
    texto = unicodedata.normalize("NFD", str(texto or "").lower())
    return "".join(c for c in texto if unicodedata.category(c) != "Mn")


# --------------------------------------------------------------------------
# LECTURA DEL CATÁLOGO E-7
# --------------------------------------------------------------------------
def _puente_de_contrato(nombre_archivo: str, obra: str) -> str:
    t = _norm(nombre_archivo + " " + obra)
    if re.search(r"garzas|complemento|2da etapa|segunda etapa", t):
        return "Garzas (2ª etapa)"
    return "Gaviotas (Barrio V)"


def leer_catalogo(ruta: Path) -> tuple[dict, pd.DataFrame]:
    """Devuelve (datos generales del contrato, conceptos)."""
    wb = openpyxl.load_workbook(ruta, data_only=True, read_only=True)
    hoja = next((wb[n] for n in wb.sheetnames if n.strip().upper() == "E-7"), wb.worksheets[0])
    filas = list(hoja.iter_rows(values_only=True))
    info = {"archivo": ruta.name, "obra": "", "contrato": "", "monto_con_iva": None, "periodo": ""}
    inicio = 0
    for i, f in enumerate(filas[:30]):
        celdas = [c for c in f if c is not None]
        texto = [str(c).strip() for c in celdas]
        if "Contrato No.:" in texto:
            info["obra"] = texto[0]
            info["contrato"] = texto[texto.index("Contrato No.:") + 1] if texto.index("Contrato No.:") + 1 < len(texto) else ""
        if texto and texto[0] == "Monto:" and len(celdas) > 1:
            info["monto_con_iva"] = celdas[1]
        if texto and texto[0].startswith("Periodo de Ejecuci") and len(texto) > 1:
            info["periodo"] = texto[1]
        if texto and texto[0] == "No." and "Descripción" in " ".join(texto):
            inicio = i + 2
            break
    info["puente"] = _puente_de_contrato(ruta.name, info["obra"])

    conceptos = []
    bloque, seccion, subseccion, texto_padre = "", "", "", ""
    for f in filas[inicio:]:
        no, clave, desc, unidad, cantidad = (list(f) + [None] * 8)[:5]
        pu = f[6] if len(f) > 6 else None
        importe = f[7] if len(f) > 7 else None
        if isinstance(no, (int, float)) and desc:
            d = str(desc).strip()
            # El texto padre ("Concreto de f'c=250 kg/cm2 en:") solo aplica a renglones cortos que lo continúan
            if texto_padre.endswith(":") and (len(d) > 60 or re.match(r"(?i)(concreto|acero|neopreno|suministro)", d)):
                texto_padre = ""
            conceptos.append({
                "puente": info["puente"], "contrato": info["contrato"], "no": int(no),
                "clave": str(clave or "").replace("\n", " ").strip(), "bloque": bloque, "partida": seccion,
                "subpartida": subseccion, "texto_padre": texto_padre,
                "descripción": str(desc).replace("\n", " ").strip(), "unidad": str(unidad or "").strip(),
                "cantidad": cantidad, "precio_unitario": pu, "importe": importe,
            })
        elif isinstance(no, str) and no.strip():
            t = no.strip()
            if t.upper().startswith(("SUBTOTAL", "IVA", "TOTAL")):
                continue
            # "a) Cortes", "b). - Reubicación…" son subpartidas; el resto, partidas
            if re.match(r"^[a-z]\s*\)|^[a-z]\s*\)\s*\.|^[a-z]\)\.", t, re.IGNORECASE):
                subseccion = t
            elif not re.match(r"^[IVXL]+[\s.\-]", t) and t.upper() == t and len(t) > 15:
                bloque, seccion, subseccion = t, "", ""  # p. ej. "RETORNO PASEO DE LAS GAVIOTAS…"
            else:
                seccion, subseccion = t, ""
            texto_padre = ""
        elif no is None and desc and not unidad:
            texto_padre = str(desc).replace("\n", " ").strip()
        elif isinstance(f[6] if len(f) > 6 else None, str) and str(f[6]).upper().startswith("SUBTOTAL"):
            break
    wb.close()
    return info, pd.DataFrame(conceptos)


def cargar_catalogos(carpeta: Path) -> tuple[list[dict], pd.DataFrame]:
    infos, tablas = [], []
    for ruta in sorted(carpeta.glob("*.xls*")):
        if ruta.name.startswith("~$"):
            continue
        try:
            info, conc = leer_catalogo(ruta)
        except Exception as exc:
            print(f"⚠️  No se pudo leer el catálogo {ruta.name}: {exc}")
            continue
        if conc.empty:
            continue
        infos.append(info)
        tablas.append(conc)
        print(f"📘 Catálogo {info['contrato']} ({info['puente']}): {len(conc)} conceptos")
    return infos, (pd.concat(tablas, ignore_index=True) if tablas else pd.DataFrame())


# --------------------------------------------------------------------------
# SIMILITUD ACTIVIDAD ↔ CONCEPTO
# --------------------------------------------------------------------------
VACIAS = set("""de la el los las en para con por del al un una y o a e se su sus que como sin
incluye incluyen incluido mano obra equipo equipos herramienta herramientas todo lo necesario correcta
ejecucion puot p.u.o.t unidad terminada acarreos acarreo limpieza materiales material cualquier
dentro fuera continua continuacion continuacion inicia inicio trabajos trabajo actividades segun proyecto
indique dependencia este esta estos concepto conceptos realizar ejecutar""".split())

# Frases del reporte de obra → palabras del catálogo (mejora la coincidencia)
SINONIMOS = [
    (r"\breperfora", "reperforacion pilas perforacion relleno fluido"),
    (r"\bperforaci[oó]n\b.*\bpila|\bpila.*\bperforaci[oó]n", "perforacion alojar pilas cimentacion"),
    (r"relleno fluido|concreto fluido", "concreto fluido estabilizacion paredes perforacion pilas"),
    (r"(izaje|izado|colado)[^.]*\bpila", "concreto pilas cimentacion"),
    (r"(acero|armado|habilitado)[^.]*\bpila", "acero refuerzo pilas cimentacion"),
    (r"(acero|armado|habilitado)[^.]*\bzapata", "acero refuerzo zapatas"),
    (r"\b(acero|armado|habilitado)\b", "acero refuerzo"),
    (r"colado[^.]*\bzapata", "concreto zapatas"),
    (r"plantilla", "concreto plantillas"),
    (r"m[eé]nsula|muro respaldo|cabezal", "cabezales respaldos topes laterales zoclos"),
    (r"columna", "columnas"),
    (r"excavaci[oó]n[^.]*zapata|caja para", "excavacion caja desplante zapatas"),
    (r"relleno[^.]*(zapata|fondo)", "rellenos"),
    (r"demolici[oó]n[^.]*losa|corte de losa", "demolicion concreto hidraulico losas rodamiento"),
    (r"terrapl[eé]n", "terraplenes formacion compactacion"),
    (r"tuber[ií]a", "suministro colocacion tuberia"),
    (r"ductos|cfe|media tensi[oó]n|baja tensi[oó]n|libranza", "ductos registros media tension cfe linea"),
    (r"fibra", "reubicacion lineas fibra optica"),
    (r"desv[ií]o", "camino desvio"),
    (r"banderer", "jornada banderero"),
    (r"sondeo", "sondeo localizacion infraestructura existente"),
    (r"poste", "retiro postes"),
    (r"bacheo|bache", "bacheo"),
    (r"señal|luces destellantes|barrera", "senalamiento dispositivos proteccion obra"),
]


# Palabra principal de la actividad: si el reporte la menciona, se prefieren los conceptos que también la
# tienen (en la descripción o en su partida) y se castigan los que no. Evita, por ejemplo, que
# "tubería de 24 plg" caiga en "codo de 24 plg".
CLAVES = ["tuberia", "ducto", "registro", "pila", "zapata", "columna", "cabezal", "mensula", "respaldo",
          "terraplen", "retorno", "desvio", "demolicion", "sondeo", "poste", "banqueta", "guarnicion",
          "fibra", "valvula", "plantilla", "relleno", "excavacion", "senal", "luminaria", "alumbrado"]


# Palabras de conceptos muy específicos: si el reporte no las dice, ese concepto se castiga
EXCLUYENTES = ["reperforacion", "codo", "brida", "empaque", "extremidad", "tapa", "alivio", "atraque",
               "proyecto ejecutivo", "pago concepto", "transplante", "derribo"]
RE_PULG = re.compile(r"(\d{1,2})\s*(?:\"|''|”|“|plgs?\b|pulg\w*)")


def _tokens(texto: str) -> list[str]:
    t = _norm(texto)
    pulgadas = [f"{n}pulg" for n in re.findall(r"(\d{1,2})\s*(?:\"|''|”|“|plgs?\b|pulg\w*)", t)]
    palabras = [w[:7] for w in re.findall(r"[a-zñ]{3,}", t) if w not in VACIAS]
    return palabras + pulgadas


def _expandir(texto: str) -> str:
    extra = [s for patron, s in SINONIMOS if re.search(patron, texto, re.IGNORECASE)]
    return texto + " " + " ".join(extra)


class Clasificador:
    def __init__(self, conceptos: pd.DataFrame):
        self.conceptos = conceptos.reset_index(drop=True)
        docs = []
        for _, c in self.conceptos.iterrows():
            # La descripción pesa doble; la partida y el texto padre dan contexto
            docs.append(Counter(_tokens(c["descripción"]) * 2 + _tokens(c["texto_padre"]) * 2
                                + _tokens(c["partida"]) + _tokens(c["subpartida"]) + _tokens(c["bloque"]) * 2))
        n = len(docs)
        df = Counter(t for d in docs for t in d)
        self.idf = {t: math.log((n + 1) / (k + 0.5)) for t, k in df.items()}
        self.vecs = [self._pesar(d) for d in docs]
        self.textos = [_norm(" ".join(str(c[k]) for k in ("descripción", "texto_padre", "subpartida", "partida", "bloque")))
                       for _, c in self.conceptos.iterrows()]
        self.descs = [_norm(str(c["descripción"]) + " " + str(c["texto_padre"])) for _, c in self.conceptos.iterrows()]

    def _pesar(self, conteo: Counter) -> dict:
        v = {t: (1 + math.log(k)) * self.idf.get(t, 0.0) for t, k in conteo.items()}
        norma = math.sqrt(sum(x * x for x in v.values())) or 1.0
        return {t: x / norma for t, x in v.items()}

    def sugerir(self, texto: str, puente: str | None = None, n: int = 3) -> list[tuple[int, float]]:
        q = self._pesar(Counter(_tokens(_expandir(texto))))
        if not q:
            return []
        t = _norm(texto)
        claves = [k for k in CLAVES if k in t]
        excl = [k for k in EXCLUYENTES if k not in t]
        diametros = set(RE_PULG.findall(t))
        puntajes = []
        for i, v in enumerate(self.vecs):
            if puente and self.conceptos.at[i, "puente"] != puente:
                continue
            s = sum(x * v.get(tok, 0.0) for tok, x in q.items())
            for k in claves:
                donde = self.textos[i] if k == "retorno" else self.descs[i]
                s *= 1.35 if k in donde else 0.75
            for k in excl:
                if k in self.descs[i]:
                    s *= 0.6
            if diametros:
                d_conc = set(RE_PULG.findall(self.descs[i]))
                if d_conc:
                    s *= 1.4 if diametros & d_conc else 0.5
            if s > 0:
                puntajes.append((i, s))
        puntajes.sort(key=lambda x: -x[1])
        return puntajes[:n]

    def etiqueta(self, i: int) -> str:
        c = self.conceptos.loc[i]
        desc = c["descripción"]
        if c["texto_padre"] and len(desc) < 40:
            desc = f"{c['texto_padre']} {desc}"
        desc = desc if len(desc) <= 110 else desc[:110].rsplit(" ", 1)[0] + "…"
        return f"{c['no']} · {desc} ({c['unidad']})"


def confianza(puntaje: float) -> str:
    return "Alta" if puntaje >= 0.60 else "Media" if puntaje >= 0.35 else "Baja"


def asignar_conceptos(actividades: pd.DataFrame, clasif: Clasificador) -> pd.DataFrame:
    """Agrega a cada actividad el concepto sugerido de su contrato y avisa si
    el texto se parece claramente más a un concepto del otro contrato."""
    if actividades.empty:
        return actividades
    act = actividades.copy()
    cols = {k: [] for k in ["concepto_no", "concepto_sugerido", "unidad_concepto", "similitud",
                            "confianza", "otras_opciones", "aviso_contrato"]}
    for _, r in act.iterrows():
        texto = f"{r['actividad']}"
        propias = clasif.sugerir(texto, r.get("puente") or None)
        todas = clasif.sugerir(texto, None, n=1)
        if propias:
            i, s = propias[0]
            c = clasif.conceptos.loc[i]
            cols["concepto_no"].append(int(c["no"]))
            cols["concepto_sugerido"].append(clasif.etiqueta(i))
            cols["unidad_concepto"].append(c["unidad"])
            cols["similitud"].append(round(s, 2))
            cols["confianza"].append(confianza(s))
            cols["otras_opciones"].append(" | ".join(clasif.etiqueta(j) for j, _ in propias[1:]))
        else:
            for k in ["concepto_no", "concepto_sugerido", "unidad_concepto", "similitud", "confianza", "otras_opciones"]:
                cols[k].append(None if k in ("concepto_no", "similitud") else "")
            s = 0.0
        aviso = ""
        if todas:
            j, s2 = todas[0]
            otro = clasif.conceptos.at[j, "puente"]
            if otro != r.get("puente") and s2 >= 0.60 and s2 > s * 1.5:
                aviso = f"Se parece más a {otro}: {clasif.etiqueta(j)}"
        cols["aviso_contrato"].append(aviso)
    for k, v in cols.items():
        act[k] = v
    return act


# --------------------------------------------------------------------------
# AVANCE POR CONCEPTO
# --------------------------------------------------------------------------
_UNIDAD_REPORTE = {"m3": "m3", "m³": "m3", "m": "m", "ml": "m", "mts": "m", "mt": "m", "metros": "m",
                   "kg": "kg", "ton": "ton", "tons": "ton"}
_UNIDAD_CATALOGO = {"m3": "m3", "m³": "m3", "ml": "m", "m": "m", "kg": "kg", "ton": "ton"}


def _cantidades(texto: str) -> list[tuple[float, str]]:
    out = []
    for num, uni in re.findall(r"(\d+(?:[.,]\d+)?)\s*(m3|m³|ml|mts?|metros|kg|tons?|m)(?![a-z0-9²³])",
                               str(texto or ""), re.IGNORECASE):
        u = _UNIDAD_REPORTE.get(uni.lower())
        if u:
            out.append((float(num.replace(",", ".")), u))
    return out


def avance_por_concepto(actividades: pd.DataFrame, conceptos: pd.DataFrame) -> pd.DataFrame:
    """Agrupa las actividades por concepto sugerido (confianza media o alta) y suma
    las cantidades reportadas que vienen en la misma unidad que el concepto."""
    if actividades.empty or "concepto_no" not in actividades:
        return pd.DataFrame()
    a = actividades[actividades["concepto_no"].notna() & actividades["confianza"].isin(["Alta", "Media"])]
    filas = []
    for (pte, no), g in a.groupby(["puente", "concepto_no"]):
        c = conceptos[(conceptos["puente"] == pte) & (conceptos["no"] == int(no))].iloc[0]
        u_cat = _UNIDAD_CATALOGO.get(_norm(c["unidad"]).strip(), "")
        suma = 0.0
        for t in g["actividad"]:
            for valor, u in _cantidades(t):
                if u == u_cat and u != "m":  # las profundidades en "m" se ven en la tabla de pilas
                    suma += valor
        filas.append({
            "puente": pte, "concepto": int(no), "clave": c["clave"],
            "descripción": (c["texto_padre"] + " " + c["descripción"]).strip() if len(c["descripción"]) < 40 else c["descripción"],
            "unidad": c["unidad"], "cantidad_catálogo": c["cantidad"], "precio_unitario": c["precio_unitario"],
            "días_con_actividad": g["fecha"].nunique(),
            "primera_fecha": g["fecha"].min(), "última_fecha": g["fecha"].max(),
            "cantidad_reportada_whatsapp": suma if suma else None,
            "importe_reportado_estimado": suma * c["precio_unitario"] if suma and c["precio_unitario"] else None,
            "ejemplo_de_actividad": g["actividad"].iloc[-1],
            "nota": ("Para pilas usar la hoja 'Pilas vs catálogo' del control de pilas: ahí se quitan reportes "
                     "repetidos y colados duplicados") if "pilas" in _norm(c["descripción"] + c["texto_padre"]) else "",
        })
    return pd.DataFrame(filas).sort_values(["puente", "concepto"]) if filas else pd.DataFrame()
