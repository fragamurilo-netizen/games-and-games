#!/usr/bin/env python3
"""Gera as texturas de detalhe dos retratos 2D (cabelo, barba, pele, íris).

Tudo procedural e determinístico (sementes fixas): rode de novo e sai igual.
    python3 tools/portrait_textures/gen.py [nome ...]
Saída: assets/portrait/*.png em cinza + alfa (tom no cinza, cobertura no alfa).

O tom de cada textura é normalizado para média 0,5: o PortraitView tinge a textura com o dobro
da cor já iluminada da peça, então na média a peça fica com a cor de antes e os fios clareiam e
escurecem em volta dela. Todas (menos a íris) emendam sem costura nas bordas, para repetir pela
cabeça e pelo rosto. Escala: 256 texels por meia largura de rosto (barba 320, pele 256).
Precisa de numpy, scipy, pillow e pycairo.
"""
import math
import os
import sys

import cairo
import numpy as np
from PIL import Image
from scipy import ndimage

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "portrait")
TAU = math.tau


# ---------------------------------------------------------------------------
# Utilidades
# ---------------------------------------------------------------------------

def surface(w, h):
    s = cairo.ImageSurface(cairo.FORMAT_ARGB32, w, h)
    ctx = cairo.Context(s)
    ctx.set_line_cap(cairo.LINE_CAP_ROUND)
    ctx.set_line_join(cairo.LINE_JOIN_ROUND)
    return s, ctx


# Deslocamentos em que cada traço é repetido (as 8 vizinhas da textura), e o tamanho dela
OFFS = [(0, 0)]
SIZE = [0, 0]


def tiled(W, H, draw, bg=None, wrap=True):
    """Desenha `draw(ctx)` com cada traço repetido nas texturas vizinhas: o que passa de uma borda
    volta pela oposta, e a textura repete sem costura. Cada traço sai em todas as posições antes
    do próximo, então a ordem das camadas é a mesma na textura toda."""
    global OFFS
    s, ctx = surface(W, H)
    if bg is not None:
        ctx.set_source_rgba(bg[0], bg[0], bg[0], bg[1])
        ctx.paint()
    SIZE[0], SIZE[1] = W, H
    OFFS = [(dx, dy) for dy in (-H, 0, H) for dx in (-W, 0, W)] if wrap else [(0, 0)]
    draw(ctx)
    OFFS = [(0, 0)]
    return s


def _offsets(xs, ys, pad):
    W, H = SIZE
    x0, x1, y0, y1 = min(xs) - pad, max(xs) + pad, min(ys) - pad, max(ys) + pad
    return [(dx, dy) for dx, dy in OFFS if x1 + dx >= 0 and x0 + dx <= W and y1 + dy >= 0 and y0 + dy <= H]


def save(s, name, post=None):
    w, h = s.get_width(), s.get_height()
    buf = np.frombuffer(s.get_data(), np.uint8).reshape(h, s.get_stride() // 4, 4)[:, :w].astype(np.float32) / 255.0
    # cairo: BGRA pré-multiplicado
    a = buf[..., 3]
    rgb = buf[..., [2, 1, 0]] / np.maximum(a[..., None], 1e-4)
    lum = np.clip(rgb, 0.0, 1.0).mean(axis=2)
    if post is not None:
        lum, a = post(lum, a)
    a = np.clip(a, 0.0, 1.0)
    # Tom médio (ponderado pela cobertura) em 0,5
    m = float((lum * a).sum() / max(a.sum(), 1e-4))
    lum = np.clip(lum - m + 0.5, 0.0, 1.0)
    # Onde quase não há cobertura, o tom vira o da vizinhança: sem halo claro/escuro nos mipmaps
    wa = ndimage.gaussian_filter(a, 3.0, mode="wrap")
    lb = ndimage.gaussian_filter(lum * a, 3.0, mode="wrap") / np.maximum(wa, 1e-4)
    lum = np.where(a < 0.03, np.where(wa > 1e-3, lb, 0.5), lum)
    out = np.dstack([lum, a])
    img = Image.fromarray((np.clip(out, 0, 1) * 255 + 0.5).astype(np.uint8), "LA")
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".png")
    img.save(path, optimize=True)
    print("ok %-16s %s %4d KB  tom médio era %.2f, cobertura média %.2f" % (name, img.size, os.path.getsize(path) // 1024, m, a.mean()))


def value_noise(w, h, cells, seed):
    """Ruído suave (0..1) que repete na largura e na altura."""
    rng = np.random.default_rng(seed)
    cx, cy = cells
    g = rng.random((cy, cx))
    g = np.concatenate([g, g[:, :1]], axis=1)
    g = np.concatenate([g, g[:1, :]], axis=0)
    ys = np.linspace(0, cy, h, endpoint=False)
    xs = np.linspace(0, cx, w, endpoint=False)
    yi = ys.astype(int)
    xi = xs.astype(int)
    fy = (ys - yi)[:, None]
    fx = (xs - xi)[None, :]
    fy = fy * fy * (3 - 2 * fy)
    fx = fx * fx * (3 - 2 * fx)
    a = g[yi][:, xi]
    b = g[yi][:, xi + 1]
    c = g[yi + 1][:, xi]
    d = g[yi + 1][:, xi + 1]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def fbm(w, h, base, octaves, seed):
    tot = np.zeros((h, w))
    amp = 1.0
    norm = 0.0
    for o in range(octaves):
        tot += amp * value_noise(w, h, (base[0] * 2 ** o, base[1] * 2 ** o), seed + o * 17)
        norm += amp
        amp *= 0.5
    return tot / norm


def line(ctx, pts, lum, alpha, width):
    """Traço por `pts` (3 pontos viram uma curva), repetido onde a textura emenda."""
    offs = _offsets([p[0] for p in pts], [p[1] for p in pts], width + 2)
    if not offs:
        return
    ctx.set_source_rgba(lum, lum, lum, alpha)
    ctx.set_line_width(width)
    for dx, dy in offs:
        ctx.move_to(pts[0][0] + dx, pts[0][1] + dy)
        if len(pts) == 3:
            ctx.curve_to(pts[1][0] + dx, pts[1][1] + dy, pts[1][0] + dx, pts[1][1] + dy, pts[2][0] + dx, pts[2][1] + dy)
        else:
            for p in pts[1:]:
                ctx.line_to(p[0] + dx, p[1] + dy)
    ctx.stroke()


def arc(ctx, x, y, r, a0, a1, lum, alpha, width=None):
    """Arco (traço) ou disco cheio (`width` None), repetido onde a textura emenda."""
    offs = _offsets([x], [y], r + 2 + (width or 0))
    if not offs:
        return
    ctx.set_source_rgba(lum, lum, lum, alpha)
    for dx, dy in offs:
        ctx.new_sub_path()
        ctx.arc(x + dx, y + dy, r, a0, a1)
    if width is None:
        ctx.fill()
    else:
        ctx.set_line_width(width)
        ctx.stroke()


def zigzag(ctx, rng, x0, y0, ln, amp, per, ang, lum, alpha, width):
    ca, sa = math.cos(ang), math.sin(ang)
    steps = max(3, int(ln / (per * 0.5)))
    pts = []
    for k in range(steps + 1):
        t = ln * k / steps
        o = amp * (1 if k % 2 else -1) * rng.uniform(0.6, 1.0)
        pts.append((x0 + t * ca - o * sa, y0 + t * sa + o * ca))
    line(ctx, pts, lum, alpha, width)


def clamp(x, a, b):
    return max(a, min(b, x))


def at(noise, x, y):
    h, w = noise.shape
    return noise[int(y) % h, int(x) % w]


# ---------------------------------------------------------------------------
# Cabelo (u ao longo da cabeça, v da linha do cabelo para fora / de cima para baixo)
# ---------------------------------------------------------------------------

def hair_straight(name, wavy, seed, W=1024, H=256):
    """Liso/ondulado: mechas (faixas com tom próprio) feitas de fios finos ao longo de v, com
    vão escuro entre elas e alguns fios claros que pegam a luz."""
    r0 = np.random.default_rng(seed)
    clumps = []
    x = 0.0
    while x < W:
        cw = r0.uniform(8, 20)
        clumps.append((x + cw * 0.5, cw, clamp(r0.normal(0.55, 0.15), 0.18, 0.92), r0.uniform(0, TAU), r0.normal(0, 0.05)))
        x += cw * r0.uniform(0.6, 0.9)

    def path(x0, y0, ln, ph, tilt, sway):
        pts = []
        for k in range(13):
            t = k / 12
            y = y0 + ln * t
            xx = x0 + tilt * (y - y0) + sway * math.sin(math.pi * t)
            if wavy:
                xx += 4.5 * math.sin(TAU * 3 * y / H + ph) + 1.6 * math.sin(TAU * 8 * y / H + ph * 1.7)
            pts.append((xx, y))
        return pts

    def draw(ctx):
        rng = np.random.default_rng(seed + 1)
        for (cx, cw, cl, ph, tilt) in clumps:
            for i in range(int(cw * 1.4)):
                pts = path(cx + rng.normal(0, cw * 0.3), rng.uniform(0, H), rng.uniform(90, 230), ph, tilt, rng.normal(0, 2))
                line(ctx, pts, clamp(cl * 0.45 + rng.normal(0, 0.05), 0.03, 0.6), rng.uniform(0.6, 0.9), rng.uniform(1.8, 3.0))
        for (cx, cw, cl, ph, tilt) in clumps:
            for i in range(int(cw * 3)):
                off = rng.normal(0, cw * 0.27)
                mid = 1.0 - min(1.0, abs(off) / (cw * 0.6))
                pts = path(cx + off, rng.uniform(0, H), rng.uniform(60, 220), ph, tilt, rng.normal(0, 2.5))
                line(ctx, pts, clamp(cl * (0.7 + 0.45 * mid) + rng.normal(0, 0.07), 0.08, 1.0), rng.uniform(0.35, 0.75), rng.uniform(0.6, 1.2))
        for i in range(int(W * 0.3)):
            cx, cw, cl, ph, tilt = clumps[rng.integers(len(clumps))]
            pts = path(cx + rng.normal(0, cw * 0.2), rng.uniform(0, H), rng.uniform(30, 110), ph, tilt, 0.0)
            line(ctx, pts, rng.uniform(0.9, 1.0), rng.uniform(0.25, 0.55), rng.uniform(0.5, 0.9))

    save(tiled(W, H, draw, bg=(0.18, 0.95)), name)


def hair_curl(name, W, H, radius, width, seed):
    """Cacheado: um monte de cachos em C (voltas de raio `radius`, cada uma feita de vários fios
    paralelos), em todas as direções. A parte de cada volta virada para a luz (alto à esquerda)
    clareia, o vão por baixo escurece: lê como um tapete de cachos, não como tricô."""
    noise = fbm(W, H, (max(1, W // 128), max(1, H // 128)), 3, seed + 5)
    light = (-0.55, -0.83)

    def draw(ctx):
        rng = np.random.default_rng(seed)
        placed = 0.0
        while placed < W * H * 1.6:
            cx, cy = rng.uniform(0, W), rng.uniform(0, H)
            R, cw = rng.uniform(*radius), rng.uniform(*width)
            a0 = rng.uniform(0, TAU)
            sweep = rng.uniform(3.4, 5.4)
            sq = rng.uniform(0.65, 1.0)
            base = clamp(0.45 + 0.5 * at(noise, cx, cy) + rng.normal(0, 0.08), 0.2, 1.0)
            placed += sweep * R * cw
            steps = max(10, int(sweep * R / 2.5))
            # vão escuro por baixo da volta
            sh = [(cx + 1.5 + math.cos(a0 + sweep * k / steps) * R, cy + 2.0 + math.sin(a0 + sweep * k / steps) * R * sq) for k in range(steps + 1)]
            line(ctx, sh, 0.05, 0.5, cw * 1.3)
            for f in range(max(4, int(cw * 1.5))):
                o = rng.uniform(-0.5, 0.5) * cw
                wdt = rng.uniform(0.7, 1.15)
                edge = 1.0 - (2 * abs(o) / cw) ** 2
                prev = None
                for k in range(steps + 1):
                    a = a0 + sweep * k / steps
                    rr = R + o
                    pt = (cx + math.cos(a) * rr, cy + math.sin(a) * rr * sq)
                    if prev is not None:
                        nl = max(0.0, math.cos(a) * light[0] + math.sin(a) * light[1])
                        lum = clamp(base * (0.3 + 0.75 * nl * edge + 0.12 * edge), 0.03, 1.0)
                        line(ctx, [prev, pt], lum, 0.8, wdt)
                    prev = pt
        # Frizz: fiapos finos por cima, para os cachos não parecerem argolas de plástico
        for i in range(int(W * H / 30)):
            x0, y0 = rng.uniform(0, W), rng.uniform(0, H)
            lum = clamp(0.2 + 0.7 * at(noise, x0, y0) + rng.normal(0, 0.15), 0.02, 1.0)
            zigzag(ctx, rng, x0, y0, rng.uniform(3.0, 7.0), rng.uniform(0.5, 1.1), rng.uniform(1.6, 2.4), rng.uniform(0, TAU), lum, rng.uniform(0.3, 0.6), rng.uniform(0.5, 0.8))

    save(tiled(W, H, draw, bg=(0.1, 0.95)), name)


def hair_coil(name, W, H, seed, up, sparse=False):
    """Crespo: massa fosca de molinhas miúdas em zigue-zague, com tufos mais claros e vãos
    escuros. `up` puxa as molinhas para cima (calota). `sparse`: só fios soltos sobre fundo
    transparente, para a borda crespa da silhueta."""
    big = fbm(W, H, (W // 40, H // 40), 3, seed + 3)
    small = fbm(W, H, (W // 10, H // 10), 2, seed + 7)

    def draw(ctx):
        rng = np.random.default_rng(seed)
        for i in range(int(W * H / (20.0 if sparse else 6.0))):
            x0, y0 = rng.uniform(0, W), rng.uniform(0, H)
            tone = 0.6 * at(big, x0, y0) + 0.4 * at(small, x0, y0)
            r = rng.random()
            if r < 0.16:
                lum = clamp(0.7 + 0.45 * tone, 0, 1)
            elif r < 0.5:
                lum = clamp(0.08 + 0.3 * tone, 0, 1)
            else:
                lum = clamp(0.25 + 0.6 * tone + rng.normal(0, 0.06), 0, 1)
            ang = -math.pi / 2 + rng.normal(0, 0.7) if (up and rng.random() < 0.5) else rng.uniform(0, TAU)
            zigzag(ctx, rng, x0, y0, rng.uniform(3.0, 7.5), rng.uniform(0.6, 1.3), rng.uniform(1.6, 2.4), ang, lum, rng.uniform(0.45, 0.85), rng.uniform(0.55, 0.9))

    save(tiled(W, H, draw, bg=None if sparse else (0.2, 0.97)), name)


def hair_buzz(name, seed, W=1024, H=256):
    """Raspado / máquina: pelinhos curtos e escuros sobre o couro (fundo transparente)."""
    dens = fbm(W, H, (16, 4), 2, seed + 1)

    def draw(ctx):
        rng = np.random.default_rng(seed)
        for i in range(int(W * H / 3.0)):
            x0, y0 = rng.uniform(0, W), rng.uniform(0, H)
            keep = rng.random() < 0.6 + 0.4 * at(dens, x0, y0)
            ln, ang = rng.uniform(1.2, 3.2), rng.normal(0, 0.35)
            lum, al, wd = rng.uniform(0.0, 0.35), rng.uniform(0.35, 0.7), rng.uniform(0.6, 1.0)
            if keep:
                line(ctx, [(x0, y0), (x0 + math.sin(ang) * ln, y0 - math.cos(ang) * ln)], lum, al, wd)

    save(tiled(W, H, draw), name)


def hair_long(name, seed, W=512, H=512):
    """Cabelo comprido (atrás da cabeça): fios ao longo de v em mechas levemente onduladas."""
    r0 = np.random.default_rng(seed)
    clumps = []
    x = 0.0
    while x < W:
        cw = r0.uniform(8, 22)
        clumps.append((x + cw * 0.5, cw, clamp(r0.normal(0.55, 0.15), 0.2, 0.95), r0.uniform(0, TAU), r0.uniform(1.5, 4.5)))
        x += cw * r0.uniform(0.55, 0.85)

    def draw(ctx):
        rng = np.random.default_rng(seed + 1)
        for (cx, cw, cl, ph, amp) in clumps:
            for i in range(int(cw * 4)):
                off = rng.normal(0, cw * 0.3)
                y0, ln = rng.uniform(0, H), rng.uniform(140, 420)
                mid = 1.0 - min(1.0, abs(off) / (cw * 0.6))
                pts = [(cx + off + amp * math.sin(TAU * 2 * (y0 + ln * k / 16) / H + ph), y0 + ln * k / 16) for k in range(17)]
                dark = i < cw * 1.2
                lum = clamp(cl * 0.45, 0.03, 0.6) if dark else clamp(cl * (0.7 + 0.4 * mid) + rng.normal(0, 0.06), 0.08, 1.0)
                line(ctx, pts, lum, rng.uniform(0.6, 0.9) if dark else rng.uniform(0.35, 0.75), rng.uniform(1.8, 3.0) if dark else rng.uniform(0.6, 1.3))

    save(tiled(W, H, draw, bg=(0.18, 0.95)), name)


# ---------------------------------------------------------------------------
# Barba (plana no rosto: x da esquerda para a direita, y de cima para baixo)
# ---------------------------------------------------------------------------

def beard(name, kind, dense, seed, W=512, H=512):
    """Pelos de barba sobre fundo transparente: a pele aparece entre eles. `dense` é a camada do
    miolo da barba; a outra, rala, vai nas bordas e nas falhas."""
    noise = fbm(W, H, (6, 6), 3, seed + 9)

    def draw(ctx):
        rng = np.random.default_rng(seed)
        if kind == "stubble":
            for i in range(int(W * H / (7 if dense else 22))):
                x0, y0 = rng.uniform(0, W), rng.uniform(0, H)
                keep = rng.random() < 0.55 + 0.45 * at(noise, x0, y0)
                ln, ang = rng.uniform(1.2, 3.4), rng.normal(0, 0.5)
                lum, al, wd = rng.uniform(0.0, 0.3), rng.uniform(0.45, 0.85), rng.uniform(0.6, 1.0)
                if keep:
                    line(ctx, [(x0, y0), (x0 + math.sin(ang) * ln, y0 + math.cos(ang) * ln)], lum, al, wd)
            return
        if kind == "curly":
            for i in range(int(W * H / (10 if dense else 34))):
                x0, y0 = rng.uniform(0, W), rng.uniform(0, H)
                lum = clamp(0.15 + 0.65 * at(noise, x0, y0) + rng.normal(0, 0.14), 0.02, 1.0)
                if rng.random() < 0.55:
                    r, a0 = rng.uniform(1.6, 3.6), rng.uniform(0, TAU)
                    al, wd, span = rng.uniform(0.5, 0.9), rng.uniform(0.7, 1.1), rng.uniform(2.0, 3.8)
                    arc(ctx, x0, y0, r, a0, a0 + span, lum, al, wd)
                else:
                    zigzag(ctx, rng, x0, y0, rng.uniform(4, 10), rng.uniform(0.8, 1.6), rng.uniform(1.8, 2.8), rng.uniform(0, TAU), lum, rng.uniform(0.5, 0.9), rng.uniform(0.7, 1.1))
            return
        long = kind == "long"
        for i in range(int(W * H / ((22 if long else 11) if dense else (80 if long else 46)))):
            x0, y0 = rng.uniform(0, W), rng.uniform(0, H)
            ln = rng.uniform(18, 50) if long else rng.uniform(5, 14)
            ang = rng.normal(0, 0.25 if long else 0.4)
            bend = rng.normal(0, ln * 0.18)
            dx, dy = math.sin(ang), math.cos(ang)
            p1 = (x0 + dx * ln * 0.5 - dy * bend, y0 + dy * ln * 0.5 + dx * bend * 0.3)
            p2 = (x0 + dx * ln, y0 + dy * ln)
            if rng.random() < 0.12:
                lum = rng.uniform(0.85, 1.0)
            else:
                lum = clamp(0.2 + 0.55 * at(noise, x0, y0) + rng.normal(0, 0.12), 0.02, 0.9)
            line(ctx, [(x0, y0), p1, p2], lum, rng.uniform(0.35, 0.8) if dense else rng.uniform(0.55, 0.95), rng.uniform(0.7, 1.2))

    save(tiled(W, H, draw), name)


# ---------------------------------------------------------------------------
# Pele e olhos
# ---------------------------------------------------------------------------

def skin(name, seed, W=512, H=512):
    """Pele: manchas suaves, granulado e poros. Vai por cima do rosto com pouca opacidade."""
    def draw(ctx):
        rng = np.random.default_rng(seed)
        for i in range(int(W * H / 30)):
            x0, y0 = rng.uniform(0, W), rng.uniform(0, H)
            r, lum, al = rng.uniform(0.6, 1.5), rng.uniform(0.15, 0.4), rng.uniform(0.35, 0.8)
            arc(ctx, x0, y0, r, 0, TAU, lum, al)
        for i in range(int(W * H / 500)):
            x0, y0 = rng.uniform(0, W), rng.uniform(0, H)
            ang, ln, al = rng.uniform(0, math.pi), rng.uniform(4, 12), rng.uniform(0.1, 0.25)
            line(ctx, [(x0, y0), (x0 + math.cos(ang) * ln, y0 + math.sin(ang) * ln)], 0.3, al, 0.7)

    def post(lum, a):
        mott = fbm(W, H, (4, 4), 4, seed + 2)
        fine = fbm(W, H, (32, 32), 2, seed + 3)
        grain = np.random.default_rng(seed + 4).random((H, W))
        # Fundo: tom que varia em manchas grandes e em granulado fino (cobertura cheia)
        base = 0.5 + 0.3 * (mott - 0.5) + 0.3 * (fine - 0.5) + 0.16 * (grain - 0.5)
        out_l = lum * a + base * (1 - a)
        return out_l, np.ones_like(a)

    save(tiled(W, H, draw), name, post)


def iris(name, seed):
    W = H = 128
    c = W / 2
    R = W / 2 - 1

    def draw(ctx):
        rng = np.random.default_rng(seed)
        for i in range(900):
            a = rng.uniform(0, TAU)
            r0, r1, wob = R * rng.uniform(0.36, 0.5), R * rng.uniform(0.7, 0.98), rng.normal(0, 0.05)
            pts = []
            for k in range(7):
                t = k / 6
                rr = r0 + (r1 - r0) * t
                aa = a + wob * math.sin(math.pi * t)
                pts.append((c + math.cos(aa) * rr, c + math.sin(aa) * rr))
            light = rng.random() < 0.45
            line(ctx, pts, rng.uniform(0.85, 1.0) if light else rng.uniform(0.25, 0.5), rng.uniform(0.25, 0.6), rng.uniform(0.5, 1.0))
        # Colarete (anel em zigue-zague em volta da pupila) e criptas escuras
        ctx.set_source_rgba(1, 1, 1, 0.5)
        ctx.set_line_width(1.3)
        for k in range(73):
            a = k / 72 * TAU
            rr = R * (0.52 + 0.04 * math.sin(a * 11 + 1.3) + 0.02 * math.sin(a * 23))
            p = (c + math.cos(a) * rr, c + math.sin(a) * rr)
            if k:
                ctx.line_to(*p)
            else:
                ctx.move_to(*p)
        ctx.stroke()
        for i in range(26):
            a, rr = rng.uniform(0, TAU), R * rng.uniform(0.55, 0.8)
            ctx.save()
            ctx.translate(c + math.cos(a) * rr, c + math.sin(a) * rr)
            ctx.rotate(a)
            ctx.scale(rng.uniform(2.0, 4.0), rng.uniform(0.8, 1.6))
            ctx.arc(0, 0, 1, 0, TAU)
            ctx.restore()
            ctx.set_source_rgba(0.12, 0.12, 0.12, rng.uniform(0.25, 0.5))
            ctx.fill()

    def post(lum, a):
        yy, xx = np.mgrid[0:H, 0:W]
        d = np.sqrt((xx - c + 0.5) ** 2 + (yy - c + 0.5) ** 2) / R
        # Borda do limbo mais escura
        lum = lum * (1.0 - 0.45 * np.clip((d - 0.8) / 0.2, 0, 1))
        return lum, a * np.clip((1.0 - d) * 12, 0, 1)

    save(tiled(W, H, draw, wrap=False), name, post)


JOBS = {
    "hair_str": lambda: hair_straight("hair_str", False, 11),
    "hair_wavy": lambda: hair_straight("hair_wavy", True, 12),
    "hair_curl": lambda: hair_curl("hair_curl", 1024, 256, (7, 13), (5, 9), 13),
    "hair_coil": lambda: hair_coil("hair_coil", 1024, 256, 14, True),
    "hair_buzz": lambda: hair_buzz("hair_buzz", 15),
    "hair_long": lambda: hair_long("hair_long", 16),
    "hair_afro": lambda: hair_coil("hair_afro", 512, 512, 17, False),
    "hair_fuzz": lambda: hair_coil("hair_fuzz", 1024, 256, 19, False, sparse=True),
    "hair_ringlets": lambda: hair_curl("hair_ringlets", 512, 512, (11, 20), (7, 12), 18),
    "beard_stubble": lambda: beard("beard_stubble", "stubble", True, 21),
    "beard_short_a": lambda: beard("beard_short_a", "short", False, 22),
    "beard_short_b": lambda: beard("beard_short_b", "short", True, 23),
    "beard_long_a": lambda: beard("beard_long_a", "long", False, 24),
    "beard_long_b": lambda: beard("beard_long_b", "long", True, 25),
    "beard_curly_a": lambda: beard("beard_curly_a", "curly", False, 26),
    "beard_curly_b": lambda: beard("beard_curly_b", "curly", True, 27),
    "skin_pores": lambda: skin("skin_pores", 31),
    "iris": lambda: iris("iris", 41),
}

if __name__ == "__main__":
    names = sys.argv[1:] or list(JOBS)
    for n in names:
        JOBS[n]()
