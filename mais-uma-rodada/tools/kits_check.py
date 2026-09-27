#!/usr/bin/env python3
"""Confere os uniformes reais (data/world/kits/<NAÇÃO>.json).

    python3 tools/kits_check.py            # todas as nações
    python3 tools/kits_check.py BRA ARG    # só algumas

Verifica o formato de cada uniforme, se todo clube de data/world/clubs tem os quatro uniformes
e se titular, reserva e terceiro não ficam "da mesma cor" (a mesma conta de KitDesign.clash:
cores pesadas pela área da estampa, distância CIELAB e mesma família de matiz).
Sai com código 1 se houver erro.
"""
import json
import math
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
CLUBS = os.path.join(ROOT, "data", "world", "clubs")
KITS = os.path.join(ROOT, "data", "world", "kits")

# Fração do corpo coberta por c2 e pela terceira cor (c3) em cada estampa (KitDesign.coverage).
COVERAGE = {
    "argyle": (0.41, 0.00),
    "band_low": (0.14, 0.00),
    "bottom_half": (0.45, 0.00),
    "brush": (0.26, 0.00),
    "camo": (0.29, 0.00),
    "center_panel": (0.55, 0.00),
    "center_stripe": (0.25, 0.00),
    "center_stripe_edged": (0.13, 0.23),
    "checkers": (0.50, 0.00),
    "chevron": (0.14, 0.00),
    "cross": (0.39, 0.00),
    "diagonal": (0.31, 0.00),
    "diagonal_rev": (0.31, 0.00),
    "diagonal_split": (0.43, 0.00),
    "dots": (0.15, 0.00),
    "double_band": (0.16, 0.00),
    "fade_up": (0.40, 0.00),
    "faixa": (0.16, 0.00),
    "faixa_duo": (0.09, 0.09),
    "gradient": (0.40, 0.00),
    "halftone": (0.26, 0.00),
    "halves": (0.50, 0.00),
    "harlequin": (0.90, 0.00),
    "hoop_fade": (0.40, 0.00),
    "hoops_pin": (0.23, 0.00),
    "hoops_thin": (0.32, 0.00),
    "pinstripes": (0.25, 0.00),
    "pixels": (0.20, 0.00),
    "plain": (0.00, 0.00),
    "quarters": (0.50, 0.00),
    "saltire": (0.32, 0.00),
    "sash_double": (0.20, 0.00),
    "sash_thin": (0.12, 0.00),
    "shatter": (0.03, 0.00),
    "shoulder_band": (0.09, 0.00),
    "side_panels": (0.14, 0.00),
    "stripes_h": (0.42, 0.00),
    "stripes_tri": (0.40, 0.40),
    "stripes_v": (0.50, 0.00),
    "sunburst": (0.50, 0.00),
    "tartan": (0.70, 0.00),
    "topo": (0.16, 0.00),
    "triangles": (0.49, 0.00),
    "tricolor_h": (0.32, 0.34),
    "tricolor_v": (0.35, 0.32),
    "twin_stripes": (0.23, 0.00),
    "v_big": (0.16, 0.00),
    "waves": (0.29, 0.00),
    "wide_stripes": (0.62, 0.00),
    "yoke": (0.24, 0.00),
    "zigzag": (0.29, 0.00),
}
GRADIENTS = {"gradient", "fade_up"}
COLLARS = {"round", "ringer", "wide", "v", "crossover", "henley", "laced", "polo", "retro", "mandarin", "zip"}
SLEEVES = {"same", "contrast", "cuff", "cuff_double", "tipped", "stripes", "shoulder_stripe", "raglan", "pattern"}
TRIMS = {"none", "sides", "shoulders", "both", "hem"}
SHORTS = {"plain", "side_stripe", "side_panel", "piping", "hem", "hem_double", "two_tone", "stripes3", "vent"}
SOCKS = {"plain", "hoops", "top_band", "top_stripes", "two_tone", "stripes3", "hoops_thin", "band_mid", "chevron", "foot"}
COLOR_KEYS = ["c1", "c2", "c3", "shorts", "shorts2", "socks", "socks2"]
REQUIRED = ["pattern", "c1", "c2", "shorts", "socks"]
ALLOWED = set(COLOR_KEYS) | {"pattern", "tonal", "collar", "sleeve", "sleeve_len", "trim", "shorts_style", "socks_style"}
HEX = re.compile(r"^#[0-9A-Fa-f]{6}$")
MIN_OWN = 42.0


def rgb(h):
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (1, 3, 5))


def _lin(v):
    return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4


def _f(t):
    return t ** (1.0 / 3.0) if t > 0.008856 else 7.787 * t + 16.0 / 116.0


def lab(h):
    r, g, b = (_lin(x) for x in rgb(h))
    x = (r * 0.4124 + g * 0.3576 + b * 0.1805) / 0.95047
    y = r * 0.2126 + g * 0.7152 + b * 0.0722
    z = (r * 0.0193 + g * 0.1192 + b * 0.9505) / 1.08883
    fx, fy, fz = _f(x), _f(y), _f(z)
    return (116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz))


def delta_e(a, b):
    return math.dist(lab(a), lab(b))


def swatches(k):
    c1 = k["c1"]
    c2 = k["c2"]
    c3 = k.get("c3", c2)
    shirt = 0.8
    out = []
    if k.get("tonal"):
        out.append([c1, shirt])
    else:
        pat = k.get("pattern", "plain")
        if pat in GRADIENTS:
            w2, w3 = 0.4, 0.0
        else:
            w2, w3 = COVERAGE.get(pat, (0.0, 0.0))
        if k.get("sleeve", "same") in ("contrast", "raglan"):
            w2 = min(0.9, w2 + 0.15)
        out.append([c1, shirt * max(0.1, 1.0 - w2 - w3)])
        if w2 > 0:
            out.append([c2, shirt * w2])
        if w3 > 0:
            out.append([c3, shirt * w3])
    out.append([k.get("shorts", c2), 0.2])
    tot = sum(s[1] for s in out)
    return [[s[0], s[1] / tot] for s in out]


def dominant(k):
    return max(swatches(k), key=lambda s: s[1])[0]


def distance(a, b):
    sa, sb = swatches(a), swatches(b)
    pairs = sorted((delta_e(x[0], y[0]), i, j) for i, x in enumerate(sa) for j, y in enumerate(sb))
    ra = [s[1] for s in sa]
    rb = [s[1] for s in sb]
    d = 0.0
    for de, i, j in pairs:
        f = min(ra[i], rb[j])
        if f <= 0:
            continue
        d += f * de
        ra[i] -= f
        rb[j] -= f
    return d


def same_family(a, b):
    la, lb = lab(a), lab(b)
    d = math.dist(la, lb)
    if d < 30.0:
        return True
    ca, cb = (la[1], la[2]), (lb[1], lb[2])
    if math.hypot(*ca) < 25.0 or math.hypot(*cb) < 25.0:
        return False
    ang = math.degrees(abs(math.atan2(ca[0] * cb[1] - ca[1] * cb[0], ca[0] * cb[0] + ca[1] * cb[1])))
    return ang < 22.0 and d < 60.0


def clash(a, b):
    return distance(a, b) < MIN_OWN or same_family(dominant(a), dominant(b))


def check_kit(where, k, errors):
    if not isinstance(k, dict):
        errors.append(f"{where}: não é um objeto")
        return False
    for f in REQUIRED:
        if f not in k:
            errors.append(f"{where}: falta '{f}'")
    for f in k:
        if f not in ALLOWED:
            errors.append(f"{where}: chave desconhecida '{f}'")
    for f in COLOR_KEYS:
        if f in k and not (isinstance(k[f], str) and HEX.match(k[f])):
            errors.append(f"{where}: cor inválida {f}={k[f]!r}")
    if k.get("pattern") not in COVERAGE:
        errors.append(f"{where}: estampa desconhecida {k.get('pattern')!r}")
    for f, opts in (("collar", COLLARS), ("sleeve", SLEEVES), ("trim", TRIMS), ("shorts_style", SHORTS), ("socks_style", SOCKS)):
        if f in k and k[f] not in opts:
            errors.append(f"{where}: {f} inválido {k[f]!r}")
    if "sleeve_len" in k and k["sleeve_len"] not in ("short", "long"):
        errors.append(f"{where}: sleeve_len inválido {k['sleeve_len']!r}")
    if "tonal" in k and not isinstance(k["tonal"], bool):
        errors.append(f"{where}: tonal deve ser true/false")
    return all(f in k for f in REQUIRED) and all(HEX.match(str(k.get(f, "#000000"))) for f in COLOR_KEYS if f in k) and k.get("pattern") in COVERAGE


def check_nation(code):
    errors, warnings = [], []
    clubs = json.load(open(os.path.join(CLUBS, code + ".json"), encoding="utf-8"))["clubs"]
    path = os.path.join(KITS, code + ".json")
    if not os.path.exists(path):
        return [f"{code}: falta {os.path.relpath(path, ROOT)}"], []
    data = json.load(open(path, encoding="utf-8"))
    kits = data.get("kits", {})
    keys = {c["key"]: c for c in clubs}
    for key in keys:
        if key not in kits:
            errors.append(f"{code}: {key} ({keys[key]['short']}) sem uniformes")
    for key, ks in kits.items():
        if key not in keys:
            errors.append(f"{code}: {key} não existe em clubs/{code}.json")
            continue
        name = keys[key]["short"]
        ok = True
        for w in ("h", "a", "t", "g"):
            if w not in ks:
                errors.append(f"{code}: {name}: falta '{w}'")
                ok = False
            else:
                ok = check_kit(f"{code}: {name}.{w}", ks[w], errors) and ok
        alts = ks.get("alt", [])
        if not isinstance(alts, list):
            errors.append(f"{code}: {name}: 'alt' deve ser uma lista")
            alts = []
        for i, k in enumerate(alts):
            ok = check_kit(f"{code}: {name}.alt[{i}]", k, errors) and ok
        for f in ks:
            if f not in ("h", "a", "t", "g", "alt", "note"):
                errors.append(f"{code}: {name}: chave desconhecida '{f}'")
        if not ok:
            continue
        h, a, t, g = ks["h"], ks["a"], ks["t"], ks["g"]
        for x, y, nx, ny in ((h, a, "titular", "reserva"), (h, t, "titular", "terceiro"), (a, t, "reserva", "terceiro")):
            if clash(x, y):
                errors.append(f"{code}: {name}: {nx} e {ny} parecidos demais (d={distance(x, y):.0f}, {dominant(x)} x {dominant(y)})")
        for x, nx in ((h, "titular"), (a, "reserva"), (t, "terceiro")):
            if distance(g, x) < 30.0:
                warnings.append(f"{code}: {name}: goleiro parecido com o {nx} (d={distance(g, x):.0f})")
        for i, k in enumerate(alts):
            if clash(h, k):
                errors.append(f"{code}: {name}: alt[{i}] parecido demais com o titular")
    return errors, warnings


def main():
    codes = sys.argv[1:] or sorted(f[:-5] for f in os.listdir(CLUBS) if f.endswith(".json"))
    all_e, all_w = [], []
    for code in codes:
        e, w = check_nation(code)
        all_e += e
        all_w += w
    for w in all_w:
        print("aviso:", w)
    for e in all_e:
        print("ERRO:", e)
    print(f"{len(codes)} nações, {len(all_e)} erros, {len(all_w)} avisos")
    sys.exit(1 if all_e else 0)


if __name__ == "__main__":
    main()
