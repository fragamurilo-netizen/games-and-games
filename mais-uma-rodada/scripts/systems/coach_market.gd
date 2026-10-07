class_name CoachMarket
extends RefCounted
## Mercado de técnicos da IA com a cara de cada liga (data/gameplay/coach_market.json):
##   - quem é contratado: muitos estrangeiros na Premier e na Arábia, portugueses e argentinos no
##     Brasil, argentinos no México e no Chile, a maioria da casa na Itália e na Espanha;
##   - a pressão vem do resultado contra o esperado (perder para o pequeno pesa muito, para o
##     grande quase nada) e da tabela contra a meta da diretoria;
##   - demitir custa: contrato com salário e rescisão; caixa curto segura o técnico; quem acabou de
##     chegar tem lua de mel; perto do fim, quem não corre risco espera as férias para trocar;
##   - o substituto sai dos livres (que circulam pela liga: o rodízio), de um clube menor (com
##     multa) ou de fora, e pode recusar: técnico de nome não vai para clube pequeno;
##   - todo ano entram técnicos novos no mercado (ex-auxiliares, ex-jogadores) e contratos vencem.
##
## Técnico (dict de People): "ct" último ano do contrato, "wg" salário mensal, "sev" rescisão paga
## na última demissão.

const POOL_MIN := 120


static func data() -> Dictionary:
	var d: Variant = DatabaseManager.get_data("coach_market")
	return d if d is Dictionary else {}


## Perfil do mercado da liga do clube: {f, from, sack, ct}.
static func profile(club: Club) -> Dictionary:
	var d := data()
	var lg: Dictionary = d.get("leagues", {})
	if club != null and lg.has(club.league_id):
		return lg[club.league_id]
	if club != null and lg.has(club.nation + "1"):
		var p: Dictionary = (lg[club.nation + "1"] as Dictionary).duplicate()
		p["f"] = float(p["f"]) * 0.5
		return p
	return d.get("default", {"f": 0.15, "from": {}, "sack": 1.0, "ct": [1, 2]})


## Nacionalidade de um técnico novo para o clube: da casa ou de fora, pelas rotas da liga.
static func coach_nation(r: RandomNumberGenerator, club: Club) -> String:
	var p := profile(club)
	if r.randf() >= float(p.get("f", 0.15)):
		return club.nation
	var pool := {}
	var from: Dictionary = p.get("from", {})
	for k in from:
		if not (DatabaseManager.nation(String(k)).get("origins", []) as Array).is_empty() and String(k) != club.nation:
			pool[k] = float(from[k])
	if pool.is_empty():
		return club.nation
	return String(RngUtil.weighted_key(r, pool))


## Salário mensal do técnico: fração da folha do clube, maior para quem tem nome.
static func wage_for(club: Club, co: Dictionary) -> int:
	return Valuation.round_wage(maxf(3000.0, float(club.wage_budget) * (0.035 + 0.045 * float(co.get("rep", 50.0)) / 100.0)))


## Contrato com a duração típica da liga (assinado nas férias conta a partir da temporada nova).
static func sign_contract(world: GameWorld, r: RandomNumberGenerator, co: Dictionary, club: Club) -> void:
	var ct: Array = profile(club).get("ct", [1, 2])
	var yrs := r.randi_range(int(ct[0]), int(ct[1]))
	if float(co.get("rep", 50.0)) >= 75.0 and yrs < int(ct[1]):
		yrs += 1
	var off := world.season == null or world.season.finished
	co["ct"] = world.year + yrs - (0 if off else 1)


## Contrato de quem já estava no cargo no começo do mundo: vence em anos diferentes.
static func sign_existing(world: GameWorld, r: RandomNumberGenerator, co: Dictionary, club: Club) -> void:
	sign_contract(world, r, co, club)
	var ct: Array = profile(club).get("ct", [1, 2])
	co["ct"] = world.year + r.randi_range(0, int(ct[1]))
	co["wg"] = wage_for(club, co)


## Meses que faltam na temporada (0 nas férias).
static func months_left(world: GameWorld) -> int:
	if world.season == null or world.season.finished:
		return 0
	var total := maxi(1, world.season.calendar.size())
	return clampi(int(round(10.0 * (1.0 - float(world.season.day) / float(total)))), 0, 10)


## Rescisão: os salários que faltam até o fim do contrato, com desconto de acordo.
static func sack_cost(world: GameWorld, club: Club, co: Dictionary) -> int:
	var months := (int(co.get("ct", world.year)) - world.year) * 12 + months_left(world)
	months = clampi(months, 1, 30)
	var wg := int(co.get("wg", wage_for(club, co)))
	return Valuation.round_value(wg * months * 0.7)


## Resultado esperado (0 a 1) pelo tamanho dos dois clubes, com o mando.
static func expected(club: Club, opp: Club, home: bool) -> float:
	if opp == null:
		return 0.5
	var diff := club.reputation - opp.reputation + (4.0 if home else -4.0)
	return 1.0 / (1.0 + pow(10.0, -diff / 22.0))


## Quanto o jogo mexe no cargo: o resultado contra o esperado.
static func result_delta(world: GameWorld, club: Club, f: Fixture, res: String) -> float:
	var opp := world.club(f.opponent_of(club.id))
	var e := expected(club, opp, f.home == club.id and not f.neutral)
	var got := 1.0 if res == "V" else (0.45 if res == "E" else 0.0)
	return (got - e) * 5.0


## A tabela contra a meta da diretoria (depois de seis rodadas), toda semana.
static func table_delta(world: GameWorld, club: Club) -> float:
	var league := world.league(club.league_id)
	if league == null or league.rounds_played() < 6:
		return 0.0
	var pos := CompetitionManager.position_of(league, club.id)
	if pos <= 0:
		return 0.0
	var goal := int(SeasonManager.goal_of(world, club.id)[1])
	var teams := league.club_ids.size()
	var safe := teams - league.relegated_count()
	var d := -clampf(float(pos - goal) * 0.22, -0.6, 1.6)
	if league.relegated_count() > 0 and pos > safe and goal <= safe:
		d -= 0.8
	return d


## Chance de o técnico cair depois deste jogo.
static func sack_chance(world: GameWorld, club: Club, co: Dictionary) -> float:
	var job := float(co.get("job", 60.0))
	if job >= 36.0:
		return 0.0
	var games := int(co.get("w", 0)) + int(co.get("d", 0)) + int(co.get("l", 0))
	if games < 4:
		return 0.0 # lua de mel
	var p := (36.0 - job) / 36.0 * 0.5 * float(profile(club).get("sack", 1.0))
	if club.streak_winless < 2:
		p *= 0.35
	var league := world.league(club.league_id)
	if league != null:
		var left := CompetitionManager.remaining_rounds(league, club.id)
		var teams := league.club_ids.size()
		var pos := CompetitionManager.position_of(league, club.id)
		var danger := league.relegated_count() > 0 and pos > teams - league.relegated_count() - 2
		if left <= 3 and not danger:
			p *= 0.3 # quem não corre risco espera as férias
	if club.balance < sack_cost(world, club, co) * 1.5:
		p *= 0.45 # rescisão cara e caixa curto
	return clampf(p, 0.0, 0.6)


## Fatia de estrangeiros no banco da liga hoje.
static func foreign_share(world: GameWorld, club: Club) -> float:
	var pp := People.data(world)
	var n := 0
	var f := 0
	for c: Club in world.clubs_in_league(club.league_id):
		var co: Dictionary = pp["coaches"].get(c.id, {})
		if co.is_empty() or c.id == club.id:
			continue
		n += 1
		if String(co.get("nat", "")) != c.nation:
			f += 1
	return float(f) / float(n) if n > 0 else 0.0


## Já trabalhou como técnico neste país (o rodízio: os nomes que circulam pela liga)?
static func knows_country(world: GameWorld, co: Dictionary, nation: String) -> bool:
	for sp in co.get("car", []):
		if String(sp.get("k", "")) != "":
			continue
		var c := world.club(int(sp.get("c", -1)))
		if c != null and c.nation == nation:
			return true
	return false


## Escolhe o técnico novo: livres, empregados de clube menor (com multa) ou de fora, nessa ordem
## de preferência pelo encaixe. O escolhido pode recusar. {co, from (Club|null), fee} ou {} se
## ninguém topou.
static func choose(world: GameWorld, r: RandomNumberGenerator, club: Club, old: Dictionary, allow_poach: bool) -> Dictionary:
	var pp := People.data(world)
	var prof := profile(club)
	var from: Dictionary = prof.get("from", {})
	var pull := (float(prof.get("f", 0.15)) - foreign_share(world, club)) * 30.0
	var cands: Array = []
	for co: Dictionary in pp["free"]:
		cands.append([co, null])
	if allow_poach:
		for cid in pp["coaches"]:
			var t := world.club(int(cid))
			var co2: Dictionary = pp["coaches"][cid]
			if t == null or t.id == club.id or world.is_user_club(t.id) or bool(co2.get("int", false)):
				continue
			if t.reputation > club.reputation - 10.0 or float(co2.get("job", 60.0)) < 55.0:
				continue
			cands.append([co2, t])
	var scored: Array = []
	for pair in cands:
		var co: Dictionary = pair[0]
		var t: Club = pair[1]
		if int(co.get("id", -1)) == int(old.get("id", -2)):
			continue
		var rep := float(co.get("rep", 40.0))
		if rep < club.reputation - 28.0:
			continue
		var s := -absf(rep - club.reputation * 0.92)
		var nat := String(co.get("nat", ""))
		if nat == club.nation:
			s += 4.0 - pull * 0.5
		else:
			s += float(from.get(nat, 0.0)) * 2.0 + pull - (10.0 if not from.has(nat) else 0.0)
		if knows_country(world, co, club.nation):
			s += 5.0
		s += minf(8.0, float(co.get("bt", 0)) * 2.0) + clampf(float(co.get("sov", 0)) * 1.5, -6.0, 6.0)
		s += minf(20.0, FootballMemory.coach_bond(world, co, club.id) / 8.0)
		if t != null:
			s -= 12.0 if t.nation == club.nation else 16.0 # tirar de outro clube só vale se for bem melhor
		if world.year - int(co.get("by", world.year - 50)) >= 68:
			s -= 8.0
		s += r.randf() * 6.0
		scored.append([s, co, t])
	scored.sort_custom(func(a, b): return float(a[0]) > float(b[0]))
	for i in mini(6, scored.size()):
		var co3: Dictionary = scored[i][1]
		var t3: Club = scored[i][2]
		if not _accepts(world, r, club, co3, t3):
			continue
		var fee := 0
		if t3 != null:
			fee = maxi(50000, sack_cost(world, t3, co3))
		return {"co": co3, "from": t3, "fee": fee}
	return {}


## O técnico topa? Empregado só sai para um clube bem maior; livre de nome não desce muito.
static func _accepts(world: GameWorld, r: RandomNumberGenerator, club: Club, co: Dictionary, t: Club) -> bool:
	var rep := float(co.get("rep", 40.0))
	if t != null:
		return r.randf() < clampf(0.55 + (club.reputation - t.reputation) / 60.0, 0.1, 0.95)
	var p := 0.88
	if rep > club.reputation + 10.0:
		p = clampf(0.6 - (rep - club.reputation - 10.0) / 30.0, 0.08, 0.6)
	if String(co.get("nat", "")) != club.nation and not knows_country(world, co, club.nation):
		p *= 0.85
	return r.randf() < p


## Fim de temporada: técnicos novos entram no mercado (ex-auxiliares, ex-jogadores que fizeram
## o curso), cada país na proporção dos seus clubes, e a lista de livres não cresce sem fim.
static func season_supply(world: GameWorld, r: RandomNumberGenerator) -> void:
	var pp := People.data(world)
	var by_nat := {}
	for c: Club in world.clubs:
		if c != null and c.nation != "":
			if not by_nat.has(c.nation):
				by_nat[c.nation] = []
			by_nat[c.nation].append(c)
	for n in by_nat:
		var arr: Array = by_nat[n]
		var k := int(floor(arr.size() * 0.035 + r.randf()))
		for _i in k:
			var c: Club = arr[r.randi_range(0, arr.size() - 1)]
			var co := People._new_coach(world, r, n, c.reputation - r.randf_range(6.0, 20.0), "", n)
			CoachCareer.fresh_past(world, r, co, c)
			CoachSchools.on_new_coach(world, co)
			pp["free"].append(co)
	trim_pool(world)


## Lista de livres com teto: saem primeiro os mais velhos e os de menos nome.
static func trim_pool(world: GameWorld) -> void:
	var pp := People.data(world)
	var cap := maxi(POOL_MIN, world.clubs.size() / 4)
	var free: Array = pp["free"]
	if free.size() <= cap:
		return
	free.sort_custom(func(a: Dictionary, b: Dictionary):
		return _keep_score(world, a) > _keep_score(world, b))
	pp["free"] = free.slice(0, cap)


static func _keep_score(world: GameWorld, co: Dictionary) -> float:
	var age := world.year - int(co.get("by", world.year - 50))
	return float(co.get("rep", 40.0)) - maxf(0.0, age - 58.0) * 3.0
