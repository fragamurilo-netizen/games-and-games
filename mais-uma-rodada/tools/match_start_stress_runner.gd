extends Node

var games := 6
var wait_save := true
var intro_dir := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--games="):
			games = int(a.get_slice("=", 1))
		elif a.begins_with("--tv="):
			AppSettings.tv_graphics = int(a.get_slice("=", 1))
		elif a.begins_with("--intro-shots="):
			intro_dir = a.get_slice("=", 1)
		elif a == "--no-wait-save":
			wait_save = false
	_run()


func _frames(k: int) -> void:
	for i in k:
		await get_tree().process_frame


func _mem(tag: String) -> void:
	print("[mem] %-22s estática %6.1f MB · vídeo %6.1f MB · objetos %d · nós %d" % [tag,
		OS.get_static_memory_usage() / 1048576.0,
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])


func _run() -> void:
	await _frames(2)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await _frames(6)
	_mem("início")
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	var clubs := w.clubs_in_league("BRA1")
	AppSettings.tutorial_done = true
	if AppSettings.match_speed == AppSettings.SPEED_INSTANT:
		AppSettings.match_speed = AppSettings.SPEED_FAST
	GameManager.start_career(w, clubs[3].id, "Teste", GameWorld.DIFF_NORMAL, 5)
	UIManager.goto("hub")
	await _frames(10)
	_mem("carreira")
	for g in games:
		if wait_save:
			while bool(GameManager.get("_save_busy")):
				await get_tree().process_frame
		while GameManager.is_busy():
			await get_tree().process_frame
		UIManager.close_all_modals()
		UIManager.push("prematch")
		await _frames(6)
		var pre: BaseScreen = UIManager.current()
		if pre == null or not pre.has_method("_start"):
			print("[etapa] %d: sem pré-jogo (%s)" % [g, str(pre)])
			break
		_mem("pré-jogo %d" % g)
		var t0 := Time.get_ticks_msec()
		var tx := func() -> float: return Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0
		var ta := Time.get_ticks_usec()
		GameManager.begin_match()
		var tb := Time.get_ticks_usec()
		print("[passo] begin_match %d ms · textura %.1f" % [(tb - ta) / 1000, tx.call()])
		UIManager.replace("match")
		var tc := Time.get_ticks_usec()
		print("[passo] tela da partida %d ms · textura %.1f" % [(tc - tb) / 1000, tx.call()])
		await get_tree().process_frame
		print("[passo] 1º quadro (abertura) %d ms · textura %.1f" % [(Time.get_ticks_usec() - tc) / 1000, tx.call()])
		var t1 := Time.get_ticks_msec()
		var ms: BaseScreen = UIManager.current()
		for k in 600:
			if ms != null and ms.get("_done") != null:
				break
			await get_tree().process_frame
			ms = UIManager.current()
		for k in 40:
			if k % 4 == 0:
				print("[quadro] %d textura %.1f MB modal=%s nós=%d" % [k, Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0, str(UIManager.has_modal()), int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])
			await get_tree().process_frame
		print("[etapa] %d: iniciar levou %d ms até o 1º quadro, %d ms até 30 quadros · tela %s · save ocupado %s" % [
			g, t1 - t0, Time.get_ticks_msec() - t0, ms.name if ms != null else "-", str(GameManager.get("_save_busy"))])
		_mem("partida %d" % g)
		if intro_dir != "" and g == 0:
			await _walk_intro()
		_vps(get_tree().root)

		if ms == null or ms.get("_done") == null:
			print("[etapa] %d: a tela da partida não abriu" % g)
			break
		ms.set("_pace", 2)
		var guard := Time.get_ticks_msec() + 240000
		while not bool(ms.get("_done")) and Time.get_ticks_msec() < guard:
			await get_tree().process_frame
			if UIManager.has_modal():
				if bool(ms.get("_halftime")):
					UIManager.close_all_modals()
					ms.call("_start_second_half")
				else:
					UIManager.close_all_modals()
		while GameManager.is_busy():
			await get_tree().process_frame
		_mem("fim %d" % g)
		await _frames(10)
		UIManager.close_all_modals()
		UIManager.replace("results", {"report": ms.get("_report")})
		await _frames(10)
		UIManager.goto("hub")
		await _frames(6)
	while GameManager.is_busy():
		await get_tree().process_frame
	_mem("final")
	SaveManager.delete_slot(5)
	print("[etapa] FIM OK")
	get_tree().quit()


func _vps(root: Node) -> void:
	var n := 0
	var px := 0
	var by_owner := {}
	for v in root.find_children("*", "SubViewport", true, false):
		var vp := v as SubViewport
		n += 1
		px += vp.size.x * vp.size.y
		var owner_name := String(vp.get_parent().get_class()) + ":" + str(vp.get_parent().get_script().resource_path.get_file() if vp.get_parent().get_script() != null else "")
		by_owner[owner_name] = int(by_owner.get(owner_name, 0)) + 1
	print("[vp] %d SubViewports · %.1f Mpx · textura %.1f MB · buffers %.1f MB · %s" % [n, px / 1e6,
		Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1048576.0, str(by_owner)])



## Passa pelas páginas da abertura com "Próximo", capturando cada uma.
func _walk_intro() -> void:
	DirAccess.make_dir_recursive_absolute(intro_dir)
	for page in 9:
		if not UIManager.has_modal():
			break
		await _frames(40)
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/intro_%d.png" % [intro_dir, page])
		print("[abertura] página %d · textura %.1f MB" % [page, Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0])
		var next: Button = null
		for b in get_tree().root.find_children("*", "Button", true, false):
			if (b as Button).text in ["Próximo", "Apito inicial"] and (b as Button).is_visible_in_tree():
				next = b
		if next == null:
			break
		next.pressed.emit()
