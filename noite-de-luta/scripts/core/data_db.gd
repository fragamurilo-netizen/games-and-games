class_name DataDB
extends RefCounted
## Dados fixos do jogo, lidos uma vez: países e etnias (data/world/nations.json), culturas de
## nome (data/names/names.json) e o mundo do MMA (data/world/mma.json: categorias, ligas,
## estilos, apelidos, nomes de equipes).

static var _nations: Dictionary = {}
static var _names: Dictionary = {}
static var _mma: Dictionary = {}


static func _load(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("não abriu " + path)
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}


static func nations_doc() -> Dictionary:
	if _nations.is_empty():
		_nations = _load("res://data/world/nations.json")
	return _nations


## Culturas de nome do MUR com o complemento do MMA (data/names/fight_names.json) por cima.
static func names() -> Dictionary:
	if _names.is_empty():
		_names = _load("res://data/names/names.json")
		var extra := fight_names()
		var cultures: Dictionary = _names.get("cultures", {})
		for k in (extra.get("cultures", {}) as Dictionary):
			cultures[k] = extra["cultures"][k]
		_names["cultures"] = cultures
	return _names


static var _fight_names: Dictionary = {}


static func fight_names() -> Dictionary:
	if _fight_names.is_empty():
		_fight_names = _load("res://data/names/fight_names.json")
	return _fight_names


## De onde vêm os lutadores nascidos no país (complemento do MMA primeiro, depois o do MUR).
static func origins(code: String) -> Array:
	var o: Dictionary = fight_names().get("origins", {})
	if o.has(code):
		return o[code]
	return nation(code).get("origins", [])


## Primeiros nomes femininos para uma cultura (ou a lista do grupo parecido).
static func female_first(culture_id: String) -> Array:
	var fem: Dictionary = fight_names().get("female", {})
	if fem.has(culture_id):
		return fem[culture_id]
	var grp := String((fight_names().get("female_group", {}) as Dictionary).get(culture_id, "en"))
	return fem.get(grp, fem.get("en", ["Ana"]))


static func mma() -> Dictionary:
	if _mma.is_empty():
		_mma = _load("res://data/world/mma.json")
	return _mma


static func nation(code: String) -> Dictionary:
	return (nations_doc().get("nations", {}) as Dictionary).get(code, {})


static func nation_name(code: String) -> String:
	return String(nation(code).get("name", code))


## Gentílico ("brasileiro"); no feminino troca o -o final por -a.
static func nation_adj(code: String, fem: bool = false) -> String:
	var a := String(nation(code).get("adj", nation_name(code)))
	if fem and a.ends_with("o"):
		return a.substr(0, a.length() - 1) + "a"
	return a


static func ethnicities() -> Array:
	return nations_doc().get("ethnicities", [])


## Cidades do país: [[nome, tamanho 1-5, região], ...].
static func cities(code: String) -> Array:
	return nation(code).get("cities", [])


static func divisions() -> Array:
	return mma().get("divisions", [])


static func division(id: String) -> Dictionary:
	for d: Dictionary in divisions():
		if String(d["id"]) == id:
			return d
	return {}


## Países que formam lutadores, com o peso de cada um no mundo do MMA.
static func fight_nations() -> Dictionary:
	return mma().get("nations", {})
