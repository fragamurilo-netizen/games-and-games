"""Marca do jogo, desenhada por código: o emblema (octógono com o canto vermelho e o azul e a
lua da "noite"), o ícone do app (antigo, adaptável e de uma cor só), a imagem de abertura e as
peças da loja. Precisa de Pillow e numpy.
Uso: python3 tools/gera_marca.py assets/brand [PASTA_DA_LOJA]
As peças da loja (ícone de 512 sem cantos e a faixa de destaque de 1024×500) não entram no
jogo: só saem se a segunda pasta for dada."""
import math
import sys

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

RED = (0xB3, 0x26, 0x2E)
BLUE = (0x2E, 0x5C, 0x9E)
INK = (0xF1, 0xF0, 0xEC)
GOLD = (0xD3, 0xA9, 0x4A)
GOLD_HI = (0xF0, 0xCE, 0x73)
GOLD_LO = (0xB8, 0x8A, 0x2E)
BG = (0x0E, 0x0E, 0x10)  # a cor do fundo da abertura (boot_splash/bg_color)
SS = 4  # desenha quatro vezes maior e reduz (bordas lisas)
FONT = "assets/fonts/Saira-Variable.ttf"

# Proporções do emblema, em frações do raio de fora. As mesmas valem para a versão de uma cor.
RING = 0.80  # onde o anel acaba e a lona começa
MOON_R = 0.50
MOON_DX = 0.05
MOON_CUT = 0.86
MOON_CUT_DX = 0.42
MOON_CUT_DY = -0.28


def octo(cx, cy, r, rot=22.5):
    return [(cx + r * math.cos(math.radians(rot + 45 * k)), cy + r * math.sin(math.radians(rot + 45 * k))) for k in range(8)]


def radial(size, inner, outer, cx=0.5, cy=0.5, rad=0.75):
    w, h = size if isinstance(size, tuple) else (size, size)
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    d = np.clip(np.hypot(x / w - cx, (y / h - cy) * h / w) / rad, 0, 1)[..., None]
    a = np.array(inner, np.float32)
    b = np.array(outer, np.float32)
    return Image.fromarray((a + (b - a) * d).astype(np.uint8), "RGB")


def moon_mask(s, c, r):
    m = Image.new("L", (s, s), 0)
    md = ImageDraw.Draw(m)
    mr = r * MOON_R
    mx = c + r * MOON_DX
    my = c
    md.ellipse([mx - mr, my - mr, mx + mr, my + mr], fill=255)
    cr = mr * MOON_CUT
    ox = mx + mr * MOON_CUT_DX
    oy = my + mr * MOON_CUT_DY
    md.ellipse([ox - cr, oy - cr, ox + cr, oy + cr], fill=0)
    return m, my - mr, mr


def emblem(size, radius, mono=False):
    """O emblema em RGBA num quadro size×size, com raio de fora `radius` (em pixels)."""
    s = size * SS
    c = s / 2
    r = radius * SS
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    moon, moon_top, mr = moon_mask(s, c, r)
    if mono:
        d.polygon(octo(c, c, r), fill=(255, 255, 255, 255))
        d.polygon(octo(c, c, r * RING), fill=(0, 0, 0, 0))
        img.paste((255, 255, 255, 255), mask=moon)
        return img.resize((size, size), Image.LANCZOS)
    # O anel: metade vermelha, metade azul, com a luz vindo de cima.
    ring = Image.new("L", (s, s), 0)
    rd = ImageDraw.Draw(ring)
    rd.polygon(octo(c, c, r), fill=255)
    rd.polygon(octo(c, c, r * RING), fill=0)
    x = np.arange(s, dtype=np.float32)[None, :].repeat(s, 0)
    y = np.arange(s, dtype=np.float32)[:, None].repeat(s, 1)
    t = np.clip((x - (c - r * 0.02)) / (r * 0.04), 0, 1)[..., None]
    col = np.array(RED, np.float32) * (1 - t) + np.array(BLUE, np.float32) * t
    shade = (1.18 - 0.36 * np.clip((y - (c - r)) / (2 * r), 0, 1))[..., None]
    img.paste(Image.fromarray(np.clip(col * shade, 0, 255).astype(np.uint8), "RGB"), mask=ring)
    # A lona: escura, com a luz do centro.
    core = Image.new("L", (s, s), 0)
    ImageDraw.Draw(core).polygon(octo(c, c, r * RING), fill=255)
    img.paste(radial(s, (0x2A, 0x30, 0x3C), (0x10, 0x12, 0x17), 0.5, 0.5, radius / size * 0.95), mask=core)
    # O filete claro da grade e a emenda dos dois cantos, em cima e embaixo.
    d = ImageDraw.Draw(img)
    inner = octo(c, c, r * RING)
    d.line(inner + [inner[0]], fill=INK + (255,), width=max(2, int(r * 0.028)), joint="curve")
    bw = r * 0.035
    d.rectangle([c - bw, c - r * 0.925, c + bw, c - r * 0.74], fill=INK + (255,))
    d.rectangle([c - bw, c + r * 0.74, c + bw, c + r * 0.925], fill=INK + (255,))
    # A lua, dourada, com um brilho que não sai da lona.
    tt = np.clip((y - moon_top) / (2 * mr), 0, 1)[..., None]
    gold = (np.array(GOLD_HI, np.float32) * (1 - tt) + np.array(GOLD_LO, np.float32) * tt).astype(np.uint8)
    glow = moon.filter(ImageFilter.GaussianBlur(r * 0.10)).point(lambda v: int(v * 0.35))
    halo = Image.new("RGBA", (s, s), GOLD + (0,))
    halo.putalpha(ImageChops.multiply(glow, core))
    img = Image.alpha_composite(img, halo)
    img.paste(Image.fromarray(gold, "RGB"), mask=moon)
    return img.resize((size, size), Image.LANCZOS)


def backdrop(size):
    return radial(size, (0x23, 0x27, 0x30), (0x0B, 0x0C, 0x0F), 0.5, 0.42, 0.78)


def with_shadow(base, e, size):
    alpha = e.getchannel("A").filter(ImageFilter.GaussianBlur(size * 0.03)).point(lambda v: int(v * 0.6))
    sh = Image.new("RGBA", e.size, (0, 0, 0, 0))
    sh.putalpha(alpha)
    sh = ImageChops.offset(sh, 0, int(size * 0.02))
    return Image.alpha_composite(Image.alpha_composite(base, sh), e)


def legacy_icon(size, rounded=True):
    s = size * SS
    out = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    mask = Image.new("L", (s, s), 255 if not rounded else 0)
    if rounded:
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, s - 1, s - 1], radius=int(s * 0.22), fill=255)
    out.paste(backdrop(s), mask=mask)
    out = out.resize((size, size), Image.LANCZOS)
    return with_shadow(out, emblem(size, size * 0.385), size)


def wordmark(text, px, weight=800, width=87.5, fill=INK, tracking=0.0):
    f = ImageFont.truetype(FONT, px)
    f.set_variation_by_axes([weight, width])
    if tracking <= 0.0:
        box = f.getbbox(text)
        img = Image.new("RGBA", (box[2] - box[0] + 8, box[3] - box[1] + 8), (0, 0, 0, 0))
        ImageDraw.Draw(img).text((4 - box[0], 4 - box[1]), text, font=f, fill=fill + (255,))
        return img
    widths = [f.getlength(ch) + tracking * px for ch in text]
    asc, desc = f.getmetrics()
    img = Image.new("RGBA", (int(sum(widths)) + 8, asc + desc + 8), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    x = 4.0
    for ch, w in zip(text, widths):
        d.text((x, 4), ch, font=f, fill=fill + (255,))
        x += w
    return img.crop(img.getbbox())


def feature_graphic():
    """Faixa de destaque da loja: 1024×500, emblema à esquerda, nome e chamada à direita."""
    w, h = 1024, 500
    img = radial((w, h), (0x26, 0x2B, 0x35), (0x0B, 0x0C, 0x0F), 0.27, 0.5, 0.62).convert("RGBA")
    # Dois fachos de luz, um de cada canto.
    beams = Image.new("RGBA", (w * 2, h * 2), (0, 0, 0, 0))
    bd = ImageDraw.Draw(beams)
    bd.polygon([(0, 0), (160, 0), (760, h * 2), (340, h * 2)], fill=RED + (46,))
    bd.polygon([(w * 2, 0), (w * 2 - 160, 0), (w * 2 - 1500, h * 2), (w * 2 - 1080, h * 2)], fill=BLUE + (54,))
    beams = beams.filter(ImageFilter.GaussianBlur(26)).resize((w, h), Image.LANCZOS)
    img = Image.alpha_composite(img, beams)
    e = emblem(400, 176)
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    layer.paste(e, (78, 50), e)
    img = with_shadow(img, layer, 400)
    a = wordmark("NOITE DE", 76, 800, 87.5, INK, 0.05)
    b = wordmark("LUTA", 190, 900, 87.5, INK, 0.02)
    c = wordmark("Sua equipe. Sua liga. Sua noite.", 34, 500, 100.0, (0xC9, 0xCD, 0xD2))
    x = 520
    img.paste(a, (x, 112), a)
    img.paste(b, (x - 6, 112 + a.height + 22), b)
    bar_y = 112 + a.height + 22 + b.height + 26
    ImageDraw.Draw(img).rectangle([x, bar_y, x + 96, bar_y + 6], fill=GOLD + (255,))
    img.paste(c, (x, bar_y + 26), c)
    return img.convert("RGB")


def beam(w=192, h=768):
    """Facho de luz branco (o jogo dá a cor): estreito e forte em cima, largo e fraco embaixo."""
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    v = y / (h - 1)
    half = (0.10 + 0.40 * v) * w
    across = np.clip(1.0 - np.abs(x - (w - 1) / 2) / half, 0, 1) ** 1.6
    along = (1.0 - v) ** 1.35 * np.clip(v / 0.04, 0, 1)
    a = (across * along * 255).astype(np.uint8)
    img = Image.new("RGBA", (w, h), (255, 255, 255, 0))
    img.putalpha(Image.fromarray(a, "L"))
    return img


def main(out, store=""):
    emblem(768, 768 * 0.47).save(out + "/emblema.png")
    beam().save(out + "/facho.png")
    legacy_icon(512).save(out + "/icone.png")
    legacy_icon(192).save(out + "/icone_192.png")
    # Ícone adaptável do Android: 432 px, e só o miolo de 264 px aparece com certeza.
    emblem(432, 432 * 0.275).save(out + "/icone_frente_432.png")
    backdrop(432).convert("RGBA").save(out + "/icone_fundo_432.png")
    emblem(432, 432 * 0.275, mono=True).save(out + "/icone_mono_432.png")
    # Abertura: a engine encaixa o quadrado na tela, e o emblema ocupa 40% do lado menor
    # (o mesmo tamanho com que a abertura do jogo começa).
    emblem(1024, 1024 * 0.20).save(out + "/abertura.png")
    if store:
        legacy_icon(512, rounded=False).convert("RGB").save(store + "/icone_loja_512.png")
        feature_graphic().save(store + "/destaque_1024x500.png")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else "")
