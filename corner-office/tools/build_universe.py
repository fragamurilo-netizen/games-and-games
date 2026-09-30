"""Gera game/content/universe/*.json (Game Design Bible §§2–3, 13–14).

    python3 tools/build_universe.py

Determinístico: a mesma fonte (universe_source.py, universe_people.py) gera
sempre os mesmos arquivos. Autoral onde importa (países, arenas, organizações,
lendas, marcos) e gerado onde a escala pede (promotoras regionais, 30 anos de
linhagens de cinturão, lutas por título, Hall da Fama, recordes).
"""
from __future__ import annotations

import datetime as dt
import json
import random
import re
import unicodedata
from pathlib import Path

import universe_people as P
import universe_source as S

ROOT = Path(__file__).resolve().parents[1]
CONTENT = ROOT / "game/content"
OUT = CONTENT / "universe"
END = dt.date(2026, 12, 31)
START_2027 = dt.date(2027, 1, 1)

rng = random.Random(19911012)


def slug(text: str) -> str:
    t = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z0-9]+", "_", t.lower()).strip("_")


def d(s: str) -> dt.date:
    return dt.date.fromisoformat(s)


def iso(x: dt.date) -> str:
    return x.isoformat()


def load(name: str):
    return json.loads((CONTENT / name).read_text(encoding="utf-8"))


GLOBAL_ORGS = {o["id"]: o for o in load("organizations.json")}
DIVISIONS = {w["id"]: w for w in load("weight_classes.json")}
DIV_ORDER = [w["id"] for w in load("weight_classes.json")]
GYMS = load("gyms.json")
OUTLETS = load("media_outlets.json")
EVENT_NUMBER_PER_REP = load("career_tuning.json")["rival_ai"]["event_number_per_reputation"]
CANONICAL = {f["id"]: f for f in load("canonical_fighters.json")}
COUNTRY_NAME = {c[0]: c[1] for c in S.COUNTRIES}

# ---------------------------------------------------------------------------
# Geografia
# ---------------------------------------------------------------------------
REGION_OF = {c[0]: c[2] for c in S.COUNTRIES}
MOUNTAINS = {"Rio de Janeiro", "Almaty", "Bishkek", "Tbilisi", "Denver", "Salt Lake City", "Vancouver", "Bogotá", "Medellín", "Santiago",
             "Cidade do Cabo", "Christchurch", "Baguio", "Ulan Bator", "Erevan", "Duchambé", "Teerã", "Honolulu", "Sapporo", "Albuquerque",
             "Tijuana", "Monterrey", "Grozny", "Makhachkala", "Sarajevo", "Belo Horizonte", "Lima", "Seul", "Busan", "Chengdu", "Astana"}
DESERT = {"Las Vegas", "Phoenix", "Dubai", "Abu Dhabi", "Riad", "Doha", "Albuquerque", "Cairo", "Manama", "Teerã", "Perth"}
INLAND = {"Las Vegas", "Phoenix", "Denver", "Salt Lake City", "Albuquerque", "Chicago", "Dallas", "Atlanta", "Edmonton", "Brasília", "Goiânia",
          "Belo Horizonte", "Cidade do México", "Guadalajara", "Córdoba", "Bogotá", "Medellín", "Santiago", "Madri", "Munique", "Berlim", "Praga",
          "Varsóvia", "Cracóvia", "Łódź", "Belgrado", "Zagreb", "Sarajevo", "Bucareste", "Sófia", "Kiev", "Moscou", "Kazan", "Grozny", "Tbilisi",
          "Erevan", "Almaty", "Astana", "Bishkek", "Tashkent", "Duchambé", "Teerã", "Riad", "Iaundé", "Joanesburgo", "Pequim", "Chengdu",
          "Ulan Bator", "Baguio", "Nova Délhi", "Paris", "Lyon", "Colônia", "Milão", "Birmingham", "Madri", "Manchester", "Nagoya", "Saitama", "Goiânia"}
LANDMARK = {
    "brazil": ["hills", "towers", "cathedral", "bridge"], "north_america": ["towers", "needle", "bridge"], "mexico": ["cathedral", "towers", "pyramid"],
    "latam": ["cathedral", "hills", "towers"], "europe_west": ["cathedral", "gables", "clock", "bridge", "needle"],
    "europe_east": ["onion", "cathedral", "needle", "bridge"], "central_asia": ["dome", "minaret", "needle", "onion"],
    "japan_korea": ["pagoda", "needle", "towers"], "asia_pacific": ["pagoda", "needle", "towers", "dome"],
    "oceania": ["towers", "bridge", "needle"], "middle_east": ["minaret", "needle", "dome"], "africa": ["dome", "towers", "minaret"],
}
LANDMARK_CITY = {"Londres": "clock", "Paris": "lattice", "Las Vegas": "neon", "Rio de Janeiro": "hills", "São Paulo": "towers",
                 "Tóquio": "lattice", "Dubai": "needle", "Sydney": "sails", "Moscou": "onion", "São Petersburgo": "onion", "Istambul": "minaret",
                 "Cidade do México": "pyramid", "Seul": "needle", "Xangai": "needle", "Toronto": "needle", "Seattle": "needle",
                 "Kazan": "onion", "Almaty": "needle", "Astana": "needle", "Baku": "flame", "Roma": "coliseum", "Atenas": "temple",
                 "Cairo": "pyramid", "Bangkok": "pagoda", "Amsterdã": "gables", "Bruxelas": "gables", "Copenhague": "gables",
                 "Honolulu": "palms", "Miami": "palms", "Salvador": "cathedral", "Recife": "bridge", "Nova York": "towers", "Chicago": "towers",
                 "Lisboa": "bridge", "Porto": "bridge", "Belgrado": "bridge", "Budapeste": "bridge", "Doha": "needle", "Riad": "needle",
                 "Kuala Lumpur": "needle", "Singapura": "sails", "Manila": "palms", "Jacarta": "needle", "Mumbai": "dome", "Nova Délhi": "dome",
                 "Brasília": "bowl", "Varsóvia": "needle", "Berlim": "needle", "Marselha": "cathedral", "Barcelona": "cathedral"}


# Paletas das ilustrações de cidade (presentation/city/city_art.gd). Tons
# foscos, sem neon, coerentes com DESIGN.md.
ART_PALETTES = {
    "dusk": {"top": "#23283A", "mid": "#7A4A48", "horizon": "#D98F5C", "sun": "#F2C27B", "far": "#5A4150",
             "near": "#1A1C26", "window": "#E9B866", "water": "#2C2A3A", "ground": "#15161D"},
    "night": {"top": "#0A0E18", "mid": "#141D30", "horizon": "#2A3550", "sun": "#E8E4D2", "far": "#1D2538",
              "near": "#0E1119", "window": "#E3BE72", "water": "#0E1422", "ground": "#0B0D13"},
    "day": {"top": "#5F8DB0", "mid": "#98BACF", "horizon": "#D5E1E4", "sun": "#F6F1DE", "far": "#8FA2B0",
            "near": "#48535E", "window": "#C9D6DD", "water": "#557A92", "ground": "#39424A"},
    "dawn": {"top": "#34405C", "mid": "#9A7C8C", "horizon": "#EBC3A2", "sun": "#F7DDB0", "far": "#7C7288",
             "near": "#2A2A38", "window": "#EFCB8C", "water": "#4A4E66", "ground": "#23232E"},
}


def city_art(name: str, country: str, market: int) -> dict:
    region = REGION_OF[country]
    r = random.Random(slug(name))
    sky = r.choices(["dusk", "night", "day", "dawn"], [4, 3, 2, 1])[0]
    return {
        "seed": r.randrange(1, 2_000_000_000),
        "sky": sky,
        "landmark": LANDMARK_CITY.get(name) or r.choice(LANDMARK[region]),
        "density": round(0.25 + market / 140, 2),
        "height": round(0.35 + (market / 100) ** 1.6 * 0.6 + (0.15 if region == "north_america" else 0), 2),
        "mountains": name in MOUNTAINS,
        "desert": name in DESERT,
        "water": name not in INLAND and name not in DESERT - {"Dubai", "Abu Dhabi", "Doha", "Manama", "Perth"},
        "snow": country in {"CA", "RU", "KZ", "KG", "MN", "NO", "SE"} and r.random() < .5,
    }


def build_geo():
    regions = [{"id": r[0], "name": r[1], "game_region": r[2], "summary": r[3]} for r in S.REGIONS]
    cities, city_by_name = [], {}
    for name, country, market, passion, note in S.CITIES:
        c = {"id": "city_" + slug(name), "name": name, "country": country, "region": REGION_OF[country], "market": market,
             "passion": passion, "note": note, "venues": [], "art": city_art(name, country, market)}
        cities.append(c)
        city_by_name[name] = c
    venues = []
    for name, city, cap, tier, cost in S.VENUES:
        c = city_by_name[city]
        v = {"id": "ven_" + slug(name), "name": name, "city_id": c["id"], "city": city, "country": c["country"], "capacity": cap,
             "tier": tier, "cost": cost}
        venues.append(v)
        c["venues"].append(v["id"])
    countries = []
    for iso_, name, region, scene, market, passion, styles, commission, capital, currency in S.COUNTRIES:
        countries.append({"id": iso_, "name": name, "region": region, "scene": scene, "market": market, "passion": passion,
                          "style_tendencies": styles, "commission": commission, "capital": capital, "currency": currency,
                          "cities": [c["id"] for c in cities if c["country"] == iso_]})
    return regions, countries, cities, city_by_name, venues


# ---------------------------------------------------------------------------
# Pessoas
# ---------------------------------------------------------------------------
people: dict[str, dict] = {}
used_names: set[str] = {f"{f['first_name']} {f['last_name']}" for f in CANONICAL.values()}


def add_person(pid, first, last, nick, country, sex, birth, division, **extra):
    people[pid] = {"id": pid, "first_name": first, "last_name": last, "nickname": nick, "country": country, "sex": sex,
                   "birth_year": birth, "division": division, "titles": [], "title_fights": {"wins": 0, "losses": 0, "draws": 0}, **extra}
    used_names.add(f"{first} {last}")
    return people[pid]


for lid, first, last, nick, country, sex, birth, div, retired, role, bio in P.LEGENDS:
    add_person(lid, first, last, nick, country, sex, birth, div, retired=retired, role=role, bio=bio, legend=True)
for fid, f in CANONICAL.items():
    add_person(fid, f["first_name"], f["last_name"], f.get("nickname", ""), f["country"], "F" if f["sex"] == 1 else "M",
               f["birth_date"]["year"], f["division"], retired=None, role="active", bio=f.get("bio", ""), canonical=True)

_gen = 0


def new_person(org_id: str, division: str, year: int) -> dict:
    global _gen
    talent = P.TALENT[org_id]
    sex = "F" if division.startswith("w_") else "M"
    for _ in range(400):
        country = rng.choices(list(talent), list(talent.values()))[0]
        males, females, lasts, lang = P.NAME_POOLS[country]
        first = rng.choice(females if sex == "F" else males)
        last = rng.choice(lasts)
        if f"{first} {last}" not in used_names:
            break
    nick = rng.choice(P.NICKNAMES.get(lang, P.NICKNAMES["en"])) if rng.random() < .55 else ""
    _gen += 1
    return add_person(f"hist_{_gen:04d}", first, last, nick, country, sex, year - rng.randint(24, 33), division, retired=None, role="", bio="")


def full_name(p: dict) -> str:
    return f"{p['first_name']} “{p['nickname']}” {p['last_name']}" if p["nickname"] else f"{p['first_name']} {p['last_name']}"


def short_name(p: dict) -> str:
    return f"{p['first_name']} {p['last_name']}"


# ---------------------------------------------------------------------------
# Numeração de eventos
# ---------------------------------------------------------------------------
EVENT_ANCHORS = {org: [(d(S_), 1)] for org, S_ in P.FOUNDED.items()}
for a in S.ANCHOR_FIGHTS:
    if a[1] in EVENT_ANCHORS and a[2]:
        EVENT_ANCHORS[a[1]].append((d(a[0]), a[2]))
for org, o in GLOBAL_ORGS.items():
    EVENT_ANCHORS[org].append((START_2027, int(o["reputation"] * EVENT_NUMBER_PER_REP)))
    EVENT_ANCHORS[org].sort()


def event_name(org: str, when: dt.date) -> str:
    anchors = EVENT_ANCHORS[org]
    for (a, na), (b, nb) in zip(anchors, anchors[1:]):
        if a <= when <= b:
            n = na + (nb - na) * (when - a).days / max(1, (b - a).days)
            return f"{GLOBAL_ORGS[org]['short_name']} {max(1, round(n))}"
    return GLOBAL_ORGS[org]["short_name"]


# ---------------------------------------------------------------------------
# Linhagens de cinturão
# ---------------------------------------------------------------------------
FINISHES = [("Nocaute", 30), ("Nocaute técnico", 26), ("Finalização", 20), ("Decisão unânime", 14), ("Decisão dividida", 7), ("Decisão majoritária", 3)]
VACATE = [("Vagou por lesão", 30), ("Vagou para subir de categoria", 22), ("Aposentou-se", 22), ("Saiu da organização (contrato)", 16),
          ("Título retirado (doping)", 6), ("Título retirado (inatividade)", 4)]
OPEN_ERA = ["Contrato venceu em dez/2026; virou free agent", "Aposentou-se no fim de 2026", "Vagou por lesão grave em 2026",
            "Título retirado na reestruturação de dez/2026", "Deixou a organização rumo ao Oriente Médio"]
GP_ORGS = {"org_shinsei"}


def rand_date(a: dt.date, b: dt.date, org: str) -> dt.date:
    if b <= a:
        return a
    x = a + dt.timedelta(days=rng.randint(0, (b - a).days))
    if org in GP_ORGS and rng.random() < .35:
        x = dt.date(x.year, 12, 31) if dt.date(x.year, 12, 31) <= b else x
    else:  # lutas são no sábado
        x -= dt.timedelta(days=(x.weekday() - 5) % 7)
        x = max(a, x)
    return x


def method_detail(method: str, max_rounds: int) -> tuple[int, str]:
    if method.startswith("Decisão"):
        return max_rounds, "5:00"
    rnd = rng.choices(range(1, max_rounds + 1), [40, 26, 18, 10, 6][:max_rounds])[0]
    return rnd, f"{rng.randint(0, 4)}:{rng.randint(0, 59):02d}"


fights: list[dict] = []


def busy(pid: str, a: dt.date, b: dt.date | None) -> bool:
    """Já é campeão (em outra linhagem) em algum momento de [a, b]?"""
    b = b or START_2027
    for t in people[pid]["titles"]:
        ta, tb = d(t["start"]), d(t["end"]) if t["end"] else START_2027
        if ta <= b and a <= tb:
            return True
    return False


def add_fight(org, division, when, red, blue, winner, method, title_change, kind, max_rounds, rnd=None, time=None, event=None):
    if rnd is None:
        rnd, time = method_detail(method, max_rounds) if winner != "draw" else (max_rounds, "5:00")
    f = {"id": f"hf_{len(fights) + 1:05d}", "date": iso(when), "org": org, "event": event or event_name(org, when), "division": division,
         "red": red, "blue": blue, "winner": winner, "method": method, "round": rnd, "time": time, "title_change": title_change, "kind": kind}
    fights.append(f)
    for side, pid in (("red", red), ("blue", blue)):
        tf = people[pid]["title_fights"]
        tf["draws" if winner == "draw" else "wins" if winner == side else "losses"] += 1
    return f


def build_lineages():
    lineages = {}
    promoted: dict[tuple, list] = {}  # (org, div) -> campeões que subiram
    pins_by = {}
    for p in P.PINNED_REIGNS:
        pins_by.setdefault((p[0], p[1]), []).append(p)
    for org in P.DIVISIONS:
        max_rounds = 3 if GLOBAL_ORGS[org]["ruleset_id"] == "shinsei_ring" else 5
        founded = d(P.FOUNDED[org])
        for division in sorted(P.DIVISIONS[org], key=DIV_ORDER.index):
            year = P.DIVISIONS[org][division]
            t = max(founded, dt.date(year, rng.randint(1, 10), rng.randint(1, 28)))
            pins = sorted(pins_by.get((org, division), []), key=lambda p: p[3])
            if pins and d(pins[0][3]) < t:
                t = d(pins[0][3])
            reigns, prev = [], None
            contenders: list[str] = []
            while t < END:
                pin = pins[0] if pins else None
                if pin and d(pin[3]) <= t + dt.timedelta(days=120):
                    pins.pop(0)
                    champ = pin[2]
                    start, end = d(pin[3]), (d(pin[4]) if pin[4] else None)
                    defenses, how, reason = pin[5], pin[6], pin[7]
                else:
                    start = t
                    years = min(rng.uniform(4.0, 6.2), max(.45, rng.lognormvariate(0.35, 0.7)))
                    end = start + dt.timedelta(days=int(years * 365))
                    if pin and end >= d(pin[3]) - dt.timedelta(days=45):
                        end = d(pin[3])
                    if end >= END:
                        lo = max(start + dt.timedelta(days=60), dt.date(2026, 6, 1))
                        end = rand_date(lo, max(lo, dt.date(2026, 12, 19)), org)
                    champ = None
                    if prev and prev["how_ended"] == "Perdeu o cinturão" and people[prev["fighter_id"]]["retired"] is None \
                            and rng.random() < .18 and not people[prev["fighter_id"]].get("canonical"):
                        champ = prev["fighter_id"]  # revanche imediata
                    elif rng.random() < .5 and (ready := [x for x in promoted.get((org, division), [])
                                                          if x[1] <= start <= x[1] + dt.timedelta(days=1100)]):
                        champ = ready[0][0]
                        promoted[(org, division)].remove(ready[0])
                    elif contenders and rng.random() < .45:
                        champ = contenders.pop(rng.randrange(len(contenders)))
                    if champ is not None and (busy(champ, start, end) or start.year - people[champ]["birth_year"] > 37):
                        champ = None
                    if champ is None:
                        champ = new_person(org, division, start.year)["id"]
                    defenses = min(8, max(0, int(years * rng.uniform(.6, 1.7) - .3)))
                    first = not reigns
                    if first:
                        how = "Final do Grand Prix" if org in GP_ORGS else rng.choice(["Luta inaugural", "Torneio inaugural"])
                    else:
                        how = rng.choices([m for m, _ in FINISHES], [w for _, w in FINISHES])[0]
                    if pin and end == d(pin[3]):
                        reason = "Perdeu o cinturão"
                    elif end.year == 2026 and end >= dt.date(2026, 6, 1):
                        reason = rng.choice(OPEN_ERA)
                    else:
                        reason = "Perdeu o cinturão" if rng.random() < .68 else rng.choices([v for v, _ in VACATE], [w for _, w in VACATE])[0]
                        if reason == "Vagou para subir de categoria":
                            heavier = [x for x in DIV_ORDER[DIV_ORDER.index(division) + 1:]
                                       if x in P.DIVISIONS[org] and x[0] == division[0]][:1]
                            if heavier:
                                promoted.setdefault((org, heavier[0]), []).append((champ, end))
                            else:
                                reason = "Vagou por lesão"
                    if reason.startswith("Aposentou") or "Oriente" in reason:
                        people[champ]["retired"] = end.year
                vacant_before = bool(reigns) and reigns[-1]["how_ended"] != "Perdeu o cinturão"
                reign = {"fighter_id": champ, "name": full_name(people[champ]), "country": people[champ]["country"],
                         "start": iso(start), "end": iso(end) if end else None, "defenses": defenses, "how_won": how,
                         "how_ended": reason if end else "", "vacant_before": vacant_before or not reigns,
                         "event": event_name(org, start)}
                # Luta que deu o cinturão
                loser = prev["fighter_id"] if prev and prev["how_ended"] == "Perdeu o cinturão" else None
                if loser is None:
                    opp = contenders.pop(0) if contenders else new_person(org, division, start.year)["id"]
                else:
                    opp = loser
                method = how if how in dict(FINISHES) else rng.choices([m for m, _ in FINISHES], [w for _, w in FINISHES])[0]
                add_fight(org, division, start, opp, champ, "blue", method, True, "title_change" if loser else "vacant", max_rounds)
                if not (loser is None and how in ("Luta inaugural", "Torneio inaugural", "Final do Grand Prix")) and loser is None:
                    reign["won_against"] = opp
                if loser:
                    reign["won_against"] = loser
                elif opp:
                    reign["won_against"] = opp
                people[champ]["titles"].append({"org": org, "division": division, "start": iso(start), "end": iso(end) if end else None})
                # Defesas
                last = end or END
                if defenses:
                    step = (last - start).days / (defenses + 1)
                    for k in range(defenses):
                        when = rand_date(start + dt.timedelta(days=int(step * (k + .6))), start + dt.timedelta(days=int(step * (k + 1.3))), org)
                        r = rng.random()
                        if prev and r < .12 and people[prev["fighter_id"]]["retired"] is None and prev["fighter_id"] != champ \
                                and not busy(prev["fighter_id"], when, when):
                            ch = prev["fighter_id"]
                        elif contenders and r < .35 and not busy(c := rng.choice(contenders), when, when):
                            ch = c
                            contenders.remove(c)
                        else:
                            ch = new_person(org, division, when.year)["id"]
                            if rng.random() < .5:
                                contenders.append(ch)
                        m = rng.choices([m for m, _ in FINISHES], [w for _, w in FINISHES])[0]
                        winner = "draw" if rng.random() < .03 and m.startswith("Decisão") else "blue"
                        add_fight(org, division, when, ch, champ, winner, "Empate" if winner == "draw" else m, False, "defense", max_rounds)
                reigns.append(reign)
                prev = reign
                if end is None:
                    break
                gap = 0 if reason == "Perdeu o cinturão" else rng.randint(70, 200)
                t = end + dt.timedelta(days=gap)
                if pins and reason == "Perdeu o cinturão" and d(pins[0][3]) - end < dt.timedelta(days=45):
                    t = d(pins[0][3])
            # Quem terminou 2026 em atividade e não virou campeão
            lineages.setdefault(org, {})[division] = reigns
    return lineages


# ---------------------------------------------------------------------------
# Organizações nacionais, regionais e extintas
# ---------------------------------------------------------------------------
REGIONAL_PATTERNS = {
    "pt": ["{c} Fight Night", "Desafio {c}", "{c} Combate", "Arena {c} FC", "Guerreiros de {c}", "Circuito {c} de MMA", "{c} Vale-Tudo Clássico", "Noite dos Campeões {c}"],
    "es": ["Guerra en {c}", "{c} Combate", "Noche de Guerreros {c}", "Liga {c} de MMA", "{c} Fight Club", "Reyes de {c}"],
    "en": ["{c} Fight Night", "{c} Cage Wars", "{c} Combat Series", "Battle of {c}", "{c} Fighting Championship", "{c} Brawl", "{c} Warriors League", "Kings of {c}"],
    "fr": ["{c} Combat", "Nuit des Guerriers {c}", "{c} Fight Series"],
    "ru": ["{c} Fight Nights", "{c} Combat League", "{c} Warrior Cup"],
    "ja": ["{c} Fighting Spirit", "{c} Ring Wars", "{c} Budokai MMA"],
    "pl": ["{c} Fight Arena", "Wojownicy {c}", "{c} Cage Series"],
}
LANG = {"BR": "pt", "PT": "pt", "MX": "es", "AR": "es", "CL": "es", "CO": "es", "PE": "es", "ES": "es", "FR": "fr", "BE": "fr", "MA": "fr", "CM": "fr",
        "RU": "ru", "KZ": "ru", "KG": "ru", "UZ": "ru", "TJ": "ru", "AZ": "ru", "GE": "ru", "AM": "ru", "UA": "ru", "JP": "ja", "PL": "pl"}
SPECIALTY = ["Revela prospects baratos", "Cards de trocação para TV local", "Grappling e finalizações", "Eventos em clubes pequenos lotados",
             "Torneios de uma noite", "Eventos com transmissão digital própria", "Card misto com kickboxing", "Aposta em lutadoras",
             "Promove lutas amadoras e profissionais na mesma noite", "Evento anual em praça pública"]


def build_orgs(city_by_name):
    national = []
    for oid, name, short, country, city, founded, rep, feeder, identity, status in S.NATIONAL_ORGS:
        national.append({"id": oid, "name": name, "short_name": short, "tier": "national", "base_country": country, "base_city": city,
                         "city_id": city_by_name[city]["id"], "founded": founded, "reputation": rep, "feeds": feeder,
                         "identity": identity, "situation": status,
                         "events_held": max(8, int((2027 - founded) * rng.uniform(4, 9)))})
    defunct = []
    for oid, name, short, country, city, start, end, cause, story in S.DEFUNCT_ORGS:
        defunct.append({"id": oid, "name": name, "short_name": short, "tier": "defunct", "base_country": country, "base_city": city,
                        "city_id": city_by_name[city]["id"], "founded": start, "closed": end, "cause": cause, "story": story})
    regional, names = [], {o["name"] for o in national}
    by_country = {}
    for c in S.CITIES:
        by_country.setdefault(c[1], []).append(c[0])
    weights = {c[0]: c[3] ** 1.4 for c in S.COUNTRIES if c[0] in by_country and c[0] != "MC"}
    nat_by_country = {}
    for o in national:
        nat_by_country.setdefault(o["base_country"], []).append(o["id"])
    for i in range(112):
        for _ in range(100):
            country = rng.choices(list(weights), list(weights.values()))[0]
            city = rng.choice(by_country[country])
            name = rng.choice(REGIONAL_PATTERNS[LANG.get(country, "en")]).format(c=city)
            if name not in names:
                break
        names.add(name)
        founded = rng.randint(2004, 2026)
        status = rng.choices(["ativa", "instável", "em ascensão", "à venda"], [55, 20, 18, 7])[0]
        short = "".join(w[0] for w in re.findall(r"[A-Za-zÀ-ÿ]+", name) if w[0].isupper())[:5] or name[:3].upper()
        regional.append({"id": f"reg_{i + 1:03d}", "name": name, "short_name": short, "tier": "regional", "base_country": country,
                         "base_city": city, "city_id": city_by_name[city]["id"], "founded": founded,
                         "reputation": rng.randint(4, 12) + min(16, (2027 - founded)), "events_per_year": rng.randint(3, 12),
                         "feeds": rng.choice(nat_by_country.get(country, [None])), "specialty": rng.choice(SPECIALTY), "status": status})
    return national, regional, defunct


# ---------------------------------------------------------------------------
# Lutas clássicas, rivalidades, recordes e Hall da Fama
# ---------------------------------------------------------------------------
STORY = {
    "upset": "Ninguém apostava em {w}. {l} vinha de {d} defesas e caiu {how}.",
    "late_finish": "Os dois estavam exaustos quando {w} achou {how_l} no {r}º round.",
    "split": "Decisão dividida que ainda rende discussão: muita gente viu {l} vencendo.",
    "trilogy": "Mais um capítulo de uma rivalidade que definiu a divisão.",
    "fast": "Acabou em {t} do primeiro round. {w} mal suou.",
    "vacant": "{w} ganhou o cinturão vago e começou uma nova era na divisão.",
    "draw": "Empate: ninguém saiu com a mão erguida e o cinturão ficou onde estava.",
    "default": "{w} venceu {l} {how} numa luta de campeonato lembrada até hoje.",
}


def how_phrase(method: str) -> str:
    return {"Nocaute": "por nocaute", "Nocaute técnico": "por nocaute técnico", "Finalização": "por finalização"}.get(method, "na decisão dos juízes")


def rate_fights(lineages):
    pair_count = {}
    for f in fights:
        k = tuple(sorted((f["red"], f["blue"])))
        pair_count[k] = pair_count.get(k, 0) + 1
    prior_defenses = {}
    for org, divs in lineages.items():
        for div, reigns in divs.items():
            for a, b in zip(reigns, reigns[1:]):
                if a["how_ended"] == "Perdeu o cinturão":
                    prior_defenses[(org, div, b["start"])] = a["defenses"]
    for f in fights:
        tags, stars = [], 2.4
        w = f["red"] if f["winner"] == "red" else f["blue"]
        l = f["blue"] if f["winner"] == "red" else f["red"]
        if f["title_change"] and f["kind"] == "title_change":
            stars += .7
            if prior_defenses.get((f["org"], f["division"], f["date"]), 0) >= 4:
                stars += 1.1
                tags.append("upset")
        if f["method"] in ("Nocaute", "Nocaute técnico", "Finalização"):
            stars += .4
            if f["round"] >= 4:
                stars += .9
                tags.append("late_finish")
            if f["round"] == 1 and int(f["time"].split(":")[0]) == 0:
                stars += .5
                tags.append("fast")
        if f["method"] == "Decisão dividida":
            stars += .8
            tags.append("split")
        if f["winner"] == "draw":
            stars += .6
            tags.append("draw")
        if pair_count[tuple(sorted((f["red"], f["blue"])))] >= 2:
            stars += .6
            tags.append("trilogy")
        if f["kind"] == "vacant":
            tags.append("vacant")
        f["stars"] = round(min(5.0, stars + rng.uniform(-.4, .4)), 1)
        f["tags"] = tags
        prior = prior_defenses.get((f["org"], f["division"], f["date"]), 0)
        tmpl = STORY[tags[0]] if tags else STORY["default"]
        f["story"] = tmpl.format(w=short_name(people[w]), l=short_name(people[l]), d=prior, how=how_phrase(f["method"]),
                                 how_l={"Nocaute": "o nocaute", "Nocaute técnico": "o nocaute técnico"}.get(f["method"], "a finalização"), r=f["round"], t=f["time"])


def build_classics():
    classics = []
    for a in S.ANCHOR_FIGHTS:
        when, org, num, div, red, blue, winner, method, rnd, time, stars, title, tags, story = a
        event = f"{GLOBAL_ORGS[org]['short_name']} {num}" if org in GLOBAL_ORGS else \
            {"def_imperial": "IFF Réveillon de Saitama"}.get(org, org)
        f = add_fight(org, div, d(when), red, blue, winner, method, False, "anchor", 5, rnd, time, event)
        f.update({"stars": stars, "tags": tags, "story": story, "title": title})
        classics.append(f)
    pool = [f for f in fights if f["kind"] != "anchor"]
    pool.sort(key=lambda f: (-f["stars"], f["date"]))
    chosen = pool[:70]
    for f in chosen:
        f["classic"] = True
    for f in classics:
        f["classic"] = True
    for f in fights:  # só as clássicas guardam texto; o resto é dado puro
        if not f.get("classic"):
            f.pop("story", None)
            f.pop("tags", None)
    return sorted(classics + chosen, key=lambda f: f["date"])


def build_rivalries():
    pairs = {}
    for f in fights:
        k = tuple(sorted((f["red"], f["blue"])))
        pairs.setdefault(k, []).append(f["id"])
    out = []
    for (a, b), ids in pairs.items():
        if len(ids) < 2:
            continue
        wins = {a: 0, b: 0}
        for fid in ids:
            f = next(x for x in fights if x["id"] == fid)
            if f["winner"] != "draw":
                wins[f["red"] if f["winner"] == "red" else f["blue"]] += 1
        label = "Trilogia" if len(ids) == 3 else "Quadrilogia" if len(ids) >= 4 else "Revanche"
        out.append({"a": a, "b": b, "a_name": short_name(people[a]), "b_name": short_name(people[b]), "fights": ids,
                    "score": [wins[a], wins[b]], "label": label})
    out.sort(key=lambda r: (-len(r["fights"]), r["fights"][0]))
    return out


def reign_days(r):
    end = d(r["end"]) if r["end"] else START_2027
    return (end - d(r["start"])).days


def build_records(lineages):
    reigns = [(org, div, r) for org, divs in lineages.items() for div, rs in divs.items() for r in rs]
    def top(key, n=5, reverse=True):
        return sorted(reigns, key=key, reverse=reverse)[:n]
    def entry(org, div, r, value, unit):
        return {"fighter_id": r["fighter_id"], "name": short_name(people[r["fighter_id"]]), "org": org, "division": div, "value": value, "unit": unit,
                "start": r["start"]}
    ages = [(org, div, r, d(r["start"]).year - people[r["fighter_id"]]["birth_year"]) for org, div, r in reigns]
    by_person = {}
    for org, div, r in reigns:
        by_person.setdefault(r["fighter_id"], []).append((org, div))
    multi = [(pid, v) for pid, v in by_person.items() if len({x[1] for x in v}) >= 2]
    tfw = sorted(people.values(), key=lambda p: (-p["title_fights"]["wins"], p["id"]))[:5]
    return [
        {"id": "most_defenses", "category": "Campeonato", "title": "Mais defesas de cinturão num reinado",
         "entries": [entry(o, dv, r, r["defenses"], "defesas") for o, dv, r in top(lambda x: (x[2]["defenses"], -reign_days(x[2])))]},
        {"id": "longest_reign", "category": "Campeonato", "title": "Reinado mais longo",
         "entries": [entry(o, dv, r, reign_days(r), "dias") for o, dv, r in top(lambda x: reign_days(x[2]))]},
        {"id": "youngest_champion", "category": "Campeonato", "title": "Campeão mais jovem",
         "entries": [entry(o, dv, r, age, "anos") for o, dv, r, age in sorted(ages, key=lambda x: (x[3], x[2]["start"]))[:5]]},
        {"id": "oldest_champion", "category": "Campeonato", "title": "Campeão mais velho",
         "entries": [entry(o, dv, r, age, "anos") for o, dv, r, age in sorted(ages, key=lambda x: (-x[3], x[2]["start"]))[:5]]},
        {"id": "title_fight_wins", "category": "Performance", "title": "Mais vitórias em lutas por cinturão",
         "entries": [{"fighter_id": p["id"], "name": short_name(p), "value": p["title_fights"]["wins"], "unit": "vitórias"} for p in tfw]},
        {"id": "multi_division", "category": "Histórico", "title": "Campeões em mais de uma categoria",
         "entries": [{"fighter_id": pid, "name": short_name(people[pid]), "value": len({x[1] for x in v}), "unit": "categorias",
                      "divisions": sorted({x[1] for x in v}, key=DIV_ORDER.index)} for pid, v in multi][:12]},
        {"id": "commercial", "category": "Comercial", "title": "Recordes comerciais",
         "entries": [
             {"name": "Maior público", "value": 48112, "unit": "pessoas", "note": "IFF Réveillon de Saitama (2007)"},
             {"name": "Maior público em estádio na Europa", "value": 57300, "unit": "pessoas", "note": "Wisła Fight Arena, Varsóvia (2019)"},
             {"name": "Maior venda de PPV", "value": 2350000, "unit": "compras", "note": "CROWN 198 — Carter vs. Mendes I (2022)"},
             {"name": "Maior bilheteria", "value": 21400000, "unit": "USD", "note": "CROWN 198 — Carter vs. Mendes I (2022)"},
             {"name": "Maior bolsa garantida", "value": 12000000, "unit": "USD", "note": "Riviera Fight Club (2021), paga só em parte"},
         ]},
    ]


def build_hall_of_fame(lineages):
    score = {}
    for org, divs in lineages.items():
        for div, rs in divs.items():
            for r in rs:
                s = score.setdefault(r["fighter_id"], 0)
                score[r["fighter_id"]] = s + 6 + r["defenses"] * 3 + (4 if GLOBAL_ORGS[org]["reputation"] >= 85 else 0)
    for p in people.values():
        if p.get("legend"):
            score[p["id"]] = score.get(p["id"], 0) + 25
    inductees = []
    for pid, s in sorted(score.items(), key=lambda x: (-x[1], x[0])):
        p = people[pid]
        last_title = max((d(t["end"]) for t in p["titles"] if t["end"]), default=None)
        if p.get("canonical") or p["id"] == "hist_mendes":
            continue
        if p["retired"] is None:
            if last_title is None or last_title.year > 2021:
                continue
            p["retired"] = min(2024, last_title.year + rng.randint(0, 2))
        if p["retired"] > 2024:
            continue
        inductees.append({"fighter_id": pid, "name": full_name(p), "country": p["country"], "inducted": min(2026, p["retired"] + 2),
                          "score": s, "reigns": len(p["titles"]), "citation": p["bio"] or citation(p)})
        if len(inductees) >= 36:
            break
    inductees.sort(key=lambda x: (x["inducted"], -x["score"]))
    return inductees


def citation(p):
    reigns = p["titles"]
    orgs = sorted({GLOBAL_ORGS[t["org"]]["name"] for t in reigns})
    divs = sorted({DIVISIONS[t["division"]]["name"] for t in reigns})
    return (f"{len(reigns)} reinado{'s' if len(reigns) > 1 else ''} ({', '.join(orgs)}), categoria {' e '.join(divs)}; "
            f"{p['title_fights']['wins']} vitórias em lutas por cinturão.")


ROLES = ["coach", "commentator", "gym_owner", "manager", "private", "coach", "commentator", "actor", "politician"]
CITY_OF_COUNTRY = {}
for _c in S.CITIES:
    CITY_OF_COUNTRY.setdefault(_c[1], _c[0])


def assign_roles():
    for p in people.values():
        if p.get("canonical") or p["role"] or not p["titles"] and p["retired"] is None:
            continue
        if p["retired"] is None:
            p["retired"] = min(2026, max(d(t["end"]).year for t in p["titles"] if t["end"]) + rng.randint(0, 3)) if p["titles"] and all(t["end"] for t in p["titles"]) else None
        if p["retired"] is None:
            continue
        role = rng.choice(ROLES)
        if role == "coach":
            p["role"] = "coach:" + rng.choice(GYMS)["id"]
        elif role == "commentator":
            p["role"] = "commentator:" + rng.choice(OUTLETS)["id"]
        elif role == "gym_owner":
            p["role"] = "gym_owner_city:" + CITY_OF_COUNTRY.get(p["country"], "")
        else:
            p["role"] = role


def role_text(role: str) -> str:
    kind, _, ref = role.partition(":")
    gym = {g["id"]: g["name"] for g in GYMS}
    out = {o["id"]: o["name"] for o in OUTLETS}
    orgs = {**{k: v["name"] for k, v in GLOBAL_ORGS.items()}, **{o[0]: o[1] for o in S.NATIONAL_ORGS}}
    return {
        "coach": f"Treinador na {gym.get(ref, ref)}",
        "commentator": f"Comentarista da {out.get(ref, ref)}",
        "gym_owner": f"Dono de academia ({gym.get(ref, ref)})",
        "gym_owner_city": f"Dono de academia em {ref}",
        "executive": f"Executivo da {orgs.get(ref, ref)}",
        "promoter": f"Sócio da {orgs.get(ref, ref)}",
        "manager": "Empresário de atletas",
        "private": "Vida longe do esporte",
        "actor": "Ator de filmes de ação",
        "politician": "Vereador na cidade natal",
        "media": "Apresentadora e produtora de TV",
        "inactive": "Parado por lesão; fala em voltar",
        "active": "Em atividade",
    }.get(kind, "")


# ---------------------------------------------------------------------------

def dump(name: str, data) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    text = json.dumps(data, ensure_ascii=False, separators=(",", ":"))
    (OUT / name).write_text(text + "\n", encoding="utf-8")
    print(f"  {name:28} {len(text) / 1024:7.1f} KB")


def main() -> None:
    regions, countries, cities, city_by_name, venues = build_geo()
    national, regional, defunct = build_orgs(city_by_name)
    lineages = build_lineages()
    rate_fights(lineages)
    classics = build_classics()
    rivalries = build_rivalries()
    hof = build_hall_of_fame(lineages)
    records = build_records(lineages)
    assign_roles()
    for p in people.values():
        p["role_text"] = role_text(p["role"])
    source = "tools/build_universe.py — Game Design Bible §§2–3, 13–14"
    print("universe/")
    dump("geography.json", {"version": 1, "source": source, "art_palettes": ART_PALETTES, "regions": regions, "countries": countries, "cities": cities, "venues": venues})
    dump("organizations.json", {"version": 1, "source": source, "national": national, "regional": regional, "defunct": defunct,
                                "global_history": {o: {"founded": P.FOUNDED[o], "divisions": P.DIVISIONS[o]} for o in P.FOUNDED}})
    dump("history.json", {"version": 1, "source": source,
                          "eras": [{"id": e[0], "from": e[1], "to": e[2], "name": e[3], "summary": e[4]} for e in S.ERAS],
                          "timeline": [{"date": t[0], "kind": t[1], "title": t[2], "text": t[3], "org": t[4]} for t in S.TIMELINE],
                          "classic_fights": [f["id"] for f in classics], "rivalries": rivalries, "records": records, "hall_of_fame": hof})
    dump("titles.json", {"version": 1, "source": source, "lineages": lineages})
    dump("fights.json", {"version": 1, "source": source, "fights": fights})
    dump("people.json", {"version": 1, "source": source, "people": {k: v for k, v in people.items() if not v.get("canonical") or v["titles"]}})
    reigns = sum(len(rs) for divs in lineages.values() for rs in divs.values())
    print(f"{len(countries)} países, {len(cities)} cidades, {len(venues)} arenas, {len(national)} nacionais, {len(regional)} regionais, "
          f"{len(defunct)} extintas, {reigns} reinados, {len(fights)} lutas por título, {len(classics)} clássicas, {len(people)} pessoas, "
          f"{len(rivalries)} rivalidades, {len(hof)} no Hall da Fama")


if __name__ == "__main__":
    main()
