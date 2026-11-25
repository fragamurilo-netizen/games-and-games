#!/usr/bin/env python3
"""Lista textos do jogo que ainda não têm tradução em data/i18n/<idioma>.json.

Uso (na pasta mais-uma-rodada/):
    python3 tools/i18n_check.py            # resumo do que falta em cada idioma
    python3 tools/i18n_check.py --list     # mostra cada texto que falta, com arquivo:linha
    python3 tools/i18n_check.py --write    # acrescenta os que faltam com valor "" (para preencher)
    python3 tools/i18n_check.py --strict   # falha com traduções ausentes ou placeholders inválidos

Chaves com valor "" são ignoradas pelo jogo, que mostra o português no lugar.
Os textos são coletados das strings dos scripts e cenas e dos campos de texto dos JSON de dados.
A coleta é por heurística; literais técnicos revisados ficam em i18n_exemptions.json,
limitados ao arquivo de origem. Nomes oficiais e palavras iguais nos dois idiomas são preservados.
"""
import glob
import json
import re
import sys
from pathlib import Path
from collections import OrderedDict

LANGS = ["en", "es"]
LIT = re.compile(r'"((?:[^"\\\n]|\\.)*)"')
TOKEN = re.compile(r'(?<!%)%[-+0#]*\d*(?:\.\d+)?[sdf]|\{[A-Za-z0-9_]+\}')
DATA_KEYS = {"name", "tag", "desc", "short", "label", "title", "text", "t", "b", "group", "format", "adj"}


def code_strings():
    found = OrderedDict()
    files = sorted(glob.glob("scripts/**/*.gd", recursive=True) + glob.glob("scenes/**/*.tscn", recursive=True))
    for f in files:
        f = f.replace("\\", "/")
        for i, line in enumerate(open(f, encoding="utf8"), 1):
            s = line.strip()
            if s.startswith("#") or s.startswith("##"):
                continue
            if f.endswith(".tscn") and not re.match(r"(text|placeholder_text|tooltip_text) = ", s):
                continue
            # Strings and trailing comments are not GDScript. In particular, a UI
            # sentence containing 'match' or an icon on the same line used to hide
            # the actual text from the audit (also on Windows path separators).
            masked = LIT.sub('""', line).split("#", 1)[0]
            if re.match(r"\s*(?:push_warning|push_error|print|assert)\s*\(", masked):
                continue
            for m in LIT.finditer(line):
                if m.start() > 0 and line[m.start() - 1] in "&^":
                    continue
                if "#" in LIT.sub('""', line[:m.start()]):
                    break
                before = line[:m.start()].rstrip()
                if re.search(r'(?:theme_type_variation\s*=|(?:add_theme_\w+|get_theme_\w+|has_theme_\w+|StringName|connect|emit_signal|has_method|icon|preload|load|get_node(?:_or_null)?|set_meta|get_meta|has_meta|Color|play)\s*\()$', before):
                    continue
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
    # Literal vector paths, cache keys and punctuation-only format strings.
    if re.fullmatch(r"[Mm]\s[-\d. ,MLCQHVSAZTmlcqhvsa zt]+", t):
        return False
    if re.fullmatch(r"[0-9A-Fa-f]{6}(?:[0-9A-Fa-f]{2})?", t):
        return False
    words = re.sub(r"%(?:[-+0# ]*\d*)?(?:\.\d+)?[sdfxX]|\{\w+\}", "", t)
    if not re.search(r"[^\W\d_]", words):
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
        elif isinstance(node, str) and key in DATA_KEYS and (keep(node) or key == "adj"):
            found.setdefault(node, []).append(path)

    for f in ["data/text/commentary.json", "data/text/news.json"]:
        d = json.load(open(f, encoding="utf8"))
        for k, v in d.items():
            if not k.startswith("_"):
                walk(v, f, "text")
    for f in sorted(glob.glob("data/gameplay/*.json") + glob.glob("data/world/*.json")):
        walk(json.load(open(f, encoding="utf8")), f)
    # Display dictionaries keyed by IDs, rather than by a field called 'name'.
    def all_values(node, path):
        if isinstance(node, dict):
            for k, v in node.items():
                if not str(k).startswith("_"):
                    all_values(v, path)
        elif isinstance(node, str):
            found.setdefault(node, []).append(path)
    all_values(json.load(open("data/gameplay/awards.json", encoding="utf8")), "data/gameplay/awards.json")
    all_values(json.load(open("data/world/languages.json", encoding="utf8")).get("names", {}), "data/world/languages.json")
    return found


def placeholder_errors(table):
    errors = []
    for key, value in table.items():
        if key.startswith("_") or not value:
            continue
        source, target = TOKEN.findall(key), TOKEN.findall(value)
        if not source:
            continue
        named = {t for t in source if t.startswith("{")}
        numeric = [int(t[1:-1]) for t in target if t.startswith("{") and t[1:-1].isdigit()]
        invalid = bool(named - set(target)) or any(n < 1 or n > len(source) for n in numeric)
        if not numeric:
            invalid |= [t for t in source if t.startswith("%")] != [t for t in target if t.startswith("%")]
        if invalid:
            errors.append(key)
    return errors


def main():
    invocation_dir = Path.cwd()
    os_root = Path(__file__).resolve().parents[1]
    import os
    os.chdir(os_root)
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf8")
    strings = code_strings()
    for k, v in data_strings().items():
        strings.setdefault(k, []).extend(v)
    ignore = {l.rstrip("\n") for l in open("tools/i18n_ignore.txt", encoding="utf8") if l.strip() and not l.startswith("#")}
    strings = OrderedDict((k, v) for k, v in strings.items() if k not in ignore)
    # Reviewed technical literals are scoped to their source file. A UI text with
    # the same spelling elsewhere must still be audited.
    exemption_path = Path("tools/i18n_exemptions.json")
    exemptions = json.loads(exemption_path.read_text(encoding="utf8")) if exemption_path.exists() else {}
    for key, refs in list(strings.items()):
        visible_refs = [ref for ref in refs if key not in exemptions.get(ref.replace("\\", "/").split(":")[0], {})]
        if visible_refs:
            strings[key] = visible_refs
        else:
            del strings[key]
    report = {}
    invalid_formats = {}
    for lang in LANGS:
        path = f"data/i18n/{lang}.json"
        try:
            table = json.load(open(path, encoding="utf8"))
        except FileNotFoundError:
            table = {}
        missing = [s for s in strings if not table.get(s)]
        invalid_formats[lang] = placeholder_errors(table)
        report[lang] = [{"text": s, "refs": strings[s]} for s in missing]
        print(f"{lang}: {len(strings) - len(missing)}/{len(strings)} traduzidos, {len(missing)} faltando")
        print(f"  placeholders inválidos: {len(invalid_formats[lang])}")
        for key in invalid_formats[lang]:
            print(f"  PLACEHOLDER: {key!r} -> {table[key]!r}")
        if "--list" in sys.argv:
            for s in missing:
                print(f"  {s!r}  ({strings[s][0]})")
        if "--write" in sys.argv and missing:
            for s in missing:
                table.setdefault(s, "")
            with open(path, "w", encoding="utf8") as fh:
                json.dump(table, fh, ensure_ascii=False, indent="\t")
                fh.write("\n")
    if "--json" in sys.argv:
        destination = invocation_dir / sys.argv[sys.argv.index("--json") + 1]
        destination.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf8")
    if "--strict" in sys.argv and (any(report.values()) or any(invalid_formats.values())):
        raise SystemExit(1)


if __name__ == "__main__":
    main()
