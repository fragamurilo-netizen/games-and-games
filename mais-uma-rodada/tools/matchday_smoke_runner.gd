extends Node


func _ready() -> void:
	_run()


func _frames(k: int) -> void:
	for i in k:
		await get_tree().process_frame


func _wait_save(tag: String) -> void:
	var t0 := Time.get_ticks_msec()
	while bool(GameManager.get("_save_busy")) and Time.get_ticks_msec() - t0 < 60000:
		await get_tree().process_frame
	print("[etapa] save %s terminou em %d ms · busy=%s" % [tag, Time.get_ticks_msec() - t0, str(GameManager.get("_save_busy"))])


func _run() -> void:
	await _frames(2)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await _frames(6)
	print("[etapa] gerando mundo")
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	var clubs := w.clubs_in_league("BRA1")
	AppSettings.tutorial_done = true
	GameManager.start_career(w, clubs[0].id, "Teste", GameWorld.DIFF_NORMAL, 5)
	print("[etapa] carreira criada, save pedido")
	UIManager.goto("hub")
	await _wait_save("inicial")
	for day in 3:
		UIManager.close_all_modals()
		UIManager.push("prematch")
		await _frames(8)
		print("[etapa] pré-jogo %d" % day)
		GameManager.begin_match()
		UIManager.replace("match")
		await _frames(8)
		var ms: BaseScreen = UIManager.current()
		ms.set("_pace", 2)
		var guard := Time.get_ticks_msec() + 180000
		while not bool(ms.get("_done")) and Time.get_ticks_msec() < guard:
			await get_tree().process_frame
			if UIManager.has_modal():
				if bool(ms.get("_halftime")):
					UIManager.close_all_modals()
					ms.call("_start_second_half")
				else:
					UIManager.close_all_modals()
		while GameManager.is_busy(): # a data fecha numa thread de trabalho
			await get_tree().process_frame
		print("[etapa] fim da partida %d" % day)
		await _frames(10)
		UIManager.close_all_modals()
		ms.call("_build_controls")
		UIManager.replace("results", {"report": ms.get("_report")})
		await _frames(10)
		print("[etapa] resultado %d" % day)
		await _wait_save("pós-jogo %d" % day)
		UIManager.goto("hub")
		await _frames(6)
	var ok := SaveManager.load_world(5) != null
	print("[etapa] carregar o save: %s" % ("ok" if ok else "FALHOU"))
	SaveManager.delete_slot(5)
	get_tree().quit()
