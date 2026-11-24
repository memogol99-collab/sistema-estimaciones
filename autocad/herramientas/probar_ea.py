# -*- coding: utf-8 -*-
"""
Prueba automática de EA (lectura de áreas, reemplazo al etiquetar y
cadenamientos) ejecutando el AutoLISP REAL del bundle con minilisp.

    python herramientas/probar_ea.py
"""
import os
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
from minilisp import Lisp  # noqa: E402

LIB = os.path.join(os.path.dirname(AQUI), "MemoPRO.bundle", "Contents", "LISP", "Sistema", "MEMO_Lib.lsp")
EA = os.path.join(os.path.dirname(AQUI), "MemoPRO.bundle", "Contents", "LISP", "Secciones", "EA_ExportarEstArea.lsp")

AREAS = [  # texto del dibujo -> área que debe ir a Excel
    ("AREA DE CORTE=12.50 M2", 12.5),
    ("AREA DE SUB-BASE=3.25 M2", 3.25),
    ("AREA DE CORTE (M2)=12.50", 12.5),
    ("A= 1,234.56 m2", 1234.56),
    ("\\H0.25x;AREA DE CORTE=7.80", 7.8),
    ("{\\fArial|b0|i0|c0|p34;AREA DE BASE=4.10 M2}", 4.1),
    ("AREA DE RELLENO: 15,5 M2", 15.5),
    ("AREA DE CARPETA - 2.40 M2", 2.4),
    ("ESCALA 1:100", None),
]
REEMPLAZOS = [  # texto, nuevo valor -> resultado
    ("AREA DE CORTE=12.50 M2", "99.99", "AREA DE CORTE=99.99 M2"),
    ("\\H0.25x;AREA DE CORTE 12.50", "99.99", "\\H0.25x;AREA DE CORTE 99.99"),
    ("A=1,234.56 M2", "99.99", "A=99.99 M2"),
    ("AREA DE CORTE (M2)=12.50", "8.00", "AREA DE CORTE (M2)=8.00"),
]
CADS = [("0+020", 20.0), ("1+020.50", 1020.5), ("SECCION 3 KM 1+020", 1020.0),
        ("EST. 2+340", 2340.0), ("\\H0.3x;KM 0+120.00", 120.0)]
TIPOS = [  # texto o nombre de capa -> tipo
    ("AREA DE CORTE=1", "CORTE"), ("\\H0.2x;AREA DE EXCAVACION=2", "EXCAVACION"),
    ("AREA DE SUB-BASE=1", "SUBBASE"), ("AREA DE SUBBASE=1", "SUBBASE"), ("AREA DE BASE=1", "BASE"),
    ("AREA DE TERRAPLEN=3", "TERRAPLEN"), ("AREA DE DESMONTE=3", "DESMONTE"),
    ("SEC-SUBBASE", "SUBBASE"), ("SEC-BASE", "BASE"), ("HATCH_SUBRASANTE", "SUBRASANTE"),
    ("COTAS", None)]

# Dos secciones apiladas, cada una con su recuadro y su CAD; el texto de la
# sección de abajo está MÁS CERCA del CAD de la de arriba.
RECUADRO_A = [[0.0, 0.0], [40.0, 0.0], [40.0, 20.0], [0.0, 20.0]]     # sección 0+020
RECUADRO_B = [[0.0, 22.0], [40.0, 22.0], [40.0, 42.0], [0.0, 42.0]]   # sección 0+040
LAMINA = [[-5.0, -5.0], [45.0, -5.0], [45.0, 50.0], [-5.0, 50.0]]     # marco de la lámina
# CAD de cada sección escrito ARRIBA de su recuadro
CADS_EJ = [["0+020", 20.0, [20.0, 19.0, 0.0]], ["0+040", 40.0, [20.0, 41.0, 0.0]]]


def main():
    L = Lisp()
    L.cargar(LIB)
    L.cargar(EA)
    fallos = 0

    def ver(desc, obtenido, esperado):
        nonlocal fallos
        ok = (obtenido == esperado) or (isinstance(esperado, float) and obtenido is not None
                                         and abs(obtenido - esperado) < 1e-9)
        if not ok:
            fallos += 1
        print("  %s %-45r -> %-28r %s" % ("OK " if ok else "MAL", desc, obtenido, "" if ok else "(esperado %r)" % (esperado,)))

    print("Área que se exporta a Excel:")
    for t, e in AREAS:
        ver(t, L.llamar("extraer-numero", t), e)
    print("Reemplazo del área al etiquetar:")
    for t, v, e in REEMPLAZOS:
        ver(t, L.llamar("reemplazar-solo-numero", t, v), e)
    print("Cadenamientos:")
    for t, e in CADS:
        cl = L.llamar("extraer-cad-limpia", L.llamar("ea:limpiar-mtext", t))
        ver(t, L.llamar("cad-a-numero", cl) if cl else None, e)
    print("Tipo de área:")
    for t, e in TIPOS:
        ver(t, L.llamar("extraer-tipo-de-texto", t), e)
    print("Recuadros de sección:")
    recs = L.llamar("ea:recuadros-de", [RECUADRO_A, RECUADRO_B, LAMINA], CADS_EJ)
    ver("recuadros que contienen CAD", len(recs or []), 3)
    # texto de la sección 0+040 junto a su borde inferior: está a 3.5 m del
    # CAD 0+020 y a 18.5 m del CAD 0+040. El método "más cercano" lo mandaba
    # a 0+020 (error); con recuadros va a 0+040.
    cercano = min(CADS_EJ, key=lambda c: ((c[2][0] - 20) ** 2 + (c[2][1] - 22.5) ** 2))[0]
    ver("(antes) CAD más cercano al texto en (20,22.5)", cercano, "0+020")
    r = L.llamar("ea:recuadro-de", [20.0, 22.5, 0.0], recs)
    cads_r = r[6] if r else []
    ver("texto en (20,22.5) -> CAD del recuadro", [c[0] for c in cads_r], ["0+040"])
    r = L.llamar("ea:recuadro-de", [20.0, 10.0, 0.0], recs)
    ver("texto en (20,10) -> CAD del recuadro", [c[0] for c in (r[6] if r else [])], ["0+020"])
    ver("texto fuera de todo recuadro", L.llamar("ea:recuadro-de", [100.0, 100.0, 0.0], recs), None)
    ver("punto en polígono (dentro)", L.llamar("ea:pt-en-pol", 5.0, 5.0, RECUADRO_A) is not None, True)
    ver("punto en polígono (fuera)", L.llamar("ea:pt-en-pol", 5.0, 25.0, RECUADRO_A), None)
    ver("área del recuadro", L.llamar("ea:area-pol", RECUADRO_A), 800.0)
    print("Fórmulas de la hoja RESUMEN:")
    ver("suma de 2 columnas", L.llamar("ea:suma-cols", ["H", "J"], 7), "=SUM(VOLUMEN!H7,VOLUMEN!J7)")
    ver("sin columnas", L.llamar("ea:suma-cols", None, 7), 0)
    print("\nRESULTADO:", "OK" if not fallos else "%d prueba(s) fallaron" % fallos)
    return 1 if fallos else 0


if __name__ == "__main__":
    sys.exit(main())
