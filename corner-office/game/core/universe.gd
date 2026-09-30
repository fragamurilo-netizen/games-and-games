class_name Universe
extends RefCounted
## O universo fictício anterior ao save: geografia, promotoras de todas as
## camadas, 1991–2026 de história, linhagens de cinturão, lutas clássicas,
## rivalidades, recordes e Hall da Fama (Game Design Bible §§2–3, 13–14).
## Dados em res://content/universe/*.json, gerados por tools/build_universe.py.
## Só leitura: o estado vivo continua em WorldState. O único gancho no mundo é
## `apply_titles`, que coroa os campeões de 2027 em Organization.titles.

const DIR := "res://content/universe"
const OPEN_ERA := {"year": 2027, "month": 1, "day": 1}

static var _cache := {}
static var _index := {}


## Arquivo inteiro (lazy). Sem ContentDB.normalize_ints: são ~1 MB e a UI
## converte o que precisa com int().
static func data(file: String) -> Dictionary:
	if not _cache.has(file):
		var f := FileAccess.open("%s/%s.json" % [DIR, file], FileAccess.READ)
		var parsed: Variant = JSON.parse_string(f.get_as_text()) if f else null
		if typeof(parsed) != TYPE_DICTIONARY:
			push_error("Universe: não foi possível ler %s" % file)
			parsed = {}
		_cache[file] = parsed
	return _cache[file]


static func _indexed(key: String, file: String, list_key: String) -> Dictionary:
	if not _index.has(key):
		var out := {}
		for item: Dictionary in data(file).get(list_key, []):
			out[item.id] = item
		_index[key] = out
	return _index[key]


# --- Geografia --------------------------------------------------------------

static func regions() -> Array:
	return data("geography").get("regions", [])


static func countries() -> Array:
	return data("geography").get("countries", [])


static func country(id: String) -> Dictionary:
	return _indexed("countries", "geography", "countries").get(id, {})


static func country_name(id: String) -> String:
	return str(country(id).get("name", id))


static func cities(country_id: String = "") -> Array:
	var all: Array = data("geography").get("cities", [])
	return all if country_id.is_empty() else all.filter(func(c): return c.country == country_id)


static func city(id: String) -> Dictionary:
	return _indexed("cities", "geography", "cities").get(id, {})


static func city_by_name(name: String) -> Dictionary:
	for c: Dictionary in cities():
		if c.name == name:
			return c
	return {}


static func venue(id: String) -> Dictionary:
	return _indexed("venues", "geography", "venues").get(id, {})


static func venues_in(city_id: String) -> Array:
	return city(city_id).get("venues", []).map(func(id): return venue(id))


# --- Organizações -----------------------------------------------------------

## tier: "global" | "national" | "regional" | "defunct"
static func organizations(tier: String) -> Array:
	if tier == "global":
		var hist: Dictionary = data("organizations").get("global_history", {})
		var out: Array = []
		for o: Dictionary in ContentDB.load_json("organizations.json"):
			var copy := o.duplicate()
			copy.merge(hist.get(o.id, {}))
			copy["city_id"] = city_by_name(o.base_city).get("id", "")
			out.append(copy)
		return out
	return data("organizations").get(tier, [])


static func organization(id: String) -> Dictionary:
	if not _index.has("orgs"):
		var out := {}
		for tier in ["global", "national", "regional", "defunct"]:
			for o: Dictionary in organizations(tier):
				out[o.id] = o
		_index["orgs"] = out
	return _index["orgs"].get(id, {})


static func organizations_in(country_id: String) -> Array:
	var out: Array = []
	for tier in ["global", "national", "regional", "defunct"]:
		out.append_array(organizations(tier).filter(func(o): return o.base_country == country_id))
	return out


# --- Cinturões --------------------------------------------------------------

static func divisions_of(org_id: String) -> Array:
	var lineages: Dictionary = data("titles").get("lineages", {}).get(org_id, {})
	var order: Array = ContentDB.load_json("weight_classes.json").map(func(w): return w.id)
	var out: Array = lineages.keys()
	out.sort_custom(func(a, b): return order.find(a) < order.find(b))
	return out


static func lineage(org_id: String, division: String) -> Array:
	return data("titles").get("lineages", {}).get(org_id, {}).get(division, [])


## Último reinado até dez/2026 ({} se a divisão não existe na organização).
static func last_reign(org_id: String, division: String) -> Dictionary:
	var l := lineage(org_id, division)
	return l[-1] if not l.is_empty() else {}


## Coroa os campeões de 2027 (gancho de Rankings: org.titles[div].champion_id).
## Quem reinava em dez/2026 e existe no mundo continua campeão; divisões cujo
## último campeão saiu na virada da Open Era ficam com o melhor atleta do
## elenco naquela categoria (critério determinístico, sem world.rng).
## `only_if_empty` preserva saves que já têm cinturões.
static func apply_titles(world: WorldState, only_if_empty: bool = false) -> void:
	for org_id: String in world.organizations:
		var org: Organization = world.organizations[org_id]
		if org.is_player or (only_if_empty and not org.titles.is_empty()):
			continue
		for division: String in divisions_of(org_id):
			var reign := last_reign(org_id, division)
			var champion := ""
			var since := OPEN_ERA
			if reign.get("end") == null and world.fighters.has(str(reign.get("fighter_id", ""))):
				champion = reign.fighter_id
				since = _date(reign.start)
			else:
				champion = _best_in(world, org, division)
				since = {"year": 2026, "month": 12, "day": 19}
			if champion.is_empty():
				continue
			org.titles[division] = {"champion_id": champion, "interim_id": "", "since": since}


static func _best_in(world: WorldState, org: Organization, division: String) -> String:
	var best := ""
	var best_key := []
	for id: String in org.roster:
		var f: Fighter = world.fighters.get(id)
		if f == null or f.division != division:
			continue
		var key := [int(f.record.wins) - int(f.record.losses), int(f.record.wins)]
		if best.is_empty() or key > best_key or (key == best_key and id < best):
			best = id
			best_key = key
	return best


## Campeão atual como Dictionary pronto para a UI ({} se vago).
static func current_champion(world: WorldState, org_id: String, division: String) -> Dictionary:
	if world == null or not world.organizations.has(org_id):
		return {}
	var t: Dictionary = world.organizations[org_id].titles.get(division, {})
	var f: Fighter = world.fighters.get(str(t.get("champion_id", "")))
	if f == null:
		return {}
	return {"id": f.id, "name": f.display_name(), "country": f.country, "since": t.get("since", OPEN_ERA)}


# --- Pessoas, lutas e memória ----------------------------------------------

static func person(id: String) -> Dictionary:
	return data("people").get("people", {}).get(id, {})


static func person_name(id: String) -> String:
	var p := person(id)
	if p.is_empty():
		return id
	return "%s %s" % [p.first_name, p.last_name]


static func fight(id: String) -> Dictionary:
	return _indexed("fights", "fights", "fights").get(id, {})


static func fights_of(person_id: String) -> Array:
	return data("fights").get("fights", []).filter(func(f): return f.red == person_id or f.blue == person_id)


static func classic_fights() -> Array:
	return data("history").get("classic_fights", []).map(func(id): return fight(id))


static func eras() -> Array:
	return data("history").get("eras", [])


static func timeline() -> Array:
	return data("history").get("timeline", [])


static func rivalries() -> Array:
	return data("history").get("rivalries", [])


static func records() -> Array:
	return data("history").get("records", [])


static func hall_of_fame() -> Array:
	return data("history").get("hall_of_fame", [])


static func legends_from(country_id: String) -> Array:
	return hall_of_fame().filter(func(h): return h.country == country_id)


## "Neste dia": marcos e lutas clássicas no mesmo dia/mês (para notícias e UI).
static func on_this_day(date: Dictionary) -> Array:
	var key := "-%02d-%02d" % [int(date.month), int(date.day)]
	var out: Array = []
	for t: Dictionary in timeline():
		if str(t.date).ends_with(key):
			out.append({"year": int(str(t.date).left(4)), "title": t.title, "text": t.text})
	for f: Dictionary in classic_fights():
		if str(f.date).ends_with(key):
			out.append({"year": int(str(f.date).left(4)), "title": "%s: %s × %s" % [f.event, person_name(f.red), person_name(f.blue)],
				"text": str(f.get("story", ""))})
	out.sort_custom(func(a, b): return a.year < b.year)
	return out


static func _date(iso: String) -> Dictionary:
	var p := iso.split("-")
	return {"year": int(p[0]), "month": int(p[1]), "day": int(p[2])}


static func format_date(iso: Variant) -> String:
	if iso == null or str(iso).is_empty():
		return "hoje"
	return GameDate.format(_date(str(iso)))
