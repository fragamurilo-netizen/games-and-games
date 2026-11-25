extends Node
## Telas da luta ao vivo (gritos do corner, intervalo, resultado), para conferir a tela nova.
## godot --path . --resolution 450x900 --script res://tools/design_shots.gd -- --runner=fight_live_runner --out=DIR

var out_dir := "user://shots"
var prefix := ""


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await _frames(6)
	var g := 0
	while Portraits.pending() > 0 and g < 600:
		await get_tree().process_frame
		g += 1
	await _frames(3)
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s%s.png" % [out_dir, prefix, name])
	print("ok ", name)


func _ready() -> void:
	GameManager.delete_save()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await _frames(8)
	var w := Career.new_career("Equipe Nova Era", "", "BRA", "Recife", Color("#B3262E"), Color("#F1F0EC"), 250000.0, 2027)
	var y := w.year()
	var m := w.month()
	var pros: Array = w.fighters.values().filter(func(f: Fighter) -> bool: return f.team_id < 0 and f.stage(y, m) == "profissional")
	pros.sort_custom(func(a: Fighter, b: Fighter) -> bool: return a.level() > b.level())
	for f: Fighter in [pros[2], pros[5], pros[9]]:
		f.team_id = w.user_team_id
		f.contract = {"cut": 0.2, "fights": 5}
	GameManager.start_career(w)
	w.tut["on"] = false
	w.tut["skipped"] = true
	w.tut["tips_on"] = false
	w.pops.clear()
	var guard := 0
	while Career.pending_user_bouts(w).is_empty() and guard < 30:
		guard += 1
		if not w.offers.is_empty() and guard > 2:
			Matchmaker.accept_offer(w, w.offers[0])
		Career.advance_week(w)
	w.pops.clear()
	var b: Bout = Career.pending_user_bouts(w)[0]
	var me := w.fighter(b.a) if w.is_user_fighter(w.fighter(b.a)) else w.fighter(b.b)
	UIManager.goto("hub")
	UIManager.push("fighter", {"id": me.id})
	await _shot("01_ficha")
	UIManager.current().scroll().scroll_vertical = 700
	await _shot("02_ficha_b")
	UIManager.current().scroll().scroll_vertical = 1500
	await _shot("03_ficha_c")
	UIManager.current().set("_tab", "carreira")
	UIManager.current().refresh()
	await _shot("04_carreira")
	UIManager.current().scroll().scroll_vertical = 900
	await _shot("05_carreira_b")
	UIManager.back()
	UIManager.push("fight_plan", {"bout": b.id})
	await _shot("09_noite")
	UIManager.replace("fight", {"bout": b.id})
	var fs := UIManager.current()
	fs.set("_speed", 0)
	await _frames(150)
	await _shot("10_apresentacao")
	await _frames(240)
	await _shot("11_luta")
	fs.call("_shout", FightScreen.SHOUTS["pe"][0])
	await _frames(200)
	await _shot("12_luta_grito")
	fs.set("_speed", 2)
	await _frames(260)
	await _shot("13_luta_c")
	var t0 := Time.get_ticks_msec()
	while String(fs.get("_state")) == "round" and Time.get_ticks_msec() - t0 < 30000:
		fs.set("_clock", 99999.0)
		fs.set("_skip", true)
		await get_tree().process_frame
	await _frames(60)
	await _shot("14_intervalo_ou_fim")
	while String(fs.get("_state")) != "done" and Time.get_ticks_msec() - t0 < 60000:
		if String(fs.get("_state")) == "corner":
			var foot: VBoxContainer = fs.footer()
			var btns := foot.find_children("*", "Button", true, false).filter(func(x: Node) -> bool: return not x.is_queued_for_deletion() and not x.get_parent().is_queued_for_deletion())
			if not btns.is_empty():
				(btns[0] as Button).pressed.emit()
		fs.set("_clock", 99999.0)
		fs.set("_skip", true)
		await get_tree().process_frame
	await _frames(120)
	await _shot("15_resultado")
	GameManager.delete_save()
	get_tree().quit()
