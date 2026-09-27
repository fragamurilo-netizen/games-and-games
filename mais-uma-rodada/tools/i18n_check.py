#!/usr/bin/env python3
"""Lista textos do jogo que ainda não têm tradução em data/i18n/<idioma>.json.

Uso (na pasta mais-uma-rodada/):
    python3 tools/i18n_check.py            # resumo do que falta em cada idioma
    python3 tools/i18n_check.py --list     # mostra cada texto que falta, com arquivo:linha
    python3 tools/i18n_check.py --write    # acrescenta os que faltam com valor "" (para preencher)

Chaves com valor "" são ignoradas pelo jogo, que mostra o português no lugar.
Os textos são coletados das strings dos scripts e cenas e dos campos de texto dos JSON de dados.
A coleta é por heurística: alguns textos internos aparecem; deixe-os com "" (ou copie o original).
"""
import glob
import json
import re
import sys
from collections import OrderedDict

LANGS = ["en", "es"]
LIT = re.compile(r'(?<![&^])"((?:[^"\\\n]|\\.)*)"')
# Linhas cujas strings nunca chegam à tela.
SKIP_LINE = re.compile(
    r"theme_type_variation|add_theme_|get_theme_|has_theme_|StringName|&\"|\bconnect\(|emit_signal|"
    r"has_method|\bicon\(|preload\(|load\(|push_warning|push_error|print\(|assert\(|\bmatch\b|get_node|"
    r"set_meta|get_meta|has_meta|\.play\(|Color\(|class_name|extends"
)
DATA_KEYS = {"name", "tag", "desc", "short", "label", "title", "text", "t", "b"}


def code_strings():
    found = OrderedDict()
    files = sorted(glob.glob("scripts/**/*.gd", recursive=True) + glob.glob("scenes/**/*.tscn", recursive=True))
    for f in files:
        for i, line in enumerate(open(f, encoding="utf8"), 1):
            s = line.strip()
            if s.startswith("#") or s.startswith("##"):
                continue
            if f.endswith(".tscn") and not re.match(r"(text|placeholder_text|tooltip_text) = ", s):
                continue
            if SKIP_LINE.search(line):
                continue
            for m in LIT.finditer(line):
                t = unescape(m.group(1))
                if keep(t) or ui_word(t, line, m, f.startswith("scripts/ui/")):
                    found.setdefault(t, []).append(f"{f}:{i}")
    return found


def unescape(t):
    return re.sub(r"\\(.)", lambda m: {"n": "\n", "t": "\t"}.get(m.group(1), m.group(1)), t)


# Palavras em minúsculas só contam quando vão direto para a tela ("pontos" em UIKit.stat).
UI_CALL = re.compile(r"UIKit\.\w+\(|\.text\s*[+]?=|toast\(|plural\(|screen_(?:sub)?title|\.append\(")


def ui_word(t, line, m, in_ui=False):
    if not re.fullmatch(r"[a-zà-ú][a-zà-ú ]*[a-zà-ú]", t):
        return False
    if not UI_CALL.search(line) and not (in_ui and "(" in line[: m.start()]):
        return False
    before, after = line[: m.start()].rstrip(), line[m.end():].lstrip()
    return not (after.startswith((":", "]", ")]")) or before.endswith(("[", "get(", "==", "!=", "in", "has(")))


def keep(t):
    if not t or not re.search(r"[^\W\d_]", t):
        return False
    if t.startswith(("res://", "user://", "#")):
        return False
    if re.fullmatch(r"[a-z0-9_./:%-]+", t):  # chaves, ids, caminhos
        return False
    if re.fullmatch(r"[A-Z][a-z]+(?:[A-Z][a-z0-9]*)+", t):  # variações de tema (GhostButton)
        return False
    return True


def data_strings():
    found = OrderedDict()

    def walk(node, path, key=None):
        if isinstance(node, dict):
            for k, v in node.items():
                if not str(k).startswith("_"):
                    walk(v, path, k)
        elif isinstance(node, list):
            for v in node:
                walk(v, path, key)
        elif isinstance(node, str) and key in DATA_KEYS and keep(node):
            found.setdefault(node, []).append(path)

    for f in ["data/text/commentary.json", "data/text/news.json"]:
        d = json.load(open(f, encoding="utf8"))
        for k, v in d.items():
            if not k.startswith("_"):
                walk(v, f, "text")
    for f in sorted(glob.glob("data/gameplay/*.json") + glob.glob("data/world/*.json")):
        walk(json.load(open(f, encoding="utf8")), f)
    return found


def main():
    strings = code_strings()
    for k, v in data_strings().items():
        strings.setdefault(k, []).extend(v)
    ignore = {l.rstrip("\n") for l in open("tools/i18n_ignore.txt", encoding="utf8") if l.strip() and not l.startswith("#")}
    strings = OrderedDict((k, v) for k, v in strings.items() if k not in ignore)
    for lang in LANGS:
        path = f"data/i18n/{lang}.json"
        try:
            table = json.load(open(path, encoding="utf8"))
        except FileNotFoundError:
            table = {}
        missing = [s for s in strings if not table.get(s)]
        print(f"{lang}: {len(strings) - len(missing)}/{len(strings)} traduzidos, {len(missing)} faltando")
        if "--list" in sys.argv:
            for s in missing:
                print(f"  {s!r}  ({strings[s][0]})")
        if "--write" in sys.argv and missing:
            for s in missing:
                table.setdefault(s, "")
            with open(path, "w", encoding="utf8") as fh:
                json.dump(table, fh, ensure_ascii=False, indent="\t")
                fh.write("\n")


if __name__ == "__main__":
    main()
