extends SceneTree
## Testes de regressão de layout e ciclo de vida. Não usa nem altera saves do usuário.
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("MOBILE_FAIL: " + message)


func _run() -> void:
	check(UILayout.base_size_for(Vector2i(1080, 2400)) == Vector2i(720, 1280), "phone portrait base")
	check(UILayout.base_size_for(Vector2i(2400, 1080)) == Vector2i(1280, 720), "phone landscape base")
	check(UILayout.base_size_for(Vector2i(1600, 2560), true) == Vector2i(900, 1200), "tablet portrait base")
	check(UILayout.base_size_for(Vector2i(2560, 1600), true) == Vector2i(1200, 900), "tablet landscape base")
	check(is_equal_approx(UILayout.device_scale(), 1.0), "no hidden text shrink")
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		check(false, "main scene load")
		quit(1)
		return
	var main := packed.instantiate()
	root.add_child(main)
	for i in 12:
		await process_frame
	check(main.find_child("MainMenuScreen", true, false) != null, "menu boot")
	for tablet in [false, true]:
		UILayout.force_tablet = tablet
		for dimensions in [Vector2i(720, 1280), Vector2i(1280, 720), Vector2i(900, 1200), Vector2i(1200, 900), Vector2i(720, 1280)]:
			root.size = dimensions
			main.call("_update_layout")
			for i in 8:
				await process_frame
			check(root.content_scale_size == UILayout.base_size_for(dimensions, tablet), "rotated base " + str(dimensions))
			check(not bool(main.get("_layout_pending")), "resize notifications settle")
			check(is_instance_valid(main.get("bottom_nav")), "navigation survives rotation")
	UILayout.force_tablet = false
	await _test_match_rotation()
	PortraitView._cmd_cache.clear()
	PortraitView._cmd_cache_order.clear()
	for i in 360:
		PortraitView._cmd_cache[i] = []
		PortraitView._cmd_cache_order.append(i)
	main.call("_trim_portrait_cache", 240)
	check(PortraitView._cmd_cache.size() == 240, "portrait cache bounded")
	check(PortraitView._cmd_cache_order.size() == 240, "cache FIFO remains in sync")
	main.notification(Node.NOTIFICATION_OS_MEMORY_WARNING)
	check(PortraitView._cmd_cache.is_empty(), "memory warning clears only disposable cache")
	check(PortraitView._cmd_cache_order.is_empty(), "memory warning clears FIFO")
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
	var pitch := PitchView.new()
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
		UILayout.viewport = Vector2(1280, 720)
		screen.call("_responsive_layout")
		check(is_instance_valid(screen.get("_wide_body")), "wide match body " + str(turn))
		check(score.get_parent() == body and controls.get_parent() == body, "score/controls stay outside columns")
		UILayout.viewport = Vector2(720, 1280)
		screen.call("_responsive_layout")
		check(body.get_children() == original, "exact child order restored " + str(turn))
		check(is_equal_approx(pitch.custom_minimum_size.y, 330.0), "portrait field height restored")
		await process_frame
	screen.queue_free()
	await process_frame
