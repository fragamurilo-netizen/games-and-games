class_name StadiumStyle
extends RefCounted
## Como o estádio da partida aparece no campo 2D: tipo de construção, clima, hora do jogo,
## lotação e as placas de publicidade em volta do gramado.
##   arena     — moderno, cobertura fechada, arquibancada colada no campo e placas de LED
##   caldeirao — arquibancada íngreme, alambrado, bandeirões e fumaça na hora do gol
##   olimpico  — pista de atletismo, torcida mais longe, placas na beira da pista
##   acanhado  — estádio pequeno: uma arquibancada principal, muro pintado e refletores em torres
##   nacional  — campo neutro de final: torcida dividida, telão e placas da competição
## Tudo é decidido de forma determinística pelo clube, pela competição e pela rodada.

const KINDS: Array[String] = ["arena", "caldeirao", "olimpico", "acanhado", "nacional"]
const HOT_NATIONS: Array[String] = ["BRA", "ARG", "URU", "PAR", "COL", "CHI", "ECU", "PER", "BOL", "VEN", "MEX", "TUR", "GRE", "SRB", "CRO", "EGY", "MAR", "TUN", "ALG", "RSA"]
const SUNNY: Array[String] = ["BRA", "ARG", "URU", "PAR", "COL", "ECU", "PER", "BOL", "VEN", "MEX", "KSA", "QAT", "UAE", "EGY", "MAR", "TUN", "ALG", "ESP", "POR", "ITA", "GRE", "TUR", "RSA", "NGA", "AUS", "USA"]
const RAINY: Array[String] = ["ENG", "SCO", "IRL", "NED", "BEL", "GER", "DEN", "NOR", "SWE", "JPN", "KOR", "CHN"]
const TRACK_WORDS: Array[String] = ["Olímpic", "Olimpic", "Olympia", "Olympiastadion", "Olimpiyat", "Olympisch", "Olympic Sports", "Estadio Nacional", "Olímpico"]


static func kind_for(w: GameWorld, home: Club, neutral: bool) -> String:
	if neutral:
		return "nacional"
	var name := home.stadium
	for word in TRACK_WORDS:
		if name.contains(word) and not name.begins_with("Parc"):
			return "olimpico"
	var tier := 1
	var lg := w.league_of(home.id) if w != null else null
	if lg != null:
		tier = lg.tier
	var cap := home.capacity
	var h := absi(hash(home.key + name))
	if cap < 16000 or (tier >= 3 and cap < 30000):
		return "acanhado"
	if HOT_NATIONS.has(home.nation):
		if cap >= 50000 and h % 5 == 0:
			return "olimpico"
		return "caldeirao" if (cap < 60000 or h % 3 != 0) else "arena"
	if cap >= 45000 and h % 7 == 0:
		return "olimpico"
	if cap < 22000 and h % 3 == 0:
		return "caldeirao"
	return "arena"


## {kind, night, rain, weather, fill, cap, brands, comp_brand, seats, grass, away_share}
static func for_match(w: GameWorld, fx: Fixture, home: Club, away: Club, neutral: bool, attendance: int, seed_value: int) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	var kind := kind_for(w, home, neutral)
	var league := w.league(fx.comp) if w != null else null
	var continental := league == null and fx.comp != "F" and not fx.comp.begins_with("C:")
	var p_night := 0.75 if continental else 0.42
	var night := r.randf() < p_night
	var nation := home.nation
	var p_rain := 0.3 if RAINY.has(nation) else (0.12 if SUNNY.has(nation) else 0.2)
	var rain := r.randf() < p_rain
	var weather := "cloud"
	if night:
		weather = "night_rain" if rain else ("cold" if RAINY.has(nation) and r.randf() < 0.5 else "night")
	elif rain:
		weather = "rain"
	elif SUNNY.has(nation) and r.randf() < 0.45:
		weather = "heat"
	elif r.randf() < 0.15:
		weather = "wind"
	elif r.randf() < 0.6:
		weather = "sun"
	var cap := maxi(1000, home.capacity)
	var fill := clampf(float(attendance) / float(cap), 0.12, 1.0)
	var tier_goal := 1
	if continental or kind == "nacional":
		tier_goal = 3
	elif league != null:
		tier_goal = 3 if league.tier == 1 and home.reputation >= 70.0 else (2 if league.tier <= 2 else 1)
	return {
		"kind": kind, "night": night, "rain": rain, "weather": weather, "fill": fill, "cap": cap,
		"brands": _brands(w, fx, home, tier_goal, continental, r), "fence_brands": _fence_brands(home, r), "seed": seed_value,
		"away_share": 0.5 if neutral else clampf(0.06 + away.reputation / 900.0, 0.05, 0.16),
	}


## Placas do jogo: patrocinadores do mandante primeiro (o master aparece mais de uma vez), depois
## as parceiras da competição e as marcas do país no tamanho do jogo. Tudo sai do BrandCatalog,
## então num jogo na Inglaterra só aparecem marcas inglesas e multinacionais.
static func _brands(w: GameWorld, fx: Fixture, home: Club, tier_goal: int, continental: bool, r: RandomNumberGenerator) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	var add := func(b: Dictionary) -> void:
		var n := String(b.get("n", ""))
		if n == "" or seen.has(n):
			return
		seen[n] = true
		out.append({"n": n, "c": String(b.get("c", "#1B1B1B")), "t": String(b.get("t", "#FFFFFF")),
			"m": String(b.get("m", "")), "logo": String(b.get("logo", ""))})
	var master: Dictionary = home.sponsors.get("master", {})
	for s in SponsorManager.SLOTS:
		var ct: Dictionary = home.sponsors.get(s[0], {})
		if not ct.is_empty():
			var e := BrandCatalog.find(String(ct.get("n", "")))
			var b := ct.duplicate()
			if not b.has("m") or String(b.get("m", "")) == "":
				b["m"] = e.get("m", "")
			add.call(b)
	if fx != null and fx.comp != "F":
		for b in BrandCatalog.competition_partners(fx.comp, home.nation, continental, 3 if tier_goal >= 2 else 2):
			add.call(b)
	var pool := BrandCatalog.brands_for(home.nation, tier_goal, "placa", w.league_of(home.id).tier if w != null and w.league_of(home.id) != null else 1, home.city)
	RngUtil.shuffle(r, pool)
	for b: Dictionary in pool:
		if out.size() >= 11:
			break
		add.call(b)
	if out.is_empty():
		out.append({"n": home.short_name, "c": home.color1, "t": home.color2, "m": "", "logo": ""})
	# O master do clube volta no meio da fila: é quem mais aparece em volta do gramado.
	if not master.is_empty() and out.size() >= 6:
		out.insert(out.size() / 2, out[0].duplicate())
	return out


## Faixas amarradas no alambrado: comércio da cidade e marcas pequenas do país.
static func _fence_brands(home: Club, r: RandomNumberGenerator) -> Array:
	var pool := BrandCatalog.local_brands(home.nation, home.city)
	for b: Dictionary in BrandCatalog.brands_for(home.nation, 1, "placa", 2, ""):
		if int(b.get("tier", 1)) <= 2:
			pool.append(b)
	RngUtil.shuffle(r, pool)
	var out: Array = []
	for b: Dictionary in pool.slice(0, 6):
		out.append({"n": String(b["n"]), "c": String(b.get("c", "#1B1B1B")), "t": String(b.get("t", "#FFFFFF")), "m": String(b.get("m", ""))})
	return out
