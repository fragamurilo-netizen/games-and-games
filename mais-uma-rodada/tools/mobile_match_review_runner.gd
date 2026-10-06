extends Node
## Uses an isolated QA user directory (override.cfg); never run against player saves.

var out_dir := ""
var failures := 0
var main: Node
var finish_calls := 0
const SIZES := [Vector2i(390, 844), Vector2i(844, 390), Vector2i(800, 1280), Vector2i(1280, 800)]

func _ready() -> void:
	_run()

func _frames(n: int = 12) -> void:
	for i in n:
		await get_tree().process_frame

func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error("REVIEW_FAIL: " + label)

func _resize(dimensions: Vector2i) -> void:
	UILayout.force_tablet = mini(dimensions.x, dimensions.y) >= 800
	get_tree().root.size = dimensions
	main.call("_update_layout")
	await _frames(30)

func _shot(label: String) -> void:
	await _frames()
	if label == "champions-table":
		var top: Control = main.get("top_bar")
		print("TOP_GEOMETRY viewport=", get_viewport().get_visible_rect(), " bar=", top.get_global_rect(), " title=", top.title_lbl.get_global_rect())
		_check(top.title_lbl.get_global_rect().position.y >= 0, "header title stays in viewport")
	if out_dir != "" and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var dimensions := get_tree().root.size
		var path := out_dir.path_join("%dx%d-%s.png" % [dimensions.x, dimensions.y, label])
		get_viewport().get_texture().get_image().save_png(path)
	print("REVIEW_SHOT ", label, " ", get_tree().root.size)

func _run() -> void:
	_check(OS.get_user_data_dir().contains("QA"), "isolated user directory")
	if failures > 0:
		get_tree().quit(1)
		return
	if out_dir != "":
		DirAccess.make_dir_recursive_absolute(out_dir)
	main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await _frames()
	var world := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	AppSettings.tutorial_done = true
	GameManager.start_career(world, world.clubs_in_league("ENG1")[0].id, "QA", GameWorld.DIFF_NORMAL, 97)
	var cup: Cup = world.season.cups["UCL"]
	for dimensions in SIZES:
		await _resize(dimensions)
		UIManager.goto("table", {"cup": "UCL"})
		await _shot("champions-table")
		UIManager.goto("table", {"cup": "UCL", "tab": "rounds"})
		await _shot("champions-games")
		# Fixture detail and back preserve the list and round.
		TableRows.fixture_details(world, cup.fixtures[0])
		await _shot("fixture")
		UIManager.close_all_modals()
		UIManager.goto("hub")
		SimDialog.open(func(): pass)
		await _shot("sim-options")
		UIManager.close_all_modals()
	GameManager.begin_match()
	UIManager.replace("match")
	await _frames()
	var match_screen: BaseScreen = UIManager.current()
	match_screen.set("_paused", true)
	UIManager.close_all_modals()
	for dimensions in SIZES:
		await _resize(dimensions)
		await _shot("match")
		var pitch: Control = match_screen.get("_pitch")
		_check(pitch.horizontal == (dimensions.x > dimensions.y), "field orientation " + str(dimensions))
		var controls: Control = match_screen.get("_controls_panel")
		_check(controls.get_global_rect().end.y <= get_viewport().get_visible_rect().size.y + 1, "match controls reachable " + str(dimensions))
		match_screen.call("_open_panel")
		await _shot("match-panel")
		UIManager.close_all_modals()
	match_screen.set_process(false)
	var turn := world.season.turn
	GameManager.user_sim().run_to_end()
	GameManager.finish_match_async(_finished)
	_check(GameManager.begin_match().is_empty(), "cannot reenter a busy match")
	GameManager.finish_match_async(_finished)
	while GameManager.is_busy():
		await get_tree().process_frame
	_check(finish_calls == 1, "one completion callback after duplicate finish")
	_check(world.season.turn == turn + 1, "one settlement after duplicate finish")
	_check(GameManager.matchday.is_empty(), "match released after completion")
	# Closing a simulation sheet must return immediately while its worker finishes.
	GameManager.begin_batch()
	GameManager.run_work(func(): OS.delay_msec(300))
	var stop_time := Time.get_ticks_msec()
	GameManager.end_batch()
	_check(Time.get_ticks_msec() - stop_time < 100, "batch close does not block UI")
	_check(GameManager.in_batch(), "batch remains protected until worker finishes")
	while GameManager.is_busy():
		await get_tree().process_frame
	_check(not GameManager.in_batch(), "batch closes after worker completion")
	UIManager.goto("hub")
	await _frames()
	GameManager.save_blocking()
	SaveManager.delete_slot(97)
	print("MOBILE_MATCH_REVIEW failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)

func _finished(_report: Dictionary) -> void:
	finish_calls += 1
