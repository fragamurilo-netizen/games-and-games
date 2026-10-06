class_name NameGenerator
extends RefCounted
## Nomes coerentes por cultura (names.json) a partir da origem de cada nacionalidade (nations.json):
## o jogador sorteia uma origem — cultura de nome + etnia (usada pelo rosto). Quem tem família de
## outra origem (um negro nascido no País Basco, um nipo-brasileiro) ganha nome misto: sobrenome da
## família e, muitas vezes, primeiro nome do país — "Iñaki Williams", não "Iker Etxeberria". Gera apelidos
## (diminutivos, regionais e descritivos), o nome de camisa (known_as) e nunca repete nomes
## completos já usados no mundo nem nomes de craques reais.

const MAX_TRIES := 60
## Quantos jogadores do mundo podem usar o mesmo apelido ou só o primeiro nome na camisa: um
## "Canhoto" ou "Pedro" por aí é normal; vinte e cinco no mesmo mundo, não.
const NICK_MAX := 2
const FIRST_MAX := 4
## Nome de camisa comum ("Silva", "Juan González"): a partir do terceiro, entra o primeiro nome ou
## o sobrenome completo, como os clubes fazem na vida real.
const KNOWN_MAX := 3
## Diminutivo que vira nome de camisa (o resto fica só como apelido no perfil).
const DIM_SHIRT := 0.55

static var _famous: Dictionary = {}
static var _eth_index: Dictionary = {}
static var _mixing: Dictionary = {}


static func _prepare() -> void:
	if not _eth_index.is_empty():
		return
	for n in DatabaseManager.names().get("famous", []):
		_famous[String(n).to_lower()] = true
	var eth: Array = DatabaseManager.ethnicities()
	for i in eth.size():
		_eth_index[eth[i]] = i
	_mixing = DatabaseManager.names().get("mixing", {})


static func nationality_name(code: String) -> String:
	return DatabaseManager.nation_name(code)


static func ethnicity_index(key: String) -> int:
	_prepare()
	return int(_eth_index.get(key, 1))


## Origem de quem nasceu em `nation_code`: {"c": cultura de nome, "eth": índice da etnia,
## "h": cultura da família quando ela é de outra origem, senão ""}. Com família de outra origem,
## "c" vem como "país+família" (ou "país+família+m" para filho de casal misto), que generate() entende.
static func pick_origin(rng: RandomNumberGenerator, nation_code: String) -> Dictionary:
	_prepare()
	var origins: Array = DatabaseManager.nation(nation_code).get("origins", [])
	if origins.is_empty():
		return {"c": "en", "eth": 1, "h": ""}
	var weights: Array = []
	for o in origins:
		weights.append(float(o["w"]))
	var o: Dictionary = origins[maxi(0, RngUtil.weighted_index(rng, weights))]
	var eth_key: Variant = RngUtil.weighted_key(rng, o["eth"])
	var c := String(o["c"])
	# Sorteio à parte, a partir do estado atual: não consome o gerador principal, então o resto do
	# mundo (atributos, clubes, rostos) sai igual.
	var hr := RandomNumberGenerator.new()
	hr.seed = hash([rng.state, nation_code, eth_key])
	var fam := ""
	if o.has("h"):
		fam = String(RngUtil.weighted_key(hr, o["h"]))
	elif hr.randf() >= _keep_chance(c, String(eth_key)):
		fam = _heritage(hr, String(eth_key), nation_code)
	if fam != "" and fam != c:
		c += "+" + fam + ("+m" if String(eth_key) == "mix" else "")
	elif _immigrant(c, nation_code):
		fam = c # família toda de fora: nome inteiro da cultura dela ("Moussa Diarra" na França)
	else:
		fam = ""
	return {"c": c, "eth": int(_eth_index.get(eth_key, 1)), "h": fam}


## Culturas que, num país que não é o delas, indicam família imigrante (o nome todo é da família).
## As línguas do próprio país (francês na Bélgica e no Canadá, italiano na Suíça) não contam.
const IMMIGRANT := ["waf_en", "waf_fr", "ng", "gh", "sn", "ml", "ci", "cm", "cd", "bf", "ga", "zw", "gw", "ao", "cv", "mz",
	"lusoaf", "jm", "maghreb", "ma", "dz", "tn", "arab", "eg", "tr", "persian", "sas", "horn", "jp", "kr", "cn", "vn", "ph",
	"pac", "latam", "mx", "br", "south_slav", "west_slav", "east_slav", "alb", "sur", "molucca", "ssd"]


static func _immigrant(culture_id: String, nation_code: String) -> bool:
	return IMMIGRANT.has(culture_id) and not heritage_nations(culture_id).has(nation_code)


## Países da família de uma cultura (mixing.homes), para o segundo passaporte.
static func heritage_nations(culture_id: String) -> Array:
	_prepare()
	return (_mixing.get("homes", {}) as Dictionary).get(culture_id, [])


## Chance de alguém dessa etnia ter o nome todo da cultura do país (mixing.coherent).
static func _keep_chance(culture_id: String, eth_key: String) -> float:
	var coh: Dictionary = _mixing.get("coherent", {})
	if not coh.has(culture_id):
		return 1.0
	return float((coh[culture_id] as Dictionary).get(eth_key, 0.0))


## Cultura da família de quem tem essa etnia e nasceu nesse país (mixing.heritage).
static func _heritage(rng: RandomNumberGenerator, eth_key: String, nation_code: String) -> String:
	var t: Dictionary = (_mixing.get("heritage", {}) as Dictionary).get(eth_key, {})
	var w: Dictionary = t.get(nation_code, t.get("*", {}))
	if w.is_empty():
		return ""
	return String(RngUtil.weighted_key(rng, w))


## Troca a cultura do país numa origem (filosofia de clube: os da região levam nome basco).
## "es" → "eus"; "es+gh" → "eus+gh"; família toda de fora ("waf_fr") → "eus+waf_fr".
static func with_local(origin_c: String, local: String) -> String:
	var parts := origin_c.split("+")
	if parts.size() > 1:
		parts[0] = local
		return "+".join(parts)
	if IMMIGRANT.has(origin_c):
		return local + "+" + origin_c
	return local


static func _culture(culture_id: String) -> Dictionary:
	var cultures: Dictionary = DatabaseManager.names()["cultures"]
	return cultures.get(culture_id, cultures["en"])


## Cultura de nome de quem tem família de outra origem ("país+família[+m]"): sobrenome da família;
## o primeiro nome vem do país com a chance da família (diaspora_first) somada à do país
## (first_pull). Filho de casal misto (+m) às vezes leva o primeiro nome da família e o sobrenome
## do país ("Yussuf Poulsen").
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
		c.erase("diminutives")
		return c
	c["last"] = fam["last"]
	c.erase("suffixes") # "Júnior", "Neto" e "Filho" só com o sobrenome do país
	if r >= swap + (1.0 - swap) * lf:
		c["first"] = fam["first"]
		c.erase("compound")
		c.erase("diminutives")
	return c


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
	var c := _blend(rng, culture_id)
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
		# Apelido descritivo ou regional ("Trator", "Canhoto", "Baiano") fica só no perfil; nome de
		# camisa só o diminutivo do próprio nome ("Dudu", "Juninho"), e nem sempre.
		var nk := _make_nickname(rng, c, first, last, ctx)
		nickname = String(nk[0])
		var shirt := String(nk[1]) == "dim" and rng.randf() < DIM_SHIRT
		if nickname == "" or int(used.get("~k:" + nickname, 0)) >= NICK_MAX:
			nickname = ""
			shirt = false
		if not shirt:
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


## [apelido, tipo]: "dim" (diminutivo do nome, pode ir na camisa), "regional" ou "desc" (só no perfil).
static func _make_nickname(rng: RandomNumberGenerator, c: Dictionary, first: String, last: String, ctx: Dictionary) -> Array:
	var options: Array = []
	var first_base := first.get_slice(" ", 0)
	# Diminutivo do primeiro nome
	var dims: Dictionary = c.get("diminutives", {})
	if dims.has(first_base) and rng.randf() < 0.5:
		return [String(RngUtil.pick(rng, dims[first_base])), "dim"]
	# Júnior -> Juninho
	if last.ends_with("Júnior") and rng.randf() < 0.6:
		return ["Juninho", "dim"]
	# Regional (conforme a região da cidade natal)
	var regional: Dictionary = c.get("regional", {})
	var region: String = ctx.get("region", "")
	if region != "" and regional.has(region) and rng.randf() < 0.3:
		return [String(RngUtil.pick(rng, regional[region])), "regional"]
	# Descritivo: depende de físico e atributos
	var desc: Dictionary = c.get("descriptive", {})
	if desc.is_empty():
		return ["", ""]
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
		return [String(RngUtil.pick(rng, desc[key])), "desc"]
	if desc.has("generic"):
		return [String(RngUtil.pick(rng, desc["generic"])), "desc"]
	return ["", ""]



static var _shirt_nicks: Dictionary = {}


## Apelido que pode ser nome de camisa (diminutivo do nome: "Dudu", "Juninho")? Os descritivos e
## regionais ("Trator", "Baiano") não: ficam só no perfil.
static func is_shirt_nickname(nick: String) -> bool:
	if nick == "":
		return false
	if _shirt_nicks.is_empty():
		var m := {"Juninho": true}
		var cultures: Variant = DatabaseManager.names().get("cultures", {})
		if cultures is Dictionary:
			for cid in cultures:
				var dims: Variant = (cultures[cid] as Dictionary).get("diminutives", {}) if cultures[cid] is Dictionary else {}
				if dims is Dictionary:
					for k in dims:
						for n in dims[k]:
							m[String(n)] = true
		_shirt_nicks = m
	return _shirt_nicks.has(nick)
