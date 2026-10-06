class_name PlayerGenerator
extends RefCounted
## Cria jogadores com atributos coerentes por posição e perfil, físico, potencial,
## curva de desenvolvimento, personalidade e contrato. Tudo a partir do RNG do mundo.

# Índices: FIN PAS TEC VEL FOR MAR POS VIS CRU CAB RES GOL DIS INT DEC DRI DES CHL ACE REF FRI
const TEMPLATE: Array = [
	[-40, -10, -20, -12, -2, -35, 3, -15, -35, -25, -15, 5, 0, 0, 1, -30, -35, -30, -12, 6, 0], # GK
	[-20, -4, -4, 3, -4, 1, 0, -8, 2, -10, 3, -50, 0, -4, -2, -2, 2, -12, 3, -50, -4], # RB
	[-28, -8, -14, -5, 4, 4, 3, -12, -18, 4, -4, -50, 0, -2, 0, -16, 5, -16, -6, -50, 0], # CB
	[-20, -4, -4, 3, -4, 1, 0, -8, 2, -10, 3, -50, 0, -4, -2, -2, 2, -12, 3, -50, -4], # LB
	[-18, 0, -6, -6, 2, 3, 2, -4, -14, -4, 2, -50, 0, 0, 0, -8, 4, -6, -6, -50, 0], # DM
	[-10, 2, 1, -4, -4, -4, -2, 2, -6, -10, 2, -50, 0, 0, 1, -2, -2, 0, -4, -50, 0], # CM
	[-2, 2, 3, -1, -10, -20, -6, 3, -4, -14, -4, -50, 0, 0, 0, 4, -18, 2, 0, -50, 0], # AM
	[-8, 0, 1, 2, -8, -8, -6, -2, 3, -14, 2, -50, 0, -4, -2, 2, -6, -4, 2, -50, -2], # RM
	[-8, 0, 1, 2, -8, -8, -6, -2, 3, -14, 2, -50, 0, -4, -2, 2, -6, -4, 2, -50, -2], # LM
	[-2, -4, 2, 4, -10, -22, -4, -2, 0, -14, -2, -50, 0, -4, -2, 5, -20, -2, 5, -50, -2], # RW
	[-2, -4, 2, 4, -10, -22, -4, -2, 0, -14, -2, -50, 0, -4, -2, 5, -20, -2, 5, -50, -2], # LW
	[3, -10, -2, 0, 0, -26, 2, -10, -14, 0, -4, -50, 0, -2, 0, 0, -24, -2, 0, -50, 3], # ST
]

## Perfis por posição: pequenas variações que tornam dois jogadores de mesmo overall diferentes.
const PROFILES: Dictionary = {
	Pos.GK: [{Attr.REF: 8, Attr.ACE: 5, Attr.POS: -4}, {Attr.POS: 6, Attr.DEC: 3, Attr.REF: -3}, {Attr.PAS: 14, Attr.TEC: 8, Attr.FRI: 4}, {Attr.CAB: 6, Attr.FOR: 6}, {}],
	Pos.CB: [{Attr.CAB: 8, Attr.FOR: 8, Attr.VEL: -6, Attr.ACE: -6}, {Attr.VEL: 10, Attr.ACE: 8, Attr.FOR: -4, Attr.CAB: -4}, {Attr.PAS: 10, Attr.TEC: 6, Attr.VIS: 6, Attr.DRI: 6, Attr.MAR: -3}, {Attr.DES: 9, Attr.POS: 4, Attr.PAS: -4}, {}],
	Pos.RB: [{Attr.CRU: 8, Attr.VEL: 4, Attr.TEC: 4, Attr.DRI: 5, Attr.MAR: -6}, {Attr.MAR: 6, Attr.DES: 6, Attr.POS: 5, Attr.CRU: -6}, {Attr.VEL: 10, Attr.ACE: 8}, {Attr.PAS: 8, Attr.VIS: 6, Attr.INT: 4, Attr.VEL: -4}, {}],
	Pos.LB: [{Attr.CRU: 8, Attr.VEL: 4, Attr.TEC: 4, Attr.DRI: 5, Attr.MAR: -6}, {Attr.MAR: 6, Attr.DES: 6, Attr.POS: 5, Attr.CRU: -6}, {Attr.VEL: 10, Attr.ACE: 8}, {Attr.PAS: 8, Attr.VIS: 6, Attr.INT: 4, Attr.VEL: -4}, {}],
	Pos.DM: [{Attr.MAR: 7, Attr.DES: 8, Attr.FOR: 6, Attr.PAS: -5}, {Attr.PAS: 8, Attr.VIS: 8, Attr.FRI: 4, Attr.MAR: -4, Attr.DES: -4}, {Attr.CHL: 10, Attr.FOR: 4, Attr.VIS: -3}, {}],
	Pos.CM: [{Attr.RES: 10, Attr.MAR: 5, Attr.DES: 5, Attr.FIN: 3}, {Attr.VIS: 8, Attr.PAS: 6, Attr.FOR: -5}, {Attr.FIN: 8, Attr.CHL: 8, Attr.POS: 4, Attr.MAR: -4}, {Attr.DRI: 8, Attr.TEC: 5, Attr.ACE: 4, Attr.MAR: -5}, {}],
	Pos.AM: [{Attr.VIS: 8, Attr.PAS: 6, Attr.FIN: -4}, {Attr.FIN: 8, Attr.FRI: 5, Attr.VEL: 4, Attr.VIS: -4}, {Attr.TEC: 6, Attr.DRI: 9, Attr.ACE: 4}, {Attr.CHL: 11, Attr.TEC: 3, Attr.DRI: -3}, {}],
	Pos.RM: [{Attr.CRU: 8, Attr.TEC: -3}, {Attr.TEC: 5, Attr.DRI: 7, Attr.VEL: 4, Attr.CRU: -4}, {Attr.RES: 8, Attr.MAR: 6, Attr.DES: 4, Attr.TEC: -4}, {}],
	Pos.LM: [{Attr.CRU: 8, Attr.TEC: -3}, {Attr.TEC: 5, Attr.DRI: 7, Attr.VEL: 4, Attr.CRU: -4}, {Attr.RES: 8, Attr.MAR: 6, Attr.DES: 4, Attr.TEC: -4}, {}],
	Pos.RW: [{Attr.VEL: 10, Attr.ACE: 9, Attr.FIN: -2}, {Attr.TEC: 6, Attr.DRI: 10, Attr.VIS: 3}, {Attr.FIN: 8, Attr.CHL: 5, Attr.POS: 4, Attr.CRU: -4}, {Attr.CRU: 9, Attr.PAS: 5, Attr.DRI: -4}, {}],
	Pos.LW: [{Attr.VEL: 10, Attr.ACE: 9, Attr.FIN: -2}, {Attr.TEC: 6, Attr.DRI: 10, Attr.VIS: 3}, {Attr.FIN: 8, Attr.CHL: 5, Attr.POS: 4, Attr.CRU: -4}, {Attr.CRU: 9, Attr.PAS: 5, Attr.DRI: -4}, {}],
	Pos.ST: [{Attr.CAB: 10, Attr.FOR: 10, Attr.VEL: -8, Attr.ACE: -6}, {Attr.VEL: 12, Attr.ACE: 10, Attr.FOR: -6, Attr.CAB: -4}, {Attr.FIN: 8, Attr.FRI: 6, Attr.POS: 6, Attr.TEC: -3, Attr.PAS: -3}, {Attr.TEC: 8, Attr.PAS: 6, Attr.VIS: 6, Attr.DRI: 5, Attr.CAB: -4}, {}],
}

const HEIGHT_MEAN: Array[int] = [189, 177, 187, 177, 181, 179, 176, 176, 176, 175, 175, 183]

## "Assinaturas": o que faz um jogador ser lembrado (e o preço que ele paga por isso).
## [nome, posições, {atributo: ajuste}, cm a mais de altura]
const SIGNATURES: Array = [
	["velocista", [Pos.RB, Pos.LB, Pos.RM, Pos.LM, Pos.RW, Pos.LW, Pos.ST], {Attr.VEL: 13, Attr.ACE: 10, Attr.FOR: -5, Attr.CAB: -3}, 0],
	["matador", [Pos.ST, Pos.AM, Pos.RW, Pos.LW], {Attr.FIN: 11, Attr.FRI: 8, Attr.POS: 5, Attr.PAS: -5, Attr.RES: -4}, 0],
	["torre", [Pos.CB, Pos.ST], {Attr.CAB: 13, Attr.FOR: 7, Attr.VEL: -7, Attr.ACE: -7, Attr.TEC: -4}, 7],
	["driblador", [Pos.RW, Pos.LW, Pos.AM, Pos.RM, Pos.LM], {Attr.DRI: 14, Attr.TEC: 6, Attr.ACE: 5, Attr.MAR: -6, Attr.CAB: -4}, -2],
	["maestro", [Pos.CM, Pos.AM, Pos.DM], {Attr.PAS: 9, Attr.VIS: 10, Attr.FRI: 4, Attr.FOR: -6, Attr.VEL: -4}, 0],
	["carrapato", [Pos.DM, Pos.CB, Pos.RB, Pos.LB], {Attr.MAR: 9, Attr.DES: 9, Attr.RES: 6, Attr.TEC: -6, Attr.DIS: -6}, 0],
	["motorzinho", [Pos.CM, Pos.RM, Pos.LM, Pos.RB, Pos.LB, Pos.DM], {Attr.RES: 13, Attr.FOR: 3, Attr.VIS: -4}, 0],
	["cruzador", [Pos.RB, Pos.LB, Pos.RM, Pos.LM], {Attr.CRU: 13, Attr.MAR: -4}, 0],
	["paredao", [Pos.GK], {Attr.GOL: 6, Attr.POS: 5, Attr.REF: 4, Attr.PAS: -8}, 3],
	["goleiro_linha", [Pos.GK], {Attr.PAS: 14, Attr.TEC: 10, Attr.FRI: 6, Attr.GOL: -2}, 0],
	["cerebral", [Pos.CB, Pos.DM, Pos.CM], {Attr.DEC: 9, Attr.INT: 9, Attr.POS: 5, Attr.VEL: -6}, 0],
	["chutador", [Pos.AM, Pos.CM, Pos.DM, Pos.ST, Pos.RW, Pos.LW], {Attr.CHL: 15, Attr.FIN: 3, Attr.PAS: -3, Attr.DRI: -3}, 0],
	["gelo", [Pos.ST, Pos.AM, Pos.CM, Pos.GK], {Attr.FRI: 15, Attr.DEC: 4, Attr.RES: -4}, 0],
	["ladrao", [Pos.DM, Pos.CB, Pos.CM], {Attr.DES: 14, Attr.POS: 4, Attr.TEC: -5, Attr.PAS: -3}, 0],
	["arranque", [Pos.RB, Pos.LB, Pos.RW, Pos.LW, Pos.ST], {Attr.ACE: 15, Attr.VEL: 4, Attr.RES: -5, Attr.CAB: -3}, -1],
	["reflexo", [Pos.GK], {Attr.REF: 13, Attr.ACE: 6, Attr.POS: -4, Attr.CAB: -4}, -2],
	["garcom", [Pos.AM, Pos.CM, Pos.RW, Pos.LW, Pos.RM, Pos.LM], {Attr.PAS: 10, Attr.VIS: 9, Attr.CRU: 4, Attr.FIN: -6}, 0],
]
const SIGNATURE_CHANCE := 0.17
## Nível dos titulares por função em relação ao time (como no futebol real, os melhores de cada
## elenco quase sempre são meias e atacantes; laterais raramente estão entre os melhores do mundo).
## O time inteiro continua na média do clube (calibrate_xi).
const STARTER_SHIFT := {Pos.GK: 0.0, Pos.RB: -1.5, Pos.LB: -1.5, Pos.CB: -0.25, Pos.DM: -0.25, Pos.CM: 0.25,
	Pos.AM: 0.5, Pos.RM: 0.0, Pos.LM: 0.0, Pos.RW: 0.5, Pos.LW: 0.5, Pos.ST: 0.5}
const CURVE_WEIGHTS: Array = [15.0, 52.0, 13.0, 10.0, 10.0]

## Modelo de elenco (25 vagas): [posição, deslocamento de qualidade em relação ao nível do clube, "nível" 0 titular/1 reserva/2 jovem]
const SQUAD_TEMPLATE: Array = [
	[Pos.GK, 0.0, 0], [Pos.GK, -7.0, 1], [Pos.GK, -14.0, 2],
	[Pos.CB, 0.0, 0], [Pos.CB, -1.0, 0], [Pos.CB, -6.0, 1], [Pos.CB, -11.0, 2],
	[Pos.RB, 0.0, 0], [Pos.RB, -7.0, 1],
	[Pos.LB, 0.0, 0], [Pos.LB, -7.0, 1],
	[Pos.DM, 0.0, 0], [Pos.DM, -6.0, 1],
	[Pos.CM, 0.0, 0], [Pos.CM, -2.0, 0], [Pos.CM, -8.0, 2],
	[Pos.AM, -1.0, 0], [Pos.AM, -9.0, 1],
	[Pos.RM, -4.0, 1], [Pos.LM, -4.0, 1],
	[Pos.RW, -1.0, 0], [Pos.LW, -1.0, 0],
	[Pos.ST, 0.0, 0], [Pos.ST, -4.0, 1], [Pos.ST, -10.0, 2],
]

static var _hometowns: Dictionary = {} # nação -> [nomes, pesos]
static var _free_pool: Array = [] # [nações, pesos] para agentes livres


static func _hometown_table(nation: String) -> Array:
	if not _hometowns.has(nation):
		var names: Array = []
		var weights: Array = []
		for cd in DatabaseManager.nation(nation).get("cities", []):
			names.append(cd[0])
			weights.append(float(cd[1]) * float(cd[1]))
		_hometowns[nation] = [names, weights]
	return _hometowns[nation]


## Cidade natal: às vezes a cidade do clube (se for do mesmo país), senão uma cidade do país pelo tamanho.
static func pick_hometown(rng: RandomNumberGenerator, nation: String, club_city: String) -> String:
	if club_city != "" and NationalityManager.city_in(club_city, nation) and rng.randf() < 0.3:
		return club_city
	var t := _hometown_table(nation)
	if t[0].is_empty():
		return ""
	return t[0][RngUtil.weighted_index(rng, t[1])]


## Nacionalidade de um jogador de elenco: estrangeiros conforme a divisão, o tamanho do clube e
## as rotas de importação do país (ingleses compram franceses; sauditas, brasileiros...).
static func pick_nationality(rng: RandomNumberGenerator, club: Club) -> String:
	var n := DatabaseManager.nation(club.nation)
	var shares: Array = n.get("foreign", [0.1])
	var share := float(shares[clampi(club.tier - 1, 0, shares.size() - 1)])
	var rr: Array = club.league_cfg().get("rep", [40, 70])
	var t := clampf((club.reputation - float(rr[0])) / maxf(1.0, float(rr[1]) - float(rr[0])), 0.0, 1.0)
	share *= 0.7 + 0.6 * t
	if rng.randf() >= share:
		return club.nation
	return pick_import(rng, club.nation)


## Base: garotos são quase todos do país. Estrangeiro na base vem de vizinho, de ex-colônia ou da
## diáspora (irlandeses e escoceses na Inglaterra, PALOP em Portugal, latinos nos EUA...). A FIFA
## só deixa transferir menor entre países da UE/EEE a partir dos 16; fora dela, aos 18.
const YOUTH_FOREIGN := {"ENG": 0.14, "ESP": 0.06, "FRA": 0.07, "GER": 0.1, "ITA": 0.07, "POR": 0.12, "NED": 0.08,
	"BEL": 0.12, "SCO": 0.1, "SUI": 0.12, "AUT": 0.1, "USA": 0.1, "CAN": 0.08, "MEX": 0.03, "TUR": 0.04,
	"GRE": 0.04, "DEN": 0.06, "SWE": 0.06, "NOR": 0.05, "BRA": 0.01, "ARG": 0.02, "URU": 0.03, "JPN": 0.01,
	"KOR": 0.005, "KSA": 0.01, "QAT": 0.03, "UAE": 0.03, "CHN": 0.005, "AUS": 0.06}
const YOUTH_IMPORTS := {
	"ENG": {"IRL": 3.0, "SCO": 2.0, "WAL": 2.0, "NED": 0.6, "FRA": 0.8, "ESP": 0.6, "POR": 0.5, "BEL": 0.4, "NGA": 0.4, "JAM": 0.4, "DEN": 0.4, "GER": 0.4},
	"SCO": {"ENG": 3.0, "IRL": 2.0, "WAL": 0.5},
	"ESP": {"MAR": 1.5, "ARG": 1.0, "FRA": 0.8, "POR": 0.6, "CRO": 0.4, "COL": 0.5, "VEN": 0.5},
	"FRA": {"BEL": 1.0, "SEN": 1.0, "CIV": 0.8, "MLI": 0.6, "POR": 0.8, "ALG": 0.8, "MAR": 0.8, "CMR": 0.5, "COD": 0.5},
	"GER": {"AUT": 1.0, "TUR": 1.0, "POL": 0.8, "NED": 0.6, "CRO": 0.6, "SUI": 0.5, "BIH": 0.5, "ENG": 0.4, "USA": 0.3},
	"ITA": {"ALB": 1.0, "ROU": 0.8, "SUI": 0.5, "FRA": 0.5, "CRO": 0.5, "SEN": 0.4, "ARG": 0.5},
	"POR": {"ANG": 1.2, "CPV": 1.2, "GNB": 1.2, "MOZ": 0.8, "BRA": 1.0, "FRA": 0.5},
	"NED": {"BEL": 1.5, "MAR": 0.8, "GER": 0.5},
	"BEL": {"NED": 1.5, "FRA": 1.2, "COD": 1.0, "MAR": 0.8, "CMR": 0.3},
	"SUI": {"GER": 1.0, "FRA": 1.0, "ITA": 1.0, "ALB": 0.6, "POR": 0.6},
	"AUT": {"GER": 1.5, "BIH": 0.8, "CRO": 0.8, "TUR": 0.6, "SRB": 0.6},
	"USA": {"MEX": 2.5, "CAN": 1.0, "JAM": 0.8, "HON": 0.5},
	"CAN": {"USA": 1.5, "JAM": 0.6},
	"MEX": {"USA": 2.0, "ARG": 0.5, "COL": 0.3},
	"TUR": {"GER": 1.0, "NED": 0.5, "BIH": 0.3},
	"BRA": {"PAR": 1.0, "URU": 0.8, "ARG": 0.6, "BOL": 0.5, "VEN": 0.5},
	"ARG": {"PAR": 1.2, "URU": 1.0, "BOL": 0.6, "CHI": 0.4},
	"URU": {"ARG": 1.5},
	"DEN": {"SWE": 1.0, "NOR": 0.8, "ISL": 0.3},
	"SWE": {"NOR": 1.0, "DEN": 1.0, "FIN": 0.6},
	"NOR": {"SWE": 1.0, "DEN": 1.0},
	"AUS": {"NZL": 1.5, "ENG": 0.5},
}


## Nacionalidade de um garoto da base do clube (captação da IA e jovens na criação do mundo).
static func pick_youth_nationality(rng: RandomNumberGenerator, club: Club, age: int) -> String:
	if rng.randf() >= float(YOUTH_FOREIGN.get(club.nation, 0.04)):
		return club.nation
	var pool: Dictionary = YOUTH_IMPORTS.get(club.nation, {})
	var nat := String(RngUtil.weighted_key(rng, pool)) if not pool.is_empty() else pick_import(rng, club.nation)
	var eu := String(DatabaseManager.nation(nat).get("confed", "")) == "UEFA" and String(DatabaseManager.nation(club.nation).get("confed", "")) == "UEFA"
	if DatabaseManager.nation(nat).is_empty() or age < (16 if eu else 18) and rng.randf() < 0.8:
		return club.nation # menor estrangeiro: só com a família morando no país (raro)
	return nat


static func pick_import(rng: RandomNumberGenerator, nation: String) -> String:
	var imports: Dictionary = DatabaseManager.nation(nation).get("imports", {})
	if imports.is_empty():
		return nation
	return RngUtil.weighted_key(rng, imports)


## Nacionalidade de um agente livre: um país com liga (pelo número de clubes) ou um de seus "exportadores".
static func pick_free_nationality(rng: RandomNumberGenerator) -> String:
	if _free_pool.is_empty():
		var codes: Array = []
		var weights: Array = []
		for code in DatabaseManager.league_nations():
			var slots := 0
			for lid in DatabaseManager.leagues_of_nation(code):
				slots += int(DatabaseManager.league_cfg(lid)["teams"])
			codes.append(code)
			weights.append(float(slots))
		_free_pool = [codes, weights]
	var base: String = _free_pool[0][RngUtil.weighted_index(rng, _free_pool[1])]
	return base if rng.randf() < 0.7 else pick_import(rng, base)


## Cria um jogador sem clube. `target` é o overall desejado na posição.
static func create(world: GameWorld, rng: RandomNumberGenerator, pos: int, target: float, age: int,
		nationality: String, club_city: String, used_names: Dictionary, sig_chance: float = SIGNATURE_CHANCE) -> Player:
	var p := Player.new()
	p.id = world.new_player_id()
	p.face_seed = rng.randi()
	p.position = pos
	p.birth_year = world.year - age
	p.nationality = nationality
	var origin := NameGenerator.pick_origin(rng, nationality)
	p.eth = int(origin["eth"])
	p.foot = _pick_foot(rng, pos)
	var sig: Array = _pick_signature(rng, pos) if rng.randf() < sig_chance else []
	p.height = int(round(RngUtil.gauss(rng, HEIGHT_MEAN[pos] + _height_shift(p.eth) + (float(sig[3]) if not sig.is_empty() else 0.0), 5.0, 163.0, 205.0)))
	p.weight = Physique.weight_for(rng, p.height, pos, age)
	_pick_traits(rng, p)
	BodyGrowth.setup_young(p, world.year) # garoto ainda cresce e ganha massa
	_generate_attributes(rng, p, target, age, sig[2] if not sig.is_empty() else {})
	p.signature = String(sig[0]) if not sig.is_empty() else ""
	p.secondary = _pick_secondary(rng, pos)
	p.potential = _pick_potential(rng, p.overall, age)
	p.dev_curve = RngUtil.weighted_index(rng, CURVE_WEIGHTS)
	p.consistency = clampi(int(round(rng.randfn(10.5, 3.2) + p.trait_sum("consistency"))), 1, 20)
	p.injury_prone = clampi(int(round(rng.randfn(9.0, 3.5))) + (2 if p.has_trait("festeiro") else 0), 1, 20)
	p.scout_noise = rng.randi_range(-6, 6)
	p.morale = rng.randf_range(55.0, 75.0)
	p.hometown = pick_hometown(rng, nationality, club_city)
	var names := NameGenerator.generate(rng, origin["c"], {
		"pos": pos, "height": p.height, "foot": p.foot, "attrs": p.attrs,
		"region": ClubGenerator.region_of_city(nationality, p.hometown),
	}, used_names)
	p.first_name = names["first"]
	p.last_name = names["last"]
	p.nickname = names["nickname"]
	p.known_as = names["known_as"]
	NationalityManager.generate(p, String(origin.get("h", "")))
	return p


## Diferença média de altura por etnia (cm), só para dar variedade física coerente.
static func _height_shift(eth: int) -> float:
	match eth:
		0:
			return 2.0 # nor
		4, 5:
			return -2.0 # lat, and
		8:
			return -2.5 # eas
		9:
			return -1.5 # sas
		10:
			return 1.0 # hae
		11:
			return 2.0 # pac
		12:
			return -3.0 # sea
	return 0.0


static func _pick_foot(rng: RandomNumberGenerator, pos: int) -> int:
	var r := rng.randf()
	if Pos.is_left(pos):
		return Player.FOOT_LEFT if r < 0.68 else (Player.FOOT_BOTH if r < 0.76 else Player.FOOT_RIGHT)
	if pos == Pos.RW:
		return Player.FOOT_LEFT if r < 0.3 else (Player.FOOT_BOTH if r < 0.36 else Player.FOOT_RIGHT)
	if r < 0.2:
		return Player.FOOT_LEFT
	if r < 0.26:
		return Player.FOOT_BOTH
	return Player.FOOT_RIGHT


static func _pick_traits(rng: RandomNumberGenerator, p: Player) -> void:
	var ids := DatabaseManager.trait_ids()
	var weights := DatabaseManager.trait_weights()
	var first: String = ids[RngUtil.weighted_index(rng, weights)]
	p.traits = [first]
	var pers: Dictionary = DatabaseManager.personalities()
	if rng.randf() < float(pers["secondary_chance"]):
		for _i in 6:
			var second: String = ids[RngUtil.weighted_index(rng, weights)]
			if second == first or _conflicts(pers["conflicts"], first, second):
				continue
			p.traits.append(second)
			break


static func _conflicts(conflicts: Array, a: String, b: String) -> bool:
	for pair in conflicts:
		if (pair[0] == a and pair[1] == b) or (pair[0] == b and pair[1] == a):
			return true
	return false


static func _pick_signature(rng: RandomNumberGenerator, pos: int) -> Array:
	var ok: Array = []
	for sg: Array in SIGNATURES:
		if (sg[1] as Array).has(pos):
			ok.append(sg)
	return RngUtil.pick(rng, ok) if not ok.is_empty() else []


static func _generate_attributes(rng: RandomNumberGenerator, p: Player, target: float, age: int, sig: Dictionary = {}) -> void:
	var pos := p.position
	var vals: Array = []
	var tpl: Array = TEMPLATE[pos]
	var profile: Dictionary = RngUtil.pick(rng, PROFILES[pos])
	for i in Attr.COUNT:
		var v: float = target + tpl[i] + rng.randfn(0.0, 5.0)
		v += float(profile.get(i, 0)) + float(sig.get(i, 0))
		vals.append(v)
	# Idade: jovens mais físicos/menos maduros; veteranos mais inteligentes e mais lentos.
	var mental := clampf((age - 25) * 0.9, -6.0, 6.0)
	for i in [Attr.INT, Attr.DEC, Attr.POS, Attr.VIS]:
		vals[i] += mental
	if age > 29:
		vals[Attr.VEL] -= (age - 29) * 1.8
		vals[Attr.ACE] -= (age - 29) * 2.1
		vals[Attr.RES] -= (age - 29) * 1.2
	elif age < 23:
		vals[Attr.VEL] += (23 - age) * 0.6
		vals[Attr.ACE] += (23 - age) * 0.8
	vals[Attr.FRI] += mental * 0.7
	# Físico
	var h := float(p.height)
	vals[Attr.CAB] += (h - 180.0) * 0.5
	vals[Attr.FOR] += (h - 180.0) * 0.35
	if h > 182.0:
		vals[Attr.VEL] -= (h - 182.0) * 0.25
		vals[Attr.ACE] -= (h - 182.0) * 0.4
	elif h < 174.0:
		vals[Attr.ACE] += (174.0 - h) * 0.4
		vals[Attr.DRI] += (174.0 - h) * 0.3
	if h > 186.0:
		vals[Attr.TEC] -= (h - 186.0) * 0.2
	# Personalidade
	if p.has_trait("esforcado"):
		vals[Attr.RES] += 3.0
	if p.has_trait("lider"):
		vals[Attr.INT] += 2.0
		vals[Attr.DEC] += 2.0
	var dis := rng.randfn(60.0, 14.0)
	if p.has_trait("disciplinado"):
		dis += 15.0
	if p.has_trait("profissional"):
		dis += 6.0
	if p.has_trait("temperamental"):
		dis -= 14.0
	if p.has_trait("rebelde") or p.has_trait("provocador"):
		dis -= 10.0
	vals[Attr.DIS] = dis
	# Normaliza para que o overall bata com o alvo (desloca só atributos relevantes).
	var w: Array = Pos.WEIGHTS[pos]
	for _iter in 6:
		var ovr := 0.0
		for i in Attr.COUNT:
			ovr += w[i] * soft_attr(spike_cap(vals[i], target, i))
		var d := target - ovr
		if absf(d) < 0.3:
			break
		for i in Attr.COUNT:
			if w[i] > 0.0:
				vals[i] += d
	for i in Attr.COUNT:
		if (i == Attr.GOL or i == Attr.REF) and pos != Pos.GK:
			vals[i] = clampf(vals[i], 1.0, 25.0)
		p.attrs[i] = int(round(soft_attr(spike_cap(vals[i], target, i))))
	p.recompute_overall()


## O ponto forte de um jogador passa do overall dele, mas não muito: um zagueiro 83 desarma como
## 90, não como 98 (como nos jogos de futebol de verdade, o pico fica uns 10 acima do overall).
static func spike_cap(v: float, target: float, attr: int) -> float:
	if attr == Attr.DIS:
		return v
	var cap := target + 10.0
	return v if v <= cap else cap + (v - cap) * 0.4


## Acima de 90 cada ponto de atributo fica mais raro: o craque tem dois ou três números na casa dos
## 90, e 97–99 é só para o que ele faz de melhor no mundo (não quatro atributos de uma vez).
static func soft_attr(v: float) -> float:
	if v > 90.0:
		v = 90.0 + (v - 90.0) * 0.6
	return clampf(v, 1.0, 99.0)


static func _pick_secondary(rng: RandomNumberGenerator, pos: int) -> Array:
	var rel: Dictionary = Pos.RELATED[pos]
	if rel.is_empty():
		return []
	var r := rng.randf()
	var count := 0 if r < 0.3 else (1 if r < 0.8 else 2)
	var keys := rel.keys()
	var weights: Array = []
	for k in keys:
		weights.append(float(rel[k]) - 0.75)
	var out: Array = []
	for _i in count:
		var idx := RngUtil.weighted_index(rng, weights)
		if idx < 0:
			break
		out.append(keys[idx])
		weights[idx] = 0.0
	return out


## Distância média até o teto por idade (FC/Transfermarkt): grande aos 17–18, some aos 27.
const POT_GAP := {17: [10.0, 5.0], 18: [9.5, 5.0], 19: [8.0, 4.6], 20: [6.8, 4.2], 21: [5.4, 3.6], 22: [4.2, 3.0],
	23: [3.0, 2.4], 24: [2.0, 1.9], 25: [1.2, 1.3], 26: [0.7, 1.0], 27: [0.3, 0.8]}


static func _pick_potential(rng: RandomNumberGenerator, ovr: int, age: int) -> int:
	var gap := 0.0
	var g: Array = POT_GAP.get(clampi(age, 17, 99), [])
	if not g.is_empty():
		gap = rng.randfn(float(g[0]), float(g[1]))
	if age <= 20 and rng.randf() < 0.012:
		gap += rng.randf_range(6.0, 12.0) # joia rara
	# Garoto de 17–20 anos sempre tem o que crescer (pouco, às vezes): ninguém chega pronto aos 18.
	gap = maxf(maxf(0.0, (21.0 - age) * 1.2), gap)
	# Acima de 85 cada ponto de potencial é mais raro (só os fenômenos passam de 90).
	var pot := float(ovr) + gap
	if pot > 85.0:
		pot = 85.0 + (pot - 85.0) * 0.5
	return clampi(int(round(pot)), ovr, 94)


## Potencial de um jovem da base, influenciado pela qualidade da base do clube e pela escola do país.
static func youth_potential(rng: RandomNumberGenerator, ovr: int, youth_level: int, drift: float = 0.0, nation_bonus: float = 0.0) -> int:
	var gap := rng.randfn(5.0 + youth_level * 0.05 - drift * 0.8 + nation_bonus, 6.5)
	var gem_chance := 0.005 + youth_level * 0.0002 + nation_bonus * 0.001
	if rng.randf() < gem_chance:
		gap += rng.randf_range(12.0, 20.0)
	var pot := float(ovr) + maxf(2.0, gap)
	# Acima de 86 cada ponto é raro, mas toda safra mundial tem as suas joias de 90+ (FC/Transfermarkt).
	if pot > 86.0:
		pot = 86.0 + (pot - 86.0) * 0.65
	return clampi(int(round(pot)), ovr + 2, 94)


## Potencial de um garoto que a IA sobe da base: o teto está longe (quanto mais novo, mais longe) e
## a base boa acrescenta um pouco. Acima de 85 cada ponto é mais raro; joia rara em qualquer clube.
static func intake_potential(rng: RandomNumberGenerator, ovr: int, age: int, youth_level: int, drift: float = 0.0, nation_bonus: float = 0.0) -> int:
	var gap := rng.randfn(12.0 - (age - 16) * 1.5 + youth_level * 0.04 - drift * 0.8 + nation_bonus, 6.0)
	if rng.randf() < 0.006 + youth_level * 0.0001 + nation_bonus * 0.001:
		gap += rng.randf_range(8.0, 16.0)
	var pot := float(ovr) + maxf(3.0, gap)
	if pot > 86.0:
		pot = 86.0 + (pot - 86.0) * 0.6
	return clampi(int(round(pot)), ovr + 3, 94)


# ---------------------------------------------------------------------------
# Elencos
# ---------------------------------------------------------------------------

## Gera o elenco inicial de um clube em torno do nível `level` (overall médio dos titulares).
static func create_squad(world: GameWorld, rng: RandomNumberGenerator, club: Club, level: float, used_names: Dictionary) -> void:
	var arch: Dictionary = club.arch()
	var hg_share := ClubPolicy.homegrown_share(club)
	var young_share: float = arch.get("young_share", 0.2)
	var veteran_share: float = arch.get("veteran_share", 0.2)
	var slots: Array = SQUAD_TEMPLATE.duplicate()
	# Tamanho do elenco como na vida real: grande clube de 1ª divisão tem 27–30 jogadores, o
	# pequeno da 2ª fica com 22–25; no Brasil e na Argentina os elencos são mais inchados.
	var removable: Array = []
	for i in slots.size():
		if slots[i][2] >= 1 and slots[i][0] != Pos.GK:
			removable.append(i)
	RngUtil.shuffle(rng, removable)
	var remove_n := rng.randi_range(0, 2 if club.tier >= 2 else 1)
	var to_remove: Array = removable.slice(0, remove_n)
	to_remove.sort()
	to_remove.reverse()
	for i in to_remove:
		slots.remove_at(i)
	var extra := rng.randi_range(0, 1)
	if club.tier == 1:
		extra += 1 + (1 if club.reputation >= 60.0 else 0) + (1 if club.reputation >= 78.0 else 0)
	if club.nation in ["BRA", "ARG"]:
		extra += 2
	var pool: Array = [[Pos.CB, -8.0, 1], [Pos.CM, -6.0, 1], [Pos.ST, -8.0, 1], [Pos.RW, -7.0, 1], [Pos.LW, -7.0, 1],
		[Pos.LB, -12.0, 2], [Pos.RB, -12.0, 2], [Pos.AM, -10.0, 2], [Pos.DM, -10.0, 2], [Pos.GK, -16.0, 2]]
	RngUtil.shuffle(rng, pool)
	for i in mini(extra, pool.size()):
		slots.append(pool[i])
	if rng.randf() < 0.45:
		slots.append([RngUtil.pick(rng, [Pos.CM, Pos.ST, Pos.CB, Pos.RW, Pos.AM]), -12.0, 2])
	# Roteiro do elenco: hierarquia dos titulares, capitão, ídolo, joia, repatriado, astros
	var story := SquadStory.plan(rng, club, slots)
	var n_starters := 0
	for s0: Array in slots:
		if int(s0[2]) == 0:
			n_starters += 1
	for si in slots.size():
		var s: Array = slots[si]
		var pos: int = s[0]
		var tier: int = s[2]
		var st: Dictionary = story.get(si, {})
		var rank := int(st.get("rank", -1))
		var role := String(st.get("role", ""))
		var star := rank == 0 or (rank == 1 and club.reputation >= 80.0)
		var age := _pick_age(rng, tier, young_share, veteran_share)
		if pos == Pos.GK and tier == 0:
			age = clampi(int(round(rng.randfn(29.5, 3.3))), 22, 37) # goleiro titular costuma ser mais experiente
		var pol_age := ClubPolicy.of(club)
		if pol_age.has("buy_age_max") and tier <= 1:
			age = mini(age, int(pol_age["buy_age_max"]) + (6 if pos == Pos.GK else 3)) # elenco jovem (Red Bull, Brighton...)
		if pol_age.has("buy_age_min") and tier == 0:
			age = maxi(age, int(pol_age["buy_age_min"]) + 1) # estrelas experientes
		if star and role == "":
			if pos == Pos.GK:
				age = clampi(int(round(rng.randfn(29.5, 2.6))), 25, 34) # goleiro craque é experiente
			else:
				age = clampi(int(round(rng.randfn(27.0, 2.6))), 22, 31) # craques no auge
		var r_age := SquadStory.role_age(rng, role, pos, club)
		if r_age > 0:
			age = r_age
		# Garotos do elenco vêm quase todos da base local; os mais velhos seguem as rotas de importação
		var nat := SquadStory.role_nation(rng, role, club)
		if nat == "":
			nat = pick_youth_nationality(rng, club, age) if age <= 19 else pick_nationality(rng, club)
		if nat != club.nation and role == "" and age >= 21:
			# Vitrine compra garoto para revender; o Golfo paga pela experiência.
			age = clampi(age + int(SquadStory.IMPORT_AGE.get(club.nation, 0)), 19, 35)
		var noise := 1.2 if tier == 0 else 2.4
		var target: float = level + float(s[1]) + rng.randfn(0.0, noise) + SquadStory.role_target(role)
		if tier == 0:
			target += float(STARTER_SHIFT.get(pos, 0.0)) + SquadStory.rank_offset(rank, n_starters, club)
		# O capitão e o astro veterano ainda estão no nível de titular (a idade pesa pouco neles)
		target -= age_penalty(age, pos) * (0.35 if role in ["capitao", "astro"] else 1.0)
		if nat != club.nation:
			target += 1.5
		target = clampf(soft_cap(target, star_ceiling(club) + (2.0 if role == "astro" else 0.0)), 25.0, 93.0)
		# Craque quase sempre tem "assinatura"
		var p := create(world, rng, pos, target, age, nat, club.city, used_names, 0.6 if star or role == "astro" else SIGNATURE_CHANCE)
		if role != "idolo" and role != "repatriado":
			ClubPolicy.apply_rule(world, rng, club, p, ClubPolicy.generation_rule(rng, club), used_names)
		sign_to_club(world, rng, p, club, true)
		# Cria da casa: na carreira anterior ele só jogou aqui (formado na base)
		if hg_share > 0.0 and age <= 31 and rng.randf() < hg_share:
			p.joined_year = world.year - maxi(0, age - 18)
		SquadStory.apply(world, rng, club, p, role, level)
	calibrate_xi(world, club, level)
	assign_statuses(world, club)
	assign_shirt_numbers(world, club)
	_dedupe_names(world, club)


## Dois jogadores com o mesmo nome no elenco: o segundo passa a ser chamado pelo nome completo
## (como o "Matos" que vira "Thiago Matos" na súmula).
static func _dedupe_names(world: GameWorld, club: Club) -> void:
	var seen := {}
	for p: Player in world.squad(club):
		var k := p.display_name()
		if seen.has(k):
			var full := "%s %s" % [p.first_name, p.last_name]
			if full.strip_edges() != "" and not seen.has(full) and full != k:
				p.known_as = full
			elif NameGenerator.is_shirt_nickname(p.nickname) and not seen.has(p.nickname):
				p.known_as = p.nickname
		seen[p.display_name()] = true


## Quanto a idade tira do nível de quem ainda não chegou (ou já passou) do auge.
static func age_penalty(age: int, pos: int = -1) -> float:
	if pos == Pos.GK:
		# Goleiro amadurece mais tarde e dura mais: auge dos 27 aos 33.
		if age <= 23:
			return (24 - age) * 1.5
		age = maxi(age - 3, 21)
	if age <= 20:
		return (21 - age) * 1.6
	if age <= 30:
		return 0.0
	return [0.0, 0.6, 1.5, 2.8, 4.2, 5.8, 7.5][mini(age - 30, 6)]


## Teto de um craque na liga: o melhor da liga fica ~6 acima do nível do clube mais forte dela.
static func star_ceiling(club: Club) -> float:
	var lr: Array = club.league_cfg().get("level", [55, 65])
	return float(lr[1]) + 6.0


## Acima do teto o nível cresce devagar (poucos chegam a 90 no mundo).
## Acima do joelho o alvo cresce devagar: craques existem, mas 90+ é para meia dúzia no mundo.
static func soft_cap(target: float, ceiling: float) -> float:
	var knee := ceiling - 5.0
	if target <= knee:
		return target
	return knee + (target - knee) * 0.75


## Média do time titular provável (melhor goleiro + 10 melhores de linha).
static func xi_average(world: GameWorld, club: Club) -> float:
	var gk := 0
	var field: Array = []
	for pid in club.player_ids:
		var p := world.player(pid)
		if p == null:
			continue
		if p.position == Pos.GK:
			gk = maxi(gk, p.overall)
		else:
			field.append(p.overall)
	field.sort()
	field.reverse()
	var s := float(gk)
	for i in mini(10, field.size()):
		s += float(field[i])
	return s / float(1 + mini(10, field.size()))


## Acerta o elenco inteiro para o time titular ter a média do nível do clube (a força que ele tem na
## vida real): estrelas, estrangeiros e sorteio não podem inflar nem esvaziar o time.
static func calibrate_xi(world: GameWorld, club: Club, level: float) -> void:
	for _iter in 3:
		var d := level - xi_average(world, club)
		if absf(d) < 0.35:
			return
		var step := int(round(d))
		if step == 0:
			step = signi(int(signf(d)))
		for pid in club.player_ids:
			var p := world.player(pid)
			if p == null:
				continue
			for i in Attr.COUNT:
				if i == Attr.DIS or (i == Attr.GOL and p.position != Pos.GK):
					continue
				p.attrs[i] = clampi(p.attrs[i] + step, 1, 99)
			p.recompute_overall()
			p.potential = clampi(p.potential + step, p.overall, 94)


static func _pick_age(rng: RandomNumberGenerator, tier: int, young_share: float, veteran_share: float) -> int:
	if tier == 2:
		return rng.randi_range(17, 20)
	var r := rng.randf()
	if r < young_share * 0.6:
		return rng.randi_range(18, 22)
	if r > 1.0 - veteran_share * 0.7:
		return rng.randi_range(30, 35)
	if tier == 0:
		return clampi(int(round(rng.randfn(27.0, 3.3))), 20, 34)
	return clampi(int(round(rng.randfn(25.5, 4.5))), 18, 35)


## Vincula o jogador ao clube com contrato e salário coerentes.
static func sign_to_club(world: GameWorld, rng: RandomNumberGenerator, p: Player, club: Club, initial: bool) -> void:
	p.club_id = club.id
	club.player_ids.append(p.id)
	world.add_player(p)
	var years: int
	if initial:
		years = RngUtil.weighted_index(rng, [18.0, 27.0, 27.0, 18.0, 10.0])
		p.joined_year = world.year - rng.randi_range(0, mini(6, maxi(0, p.age(world.year) - 17)))
	else:
		years = rng.randi_range(1, 3)
		p.joined_year = world.year
	p.contract_end = world.year + years
	p.wage = Valuation.initial_wage(p, club, world.year, rng)
	p.spells = [{"c": club.id, "cn": club.short_name, "from": p.joined_year, "to": 0, "a": 0, "g": 0, "as": 0}]
	NationalityManager.sync_residence(world, p)
	Valuation.update_value(p, world.year)


## Define status no elenco pela ordem de qualidade (estrela, titular, rotação, reserva, promessa).
## Titular é quem joga: o melhor goleiro e os 10 melhores de linha (o 2º goleiro nunca é titular,
## mesmo sendo melhor que o 11º de linha).
static func assign_statuses(world: GameWorld, club: Club) -> void:
	var squad := world.squad(club)
	squad.sort_custom(func(a, b): return a.ovr_f > b.ovr_f)
	var xi := {}
	var gk := false
	var field := 0
	var avg := 0.0
	for p: Player in squad:
		if p.position == Pos.GK:
			if gk:
				continue
			gk = true
		elif field >= 10:
			continue
		else:
			field += 1
		xi[p.id] = true
		avg += p.ovr_f
	avg = avg / maxf(1.0, xi.size())
	var rest := 0
	for i in squad.size():
		var p: Player = squad[i]
		var age := p.age(world.year)
		if xi.has(p.id):
			p.squad_status = Player.STATUS_STAR if i < 2 and p.ovr_f >= avg + 3.0 else Player.STATUS_STARTER
			continue
		rest += 1
		if age <= 21 and p.potential >= p.overall + 6:
			p.squad_status = Player.STATUS_PROSPECT
		elif rest <= 7:
			p.squad_status = Player.STATUS_ROTATION
		else:
			p.squad_status = Player.STATUS_BACKUP


## Numeração clássica para os melhores de cada posição; o resto recebe números livres.
static func assign_shirt_numbers(world: GameWorld, club: Club) -> void:
	var squad := world.squad(club)
	squad.sort_custom(func(a, b): return a.ovr_f > b.ovr_f)
	var used := {}
	var classic := {Pos.GK: [1], Pos.RB: [2], Pos.CB: [3, 4], Pos.LB: [6], Pos.DM: [5], Pos.CM: [8], Pos.AM: [10],
		Pos.RW: [7], Pos.RM: [7], Pos.LW: [11], Pos.LM: [11], Pos.ST: [9]}
	for p in squad:
		p.shirt = 0
		var options: Array = classic.get(p.position, [])
		for n in options:
			if not used.has(n):
				p.shirt = n
				used[n] = true
				break
	var next := 12
	for p in squad:
		if p.shirt != 0:
			continue
		if p.position == Pos.GK and not used.has(12):
			p.shirt = 12
			used[12] = true
			continue
		while used.has(next) or next == 12:
			next += 1
		p.shirt = next
		used[next] = true


## Gera um jovem da base (16–18 anos).
static func create_youth(world: GameWorld, rng: RandomNumberGenerator, club: Club, used_names: Dictionary) -> Player:
	var pos: int = RngUtil.weighted_index(rng, [1.2, 1.0, 1.6, 1.0, 1.0, 1.4, 1.0, 0.6, 0.6, 0.9, 0.9, 1.6])
	var age := rng.randi_range(16, 18)
	var level := league_level(club)
	var drift := clampf(float(world.stats.get("talent_drift", 0.0)), -8.0, 8.0)
	var nation_bonus := Generations.nation_youth(world, club.nation)
	# O garoto que sobe no gigante tem ~60 aos 16 (não 70: quase ninguém chega pronto); o do clube
	# pequeno, ~35–40. A diferença entre as bases é menor que a entre os times principais.
	var target := 6.0 + level * 0.6 + club.youth_level * 0.05 + rng.randfn(0.0, 4.5) + (age - 16) * 2.0 - drift + nation_bonus * 0.4
	target = clampf(target, 22.0, 70.0)
	var nat := pick_youth_nationality(rng, club, age)
	var p := create(world, rng, pos, target, age, nat, club.city, used_names)
	ClubPolicy.apply_rule(world, rng, club, p, ClubPolicy.generation_rule(rng, club), used_names)
	p.potential = intake_potential(rng, p.overall, age, club.youth_level, drift, nation_bonus)
	Generations.on_new_kid(world, p) # categoria do país e, se for o caso, a geração excepcional
	p.squad_status = Player.STATUS_PROSPECT
	sign_to_club(world, rng, p, club, false)
	p.contract_end = world.year + 3
	p.wage = Valuation.round_wage(Valuation.base_wage(p.ovr_f) * 0.6 * float(club.league_cfg().get("wage", 0.5)))
	if NationalityManager.birth_country(p) == club.nation and rng.randf() < 0.55 and not ClubPolicy.of(club).has("only"):
		p.hometown = club.city
	return p


## Jogador livre (sem clube), útil para manter o mercado vivo.
static func create_free_agent(world: GameWorld, rng: RandomNumberGenerator, level: float, used_names: Dictionary) -> Player:
	var pos: int = RngUtil.weighted_index(rng, [1.0, 0.8, 1.4, 0.8, 0.9, 1.2, 0.8, 0.5, 0.5, 0.7, 0.7, 1.3])
	var age := rng.randi_range(19, 35)
	var target := level + rng.randfn(-4.0, 5.0)
	var nat := pick_free_nationality(rng)
	var p := create(world, rng, pos, clampf(target, 30.0, 82.0), age, nat, "", used_names)
	p.club_id = -1
	p.wage = 0
	p.contract_end = world.year
	p.squad_status = Player.STATUS_ROTATION
	world.add_player(p)
	Valuation.update_value(p, world.year)
	return p


## Nível típico (overall dos titulares) de um clube na sua liga, sem o arquétipo.
static func league_level(club: Club) -> float:
	return FinanceManager.level_of_rep(club.league_cfg(), club.reputation)


## Nível-alvo do elenco de um clube (liga + reputação + arquétipo).
## O arquétipo mexe pouco: a reputação já diz quão forte o clube é (e ninguém passa do teto da liga).
static func club_level(club: Club) -> float:
	var lr: Array = club.league_cfg().get("level", [55, 65])
	return minf(league_level(club) + float(club.arch().get("level_mod", 0.0)) * 0.4, float(lr[1]) + 0.5)
