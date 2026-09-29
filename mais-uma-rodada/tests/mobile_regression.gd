extends SceneTree
## Testes de regressão de layout e ciclo de vida. Não usa nem altera saves do usuário.
var failures := 0
# Não referenciar classes do projeto no parser deste SceneTree: --script carrega
# o main loop antes de registrar os autoloads. As dependências entram no deferred.
var _layout: Script
var _portraits: Script


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("MOBILE_FAIL: " + message)


func _run() -> void:
	check(root.get_node_or_null("AudioManager") != null, "audio autoload initialized")
	_layout = load("res://scripts/ui/ui_layout.gd")
	_portraits = load("res://scripts/ui/components/portrait_view.gd")
	check(_layout.base_size_for(Vector2i(1080, 2400)) == Vector2i(720, 1280), "phone portrait base")
	check(_layout.base_size_for(Vector2i(2400, 1080)) == Vector2i(1280, 720), "phone landscape base")
	check(_layout.base_size_for(Vector2i(1600, 2560), true) == Vector2i(1100, 1500), "tablet portrait base")
	check(_layout.base_size_for(Vector2i(2560, 1600), true) == Vector2i(1500, 1100), "tablet landscape base")
	check(is_equal_approx(_layout.device_scale(), 1.0), "no hidden text shrink")
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		check(false, "main scene load")
		quit(1)
		return
	var main := packed.instantiate()
	root.add_child(main)
	for i in 12:
		await process_frame
	var menu := main.find_child("MainMenuScreen", true, false)
	check(menu != null, "menu boot")
	if menu != null:
		var content := menu.get_node_or_null("Body/Scroll/Margin/Content")
		check(content != null and content.get_child_count() >= 3, "menu populated")
	for tablet in [false, true]:
		_layout.force_tablet = tablet
		for dimensions in [Vector2i(720, 1280), Vector2i(1280, 720), Vector2i(900, 1200), Vector2i(1200, 900), Vector2i(720, 1280)]:
			root.size = dimensions
			main.call("_update_layout")
			for i in 8:
				await process_frame
			check(root.content_scale_size == _layout.base_size_for(dimensions, tablet), "rotated base " + str(dimensions))
			check(not bool(main.get("_layout_pending")), "resize notifications settle")
			check(is_instance_valid(main.get("bottom_nav")), "navigation survives rotation")
	_layout.force_tablet = false
	await _test_match_rotation()
	_portraits._cmd_cache.clear()
	_portraits._cmd_cache_order.clear()
	for i in 360:
		_portraits._cmd_cache[i] = []
		_portraits._cmd_cache_order.append(i)
	main.call("_trim_portrait_cache", 240)
	check(_portraits._cmd_cache.size() == 240, "portrait cache bounded")
	check(_portraits._cmd_cache_order.size() == 240, "cache FIFO remains in sync")
	main.notification(Node.NOTIFICATION_OS_MEMORY_WARNING)
	check(_portraits._cmd_cache.is_empty(), "memory warning clears only disposable cache")
	check(_portraits._cmd_cache_order.is_empty(), "memory warning clears FIFO")
	main.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	main.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	for i in 8:
		await process_frame
	check(not bool(main.get("_wake_pending")), "resume notifications settle")
	print("MOBILE_REGRESSION_RESULT failures=", failures)
	if failures == 0:
		print("MOBILE_REGRESSION_OK")
	quit(0 if failures == 0 else 1)


func _test_match_rotation() -> void:
	# Monta o esqueleto real da partida, incluindo os dois blocos entre campo e estatísticas.
	# O bug anterior confundia índices de pais diferentes e perdia/movia esses blocos.
	var screen := (load("res://scenes/screens/match.tscn") as PackedScene).instantiate()
	var body := VBoxContainer.new()
	screen.add_child(body)
	screen.set("_root", body)
	var score := Control.new()
	body.add_child(score)
	var pitch: Control = load("res://scripts/ui/components/pitch_view.gd").new()
	pitch.custom_minimum_size.y = 330.0
	var pitch_box := MarginContainer.new()
	pitch_box.add_child(pitch)
	body.add_child(pitch_box)
	body.add_child(MarginContainer.new()) # tarja de gol
	body.add_child(MarginContainer.new()) # placares paralelos
	var stats := VBoxContainer.new()
	var stats_box := MarginContainer.new()
	stats_box.add_child(stats)
	body.add_child(stats_box)
	var tabs := HBoxContainer.new()
	var tabs_box := MarginContainer.new()
	tabs_box.add_child(tabs)
	body.add_child(tabs_box)
	var feed := ScrollContainer.new()
	var tab_scroll := ScrollContainer.new()
	body.add_child(feed)
	body.add_child(tab_scroll)
	var controls := Control.new()
	body.add_child(controls)
	screen.set("_pitch", pitch)
	screen.set("_stats_box", stats)
	screen.set("_tabs_row", tabs)
	screen.set("_feed_scroll", feed)
	screen.set("_tab_scroll", tab_scroll)
	root.add_child(screen)
	pitch.set_process(false)
	screen.set_process(false)
	var original: Array[Node] = body.get_children()
	for turn in 24:
		_layout.viewport = Vector2(1280, 720)
		screen.call("_responsive_layout")
		check(is_instance_valid(screen.get("_wide_body")), "wide match body " + str(turn))
		check(score.get_parent() == body and controls.get_parent() == body, "score/controls stay outside columns")
		_layout.viewport = Vector2(720, 1280)
		screen.call("_responsive_layout")
		check(body.get_children() == original, "exact child order restored " + str(turn))
		check(is_equal_approx(pitch.custom_minimum_size.y, 330.0), "portrait field height restored")
		await process_frame
	screen.queue_free()
	await process_frame
