#!/usr/bin/env python3
"""Confere se o projeto está pronto para gerar o AAB da Google Play.

Uso (na pasta mais-uma-rodada/):
    python3 tools/release_check.py

Verifica: versão igual no project.godot e nos presets Android, version/code, ícones do
lançador, plugin de compras, filtros de exportação, textos da ficha da loja (limites da
Play Console), ícone 512, banner 1024x500, capturas de tela (2 a 8), política de
privacidade, traduções válidas e que nenhuma chave de assinatura esteja no repositório.
Sai com código 1 se algo impedir a publicação.
"""
import glob
import json
import os
import re
import struct
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STORE = os.path.join(os.path.dirname(ROOT), "store")
errors = []
warnings = []


def err(msg):
    errors.append(msg)


def warn(msg):
    warnings.append(msg)


def png_size(path):
    with open(path, "rb") as f:
        head = f.read(24)
    if head[:8] != b"\x89PNG\r\n\x1a\n":
        return None
    return struct.unpack(">II", head[16:24])


def res_path(res):
    return os.path.join(ROOT, res.replace("res://", ""))


class GodotCfg:
    """Leitor mínimo do formato .cfg/.godot (seções [x] e linhas chave=valor)."""

    def __init__(self, path):
        self.data = {"": {}}
        sec = ""
        with open(path, encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line == "" or line.startswith(";"):
                    continue
                m = re.fullmatch(r"\[([^\]]+)\]", line)
                if m:
                    sec = m.group(1)
                    self.data.setdefault(sec, {})
                elif "=" in line:
                    k, _, v = line.partition("=")
                    self.data[sec][k.strip()] = v.strip()

    def sections(self):
        return list(self.data.keys())

    def get(self, sec, key, fallback=None):
        return self.data.get(sec, {}).get(key, fallback)


def read_godot_cfg(path):
    return GodotCfg(path)


def unq(v):
    return v.strip().strip('"') if v is not None else ""


# --- Versão -------------------------------------------------------------------
proj = read_godot_cfg(os.path.join(ROOT, "project.godot"))
version = unq(proj.get("application", "config/version", fallback=""))
if not re.fullmatch(r"\d+\.\d+\.\d+", version):
    err("project.godot: config/version inválida (%r)" % version)

presets = read_godot_cfg(os.path.join(ROOT, "export_presets.cfg"))
android = []
for sec in presets.sections():
    if re.fullmatch(r"preset\.\d+", sec) and unq(presets.get(sec, "platform", fallback="")) == "Android":
        android.append((unq(presets.get(sec, "name")), sec + ".options", sec))
if not android:
    err("export_presets.cfg: nenhum preset Android")
codes = set()
release = None
for name, opts, sec in android:
    vname = unq(presets.get(opts, "version/name", fallback=""))
    code = int(unq(presets.get(opts, "version/code", fallback="0")) or 0)
    codes.add(code)
    if vname != version:
        err("preset %s: version/name %s ≠ config/version %s" % (name, vname, version))
    if code <= 0:
        err("preset %s: version/code inválido" % name)
    excl = unq(presets.get(sec, "exclude_filter", fallback=""))
    for need in ("tests/*", "tools/*"):
        if need not in excl:
            warn("preset %s: exclude_filter sem %s (APK maior)" % (name, need))
    if not unq(presets.get(opts, "architectures/arm64-v8a", fallback="false")) == "true":
        err("preset %s: sem arm64-v8a (exigido pela Play)" % name)
    for key in ("launcher_icons/main_192x192", "launcher_icons/adaptive_foreground_432x432",
                "launcher_icons/adaptive_background_432x432"):
        icon = unq(presets.get(opts, key, fallback=""))
        want = 192 if "192" in key else 432
        if icon == "" or not os.path.exists(res_path(icon)):
            err("preset %s: ícone %s não encontrado" % (name, key))
        else:
            size = png_size(res_path(icon))
            if size is not None and size != (want, want):
                warn("preset %s: %s tem %dx%d (esperado %dx%d)" % (name, key, size[0], size[1], want, want))
    if unq(presets.get(opts, "gradle_build/use_gradle_build", fallback="false")) == "true" \
            and unq(presets.get(opts, "gradle_build/export_format", fallback="0")) == "1":
        release = name
if len(codes) > 1:
    err("version/code diferente entre os presets Android: %s" % sorted(codes))
if release is None:
    err("nenhum preset Android gera AAB (Gradle + export_format=1)")

# version/code precisa subir a cada envio: compara com o último commit que mexeu nos presets.
try:
    prev = subprocess.run(["git", "log", "-1", "--format=%H", "HEAD~1", "--", "export_presets.cfg"],
                          cwd=ROOT, capture_output=True, text=True).stdout.strip()
    if prev:
        old = subprocess.run(["git", "show", "%s:./export_presets.cfg" % prev], cwd=ROOT,
                             capture_output=True, text=True).stdout
        old_codes = [int(c) for c in re.findall(r"^version/code=(\d+)", old, re.M)]
        if old_codes and codes and max(codes) < max(old_codes):
            err("version/code (%d) menor que o de antes (%d)" % (max(codes), max(old_codes)))
except (OSError, ValueError):
    pass

# --- Plugin de compras --------------------------------------------------------
plugins = proj.get("editor_plugins", "enabled", fallback="")
if "GodotGooglePlayBilling" not in plugins:
    err("project.godot: plugin GodotGooglePlayBilling desligado (compras não funcionam)")
if not os.path.exists(os.path.join(ROOT, "addons", "GodotGooglePlayBilling", "plugin.cfg")):
    err("addons/GodotGooglePlayBilling ausente")

# --- Ficha da loja -------------------------------------------------------------
LIMITS = {"title": 30, "short": 80, "full": 4000}
for path in sorted(glob.glob(os.path.join(STORE, "play-store-*.txt"))):
    text = open(path, encoding="utf-8").read()
    blocks = re.split(r"\n(?=[A-ZÁÉÍÓÚÇÃÕ' ]+(?:\([^)]*\))?\n)", "\n" + text)
    parts = {}
    for b in blocks:
        b = b.strip("\n")
        if not b:
            continue
        head, _, body = b.partition("\n")
        parts[head.strip()] = body.strip()
    heads = list(parts.keys())
    title = parts.get(heads[0], "") if heads else ""
    short = parts.get(heads[1], "") if len(heads) > 1 else ""
    full = parts.get(heads[2], "") if len(heads) > 2 else ""
    name = os.path.basename(path)
    for kind, val in (("title", title), ("short", short), ("full", full)):
        if val == "":
            err("%s: bloco %s vazio" % (name, kind))
        elif len(val) > LIMITS[kind]:
            err("%s: %s com %d caracteres (máximo %d)" % (name, kind, len(val), LIMITS[kind]))
    news = [parts[h] for h in heads[3:] if version in h]
    if not news:
        warn("%s: sem as novidades da versão %s" % (name, version))
    elif len(news[0]) > 500:
        err("%s: novidades com %d caracteres (máximo 500)" % (name, len(news[0])))

for fname, want in (("icon-512.png", (512, 512)), ("feature-graphic-1024x500.png", (1024, 500))):
    p = os.path.join(STORE, fname)
    if not os.path.exists(p):
        err("store/%s ausente" % fname)
    elif png_size(p) != want:
        err("store/%s com tamanho %s (esperado %dx%d)" % (fname, png_size(p), want[0], want[1]))

shots = sorted(glob.glob(os.path.join(STORE, "screenshots", "*.png")))
if len(shots) < 2:
    err("store/screenshots: %d captura(s) (a Play pede de 2 a 8)" % len(shots))
elif len(shots) > 8:
    warn("store/screenshots: %d capturas (a Play aceita até 8 por tipo de aparelho)" % len(shots))
for p in shots:
    s = png_size(p)
    if s is None or min(s) < 320 or max(s) > 3840 or max(s) > 2 * min(s):
        err("%s: tamanho %s fora do padrão da Play (lados 320-3840, proporção até 2:1)" % (os.path.basename(p), s))

if not os.path.exists(os.path.join(STORE, "politica-de-privacidade.html")):
    err("store/politica-de-privacidade.html ausente (obrigatória com compras no app)")
else:
    # Cópia publicada pelo GitHub Pages (Settings → Pages → main, pasta /docs)
    pages = os.path.join(os.path.dirname(ROOT), "docs", "privacidade", "index.html")
    if not os.path.exists(pages) or open(pages, "rb").read() != open(os.path.join(STORE, "politica-de-privacidade.html"), "rb").read():
        err("docs/privacidade/index.html diferente de store/politica-de-privacidade.html (copie de novo)")

# --- Traduções e segredos --------------------------------------------------------
for p in glob.glob(os.path.join(ROOT, "data", "i18n", "*.json")):
    try:
        json.load(open(p, encoding="utf-8"))
    except ValueError as e:
        err("%s inválido: %s" % (os.path.relpath(p, ROOT), e))

tracked = subprocess.run(["git", "ls-files"], cwd=os.path.dirname(ROOT), capture_output=True, text=True).stdout.split("\n")
for f in tracked:
    if re.search(r"\.(jks|keystore)$|export_credentials\.cfg$", f):
        err("chave de assinatura no repositório: %s" % f)

# --- Resultado --------------------------------------------------------------------
print("Mais Uma Rodada %s · version/code %s · AAB pelo preset %r" % (version, ",".join(map(str, sorted(codes))), release))
for w in warnings:
    print("  aviso: " + w)
for e in errors:
    print("  ERRO:  " + e)
print("RELEASE_CHECK " + ("OK" if not errors else "FALHOU (%d)" % len(errors)))
sys.exit(1 if errors else 0)
