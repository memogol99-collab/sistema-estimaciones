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

EA = os.path.join(os.path.dirname(AQUI), "MEMO_SISTEMA.bundle", "Contents", "LISP", "Secciones", "EA_ExportarEstArea.lsp")

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
TIPOS = [("AREA DE CORTE=1", "CORTE"), ("\\H0.2x;AREA DE EXCAVACION=2", "EXCAVACION"),
         ("AREA DE SUB-BASE=1", "BASE"), ("AREA DE TERRAPLEN=3", "TERRAPLEN")]


def main():
    L = Lisp()
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
    print("\nRESULTADO:", "OK" if not fallos else "%d prueba(s) fallaron" % fallos)
    return 1 if fallos else 0


if __name__ == "__main__":
    sys.exit(main())
