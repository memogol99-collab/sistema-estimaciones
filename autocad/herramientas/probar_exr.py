# -*- coding: utf-8 -*-
"""
Prueba de EXR (generador de bacheo en Excel): ejecuta exr:llenar del
bundle con minilisp, simulando la hoja de Excel, y verifica en qué celdas
quedan No./LARGO/ANCHO, la calle, el espesor y el número de bloques.

    python herramientas/probar_exr.py
"""
import os
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
from minilisp import Lisp, Sym  # noqa: E402

LISP = os.path.join(os.path.dirname(AQUI), "MemoPRO.bundle", "Contents", "LISP")


def main():
    L = Lisp()
    L.cargar(os.path.join(LISP, "Sistema", "MEMO_Lib.lsp"))
    L.cargar(os.path.join(LISP, "Bacheo", "MEMO_Bacheo.lsp"))
    hoja, ajustes = {}, []
    L.glob[Sym("EXR:PONER")] = lambda ws, f, c, v: hoja.__setitem__((f, c), v)
    L.glob[Sym("EXR:FORMULA")] = lambda ws, f, c, v: hoja.__setitem__((f, c), v)
    L.glob[Sym("EXR:AJUSTAR-BLOQUES")] = lambda ws, n: ajustes.append(n)
    fallos = 0

    def ver(desc, obtenido, esperado):
        nonlocal fallos
        ok = obtenido == esperado
        fallos += not ok
        print("  %s %-48s -> %-28r %s" % ("OK " if ok else "MAL", desc, obtenido, "" if ok else "(esperado %r)" % (esperado,)))

    def lista(n):
        return [[i + 1, 1.0 + i / 1000.0, 0.8, 0.8, 0.0] for i in range(n)]

    print("130 baches, espesor 0.10:")
    b = L.llamar("exr:llenar", "WS", lista(130), "AV. HIDALGO", 0.1)
    ver("bloques", b, 2)
    ver("ajustar-bloques", ajustes, [2])
    ver("No. 1 en A19", hoja.get((19, 1)), 1)
    ver("LARGO 1 en B19", hoja.get((19, 2)), 1.0)
    ver("ANCHO 1 en C19", hoja.get((19, 3)), 0.8)
    ver("No. 22 en A40", hoja.get((40, 1)), 22)
    ver("No. 23 en G19", hoja.get((19, 7)), 23)
    ver("No. 110 en Y40", hoja.get((40, 25)), 110)
    ver("No. 111 en A63 (bloque 2)", hoja.get((63, 1)), 111)
    ver("No. 130 en A82", hoja.get((82, 1)), 130)
    ver("LARGO 130 redondeado", hoja.get((82, 2)), 1.13)
    ver("calle bloque 1 (A16)", hoja.get((16, 1)), "AV. HIDALGO")
    ver("calle bloque 2 (A60)", hoja.get((60, 1)), "AV. HIDALGO")
    ver("sin bloque 3 (A104)", hoja.get((104, 1)), None)
    ver("espesor 0.10: no toca fórmulas", hoja.get((41, 5)), None)

    print("5 baches, espesor 0.08, sin calle:")
    hoja.clear(); ajustes.clear()
    b = L.llamar("exr:llenar", "WS", lista(5), "", 0.08)
    ver("bloques", b, 1)
    ver("calle vacía no se escribe", hoja.get((16, 1)), None)
    ver("volumen E41", hoja.get((41, 5)), "=ROUND(D41*0.0800,2)")
    ver("volumen AC41", hoja.get((41, 29)), "=ROUND(AB41*0.0800,2)")
    ver("texto E37", hoja.get((37, 5)), "Vol Esp 8cm")
    ver("texto W37", hoja.get((37, 23)), "Vol Esp 8cm")
    ver("texto AC40", hoja.get((40, 29)), "Vol Esp 8cm")

    print("Letras de columna:")
    ver("1 -> A", L.llamar("exr:col-letra", 1), "A")
    ver("28 -> AB", L.llamar("exr:col-letra", 28), "AB")

    print("\n%s" % ("TODO BIEN" if not fallos else "%d FALLO(S)" % fallos))
    sys.exit(1 if fallos else 0)


if __name__ == "__main__":
    main()
