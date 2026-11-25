#!/usr/bin/env python3
"""Lista os textos do jogo que ainda não têm tradução em data/i18n/<idioma>.json.

Uso (na pasta noite-de-luta/):
    python3 tools/i18n_check.py                 # resumo do que falta em cada idioma
    python3 tools/i18n_check.py --list [--lang=en]   # cada texto que falta, com arquivo:linha
    python3 tools/i18n_check.py --dump=ARQ      # todos os textos encontrados (um JSON: texto → onde)
    python3 tools/i18n_check.py --stale         # chaves dos JSON que o código não usa mais

O texto-fonte é o português escrito no código e nos JSON de dados. Cada idioma é um JSON
{"texto em pt": "tradução"}; valor "" (ou chave ausente) mostra o português.

Como os textos são achados (heurística, ver scripts/core/i18n.gd):
- strings dos scripts que parecem texto de tela (espaço, acento ou maiúscula);
- concatenações viram moldes: `"Semana " + str(w)` vira a chave "Semana %s" (o jogo casa o
  texto pronto "Semana 12" com o molde); `"%d lutas" % n` já é molde;
- campos de texto dos JSON de dados (nomes de país, artes, frases da vida, narração).
Textos montados em várias linhas escapam: os passeios de tela com --i18n-miss acham o resto.
"""
import glob
import json
import re
import sys
from collections import OrderedDict

LANGS = ["en", "es", "de", "fr", "ru", "zh"]

# Linhas cujas strings nunca chegam à tela.
SKIP_LINE = re.compile(
    r"^\s*(?:push_warning|push_error|print|printerr|assert)\(|\bclass_name\b|^\s*extends\b|RegEx\.|"
    r"ResourceLoader|FileAccess|DirAccess|ProjectSettings|cfg\.(?:get|set)_value"
)
# Arquivos que só formatam ou traduzem (os textos deles já são de cada idioma).
SKIP_FILES = {"fmt.gd", "i18n.gd", "pattern_translation.gd", "fonts.gd", "data_db.gd", "hair_shape.gd"}
DATA_TEXT_KEYS = {"name", "short", "desc", "region", "label", "title", "text", "texts", "t", "tag",
                  "adj", "names", "start", "start_by_culture", "jobs", "drive", "quirk", "heritage"}
ID_RE = re.compile(r"[a-z0-9_./:%#-]+")


def unescape(t):
    return re.sub(r"\\(.)", lambda m: {"n": "\n", "t": "\t"}.get(m.group(1), m.group(1)), t)


def looks_text(t):
    """Texto de tela: tem letra e não é chave/id/caminho/variação de tema."""
    if not t or not re.search(r"[^\W\d_]", t):
        return False
    if t.startswith(("res://", "user://", "#", "uid://")):
        return False
    if ID_RE.fullmatch(t):
        return False
    if re.fullmatch(r"[A-Z][a-z]+(?:[A-Z][a-z0-9]*)+", t):  # GhostButton, PrimaryButton
        return False
    if re.fullmatch(r"[A-Z0-9_]+", t) and "_" in t:  # CONSTANTES
        return False
    if re.fullmatch(r"[0-9A-F]{6}", t) or "|" in t and re.fullmatch(r"[%sd0-9|]+", t):
        return False
    return True


def looks_template(t):
    rest = re.sub(r"%(?:\.\d+)?[sdf]", " ", t)
    if looks_text(rest.strip()):
        return True
    # "%s/sem", "%s pts": sufixo curto que ainda é palavra; ids ("camp:%d", "%s_%s") ficam fora.
    if re.search(r"[^\W\d_]{2}", rest) and not re.search(r"[_:]|res:|user:", rest):
        return True
    return False


# ---------------------------------------------------------------- tokens de uma linha lógica

TOKEN = re.compile(
    r'(?P<tq>"""(?:.|\n)*?""")|(?P<pre>[&^])?"(?P<s>(?:[^"\\\n]|\\.)*)"|(?P<sq>\'(?:[^\'\\\n]|\\.)*\')|'
    r"(?P<num>\d[\d_]*(?:\.\d+)?)|(?P<id>[A-Za-z_][A-Za-z0-9_]*)|(?P<op>==|!=|<=|>=|\+=|-=|:=|\*\*|->|[-+*/%<>=!,:;.()\[\]{}])|(?P<sp>\s+)|(?P<other>.)"
)
OPEN, CLOSE = "([{", ")]}"
STOP_WORDS = {"if", "else", "and", "or", "not", "return", "in", "for", "while", "var", "const", "elif", "match", "is", "as", "await"}


def tokenize(src):
    out = []
    for m in TOKEN.finditer(src):
        k = m.lastgroup
        if m.group("sp") is not None:
            continue
        if m.group("s") is not None:
            out.append(("str" if not m.group("pre") else "sname", unescape(m.group("s")), m.start()))
        elif m.group("tq") is not None:
            out.append(("str", m.group("tq")[3:-3], m.start()))
        elif m.group("sq") is not None:
            out.append(("str", unescape(m.group("sq")[1:-1]), m.start()))
        elif m.group("id") is not None:
            out.append(("id", m.group("id"), m.start()))
        elif m.group("num") is not None:
            out.append(("num", m.group("num"), m.start()))
        elif m.group("op") is not None:
            out.append(("op", m.group("op"), m.start()))
        else:
            out.append(("other", m.group(0), m.start()))
    return out


def operand_end(toks, i):
    """Índice depois do operando que começa em i (mesma profundidade)."""
    depth = 0
    j = i
    n = len(toks)
    while j < n:
        k, v, _ = toks[j]
        if k == "op" and v in OPEN:
            depth += 1
        elif k == "op" and v in CLOSE:
            if depth == 0:
                return j
            depth -= 1
        elif depth == 0:
            if k == "op" and v in ("+", ",", "=", ":=", "+=", "-=", ":", "==", "!=", "<", ">", "<=", ">=", ";", "-", "*", "/"):
                return j
            if k == "id" and v in STOP_WORDS and j > i:
                return j
            if k == "op" and v == "%" and j > i:
                return j
        j += 1
    return j


def operand_start(toks, i):
    """Índice onde começa o operando que termina em i-1 (exclusivo i)."""
    depth = 0
    j = i - 1
    while j >= 0:
        k, v, _ = toks[j]
        if k == "op" and v in CLOSE:
            depth += 1
        elif k == "op" and v in OPEN:
            if depth == 0:
                return j + 1
            depth -= 1
        elif depth == 0:
            if k == "op" and v in ("+", ",", "=", ":=", "+=", "-=", ":", "==", "!=", "<", ">", "<=", ">=", ";", "-", "*", "/", "%"):
                return j + 1
            if k == "id" and v in STOP_WORDS:
                return j + 1
        j -= 1
    return 0


def operand_text(toks, a, b):
    """Um operando vira o texto dele (string pura ou molde entre parênteses) ou %s."""
    seg = toks[a:b]
    if len(seg) == 1 and seg[0][0] == "str":
        return seg[0][1], True
    # ("molde %s" % x) entre parênteses: o molde entra inteiro.
    if len(seg) >= 3 and seg[0][1] == "(" and seg[-1][1] == ")":
        inner = seg[1:-1]
        if inner and inner[0][0] == "str" and len(inner) > 1 and inner[1] == ("op", "%", inner[1][2]):
            return inner[0][1], True
    if len(seg) >= 2 and seg[0][0] == "str" and seg[1][0] == "op" and seg[1][1] == "%":
        return seg[0][1], True
    # str(x), Fmt.algo(x), nome.field: valor que entra na frase.
    return "%s", False


def chains(toks):
    """Moldes de concatenação: lista de (molde, posição) para cada cadeia com '+'."""
    out = []
    seen = set()
    for i, (k, v, pos) in enumerate(toks):
        if k != "str" or i in seen:
            continue
        a = i
        b = operand_end(toks, i)
        parts = [(a, b)]
        # para a esquerda
        while a > 1 and toks[a - 1][0] == "op" and toks[a - 1][1] == "+":
            s = operand_start(toks, a - 1)
            if s >= a - 1:
                break
            parts.insert(0, (s, a - 1))
            a = s
        # para a direita
        while b < len(toks) and toks[b][0] == "op" and toks[b][1] == "+":
            e = operand_end(toks, b + 1)
            if e <= b + 1:
                break
            parts.append((b + 1, e))
            b = e
        if len(parts) < 2:
            continue
        text = ""
        any_lit = False
        for (s, e) in parts:
            t, lit = operand_text(toks, s, e)
            for q in range(s, e):
                if toks[q][0] == "str":
                    seen.add(q)
            text += t
            any_lit = any_lit or lit
        if any_lit:
            out.append((text, pos))
    return out


def logical_lines(path):
    """Junta linhas de uma mesma expressão (parênteses abertos ou barra no fim)."""
    lines = open(path, encoding="utf8").read().split("\n")
    buf, start, depth = "", 0, 0
    in_tq = False
    for i, raw in enumerate(lines, 1):
        line = raw
        if not buf:
            start = i
        # tira comentário (fora de string)
        code = strip_comment(line) if not in_tq else line
        if code.count('"""') % 2 == 1:
            in_tq = not in_tq
        buf += (" " if buf else "") + code.strip()
        depth = paren_depth(buf)
        if depth > 0 or in_tq or buf.endswith("\\"):
            if buf.endswith("\\"):
                buf = buf[:-1]
            continue
        yield start, buf
        buf = ""
    if buf:
        yield start, buf


def strip_comment(line):
    out = []
    q = None
    i = 0
    while i < len(line):
        c = line[i]
        if q:
            out.append(c)
            if c == "\\" and i + 1 < len(line):
                out.append(line[i + 1])
                i += 2
                continue
            if c == q:
                q = None
        else:
            if c == "#":
                break
            if c in "\"'":
                q = c
            out.append(c)
        i += 1
    return "".join(out)


def paren_depth(s):
    d = 0
    for k, v, _ in tokenize(s):
        if k == "op" and v in OPEN:
            d += 1
        elif k == "op" and v in CLOSE:
            d -= 1
    return d


KEY_CONTEXT_BEFORE = ("[", "get(", "==", "!=", " in", "has(", "find(", "begins_with(", "ends_with(", "contains(", "replace(", "split(")


def code_strings():
    found = OrderedDict()
    files = sorted(f for f in glob.glob("scripts/**/*.gd", recursive=True) if f.split("/")[-1] not in SKIP_FILES)
    for f in files:
        for ln, line in logical_lines(f):
            s = line.strip()
            if not s or s.startswith("@export") or s.startswith("signal "):
                continue
            if SKIP_LINE.search(line):
                continue
            toks = tokenize(line)
            if not any(t[0] == "str" for t in toks):
                continue
            in_chain = set()
            for text, pos in chains(toks):
                if looks_template(text):
                    found.setdefault(text, []).append(f"{f}:{ln}")
                in_chain.add(pos)
            for i, (k, v, pos) in enumerate(toks):
                if k != "str" or pos in in_chain:
                    continue
                if not looks_text(v):
                    # Palavra solta em minúsculas só conta se vai para a tela por um caminho conhecido.
                    if not lower_ui_word(v, line, toks, i):
                        continue
                if is_key_context(toks, i, line, pos):
                    continue
                found.setdefault(v, []).append(f"{f}:{ln}")
    for f in sorted(glob.glob("scenes/**/*.tscn", recursive=True)):
        for ln, line in enumerate(open(f, encoding="utf8"), 1):
            m = re.match(r'(text|placeholder_text|tooltip_text) = "((?:[^"\\]|\\.)*)"', line.strip())
            if m and looks_text(unescape(m.group(2))):
                found.setdefault(unescape(m.group(2)), []).append(f"{f}:{ln}")
    return found


UI_CALL = re.compile(r"UIKit\.\w+\(|FightKit\.\w+\(|\.text\s*[+]?=|toast\(|plural\(|screen_(?:sub)?title|stat_tile\(|I18n\.t\(")


def lower_ui_word(t, line, toks, i):
    if not re.fullmatch(r"[a-zà-úç][a-zà-úç]*", t) or len(t) < 3:
        return False
    if not UI_CALL.search(line) and not ("_slider(" in line and in_text_list(toks, i)):
        return False
    if is_key_context(toks, i, line, toks[i][2]):
        return False
    return True


def in_text_list(toks, i):
    """["pequeno", "médio", "cheio"]: lista só de strings em que alguma é texto de tela."""
    j = i - 1
    while j >= 0 and (toks[j][0] == "str" or toks[j][1] == ","):
        j -= 1
    k = i + 1
    while k < len(toks) and (toks[k][0] == "str" or toks[k][1] == ","):
        k += 1
    if j < 0 or k >= len(toks) or toks[j][1] != "[" or toks[k][1] != "]":
        return False
    return any(toks[x][0] == "str" and looks_text(toks[x][1]) for x in range(j + 1, k))


def is_key_context(toks, i, line, pos):
    nxt = toks[i + 1] if i + 1 < len(toks) else None
    prv = toks[i - 1] if i > 0 else None
    # chave de dicionário {"x": ...}
    if nxt and nxt[0] == "op" and nxt[1] == ":" and prv and prv[1] in ("{", ","):
        return True
    if prv and prv[0] == "op" and prv[1] in ("==", "!="):
        return True
    if nxt and nxt[0] == "op" and nxt[1] in ("==", "!="):
        return True
    if prv and prv[0] == "id" and prv[1] in ("in",):
        return False
    if nxt and nxt[0] == "id" and nxt[1] == "in":
        return True
    before = line[:pos].rstrip()
    if before.endswith(("get(", "has(", "find(", "begins_with(", "ends_with(", "replace(", "split(", "erase(")):
        return True
    return False


def data_strings():
    found = OrderedDict()

    def walk(node, path, key=None, keep_all=False):
        if isinstance(node, dict):
            for k, v in node.items():
                if str(k).startswith("_"):
                    continue
                walk(v, path, k if k in DATA_TEXT_KEYS or not keep_all else key, keep_all or k in DATA_TEXT_KEYS)
        elif isinstance(node, list):
            for v in node:
                walk(v, path, key, keep_all)
        elif isinstance(node, str) and keep_all and looks_text(node):
            found.setdefault(node, []).append(path)

    d = json.load(open("data/world/styles.json", encoding="utf8"))
    for sect in ("bases", "takedowns", "subs", "traits"):
        for k, v in d.get(sect, {}).items():
            walk(v, f"data/world/styles.json:{sect}.{k}")
    d = json.load(open("data/world/bio.json", encoding="utf8"))
    for k, v in d.get("homes", {}).items():
        for c, h in v.items():
            if isinstance(h, dict) and h.get("region"):
                found.setdefault(h["region"], []).append("data/world/bio.json:homes")
    for sect in ("heritage", "start", "start_by_culture", "jobs", "drive", "quirk"):
        walk(d.get(sect), f"data/world/bio.json:{sect}", None, True)
    for k, v in d.get("gifts", {}).items():
        walk(v, f"data/world/bio.json:gifts.{k}")
    d = json.load(open("data/world/mma.json", encoding="utf8"))
    for div in d.get("divisions", []):
        found.setdefault(div["name"], []).append("data/world/mma.json:divisions")
    walk(d.get("promotions"), "data/world/mma.json:promotions")
    for k, v in d.get("continental", {}).items():
        if isinstance(v, str):
            found.setdefault(v, []).append("data/world/mma.json:continental")
        else:
            walk(v, "data/world/mma.json:continental")
    for p in d.get("regional_patterns", []) + d.get("team_patterns", []):
        if looks_text(p.replace("{c}", "").replace("{w}", "")):
            found.setdefault(p, []).append("data/world/mma.json:patterns")
    d = json.load(open("data/world/nations.json", encoding="utf8"))
    for code, n in d.get("nations", {}).items():
        for k in ("name", "adj"):
            if n.get(k):
                found.setdefault(n[k], []).append(f"data/world/nations.json:{code}")
    return found


def not_text_names():
    """Nomes de variação do tema, ícones e sons: aparecem em strings mas nunca na tela."""
    out = set()
    for line in open("tools/build_theme_runner.gd", encoding="utf8"):
        out.update(re.findall(r'"([A-Z][A-Za-z0-9]+)"', line))
    for f in glob.glob("assets/icons/*") + glob.glob("assets/audio/**/*", recursive=True):
        out.add(re.sub(r"\.[a-z0-9]+(\.import)?$", "", f.split("/")[-1]))
    return out


def collect():
    strings = code_strings()
    skip = not_text_names()
    strings = OrderedDict((k, v) for k, v in strings.items() if k not in skip)
    for k, v in data_strings().items():
        strings.setdefault(k, []).extend(v)
    try:
        ignore = {l.rstrip("\n") for l in open("tools/i18n_ignore.txt", encoding="utf8") if l.strip() and not l.startswith("#")}
    except FileNotFoundError:
        ignore = set()
    return OrderedDict((k, v) for k, v in strings.items() if k not in ignore)


def main():
    strings = collect()
    arg = {a.split("=")[0]: (a.split("=", 1)[1] if "=" in a else True) for a in sys.argv[1:]}
    if "--dump" in arg:
        with open(arg["--dump"], "w", encoding="utf8") as fh:
            json.dump(strings, fh, ensure_ascii=False, indent=1)
        print(f"{len(strings)} textos em {arg['--dump']}")
        return
    langs = [arg["--lang"]] if "--lang" in arg else LANGS
    for lang in langs:
        path = f"data/i18n/{lang}.json"
        try:
            table = json.load(open(path, encoding="utf8"))
        except FileNotFoundError:
            table = {}
        missing = [s for s in strings if not table.get(s)]
        print(f"{lang}: {len(strings) - len(missing)}/{len(strings)} traduzidos, {len(missing)} faltando")
        if "--list" in arg:
            for s in missing:
                print(f"  {s!r}  ({strings[s][0]})")
        if "--stale" in arg:
            stale = [k for k in table if not k.startswith("_") and k not in strings]
            print(f"  {len(stale)} chaves sem uso no código")


if __name__ == "__main__":
    main()
