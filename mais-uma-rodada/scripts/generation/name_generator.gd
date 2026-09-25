class_name NameGenerator
extends RefCounted
## Nomes coerentes por cultura (names.json) a partir da origem de cada nacionalidade (nations.json):
## o jogador sorteia uma origem — cultura de nome + etnia (usada pelo rosto). Gera apelidos
## (diminutivos, regionais e descritivos), o nome de camisa (known_as) e nunca repete nomes
## completos já usados no mundo nem nomes de craques reais.

const MAX_TRIES := 12
## Quantos jogadores do mundo podem usar o mesmo apelido ou só o primeiro nome na camisa: um
## "Canhoto" ou "Pedro" por aí é normal; vinte e cinco no mesmo mundo, não.
const NICK_MAX := 2
const FIRST_MAX := 4
## Nome de camisa comum ("Silva", "Juan González"): a partir do terceiro, entra o primeiro nome ou
## o sobrenome completo, como os clubes fazem na vida real.
const KNOWN_MAX := 3

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
static func generate(rng_in: RandomNumberGenerator, culture_id: String, ctx: Dictionary, used: Dictionary) -> Dictionary:
	_prepare()
	# Gerador próprio (um único sorteio do principal): mudar as listas de nomes ou as tentativas
	# contra repetidos não desloca o resto da geração do mundo (atributos, clubes, rostos).
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_in.randi()
	var c := _culture(culture_id)
	var first := ""
	var last := ""
	var main := ""
	var full := ""
	var zipf := float(c.get("zipf", 1.0))
	for _i in MAX_TRIES:
		first = _pick_first(rng, c)
		var a: String = _pick_list(rng, c["last"], zipf)
		last = a
		main = a
		if c.has("suffixes") and rng.randf() < float(c.get("suffix_chance", 0.0)):
			last = a + " " + String(RngUtil.pick(rng, c["suffixes"]))
		elif rng.randf() < float(c.get("double_last_chance", 0.0)):
			var b: String = _pick_list(rng, c["last"], zipf)
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
		if nickname == "" or int(used.get("~k:" + nickname, 0)) >= NICK_MAX:
			nickname = ""
			mode = "full" if known_by.has("full") else "last"
	elif mode == "first" and int(used.get("~k:" + first, 0)) >= FIRST_MAX:
		mode = "full" if known_by.has("full") else "last"
	var known := ""
	match mode:
		"nickname":
			known = nickname
		"first":
			known = first
		"full":
			if bool(c.get("family_first", false)):
				known = main + " " + first
			elif _suffix_of(c, last) != "" and rng.randf() < 0.6:
				# Sufixo de família vira o nome de jogo: "Vinícius Júnior", "Zé Neto"
				known = first.get_slice(" ", 0) + " " + _suffix_of(c, last)
			else:
				known = first.get_slice(" ", 0) + " " + main
		_:
			known = main
	if _famous.has(known.to_lower()):
		known = main
	if mode != "nickname" and int(used.get("~k:" + known, 0)) >= KNOWN_MAX:
		var fb := first.get_slice(" ", 0)
		var alt := (main + " " + fb) if bool(c.get("family_first", false)) else (fb + " " + main)
		if int(used.get("~k:" + alt, 0)) >= KNOWN_MAX and last != main:
			alt = fb + " " + last
		known = alt
	count_known(used, known)
	return {"first": first, "last": last, "nickname": nickname, "known_as": known}


## Registra mais um jogador com esse nome de camisa (para o limite de apelidos repetidos).
static func count_known(used: Dictionary, known: String) -> void:
	used["~k:" + known] = int(used.get("~k:" + known, 0)) + 1


static func _suffix_of(c: Dictionary, last: String) -> String:
	for sfx in c.get("suffixes", []):
		if last.ends_with(" " + String(sfx)):
			return String(sfx)
	return ""


static func _pick_first(rng: RandomNumberGenerator, c: Dictionary) -> String:
	if c.has("compound") and rng.randf() < float(c.get("compound_chance", 0.0)):
		return RngUtil.pick(rng, c["compound"])
	return _pick_list(rng, c["first"], float(c.get("zipf", 1.0)))


## Sorteio com frequência: nas listas em ordem de popularidade (zipf > 1) os primeiros nomes
## saem bem mais que os do fim — há muito mais Silva que Paquetá.
static func _pick_list(rng: RandomNumberGenerator, arr: Array, zipf: float) -> String:
	if arr.is_empty():
		return ""
	if zipf <= 1.0:
		return String(arr[rng.randi_range(0, arr.size() - 1)])
	return String(arr[mini(arr.size() - 1, int(floor(arr.size() * pow(rng.randf(), zipf))))])


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
