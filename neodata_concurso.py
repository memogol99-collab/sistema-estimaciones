"""
Lectura de los documentos de concurso impresos por NEODATA (texto de los PDF con
`pdftotext -layout`):
  - Doc. 15  Listado de insumos       → código, descripción, unidad, precio, tipo
  - Doc. 14c Análisis de básicos      → componentes y costo directo de cada básico/cuadrilla
  - Doc. 14a Análisis de P.U.         → cada matriz: renglones, costo directo, base ISN y P.U.

También calibra la base del ISN (impuesto sobre nómina) por insumo con las 360 matrices,
para que los extraordinarios calculen el ISN igual que el concurso.
"""

import re
import subprocess
from pathlib import Path

import numpy as np

NUM = r"-?[\d,]+\.\d+"
RE_COLA = re.compile(rf"\s\$(?P<precio>{NUM})\s+(?P<op>[*/])\s+(?P<cant>{NUM})\s+\$(?P<importe>{NUM})(?:\s+(?P<pct>{NUM})%)?\s*$")


class _Renglon(dict):
    def __getitem__(self, k):
        return dict.__getitem__(self, k)


class RE_RENGLON:  # noqa: N801 — mismo uso que un patrón compilado: RE_RENGLON.match(linea)
    """Renglón de matriz: CÓDIGO  descripción  UNIDAD  $precio  op  cantidad  $importe  [%].
    Se lee de derecha a izquierda para evitar expresiones lentas."""

    @staticmethod
    def match(linea: str):
        m = RE_COLA.search(linea)
        if not m:
            return None
        cabeza = linea[:m.start()].rstrip()
        partes = cabeza.split(None, 1)
        if len(partes) < 2:
            return None
        codigo, resto = partes
        trozos = re.split(r"\s{2,}", resto.strip())
        if len(trozos) < 2:
            return None
        unidad = trozos[-1]
        desc = " ".join(trozos[:-1])
        return _Renglon(codigo=codigo, desc=desc, unidad=unidad, precio=m["precio"], op=m["op"],
                        cant=m["cant"], importe=m["importe"], pct=m["pct"])


RE_INSUMO = re.compile(
    rf"^(?P<codigo>\S+)\s+(?P<desc>.+?)\s{{2,}}(?P<unidad>\S+(?: \S+)?)\s+(?P<cant>{NUM})\s+\$(?P<precio>{NUM})\s+\$(?P<importe>{NUM})\s+(?P<pct>{NUM})%\s*$")
SECCIONES = {"MATERIALES": "MAT", "MANO DE OBRA": "MO", "EQUIPO Y HERRAMIENTA": "EQ", "BASICOS": "BAS", "BÁSICOS": "BAS"}


def _n(x: str) -> float:
    return float(x.replace(",", ""))


def texto_pdf(ruta: Path) -> str:
    """Texto de un PDF (usa pdftotext). Si existe un .txt con el mismo nombre, lo usa."""
    txt = ruta.with_suffix(".txt")
    if txt.exists():
        return txt.read_text(encoding="utf-8", errors="replace")
    out = subprocess.run(["pdftotext", "-layout", str(ruta), "-"], capture_output=True, text=True, check=True).stdout
    return out


# --------------------------------------------------------------------------
# Doc. 15 — INSUMOS
# --------------------------------------------------------------------------
def leer_insumos(texto: str) -> dict:
    insumos, tipo = {}, "MAT"
    for linea in texto.splitlines():
        l = linea.strip()
        if l in ("MATERIALES",):
            tipo = "MAT"
        elif l.startswith("MANO DE OBRA"):
            tipo = "MO"
        elif l.startswith("EQUIPO Y HERRAMIENTA"):
            tipo = "EQ"
        m = RE_INSUMO.match(l)
        if m:
            insumos[m["codigo"]] = {"codigo": m["codigo"], "descripcion": m["desc"].strip(), "unidad": m["unidad"].strip(),
                                    "precio": _n(m["precio"]), "tipo": tipo, "origen": "Doc. 15 (insumo del concurso)"}
    return insumos


# --------------------------------------------------------------------------
# Renglones de un análisis (sirve para básicos del Doc. 14c y matrices del Doc. 14a)
# --------------------------------------------------------------------------
RE_CAB_SUB = re.compile(r"^((?:BA-|MOCU)\S+)\s+(.+?)\s{2,}(\S+)\s*$")
RE_CIERRE = re.compile(rf"^(Volumen|Rendimiento):.*?({NUM})\s+\$({NUM})")


class _Lector:
    """Acumula los renglones de un análisis. Los sub-bloques (cuadrilla o básico expandido, que
    terminan en 'Importe:' y 'Volumen:'/'Rendimiento:') quedan como un renglón con sus componentes."""

    def __init__(self):
        self.renglones, self.seccion, self.sub, self.comp = [], None, None, []

    def linea(self, l: str) -> bool:
        if l in SECCIONES:
            self.seccion, self.sub, self.comp = SECCIONES[l], None, []
            return True
        if self.seccion is None:
            return False
        m = RE_CIERRE.match(l)
        if m and self.sub:
            op = "/" if m[1] == "Rendimiento" else "*"
            self.renglones.append({**self.sub, "precio": round(sum(c["importe"] for c in self.comp), 2), "op": op,
                                   "cantidad": _n(m[2]), "importe": _n(m[3]), "seccion": self.seccion,
                                   "es_basico": True, "componentes": self.comp})
            self.sub, self.comp = None, []
            return True
        r = RE_RENGLON.match(l)
        if r:
            d = {"codigo": r["codigo"], "descripcion": r["desc"].strip(), "unidad": r["unidad"].strip(),
                 "precio": _n(r["precio"]), "op": r["op"], "cantidad": _n(r["cant"]), "importe": _n(r["importe"]),
                 "seccion": self.seccion}
            (self.comp if self.sub else self.renglones).append(d)
            return True
        m = RE_CAB_SUB.match(l)
        if m and not l.startswith(("SUBTOTAL", "Importe")):
            self.sub = {"codigo": m[1], "descripcion": m[2].strip(), "unidad": m[3]}
            self.comp = []
            return True
        return False


# --------------------------------------------------------------------------
# Doc. 14c — BÁSICOS Y CUADRILLAS
# --------------------------------------------------------------------------
def leer_basicos(texto: str) -> dict:
    basicos, actual, lector = {}, None, None
    lineas = texto.splitlines()
    for i, linea in enumerate(lineas):
        l = linea.strip()
        m = re.match(r"^Análisis:\s+(\S+)\s+(\S+)\s*$", l)
        if m:
            desc = next((x.strip() for x in lineas[i + 1:i + 4] if x.strip()), "")
            lector = _Lector()
            actual = {"codigo": m[1], "unidad": m[2], "descripcion": desc, "renglones": lector.renglones, "cd": None}
            basicos[m[1]] = actual
            continue
        if actual is None:
            continue
        m = re.match(rf"^Costo Directo:\s+\$({NUM})", l)
        if m:
            actual["cd"] = _n(m[1])
            continue
        lector.linea(l)
    return basicos


# --------------------------------------------------------------------------
# Doc. 14a — MATRICES DE P.U.
# --------------------------------------------------------------------------
def leer_matrices(texto: str) -> dict:
    matrices, actual, lector = {}, None, None
    lineas = texto.splitlines()
    for i, linea in enumerate(lineas):
        l = linea.strip()
        m = re.match(rf"^Análisis:\s+(\d+)\s+(.+?)\s+({NUM})\s+\$({NUM})\s*$", l)
        if m:
            desc = []
            for x in lineas[i + 1:i + 12]:
                xs = x.strip()
                if not xs:
                    continue
                if xs in SECCIONES or RE_RENGLON.match(xs):
                    break
                desc.append(xs)
            lector = _Lector()
            actual = {"no": int(m[1]), "unidad": m[2].strip(), "cantidad": _n(m[3]), "descripcion": " ".join(desc),
                      "renglones": lector.renglones, "cd": None, "base_isn": None, "pu": None}
            matrices[actual["no"]] = actual
            continue
        if actual is None:
            continue
        m = re.match(rf"^\(A\) COSTO DIRECTO\s+\$({NUM})", l)
        if m:
            actual["cd"] = _n(m[1])
            continue
        m = re.match(rf"^\(J\) ISN .*?x\s+({NUM})\s+\$({NUM})", l)
        if m:
            actual["base_isn"] = _n(m[1])
            continue
        m = re.match(rf"^\(K\) PRECIO UNITARIO .*?\$({NUM})\s*$", l)
        if m:
            actual["pu"] = _n(m[1])
            continue
        lector.linea(l)
    return matrices


# --------------------------------------------------------------------------
# CALIBRACIÓN DE LA BASE DEL ISN
# --------------------------------------------------------------------------
def aportes_isn(renglones: list[dict], basicos: dict, factor: float = 1.0, _prof: int = 0) -> dict:
    """Importe de salarios ("MO") y de cada equipo ("EQ-…") dentro de una lista de renglones.
    Las cuadrillas (MOCU) y los básicos (BA-) se abren con el Doc. 14c, en cualquier nivel."""
    out: dict = {}

    def sumar(d):
        for k, v in d.items():
            out[k] = out.get(k, 0.0) + v

    for r in renglones:
        imp = r["importe"] * factor
        cod = r["codigo"]
        if r.get("es_basico"):
            suma = sum(c["importe"] for c in r["componentes"]) or 1.0
            sumar(aportes_isn(r["componentes"], basicos, imp / suma, _prof + 1))
        elif cod in basicos and _prof < 6 and basicos[cod]["cd"]:
            sumar(aportes_isn(basicos[cod]["renglones"], basicos, imp / basicos[cod]["cd"], _prof + 1))
        elif cod.startswith("%"):
            continue
        elif r["seccion"] == "MO" or cod.startswith("MO"):
            sumar({"MO": imp})
        elif cod.startswith("EQ-"):
            sumar({cod: imp})
    return out


def calibrar_isn(matrices: dict, basicos: dict) -> dict:
    """Factor de base ISN por peso de importe: uno para salarios y uno por cada equipo.
    1) Salarios: mediana de base/salarios en las matrices sin equipo.
    2) Equipos: mínimos cuadrados no negativos sobre lo que queda."""
    datos = []
    for m in matrices.values():
        if m["base_isn"] is not None:
            datos.append((aportes_isn(m["renglones"], basicos), m["base_isn"]))
    sin_eq = [b / a["MO"] for a, b in datos if a.get("MO") and not any(k.startswith("EQ-") for k in a)]
    k_mo = float(np.median(sin_eq)) if sin_eq else 0.6
    equipos = sorted({k for a, _ in datos for k in a if k.startswith("EQ-")})
    X = np.array([[a.get(e, 0.0) for e in equipos] for a, _ in datos])
    y = np.array([b - k_mo * a.get("MO", 0.0) for a, b in datos])
    activos = list(range(len(equipos)))
    coef = np.zeros(len(equipos))
    for _ in range(40):
        sol, *_ = np.linalg.lstsq(X[:, activos], y, rcond=None)
        if (sol >= 0).all():
            coef[:] = 0
            coef[activos] = sol
            break
        activos = [a for a, v in zip(activos, sol) if v > 0]
    factores = {"MO": k_mo, **{e: float(c) for e, c in zip(equipos, coef)}}
    pred = np.array([sum(factores.get(k, 0.0) * v for k, v in a.items()) for a, _ in datos])
    real = np.array([b for _, b in datos])
    err = np.abs(pred - real) / np.maximum(real, 1)
    factores["_error_mediana"] = float(np.median(err))
    factores["_error_p90"] = float(np.percentile(err, 90))
    return factores


def base_isn(renglones: list[dict], basicos: dict, factores: dict) -> float:
    a = aportes_isn(renglones, basicos)
    eq_prom = np.mean([v for k, v in factores.items() if k.startswith("EQ-")] or [0.1])
    return sum(v * factores.get(k, eq_prom if k.startswith("EQ-") else 0.0) for k, v in a.items())


def cargar_concurso(carpeta: Path) -> dict:
    """Busca en la carpeta los documentos 14a, 14c y 15 (PDF o TXT) y los lee."""
    def buscar(patron):
        for p in sorted(carpeta.glob("*")):
            if re.search(patron, p.name, re.IGNORECASE) and p.suffix.lower() in (".pdf", ".txt"):
                return p
        raise FileNotFoundError(f"No encontré en {carpeta} un archivo que coincida con {patron}")
    insumos = leer_insumos(texto_pdf(buscar(r"15.*insumo")))
    basicos = leer_basicos(texto_pdf(buscar(r"14c.*b[aá]sico")))
    matrices = leer_matrices(texto_pdf(buscar(r"14a.*precio")))
    cabecera = texto_pdf(buscar(r"14a.*precio")).split("ANALISIS DE PRECIOS UNITARIOS")[0]
    return {"insumos": insumos, "basicos": basicos, "matrices": matrices, "isn": calibrar_isn(matrices, basicos),
            "cabecera": cabecera}
