extends Node

const COUNTRIES := ["IND", "IDN", "NZL", "POL", "SWE", "NOR", "ROU", "HUN", "IRN", "THA", "MAS", "CAN", "CRC", "IRL"]
var failures := 0
var main: Node
var pictures := ""

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("FEEDBACK_FAIL: " + message)


func _ready() -> void:
	_run()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _idle() -> void:
	var until := Time.get_ticks_msec() + 240000
	while GameManager.is_busy() and Time.get_ticks_msec() < until:
		await get_tree().process_frame
	check(not GameManager.is_busy(), "background work finishes")
	await _frames(3)


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			pictures = arg.substr(6)
	if pictures != "":
		DirAccess.make_dir_recursive_absolute(pictures)
	AppSettings.tutorial_done = true
	AppSettings.sound = false
	AppSettings.music = false
	DatabaseManager.load_all()
	# Generate an old career with none of the new leagues, then apply the migration.
	var order := DatabaseManager._league_order.duplicate()
	DatabaseManager._league_order = order.filter(func(id): return not COUNTRIES.has(String(id).left(3)))
	var delivery := {}
	GameManager.generate_world_async(WorldGenerator.DEFAULT_SEED, "padrao", func(w: GameWorld): delivery["world"] = w)
	while GameManager.is_generating():
		await get_tree().process_frame
	DatabaseManager._league_order = order
	var w: GameWorld = delivery["world"]
	delivery.clear()
	var old_count := w.clubs.size()
	var original_club: Club = w.clubs[0]
	var old_fixture: Fixture = w.season.leagues["ENG1"].rounds[0][0]
	var rng_state := w.rng.state
	var added := LeagueExpansion.apply(w)
	check(added.size() == COUNTRIES.size() and w.clubs.size() == old_count + 194, "all 14 leagues migrate with 194 clubs")
	check(w.clubs[0] == original_club and w.season.leagues["ENG1"].rounds[0][0] == old_fixture, "migration preserves club IDs and existing fixtures")
	check(w.rng.state == rng_state, "migration preserves career RNG")
	check(LeagueExpansion.apply(w).is_empty(), "migration is idempotent")
	for i in w.clubs.size():
		check(w.clubs[i].id == i, "stable club index %d" % i)
	for code in COUNTRIES:
		var cfg := DatabaseManager.league_cfg(code + "1")
		check(w.clubs_in_league(code + "1").size() == int(cfg["teams"]), "club count " + code)
		for c: Club in w.clubs_in_league(code + "1"):
			check(w.squad(c).size() >= 18, "generated squad " + c.name)
	w.season = SeasonManager.build_season(w)
	NationalTeamManager.start_season(w)
	SeasonManager.compute_goals(w)
	GameManager.world = w
	var gate := Semaphore.new()
	GameManager.run_work(func(): gate.wait())
	check(not GameManager.start_career_async(GameWorld.new(), 0, "Duplicate", 0, 98, Callable()), "duplicate career start rejected during work")
	check(GameManager.world == w, "duplicate start cannot replace the active worker's world")
	GameManager.slot = 98
	check(GameManager.save_now() and not GameManager._save_busy, "save during worker is deferred without a competing reader")
	gate.post()
	await _idle()
	GameManager.run_work(func():
		GameManager._start_core(w.clubs_in_league("BRA1")[0].id, "Feedback", GameWorld.DIFF_EASY, 98)
		GameManager.slot = -1)
	await _idle()
	for code in DatabaseManager.nations():
		var spec: Dictionary = DatabaseManager.nation(code).get("flag", {})
		check(not spec.is_empty(), "flag specification " + code)
		if spec.has("svg"):
			check(ResourceLoader.exists(spec["svg"], "Texture2D"), "imported flag artwork " + code)
	BoardObjectives.list(w)
	w.stats[BoardObjectives.KEY]["list"] = [{"k": "league", "t": "OLD_CLUB_TARGET", "w": 3}]
	w.stats[BoardObjectives.CONF_KEY] = {"Old club": 25.0}
	BoardManager.take_job(w, w.clubs_in_league("BRA1")[1].id)
	check(int(w.stats[BoardObjectives.KEY]["club"]) == w.user_club_id, "objectives follow the new job in the same year")
	check(not str(BoardObjectives.list(w)).contains("OLD_CLUB_TARGET"), "old club targets disappear")
	check(not w.stats[BoardObjectives.CONF_KEY].has("Old club"), "old club confidence breakdown disappears")
	w.stats[BoardObjectives.KEY].erase("club")
	BoardObjectives.list(w)
	check(int(w.stats[BoardObjectives.KEY]["club"]) == w.user_club_id, "legacy objective cache repairs on access")
	main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await _frames(6)
	I18n.apply("en")
	UIManager.goto("national", {"nation": "IND"})
	await _frames(8)
	await _sizes("national-en")
	_national(w)
	UIManager.goto("hub")
	await _frames(6)
	Autopilot.mode = Autopilot.MODE_OFF
	SimDialog.stop_on_events = false
	SimDialog.auto_lineup = true
	var first := await _simulate(SimDialog.MODE_GAMES, 3)
	check(first._results.size() == 3, "next three matches plays exactly three")
	UIManager.close_all_modals()
	await _frames(3)
	var end := await _simulate(SimDialog.MODE_SEASON, 0)
	check(w.season.finished and w.season.day == w.season.calendar.size(), "simulate season reaches the final calendar date")
	check(end._results.size() > 20, "full season runs after next three matches")
	UIManager.close_all_modals()
	await _frames(3)
	check(not GameManager.is_busy() and not GameManager.in_batch(), "worker and batch released after simulation")
	check(SaveManager.save_world(w, 98) == OK, "updated career saves")
	var loaded := SaveManager.load_world(98)
	check(loaded != null and loaded.clubs.size() == w.clubs.size() and loaded.season.finished, "expanded completed career loads")
	check(loaded.stats[BoardObjectives.KEY]["club"] == w.user_club_id, "new club objectives survive save/load")
	SaveManager.delete_slot(98)
	print("TESTER_FEEDBACK_RESULT failures=", failures)
	UIManager.goto("menu")
	await _frames(4)
	get_tree().quit(0 if failures == 0 else 1)


func _national(w: GameWorld) -> void:
	var before := NationalTeamManager.data(w).duplicate(true)
	var selected := ["BRA", "ENG", "IND", "IDN", "NZL", "JPN", "USA"]
	var planned := {}
	for code in selected:
		planned[code] = NationalSchedule.upcoming(w, code)
		check(not planned[code].is_empty(), "upcoming fixtures exist for " + code)
	var saved_calendar := JSON.stringify(NationalSchedule.ensure(w))
	NationalTeamManager.data(w)["calendar"] = JSON.parse_string(saved_calendar)
	check(NationalSchedule.upcoming(w, "IND") == planned["IND"], "published fixtures survive JSON save/load")
	for win in NationalTeamManager.windows(w):
		NationalTeamManager.after_weekend(w, int(win["w"]))
		var counts := {}
		var dates := {}
		for row in NationalTeamManager.data(w).get("log", []):
			if row.size() < 9 or int(row[8]) < int(win["from"]) or int(row[8]) > int(win["to"]):
				continue
			for code in [row[1], row[2]]:
				counts[code] = int(counts.get(code, 0)) + 1
				var key := "%s:%d" % [code, int(row[8])]
				check(not dates.has(key), "national team not double-booked " + key)
				dates[key] = true
		for code in counts:
			check(int(counts[code]) <= 2, "two matches per FIFA window " + code)
		var log_size: int = NationalTeamManager.data(w).get("log", []).size()
		var fifa: int = NationalTeamManager.data(w)["fifa"]
		NationalTeamManager.after_weekend(w, int(win["w"]))
		check(NationalTeamManager.data(w).get("log", []).size() == log_size and int(NationalTeamManager.data(w)["fifa"]) == fifa, "FIFA window cannot play twice")
	for code in selected:
		for game in planned[code]:
			check(NationalTeamManager.recent_games(w, code, 20).any(func(r): return r["a"] == game["a"] and r["b"] == game["b"] and int(r["day"]) == int(game["day"])), "displayed national fixture actually played " + code)
	w.stats[NationalTeamManager.KEY] = before
	print("FEEDBACK national calendar checked")


func _simulate(mode: int, count: int) -> SimDialog:
	SimDialog.start(mode, count, Callable())
	var d := SimDialog._active
	check(is_instance_valid(d), "simulation dialog starts")
	var until := Time.get_ticks_msec() + 600000
	var frames := 0
	while is_instance_valid(d) and d._running and Time.get_ticks_msec() < until:
		frames += 1
		await get_tree().process_frame
	check(not d._running and frames > 0, "simulation finishes and keeps processing frames")
	print("FEEDBACK simulation mode=", mode, " games=", d._results.size(), " reason=", d._stop_reason, " frames=", frames)
	return d


func _sizes(prefix: String) -> void:
	if pictures == "" or DisplayServer.get_name() == "headless":
		return
	for dims in [Vector2i(390,844), Vector2i(844,390), Vector2i(800,1280), Vector2i(1280,800)]:
		get_tree().root.size = dims
		main.call("_update_layout")
		await _frames(8)
		var sc := UIManager.current().scroll()
		if sc != null:
			sc.scroll_vertical = 100000
		await _frames(5)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(pictures.path_join("%s-%dx%d.png" % [prefix, dims.x, dims.y]))
