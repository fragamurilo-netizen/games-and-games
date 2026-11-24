extends Node
## Capturas da etapa "UI e HUD profissionais" (0.5): painel inicial dos dois papéis, caixa de
## entrada, HUD da luta com números ao vivo e ficha dos juízes.
## xvfb-run -a -s "-screen 0 1900x1900x24" godot --path . --resolution 780x1688 --script res://tools/design_shots.gd -- --runner=ui_shots_runner --out=DIR [--part=presidente|luta]
## Deitado: --resolution 1688x780. Tablet: --resolution 1280x800 com --tablet.

var out_dir := "user://shots"
var prefix := ""


func _ready() -> void:
	var part := "empresario"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--part="):
			part = a.substr(7)
		if a == "--tablet":
			UILayout.force_tablet = true
		if a.begins_with("--prefix="):
			prefix = a.substr(9)
	match part:
		"presidente":
			_president()
		"luta":
			_fight()
		_:
			_manager()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _shot(name: String) -> void:
	await _frames(6)
	var _pw := 0
	while Portraits.pending() > 0 and _pw < 1200:
		await get_tree().process_frame
		_pw += 1
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s%s.png" % [out_dir, prefix, name])
	print("[tela] ", name)


func _scroll_to(text: String, offset: int = 40) -> void:
	await _frames(3)
	var s := UIManager.current()
	var hit: Label = null
	for l: Node in s.find_children("*", "Label", true, false):
		if (l as Label).text.begins_with(text) and (l as Label).is_visible_in_tree():
			hit = l
	if hit == null:
		print("não achei: ", text)
		return
	s.scroll().scroll_vertical = int(hit.global_position.y - s.scroll().global_position.y + s.scroll().scroll_vertical) - offset


func _boot() -> void:
	GameManager.delete_save()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await _frames(8)


func _manager_world() -> GameWorld:
	var w := Career.new_career("Equipe Nova Era", "", "BRA", "Recife", Color("#B3262E"), Color("#F1F0EC"), 500000.0, 2027)
	var y := w.year()
	var m := w.month()
	var pros: Array = w.fighters.values().filter(func(f: Fighter) -> bool: return f.team_id < 0 and f.stage(y, m) == "profissional")
	pros.sort_custom(func(a: Fighter, b: Fighter) -> bool: return a.level() > b.level())
	var ams: Array = w.fighters.values().filter(func(f: Fighter) -> bool: return f.team_id < 0 and not f.is_pro())
	ams.sort_custom(func(a: Fighter, b: Fighter) -> bool: return a.potential > b.potential)
	w.user_team().balance += 900000.0
	for f: Fighter in [pros[3], pros[8], pros[20], pros[40], ams[0]]:
		f.team_id = w.user_team_id
		f.contract = {"cut": 0.2, "fights": 4}
		f.known = 0.45
		CareerStats.snapshot(w, f)
	for cand: Dictionary in w.staff_market.duplicate():
		if w.user_team().staff_of(String(cand["role"])).is_empty() and float(cand["quality"]) >= 45.0:
			StaffMarket.hire(w, cand)
	return w


func _manager() -> void:
	await _boot()
	var w := _manager_world()
	GameManager.start_career(w)
	for i in 40:
		# Aceita só parte das propostas, para sobrar pendência na caixa.
		for o: Dictionary in w.offers.duplicate():
			if w.offers.has(o) and (i % 3 != 0 or int(o["expires"]) <= w.week):
				Matchmaker.accept_offer(w, o)
		Career.advance_week(w, true)
		if i % 8 == 0:
			await get_tree().process_frame
	var guard := 0
	while guard < 30 and (w.offers.is_empty() or not Career.pending_user_bouts(w).is_empty()):
		guard += 1
		Career.advance_week(w, true)
	var mine := w.user_fighters()
	if mine.size() > 1:
		(mine[1] as Fighter).morale = 24.0
		(mine[1] as Fighter).talk_week = w.week - 10
	GameManager.save_now()
	UIManager.goto("hub")
	await _wait(1.2)
	await _shot("u01_inicio")
	await _scroll_to("Para resolver", 20)
	await _shot("u02_inicio_resolver_agenda")
	await _scroll_to("Equipe (", 20)
	await _shot("u03_inicio_equipe_noticias")
	UIManager.push("inbox")
	await _wait(0.8)
	await _shot("u04_caixa_pendentes")
	var s := UIManager.current()
	s.set("_view", "tudo")
	s.refresh()
	await _wait(0.4)
	await _shot("u05_caixa_tudo")
	UIManager.back()
	await _wait(0.5)
	_press("Avançar semana")
	await _wait(0.1)
	while DashKit.closing or GameManager.turning:
		await get_tree().process_frame
	await _wait(0.3)
	await _shot("u06_semana_virou")
	await _wait(1.6)
	print("[fim]")
	get_tree().quit()


func _president() -> void:
	await _boot()
	var w := Org.new_career("Liga Global de Combate", "LGC", "USA", Color("#B3262E"), Color("#F1F0EC"), 12000000.0, 2027)
	GameManager.start_career(w)
	for i in 34:
		Career.advance_week(w, true)
		if i % 8 == 0:
			await get_tree().process_frame
	var guard := 0
	while guard < 30 and Org.night_this_week(w) != null:
		guard += 1
		Career.advance_week(w, true)
	# Uma noite a 4 semanas com o card aberto, para a pendência do matchmaker aparecer.
	w.delegate_cards = false
	for ev: FightEvent in Org.upcoming_events(w):
		if ev.week - w.week >= 3 and ev.week - w.week <= 5:
			for b: Bout in Org.event_bouts(w, ev).slice(0, 4):
				Org.cancel(w, b)
			break
	GameManager.save_now()
	UIManager.goto("hub")
	await _wait(1.2)
	await _shot("p01_inicio")
	await _scroll_to("Para resolver", 20)
	await _shot("p02_inicio_resolver_agenda")
	await _scroll_to("Campeões", 20)
	await _shot("p03_inicio_campeoes_noticias")
	UIManager.push("inbox")
	await _wait(0.8)
	await _shot("p04_caixa_pendentes")
	var s := UIManager.current()
	s.set("_view", "tudo")
	s.refresh()
	await _wait(0.4)
	await _shot("p05_caixa_tudo")
	print("[fim]")
	get_tree().quit()


## Aperta o botão visível com este texto na tela atual (e marca, se for de alternar).
func _press(text: String) -> bool:
	var s := UIManager.current()
	for n: Node in s.find_children("*", "Button", true, false):
		var b := n as Button
		if b.text == text and b.is_visible_in_tree() and not b.is_queued_for_deletion():
			if b.toggle_mode:
				b.button_pressed = true
			b.pressed.emit()
			return true
	print("sem botão: ", text)
	return false


func _until(cond: Callable, max_s: float) -> void:
	var t0 := Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t0 < int(max_s * 1000.0):
		await get_tree().process_frame


## Procura uma luta pendente da equipe cujo desfecho (simulado à parte, sem mexer no mundo)
## serve para a captura; as outras semanas passam sozinhas.
func _find_bout(w: GameWorld, want: Callable) -> Bout:
	for g in 160:
		for b: Bout in Career.pending_user_bouts(w):
			var e := Career.engine_for(w, b, true)
			var res := e.run_all()
			if want.call(res):
				return b
		for o: Dictionary in w.offers.duplicate():
			if w.offers.has(o):
				Matchmaker.accept_offer(w, o)
		Career.advance_week(w, true)
		if g % 8 == 0:
			await get_tree().process_frame
	return null


## Corre o round atual até o fim (como o botão "Pular").
func _skip_round(fs: BaseScreen) -> void:
	var t0 := Time.get_ticks_msec()
	var n := int(fs.get("_e").round_no)
	while String(fs.get("_state")) == "round" and int(fs.get("_e").round_no) == n and Time.get_ticks_msec() - t0 < 30000:
		fs.set("_clock", 99999.0)
		fs.set("_skip", true)
		await get_tree().process_frame


func _next_round(fs: BaseScreen) -> void:
	var foot: VBoxContainer = fs.footer()
	for n: Node in foot.find_children("*", "Button", true, false):
		if not n.is_queued_for_deletion() and (n as Button).text.begins_with("Começar"):
			(n as Button).pressed.emit()
			return


func _fight() -> void:
	await _boot()
	var w := _manager_world()
	GameManager.start_career(w)
	AppSettings.fight_view = "2d"
	AppSettings.fight_speed = 1
	# 1. Uma luta que vai para os juízes: lances, números, placar, intervalo e a decisão.
	var b: Bout = await _find_bout(w, func(res: Dictionary) -> bool: return String(res.get("method", "")) == "DEC")
	if b == null:
		print("sem luta por decisão")
		get_tree().quit()
		return
	GameManager.save_now()
	UIManager.goto("hub")
	UIManager.push("fight", {"bout": b.id})
	var fs := UIManager.current()
	await _until(func() -> bool: return float(fs.get("_clock")) > 95.0, 60.0)
	await _shot("f01_luta_lances")
	_press("Números")
	await _wait(0.5)
	await _shot("f02_luta_numeros")
	await _skip_round(fs)
	await _wait(0.9)
	await _shot("f03_intervalo")
	await _scroll_to("Placar da transmissão", 20)
	await _shot("f04_intervalo_placar")
	await _next_round(fs)
	await _until(func() -> bool: return float(fs.get("_clock")) > 150.0, 60.0)
	_press("Placar")
	await _wait(0.5)
	await _shot("f05_luta_placar")
	_press("Números")
	await _wait(0.2)
	_press("2º round")
	await _wait(0.5)
	await _shot("f06_luta_numeros_round")
	var t0 := Time.get_ticks_msec()
	while String(fs.get("_state")) != "done" and Time.get_ticks_msec() - t0 < 90000:
		if String(fs.get("_state")) == "corner":
			await _next_round(fs)
		await _skip_round(fs)
		await get_tree().process_frame
	await _wait(1.9)
	await _shot("f07_decisao_juiz_por_juiz")
	await _wait(4.0)
	await _shot("f08_decisao")
	await _scroll_to("Números da luta", 20)
	await _shot("f09_numeros_da_luta")
	_press("Continuar")
	await _wait(0.8)
	# 2. Uma que acaba antes da hora, depois do primeiro round: "Como estava nos cartões".
	var k: Bout = await _find_bout(w, func(res: Dictionary) -> bool: return String(res.get("method", "")) in ["KO", "TKO", "FIN"] and int(res.get("round", 1)) >= 2)
	if k != null:
		GameManager.save_now()
		UIManager.goto("hub")
		UIManager.push("fight", {"bout": k.id})
		fs = UIManager.current()
		t0 = Time.get_ticks_msec()
		while String(fs.get("_state")) != "done" and Time.get_ticks_msec() - t0 < 90000:
			if String(fs.get("_state")) == "corner":
				await _next_round(fs)
			await _skip_round(fs)
			await get_tree().process_frame
		await _wait(1.2)
		await _shot("f10_nocaute")
		await _scroll_to("Como estava nos cartões", 20)
		await _shot("f11_nocaute_cartoes")
	print("[fim]")
	get_tree().quit()
