extends Node
## Lógica de tools/face_lab_check.gd (carregada depois dos autoloads).

var out_dir := ""
var _fails := 0


func _ready() -> void:
	_run()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	await _frames(6)
	if out_dir == "":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, shot_name])


func check(ok: bool, msg: String) -> void:
	if not ok:
		_fails += 1
		print("FALHA: ", msg)


func _run() -> void:
	await _frames(2)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await _frames(10)
	UIManager.push("editor")
	await _frames(6)
	UIManager.push("face_lab")
	await _frames(10)
	var lab := UIManager.current()
	check(lab != null and lab.get_script().resource_path.ends_with("face_lab_screen.gd"), "laboratório não abriu")
	if lab == null:
		get_tree().quit(1)
		return
	await _shot("lab_00")
	var view: PortraitView = lab.get("_view")
	check(view != null and view.last_draw_usec > 0, "retrato do laboratório não desenhou")
	var seed0: int = lab.get("_seed")
	lab.call("_update")
	lab.set("_seed", seed0 + 1)
	lab.call("_update")
	await _frames(4)
	check(view.face_seed == seed0 + 1, "próximo não trocou a semente")
	# Ajustes finos mexem no DNA
	var f0 := FaceDNA.from_seed(view.face_seed, view.eth, view.age, view.look)
	var sl: HSlider = (lab.get("_sliders") as Dictionary)["nose_w"]
	sl.value = 1.0
	await _frames(4)
	var f1 := FaceDNA.from_seed(view.face_seed, view.eth, view.age, view.look)
	check(float(f1["nose_w"]) > float(f0["nose_w"]), "slider do nariz não alargou o nariz")
	(lab.get("_sliders") as Dictionary)["light"].value = 1.4
	await _frames(4)
	check(is_equal_approx(FaceLighting.contrast, 1.4), "slider de luz não mudou o contraste")
	await _shot("lab_01_ajustes")
	# Grade de 100
	lab.call("_gen_grid", false)
	await _frames(20)
	var views: Array = lab.get("_grid_views")
	check(views.size() == 100, "grade sem 100 rostos (%d)" % views.size())
	var drawn := 0
	var total := 0
	for v: PortraitView in views:
		if v.last_draw_usec > 0:
			drawn += 1
			total += v.last_draw_usec
	check(drawn == 100, "grade com rostos sem desenhar (%d)" % drawn)
	print("FACE_LAB grade: %d rostos, média %.1f ms por retrato" % [drawn, total / 1000.0 / maxf(1.0, drawn)])
	var sc: ScrollContainer = lab.scroll()
	sc.scroll_vertical = int(sc.get_v_scroll_bar().max_value)
	await _shot("lab_02_grade")
	UIManager.back()
	await _frames(6)
	check(is_equal_approx(FaceLighting.contrast, 1.0), "a luz do laboratório vazou para o jogo")
	if _fails == 0:
		print("FACE_LAB_CHECK OK")
	get_tree().quit(1 if _fails > 0 else 0)
