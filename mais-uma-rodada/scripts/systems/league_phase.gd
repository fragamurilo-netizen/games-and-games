class_name LeaguePhase
extends RefCounted
## Champions league phase: four pots, eight distinct opponents, seeded knockout path.
## The fixture template is a factorization of C36(1,2,3,4). Clubs are drawn into
## positions within their pot; association restrictions are checked on every draw.

const SLOTS := ["C1", "C2", "C3", "C4", "C5", "C6", "C7", "C8"]
const PLAN := ["po", "r16", "qf", "sf", "f"]
const KO_DATES := [["C9", "C10"], ["C11", "C12"], ["C14", "C15"], ["C16", "C17"], ["C13"]]
const ROUNDS := [
	[[0,9],[18,27],[1,10],[19,28],[2,11],[20,29],[3,12],[21,30],[4,13],[22,31],[5,14],[23,32],[6,15],[24,33],[7,16],[25,34],[8,17],[26,35]],
	[[9,18],[27,1],[10,19],[28,2],[11,20],[29,3],[12,21],[30,4],[13,22],[31,5],[14,23],[32,6],[15,24],[33,7],[16,25],[34,8],[17,26],[35,0]],
	[[0,27],[19,11],[3,30],[22,14],[6,33],[25,17],[9,1],[28,20],[12,4],[31,23],[15,7],[34,26],[18,10],[2,29],[21,13],[5,32],[24,16],[8,35]],
	[[27,19],[11,3],[30,22],[14,6],[33,25],[17,0],[1,28],[20,12],[4,31],[23,15],[7,34],[26,9],[10,2],[29,21],[13,5],[32,24],[16,8],[35,18]],
	[[0,18],[1,19],[2,20],[3,21],[4,22],[5,23],[6,7],[24,25],[8,26],[9,27],[10,28],[11,29],[12,30],[13,31],[14,32],[15,16],[33,34],[17,35]],
	[[0,1],[18,19],[2,3],[20,21],[4,5],[22,23],[6,24],[7,8],[25,26],[9,10],[27,28],[11,12],[29,30],[13,14],[31,32],[15,33],[16,17],[34,35]],
	[[18,1],[19,2],[20,3],[21,4],[22,5],[23,6],[24,7],[25,8],[26,0],[27,10],[28,11],[29,12],[30,13],[31,14],[32,15],[33,16],[34,17],[35,9]],
	[[1,2],[19,20],[3,4],[21,22],[5,6],[23,24],[7,25],[8,0],[26,18],[10,11],[28,29],[12,13],[30,31],[14,15],[32,33],[16,34],[17,9],[35,27]]
]


## Insert extra knockout dates in free midweeks; if the unified calendar has
## too few, postpone the continental final and later dates. Existing slot codes,
## transfer-window markers and the final-before-Club-World-Cup order survive.
static func extend_calendar(calendar: Array) -> Array:
	var after := -1
	var final_day := -1
	for e in calendar:
		if e["t"] == "C12":
			after = int(e["d"])
		if e["t"] == "C13":
			final_day = int(e["d"])
	if after < 0 or final_day < 0:
		return calendar
	var dates: Array = []
	for i in range(calendar.size() - 1):
		var e: Dictionary = calendar[i]
		var day := int(e["d"])
		if e["t"] == "W" and day > after and day + 4 < final_day and int(calendar[i + 1]["d"]) - day >= 6:
			dates.append(day + 4)
			if dates.size() == 4:
				break
	var missing := 4 - dates.size()
	if missing > 0:
		for e in calendar:
			if int(e["d"]) >= final_day:
				e["d"] = int(e["d"]) + missing * 7
		for i in missing:
			dates.append(final_day + i * 7)
	for i in 4:
		calendar.append({"t": "C%d" % (14 + i), "d": dates[i]})
	calendar.sort_custom(func(a, b): return int(a["d"]) < int(b["d"]))
	return calendar


static func rounds_for(id: String) -> Array:
	if id != "UECL":
		return ROUNDS
	# Six pots of six: one opponent per pot. The pot round-robin supplies
	# five dates; the sixth pairs clubs inside their own pot. Orient cycles
	# so every club has one home and one away against each paired pot (1/2,3/4,5/6).
	var rounds: Array = []
	var own: Array = []
	for p in 6:
		for i in range(0, 6, 2):
			var pair := [p * 6 + i, p * 6 + i + 1]
			own.append(pair if p % 2 == 0 else [pair[1], pair[0]])
	rounds.append(own)
	var pots := [0, 1, 2, 3, 4, 5]
	for r in 5:
		var games: Array = []
		for k in 3:
			var a: int = mini(pots[k], pots[5 - k])
			var b: int = maxi(pots[k], pots[5 - k])
			for i in 6:
				var home_a := (i % 2 != 0) if a / 2 == b / 2 else (a % 2 == b % 2)
				games.append([a * 6 + i, b * 6 + i] if home_a else [b * 6 + i, a * 6 + i])
		rounds.append(games)
		pots.insert(1, pots.pop_back())
	return rounds


static func matchdays(cup: Cup) -> int:
	var count := 0
	for f: Fixture in cup.fixtures:
		if f.stage == Fixture.STAGE_GROUP:
			count = maxi(count, f.round + 1)
	return count


static func draw(world: GameWorld, ids: Array, id: String = "UCL") -> Array:
	if ids.size() != 36:
		return []
	var seeds := ids.duplicate()
	seeds.sort_custom(func(a, b):
		var ca := CupManager._coef(world, a)
		var cb := CupManager._coef(world, b)
		return ca > cb or (is_equal_approx(ca, cb) and a < b))
	var holder := CupManager.last_winner(world, "C:" + id)
	if seeds.has(holder):
		seeds.erase(holder)
		seeds.push_front(holder)
	var neighbours: Array = []
	for i in 36:
		neighbours.append([])
	var rounds := rounds_for(id)
	var pot_size := 6 if id == "UECL" else 9
	for row in rounds:
		for pair in row:
			neighbours[pair[0]].append(pair[1])
			neighbours[pair[1]].append(pair[0])
	var best: Array = []
	var best_cost := 100000
	# Swap only within pots, preserving sporting seeding and all fixture invariants.
	for attempt in 40:
		var order: Array = []
		for p in 36 / pot_size:
			var pot := seeds.slice(p * pot_size, (p + 1) * pot_size)
			RngUtil.shuffle(world.rng, pot)
			order.append_array(pot)
		var nations: Array = []
		for cid in order:
			nations.append(world.club(cid).nation)
		var score := _cost(nations, neighbours, range(36))
		for step in 6000:
			if score < best_cost:
				best_cost = score
				best = order.duplicate()
			if score == 0:
				return order
			var a := world.rng.randi_range(0, 35)
			var b := (a / pot_size) * pot_size + world.rng.randi_range(0, pot_size - 1)
			if nations[a] == nations[b]:
				continue
			var affected: Array = [a, b]
			for v in neighbours[a] + neighbours[b]:
				if not affected.has(v):
					affected.append(v)
			var before := _cost(nations, neighbours, affected)
			_swap(nations, a, b)
			var delta := _cost(nations, neighbours, affected) - before
			var temperature := maxf(0.12, 2.0 * (1.0 - float(step % 2000) / 2000.0))
			if delta <= 0 or world.rng.randf() < exp(-float(delta) / temperature):
				_swap(order, a, b)
				score += delta
			else:
				_swap(nations, a, b)
	# A mod can create an impossible association distribution. Keep the complete
	# 36-team schedule rather than falling into an invalid 18-tie knockout bracket.
	push_warning("%s draw: association restrictions relaxed for custom participant distribution." % id)
	return best


static func _swap(a: Array, i: int, j: int) -> void:
	var tmp: Variant = a[i]
	a[i] = a[j]
	a[j] = tmp


static func _cost(nations: Array, neighbours: Array, vertices: Array) -> int:
	var cost := 0
	for v in vertices:
		var counts := {}
		for other in neighbours[v]:
			var nation: String = nations[other]
			if nation == nations[v]:
				cost += 8
			counts[nation] = int(counts.get(nation, 0)) + 1
		for n in counts.values():
			cost += maxi(0, int(n) - 2)
	return cost


static func setup(world: GameWorld, season: SeasonState, cup: Cup) -> bool:
	var ids := draw(world, cup.club_ids, cup.id)
	if ids.is_empty():
		return false
	cup.league_phase = true
	cup.club_ids = ids
	cup.plan = PLAN.duplicate()
	cup.plan_slots = KO_DATES.duplicate(true)
	cup.round_names = ["Playoffs", "Oitavas de final", "Quartas de final", "Semifinal", "Final"]
	var table := {}
	for cid in ids:
		table[cid] = CompetitionManager.empty_row()
		table[cid]["coef"] = CupManager._coef(world, cid)
		table[cid]["name"] = world.club(cid).short_name
	cup.groups = [{"n": "Fase de liga", "clubs": ids.duplicate(), "table": table}]
	var rounds := rounds_for(cup.id)
	for r in rounds.size():
		for pair in rounds[r]:
			var f := Fixture.new()
			f.home = ids[pair[0]]
			f.away = ids[pair[1]]
			f.comp = cup.id
			f.stage = Fixture.STAGE_GROUP
			f.round = r
			f.slot = season.slot_of(SLOTS[r])
			cup.fixtures.append(f)
	return true


## UEFA article 18. Opponent totals only break ties after the eighth matchday.
static func sorted_ids(cup: Cup, table_override: Dictionary = {}, live_scores: Dictionary = {}) -> Array:
	if cup.groups.is_empty():
		return []
	var table: Dictionary = cup.groups[0]["table"] if table_override.is_empty() else table_override
	var extra := {}
	var complete := true
	for cid in cup.club_ids:
		extra[cid] = [0, 0, 0, 0, 0] # away goals/wins, opponent pts/GD/GF
	for f: Fixture in cup.fixtures:
		if f.stage != Fixture.STAGE_GROUP:
			continue
		if not f.played and not live_scores.has(f):
			complete = false
			continue
		var score: Array = live_scores.get(f, [f.hg, f.ag])
		extra[f.away][0] += int(score[1])
		extra[f.away][1] += 1 if int(score[1]) > int(score[0]) else 0
		for pair in [[f.home, f.away], [f.away, f.home]]:
			var opponent: Dictionary = table[pair[1]]
			extra[pair[0]][2] += int(opponent["pts"])
			extra[pair[0]][3] += int(opponent["gf"]) - int(opponent["ga"])
			extra[pair[0]][4] += int(opponent["gf"])
	var keys := {}
	for cid in cup.club_ids:
		var t: Dictionary = table[cid]
		var e: Array = extra[cid]
		var key := [int(t["pts"]), int(t["gf"]) - int(t["ga"]), int(t["gf"]), e[0], int(t["w"]), e[1]]
		if complete:
			key.append_array([e[2], e[3], e[4], -int(t.get("discipline", 0)), float(t.get("coef", 0.0))])
		keys[cid] = key
	var order := cup.club_ids.duplicate()
	order.sort_custom(func(a, b):
		for i in keys[a].size():
			if keys[a][i] != keys[b][i]:
				return keys[a][i] > keys[b][i]
		var na := String(table[a].get("name", str(a)))
		var nb := String(table[b].get("name", str(b)))
		return na < nb or (na == nb and a < b))
	return order


static func playoff_pairs(world: GameWorld, cup: Cup) -> Array:
	cup.league_rank = sorted_ids(cup)
	cup.byes = cup.league_rank.slice(0, 8)
	var pairs: Array = []
	for i in 4:
		var seeded := cup.league_rank.slice(8 + i * 2, 10 + i * 2)
		var rest := cup.league_rank.slice(22 - i * 2, 24 - i * 2)
		RngUtil.shuffle(world.rng, rest)
		for j in 2:
			pairs.append([rest[j], seeded[j]])
	return pairs


static func next_pairs(world: GameWorld, cup: Cup, round_index: int, winners: Array) -> Array:
	var pairs: Array = []
	if round_index == 1:
		var opponents := {}
		for block in 4:
			var pool := winners.slice((3 - block) * 2, (4 - block) * 2)
			RngUtil.shuffle(world.rng, pool)
			opponents[block * 2] = pool[0]
			opponents[block * 2 + 1] = pool[1]
		# Opposite halves for 1/2; top four occupy separate quarters of the bracket.
		for rank_index in [0, 7, 3, 4, 1, 6, 2, 5]:
			pairs.append([opponents[rank_index], cup.byes[rank_index]])
	else:
		# Bracket positions are inherited by winners; no new random draw.
		for i in range(0, winners.size(), 2):
			var a: int = winners[i]
			var b: int = winners[i + 1]
			var sa := _path_seed(cup, a, round_index - 1)
			var sb := _path_seed(cup, b, round_index - 1)
			pairs.append([b, a] if sa < sb else [a, b])
	return pairs


static func _path_seed(cup: Cup, club_id: int, through_round: int) -> int:
	var rank_index := cup.league_rank.find(club_id)
	for r in range(through_round, -1, -1):
		var tie := cup.tie_of(club_id, r)
		if not tie.is_empty():
			rank_index = mini(rank_index, mini(_path_seed(cup, int(tie["a"]), r - 1), _path_seed(cup, int(tie["b"]), r - 1)))
	return rank_index
