extends Node
## Capturas da etapa "Lançamento" (1.0): a abertura quadro a quadro, a tela inicial sem e com
## carreira salva, as opções (no menu e na carreira), os créditos e as licenças.
## xvfb-run -a -s "-screen 0 1900x1900x24" godot --path . --resolution 780x1688 --script res://tools/design_shots.gd -- --runner=brand_shots_runner --out=DIR --abertura [--tablet] [--prefix=l_]
## Deitado: --resolution 1688x780. Tablet: --resolution 1280x800 com --tablet.

var out_dir := "user://shots"
var prefix := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--tablet":
			UILayout.force_tablet = true
		if a.begins_with("--prefix="):
			prefix = a.substr(9)
	_run()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _shot(name: String, settle: int = 6) -> void:
	await _frames(settle)
	var _pw := 0
	while Portraits.pending() > 0 and _pw < 1200:
		await get_tree().process_frame
		_pw += 1
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s%s.png" % [out_dir, prefix, name])
	print("[tela] ", name)


func _press(text: String) -> bool:
	await _frames(3)
	for b: Node in get_tree().root.find_children("*", "BaseButton", true, false):
		var bb := b as BaseButton
		if bb is Button and (bb as Button).text == text and bb.is_visible_in_tree() and not bb.disabled:
			bb.pressed.emit()
			await _frames(4)
			return true
	print("não achei o botão: ", text)
	return false


## Toca na linha de menu que tem este título.
func _tap_row(title: String) -> bool:
	await _frames(3)
	for l: Node in UIManager.current().find_children("*", "Label", true, false):
		if (l as Label).text != title or not (l as Label).is_visible_in_tree():
			continue
		var n: Node = l.get_parent()
		while n != null and not (n is PanelContainer and not n.find_children("Tap", "Button", true, false).is_empty()):
			n = n.get_parent()
		if n != null:
			(n.find_children("Tap", "Button", true, false)[0] as Button).pressed.emit()
			await _frames(4)
			return true
	print("não achei a linha: ", title)
	return false


func _until(cond: Callable, max_s: float) -> void:
	var t0 := Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t0 < int(max_s * 1000.0):
		await get_tree().process_frame


func _run() -> void:
	GameManager.delete_save()
	if FileAccess.file_exists(GameManager.BACKUP_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GameManager.BACKUP_PATH))
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	# A abertura, se foi ligada (--abertura): do emblema parado ao nome completo e à saída.
	var intro: Node = null
	for n: Node in main.get("modal_host").get_children():
		if n is IntroOverlay:
			intro = n
	if intro != null:
		var back: BrandBackdrop = intro.get("_back")
		var logo: BrandLogo = intro.get("_logo")
		await _shot("01_abertura_a", 1)
		await _until(func() -> bool: return back.beam > 0.97, 4.0)
		await _shot("01_abertura_b", 0)
		await _until(func() -> bool: return logo.mix > 0.5, 4.0)
		await _shot("01_abertura_c", 0)
		await _until(func() -> bool: return logo.tagline.modulate.a > 0.99, 4.0)
		await _shot("01_abertura_d", 0)
		await _until(func() -> bool: return not is_instance_valid(intro) or (intro as Control).modulate.a < 0.6, 4.0)
		await _shot("01_abertura_e", 0)
		await _until(func() -> bool: return not is_instance_valid(intro), 4.0)
		await _wait(0.8)
	await _shot("02_menu_sem_save")
	# Opções no menu, sem carreira.
	await _press("Opções")
	await _wait(0.4)
	await _shot("03_opcoes_menu")
	UIManager.back()
	await _wait(0.4)
	# Créditos e licenças.
	await _press("Créditos")
	await _wait(0.5)
	await _shot("04_creditos")
	UIManager.current().scroll().scroll_vertical = 100000
	await _shot("04b_creditos_fim")
	UIManager.push("licenses", {"doc": "godot"})
	await _wait(0.4)
	await _shot("05_licenca_godot")
	UIManager.back()
	await _wait(0.3)
	UIManager.push("licenses", {"doc": "saira"})
	await _wait(0.4)
	await _shot("05b_licenca_saira")
	UIManager.back()
	await _wait(0.3)
	UIManager.push("licenses")
	await _wait(0.6)
	await _shot("06_componentes")
	UIManager.push("licenses", {"component": 1})
	await _wait(0.4)
	await _shot("06b_componente")
	UIManager.push("licenses", {"license": "Zlib"})
	await _wait(0.4)
	await _shot("06c_licenca")
	UIManager.goto("menu")
	await _wait(0.4)
	# Uma carreira salva: o menu com "Continuar", as opções com "Carreira salva".
	var w := Career.new_career("Equipe Nova Era", "", "BRA", "Recife", Color("#B3262E"), Color("#F1F0EC"), 500000.0, 2027)
	GameManager.start_career(w)
	for i in 3:
		GameManager.advance_week()
	UIManager.goto("hub")
	await _wait(0.4)
	UIManager.push("settings")
	await _wait(0.4)
	await _shot("07_opcoes_carreira")
	UIManager.current().scroll().scroll_vertical = 100000
	await _shot("07b_opcoes_carreira_fim")
	# "Sair para o menu" fecha a carreira e volta à tela inicial.
	await _tap_row("Sair para o menu")
	await _wait(0.5)
	print("saiu para o menu: ", UIManager.current().screen_name == "menu" and not GameManager.has_career())
	DirAccess.copy_absolute(ProjectSettings.globalize_path(GameManager.SAVE_PATH), ProjectSettings.globalize_path(GameManager.BACKUP_PATH))
	UIManager.goto("menu")
	await _wait(6.0)
	await _shot("08_menu_com_save")
	await _press("Opções")
	await _wait(0.4)
	UIManager.current().scroll().scroll_vertical = 100000
	await _shot("09_opcoes_carreira_salva")
	# Voltar à cópia e apagar: os dois caminhos de verdade.
	await _tap_row("Voltar à cópia de antes da atualização")
	await _wait(0.4)
	await _shot("09b_confirma_copia")
	await _press("Voltar à cópia")
	await _wait(0.4)
	print("cópia restaurada, save existe: ", GameManager.has_save())
	await _tap_row("Apagar a carreira salva")
	await _wait(0.4)
	await _press("Apagar")
	await _wait(0.5)
	print("apagada, save existe: ", GameManager.has_save())
	UIManager.current().scroll().scroll_vertical = 100000
	await _shot("09c_depois_de_apagar")
	UIManager.back()
	await _wait(0.4)
	await _shot("10_menu_depois")
	get_tree().quit()
