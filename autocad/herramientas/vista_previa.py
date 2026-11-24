# -*- coding: utf-8 -*-
"""Genera una imagen aproximada de cómo se verán las fichas MEMO en la cinta."""
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import catalogo as cat  # noqa: E402
import iconos  # noqa: E402

F = iconos._fuente
GRIS, BORDE, TXT = (243, 244, 246, 255), (205, 208, 214, 255), (33, 37, 41, 255)


def ficha(nombre, paneles, ancho_txt=11):
    f_s, f_t, f_p = F(12), F(12), F(12)
    cols = []
    for panel, items in paneles:
        bloques = []
        for it in items:
            if isinstance(it, list):
                w = 26 + max(int(f_s.getlength(cat.COMANDOS[c][0])) for c in it) + 8
                bloques.append(("s", it, w))
            else:
                et = cat.COMANDOS[it][0]
                w = max(58, int(f_t.getlength(et)) + 12)
                bloques.append(("l", it, w))
        ancho = max(sum(b[2] for b in bloques) + 8, int(f_p.getlength(panel)) + 20)
        cols.append((panel, bloques, ancho))
    W = sum(c[2] for c in cols) + 2 * len(cols) + 20
    H = 150
    img = Image.new("RGBA", (W, H + 34), (255, 255, 255, 255))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, W, 30], fill=(230, 232, 236, 255))
    d.rectangle([10, 4, 20 + int(F(14).getlength(nombre)) + 12, 31], fill=GRIS, outline=BORDE)
    d.text((22, 9), nombre, font=F(14), fill=(0, 90, 170, 255))
    x = 10
    y0 = 34
    for panel, bloques, ancho in cols:
        d.rectangle([x, y0, x + ancho, y0 + H - 6], fill=GRIS, outline=BORDE)
        d.rectangle([x, y0 + H - 26, x + ancho, y0 + H - 6], fill=(226, 229, 234, 255))
        tw = f_p.getlength(panel)
        d.text((x + (ancho - tw) / 2, y0 + H - 23), panel, font=f_p, fill=(80, 85, 95, 255))
        bx = x + 4
        for tipo, it, w in bloques:
            if tipo == "l":
                ic = iconos._icono(cat.CATEGORIAS[cat.COMANDOS[it][3]][1], cat.COMANDOS[it][2]).resize((32, 32), Image.LANCZOS)
                img.alpha_composite(ic, (int(bx + (w - 32) / 2), y0 + 10))
                et = cat.COMANDOS[it][0]
                palabras = et.split(" ")
                lineas = [et] if len(palabras) == 1 else [" ".join(palabras[:1]), " ".join(palabras[1:])]
                for k, ln in enumerate(lineas):
                    lw = f_t.getlength(ln)
                    d.text((bx + (w - lw) / 2, y0 + 48 + k * 14), ln, font=f_t, fill=TXT)
            else:
                for k, c in enumerate(it):
                    ic = iconos._icono(cat.CATEGORIAS[cat.COMANDOS[c][3]][1], cat.COMANDOS[c][2]).resize((16, 16), Image.LANCZOS)
                    yy = y0 + 10 + k * 34
                    img.alpha_composite(ic, (bx + 4, yy))
                    d.text((bx + 24, yy + 1), cat.COMANDOS[c][0], font=f_s, fill=TXT)
            bx += w
        x += ancho + 2
    return img


def main(salida):
    imgs = [ficha(t, p) for t, _k, p in cat.FICHAS]
    W = max(i.width for i in imgs)
    H = sum(i.height + 12 for i in imgs)
    hoja = Image.new("RGBA", (W, H), (255, 255, 255, 255))
    y = 0
    for i in imgs:
        hoja.alpha_composite(i, (0, y))
        y += i.height + 12
    hoja.save(salida)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "vista_previa_fichas.png")
