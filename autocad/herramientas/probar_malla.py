# -*- coding: utf-8 -*-
"""
Prueba automática de la interpolación de MALLA-PUNTOS (sin AutoCAD).

Ejecuta el código AutoLISP REAL del bundle (MP_MallaPuntos.lsp) con el
intérprete minilisp.py sobre terrenos sintéticos cuya elevación exacta se
conoce, y compara el método nuevo (ENTRECURVAS) con el anterior (IDW).

    python herramientas/probar_malla.py
"""
import math
import os
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
from minilisp import Lisp, Sym  # noqa: E402

MALLA = os.path.join(os.path.dirname(AQUI), "MEMO_SISTEMA.bundle", "Contents", "LISP", "Topografia", "MP_MallaPuntos.lsp")


def circulo(r, n=72):
    return [[r * math.cos(2 * math.pi * i / n), r * math.sin(2 * math.pi * i / n)] for i in range(n)]


CASOS = [
    # nombre, curvas (z verts cerrada), elevación exacta, puntos, error medio máx. permitido
    ("Cono, curvas cada 10 m",
     [[100 - 0.1 * r, circulo(r), Sym("T")] for r in range(10, 101, 10)],
     lambda p: 100 - 0.1 * math.hypot(*p),
     [[float(x), float(y)] for x in range(-90, 91, 6) for y in range(-90, 91, 6) if 10 <= math.hypot(x, y) <= 95],
     0.02),
    ("Plano, curvas rectas cada 30 m",
     [[0.05 * x, [[float(x), 0.0], [float(x), 200.0]], None] for x in range(0, 301, 30)],
     lambda p: 0.05 * p[0],
     [[float(x), float(y)] for x in range(2, 299, 4) for y in range(10, 191, 20)],
     0.01),
    ("Ladera ondulada, curvas cada 1 m",
     [[float(z), [[float(x), (z - 2 * math.sin(x / 20)) / 0.1] for x in range(0, 201, 5)], None] for z in range(0, 21)],
     lambda p: 0.1 * p[1] + 2 * math.sin(p[0] / 20),
     [[float(x), float(y)] for x in range(3, 198, 7) for y in range(30, 170, 7)],
     0.03),
    ("Batimetría (Z negativas), curvas cada 1 m",
     [[-0.1 * r, circulo(r), Sym("T")] for r in range(10, 101, 10)],
     lambda p: -0.1 * math.hypot(*p),
     [[float(x), float(y)] for x in range(-90, 91, 9) for y in range(-90, 91, 9) if 10 <= math.hypot(x, y) <= 95],
     0.02),
]


def main():
    L = Lisp()
    L.cargar(MALLA)
    L.glob[Sym("MEMO:CFG")] = lambda k: ""
    L.glob[Sym("MEMO:CFG-NUM")] = lambda k: 0.0
    fallos = 0
    for nombre, curvas, exacta, puntos, tolerancia in CASOS:
        L.llamar("mpi:preparar", curvas)
        prep = L.llamar("mp-prepare-curves", curvas)
        print("== %s (%d puntos)" % (nombre, len(puntos)))
        for metodo, fn in (("ENTRECURVAS", lambda p: L.llamar("mpi:entre-curvas", p)),
                           ("IDW anterior", lambda p: L.llamar("mpi:idw", p, prep, 2))):
            res = [fn(p) for p in puntos]
            err = [abs(r - exacta(p)) for r, p in zip(res, puntos) if r is not None]
            huecos = sum(r is None for r in res)
            medio = sum(err) / len(err) if err else float("inf")
            print("   %-13s error medio %.3f m   máx %.3f m   puntos sin valor %d" % (metodo, medio, max(err or [0]), huecos))
            if metodo == "ENTRECURVAS" and (medio > tolerancia or huecos):
                fallos += 1
                print("   ** FALLA: se esperaba error medio <= %.3f y 0 puntos sin valor" % tolerancia)
    print("\nRESULTADO:", "OK" if not fallos else "%d caso(s) fallaron" % fallos)
    return 1 if fallos else 0


if __name__ == "__main__":
    sys.exit(main())
