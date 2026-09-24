class_name DatabaseManager
extends RefCounted
## Carrega e cacheia os dados estáticos de res://data.
## Estático (sem autoload) para funcionar também nos testes headless.
## Chame load_all() uma vez na thread principal antes de usar em threads.

const PATHS := {
	"competitions": "res://data/world/competitions.json",
	"clubs_default": "res://data/world/clubs_default.json",
	"cities": "res://data/world/cities.json",
	"names": "res://data/names/names.json",
	"archetypes": "res://data/gameplay/archetypes.json",
	"personalities": "res://data/gameplay/personalities.json",
	"formations": "res://data/gameplay/formations.json",
	"tactics": "res://data/gameplay/tactics.json",
	"commentary": "res://data/text/commentary.json",
	"news": "res://data/text/news.json",
}

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


static func load_all() -> void:
	if _loaded:
		return
	for key in PATHS:
		_load_json(key)
	_prepare_formations()
	_prepare_traits()
	_loaded = true


static func _load_json(key: String) -> Variant:
	if _cache.has(key):
		return _cache[key]
	var path: String = PATHS[key]
	var data: Variant = {}
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if parsed == null:
			push_error("DatabaseManager: JSON inválido em " + path)
		else:
			data = parsed
	else:
		push_error("DatabaseManager: arquivo ausente " + path)
	_cache[key] = data
	return data


static func get_data(key: String) -> Variant:
	if not _cache.has(key):
		return _load_json(key)
	return _cache[key]


static func competitions() -> Dictionary:
	return get_data("competitions")


static func division_config(div: int) -> Dictionary:
	return competitions()["divisions"][div]


static func division_count() -> int:
	return competitions()["divisions"].size()


static func squad_rules() -> Dictionary:
	return competitions()["squad"]


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


static func cities() -> Dictionary:
	return get_data("cities")


static func clubs_default() -> Array:
	return get_data("clubs_default")["clubs"]


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
