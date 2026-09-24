extends Node
## Lógica do passeio pelas telas (carregada em tempo de execução pelo screenshot_tour.gd,
## depois que os autoloads existem).

var out_dir := ""
var shots := false
var count := 0


func _ready() -> void:
	_run()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait(sec: float) -> void:
	var t := Time.get_ticks_msec() + int(sec * 1000.0)
	while Time.get_ticks_msec() < t:
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	await _frames(3)
	count += 1
	print("[tela] ", shot_name)
	if not shots:
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [out_dir, shot_name])


func _screen() -> BaseScreen:
	return UIManager.current()


func _run() -> void:
	await _frames(2)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await _frames(10)
	await _shot("01_menu")
	UIManager.push("new_career")
	await _frames(10)
	await _shot("02_nova_carreira")
	# Carreira de teste (mundo padrão, clube da 2ª divisão)
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	var club_id := -1
	for c: Club in w.clubs_in_league("BRA1"):
		if c.archetype == "tradicional_decadente" or club_id < 0:
			club_id = c.id
	AppSettings.tutorial_done = false
	GameManager.start_career(w, club_id, "Murilo", GameWorld.DIFF_NORMAL, 5)
	UIManager.goto("hub")
	await _frames(12)
	await _shot("03_tutorial")
	UIManager.close_all_modals()
	await _frames(4)
	await _shot("04_hub")
	UIManager.goto("squad")
	await _frames(8)
	await _shot("05_elenco")
	var star: Player = null
	for p in w.squad(w.user_club()):
		if star == null or p.ovr_f > star.ovr_f:
			star = p
	UIManager.push("player", {"id": star.id})
	await _frames(8)
	await _shot("06_perfil")
	UIManager.goto("hub")
	UIManager.push("prematch")
	await _frames(8)
	await _shot("07_pre_jogo")
	# Partida ao vivo em modo turbo
	GameManager.begin_match()
	UIManager.replace("match")
	await _frames(6)
	var ms := _screen()
	ms.set("_pace", 2)
	await _wait(2.5)
	await _shot("08_partida")
	var got_goal := false
	var got_half := false
	var guard := Time.get_ticks_msec() + 120000
	while not bool(ms.get("_done")) and Time.get_ticks_msec() < guard:
		await get_tree().process_frame
		var ov: GoalOverlay = ms.get("_overlay")
		if not got_goal and ov != null and ov.is_playing():
			got_goal = true
			await _wait(0.45)
			await _shot("09_gol")
		if not got_half and bool(ms.get("_halftime")):
			got_half = true
			await _frames(6)
			await _shot("10_intervalo")
			UIManager.close_all_modals()
			ms.call("_open_tactics")
			await _frames(6)
			await _shot("11_ajustes")
			UIManager.close_all_modals()
			ms.call("_start_second_half")
	await _frames(8)
	await _shot("12_fim_de_jogo")
	var report: Dictionary = ms.get("_report")
	UIManager.replace("results", {"report": report})
	await _frames(8)
	await _shot("13_resultados")
	UIManager.goto("table")
	await _frames(8)
	await _shot("14_tabela")
	_screen().set("_tab", "scorers")
	_screen().refresh()
	await _frames(6)
	await _shot("15_artilharia")
	_screen().set("_tab", "rounds")
	_screen().refresh()
	await _frames(6)
	await _shot("16_rodadas")
	UIManager.goto("market")
	await _frames(8)
	await _shot("17_mercado")
	_screen().set("_tab", "free")
	_screen().refresh()
	await _frames(6)
	await _shot("18_livres")
	_screen().set("_tab", "offers")
	_screen().refresh()
	await _frames(4)
	UIManager.goto("club")
	await _frames(8)
	await _shot("19_clube")
	var rival := w.user_club().main_rival()
	if rival >= 0:
		UIManager.push("club", {"id": rival})
		await _frames(8)
		await _shot("20_clube_rival")
	UIManager.goto("hub")
	UIManager.push("news")
	await _frames(8)
	await _shot("21_noticias")
	UIManager.push("settings")
	await _frames(6)
	await _shot("22_opcoes")
	UIManager.goto("menu")
	UIManager.push("load")
	await _frames(6)
	await _shot("23_carregar")
	# Resto da temporada no instantâneo, com passagens pelo hub e pelos resultados
	UIManager.goto("hub")
	var rounds := 1
	while not GameManager.season_over():
		var r := GameManager.play_instant()
		rounds += 1
		if rounds == 19:
			UIManager.goto("hub")
			UIManager.push("results", {"report": r})
			await _frames(6)
			await _shot("24_resultados_meio")
	UIManager.goto("hub")
	await _frames(8)
	await _shot("25_hub_fim")
	UIManager.push("season_end")
	await _wait(0.6)
	await _shot("26_fim_de_temporada")
	await _wait(4.0)
	await _shot("27_fim_de_temporada_resumo")
	UIManager.goto("hub")
	await _frames(8)
	await _shot("28_hub_nova_temporada")
	print("TOUR OK: %d telas, temporada %d, rodadas %d" % [count, GameManager.world.year, rounds])
	GameManager.close_career()
	SaveManager.delete_slot(5)
	main.queue_free()
	await _frames(2)
	get_tree().quit(0)
