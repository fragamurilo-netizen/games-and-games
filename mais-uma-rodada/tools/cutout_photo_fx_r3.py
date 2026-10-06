# Protótipo (rodada 3): opções fotorrealistas sobre o recorte FM (fundo transparente).
# Entrada: capturas da mesma faixa com fundo preto e com fundo branco, de
#   tools/cutout_closeup.gd --size=400 --bg=#000000 (e --bg=#ffffff), sem --cutout (enquadramento FM).
# Uso: python3 cutout_photo_fx_r3.py --out DIR PRETO1.png BRANCO1.png [PRETO2.png BRANCO2.png ...]
# Gera DIR/r3-N-nome.png (uma folha por opção, uma linha por par) e DIR/r3-comparacao.png.
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage as nd

S = 400
rng = np.random.default_rng(11)
yy, xx = np.mgrid[0:S, 0:S] / S


# ---------------------------------------------------------------------------
# Entrada: recorte com alfa recuperado da diferença entre fundo preto e branco
# ---------------------------------------------------------------------------

def load_strip(black, white):
    B = np.asarray(Image.open(black).convert('RGB')).astype(np.float32) / 255
    W = np.asarray(Image.open(white).convert('RGB')).astype(np.float32) / 255
    A = np.clip(1 - (W - B).mean(2), 0, 1)
    RGB = np.where(A[..., None] > 1e-3, B / np.maximum(A[..., None], 1e-3), 0).clip(0, 1)
    tiles = []
    n = (B.shape[1] - 10) // (S + 10)
    for i in range(n):
        x = 10 + i * (S + 10)
        a = A[10:10 + S, x:x + S].copy()
        if a.mean() < 0.02:
            continue
        tiles.append((RGB[10:10 + S, x:x + S].copy(), a))
    return tiles


# ---------------------------------------------------------------------------
# Peças
# ---------------------------------------------------------------------------

def blur(a, s):
    return nd.gaussian_filter(a, s)


def blur3(c, s):
    return np.dstack([blur(c[..., k], s) for k in range(3)])


def lum(c):
    return c @ np.array([0.299, 0.587, 0.114], dtype=np.float32)


def shift(a, dx, dy):
    return nd.shift(a, (dy, dx), order=1, mode='nearest')


def comp(fg, a, bg):
    return fg * a[..., None] + bg * (1 - a[..., None])


def tone(c, exposure=1.0, contrast=0.2, shoulder=0.82):
    # Curva de foto: ombro macio nos claros (nada estoura) e um S leve no contraste
    x = np.maximum(c * exposure, 0)
    x = np.where(x > shoulder, shoulder + (1 - shoulder) * (1 - np.exp(-(x - shoulder) / (1 - shoulder))), x)
    s = x * x * (3 - 2 * x)
    return np.clip(x + (s - x) * contrast, 0, 1)


def saturate(c, k):
    L = lum(c)[..., None]
    return np.clip(L + (c - L) * k, 0, 1)


def unsharp(c, s=1.0, amt=0.5):
    return np.clip(c + amt * (c - blur3(c, s)), 0, 1)


def grain(c, amt, color=0.0, size=0.6):
    L = lum(c)
    w = 0.55 + 1.8 * L * (1 - L)
    n = blur(rng.standard_normal((S, S)), size) * amt * w
    out = c + n[..., None]
    if color > 0:
        out = out + np.dstack([blur(rng.standard_normal((S, S)), size * 1.4) for _ in range(3)]) * amt * color
    return np.clip(out, 0, 1)


def vignette(c, k, cx=0.5, cy=0.45):
    d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
    return c * np.clip(1 - k * d ** 2 * 2.2, 0, 1)[..., None]


def chroma(c, px):
    # Aberração cromática: vermelho um pouco maior e azul um pouco menor que o verde, a partir do centro
    out = c.copy()
    for k, s in ((0, 1 + px / S), (2, 1 - px / S)):
        m = np.array([1 / s, 1 / s])
        off = (np.array([S, S]) / 2) * (1 - 1 / s)
        out[..., k] = nd.affine_transform(c[..., k], m, offset=off, order=1, mode='nearest')
    return out


def micro(c, a, amt):
    # Microtextura de foto (poros, fios, ruído de sensor) onde o desenho é liso; menos nas sombras
    n = blur(rng.standard_normal((S, S)), 0.5) + blur(rng.standard_normal((S, S)), 1.1) * 0.3
    n /= n.std() + 1e-6
    L = lum(c)
    flat = np.exp(-np.abs(L - blur(L, 1.2)) * 40)  # mais onde é liso (pele), menos em bordas e fios
    w = a * (0.3 + 0.7 * flat) * np.clip(4 * L * (1 - L), 0, 1)
    return np.clip(c * (1 + amt * n * w)[..., None], 0, 1)


def normals(a, c, relief=5.0):
    # Normal aproximada: uma cúpula pela distância até a borda do recorte (os ombros saem pela
    # borda de baixo, então a borda de baixo do quadro conta como "dentro") e relevo pela luminância
    m = a > 0.5
    ext = np.vstack([m, np.repeat(m[-1:], 160, 0)])
    D = nd.distance_transform_edt(ext)[:S]
    # Só a faixa perto da borda se curva, e bem suavizada: a distância até a borda tem "vincos"
    # (onde duas bordas ficam à mesma distância) que a luz de lado mostrava como riscos no rosto
    R = 45.0
    h = (1 - (1 - np.clip(D / R, 0, 1)) ** 2) * R * 0.85
    h = blur(h, 7.0) + blur(lum(c), 3.0) * relief
    gy, gx = np.gradient(h)
    N = np.dstack([-gx, -gy, np.ones_like(gx)])
    return N / np.linalg.norm(N, axis=2, keepdims=True)


def relight(c, a, N, L, strength, ambient=0.35):
    L = np.array(L, dtype=np.float32)
    L /= np.linalg.norm(L)
    sh = np.clip(N @ L, 0, 1)
    mult = ambient + (1 - ambient) * sh
    mean = (mult * a).sum() / max(a.sum(), 1)
    k = 1 + strength * (mult / mean - 1)
    return np.clip(c * k[..., None], 0, 1.4)


def spec(N, a, L, power, mask):
    L = np.array(L, dtype=np.float32)
    L /= np.linalg.norm(L)
    H = L + np.array([0, 0, 1.0])
    H /= np.linalg.norm(H)
    return np.clip(N @ H, 0, 1) ** power * a * mask


def rim(a, N, side, width=1.0):
    # Contorno de luz pelo lado `side` (-1 esquerda, 1 direita, 0 os dois), mais forte em cima
    edge = np.clip(1 - N[..., 2], 0, 1) ** (1.4 / width)
    if side != 0:
        edge *= np.clip(N[..., 0] * side * 1.6, 0, 1)
    return edge * a * np.clip(1.3 - yy * 0.9, 0, 1)


def light_wrap(fg, a, bg, k):
    # A luz do fundo vaza um pouco sobre a borda do recorte, como numa foto de verdade
    e = a * np.clip(1 - blur(a, 3.5) * 1.0, 0, 1) * 2.2
    e = np.clip(e, 0, 1)[..., None]
    return fg * (1 - k * e) + blur3(bg, 6) * k * e


def bokeh(bg, n, cols, rmin, rmax, ymin, ymax, alpha, seed, ring=0.0):
    r = np.random.default_rng(seed)
    out = bg.copy()
    for _ in range(n):
        cx, cy = r.uniform(-0.05, 1.05), r.uniform(ymin, ymax)
        rr = r.uniform(rmin, rmax)
        d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / rr
        m = np.clip((1 - d) * 6, 0, 1) * (1 - ring + ring * np.clip(d * 1.3, 0, 1)) * alpha * r.uniform(0.35, 1)
        col = np.array(cols[r.integers(len(cols))])
        out = out + m[..., None] * col
    return out


def gradient(top, bottom, curve=1.0):
    t = (yy ** curve)[..., None]
    return np.array(top) * (1 - t) + np.array(bottom) * t


def glow(cx, cy, r, col, amt):
    d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
    return (np.clip(1 - d / r, 0, 1) ** 2 * amt)[..., None] * np.array(col)


# ---------------------------------------------------------------------------
# Opções
# ---------------------------------------------------------------------------

def o_estudio(c, a):
    # 1. Estúdio FM: luz macia de frente-esquerda, rebatedor, fundo cinza-azulado do cartão.
    N = normals(a, c)
    fg = relight(c, a, N, (-0.45, -0.55, 0.75), 0.35, 0.45)
    fg = fg + spec(N, a, (-0.45, -0.55, 0.75), 18, lum(c) > 0.25)[..., None] * 0.06
    fg = saturate(fg, 0.9)
    fg = micro(fg, a, 0.018)
    bg = gradient((0.17, 0.19, 0.22), (0.09, 0.10, 0.12), 0.8) + glow(0.42, 0.32, 0.75, (0.16, 0.17, 0.19), 1.0)
    sh = blur(shift(a, 9, 7), 9) * 0.35
    bg = bg * (1 - sh[..., None])
    fg = light_wrap(fg, a, bg, 0.12)
    out = comp(fg, a, bg)
    out = tone(out, 1.0, 0.18)
    out = unsharp(out, 0.9, 0.55)
    return grain(out, 0.012)


def o_coletiva(c, a):
    # 2. Coletiva de imprensa: flash de frente, sombra dura na parede de patrocinadores desfocada.
    N = normals(a, c, 3.0)
    fg = c * 1.02 + 0.01
    fg = relight(fg, a, N, (0.05, -0.15, 1.0), 0.2, 0.6)
    L = lum(c)
    hot = spec(N, a, (0.05, -0.2, 1.0), 30, np.clip((L - 0.35) * 2.5, 0, 1))
    fg = fg + hot[..., None] * 0.1
    fg = saturate(fg, 1.05) * np.array([1.03, 1.0, 0.97])
    fg = micro(fg, a, 0.016)
    # Parede: placas em xadrez com marcas inventadas (sem marca real)
    bg = np.zeros((S, S, 3)) + np.array([0.86, 0.87, 0.89])
    cell = 0.25
    gx = np.floor((xx + 0.07) / cell).astype(int)
    gy = np.floor((yy + 0.03) / (cell * 0.62)).astype(int)
    fx = ((xx + 0.07) % cell) / cell - 0.5
    fy = ((yy + 0.03) % (cell * 0.62)) / (cell * 0.62) - 0.5
    alt = (gx + gy) % 2 == 0
    logo1 = (np.abs(fx) < 0.3) & (np.abs(fy) < 0.12)
    logo2 = np.sqrt((fx / 0.6) ** 2 + (fy / 0.75) ** 2) < 0.3
    bg = np.where((alt & logo1)[..., None], np.array([0.06, 0.18, 0.45]), bg)
    bg = np.where((~alt & logo2)[..., None], np.array([0.78, 0.12, 0.14]), bg)
    bg = np.where((~alt & logo2 & (np.sqrt((fx / 0.6) ** 2 + (fy / 0.75) ** 2) < 0.15))[..., None], np.array([0.97, 0.97, 0.97]), bg)
    bg = blur3(bg, 3.2)
    bg = bg * (1.08 - 0.5 * np.sqrt((xx - 0.5) ** 2 + (yy - 0.42) ** 2))[..., None]   # o flash cai nas bordas
    sh = blur(shift(a, 16, 9), 2.2) * 0.55
    bg = bg * (1 - sh[..., None])
    out = comp(np.clip(fg, 0, 1), a, bg)
    out = tone(out, 1.0, 0.12)
    out = unsharp(out, 0.8, 0.6)
    return grain(out, 0.018, 0.2)


def o_tunel(c, a):
    # 3. Túnel de acesso: luz fria de cima, corredor escuro com as lâmpadas fugindo para o fundo.
    N = normals(a, c, 1.5)
    fg = relight(c, a, N, (0.0, -1.0, 0.6), 0.35, 0.35)
    fg = fg * np.clip(1.1 - yy * 0.4, 0.6, 1.1)[..., None]
    fg = fg * np.array([0.93, 1.0, 1.03]) + np.array([-0.01, 0.005, 0.015])
    fg = fg + spec(N, a, (0.0, -1.0, 0.5), 24, lum(c) > 0.2)[..., None] * np.array([0.75, 0.9, 1.0]) * 0.12
    r = rim(a, N, 0, 0.8)
    fg = fg + r[..., None] * np.array([0.55, 0.75, 0.9]) * 0.35
    fg = micro(fg, a, 0.018)
    bg = gradient((0.05, 0.07, 0.08), (0.03, 0.035, 0.04), 1.2)
    # Duas fileiras de lâmpadas no teto, uma de cada lado, fugindo para a saída clara atrás da cabeça
    vx, vy = 0.5, 0.4
    for side in (-1, 1):
        x0, y0 = 0.5 + side * 0.75, -0.08
        dx, dy = vx - x0, vy - y0
        ln = np.hypot(dx, dy)
        t = np.clip(((xx - x0) * dx + (yy - y0) * dy) / ln ** 2, 0, 1)
        d = np.hypot(xx - (x0 + t * dx), yy - (y0 + t * dy))
        thick = 0.022 * (1 - t) + 0.003
        dash = (np.sin(t * 60 * (1 + 0.6 * t)) > -0.2).astype(float)
        m = np.clip(1 - d / thick, 0, 1) * dash * (1 - 0.6 * t)
        bg = bg + m[..., None] * np.array([0.8, 0.95, 1.0])
    bg = bg + glow(0.5, 0.4, 0.5, (0.55, 0.65, 0.7), 1.0)
    bg = blur3(bg, 6)
    bg = bg + blur3(bg, 18) * 0.6
    fg = light_wrap(fg, a, bg, 0.2)
    out = comp(np.clip(fg, 0, 1), a, bg)
    out = tone(out, 1.0, 0.25)
    out = vignette(out, 0.35)
    out = unsharp(out, 1.0, 0.5)
    return grain(out, 0.028, 0.25)


def o_filme(c, a):
    # 4. Filme 35 mm: luz de dia nublado, cor de filme (pretos levantados, pele quente, verde
    # contido), halo vermelho em volta do claro, grão e aberração da lente.
    N = normals(a, c)
    fg = relight(c, a, N, (-0.3, -0.6, 0.8), 0.25, 0.55)
    fg = micro(fg, a, 0.016)
    bg = gradient((0.62, 0.68, 0.62), (0.28, 0.42, 0.25), 1.6)
    bg = bg + glow(0.2, 0.15, 0.6, (0.25, 0.22, 0.15), 1.0)
    bg = bokeh(bg, 30, [(0.9, 0.95, 0.85), (0.45, 0.6, 0.35), (0.3, 0.45, 0.25)], 0.03, 0.09, 0.0, 0.55, 0.35, 21)
    bg = blur3(bg, 7)
    fg = light_wrap(fg, a, bg, 0.18)
    out = comp(np.clip(fg, 0, 1), a, np.clip(bg, 0, 1))
    # Curva de filme: pretos levantados, ombro macio, pele quente e verdes puxados para o oliva
    out = tone(out, 1.0, 0.1)
    out = out * 0.92 + 0.045
    out = out * np.array([1.04, 1.0, 0.92])
    g = out[..., 1] - (out[..., 0] + out[..., 2]) / 2
    out[..., 1] -= np.clip(g, 0, 1) * 0.25
    out = saturate(out, 0.88)
    hal = blur3(np.clip(out - 0.72, 0, 1), 5) * np.array([1.0, 0.42, 0.22]) * 0.9
    out = np.clip(out + hal, 0, 1)
    out = chroma(out, 1.2)
    out = vignette(out, 0.28)
    return grain(out, 0.04, 0.35, 0.8)


def o_chuva(c, a):
    # 5. Noite de chuva: refletores atrás, pele e cabelo molhados (brilho nas partes altas),
    # cor fria e gotas riscando a frente e o fundo.
    N = normals(a, c, 6.0)
    fg = relight(c, a, N, (0.2, -0.5, 0.8), 0.4, 0.3)
    fg = fg * 0.82 * np.array([0.9, 0.97, 1.08])
    L = lum(c)
    wet = blur(np.clip((L - blur(L, 4.0)) * 3, 0, 1), 0.8) * np.clip((L - 0.3) * 3, 0, 1) * a
    fg = fg + (wet * 0.16 + spec(N, a, (0.3, -0.6, 0.7), 40, np.clip((L - 0.2) * 3, 0, 1)) * 0.25)[..., None] * np.array([0.85, 0.92, 1.0])
    r = rim(a, N, 0, 1.0)
    fg = fg + r[..., None] * np.array([0.8, 0.9, 1.0]) * 0.4
    fg = micro(fg, a, 0.016)
    bg = gradient((0.06, 0.08, 0.12), (0.02, 0.03, 0.05), 0.9)
    bg = bokeh(bg, 10, [(1.0, 0.98, 0.92), (0.8, 0.9, 1.0)], 0.04, 0.08, 0.0, 0.25, 0.9, 31, 0.3)
    bg = bg + glow(0.5, -0.05, 0.7, (0.5, 0.62, 0.8), 0.5)
    bg = blur3(bg, 3)

    def streaks(n, alpha, seed, thick):
        r_ = np.random.default_rng(seed)
        m = np.zeros((S, S))
        for _ in range(n):
            x0, y0 = r_.integers(0, S), r_.integers(-40, S)
            ln = r_.integers(14, 40)
            for t in range(ln):
                x, y = int(x0 + t * 0.28), int(y0 + t)
                if 0 <= x < S and 0 <= y < S:
                    m[y, x] = max(m[y, x], r_.uniform(0.4, 1.0))
        return blur(m, thick) * alpha

    rain_b = streaks(170, 1.6, 41, 0.7)
    bg = bg + rain_b[..., None] * np.array([0.7, 0.8, 0.95]) * (0.4 + 0.8 * (1 - yy))[..., None]
    out = comp(np.clip(fg, 0, 1), a, bg)
    rain_f = streaks(45, 1.4, 43, 1.1)
    out = out + rain_f[..., None] * np.array([0.75, 0.85, 1.0]) * 0.55
    glw = blur3(np.clip(out - 0.6, 0, 1), 7) * 0.7
    out = tone(out + glw, 1.0, 0.25)
    out = vignette(out, 0.45)
    out = unsharp(out, 1.0, 0.5)
    return grain(out, 0.035, 0.3)


def o_sol(c, a):
    # 6. Treino ao sol do meio-dia: sol duro de cima à direita, sombra marcada, céu e gramado.
    N = normals(a, c, 0.5)
    Lsun = (0.55, -0.75, 0.45)
    Lv = np.array(Lsun) / np.linalg.norm(Lsun)
    sh = N @ Lv
    hard = np.clip((sh + 0.1) / 0.45, 0, 1)
    hard = hard * hard * (3 - 2 * hard)
    k = 0.66 + 0.5 * hard
    mean = (k * a).sum() / max(a.sum(), 1)
    fg = c * (1 + 0.6 * (k / mean - 1))[..., None]
    fg = fg + ((1 - hard) * a)[..., None] * np.array([-0.02, 0.0, 0.035])   # sombra azulada do céu
    fg = fg * (1 + hard[..., None] * np.array([0.04, 0.02, -0.03]))           # luz quente
    fg = fg + spec(N, a, Lsun, 22, lum(c) > 0.25)[..., None] * 0.12
    fg = saturate(fg, 1.12)
    fg = micro(fg, a, 0.016)
    bg = gradient((0.33, 0.56, 0.86), (0.62, 0.76, 0.9), 1.0)
    grass = yy > 0.66
    bg = np.where(grass[..., None], np.array([0.24, 0.5, 0.2]) * (1.1 - (yy - 0.66))[..., None], bg)
    line = np.abs(yy - 0.8) < 0.006
    bg = np.where(line[..., None], np.array([0.85, 0.9, 0.85]), bg)
    bg = bokeh(bg, 8, [(0.95, 0.95, 0.95), (0.9, 0.85, 0.3)], 0.02, 0.05, 0.58, 0.68, 0.6, 51)
    bg = blur3(bg, 6)
    fg = light_wrap(fg, a, bg, 0.12)
    out = comp(np.clip(fg, 0, 1.2), a, bg)
    out = tone(out, 1.0, 0.22)
    out = unsharp(out, 0.9, 0.6)
    return grain(out, 0.014)


OPTS = [
    ('estudio-fm', o_estudio),
    ('coletiva-de-imprensa', o_coletiva),
    ('tunel-de-acesso', o_tunel),
    ('filme-35mm', o_filme),
    ('noite-de-chuva', o_chuva),
    ('treino-ao-sol', o_sol),
]


def main():
    args = sys.argv[1:]
    out_dir = '.'
    if '--out' in args:
        i = args.index('--out')
        out_dir = args[i + 1]
        del args[i:i + 2]
    only = None
    if '--only' in args:
        i = args.index('--only')
        only = [int(x) for x in args[i + 1].split(',')]
        del args[i:i + 2]
    rows = [load_strip(args[k], args[k + 1]) for k in range(0, len(args), 2)]
    os.makedirs(out_dir, exist_ok=True)
    gap = 10
    cols = max(len(r) for r in rows)
    firsts = []
    for n, (name, fn) in enumerate(OPTS, 1):
        if only and n not in only:
            continue
        sheet = np.zeros((len(rows) * (S + gap) + gap, cols * (S + gap) + gap, 3)) + 0.08
        for r, tiles in enumerate(rows):
            for i, (c, a) in enumerate(tiles):
                o = fn(c, a)
                sheet[gap + r * (S + gap):gap + r * (S + gap) + S, gap + i * (S + gap):gap + i * (S + gap) + S] = o
                if r == 0 and i == 2:
                    firsts.append(o)
        Image.fromarray((np.clip(sheet, 0, 1) * 255).astype('uint8')).save(os.path.join(out_dir, 'r3-%d-%s.png' % (n, name)))
        print('ok', name)
    if not only:
        # Comparação: o mesmo jogador sem pós (no fundo do cartão) e nas seis opções, com o nome
        from PIL import ImageDraw, ImageFont
        c, a = rows[0][2]
        plain = comp(c, a, np.zeros((S, S, 3)) + np.array([0.11, 0.125, 0.14]))
        tiles = [plain] + firsts
        names = ['Sem pós (jogo hoje)', '1 Estúdio FM', '2 Coletiva de imprensa', '3 Túnel de acesso',
                 '4 Filme 35 mm', '5 Noite de chuva', '6 Treino ao sol']
        cmp_ = np.zeros((2 * (S + gap) + gap, 4 * (S + gap) + gap, 3)) + 0.08
        for k, o in enumerate(tiles):
            r, i = divmod(k, 4)
            cmp_[gap + r * (S + gap):gap + r * (S + gap) + S, gap + i * (S + gap):gap + i * (S + gap) + S] = o
        im = Image.fromarray((np.clip(cmp_, 0, 1) * 255).astype('uint8'))
        font_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'assets', 'fonts', 'Saira-Variable.ttf')
        try:
            font = ImageFont.truetype(font_path, 24)
            font.set_variation_by_axes([600, 100])
        except Exception:
            font = ImageFont.load_default()
        dr = ImageDraw.Draw(im, 'RGBA')
        for k, name in enumerate(names):
            r, i = divmod(k, 4)
            x, y = gap + i * (S + gap), gap + r * (S + gap) + S - 40
            dr.rectangle([x, y, x + S, y + 40], fill=(10, 12, 14, 170))
            dr.text((x + 12, y + 5), name, fill=(241, 240, 236, 255), font=font)
        im.save(os.path.join(out_dir, 'r3-comparacao.png'))
        print('ok comparacao')


if __name__ == '__main__':
    main()
