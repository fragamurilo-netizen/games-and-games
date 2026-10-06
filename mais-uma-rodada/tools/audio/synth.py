"""Instrumentos e efeitos de síntese usados pela trilha do jogo (tudo gerado por conta, sem amostras
de terceiros). Cada função devolve um sinal mono em float (numpy), a 44,1 kHz."""
import numpy as np
import scipy.signal as ss

SR = 44100


def hz(midi):
    return 440.0 * 2.0 ** ((np.asarray(midi, dtype=float) - 69.0) / 12.0)


def tvec(dur):
    return np.arange(int(dur * SR)) / SR


# ---------------------------------------------------------------------------
# Osciladores
# ---------------------------------------------------------------------------

def _blep(ph, dt):
    y = 2.0 * ph - 1.0
    m = ph < dt
    t = ph[m] / dt[m]
    y[m] -= t + t - t * t - 1.0
    m = ph > 1.0 - dt
    t = (ph[m] - 1.0) / dt[m]
    y[m] -= t * t + t + t + 1.0
    return y


def phase(freq, n, ph0=0.0):
    f = np.full(n, float(freq)) if np.ndim(freq) == 0 else np.asarray(freq, dtype=float)[:n]
    dt = f / SR
    return (ph0 + np.cumsum(dt)) % 1.0, dt


def saw(freq, n, ph0=0.0):
    ph, dt = phase(freq, n, ph0)
    return _blep(ph, dt)


def square(freq, n, ph0=0.0, width=0.5):
    ph, dt = phase(freq, n, ph0)
    return 0.5 * (_blep(ph, dt) - _blep((ph + width) % 1.0, dt))


def sine(freq, n, ph0=0.0):
    ph, _ = phase(freq, n, ph0)
    return np.sin(2 * np.pi * ph)


def noise(n, rng):
    return rng.uniform(-1.0, 1.0, n)


def pink(n, rng):
    w = rng.standard_normal(n)
    b, a = [0.049922035, -0.095993537, 0.050612699, -0.004408786], [1, -2.494956002, 2.017265875, -0.522189400]
    y = ss.lfilter(b, a, w)
    return y / (np.max(np.abs(y)) + 1e-9)


# ---------------------------------------------------------------------------
# Filtros e envelopes
# ---------------------------------------------------------------------------

def lp(x, fc, order=2):
    fc = min(fc, SR * 0.45)
    return ss.sosfilt(ss.butter(order, fc, "low", fs=SR, output="sos"), x)


def hp(x, fc, order=2):
    return ss.sosfilt(ss.butter(order, fc, "high", fs=SR, output="sos"), x)


def bp(x, lo, hi, order=2):
    hi = min(hi, SR * 0.45)
    return ss.sosfilt(ss.butter(order, [lo, hi], "band", fs=SR, output="sos"), x)


def peak(x, fc, q, gain_db=0.0):
    """Ressonância (filtro passa-faixa de 2ª ordem com ganho em dB)."""
    w0 = 2 * np.pi * fc / SR
    alpha = np.sin(w0) / (2 * q)
    b = [alpha, 0.0, -alpha]
    a = [1 + alpha, -2 * np.cos(w0), 1 - alpha]
    return ss.lfilter(b, a, x) * 10 ** (gain_db / 20.0)


def tv_lp(x, cutoff, block=256):
    """Passa-baixa com corte variando no tempo (array do mesmo tamanho de x)."""
    out = np.empty_like(x)
    zi = np.zeros(2)
    for i in range(0, len(x), block):
        fc = float(np.clip(cutoff[min(i, len(cutoff) - 1)], 30.0, SR * 0.45))
        b, a = ss.butter(2, fc, "low", fs=SR)
        out[i:i + block], zi = ss.lfilter(b, a, x[i:i + block], zi=zi)
    return out


def adsr(n, a=0.005, d=0.1, s=0.7, r=0.1, hold=None):
    """Envelope com sustentação até `hold` segundos e soltura `r` (n inclui a soltura)."""
    t = np.arange(n) / SR
    hold = (n / SR - r) if hold is None else hold
    e = np.where(t < a, t / max(a, 1e-6), s + (1 - s) * np.exp(-(t - a) / max(d, 1e-6)))
    rel = np.clip(1.0 - (t - hold) / max(r, 1e-6), 0.0, 1.0)
    return e * np.where(t > hold, rel, 1.0)


def fade(x, a=0.002, r=0.01):
    n = len(x)
    na, nr = max(1, int(a * SR)), max(1, int(r * SR))
    x = x.copy()
    x[:na] *= np.linspace(0, 1, na)
    x[-nr:] *= np.linspace(1, 0, nr)
    return x


def vibrato(n, rate=5.5, depth=0.006, delay=0.25, rng=None):
    t = np.arange(n) / SR
    ph = 0.0 if rng is None else rng.uniform(0, 6.28)
    ramp = np.clip((t - delay) / 0.4, 0.0, 1.0)
    return 1.0 + depth * ramp * np.sin(2 * np.pi * rate * t + ph)


def drift(n, rng, amount=0.003, smooth=30.0):
    w = lp(rng.standard_normal(n), smooth, 1)
    w /= np.max(np.abs(w)) + 1e-9
    return 1.0 + amount * w


# ---------------------------------------------------------------------------
# Bateria e percussão
# ---------------------------------------------------------------------------

def kick(rng, punch=1.0, dur=0.42, tune=50.0):
    t = tvec(dur)
    f = tune + 115.0 * np.exp(-t * 32.0) + 30.0 * np.exp(-t * 6.0)
    body = sine(f, len(t)) * np.exp(-t * 7.5)
    click = hp(noise(len(t), rng), 2500) * np.exp(-t * 400.0) * 0.35 * punch
    return np.tanh((body + click) * 1.6) * 0.8


def snare(rng, dur=0.28, tone=190.0, bright=1.0):
    t = tvec(dur)
    nz = bp(noise(len(t), rng), 900, 9000) * np.exp(-t * 16.0) * 0.9 * bright
    body = (sine(tone, len(t)) * 0.6 + sine(tone * 1.65, len(t)) * 0.3) * np.exp(-t * 28.0)
    return np.tanh((nz + body) * 1.3) * 0.7


def rim(rng):
    t = tvec(0.06)
    return (sine(1700, len(t)) * 0.5 + bp(noise(len(t), rng), 2000, 6000) * 0.5) * np.exp(-t * 90.0)


def clap(rng, dur=0.3, spread=0.011):
    t = tvec(dur)
    x = np.zeros(len(t))
    nz = bp(noise(len(t), rng), 900, 3200, 2)
    for k in range(4):
        s = int(k * spread * SR)
        tt = t[: len(t) - s]
        decay = 18.0 if k == 3 else 140.0
        x[s:] += nz[: len(tt)] * np.exp(-tt * decay) * (1.0 if k == 3 else 0.7)
    return x * 0.6


def _metal(n, rng, base=330.0):
    ratios = [1.0, 1.4471, 1.6170, 1.9265, 2.5028, 2.6637]
    x = sum(square(base * r * (1 + rng.uniform(-0.01, 0.01)), n) for r in ratios)
    return x / len(ratios)


def hat(rng, open_=False, vol=1.0):
    dur = 0.45 if open_ else 0.07
    t = tvec(dur)
    x = hp(_metal(len(t), rng, 320.0) * 0.6 + noise(len(t), rng) * 0.6, 7000, 2)
    return x * np.exp(-t * (7.0 if open_ else 55.0)) * 0.5 * vol


def crash(rng, dur=2.6, vol=1.0):
    t = tvec(dur)
    x = hp(_metal(len(t), rng, 410.0) * 0.5 + noise(len(t), rng), 4200, 2)
    env = np.exp(-t * 1.6) * (0.4 + 0.6 * np.exp(-t * 9.0))
    return x * env * 0.5 * vol


def ride(rng):
    t = tvec(0.9)
    x = hp(_metal(len(t), rng, 600.0) * 0.7 + noise(len(t), rng) * 0.3, 5000, 2)
    return x * np.exp(-t * 4.0) * 0.25


def shaker(rng, vol=1.0):
    t = tvec(0.09)
    env = np.minimum(1.0, t / 0.02) * np.exp(-t * 45.0)
    return bp(noise(len(t), rng), 4000, 12000) * env * 0.4 * vol


def tom(rng, f=110.0, dur=0.55):
    t = tvec(dur)
    fr = f * (1.0 + 0.5 * np.exp(-t * 20.0))
    return np.tanh((sine(fr, len(t)) * np.exp(-t * 6.0) + bp(noise(len(t), rng), 200, 2000) * np.exp(-t * 40) * 0.2) * 1.5) * 0.7


def timpani(rng, f=55.0, dur=2.2, vol=1.0):
    t = tvec(dur)
    parts = [(1.0, 1.0), (1.5, 0.5), (1.99, 0.35), (2.44, 0.2), (2.9, 0.1)]
    x = sum(a * sine(f * r, len(t)) * np.exp(-t * (1.6 + r)) for r, a in parts)
    x += lp(noise(len(t), rng), 900) * np.exp(-t * 30.0) * 0.5
    return np.tanh(x * 1.2) * 0.6 * vol


def surdo(rng, f=58.0, dur=0.9, muted=False):
    t = tvec(dur)
    fr = f * (1.0 + 0.35 * np.exp(-t * 18.0))
    x = sine(fr, len(t)) + 0.25 * sine(fr * 2.01, len(t))
    x *= np.exp(-t * (14.0 if muted else 3.8))
    x += lp(noise(len(t), rng), 600) * np.exp(-t * 60.0) * 0.3
    return np.tanh(x * 1.4) * 0.75


def tamborim(rng, vol=1.0):
    t = tvec(0.09)
    x = sine(720.0 * (1 + 0.2 * np.exp(-t * 60)), len(t)) * 0.6 + bp(noise(len(t), rng), 1500, 7000) * 0.6
    return x * np.exp(-t * 55.0) * 0.45 * vol


def agogo(rng, high=True):
    f = 1250.0 if high else 900.0
    t = tvec(0.35)
    x = sine(f, len(t)) + 0.5 * sine(f * 2.62, len(t)) * np.exp(-t * 12.0) + 0.3 * sine(f * 4.1, len(t)) * np.exp(-t * 25.0)
    return x * np.exp(-t * 9.0) * 0.18


def pandeiro(rng, slap=False):
    t = tvec(0.12)
    jingle = hp(_metal(len(t), rng, 900.0) + noise(len(t), rng) * 0.6, 6000) * np.exp(-t * 30.0) * 0.4
    skin = sine(260.0 if not slap else 420.0, len(t)) * np.exp(-t * 35.0) * (0.5 if slap else 0.3)
    return (jingle + skin) * 0.5


def cuica(rng, up=True, dur=0.22):
    t = tvec(dur)
    f = (420.0 + 380.0 * (t / dur)) if up else (760.0 - 300.0 * (t / dur))
    x = saw(f, len(t)) * 0.5
    x = peak(x, 800.0, 3.0, 6.0) + lp(x, 1400)
    return x * np.sin(np.pi * np.clip(t / dur, 0, 1)) * 0.25


# ---------------------------------------------------------------------------
# Instrumentos com altura
# ---------------------------------------------------------------------------

def sub_bass(m, dur, rng, vol=1.0, drive=1.3):
    n = int((dur + 0.06) * SR)
    f = hz(m)
    x = sine(f, n) + 0.35 * sine(f * 2, n) + 0.12 * sine(f * 3, n)
    env = adsr(n, 0.004, 0.25, 0.75, 0.06, hold=dur)
    return np.tanh(x * env * drive) * 0.6 * vol


def synth_bass(m, dur, rng, vol=1.0, bright=1.0):
    n = int((dur + 0.06) * SR)
    f = hz(m)
    x = saw(f, n) * 0.6 + square(f * 0.5, n) * 0.4
    t = np.arange(n) / SR
    cut = 180 + (900 + 1200 * bright) * np.exp(-t * 12.0)
    x = tv_lp(x, cut)
    env = adsr(n, 0.003, 0.2, 0.8, 0.05, hold=dur)
    return np.tanh(x * env * 1.6) * 0.55 * vol


def finger_bass(m, dur, rng, vol=1.0):
    n = int((dur + 0.08) * SR)
    f = hz(m)
    t = np.arange(n) / SR
    x = saw(f, n) * 0.5 + sine(f, n) * 0.8
    x = tv_lp(x, 250 + 1100 * np.exp(-t * 9.0))
    env = adsr(n, 0.004, 0.35, 0.55, 0.07, hold=dur)
    return x * env * 0.7 * vol


def pluck(m, dur, rng, vol=1.0, bright=0.7, decay=0.996):
    """Corda dedilhada (Karplus-Strong em blocos): cavaquinho, violão, arpejos."""
    f = float(hz(m))
    p = max(2, int(round(SR / f)))
    n = int((dur + 0.12) * SR)
    n = ((n // p) + 2) * p
    y = np.zeros(n)
    exc = noise(p, rng)
    exc = lp(exc, 1500 + 7000 * bright, 1)
    y[:p] = exc
    g = 0.5 * (decay ** (1.0 + (1.0 - bright)))
    for i in range(p, n - p + 1, p):
        prev = y[i - p - 1:i - 1] if i - p - 1 >= 0 else np.concatenate(([0.0], y[i - p:i - 1]))
        y[i:i + p] = g * (y[i - p:i] + prev)
    y = y[: int((dur + 0.12) * SR)]
    t = np.arange(len(y)) / SR
    rel = np.clip(1.0 - (t - dur) / 0.12, 0.0, 1.0)
    return y * np.where(t > dur, rel, 1.0) * 0.8 * vol


def epiano(m, dur, rng, vol=1.0, bright=1.0):
    n = int((dur + 0.6) * SR)
    f = float(hz(m))
    t = np.arange(n) / SR
    idx = (1.6 * bright) * np.exp(-t * 3.5) + 0.25
    mod = np.sin(2 * np.pi * f * t)
    x = np.sin(2 * np.pi * f * t + idx * mod)
    tine = np.sin(2 * np.pi * f * 14.0 * t) * np.exp(-t * 40.0) * 0.12 * bright
    env = np.exp(-t * (1.1 + m / 90.0)) * np.minimum(1.0, t / 0.003)
    rel = np.clip(1.0 - (t - dur) / 0.35, 0.0, 1.0)
    return (x + tine) * env * np.where(t > dur, rel, 1.0) * 0.32 * vol


def mallet(m, dur, rng, vol=1.0, kind="marimba"):
    f = float(hz(m))
    d = min(dur, 1.4) + 0.4
    t = tvec(d)
    if kind == "glock":
        parts = [(1.0, 1.0, 1.2), (2.76, 0.35, 4.0), (5.4, 0.15, 7.0), (8.93, 0.08, 10.0)]
    else:
        parts = [(1.0, 1.0, 3.8), (3.93, 0.35, 14.0), (9.2, 0.1, 30.0)]
    x = sum(a * sine(f * r, len(t)) * np.exp(-t * dk) for r, a, dk in parts if f * r < SR * 0.45)
    return x * np.minimum(1.0, t / 0.001) * 0.35 * vol


def bell(m, dur, rng, vol=1.0):
    f = float(hz(m))
    t = tvec(dur + 1.2)
    mod = np.sin(2 * np.pi * f * 3.5 * t) * 2.2 * np.exp(-t * 2.0)
    return np.sin(2 * np.pi * f * t + mod) * np.exp(-t * 1.6) * np.minimum(1.0, t / 0.002) * 0.25 * vol


def supersaw(m, n, rng, voices=5, detune=0.012):
    f = float(hz(m))
    x = np.zeros(n)
    for k in range(voices):
        d = 1.0 + detune * (k - (voices - 1) / 2) / ((voices - 1) / 2 if voices > 1 else 1)
        x += saw(f * d, n, rng.uniform(0, 1))
    return x / voices


def pad(m, dur, rng, vol=1.0, bright=0.5, attack=0.6, release=0.8):
    n = int((dur + release) * SR)
    x = supersaw(m, n, rng, 5, 0.010)
    x = lp(x, 900 + 2600 * bright)
    return x * adsr(n, attack, 0.5, 0.85, release, hold=dur) * 0.35 * vol


def strings(m, dur, rng, vol=1.0, attack=0.25, release=0.5, bright=0.6):
    n = int((dur + release) * SR)
    f = float(hz(m))
    vib = vibrato(n, 5.2, 0.005, 0.3, rng) * drift(n, rng, 0.002)
    x = np.zeros(n)
    for k in range(4):
        x += saw(f * vib * (1 + 0.004 * (k - 1.5)), n, rng.uniform(0, 1))
    x = lp(x / 4, 1800 + 3500 * bright)
    x = peak(x, 1200, 1.2, 3) + x
    return x * adsr(n, attack, 0.4, 0.9, release, hold=dur) * 0.2 * vol


def spiccato(m, dur, rng, vol=1.0):
    d = min(dur, 0.22)
    n = int((d + 0.12) * SR)
    f = float(hz(m))
    x = sum(saw(f * (1 + 0.004 * k), n, rng.uniform(0, 1)) for k in (-1, 0, 1)) / 3
    t = np.arange(n) / SR
    x = tv_lp(x, 900 + 3500 * np.exp(-t * 18.0))
    return x * adsr(n, 0.006, 0.08, 0.4, 0.1, hold=d) * 0.35 * vol


def brass(m, dur, rng, vol=1.0, bright=1.0, attack=0.03):
    n = int((dur + 0.14) * SR)
    f = float(hz(m))
    t = np.arange(n) / SR
    vib = vibrato(n, 5.6, 0.007, 0.35, rng)
    bend = 1.0 - 0.02 * np.exp(-t * 30.0)
    x = sum(saw(f * vib * bend * (1 + 0.003 * k), n, rng.uniform(0, 1)) for k in (-1, 0, 1)) / 3
    env = adsr(n, attack, 0.25, 0.75, 0.12, hold=dur)
    cut = (500 + 3800 * bright) * (0.35 + 0.65 * env) * (1.0 + 0.6 * np.exp(-t * 14.0))
    x = tv_lp(x, cut)
    x = x + peak(x, 1400, 1.0, 2.0)
    return np.tanh(x * env * 1.5) * 0.3 * vol


def horn(m, dur, rng, vol=1.0):
    return brass(m, dur, rng, vol, bright=0.35, attack=0.09)


def flute(m, dur, rng, vol=1.0):
    n = int((dur + 0.1) * SR)
    f = float(hz(m))
    vib = vibrato(n, 5.0, 0.008, 0.2, rng)
    x = sine(f * vib, n) + 0.18 * sine(2 * f * vib, n) + 0.05 * sine(3 * f * vib, n)
    breath = bp(noise(n, rng), f * 0.8, min(f * 4, 15000)) * 0.12
    env = adsr(n, 0.04, 0.2, 0.85, 0.08, hold=dur)
    return (x + breath) * env * 0.3 * vol


def lead(m, dur, rng, vol=1.0):
    n = int((dur + 0.1) * SR)
    f = float(hz(m))
    vib = vibrato(n, 5.8, 0.006, 0.2, rng)
    x = saw(f * vib, n) * 0.6 + square(f * vib * 1.003, n) * 0.4
    t = np.arange(n) / SR
    x = tv_lp(x, 1200 + 2500 * np.exp(-t * 6.0))
    return x * adsr(n, 0.01, 0.2, 0.8, 0.08, hold=dur) * 0.22 * vol


def arp_pluck(m, dur, rng, vol=1.0, cutoff=2000.0):
    n = int((dur + 0.15) * SR)
    f = float(hz(m))
    t = np.arange(n) / SR
    x = saw(f, n) * 0.5 + square(f * 1.005, n, 0.3, 0.3) * 0.5
    x = tv_lp(x, 200 + cutoff * np.exp(-t * 14.0))
    return x * np.exp(-t * 6.0) * np.minimum(1.0, t / 0.002) * 0.4 * vol


# ---------------------------------------------------------------------------
# Vozes (torcida e coro): pulso glotal + formantes de vogal
# ---------------------------------------------------------------------------

VOWELS = {
    "a": [(730, 90, 1.0), (1090, 110, 0.5), (2440, 160, 0.25)],
    "e": [(530, 80, 1.0), (1840, 120, 0.45), (2480, 170, 0.3)],
    "o": [(570, 80, 1.0), (840, 100, 0.55), (2410, 160, 0.15)],
    "u": [(330, 60, 1.0), (870, 90, 0.35), (2240, 160, 0.08)],
    "eh": [(660, 90, 1.0), (1700, 130, 0.5), (2400, 170, 0.3)],
}


def formants(x, vowel, shift=1.0):
    y = np.zeros_like(x)
    for f, bw, g in VOWELS[vowel]:
        y += peak(x, f * shift, (f * shift) / bw) * g
    return y


def voices(dur, rng, count, f0_lo, f0_hi, vowel, pitch=None, env=None, onset=0.25, breath=0.25,
           female=0.25, stereo=True, jitter=0.03, syll=0.0):
    """Muitas vozes juntas (gente gritando ou cantando). `pitch(t)` multiplica a altura de todas."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    pc = np.ones(n) if pitch is None else pitch(t)
    groups = {"m": [np.zeros(n), np.zeros(n)], "f": [np.zeros(n), np.zeros(n)]}
    for v in range(count):
        fem = rng.random() < female
        f0 = rng.uniform(f0_lo, f0_hi) * (1.8 if fem else 1.0)
        fr = f0 * pc * drift(n, rng, jitter, 6.0) * vibrato(n, rng.uniform(4.5, 6.5), 0.01, 0.1, rng)
        src = saw(fr, n, rng.uniform(0, 1))
        src = lp(src, 2600, 1)
        st = rng.uniform(0, onset)
        e = np.clip((t - st) / rng.uniform(0.05, 0.2), 0.0, 1.0) * rng.uniform(0.5, 1.0)
        e *= drift(n, rng, 0.35, 2.0)
        if syll:
            # sílabas: a voz liga e desliga 3 a 6 vezes por segundo (conversa, murmúrio)
            sy = np.abs(lp(rng.standard_normal(n), rng.uniform(3.0, 6.0), 2))
            e *= (1 - syll) + syll * sy / (np.max(sy) + 1e-9)
        pan = rng.uniform(-0.8, 0.8) if stereo else 0.0
        g = groups["f" if fem else "m"]
        g[0] += src * e * np.sqrt(0.5 * (1 - pan))
        g[1] += src * e * np.sqrt(0.5 * (1 + pan))
    out = []
    for ch in range(2):
        y = formants(groups["m"][ch], vowel) + formants(groups["f"][ch], vowel, 1.17)
        nz = pink(n, rng) * breath * count ** 0.5
        y += formants(nz, vowel) * 0.6
        out.append(y)
    out = np.array(out)
    out /= np.max(np.abs(out)) + 1e-9
    if env is not None:
        out *= env(t)
    return out


def claps(dur, rng, people=120, rate=(3.5, 6.0), env=None):
    """Aplausos: cada pessoa bate palmas no seu ritmo; as palmas têm timbres diferentes."""
    n = int(dur * SR)
    out = np.zeros((2, n))
    kernels = []
    for k in range(8):
        kt = tvec(0.03)
        c = bp(noise(len(kt), rng), rng.uniform(700, 1300), rng.uniform(2200, 4200)) * np.exp(-kt * rng.uniform(110, 220))
        kernels.append(c)
    trains = [np.zeros((2, n)) for _ in kernels]
    for p in range(people):
        r = rng.uniform(*rate)
        tt = rng.uniform(0, 0.3)
        pan = rng.uniform(-0.9, 0.9)
        amp = rng.uniform(0.3, 1.0)
        k = rng.integers(len(kernels))
        while tt < dur:
            i = int(tt * SR)
            w = amp * (env(np.array([tt]))[0] if env is not None else 1.0)
            if w > 0.01:
                trains[k][0, i] += w * np.sqrt(0.5 * (1 - pan))
                trains[k][1, i] += w * np.sqrt(0.5 * (1 + pan))
            tt += 1.0 / r * rng.uniform(0.85, 1.15)
    for k, c in enumerate(kernels):
        for ch in range(2):
            out[ch] += ss.fftconvolve(trains[k][ch], c)[:n]
    return out / (np.max(np.abs(out)) + 1e-9)


def ref_whistle(dur, rng, f=2950.0, pea=True, vol=1.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    roll = rng.uniform(26, 34)
    fm = f * (1.0 + (0.045 * np.sin(2 * np.pi * roll * t) if pea else 0.0)) * (1.0 + 0.01 * np.exp(-t * 20))
    tone = sine(fm, n) + 0.12 * sine(fm * 2, n) + 0.04 * sine(fm * 3, n)
    am = 1.0 - (0.35 * (0.5 + 0.5 * np.sin(2 * np.pi * roll * t + 1.0)) if pea else 0.0)
    breath = bp(noise(n, rng), f * 0.7, f * 1.4) * 0.35
    env = np.minimum(1.0, t / 0.012) * np.clip((dur - t) / 0.035, 0.0, 1.0)
    env *= 1.0 + 0.08 * np.exp(-t * 15)
    return (tone * am + breath) * env * 0.4 * vol


# ---------------------------------------------------------------------------
# Mixagem
# ---------------------------------------------------------------------------

def reverb_ir(rng, seconds=2.2, predelay=0.02, damp=5500.0, early=True):
    n = int(seconds * SR)
    t = np.arange(n) / SR
    ir = np.zeros((2, n + int(predelay * SR)))
    tau = seconds / 6.9
    for ch in range(2):
        nz = rng.standard_normal(n) * np.exp(-t / tau)
        nz = lp(nz, damp, 1)
        # tirar agudos com o tempo: mistura de cópia escura no fim
        dark = lp(nz, damp * 0.35, 1)
        mix = np.clip(t / seconds * 1.5, 0, 1)
        nz = nz * (1 - mix) + dark * mix
        ir[ch, int(predelay * SR):] = nz
        if early:
            for k in range(6):
                d = int(rng.uniform(0.008, 0.06) * SR)
                ir[ch, d] += rng.uniform(0.2, 0.5) * (1 if rng.random() < 0.5 else -1)
    ir /= np.sqrt(np.sum(ir ** 2) / 2) + 1e-9
    return ir


def apply_reverb(st, ir, wet):
    out = np.zeros((2, st.shape[1]))
    for ch in range(2):
        out[ch] = ss.fftconvolve(st[ch], ir[ch])[: st.shape[1]]
    return st + out * wet


def pan2(x, pan):
    pan = float(np.clip(pan, -1, 1))
    return np.array([x * np.sqrt(0.5 * (1 - pan)), x * np.sqrt(0.5 * (1 + pan))])


def compress(st, thresh=0.5, ratio=3.0, attack=0.005, release=0.12):
    level = np.max(np.abs(st), axis=0)
    a = np.exp(-1.0 / (attack * SR))
    r = np.exp(-1.0 / (release * SR))
    # seguidor de envelope em blocos (rápido o bastante para o numpy)
    block = 64
    env = np.zeros_like(level)
    e = 0.0
    for i in range(0, len(level), block):
        m = level[i:i + block].max()
        c = a ** block if m > e else r ** block
        e = c * e + (1 - c) * m
        env[i:i + block] = e
    gain = np.where(env > thresh, (thresh + (env - thresh) / ratio) / (env + 1e-9), 1.0)
    gain = lp(gain, 40, 1)
    return st * gain


def master(st, target_peak=0.89, drive=1.2, lowcut=32.0):
    st = np.array([hp(ch, lowcut) for ch in st])
    st = st / (np.max(np.abs(st)) + 1e-9)
    st = np.tanh(st * drive) / np.tanh(drive)
    return st / (np.max(np.abs(st)) + 1e-9) * target_peak
