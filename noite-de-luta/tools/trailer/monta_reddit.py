# Monta o vídeo 4:5 (1080x1350) para o Reddit a partir das gravações do Movie Maker (780x1688).
# uso: python3 monta_reddit.py PASTA saida.mp4   (PASTA tem hd/a.avi, a.log, b.avi, b.log, cart/, trilha.wav)
import re, subprocess, sys, os
W_DIR = sys.argv[1]
OUT = sys.argv[2]
HD = W_DIR + "/hd"
FPS = 30
W, H, SCALED_H = 1080, 1350, 2338


def clips(log):
    r = {}
    for m in re.finditer(r"\[trecho\] (\S+) (\d+) (\d+)", open(log).read()):
        r[m.group(1)] = (int(m.group(2)), int(m.group(3)))
    return r


CA = clips(HD + "/a.log"); CB = clips(HD + "/b.log")
# (fonte, trecho, deslocamento s, duração s, corte vertical inicial, corte final, legenda, flash)
SEG = [
    ("a", "luta_rapida", 2.0, 3.6, 0, 0, "gancho", False),
    ("a", "inicio", 0.3, 2.4, 0, 120, "inicio", True),
    ("a", "ficha", 0.3, 2.4, 0, 0, "ficha", False),
    ("a", "plano", 0.2, 1.8, 0, 0, "plano", False),
    ("a", "luta", 6.2, 4.8, 330, 988, "luta", False),
    ("a", "resultado", 0.3, 2.4, 0, 0, None, False),
    ("b", "card_cheio", 0.2, 2.4, 0, 200, "card", True),
    ("b", "sede", 0.4, 1.8, 0, 100, "sede", False),
    ("b", "principal", 8.0, 3.6, 0, 0, "principal", False),
    ("a", "visual", 0.8, 2.4, 0, 0, "visual", False),
]
if os.environ.get("TR_SEG"):
    SEG = eval(open(os.environ["TR_SEG"]).read())
os.makedirs(W_DIR + "/seg", exist_ok=True)
lst = []
t = 0.0
for i, (src, name, off, dur, cy0, cy1, cap, flash) in enumerate(SEG):
    c = (CA if src == "a" else CB)[name]
    start = c[0] / FPS + off
    avail = (c[1] - c[0]) / FPS - off
    if avail < dur - 0.01:
        print("AVISO trecho curto", name, avail, dur)
    o = f"{W_DIR}/seg/{i:02d}.mp4"
    cy = f"{cy0}+({cy1}-{cy0})*min(t/{dur * 0.6:.3f}\\,1)" if cy0 != cy1 else str(cy0)
    f = f"[0:v]scale={W}:{SCALED_H}:flags=lanczos,crop={W}:{H}:0:'{cy}',setsar=1,fps={FPS}"
    inputs = ["-ss", f"{start:.3f}", "-t", f"{dur:.3f}", "-i", f"{HD}/{src}.avi"]
    if cap:
        inputs += ["-loop", "1", "-t", f"{dur:.3f}", "-i", f"{W_DIR}/cart/cap_{cap}.png"]
        f += "[v];[v][1:v]overlay=0:0:shortest=1"
    if flash:
        f += ",fade=t=in:st=0:d=0.15:color=white"
    f += f",trim=duration={dur:.3f}[o]"
    subprocess.run(["ffmpeg", "-v", "error", "-y", *inputs, "-filter_complex", f, "-map", "[o]", "-an",
                    "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-pix_fmt", "yuv420p", "-r", str(FPS), o], check=True)
    lst.append(o)
    print(f"{t:5.1f}s {name} {dur}")
    t += dur
# Cartela final com zoom lento.
END_DUR = 3.6
o = f"{W_DIR}/seg/99.mp4"
subprocess.run(["ffmpeg", "-v", "error", "-y", "-loop", "1", "-t", f"{END_DUR}", "-i", f"{W_DIR}/cart/final.png", "-filter_complex",
                f"[0:v]scale={W*2}:{H*2},zoompan=z='1+0.05*on/{int(END_DUR*FPS)}':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=1:s={W}x{H}:fps={FPS},fade=t=in:st=0:d=0.15:color=white,trim=duration={END_DUR}[o]",
                "-map", "[o]", "-an", "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-pix_fmt", "yuv420p", "-r", str(FPS), o], check=True)
lst.append(o)
print(f"{t:5.1f}s final {END_DUR}  total {t + END_DUR:.1f}")
with open(W_DIR + "/seg/lista.txt", "w") as fh:
    for p in lst:
        fh.write(f"file '{p}'\n")
subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "concat", "-safe", "0", "-i", W_DIR + "/seg/lista.txt", "-i", W_DIR + "/trilha.wav",
                "-map", "0:v", "-map", "1:a", "-c:v", "copy", "-c:a", "aac", "-b:a", "192k", "-shortest", "-movflags", "+faststart", OUT], check=True)
print("ok", OUT)
