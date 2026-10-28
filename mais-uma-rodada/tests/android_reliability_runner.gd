extends Node

var failures := 0
var main: Node
var pictures := ""
var _pictured_market := false
var league_id := "BRA1"


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("RELIABILITY_FAIL: " + message)


func _ready() -> void:
	_run()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _idle() -> void:
	var deadline := Time.get_ticks_msec() + 180000
	while GameManager.is_busy() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	check(not GameManager.is_busy(), "worker completes")
	await _frames(3)


func _tables_ready(n: Node) -> bool:
	if n is DataTable and n._pending_index < n._pending_count:
		return false
	for c in n.get_children():
		if not _tables_ready(c):
			return false
	return true


func _table_frames() -> int:
	var frames := 0
	var deadline := Time.get_ticks_msec() + 30000
	while not _tables_ready(UIManager.current()) and Time.get_ticks_msec() < deadline:
		frames += 1
		await get_tree().process_frame
	check(_tables_ready(UIManager.current()), "all table rows finish loading")
	return frames


func _large_table(n: Node) -> DataTable:
	if n is DataTable and n.items.size() > DataTable.MOBILE_PAGE:
		return n
	for child in n.get_children():
		var found := _large_table(child)
		if found != null:
			return found
	return null


func _shot(name_: String) -> void:
	if pictures == "" or DisplayServer.get_name() == "headless":
		return
	RenderingServer.force_draw() # Windows pode suspender o desenho da janela ocluída
	get_viewport().get_texture().get_image().save_png(pictures.path_join(name_ + ".png"))


func _sizes(name_: String) -> void:
	if pictures == "":
		return
	for dims in [Vector2i(390, 844), Vector2i(844, 390), Vector2i(800, 1280), Vector2i(1280, 800)]:
		get_tree().root.size = dims
		main.call("_update_layout")
		await _frames(8)
		await _idle()
		await _table_frames()
		await _shot("%s-%dx%d" % [name_, dims.x, dims.y])


func _run() -> void:
	get_tree().root.gui_disable_input = true
	AppSettings.sound = true
	AppSettings.music = true
	AudioServer.set_bus_mute(0, true) # exercício real de áudio sem ruído durante o teste
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			pictures = a.substr(6)
		if a.begins_with("--league="):
			league_id = a.substr(9)
	if pictures != "":
		DirAccess.make_dir_recursive_absolute(pictures)
	AppSettings.tutorial_done = true
	var generated := {}
	GameManager.generate_world_async(WorldGenerator.DEFAULT_SEED, "padrao", func(value: GameWorld): generated["world"] = value)
	while GameManager.is_generating():
		await get_tree().process_frame
	var w: GameWorld = generated["world"]
	generated.clear()
	check(GameManager._gen_result == null, "generator releases the delivered world")
	GameManager.start_career(w, w.clubs_in_league(league_id)[0].id, "Reliability", GameWorld.DIFF_NORMAL, 97)
	GameManager.save_blocking()
	main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await _frames(8)
	UIManager.goto("hub")
	await _idle()
	var orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	for i in 18:
		UIManager.current().refresh()
		await _frames(3)
	var orphan_growth := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) - orphans
	print("RELIABILITY hub_refresh_orphan_growth=", orphan_growth)
	check(orphan_growth == 0, "refreshing the next-match card leaves no orphan nodes")
	if league_id == "ENG4":
		for code in ["en", "es"]:
			I18n.apply(code)
			check(I18n.t("De Graafschap") == "De Graafschap", "club names are not translated")
			check(I18n.t("%s vence os playoffs da %s!" % ["De Graafschap", "Eerste Divisie"]).contains("De Graafschap"), "club names inside translated news")
			for lid in ["ENG2", "ENG3", "ENG4", "NED2", "TUR2", "SCO2", "AUT2", "SUI2", "JPN2"]:
				UIManager.goto("table", {"league": lid})
				await _frames(4)
				await _table_frames()
				var before_refresh := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
				UIManager.current().refresh()
				await _frames(4)
				await _table_frames()
				check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == before_refresh, "table refresh leaves no orphan nodes " + lid)
				check(UIManager.current().get("_league_id") == lid, "new league table opens " + lid)
				var desc := String(DatabaseManager.league_cfg(lid).get("format", {}).get("desc", ""))
				check(desc == "" or I18n.t(desc) != desc, "regulations translated " + lid + " " + code)
				await _shot("table-" + lid + "-" + code)
		UIManager.goto("hub")
		await _frames(3)
	for code in ["pt", "en", "es", "en"]:
		I18n.apply(code)
		var started := Time.get_ticks_msec()
		UIManager.goto("market")
		var open_ms := Time.get_ticks_msec() - started
		check(GameManager.is_busy(), "market search runs outside the UI thread")
		await _idle()
		var frames := await _table_frames()
		print("RELIABILITY market ", code, " open_ms=", open_ms, " total_ms=", Time.get_ticks_msec() - started, " table_frames=", frames)
		var market := UIManager.current()
		if market.screen_name != "market":
			check(false, "expected market, current screen: " + market.screen_name)
			await _shot("unexpected-screen")
			get_tree().quit(1)
			return
		check(not market.get("_base").is_empty(), "whole-world search returns players")
		if code == "pt":
			var players := _large_table(market)
			var page := 20 if OS.has_feature("mobile") or UILayout.size_class() == UILayout.COMPACT else 80
			check(players != null and players._pending_count == page, "initial page follows the device memory budget")
			if players != null and is_instance_valid(players._more):
				players._more.pressed.emit()
				await _table_frames()
				check(players._pending_count == page * 2, "show more loads the next page")
		if code == "en":
			check(I18n.t("Vendas") == "Sales", "new English market text")
			check(I18n.t("Janela fechada, reabre na rodada 9.").contains("matchday 9"), "formatted translation")
			check(I18n.t("Suspenso, 2 jogo(s) · Na seleção") == "Suspended, 2 match(es) · On international duty", "compound translation")
			var table := DataTable.new()
			var cell: Label = table._cell({"text": func(_p): return "Disputa vaga"}, null, false)
			check(cell.text == "Competes for a place", "table text translated despite auto-translation being off")
			cell.free()
			table.free()
			if not _pictured_market:
				await _sizes("market-en")
				_pictured_market = true
			market.set("_query", "zzzz-no-such-player")
			market.refresh()
			await _table_frames()
			check(not market.get("_base").is_empty(), "empty search does not discard search base")
			market.set("_query", "")
		for tab in ["free", "pre", "shortlist", "sales"]:
			if tab in ["free", "pre"]:
				market.set("_tab", "search")
				market.set("_pool", tab)
			else:
				market.set("_tab", tab)
			market.refresh()
			await _table_frames()
		UIManager.goto("hub")
		await _frames(4)
	# Reproduce reopening Mercado after loading the same career, rather than only a new game.
	print("RELIABILITY load begin")
	w = null
	UIManager.goto("menu")
	await _frames(3)
	GameManager.load_career_async(97, func(ok: bool): check(ok, "career loads"))
	await _idle()
	print("RELIABILITY load settled")
	check(not UIManager.stacks.has("market"), "previous career market cache released")
	UIManager.goto("market")
	await _idle()
	await _table_frames()
	check(not UIManager.current().get("_base").is_empty(), "market works after save/load")
	UIManager.goto("hub")
	await _frames(3)
	var completed := {"yes": false}
	var started := Time.get_ticks_msec()
	check(GameManager.begin_match_async(func(md: Dictionary):
		check(not md.get("user", {}).is_empty(), "prepared user match exists")
		completed["yes"] = true), "match preparation starts")
	check(not GameManager.begin_match_async(Callable()), "duplicate preparation rejected")
	var frames := 0
	while GameManager.is_busy() and Time.get_ticks_msec() - started < 180000:
		frames += 1
		await get_tree().process_frame
	check(completed["yes"] and frames > 0, "frames continue while preparing the match")
	print("RELIABILITY begin_match_ms=", Time.get_ticks_msec() - started, " responsive_frames=", frames)
	started = Time.get_ticks_msec()
	UIManager.goto("match")
	print("RELIABILITY match_ui_ms=", Time.get_ticks_msec() - started)
	await _frames(20)
	UIManager.close_all_modals()
	var screen := UIManager.current()
	check(screen.get("_sim") != null and screen.get("_pitch") != null, "live match initialized")
	var board_labels: Array = screen.get("_board").find_children("*", "Label", true, false)
	check(board_labels.any(func(l): return String(l.text).contains("MATCHDAY")), "drawn match header translated before uppercasing")
	await _sizes("match-en")
	var sim := GameManager.user_sim()
	sim.run_to_end()
	check(sim.finished, "user match reaches full-time")
	UIManager.goto("hub")
	GameManager.finish_match_async(func(report: Dictionary): check(not report.is_empty(), "match settlement"))
	await _idle()
	GameManager.save_blocking()
	SaveManager.delete_slot(97)
	print("ANDROID_RELIABILITY_RESULT failures=", failures)
	if failures == 0:
		print("ANDROID_RELIABILITY_OK")
	UIManager.goto("menu")
	await _frames(3)
	get_tree().quit(0 if failures == 0 else 1)
