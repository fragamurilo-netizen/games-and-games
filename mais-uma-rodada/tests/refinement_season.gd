extends RefCounted
## One complete simulated world season. No user saves or production app state are accessed.
func run(tree:SceneTree)->void:
	DatabaseManager.load_all()
	var started:=Time.get_ticks_msec()
	var w:=WorldGenerator.generate(19031911,"padrao")
	var slots:=0
	var result:={"seed":19031911,"initial_players":w.players.size(),"clubs":w.clubs.size()}
	while not w.season.finished:
		var before:=w.season.day
		SeasonManager.play_matchday_instant(w)
		slots+=1
		if w.season.day<=before and not w.season.finished:
			push_error("REFINEMENT_SEASON_FAIL: stalled calendar")
			tree.quit(3);return
		if slots%10==0:print("REFINEMENT_SEASON_SLOT ",slots,"/",w.season.calendar.size())
		if Time.get_ticks_msec()-started>420000:
			print("REFINEMENT_SEASON_INCOMPLETE time budget; slots=",slots)
			tree.quit(4);return
		await tree.process_frame
	var goals:=0;var matches:=0;var sum_player_goals:=0;var own:=0;var assists:=0
	var records:Array=[]
	for league:League in w.season.leagues.values():
		var total:=0;var n:=0;var draw:=0
		for fixtures in league.rounds:
			for fx:Fixture in fixtures:
				if not fx.played or not fx.is_league():continue
				n+=1;total+=fx.hg+fx.ag
				if fx.hg==fx.ag:draw+=1
				for g in fx.goals:
					if g[3]==Fixture.GOAL_OWN:own+=1
		goals+=total;matches+=n
		if league.id not in ["BRA1","ENG1","ESP1","ITA1","GER1","FRA1"]:continue
		var players:Array=[]
		for clubid in league.club_ids:
			for row in TeamStatsScreen.current_club_rows(w,w.club(int(clubid)),true):
				if int(row["g"])>0:players.append({"n":row["n"],"club":int(clubid),"g":row["g"],"a":row["as"],"apps":row["a"],"pos":Pos.code(int(row["pos"]))})
		players.sort_custom(func(a,b):return a["g"]>b["g"])
		records.append({"league":league.id,"matches":n,"goals":total,"draws":draw,"top_scorers":players.slice(0,5)})
	for p:Player in w.players.values():
		sum_player_goals+=p.stats[Player.S_GOALS];assists+=p.stats[Player.S_ASSISTS]
	result["matches"]=matches;result["goals"]=goals;result["goals_per_match"]=goals/maxf(1.0,matches);result["player_league_goals"]=sum_player_goals;result["own_goals"]=own;result["assists"]=assists
	if sum_player_goals+own!=goals:
		push_error("REFINEMENT_SEASON_FAIL: individual goals + own goals differ from league scores")
		tree.quit(5);return
	result["league_samples"]=records;result["slots"]=slots
	print("REFINEMENT_SEASON_BEFORE_YEAR_END ",JSON.stringify(result))
	var ending:=SeasonManager.end_season(w)
	result["end_season_completed"]=not ending.is_empty()
	result["elapsed_ms"]=Time.get_ticks_msec()-started
	result["remaining_players"]=w.players.size()
	var path:=OS.get_environment("REFINEMENT_SEASON_REPORT")
	if path=="":path="user://refinement-season.json"
	var f:=FileAccess.open(path,FileAccess.WRITE)
	if f!=null:f.store_string(JSON.stringify(result,"  "));f.close()
	print("REFINEMENT_SEASON_OK ",JSON.stringify(result))
	tree.quit(0)
