class_name DatabaseManager
extends RefCounted
## Carrega e cacheia os dados estáticos de res://data.
## Estático (sem autoload) para funcionar também nos testes headless.
## Chame load_all() uma vez na thread principal antes de usar em threads.

const PATHS := {
	"rules": "res://data/world/rules.json",
	"nations": "res://data/world/nations.json",
	"leagues": "res://data/world/leagues.json",
	"continental": "res://data/world/continental.json",
	"international": "res://data/world/international.json",
	"history": "res://data/world/history.json",
	"names": "res://data/names/names.json",
	"archetypes": "res://data/gameplay/archetypes.json",
	"personalities": "res://data/gameplay/personalities.json",
	"formations": "res://data/gameplay/formations.json",
	"tactics": "res://data/gameplay/tactics.json",
	"sponsors": "res://data/gameplay/sponsors.json",
	"commentary": "res://data/text/commentary.json",
	"news": "res://data/text/news.json",
}
const CLUBS_DIR := "res://data/world/clubs/"

const POS_BY_CODE := {
	"GK": Pos.GK, "RB": Pos.RB, "CB": Pos.CB, "LB": Pos.LB, "DM": Pos.DM, "CM": Pos.CM,
	"AM": Pos.AM, "RM": Pos.RM, "LM": Pos.LM, "RW": Pos.RW, "LW": Pos.LW, "ST": Pos.ST,
}

static var _cache: Dictionary = {}
static var _loaded := false
## Formações pré-processadas: nome -> {desc, slots: [{pos:int, role:String, x, y, def, mid, att, wide}]}
static var _formations: Dictionary = {}
static var _formation_order: Array[String] = []
static var _trait_ids: Array[String] = []
static var _trait_weights: Array = []
static var _league_by_id: Dictionary = {}
static var _league_order: Array[String] = []
static var _leagues_by_nation: Dictionary = {} # nação -> [ids por divisão]
static var _league_nations: Array[String] = []
static var _club_data: Dictionary = {} # nação -> Array de dicionários de clube


static func load_all() -> void:
	if _loaded:
		return
	for key in PATHS:
		_load_json(key)
	_prepare_formations()
	_prepare_traits()
	_prepare_leagues()
	_prepare_clubs()
	_loaded = true
	Overrides.apply_db()


static func _load_json(key: String) -> Variant:
	if _cache.has(key):
		return _cache[key]
	var data: Variant = read_json(PATHS[key])
	_cache[key] = data if data != null else {}
	return _cache[key]


static func read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("DatabaseManager: arquivo ausente " + path)
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed == null:
		push_error("DatabaseManager: JSON inválido em " + path)
	return parsed


static func get_data(key: String) -> Variant:
	if not _cache.has(key):
		return _load_json(key)
	return _cache[key]


# ---------------------------------------------------------------------------
# Regras globais
# ---------------------------------------------------------------------------

static func rules() -> Dictionary:
	return get_data("rules")


static func squad_rules() -> Dictionary:
	return rules()["squad"]


static func money() -> Dictionary:
	return rules()["money"]


static func calendar_cfg() -> Dictionary:
	return rules()["calendar"]


static func start_year() -> int:
	return int(rules().get("start_year", 2026))


# ---------------------------------------------------------------------------
# Nações e ligas
# ---------------------------------------------------------------------------

static func nations() -> Dictionary:
	return get_data("nations")["nations"]


static func nation(code: String) -> Dictionary:
	return nations().get(code, {})


static func has_nation(code: String) -> bool:
	return nations().has(code)


static func sponsor_brands() -> Array:
	return _load_json("sponsors").get("brands", [])


static func kit_suppliers() -> Array:
	return _load_json("sponsors").get("suppliers", [])


static func nation_name(code: String) -> String:
	return nation(code).get("name", code)


static func nation_adj(code: String) -> String:
	return nation(code).get("adj", code)


static func ethnicities() -> Array:
	return get_data("nations")["ethnicities"]


static func lang(key: String) -> Dictionary:
	var all: Dictionary = get_data("nations")["lang"]
	return all.get(key, all["en"])


static func league_cfg(id: String) -> Dictionary:
	load_all()
	return _league_by_id.get(id, {})


static func has_league(id: String) -> bool:
	load_all()
	return _league_by_id.has(id)


static func league_ids() -> Array[String]:
	load_all()
	return _league_order


## Ids das ligas de uma nação, da primeira para a última divisão.
static func leagues_of_nation(code: String) -> Array:
	load_all()
	return _leagues_by_nation.get(code, [])


## Nações com liga jogável, na ordem dos dados (por confederação).
static func league_nations() -> Array[String]:
	load_all()
	return _league_nations


## Liga da divisão `tier` (1 = primeira) de uma nação, ou "" se não existir.
static func league_at(code: String, tier: int) -> String:
	for id in leagues_of_nation(code):
		if int(league_cfg(id)["tier"]) == tier:
			return id
	return ""


## Copas continentais e Mundial: id -> configuração (continental.json).
static func cups_cfg() -> Dictionary:
	return get_data("continental")["cups"]


static func cup_cfg(id: String) -> Dictionary:
	return cups_cfg().get(id, {})


## Futebol de seleções: datas FIFA e torneios (international.json).
static func international_cfg() -> Dictionary:
	return get_data("international")


static func tournament_cfg(id: String) -> Dictionary:
	return international_cfg().get("tournaments", {}).get(id, {})


## Clubes autorais de uma nação (arquivos em data/world/clubs).
static func club_data(code: String) -> Array:
	load_all()
	return _club_data.get(code, [])


static func _prepare_leagues() -> void:
	_league_by_id.clear()
	_league_order.clear()
	_leagues_by_nation.clear()
	_league_nations.clear()
	for l in get_data("leagues")["leagues"]:
		var id: String = l["id"]
		_league_by_id[id] = l
		_league_order.append(id)
		var n: String = l["nation"]
		if not _leagues_by_nation.has(n):
			_leagues_by_nation[n] = []
			_league_nations.append(n)
		_leagues_by_nation[n].append(id)
	for n in _leagues_by_nation:
		_leagues_by_nation[n].sort_custom(func(a, b): return int(_league_by_id[a]["tier"]) < int(_league_by_id[b]["tier"]))


static func _prepare_clubs() -> void:
	_club_data.clear()
	for n in _league_nations:
		var path := CLUBS_DIR + n + ".json"
		if not FileAccess.file_exists(path):
			_club_data[n] = []
			continue
		var d: Variant = read_json(path)
		_club_data[n] = d.get("clubs", []) if d is Dictionary else []


# ---------------------------------------------------------------------------
# Jogo
# ---------------------------------------------------------------------------

static func archetypes() -> Dictionary:
	return get_data("archetypes")


static func archetype(id: String) -> Dictionary:
	var all := archetypes()
	return all.get(id, all["tradicional_equilibrado"])


static func personalities() -> Dictionary:
	return get_data("personalities")


static func trait_data(id: String) -> Dictionary:
	return personalities()["traits"].get(id, {})


static func trait_ids() -> Array[String]:
	load_all()
	return _trait_ids


static func trait_weights() -> Array:
	load_all()
	return _trait_weights


static func tactics() -> Dictionary:
	return get_data("tactics")


static func names() -> Dictionary:
	return get_data("names")


static func commentary() -> Dictionary:
	return get_data("commentary")


static func news_templates() -> Dictionary:
	return get_data("news")


static func formation(fname: String) -> Dictionary:
	load_all()
	return _formations.get(fname, _formations["4-4-2"])


static func has_formation(fname: String) -> bool:
	load_all()
	return _formations.has(fname)


static func formation_names() -> Array[String]:
	load_all()
	return _formation_order


static func attr_index(code: String) -> int:
	return Attr.SHORT.find(code)


static func _prepare_formations() -> void:
	var raw: Dictionary = get_data("formations")
	var roles: Dictionary = raw["roles"]
	_formations.clear()
	_formation_order.clear()
	for fname in raw["order"]:
		_formation_order.append(fname)
	for fname in raw["formations"]:
		var f: Dictionary = raw["formations"][fname]
		var slots: Array = []
		for s in f["slots"]:
			var role: Dictionary = roles[s["role"]]
			slots.append({
				"pos": POS_BY_CODE[s["pos"]],
				"role": s["role"],
				"x": float(s["x"]),
				"y": float(s["y"]),
				"def": float(role["def"]),
				"mid": float(role["mid"]),
				"att": float(role["att"]),
				"wide": float(role["wide"]),
			})
		_formations[fname] = {"name": fname, "desc": f["desc"], "slots": slots}


static func formation_norms() -> Dictionary:
	return get_data("formations")["norms"]


static func _prepare_traits() -> void:
	_trait_ids.clear()
	_trait_weights.clear()
	var traits: Dictionary = personalities()["traits"]
	for id in traits:
		_trait_ids.append(id)
		_trait_weights.append(float(traits[id]["weight"]))
