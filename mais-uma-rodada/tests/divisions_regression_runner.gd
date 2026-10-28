extends Node

const NEW_LEAGUES := ["ENG3", "ENG4", "NED2", "TUR2", "SCO2", "AUT2", "SUI2", "JPN2"]
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("DIVISIONS_FAIL: " + message)

func _ready() -> void:
	DatabaseManager.load_all()
	var w := GameWorld.new()
	w.world_seed = 261028
	w.rng.seed = w.world_seed
	w.year = DatabaseManager.start_year()
	Economy.ensure(w)
	ClubGenerator.build_all(w, w.rng, false)
	var keys := {}
	for c: Club in w.clubs:
		check(not keys.has(c.key), "unique club key " + c.key)
		keys[c.key] = true
	for id in NEW_LEAGUES + ["ENG2"]:
		check(w.clubs_in_league(id).size() == int(DatabaseManager.league_cfg(id)["teams"]), id + " authored membership")
	for kind in ["", "ano"]:
		w.stats["cal"] = kind
		w.season = SeasonManager.build_season(w)
		_calendar(w)
		_season(w)
	print("DIVISIONS calendar/playoffs checked")
	_migration(w)
	print("DIVISIONS failures=%d" % failures)
	get_tree().quit(0 if failures == 0 else 1)

func _calendar(w: GameWorld) -> void:
	var s := w.season
	var days := {}
	for e in s.calendar:
		check(not days.has(int(e["d"])), "unique calendar day " + str(e["d"]))
		days[int(e["d"])] = true
	check(int(s.calendar.back()["d"]) - int(s.calendar.front()["d"]) < 366, "season fits in one year " + str(s.calendar.back()["d"]))
	var weekly := 0
	var extra := 0
	for i in s.calendar.size():
		if s.is_weekend(i): weekly += 1
		if not bool(s.calendar[i].get("weekly", true)):
			extra += 1
			check(not s.is_weekend(i), "extra midweek does not age injuries or pay another weekly bill")
			check(SeasonManager._weekend_index(s, i) == weekly, "extra midweek does not shift FIFA week index")
	check(extra > 0 and weekly < 46, "46 fixtures do not create 46 weekly development ticks")
	for win in NationalTeamManager.windows(w):
		check(s.is_weekend(int(win["slot"])) and bool(s.calendar[int(win["slot"])].get("fifa", false)), "FIFA window keeps the original pause marker")
	for id in ["ENG2", "ENG3", "ENG4"]:
		var l := w.league(id)
		check(l.regular_rounds == 46, id + " has 46 regular rounds")
		var seen := {}
		for rr in l.regular_rounds:
			check(l.rounds[rr].size() == 12, id + " twelve matches per round")
			for f: Fixture in l.rounds[rr]:
				var key := "%d:%d" % [f.home, f.away]
				check(not seen.has(key), id + " unique home/away pair")
				seen[key] = true
		check(seen.size() == 552, id + " complete home/away schedule")
	for id in NEW_LEAGUES + ["ENG2"]:
		var l := w.league(id)
		check(l.phase_slots.size() == LeagueFormat.extra_rounds(l.cfg(), l.club_ids.size()), id + " sufficient phase dates")
		for slot in l.phase_slots:
			check(int(slot) > int(l.round_slots.back()), id + " playoff after regular season")
	for id in ["NED2", "AUT2"]:
		for cid in w.league(id).club_ids:
			var c := w.club(cid)
			if c.promotion_eligible: continue
			check(not LeagueFormat.promotion_candidates(w, [cid]).has(cid), "reserve blocked from promotion")
			var restored := Club.from_dict(c.to_dict())
			check(not restored.promotion_eligible and not restored.domestic_cup_eligible, "eligibility survives save")
			for cup: Cup in s.cups.values():
				if CupManager.is_domestic(cup.id): check(not cup.club_ids.has(cid), "reserve outside domestic cups")
	check(Club.from_dict({}).promotion_eligible, "old saves eligible by default")

func _season(w: GameWorld) -> void:
	var s := w.season
	for slot in s.calendar.size():
		s.day = slot
		var occupied := {}
		for f: Fixture in s.fixtures_at(slot):
			for cid in [f.home, f.away]:
				check(not occupied.has(cid), "no club plays twice on slot " + str(slot) + " " + w.club(cid).key)
				occupied[cid] = true
			f.hg = 1; f.ag = 1; f.played = true
			var l := w.league(f.comp)
			if l != null and f.stage == Fixture.STAGE_LEAGUE:
				CompetitionManager.apply_result(l, f)
		for l: League in s.leagues.values(): LeagueFormat.after_slot(w, l)
		for l: League in s.leagues.values(): LeagueFormat.barrage_after_slot(w, l)
		CupManager.after_slot(w, slot)
	for id in NEW_LEAGUES + ["ENG2"]:
		var l := w.league(id)
		for round_games in l.rounds:
			for f: Fixture in round_games: check(f.played, id + " no stranded fixture")
		if LeagueFormat.kind(l) == "promo": check(int(l.po.get("champ", -1)) >= 0, id + " playoffs finish")
		var promoted := LeagueFormat.promoted(l, LeagueFormat.sorted_ids(l), l.promoted_count(), w)
		for cid in promoted: check(w.club(cid).promotion_eligible, id + " only eligible promotions")
		var upper := LeagueFormat.barrage_upper(w, l)
		var extra := 1 if upper != null and LeagueFormat.barrage_relegated(upper) >= 0 else 0
		check(promoted.size() == l.promoted_count() + extra, id + " correct promotion count")
	var jp := w.league("JPN2")
	check(int(jp.po["champ"]) == int(jp.po["seeds"][0]), "Japanese draws favor best seed")
	for rr in range(jp.regular_rounds, jp.rounds.size()):
		for f: Fixture in jp.rounds[rr]:
			check(not LeagueFormat.requires_tiebreak(w, f), "Japanese playoff no extra time or penalties")
			check(int(TieStakes.of(w, f)["w"]) == LeagueFormat.draw_advantage_winner(w, f), "board recognizes advancement on drawn playoff")
			check(FootballMemory._tie_winner(w, f) == LeagueFormat.draw_advantage_winner(w, f), "history recognizes advancement on drawn playoff")
	var tr := w.league("TUR2")
	var seed := int(tr.po["seeds"][0])
	var played := 0
	for rr in range(tr.regular_rounds, tr.rounds.size()):
		for f: Fixture in tr.rounds[rr]:
			if f.involves(seed):
				played += 1
				check(f.round == 2, "Turkish third place enters final")
	check(played == 1, "Turkish bye preserved through two rounds")
	for id in ["NED1", "SCO1", "SUI1"]:
		var bar := LeagueFormat.barrage(w.league(id))
		check(int(bar.get("w", -1)) >= 0 and int(bar.get("legs", 0)) == 2, id + " full two-leg relegation playoff")

func _migration(fresh: GameWorld) -> void:
	var old := GameWorld.new()
	old.world_seed = 1234; old.year = 2029; old.rng.seed = 987
	Economy.ensure(old)
	var before_keys: Array = []
	for c: Club in fresh.clubs:
		if NEW_LEAGUES.has(c.league_id) or c.key.begins_with("ENG_D2_"): continue
		var copy := Club.from_dict(c.to_dict())
		copy.id = old.clubs.size()
		old.clubs.append(copy)
		before_keys.append(copy.key)
	old.season = SeasonManager.build_season(old)
	check(not SeasonManager.active_division(old, "ENG3"), "no relegation into absent legacy division")
	var previous_fixture: Fixture = old.league("ENG2").rounds[0][0]
	previous_fixture.hg = 4; previous_fixture.played = true
	var old_rng := old.rng.state
	var added := LeagueExpansion.apply(old)
	check(added.size() == 9, "eight new leagues plus partial Championship expanded")
	for id in NEW_LEAGUES + ["ENG2"]:
		check(old.clubs_in_league(id).size() == int(DatabaseManager.league_cfg(id)["teams"]), id + " legacy membership complete")
	for i in before_keys.size(): check(old.club(i).key == before_keys[i], "legacy club IDs stable")
	check(previous_fixture.hg == 4 and previous_fixture.played, "legacy results preserved")
	check(old.rng.state == old_rng, "career RNG unaffected by migration")
	check(LeagueExpansion.apply(old).is_empty(), "migration is idempotent")
	check(old.clubs.size() == fresh.clubs.size(), "no duplicate clubs after migration")
	var c1 := old.clubs_in_league("ENG1")[0] as Club
	var c2 := old.clubs_in_league("ENG2")[0] as Club
	c1.league_id = "ENG2"; c2.league_id = "ENG1"; old.reset_indexes()
	check(LeagueExpansion.apply(old).is_empty(), "career promotion never duplicates authored clubs")
