"""Efeitos sonoros do jogo: interface, apito, torcida e vinhetas. Tudo sintetizado aqui."""
import numpy as np
from synth import *
from musica import Song


def norm(x, peak_=0.5):
    return x / (np.max(np.abs(x)) + 1e-9) * peak_


def room(x, rng, seconds=0.5, wet=0.15, damp=6000.0):
    st = x if x.ndim == 2 else np.array([x, x])
    pad_ = np.zeros((2, st.shape[1] + int(seconds * SR)))
    pad_[:, : st.shape[1]] = st
    out = apply_reverb(pad_, reverb_ir(rng, seconds, 0.008, damp, early=False), wet)
    return out


def trim(st, thr=0.0008):
    lvl = np.max(np.abs(st), axis=0) if st.ndim == 2 else np.abs(st)
    idx = np.nonzero(lvl > thr * np.max(lvl))[0]
    end = idx[-1] + 1 if len(idx) else len(lvl)
    st = st[..., :end].copy()
    nr = min(int(0.01 * SR), end)
    st[..., -nr:] *= np.linspace(1, 0, nr)
    return st


def cat(parts):
    return np.concatenate(parts, axis=-1)


def gap(dur, stereo=False):
    return np.zeros((2, int(dur * SR))) if stereo else np.zeros(int(dur * SR))


def place(total, sig, t0, gain=1.0, pan=0.0):
    s = int(t0 * SR)
    st = pan2(sig, pan) if sig.ndim == 1 else sig
    end = min(total.shape[1], s + st.shape[1])
    total[:, s:end] += st[:, : end - s] * gain


# ---------------------------------------------------------------------------
# Interface
# ---------------------------------------------------------------------------

def ui_click(r):
    t = tvec(0.045)
    body = sine(1850 * (1 - 0.2 * t / 0.045), len(t)) * np.exp(-t * 170)
    trans = bp(noise(len(t), r), 2500, 8000) * np.exp(-t * 1100) * 0.6
    return norm(fade(body * 0.7 + trans, 0.0005, 0.005), 0.35)


def ui_tab(r):
    t = tvec(0.06)
    x = sine(1080, len(t)) * np.exp(-t * 95) + sine(2700, len(t)) * np.exp(-t * 220) * 0.3
    x += bp(noise(len(t), r), 1500, 6000) * np.exp(-t * 900) * 0.35
    return norm(fade(x, 0.0005, 0.006), 0.3)


def ui_back(r):
    t = tvec(0.07)
    x = sine(900 * (1 - 0.28 * t / 0.07), len(t)) * np.exp(-t * 85)
    x += bp(noise(len(t), r), 1200, 5000) * np.exp(-t * 900) * 0.3
    return norm(fade(x, 0.0005, 0.006), 0.3)


def ui_toggle(r, on=True):
    a, b = (1250, 1700) if on else (1500, 1050)
    t = tvec(0.03)
    tick = lambda f: sine(f, len(t)) * np.exp(-t * 200) + bp(noise(len(t), r), 2000, 7000) * np.exp(-t * 1200) * 0.3
    return norm(fade(cat([tick(a), gap(0.035), tick(b)]), 0.0005, 0.005), 0.3)


def marimba_seq(r, notes, step=0.07, vol=0.45, kind="marimba", wet=0.12):
    total = np.zeros((2, int((step * len(notes) + 1.2) * SR)))
    for i, m in enumerate(notes):
        place(total, mallet(m, 0.6, r, 1.0, kind), i * step, 1.0 - 0.1 * i, pan=-0.2 + 0.2 * i)
    return norm(trim(room(total, r, 0.6, wet)), vol)


def pen_sign(r):
    dur = 0.42
    t = tvec(dur)
    strokes = np.zeros(len(t))
    tt = 0.0
    while tt < dur - 0.05:
        L = r.uniform(0.04, 0.09)
        m = (t >= tt) & (t < tt + L)
        strokes[m] += np.sin(np.pi * (t[m] - tt) / L) * r.uniform(0.6, 1.0)
        tt += L * r.uniform(0.7, 1.1)
    scratch = bp(noise(len(t), r), 1800, 7000) * strokes * 0.5
    scratch += bp(noise(len(t), r), 300, 900) * strokes * 0.15
    chime = marimba_seq(r, [91, 98], 0.09, 1.0, "glock", 0.25)
    total = np.zeros((2, len(t) + chime.shape[1]))
    place(total, scratch, 0.0, 0.35)
    place(total, chime, dur - 0.02, 0.6)
    return norm(trim(total), 0.5)


def achievement(r):
    s = Song(150, 3, 77, tail=8.0, loop=False)
    for i, m in enumerate([84, 88, 91, 96, 100]):
        s.note("bells", mallet, m, 0, i * 0.25, 1.5, pan=-0.4 + 0.2 * i, gain=0.9, kind="glock")
    s.chord("pad", pad, [60, 64, 67, 72], 0, 0.5, 4, gain=0.7, attack=0.15, release=1.0, bright=0.6)
    s.note("bells", bell, 96, 1, 1, 2, gain=0.5)
    return norm(s.mix({"bells": (0.8, 0.45, 0.0), "pad": (0.4, 0.5, 0.0)}, 2.0, loop=False), 0.6)


# ---------------------------------------------------------------------------
# Vinhetas de resultado
# ---------------------------------------------------------------------------

def win_jingle(r):
    s = Song(138, 3, 88, tail=8.0, loop=False)
    s.chord("brass", brass, [67, 72, 76], 0, 0, 0.4, gain=1.0, spread=0.5)
    s.chord("brass", brass, [67, 72, 76], 0, 0.5, 0.4, gain=0.9, spread=0.5)
    s.chord("brass", brass, [69, 74, 77], 0, 1.0, 0.4, gain=0.9, spread=0.5)
    s.chord("brass", brass, [72, 76, 79, 84], 0, 1.5, 2.6, gain=1.2, spread=0.6)
    s.note("bass", sub_bass, 36, 0, 1.5, 2.5, gain=0.8)
    for k in range(6):
        s.hit("drums", snare(r, 0.2, 220), 0, k * 0.25, gain=0.2 + 0.1 * k)
    s.hit("kick", kick(r), 0, 1.5)
    s.hit("cym", crash(r, 2.5), 0, 1.5, pan=0.2)
    s.note("bells", mallet, 96, 0, 1.5, 2, kind="glock", gain=0.6)
    return norm(s.mix({"brass": (0.8, 0.3, 0.0), "bass": (0.6, 0.0, 0.0), "drums": (0.5, 0.25, 0.0), "kick": (0.7, 0.1, 0.0),
                       "cym": (0.35, 0.3, 0.0), "bells": (0.4, 0.4, 0.0)}, 1.8, loop=False), 0.7)


def lose_jingle(r):
    s = Song(80, 3, 99, tail=8.0, loop=False)
    for i, (m, b) in enumerate([(76, 0), (72, 0.5), (69, 1.0), (64, 1.5)]):
        s.note("keys", epiano, m, 0, b, 1.6 - 0.2 * i, gain=0.9, bright=0.6)
    s.chord("pad", strings, [53, 57, 60, 64], 0, 1.5, 3.0, gain=0.8, attack=0.4, bright=0.35)
    s.note("bass", sub_bass, 41, 0, 1.5, 3.0, gain=0.5)
    return norm(s.mix({"keys": (0.8, 0.35, 0.0), "pad": (0.5, 0.45, 0.0), "bass": (0.5, 0.0, 0.0)}, 2.2, loop=False), 0.55)


def title_fanfare(r):
    s = Song(116, 4, 111, tail=8.0, loop=False)
    # rufar do tímpano (crescendo)
    for k in range(16):
        s.hit("perc", timpani(r, 49.0, 0.6, 0.35 + 0.65 * k / 15), 0, k * 0.25, pan=-0.1)
    for k in range(16):
        s.hit("drums", snare(r, 0.15, 220, 0.8), 0, k * 0.25, gain=0.1 + 0.35 * k / 15, pan=0.1)
    s.hit("kick", kick(r, 1.2), 1, 0)
    s.hit("perc", timpani(r, 65.4, 2.5, 1.0), 1, 0)
    s.hit("cym", crash(r, 3.5, 1.0), 1, 0, pan=-0.3)
    s.hit("cym", crash(r, 3.5, 0.8), 1, 0, pan=0.3)
    mel = [(1, 0, 67, .5), (1, .5, 72, .5), (1, 1, 76, .5), (1, 1.5, 79, 1.5), (1, 3, 76, .5), (1, 3.5, 79, .5), (2, 0, 84, 3.0)]
    for bar, b, m, l in mel:
        s.chord("brass", brass, [m, m - 12], bar, b, l, gain=1.0, spread=0.3, bright=1.1)
    s.chord("brass", brass, [60, 64, 67], 1, 0, 1.4, gain=0.7)
    s.chord("brass", brass, [65, 69, 72], 1, 2, 0.9, gain=0.6)
    s.chord("brass", brass, [60, 64, 67, 72], 2, 0, 3.0, gain=0.8)
    s.chord("pad", strings, [60, 64, 67, 72, 76], 1, 0, 8, gain=1.0, attack=0.2, bright=0.7)
    s.note("bass", sub_bass, 36, 1, 0, 8, gain=0.7)
    s.hit("kick", kick(r, 1.2), 2, 0)
    s.hit("perc", timpani(r, 65.4, 2.5, 0.9), 2, 0)
    s.hit("cym", crash(r, 3.5, 0.9), 2, 0)
    for i, m in enumerate([84, 88, 91, 96, 100, 103]):
        s.note("bells", mallet, m, 2, 0.25 + i * 0.25, 1.5, kind="glock", pan=-0.5 + 0.2 * i, gain=0.6)
    return norm(s.mix({"perc": (0.8, 0.3, 0.0), "drums": (0.45, 0.25, 0.0), "kick": (0.7, 0.1, 0.0), "cym": (0.35, 0.3, 0.0),
                       "brass": (0.75, 0.35, 0.0), "pad": (0.45, 0.45, 0.0), "bass": (0.5, 0.0, 0.0), "bells": (0.4, 0.45, 0.0)},
                      2.5, loop=False), 0.75)


# ---------------------------------------------------------------------------
# Apito do árbitro
# ---------------------------------------------------------------------------

def stadium(x, r, wet=0.12):
    """Apito num estádio: eco curto da arquibancada e cauda de ar livre."""
    n = len(x)
    y = np.zeros(n + int(0.9 * SR))
    y[:n] += x
    d = int(0.21 * SR)
    y[d:d + n] += lp(x, 4500) * 0.12
    st = np.array([y, y])
    return trim(apply_reverb(st, reverb_ir(r, 0.9, 0.01, 5000, early=False), wet))


def whistle_seq(r, blasts, vol=0.5):
    parts = []
    for i, (dur, pause) in enumerate(blasts):
        parts.append(ref_whistle(dur, r))
        if pause:
            parts.append(gap(pause))
    return norm(stadium(cat(parts), r), vol)


# ---------------------------------------------------------------------------
# Torcida
# ---------------------------------------------------------------------------

def crowd_whistles(dur, r, count, t_lo=0.0, t_hi=None):
    n = int(dur * SR)
    out = np.zeros((2, n))
    t_hi = dur - 0.8 if t_hi is None else t_hi
    for _ in range(count):
        L = r.uniform(0.25, 0.8)
        tt = tvec(L)
        f0 = r.uniform(2100, 3300)
        curve = f0 * (1 + r.uniform(-0.15, 0.2) * (tt / L)) * (1 + 0.01 * np.sin(2 * np.pi * 6 * tt))
        w = sine(curve, len(tt)) * np.sin(np.pi * tt / L) ** 0.5 + bp(noise(len(tt), r), f0 * 0.8, f0 * 1.3) * 0.1
        place(out, w * r.uniform(0.1, 0.3), r.uniform(t_lo, t_hi), pan=r.uniform(-0.9, 0.9))
    return out


def roar_noise(dur, r, lo=250, hi=3500):
    n = int(dur * SR)
    return np.array([bp(pink(n, r), lo, hi) for _ in range(2)])


def goal_roar(r, dur=5.5, size=1.0, horns=False):
    n = int(dur * SR)
    t = np.arange(n) / SR
    shout = lambda tt: 1.0 + 0.35 * np.clip(tt / 0.25, 0, 1) - 0.12 * np.clip((tt - 1.5) / 3.0, 0, 1) + 0.04 * np.sin(2 * np.pi * 1.2 * tt)
    env = lambda tt: np.clip(tt / 0.18, 0, 1) * (0.35 + 0.65 * np.exp(-np.clip(tt - 1.6, 0, None) / 1.6)) * np.clip((dur - tt) / 0.8, 0, 1)
    a = voices(dur, r, int(70 * size), 120, 190, "a", shout, env, onset=0.25, breath=0.35, female=0.3)
    e = voices(dur, r, int(45 * size), 130, 210, "eh", shout, env, onset=0.35, breath=0.3, female=0.35)
    nz = roar_noise(dur, r) * env(t)
    nz /= np.max(np.abs(nz)) + 1e-9
    total = a * 0.55 + e * 0.4 + nz * 0.55
    total += crowd_whistles(dur, r, int(10 * size), 0.3, dur - 1.0) * 0.6
    cl = claps(dur, r, int(90 * size), (4.0, 6.5), lambda tt: np.clip((tt - 1.2) / 1.0, 0, 1) * np.clip((dur - tt) / 1.5, 0, 1))
    total += cl * 0.3
    if horns:
        for k in range(3):
            hn = brass(46 + [0, 7, 4][k], r.uniform(0.6, 1.2), r, 1.0, 0.8)
            place(total, hn, 0.4 + k * 0.9 + r.uniform(0, 0.2), 0.5, pan=r.uniform(-0.6, 0.6))
    total = apply_reverb(total, reverb_ir(r, 1.6, 0.02, 4500), 0.25)
    return norm(trim(total), 0.7)


def ooh(r, dur=2.4):
    def pitch(tt):
        return 0.92 + 0.3 * np.clip(tt / 0.45, 0, 1) - 0.42 * np.clip((tt - 0.6) / 1.6, 0, 1)
    env = lambda tt: np.clip(tt / 0.3, 0, 1) ** 1.5 * np.exp(-np.clip(tt - 0.7, 0, None) / 0.7) * np.clip((dur - tt) / 0.4, 0, 1)
    u = voices(dur, r, 70, 115, 175, "u", pitch, env, onset=0.18, breath=0.25, female=0.3)
    o = voices(dur, r, 50, 115, 175, "o", pitch, env, onset=0.25, breath=0.25, female=0.3)
    x = (u * 0.6 + o * 0.5)
    t = np.arange(x.shape[1]) / SR
    x += roar_noise(dur, r, 200, 1500) * (env(t) * 0.25)
    x = apply_reverb(x, reverb_ir(r, 1.4, 0.02, 4000), 0.25)
    return norm(trim(x), 0.6)


def groan(r, dur=1.8):
    pitch = lambda tt: 1.15 - 0.4 * np.clip(tt / dur, 0, 1)
    env = lambda tt: np.clip(tt / 0.12, 0, 1) * np.exp(-tt / 0.8)
    a = voices(dur, r, 60, 110, 165, "a", pitch, env, onset=0.12, breath=0.3, female=0.25)
    o = voices(dur, r, 40, 110, 165, "o", pitch, env, onset=0.15, breath=0.3, female=0.25)
    x = apply_reverb(a * 0.5 + o * 0.6, reverb_ir(r, 1.3, 0.02, 4000), 0.25)
    return norm(trim(x), 0.5)


def boo(r, dur=2.4):
    pitch = lambda tt: 1.0 - 0.1 * np.clip(tt / dur, 0, 1) + 0.03 * np.sin(2 * np.pi * 0.8 * tt)
    env = lambda tt: np.clip(tt / 0.35, 0, 1) * np.clip((dur - tt) / 0.7, 0, 1)
    u = voices(dur, r, 80, 90, 140, "u", pitch, env, onset=0.35, breath=0.3, female=0.2)
    x = u + crowd_whistles(dur, r, 14, 0.1, dur - 0.9) * 1.2
    x = apply_reverb(x, reverb_ir(r, 1.4, 0.02, 4000), 0.25)
    return norm(trim(x), 0.55)


def applause(r, dur=2.8):
    env = lambda tt: np.clip(tt / 0.25, 0, 1) * np.clip((dur - tt) / 1.4, 0, 1) ** 1.2
    x = claps(dur, r, 150, (3.5, 6.0), env)
    t = np.arange(x.shape[1]) / SR
    x += voices(dur, r, 30, 130, 200, "eh", None, env, 0.3, 0.3, 0.3) * 0.12
    x = apply_reverb(x, reverb_ir(r, 1.2, 0.02, 5000), 0.2)
    return norm(trim(x), 0.5)


def post_clang(r):
    t = tvec(1.3)
    f = 487.0
    parts = [(1.0, 1.0, 3.0), (2.76, 0.6, 5.0), (5.40, 0.35, 8.0), (8.93, 0.2, 12.0), (13.3, 0.08, 18.0)]
    x = sum(a * sine(f * k, len(t)) * np.exp(-t * d) for k, a, d in parts)
    x += lp(noise(len(t), r), 1500) * np.exp(-t * 60) * 0.6  # a pancada da bola
    x = stadium(x * np.minimum(1, t / 0.0008), r, 0.15)
    return norm(x, 0.5)


def build(rng_seed=7):
    r = np.random.default_rng(rng_seed)
    out = {}
    out["click"] = ui_click(r)
    out["tab"] = ui_tab(r)
    out["back"] = ui_back(r)
    out["toggle_on"] = ui_toggle(r, True)
    out["toggle_off"] = ui_toggle(r, False)
    out["notify"] = marimba_seq(r, [88, 93], 0.075, 0.35)
    out["notify_good"] = marimba_seq(r, [84, 88, 91, 96], 0.06, 0.4)
    out["notify_bad"] = marimba_seq(r, [76, 72], 0.1, 0.32)
    out["sign"] = pen_sign(r)
    out["achievement"] = achievement(r)
    out["win"] = win_jingle(r)
    out["lose"] = lose_jingle(r)
    out["title"] = title_fanfare(r)
    out["whistle"] = whistle_seq(r, [(0.55, 0)], 0.5)
    out["card"] = whistle_seq(r, [(0.24, 0)], 0.5)
    out["whistle_half"] = whistle_seq(r, [(0.32, 0.14), (0.8, 0)], 0.5)
    out["whistle_end"] = whistle_seq(r, [(0.3, 0.13), (0.3, 0.13), (1.05, 0)], 0.5)
    out["chance"] = ooh(r)
    out["groan"] = groan(r)
    out["boo"] = boo(r)
    out["applause"] = applause(r)
    out["post"] = post_clang(r)
    out["goal_roar"] = goal_roar(r, 5.5, 1.0)
    out["goal"] = goal_roar(r, 4.0, 0.7)
    out["goal_big"] = goal_roar(r, 6.0, 1.2, horns=True)
    return out
