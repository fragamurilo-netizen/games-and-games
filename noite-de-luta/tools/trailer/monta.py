# Monta o trailer vertical 1080x1920 a partir das gravações do Movie Maker.
import re, subprocess, sys, os
D = os.path.dirname(os.path.abspath(__file__))
HD = D + "/hd"
OUT = sys.argv[1]
FPS = 30


def clips(log):
    r = {}
    for m in re.finditer(r"\[trecho\] (\S+) (\d+) (\d+)", open(log).read()):
        r[m.group(1)] = (int(m.group(2)), int(m.group(3)))
    return r


CA = clips(HD + "/a.log"); CB = clips(HD + "/b.log")
# (fonte, trecho, deslocamento s, duração s, corte vertical, legenda, flash)
SEG = [
    ("a", "abertura", 0.0, 4.8, 209, None, False),
    ("a", "inicio", 0.5, 3.6, 0, "inicio", True),
    ("a", "ficha", 0.3, 3.0, 0, "ficha", False),
    ("a", "plano", 0.5, 2.4, 0, "plano", False),
    ("a", "luta", 4.0, 6.0, 0, "luta", False),
    ("a", "luta_rapida", 2.0, 2.4, 0, None, False),
    ("a", "resultado", 0.3, 2.4, 0, "resultado", False),
    ("b", "card_vazio", 0.0, 1.2, 0, "card", True),
    ("b", "card_cheio", 0.2, 2.4, 0, "card", False),
    ("b", "sede", 0.4, 3.0, 0, "sede", False),
    ("b", "noite", 0.5, 2.4, 0, None, False),
    ("b", "principal", 1.0, 4.8, 0, "principal", False),
    ("b", "principal_fim", 0.2, 2.4, 0, None, False),
    ("a", "visual", 0.8, 3.6, 0, "visual", False),
    ("a", "gala", float(os.environ.get("GALA_OFF", "2.0")), 3.6, 0, "gala", False),
]
os.makedirs(D + "/seg", exist_ok=True)
lst = []
t = 0.0
for i, (src, name, off, dur, cy, cap, flash) in enumerate(SEG):
    c = (CA if src == "a" else CB)[name]
    start = c[0] / FPS + off
    avail = (c[1] - c[0]) / FPS - off
    if avail < dur - 0.01:
        print("AVISO trecho curto", name, avail, dur)
    o = f"{D}/seg/{i:02d}.mp4"
    f = f"[0:v]scale=1080:2338:flags=lanczos,crop=1080:1920:0:{cy},setsar=1,fps={FPS}"
    inputs = ["-ss", f"{start:.3f}", "-t", f"{dur:.3f}", "-i", f"{HD}/{src}.avi"]
    if cap:
        inputs += ["-loop", "1", "-t", f"{dur:.3f}", "-i", f"{D}/cart/cap_{cap}.png"]
        f += "[v];[v][1:v]overlay=0:0:shortest=1"
    if flash:
        f += ",fade=t=in:st=0:d=0.18:color=white"
    f += f",trim=duration={dur:.3f}[o]"
    subprocess.run(["ffmpeg", "-v", "error", "-y", *inputs, "-filter_complex", f, "-map", "[o]", "-an",
                    "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-pix_fmt", "yuv420p", "-r", str(FPS), o], check=True)
    lst.append(o)
    print(f"{t:5.1f}s {name} {dur}")
    t += dur
# Cartela final com zoom lento.
o = f"{D}/seg/99.mp4"
import shutil; shutil.copy(D + "/final99.mp4", o); lst.append(o)
print(f"{t:5.1f}s final 5.0")
with open(D + "/seg/lista.txt", "w") as fh:
    for p in lst:
        fh.write(f"file '{p}'\n")
subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "concat", "-safe", "0", "-i", D + "/seg/lista.txt", "-i", D + "/trilha.wav",
                "-map", "0:v", "-map", "1:a", "-c:v", "copy", "-c:a", "aac", "-b:a", "192k", "-shortest", "-movflags", "+faststart", OUT], check=True)
print("ok", OUT)
