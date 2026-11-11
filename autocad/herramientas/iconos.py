# -*- coding: utf-8 -*-
"""
Dibuja los iconos del MEMO SISTEMA (PNG 16x16 y 32x32 con transparencia).

Cada icono = mosaico redondeado con el color de la categoría + un glifo blanco
que representa la acción (tabla, cota, hatch, exportar, curvas, etc.).
Se dibuja a 256 px y se reduce con antialiasing para que se vea nítido.
"""
import math
import os

from PIL import Image, ImageDraw, ImageFont

G = 256          # lienzo de trabajo
B = (255, 255, 255, 255)

_FUENTES = [
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    "C:/Windows/Fonts/arialbd.ttf",
    "/Library/Fonts/Arial Bold.ttf",
]


def _fuente(tam):
    for f in _FUENTES:
        if os.path.exists(f):
            return ImageFont.truetype(f, tam)
    return ImageFont.load_default()


def _hex(c):
    c = c.lstrip("#")
    return tuple(int(c[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def _texto(d, s, tam, y=None):
    f = _fuente(tam)
    x0, y0, x1, y1 = d.textbbox((0, 0), s, font=f)
    w, h = x1 - x0, y1 - y0
    yy = (G - h) / 2 - y0 if y is None else y
    d.text(((G - w) / 2 - x0, yy), s, font=f, fill=B)


W = 18  # grosor de línea base


def g_tabla(d):
    x0, y0, x1, y1 = 52, 64, 204, 192
    d.rectangle([x0, y0, x1, y1], outline=B, width=W)
    d.rectangle([x0, y0, x1, y0 + 34], fill=B)
    for y in (122, 158):
        d.line([x0, y, x1, y], fill=B, width=W - 6)
    d.line([104, y0, 104, y1], fill=B, width=W - 6)


def g_rect(d):
    d.rectangle([56, 70, 200, 170], outline=B, width=W)
    d.line([56, 200, 200, 200], fill=B, width=10)
    for x in (56, 200):
        d.line([x, 186, x, 214], fill=B, width=10)


def g_cota(d):
    d.line([40, 150, 216, 150], fill=B, width=12)
    for x in (40, 216):
        d.line([x, 110, x, 190], fill=B, width=12)
    d.polygon([(40, 150), (78, 132), (78, 168)], fill=B)
    d.polygon([(216, 150), (178, 132), (178, 168)], fill=B)
    _texto(d, "2.50", 62, y=52)


def g_renum(d):
    _texto(d, "1 2", 120)


def _flecha(d, x0, y0, x1, y1, w=W):
    d.line([x0, y0, x1, y1], fill=B, width=w)
    ang = math.atan2(y1 - y0, x1 - x0)
    L = 52
    for s in (-1, 1):
        a = ang + math.pi + s * 0.6
        d.line([x1, y1, x1 + L * math.cos(a), y1 + L * math.sin(a)], fill=B, width=w)


def g_export(d):
    d.rectangle([44, 92, 150, 204], outline=B, width=W)
    _flecha(d, 108, 148, 214, 52)


def g_import(d):
    d.rectangle([106, 92, 212, 204], outline=B, width=W)
    _flecha(d, 40, 52, 150, 150)


def g_hatch(d):
    x0, y0, x1, y1 = 52, 52, 204, 204
    d.rectangle([x0, y0, x1, y1], outline=B, width=W)
    for k in range(-2, 4):
        off = k * 44
        d.line([x0 + off, y1, x0 + off + (y1 - y0), y0], fill=B, width=9)
    # recortar sobrante: repintar fuera del cuadro lo hace el llamador (máscara)


def g_borrar(d):
    d.line([66, 66, 190, 190], fill=B, width=W + 8)
    d.line([190, 66, 66, 190], fill=B, width=W + 8)


def g_limpiar(d):
    for y in (70, 112, 154):
        d.line([48, y, 150, y], fill=B, width=12)
    d.line([132, 200, 214, 118], fill=B, width=W + 6)
    d.polygon([(118, 214), (100, 196), (150, 146), (168, 164)], fill=B)


def g_engrane(d):
    cx, cy = 128, 128
    pts = []
    n = 8
    for i in range(n * 2):
        a = i * math.pi / n
        r = 92 if i % 2 == 0 else 70
        for da in (-0.17, 0.17):
            pts.append((cx + r * math.cos(a + da), cy + r * math.sin(a + da)))
    d.polygon(pts, fill=B)
    d.ellipse([cx - 32, cy - 32, cx + 32, cy + 32], fill=(0, 0, 0, 0))


def g_lista(d):
    for y in (72, 128, 184):
        d.ellipse([46, y - 12, 70, y + 12], fill=B)
        d.line([92, y, 210, y], fill=B, width=14)


def g_info(d):
    _texto(d, "i", 170)


def g_ayuda(d):
    _texto(d, "?", 170)


def g_elev(d):
    d.polygon([(72, 92), (184, 92), (128, 172)], outline=B, width=W)
    d.line([40, 196, 216, 196], fill=B, width=W)
    _texto(d, "Z", 60, y=30)


def g_area(d):
    d.polygon([(44, 196), (84, 64), (200, 92), (212, 196)], fill=(255, 255, 255, 110), outline=B, width=W)
    _texto(d, "m²", 70)


def g_prefijo(d):
    _texto(d, "A=", 118)


def g_imagen(d):
    d.rectangle([40, 56, 216, 200], outline=B, width=W)
    d.polygon([(56, 186), (112, 112), (150, 160), (172, 134), (202, 186)], fill=B)
    d.ellipse([160, 76, 192, 108], fill=B)


def g_copiar(d):
    d.rectangle([44, 44, 152, 152], outline=B, width=W)
    d.rectangle([104, 104, 212, 212], fill=B)


def g_suma(d):
    _texto(d, "Σ", 170)


def g_texto(d):
    _texto(d, "T", 180)


def g_alinear(d):
    d.line([50, 40, 50, 216], fill=B, width=12)
    for y, x1 in ((76, 206), (128, 160), (180, 190)):
        d.line([70, y, x1, y], fill=B, width=24)


def g_rotar(d):
    d.arc([48, 48, 208, 208], start=200, end=500, fill=B, width=W)
    a = math.radians(140)
    x, y = 128 + 80 * math.cos(a), 128 + 80 * math.sin(a)
    d.polygon([(x - 34, y - 6), (x + 26, y - 20), (x + 2, y + 40)], fill=B)


def g_mayus(d):
    _texto(d, "Aa", 130)


def g_pendiente(d):
    d.polygon([(40, 196), (216, 196), (216, 84)], outline=B, width=W)
    _texto(d, "%", 72, y=118)


def g_coord(d):
    _texto(d, "XY", 120)


def g_fusion(d):
    d.rectangle([40, 70, 116, 146], outline=B, width=14)
    d.rectangle([140, 70, 216, 146], outline=B, width=14)
    d.rectangle([80, 170, 176, 220], fill=B)
    d.line([78, 150, 112, 170], fill=B, width=12)
    d.line([178, 150, 144, 170], fill=B, width=12)


def g_separa(d):
    d.rectangle([80, 36, 176, 96], fill=B)
    d.rectangle([40, 140, 116, 216], outline=B, width=14)
    d.rectangle([140, 140, 216, 216], outline=B, width=14)
    d.line([112, 100, 78, 136], fill=B, width=12)
    d.line([144, 100, 178, 136], fill=B, width=12)


def g_vista(d):
    for (x, y, sx, sy) in ((44, 60, 1, 1), (212, 60, -1, 1), (44, 196, 1, -1), (212, 196, -1, -1)):
        d.line([x, y, x + sx * 50, y], fill=B, width=W)
        d.line([x, y, x, y + sy * 46], fill=B, width=W)
    d.ellipse([92, 96, 164, 160], outline=B, width=W)
    d.ellipse([116, 116, 140, 140], fill=B)


def g_layout(d):
    d.polygon([(64, 36), (156, 36), (196, 76), (196, 220), (64, 220)], outline=B, width=W)
    d.line([156, 36, 156, 76, 196, 76], fill=B, width=12)
    d.rectangle([90, 110, 170, 190], outline=B, width=10)


def g_capas(d):
    for k, y in enumerate((150, 118, 86)):
        pts = [(128, y - 44), (216, y), (128, y + 44), (40, y)]
        if k == 2:
            d.polygon(pts, fill=B)
        else:
            d.polygon(pts, outline=B, width=12)


def g_poli(d):
    pts = [(44, 190), (100, 92), (156, 160), (212, 60)]
    d.line(pts, fill=B, width=14, joint="curve")
    for x, y in pts:
        d.ellipse([x - 20, y - 20, x + 20, y + 20], fill=B)


def g_puntos(d):
    for i in range(3):
        for j in range(3):
            x, y = 64 + i * 64, 64 + j * 64
            d.ellipse([x - 18, y - 18, x + 18, y + 18], fill=B)


def g_color(d):
    cols = [(231, 76, 60, 255), (241, 196, 15, 255), (46, 204, 113, 255), (52, 152, 219, 255)]
    for k, c in enumerate(cols):
        x = 46 + k * 44
        d.rounded_rectangle([x, 60, x + 34, 196], radius=10, fill=c, outline=B, width=6)


def g_curvas(d):
    for k, r in enumerate((96, 68, 40)):
        d.ellipse([128 - r - 14, 128 - r * 0.75, 128 + r + 14, 128 + r * 0.75], outline=B, width=12)


def g_agua(d):
    for y in (92, 140, 188):
        pts = [(40 + t, y + 16 * math.sin(t / 22.0)) for t in range(0, 177, 4)]
        d.line(pts, fill=B, width=14)
    d.polygon([(128, 24), (110, 60), (146, 60)], fill=B)


def g_perfil(d):
    d.line([40, 120, 216, 120], fill=B, width=8)
    pts = [(40, 92), (80, 104), (110, 170), (146, 186), (176, 140), (216, 96)]
    d.line(pts, fill=B, width=16, joint="curve")
    d.line([40, 210, 216, 210], fill=B, width=8)
    for x in (40, 128, 216):
        d.line([x, 200, x, 220], fill=B, width=8)


def g_clip(d):
    d.ellipse([44, 148, 104, 208], outline=B, width=14)
    d.ellipse([152, 148, 212, 208], outline=B, width=14)
    d.line([94, 156, 186, 44], fill=B, width=16)
    d.line([162, 156, 70, 44], fill=B, width=16)


def g_bloque(d):
    t = [(128, 40), (210, 84), (128, 128), (46, 84)]
    d.polygon(t, fill=B)
    d.polygon([(46, 84), (128, 128), (128, 220), (46, 176)], outline=B, width=12)
    d.polygon([(210, 84), (128, 128), (128, 220), (210, 176)], outline=B, width=12)


GLIFOS = {k[2:]: v for k, v in globals().items() if k.startswith("g_")}


def _icono(color, glifo):
    img = Image.new("RGBA", (G, G), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([4, 4, G - 5, G - 5], radius=48, fill=_hex(color))
    capa = Image.new("RGBA", (G, G), (0, 0, 0, 0))
    dc = ImageDraw.Draw(capa)
    GLIFOS[glifo](dc)
    if glifo == "hatch":       # recortar las diagonales al cuadro
        m = Image.new("L", (G, G), 0)
        ImageDraw.Draw(m).rectangle([52, 52, 204, 204], fill=255)
        capa.putalpha(Image.composite(capa.getchannel("A"), Image.new("L", (G, G), 0), m))
    if glifo == "engrane":     # perforar el centro
        hueco = Image.new("L", (G, G), 255)
        ImageDraw.Draw(hueco).ellipse([96, 96, 160, 160], fill=0)
        a = capa.getchannel("A")
        capa.putalpha(Image.composite(a, Image.new("L", (G, G), 0), hueco))
    img.alpha_composite(capa)
    return img


def generar(comandos, cat, carpeta, nombre_icono):
    os.makedirs(carpeta, exist_ok=True)
    for c in comandos:
        _et, _desc, glifo, categoria = cat.COMANDOS[c]
        color = cat.CATEGORIAS[categoria][1]
        if glifo not in GLIFOS:
            raise SystemExit("Glifo desconocido %s (%s)" % (glifo, c))
        img = _icono(color, glifo)
        for t in (32, 16):
            img.resize((t, t), Image.LANCZOS).save(os.path.join(carpeta, nombre_icono(c, t)), optimize=True)


def hoja_muestra(cat, ruta):
    """Imagen con todos los glifos por categoría (para revisar el diseño)."""
    glifos = sorted({(v[2], v[3]) for v in cat.COMANDOS.values()}, key=lambda x: (x[1], x[0]))
    cols = 10
    filas = (len(glifos) + cols - 1) // cols
    hoja = Image.new("RGBA", (cols * 90 + 20, filas * 90 + 20), (245, 245, 245, 255))
    for i, (g, c) in enumerate(glifos):
        ic = _icono(cat.CATEGORIAS[c][1], g)
        x, y = 20 + (i % cols) * 90, 20 + (i // cols) * 90
        hoja.alpha_composite(ic.resize((32, 32), Image.LANCZOS), (x, y))
        hoja.alpha_composite(ic.resize((16, 16), Image.LANCZOS), (x + 40, y + 8))
        ImageDraw.Draw(hoja).text((x, y + 40), g, fill=(40, 40, 40, 255))
    hoja.save(ruta)
