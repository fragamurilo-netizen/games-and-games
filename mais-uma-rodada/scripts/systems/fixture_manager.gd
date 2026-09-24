class_name FixtureManager
extends RefCounted
## Calendário de pontos corridos: turno e returno pelo método do círculo.
## Com 20 clubes: 38 rodadas, 10 jogos por rodada, cada par se enfrenta uma vez em cada mando.


## Retorna Array de rodadas; cada rodada é Array de pares [mandante, visitante].
static func double_round_robin(rng: RandomNumberGenerator, club_ids: Array) -> Array:
	var teams: Array = club_ids.duplicate()
	RngUtil.shuffle(rng, teams)
	if teams.size() % 2 == 1:
		teams.append(-1) # folga
	var n := teams.size()
	var first_leg: Array = []
	for r in n - 1:
		var pairs: Array = []
		for i in n / 2:
			var a: int = teams[i]
			var b: int = teams[n - 1 - i]
			if a < 0 or b < 0:
				continue
			# Alterna o mando por rodada e por posição no círculo para equilibrar casa/fora.
			if i == 0:
				pairs.append([a, b] if r % 2 == 0 else [b, a])
			elif (i + r) % 2 == 0:
				pairs.append([a, b])
			else:
				pairs.append([b, a])
		first_leg.append(pairs)
		# Rotação: o primeiro fica fixo, os demais giram.
		var last: int = teams[n - 1]
		for k in range(n - 1, 1, -1):
			teams[k] = teams[k - 1]
		teams[1] = last
	var rounds: Array = first_leg.duplicate()
	for pairs in first_leg:
		var mirrored: Array = []
		for p in pairs:
			mirrored.append([p[1], p[0]])
		rounds.append(mirrored)
	return rounds


## Cria os Fixture de uma liga a partir dos pares.
static func build_league_fixtures(rng: RandomNumberGenerator, league: League) -> void:
	league.rounds.clear()
	var pairs_by_round := double_round_robin(rng, league.club_ids)
	for r in pairs_by_round.size():
		var arr: Array = []
		for pair in pairs_by_round[r]:
			var f := Fixture.new()
			f.home = pair[0]
			f.away = pair[1]
			f.round = r
			f.competition = "L"
			f.division = league.division
			arr.append(f)
		league.rounds.append(arr)


## Próximo jogo (não disputado) de um clube a partir de um dia do calendário.
static func next_fixture_for(world: GameWorld, club_id: int) -> Fixture:
	if world.season == null or world.season.finished:
		return null
	var league := world.league_of(club_id)
	if league == null:
		return null
	for d in range(world.season.day, world.season.calendar.size()):
		var e: Dictionary = world.season.calendar[d]
		if e.get("t", "L") == "L":
			var f := league.fixture_for(club_id, int(e["r"]))
			if f != null and not f.played:
				return f
	return null


## Últimos jogos disputados de um clube (mais recente primeiro).
static func recent_fixtures(world: GameWorld, club_id: int, count: int) -> Array:
	var out: Array = []
	var league := world.league_of(club_id)
	if league == null:
		return out
	for r in range(league.rounds.size() - 1, -1, -1):
		var f := league.fixture_for(club_id, r)
		if f != null and f.played:
			out.append(f)
			if out.size() >= count:
				break
	return out
