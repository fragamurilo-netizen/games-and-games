class_name NameGenerator
extends RefCounted
## Nomes coerentes por cultura (names.json) a partir da origem de cada nacionalidade (nations.json):
## o jogador sorteia uma origem — cultura de nome + etnia (usada pelo rosto). Gera apelidos
## (diminutivos, regionais e descritivos), o nome de camisa (known_as) e nunca repete nomes
## completos já usados no mundo nem nomes de craques reais.

const MAX_TRIES := 12

static var _famous: Dictionary = {}
static var _eth_index: Dictionary = {}


static func _prepare() -> void:
	if not _eth_index.is_empty():
		return
	for n in DatabaseManager.names().get("famous", []):
		_famous[String(n).to_lower()] = true
	var eth: Array = DatabaseManager.ethnicities()
	for i in eth.size():
		_eth_index[eth[i]] = i


static func nationality_name(code: String) -> String:
	return DatabaseManager.nation_name(code)


static func ethnicity_index(key: String) -> int:
	_prepare()
	return int(_eth_index.get(key, 1))


## Origem de quem nasceu em `nation_code`: {"c": cultura de nome, "eth": índice da etnia}.
static func pick_origin(rng: RandomNumberGenerator, nation_code: String) -> Dictionary:
	_prepare()
	var origins: Array = DatabaseManager.nation(nation_code).get("origins", [])
	if origins.is_empty():
		return {"c": "en", "eth": 1}
	var weights: Array = []
	for o in origins:
		weights.append(float(o["w"]))
	var o: Dictionary = origins[maxi(0, RngUtil.weighted_index(rng, weights))]
	var eth_key: Variant = RngUtil.weighted_key(rng, o["eth"])
	return {"c": o["c"], "eth": int(_eth_index.get(eth_key, 1))}


static func _culture(culture_id: String) -> Dictionary:
	var cultures: Dictionary = DatabaseManager.names()["cultures"]
	return cultures.get(culture_id, cultures["en"])


static func _is_famous(first: String, main: String, last: String) -> bool:
	var f := first.to_lower()
	var m := main.to_lower()
	return _famous.has(f + " " + m) or _famous.has(f + " " + last.to_lower()) or _famous.has(m + " " + f)


## ctx: {pos, height, foot, attrs (PackedByteArray), region}
## used: Dictionary de nomes completos já usados (é atualizado).
## Retorna {first, last, nickname, known_as}.
static func generate(rng: RandomNumberGenerator, culture_id: String, ctx: Dictionary, used: Dictionary) -> Dictionary:
	_prepare()
	var c := _culture(culture_id)
	var first := ""
	var last := ""
	var main := ""
	var full := ""
	for _i in MAX_TRIES:
		first = _pick_first(rng, c)
		var a: String = RngUtil.pick(rng, c["last"])
		last = a
		main = a
		if c.has("suffixes") and rng.randf() < float(c.get("suffix_chance", 0.0)):
			last = a + " " + String(RngUtil.pick(rng, c["suffixes"]))
		elif rng.randf() < float(c.get("double_last_chance", 0.0)):
			var b: String = RngUtil.pick(rng, c["last"])
			if b != a:
				last = a + " " + b
				main = a if String(c.get("main_surname", "last")) == "first" else b
		full = first + " " + last
		if not used.has(full) and not _is_famous(first, main, last):
			break
	used[full] = true
	var nickname := ""
	var known_by: Dictionary = c.get("known_by", {"last": 1.0})
	var mode: String = RngUtil.weighted_key(rng, known_by)
	if mode == "nickname":
		nickname = _make_nickname(rng, c, first, last, ctx)
		if nickname == "":
			mode = "last"
	var known := ""
	match mode:
		"nickname":
			known = nickname
		"first":
			known = first
		"full":
			if bool(c.get("family_first", false)):
				known = main + " " + first
			else:
				known = first.get_slice(" ", 0) + " " + main
		_:
			known = main
	if _famous.has(known.to_lower()):
		known = main
	return {"first": first, "last": last, "nickname": nickname, "known_as": known}


static func _pick_first(rng: RandomNumberGenerator, c: Dictionary) -> String:
	if c.has("compound") and rng.randf() < float(c.get("compound_chance", 0.0)):
		return RngUtil.pick(rng, c["compound"])
	return RngUtil.pick(rng, c["first"])


static func _make_nickname(rng: RandomNumberGenerator, c: Dictionary, first: String, last: String, ctx: Dictionary) -> String:
	var options: Array = []
	var first_base := first.get_slice(" ", 0)
	# Diminutivo do primeiro nome
	var dims: Dictionary = c.get("diminutives", {})
	if dims.has(first_base) and rng.randf() < 0.5:
		return RngUtil.pick(rng, dims[first_base])
	# Júnior -> Juninho
	if last.ends_with("Júnior") and rng.randf() < 0.6:
		return "Juninho"
	# Regional (conforme a região da cidade natal)
	var regional: Dictionary = c.get("regional", {})
	var region: String = ctx.get("region", "")
	if region != "" and regional.has(region) and rng.randf() < 0.3:
		return RngUtil.pick(rng, regional[region])
	# Descritivo: depende de físico e atributos
	var desc: Dictionary = c.get("descriptive", {})
	if desc.is_empty():
		return ""
	var pos: int = ctx.get("pos", Pos.CM)
	var h: int = ctx.get("height", 178)
	var a: PackedByteArray = ctx.get("attrs", PackedByteArray())
	if a.size() == Attr.COUNT:
		if pos == Pos.GK and desc.has("keeper"):
			options.append("keeper")
		if h >= 192 and desc.has("tall"):
			options.append("tall")
		if h <= 168 and desc.has("short"):
			options.append("short")
		if ctx.get("foot", 0) == Player.FOOT_LEFT and pos != Pos.GK and desc.has("left"):
			options.append("left")
		if a[Attr.VEL] >= 78 and desc.has("fast"):
			options.append("fast")
		if pos == Pos.CB and a[Attr.MAR] >= 65 and desc.has("defender"):
			options.append("defender")
		if pos == Pos.DM and a[Attr.MAR] >= 62 and desc.has("destroyer"):
			options.append("destroyer")
		if (pos == Pos.CM or pos == Pos.AM) and a[Attr.VIS] >= 66 and desc.has("playmaker"):
			options.append("playmaker")
		if pos == Pos.ST and a[Attr.FOR] >= 70 and desc.has("strong"):
			options.append("strong")
		if a[Attr.TEC] >= 76 and desc.has("skill"):
			options.append("skill")
	if not options.is_empty() and rng.randf() < 0.75:
		var key: String = RngUtil.pick(rng, options)
		return RngUtil.pick(rng, desc[key])
	if desc.has("generic"):
		return RngUtil.pick(rng, desc["generic"])
	return ""
