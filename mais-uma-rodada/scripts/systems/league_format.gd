class_name LeagueFormat
extends RefCounted
## Formatos reais das ligas além dos pontos corridos (leagues.json → "format"):
##
##   split   depois da fase regular a tabela se divide em grupos que jogam entre si; o grupo de
##           cima fica sempre à frente na classificação final. {"type": "split", "groups": [6, 6],
##           "legs": [1, 1], "halve": false} — halve corta os pontos pela metade (Bélgica, Áustria).
##   playoff os primeiros da fase regular decidem o título em mata-mata; a tabela continua valendo
##           para vagas e rebaixamento. {"type": "playoff", "teams": 8, "byes": 0,
##           "ko": ["qf", "sf", "f"], "legs": {"qf": 2, "sf": 2, "f": 2}, "neutral_final": false}
##   promo   playoffs de acesso: os colocados de "from" em diante (teams clubes) decidem a última vaga
##           de acesso em mata-mata (Championship, LaLiga 2, Serie B, Ligue 2). O campeão continua sendo
##           o primeiro da tabela. {"type": "promo", "from": 3, "teams": 4, "ko": ["sf", "f"], ...}
##
## As datas da fase final são os últimos fins de semana da temporada, reservados ao montar a
## liga (League.phase_slots). O estado fica no próprio League (salvo com a temporada).

const KO_NAMES := {"r16": "Oitavas", "ef": "Eliminatória", "qf": "Quartas", "sf": "Semifinal", "f": "Final"}


static func cfg(league: League) -> Dictionary:
	return league.cfg().get("format", {})


static func kind(league: League) -> String:
	return String(cfg(league).get("type", ""))


## Fins de semana que a fase final precisa (reservados no fim da temporada).
static func extra_rounds(league_cfg: Dictionary, n_clubs: int) -> int:
	var f: Dictionary = league_cfg.get("format", {})
	match String(f.get("type", "")):
		"split":
			var groups := _group_sizes(f, n_clubs)
			var legs: Array = f.get("legs", [1])
			var most := 0
			for i in groups.size():
				var g: int = groups[i]
				var l := int(legs[mini(i, legs.size() - 1)])
				most = maxi(most, (g - 1 + g % 2) * l)
			return most
		"playoff", "promo":
			var n := 0
			var legs2: Dictionary = f.get("legs", {})
			for k in f.get("ko", []):
				n += int(legs2.get(k, 1))
			return n
	return 0


static func _group_sizes(f: Dictionary, n_clubs: int) -> Array:
	var sizes: Array = Array(f.get("groups", [6])).duplicate()
	var used := 0
	for s in sizes:
		used += int(s)
	if used < n_clubs:
		sizes.append(n_clubs - used) # o resto forma o último grupo
	elif used > n_clubs:
		sizes[sizes.size() - 1] = maxi(0, int(sizes[sizes.size() - 1]) - (used - n_clubs))
	return sizes.filter(func(x): return int(x) >= 2)


## Chamado depois de cada data: abre a segunda fase, avança o mata-mata e define o campeão.
static func after_slot(world: GameWorld, league: League) -> Array:
	var events: Array = []
	var k := kind(league)
	if k == "" or league.regular_rounds <= 0:
		return events
	if not _regular_done(league):
		return events
	if k == "split" and league.phase_groups.is_empty():
		_start_split(world, league)
		events.append({"t": "split", "league": league.id})
	elif k == "playoff" or k == "promo":
		events.append_array(_playoff_step(world, league))
	return events


static func _regular_done(league: League) -> bool:
	for r in league.regular_rounds:
		for f: Fixture in league.rounds[r]:
			if not f.played:
				return false
	return true


# ---------------------------------------------------------------------------
# Split
# ---------------------------------------------------------------------------

static func _start_split(world: GameWorld, league: League) -> void:
	var f := cfg(league)
	var order := CompetitionManager.sort_table(league.club_ids, league.table)
	var sizes := _group_sizes(f, order.size())
	var legs: Array = f.get("legs", [1])
	if bool(f.get("halve", false)):
		for cid in league.table:
			var row: Dictionary = league.table[cid]
			row["pts"] = int(ceil(int(row["pts"]) / 2.0))
	var at := 0
	var group_rounds: Array = []
	for i in sizes.size():
		var ids: Array = order.slice(at, at + int(sizes[i]))
		at += int(sizes[i])
		league.phase_groups.append(ids)
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([world.world_seed, world.year, league.id, i])
		group_rounds.append(FixtureManager.round_robin(rng, ids, int(legs[mini(i, legs.size() - 1)])))
	var most := 0
	for gr in group_rounds:
		most = maxi(most, gr.size())
	for r in mini(most, league.phase_slots.size()):
		var arr: Array = []
		var slot := int(league.phase_slots[r])
		for gr in group_rounds:
			if r >= gr.size():
				continue
			for pair in gr[r]:
				var fx := Fixture.new()
				fx.home = pair[0]
				fx.away = pair[1]
				fx.round = league.rounds.size()
				fx.comp = league.id
				fx.stage = Fixture.STAGE_LEAGUE
				fx.slot = slot
				arr.append(fx)
		league.rounds.append(arr)
		league.round_slots.append(slot)


## Classificação final respeitando os grupos da segunda fase.
static func sorted_ids(league: League) -> Array:
	if league.phase_groups.is_empty():
		return CompetitionManager.sort_table(league.club_ids, league.table)
	var out: Array = []
	for g in league.phase_groups:
		out.append_array(CompetitionManager.sort_table(g, league.table))
	return out


# ---------------------------------------------------------------------------
# Playoffs
# ---------------------------------------------------------------------------

static func _legs(league: League, r: int) -> int:
	var f := cfg(league)
	var ko: Array = f.get("ko", ["f"])
	return int(Dictionary(f.get("legs", {})).get(ko[clampi(r, 0, ko.size() - 1)], 1))


static func _slot_index(league: League, r: int) -> int:
	var i := 0
	for k in r:
		i += _legs(league, k)
	return i


static func _playoff_step(world: GameWorld, league: League) -> Array:
	var events: Array = []
	var f := cfg(league)
	var ko: Array = f.get("ko", ["f"])
	var po := league.po
	if po.is_empty():
		var n := int(f.get("teams", 8))
		var byes := int(f.get("byes", 0))
		var first := maxi(0, int(f.get("from", 1)) - 1) if kind(league) == "promo" else 0
		var seeds := CompetitionManager.sort_table(league.club_ids, league.table).slice(first, first + n)
		po["seeds"] = seeds
		po["ties"] = []
		po["champ"] = -1
		po["runner"] = -1
		_create_round(world, league, 0, _pairs(seeds.slice(byes), _legs(league, 0)))
		events.append({"t": "playoff_start", "league": league.id, "clubs": seeds})
		return events
	if int(po.get("champ", -1)) >= 0:
		return events
	var last_r := -1
	for t in po["ties"]:
		last_r = maxi(last_r, int(t["r"]))
	var all_done := true
	for t in po["ties"]:
		if int(t["r"]) != last_r or int(t["w"]) >= 0:
			continue
		var fx := _tie_fixtures(league, t)
		var done := fx.size() >= _legs(league, last_r)
		for g in fx:
			if not g.played:
				done = false
		if not done:
			all_done = false
			continue
		t["w"] = _tie_winner(world, t, fx)
	if not all_done:
		return events
	var winners: Array = []
	for t in po["ties"]:
		if int(t["r"]) == last_r:
			winners.append(int(t["w"]))
	if last_r >= ko.size() - 1:
		var final_tie: Dictionary = po["ties"][po["ties"].size() - 1]
		po["champ"] = int(final_tie["w"])
		po["runner"] = int(final_tie["a"]) if int(final_tie["w"]) == int(final_tie["b"]) else int(final_tie["b"])
		events.append({"t": "playoff_champion", "league": league.id, "club": po["champ"]})
		return events
	if last_r == 0:
		var byes2 := int(f.get("byes", 0))
		winners = Array(po["seeds"]).slice(0, byes2) + winners
	# Os mais bem colocados na fase regular enfrentam os piores que restaram.
	var seeds_order: Array = po["seeds"]
	winners.sort_custom(func(a, b): return seeds_order.find(a) < seeds_order.find(b))
	_create_round(world, league, last_r + 1, _pairs(winners, _legs(league, last_r + 1)))
	return events


## 1º x último, 2º x penúltimo: jogo único na casa do melhor; em dois jogos, ele decide em casa.
static func _pairs(seeds: Array, legs: int) -> Array:
	var out: Array = []
	var n := seeds.size()
	for i in n / 2:
		var best: int = seeds[i]
		var worst: int = seeds[n - 1 - i]
		out.append([best, worst] if legs == 1 else [worst, best])
	return out


static func _create_round(world: GameWorld, league: League, r: int, pairs: Array) -> void:
	var f := cfg(league)
	var ko: Array = f.get("ko", ["f"])
	var legs := _legs(league, r)
	var first := _slot_index(league, r)
	var neutral := r == ko.size() - 1 and legs == 1 and bool(f.get("neutral_final", false))
	for leg in legs:
		var si := first + leg
		if si >= league.phase_slots.size():
			break
		var slot := int(league.phase_slots[si])
		var arr: Array = []
		for pair in pairs:
			var fx := Fixture.new()
			fx.home = int(pair[0]) if leg == 0 else int(pair[1])
			fx.away = int(pair[1]) if leg == 0 else int(pair[0])
			fx.round = r
			fx.leg = leg
			fx.comp = league.id
			fx.stage = Fixture.STAGE_KO
			fx.slot = slot
			fx.neutral = neutral
			arr.append(fx)
		league.rounds.append(arr)
		league.round_slots.append(slot)
	for pair in pairs:
		league.po["ties"].append({"r": r, "a": int(pair[0]), "b": int(pair[1]), "w": -1})


static func _tie_fixtures(league: League, t: Dictionary) -> Array:
	var out: Array = []
	for rr in range(league.regular_rounds, league.rounds.size()):
		for g: Fixture in league.rounds[rr]:
			if g.stage == Fixture.STAGE_KO and g.round == int(t["r"]) and ((g.home == int(t["a"]) and g.away == int(t["b"])) or (g.home == int(t["b"]) and g.away == int(t["a"]))):
				out.append(g)
	out.sort_custom(func(x: Fixture, y: Fixture): return x.leg < y.leg)
	return out


static func _tie_winner(world: GameWorld, t: Dictionary, fx: Array) -> int:
	var a := int(t["a"])
	var b := int(t["b"])
	var ga := 0
	var gb := 0
	for g: Fixture in fx:
		if g.home == a:
			ga += g.hg
			gb += g.ag
		else:
			ga += g.ag
			gb += g.hg
	if ga != gb:
		return a if ga > gb else b
	var last: Fixture = fx[fx.size() - 1]
	if last.has_penalties():
		return last.home if last.pen_h > last.pen_a else last.away
	return a if world.club(a).reputation >= world.club(b).reputation else b


## É o jogo que decide o confronto (vale prorrogação e pênaltis)?
static func is_deciding_leg(world: GameWorld, f: Fixture) -> bool:
	var league := world.league(f.comp)
	if league == null or f.stage != Fixture.STAGE_KO:
		return false
	return f.leg == _legs(league, f.round) - 1


static func aggregate_before(world: GameWorld, f: Fixture) -> Array:
	if f.leg == 0:
		return [0, 0]
	var league := world.league(f.comp)
	if league == null:
		return [0, 0]
	for rr in range(league.regular_rounds, league.rounds.size()):
		for g: Fixture in league.rounds[rr]:
			if g.stage == Fixture.STAGE_KO and g.round == f.round and g.leg == 0 and g.home == f.away and g.away == f.home and g.played:
				return [g.ag, g.hg]
	return [0, 0]


## Campeão da temporada: o dos playoffs quando a liga tem playoffs; senão o primeiro da tabela.
static func champion(league: League, ids: Array) -> int:
	if kind(league) == "playoff" and int(league.po.get("champ", -1)) >= 0:
		return int(league.po["champ"])
	return int(ids[0]) if not ids.is_empty() else -1


static func runner_up(league: League, ids: Array) -> int:
	if kind(league) == "playoff" and int(league.po.get("runner", -1)) >= 0:
		return int(league.po["runner"])
	return int(ids[1]) if ids.size() > 1 else -1


static func round_label(league: League, f: Fixture) -> String:
	if f.stage != Fixture.STAGE_KO:
		return "%dª rodada" % (f.round + 1)
	var ko: Array = cfg(league).get("ko", ["f"])
	var name := String(KO_NAMES.get(ko[clampi(f.round, 0, ko.size() - 1)], "Playoff"))
	if _legs(league, f.round) == 2:
		name += " · %s" % ("ida" if f.leg == 0 else "volta")
	return ("Playoffs de acesso · " if kind(league) == "promo" else "Playoffs · ") + name


## Clubes que sobem: os primeiros da tabela e, com playoffs de acesso, o vencedor deles na
## última vaga (se os playoffs não terminaram, vale a tabela).
static func promoted(league: League, ids: Array, up: int) -> Array:
	if up <= 0:
		return []
	if kind(league) != "promo":
		return ids.slice(0, up)
	var out: Array = ids.slice(0, up - 1)
	var w := int(league.po.get("champ", -1))
	out.append(w if w >= 0 and not out.has(w) else ids[mini(up - 1, ids.size() - 1)])
	return out


## Texto do regulamento para a interface.
static func describe(league: League) -> String:
	return String(cfg(league).get("desc", ""))
