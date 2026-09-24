class_name PlayerGenerator
extends RefCounted
## Cria jogadores com atributos coerentes por posição e perfil, físico, potencial,
## curva de desenvolvimento, personalidade e contrato. Tudo a partir do RNG do mundo.

# Índices: FIN PAS TEC VEL FOR MAR POS VIS CRU CAB RES GOL DIS INT DEC
const TEMPLATE: Array = [
	[-40, -10, -20, -12, -2, -35, 3, -15, -35, -25, -15, 5, 0, 0, 1], # GK
	[-20, -4, -4, 3, -4, 1, 0, -8, 2, -10, 3, -50, 0, -4, -2], # RB
	[-28, -8, -14, -5, 4, 4, 3, -12, -18, 4, -4, -50, 0, -2, 0], # CB
	[-20, -4, -4, 3, -4, 1, 0, -8, 2, -10, 3, -50, 0, -4, -2], # LB
	[-18, 0, -6, -6, 2, 3, 2, -4, -14, -4, 2, -50, 0, 0, 0], # DM
	[-10, 2, 1, -4, -4, -4, -2, 2, -6, -10, 2, -50, 0, 0, 1], # CM
	[-2, 2, 3, -1, -10, -20, -6, 3, -4, -14, -4, -50, 0, 0, 0], # AM
	[-8, 0, 1, 2, -8, -8, -6, -2, 3, -14, 2, -50, 0, -4, -2], # RM
	[-8, 0, 1, 2, -8, -8, -6, -2, 3, -14, 2, -50, 0, -4, -2], # LM
	[-2, -4, 2, 4, -10, -22, -4, -2, 0, -14, -2, -50, 0, -4, -2], # RW
	[-2, -4, 2, 4, -10, -22, -4, -2, 0, -14, -2, -50, 0, -4, -2], # LW
	[3, -10, -2, 0, 0, -26, 2, -10, -14, 0, -4, -50, 0, -2, 0], # ST
]

## Perfis por posição: pequenas variações que tornam dois jogadores de mesmo overall diferentes.
const PROFILES: Dictionary = {
	Pos.GK: [{Attr.VEL: 6, Attr.POS: -4}, {Attr.POS: 6, Attr.DEC: 3, Attr.VEL: -4}, {Attr.PAS: 14, Attr.TEC: 8}, {}],
	Pos.CB: [{Attr.CAB: 8, Attr.FOR: 8, Attr.VEL: -6}, {Attr.VEL: 10, Attr.FOR: -4, Attr.CAB: -4}, {Attr.PAS: 10, Attr.TEC: 6, Attr.VIS: 6, Attr.MAR: -3}, {}],
	Pos.RB: [{Attr.CRU: 8, Attr.VEL: 4, Attr.TEC: 4, Attr.MAR: -6}, {Attr.MAR: 6, Attr.POS: 5, Attr.CRU: -6}, {Attr.VEL: 10}, {}],
	Pos.LB: [{Attr.CRU: 8, Attr.VEL: 4, Attr.TEC: 4, Attr.MAR: -6}, {Attr.MAR: 6, Attr.POS: 5, Attr.CRU: -6}, {Attr.VEL: 10}, {}],
	Pos.DM: [{Attr.MAR: 7, Attr.FOR: 6, Attr.PAS: -5}, {Attr.PAS: 8, Attr.VIS: 6, Attr.MAR: -4}, {}],
	Pos.CM: [{Attr.RES: 10, Attr.MAR: 5, Attr.FIN: 3}, {Attr.VIS: 8, Attr.PAS: 6, Attr.FOR: -5}, {Attr.FIN: 8, Attr.POS: 4, Attr.MAR: -4}, {}],
	Pos.AM: [{Attr.VIS: 8, Attr.PAS: 6, Attr.FIN: -4}, {Attr.FIN: 8, Attr.VEL: 4, Attr.VIS: -4}, {Attr.TEC: 8, Attr.VEL: 4}, {}],
	Pos.RM: [{Attr.CRU: 8, Attr.TEC: -3}, {Attr.TEC: 7, Attr.VEL: 4, Attr.CRU: -4}, {Attr.RES: 8, Attr.MAR: 6, Attr.TEC: -4}, {}],
	Pos.LM: [{Attr.CRU: 8, Attr.TEC: -3}, {Attr.TEC: 7, Attr.VEL: 4, Attr.CRU: -4}, {Attr.RES: 8, Attr.MAR: 6, Attr.TEC: -4}, {}],
	Pos.RW: [{Attr.VEL: 10, Attr.FIN: -2}, {Attr.TEC: 8, Attr.VIS: 3}, {Attr.FIN: 8, Attr.POS: 4, Attr.CRU: -4}, {}],
	Pos.LW: [{Attr.VEL: 10, Attr.FIN: -2}, {Attr.TEC: 8, Attr.VIS: 3}, {Attr.FIN: 8, Attr.POS: 4, Attr.CRU: -4}, {}],
	Pos.ST: [{Attr.CAB: 10, Attr.FOR: 10, Attr.VEL: -8}, {Attr.VEL: 12, Attr.FOR: -6, Attr.CAB: -4}, {Attr.FIN: 8, Attr.POS: 6, Attr.TEC: -3, Attr.PAS: -3}, {Attr.TEC: 8, Attr.PAS: 6, Attr.VIS: 6, Attr.CAB: -4}, {}],
}

const HEIGHT_MEAN: Array[int] = [189, 177, 187, 177, 181, 179, 176, 176, 176, 175, 175, 183]
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
	if club_city != "" and rng.randf() < 0.3:
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
		nationality: String, club_city: String, used_names: Dictionary) -> Player:
	var p := Player.new()
	p.id = world.new_player_id()
	p.face_seed = rng.randi()
	p.position = pos
	p.birth_year = world.year - age
	p.nationality = nationality
	var origin := NameGenerator.pick_origin(rng, nationality)
	p.eth = int(origin["eth"])
	p.foot = _pick_foot(rng, pos)
	p.height = int(round(RngUtil.gauss(rng, HEIGHT_MEAN[pos] + _height_shift(p.eth), 5.0, 163.0, 203.0)))
	_pick_traits(rng, p)
	_generate_attributes(rng, p, target, age)
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


static func _generate_attributes(rng: RandomNumberGenerator, p: Player, target: float, age: int) -> void:
	var pos := p.position
	var vals: Array = []
	var tpl: Array = TEMPLATE[pos]
	var profile: Dictionary = RngUtil.pick(rng, PROFILES[pos])
	for i in Attr.COUNT:
		var v: float = target + tpl[i] + rng.randfn(0.0, 5.0)
		v += float(profile.get(i, 0))
		vals.append(v)
	# Idade: jovens mais físicos/menos maduros; veteranos mais inteligentes e mais lentos.
	var mental := clampf((age - 25) * 0.9, -6.0, 6.0)
	for i in [Attr.INT, Attr.DEC, Attr.POS, Attr.VIS]:
		vals[i] += mental
	if age > 29:
		vals[Attr.VEL] -= (age - 29) * 1.8
		vals[Attr.RES] -= (age - 29) * 1.2
	elif age < 23:
		vals[Attr.VEL] += (23 - age) * 0.6
	# Físico
	var h := float(p.height)
	vals[Attr.CAB] += (h - 180.0) * 0.5
	vals[Attr.FOR] += (h - 180.0) * 0.35
	if h > 182.0:
		vals[Attr.VEL] -= (h - 182.0) * 0.25
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
	for _iter in 4:
		var ovr := 0.0
		for i in Attr.COUNT:
			ovr += w[i] * clampf(vals[i], 1.0, 99.0)
		var d := target - ovr
		if absf(d) < 0.3:
			break
		for i in Attr.COUNT:
			if w[i] > 0.0:
				vals[i] += d
	for i in Attr.COUNT:
		var hi := 99.0
		if i == Attr.GOL and pos != Pos.GK:
			vals[i] = clampf(vals[i], 1.0, 25.0)
		p.attrs[i] = int(clampf(round(vals[i]), 1.0, hi))
	p.recompute_overall()


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


static func _pick_potential(rng: RandomNumberGenerator, ovr: int, age: int) -> int:
	var gap := 0.0
	if age <= 18:
		gap = rng.randfn(10.0, 6.0)
	elif age <= 20:
		gap = rng.randfn(7.0, 5.0)
	elif age <= 22:
		gap = rng.randfn(4.5, 3.5)
	elif age <= 24:
		gap = rng.randfn(2.5, 2.5)
	elif age <= 27:
		gap = rng.randfn(1.0, 1.2)
	if age <= 21 and rng.randf() < 0.02:
		gap += rng.randf_range(8.0, 15.0) # joia rara
	gap = maxf(0.0, gap)
	return clampi(ovr + int(round(gap)), ovr, 96)


## Potencial de um jovem da base, influenciado pela qualidade da base do clube e pela escola do país.
static func youth_potential(rng: RandomNumberGenerator, ovr: int, youth_level: int, drift: float = 0.0, nation_bonus: float = 0.0) -> int:
	var gap := rng.randfn(5.0 + youth_level * 0.05 - drift * 0.8 + nation_bonus, 6.5)
	var gem_chance := 0.004 + youth_level * 0.0002 + nation_bonus * 0.001
	if rng.randf() < gem_chance:
		gap += rng.randf_range(12.0, 20.0)
	return clampi(ovr + int(round(maxf(2.0, gap))), ovr + 2, 95)


# ---------------------------------------------------------------------------
# Elencos
# ---------------------------------------------------------------------------

## Gera o elenco inicial de um clube em torno do nível `level` (overall médio dos titulares).
static func create_squad(world: GameWorld, rng: RandomNumberGenerator, club: Club, level: float, used_names: Dictionary) -> void:
	var arch: Dictionary = club.arch()
	var young_share: float = arch.get("young_share", 0.2)
	var veteran_share: float = arch.get("veteran_share", 0.2)
	var slots: Array = SQUAD_TEMPLATE.duplicate()
	# Remove 0-3 vagas de baixo nível (exceto goleiros) e às vezes adiciona uma promessa.
	var removable: Array = []
	for i in slots.size():
		if slots[i][2] >= 1 and slots[i][0] != Pos.GK:
			removable.append(i)
	RngUtil.shuffle(rng, removable)
	var remove_n := rng.randi_range(0, 3)
	var to_remove: Array = removable.slice(0, remove_n)
	to_remove.sort()
	to_remove.reverse()
	for i in to_remove:
		slots.remove_at(i)
	if rng.randf() < 0.45:
		slots.append([RngUtil.pick(rng, [Pos.CM, Pos.ST, Pos.CB, Pos.RW, Pos.AM]), -12.0, 2])
	for s in slots:
		var pos: int = s[0]
		var tier: int = s[2]
		var age := _pick_age(rng, tier, young_share, veteran_share)
		var target: float = level + float(s[1]) + rng.randfn(0.0, 2.6)
		if age <= 20:
			target -= (21 - age) * 1.6
		elif age >= 33:
			target -= (age - 32) * 1.0
		var nat := pick_nationality(rng, club)
		if nat != club.nation:
			target += 1.5
		target = clampf(target, 25.0, 92.0)
		var p := create(world, rng, pos, target, age, nat, club.city, used_names)
		sign_to_club(world, rng, p, club, true)
	assign_statuses(world, club)
	assign_shirt_numbers(world, club)


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
	Valuation.update_value(p, world.year)


## Define status no elenco pela ordem de qualidade (estrela, titular, rotação, reserva, promessa).
static func assign_statuses(world: GameWorld, club: Club) -> void:
	var squad := world.squad(club)
	squad.sort_custom(func(a, b): return a.ovr_f > b.ovr_f)
	var avg := 0.0
	var n := mini(11, squad.size())
	for i in n:
		avg += squad[i].ovr_f
	avg = avg / maxf(1.0, n)
	for i in squad.size():
		var p: Player = squad[i]
		var age := p.age(world.year)
		if i < 2 and p.ovr_f >= avg + 3.0:
			p.squad_status = Player.STATUS_STAR
		elif i < 12:
			p.squad_status = Player.STATUS_STARTER
		elif age <= 21 and p.potential >= p.overall + 6:
			p.squad_status = Player.STATUS_PROSPECT
		elif i < 18:
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
	var nation_bonus := float(DatabaseManager.nation(club.nation).get("youth", 0.0))
	var target := level - 17.0 + club.youth_level * 0.06 + rng.randfn(0.0, 4.0) + (age - 16) * 1.5 - drift + nation_bonus * 0.4
	target = clampf(target, 22.0, 72.0)
	var nat := club.nation if rng.randf() < 0.95 else pick_import(rng, club.nation)
	var p := create(world, rng, pos, target, age, nat, club.city, used_names)
	p.potential = youth_potential(rng, p.overall, club.youth_level, drift, nation_bonus)
	p.squad_status = Player.STATUS_PROSPECT
	sign_to_club(world, rng, p, club, false)
	p.contract_end = world.year + 3
	p.wage = Valuation.round_wage(Valuation.base_wage(p.ovr_f) * 0.6 * float(club.league_cfg().get("wage", 0.5)))
	if p.nationality == club.nation and rng.randf() < 0.55:
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
static func club_level(club: Club) -> float:
	return league_level(club) + float(club.arch().get("level_mod", 0.0))
