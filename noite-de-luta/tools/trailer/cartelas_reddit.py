# Legendas (PNG transparente 1080x1350, 4:5 do Reddit) e cartela final, no visual de cartaz da 1.3.0.
import os, sys
from PIL import Image, ImageDraw, ImageFont
D = os.path.dirname(os.path.abspath(__file__))
FONT = D + "/../../assets/fonts/Saira-Variable.ttf"
EMB = D + "/../../assets/brand/emblema.png"
OUT = sys.argv[1]
W, H = 1080, 1350
YEL = (255, 207, 13, 255); TXT = (243, 238, 228, 255); MUT = (185, 178, 166, 255); BLK = (10, 10, 10, 255)


def font(sz, wght=800, wdth=80):
    f = ImageFont.truetype(FONT, sz)
    try:
        f.set_variation_by_axes([wght, wdth])
    except Exception:
        pass
    return f


def caption(name, kicker, title, top=False):
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    lines = title.upper().split("\n")
    bh = 300 if top else 520
    band = Image.new("RGBA", (W, bh))
    px = band.load()
    for y in range(bh):
        k = (bh - 1 - y) if top else y
        a = int(250 * min(1.0, k / (bh * 0.44)) ** 1.3)
        for x in range(W):
            px[x, y] = (10, 10, 10, a)
    img.alpha_composite(band, (0, 0 if top else H - bh))
    d = ImageDraw.Draw(img)
    ft = font(118, 800, 80)
    fk = font(40, 800, 87.5)
    y = 30 if top else H - 70 - len(lines) * 112
    if kicker:
        d.text((56, y - 54), kicker.upper(), font=fk, fill=YEL)
    for ln in lines:
        d.text((56, y), ln, font=ft, fill=TXT, stroke_width=3, stroke_fill=BLK)
        y += 112
    img.save(f"{OUT}/cap_{name}.png")


CAPS = {
    "gancho": ("Noite de Luta", "Você é\no técnico"),
    "inicio": ("", "Monte sua\nacademia"),
    "ficha": ("", "Cada lutador\ntem história"),
    "plano": ("", "Chegou a\nnoite de luta"),
    "luta": ("", "Grite do corner"),
    "card": ("Modo presidente", "Ou comande\na liga"),
    "sede": ("", "Encha\na arena"),
    "principal": ("", "A luta principal\né sua"),
    "visual": ("", "Mude o visual\nde cada um"),
}
for k, (a, b) in CAPS.items():
    caption(k, a, b, k == "luta")

# Cartela final.
img = Image.new("RGBA", (W, H), BLK)
emb = Image.open(EMB).convert("RGBA")
s = 430 / max(emb.size)
emb = emb.resize((int(emb.width * s), int(emb.height * s)), Image.LANCZOS)
img.alpha_composite(emb, ((W - emb.width) // 2, 250))
d = ImageDraw.Draw(img)


def center(text, y, f, fill):
    w = d.textlength(text, font=f)
    d.text(((W - w) / 2, y), text, font=f, fill=fill)


center("NOITE DE", 720, font(96, 800, 87.5), TXT)
center("LUTA", 800, font(220, 800, 87.5), TXT)
d.rectangle([W // 2 - 90, 1062, W // 2 + 90, 1072], fill=YEL)
center("JOGO DE GESTÃO DE MMA", 1110, font(50, 800, 80), YEL)
center("Android · em português", 1180, font(40, 500, 100), MUT)
img.save(f"{OUT}/final.png")
print("ok")
