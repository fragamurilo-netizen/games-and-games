#!/usr/bin/env python3
"""Gera o kit de rostos 3D (assets/face3d/) a partir dos dados CC0 do MakeHuman.

Uso: MH_DATA=/caminho/makehuman-data-v1/package python3 tools/face3d/build_face3d.py [saida]
  (npm pack makehuman-data-v1 ; tar xzf ... ; pip install numpy pillow)

Saída (tudo pequeno, lido em runtime por scripts/ui/face3d/face3d_kit.gd):
  body.bin    busto (cabeça, pescoço e ombros) + alvos esparsos (etnia, idade, peso e ~120 traços)
  <proxy>.bin cabelos, barbas, sobrancelhas, cílios, olhos e camisa, presos à malha pelos
              vértices de referência do MakeHuman (acompanham qualquer formato de cabeça)
  tex/*.png   peles, cabelos, olhos; posmap.png (posição 3D de cada texel da pele, para pintar
              barba rala, costeletas e cabelo raspado no shader)

Formato .bin: 'F3D1', u32 tamanho do JSON, JSON (metadados), depois os blocos binários na ordem
listada em meta["blocks"] (cada um com nome, tipo f32/i32 e tamanho)."""
import json, os, struct, sys
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from mhload import D, load_base, load_json, parse_faces, target, has_target

OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "../../assets/face3d")
os.makedirs(OUT + "/tex", exist_ok=True)
M = 0.1  # decímetros -> metros
CUT_Y = 4.9  # corte do busto (altura, na pose padrão)

d, V0, UV, FACES = load_base()


def mix(age):
    return sum(target(f"{r}-male-{age}") for r in ("african", "asian", "caucasian")) / 3.0


UNI = "universal-male-%s-%s-%s"
base_macro = target(UNI % ("young", "averagemuscle", "averageweight")) + mix("young")
V = V0 + base_macro  # homem jovem, porte médio, mistura das três etnias de referência

body_faces = [f for f in FACES if f[1] == 0]
head_faces = [f for f in body_faces if V[f[0], 1].min() > CUT_Y and np.abs(V[f[0], 0]).max() < 2.35]
head_verts = np.unique(np.concatenate([f[0] for f in head_faces]))
skull = head_verts[V[head_verts, 1] > 7.3]

# --- Alvos -----------------------------------------------------------------------------------
shapes = {}


def norm_macro(delta):
    """Tira a translação da cabeça (a câmera enquadra o rosto, não a altura da pessoa)."""
    return delta - delta[skull].mean(0)


shapes["eth_eur"] = norm_macro(target("caucasian-male-young") - mix("young"))
shapes["eth_afr"] = norm_macro(target("african-male-young") - mix("young"))
shapes["eth_asi"] = norm_macro(target("asian-male-young") - mix("young"))
shapes["age_old"] = norm_macro(target(UNI % ("old", "averagemuscle", "averageweight")) + mix("old") - base_macro)
shapes["age_child"] = norm_macro(target(UNI % ("child", "averagemuscle", "averageweight")) + mix("child") - base_macro)
shapes["fat"] = norm_macro(target(UNI % ("young", "averagemuscle", "maxweight")) - target(UNI % ("young", "averagemuscle", "averageweight")))
shapes["thin"] = norm_macro(target(UNI % ("young", "averagemuscle", "minweight")) - target(UNI % ("young", "averagemuscle", "averageweight")))
shapes["muscle"] = norm_macro(target(UNI % ("young", "maxmuscle", "averageweight")) - target(UNI % ("young", "averagemuscle", "averageweight")))

FACE = {
    "head": ["head-oval", "head-round", "head-square", "head-rectangular", "head-triangular", "head-invertedtriangular",
             "head-diamond", "head-fat", "head-skinny", "head-scale-horiz-less", "head-scale-horiz-more",
             "head-scale-vert-less", "head-scale-vert-more", "head-scale-depth-less", "head-scale-depth-more",
             "head-back-scale-depth-less", "head-back-scale-depth-more", "head-age-less", "head-age-more"],
    "forehead": ["forehead-scale-vert-less", "forehead-scale-vert-more", "forehead-trans-depth-forward",
                 "forehead-trans-depth-backward", "forehead-temple-in", "forehead-temple-out", "forehead-nubian-more"],
    "eyebrows": ["eyebrows-trans-depth-less", "eyebrows-trans-depth-more", "eyebrows-angle-up", "eyebrows-angle-down",
                 "eyebrows-trans-vert-less", "eyebrows-trans-vert-more"],
    "eyes": ["eye-size-small", "eye-size-big", "eye-move-in", "eye-move-out", "eye-move-down", "eye-move-up",
             "eye-height2-min", "eye-height2-max", "eye-epicanthus-in", "eye-epicanthus-out", "eye-corner1-down",
             "eye-corner1-up", "eye-corner2-down", "eye-corner2-up", "eye-bag-max", "eye-eyefold-down", "eye-eyefold-up",
             "eye-push1-in", "eye-push1-out", "eye-push2-in", "eye-push2-out", "eye-height1-min", "eye-height1-max",
             "eye-height3-min", "eye-height3-max", "eye-bag-min", "eye-bag-in", "eye-bag-out", "eye-bag-height-min",
             "eye-bag-height-max", "eye-eyefold-angle-up", "eye-eyefold-angle-down", "eye-eyefold-concave",
             "eye-eyefold-convex"],
    "nose": ["nose-scale-horiz-decr", "nose-scale-horiz-incr", "nose-scale-vert-decr", "nose-scale-vert-incr",
             "nose-scale-depth-decr", "nose-scale-depth-incr", "nose-nostril-width-min", "nose-nostril-width-max",
             "nose-point-width-less", "nose-point-width-more", "nose-hump-lesshump", "nose-hump-morehump",
             "nose-greek-moregreek", "nose-volume-potato", "nose-volume-point", "nose-point-up", "nose-point-down",
             "nose-width1-min", "nose-width1-max", "nose-width2-min", "nose-width2-max", "nose-compression-compress",
             "nose-flaring-incr", "nose-trans-vert-down", "nose-trans-vert-up", "nose-curve-concave",
             "nose-curve-convex", "nose-trans-depth-forward", "nose-trans-depth-backward", "nose-septumangle-decr",
             "nose-septumangle-incr", "nose-nostrils-angle-up", "nose-nostrils-angle-down", "nose-width3-min", "nose-width3-max",
             "nose-compression-uncompress", "nose-greek-lessgreek", "nose-height-min", "nose-height-max", "nose-flaring-decr"],
    "mouth": ["mouth-scale-horiz-decr", "mouth-scale-horiz-incr", "mouth-lowerlip-volume-deflate",
              "mouth-lowerlip-volume-inflate", "mouth-upperlip-volume-deflate", "mouth-upperlip-volume-inflate",
              "mouth-angles-down", "mouth-angles-up", "mouth-trans-down", "mouth-trans-up", "mouth-trans-backward",
              "mouth-trans-forward", "mouth-cupidsbow-decr", "mouth-cupidsbow-incr", "mouth-lowerlip-height-min",
              "mouth-lowerlip-height-max", "mouth-upperlip-height-min", "mouth-upperlip-height-max",
              "mouth-laugh-lines-out", "mouth-dimples-in", "mouth-dimples-out", "mouth-philtrum-volume-increase",
              "mouth-philtrum-volume-decrease", "mouth-scale-vert-incr", "mouth-scale-vert-decr", "mouth-scale-depth-incr",
              "mouth-scale-depth-decr", "mouth-upperlip-width-min", "mouth-upperlip-width-max", "mouth-lowerlip-width-min",
              "mouth-lowerlip-width-max", "mouth-lowerlip-ext-up", "mouth-lowerlip-ext-down", "mouth-upperlip-ext-up",
              "mouth-upperlip-ext-down", "mouth-lowerlip-middle-up", "mouth-lowerlip-middle-down", "mouth-upperlip-middle-up",
              "mouth-upperlip-middle-down", "mouth-cupidsbow-width-min", "mouth-cupidsbow-width-max"],
    "ears": ["ear-size-small", "ear-size-big", "ear-wing-out", "ear-wing-in", "ear-lobe-min", "ear-lobe-max",
             "ear-flap-out", "ear-flap-in", "ear-trans-vert-down", "ear-trans-vert-up", "ear-height-min", "ear-height-max",
             "ear-width-min", "ear-width-max", "ear-shape1-pointed", "ear-shape1-triangle", "ear-shape2-square",
             "ear-shape2-round", "ear-rot-backward", "ear-rot-forward", "ear-trans-depth-backward", "ear-trans-depth-forward"],
    "chin": ["chin-width-min", "chin-width-max", "chin-height-min", "chin-height-max", "chin-prominent-less",
             "chin-prominent-more", "chin-cleft-out", "chin-bones-in", "chin-bones-out", "chin-jaw-drop-less",
             "chin-jaw-drop-more", "chin-prognathism-less", "chin-prognathism-more"],
    "cheek": ["cheek-bones-in", "cheek-bones-out", "cheek-volume-deflate", "cheek-volume-inflate",
              "cheek-inner-deflate", "cheek-inner-inflate", "cheek-trans-vert-down", "cheek-trans-vert-up"],
    "neck": ["neck-scale-vert-less", "neck-scale-vert-more", "neck-back-scale-depth-more", "neck-scale-horiz-less", "neck-scale-horiz-more", "neck-scale-depth-less", "neck-scale-depth-more",
             "neck-double-more"],
}
# Assimetria (um lado só): ninguém é simétrico
ASYM = ["l-eye-size-big", "l-eye-size-small", "l-eye-move-up", "l-eye-move-down", "l-eye-height2-max", "l-eye-height2-min",
        "l-ear-size-big", "l-ear-wing-out", "l-cheek-bones-out", "l-cheek-volume-inflate", "l-eye-corner1-up",
        "r-eye-size-big", "r-eye-move-up", "r-ear-wing-out", "r-cheek-bones-out", "r-eye-height2-max",
        "nose-trans-in", "nose-trans-out", "l-eyebrows?"]
for n in ASYM:
    if has_target(n):
        shapes["a:" + n] = target(n)
for grp, names in FACE.items():
    for n in names:
        if has_target(n):
            shapes[n] = target(n)
        elif has_target("l-" + n) and has_target("r-" + n):
            shapes[n] = target("l-" + n) + target("r-" + n)
        else:
            print("sem alvo:", n)

# --- Proxies -------------------------------------------------------------------------------
PROXIES = {
    # só o que o rosto 3D usa (cabelo, barba e sobrancelhas são procedurais: Face3DHair)
    "eyes": "eyes/HighPolyEyes", "lashes": "eyelashes/Eyelashes01", "shirt": "clothes/short_tail_camo_tee",
}

proxy_data = {}
ref_union = set()
for key, rel in PROXIES.items():
    name = rel.split("/")[1]
    p = load_json(f"public/data/proxies/{rel}/{name}.json")
    ref = np.array(p["ref_vIdxs"], dtype=np.int64).reshape(-1, 3)
    w = np.array(p["weights"], dtype=np.float64).reshape(-1, 3)
    off = np.array(p["offsets"], dtype=np.float64).reshape(-1, 3)
    pf = parse_faces(p["faces"])
    puv = np.array(p["uvs"][0], dtype=np.float64).reshape(-1, 2)
    mat = p["materials"][0]
    proxy_data[key] = (rel, ref, w, off, pf, puv, mat)
    ref_union.update(ref.flatten().tolist())

keep = np.array(sorted(set(head_verts.tolist()) | ref_union), dtype=np.int64)
remap = -np.ones(len(V), dtype=np.int64)
remap[keep] = np.arange(len(keep))
print("vértices mantidos", len(keep), "busto", len(head_verts))


def write_bin(path, meta, blocks):
    meta = dict(meta)
    meta["blocks"] = [[n, t, int(a.size)] for n, t, a in blocks]
    js = json.dumps(meta, separators=(",", ":")).encode()
    with open(path, "wb") as fo:
        fo.write(b"F3D1" + struct.pack("<I", len(js)) + js)
        for n, t, a in blocks:
            fo.write(np.ascontiguousarray(a, dtype=np.float32 if t == "f32" else np.int32).tobytes())


def split_mesh(faces, nverts_uv_src):
    """Faces quad com uv por canto -> vértices únicos (pos, uv) e triângulos."""
    key_to_i = {}
    vpos, vuv, tris = [], [], []
    for vs, _m, uv in faces:
        ids = []
        for k in range(len(vs)):
            kk = (vs[k], uv[k] if uv is not None else -1)
            if kk not in key_to_i:
                key_to_i[kk] = len(vpos)
                vpos.append(kk[0])
                vuv.append(kk[1])
            ids.append(key_to_i[kk])
        if len(ids) == 4:
            if ids[2] == ids[3]:
                tris += [ids[0], ids[1], ids[2]]
            else:
                tris += [ids[0], ids[1], ids[2], ids[0], ids[2], ids[3]]
        else:
            tris += ids
    return np.array(vpos), np.array(vuv), np.array(tris, dtype=np.int64)


# --- body.bin ----------------------------------------------------------------------------
vpos, vuv, tris = split_mesh(head_faces, None)
uvs = UV[vuv].copy()
uvs[:, 1] = 1.0 - uvs[:, 1]
blocks = [("pos", "f32", (V[keep] * M).flatten()), ("uv", "f32", uvs.flatten()),
          ("orig", "i32", remap[vpos]), ("idx", "i32", tris)]
shape_meta = []
for n, delta in shapes.items():
    dk = delta[keep] * M
    mag = np.abs(dk).max(1)
    nz = np.nonzero(mag > 2e-5)[0]
    if len(nz) == 0:
        print("alvo vazio:", n)
        continue
    shape_meta.append(n)
    blocks.append(("s:" + n + ":i", "i32", nz))
    blocks.append(("s:" + n + ":d", "f32", dk[nz].flatten()))
write_bin(OUT + "/body.bin", {"n": int(len(keep)), "shapes": shape_meta, "tex_skin": True}, blocks)
print("body.bin", os.path.getsize(OUT + "/body.bin") // 1024, "KB", len(shape_meta), "alvos")

# --- proxies -------------------------------------------------------------------------------
tex_used = {}
for key, (rel, ref, w, off, pf, puv, mat) in proxy_data.items():
    faces = pf
    if key == "shirt":  # só o que aparece no busto
        fit = (V[ref] * w[..., None]).sum(1) + off
        faces = [f for f in pf if fit[f[0], 1].min() > CUT_Y - 0.4]
    ppos, puvi, ptris = split_mesh(faces, None)
    pu = puv[puvi].copy()
    pu[:, 1] = 1.0 - pu[:, 1]
    used = np.unique(ppos)
    loc = -np.ones(len(ref), dtype=np.int64)
    loc[used] = np.arange(len(used))
    tex = mat.get("mapDiffuse", "")
    meta = {"src": rel, "tex": ""}
    if tex:
        src = f"{D}public/data/proxies/{rel}/{tex}"
        tname = key + ".png"
        im = Image.open(src).convert("RGBA")
        im.save(OUT + "/tex/" + tname, optimize=True)
        a = np.asarray(im, dtype=np.float64) / 255.0
        sel = a[..., 3] > 0.5
        meta["tex"] = tname
        meta["avg"] = a[sel][:, :3].mean(0).round(4).tolist() if sel.any() else [0.5, 0.5, 0.5]
    extra = []
    if key == "shirt":  # distância até a gola (arestas de borda no alto da camisa), para o friso
        from collections import Counter
        fit = (V[ref] * w[..., None]).sum(1) + off
        ec = Counter()
        for vs, _m, _uv in faces:
            for k in range(len(vs)):
                a, b = vs[k], vs[(k + 1) % len(vs)]
                if a != b:
                    ec[(min(a, b), max(a, b))] += 1
        border = set()
        top = max(fit[a, 1] for (a, b), c in ec.items() if c == 1)
        for (a, b), c in ec.items():
            if c == 1 and fit[a, 1] > top - 0.9 and fit[b, 1] > top - 0.9:
                border.update((a, b))
        bp_ = fit[sorted(border)]
        dist = np.array([np.linalg.norm(bp_ - fit[i], axis=1).min() for i in used]) * M
        extra = [("dist", "f32", dist)]
    blocks = [("ref", "i32", remap[ref[used]].flatten()), ("w", "f32", w[used].flatten()),
              ("off", "f32", (off[used] * M).flatten()), ("vloc", "i32", loc[ppos]), ("uv", "f32", pu.flatten()),
              ("idx", "i32", ptris)] + extra
    assert (remap[ref[used]] >= 0).all()
    write_bin(f"{OUT}/{key}.bin", meta, blocks)
print("proxies ok")

# --- raízes dos fios (couro cabeludo, barba, sobrancelhas) --------------------------------
def sample_roots(pred, count, seed):
    tri_v, tri_area = [], []
    for vs, _m, _uv in head_faces:
        for t in ([(0, 1, 2), (0, 2, 3)] if len(vs) == 4 else [(0, 1, 2)]):
            ids = [vs[t[0]], vs[t[1]], vs[t[2]]]
            P = V[ids]
            cen = P.mean(0)
            if not pred(cen):
                continue
            tri_v.append(ids)
            tri_area.append(0.5 * np.linalg.norm(np.cross(P[1] - P[0], P[2] - P[0])))
    tri_v = np.array(tri_v)
    pa = np.array(tri_area)
    r = np.random.default_rng(seed)
    pick = r.choice(len(tri_v), size=count, p=pa / pa.sum())
    u = r.random(count)
    v = r.random(count)
    flip = u + v > 1
    u[flip] = 1 - u[flip]
    v[flip] = 1 - v[flip]
    ids = tri_v[pick]
    P = V[ids[:, 0]] * (1 - u - v)[:, None] + V[ids[:, 1]] * u[:, None] + V[ids[:, 2]] * v[:, None]
    # ordena de trás para frente (fios da frente desenhados por último ajudam no alfa)
    order = np.argsort(P[:, 2])
    return remap[ids[order]], np.stack([u, v], 1)[order], P[order]


def is_scalp(c):
    x, y, z = c
    ax = abs(x)
    if y < 6.9:
        return False
    face = z > 0.45 and y < 8.62 and ax < 0.66
    ear = ax > 0.6 and ((y - 7.58) / 0.5) ** 2 + ((z - 0.45) / 0.42) ** 2 < 1.0
    return not face and not ear


def is_beard(c):
    x, y, z = c
    ax = abs(x)
    if y < 6.3 or y > 8.15 or z < -0.15 or ax > 0.86:
        return False
    if y > 7.72 and ax < 0.5 and z > 1.0:  # olhos e nariz
        return False
    return True


def is_brow(c):
    x, y, z = c
    ax = abs(x)
    return 0.03 < ax < 0.8 and 7.95 < y < 8.5 and z > 0.75


for name, pred, cnt, sd in (("roots_scalp", is_scalp, 9000, 1), ("roots_beard", is_beard, 7000, 2), ("roots_brow", is_brow, 10000, 3)):
    ids, bc, P = sample_roots(pred, cnt, sd)
    write_bin(f"{OUT}/{name}.bin", {"n": int(cnt)}, [("ids", "i32", ids.flatten()), ("bc", "f32", bc.flatten()), ("p", "f32", P.flatten())])
    print(name, cnt)

# elipsoide do crânio (colisão dos fios): a x² + b (y-cy)² + c (z-cz)² = 1 ajustado no domo
dome = head_verts[(V[head_verts, 1] > 7.95)]
Pd = V[dome]
A = np.stack([Pd[:, 0] ** 2, Pd[:, 1] ** 2, Pd[:, 2] ** 2, Pd[:, 1], Pd[:, 2]], 1)
coef = np.linalg.lstsq(A, np.ones(len(Pd)), rcond=None)[0]
ca, cb, cc, cd, ce = coef
cy = -cd / (2 * cb)
cz = -ce / (2 * cc)
k = 1 + cb * cy * cy + cc * cz * cz
ellip = {"c": [0.0, cy * M, cz * M], "r": [float(np.sqrt(k / ca)) * M, float(np.sqrt(k / cb)) * M, float(np.sqrt(k / cc)) * M]}
print("elipsoide", ellip)

# --- peles e cor média do rosto (para ajustar o tom exato no shader) -------------------------
SKINS = {"light": "young_caucasian_male/textures/young_lightskinned_male_diffuse.png",
}
# máscara do rosto no UV (bochechas/testa) para medir a cor média
face_uv = np.concatenate([UV[f[2]] for f in head_faces if V[f[0], 1].min() > 7.4 and V[f[0], 2].min() > 0.6])
avg = {}
for k, rel in SKINS.items():
    im = Image.open(f"{D}public/data/skins/{rel}").convert("RGB")
    a = np.asarray(im, dtype=np.float64) / 255.0
    h, wdt = a.shape[:2]
    px = a[((1.0 - face_uv[:, 1]) * (h - 1)).astype(int), (face_uv[:, 0] * (wdt - 1)).astype(int)]
    avg[k] = px.mean(0).round(4).tolist()
    im.save(OUT + f"/tex/skin_{k}.png", optimize=True)

# íris (esclera da textura do MakeHuman)
for c in ("brown",):
    Image.open(f"{D}public/data/proxies/eyes/HighPolyEyes/textures/{c}_eye.png").save(OUT + f"/tex/eye_{c}.png", optimize=True)

info = {"skin_avg": avg,
        "skull": ellip, "license": "MakeHuman assets (CC0) — makehuman.org"}
json.dump(info, open(OUT + "/face3d.json", "w"), indent=1)
print("ok", OUT)
