class_name NameGenerator
extends RefCounted
## Nomes coerentes por cultura (names.json) a partir da origem de cada país (nations.json), o
## mesmo sistema do Mais Uma Rodada: o lutador sorteia uma origem (cultura de nome + etnia, que
## vai para o rosto). Quem tem família de outra origem ganha nome misto. Nunca repete nome
## completo no mundo nem cria lutadores (ou jogadores) reais famosos.

const MAX_TRIES := 60

static var _famous: Dictionary = {}
static var _eth_index: Dictionary = {}
static var _mixing: Dictionary = {}


static func _prepare() -> void:
	if not _eth_index.is_empty():
		return
	for n in DataDB.names().get("famous", []):
		_famous[String(n).to_lower()] = true
	for n in DataDB.mma().get("famous", []):
		_famous[String(n).to_lower()] = true
	var eth: Array = DataDB.ethnicities()
	for i in eth.size():
		_eth_index[eth[i]] = i
	_mixing = DataDB.names().get("mixing", {})


static func ethnicity_index(key: String) -> int:
	_prepare()
	return int(_eth_index.get(key, 1))


## Origem de quem nasceu em `nation_code`: {"c": cultura de nome, "eth": índice da etnia}.
## Com família de outra origem, "c" vem como "país+família" (ou "país+família+m"). `fem`: usa o
## peso feminino da origem ("fw"), quando houver (lutadoras do Daguestão são raras).
static func pick_origin(rng: RandomNumberGenerator, nation_code: String, fem: bool = false) -> Dictionary:
	_prepare()
	var origins: Array = DataDB.origins(nation_code)
	if origins.is_empty():
		return {"c": "en", "eth": 1, "h": ""}
	var weights: Array = []
	for o in origins:
		weights.append(float(o["w"]) * (float(o.get("fw", 1.0)) if fem else 1.0))
	var o: Dictionary = origins[maxi(0, RngUtil.weighted_index(rng, weights))]
	var eth_key: Variant = RngUtil.weighted_key(rng, o["eth"])
	var c := String(o["c"])
	var fam := ""
	if o.has("h"):
		fam = String(RngUtil.weighted_key(rng, o["h"]))
	elif rng.randf() >= _keep_chance(c, String(eth_key)):
		fam = _heritage(rng, String(eth_key), nation_code)
	if fam != "" and fam != c:
		c += "+" + fam + ("+m" if String(eth_key) == "mix" else "")
	return {"c": c, "eth": int(_eth_index.get(eth_key, 1)), "h": fam}


static func _keep_chance(culture_id: String, eth_key: String) -> float:
	var coh: Dictionary = _mixing.get("coherent", {})
	if not coh.has(culture_id):
		return 1.0
	return float((coh[culture_id] as Dictionary).get(eth_key, 0.0))


static func _heritage(rng: RandomNumberGenerator, eth_key: String, nation_code: String) -> String:
	var t: Dictionary = (_mixing.get("heritage", {}) as Dictionary).get(eth_key, {})
	var w: Dictionary = t.get(nation_code, t.get("*", {}))
	if w.is_empty():
		return ""
	return String(RngUtil.weighted_key(rng, w))


static func _culture(culture_id: String) -> Dictionary:
	var cultures: Dictionary = DataDB.names()["cultures"]
	return cultures.get(culture_id, cultures["en"])


## Cultura de nome de quem tem família de outra origem ("país+família[+m]").
static func _blend(rng: RandomNumberGenerator, culture_id: String) -> Dictionary:
	var parts := culture_id.split("+")
	var local := _culture(parts[0])
	if parts.size() < 2:
		return local
	var fam := _culture(parts[1])
	var c := local.duplicate()
	var swap := 0.3 if parts.size() > 2 and parts[2] == "m" else 0.04
	var lf := clampf(float(fam.get("diaspora_first", 0.4)) + float(local.get("first_pull", 0.0)), 0.0, 0.95)
	var r := rng.randf()
	if r < swap:
		c["first"] = fam["first"]
		c.erase("compound")
		return c
	c["last"] = fam["last"]
	c.erase("suffixes")
	if r >= swap + (1.0 - swap) * lf:
		c["first"] = fam["first"]
		c.erase("compound")
	return c


## Cultura principal (a do país) de uma origem: "br+jp" → "br".
static func base_culture(culture_id: String) -> String:
	return culture_id.split("+")[0]


static func _is_famous(first: String, main: String, last: String) -> bool:
	var f := first.to_lower()
	var m := main.to_lower()
	return _famous.has(f + " " + m) or _famous.has(f + " " + last.to_lower()) or _famous.has(m + " " + f)


## Cultura do primeiro nome numa origem mista: na maioria das vezes, a do país.
static func _first_culture(culture_id: String) -> String:
	return base_culture(culture_id)


## Nome e sobrenome. `used` guarda os nomes completos já usados (é atualizado). Mulheres
## usam a lista feminina da cultura (data/names/fight_names.json › female).
static func generate(rng_in: RandomNumberGenerator, culture_id: String, used: Dictionary, fem: bool = false) -> Dictionary:
	_prepare()
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_in.randi()
	var c := _blend(rng, culture_id)
	var first := ""
	var last := ""
	var main := ""
	var full := ""
	var zipf := float(c.get("zipf", 1.0))
	var firsts: Array = DataDB.female_first(_first_culture(culture_id)) if fem else c["first"]
	for _i in MAX_TRIES:
		if not fem and c.has("compound") and rng.randf() < float(c.get("compound_chance", 0.0)):
			first = RngUtil.pick(rng, c["compound"])
		else:
			first = _pick_list(rng, firsts, zipf)
		var s1: String = _pick_list(rng, c["last"], zipf)
		last = s1
		main = s1
		if not fem and c.has("suffixes") and rng.randf() < float(c.get("suffix_chance", 0.0)) * 0.5:
			last = s1 + " " + String(RngUtil.pick(rng, c["suffixes"]))
		elif rng.randf() < float(c.get("double_last_chance", 0.0)):
			var s2: String = _pick_list(rng, c["last"], zipf)
			if s2 != s1:
				last = s1 + " " + s2
				main = s1 if String(c.get("main_surname", "last")) == "first" else s2
		full = first + " " + last
		if not used.has(full) and not _is_famous(first, main, last):
			break
	used[full] = true
	# China e Coreia: sobrenome antes do nome ("Zhang Wei"), como nas transmissões.
	return {"first": first, "last": last, "main": main, "family_first": bool(c.get("family_first", false))}


static func _pick_list(rng: RandomNumberGenerator, arr: Array, zipf: float) -> String:
	if arr.is_empty():
		return ""
	if zipf <= 1.0:
		return String(arr[rng.randi_range(0, arr.size() - 1)])
	return String(arr[mini(arr.size() - 1, int(floor(arr.size() * pow(rng.randf(), zipf))))])
