class_name ClubGenerator
extends RefCounted
## Cria os clubes do mundo: os autorais (data/world/clubs/<NAÇÃO>.json, nomes genéricos inspirados
## nos clubes reais) e, quando uma liga tem mais vagas que clubes autorais, clubes procedurais
## no idioma local ("{cidade} {palavra}"). Valores derivam de arquétipo, liga, reputação e cidade.

const KIT_PATTERNS: Array[String] = ["plain", "stripes_v", "stripes_h", "faixa", "diagonal", "halves"]
const KIT_PATTERN_NAMES: Array[String] = ["Liso", "Listras verticais", "Listras horizontais", "Faixa", "Diagonal", "Duas cores"]
const CREST_SHAPES: Array[String] = ["shield", "heater", "iberian", "french", "swiss", "tall", "notched", "scallop", "modern", "round", "ring", "oval", "oval_ring", "octagon", "diamond", "hexagon", "square", "pennant"]
const CREST_SHAPE_NAMES: Array[String] = ["Clássico", "Heráldico", "Ibérico", "Francês", "Suíço", "Alongado", "Recortado", "Ondulado", "Moderno", "Redondo", "Anel com nome", "Oval", "Oval com nome", "Octógono", "Losango", "Hexágono", "Quadrado", "Flâmula"]
const CREST_FIELDS: Array[String] = ["plain", "stripes:3", "stripes:5", "hoops:3", "hoops:2", "halves", "halves_h", "quarters", "sash", "sash_r", "diag", "vee", "chevron", "cross", "saltire", "chief", "pale", "tricolor_v", "tricolor_h", "lozenges", "checky", "bordure"]
const CREST_FIELD_NAMES: Array[String] = ["Liso", "Listras", "Listras finas", "Faixas", "Faixa central", "Meio a meio", "Meio a meio (horizontal)", "Quartos", "Faixa diagonal", "Diagonal invertida", "Diagonal", "V", "Divisa", "Cruz", "Aspa", "Chefe", "Pala", "Tricolor vertical", "Tricolor horizontal", "Losangos", "Xadrez", "Bordadura"]
const CREST_SYMBOLS: Array[String] = ["letter", "star", "stars:3", "ball", "crown", "eagle", "lion", "lion_head", "rooster", "wolf", "bull", "bull_charging", "fox", "bird", "seagull", "owl", "bat", "bear", "horse", "ram", "cat", "tiger", "dragon", "devil", "dolphin", "bee", "antlers", "castle", "tower", "ship", "caravel", "anchor", "anchor_oars", "cannon", "hammers", "swords", "trident", "key", "lighthouse", "torch", "tree", "rose", "fleur", "clover", "shamrock", "heart", "cross_pattee", "cross_plain", "crescent", "southern_cross", "sunrise", "mountain", "waves", "bolt", "gear", "skull", "laurel", "none"]
const CREST_SYMBOL_NAMES: Array[String] = ["Iniciais", "Estrela", "Três estrelas", "Bola", "Coroa", "Águia", "Leão", "Cabeça de leão", "Galo", "Lobo", "Touro", "Touro investindo", "Raposa", "Pássaro", "Gaivota", "Coruja", "Morcego", "Urso", "Cavalo", "Carneiro", "Felino", "Tigre", "Dragão", "Diabo", "Golfinho", "Abelha", "Chifres", "Castelo", "Torre", "Navio", "Caravela", "Âncora", "Âncora e remos", "Canhão", "Martelos", "Espadas", "Tridente", "Chave", "Farol", "Tocha", "Árvore", "Rosa", "Flor-de-lis", "Trevo", "Trevo de três folhas", "Coração", "Cruz pátea", "Cruz", "Lua crescente", "Cruzeiro do Sul", "Sol nascente", "Montanha", "Ondas", "Raio", "Engrenagem", "Caveira", "Louros", "Nenhum"]
const CREST_BORDERS: Array[String] = ["none", "thin", "thick", "double", "gold"]
const CREST_BORDER_NAMES: Array[String] = ["Sem borda", "Fina", "Grossa", "Dupla", "Dourada"]
## Símbolos de clubes gerados, por grupo.
const _CREST_ANIMALS: Array[String] = ["eagle", "lion", "lion_head", "rooster", "wolf", "bull", "fox", "bird", "owl", "bear", "horse", "ram", "cat", "tiger", "dragon", "dolphin", "bee", "seagull"]
const _CREST_OBJECTS: Array[String] = ["star", "ball", "castle", "tower", "ship", "anchor", "hammers", "swords", "key", "lighthouse", "torch", "tree", "rose", "fleur", "clover", "cross_pattee", "sunrise", "mountain", "waves", "bolt", "gear", "stars:3"]
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
	# Clubes reais: as letras do escudo saem do nome curto ("Real Madrid" → RM, "Flamengo" → FLA),
	# não do nome oficial ("Club de Regatas do Flamengo" daria CRF).
	if not (data.get("crest", {}) as Dictionary).has("initials"):
		c.crest["initials"] = String(data.get("initials", _short_initials(c)))
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
	var yb := ClubPolicy.youth_bonus(c)
	c.youth_level = clampi(int(arch.get("youth", 50)) + rng.randi_range(-8, 8) + yb, 5, 97 if yb >= 20 else 92)
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
	# Sorteio próprio do clube: uma só tirada do gerador do mundo.
	var kr := RandomNumberGenerator.new()
	kr.seed = hash([c.key, c.color1, c.color2, rng.randi()])
	c.kit_home = home_kit(kr, c, hint)
	c.kit_away = away_kit(kr, c, c.kit_home)
	c.kit_third = {}


## Estampas de clubes procedurais (peso: lisa e listras dominam, como no futebol de verdade).
const HOME_PATTERNS := {"plain": 9.0, "stripes_v": 4.0, "stripes_h": 2.0, "faixa": 1.2, "diagonal": 1.0, "halves": 1.0,
	"pinstripes": 0.8, "wide_stripes": 0.8, "center_stripe": 0.6, "hoops_thin": 0.6, "yoke": 0.5, "sash_thin": 0.5,
	"chevron": 0.4, "quarters": 0.3, "checkers": 0.2, "double_band": 0.4, "cross": 0.2, "twin_stripes": 0.3, "bottom_half": 0.3}
const COLLAR_W := {"round": 3.0, "v": 2.2, "crossover": 1.2, "polo": 1.4, "ringer": 1.0, "henley": 0.8, "wide": 0.6,
	"mandarin": 0.6, "laced": 0.3, "retro": 0.3, "zip": 0.2}
const SLEEVE_W := {"same": 4.0, "cuff": 2.4, "cuff_double": 1.0, "tipped": 0.8, "contrast": 1.2, "shoulder_stripe": 0.6,
	"raglan": 0.5, "stripes": 0.4}
const TRIM_W := {"none": 6.0, "sides": 1.0, "shoulders": 1.0, "both": 0.5, "hem": 0.4}
const SHORTS_W := {"plain": 5.0, "side_stripe": 1.4, "hem": 1.2, "piping": 1.0, "side_panel": 0.8, "hem_double": 0.5,
	"stripes3": 0.4, "vent": 0.4, "two_tone": 0.2}
const SOCKS_W := {"plain": 4.0, "top_band": 2.4, "top_stripes": 1.4, "hoops": 1.0, "stripes3": 0.8, "hoops_thin": 0.6,
	"band_mid": 0.5, "two_tone": 0.4, "chevron": 0.3, "foot": 0.3}
## Estampas tom sobre tom das camisas lisas modernas.
const TONAL := ["pinstripes", "hoops_pin", "halftone", "gradient", "argyle", "tartan", "waves", "brush", "topo", "sunburst"]
## Cores "da moda" para terceiros uniformes.
const THIRD_COLORS := ["#2BB3A3", "#B8A1E3", "#C7F464", "#3A3F47", "#F28C28", "#E8DCC4", "#7A1F3D", "#0E7C86", "#FF5E78",
	"#5B6CFF", "#1F4E3D", "#D4AF37", "#9AD1F5", "#6B2D5C", "#EDE6D6", "#101820"]
const THIRD_PATTERNS := ["plain", "gradient", "fade_up", "halftone", "brush", "shatter", "camo", "topo", "zigzag", "sunburst",
	"waves", "pixels", "harlequin", "hoop_fade", "v_big", "sash_double", "diagonal_split", "triangles", "center_panel", "tricolor_v"]
const AWAY_PATTERNS := ["faixa", "diagonal", "sash_thin", "chevron", "v_big", "side_panels", "center_stripe", "hoops_thin",
	"yoke", "shoulder_band", "double_band", "gradient", "center_panel", "twin_stripes", "band_low"]


static func _w(kr: RandomNumberGenerator, table: Dictionary) -> String:
	return String(RngUtil.pick_weighted(kr, table))


static func _lum(hex: String) -> float:
	return Color(hex).get_luminance()


## Detalhe que aparece sobre `bg`: a outra cor do clube, ou branco/preto.
static func _accent(bg: String, prefs: Array) -> String:
	for p in prefs:
		if _color_dist(Color(String(p)), Color(bg)) > 0.45:
			return String(p)
	return "#FFFFFF" if _lum(bg) < 0.5 else "#111111"


## Acabamento comum (gola, mangas, vivos, calção e meiões) sobre as cores já escolhidas.
static func _finish(kr: RandomNumberGenerator, k: Dictionary, shorts_pref: Array, socks_pref: Array) -> void:
	k["collar"] = _w(kr, COLLAR_W)
	var sl := _w(kr, SLEEVE_W)
	var pat := String(k.get("pattern", "plain"))
	if sl == "contrast" and pat in ["halves", "quarters"]:
		sl = "same"
	k["sleeve"] = sl
	k["trim"] = _w(kr, TRIM_W)
	k["c3"] = _accent(String(k["c1"]), [k["c2"], "#FFFFFF", "#111111"]) if kr.randf() < 0.85 else _accent(String(k["c1"]), ["#D4AF37", k["c2"]])
	k["shorts"] = String(RngUtil.pick(kr, shorts_pref)) if kr.randf() < 0.7 else String(shorts_pref[0])
	k["shorts2"] = _accent(String(k["shorts"]), [k["c1"], k["c2"], k["c3"]])
	k["shorts_style"] = _w(kr, SHORTS_W)
	var so := String(socks_pref[0]) if kr.randf() < 0.55 else String(RngUtil.pick(kr, socks_pref))
	k["socks"] = so
	k["socks2"] = _accent(so, [k["c2"], k["c1"], k["shorts"]])
	k["socks_style"] = _w(kr, SOCKS_W)


## Uniforme titular: estampa tradicional do clube (dica do arquivo) com acabamento sorteado.
static func home_kit(kr: RandomNumberGenerator, c: Club, hint: String) -> Dictionary:
	var pattern := hint if hint != "" and KitView.pattern_name(hint) != hint else _w(kr, HOME_PATTERNS)
	var k := {"pattern": pattern, "c1": c.color1, "c2": c.color2}
	# Camisa lisa moderna: às vezes ganha estampa discreta tom sobre tom.
	if pattern == "plain" and kr.randf() < 0.22:
		k["pattern"] = RngUtil.pick(kr, TONAL)
		k["tonal"] = true
	# Calção: a secundária é o mais comum; branco e a principal também aparecem.
	var shorts: Array = [c.color2, c.color2, "#FFFFFF", c.color1]
	if pattern in ["stripes_v", "pinstripes", "wide_stripes", "halves", "quarters", "checkers"]:
		shorts = [c.color2, "#FFFFFF", "#111111"] if _lum(c.color2) < 0.9 else [c.color1, "#111111", "#FFFFFF"]
	_finish(kr, k, shorts, [c.color1, k.get("shorts", c.color2), c.color2])
	# Meião acompanha o calção ou a camisa (sorteado em _finish); corrige combinação apagada
	if _color_dist(Color(String(k["shorts"])), Color(c.color1)) < 0.1 and pattern == "plain" and not k.has("tonal") and kr.randf() < 0.5:
		k["shorts"] = c.color2
	return k


## Uniforme reserva: branco, cores invertidas, escuro ou um tom próximo; sempre bem diferente do titular.
static func away_kit(kr: RandomNumberGenerator, c: Club, home: Dictionary) -> Dictionary:
	var home_c1 := Color(String(home.get("c1", c.color1)))
	var modes := {"white": 3.5, "invert": 3.0, "dark": 2.0, "shade": 1.2}
	if _lum(c.color1) > 0.8:
		modes.erase("white")
	var mode := _w(kr, modes)
	var c1 := "#FFFFFF"
	var c2 := c.color1
	match mode:
		"white":
			c1 = "#F4F4F2" if kr.randf() < 0.3 else "#FFFFFF"
			c2 = c.color1
		"invert":
			c1 = c.color2
			c2 = c.color1
		"dark":
			c1 = String(RngUtil.pick(kr, ["#111111", "#1A1A2E", "#0B1F4B", "#2B2F36"]))
			c2 = _accent(c1, [c.color1, c.color2])
		"shade":
			var base := Color(c.color1)
			c1 = (base.darkened(0.45) if base.get_luminance() > 0.35 else base.lightened(0.55)).to_html(false)
			c2 = _accent(c1, [c.color2, c.color1])
	if _color_dist(Color(c1), home_c1) < 0.4:
		c1 = "#FFFFFF" if home_c1.get_luminance() < 0.6 else "#15181D"
		c2 = _accent(c1, [c.color1, c.color2])
	var pattern := "plain"
	var r := kr.randf()
	if r < 0.3:
		pattern = String(RngUtil.pick(kr, AWAY_PATTERNS))
	elif r < 0.45 and String(home.get("pattern", "plain")) != "plain" and not home.get("tonal", false):
		pattern = String(home["pattern"])
	var k := {"pattern": pattern, "c1": c1, "c2": c2}
	if pattern == "plain" and kr.randf() < 0.25:
		k["pattern"] = RngUtil.pick(kr, TONAL)
		k["tonal"] = true
	_finish(kr, k, [c1, c2], [c1, c2])
	return k


## Terceiro uniforme: cor da moda e estampa ousada, com os detalhes nas cores do clube. Gerado na
## primeira vez que é pedido (sempre o mesmo para o clube).
static func make_third_kit(c: Club) -> Dictionary:
	var kr := RandomNumberGenerator.new()
	kr.seed = hash(c.key + ":3")
	var used: Array = []
	for k in [c.kit_home, c.kit_away]:
		used.append(Color(String(k.get("c1", c.color1))))
	var order: Array = range(THIRD_COLORS.size())
	RngUtil.shuffle(kr, order)
	var c1: String = THIRD_COLORS[order[0]]
	for i in order:
		var ok := true
		for u: Color in used:
			if _color_dist(Color(String(THIRD_COLORS[i])), u) < 0.45:
				ok = false
				break
		if ok:
			c1 = THIRD_COLORS[i]
			break
	var k := {"pattern": String(RngUtil.pick(kr, THIRD_PATTERNS)), "c1": c1, "c2": _accent(c1, [c.color1, c.color2])}
	if kr.randf() < 0.4 and String(k["pattern"]) != "plain":
		k["tonal"] = true
	_finish(kr, k, [c1, String(k["c2"])], [c1, String(k["c2"])])
	return k


## Cores clássicas de goleiro: [principal, detalhe].
const GK_COLORS: Array = [["#111111", "#39FF14"], ["#39FF14", "#111111"], ["#FFD400", "#111111"], ["#FF6A00", "#111111"],
	["#6A1B9A", "#FFD400"], ["#FF3EA5", "#111111"], ["#00B8D9", "#0B1F4B"], ["#7D8A99", "#111111"], ["#0B6E4F", "#F2C14E"],
	["#1E3A8A", "#7DD3FC"], ["#B91C1C", "#111111"], ["#A3E635", "#1F2937"]]


## Camisa de goleiro do clube: uma cor de goleiro bem diferente das duas camisas de linha, sempre a
## mesma para o clube (sorteio pela chave).
static func make_gk_kit(c: Club) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(c.key + ":gk")
	var order: Array = range(GK_COLORS.size())
	RngUtil.shuffle(rng, order)
	var used: Array = []
	for k in [c.kit_home, c.kit_away]:
		for f in ["c1", "c2"]:
			if k.has(f):
				used.append(Color(String(k[f])))
	var pick: Array = GK_COLORS[order[0]]
	for i in order:
		var cand: Array = GK_COLORS[i]
		var col := Color(String(cand[0]))
		var ok := true
		for u: Color in used:
			if _color_dist(col, u) < 0.35:
				ok = false
				break
		if ok:
			pick = cand
			break
	var patterns := ["plain", "plain", "plain", "side_panels", "chevron", "pixels", "yoke", "shatter", "gradient", "hoop_fade", "triangles", "brush"]
	var k := {"pattern": patterns[rng.randi_range(0, patterns.size() - 1)], "c1": pick[0], "c2": pick[1], "c3": pick[1],
		"collar": RngUtil.pick(rng, ["round", "v", "polo", "mandarin", "crossover", "zip"]), "sleeve": "same" if rng.randf() < 0.6 else "contrast", "gk": true,
		"sleeve_len": "long" if rng.randf() < 0.55 else "short", "trim": RngUtil.pick(rng, ["none", "none", "sides", "shoulders"]),
		"shorts": pick[0], "shorts2": pick[1], "socks": pick[0], "socks2": pick[1],
		"shorts_style": RngUtil.pick(rng, ["plain", "side_stripe", "piping"]), "socks_style": RngUtil.pick(rng, ["plain", "top_band", "top_stripes"])}
	if String(k["pattern"]) != "plain" and rng.randf() < 0.5:
		k["tonal"] = true
	return k


static func _color_dist(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


## Saves antigos: escudos no formato antigo (sem "field") viram os novos — os reais pelo banco
## de dados, os gerados pelo estilo do país. Imagem importada e escudo do editor ficam.
static func upgrade_crests(world: GameWorld) -> void:
	var datas := {}
	for c in world.clubs:
		if not datas.has(c.nation):
			var by_key := {}
			for d in DatabaseManager.club_data(c.nation):
				by_key[String(d.get("key", ""))] = d
			datas[c.nation] = by_key
	for c in world.clubs:
		if c.crest.has("field") or c.crest.has("img") or not Overrides.club(c.key).get("crest", {}).is_empty():
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(c.key)
		var data: Dictionary = datas[c.nation].get(c.key, {})
		var hint: Dictionary = data.get("crest", {})
		var old: Dictionary = c.crest
		_make_crest(rng, c, hint)
		if not hint.has("initials") and old.has("initials"):
			c.crest["initials"] = old["initials"]
		# Cores trocadas pelo jogador valem mais que as do banco
		if not data.is_empty() and Array(data.get("colors", [])).size() >= 2 and (String(data["colors"][0]) != c.color1 or String(data["colors"][1]) != c.color2):
			c.crest["c1"] = c.color1
			c.crest["c2"] = c.color2


## Escudo do clube: o do banco de dados (clubes reais, formato completo do CrestView) ou um
## gerado no estilo do país. Dicas antigas (só shape/symbol) viram um escudo gerado com elas.
static func _make_crest(rng: RandomNumberGenerator, c: Club, hint: Dictionary) -> void:
	if hint.has("field"):
		c.crest = hint.duplicate(true)
	else:
		c.crest = _random_crest(rng, c)
		if hint.has("shape"):
			c.crest["shape"] = String(hint["shape"])
		if hint.has("symbol"):
			c.crest["symbol"] = String(CrestView.LEGACY.get(String(hint["symbol"]), String(hint["symbol"])))
	if not c.crest.has("c1"):
		c.crest["c1"] = c.color1
	if not c.crest.has("c2"):
		c.crest["c2"] = c.color2
	if not c.crest.has("initials"):
		c.crest["initials"] = _initials(c)
	var shape := String(c.crest.get("shape", ""))
	if shape == "ring" or shape == "oval_ring":
		if String(c.crest.get("text", "")) == "":
			c.crest["text"] = c.name.to_upper()
		if String(c.crest.get("text2", "")) == "" and String(c.crest.get("year", "")) == "":
			c.crest["year"] = str(c.founded)


## Escudo gerado com a cara do futebol do país (monogramas na América do Sul, bichos na
## Inglaterra, redondos com letras na Alemanha, crescente no mundo árabe...).
static func _random_crest(rng: RandomNumberGenerator, c: Club) -> Dictionary:
	var lang := String(DatabaseManager.nation(c.nation).get("lang", ""))
	var shapes := {"shield": 3.0, "round": 3.0, "iberian": 1.0, "french": 1.0, "modern": 1.0, "ring": 0.6, "oval": 0.5, "heater": 0.5}
	var fields := {"plain": 5.0, "stripes:3": 2.0, "hoops:3": 1.0, "halves": 1.0, "sash": 0.6, "hoops:2": 0.6, "tricolor_v": 0.3, "diag": 0.4, "chief": 0.4}
	var kinds := {"letter": 3.0, "animal": 2.0, "object": 2.0}
	match lang:
		"pt_br", "pt":
			shapes = {"shield": 5.0, "round": 2.0, "iberian": 1.0, "french": 1.0, "modern": 0.6, "ring": 0.5}
			fields = {"plain": 4.0, "stripes:3": 3.0, "hoops:3": 2.0, "sash": 0.8, "halves": 0.6, "hoops:2": 0.8, "tricolor_h": 0.3, "chief": 0.6}
			kinds = {"letter": 6.0, "animal": 1.5, "object": 1.5}
		"es":
			shapes = {"shield": 3.0, "iberian": 3.0, "round": 2.0, "french": 1.0, "ring": 0.5}
			fields = {"plain": 4.0, "stripes:3": 3.0, "hoops:2": 1.0, "hoops:3": 1.0, "halves": 1.0, "sash": 0.8, "chief": 0.6}
			kinds = {"letter": 5.0, "animal": 1.5, "object": 2.0}
		"en", "sco", "en_au", "en_af":
			shapes = {"round": 3.0, "shield": 3.0, "modern": 1.5, "ring": 1.0, "heater": 1.0, "french": 0.6}
			fields = {"plain": 6.0, "halves": 1.0, "stripes:3": 1.0, "hoops:3": 0.6, "quarters": 0.5, "chevron": 0.5}
			kinds = {"letter": 1.5, "animal": 5.0, "object": 3.0}
		"de":
			shapes = {"round": 5.0, "shield": 2.0, "diamond": 0.6, "french": 0.6, "ring": 0.8}
			fields = {"plain": 6.0, "halves": 1.0, "hoops:2": 0.8, "stripes:3": 0.8, "diag": 0.5}
			kinds = {"letter": 5.0, "animal": 2.0, "object": 1.5}
		"it":
			shapes = {"shield": 2.0, "french": 2.0, "oval": 1.5, "round": 1.5, "swiss": 0.6}
			fields = {"plain": 4.0, "stripes:3": 2.5, "halves": 1.0, "cross": 0.6, "sash": 0.5}
			kinds = {"letter": 2.0, "animal": 3.5, "object": 2.0}
		"ar", "tr":
			shapes = {"round": 6.0, "shield": 1.5, "modern": 1.0, "ring": 1.0}
			fields = {"plain": 6.0, "stripes:3": 1.0, "halves": 1.0}
			kinds = {"letter": 2.5, "animal": 2.0, "object": 1.5, "crescent": 1.5}
		"ja", "ko", "zh":
			shapes = {"round": 4.0, "shield": 2.0, "modern": 2.0}
			fields = {"plain": 6.0, "stripes:3": 1.0, "halves": 0.8}
			kinds = {"letter": 2.0, "animal": 3.0, "object": 2.5}
	var shape := String(RngUtil.pick_weighted(rng, shapes))
	var field := String(RngUtil.pick_weighted(rng, fields))
	var kind := String(RngUtil.pick_weighted(rng, kinds))
	var symbol := "letter"
	match kind:
		"animal":
			symbol = _CREST_ANIMALS[rng.randi_range(0, _CREST_ANIMALS.size() - 1)]
		"object":
			symbol = _CREST_OBJECTS[rng.randi_range(0, _CREST_OBJECTS.size() - 1)]
		"crescent":
			symbol = "crescent"
	var cr := {
		"shape": shape, "field": field, "symbol": symbol, "c1": c.color1, "c2": c.color2,
		"border": CREST_BORDERS[RngUtil.weighted_index(rng, [0.8, 3.0, 2.0, 1.2, 0.6])],
	}
	# Monograma sobre listras fica ilegível sem cor própria: branco ou escuro, o que contrastar.
	if symbol == "letter" and field != "plain":
		cr["sc"] = "#FFFFFF" if Color(c.color1).get_luminance() < 0.6 else "#15171B"
	if field == "chief" and rng.randf() < 0.7:
		cr["chief_text"] = c.abbr
		cr["symbol"] = _CREST_ANIMALS[rng.randi_range(0, _CREST_ANIMALS.size() - 1)] if symbol == "letter" else symbol
	if c.nation == "ESP" and rng.randf() < 0.35:
		cr["crown"] = 1
		cr["c3"] = "#E2B84A"
	if rng.randf() < 0.06:
		cr["stars"] = rng.randi_range(1, 3)
	return cr


static func _short_initials(c: Club) -> String:
	var out := ""
	for w in c.short_name.replace("-", " ").replace(".", " ").split(" ", false):
		if w.substr(0, 1).is_valid_int():
			continue
		out += _ascii_upper(w.substr(0, 1))
		if out.length() >= 3:
			break
	return out if out.length() >= 2 else c.abbr.substr(0, 3)


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
