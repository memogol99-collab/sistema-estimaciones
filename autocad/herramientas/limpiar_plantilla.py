#!/usr/bin/env python3
"""Genera la plantilla LIMPIA del generador de bacheo a partir de un
generador ya llenado (Formato_Generador_Bacheo.xlsx).

Se edita el XML de la hoja directamente (no con openpyxl) para conservar
TODO el formato: logo del encabezado, validaciones, configuración de
impresión, celdas combinadas, etc.

Qué se limpia (en los 6 bloques de la hoja "Generadores"):
  * LARGO y ANCHO de todos los baches.
  * No.: se reemplaza por fórmulas consecutivas que sólo muestran número
    si el renglón tiene LARGO (EXR de todos modos escribe el número real).
  * Nombre de la calle de cada bloque.
  * Datos de la estimación: No. de estimación, periodo (Del / Al) y el
    volumen acumulado de la estimación anterior.
Se conservan: datos del contrato, concepto, P.U., fórmulas y firmas.

Uso:  python3 -I limpiar_plantilla.py <generador_lleno.xlsx> <salida.xlsx>
"""
import re
import sys
import zipfile

BLOQUES = 6
PASO = 44                  # renglones entre bloques
ENC = 17                   # renglón de encabezados No./LARGO/ANCHO/AREA (bloque 0)
FILAS = 22                 # baches por grupo
GRUPOS = 5                 # grupos por bloque


def col(n):
    s = ""
    while n:
        n, r = divmod(n - 1, 26)
        s = chr(65 + r) + s
    return s


def celdas_a_limpiar():
    vaciar, formulas = set(), {}
    for k in range(BLOQUES):
        enc = ENC + PASO * k
        vaciar.add("A%d" % (enc - 1))                    # calle
        vaciar.add("E%d" % (enc + 27))                   # vol. acumulado estimación anterior
        for g in range(GRUPOS):
            cn = 1 + 6 * g                               # columna No.
            for i in range(FILAS):
                f = enc + 2 + i
                vaciar.add("%s%d" % (col(cn + 1), f))     # LARGO
                vaciar.add("%s%d" % (col(cn + 2), f))     # ANCHO
                largo = "%s%d" % (col(cn + 1), f)
                if i > 0:
                    ant = "%s%d" % (col(cn), f - 1)
                elif g > 0:
                    ant = "%s%d" % (col(cn - 6), f + FILAS - 1)
                elif k > 0:
                    ant = "Y%d" % (f - PASO + FILAS - 1)
                else:
                    ant = None
                formulas["%s%d" % (col(cn), f)] = (
                    'IF(%s="","",%s)' % (largo, "1" if ant is None else "N(%s)+1" % ant))
    vaciar |= {"E11", "M11", "M12"}
    return vaciar, formulas


def esc(s):
    return s.replace("&", "&amp;").replace('"', "&quot;").replace("<", "&lt;").replace(">", "&gt;")


def limpiar_hoja(xml):
    vaciar, formulas = celdas_a_limpiar()
    hechos = set()

    def rep(m):
        ref, attrs = m.group(1), m.group(2)
        if ref not in vaciar and ref not in formulas:
            return m.group(0)
        hechos.add(ref)
        attrs = re.sub(r'\s+t="[^"]*"', "", attrs)
        if ref in formulas:
            return '<c r="%s"%s><f>%s</f></c>' % (ref, attrs, esc(formulas[ref]))
        return '<c r="%s"%s/>' % (ref, attrs)

    xml = re.sub(r'<c r="([A-Z]+\d+)"([^>]*?)(?:/>|>.*?</c>)', rep, xml, flags=re.S)
    faltan = sorted(set(formulas) - hechos)
    if faltan:
        raise SystemExit("No se encontraron las celdas No.: %s ..." % faltan[:5])
    return xml


def main(entrada, salida):
    zin = zipfile.ZipFile(entrada)
    zout = zipfile.ZipFile(salida, "w", zipfile.ZIP_DEFLATED)
    for it in zin.infolist():
        datos = zin.read(it.filename)
        if it.filename == "xl/calcChain.xml":
            continue                                  # Excel lo reconstruye
        if it.filename == "[Content_Types].xml":
            datos = re.sub(rb'<Override[^>]*calcChain[^>]*/>', b"", datos)
        elif it.filename == "xl/_rels/workbook.xml.rels":
            datos = re.sub(rb'<Relationship[^>]*calcChain[^>]*/>', b"", datos)
        elif it.filename == "xl/workbook.xml":
            # recalcular todo al abrir
            datos = re.sub(rb'<calcPr([^>]*?)/>', lambda m: b'<calcPr' + re.sub(rb'\s*fullCalcOnLoad="[^"]*"', b"", m.group(1)) + b' fullCalcOnLoad="1"/>', datos)
        elif it.filename == "xl/worksheets/sheet1.xml":
            datos = limpiar_hoja(datos.decode("utf-8")).encode("utf-8")
        zout.writestr(it, datos)
    zout.close()


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    main(sys.argv[1], sys.argv[2])
