"""Leitura dos dados do MakeHuman (pacote npm makehuman-data-v1: malha base, alvos e proxies).
Os recursos gráficos do MakeHuman (malha, alvos, peles e proxies do sistema) são CC0.
Pasta do pacote extraído em $MH_DATA (a que tem public/ e src/)."""
import json, os
import numpy as np

D = os.environ.get("MH_DATA", "mh/package").rstrip("/") + "/"


def parse_faces(F):
    """Faces no formato JSON 3.1 do three.js -> [(vértices, material, uvs)]."""
    i = 0
    out = []
    while i < len(F):
        t = F[i]
        i += 1
        n = 4 if t & 1 else 3
        vs = F[i:i + n]
        i += n
        m = 0
        if t & 2:
            m = F[i]
            i += 1
        if t & 4:
            i += 1
        uv = None
        if t & 8:
            uv = F[i:i + n]
            i += n
        if t & 16:
            i += 1
        if t & 32:
            i += n
        if t & 64:
            i += 1
        if t & 128:
            i += n
        out.append((vs, m, uv))
    return out


def load_json(rel):
    return json.load(open(D + rel))


def load_base():
    d = load_json("public/data/models/human_full_size.json")
    V = np.array(d["vertices"], dtype=np.float64).reshape(-1, 3) * d.get("scale", 1.0)
    UV = np.array(d["uvs"][0], dtype=np.float64).reshape(-1, 2)
    return d, V, UV, parse_faces(d["faces"])


_T = None
_names = None


def targets():
    global _T, _names
    if _T is None:
        t = load_json("src/json/targets/target-list.json")["targets"]
        _names = sorted(t.keys())
        _T = np.memmap(D + "public/data/targets/targets.bin", dtype=np.int16, mode="r", shape=(len(_names), 57474))
    return _T, _names


def target(name):
    T, names = targets()
    k = [i for i, n in enumerate(names) if n.endswith("/" + name + ".target")]
    assert len(k) == 1, (name, [names[i] for i in k][:5])
    return np.asarray(T[k[0]], dtype=np.float64).reshape(-1, 3) * 1e-3


def has_target(name):
    _, names = targets()
    return any(n.endswith("/" + name + ".target") for n in names)
