# Legendas (PNG transparente 1080x1920) e cartela final do trailer.
import sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter
FONT = "/home/user/games-and-games/noite-de-luta/assets/fonts/Saira-Variable.ttf"
EMB = "/home/user/games-and-games/noite-de-luta/assets/brand/emblema.png"
OUT = sys.argv[1]
W, H = 1080, 1920
GOLD = (242, 193, 78, 255); TXT = (244, 243, 239, 255); MUT = (190, 196, 206, 255)


def font(sz, wght=800, wdth=100):
    f = ImageFont.truetype(FONT, sz)
    try:
        f.set_variation_by_axes([wght, wdth])
    except Exception:
        pass
    return f


def gradient_band(img, y0, y1, alpha=235):
    band = Image.new("RGBA", (W, y1 - y0))
    px = band.load()
    for y in range(y1 - y0):
        a = int(alpha * min(1.0, (y / ((y1 - y0) * 0.38))) ** 1.2)
        for x in range(W):
            px[x, y] = (8, 10, 15, a)
    img.alpha_composite(band, (0, y0))


def caption(name, kicker, title):
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gradient_band(img, 1220, H, 248)
    d = ImageDraw.Draw(img)
    fk = font(40, 700, 110)
    ft = font(92, 850, 100)
    lines = title.split("\n")
    y = H - 150 - len(lines) * 100
    d.rectangle([64, y - 58, 64 + 10, y - 16], fill=GOLD)
    d.text((90, y - 66), kicker.upper(), font=fk, fill=GOLD)
    for ln in lines:
        # contorno leve para ler sobre qualquer fundo
        d.text((64, y), ln.upper(), font=ft, fill=TXT, stroke_width=2, stroke_fill=(8, 10, 15, 200))
        y += 100
    img.save(f"{OUT}/cap_{name}.png")


CAPS = {
    "inicio": ("Noite de Luta", "Monte sua\nacademia"),
    "ficha": ("Contrate e treine", "Cada atleta\nevolui"),
    "plano": ("Semana de luta", "Você faz\no plano"),
    "luta": ("Ao vivo", "Cada round\nconta"),
    "resultado": ("Resultado", "Vitória ou\nrevanche"),
    "card": ("Modo presidente", "Ou comande\nsua liga"),
    "sede": ("Cidade, arena, ingresso", "Encha a\narena"),
    "principal": ("Luta principal", "A noite\né sua"),
    "visual": ("Editor de visual", "Do seu\njeito"),
    "gala": ("Fim de temporada", "Noite de\ngala"),
}
for k, (a, b) in CAPS.items():
    caption(k, a, b)

# Cartela final.
img = Image.new("RGBA", (W, H), (9, 11, 17, 255))
glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
gd = ImageDraw.Draw(glow)
gd.ellipse([140, 420, 940, 1220], fill=(179, 38, 46, 120))
glow = glow.filter(ImageFilter.GaussianBlur(140))
img.alpha_composite(glow)
emb = Image.open(EMB).convert("RGBA")
s = 520 / max(emb.size)
emb = emb.resize((int(emb.width * s), int(emb.height * s)), Image.LANCZOS)
img.alpha_composite(emb, ((W - emb.width) // 2, 560))
d = ImageDraw.Draw(img)
def center(text, y, f, fill):
    w = d.textlength(text, font=f)
    d.text(((W - w) / 2, y), text, font=f, fill=fill)
center("NOITE DE LUTA", 1150, font(118, 850, 100), TXT)
center("GERENCIAMENTO DE MMA", 1312, font(44, 700, 115), GOLD)
center("Android · em português", 1386, font(42, 500), MUT)
img.save(f"{OUT}/final.png")
print("ok")
