#!/usr/bin/env python3
"""Recomprime um APK com zopfli (deflate mais forte, ~2-3% menor) e reassina com a chave de debug.
Uso: python3 tools/shrink_apk.py entrada.apk saida.apk   (precisa de: pip install zopfli; $SIGNER)"""
import os, subprocess, sys, tempfile, zipfile
import zopfli.zlib as zz

src, dst = sys.argv[1], sys.argv[2]


class Z:
    def __init__(s): s.b = []
    def compress(s, d): s.b.append(d); return b""
    def flush(s): return zz.compress(b"".join(s.b), numiterations=3)[2:-4]


orig = zipfile._get_compressor
zipfile._get_compressor = lambda t, l=None: Z() if t == zipfile.ZIP_DEFLATED else orig(t, l)
work = tempfile.mkdtemp()
unsigned = os.path.join(work, "unsigned.apk")
with zipfile.ZipFile(src) as zi, zipfile.ZipFile(unsigned, "w") as zo:
    for it in zi.infolist():
        if it.filename.startswith("META-INF/"):
            continue
        ni = zipfile.ZipInfo(it.filename, it.date_time)
        ni.external_attr = it.external_attr
        ni.compress_type = it.compress_type
        zo.writestr(ni, zi.read(it))
signer = os.environ.get("SIGNER", "/opt/apk/signer.jar")
subprocess.run(["java", "-jar", signer, "-a", unsigned, "-o", os.path.join(work, "signed"), "--allowResign"], check=True, stdout=subprocess.DEVNULL)
out = [f for f in os.listdir(os.path.join(work, "signed")) if f.endswith(".apk")][0]
os.replace(os.path.join(work, "signed", out), dst)
print(dst, os.path.getsize(dst))
