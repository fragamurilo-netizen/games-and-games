class_name FixtureManager
extends RefCounted
## Calendários: pontos corridos pelo método do círculo (turnos variáveis por liga) e a
## distribuição das rodadas pelas datas de fim de semana do calendário unificado.


## Um turno completo (cada par se enfrenta uma vez). Retorna Array de rodadas; cada rodada é
## Array de pares [mandante, visitante].
static func single_round_robin(rng: RandomNumberGenerator, club_ids: Array) -> Array:
	var teams: Array = club_ids.duplicate()
	RngUtil.shuffle(rng, teams)
	if teams.size() % 2 == 1:
		teams.append(-1) # folga
	var n := teams.size()
	var leg: Array = []
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
		leg.append(pairs)
		# Rotação: o primeiro fica fixo, os demais giram.
		var last: int = teams[n - 1]
		for k in range(n - 1, 1, -1):
			teams[k] = teams[k - 1]
		teams[1] = last
	return leg


## `turns` turnos: turnos pares espelham o mando do anterior (turno e returno).
static func round_robin(rng: RandomNumberGenerator, club_ids: Array, turns: int) -> Array:
	var first := single_round_robin(rng, club_ids)
	var rounds: Array = []
	var home_count := {}
	var n_turns := maxi(1, turns)
	for t in n_turns:
		# Turno ímpar final (ex.: três turnos): mando decidido para equilibrar os jogos em casa
		if t == n_turns - 1 and t % 2 == 0 and t > 0:
			for pairs in first:
				var balanced: Array = []
				for p in pairs:
					var a: int = p[0]
					var b: int = p[1]
					if int(home_count.get(b, 0)) < int(home_count.get(a, 0)):
						balanced.append([b, a])
					else:
						balanced.append([a, b])
				for q in balanced:
					home_count[q[0]] = int(home_count.get(q[0], 0)) + 1
				rounds.append(balanced)
			continue
		for pairs in first:
			for q in pairs:
				var h: int = q[0] if t % 2 == 0 else q[1]
				home_count[h] = int(home_count.get(h, 0)) + 1
			if t % 2 == 0:
				rounds.append(pairs.duplicate())
			else:
				var mirrored: Array = []
				for p in pairs:
					mirrored.append([p[1], p[0]])
				rounds.append(mirrored)
	return rounds


## Cria os Fixture de uma liga a partir dos pares e distribui as rodadas nas datas de fim de semana.
static func build_league_fixtures(rng: RandomNumberGenerator, league: League, turns: int, weekend_slots: Array) -> void:
	league.rounds.clear()
	var pairs_by_round := round_robin(rng, league.club_ids, turns)
	league.round_slots = spread_rounds(pairs_by_round.size(), weekend_slots)
	for r in pairs_by_round.size():
		var arr: Array = []
		for pair in pairs_by_round[r]:
			var f := Fixture.new()
			f.home = pair[0]
			f.away = pair[1]
			f.round = r
			f.comp = league.id
			f.stage = Fixture.STAGE_LEAGUE
			f.slot = league.round_slots[r]
			arr.append(f)
		league.rounds.append(arr)


## Datas das rodadas: ligas menores folgam em alguns fins de semana, espalhados pela temporada.
static func spread_rounds(n_rounds: int, weekend_slots: Array) -> Array:
	var out: Array = []
	var w := weekend_slots.size()
	for r in n_rounds:
		out.append(weekend_slots[mini(w - 1, int(floor(float(r) * w / maxf(1.0, n_rounds))))])
	return out


## Próximo jogo (não disputado) de um clube a partir da data atual — liga ou copa.
static func next_fixture_for(world: GameWorld, club_id: int) -> Fixture:
	if world.season == null or world.season.finished:
		return null
	var s := world.season
	var league := world.league_of(club_id)
	for d in range(s.day, s.calendar.size()):
		if league != null:
			var r := league.round_at_slot(d)
			if r >= 0:
				var f := league.fixture_for(club_id, r)
				if f != null and not f.played:
					return f
		for cid in s.cups:
			for f in s.cups[cid].fixtures_at(d):
				if f.involves(club_id) and not f.played:
					return f
	return null


## Data do próximo jogo do clube (-1 se não houver mais jogos na temporada).
static func next_slot_for(world: GameWorld, club_id: int) -> int:
	var f := next_fixture_for(world, club_id)
	return f.slot if f != null else -1


## Últimos jogos disputados de um clube (mais recente primeiro), em todas as competições.
static func recent_fixtures(world: GameWorld, club_id: int, count: int) -> Array:
	var out: Array = []
	if world.season == null:
		return out
	var all: Array = []
	var league := world.league_of(club_id)
	if league != null:
		for r in league.rounds:
			for f in r:
				if f.played and f.involves(club_id):
					all.append(f)
	for cid in world.season.cups:
		for f in world.season.cups[cid].fixtures:
			if f.played and f.involves(club_id):
				all.append(f)
	all.sort_custom(func(a, b): return a.slot > b.slot)
	return all.slice(0, count)


## Todos os jogos de um clube na temporada (liga e copas), em ordem de data.
static func season_fixtures(world: GameWorld, club_id: int) -> Array:
	var all: Array = []
	if world.season == null:
		return all
	var league := world.league_of(club_id)
	if league != null:
		for r in league.rounds:
			for f in r:
				if f.involves(club_id):
					all.append(f)
	for cid in world.season.cups:
		for f in world.season.cups[cid].fixtures:
			if f.involves(club_id):
				all.append(f)
	all.sort_custom(func(a, b): return a.slot < b.slot)
	return all
