extends Node
## Capturas da etapa "atletas de verdade" (0.3): moral e conversa, potencial e olheiro, carreira
## (evolução, números, marcos, lutas), camp, mercado com indicações, plano de luta e resultado.
## xvfb-run -a -s "-screen 0 1900x1900x24" godot --path . --resolution 780x1688 --script res://tools/design_shots.gd -- --runner=athletes_shots_runner --out=DIR

var out_dir := "user://shots"
var prefix := ""


func _ready() -> void:
	_run()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


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
	for l: Node in s.find_children("*", "Label", true, false):
		if (l as Label).text == text and (l as Label).is_visible_in_tree():
			s.scroll().scroll_vertical = int((l as Label).global_position.y - s.scroll().global_position.y + s.scroll().scroll_vertical) - offset
			return
	print("não achei: ", text)


func _run() -> void:
	GameManager.delete_save()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await _frames(8)
	var w := Career.new_career("Equipe Nova Era", "", "BRA", "Recife", Color("#B3262E"), Color("#F1F0EC"), 500000.0, 2027)
	var y := w.year()
	var m := w.month()
	var pros: Array = w.fighters.values().filter(func(f: Fighter) -> bool: return f.team_id < 0 and f.stage(y, m) == "profissional")
	pros.sort_custom(func(a: Fighter, b: Fighter) -> bool: return a.level() > b.level())
	var ams: Array = w.fighters.values().filter(func(f: Fighter) -> bool: return f.team_id < 0 and not f.is_pro())
	ams.sort_custom(func(a: Fighter, b: Fighter) -> bool: return a.potential > b.potential)
	w.user_team().balance += 1500000.0
	for f: Fighter in [pros[4], pros[9], ams[0]]:
		f.team_id = w.user_team_id
		f.contract = {"cut": 0.2, "fights": 8}
		f.known = 0.45
		CareerStats.snapshot(w, f)
	for cand: Dictionary in w.staff_market.duplicate():
		if w.user_team().staff_of(String(cand["role"])).is_empty() and float(cand["quality"]) >= 45.0:
			StaffMarket.hire(w, cand)
	for role: String in StaffMarket.ORDER:
		if w.user_team().staff_of(role).is_empty():
			for cand: Dictionary in w.staff_market.duplicate():
				if String(cand["role"]) == role and w.user_team().staff_of(role).is_empty():
					StaffMarket.hire(w, cand)
	GameManager.start_career(w)
	var star: Fighter = w.user_fighters()[0]
	# Um ano de carreira para ter história: lutas, marcos, curva e indicações do olheiro.
	for i in 46:
		for o: Dictionary in w.offers.duplicate():
			if w.offers.has(o):
				Matchmaker.accept_offer(w, o)
		for f: Fighter in w.user_fighters():
			if not f.camp.is_empty() and int(f.camp.get("weeks", 0)) == 0:
				f.camp["spar"] = true
		Career.advance_week(w, true)
		if i % 8 == 0:
			await get_tree().process_frame
	# Até o melhor da equipe ter luta marcada com o camp no meio.
	var guard := 0
	while guard < 40:
		guard += 1
		var b := Camp.bout_of(w, star)
		if b != null and b.week - w.week <= 4 and b.week - w.week >= 2:
			break
		for o: Dictionary in w.offers.duplicate():
			if w.offers.has(o):
				Matchmaker.accept_offer(w, o)
		Career.advance_week(w, true)
	print("estrela: ", star.display_name(), " ", star.record_text(), " moral ", int(star.morale), " camp ", star.camp)
	UIManager.goto("hub")
	await _shot("a01_inicio")
	UIManager.push("fighter", {"id": star.id})
	await _shot("a02_ficha_moral")
	await _scroll_to("Potencial")
	await _shot("a03_potencial")
	UIManager.current().scroll().scroll_vertical = 0
	TalkSheet.open(w, star, func(): UIManager.current().refresh())
	await _shot("a04_conversa")
	UIManager.close_modal()
	var r := Morale.talk(w, star, "elogiar")
	UIManager.info("Elogiar", "%s A moral subiu (%s)." % [String(r["text"]), Fmt.signed(int(r["delta"]))])
	await _shot("a05_resposta")
	UIManager.close_modal()
	UIManager.replace("fighter", {"id": star.id, "tab": "carreira"})
	await _shot("a06_carreira")
	await _scroll_to("Evolução")
	await _shot("a07_evolucao")
	await _scroll_to("Números da carreira")
	await _shot("a08_numeros")
	await _scroll_to("Marcos da carreira")
	await _shot("a09_marcos")
	await _scroll_to("Lutas no jogo", 20)
	await _shot("a10_lutas")
	# Quem mais juntou marcos com data no jogo (de qualquer equipe): o cartão com as medalhas.
	var best: Fighter = null
	var best_n := 0
	for f: Fighter in w.fighters.values():
		var n := f.marks.filter(func(mk: Array) -> bool: return int(mk[1]) >= 0).size()
		if n > best_n and not f.retired:
			best_n = n
			best = f
	if best != null:
		UIManager.push("fighter", {"id": best.id, "tab": "carreira"})
		await _scroll_to("Marcos da carreira")
		await _shot("a20_marcos_datados")
		UIManager.back()
		await _frames(4)
	UIManager.replace("fighter", {"id": star.id, "tab": "treino"})
	await _shot("a11_camp")
	await _scroll_to("Onde")
	await _shot("a12_camp_escolhas")
	# Um lutador de fora: potencial pela faixa e o olheiro.
	var finds := Scouting.finds(w)
	var target: Fighter = (finds.back() as Array)[0] if not finds.is_empty() else ams[3]
	UIManager.pop_to_root()
	UIManager.switch_area("market")
	await _shot("a13_mercado_indicacoes")
	UIManager.push("fighter", {"id": target.id})
	await _scroll_to("Potencial")
	await _shot("a14_olheiro")
	print("observar: ", Scouting.assign(w, target))
	UIManager.current().refresh()
	await _scroll_to("Potencial")
	await _shot("a15_observando")
	UIManager.replace("fighter", {"id": target.id, "tab": "carreira"})
	await _scroll_to("Evolução")
	await _shot("a16_evolucao_prospecto")
	# Semana da luta: plano com o camp dos dois e o resultado com marcos e moral.
	UIManager.pop_to_root()
	guard = 0
	while Career.pending_user_bouts(w).is_empty() and guard < 12:
		guard += 1
		Career.advance_week(w, true)
	var pend := Career.pending_user_bouts(w)
	if pend.is_empty():
		print("sem luta pendente")
		get_tree().quit()
		return
	var b2: Bout = pend[0]
	UIManager.switch_area("hub")
	UIManager.push("fight_plan", {"bout": b2.id})
	await _scroll_to("Como chegam")
	await _shot("a17_plano_camp")
	var e := Career.engine_for(w, b2, true)
	var res := e.run_all()
	Career.resolve(w, b2, res, e)
	UIManager.replace("fight", {"bout": b2.id})
	await _shot("a18_resultado")
	UIManager.goto("hub")
	UIManager.switch_area("team")
	await _shot("a19_equipe")
	get_tree().quit()
