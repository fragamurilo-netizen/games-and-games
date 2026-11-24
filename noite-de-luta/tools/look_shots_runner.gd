extends Node

var out_dir := "user://shots"


func _ready() -> void:
	_run()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await _frames(24)
	var _pw := 0
	while Portraits.pending() > 0 and _pw < 1200:
		await get_tree().process_frame
		_pw += 1
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])
	print("[tela] ", name)


func _run() -> void:
	GameManager.delete_save()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await _frames(8)
	var w := Career.new_career("Equipe Nova Era", "", "BRA", "Recife", Color("#B3262E"), Color("#F1F0EC"), 250000.0, 2027)
	var y := w.year()
	var m := w.month()
	var pros: Array = w.fighters.values().filter(func(f: Fighter) -> bool: return f.team_id < 0 and f.stage(y, m) == "profissional")
	pros.sort_custom(func(a: Fighter, b: Fighter) -> bool: return a.level() > b.level())
	var fem: Array = pros.filter(func(f: Fighter) -> bool: return f.is_female())
	var men: Array = pros.filter(func(f: Fighter) -> bool: return not f.is_female())
	var her: Fighter = fem[1]
	var him: Fighter = men[3]
	for f: Fighter in [her, him]:
		f.team_id = w.user_team_id
		f.contract = {"cut": 0.2, "fights": 5}
	GameManager.start_career(w)
	UIManager.goto("team")
	UIManager.push("fighter", {"id": her.id})
	await _shot("00_perfil_dela")
	var t0 := Time.get_ticks_msec()
	UIManager.push("look", {"id": her.id})
	await _frames(2)
	print("abrir editor: ", Time.get_ticks_msec() - t0, " ms")
	await _shot("01_cabelo")
	var s := UIManager.current()
	s.call("_put", "hs", 142)
	s.call("_put", "hc", 5)
	await _shot("02_cabelo_loiro_solto")
	s.set("_hair_cat", "longo")
	s.refresh()
	await _shot("03_cabelo_longos")
	s.set("_tab", "maquiagem")
	s.call("_put", "mk", 3)
	s.call("_put", "lp", 5)
	s.call("_put", "sd", 2)
	await _shot("04_maquiagem_gala")
	s.set("_tab", "rosto")
	s.call("_put", "bt", 1.0)
	await _shot("05_rosto")
	s.set("_tab", "corpo")
	s.call("_put", "bu", 0.9)
	s.call("_put", "ws", 0.05)
	s.call("_put", "hp", 0.9)
	await _shot("06_corpo")
	UIManager.back()
	await _shot("07_perfil_dela_depois")
	UIManager.push("look", {"id": him.id})
	await _shot("08_ele_cabelo")
	s = UIManager.current()
	s.set("_tab", "barba")
	s.refresh()
	await _shot("09_ele_barba")
	s.set("_tab", "corpo")
	s.refresh()
	await _shot("10_ele_corpo")
	GameManager.delete_save()
	get_tree().quit()
