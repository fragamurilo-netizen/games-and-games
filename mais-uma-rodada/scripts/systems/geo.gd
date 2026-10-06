class_name Geo
extends RefCounted
## Geografia de verdade: coordenadas das cidades dos clubes e das cidades natais (data/world/geo.json).
##   - Distância de viagem entre clubes: viagem bem mais longa que a média da liga pesa no
##     visitante (Manaus–Porto Alegre não é Rio–São Paulo). A média da liga já está na cultura
##     calibrada (LeagueCulture), então só o desvio em relação a ela muda o mando.
##   - Distância de casa: o garoto que mora a 2.000 km da família sente mais saudade; o estrangeiro
##     de um país vizinho sofre menos que o que atravessou o oceano.
## Cidades sem coordenada caem no ponto de referência do país.

const EARTH_KM := 6371.0

static var _d: Dictionary = {}
static var _league_avg: Dictionary = {}


static func _data() -> Dictionary:
	if _d.is_empty():
		var v: Variant = DatabaseManager.read_modded("res://data/world/geo.json")
		_d = v if v is Dictionary else {"nations": {}, "cities": {}}
	return _d


## [lat, lon] da cidade (ou do país, se a cidade não estiver na base). [] se nada for conhecido.
static func point(nation: String, city: String) -> Array:
	var d := _data()
	var cs: Dictionary = d["cities"].get(nation, {})
	if city != "" and cs.has(city):
		return cs[city]
	var n: Variant = d["nations"].get(nation, null)
	return n if n is Array else []


static func club_point(c: Club) -> Array:
	return point(c.nation, c.city)


## Distância em km entre dois pontos (haversine). -1 se faltar algum.
static func km(a: Array, b: Array) -> float:
	if a.size() < 2 or b.size() < 2:
		return -1.0
	var la1 := deg_to_rad(float(a[0]))
	var la2 := deg_to_rad(float(b[0]))
	var dla := la2 - la1
	var dlo := deg_to_rad(float(b[1]) - float(a[1]))
	var h := sin(dla / 2.0) * sin(dla / 2.0) + cos(la1) * cos(la2) * sin(dlo / 2.0) * sin(dlo / 2.0)
	return EARTH_KM * 2.0 * atan2(sqrt(h), sqrt(maxf(0.0, 1.0 - h)))


static func club_km(a: Club, b: Club) -> float:
	if a == null or b == null:
		return -1.0
	return km(club_point(a), club_point(b))


## Prepara (na thread principal) as médias de viagem de todas as ligas da temporada: durante os
## jogos, que rodam em threads, Geo só lê.
static func prepare(world: GameWorld) -> void:
	_data()
	if int(_league_avg.get("_y", -1)) == world.year:
		return
	var by := {}
	for c: Club in world.clubs:
		if not by.has(c.league_id):
			by[c.league_id] = []
		by[c.league_id].append(c)
	var out := {"_y": world.year}
	for lid in by:
		var arr: Array = by[lid]
		var tot := 0.0
		var n := 0
		for i in arr.size():
			for j in range(i + 1, arr.size()):
				var k := club_km(arr[i], arr[j])
				if k >= 0.0:
					tot += k
					n += 1
		out[lid] = tot / float(n) if n > 0 else 300.0
	_league_avg = out


## Distância média de viagem entre os clubes de uma liga.
static func league_avg_km(_world: GameWorld, league_id: String) -> float:
	return float(_league_avg.get(league_id, 300.0))


## Peso da viagem no mando (multiplica o fator torcida do mandante): 0,9 no vizinho, até ~1,3 na
## viagem de outro continente/país continental.
static func travel_factor(world: GameWorld, home: Club, away: Club) -> float:
	var k := club_km(home, away)
	if k < 0.0:
		return 1.0
	var avg := league_avg_km(world, home.league_id)
	return 1.0 + clampf((k - avg) / 2500.0, -0.2, 0.6) * 0.5


## Distância entre a terra do jogador e o clube.
static func home_km(p: Player, c: Club) -> float:
	if c == null:
		return -1.0
	var born := NationalityManager.birth_country(p)
	return km(point(born, p.hometown), club_point(c))


## Texto curto da distância ("perto de casa", "a 2.300 km de casa").
static func home_text(p: Player, c: Club) -> String:
	var k := home_km(p, c)
	if k < 0.0:
		return ""
	if k < 80.0:
		return "Joga perto de casa"
	return "A %s km de casa" % Fmt.thousands(int(round(k / 50.0)) * 50)
