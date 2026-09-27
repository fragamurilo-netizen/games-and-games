#!/usr/bin/env python3
"""Texturas procedurais de cabelo/barba/pele para o rosto 3D (tudo gerado aqui, sem arte de terceiros).

Uso: python3 tools/face3d/build_hair_tex.py [saida]   (numpy + pillow)

  strands_<tipo>.png  atlas 1024x1024 com 8 cartões verticais (128 px cada) de mechas: a raiz fica em
                      cima, as pontas afinam e somem. RGB = brilho do fio (o shader tinge), A = cobertura.
                      Tipos: straight, wavy, curly, coily, locs, braid, fine (sobrancelha/barba).
  fur.png             ruído de fios para as camadas (shells): R = altura do fio (0 = sem fio),
                      G = brilho, B = variação de cor, A = fios crespos (enrolados em tufos).
  pores.png           altura dos poros e microrrelevo da pele (tileável).
"""
import math, os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "../../assets/face3d/tex")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(11)
SS = 3  # supersampling


def strand_card(kind, w, h, seed):
    """Um cartão de mecha: muitos fios finos com cor/grossura variadas, afinando até a ponta."""
    r = np.random.default_rng(seed)
    W, H = w * SS, h * SS
    lum = Image.new("L", (W, H), 0)
    alp = Image.new("L", (W, H), 0)
    dl = ImageDraw.Draw(lum)
    da = ImageDraw.Draw(alp)
    n = {"straight": 170, "wavy": 160, "curly": 150, "coily": 260, "fine": 60, "locs": 5, "braid": 1}[kind]
    if kind in ("locs", "braid"):
        # desenhado direto em numpy: cilindros com sombreamento e fibras torcidas
        yy, xx = np.mgrid[0:H, 0:W].astype(np.float64)
        L = np.zeros((H, W))
        A = np.zeros((H, W))
        t = yy / H
        if kind == "locs":
            for i in range(n):
                x0 = (i + 0.5) / n * W + r.normal(0, W * 0.015)
                rad = W / n * r.uniform(0.36, 0.46)
                ph = r.random() * 6.28
                xc = x0 + np.sin(t * r.uniform(4, 8) + ph) * rad * 0.3
                rr = rad * (1.0 - 0.25 * t ** 2) * (1 + 0.08 * np.sin(t * 40 + ph))
                dsg = (xx - xc) / rr
                inside = np.abs(dsg) < 1
                cyl = np.sqrt(np.clip(1 - dsg ** 2, 0, 1))
                twist = 0.5 + 0.5 * np.sin(yy / (rad * 0.55) + dsg * 2.4 + ph)
                fib = r.random((H, W)) * 0.25
                lm = (0.35 + 0.65 * cyl) * (0.6 + 0.4 * twist) + fib - 0.12
                tip = np.clip((r.uniform(0.9, 1.0) - t) / 0.04, 0, 1)
                a = np.clip((1 - np.abs(dsg)) * 6, 0, 1) * inside * tip
                upd = a > A
                L[upd] = lm[upd]
                A = np.maximum(A, a)
        else:
            seg = H / 13.0
            for side in (0, 1):
                k = np.floor(yy / seg)
                fy = yy / seg - k
                par = (k + side) % 2
                sgn = np.where(par == 0, 1.0, -1.0)
                xc = W / 2 + sgn * (fy - 0.5) * W * 0.36
                rx = W * 0.28
                ry = 0.62
                d = np.hypot((xx - xc) / rx, (fy - 0.5) / ry)
                cyl = np.sqrt(np.clip(1 - d ** 2, 0, 1))
                strands = 0.5 + 0.5 * np.sin((xx - xc) / (W * 0.018) * sgn + fy * 9)
                lm = (0.3 + 0.7 * cyl) * (0.7 + 0.3 * strands)
                a = np.clip((1 - d) * 5, 0, 1)
                upd = a > A
                L[upd] = lm[upd]
                A = np.maximum(A, a)
        l8 = Image.fromarray((np.clip(L, 0, 1) * 235).astype(np.uint8), "L")
        a8 = Image.fromarray((np.clip(A, 0, 1) * 255).astype(np.uint8), "L")
        lum.paste(l8)
        alp.paste(a8)
    else:
        for i in range(n):
            x0 = r.uniform(0.06, 0.94) * W
            length = r.uniform(0.7, 1.0) if kind != "fine" else r.uniform(0.5, 1.0)
            amp = {"straight": 0.004, "wavy": 0.05, "curly": 0.09, "coily": 0.06, "fine": 0.01}[kind] * W * r.uniform(0.6, 1.3)
            freq = {"straight": 1.0, "wavy": 3.0, "curly": 7.0, "coily": 18.0, "fine": 1.5}[kind] * r.uniform(0.8, 1.2)
            ph = r.random() * 6.28
            drift = r.normal(0, 0.03) * W
            wid = r.uniform(0.7, 1.6) * SS * (0.8 if kind == "fine" else 1.0)
            bright = r.uniform(80, 245)
            steps = 90
            prev = None
            for k in range(steps + 1):
                t = k / steps
                if t > length:
                    break
                x = x0 + drift * t + math.sin(t * freq * 6.28 + ph) * amp * (0.3 + t)
                if kind == "coily":
                    x += math.sin(t * freq * 17 + ph) * amp * 0.5
                y = t * H
                if prev is not None:
                    taper = 1.0 - (t / length) ** 3
                    a = int(255 * min(1.0, 0.35 + taper))
                    ww = max(1, int(wid * (0.4 + 0.6 * taper)))
                    da.line([prev, (x, y)], fill=a, width=ww)
                    # brilho ao longo do fio (reflexo de luz em faixas)
                    lb = bright * (0.8 + 0.25 * math.sin(t * 9 + ph))
                    dl.line([prev, (x, y)], fill=int(min(255, lb)), width=ww)
                prev = (x, y)
    lum = lum.resize((w, h), Image.LANCZOS)
    alp = alp.resize((w, h), Image.LANCZOS)
    # pontas somem, raiz um pouco mais escura
    a = np.asarray(alp, dtype=np.float64)
    l = np.asarray(lum, dtype=np.float64)
    yy = np.linspace(0, 1, h)[:, None]
    root_dark = 0.72 + 0.28 * np.clip(yy / 0.25, 0, 1)
    l = l * root_dark
    return l, a


def atlas(kind, seed):
    w, h, n = 128, 1024, 8
    L = np.zeros((h, w * n))
    A = np.zeros((h, w * n))
    for i in range(n):
        l, a = strand_card(kind, w, h, seed * 100 + i)
        L[:, i * w:(i + 1) * w] = l
        A[:, i * w:(i + 1) * w] = a
    rgb = np.repeat(np.clip(L, 0, 255)[..., None], 3, 2)
    img = np.concatenate([rgb, np.clip(A, 0, 255)[..., None]], 2).astype(np.uint8)
    # metade da largura: no tamanho do retrato cada cartão tem poucos pixels
    Image.fromarray(img, "RGBA").resize((w * n // 2, h), Image.LANCZOS).save(f"{OUT}/strands_{kind}.png", optimize=True)
    print("strands", kind)


for i, k in enumerate(("straight", "wavy", "curly", "coily", "locs", "braid", "fine")):
    atlas(k, i + 1)

# --- fur.png: fios para as camadas (tileável) -----------------------------------------------
N = 512
fur = np.zeros((N, N, 4))
# R: cada fio é um pontinho com altura aleatória; G: brilho; B: tom
for layer, (count, rad) in enumerate(((52000, 1.1), (16000, 1.6))):
    xs = rng.random(count) * N
    ys = rng.random(count) * N
    hgt = rng.random(count) ** 0.6
    br = rng.uniform(0.5, 1.0, count)
    tone = rng.random(count)
    for x, y, hh, b, t in zip(xs, ys, hgt, br, tone):
        ix, iy = int(x), int(y)
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                d = math.hypot(dx + ix - x, dy + iy - y)
                if d < rad:
                    px, py = (ix + dx) % N, (iy + dy) % N
                    k = 1.0 - d / rad
                    v = hh * (0.6 + 0.4 * k)
                    if v > fur[py, px, 0]:
                        fur[py, px, 0] = v
                        fur[py, px, 1] = b
                        fur[py, px, 2] = t
# A: tufos crespos (manchas enroladas) — ruído em espiral
yy, xx = np.mgrid[0:N, 0:N] / N
coil = np.zeros((N, N))
for i in range(900):
    cx, cy = rng.random(2)
    rr = rng.uniform(0.006, 0.018)
    dxw = (xx - cx + 0.5) % 1 - 0.5
    dyw = (yy - cy + 0.5) % 1 - 0.5
    d = np.hypot(dxw, dyw)
    ang = np.arctan2(dyw, dxw)
    ring = np.exp(-((d - rr * (0.6 + 0.4 * np.sin(ang * 3 + i))) / (rr * 0.35)) ** 2)
    coil = np.maximum(coil, ring * (d < rr * 1.6) * rng.uniform(0.5, 1.0))
fur[..., 3] = coil
Image.fromarray((np.clip(fur, 0, 1) * 255).astype(np.uint8), "RGBA").save(f"{OUT}/fur.png", optimize=True)
print("fur")

# --- pores.png: poros + microrrelevo (tileável) -------------------------------------------
P = 512
h = np.zeros((P, P))
for scale, amp in ((4, 0.35), (8, 0.25), (16, 0.2), (32, 0.12)):
    g = rng.random((scale, scale))
    up = np.array(Image.fromarray((g * 255).astype(np.uint8)).resize((P, P), Image.BICUBIC), dtype=np.float64) / 255
    h += up * amp
pores = np.zeros((P, P))
px = rng.random(9000) * P
py = rng.random(9000) * P
for x, y in zip(px, py):
    ix, iy = int(x), int(y)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            d = math.hypot(dx + ix - x, dy + iy - y)
            if d < 1.4:
                pores[(iy + dy) % P, (ix + dx) % P] = max(pores[(iy + dy) % P, (ix + dx) % P], 1 - d / 1.4)
hh = np.clip(h / h.max() * 0.7 - pores * 0.5 + 0.3, 0, 1)
Image.fromarray((hh * 255).astype(np.uint8), "L").save(f"{OUT}/pores.png", optimize=True)
print("pores ok")
