extends Node
## Capturas da etapa "montagem dos eventos" (0.4). Presidente: termômetro de hype, card em
## blocos, ficha da luta, sede e ingressos, contrato de TV, oferta com cinturão interino.
## Empresário: proposta com termômetro, negociação, desafio com pedido de bolsa, rivais no
## perfil, card do evento e cinturões com interino.
## xvfb-run -a -s "-screen 0 1900x1900x24" godot --path . --resolution 780x1688 --script res://tools/design_shots.gd -- --runner=events_shots_runner --out=DIR [--part=empresario]

var out_dir := "user://shots"
var prefix := ""


func _ready() -> void:
	if OS.get_cmdline_user_args().has("--part=empresario"):
		_manager()
	else:
		_president()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await _frames(6)
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


## Joga a semana como um presidente que cuida do card: disputa de cinturão na próxima noite
## com tempo e o resto pelo matchmaker.
func _play_week(w: GameWorld) -> void:
	var evs := Org.upcoming_events(w).filter(func(e: FightEvent) -> bool: return e.week - w.week >= 3)
	if not evs.is_empty():
		var ev: FightEvent = evs[0]
		for d: Dictionary in DataDB.divisions():
			var div := String(d["id"])
			if Card.has_belt(w, ev) or Org.event_bouts(w, ev).size() >= ev.slots:
				break
			if Org.title_booked(w, div) != null:
				continue
			var champ := w.fighter(int(w.champions.get(div, -1)))
			if champ == null or champ.bout_id >= 0 or not Matchmaker.ready_to_book(w, champ, ev.week - w.week):
				continue
			for cid: int in (w.rankings.get(div, []) as Array).slice(0, 3):
				var c := w.fighter(cid)
				if Org.book_reason(w, ev, champ, c) == "" and Org.title_reason(w, champ, c) == "" and bool(Org.offer_bout(w, ev, champ, c, true, true, 1.25)["ok"]):
					break
	Career.advance_week(w, true)


func _president() -> void:
	GameManager.delete_save()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await _frames(8)
	var w := Org.new_career("Liga Global de Combate", "LGC", "USA", Color("#B3262E"), Color("#F1F0EC"), Org.START_FUNDS[1], 2027)
	GameManager.start_career(w)
	# Até as propostas de TV chegarem.
	var guard := 0
	while not TVDeal.pending(w) and guard < 40:
		guard += 1
		_play_week(w)
		if guard % 6 == 0:
			await get_tree().process_frame
	UIManager.goto("hub")
	await _shot("e01_inicio_tv")
	UIManager.push("tv")
	await _shot("e02_tv_contrato")
	await _scroll_to("Propostas na mesa")
	await _shot("e03_tv_propostas")
	if not w.tv_offers.is_empty():
		var o: Dictionary = w.tv_offers[0]
		var r := TVDeal.ask(w, o, 0.1)
		print("pedido de TV: ", r["text"])
		UIManager.current().refresh()
		await _frames(3)
		UIManager.toast(String(r["text"]), UIColors.GREEN if bool(r["ok"]) else UIColors.RED)
		await _scroll_to("Propostas na mesa")
		await _shot("e04_tv_pedido")
		await get_tree().create_timer(4.5).timeout
	if not w.tv_offers.is_empty():
		var best: Dictionary = w.tv_offers[0]
		for o2: Dictionary in w.tv_offers:
			if String(o2["partner"]) == "aberta":
				best = o2
		TVDeal.sign(w, best)
	UIManager.back()
	# Mais uns meses para o mundo criar história (rivalidades, revanches).
	for i in 30:
		_play_week(w)
		if i % 6 == 0:
			await get_tree().process_frame
	# A noite a montar: a primeira com pelo menos cinco semanas pela frente.
	var ev: FightEvent = null
	for e: FightEvent in Org.upcoming_events(w):
		if e.week - w.week >= 5:
			ev = e
			break
	if ev == null:
		print("sem noite para montar")
		get_tree().quit()
		return
	for b: Bout in Org.event_bouts(w, ev):
		Org.cancel(w, b)
	UIManager.goto("hub")
	UIManager.push("org_event", {"id": ev.id})
	await _shot("e05_noite_vazia")
	# Campeão machucado numa categoria: abre o cinturão interino.
	var div_out := ""
	for d: Dictionary in DataDB.divisions():
		var div := String(d["id"])
		var c := w.fighter(int(w.champions.get(div, -1)))
		if c != null and c.bout_id < 0 and Titles.interim_of(w, div) == null and Titles.booked(w, div) == null:
			c.injury = {"name": "Lesão no joelho", "weeks": 18}
			div_out = div
			break
	var lst_out: Array = w.rankings.get(div_out, [])
	var ia: Fighter = null
	var ib: Fighter = null
	for i in mini(8, lst_out.size()):
		var f := w.fighter(int(lst_out[i]))
		if f.bout_id >= 0 or not Matchmaker.ready_to_book(w, f, ev.week - w.week):
			continue
		if ia == null:
			ia = f
		elif Org.book_reason(w, ev, ia, f) == "" and Titles.interim_reason(w, ia, f) == "":
			ib = f
			break
	UIManager.push("book", {"event": ev.id, "div": div_out})
	await _shot("e06_marcar_interino_aviso")
	var bk := UIManager.current()
	if ia != null and ib != null:
		bk.set("_a", ia.id)
		bk.refresh()
		await _shot("e07_marcar_adversarios")
		bk.call("_offer_sheet", w, ev, ia, ib)
		await _shot("e08_oferta_interino")
		UIManager.close_modal()
		var tries := 0
		while tries < 6 and not bool(Org.offer_bout(w, ev, ia, ib, false, true, 1.5, true)["ok"]):
			tries += 1
			w.bout_block.clear()
	UIManager.back()
	# Uma disputa de cinturão de verdade e o resto pelo matchmaker.
	for d: Dictionary in DataDB.divisions():
		var div := String(d["id"])
		if div == div_out or Org.title_booked(w, div) != null:
			continue
		var champ := w.fighter(int(w.champions.get(div, -1)))
		if champ == null or champ.bout_id >= 0 or not Matchmaker.ready_to_book(w, champ, ev.week - w.week):
			continue
		var done := false
		for cid: int in (w.rankings.get(div, []) as Array).slice(0, 3):
			var c := w.fighter(cid)
			if Org.book_reason(w, ev, champ, c) == "" and Org.title_reason(w, champ, c) == "" and bool(Org.offer_bout(w, ev, champ, c, true, true, 1.5)["ok"]):
				done = true
				break
		if done:
			break
	Org.auto_fill(w, ev)
	UIManager.current().refresh()
	await _shot("e09_noite_termometro")
	await _scroll_to("Sede e ingressos", 30)
	await _shot("e10_noite_sede_contas")
	await _scroll_to("Luta principal", 30)
	await _shot("e11_card_blocos")
	await _scroll_to("Preliminares · %s" % Fmt.plural(maxi(0, Org.event_bouts(w, ev).size() - Card.main_card_size(ev)), "luta", "lutas"), 420)
	await _shot("e12_card_blocos_2")
	var lst := Org.event_bouts(w, ev)
	if lst.size() >= 3:
		UIManager.current().call("_bout_sheet", w, ev, lst[lst.size() - 2])
		await _shot("e13_ficha_da_luta")
		UIManager.close_modal()
	UIManager.push("venue", {"id": ev.id})
	await _shot("e14_sede_resumo")
	await _scroll_to("Preço do ingresso", 30)
	await _shot("e15_sede_preco_arena")
	await _scroll_to("Sede", 30)
	await _shot("e16_sede_cidades")
	UIManager.current().scroll().scroll_vertical = 0
	Venue.set_type(w, ev, "estadio")
	Venue.set_ticket(w, ev, 3)
	UIManager.current().refresh()
	await _shot("e17_sede_estadio_premium")
	Venue.set_type(w, ev, "arena")
	Venue.set_ticket(w, ev, 2)
	UIManager.back()
	UIManager.goto("hub")
	UIManager.switch_area("events")
	await _shot("e18_eventos")
	UIManager.switch_area("org")
	await _scroll_to("Contrato de TV", 30)
	await _shot("e19_organizacao_tv")
	var past := Org.past_events(w)
	if not past.is_empty():
		UIManager.switch_area("hub")
		UIManager.push("org_event", {"id": (past[0] as FightEvent).id})
		await _shot("e20_noite_fechada")
	UIManager.goto("hub")
	UIManager.switch_area("titles")
	await _shot("e21_cinturoes")
	get_tree().quit()


func _manager() -> void:
	GameManager.delete_save()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await _frames(8)
	var w := Career.new_career("Equipe Nova Era", "", "BRA", "Recife", Color("#B3262E"), Color("#F1F0EC"), 500000.0, 2027)
	var y := w.year()
	var m := w.month()
	var pros: Array = w.fighters.values().filter(func(f: Fighter) -> bool: return f.team_id < 0 and f.stage(y, m) == "profissional")
	pros.sort_custom(func(a: Fighter, b: Fighter) -> bool: return a.level() > b.level())
	w.user_team().balance += 3000000.0
	for f: Fighter in [pros[0], pros[3], pros[8], pros[20]]:
		f.team_id = w.user_team_id
		f.contract = {"cut": 0.2, "fights": 12}
		f.known = 0.6
		CareerStats.snapshot(w, f)
	for role: String in StaffMarket.ORDER:
		for cand: Dictionary in w.staff_market.duplicate():
			if String(cand["role"]) == role and w.user_team().staff_of(role).is_empty():
				StaffMarket.hire(w, cand)
	GameManager.start_career(w)
	# Joga até chegar uma proposta de cinturão (ou, sem sorte, uma proposta qualquer).
	var pick: Dictionary = {}
	var guard := 0
	while guard < 90:
		guard += 1
		for o: Dictionary in w.offers:
			if bool(o.get("title", false)) or bool(o.get("interim", false)):
				pick = o
		if not pick.is_empty() and guard > 30:
			break
		pick = {}
		for o: Dictionary in w.offers.duplicate():
			if not w.offers.has(o):
				continue
			var f := w.fighter(int(o["fighter"]))
			if not bool(o.get("title", false)) and Matchmaker.shot_promised(w, f):
				continue
			Matchmaker.accept_offer(w, o)
		Career.advance_week(w, true)
		if guard % 6 == 0:
			await get_tree().process_frame
	if pick.is_empty() and not w.offers.is_empty():
		pick = w.offers[0]
	print("proposta: ", pick)
	UIManager.goto("hub")
	await _shot("m01_inicio_propostas")
	if not pick.is_empty():
		UIManager.push("offer", {"id": int(pick["id"])})
		await _shot("m02_proposta")
		await _scroll_to("Hype da luta", 30)
		await _shot("m03_proposta_hype_bolsa")
		UIManager.current().call("_negotiate", w, pick)
		await _shot("m04_negociar")
		UIManager.close_modal()
		var r := Negotiation.ask(w, pick, "bolsa15")
		print("pedido: ", r)
		if not bool(r["gone"]):
			UIManager.current().refresh()
			await _frames(3)
			UIManager.toast(String(r["text"]), UIColors.GREEN if bool(r["ok"]) else UIColors.RED)
			await _scroll_to("Bolsa", 200)
			await _shot("m05_resposta")
			await get_tree().create_timer(4.5).timeout
			UIManager.current().call("_negotiate", w, pick)
			await _shot("m06_negociar_de_novo")
			UIManager.close_modal()
		UIManager.back()
	# Desafio: um lutador livre da equipe chama alguém logo acima.
	for f: Fighter in w.user_fighters():
		if f.bout_id >= 0 or not f.is_pro():
			continue
		var lst: Array = w.rankings.get(f.division, [])
		var r2 := w.rank_of(f)
		var target: Fighter = null
		for i in range(maxi(0, r2 - 5), lst.size()):
			var o := w.fighter(int(lst[i]))
			if o != null and o.id != f.id and Matchmaker.challenge_block_reason(w, f, o) == "":
				target = o
				break
		if target != null:
			UIManager.push("challenge", {"target": target.id, "mine": f.id})
			UIManager.current().set("_ask", 1)
			UIManager.current().refresh()
			await _shot("m07_desafio")
			await _scroll_to("Hype da luta", 30)
			await _shot("m08_desafio_hype")
			UIManager.back()
			break
	# Perfil com rivais: da equipe se houver, senão o mais quente do mundo.
	var who: Fighter = null
	for f: Fighter in w.user_fighters():
		if not Rivalry.of(w, f).is_empty() and (who == null or Rivalry.of(w, f).size() > Rivalry.of(w, who).size()):
			who = f
	if who == null:
		var best := 0.0
		for k: String in w.rivalries:
			if float(w.rivalries[k]["heat"]) > best:
				best = float(w.rivalries[k]["heat"])
				who = w.fighter(int(k.split(":")[0]))
	if who != null:
		UIManager.push("fighter", {"id": who.id})
		await _scroll_to("Rivais", 30)
		await _scroll_to("Rivais e cinturão", 30)
		await _shot("m09_rivais")
		UIManager.back()
	# A próxima noite da liga com card e o termômetro dela.
	var night: FightEvent = null
	for ev: FightEvent in w.events.values():
		if ev.tier == 2 and ev.week > w.week and ev.bouts.size() >= 6 and (night == null or ev.week < night.week):
			night = ev
	if night != null:
		UIManager.push("event", {"id": night.id})
		await _shot("m10_card_termometro")
		await _scroll_to("Co-principal", 200)
		await _shot("m11_card_blocos")
		var bl := Card.bouts(w, night)
		UIManager.current().call("_bout_sheet", w, night, bl.back())
		await _shot("m12_ficha_da_luta")
		UIManager.close_modal()
		UIManager.back()
	# Campeão machucado: a liga marca o interino sozinha.
	var div_out := ""
	for d: Dictionary in DataDB.divisions():
		var div := String(d["id"])
		var c := w.fighter(int(w.champions.get(div, -1)))
		if c != null and c.bout_id < 0 and not w.is_user_fighter(c) and Titles.interim_of(w, div) == null and Titles.booked(w, div) == null:
			c.injury = {"name": "Lesão no joelho", "weeks": 20}
			div_out = div
			break
	var tries := 0
	while div_out != "" and Titles.booked(w, div_out) == null and tries < 5:
		tries += 1
		Career.advance_week(w, true)
	UIManager.goto("hub")
	UIManager.switch_area("titles")
	if div_out != "":
		await _scroll_to(Matchmaker.division_title(div_out), 30)
	await _shot("m13_cinturoes_interino")
	get_tree().quit()
