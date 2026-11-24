extends Node

var out_dir := ""


func _ready() -> void:
	_run()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	var _pw := 0
	while Portraits.pending() > 0 and _pw < 1200:
		await get_tree().process_frame
		_pw += 1
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])


func _button(text: String) -> Button:
	for b: Button in get_tree().root.find_children("*", "Button", true, false):
		if b.text == text and b.is_visible_in_tree():
			return b
	return null


func _mtime() -> int:
	return FileAccess.get_modified_time(GameManager.SAVE_PATH)


func _run() -> void:
	GameManager.delete_save()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await _frames(8)
	var w := Career.new_career("Equipe Teste", "", "BRA", "Recife", Color("#B3262E"), Color("#F1F0EC"), 250000.0, 2027)
	Tutorial.start(w, false)
	GameManager.start_career(w)
	print("save criado na hora: ", GameManager.has_save(), " · pendente: ", GameManager.get("_dirty"))
	UIManager.goto("hub")
	await _frames(6)
	var week0 := w.week
	var btn := _button("Avançar semana")
	print("botão: ", btn != null)
	btn.pressed.emit()
	await _frames(1)
	await _shot("turn_busy")
	print("durante: semana ", w.week, " (antes ", week0, ") · aviso na tela: ", is_instance_valid(UIManager.get("_busy")))
	while DashKit.closing or GameManager.turning:
		await get_tree().process_frame
	await _frames(4)
	print("depois: semana ", w.week, " · aviso na tela: ", is_instance_valid(UIManager.get("_busy")), " · pendente: ", GameManager.get("_dirty"), " · semanas esperando: ", GameManager.get("_weeks_pending"))
	await _shot("turn_after")
	var m0 := _mtime()
	await get_tree().create_timer(3.4).timeout
	print("3 s sem toque: pendente ", GameManager.get("_dirty"), " · arquivo regravado: ", _mtime() >= m0 and not bool(GameManager.get("_dirty")))
	var meta := GameManager.save_summary()
	print("resumo do save: ", meta)
	# Duas semanas seguidas sem parar: a segunda grava na hora.
	for i in 2:
		btn = _button("Avançar semana")
		if btn == null:
			print("sem botão (luta pendente?)")
			break
		btn.pressed.emit()
		await _frames(2)
		while DashKit.closing or GameManager.turning:
			await get_tree().process_frame
		await _frames(5)
		print("semana ", w.week, " · pendente: ", GameManager.get("_dirty"), " · esperando: ", GameManager.get("_weeks_pending"))
	# Adiantar: fecha semanas até aparecer algo para decidir e grava uma vez só, no fim.
	btn = _button("Adiantar")
	print("botão Adiantar: ", btn != null)
	if btn != null:
		var wk0 := w.week
		var open0 := DashKit.open_keys(w)
		var cash0 := w.user_team().balance
		btn.pressed.emit()
		await _frames(3)
		await _shot("skip_busy")
		while DashKit.closing or GameManager.turning:
			await get_tree().process_frame
		await _frames(5)
		print("adiantou ", w.week - wk0, " semanas · há o que decidir: ", DashKit.needs_player(w, open0, cash0), " · pendências novas: ",
			DashKit.open_keys(w).filter(func(k: String) -> bool: return not open0.has(k)).size(), " · aviso na tela: ", is_instance_valid(UIManager.get("_busy")))
		await _shot("skip_after")
	# Sair de cena grava o que estiver pendente.
	GameManager.save_now()
	print("marcado: ", GameManager.get("_dirty"))
	GameManager.notification(NOTIFICATION_APPLICATION_PAUSED)
	print("depois de pausar o app: pendente ", GameManager.get("_dirty"))
	# Fechar e continuar pelo menu.
	var wk := w.week
	GameManager.close_career()
	UIManager.goto("menu")
	await _frames(6)
	btn = _button("Continuar")
	print("continuar: ", btn != null)
	btn.pressed.emit()
	await _frames(1)
	await _shot("load_busy")
	await _frames(6)
	print("aberto de novo: ", GameManager.has_career(), " semana ", GameManager.world.week if GameManager.has_career() else -1, " (era ", wk, ") · aviso: ", is_instance_valid(UIManager.get("_busy")),
		" · cópia anterior: ", FileAccess.file_exists(GameManager.BACKUP_PATH))
	await _shot("load_after")
	GameManager.world = null
	GameManager.delete_save()
	get_tree().quit()
