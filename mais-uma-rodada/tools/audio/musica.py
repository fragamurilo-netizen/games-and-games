"""Músicas de fundo do jogo, compostas aqui mesmo (notas escritas à mão, timbres sintetizados).
Cada faixa é um loop: o rabo do eco/sustentação do fim é somado ao começo, então emenda sem corte."""
import numpy as np
from synth import *


class Song:
    def __init__(self, bpm, bars, seed, swing=0.0, tail=6.0, loop=True):
        self.loop = loop
        self.beat = 60.0 / bpm
        self.bars = bars
        self.n = int(round(bars * 4 * self.beat * SR))
        self.tailn = int(tail * SR)
        self.rng = np.random.default_rng(seed)
        self.buses = {}
        self.kicks = []
        self.swing = swing

    def t(self, bar, beat=0.0):
        b = beat
        if self.swing and abs((b % 1.0) - 0.5) < 1e-6:
            b += self.swing * 0.5
        return (bar * 4 + b) * self.beat

    def bus(self, name):
        if name not in self.buses:
            self.buses[name] = np.zeros((2, self.n + self.tailn))
        return self.buses[name]

    def add(self, bus, t0, sig, pan=0.0, gain=1.0, human=0.0):
        if human:
            t0 += self.rng.uniform(-human, human)
        s = int(round(t0 * SR))
        s = s % self.n if self.loop else max(0, s)
        st = pan2(sig, pan) * gain if sig.ndim == 1 else sig * gain
        buf = self.bus(bus)
        L = st.shape[1]
        end = min(s + L, buf.shape[1])
        buf[:, s:end] += st[:, : end - s]
        rest = L - (end - s)
        if rest > 0 and self.loop:
            buf[:, :rest] += st[:, end - s:]

    def note(self, bus, inst, m, bar, beat, beats, pan=0.0, gain=1.0, human=0.006, **kw):
        sig = inst(m, beats * self.beat, self.rng, **kw)
        self.add(bus, self.t(bar, beat), sig, pan, gain, human)

    def chord(self, bus, inst, ms, bar, beat, beats, spread=0.5, gain=1.0, strum=0.0, **kw):
        k = len(ms)
        for i, m in enumerate(ms):
            pan = (i / (k - 1) - 0.5) * 2 * spread if k > 1 else 0.0
            sig = inst(m, beats * self.beat, self.rng, **kw)
            self.add(bus, self.t(bar, beat) + i * strum, sig, pan, gain / np.sqrt(k), 0.004)

    def hit(self, bus, sig, bar, beat, pan=0.0, gain=1.0, human=0.003):
        self.add(bus, self.t(bar, beat), sig, pan, gain, human)
        if bus == "kick":
            self.kicks.append(self.t(bar, beat))

    def mix(self, cfg, reverb=2.0, damp=5500.0, drive=1.25, comp=0.45, loop=None):
        loop = self.loop if loop is None else loop
        total = np.zeros((2, self.n + self.tailn))
        send = np.zeros_like(total)
        duck = np.zeros(self.n + self.tailn)
        for tk in self.kicks:
            s = int(tk * SR) % self.n
            duck[s] = 1.0
        dk = np.exp(-np.arange(int(0.25 * SR)) / (0.09 * SR))
        duck = np.clip(ss.fftconvolve(duck, dk)[: len(duck)], 0, 1)
        for name, buf in self.buses.items():
            g, rv, dd = cfg.get(name, (1.0, 0.15, 0.0))
            b = buf * g
            if dd:
                b = b * (1.0 - dd * duck)
            total += b
            send += b * rv
        ir = reverb_ir(self.rng, reverb, 0.025, damp)
        wet = apply_reverb(send, ir, 1.0) - send
        total += wet
        if loop:
            total[:, : self.tailn] += total[:, self.n:]
            total = total[:, : self.n]
        else:
            lvl = np.max(np.abs(total), axis=0)
            last = np.nonzero(lvl > np.max(lvl) * 0.001)[0]
            total = total[:, : (last[-1] + 1 if len(last) else total.shape[1])]
            nr = min(int(0.05 * SR), total.shape[1])
            total[:, -nr:] *= np.linspace(1, 0, nr)
        total = compress(total / (np.max(np.abs(total)) + 1e-9), comp, 2.5)
        return master(total, 0.89, drive)


# ---------------------------------------------------------------------------
# 1. Dia de jogo — hino de transmissão esportiva, Ré maior, 122 bpm
# ---------------------------------------------------------------------------

def dia_de_jogo():
    s = Song(122, 32, 101)
    r = s.rng
    D, A, Bm, G, Em, Fs = [50, 57, 62, 66], [45, 52, 57, 61], [47, 54, 59, 62], [43, 50, 55, 59], [40, 47, 52, 55], [42, 49, 54, 58]
    secA = [D, A, Bm, G, D, A, G, A]
    secB = [Bm, G, D, A, Bm, G, Em, A]
    secC = [G, A, Bm, D, G, A, Em, A]
    prog = secA + secB + secA + secC
    hook = {
        0: [(0, 69, .5), (.5, 74, .5), (1, 78, 1), (2, 76, .5), (2.5, 74, .5), (3, 76, 1)],
        1: [(0, 73, 1.5), (1.5, 69, .5), (2, 76, 1), (3, 76, 1)],
        2: [(0, 78, .5), (.5, 78, .5), (1, 83, 1), (2, 81, .5), (2.5, 78, .5), (3, 74, 1)],
        3: [(0, 76, 1.5), (1.5, 74, .5), (2, 71, 1), (3, 74, 1)],
        6: [(0, 83, 1), (1, 81, 1), (2, 79, .5), (2.5, 78, .5), (3, 76, 1)],
        7: [(0, 76, 2), (2, 73, 1), (3, 76, 1)],
    }
    hook[4], hook[5] = hook[0], hook[1]
    snare_s = snare(r, tone=200)
    kk = kick(r, 1.1)
    for bar, ch in enumerate(prog):
        sec = bar // 8
        breakdown = sec == 3 and bar % 8 < 4
        root = ch[0]
        # bateria
        if breakdown:
            s.hit("kick", kk, bar, 0, gain=0.9)
            s.hit("drums", snare_s, bar, 2, gain=0.6)
            for e in range(4):
                s.hit("hats", hat(r, vol=0.7), bar, e, pan=0.3)
        else:
            for b in (0, 1.5, 2):
                s.hit("kick", kk, bar, b)
            if bar % 2:
                s.hit("kick", kk, bar, 3.5, gain=0.6)
            s.hit("drums", snare_s, bar, 1)
            s.hit("drums", snare_s, bar, 3)
            for e in range(8):
                s.hit("hats", hat(r, open_=(e == 7 and bar % 4 == 3), vol=1.0 if e % 2 == 0 else 0.6), bar, e * 0.5, pan=0.3)
            s.hit("drums", clap(r), bar, 3, pan=-0.1, gain=0.35)
        if bar % 8 == 0:
            s.hit("cym", crash(r), bar, 0, pan=-0.3)
        if bar % 8 == 7 and sec != 3:
            for k, f in enumerate([180, 150, 120, 95]):
                s.hit("drums", tom(r, f), bar, 2 + k * 0.5, pan=0.5 - k * 0.3, gain=0.6)
        if sec == 3 and bar % 8 >= 6:
            for k in range(8 if bar % 8 == 6 else 16):
                st = (bar % 8 == 6)
                s.hit("drums", snare_s, bar, k * (0.5 if st else 0.25), gain=0.25 + 0.5 * k / (8 if st else 16))
        # baixo em colcheias (oitavas)
        for e in range(8):
            if breakdown and e % 2:
                continue
            m = root - 12 + (12 if e % 4 == 3 else 0)
            s.note("bass", synth_bass, m, bar, e * 0.5, 0.45, gain=0.9, bright=0.7)
        # cordas / pads
        if sec in (1, 3):
            s.chord("pad", strings, [n + 12 for n in ch[1:]], bar, 0, 4, gain=1.0, bright=0.7)
        else:
            s.chord("pad", pad, [n + 12 for n in ch[1:]], bar, 0, 4, gain=0.55, bright=0.5)
        # metais: estocadas
        if sec in (0, 2) or (sec == 3 and not breakdown):
            for b, l in ((0, .4), (1.5, .4), (3, .9)):
                s.chord("brass", brass, [n + 12 for n in ch[1:]], bar, b, l, gain=0.7)
        if sec == 1:
            s.chord("brass", brass, [n + 12 for n in ch[1:]], bar, 0, 3.6, gain=0.45, bright=0.6, attack=0.12)
        # melodia: guitarra/sintetizador no gancho
        if sec in (2,) or (sec == 3 and not breakdown):
            for b, m, l in hook.get(bar % 8, []):
                s.note("lead", brass, m, bar, b, l * 0.95, pan=0.1, gain=0.9, bright=1.2)
                s.note("lead", lead, m + 12, bar, b, l * 0.95, pan=-0.2, gain=0.35)
        if sec == 0 and bar % 2 == 1:
            s.note("bells", mallet, ch[3] + 24, bar, 3, 1, pan=0.4, gain=0.6, kind="glock")
        if breakdown:
            for e in range(8):
                s.note("bells", arp_pluck, [ch[1], ch[2], ch[3]][e % 3] + 24, bar, e * 0.5, 0.5, pan=-0.4 + 0.1 * e, gain=0.45, cutoff=2600)
    return s.mix({
        "kick": (1.0, 0.0, 0.0), "drums": (0.75, 0.18, 0.0), "hats": (0.4, 0.05, 0.0), "cym": (0.35, 0.2, 0.0),
        "bass": (0.75, 0.0, 0.45), "pad": (0.5, 0.35, 0.5), "brass": (0.6, 0.25, 0.2), "lead": (0.62, 0.3, 0.0),
        "bells": (0.4, 0.4, 0.0),
    }, reverb=1.8)


# ---------------------------------------------------------------------------
# 2. Arquibancada — samba-funk em Sol maior, 104 bpm
# ---------------------------------------------------------------------------

def arquibancada():
    s = Song(104, 32, 202)
    r = s.rng
    G, Em, Am, D7, C, Cm, E7, B7 = [43, 55, 59, 62, 67], [40, 55, 59, 64, 67], [45, 57, 60, 64, 69], [38, 54, 57, 60, 66], [36, 55, 60, 64, 67], [36, 55, 60, 63, 67], [40, 56, 59, 62, 68], [47, 54, 57, 63, 66]
    secA = [G, Em, Am, D7] * 2
    secB = [C, Cm, G, E7, Am, D7, G, D7]
    prog = secA + secA + secB + secA
    mel = {
        0: [(.5, 74, .5), (1, 79, .5), (1.5, 81, .25), (1.75, 83, .75), (2.5, 81, .5), (3, 79, 1)],
        1: [(0, 76, .75), (.75, 79, .75), (1.5, 83, 1), (2.5, 81, .5), (3, 79, .5), (3.5, 76, .5)],
        2: [(0, 84, .75), (.75, 83, .25), (1, 81, .5), (1.5, 76, .5), (2, 81, 1), (3, 84, .5), (3.5, 83, .5)],
        3: [(0, 81, 1.5), (1.5, 78, .5), (2, 74, 1), (3, 78, .5), (3.5, 81, .5)],
        4: [(.5, 74, .5), (1, 79, .5), (1.5, 81, .25), (1.75, 83, .75), (2.5, 86, .5), (3, 83, 1)],
        5: [(0, 79, .75), (.75, 76, .75), (1.5, 79, .5), (2, 83, 1), (3, 81, 1)],
        6: [(0, 84, .5), (.5, 83, .5), (1, 81, .5), (1.5, 79, .5), (2, 76, 1), (3, 72, 1)],
        7: [(0, 74, 1.5), (1.5, 76, .5), (2, 78, 1), (3, 81, 1)],
    }
    brass_riff = [(0, 0, .4), (.75, 0, .4), (1.5, 1, .9), (3, 2, .4), (3.5, 1, .4)]
    tamb = [0, 3, 6, 8, 10, 13]
    cav = [0, 3, 6, 8, 11, 14]
    for bar, ch in enumerate(prog):
        sec = bar // 8
        s.hit("perc", surdo(r, 60, muted=True), bar, 0, pan=-0.2, gain=0.6)
        s.hit("kick", surdo(r, 52), bar, 1, pan=-0.2)
        s.hit("perc", surdo(r, 64, muted=True), bar, 2, pan=0.2, gain=0.5)
        s.hit("kick", surdo(r, 56), bar, 3, pan=0.2)
        for k in range(16):
            s.hit("shaker", shaker(r, vol=1.0 if k % 4 == 0 else (0.55 if k % 2 == 0 else 0.4)), bar, k * 0.25, pan=0.5)
        for k in tamb:
            s.hit("perc", tamborim(r, 1.0 if k in (0, 8) else 0.8), bar, k * 0.25, pan=0.35)
        for k in (0, 2, 4, 7, 10, 12, 14):
            s.hit("perc", pandeiro(r, slap=k in (4, 12)), bar, k * 0.25, pan=-0.45, gain=0.6)
        if sec != 0:
            for k, hi in ((0, True), (1.5, False), (2, True), (2.5, True), (3.5, False)):
                s.hit("perc", agogo(r, hi), bar, k, pan=0.6, gain=0.6)
        if bar % 4 == 3:
            s.hit("perc", cuica(r, True), bar, 2.5, pan=-0.6, gain=0.5)
            s.hit("perc", cuica(r, False), bar, 3.0, pan=-0.6, gain=0.5)
        s.hit("drums", snare(r, 0.15, 260, 0.6), bar, 1, pan=0.1, gain=0.3)
        s.hit("drums", snare(r, 0.15, 260, 0.6), bar, 3, pan=0.1, gain=0.35)
        # baixo: tônica no 1, quinta antecipada
        root = ch[0]
        s.note("bass", finger_bass, root - 12 + 12 * (root < 40), bar, 0, 1.2, gain=1.0)
        s.note("bass", finger_bass, root - 5 + 12 * (root < 40), bar, 1.75, 0.5, gain=0.8)
        s.note("bass", finger_bass, root - 12 + 12 * (root < 40), bar, 2, 0.9, gain=0.9)
        s.note("bass", finger_bass, root - 10 + 12 * (root < 40), bar, 3.5, 0.45, gain=0.7)
        # cavaquinho
        for k in cav:
            up = k in (3, 11)
            notes = [n + 12 for n in ch[1:]]
            for i, m in enumerate(notes if not up else notes[::-1]):
                s.note("cav", pluck, m, bar, k * 0.25 + i * 0.008 / s.beat, 0.4, pan=0.25, gain=0.32, bright=0.85, decay=0.994)
        # violão de base
        if sec in (1, 3):
            for k in (0, 2, 2.5):
                for i, m in enumerate(ch[1:]):
                    s.note("cav", pluck, m, bar, k + i * 0.012 / s.beat, 0.9, pan=-0.35, gain=0.25, bright=0.5)
        # melodia (flauta)
        if sec in (1, 3):
            for b, m, l in mel[bar % 8]:
                s.note("lead", flute, m, bar, b, l * 0.92, pan=0.0, gain=0.9)
        # metais
        if sec == 2:
            tones = [n + 12 for n in ch[2:]]
            for b, idx, l in brass_riff:
                s.chord("brass", brass, [tones[idx], tones[idx] + 12 if idx == 2 else tones[min(idx + 1, 2)]], bar, b, l, gain=0.7, spread=0.4)
        if sec == 3 and bar % 2 == 1:
            s.chord("brass", brass, [n + 12 for n in ch[2:]], bar, 2.5, 0.35, gain=0.55)
            s.chord("brass", brass, [n + 12 for n in ch[2:]], bar, 3.0, 0.8, gain=0.6)
    return s.mix({
        "kick": (0.95, 0.05, 0.0), "perc": (0.55, 0.12, 0.0), "shaker": (0.3, 0.05, 0.0), "drums": (0.5, 0.15, 0.0),
        "bass": (0.85, 0.0, 0.25), "cav": (0.6, 0.2, 0.1), "lead": (0.6, 0.3, 0.0), "brass": (0.6, 0.25, 0.0),
    }, reverb=1.5)


# ---------------------------------------------------------------------------
# 3. Noite de final — tensão cinematográfica em Lá menor, 96 bpm
# ---------------------------------------------------------------------------

def noite_de_final():
    s = Song(96, 32, 303)
    r = s.rng
    Am, F, C, G, Dm, E, Em = [45, 57, 60, 64], [41, 57, 60, 65], [48, 55, 60, 64], [43, 55, 59, 62], [38, 57, 62, 65], [40, 56, 59, 64], [40, 55, 59, 64]
    secA = [Am, F, C, G, Am, F, Dm, E]
    secB = [F, G, Am, Em, F, G, E, E]
    prog = secA + secA + secB + secA
    mel = {
        0: [(0, 69, 1.5), (1.5, 72, .5), (2, 76, 2)], 1: [(0, 77, 1.5), (1.5, 76, .5), (2, 72, 2)],
        2: [(0, 79, 2), (2, 76, 1), (3, 72, 1)], 3: [(0, 74, 3), (3, 71, 1)],
        4: [(0, 72, 1), (1, 76, 1), (2, 81, 2)], 5: [(0, 81, 1), (1, 79, .5), (1.5, 77, .5), (2, 76, 2)],
        6: [(0, 77, 1.5), (1.5, 76, .5), (2, 74, 2)], 7: [(0, 76, 2), (2, 80, 2)],
    }
    for bar, ch in enumerate(prog):
        sec = bar // 8
        intensity = [0.5, 0.8, 1.0, 0.85][sec]
        # ostinato de cordas em colcheias
        arp = [ch[1], ch[2], ch[3], ch[2] + 12 if sec else ch[2], ch[3], ch[2], ch[1] + 12, ch[2]]
        for e in range(8):
            s.note("strings", spiccato, arp[e], bar, e * 0.5, 0.5, pan=-0.35 + 0.1 * (e % 4), gain=0.8 * intensity + 0.2 * (e % 2 == 0))
        s.chord("pad", strings, [ch[0] + 12, ch[1], ch[3]], bar, 0, 4, gain=0.6 + 0.5 * (sec == 2), attack=0.5, bright=0.4)
        # baixo pulsante
        for e in range(8):
            s.note("bass", sub_bass, ch[0] - 12 + 12 * (ch[0] < 40), bar, e * 0.5, 0.4, gain=0.55 + 0.25 * (e % 2 == 0))
        # percussão
        if bar % 8 == 0:
            s.hit("perc", timpani(r, hz(ch[0] - 12 + 12 * (ch[0] < 40)) * 1.0), bar, 0, gain=0.9)
            s.hit("cym", crash(r, 3.0, 0.8), bar, 0, pan=0.3)
        if sec >= 1:
            s.hit("kick", kick(r, 0.7, tune=46), bar, 0)
            s.hit("kick", kick(r, 0.7, tune=46), bar, 2.5, gain=0.7)
            s.hit("drums", snare(r, 0.35, 170, 0.8), bar, 2, gain=0.55)
            for k, f in ((1.5, 95), (3, 120), (3.5, 105)):
                s.hit("perc", tom(r, f, 0.7), bar, k, pan=0.4 if f > 100 else -0.4, gain=0.55 * intensity)
        if sec == 2:
            for e in range(4):
                s.hit("perc", tom(r, 75, 0.9), bar, e, pan=-0.2, gain=0.5)
            s.chord("choir", lambda m, d, rr: voices(d + 0.6, rr, 5, hz(m) * 0.98, hz(m) * 1.02, "a", breath=0.08, female=0.0, onset=0.15,
                                                     env=lambda t: np.clip(t / 0.4, 0, 1) * np.clip((d + 0.6 - t) / 0.6, 0, 1))[0],
                    [ch[1], ch[2], ch[3]], bar, 0, 4, gain=0.9)
        # metais
        if bar % 4 == 3 or sec == 2:
            s.chord("brass", horn, [ch[0], ch[1], ch[2]], bar, 0 if sec == 2 else 2, 4 if sec == 2 else 2, gain=0.8 * intensity, spread=0.3)
        # melodia
        if sec == 1:
            for b, m, l in mel[bar % 8]:
                s.note("lead", horn, m - 12, bar, b, l, pan=0.1, gain=1.0)
        if sec == 3:
            for b, m, l in mel[bar % 8]:
                s.note("lead", strings, m, bar, b, l, pan=-0.1, gain=1.3, attack=0.08, bright=0.8)
                s.note("lead", horn, m - 12, bar, b, l, pan=0.2, gain=0.6)
        if sec == 0 and bar % 2 == 0:
            s.note("bells", bell, ch[3] + 24, bar, 0, 2, pan=0.4, gain=0.5)
    return s.mix({
        "strings": (0.55, 0.3, 0.1), "pad": (0.45, 0.45, 0.3), "bass": (0.7, 0.0, 0.3), "perc": (0.7, 0.3, 0.0),
        "kick": (0.9, 0.08, 0.0), "drums": (0.55, 0.3, 0.0), "cym": (0.3, 0.35, 0.0), "choir": (0.45, 0.5, 0.0),
        "brass": (0.55, 0.4, 0.0), "lead": (0.7, 0.4, 0.0), "bells": (0.45, 0.5, 0.0),
    }, reverb=2.8, damp=4500)


# ---------------------------------------------------------------------------
# 4. Vestiário — lo-fi tranquilo para os menus, Fá maior, 82 bpm com swing
# ---------------------------------------------------------------------------

def vestiario():
    s = Song(82, 24, 404, swing=0.32)
    r = s.rng
    Fm7, Em7, Dm7, Cm7, Bbm7, Am7, Gm7, C7 = [41, 57, 60, 64, 69], [40, 55, 59, 62, 67], [38, 53, 57, 60, 64], [36, 52, 55, 59, 64], [46, 57, 62, 65, 69], [45, 55, 60, 64, 67], [43, 53, 58, 62, 65], [48, 52, 58, 62, 65]
    prog = [Fm7, Em7, Dm7, Cm7, Bbm7, Am7, Gm7, C7] * 3
    mel = [(0, 81, 1.5), (2, 79, .5), (2.5, 76, 1.5)], [(.5, 74, .5), (1, 76, 1), (2.5, 72, 1.5)], \
          [(0, 77, 1), (1.5, 76, .5), (2, 74, 2)], [(.5, 72, .5), (1, 71, .5), (1.5, 67, 2)], \
          [(0, 74, 1), (1, 77, 1), (2, 81, 1.5)], [(0, 79, 1.5), (2, 76, 1), (3, 72, 1)], \
          [(0, 74, .5), (.5, 77, 1), (2, 74, 1), (3, 70, 1)], [(0, 72, 3)]
    for bar, ch in enumerate(prog):
        sec = bar // 8
        # bateria abafada (boom bap)
        s.hit("kick", kick(r, 0.5, dur=0.35, tune=48), bar, 0, gain=0.8)
        s.hit("kick", kick(r, 0.5, dur=0.35, tune=48), bar, 1.5 if bar % 2 else 2.5, gain=0.6)
        if bar % 4 == 3:
            s.hit("kick", kick(r, 0.5, dur=0.35, tune=48), bar, 2.5, gain=0.55)
        s.hit("drums", snare(r, 0.22, 210, 0.5), bar, 1, gain=0.5)
        s.hit("drums", snare(r, 0.22, 210, 0.5), bar, 3, gain=0.5)
        s.hit("drums", rim(r), bar, 3.5, gain=0.12 if bar % 2 else 0.0, pan=0.2)
        for e in range(8):
            s.hit("hats", hat(r, vol=0.8 if e % 2 == 0 else 0.45), bar, e * 0.5, pan=0.35)
        # piano elétrico
        for b, l in ((0, 1.4), (1.5, 0.4), (2.5, 1.3)):
            s.chord("keys", epiano, ch[1:], bar, b, l, spread=0.6, gain=0.8, bright=0.7)
        # baixo
        s.note("bass", finger_bass, ch[0] - 12 + 12 * (ch[0] < 40), bar, 0, 1.4, gain=1.0)
        s.note("bass", finger_bass, ch[0] - 5 + 12 * (ch[0] < 40), bar, 2.5, 1.0, gain=0.8)
        # melodia
        if sec >= 1:
            for b, m, l in mel[bar % 8]:
                s.note("lead", mallet if sec == 1 else epiano, m + (0 if sec == 1 else 12), bar, b, l, pan=0.2, gain=0.8 if sec == 1 else 0.55)
    # chiado de vinil (sempre o mesmo, emenda no loop)
    n = s.n
    crack = np.zeros(n)
    idx = r.integers(0, n, int(n / SR * 9))
    crack[idx] = r.uniform(-1, 1, len(idx))
    hiss = lp(r.standard_normal(n), 5000) * 0.015
    vinyl = bp(crack, 800, 6000) * 0.6 + hiss
    s.add("vinyl", 0.0, vinyl, 0.0, 1.0)
    out = s.mix({
        "kick": (0.9, 0.0, 0.0), "drums": (0.6, 0.15, 0.0), "hats": (0.3, 0.05, 0.0), "keys": (0.65, 0.3, 0.35),
        "bass": (0.8, 0.0, 0.3), "lead": (0.55, 0.35, 0.0), "vinyl": (0.35, 0.0, 0.0),
    }, reverb=1.6, damp=4000, drive=1.4)
    # timbre de fita: tira um pouco de agudo
    out = np.array([lp(c, 7000, 1) for c in out])
    return out / np.max(np.abs(out)) * 0.89


# ---------------------------------------------------------------------------
# 5. Prancheta — eletrônica leve para pensar a tática, Mi menor, 112 bpm
# ---------------------------------------------------------------------------

def prancheta():
    s = Song(112, 32, 505)
    r = s.rng
    Em, Cmaj7, G, D, Am, B7 = [40, 55, 59, 64, 67], [36, 55, 59, 64, 67], [43, 55, 59, 62, 67], [38, 54, 57, 62, 66], [45, 57, 60, 64, 69], [47, 54, 59, 63, 66]
    prog = [Em, Cmaj7, G, D] * 4 + [Am, Em, Cmaj7, B7] * 2 + [Em, Cmaj7, G, D] * 2
    for bar, ch in enumerate(prog):
        sec = bar // 8
        k = kick(r, 0.6, 0.3, 52)
        for b in range(4):
            if sec > 0 or b in (0, 2):
                s.hit("kick", k, bar, b, gain=0.75)
        if sec >= 1:
            s.hit("drums", clap(r), bar, 1, gain=0.35, pan=0.1)
            s.hit("drums", clap(r), bar, 3, gain=0.35, pan=0.1)
        for e in range(16):
            if e % 2 == 1 or sec >= 2:
                s.hit("hats", hat(r, vol=0.7 if e % 4 == 2 else 0.35), bar, e * 0.25, pan=0.4)
        # arpejo em semicolcheias com o filtro abrindo ao longo da faixa
        tones = [ch[1] + 12, ch[2] + 12, ch[3] + 12, ch[4] + 12]
        pattern = [0, 1, 2, 3, 2, 1, 3, 2, 0, 2, 1, 3, 2, 3, 1, 2]
        cut = 900 + 2600 * (0.5 - 0.5 * np.cos(2 * np.pi * bar / 16))
        for e in range(16):
            s.note("arp", arp_pluck, tones[pattern[e]], bar, e * 0.25, 0.3, pan=0.5 * np.sin(e), gain=0.55, cutoff=cut)
        s.chord("pad", pad, [n + 12 for n in ch[1:4]], bar, 0, 4, gain=0.5, bright=0.35, attack=0.8)
        for e in range(8):
            s.note("bass", sub_bass, ch[0] - 12 + 12 * (ch[0] < 40), bar, e * 0.5 + 0.5 * (e % 2 == 0 and sec == 0), 0.35, gain=0.7)
        if sec == 2 and bar % 2 == 0:
            s.note("lead", bell, ch[4] + 12, bar, 0, 2, pan=-0.3, gain=0.6)
            s.note("lead", bell, ch[3] + 12, bar, 2, 2, pan=0.3, gain=0.5)
        if bar % 8 == 0:
            s.hit("cym", crash(r, 2.0, 0.5), bar, 0)
    return s.mix({
        "kick": (0.9, 0.0, 0.0), "drums": (0.5, 0.25, 0.0), "hats": (0.3, 0.1, 0.0), "arp": (0.55, 0.35, 0.3),
        "pad": (0.5, 0.4, 0.55), "bass": (0.8, 0.0, 0.5), "lead": (0.55, 0.45, 0.0), "cym": (0.25, 0.3, 0.0),
    }, reverb=2.2)


TRACKS = [
    ("dia_de_jogo", dia_de_jogo),
    ("arquibancada", arquibancada),
    ("noite_de_final", noite_de_final),
    ("vestiario", vestiario),
    ("prancheta", prancheta),
]
