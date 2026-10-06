#!/usr/bin/env python3
"""Gera as texturas de detalhe dos retratos 2D (cabelo, barba, pele, íris).

Tudo procedural e determinístico (sementes fixas): rode de novo e sai igual.
    python3 tools/portrait_textures/gen.py [nome ...]
Saída: assets/portrait/*.png (cinza + alfa: tom no cinza, cobertura no alfa). O PortraitView
desenha cada textura por cima da malha da peça, tingida pela cor da peça já iluminada.
Precisa de numpy, pillow e pycairo.
"""
import math
import os
import sys

import cairo
import numpy as np
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "portrait")


# ---------------------------------------------------------------------------
# Utilidades
# ---------------------------------------------------------------------------

def surface(w, h):
    s = cairo.ImageSurface(cairo.FORMAT_ARGB32, w, h)
    ctx = cairo.Context(s)
    ctx.set_line_cap(cairo.LINE_CAP_ROUND)
    ctx.set_line_join(cairo.LINE_JOIN_ROUND)
    return s, ctx


def fill_bg(ctx, w, h, lum, alpha):
    ctx.set_source_rgba(lum, lum, lum, alpha)
    ctx.rectangle(0, 0, w, h)
    ctx.fill()


def save(s, name, post=None):
    w, h = s.get_width(), s.get_height()
    buf = np.frombuffer(s.get_data(), np.uint8).reshape(h, s.get_stride() // 4, 4)[:, :w].astype(np.float32) / 255.0
    # cairo: BGRA pré-multiplicado
    a = buf[..., 3]
    rgb = buf[..., [2, 1, 0]] / np.maximum(a[..., None], 1e-4)
    rgb = np.clip(rgb, 0.0, 1.0)
    lum = rgb.mean(axis=2)
    if post is not None:
        lum, a = post(lum, a)
    # Onde não há cobertura, o tom fica o da vizinhança (sem borda escura nos mipmaps)
    # Cinza + alfa (LA8): metade do tamanho e da memória de vídeo de um RGBA
    out = np.dstack([lum, a])
    img = Image.fromarray((np.clip(out, 0, 1) * 255 + 0.5).astype(np.uint8), "LA")
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".png")
    img.save(path, optimize=True)
    print("ok", path, img.size, os.path.getsize(path) // 1024, "KB")


def value_noise(w, h, cells, seed):
    """Ruído suave (0..1) que se repete na largura (a calota não tem emenda visível nas pontas)."""
    rng = np.random.default_rng(seed)
    cx, cy = cells
    g = rng.random((cy + 2, cx + 1))
    g = np.concatenate([g, g[:, :1]], axis=1)
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


def stroke(ctx, pts, lum, alpha, width):
    ctx.set_source_rgba(lum, lum, lum, alpha)
    ctx.set_line_width(width)
    ctx.move_to(*pts[0])
    if len(pts) == 3:
        ctx.curve_to(pts[1][0], pts[1][1], pts[1][0], pts[1][1], pts[2][0], pts[2][1])
    else:
        for p in pts[1:]:
            ctx.line_to(*p)
    ctx.stroke()


def clamp(x, a, b):
    return max(a, min(b, x))


# ---------------------------------------------------------------------------
# Cabelo da calota (u ao longo da cabeça, v da linha do cabelo para fora)
# ---------------------------------------------------------------------------

def hair_straight(name, wavy, seed):
    W, H = 1024, 256
    rng = np.random.default_rng(seed)
    s, ctx = surface(W, H)
    # Fundo: o vão escuro entre as mechas (mais ralo junto da linha do cabelo)
    fill_bg(ctx, W, H, 0.3, 0.0)
    x = -10.0
    clumps = []
    while x < W + 10:
        cw = rng.uniform(9, 26)
        clumps.append((x + cw * 0.5, cw, clamp(rng.normal(0.62, 0.13), 0.3, 0.95), rng.uniform(-0.06, 0.06), rng.uniform(0, math.tau)))
        x += cw * rng.uniform(0.55, 0.9)
    # Camada de baixo: mechas cheias escuras (dão o volume e o vão)
    for (cx, cw, cl, tilt, ph) in clumps:
        n = int(cw * 1.6)
        for i in range(n):
            x0 = cx + rng.normal(0, cw * 0.32)
            y0 = rng.uniform(-6, 26) ** 1.0
            y1 = H + 10 - abs(rng.normal(0, 22))
            pts = []
            steps = 12
            for k in range(steps + 1):
                t = k / steps
                y = y0 + (y1 - y0) * t
                xx = x0 + tilt * (y - y0)
                if wavy:
                    xx += 5.5 * math.sin(y / 34.0 + ph) + 2.0 * math.sin(y / 13.0 + ph * 1.7)
                pts.append((xx, y))
            lum = clamp(cl * 0.55 + rng.normal(0, 0.05), 0.1, 0.8)
            stroke(ctx, pts, lum, rng.uniform(0.55, 0.85), rng.uniform(1.4, 2.6))
    # Fios: o corpo da mecha, mais claros no meio
    for (cx, cw, cl, tilt, ph) in clumps:
        n = int(cw * 3.2)
        for i in range(n):
            off = rng.normal(0, cw * 0.28)
            x0 = cx + off
            y0 = rng.uniform(-4, 40) * rng.uniform(0.2, 1.0)
            y1 = H + 10 - abs(rng.normal(0, 30))
            sway = rng.normal(0, 3.0)
            pts = []
            steps = 14
            for k in range(steps + 1):
                t = k / steps
                y = y0 + (y1 - y0) * t
                xx = x0 + tilt * (y - y0) + sway * math.sin(math.pi * t)
                if wavy:
                    xx += 5.5 * math.sin(y / 34.0 + ph) + 2.0 * math.sin(y / 13.0 + ph * 1.7)
                pts.append((xx, y))
            mid = 1.0 - min(1.0, abs(off) / (cw * 0.6))
            lum = clamp(cl * (0.8 + 0.35 * mid) + rng.normal(0, 0.06), 0.15, 1.0)
            stroke(ctx, pts, lum, rng.uniform(0.35, 0.75), rng.uniform(0.6, 1.2))
    # Reflexos: poucos fios finos bem claros
    for i in range(int(W * 0.35)):
        cx, cw, cl, tilt, ph = clumps[rng.integers(len(clumps))]
        x0 = cx + rng.normal(0, cw * 0.22)
        y0 = rng.uniform(20, 120)
        y1 = y0 + rng.uniform(40, 140)
        pts = []
        for k in range(9):
            t = k / 8
            y = y0 + (y1 - y0) * t
            xx = x0 + tilt * (y - y0)
            if wavy:
                xx += 5.5 * math.sin(y / 34.0 + ph) + 2.0 * math.sin(y / 13.0 + ph * 1.7)
            pts.append((xx, y))
        stroke(ctx, pts, rng.uniform(0.9, 1.0), rng.uniform(0.25, 0.6), rng.uniform(0.45, 0.8))
    # Fios soltos na linha do cabelo (finos, ralos)
    for i in range(int(W * 0.5)):
        x0 = rng.uniform(0, W)
        y0 = rng.uniform(-2, 18)
        ln = rng.uniform(10, 34)
        ang = rng.normal(0, 0.18)
        stroke(ctx, [(x0, y0), (x0 + math.sin(ang) * ln, y0 + ln)], rng.uniform(0.2, 0.55), rng.uniform(0.35, 0.7), rng.uniform(0.5, 0.8))

    def post(lum, a):
        # O cabelo nasce ralo: na linha do cabelo (v pequeno) a cobertura cai
        v = np.linspace(0, 1, H)[:, None]
        a = a * np.clip(0.25 + v * 7.0, 0, 1)
        return lum, a
    save(s, name, post)


def hair_curl(name, W, H, amp_rng, period_rng, width_rng, len_rng, seed, cap=True):
    """Cacheado: mechas (cachos) em S, cada uma com vários fios acompanhando a mesma onda; a crista
    de cada volta pega a luz e o vão entre os cachos fica escuro."""
    rng = np.random.default_rng(seed)
    s, ctx = surface(W, H)
    fill_bg(ctx, W, H, 0.2, 0.92)
    noise = fbm(W, H, (8, 3) if cap else (6, 6), 3, seed + 5)
    area = W * H
    placed = 0.0
    while placed < area * 2.6:
        cx = rng.uniform(-12, W + 12)
        y0 = rng.uniform(-40, H - 10)
        ln = rng.uniform(*len_rng)
        A = rng.uniform(*amp_rng)
        P = rng.uniform(*period_rng)
        cw = rng.uniform(*width_rng)
        ph = rng.uniform(0, math.tau)
        tilt = rng.normal(0, 0.12 if cap else 0.3)
        nz = noise[int(clamp(y0 + ln * 0.5, 0, H - 1)), int(clamp(cx, 0, W - 1))]
        base = clamp(0.5 + 0.45 * nz + rng.normal(0, 0.08), 0.25, 1.0)
        placed += ln * cw
        # sombra embaixo do cacho (separa do vizinho)
        pts = []
        for k in range(25):
            y = y0 + ln * k / 24
            pts.append((cx + A * math.sin(math.tau * (y - y0) / P + ph) + tilt * (y - y0), y))
        stroke(ctx, pts, 0.12, 0.55, cw * 1.25)
        nf = max(4, int(cw * 1.8))
        for f in range(nf):
            o = rng.uniform(-0.5, 0.5) * cw
            fj = rng.normal(0, 0.12)
            steps = max(10, int(ln / 2.5))
            prev = None
            for k in range(steps + 1):
                y = y0 + ln * k / steps
                th = math.tau * (y - y0) / P + ph + fj
                slope = A * math.tau / P * math.cos(th)
                nx = 1.0 / math.sqrt(1 + slope * slope)
                x = cx + A * math.sin(th) + tilt * (y - y0) + o * nx
                pt = (x, y - o * slope * nx * 0.3)
                if prev is not None:
                    # Crista da onda (sin ~ ±1) clara; trecho inclinado mais escuro; borda do cacho escura
                    crest = abs(math.sin(th)) ** 2
                    edge = 1.0 - (2 * abs(o) / cw) ** 2
                    lum = clamp(base * (0.45 + 0.45 * crest * edge + 0.15 * edge), 0.05, 1.0)
                    ctx.set_source_rgba(lum, lum, lum, 0.7)
                    ctx.set_line_width(rng.uniform(0.7, 1.2))
                    ctx.move_to(*prev)
                    ctx.line_to(*pt)
                    ctx.stroke()
                prev = pt

    def post(lum, a):
        if cap:
            v = np.linspace(0, 1, H)[:, None]
            a = a * np.clip(0.3 + v * 6.0, 0, 1)
        return lum, a
    save(s, name, post)


def zigzag(ctx, rng, x0, y0, ln, amp, per, ang, lum, alpha, width):
    ca, sa = math.cos(ang), math.sin(ang)
    steps = max(3, int(ln / (per * 0.5)))
    pts = []
    for k in range(steps + 1):
        t = ln * k / steps
        o = amp * (1 if k % 2 else -1) * rng.uniform(0.6, 1.0)
        pts.append((x0 + t * ca - o * sa, y0 + t * sa + o * ca))
    ctx.set_source_rgba(lum, lum, lum, alpha)
    ctx.set_line_width(width)
    ctx.move_to(*pts[0])
    for p in pts[1:]:
        ctx.line_to(*p)
    ctx.stroke()


def hair_coil(name, W, H, seed, cap=True):
    """Crespo: massa fosca de molinhas miúdas em zigue-zague, com tufos mais claros e vãos escuros."""
    rng = np.random.default_rng(seed)
    s, ctx = surface(W, H)
    fill_bg(ctx, W, H, 0.3, 0.95)
    big = fbm(W, H, (14, 4) if cap else (9, 9), 3, seed + 3)
    small = fbm(W, H, (60, 15) if cap else (36, 36), 2, seed + 7)
    n = int(W * H / 5.5)
    for i in range(n):
        x0 = rng.uniform(-6, W + 6)
        y0 = rng.uniform(-6, H + 6)
        yi, xi = int(clamp(y0, 0, H - 1)), int(clamp(x0, 0, W - 1))
        tone = 0.55 * big[yi, xi] + 0.45 * small[yi, xi]
        r = rng.random()
        if r < 0.18:
            lum = clamp(0.75 + 0.4 * tone, 0, 1) # pontinha que pega a luz
        elif r < 0.55:
            lum = clamp(0.15 + 0.3 * tone, 0, 1) # fundo do tufo
        else:
            lum = clamp(0.3 + 0.6 * tone + rng.normal(0, 0.06), 0, 1)
        ang = rng.uniform(0, math.tau) if not cap or rng.random() < 0.6 else -math.pi / 2 + rng.normal(0, 0.6)
        zigzag(ctx, rng, x0, y0, rng.uniform(3.5, 9.0), rng.uniform(0.6, 1.4), rng.uniform(1.6, 2.6), ang, lum, rng.uniform(0.45, 0.85), rng.uniform(0.55, 0.95))

    def post(lum, a):
        if cap:
            v = np.linspace(0, 1, H)[:, None]
            a = a * np.clip(0.35 + v * 5.0, 0, 1)
        return lum, a
    save(s, name, post)


def hair_buzz(name, seed):
    """Cabelo raspado / máquina: pelinhos curtos e escuros sobre o couro (fundo transparente)."""
    W, H = 1024, 256
    rng = np.random.default_rng(seed)
    s, ctx = surface(W, H)
    dens = fbm(W, H, (16, 4), 2, seed + 1)
    n = int(W * H / 3.2)
    for i in range(n):
        x0 = rng.uniform(0, W)
        y0 = rng.uniform(0, H)
        if rng.random() > 0.7 + 0.3 * dens[int(y0) % H, int(x0) % W]:
            continue
        ln = rng.uniform(1.0, 2.8)
        ang = rng.normal(0, 0.3)
        stroke(ctx, [(x0, y0), (x0 + math.sin(ang) * ln, y0 + math.cos(ang) * ln)], rng.uniform(0.08, 0.32), rng.uniform(0.3, 0.6), rng.uniform(0.5, 0.85))
    save(s, name)


def hair_long(name, seed):
    """Cabelo comprido (atrás da cabeça e mechas): fios verticais em mechas, levemente ondulados."""
    W = H = 512
    rng = np.random.default_rng(seed)
    s, ctx = surface(W, H)
    fill_bg(ctx, W, H, 0.3, 0.6)
    x = -8.0
    while x < W + 8:
        cw = rng.uniform(8, 22)
        cx = x + cw * 0.5
        cl = clamp(rng.normal(0.6, 0.14), 0.25, 0.95)
        ph = rng.uniform(0, math.tau)
        amp = rng.uniform(1.5, 5.0)
        for i in range(int(cw * 3.5)):
            off = rng.normal(0, cw * 0.3)
            y0 = rng.uniform(-30, 120)
            y1 = rng.uniform(H - 80, H + 30)
            pts = []
            for k in range(17):
                t = k / 16
                y = y0 + (y1 - y0) * t
                pts.append((cx + off + amp * math.sin(y / 46.0 + ph), y))
            mid = 1.0 - min(1.0, abs(off) / (cw * 0.6))
            lum = clamp(cl * (0.7 + 0.4 * mid) + rng.normal(0, 0.06), 0.1, 1.0)
            stroke(ctx, pts, lum, rng.uniform(0.35, 0.75), rng.uniform(0.6, 1.3))
        x += cw * rng.uniform(0.55, 0.9)
    save(s, name)


# ---------------------------------------------------------------------------
# Barba (mapeada no rosto: x da esquerda para a direita, y de cima para baixo)
# ---------------------------------------------------------------------------

def beard(name, kind, sparse, seed):
    W = H = 512
    rng = np.random.default_rng(seed)
    s, ctx = surface(W, H)
    noise = fbm(W, H, (6, 6), 3, seed + 9)
    if kind == "stubble":
        n = int(W * H / (9 if not sparse else 30))
        for i in range(n):
            x0, y0 = rng.uniform(0, W), rng.uniform(0, H)
            if rng.random() > 0.5 + 0.5 * noise[int(y0) % H, int(x0) % W]:
                continue
            ln = rng.uniform(1.0, 3.2)
            ang = rng.normal(0, 0.5)
            stroke(ctx, [(x0, y0), (x0 + math.sin(ang) * ln, y0 + math.cos(ang) * ln)], rng.uniform(0.05, 0.35), rng.uniform(0.4, 0.85), rng.uniform(0.55, 0.95))
        save(s, name)
        return
    if kind == "curly":
        # Pelos crespos: arquinhos em C e zigue-zagues curtos, em todas as direções
        n = int(W * H / (12 if not sparse else 45))
        for i in range(n):
            x0, y0 = rng.uniform(-4, W + 4), rng.uniform(-4, H + 4)
            nz = noise[int(clamp(y0, 0, H - 1)), int(clamp(x0, 0, W - 1))]
            lum = clamp(0.2 + 0.6 * nz + rng.normal(0, 0.14), 0.05, 1.0)
            if rng.random() < 0.6:
                r = rng.uniform(1.4, 3.2)
                a0 = rng.uniform(0, math.tau)
                ctx.set_source_rgba(lum, lum, lum, rng.uniform(0.5, 0.9))
                ctx.set_line_width(rng.uniform(0.6, 1.0))
                ctx.arc(x0, y0, r, a0, a0 + rng.uniform(2.0, 3.8))
                ctx.stroke()
            else:
                zigzag(ctx, rng, x0, y0, rng.uniform(4, 9), rng.uniform(0.8, 1.6), rng.uniform(1.8, 2.8), rng.uniform(0, math.tau), lum, rng.uniform(0.5, 0.9), rng.uniform(0.6, 1.0))
        save(s, name)
        return
    long = kind == "long"
    n = int(W * H / ((26 if long else 14) if not sparse else (90 if long else 60)))
    for i in range(n):
        x0, y0 = rng.uniform(-10, W + 10), rng.uniform(-30, H + 10)
        nz = noise[int(clamp(y0, 0, H - 1)), int(clamp(x0, 0, W - 1))]
        ln = rng.uniform(16, 42) if long else rng.uniform(5, 13)
        ang = rng.normal(0, 0.28 if long else 0.38)
        bend = rng.normal(0, ln * 0.18)
        dx, dy = math.sin(ang), math.cos(ang)
        p1 = (x0 + dx * ln * 0.5 - dy * bend, y0 + dy * ln * 0.5 + dx * bend * 0.3)
        p2 = (x0 + dx * ln, y0 + dy * ln)
        r = rng.random()
        if r < 0.12:
            lum = rng.uniform(0.85, 1.0) # fio claro (pega a luz)
        else:
            lum = clamp(0.25 + 0.55 * nz + rng.normal(0, 0.12), 0.05, 0.9)
        stroke(ctx, [(x0, y0), p1, p2], lum, rng.uniform(0.55, 0.95) if sparse else rng.uniform(0.35, 0.8), rng.uniform(0.6, 1.15))
    save(s, name)


# ---------------------------------------------------------------------------
# Pele e olhos
# ---------------------------------------------------------------------------

def skin_pores(name, seed):
    W = H = 512
    rng = np.random.default_rng(seed)
    s, ctx = surface(W, H)
    for i in range(int(W * H / 26)):
        x0, y0 = rng.uniform(0, W), rng.uniform(0, H)
        r = rng.uniform(0.45, 1.25)
        lum = rng.uniform(0.35, 0.62)
        ctx.set_source_rgba(lum, lum, lum, rng.uniform(0.25, 0.6))
        ctx.arc(x0, y0, r, 0, math.tau)
        ctx.fill()
    # Linhas finíssimas da pele (micro-relevo)
    for i in range(int(W * H / 420)):
        x0, y0 = rng.uniform(0, W), rng.uniform(0, H)
        ang = rng.uniform(0, math.pi)
        ln = rng.uniform(4, 12)
        stroke(ctx, [(x0, y0), (x0 + math.cos(ang) * ln, y0 + math.sin(ang) * ln)], 0.55, rng.uniform(0.08, 0.2), 0.6)

    def post(lum, a):
        mott = fbm(W, H, (5, 5), 4, seed + 2)
        grain = np.random.default_rng(seed + 4).random((H, W))
        # Manchas suaves (pele não é uniforme) e granulado fino por baixo dos poros
        base_a = 0.1 * np.clip((mott - 0.45) * 3.0, 0, 1) + 0.06 * grain
        base_l = 0.62 + 0.0 * mott
        out_a = a + base_a * (1 - a)
        out_l = (lum * a + base_l * base_a * (1 - a)) / np.maximum(out_a, 1e-4)
        return out_l, out_a
    save(s, name, post)


def iris(name, seed):
    W = H = 128
    rng = np.random.default_rng(seed)
    s, ctx = surface(W, H)
    c = W / 2
    R = W / 2 - 1
    # Fibras radiais (claras e escuras), mais densas perto da pupila
    for i in range(900):
        a = rng.uniform(0, math.tau)
        r0 = R * rng.uniform(0.36, 0.5)
        r1 = R * rng.uniform(0.7, 0.98)
        wob = rng.normal(0, 0.05)
        pts = []
        for k in range(7):
            t = k / 6
            rr = r0 + (r1 - r0) * t
            aa = a + wob * math.sin(math.pi * t)
            pts.append((c + math.cos(aa) * rr, c + math.sin(aa) * rr))
        light = rng.random() < 0.45
        stroke(ctx, pts, rng.uniform(0.85, 1.0) if light else rng.uniform(0.25, 0.5), rng.uniform(0.25, 0.6), rng.uniform(0.5, 1.0))
    # Colarete (anel em zigue-zague em volta da pupila) e criptas escuras
    ctx.set_source_rgba(1, 1, 1, 0.5)
    ctx.set_line_width(1.3)
    for k in range(73):
        a = k / 72 * math.tau
        rr = R * (0.52 + 0.04 * math.sin(a * 11 + 1.3) + 0.02 * math.sin(a * 23))
        p = (c + math.cos(a) * rr, c + math.sin(a) * rr)
        if k == 0:
            ctx.move_to(*p)
        else:
            ctx.line_to(*p)
    ctx.stroke()
    for i in range(26):
        a = rng.uniform(0, math.tau)
        rr = R * rng.uniform(0.55, 0.8)
        ctx.save()
        ctx.translate(c + math.cos(a) * rr, c + math.sin(a) * rr)
        ctx.rotate(a)
        ctx.scale(rng.uniform(2.0, 4.0), rng.uniform(0.8, 1.6))
        ctx.arc(0, 0, 1, 0, math.tau)
        ctx.restore()
        ctx.set_source_rgba(0.12, 0.12, 0.12, rng.uniform(0.25, 0.5))
        ctx.fill()

    def post(lum, a):
        yy, xx = np.mgrid[0:H, 0:W]
        d = np.sqrt((xx - c + 0.5) ** 2 + (yy - c + 0.5) ** 2) / R
        a = a * np.clip((1.0 - d) * 12, 0, 1)
        return lum, a
    save(s, name, post)


JOBS = {
    "hair_str": lambda: hair_straight("hair_str", False, 11),
    "hair_wavy": lambda: hair_straight("hair_wavy", True, 12),
    "hair_curl": lambda: hair_curl("hair_curl", 1024, 256, (2.5, 5.0), (12, 20), (6, 12), (50, 150), 13, True),
    "hair_coil": lambda: hair_coil("hair_coil", 1024, 256, 14, True),
    "hair_buzz": lambda: hair_buzz("hair_buzz", 15),
    "hair_long": lambda: hair_long("hair_long", 16),
    "hair_afro": lambda: hair_coil("hair_afro", 512, 512, 17, False),
    "hair_ringlets": lambda: hair_curl("hair_ringlets", 512, 512, (4.0, 8.0), (18, 30), (10, 18), (60, 180), 18, False),
    "beard_stubble": lambda: beard("beard_stubble", "stubble", False, 21),
    "beard_short_a": lambda: beard("beard_short_a", "short", True, 22),
    "beard_short_b": lambda: beard("beard_short_b", "short", False, 23),
    "beard_long_a": lambda: beard("beard_long_a", "long", True, 24),
    "beard_long_b": lambda: beard("beard_long_b", "long", False, 25),
    "beard_curly_a": lambda: beard("beard_curly_a", "curly", True, 26),
    "beard_curly_b": lambda: beard("beard_curly_b", "curly", False, 27),
    "skin_pores": lambda: skin_pores("skin_pores", 31),
    "iris": lambda: iris("iris", 41),
}

if __name__ == "__main__":
    names = sys.argv[1:] or list(JOBS)
    for n in names:
        JOBS[n]()
