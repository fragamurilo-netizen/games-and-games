"""Sons sintetizados (sem amostras de terceiros). Luta: soco, soco forte, chute, bloqueio, queda
e gongo. Interface: week, score, cash, mail e sheet. WAV mono 16 bits, 22050 Hz.
Uso: python3 gera_sons.py PASTA_DE_SAIDA"""
import sys, wave
import numpy as np

SR = 22050
rng = np.random.default_rng(7)


def t(n):
    return np.arange(int(n * SR)) / SR


def band(noise, lo, hi):
    f = np.fft.rfft(noise)
    fr = np.fft.rfftfreq(len(noise), 1 / SR)
    gain = 1 / (1 + (lo / np.maximum(fr, 1e-6)) ** 4) / (1 + (fr / hi) ** 4)
    return np.fft.irfft(f * gain, len(noise))


def sweep(dur, f0, f1, tau, drop=0.03):
    x = t(dur)
    f = f1 + (f0 - f1) * np.exp(-x / drop)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-x / tau)


def burst(dur, lo, hi, tau):
    x = t(dur)
    n = band(rng.standard_normal(len(x)), lo, hi)
    n /= np.max(np.abs(n)) + 1e-9
    return n * np.exp(-x / tau)


def tone(dur, f, tau, harm=((1, 1.0), (2, 0.22), (3, 0.07))):
    x = t(dur)
    sig = sum(a * np.sin(2 * np.pi * f * h * x) for h, a in harm)
    return sig * np.exp(-x / tau)


def swish(dur, lo, hi):
    x = t(dur)
    n = band(rng.standard_normal(len(x)), lo, hi)
    n /= np.max(np.abs(n)) + 1e-9
    return n * np.sin(np.pi * x / dur) ** 2


def mix(total, pieces):
    out = np.zeros(int(total * SR))
    for start, sig in pieces:
        i = int(start * SR)
        n = min(len(sig), len(out) - i)
        out[i:i + n] += sig[:n]
    return out


def finish(sig, peak, attack=0.002, drive=1.0):
    sig = np.tanh(sig * drive)
    a = int(attack * SR)
    sig[:a] *= np.linspace(0, 1, a)
    tail = int(0.012 * SR)
    sig[-tail:] *= np.linspace(1, 0, tail)
    return sig / (np.max(np.abs(sig)) + 1e-9) * peak


def save(path, sig):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((np.clip(sig, -1, 1) * 32767).astype("<i2").tobytes())


def main(out):
    s = {}
    s["soco"] = finish(0.7 * sweep(0.13, 190, 75, 0.032) + 0.5 * burst(0.13, 700, 3800, 0.011), 0.62, drive=1.3)
    s["soco_forte"] = finish(1.0 * sweep(0.28, 150, 46, 0.07) + 0.55 * sweep(0.28, 70, 38, 0.11, 0.05)
        + 0.6 * burst(0.28, 400, 2600, 0.022), 0.8, drive=1.8)
    s["chute"] = finish(0.6 * sweep(0.2, 170, 62, 0.045) + 0.75 * burst(0.2, 1100, 5200, 0.017), 0.7, drive=1.4)
    s["bloqueio"] = finish(0.5 * sweep(0.1, 230, 140, 0.02) + 0.4 * burst(0.1, 300, 1600, 0.01), 0.45)
    s["queda"] = finish(1.0 * sweep(0.5, 85, 36, 0.13, 0.06) + 0.5 * burst(0.5, 60, 650, 0.08)
        + 0.12 * burst(0.5, 1800, 6000, 0.12), 0.85, drive=1.6)
    x = t(1.7)
    bell = np.zeros(len(x))
    for ratio, amp, tau in [(1.0, 1.0, 0.85), (2.0, 0.55, 0.55), (2.76, 0.45, 0.42), (3.3, 0.22, 0.32), (4.07, 0.2, 0.24), (5.43, 0.12, 0.17)]:
        bell += amp * np.sin(2 * np.pi * 660 * ratio * x + rng.uniform(0, 6.28)) * np.exp(-x / tau)
    bell += 0.5 * np.concatenate([burst(0.03, 1500, 7000, 0.004), np.zeros(len(x) - int(0.03 * SR))])
    s["gongo"] = finish(bell, 0.5, attack=0.001, drive=0.8)
    # Sons de interface (0.5): semana que vira, cartão de juiz, dinheiro entrando, novidade na
    # caixa de entrada e folha que abre. Curtos, na mesma tonalidade (sol maior), sem agudos duros.
    s["week"] = finish(mix(0.62, [(0.0, 0.35 * swish(0.26, 500, 3200)), (0.12, 0.8 * tone(0.3, 392.0, 0.085)),
        (0.22, 0.9 * tone(0.4, 587.33, 0.12))]), 0.42, attack=0.004, drive=0.9)
    s["score"] = finish(mix(0.2, [(0.0, 0.7 * sweep(0.12, 300, 170, 0.028) + 0.3 * burst(0.12, 1800, 6000, 0.007)),
        (0.012, 0.35 * tone(0.18, 783.99, 0.05))]), 0.5, drive=1.1)
    s["cash"] = finish(mix(0.42, [(0.0, 0.7 * tone(0.3, 1318.5, 0.07, ((1, 1.0), (2.76, 0.3), (5.4, 0.1)))),
        (0.075, 0.9 * tone(0.34, 1975.5, 0.1, ((1, 1.0), (2.76, 0.25), (5.4, 0.08))))]), 0.36, attack=0.001, drive=0.8)
    s["mail"] = finish(mix(0.4, [(0.0, 0.8 * tone(0.2, 587.33, 0.06, ((1, 1.0), (2, 0.12)))),
        (0.11, 0.9 * tone(0.28, 783.99, 0.085, ((1, 1.0), (2, 0.12))))]), 0.4, attack=0.004, drive=0.8)
    s["sheet"] = finish(0.9 * sweep(0.1, 240, 140, 0.03) + 0.12 * burst(0.1, 900, 3000, 0.01), 0.3)
    for name, sig in s.items():
        save("%s/%s.wav" % (out, name), sig)
        spec = np.abs(np.fft.rfft(sig))
        fr = np.fft.rfftfreq(len(sig), 1 / SR)
        print("%-11s %.2fs pico %.2f rms %.3f centro %.0f Hz" % (name, len(sig) / SR, np.max(np.abs(sig)), np.sqrt(np.mean(sig ** 2)), np.sum(fr * spec) / np.sum(spec)))


main(sys.argv[1])
