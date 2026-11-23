extends Node
## Capturas do modo presidente numa carreira de teste: nova carreira, Início, Eventos, card,
## marcar luta (escolha, adversário, oferta), a noite de luta assistida (luta, intervalo,
## resultado), bônus, contas, Cinturões, Resultados, Organização e o perfil com "Seguir".

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
	UIManager.push("new_career")
	var nc := UIManager.current()
	nc.set("_role", "presidente")
	nc.set("_name", "Liga Global de Combate")
	nc.refresh()
	await _shot("p01_nova_carreira")
	var w := Org.new_career("Liga Global de Combate", "LGC", "USA", Color("#B3262E"), Color("#F1F0EC"), Org.START_FUNDS[1], 2027)
	GameManager.start_career(w)
	UIManager.goto("hub")
	await _shot("p02_inicio")
	UIManager.switch_area("events")
	await _shot("p03_eventos")
	# Uma noite ainda aberta, longe o bastante para marcar luta.
	var ev: FightEvent = null
	for e: FightEvent in Org.upcoming_events(w):
		if e.week - w.week >= 4 and Org.event_bouts(w, e).size() < e.slots:
			ev = e
			break
	if ev == null:
		print("sem noite aberta")
		get_tree().quit()
		return
	UIManager.push("org_event", {"id": ev.id})
	await _shot("p04_card")
	# Marcar: o campeão de alguma categoria contra um dos primeiros.
	var champ: Fighter = null
	var div := ""
	for d: Dictionary in DataDB.divisions():
		var c := w.fighter(int(w.champions.get(String(d["id"]), -1)))
		if c != null and c.bout_id < 0 and Matchmaker.ready_to_book(w, c, ev.week - w.week):
			champ = c
			div = String(d["id"])
			break
	UIManager.push("book", {"event": ev.id, "div": div})
	await _shot("p05_marcar_escolha")
	var bk := UIManager.current()
	if champ != null:
		bk.set("_a", champ.id)
		bk.refresh()
		await _shot("p06_marcar_adversario")
		var sugg := Org.suggestions(w, ev, champ, 3)
		if not sugg.is_empty():
			bk.call("_offer_sheet", w, ev, champ, sugg[0])
			await _shot("p07_oferta")
			UIManager.close_modal()
			Org.offer_bout(w, ev, champ, sugg[0], true, true, 1.5)
	UIManager.back()
	Org.auto_fill(w, ev)
	UIManager.current().refresh()
	await _shot("p08_card_cheio")
	# Avança até a semana da noite.
	var guard := 0
	while w.week < ev.week and guard < 12:
		guard += 1
		var n := Org.night_this_week(w)
		if n != null and n != ev:
			for b: Bout in Org.pending_bouts(w):
				Career.simulate(w, b)
			Org.close_event(w, n, Org.auto_bonuses(w, n))
		GameManager.advance_week()
	# Semana da luta: uma lesão e um lutador fora do peso, para as telas de decisão.
	var prelim := Org.event_bouts(w, ev).filter(func(b: Bout) -> bool: return not b.main_event and b.status == "marcada")
	if prelim.size() >= 2:
		var bi: Bout = prelim[0]
		var hurt := w.fighter(bi.b)
		hurt.injury = {"name": "Costela trincada", "weeks": 6}
		FightWeek.injury(w, bi, hurt, "Costela trincada", "no camp")
		var bw: Bout = prelim[1]
		var lim := float(DataDB.division(bw.division).get("limit_kg", 70.0)) + 0.5
		bw.weigh = {"kg": [lim + 1.4, lim - 0.2], "missed": [bw.a], "mods": [{}, {}], "cut": [0.1, 0.1]}
		FightWeek._weigh(w, ev, bw)
	UIManager.goto("hub")
	await _shot("p09a_inicio_problemas")
	var incs := FightWeek.pending(w, ev)
	for inc: Dictionary in incs:
		WeekKit.open_incident(w, inc, func(): pass)
		await _shot("p09b_decidir_" + String(inc["kind"]))
		UIManager.close_modal()
	for inc: Dictionary in incs:
		if String(inc["kind"]) == "lesao":
			var subs := FightWeek.substitutes(w, inc, 3)
			var ok := false
			for sf: Fighter in subs:
				if bool(FightWeek.offer_sub(w, inc, sf)["ok"]):
					ok = true
					break
			if not ok:
				FightWeek.cancel_injury(w, inc, true)
		else:
			if not bool(FightWeek.catchweight(w, inc, true)["ok"]):
				FightWeek.cancel_weight(w, inc)
	UIManager.goto("hub")
	await _shot("p09_inicio_noite")
	UIManager.push("night", {"id": ev.id})
	await _shot("p10_noite")
	# Simula as preliminares e assiste à principal.
	var lst := Org.event_bouts(w, ev)
	for b: Bout in lst.slice(0, lst.size() - 1):
		Career.simulate(w, b)
	var main_b: Bout = lst.back()
	UIManager.current().refresh()
	await _shot("p11_noite_preliminares")
	UIManager.push("fight", {"bout": main_b.id, "spectator": true})
	var fs := UIManager.current()
	fs.set("_speed", 2)
	for i in 60:
		await get_tree().process_frame
	await _shot("p12_luta_ao_vivo")
	var t0 := Time.get_ticks_msec()
	while String(fs.get("_state")) == "round" and Time.get_ticks_msec() - t0 < 30000:
		fs.set("_clock", 99999.0)
		await get_tree().process_frame
	await _shot("p13_intervalo")
	while String(fs.get("_state")) != "done" and Time.get_ticks_msec() - t0 < 60000:
		if String(fs.get("_state")) == "corner":
			var foot: VBoxContainer = fs.footer()
			(foot.get_child(0) as Button).pressed.emit()
		fs.set("_clock", 99999.0)
		await get_tree().process_frame
	await _shot("p14_resultado")
	UIManager.back()
	await _frames(4)
	UIManager.current().refresh()
	await _shot("p15_noite_completa")
	UIManager.current().call("_bonus_sheet", w, ev)
	await _shot("p16_bonus")
	UIManager.close_modal()
	Org.close_event(w, ev, Org.auto_bonuses(w, ev))
	UIManager.current().refresh()
	await _shot("p17_contas")
	var sc: Node = UIManager.current()
	var opts := FightWeek.presser_options(w, ev)
	if not opts.is_empty():
		FightWeek.presser_pick(w, ev, opts[0])
		sc.refresh()
	await _frames(4)
	var scr: ScrollContainer = sc.call("scroll")
	if scr != null:
		scr.scroll_vertical = 520
	await _frames(4)
	await _shot("p17b_coletiva")
	UIManager.goto("hub")
	UIManager.switch_area("titles")
	await _shot("p18_cinturoes")
	UIManager.switch_area("org")
	await _shot("p19_organizacao")
	UIManager.switch_area("hub")
	UIManager.push("results")
	await _shot("p20_resultados")
	var star := w.fighter(main_b.a)
	w.toggle_follow(star)
	UIManager.push("fighter", {"id": main_b.b})
	await _shot("p21_perfil")
	UIManager.goto("hub")
	await _shot("p22_inicio_seguindo")
	get_tree().quit()
