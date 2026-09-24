class_name ClubGenerator
extends RefCounted
## Cria os clubes (Mundo padrão a partir de JSON, ou Mundo aleatório), com valores derivados
## do arquétipo, da divisão e da reputação. Também gera escudos e uniformes.

const KIT_PATTERNS: Array[String] = ["plain", "stripes_v", "stripes_h", "faixa", "diagonal", "halves"]
const KIT_PATTERN_NAMES: Array[String] = ["Liso", "Listras verticais", "Listras horizontais", "Faixa", "Diagonal", "Duas cores"]
const CREST_SHAPES: Array[String] = ["shield", "round", "oval", "pennant", "modern", "square"]
const CREST_SHAPE_NAMES: Array[String] = ["Escudo tradicional", "Redondo", "Oval", "Triangular", "Moderno", "Quadrado"]
const CREST_SYMBOLS: Array[String] = ["star", "ball", "crown", "bolt", "wave", "sun", "mountain", "tower", "letter", "chevron", "cross", "diamond", "gear", "anchor"]
const CREST_SYMBOL_NAMES: Array[String] = ["Estrela", "Bola", "Coroa", "Raio", "Ondas", "Sol", "Montanha", "Torre", "Iniciais", "Divisa", "Cruz", "Diamante", "Engrenagem", "Âncora"]
const CREST_BORDERS: Array[String] = ["none", "thin", "thick", "double"]
const COLLARS: Array[String] = ["round", "v", "polo"]
const SLEEVES: Array[String] = ["same", "contrast"]

## Paleta para o mundo aleatório: pares (principal, secundária) legíveis.
const PALETTE: Array = [
	["#C1121F", "#FFFFFF"], ["#1B3A8C", "#FFFFFF"], ["#0B6E4F", "#FFFFFF"], ["#111111", "#FFFFFF"],
	["#F2C14E", "#14213D"], ["#5B2A86", "#FFFFFF"], ["#F07F13", "#111111"], ["#2E86DE", "#FFFFFF"],
	["#7A1C1C", "#F2C14E"], ["#006D77", "#FFDDD2"], ["#E63946", "#1D3557"], ["#2A9D8F", "#264653"],
	["#FFFFFF", "#C1121F"], ["#FFFFFF", "#0B6E4F"], ["#FFFFFF", "#1B3A8C"], ["#FFD166", "#073B4C"],
	["#8338EC", "#FFBE0B"], ["#3A86FF", "#FFBE0B"], ["#606C38", "#FEFAE0"], ["#BC4749", "#F2E8CF"],
	["#D90368", "#FFFFFF"], ["#00A6ED", "#FFFFFF"], ["#9B2226", "#E9D8A6"], ["#495057", "#FF7B00"],
]


static func from_default(world: GameWorld, rng: RandomNumberGenerator, data: Dictionary, id: int) -> Club:
	var c := Club.new()
	c.id = id
	c.name = data["name"]
	c.short_name = data.get("short", c.name)
	c.abbr = data.get("abbr", c.name.substr(0, 3).to_upper())
	c.nickname = data.get("nick", "")
	c.city = data.get("city", "")
	c.region = PlayerGenerator.region_of_city(c.city)
	c.founded = int(data.get("founded", 1920))
	c.division = int(data.get("division", 1)) - 1
	c.reputation = float(data.get("rep", 50))
	c.archetype = data.get("arch", "tradicional_equilibrado")
	var colors: Array = data.get("colors", ["#FFFFFF", "#000000"])
	c.color1 = colors[0]
	c.color2 = colors[1]
	c.stadium = data.get("stadium", "Estádio " + c.city)
	c.capacity = int(data.get("capacity", 0))
	_derive(world, rng, c)
	_make_kits(rng, c, data.get("kit", ""))
	_make_crest(rng, c, data.get("crest", {}))
	return c


## Resolve rivais por nome (depois que todos os clubes existem).
static func resolve_rivals(world: GameWorld, datas: Array) -> void:
	var by_name := {}
	for c in world.clubs:
		by_name[c.name] = c.id
	for i in datas.size():
		var d: Dictionary = datas[i]
		var c: Club = world.clubs[i]
		c.rival_id = by_name.get(d.get("rival", ""), -1)
		c.rival2_id = by_name.get(d.get("rival2", ""), -1)


## Valores numéricos derivados de arquétipo + reputação + cidade.
static func _derive(_world: GameWorld, rng: RandomNumberGenerator, c: Club) -> void:
	var arch := c.arch()
	var size := _city_size(c.city)
	var city_f := 0.8 + size * 0.08
	c.fan_base = int(pow(c.reputation, 1.6) * 25.0 * float(arch.get("fan_mult", 1.0)) * city_f * rng.randf_range(0.9, 1.1))
	c.fan_base = maxi(c.fan_base, 800)
	if c.capacity <= 0:
		c.capacity = int(c.fan_base * float(arch.get("stadium_mult", 1.0)) * rng.randf_range(0.9, 1.3))
		c.capacity = maxi(2000, int(round(c.capacity / 500.0)) * 500)
	c.youth_level = clampi(int(arch.get("youth", 50)) + rng.randi_range(-8, 8), 5, 99)
	c.facilities = clampi(int(float(arch.get("facilities", 50)) + (c.reputation - 50.0) * 0.3) + rng.randi_range(-8, 8), 5, 99)
	c.fan_mood = clampf(60.0 + rng.randf_range(-10.0, 10.0), 0.0, 100.0)
	c.board_confidence = 60.0
	c.cohesion = clampf(55.0 + float(arch.get("cohesion_bonus", 0)) + rng.randf_range(0.0, 10.0), 0.0, 100.0)
	var revenue := float(FinanceManager.expected_revenue(c))
	c.balance = int(revenue * float(arch.get("balance_mult", 0.3)) * rng.randf_range(0.8, 1.2))
	c.balance = int(round(c.balance / 10000.0)) * 10000


static func _city_size(city: String) -> int:
	for cd in DatabaseManager.cities()["cities"]:
		if cd["name"] == city:
			return int(cd["size"])
	for cd in DatabaseManager.cities()["extra_cities"]:
		if cd["name"] == city:
			return int(cd["size"])
	return 2


static func _make_kits(rng: RandomNumberGenerator, c: Club, hint: String) -> void:
	var pattern := hint if KIT_PATTERNS.has(hint) else KIT_PATTERNS[RngUtil.weighted_index(rng, [5.0, 2.0, 1.5, 1.0, 1.0, 1.0])]
	c.kit_home = {
		"pattern": pattern, "c1": c.color1, "c2": c.color2,
		"collar": RngUtil.pick(rng, COLLARS), "sleeve": "same" if rng.randf() < 0.6 else "contrast",
	}
	# Uniforme reserva: cores invertidas ou branco/escuro, padrão mais simples.
	var away_c1 := c.color2
	var away_c2 := c.color1
	if Color(away_c1).get_luminance() > 0.85 and Color(c.color1).get_luminance() > 0.85:
		away_c1 = "#1A1A2E"
	c.kit_away = {
		"pattern": "plain" if rng.randf() < 0.6 else pattern, "c1": away_c1, "c2": away_c2,
		"collar": RngUtil.pick(rng, COLLARS), "sleeve": "same",
	}


static func _make_crest(rng: RandomNumberGenerator, c: Club, hint: Dictionary) -> void:
	var shape: String = hint.get("shape", CREST_SHAPES[rng.randi_range(0, CREST_SHAPES.size() - 1)])
	var symbol: String = hint.get("symbol", CREST_SYMBOLS[rng.randi_range(0, CREST_SYMBOLS.size() - 1)])
	c.crest = {
		"shape": shape, "symbol": symbol, "c1": c.color1, "c2": c.color2,
		"border": CREST_BORDERS[RngUtil.weighted_index(rng, [1.0, 3.0, 2.0, 1.5])],
		"initials": _initials(c),
		"stripes": rng.randf() < 0.35,
	}


static func _initials(c: Club) -> String:
	var skip := ["de", "do", "da", "dos", "das", "e", "Futebol", "Clube", "Esporte", "Associação", "Atlética", "Atlético", "Sociedade", "Esportiva", "Desportiva"]
	var words := c.name.split(" ")
	var out := ""
	for w in words:
		if w.length() == 0 or skip.has(w):
			continue
		out += w.substr(0, 1).to_upper()
		if out.length() >= 3:
			break
	if out.length() < 2:
		out = c.abbr.substr(0, 3)
	return out


# ---------------------------------------------------------------------------
# Mundo aleatório
# ---------------------------------------------------------------------------

## Gera 80 clubes procedurais com cidades, nomes, arquétipos e rivais.
static func random_clubs(world: GameWorld, rng: RandomNumberGenerator) -> void:
	var cdata: Dictionary = DatabaseManager.cities()
	var pool: Array = []
	for cd in cdata["cities"]:
		pool.append(cd)
	for cd in cdata["extra_cities"]:
		pool.append(cd)
	RngUtil.shuffle(rng, pool)
	# Cidades grandes podem ter 2-3 clubes; escolhemos até completar 80.
	var entries: Array = [] # [cidade, região, tamanho]
	for cd in pool:
		var n := 1
		var s := int(cd["size"])
		if s >= 5:
			n = 3
		elif s >= 4:
			n = 2
		elif s >= 3 and rng.randf() < 0.35:
			n = 2
		for _i in n:
			entries.append(cd)
		if entries.size() >= 80:
			break
	entries = entries.slice(0, 80)
	# Ordena por "força" (tamanho da cidade + sorte) para distribuir divisões.
	var scored: Array = []
	for i in entries.size():
		var cd: Dictionary = entries[i]
		scored.append({"cd": cd, "score": float(cd["size"]) * 10.0 + rng.randf_range(0.0, 22.0)})
	scored.sort_custom(func(a, b): return a["score"] > b["score"])
	var archetypes := DatabaseManager.archetypes().keys()
	var used_names := {}
	var used_abbr := {}
	var by_city := {}
	for i in scored.size():
		var cd: Dictionary = scored[i]["cd"]
		var div := i / 20
		var c := Club.new()
		c.id = i
		c.division = div
		c.city = cd["name"]
		c.region = cd["region"]
		var cfg: Dictionary = DatabaseManager.division_config(div)
		var rr: Array = cfg["rep_range"]
		var rank_in_div := float(i % 20) / 19.0
		c.reputation = clampf(lerpf(float(rr[1]), float(rr[0]), rank_in_div) + rng.randf_range(-4.0, 4.0), 5.0, 95.0)
		c.archetype = _random_archetype(rng, div, archetypes)
		c.reputation = clampf(c.reputation + float(c.arch().get("rep_mod", 0)) * 0.5, 5.0, 95.0)
		_random_identity(rng, c, cdata, used_names, used_abbr, by_city.get(c.city, 0))
		by_city[c.city] = by_city.get(c.city, 0) + 1
		var pal: Array = PALETTE[rng.randi_range(0, PALETTE.size() - 1)]
		c.color1 = pal[0]
		c.color2 = pal[1]
		c.capacity = 0
		world.clubs.append(c)
	for c in world.clubs:
		_derive(world, rng, c)
		_make_kits(rng, c, "")
		_make_crest(rng, c, {})
	_random_rivals(rng, world)


static func _random_archetype(rng: RandomNumberGenerator, div: int, ids: Array) -> String:
	var weights: Array = []
	for id in ids:
		var w := 1.0
		match id:
			"gigante_endividado", "rico_promovido", "dinheiro_gestao_ruim":
				w = 1.2 if div <= 1 else 0.4
			"cidade_pequena", "azarao":
				w = 0.4 if div == 0 else (1.3 if div >= 2 else 0.8)
			"tradicional_decadente":
				w = 0.4 if div == 0 else 1.1
			"tradicional_equilibrado":
				w = 1.6
		weights.append(w)
	return ids[RngUtil.weighted_index(rng, weights)]


static func _random_identity(rng: RandomNumberGenerator, c: Club, cdata: Dictionary, used_names: Dictionary, used_abbr: Dictionary, nth_in_city: int) -> void:
	var patterns: Array = cdata["club_patterns"].duplicate()
	if c.region == "Litoral":
		patterns.append_array(cdata["coastal_patterns"])
	var name := ""
	var short := ""
	for _t in 20:
		var weights: Array = []
		for p in patterns:
			weights.append(float(p["weight"]))
		var pat: Dictionary = patterns[RngUtil.weighted_index(rng, weights)]
		name = String(pat["name"]).replace("{city}", c.city)
		short = String(pat["short"]).replace("{city}", c.city)
		if nth_in_city == 0 and short != c.city and rng.randf() < 0.6:
			continue
		if not used_names.has(name):
			break
	used_names[name] = true
	c.name = name
	c.short_name = short if short.length() <= 14 else c.city.substr(0, 14)
	c.abbr = _unique_abbr(c.city, used_abbr)
	c.founded = rng.randi_range(1900, 1995)
	var mascot: String = RngUtil.pick(rng, cdata["animal_nicknames"])
	c.nickname = mascot
	var stadium_pat: String = RngUtil.pick(rng, cdata["stadium_patterns"])
	var person := "%s %s" % [RngUtil.pick(rng, ["José", "Antônio", "Manoel", "Joaquim", "Pedro", "Luiz", "Ângelo", "Otávio"]), RngUtil.pick(rng, ["Tavares", "Siqueira", "Fontes", "Brandão", "Nogueira", "Queiroz", "Valadares"])]
	c.stadium = stadium_pat.replace("{city}", c.city).replace("{person}", person).replace("{mascot}", mascot.get_slice(" ", 1))


static func _unique_abbr(city: String, used: Dictionary) -> String:
	var letters := city.to_upper().replace(" ", "")
	var base := letters.substr(0, 3)
	var candidates: Array = [base]
	var words := city.to_upper().split(" ")
	if words.size() >= 2:
		candidates.append(words[0].substr(0, 2) + words[words.size() - 1].substr(0, 1))
		candidates.append(words[0].substr(0, 1) + words[words.size() - 1].substr(0, 2))
	for i in range(1, letters.length()):
		candidates.append(letters.substr(0, 2) + letters.substr(i, 1))
	for cand in candidates:
		if cand.length() == 3 and not used.has(cand):
			used[cand] = true
			return cand
	var n := 2
	while used.has(base.substr(0, 2) + str(n)):
		n += 1
	var out := base.substr(0, 2) + str(n)
	used[out] = true
	return out


static func _random_rivals(rng: RandomNumberGenerator, world: GameWorld) -> void:
	for c in world.clubs:
		var same_city: Array = []
		var same_region: Array = []
		for o in world.clubs:
			if o.id == c.id:
				continue
			if o.city == c.city:
				same_city.append(o)
			elif o.region == c.region:
				same_region.append(o)
		same_region.sort_custom(func(a, b): return absf(a.reputation - c.reputation) < absf(b.reputation - c.reputation))
		if not same_city.is_empty():
			c.rival_id = same_city[rng.randi_range(0, same_city.size() - 1)].id
			if not same_region.is_empty():
				c.rival2_id = same_region[0].id
		elif not same_region.is_empty():
			c.rival_id = same_region[0].id
			if same_region.size() > 1 and rng.randf() < 0.5:
				c.rival2_id = same_region[1].id
