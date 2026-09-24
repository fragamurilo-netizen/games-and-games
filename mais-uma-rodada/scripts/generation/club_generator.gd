class_name ClubGenerator
extends RefCounted
## Cria os clubes do mundo: os autorais (data/world/clubs/<NAÇÃO>.json, nomes genéricos inspirados
## nos clubes reais) e, quando uma liga tem mais vagas que clubes autorais, clubes procedurais
## no idioma local ("{cidade} {palavra}"). Valores derivam de arquétipo, liga, reputação e cidade.

const KIT_PATTERNS: Array[String] = ["plain", "stripes_v", "stripes_h", "faixa", "diagonal", "halves"]
const KIT_PATTERN_NAMES: Array[String] = ["Liso", "Listras verticais", "Listras horizontais", "Faixa", "Diagonal", "Duas cores"]
const CREST_SHAPES: Array[String] = ["shield", "round", "oval", "pennant", "modern", "square"]
const CREST_SHAPE_NAMES: Array[String] = ["Escudo tradicional", "Redondo", "Oval", "Triangular", "Moderno", "Quadrado"]
const CREST_SYMBOLS: Array[String] = ["star", "ball", "crown", "bolt", "wave", "sun", "mountain", "tower", "letter", "chevron", "cross", "diamond", "gear", "anchor"]
const CREST_SYMBOL_NAMES: Array[String] = ["Estrela", "Bola", "Coroa", "Raio", "Ondas", "Sol", "Montanha", "Torre", "Iniciais", "Divisa", "Cruz", "Diamante", "Engrenagem", "Âncora"]
const CREST_BORDERS: Array[String] = ["none", "thin", "thick", "double"]
const COLLARS: Array[String] = ["round", "v", "polo"]
const SLEEVES: Array[String] = ["same", "contrast"]

## Paleta para clubes procedurais: pares (principal, secundária) legíveis.
const PALETTE: Array = [
	["#C1121F", "#FFFFFF"], ["#1B3A8C", "#FFFFFF"], ["#0B6E4F", "#FFFFFF"], ["#111111", "#FFFFFF"],
	["#F2C14E", "#14213D"], ["#5B2A86", "#FFFFFF"], ["#F07F13", "#111111"], ["#2E86DE", "#FFFFFF"],
	["#7A1C1C", "#F2C14E"], ["#006D77", "#FFDDD2"], ["#E63946", "#1D3557"], ["#2A9D8F", "#264653"],
	["#FFFFFF", "#C1121F"], ["#FFFFFF", "#0B6E4F"], ["#FFFFFF", "#1B3A8C"], ["#FFD166", "#073B4C"],
	["#8338EC", "#FFBE0B"], ["#3A86FF", "#FFBE0B"], ["#606C38", "#FEFAE0"], ["#BC4749", "#F2E8CF"],
	["#D90368", "#FFFFFF"], ["#00A6ED", "#FFFFFF"], ["#9B2226", "#E9D8A6"], ["#495057", "#FF7B00"],
]

static var _city_cache: Dictionary = {} # nação -> {cidade: [tamanho, região]}


# ---------------------------------------------------------------------------
# Mundo
# ---------------------------------------------------------------------------

## Cria todos os clubes de todas as ligas. `shuffle_rep`: mundo aleatório (reputações e perfis variam).
static func build_all(world: GameWorld, rng: RandomNumberGenerator, shuffle_rep: bool) -> void:
	var datas_by_key := {}
	var used_abbr := {} # nação -> {abbr: true}
	var used_names := {} # nação -> {nome: true}
	var used_short := {} # nação -> {curto: true}
	var proc_count := {} # nação -> n
	for league_id in DatabaseManager.league_ids():
		var cfg := DatabaseManager.league_cfg(league_id)
		var nation: String = cfg["nation"]
		if not used_abbr.has(nation):
			used_abbr[nation] = {}
			used_names[nation] = {}
			used_short[nation] = {}
			proc_count[nation] = 0
			for d in DatabaseManager.club_data(nation):
				used_abbr[nation][d.get("abbr", "")] = true
				used_names[nation][d.get("name", "")] = true
				used_short[nation][d.get("short", "")] = true
		var authored: Array = []
		for d in DatabaseManager.club_data(nation):
			if d.get("league", "") == league_id:
				authored.append(d)
		for d in authored:
			var c := from_data(world, rng, d, world.clubs.size(), cfg)
			if shuffle_rep:
				_shuffle_identity(rng, c)
			world.clubs.append(c)
			datas_by_key[c.key] = d
		var missing := int(cfg["teams"]) - authored.size()
		for i in missing:
			proc_count[nation] += 1
			var c := procedural(world, rng, cfg, league_id, i, missing, proc_count[nation], used_abbr[nation], used_names[nation], used_short[nation])
			c.id = world.clubs.size()
			world.clubs.append(c)
	for c in world.clubs:
		_derive(world, rng, c)
	_resolve_rivals(world, rng, datas_by_key)


static func from_data(_world: GameWorld, rng: RandomNumberGenerator, data: Dictionary, id: int, cfg: Dictionary) -> Club:
	var c := Club.new()
	c.id = id
	c.key = data.get("key", "C%d" % id)
	c.name = data["name"]
	c.short_name = data.get("short", c.name)
	c.abbr = data.get("abbr", c.name.substr(0, 3).to_upper())
	c.nickname = data.get("nick", "")
	c.city = data.get("city", "")
	c.nation = cfg["nation"]
	c.league_id = cfg["id"]
	c.tier = int(cfg["tier"])
	c.region = region_of_city(c.nation, c.city)
	c.founded = int(data.get("founded", 1920))
	c.reputation = float(data.get("rep", 50))
	c.archetype = data.get("arch", "tradicional_equilibrado")
	var colors: Array = data.get("colors", ["#FFFFFF", "#000000"])
	c.color1 = colors[0]
	c.color2 = colors[1]
	c.stadium = data.get("stadium", "Estádio " + c.city)
	c.capacity = int(data.get("capacity", 0))
	_make_kits(rng, c, data.get("kit", ""))
	_make_crest(rng, c, data.get("crest", {}))
	return c


## Clube procedural de uma liga: `i` de `missing` vagas (os primeiros são os mais fortes).
static func procedural(_world: GameWorld, rng: RandomNumberGenerator, cfg: Dictionary, league_id: String, i: int, missing: int,
		serial: int, used_abbr: Dictionary, used_names: Dictionary, used_short: Dictionary) -> Club:
	var nation: String = cfg["nation"]
	var n := DatabaseManager.nation(nation)
	var vocab := DatabaseManager.lang(n.get("lang", "en"))
	var c := Club.new()
	c.key = "%s_P%02d" % [nation, serial]
	c.nation = nation
	c.league_id = league_id
	c.tier = int(cfg["tier"])
	# Reputação: procedurais ocupam o meio e o fundo da faixa da liga.
	var rr: Array = cfg["rep"]
	var t := 0.55 * (1.0 - float(i) / maxf(1.0, missing)) + rng.randf_range(-0.06, 0.06)
	c.reputation = clampf(lerpf(float(rr[0]), float(rr[1]), t), 5.0, 95.0)
	c.archetype = _random_archetype(rng, c.tier)
	# Cidade e palavra
	var cities: Array = n.get("cities", [["Cidade", 2]])
	var words: Array = vocab.get("words", [["FC", null]])
	var name := ""
	var word: Array = []
	var city: Array = []
	for _try in 40:
		city = cities[_weighted_city(rng, cities)]
		word = words[rng.randi_range(0, words.size() - 1)]
		name = "%s %s" % [city[0], word[0]]
		if not used_names.has(name):
			break
	used_names[name] = true
	c.name = name
	c.city = city[0]
	c.region = city[2] if city.size() > 2 else ""
	var short: String = word[0]
	if used_short.has(short) or short.length() > 14:
		short = String(city[0])
		if used_short.has(short) or short.length() > 14:
			short = String(city[0]).substr(0, 10) + " " + String(word[0]).substr(0, 3)
	used_short[short] = true
	c.short_name = short
	c.nickname = word[0]
	c.abbr = _unique_abbr(String(city[0]), String(word[0]), used_abbr)
	c.founded = rng.randi_range(1895, 1992)
	if word.size() > 1 and word[1] != null:
		c.color1 = word[1][0]
		c.color2 = word[1][1]
	else:
		var pal: Array = PALETTE[rng.randi_range(0, PALETTE.size() - 1)]
		c.color1 = pal[0]
		c.color2 = pal[1]
	var people: Array = vocab.get("people", ["Fundador"])
	var pat: String = RngUtil.pick(rng, vocab.get("stadium", ["Estádio {city}"]))
	c.stadium = pat.replace("{city}", c.city).replace("{word}", String(word[0])).replace("{person}", String(RngUtil.pick(rng, people)))
	c.capacity = 0
	_make_kits(rng, c, "")
	_make_crest(rng, c, {})
	return c


static func _weighted_city(rng: RandomNumberGenerator, cities: Array) -> int:
	var w: Array = []
	for cd in cities:
		w.append(float(cd[1]) * float(cd[1]))
	return maxi(0, RngUtil.weighted_index(rng, w))


## Mundo aleatório: a história é outra — reputações oscilam e alguns clubes mudam de perfil.
static func _shuffle_identity(rng: RandomNumberGenerator, c: Club) -> void:
	c.reputation = clampf(c.reputation + rng.randf_range(-8.0, 8.0), 5.0, 97.0)
	if rng.randf() < 0.3:
		c.archetype = _random_archetype(rng, c.tier)


static func _random_archetype(rng: RandomNumberGenerator, tier: int) -> String:
	var ids := DatabaseManager.archetypes().keys()
	var weights: Array = []
	for id in ids:
		var w := 1.0
		match id:
			"gigante_endividado", "rico_promovido", "dinheiro_gestao_ruim":
				w = 1.0 if tier <= 2 else 0.4
			"cidade_pequena", "azarao":
				w = 0.5 if tier == 1 else 1.3
			"tradicional_decadente":
				w = 0.5 if tier == 1 else 1.1
			"tradicional_equilibrado":
				w = 1.6
		weights.append(w)
	return ids[RngUtil.weighted_index(rng, weights)]


static func _unique_abbr(city: String, word: String, used: Dictionary) -> String:
	var letters := _ascii_upper(city).replace(" ", "").replace("-", "").replace("'", "")
	var wl := _ascii_upper(word).replace(" ", "").replace("-", "")
	var candidates: Array = [letters.substr(0, 3)]
	if wl.length() > 0:
		candidates.append(letters.substr(0, 2) + wl.substr(0, 1))
		candidates.append(letters.substr(0, 1) + wl.substr(0, 2))
	for i in range(1, letters.length()):
		candidates.append(letters.substr(0, 2) + letters.substr(i, 1))
	for cand in candidates:
		if cand.length() == 3 and not used.has(cand):
			used[cand] = true
			return cand
	var n := 2
	while used.has(letters.substr(0, 2) + str(n)):
		n += 1
	var out := letters.substr(0, 2) + str(n)
	used[out] = true
	return out


## Maiúsculas sem acento (siglas de 3 letras legíveis em qualquer fonte).
static func _ascii_upper(s: String) -> String:
	var from := "ÁÀÂÃÄÅÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑİŞĞÆØŁŽŠČĆĐŘŤĎŇŮÝ"
	var to := "AAAAAAEEEEIIIIOOOOOUUUUCNISGAOLZSCCDRTDNUY"
	var up := s.to_upper()
	var out := ""
	for ch in up:
		var k := from.find(ch)
		out += to[k] if k >= 0 else ch
	return out


# ---------------------------------------------------------------------------
# Cidades
# ---------------------------------------------------------------------------

static func _cities_of(nation: String) -> Dictionary:
	if not _city_cache.has(nation):
		var d := {}
		for cd in DatabaseManager.nation(nation).get("cities", []):
			d[cd[0]] = [int(cd[1]), cd[2] if cd.size() > 2 else ""]
		_city_cache[nation] = d
	return _city_cache[nation]


static func city_size(nation: String, city: String) -> int:
	return int(_cities_of(nation).get(city, [2, ""])[0])


static func region_of_city(nation: String, city: String) -> String:
	return String(_cities_of(nation).get(city, [2, ""])[1])


# ---------------------------------------------------------------------------
# Valores derivados, visual e rivais
# ---------------------------------------------------------------------------

## Valores numéricos derivados de arquétipo + reputação + cidade + cultura de público da liga.
static func _derive(_world: GameWorld, rng: RandomNumberGenerator, c: Club) -> void:
	var arch := c.arch()
	var cfg := c.league_cfg()
	var size := city_size(c.nation, c.city)
	var city_f := 0.8 + size * 0.08
	c.fan_base = int(30.0 * pow(c.reputation, 1.6) * float(arch.get("fan_mult", 1.0)) * city_f * float(cfg.get("att", 1.0)) * rng.randf_range(0.9, 1.1))
	c.fan_base = maxi(c.fan_base, 600)
	if c.capacity <= 0:
		c.capacity = int(c.fan_base * float(arch.get("stadium_mult", 1.0)) * rng.randf_range(0.9, 1.3))
		c.capacity = maxi(2000, int(round(c.capacity / 500.0)) * 500)
	c.youth_level = clampi(int(arch.get("youth", 50)) + rng.randi_range(-8, 8), 5, 99)
	c.facilities = clampi(int(float(arch.get("facilities", 50)) + (c.reputation - 60.0) * 0.4) + rng.randi_range(-8, 8), 5, 99)
	c.fan_mood = clampf(60.0 + rng.randf_range(-10.0, 10.0), 0.0, 100.0)
	c.board_confidence = 60.0
	c.cohesion = clampf(55.0 + float(arch.get("cohesion_bonus", 0)) + rng.randf_range(0.0, 10.0), 0.0, 100.0)
	var revenue := float(FinanceManager.expected_revenue(c))
	c.balance = int(revenue * float(arch.get("balance_mult", 0.3)) * rng.randf_range(0.8, 1.2))
	c.balance = int(round(c.balance / 10000.0)) * 10000


## Rivais: autorais pela chave; procedurais pelos clubes da mesma cidade ou de reputação parecida na nação.
static func _resolve_rivals(world: GameWorld, rng: RandomNumberGenerator, datas_by_key: Dictionary) -> void:
	for c in world.clubs:
		c.rivals = []
		if datas_by_key.has(c.key):
			for rk in datas_by_key[c.key].get("rivals", []):
				var r := world.club_by_key(rk)
				if r != null and r.id != c.id and not c.rivals.has(r.id):
					c.rivals.append(r.id)
	# Rivalidade é mútua; procedurais ganham rivais locais.
	for c in world.clubs:
		for rid in c.rivals:
			var r: Club = world.clubs[rid]
			if not r.rivals.has(c.id):
				r.rivals.append(c.id)
	for c in world.clubs:
		if not c.rivals.is_empty():
			continue
		var best: Club = null
		var best_v := -1e9
		for o in world.clubs:
			if o.id == c.id or o.nation != c.nation:
				continue
			var v := -absf(o.reputation - c.reputation) - absi(o.tier - c.tier) * 8.0
			if o.city == c.city:
				v += 30.0
			v += rng.randf_range(0.0, 4.0)
			if v > best_v:
				best_v = v
				best = o
		if best != null and (best.city == c.city or best_v > -12.0):
			c.rivals.append(best.id)
			if not best.rivals.has(c.id):
				best.rivals.append(c.id)


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
	var skip := ["de", "do", "da", "dos", "das", "e", "del", "la", "el", "of", "the", "Al", "FC", "SC"]
	var words := c.name.split(" ")
	var out := ""
	for w in words:
		if w.length() == 0 or skip.has(w):
			continue
		out += _ascii_upper(w.substr(0, 1))
		if out.length() >= 3:
			break
	if out.length() < 2:
		out = c.abbr.substr(0, 3)
	return out
