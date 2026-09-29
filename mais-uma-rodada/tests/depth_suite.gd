extends RefCounted
## Isolated validation; never reads or overwrites a player save.
var failures := 0
var checks := 0
var metrics := {}
var tree: SceneTree
var w: GameWorld

func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("DEPTH_FAIL: "+text)

func run(host: SceneTree) -> int:
	tree = host
	_scan("res://scripts")
	print("DEPTH_COMPILE_OK")
	DatabaseManager.load_all()
	_test_pure_tactics()
	_test_calendar()
	_test_playstyles()
	print("DEPTH_PURE_TESTS_DONE failures=",failures)
	var begin := Time.get_ticks_msec()
	print("DEPTH_WORLD_START")
	w = WorldGenerator.generate(19031911,"padrao")
	metrics["world_ms"] = Time.get_ticks_msec()-begin
	metrics["clubs"] = w.clubs.size()
	metrics["players"] = w.players.size()
	print("DEPTH_WORLD_READY ",metrics)
	var ids := w.clubs_in_league("BRA1")
	check(ids.size()>=16,"Brazil clubs available")
	w.user_club_id = ids[0].id
	w.manager_name = "Teste Profundidade"
	w.manager_stats["games"] = 600
	w.difficulty = 2
	_test_talent()
	_test_native_matches()
	_test_bulk_matches()
	print("DEPTH_MATCH_TESTS_DONE failures=",failures)
	_test_international()
	print("DEPTH_INTERNATIONAL_DONE failures=",failures)
	_test_youth()
	print("DEPTH_YOUTH_DONE failures=",failures)
	_test_save_roundtrip()
	await _test_ui()
	metrics["checks"] = checks
	metrics["failures"] = failures
	metrics["elapsed_ms"] = Time.get_ticks_msec()-begin
	var out := OS.get_environment("DEPTH_REPORT")
	if out == "": out = "user://depth-validation.json"
	var file := FileAccess.open(out,FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(metrics,"  "))
		file.close()
	print("DEPTH_METRICS ",JSON.stringify(metrics))
	if failures == 0: print("DEPTH_REGRESSION_OK")
	return 0 if failures==0 else 1

func _scan(path: String) -> void:
	var d := DirAccess.open(path)
	for name in d.get_files():
		if not name.ends_with(".gd"): continue
		var script = load(path.path_join(name))
		check(script != null and script.can_instantiate(),"compile "+path.path_join(name))
	for name in d.get_directories(): _scan(path.path_join(name))

func _test_pure_tactics() -> void:
	var a := {"style":8,"mentality":2,"line":1,"pressing":1,"width":1,"passing":1,"tech":75.0,"decision":72.0,"condition":94.0,"stamina":78.0,"cohesion":70.0,"pace_att":88.0,"pace_def":78.0,"aerial_att":69.0,"aerial_def":72.0,"mid":4.0}
	var b := a.duplicate()
	b["line"]=2;b["pace_def"]=55.0
	var x := TacticalMatchup.edges(a,b)
	var y := TacticalMatchup.edges(b,a)
	check(is_equal_approx(x["rate_a"],y["rate_b"]) and is_equal_approx(x["poss"],-y["poss"]),"tactical model symmetric")
	b["line"]=0;b["mentality"]=1
	check(float(x["rate_a"])>float(TacticalMatchup.edges(a,b)["rate_a"]),"fast runners exploit space, not a deep block")
	var press := a.duplicate()
	press["style"]=7;press["pressing"]=2
	var fresh := TacticalMatchup.edges(press,a)
	press["condition"]=40.0
	var tired := TacticalMatchup.edges(press,a)
	check(float(tired["rate_a"])<float(fresh["rate_a"]),"tired pressing loses effectiveness")
	check(float(tired["rate_b"])>float(fresh["rate_b"]),"tired pressing exposes space")
	for style in DatabaseManager.tactics()["styles"].size():
		a["style"]=style
		for other in DatabaseManager.tactics()["styles"].size():
			b["style"]=other
			x=TacticalMatchup.edges(a,b)
			check(float(x["rate_a"])>=0.76 and float(x["rate_a"])<=1.28 and absf(float(x["poss"]))<=0.09,"bounded style interaction")

func _test_playstyles() -> void:
	check(DatabaseManager.tactics()["styles"].size()==13,"13 selectable team styles")
	var added := 0
	for role in PlayStyle.EXTRA_ROLES:
		added+=PlayStyle.EXTRA_ROLES[role].size()
		for p in PlayStyle.EXTRA_ROLES[role]:
			check(PlayStyle.role_options(role).has(p),"new playstyle reachable "+p["k"])
			for key in ["t","o"]:
				for value in p.get("fx",{}).get(key,{}).values(): check(absf(value)<=0.15,"playstyle uses additive deltas "+p["k"])
	check(added==16,"16 additional individual playstyles")

func _test_calendar() -> void:
	var wins := InternationalCalendar.windows(2026)
	check(wins[2]["start"]=="2026-09-21" and wins[2]["end"]=="2026-10-06" and wins[2]["max_matches"]==4,"2026 four-match window")
	check(InternationalCalendar.windows(2028)[1]["start"]=="2028-05-29","2028 early June window")
	check(not wins[0]["projected"] and InternationalCalendar.windows(2031)[0]["projected"],"future calendars labelled projections")
	var sample: Array = []
	for i in 90: sample.append({"t":"W" if i%2==0 else "M","d":i*3+5})
	var fixed := InternationalCalendar.reserve(sample,2026)
	var count := 0
	var previous := -1
	for item in fixed:
		check(int(item["d"])>=previous,"calendar chronological")
		previous=int(item["d"])
		if item["t"] in ["I","IA"]:continue
		count+=1
		var date := InternationalCalendar.stamp("2026-01-01")+int(item["d"])*86400
		for win in wins: check(date<int(win["a"]) or date>int(win["b"]),"club date outside international window")
	check(count==sample.size(),"calendar preserves club slot count")

func _test_talent() -> void:
	var bad := 0
	var bad_potential:=0
	for p: Player in w.players.values():
		for v in p.attrs:
			if v<1 or v>99:bad+=1
		if p.potential<p.overall:bad_potential+=1
	check(bad==0,"generated attributes within 1..99")
	check(bad_potential==0,"potential not below current rating")
	var p: Player=w.squad(w.user_club())[5]
	var pot:=p.potential
	p.potential=p.overall
	var low:=Valuation.market_value(p,w.year)
	var projection:=TalentAssessment.projection(p,w.year)
	p.potential=99
	check(Valuation.market_value(p,w.year)==low,"market cannot read hidden ceiling")
	check(TalentAssessment.projection(p,w.year)==projection,"scout projection cannot read hidden ceiling")
	p.potential=pot
	var injury:=p.injury_weeks
	p.injury_weeks=12
	check(Valuation.market_value(p,w.year)<low,"long injury reduces valuation")
	p.injury_weeks=injury
	var development:=TalentAssessment.growth_environment(p,90)
	p.injury_weeks=8
	check(TalentAssessment.growth_environment(p,90)<development,"injury limits normal development")
	p.injury_weeks=injury

func _sim(a: Club,b: Club,seed_value: int,detail: bool=false,ha: TeamSheet=null,hb: TeamSheet=null) -> MatchSimulation:
	var asheet: TeamSheet = ha if ha!=null else ClubAI.auto_sheet(w,a,"")
	var bsheet: TeamSheet = hb if hb!=null else ClubAI.auto_sheet(w,b,"")
	var sim:=MatchSimulation.new()
	sim.setup(w,a,b,asheet,bsheet,{"neutral":true,"competition":"F","attendance":0},seed_value,detail)
	return sim

func _test_native_matches() -> void:
	var clubs:=w.clubs_in_league("BRA1")
	var a: Club=clubs[0]
	var b: Club=clubs[1]
	var sa:=ClubAI.auto_sheet(w,a,"")
	var sb:=ClubAI.auto_sheet(w,b,"")
	for seed_value in range(400,420):
		var x:=_sim(a,b,seed_value,false,sa.duplicate_sheet(),sb.duplicate_sheet())
		var y:=_sim(a,b,seed_value,true,sa.duplicate_sheet(),sb.duplicate_sheet())
		x.run_to_end();y.run_to_end()
		check(x.score==y.score and x.rng.state==y.rng.state,"live/instant same result and RNG "+str(seed_value))
		check(x.finished and y.finished,"match termination")
	var original_diff:=w.difficulty
	var baseline: Array = []
	for diff in 3:
		w.difficulty=diff
		var s:=_sim(a,b,999,false,sa.duplicate_sheet(),sb.duplicate_sheet())
		var v: Array=[s.teams[0].day_f,s.teams[1].day_f]
		if baseline.is_empty():baseline=v
		check(v==baseline,"difficulty does not inflate day strength")
		s.score=[0,3];s.minute=80;s.call("_game_state")
		check(s.teams[0].g_rate==1.0 and s.teams[0].g_quality==1.0 and s.teams[1].g_rate==1.0,"no score rubberbanding")
	w.difficulty=original_diff
	var goals:=0
	var draws:=0
	var decisions:=0
	var different:={}
	var n:=160
	var t0:=Time.get_ticks_msec()
	for i in n:
		var ha:=sa.duplicate_sheet()
		var hb:=sb.duplicate_sheet()
		ha.style=i%13;hb.style=(i*7+3)%13
		var s:=_sim(a,b,31000+i,false,ha,hb)
		s.run_to_end()
		check(s.finished,"sample match finishes")
		goals+=s.score[0]+s.score[1]
		if s.score[0]==s.score[1]:draws+=1
		decisions+=s.coach_log.size()
		different[str(s.score)]=true
	metrics["mixed_styles_sample"]={"n":n,"goals_per_match":float(goals)/n,"draw_rate":float(draws)/n,"scorelines":different.size(),"ai_decisions":decisions,"elapsed_ms":Time.get_ticks_msec()-t0}
	check(different.size()>8,"outcomes vary across seeds and tactics")
	check(decisions>0,"opponent makes explicit tactical decisions")
	check(float(goals)/n>1.0 and float(goals)/n<5.0,"broad scoring sanity, not claimed empirical calibration")

func _test_international() -> void:
	var club:=w.user_club_id
	check(InternationalCareer.apply(w,"BRA")=="","qualified coach can take national job")
	check(w.user_club_id==club,"club job preserved")
	var data:=InternationalCareer.data(w)
	var roster: Array=data["roster"]
	check(InternationalCareer.validate(w,"BRA",roster)=="","automatic 26-player squad valid")
	var dup:=roster.duplicate();dup[1]=dup[0]
	check(InternationalCareer.validate(w,"BRA",dup)!="","duplicate squad rejected")
	InternationalCareer.set_plan(w,"style",12)
	var pool:=InternationalCareer.eligible(w,"BRA")
	var selected:=InternationalCareer.squad_for(w,"BRA",pool)
	check(InternationalCareer.sheet(w,"BRA",selected).starters.size()==11,"11 national starters")
	var window: Dictionary=InternationalCalendar.windows(w.year)[2]
	InternationalCareer.announce(w,window)
	data["active_window"]=window["id"]
	var env:=NationalTeamManager._make_env(w,7741,30.0)
	var stats_before:={}
	var caps_before:={}
	for p: Player in env.squad("BRA"):
		stats_before[p.id]=p.stats.duplicate()
		caps_before[p.id]=NationalTeamManager.caps_of(w,p.id)[0]
	var result:=NationalTeamManager.play(env,"BRA","ARG",false,true)
	check(result.get("engine","")=="MatchSimulation","managed international uses full match engine")
	check(result["w"]!="","knockout winner resolved")
	var appeared:=0
	for p: Player in env.squad("BRA"):
		check(p.stats==stats_before[p.id],"international does not alter club stats")
		if NationalTeamManager.caps_of(w,p.id)[0]>caps_before[p.id]:appeared+=1
	check(appeared>=11,"international caps credited")
	check(data["games"]==1 and data["results"].size()==1,"coach result history recorded")
	var results:=NationalTeamManager.play_window(w,window)
	for count in data["last_window_counts"].values():check(int(count)<=int(window["max_matches"]),"per-nation FIFA match allowance")
	check(results.size()>20,"qualifying/friendly window produces games")
	check(InternationalCareer.kit("BRA")["c1"]!=InternationalCareer.kit("BRA","away")["c1"],"distinct national home/away kits")
	# Injury replacement keeps the published squad eligible and restores three keepers.
	var selected_keeper: Player = env.squad("BRA").filter(func(p): return p.position == Pos.GK)[0]
	var old_injury := selected_keeper.injury_weeks
	selected_keeper.injury_weeks = 8
	var replacements := InternationalCareer.squad_for(w,"BRA",InternationalCareer.eligible(w,"BRA"))
	check(not replacements.has(selected_keeper),"injured called-up player replaced")
	check(replacements.size()==26 and replacements.filter(func(p): return p.position==Pos.GK).size()==3,"replacement preserves squad and goalkeeper quota")
	check(not InternationalCareer.sheet(w,"BRA",replacements).starters.has(selected_keeper.id),"injured player cannot start another international")
	selected_keeper.injury_weeks = old_injury
	data["processed"][window["id"]]=true
	data["active_window"]=""
	# Exercise the calendar entry point, then repeat the same slot: no duplicate fixtures.
	var old_slot := w.season.day
	for slot in w.season.calendar.size():
		if w.season.calendar[slot].get("t","") != "I": continue
		if InternationalCalendar.season_date(w,slot) < int(window["b"]): continue
		w.season.day=slot
		InternationalCareer.before_slot(w,slot)
		var old_games := int(data["games"])
		var old_announcements: int = data["announcements"].size()
		check(InternationalCareer.before_slot(w,slot).is_empty(),"international calendar slot idempotent")
		check(int(data["games"])==old_games and data["announcements"].size()==old_announcements,"no duplicated caps or announcement processing")
		break
	w.season.day=old_slot
	metrics["international"]={"native_sample":result,"window_games":results.size(),"caps_brazil":appeared}

func _test_youth() -> void:
	YouthManager.ensure_academy(w)
	YouthManager.build_league(w)
	var comps:=YouthCompetitions.competitions(w)
	check(comps.size()==3,"three extra academy competitions scheduled")
	var sample_date:=InternationalCalendar.season_date(w,0)
	for age_limit in [15,19,20]:
		var team:=YouthCompetitions.select(w,age_limit,sample_date)
		for item in team["xi"]: check(item[0].age(w.year)<=age_limit,"youth age eligibility")
	var old_day:=w.season.day
	for slot in w.season.calendar.size():
		w.season.day=slot
		YouthManager.play_slot(w,slot)
		YouthCompetitions.play_slot(w,slot)
		var after:=_academy_minutes()
		YouthCompetitions.play_slot(w,slot)
		check(_academy_minutes()==after,"youth result cannot be credited twice")
	for comp in comps:check(comp["champion"]>=0,"academy competition completes "+comp["name"])
	metrics["youth"]={"competitions":comps.map(func(c):return {"id":c["id"],"teams":c["clubs"].size(),"rounds":c["rounds"].size(),"champion":c["champion"]}),"academy_size":w.academy.size(),"minutes":_academy_minutes()}
	w.season.day=old_day

func _academy_minutes() -> int:
	var total:=0
	for p: Player in w.academy.values():total+=p.stats[Player.S_MINUTES]
	return total

func _test_save_roundtrip() -> void:
	var original:=w.to_dict(false)
	var restored:=GameWorld.from_dict(bytes_to_var(var_to_bytes(original)))
	check(InternationalCareer.nation(restored)==InternationalCareer.nation(w),"national job survives save")
	check(InternationalCareer.data(restored)["roster"]==InternationalCareer.data(w)["roster"],"squad survives save")
	check(InternationalCareer.plan(restored,"BRA")["style"]==12,"national tactical plan survives save")
	check(YouthCompetitions.competitions(restored).size()==3,"youth competitions survive save")
	check(YouthCompetitions.competitions(restored)[0]["champion"]==YouthCompetitions.competitions(w)[0]["champion"],"youth results survive save")

func _test_ui() -> void:
	var gm:=tree.root.get_node("GameManager")
	gm.world=w
	var main: Node=(load("res://scenes/main.tscn") as PackedScene).instantiate()
	tree.root.add_child(main)
	for i in 4:await tree.process_frame
	var ui:=tree.root.get_node("UIManager")
	ui.goto("national")
	for i in 3:await tree.process_frame
	var screen=ui.current()
	for tab in ["command","calendar","kits"]:
		screen.set("_tab",tab)
		screen.refresh()
		for i in 3:await tree.process_frame
		check(screen.content()!=null and screen.content().get_child_count()>0,"national UI "+tab)
	ui.goto("player",{"id":w.user_club().player_ids[4]})
	for i in 3:await tree.process_frame
	check(ui.current().content().get_child_count()>0,"player development projection UI")
	ui.goto("academy")
	for i in 3:await tree.process_frame
	screen=ui.current()
	screen.set("_tab","competitions")
	screen.refresh()
	for i in 3:await tree.process_frame
	check(screen.content()!=null and screen.content().get_child_count()>0,"academy extra competition UI")
	ui.goto("menu")
	gm.world=null
	main.queue_free()
	for i in 3:await tree.process_frame


func _test_bulk_matches() -> void:
	var clubs:=w.clubs_in_league("BRA1")
	var a: Club=clubs[0]
	var b: Club=clubs[1]
	var sa:=ClubAI.auto_sheet(w,a,"")
	var sb:=ClubAI.auto_sheet(w,b,"")
	var rng:=RandomNumberGenerator.new()
	rng.seed=723
	var side:=QuickMatch._side(w,a,sa,1.0,false,rng)
	check(side["mu"].has("condition") and side["mu"].has("aerial_att") and side["mu"].has("pace_def"),"bulk match receives actual squad descriptors")
	var keys:={}
	for style in 13:
		sa.style=style
		var cached:=QuickMatch._tactics(sa)
		check(is_equal_approx(float(cached["s_rate"]),MatchSimulation.damp(float(DatabaseManager.tactics()["styles"][style]["rate"]))),"new style cache mapping")
	var n:=260
	var goals:=0
	var draws:=0
	for i in n:
		var pair:=w.clubs_in_league(DatabaseManager.league_ids()[i%DatabaseManager.league_ids().size()])
		a=pair[i%pair.size()];b=pair[(i+1)%pair.size()]
		var r:=MatchEngine.test_match(w,a,b,88000+i,true)
		goals+=int(r["hg"])+int(r["ag"])
		if r["hg"]==r["ag"]:draws+=1
		check(r["hg"]>=0 and r["ag"]>=0,"bulk match valid result")
	metrics["bulk_world_sample"]={"n":n,"goals_per_match":float(goals)/n,"draw_rate":float(draws)/n}
	check(float(goals)/n>1.0 and float(goals)/n<5.0,"bulk broad scoring sanity")
	# Check actual league and cup fixtures, not only the calendar helper.
	var first:=InternationalCalendar.season_date(w,0)
	var valid_windows:=InternationalCalendar.windows(w.year)+InternationalCalendar.windows(w.year+1)
	for league: League in w.season.leagues.values():
		for fixtures in league.rounds:
			for f: Fixture in fixtures:
				var date:=InternationalCalendar.season_date(w,f.slot)
				for win in valid_windows:
					check(date<int(win["a"]) or date>int(win["b"]),"scheduled league game outside FIFA window")
