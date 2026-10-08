class_name Styles
extends RefCounted
## Estilos de luta (data/world/styles.json): a arte de base de cada lutador e a segunda arte que
## ele treinou. Os atributos dizem o quanto ele é bom; o estilo diz como ele luta: que golpes
## prefere, como derruba (baiana do wrestler, uchi mata do judoca, suplex do greco), que
## finalização procura e as marcas da escola que o motor lê (o wrestler daguestanês emenda as
## quedas e não deixa levantar, o tailandês prende pela nuca, o sanda segura o chute).

const SECOND_WEIGHT := 0.5
const SECOND_ATTRS := 0.45
const SPIN := ["chute_giratorio", "chute_rodado", "backfist"]

static var _doc: Dictionary = {}
static var _cache: Dictionary = {}


static func doc() -> Dictionary:
	if _doc.is_empty():
		var f := FileAccess.open("res://data/world/styles.json", FileAccess.READ)
		if f != null:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			_doc = parsed if parsed is Dictionary else {}
	return _doc


static func bases() -> Dictionary:
	return doc().get("bases", {})


static func base(id: String) -> Dictionary:
	var b: Dictionary = bases()
	return b.get(id, b.get("mma", {}))


static func name(id: String) -> String:
	return String(base(id).get("name", id))


static func short(id: String) -> String:
	return String(base(id).get("short", name(id)))


## "Wrestling livre" ou "Wrestling livre e boxe".
static func describe(f: Fighter) -> String:
	if f.base2 == "" or f.base2 == f.base:
		return name(f.base)
	var s2 := short(f.base2)
	# Minúscula no começo, menos em sigla ("MMA").
	if s2.length() > 1 and s2[1] != s2[1].to_upper():
		s2 = s2[0].to_lower() + s2.substr(1)
	return "%s e %s" % [name(f.base), s2]


static func family(id: String) -> String:
	return String(base(id).get("family", "completa"))


static func takedown(id: String) -> Dictionary:
	return (doc().get("takedowns", {}) as Dictionary).get(id, {})


static func sub(id: String) -> Dictionary:
	return (doc().get("subs", {}) as Dictionary).get(id, {"name": id, "art": "a"})


## "um mata-leão", "uma guilhotina".
static func sub_with_article(id: String) -> String:
	var s := sub(id)
	return ("um " if String(s.get("art", "a")) == "o" else "uma ") + String(s.get("name", id))


static func trait_info(id: String) -> Dictionary:
	return (doc().get("traits", {}) as Dictionary).get(id, {"name": id, "desc": ""})


## O repertório do lutador: base inteira + segunda arte pela metade. Guardado por lutador
## (muda só se a base mudar, o que não acontece durante a carreira).
static func profile(f: Fighter) -> Dictionary:
	var key := f.base + "|" + f.base2
	if _cache.has(key):
		return _cache[key]
	var b1 := base(f.base)
	var p := {"strikes": {}, "td": {}, "subs": {}, "traits": {}, "names": {}}
	_merge(p, b1, 1.0)
	if f.base2 != "" and f.base2 != f.base:
		_merge(p, base(f.base2), SECOND_WEIGHT)
	if (p["td"] as Dictionary).is_empty():
		_merge_only(p, base("mma"), "td")
	if (p["subs"] as Dictionary).is_empty():
		_merge_only(p, base("mma"), "subs")
	_cache[key] = p
	return p


static func _merge(p: Dictionary, b: Dictionary, k: float) -> void:
	# Golpes: multiplicadores; a segunda arte puxa na direção dela pela metade.
	var st: Dictionary = p["strikes"]
	for g: String in (b.get("strikes", {}) as Dictionary):
		var m := float(b["strikes"][g])
		var cur := float(st.get(g, 1.0))
		st[g] = cur * lerpf(1.0, m, k)
	for sec: String in ["td", "subs"]:
		var dst: Dictionary = p[sec]
		for t: String in (b.get(sec, {}) as Dictionary):
			dst[t] = float(dst.get(t, 0.0)) + float(b[sec][t]) * k
	var tr: Dictionary = p["traits"]
	for t: String in (b.get("traits", {}) as Dictionary):
		tr[t] = minf(1.0, float(tr.get(t, 0.0)) + float(b["traits"][t]) * k)
	var nm: Dictionary = p["names"]
	for n: String in (b.get("names", {}) as Dictionary):
		if not nm.has(n) or k >= 1.0:
			nm[n] = b["names"][n]


static func _merge_only(p: Dictionary, b: Dictionary, sec: String) -> void:
	var dst: Dictionary = p[sec]
	for t: String in (b.get(sec, {}) as Dictionary):
		dst[t] = float(b[sec][t])


## Multiplicador do golpe `kind` para o perfil (aceita os grupos "chutes" e "giros").
static func strike_mult(p: Dictionary, kind: String) -> float:
	var st: Dictionary = p["strikes"]
	var m := float(st.get(kind, 1.0))
	if kind.begins_with("chute") and st.has("chutes"):
		m *= float(st["chutes"])
	if kind in SPIN and st.has("giros"):
		m *= float(st["giros"])
	return m


static func mark(p: Dictionary, t: String) -> float:
	return float((p["traits"] as Dictionary).get(t, 0.0))


## As marcas mais fortes do estilo, para o perfil: [[nome, descrição], ...].
static func trait_list(f: Fighter, n: int = 4) -> Array:
	var tr: Dictionary = profile(f)["traits"]
	var keys := tr.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return float(tr[a]) > float(tr[b]))
	var out: Array = []
	for k: String in keys:
		if float(tr[k]) < 0.3 or out.size() >= n:
			continue
		var info := trait_info(k)
		out.append([String(info.get("name", k)), String(info.get("desc", ""))])
	return out


## Atributos puxados pelas duas artes (a segunda pesa menos).
static func attr_bias(base_id: String, base2_id: String) -> Dictionary:
	var out := {}
	for k: String in (base(base_id).get("attrs", {}) as Dictionary):
		out[k] = float(base(base_id)["attrs"][k])
	if base2_id != "" and base2_id != base_id:
		for k: String in (base(base2_id).get("attrs", {}) as Dictionary):
			var v := float(base(base2_id)["attrs"][k]) * SECOND_ATTRS
			# A segunda arte tapa o buraco da primeira, mas não cria uma fraqueza nova.
			if v < 0.0 and float(out.get(k, 0.0)) > 0.0:
				v *= 0.3
			out[k] = float(out.get(k, 0.0)) + v
	return out


## Arte de base de quem nasceu em `nation` com nome da cultura `culture` (a cultura vale antes:
## o daguestanês nascido na Rússia vem do wrestling). Nas mulheres, cada base tem seu peso.
static func pick_base(rng: RandomNumberGenerator, nation: String, culture: String, fem: bool) -> String:
	var bc: Dictionary = doc().get("base_by_culture", {})
	var bn: Dictionary = doc().get("base_by_nation", {})
	var c := culture.split("+")
	var table: Dictionary = {}
	# Família de fora (o "dag" em "us+dag") pesa mais que o país.
	if c.size() > 1 and bc.has(c[1]) and rng.randf() < 0.6:
		table = bc[c[1]]
	elif bc.has(c[0]) and (c[0] != "ru" or nation == "RUS"):
		table = bc[c[0]]
	else:
		table = bn.get(nation, bn.get("*", {"mma": 1}))
	var w := {}
	for k: String in table:
		var m := float(base(k).get("fem", 1.0)) if fem else 1.0
		if m > 0.0:
			w[k] = float(table[k]) * m
	if w.is_empty():
		return "mma"
	return String(RngUtil.weighted_key(rng, w))


## Segunda arte: quase todo mundo completa o jogo (o wrestler aprende a bater, o tailandês aprende
## a defender queda). Um em cada quatro fica só na arte de origem; quem é "MMA" não precisa.
static func pick_second(rng: RandomNumberGenerator, base_id: String, fem: bool) -> String:
	if base_id == "mma" and rng.randf() < 0.6:
		return ""
	if rng.randf() < 0.25:
		return ""
	var pairs: Dictionary = base(base_id).get("pairs", {})
	var w := {}
	for k: String in pairs:
		var m := float(base(k).get("fem", 1.0)) if fem else 1.0
		if k != base_id and m > 0.0:
			w[k] = float(pairs[k]) * m
	if w.is_empty():
		return ""
	return String(RngUtil.weighted_key(rng, w))
