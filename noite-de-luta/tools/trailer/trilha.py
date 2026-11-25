# Trilha sintetizada do trailer: 100 BPM, lá menor, percussão pesada. Saída WAV estéreo 44,1 kHz.
import os, sys, wave
import numpy as np

SR = 44100
BPM = 100.0
BEAT = 60.0 / BPM
DUR = float(sys.argv[2]) if len(sys.argv) > 2 else 54.0
DROP = float(os.environ.get("TR_DROP", "4.8"))        # bateria entra aqui
SWITCH = float(os.environ.get("TR_SWITCH", "24.6"))   # virada para o modo presidente
END = float(os.environ.get("TR_END", "48.0"))        # cartela final
N = int(SR * DUR)
L = np.zeros(N); R = np.zeros(N)
rng = np.random.default_rng(7)


def put(sig, t, gain=1.0, pan=0.0):
    i = int(t * SR)
    if i >= N:
        return
    s = sig[: N - i] * gain
    L[i:i + len(s)] += s * (1.0 - max(0.0, pan))
    R[i:i + len(s)] += s * (1.0 + min(0.0, pan))


def lowpass(x, a):
    y = np.empty_like(x); acc = 0.0
    for k in range(len(x)):
        acc += a * (x[k] - acc); y[k] = acc
    return y


def kick():
    t = np.arange(int(0.45 * SR)) / SR
    f = 45 + 110 * np.exp(-t * 28)
    ph = 2 * np.pi * np.cumsum(f) / SR
    s = np.sin(ph) * np.exp(-t * 7.5)
    s += 0.35 * np.tanh(4 * s)
    click = rng.standard_normal(len(t)) * np.exp(-t * 400) * 0.3
    return np.tanh(1.6 * (s + click))


def snare():
    t = np.arange(int(0.3 * SR)) / SR
    n = rng.standard_normal(len(t))
    n = n - lowpass(n, 0.15)
    tone = np.sin(2 * np.pi * 185 * t) * np.exp(-t * 30)
    return (n * np.exp(-t * 16) * 0.7 + tone * 0.6)


def hat(open_=False):
    t = np.arange(int((0.18 if open_ else 0.05) * SR)) / SR
    n = rng.standard_normal(len(t))
    n = n - lowpass(n, 0.5)
    return n * np.exp(-t * (18 if open_ else 90)) * 0.35


def tom(freq):
    t = np.arange(int(0.4 * SR)) / SR
    f = freq * (1 + 0.6 * np.exp(-t * 20))
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 8)


def impact():
    t = np.arange(int(2.8 * SR)) / SR
    f = 30 + 90 * np.exp(-t * 6)
    boom = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 1.6)
    n = rng.standard_normal(len(t))
    n = lowpass(n, 0.05) * np.exp(-t * 2.5) * 3
    return np.tanh(1.8 * (boom + n * 0.5))


def riser(length):
    t = np.arange(int(length * SR)) / SR
    n = rng.standard_normal(len(t))
    env = (t / length) ** 2.2
    hp = n - lowpass(n, 0.02 + 0.4 * (t[-1] and 0.5))
    f = 200 + 1400 * (t / length) ** 2
    sweep = np.sin(2 * np.pi * np.cumsum(f) / SR) * 0.15
    return (hp * 0.5 + sweep) * env


def saw(freq, length, det=0.0):
    t = np.arange(int(length * SR)) / SR
    return 2 * ((t * freq * (1 + det)) % 1.0) - 1


def note(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)


# Progressão por compasso (4 tempos): Am, F, C, G em graves.
prog = [45, 41, 48, 43]  # A2 F2 C3 G2 (MIDI)
BAR = 4 * BEAT

# Pad escuro do começo ao fim.
t0 = 0.0
k = 0
while t0 < DUR:
    root = prog[k % 4]
    ln = BAR + 0.3
    pad = np.zeros(int(ln * SR))
    for iv in (0, 7, 12, 15 if k % 4 in (0,) else 16 if k % 4 in (1, 2) else 14):
        for d in (-0.004, 0.004):
            pad += saw(note(root + iv), ln, d)
    pad = lowpass(pad, 0.035)
    env = np.minimum(1, np.arange(len(pad)) / (0.25 * SR)) * np.minimum(1, (len(pad) - np.arange(len(pad))) / (0.3 * SR))
    put(pad * env, t0, 0.05, pan=0.2 * (-1) ** k)
    t0 += BAR; k += 1

# Abertura: riser até a entrada da bateria.
put(riser(DROP), 0.0, 0.5)
put(tom(70), DROP - BEAT * 1.0, 0.5)
put(tom(55), DROP - BEAT * 0.5, 0.6)

for at in (DROP, SWITCH, END):
    put(impact(), at, 0.9)

# Bateria e baixo de DROP até END.
step = 0
while DROP + step * BEAT / 2 < END - 1e-6:
    t = DROP + step * BEAT / 2
    bar_i = step // 8
    pos = (step % 8) / 2.0  # em tempos, meio a meio
    step += 1
    if pos in (0, 2.5) or (pos == 1.5 and bar_i % 2 == 1):
        put(kick(), t, 0.85)
    if pos in (1, 3):
        put(snare(), t, 0.55)
    put(hat(pos == 3.5), t, 0.35 if pos % 1 else 0.22, pan=0.3)
    # baixo pulsando em colcheias
    root = prog[bar_i % 4] - 12
    ln = BEAT / 2 * 0.9
    bs = saw(note(root), ln) + 0.5 * np.sin(2 * np.pi * note(root) * np.arange(int(ln * SR)) / SR)
    bs = lowpass(bs, 0.06) * np.exp(-np.arange(len(bs)) / SR * 6)
    put(np.tanh(2 * bs), t, 0.22)
    # virada de tons no fim de cada 4 compassos
    if bar_i % 4 == 3 and pos >= 3:
        put(tom(110 - (pos - 3) * 60), t, 0.45)

# Um respiro antes da virada para o modo presidente.
put(riser(BAR), SWITCH - BAR, 0.35)
put(riser(BAR), END - BAR, 0.45)

# Cauda final: acorde longo.
ln = DUR - END
tail = np.zeros(int(ln * SR))
for iv in (0, 7, 12, 15):
    for d in (-0.005, 0.005):
        tail += saw(note(45 + iv), ln, d)
tail = lowpass(tail, 0.03) * np.exp(-np.arange(len(tail)) / SR * 0.6)
put(tail, END, 0.08)

mix = np.stack([L, R], 1)
mix = np.tanh(mix * 1.1)
fade = np.ones(N); fl = int(1.2 * SR); fade[-fl:] = np.linspace(1, 0, fl)
mix *= fade[:, None]
mix /= np.max(np.abs(mix)) + 1e-9
mix *= 0.89
pcm = (mix * 32767).astype(np.int16)
with wave.open(sys.argv[1], "wb") as w:
    w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
    w.writeframes(pcm.tobytes())
print("ok", DUR)
