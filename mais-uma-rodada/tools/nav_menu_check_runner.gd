extends Node
## Lógica de tools/nav_menu_check.gd (carregada depois dos autoloads).

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


func _taps() -> Array:
	var found: Array = []
	var host: Control = UIManager.main.modal_host
	_collect(host, found)
	return found


func _collect(n: Node, found: Array) -> void:
	for c in n.get_children():
		if c is Button and c.name == "Tap":
			found.append(c)
		_collect(c, found)


func _run() -> void:
	await _frames(2)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await _frames(10)
	var top: TopBar = main.top_bar
	check(not top.menu_btn.visible, "menu ☰ não deveria aparecer no menu inicial")
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	AppSettings.tutorial_done = true
	GameManager.start_career(w, w.clubs_in_league("BRA1")[3].id, "Teste", GameWorld.DIFF_NORMAL, 5)
	UIManager.goto("hub")
	await _frames(10)
	UIManager.close_all_modals()
	await _frames(4)
	check(top.menu_btn.visible, "menu ☰ deveria aparecer no início da carreira")
	await _shot("00_hub")
	top.menu_btn.pressed.emit()
	await _frames(6)
	var n := _taps().size()
	check(n >= 30, "menu com poucos itens (%d)" % n)
	await _shot("01_menu")
	# Cada item (menos salvar e sair, que têm efeitos próprios)
	for i in n:
		UIManager.close_all_modals()
		UIManager.goto("hub")
		await _frames(4)
		UIManager.close_all_modals()
		NavMenu.open()
		await _frames(4)
		var taps := _taps()
		var row: Control = taps[i].get_parent()
		var title := _first_label(row)
		if title == "Sair" or title == "Salvar":
			continue
		taps[i].pressed.emit()
		await _frames(8)
		var cur := UIManager.current()
		var ok := cur != null and not UIManager.has_modal()
		check(ok, "item '%s' não abriu uma tela" % title)
		print("[menu] %-28s -> %s  (☰ %s)" % [title, cur.screen_name if cur else "?", "sim" if top.menu_btn.visible else "não"])
		if ok and cur.show_top:
			check(top.menu_btn.visible, "sem ☰ na tela %s" % cur.screen_name)
		await _shot("%02d_%s" % [i + 2, cur.screen_name if cur else "x"])
	# Salvar pelo menu
	UIManager.close_all_modals()
	NavMenu.open()
	await _frames(4)
	for t in _taps():
		if _first_label(t.get_parent()) == "Salvar":
			t.pressed.emit()
	await _frames(4)
	check(not UIManager.has_modal(), "salvar deveria fechar o menu")
	print("NAV_MENU_CHECK %s (%d falhas)" % ["OK" if _fails == 0 else "FALHOU", _fails])
	get_tree().quit(1 if _fails > 0 else 0)


func _first_label(n: Node) -> String:
	for c in n.get_children():
		if c is Label and c.text != "":
			return c.text
		var s := _first_label(c)
		if s != "":
			return s
	return ""


func check(cond: bool, msg: String) -> void:
	if not cond:
		_fails += 1
		push_error("NAV_MENU: " + msg)
