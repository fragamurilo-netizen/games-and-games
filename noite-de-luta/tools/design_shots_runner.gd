extends Node

var out_dir := "user://shots"
var prefix := ""


func _ready() -> void:
	_run()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await _frames(6)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s%s.png" % [out_dir, prefix, name])
	print("[tela] ", name)


func _run() -> void:
	GameManager.delete_save()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await _frames(8)
	await _shot("01_menu")
	UIManager.push("new_career")
	await _shot("02_nova_academia")
	var w := Career.new_career("Equipe Nova Era", "", "BRA", "Recife", Color("#B3262E"), Color("#F1F0EC"), 250000.0, 2027)
	# Uma equipe pronta: dois profissionais e um amador.
	var y := w.year()
	var m := w.month()
	var pros: Array = w.fighters.values().filter(func(f: Fighter) -> bool: return f.team_id < 0 and f.stage(y, m) == "profissional")
	pros.sort_custom(func(a: Fighter, b: Fighter) -> bool: return a.level() > b.level())
	var ams: Array = w.fighters.values().filter(func(f: Fighter) -> bool: return f.team_id < 0 and not f.is_pro())
	for f: Fighter in [pros[2], pros[5], ams[0]]:
		f.team_id = w.user_team_id
		f.contract = {"cut": 0.2, "fights": 5}
	StaffMarket.hire(w, w.staff_market[0])
	GameManager.start_career(w)
	# Avança até haver proposta, aceita e segue até a semana da luta.
	var guard := 0
	while Career.pending_user_bouts(w).is_empty() and guard < 30:
		guard += 1
		if not w.offers.is_empty() and guard > 2:
			if guard == 3:
				UIManager.goto("hub")
				await _shot("03_inicio_propostas")
				UIManager.push("offer", {"id": int(w.offers[0]["id"])})
				await _shot("04_proposta")
			Matchmaker.accept_offer(w, w.offers[0])
		Career.advance_week(w)
	UIManager.goto("hub")
	await _shot("05_inicio")
	UIManager.switch_area("team")
	await _shot("06_equipe")
	var me: Fighter = w.user_fighters()[0]
	UIManager.push("fighter", {"id": me.id})
	await _shot("07_perfil")
	UIManager.current().scroll().scroll_vertical = 700
	await _shot("07b_perfil_atributos")
	UIManager.switch_area("rankings")
	await _shot("08_rankings")
	UIManager.switch_area("market")
	await _shot("09_mercado")
	var ms := UIManager.current()
	ms.set("_tab", "staff")
	ms.refresh()
	await _shot("10_mercado_staff")
	UIManager.switch_area("gym")
	await _shot("11_academia")
	var pend := Career.pending_user_bouts(w)
	if pend.is_empty():
		print("sem luta pendente")
		get_tree().quit()
		return
	var b: Bout = pend[0]
	UIManager.switch_area("hub")
	UIManager.push("fight_plan", {"bout": b.id})
	await _shot("12_plano")
	UIManager.current().scroll().scroll_vertical = 2400
	await _shot("12b_plano_editor")
	UIManager.replace("fight", {"bout": b.id})
	var fs := UIManager.current()
	fs.set("_speed", 2)
	for i in 60:
		await get_tree().process_frame
	await _shot("13_luta")
	var t0 := Time.get_ticks_msec()
	while String(fs.get("_state")) == "round" and Time.get_ticks_msec() - t0 < 30000:
		fs.set("_clock", 99999.0)
		await get_tree().process_frame
	await _shot("14_intervalo_ou_fim")
	while String(fs.get("_state")) != "done" and Time.get_ticks_msec() - t0 < 60000:
		if String(fs.get("_state")) == "corner":
			var foot: VBoxContainer = fs.footer()
			(foot.get_child(0) as Button).pressed.emit()
		fs.set("_clock", 99999.0)
		await get_tree().process_frame
	await _shot("15_resultado")
	get_tree().quit()
