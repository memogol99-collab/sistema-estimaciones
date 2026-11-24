# -*- coding: utf-8 -*-
"""
Prueba automática de las herramientas de áreas (MEMO_Areas.lsp + MEMO_Lib.lsp)
ejecutando el AutoLISP REAL del bundle con minilisp.

    python herramientas/probar_areas.py
"""
import math
import os
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
from minilisp import Lisp, Sym  # noqa: E402

LISP = os.path.join(os.path.dirname(AQUI), "MemoPRO.bundle", "Contents", "LISP")
CFG = {}


def main():
    L = Lisp()
    L.cargar(os.path.join(LISP, "Sistema", "MEMO_Lib.lsp"))
    L.cargar(os.path.join(LISP, "Secciones", "MEMO_Areas.lsp"))
    L.glob[Sym("MEMO:CFG")] = lambda k: CFG.get(k, "")
    fallos = 0

    def ver(desc, obtenido, esperado, tol=1e-6):
        nonlocal fallos
        if isinstance(esperado, float):
            ok = obtenido is not None and abs(obtenido - esperado) <= tol
        else:
            ok = obtenido == esperado
        if not ok:
            fallos += 1
        print("  %s %-52s -> %-34r %s" % ("OK " if ok else "MAL", desc, obtenido, "" if ok else "(esperado %r)" % (esperado,)))

    print("Escribir el área en un texto (memo:texto-area):")
    CFG.clear()
    ver("NUMERO: conserva el texto", L.llamar("memo:texto-area", "AREA DE CORTE=12.50 M2", "13.10", "CORTE"), "AREA DE CORTE=13.10 M2")
    ver("NUMERO: MTEXT con formato", L.llamar("memo:texto-area", "\\H0.2x;A=1.00m2", "7.25", None), "\\H0.2x;A=7.25m2")
    ver("NUMERO: '=' sin número -> agrega", L.llamar("memo:texto-area", "AREA DE BASE=", "4.10", "BASE"), "AREA DE BASE=4.10m2")
    ver("NUMERO: texto sin número -> completo", L.llamar("memo:texto-area", "AREA", "4.10", "BASE"), "AREA DE BASE=4.10m2")
    CFG.update({"AREA_ESCRITURA": "COMPLETO", "AREA_PREF_TIPO": "NO"})
    ver("COMPLETO estilo HA (A=…m2)", L.llamar("memo:texto-area", "lo que sea", "25.50", "CORTE"), "A=25.50m2")
    CFG.update({"AREA_PREFIJO": "A= ", "AREA_SUFIJO": " m²"})
    ver("COMPLETO estilo AM2 (A= … m²)", L.llamar("memo:texto-area", "x", "25.50", None), "A= 25.50 m²")
    CFG.update({"AREA_PREF_TIPO": "SI", "AREA_SUFIJO": "M2", "AREA_MAYUSCULAS": "SI"})
    ver("COMPLETO estilo AH (AREA DE …=…M2)", L.llamar("memo:texto-area", "x", "25.50", "CORTE"), "AREA DE CORTE=25.50M2")
    CFG.update({"AREA_SUFIJO": "NINGUNO", "AREA_PREF_TIPO": "NO", "AREA_PREFIJO": "A=", "AREA_MAYUSCULAS": "NO"})
    ver("COMPLETO sin sufijo", L.llamar("memo:texto-area", "x", "3.00", None), "A=3.00")
    CFG.clear()

    print("AC: reemplazar después del patrón:")
    ver("AC=12.5 M2", L.llamar("ar:reemplazar-tras-patron", "AC=12.5 M2", "AC=", "20.00"), "AC=20.00 M2")
    ver("ACA= sin número", L.llamar("ar:reemplazar-tras-patron", "ACA= M2", "ACA=", "3.10"), "ACA=3.10 M2")
    ver("'=' seguido de M2 no toma el 2", L.llamar("memo:texto-area", "AREA DE BASE= M2", "4.10", "BASE"), "AREA DE BASE=4.10 M2")
    ver("dos patrones en un texto", L.llamar("ar:reemplazar-tras-patron", "AC=1.00 AB=2.00", "AB=", "9.99"), "AC=1.00 AB=9.99")

    print("CAS: geometría de las figuras:")
    def analizar(pts, area):
        return L.llamar("ar:analizar", [[float(x), float(y)] for x, y in pts], float(area), 2)
    # Triángulo equilátero de lado 2: área 1.7321; antes mostraba (2*2)/2 = 2
    eq = [(0, 0), (2, 0), (1, math.sqrt(3))]
    r = analizar(eq, math.sqrt(3))
    ver("triángulo equilátero: tipo", r[0], "TRIANGULO")
    ver("triángulo: b*h/2 cuadra con el área", r[1], "TRIANGULO\\P=(b*h)/2\\P=(2.00*1.73)/2\\P=1.73 m2")
    # Trapecio con lados paralelos en el PRIMER par
    r = analizar([(0, 0), (10, 0), (7, 4), (2, 4)], 30)
    ver("trapecio (paralelos p1p2/p3p4)", r[0:2], ["TRAPECIO", "TRAPECIO\\P=(B+b)*h/2\\P=(10.00+5.00)*4.00/2\\P=30.00 m2"])
    # Mismo trapecio empezando en otro vértice: paralelos en el SEGUNDO par (antes salía mal)
    r = analizar([(10, 0), (7, 4), (2, 4), (0, 0)], 30)
    ver("trapecio (paralelos p2p3/p4p1)", r[0:2], ["TRAPECIO", "TRAPECIO\\P=(B+b)*h/2\\P=(10.00+5.00)*4.00/2\\P=30.00 m2"])
    ver("trapecio: altura dibujada h=4", r[4][2], 4.0)
    r = analizar([(0, 0), (6, 0), (6, 3), (0, 3)], 18)
    ver("rectángulo", r[1], "RECTANGULO\\P=b*h\\P=6.00*3.00\\P=18.00 m2")
    r = analizar([(0, 0), (6, 1), (7, 5), (1, 3)], 20.5)
    ver("cuadrilátero irregular (no es trapecio)", r[0], "CUADRILATERO")

    print("AS: área entre terreno y corte:")
    terreno = [[0.0, 10.0], [5.0, 11.0], [10.0, 10.0]]
    corte = [[0.0, 8.0], [5.0, 8.0], [10.0, 8.0]]
    trs = L.llamar("ar:trapecios", terreno, corte)
    ver("3 vértices: 2 trapecios", len(trs), 2)
    ver("3 vértices: área total", sum(t[4] for t in trs), 25.0)
    # 5 vértices de terreno y corte con x distintas (antes no funcionaba)
    terreno = [[0.0, 10.0], [2.0, 11.0], [4.0, 12.0], [6.0, 11.0], [8.0, 10.0]]
    corte = [[0.0, 8.0], [8.0, 8.0]]
    trs = L.llamar("ar:trapecios", terreno, corte)
    ver("5 vértices vs 2: área total", sum(t[4] for t in trs), 2 * (2 * (2 + 3) / 2) + 2 * (2 * (3 + 4) / 2))
    print("\nRESULTADO:", "OK" if not fallos else "%d prueba(s) fallaron" % fallos)
    return 1 if fallos else 0


if __name__ == "__main__":
    sys.exit(main())
