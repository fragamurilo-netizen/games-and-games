extends Node
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("CAREER_FAIL: " + message)

func _ready() -> void:
	var started := Time.get_ticks_msec()
	_money()
	_tenure()
	_nationalities()
	for id in ["UEL", "UECL"]:
		_europe(id)
	_nations()
	print("CAREER_EXPANSION failures=%d time_ms=%d" % [failures, Time.get_ticks_msec() - started])
	get_tree().quit(0 if failures == 0 else 1)

func _money() -> void:
	for pair in [["1250000",1250000],["1.250.000",1250000],["1,250,000",1250000],[" 100 ",100],["0",0]]:
		check(MoneyInput.parse(pair[0], 1.0) == pair[1], "whole currency " + pair[0])
	for bad in ["", "-500", "1e9", "NaN", "1,5", "1.25", "1.23.000", "1,234.567", "100000000001", "abc"]:
		check(MoneyInput.parse(bad, 1.0) == -1, "reject invalid money " + bad)
	check(MoneyInput.parse("59091", Fmt.EUR_TO_BRL) == 10000, "BRL converted to base economy")
	check(MoneyInput.parse("299", 1.0, 300) == -1, "minimum wage")

func _nationalities() -> void:
	var w := GameWorld.new()
	w.year = 2026
	var c := Club.new()
	c.id = 0; c.nation = "ESP"; c.city = "Madrid"
	w.clubs.append(c)
	var p := Player.new()
	p.id = 1; p.nationality = "CMR"; p.hometown = "São Paulo"; p.birth_year = 2000
	p.club_id = 0; p.joined_year = 2024; p.face_seed = 88
	w.players[p.id] = p
	var rng := RandomNumberGenerator.new()
	rng.seed = 29
	for i in 500:
		check(NationalityManager.city_in(PlayerGenerator.pick_hometown(rng,"CMR","São Paulo"),"CMR"), "foreign city cannot become hometown")
	NationalityManager.ensure(w, p)
	check(NationalityManager.city_in(p.hometown,"CMR"), "legacy foreign birthplace repaired")
	check(NationalityManager.passports(p) == ["CMR"], "migration does not invent citizenship")
	var before := p.origin.duplicate(true)
	NationalityManager.ensure(w, p)
	check(p.origin == before, "migration idempotent")
	p.nationality = "BRA"; p.origin.clear(); p.hometown = "São Paulo"
	NationalityManager.ensure(w, p)
	check(NationalityManager.naturalize(w,p,false), "Brazilian obtains Spanish passport after two career seasons")
	check(not SquadRules.is_foreign(p,c,"non_eu"), "new passport applies to registration")
	check(not NationalityManager.eligible(w,p,"ESP"), "citizenship alone does not grant sporting eligibility")
	w.year = 2029
	NationalityManager.season_start(w)
	check(NationalityManager.eligible(w,p,"ESP"), "five-year sporting link")
	check(NationalityManager.choose(w,p,"ESP"), "eligible uncapped player changes association")
	check(p.nationality == "BRA" and NationalityManager.birth_country(p) == "BRA" and p.face_seed == 88, "selection never recolors or rewrites birthplace")
	check(not NationalityManager.naturalize(w,p,false), "no duplicate naturalization")
	var loan_club := Club.new()
	loan_club.id = 1; loan_club.nation = "FRA"
	w.clubs.append(loan_club)
	p.club_id = 1
	NationalityManager.sync_residence(w,p,true)
	w.year = 2030; p.club_id = 0
	NationalityManager.sync_residence(w,p,true)
	check(int(p.origin["residence"]["since"]) == 2030, "foreign loan resets continuous residence")
	var restored := Player.from_dict(JSON.parse_string(JSON.stringify(p.to_dict())))
	check(NationalityManager.team(restored) == "ESP" and NationalityManager.birth_country(restored) == "BRA" and NationalityManager.passports(restored).has("ESP") and int(restored.origin["residence"]["since"]) == 2030, "origin data survives JSON save")
	# Real senior-change constraints, including friendly caps and passports held at first cap.
	p.origin["team"] = "BRA"; p.origin["switched"] = false
	p.origin["passports"]["ESP"]["since"] = 2000
	p.origin["records"] = {"BRA":{"apps":3,"official":2,"last_year":2027,"last_official_age":20,"first_official":2025}}
	check(NationalityManager.eligible(w,p,"ESP"), "three-cap under-21 exception after three years")
	p.origin["records"]["BRA"]["apps"] = 4
	check(not NationalityManager.eligible(w,p,"ESP"), "fourth senior appearance blocks official switch")
	p.origin["records"]["BRA"]["apps"] = 3
	p.origin["records"]["BRA"]["finals"] = true
	check(not NationalityManager.eligible(w,p,"ESP"), "World Cup or confederation finals blocks switch")
	p.origin["records"]["BRA"]["finals"] = false
	p.origin["passports"]["ESP"]["since"] = 2026
	check(not NationalityManager.eligible(w,p,"ESP"), "passport after first official appearance cannot use exception")
	p.origin["records"]["BRA"]["official"] = 0
	check(NationalityManager.eligible(w,p,"ESP"), "friendlies alone do not tie nationality")

func _tenure() -> void:
	var p := Player.new()
	p.club_id = 1
	p.joined_year = 2020
	p.spells = [{"c":1,"from":2020,"to":2023},{"c":2,"from":2023,"to":2025},{"c":1,"from":2025,"to":0}]
	check(p.club_tenure(2026).contains("2 temporadas"), "return uses current spell")
	p.club_id = 3
	p.spells.append({"c":3,"from":2026,"to":0,"k":"e"})
	check(p.club_tenure(2026).contains("1ª temporada"), "loan uses current spell")
	p.club_id = -1
	check(p.club_tenure(2026) == "Sem clube", "free agent tenure")

func _europe(id: String) -> void:
	var w := GameWorld.new()
	for nation in CupManager.cfg(id)["alloc"]:
		for i in int(CupManager.cfg(id)["alloc"][nation]):
			var c := Club.new()
			c.id = w.clubs.size()
			c.nation = nation
			c.name = "%s%d" % [nation, i]
			c.short_name = c.name
			w.clubs.append(c)
	check(w.clubs.size() == 36, id + " allocation 36")
	var rounds := 6 if id == "UECL" else 8
	for seed_value in 30:
		w.rng.seed = seed_value + 20260929
		w.season = SeasonState.new()
		w.season.calendar = SeasonManager.build_calendar(2026)
		for c: Club in w.clubs:
			c.reputation = w.rng.randf_range(20, 95)
		var cup := Cup.new()
		cup.id = id
		cup.club_ids = range(36)
		check(LeaguePhase.setup(w, w.season, cup), id + " draw")
		w.season.cups[id] = cup
		check(cup.fixtures.size() == rounds * 18, id + " match count")
		for cid in cup.club_ids:
			var pots := {}
			var associations := {}
			var opponents := {}
			var home := 0
			var pair_home := [0, 0, 0]
			for f: Fixture in cup.fixtures:
				if not f.involves(cid): continue
				var other := f.opponent_of(cid)
				check(not opponents.has(other), id + " unique opponent")
				opponents[other] = true
				var pot := cup.club_ids.find(other) / (6 if id == "UECL" else 9)
				pots[pot] = int(pots.get(pot, 0)) + 1
				var nation := w.club(other).nation
				check(nation != w.club(cid).nation, id + " association restriction")
				associations[nation] = int(associations.get(nation, 0)) + 1
				if f.home == cid:
					home += 1
					if id == "UECL": pair_home[pot / 2] += 1
			check(home == rounds / 2 and opponents.size() == rounds, id + " home/away balance")
			check(pots.size() == (6 if id == "UECL" else 4), id + " all pots")
			for n in pots.values(): check(n == (1 if id == "UECL" else 2), id + " opponents per pot")
			for n in associations.values(): check(n <= 2, id + " association cap")
			if id == "UECL": check(pair_home == [1,1,1], "Conference paired-pot home balance")
		if seed_value != 0: continue
		for slot in w.season.calendar.size():
			for f: Fixture in cup.fixtures_at(slot):
				f.hg = 2; f.ag = 1; f.played = true
				if f.stage == Fixture.STAGE_KO and CupManager.is_deciding_leg(w, f):
					var agg := CupManager.aggregate_before(w, f)
					if f.hg + agg[0] == f.ag + agg[1]: f.pen_h = 5; f.pen_a = 4
				CupManager.apply_result(w, f)
			CupManager.after_slot(w, slot)
		check(cup.finished and cup.champion >= 0, id + " complete tournament")
		check(cup.fixtures.size() == rounds * 18 + 45, id + " knockout total")
		var saved := Cup.from_dict(JSON.parse_string(JSON.stringify(cup.to_dict())))
		check(saved.league_phase and LeaguePhase.matchdays(saved) == rounds, id + " saved format")
	print("EUROPE_OK ", id, " 30 draws, full season")

func _nations() -> void:
	var w := GameWorld.new()
	w.year = 2026
	w.world_seed = 20260929
	w.season = SeasonState.new()
	NationalLeagues.start(w)
	var env := NationalTeamManager._make_env(w, 123, 30)
	for window in 3:
		NationalLeagues.play_window(w, env)
	for id in NationalLeagues.IDS:
		var st: Dictionary = NationalLeagues.states(w)[id]
		check(st["teams"].size() == (54 if id == "UNL" else 41), id + " member count")
		var unique := {}
		for team in st["teams"]:
			check(not unique.has(team), id + " membership unique")
			unique[team] = true
		for g in st["groups"]:
			var expected := 4 if (id == "CNL" and g["level"] in [0,2]) or (id == "UNL" and g["level"] == 3) else 6
			for row in g["table"].values(): check(int(row["pl"]) == expected, id + " group matches")
		var rec := NationalLeagues.finish(w, id, 2027)
		check(not rec.is_empty() and rec["champion"] != rec["runner_up"], id + " champion")
		var divisions: Array = NationalLeagues.states(w)[id]["next_divisions"]
		for i in divisions.size():
			check(divisions[i].size() == ([16,16,16,6][i] if id == "UNL" else [16,16,9][i]), id + " division sizes after promotion")
		check(NationalLeagues.finish(w, id, 2027).is_empty(), id + " settlement idempotent")
	var gold := NationalTeamManager.participants(w, "GOLD", 2027, env)
	check(gold.size() == 16 and gold.has("KSA"), "Gold Cup 15 qualified + Saudi guest")
	var unique_gold := {}
	for n in gold: unique_gold[n] = true
	check(unique_gold.size() == 16, "no duplicate Gold Cup qualification")
	for spec in [["WC",2030,48,12],["EURO",2028,24,6],["AFCON",2027,24,6],["ASIAN",2027,24,6],["CA",2028,16,4],["GOLD",2027,16,4],["OFC",2028,8,2]]:
		var rec := NationalTeamManager._play_tournament(w, spec[0], spec[1])
		check(rec["teams"].size() == spec[2] and rec["groups"].size() == spec[3], spec[0] + " finals format")
		var allowed: Array = NationalTeamManager.tcfg(spec[0])["entry"].keys() + NationalTeamManager.tcfg(spec[0]).get("guests", {}).keys()
		for code in rec["teams"]:
			check(allowed.has(DatabaseManager.nation(code)["confed"]) or (spec[0] == "GOLD" and code == "KSA"), spec[0] + " eligible continent " + code)
		for g in rec["groups"]:
			check(g["order"].size() == 4, spec[0] + " four per group")
		if spec[0] == "WC":
			for host in ["ESP","POR","MAR","ARG","PAR","URU"]: check(rec["teams"].has(host), "2030 host qualified " + host)
		print("NATIONAL_OK ", spec[0], " ", rec["teams"].size(), " teams")
	# Pure JSON is the representation persisted in career stats; reopen a cycle.
	w.stats = JSON.parse_string(JSON.stringify(w.stats))
	w.year = 2028
	NationalLeagues.start(w)
	check(NationalLeagues.states(w)["UNL"]["teams"].size() == 54, "next cycle after save")
