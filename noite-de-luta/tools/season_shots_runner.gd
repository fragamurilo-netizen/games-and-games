extends "res://tools/ui_shots_runner.gd"
## Capturas da etapa "Viciar" (0.6): primeiros passos e dicas, cartão da temporada no Início,
## tela da temporada (metas, cidade ou sócios, conquistas, anos), cerimônia de fim de ano,
## avisos de conquista, ultimato e fim de mandato.
## xvfb-run -a -s "-screen 0 1900x1900x24" godot --path . --resolution 780x1688 --script res://tools/design_shots.gd -- --runner=season_shots_runner --out=DIR [--part=presidente]
## Deitado: --resolution 1688x780. Tablet: --resolution 1280x800 com --tablet.


func _ready() -> void:
	var part := "empresario"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--part="):
			part = a.substr(7)
		if a == "--tablet":
			UILayout.force_tablet = true
		if a.begins_with("--prefix="):
			prefix = a.substr(9)
	if part == "presidente":
		_season_president()
	else:
		_season_manager()


func _tab(key: String) -> void:
	var s := UIManager.current()
	s.set("_tab", key)
	s.set("intro_pending", false)
	s.refresh()
	s.scroll().scroll_vertical = 0
	await _wait(0.5)


## Avança as semanas por fora da interface até faltar uma para a virada do ano.
func _to_year_end(w: GameWorld, turn: Callable) -> void:
	var guard := 0
	while guard < 60 and SeasonKit.weeks_left(w) > 1:
		guard += 1
		turn.call()
		Career.advance_week(w, true)
		if guard % 8 == 0:
			await get_tree().process_frame
	w.pops.clear()


## Vira a semana pelo botão do Início (ou por fora, se a semana tem luta para assistir).
func _turn_week(w: GameWorld) -> void:
	UIManager.goto("hub")
	await _wait(0.8)
	if not _press("Avançar semana"):
		Career.advance_week(w, true)
		UIManager.current().refresh()
		SeasonKit.after_week(w, UIManager.current().refresh)
	await _wait(0.1)
	while DashKit.closing or GameManager.turning:
		await get_tree().process_frame
	await _wait(1.4)


## Passa pelas etapas da cerimônia, uma captura por etapa (e a segunda dobra onde houver).
func _gala(tag: String) -> void:
	var s := UIManager.current()
	var n := 1
	for i in 6:
		var pages: Array = s.get("_pages")
		var page := String(pages[int(s.get("_page"))])
		await _wait(1.3)
		await _shot("%s%02d_gala_%s" % [tag, n, page])
		n += 1
		if s.scroll().get_v_scroll_bar().max_value > s.scroll().size.y + 200.0:
			s.scroll().scroll_vertical = int(s.scroll().get_v_scroll_bar().max_value)
			await _wait(0.3)
			await _shot("%s%02d_gala_%s_fim" % [tag, n, page])
			n += 1
		if int(s.get("_page")) >= pages.size() - 1:
			break
		_press("Continuar")
	for b: Node in s.footer().find_children("*", "Button", true, false):
		if not b.is_queued_for_deletion():
			(b as Button).pressed.emit()
			break
	await _wait(1.0)


func _season_manager() -> void:
	await _boot()
	# 1. Carreira nova: primeiros passos e a dica de primeira vez.
	var w0 := Career.new_career("Equipe Nova Era", "", "BRA", "Recife", Color("#B3262E"), Color("#F1F0EC"), 250000.0, 2027)
	GameManager.start_career(w0)
	UIManager.goto("hub")
	await _wait(1.2)
	await _shot("s01_inicio_primeiros_passos")
	UIManager.switch_area("market")
	await _wait(0.9)
	await _shot("s02_mercado_dica")
	var free: Array = w0.fighters.values().filter(func(f: Fighter) -> bool: return f.team_id < 0 and not f.retired and Signing.block_reason(w0, f) == "")
	free.sort_custom(func(a: Fighter, b: Fighter) -> bool: return Signing.chance(w0, a, 0.2, 5, 0.0) > Signing.chance(w0, b, 0.2, 5, 0.0))
	for f: Fighter in free.slice(0, 12):
		if not w0.user_fighters().is_empty():
			break
		Signing.offer(w0, f, 0.2, 5, 0.0)
	print("contratados: ", w0.user_fighters().size())
	UIManager.switch_area("hub")
	await _wait(0.9)
	await _shot("s03_inicio_passo_concluido")
	await _wait(3.4)
	# 2. Equipe montada, quarenta semanas de temporada.
	var w := _manager_world()
	Tutorial.skip(w)
	# As metas saem com a equipe já montada (na carreira de verdade, o ano começa do zero).
	w.goals = {}
	Season.ensure(w)
	GameManager.start_career(w)
	var accept := func() -> void:
		for o: Dictionary in w.offers.duplicate():
			if w.offers.has(o):
				Matchmaker.accept_offer(w, o)
	for i in 40:
		accept.call()
		Career.advance_week(w, true)
		if i % 8 == 0:
			await get_tree().process_frame
	var guard := 0
	while guard < 20 and not Career.pending_user_bouts(w).is_empty():
		guard += 1
		Career.advance_week(w, true)
	w.pops.clear()
	GameManager.save_now()
	UIManager.goto("hub")
	await _wait(1.2)
	await _scroll_to("Temporada de", 30)
	await _shot("s04_inicio_temporada")
	UIManager.push("season")
	await _wait(1.0)
	await _shot("s05_temporada_metas_dica")
	_press("Entendi")
	await _wait(0.4)
	await _shot("s06_temporada_metas")
	await _tab("apoio")
	await _shot("s07_temporada_cidade")
	UIManager.current().scroll().scroll_vertical = 99999
	await _wait(0.3)
	await _shot("s08_temporada_cidade_motivos")
	await _tab("conquistas")
	await _shot("s09_conquistas")
	UIManager.current().scroll().scroll_vertical = 900
	await _wait(0.3)
	await _shot("s10_conquistas_lista")
	await _scroll_to("Conquistadas (", 20)
	await _shot("s10b_conquistas_feitas")
	# 3. Aviso de conquista e de meta cumprida.
	Season.pop(w, "feat", "Mão pesada", "Prata · 25 pontos")
	Season.pop(w, "goal", "Meta cumprida", "Vencer 8 lutas no ano")
	SeasonKit.celebrate(w)
	await _wait(0.9)
	await _shot("s11_aviso_conquista")
	await _wait(3.2)
	UIManager.back()
	# 4. A virada do ano abre a cerimônia sozinha.
	await _to_year_end(w, accept)
	GameManager.save_now()
	await _turn_week(w)
	print("tela depois da virada: ", UIManager.current().name, " gala pendente ", Season.gala_pending(w))
	if Season.gala_pending(w):
		if String(UIManager.current().get("screen_title")) != "Noite de gala":
			UIManager.push("gala", {"year": int(w.gala["year"])})
		await _gala("s2")
	print("gala vista: ", w.gala)
	await _wait(0.6)
	await _shot("s30_inicio_ano_novo")
	UIManager.push("season", {"tab": "anos"})
	await _wait(0.9)
	await _shot("s31_temporada_anos")
	UIManager.back()
	UIManager.push("inbox")
	await _wait(0.8)
	var s := UIManager.current()
	s.set("_view", "tudo")
	s.refresh()
	await _wait(0.4)
	await _shot("s32_caixa_temporada")
	print("[fim]")
	get_tree().quit()


func _season_president() -> void:
	await _boot()
	# 1. Liga nova: primeiros passos do presidente.
	var w0 := Org.new_career("Liga Global de Combate", "LGC", "USA", Color("#B3262E"), Color("#F1F0EC"), 12000000.0, 2027)
	GameManager.start_career(w0)
	UIManager.goto("hub")
	await _wait(1.2)
	await _shot("p01_inicio_primeiros_passos")
	UIManager.switch_area("events")
	await _wait(0.9)
	await _shot("p02_eventos_dica")
	# 2. Trinta semanas de liga.
	var w := Org.new_career("Liga Global de Combate", "LGC", "USA", Color("#B3262E"), Color("#F1F0EC"), 12000000.0, 2027)
	Tutorial.skip(w)
	GameManager.start_career(w)
	for i in 30:
		Career.advance_week(w, true)
		if i % 8 == 0:
			await get_tree().process_frame
	var guard := 0
	while guard < 30 and Org.night_this_week(w) != null:
		guard += 1
		Career.advance_week(w, true)
	w.pops.clear()
	GameManager.save_now()
	UIManager.goto("hub")
	await _wait(1.2)
	await _scroll_to("Temporada de", 30)
	await _shot("p03_inicio_temporada")
	UIManager.push("season")
	await _wait(1.0)
	_press("Entendi")
	await _wait(0.4)
	await _shot("p04_temporada_metas")
	await _tab("apoio")
	await _shot("p05_temporada_socios")
	await _tab("conquistas")
	await _shot("p06_conquistas")
	UIManager.back()
	# 3. A virada do ano e a cerimônia do presidente.
	await _to_year_end(w, func() -> void: pass)
	GameManager.save_now()
	await _turn_week(w)
	print("tela depois da virada: ", UIManager.current().name, " gala pendente ", Season.gala_pending(w))
	if Season.gala_pending(w):
		if String(UIManager.current().get("screen_title")) != "Noite de gala":
			UIManager.push("gala", {"year": int(w.gala["year"])})
		await _gala("p1")
	await _wait(4.0)
	# 4. Confiança no chão: ultimato, intervenção e fim de mandato.
	guard = 0
	while guard < 30 and Org.night_this_week(w) != null:
		guard += 1
		Career.advance_week(w, true)
	w.pops.clear()
	w.support["v"] = 14.0
	w.support["low"] = 3
	Season.nudge(w, -6.0, "Noite cancelada", "cancel")
	Season.nudge(w, -2.5, "Noite no prejuízo", "preju")
	w.support["v"] = 14.0
	Season._pressure(w)
	print("ultimato: ", w.support.get("ult", {}))
	GameManager.save_now()
	UIManager.goto("hub")
	await _wait(1.0)
	await _scroll_to("Para resolver", 20)
	await _shot("p20_inicio_ultimato")
	UIManager.push("season", {"tab": "apoio"})
	await _wait(1.0)
	await _shot("p21_socios_ultimato")
	UIManager.back()
	await _wait(0.4)
	w.support["v"] = 14.0
	(w.support["ult"] as Dictionary)["until"] = w.week
	Season._pressure(w)
	SeasonKit.board_event(w, UIManager.current().refresh)
	await _wait(0.9)
	await _shot("p22_intervencao")
	UIManager.close_modal()
	await _wait(0.5)
	w.support["v"] = 12.0
	w.support["ult"] = {"until": w.week, "need": Season.ULT_NEED, "from": w.week - 12}
	Season._pressure(w)
	SeasonKit.board_event(w, UIManager.current().refresh)
	await _wait(0.9)
	await _shot("p23_fim_do_mandato")
	_press_modal("Começar novo mandato")
	await _wait(1.2)
	await _shot("p24_novo_mandato")
	print("mandato: ", w.support.get("terms", 1), " caixa ", Fmt.money(w.user_team().balance))
	print("[fim]")
	get_tree().quit()


func _press_modal(text: String) -> bool:
	for n: Node in UIManager.main.find_children("*", "Button", true, false):
		var b := n as Button
		if b.text.to_lower() == text.to_lower() and b.is_visible_in_tree() and not b.is_queued_for_deletion():
			b.pressed.emit()
			return true
	print("sem botão no modal: ", text)
	return false
