extends Node
## Lógica do kit_shots.gd (carregada depois que os autoloads existem).

var out_dir := "/tmp/kits"


func _ready() -> void:
	_run()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	await _frames(4)
	var t := Time.get_ticks_msec() + 350
	while Time.get_ticks_msec() < t:
		await get_tree().process_frame
	print("[tela] ", shot_name)
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, shot_name])


func _scr() -> BaseScreen:
	return UIManager.current()


func _run() -> void:
	await _frames(2)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await _frames(8)
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	var club_id := -1
	for c: Club in w.clubs_in_league("BRA1"):
		if club_id < 0 or c.archetype == "tradicional_decadente":
			club_id = c.id
	AppSettings.tutorial_done = true
	GameManager.start_career(w, club_id, "Murilo", GameWorld.DIFF_NORMAL, 5)
	var club := w.user_club()
	# Temporadas anteriores de mentira, para o histórico
	var real_year := w.year
	for back in [3, 2, 1]:
		w.year = real_year - back
		var kr := RandomNumberGenerator.new()
		kr.seed = back * 77
		var saved := [club.kit_home.duplicate(true), club.kit_away.duplicate(true)]
		var col := KitDesign.collection(club, w.year, back)
		club.kit_home = col["h"]
		club.kit_away = col["a"]
		club.kit_third = col["t"]
		KitDesign.record(w, club)
		club.kit_home = saved[0]
		club.kit_away = saved[1]
		club.kit_third = {}
	w.year = real_year
	UIManager.goto("hub")
	await _frames(10)
	await _shot("k01_convite_lancamento")
	UIManager.close_all_modals()
	UIManager.push("kit", {"launch": true})
	await _frames(8)
	await _shot("k02_colecoes")
	_scr().scroll().scroll_vertical = 600
	await _shot("k03_colecoes_rolado")
	var col0 := KitDesign.collection(club, w.year, 1)
	_scr().call("_apply_collection", club, col0)
	_scr().set("_which", "away")
	_scr().set("_part", "colors")
	_scr().refresh()
	_scr().scroll().scroll_vertical = 0
	await _shot("k04_cores_reserva")
	_scr().scroll().scroll_vertical = 520
	await _shot("k05_cores_bloqueadas")
	# Reserva igual ao titular: aviso
	club.kit_away["c1"] = club.kit_home.get("c1", club.color1)
	club.kit_away["c2"] = club.kit_home.get("c2", club.color2)
	club.kit_away["shorts"] = club.kit_home.get("shorts", club.color2)
	_scr().set("_part", "models")
	_scr().refresh()
	_scr().scroll().scroll_vertical = 0
	await _shot("k06_aviso_mesma_cor")
	_scr().call("_finish")
	await _frames(6)
	await _shot("k07_confirma_ajuste")
	UIManager.close_all_modals()
	_scr().set("_which", "home")
	_scr().set("_part", "details")
	_scr().refresh()
	_scr().scroll().scroll_vertical = 0
	await _shot("k08_gola_mangas")
	_scr().set("_part", "shorts")
	_scr().refresh()
	await _shot("k09_calcao")
	_scr().set("_part", "shirt")
	_scr().refresh()
	await _shot("k10_estampa")
	_scr().scroll().scroll_vertical = 100000
	await _shot("k11_historico_resumo")
	UIManager.push("kit_history")
	await _frames(8)
	await _shot("k12_historico")
	_scr().call("_detail", club, real_year - 2, "h", club.kit_history[str(real_year - 2)]["h"])
	await _frames(6)
	await _shot("k13_historico_detalhe")
	get_tree().quit()
