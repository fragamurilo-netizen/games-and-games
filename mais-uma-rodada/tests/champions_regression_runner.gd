extends Node

var failures := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error("CHAMPIONS_FAIL: " + label)

func _ready() -> void:
	var start := Time.get_ticks_msec()
	var world := GameWorld.new()
	for nation in CupManager.cfg("UCL")["alloc"]:
		for i in int(CupManager.cfg("UCL")["alloc"][nation]):
			var club := Club.new()
			club.id = world.clubs.size()
			club.nation = nation
			club.name = "%s %d" % [nation, i]
			club.short_name = club.name
			world.clubs.append(club)
	check(world.clubs.size() == 36, "36 allocation slots")
	for kind in ["", "ano"]:
		world.season = SeasonState.new()
		world.season.calendar = SeasonManager.build_calendar(2026, kind)
		var codes := {}
		var dates := {}
		for e in world.season.calendar:
			if e["t"] != "W":
				check(not codes.has(e["t"]), "unique calendar code " + e["t"])
			codes[e["t"]] = true
			check(not dates.has(int(e["d"])), "no double date " + kind + str(e))
			dates[int(e["d"])] = true
		var last := -1
		for key in LeaguePhase.SLOTS + ["C9", "C10", "C11", "C12", "C14", "C15", "C16", "C17", "C13", "X1"]:
			var slot := world.season.slot_of(key)
			check(slot > last, "chronological phase " + kind + key)
			last = slot
		for seed_value in 20:
			world.rng.seed = seed_value + 29092026
			for club: Club in world.clubs:
				club.reputation = world.rng.randf_range(45, 95)
			var cup := Cup.new()
			cup.id = "UCL"
			cup.club_ids = range(36)
			var ok := LeaguePhase.setup(world, world.season, cup)
			check(ok, "valid draw " + str(seed_value))
			if not ok:
				continue
			check(cup.fixtures.size() == 144, "144 league games")
			for cid in cup.club_ids:
				var home: Array = []
				var away: Array = []
				var opponents := {}
				var nations := {}
				var slots := {}
				for f: Fixture in cup.fixtures:
					if not f.involves(cid):
						continue
					var opp := f.opponent_of(cid)
					var pot := cup.club_ids.find(opp) / 9
					(home if f.home == cid else away).append(pot)
					check(not opponents.has(opp), "distinct opponents")
					check(not slots.has(f.slot), "one match per date")
					opponents[opp] = true
					slots[f.slot] = true
					var nat := world.club(opp).nation
					check(nat != world.club(cid).nation, "no own-association opponent")
					nations[nat] = int(nations.get(nat, 0)) + 1
				home.sort()
				away.sort()
				check(home == [0, 1, 2, 3] and away == home, "two per pot, four home/four away")
				for count in nations.values():
					check(int(count) <= 2, "at most two from one association")
			if seed_value == 0:
				_play_season(world, cup)
	_test_tiebreakers()
	_test_discipline(world)
	_test_legacy(world)
	print("CHAMPIONS_REGRESSION failures=%d, 40 draws, 2 full cups, %d ms" % [failures, Time.get_ticks_msec() - start])
	get_tree().quit(0 if failures == 0 else 1)

func _play_season(world: GameWorld, cup: Cup) -> void:
	world.season.cups = {"UCL": cup}
	for slot in world.season.calendar.size():
		var used := {}
		for f: Fixture in cup.fixtures_at(slot):
			check(not used.has(f.home) and not used.has(f.away), "knockout date clash")
			used[f.home] = true
			used[f.away] = true
			f.hg = (f.home + slot) % 4
			f.ag = (f.away + slot) % 3
			f.played = true
			if f.stage == Fixture.STAGE_KO and CupManager.is_deciding_leg(world, f):
				var agg := CupManager.aggregate_before(world, f)
				if f.hg + agg[0] == f.ag + agg[1]:
					f.pen_h = 5
					f.pen_a = 4
			CupManager.apply_result(world, f)
		CupManager.after_slot(world, slot)
		if world.season.slot_type(slot) == "C8":
			check(cup.ties_of_round(0).size() == 8 and cup.byes.size() == 8, "8 byes and 8 playoff ties")
			for i in range(24, 36):
				check(not cup.is_alive(cup.league_rank[i]), "bottom 12 eliminated")
			for t in cup.ties_of_round(0):
				var a := cup.league_rank.find(t["a"])
				var b := cup.league_rank.find(t["b"])
				check(a >= 16 and a < 24 and b >= 8 and b < 16, "seeded playoff home advantage")
			# Save/load before playoffs preserves new format and calendar references.
			cup = Cup.from_dict(JSON.parse_string(JSON.stringify(cup.to_dict())))
			world.season.cups["UCL"] = cup
			check(cup.league_phase and cup.league_rank.size() == 36, "save roundtrip")
	check(cup.finished and cup.champion >= 0, "champion crowned")
	check(cup.fixtures.size() == 189, "189 matches including playoffs")
	for r in 5:
		check(cup.ties_of_round(r).size() == [8, 8, 4, 2, 1][r], "knockout field " + str(r))
	check(cup.fixtures[-1].neutral, "neutral final")
	var title_count := world.club(cup.champion).title_count("C:UCL")
	CupManager.after_slot(world, world.season.slot_of("C13"))
	check(world.club(cup.champion).title_count("C:UCL") == title_count, "no repeated title/prize")

func _test_tiebreakers() -> void:
	var cup := Cup.new()
	cup.league_phase = true
	cup.club_ids = [0, 1]
	var a := CompetitionManager.empty_row()
	var b := CompetitionManager.empty_row()
	a.merge({"pts": 6, "w": 2, "gf": 3, "ga": 3}, true)
	b.merge({"pts": 6, "w": 1, "gf": 4, "ga": 1}, true)
	cup.groups = [{"clubs": [0, 1], "table": {0: a, 1: b}}]
	check(LeaguePhase.sorted_ids(cup)[0] == 1, "goal difference before wins")
	a.merge({"pts": 6, "w": 2, "gf": 4, "ga": 1, "discipline": 0, "coef": 90}, true)
	b.merge({"pts": 6, "w": 2, "gf": 4, "ga": 1, "discipline": 0, "coef": 80}, true)
	var f := Fixture.new()
	f.stage = Fixture.STAGE_GROUP
	f.home = 0
	f.away = 1
	f.hg = 2
	f.ag = 1
	f.played = true
	cup.fixtures = [f]
	check(LeaguePhase.sorted_ids(cup)[0] == 1, "away goals before coefficient")
	f.ag = 0
	a["discipline"] = 4
	b["discipline"] = 3
	check(LeaguePhase.sorted_ids(cup)[0] == 1, "discipline before coefficient")
	a["discipline"] = 3
	check(LeaguePhase.sorted_ids(cup)[0] == 0, "coefficient after equal discipline")
	f.played = false
	var live := {0: a.duplicate(), 1: b.duplicate()}
	check(LeaguePhase.sorted_ids(cup, live, {f: [0, 1]})[0] == 1, "live away goal tie-breaker")
	check(not f.played and f.ag == 0, "projection does not mutate fixture")

func _test_discipline(world: GameWorld) -> void:
	var cup := Cup.new()
	cup.id = "UCL"
	cup.league_phase = true
	cup.club_ids = [0, 1]
	cup.groups = [{"clubs": [0, 1], "table": {0: CompetitionManager.empty_row(), 1: CompetitionManager.empty_row()}}]
	world.season.cups = {"UCL": cup}
	var f := Fixture.new()
	f.comp = "UCL"
	f.stage = Fixture.STAGE_GROUP
	f.round = 1
	f.home = 0
	f.away = 1
	var second_yellow: Array = []
	second_yellow.resize(QuickMatch.L_RED + 1)
	second_yellow.fill(0)
	second_yellow[QuickMatch.L_Y] = 2
	second_yellow[QuickMatch.L_RED] = true
	var direct_red := second_yellow.duplicate()
	direct_red[QuickMatch.L_Y] = 1
	CupManager.apply_result(world, f, {"lines": [[second_yellow, direct_red], []], "yc": [3, 1], "rc": [2, 0]})
	check(cup.groups[0]["table"][0]["discipline"] == 7, "second yellow red = 3; yellow plus direct red = 4")
	check(cup.groups[0]["table"][1]["discipline"] == 1, "aggregate card fallback")

func _test_legacy(world: GameWorld) -> void:
	var cup := Cup.new()
	cup.id = "UCL"
	cup.club_ids = range(32)
	cup.round_names = ["Oitavas de final", "Quartas de final", "Semifinal", "Final"]
	CupManager._draw_groups(world, world.season, cup, 8)
	var data := cup.to_dict()
	data.erase("lp")
	data.erase("lr")
	var old := Cup.from_dict(data)
	check(not old.league_phase and old.groups.size() == 8 and old.fixtures.size() == 96, "legacy save stays in its original format")
	check(CupManager._round_slots(old, 0) == ["C7", "C8"], "legacy knockout dates")
