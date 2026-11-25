#!/usr/bin/env python3
"""Confere quais textos vistos na tela (linhas JSON gravadas por --i18n-miss) casam com alguma
chave do catálogo (exata ou molde), do jeito que o jogo casa (PatternTranslation).

    python3 tools/i18n_cover.py MISS.txt [--keys=ARQ.json] [--lang=en]

Sem --keys, usa as chaves achadas por tools/i18n_check.py. Imprime o que não casa.
"""
import json
import re
import sys

sys.path.insert(0, "tools")
import i18n_check  # noqa: E402

TOK = re.compile(r"%(?:\.\d+)?[sdf]|\{[A-Za-z_][A-Za-z0-9_]*\}")
WORD = re.compile(r"[^\W\d_]+")
AFFIX = re.compile(r"^(.*?)( [-+]?[\d.,%]+| \([^()]*\)|[.!?:…]+)$")


class Matcher:
    def __init__(self, keys):
        self.exact = set(keys)
        self.upper = {k.upper() for k in keys}
        self.lower_first = {k[:1].lower() + k[1:] for k in keys}
        self.pats = []
        for k in keys:
            if not TOK.search(k):
                continue
            rx, last, lits = "^", 0, ""
            for m in TOK.finditer(k):
                lit = k[last:m.start()].replace("%%", "%")
                rx += re.escape(lit)
                lits += " " + lit
                t = m.group(0)
                rx += r"(-?[\d.,]+)" if t in ("%d",) or t.endswith("f") and t.startswith("%") else "(.*?)"
                last = m.end()
            rx += re.escape(k[last:].replace("%%", "%")) + "$"
            lits += " " + k[last:]
            if not WORD.search(lits):
                continue
            self.pats.append((len(lits), re.compile(rx), re.compile(rx.upper() if False else rx, re.I)))
        self.pats.sort(key=lambda p: -p[0])

    def covered(self, s, depth=0):
        if s in self.exact or s in self.upper:
            return True
        lf = s[:1].lower() + s[1:]
        if lf in self.exact or s in self.lower_first:
            return True
        if not re.search(r"[^\W\d_]", s):
            return True
        up = s == s.upper()
        for _, rx, rxi in self.pats:
            if (rxi if up else rx).match(s):
                return True
        if "\n" in s and depth < 2:
            return all(self.covered(x, depth + 1) or not x.strip() for x in s.split("\n"))
        if depth < 2:
            for sep in (" · ", " — ", " / ", ": ", " | ", ". ", ", "):
                if sep in s:
                    parts = [p.strip() for p in s.split(sep)]
                    if sep == ". ":
                        parts = [p + "." for p in parts[:-1]] + parts[-1:]
                    if any(self.covered(p, depth + 1) for p in parts if p):
                        return True
        if depth < 3:
            m = AFFIX.match(s)
            if m and m.group(1) and re.search(r"[^\W\d_]", m.group(1)) and self.covered(m.group(1), depth + 1):
                return True
        return False


def name_tokens():
    """Palavras de nomes de gente e de cidades (o que nunca se traduz)."""
    out = set()

    def walk(n):
        if isinstance(n, dict):
            for v in n.values():
                walk(v)
        elif isinstance(n, list):
            for v in n:
                walk(v)
        elif isinstance(n, str):
            out.update(re.findall(r"[^\W\d_][^\s,]*", n))

    for f in ("data/names/names.json", "data/names/fight_names.json"):
        walk(json.load(open(f, encoding="utf8")))
    d = json.load(open("data/world/nations.json", encoding="utf8"))
    for n in d["nations"].values():
        walk(n.get("cities", []))
    d = json.load(open("data/world/mma.json", encoding="utf8"))
    walk(d.get("nicknames"))
    walk(d.get("famous"))
    walk(d.get("lgc_cities"))
    walk(d.get("team_words"))
    b = json.load(open("data/world/bio.json", encoding="utf8"))
    for v in b["homes"].values():
        for h in v.values():
            walk(h.get("cities", []))
    return out


def is_name(s, toks):
    words = re.findall(r"[^\W\d_][^\s,()·×\"]*", s)
    return bool(words) and all(w.strip(".:'") in toks or w in ("×", "vs", "de", "da", "do", "dos", "das", "e") for w in words)


def main():
    arg = {a.split("=")[0]: (a.split("=", 1)[1] if "=" in a else True) for a in sys.argv[2:]}
    if "--keys" in arg:
        keys = list(json.load(open(arg["--keys"], encoding="utf8")))
    else:
        keys = list(i18n_check.collect())
    m = Matcher(keys)
    seen = [json.loads(l) for l in open(sys.argv[1], encoding="utf8") if l.strip()]
    toks = name_tokens()
    bad = [s for s in seen if not m.covered(s) and not is_name(s, toks)]
    print(f"{len(seen) - len(bad)}/{len(seen)} casam")
    for s in bad:
        print(repr(s))


if __name__ == "__main__":
    main()
