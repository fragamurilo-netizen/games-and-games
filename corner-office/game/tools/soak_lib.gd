extends RefCounted
## Biblioteca do soak de combate (Game Design Bible §21). Ver tools/soak_fights.gd.

static func overall(f: Fighter) -> float:
	var sum := 0.0
	var n := 0
	for group: String in ["striking", "grappling", "jiu_jitsu", "physical"]:
		for v in f.get(group).values():
			sum += float(v)
			n += 1
	return sum / maxf(1, n)


static func run(total: int, seed_base: int) -> Dictionary:
	var engine := FightEngine.new()
	var methods := {"m": {}, "f": {}}
	var fav_wins := 0
	var fav_games := 0
	var big_gap_wins := 0
	var big_gap_games := 0
	var close_wins := 0
	var close_games := 0
	var finish_rounds := {}
	var world: WorldState = null
	var pools := {}
	var orgs := ["org_crown", "org_ascend", "org_vale", "org_shinsei", "org_frontline", "org_iron", "org_pfl"]
	for i in total:
		if i % 200 == 0:
			world = WorldGenerator.generate(seed_base * 1000 + i, "regional_promoter")
			pools = {}
			for f: Fighter in world.fighters.values():
				if not pools.has(f.division):
					pools[f.division] = []
				pools[f.division].append(f)
		var divisions := pools.keys().filter(func(d): return pools[d].size() >= 2)
		var division: String = world.rng.pick(divisions)
		var pool: Array = pools[division]
		var a: Fighter = world.rng.pick(pool)
		var b: Fighter = a
		while b == a:
			b = world.rng.pick(pool)
		var ev := FightEvent.new()
		ev.id = world.new_id("soak_event")
		ev.organization_id = orgs[i % orgs.size()]
		world.add("events", ev)
		var fight := Fight.new()
		fight.id = world.new_id("soak_fight")
		fight.event_id = ev.id
		fight.fighter_a_id = a.id
		fight.fighter_b_id = b.id
		fight.division = division
		fight.rounds = 5 if i % 5 == 0 and ev.organization_id != "org_shinsei" else 3
		fight.status = "booked"
		engine.simulate(world, fight)
		var sex := "f" if a.sex == Fighter.Sex.FEMALE else "m"
		methods[sex][fight.method] = int(methods[sex].get(fight.method, 0)) + 1
		if fight.method in ["ko_tko", "submission"]:
			finish_rounds[fight.end_round] = int(finish_rounds.get(fight.end_round, 0)) + 1
		if not fight.winner_id.is_empty():
			var oa := overall(a)
			var ob := overall(b)
			var fav := a.id if oa >= ob else b.id
			fav_games += 1
			if fight.winner_id == fav:
				fav_wins += 1
			if absf(oa - ob) < 3.0:
				close_games += 1
				if fight.winner_id == fav:
					close_wins += 1
			if absf(oa - ob) >= 8.0:
				big_gap_games += 1
				if fight.winner_id == fav:
					big_gap_wins += 1
	var share := {}
	for sex: String in methods:
		var n := 0
		for v in methods[sex].values():
			n += int(v)
		share[sex] = {}
		for k: String in methods[sex]:
			share[sex][k] = snappedf(float(methods[sex][k]) / maxf(1, n), 0.001)
		share[sex]["n"] = n
	return {"share": share, "favorite_win_rate": snappedf(float(fav_wins) / maxf(1, fav_games), 0.001),
		"big_gap_favorite_win_rate": snappedf(float(big_gap_wins) / maxf(1, big_gap_games), 0.001), "big_gap_fights": big_gap_games,
		"close_favorite_win_rate": snappedf(float(close_wins) / maxf(1, close_games), 0.001), "close_fights": close_games,
		"finish_rounds": finish_rounds}
