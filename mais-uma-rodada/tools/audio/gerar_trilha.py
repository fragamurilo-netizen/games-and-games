"""Gera a trilha sonora do jogo em assets/audio/ (músicas em OGG, efeitos em WAV/OGG).

Uso (dentro de mais-uma-rodada/):  python3 tools/audio/gerar_trilha.py [musica|efeitos|NOME ...]
Precisa de numpy, scipy e ffmpeg. É determinístico: mesma semente, mesmo som."""
import os
import subprocess
import sys
import tempfile
import time

import numpy as np
import scipy.io.wavfile as wf

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from synth import SR  # noqa: E402
import musica  # noqa: E402
import efeitos  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_MUSIC = os.path.join(ROOT, "assets", "audio", "musica")
OUT_SFX = os.path.join(ROOT, "assets", "audio", "efeitos")
# Efeitos longos (torcida, vinhetas) vão em OGG; os curtos ficam em WAV para tocar sem atraso.
OGG_SFX = {"achievement", "win", "lose", "title", "chance", "groan", "boo", "applause", "goal_roar", "goal", "goal_big", "post",
           "whistle_end", "whistle_half"}


def to_int16(x):
    x = np.clip(x, -1.0, 1.0)
    return (x.T if x.ndim == 2 else x) * 32767.0


def write_wav(path, x):
    wf.write(path, SR, to_int16(x).astype(np.int16))


def write_ogg(path, x, q=4):
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        write_wav(tmp.name, x)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp.name, "-c:a", "libvorbis", "-q:a", str(q), path], check=True)
    os.unlink(tmp.name)


def main(args):
    want = set(args)
    os.makedirs(OUT_MUSIC, exist_ok=True)
    os.makedirs(OUT_SFX, exist_ok=True)
    if not want or "musica" in want or want & {n for n, _ in musica.TRACKS}:
        for name, fn in musica.TRACKS:
            if want and "musica" not in want and name not in want:
                continue
            t0 = time.time()
            x = fn()
            # mesmo volume percebido entre as faixas (RMS -14 dB), sem passar do pico
            rms = np.sqrt(np.mean(x ** 2))
            x = x * min(10 ** (-14 / 20) / rms, 0.92 / np.max(np.abs(x)))
            write_ogg(os.path.join(OUT_MUSIC, name + ".ogg"), x, 3)
            print(f"música {name}: {x.shape[1] / SR:.1f}s em {time.time() - t0:.0f}s")
    if not want or "efeitos" in want or want - {"musica"} - {n for n, _ in musica.TRACKS}:
        t0 = time.time()
        fx = efeitos.build()
        for name, x in fx.items():
            if want and "efeitos" not in want and name not in want:
                continue
            for ext in ("wav", "ogg"):
                old = os.path.join(OUT_SFX, f"{name}.{ext}")
                if os.path.exists(old):
                    os.unlink(old)
            if name in OGG_SFX:
                write_ogg(os.path.join(OUT_SFX, name + ".ogg"), x, 4)
            else:
                write_wav(os.path.join(OUT_SFX, name + ".wav"), x)
        print(f"efeitos: {len(fx)} em {time.time() - t0:.0f}s")


if __name__ == "__main__":
    main(sys.argv[1:])
