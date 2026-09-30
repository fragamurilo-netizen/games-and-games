extends Node
## Capturas rápidas das telas principais, nos modos escuro e claro, para revisar o visual.
## xvfb-run godot --path . --resolution 720x1280 --script res://tools/design_shots.gd -- --out=DIR

var out_dir := ""
var shots := false
var lang := ""
## --tablet: simula um tablet (escala menor da interface); --prefix=: só as telas principais,
## no modo escuro, com esse prefixo no nome (capturas de paisagem e tablet).
var tablet := false
var prefix := ""
## --only=rota,rota:aba,...: só essas telas (depois de --rounds=N rodadas jogadas), modo escuro.
var only := ""
## --nt=BRA: o técnico também comanda essa seleção (telas de seleções e uniforme da seleção).
var nt := ""
var rounds := 3
## Com --only: modo claro, clube pelo nome (parte do nome basta) e tingimento do fundo (-1 = o salvo).
var light := false
## Dados feios de propósito (nomes enormes, clube de nome comprido, lesão, suspensão,
## empréstimo), só em memória, para testar colisões e cortes.
var ugly := false
var club_name := ""
var tint := -1


func _ready() -> void:
	_run()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	await _frames(4)
	var t := Time.get_ticks_msec() + 350
	while Time.get_ticks_msec() < t:
		await get_tree().process_frame
	print("[tela] ", shot_name)
	if not shots:
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, shot_name])


func _screen() -> BaseScreen:
	return UIManager.current()


func _scroll(px: int) -> void:
	var s := _screen().scroll()
	if s != null:
		s.scroll_vertical = px


func _run() -> void:
	await _frames(2)
	if lang != "":
		I18n.apply(lang)
	UILayout.force_tablet = tablet
	get_tree().root.content_scale_factor = UILayout.device_scale()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await _frames(10)
	if only != "":
		await _only_pass()
		get_tree().quit()
		return
	await _shot(prefix + "01_menu")
	UIManager.push("new_career")
	await _frames(8)
	await _shot(prefix + "02_nova_carreira_1")
	var nc := _screen()
	nc.set("_step", 1)
	nc.call("_build")
	await _shot(prefix + "02_nova_carreira_2")
	var until := Time.get_ticks_msec() + 30000
	while nc.get("_world") == null and Time.get_ticks_msec() < until:
		await get_tree().process_frame
	nc.set("_step", 2)
	nc.call("_build")
	await _frames(4)
	var nw: GameWorld = nc.get("_world")
	if nw != null:
		nc.set("_selected", nw.clubs_in_league("BRA1")[3].id)
		nc.call("_build")
	await _shot(prefix + "02_nova_carreira_3")
	UIManager.back()
	await _frames(4)
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	var club_id := -1
	for c: Club in w.clubs_in_league("BRA1"):
		if c.archetype == "tradicional_decadente" or club_id < 0:
			club_id = c.id
	AppSettings.tutorial_done = true
	GameManager.start_career(w, club_id, "Murilo", GameWorld.DIFF_NORMAL, 5)
	GameManager.save_now()
	UIManager.goto("welcome")
	await _frames(8)
	await _shot(prefix + "03_boas_vindas")
	UIManager.push("load")
	await _frames(8)
	await _shot(prefix + "03b_carregar")
	UIManager.goto("settings")
	await _frames(8)
	await _shot(prefix + "03c_opcoes")
	if prefix != "":
		await _wide_pass(w)
		get_tree().quit()
		return
	for mode in ["claro", "escuro"]:
		AppSettings.theme_mode = AppSettings.THEME_LIGHT if mode == "claro" else AppSettings.THEME_DARK
		UIManager.apply_look()
		await _pass(w, mode)
	get_tree().quit()


func _pass(w: GameWorld, m: String) -> void:
	UIManager.goto("hub")
	await _frames(8)
	UIManager.close_all_modals()
	await _shot(m + "_04_hub")
	_scroll(1100)
	await _shot(m + "_04b_hub_rolado")
	UIManager.goto("squad")
	await _frames(8)
	await _shot(m + "_05_elenco")
	var star: Player = null
	for p in w.squad(w.user_club()):
		if star == null or p.ovr_f > star.ovr_f:
			star = p
	UIManager.push("player", {"id": star.id})
	await _frames(8)
	await _shot(m + "_06_perfil")
	_scroll(900)
	await _shot(m + "_06b_perfil_rolado")
	UIManager.goto("club")
	await _frames(8)
	await _shot(m + "_19_clube")
	_scroll(1000)
	await _shot(m + "_19b_clube_rolado")
	UIManager.goto("table")
	await _frames(8)
	await _shot(m + "_14_tabela")
	UIManager.goto("market")
	await _frames(8)
	await _shot(m + "_17_mercado")
	if m == "escuro":
		UIManager.goto("hub")
		UIManager.push("prematch")
		await _frames(8)
		await _shot(m + "_07_pre_jogo")
		GameManager.begin_match()
		UIManager.replace("match")
		await _frames(12)
		var ms := _screen()
		UIManager.close_all_modals()
		ms.call("_drain", false)
		ms.set("_pace", 2)
		var t := Time.get_ticks_msec() + 2500
		while Time.get_ticks_msec() < t:
			await get_tree().process_frame
		await _shot(m + "_08_partida")


func _wide_pass(w: GameWorld) -> void:
	UIManager.goto("hub")
	await _frames(10)
	UIManager.close_all_modals()
	await _shot(prefix + "04_hub")
	UIManager.goto("squad")
	await _frames(8)
	await _shot(prefix + "05_elenco")
	var star: Player = null
	for p in w.squad(w.user_club()):
		if star == null or p.ovr_f > star.ovr_f:
			star = p
	UIManager.push("player", {"id": star.id})
	await _frames(8)
	await _shot(prefix + "06_perfil")
	UIManager.goto("club")
	await _frames(8)
	await _shot(prefix + "19_clube")
	UIManager.goto("table")
	await _frames(8)
	await _shot(prefix + "14_tabela")
	UIManager.goto("market")
	await _frames(8)
	await _shot(prefix + "17_mercado")
	UIManager.goto("hub")
	UIManager.push("prematch")
	await _frames(8)
	await _shot(prefix + "07_pre_jogo")
	GameManager.begin_match()
	UIManager.replace("match")
	await _frames(12)
	var ms := _screen()
	UIManager.close_all_modals()
	ms.call("_drain", false)
	ms.set("_pace", 2)
	var t := Time.get_ticks_msec() + 2500
	while Time.get_ticks_msec() < t:
		await get_tree().process_frame
	await _shot(prefix + "08_partida")


func _only_pass() -> void:
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	var club_id := -1
	for c: Club in w.clubs_in_league("BRA1"):
		if c.archetype == "tradicional_decadente" or club_id < 0:
			club_id = c.id
	if club_name != "":
		# Nome exato primeiro ("Remo" não pode cair na Cremonese); senão, parte do nome.
		var partial := -1
		for c: Club in w.clubs:
			if c.name.to_lower() == club_name.to_lower():
				partial = c.id
				break
			if partial < 0 and c.name.to_lower().contains(club_name.to_lower()):
				partial = c.id
		if partial >= 0:
			club_id = partial
	AppSettings.tutorial_done = true
	AppSettings.color_source = 1
	if tint >= 0:
		AppSettings.bg_tint = tint
	AppSettings.theme_mode = AppSettings.THEME_LIGHT if light else AppSettings.THEME_DARK
	GameManager.start_career(w, club_id, "Murilo", GameWorld.DIFF_NORMAL, 5)
	if nt != "":
		NationalCoach.accept(w, nt, true)
	UIManager.apply_look()
	for i in rounds:
		GameManager.play_instant()
		await _frames(2)
	UIManager.goto("hub")
	await _frames(6)
	UIManager.close_all_modals()
	if ugly:
		_uglify(w)
	# Capturas de layout sem avisos de conquista pendentes por cima (o aviso tem captura própria).
	w.pending_achievements.clear()
	for b in ["AchievementBanner", "AchievementBannerDone"]:
		var n := get_tree().root.get_node_or_null(b)
		if n != null:
			n.queue_free()
	for spec in only.split(","):
		if spec == "!taps":
			await _tap_check(w)
			continue
		if spec.begins_with("~article"):
			await _article_shot(w, spec.substr(9))
			continue
		if spec.begins_with("~"):
			await _dialog_shot(w, spec.substr(1))
			continue
		var pages := 2
		if spec.contains("@"):
			pages = int(spec.get_slice("@", 1))
			spec = spec.get_slice("@", 0)
		var parts := spec.split(":")
		var route := parts[0]
		var args := {}
		if parts.size() > 1:
			args["tab"] = parts[1]
		if route == "player":
			var star: Player = null
			for p in w.squad(w.user_club()):
				if star == null or p.ovr_f > star.ovr_f:
					star = p
			args["id"] = star.id
		if route == "coach":
			var u2 := w.user_club()
			for oc: Club in w.clubs_in_league(u2.league_id):
				if oc.id != u2.id:
					args = {"club": oc.id}
					break
		if route == "kit" and nt != "":
			args["nation"] = nt
		if route == "compare":
			var sq := w.squad(w.user_club())
			sq.sort_custom(func(a, b): return a.overall > b.overall)
			args = {"a": sq[0].id, "b": sq[1].id}
		if route == "market" and String(args.get("tab", "")) == "scout" and Scouting.reports(w).is_empty() and Scouting.can_send(w):
			# Relatórios para a captura: uma missão aberta (qualquer setor, origem e idade).
			Scouting.send_mission(w, "all", -1, 99)
		if route == "rivalry":
			var u := w.user_club()
			args = {"a": u.id, "b": int(u.rivals[0]) if not u.rivals.is_empty() else w.clubs_in_league(u.league_id)[0].id}
		if route in UIManager.TABS:
			UIManager.goto(route, args)
		else:
			UIManager.goto("hub")
			await _frames(2)
			UIManager.push(route, args)
		await _frames(8)
		UIManager.close_all_modals()
		for prop in ["_deep_open", "_extras_open"]:
			if prop in _screen():
				_screen().set(prop, true)
				_screen().refresh()
		await _frames(4)
		var shot_name := prefix + spec.replace(":", "_")
		await _shot(shot_name)
		var sc := _screen().scroll()
		for pg in range(1, pages):
			if sc == null or sc.scroll_vertical + sc.size.y >= sc.get_v_scroll_bar().max_value - 20:
				break
			sc.scroll_vertical = int(sc.size.y * 0.85 * pg)
			await _shot(shot_name + "_" + "bcdefghij"[pg - 1])


## Diálogos e folhas por cima do hub (~confirm, ~event, ~sim, ~tutorial, ~buy, ~talk, ~toast).
func _dialog_shot(w: GameWorld, kind: String) -> void:
	UIManager.close_all_modals()
	UIManager.goto("hub")
	await _frames(6)
	UIManager.close_all_modals()
	var u := w.user_club()
	match kind:
		"confirm":
			UIManager.confirm("Apagar o espaço 2?", "Isso apaga o Coritiba para sempre, incluindo a cópia de segurança.", "Apagar", func(): pass)
		"event":
			var evs := EventManager.pending(w)
			if evs.is_empty():
				return
			EventDialog.open(evs[0])
		"sim":
			SimDialog.open(func(): pass)
		"tutorial":
			Tutorial.show_all()
		"buy":
			for c: Club in w.clubs_in_league(u.league_id):
				if c.id != u.id:
					var sq := w.squad(c)
					sq.sort_custom(func(a, b): return a.overall > b.overall)
					Negotiation.open(w, sq[0], "buy", func(): pass)
					break
		"talk":
			TalkDialog.open("board", -1)
		"training", "training_st":
			var sq := w.squad(u)
			sq.sort_custom(func(a, b): return a.age(w.year) < b.age(w.year))
			var yp: Player = sq[0]
			yp.train["ld"] = 2
			var opts := PlayStyle.options_for(yp)
			for e: Dictionary in opts:
				if String(e["k"]) != String(PlayStyle.primary(yp)["k"]):
					TrainingManager.set_style_target(yp, String(e["k"]))
					break
			TrainingSheet.open(yp, Callable(), "st" if kind == "training_st" else "")
		"nav":
			NavMenu.open()
		"focus":
			# Contorno de foco de teclado: o primeiro botão visível da tela recebe foco.
			for b in _screen().find_children("*", "Button", true, false):
				if (b as Button).is_visible_in_tree() and (b as Button).focus_mode != Control.FOCUS_NONE:
					(b as Button).grab_focus()
					print("[tela] foco em: ", (b as Button).text, " ", (b as Button).theme_type_variation, " dono=", _screen().get_viewport().gui_get_focus_owner())
					break
		"toast":
			UIManager.toast("Proposta enviada. A resposta chega na próxima rodada.", UIColors.GREEN)
		"buy_cond", "buy_terms", "buy_loan":
			for c: Club in w.clubs_in_league(u.league_id):
				if c.id != u.id and not u.is_rival(c.id):
					var sq := w.squad(c)
					sq.sort_custom(func(a, b): return a.overall > b.overall)
					Negotiation.open(w, sq[2], "buy", func(): pass)
					break
			await _frames(2)
			var neg: Negotiation = Negotiation.last
			if neg != null:
				match kind:
					"buy_cond":
						neg.buy_tab = "cond"
						neg.deal["inst"] = 2
						neg.deal["addon"] = 0.2
					"buy_terms":
						neg.agreed_fee = neg.fee
						neg.wage = TransferManager.wage_ask(w, neg.p, u)
						neg.terms_tab = "extra"
						neg.deal["abl"] = 1
						neg.deal["role"] = Player.STATUS_ROTATION
					"buy_loan":
						neg.loan_mode = true
						neg.loan_terms = {"kind": "obl", "ws": 0.75}
				neg._render()
		"offer":
			var sq2 := w.squad(u)
			sq2.sort_custom(func(a, b): return a.age(w.year) < b.age(w.year))
			var r := TransferManager.shop_player(w, sq2[0])
			if TransferManager.pending_offers(w).is_empty():
				var o := TransferOffer.new()
				o.id = w.next_offer_id
				w.next_offer_id += 1
				o.player_id = sq2[0].id
				o.buyer_id = w.clubs_in_league("POR1")[0].id
				o.seller_id = u.id
				o.fee = Valuation.round_value(sq2[0].value * 1.1)
				o.max_fee = int(o.fee * 1.25)
				o.created_day = w.current_turn()
				o.expires_day = w.current_turn() + 2
				w.offers.append(o)
			for o: TransferOffer in w.offers:
				if o.is_pending():
					o.inst = 3
					o.addon = Valuation.round_value(o.fee * 0.15)
					break
			UIManager.goto("market", {"tab": "offers"})
			await _frames(6)
			print("[tela] propostas: ", r["msg"])
		"kid":
			UIManager.push("academy")
			await _frames(6)
			var kids := YouthManager.academy(w)
			kids.sort_custom(func(a, b): return a.stats[Player.S_APPS] > b.stats[Player.S_APPS])
			_screen().call("_actions", kids[0])
		"coach":
			UIManager.push("academy", {"tab": "staff"})
			await _frames(6)
			_screen().call("_coach_picker", YouthManager.CAT_U20)
	await _shot(prefix + "dlg_" + kind)
	UIManager.close_all_modals()


## Matéria completa aberta por cima do portal: ~article (a mais recente com blocos de dados) ou
## ~article:categoria / ~article:chave (a mais recente daquela categoria ou com aquela chave na mídia).
func _article_shot(w: GameWorld, what: String) -> void:
	UIManager.close_all_modals()
	UIManager.goto("hub")
	await _frames(2)
	UIManager.push("news")
	await _frames(6)
	var pick: NewsEvent = null
	for i in range(w.news.size() - 1, -1, -1):
		var n: NewsEvent = w.news[i]
		var ok := n.category == what or n.media.has(what)
		if what == "":
			var blocks := NewsExtras.blocks(w, n)
			ok = not blocks.is_empty()
			for b: Control in blocks:
				b.free()
		if ok:
			pick = n
			break
	if pick == null:
		print("[tela] sem notícia para ", what)
		return
	UIManager.show_modal(NewsRow.article(w, pick), true)
	await _frames(6)
	await _shot(prefix + "article_" + (what if what != "" else "any"))
	UIManager.close_all_modals()


func _uglify(w: GameWorld) -> void:
	var sq := w.squad(w.user_club())
	sq.sort_custom(func(a, b): return a.ovr_f > b.ovr_f)
	var names := [["Trenton", "Alexandre-Arnaldo"], ["João Pedro", "da Silva Oliveira Albuquerque"], ["Maximiliano", "Wojciechowski-Bergkamp"]]
	for i in mini(names.size(), sq.size()):
		var p: Player = sq[i]
		p.first_name = names[i][0]
		p.last_name = names[i][1]
		p.known_as = ""
	if sq.size() > 5:
		sq[3].injury_weeks = 6
		sq[3].injury_name = "Lesão muscular na coxa"
		sq[4].suspension = 2
		sq[5].contract_end = w.year
		sq[5].wage = 1_450_000
	var opp_ids := w.clubs_in_league(w.user_club().league_id)
	for c: Club in opp_ids.slice(0, 3):
		if not w.is_user_club(c.id):
			c.short_name = "Gimnasia y Esgrima de La Plata"
			c.name = "Club de Gimnasia y Esgrima de La Plata Sur"
			break
	var nf := FixtureManager.next_fixture_for(w, w.user_club_id)
	if nf != null:
		var o := w.club(nf.opponent_of(w.user_club_id))
		o.short_name = "Sportverein Mönchenwaldbach"
		o.name = "Sportverein Mönchenwaldbach 1900 e.V."


## !taps: toque simulado (aperta, treme alguns px como um dedo, solta) em cada botão visível das
## telas principais. Conta quantos dispararam e mede quanto o "apertar" custa (tudo o que roda em
## _input antes da GUI: rolagem por arrasto, foco...). Toque que não dispara = clique ruim.
func _tap_check(w: GameWorld) -> void:
	var routes := ["hub", "squad", "tactics", "market", "club", "player", "training", "table", "inbox"]
	var total := 0
	var ok := 0
	var worst_us := 0
	var sum_us := 0
	for route in routes:
		var fails: Array = []
		var n_route := 0
		for i in 14:
			await _open_route(w, route)
			var targets := _tap_targets()
			if i >= targets.size():
				break
			var b: BaseButton = targets[i]
			var label := _btn_label(b)
			var fired := [false]
			b.pressed.connect(func(): fired[0] = true, CONNECT_ONE_SHOT)
			var pos := b.get_global_rect().get_center()
			var t0 := Time.get_ticks_usec()
			_mouse(pos, true)
			var dt := Time.get_ticks_usec() - t0
			worst_us = maxi(worst_us, dt)
			sum_us += dt
			await get_tree().process_frame
			var j := float(OS.get_environment("TAP_JITTER")) if OS.get_environment("TAP_JITTER") != "" else 6.0
			_move(pos + Vector2(j * 0.6, j * 0.5))
			await get_tree().process_frame
			_move(pos + Vector2(j, j * 0.8))
			await get_tree().process_frame
			_mouse(pos + Vector2(j, j * 0.8), false)
			await _frames(2)
			total += 1
			n_route += 1
			if fired[0]:
				ok += 1
			else:
				fails.append(label)
			UIManager.close_all_modals()
		print("[toque] %s: %d alvos, falharam %d %s" % [route, n_route, fails.size(), str(fails)])
	# Arrasto: começar em cima de uma linha e subir 160 px tem de rolar e não disparar nada.
	for route in ["squad", "hub", "inbox"]:
		await _open_route(w, route)
		var tg := _tap_targets()
		var sc := _screen().scroll()
		if tg.is_empty() or sc == null:
			continue
		var b2: BaseButton = tg[tg.size() / 2]
		var hit := [false]
		b2.pressed.connect(func(): hit[0] = true, CONNECT_ONE_SHOT)
		var p0 := b2.get_global_rect().get_center()
		var before := sc.scroll_vertical
		_mouse(p0, true)
		for k in 8:
			await get_tree().process_frame
			_move(p0 - Vector2(0, 20 * (k + 1)))
		_mouse(p0 - Vector2(0, 160), false)
		await _frames(3)
		print("[toque] arrasto em %s: rolou %d px, disparou botão: %s" % [route, sc.scroll_vertical - before, hit[0]])
	print("[toque] TOTAL %d/%d dispararam; apertar custa em média %d µs, pior %d µs" % [ok, total, sum_us / maxi(1, total), worst_us])


func _open_route(w: GameWorld, route: String) -> void:
	UIManager.close_all_modals()
	var args := {}
	if route == "player":
		var sq := w.squad(w.user_club())
		args = {"id": sq[0].id}
	if route in UIManager.TABS:
		UIManager.goto(route, args)
	else:
		UIManager.goto("hub")
		await _frames(2)
		UIManager.push(route, args)
	await _frames(6)
	var sc := _screen().scroll()
	if sc != null:
		sc.scroll_vertical = 0
	await _frames(2)


## Botões habilitados e visíveis dentro da área útil da tela atual, de cima para baixo.
func _tap_targets() -> Array:
	var out: Array = []
	var vr := get_viewport().get_visible_rect()
	var sc := _screen().scroll()
	var clip: Rect2 = sc.get_global_rect() if sc != null else vr
	for n in _screen().find_children("*", "BaseButton", true, false):
		var b := n as BaseButton
		if b.disabled or not b.is_visible_in_tree() or b.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			continue
		var r := b.get_global_rect()
		if r.size.x < 8 or r.size.y < 8:
			continue
		var c := r.get_center()
		if not clip.has_point(c) or not vr.has_point(c):
			continue
		out.append(b)
	out.sort_custom(func(a: BaseButton, b2: BaseButton): return a.get_global_rect().position.y < b2.get_global_rect().position.y)
	return out


func _btn_label(b: BaseButton) -> String:
	if b is Button and (b as Button).text != "":
		return (b as Button).text.left(24)
	var lbl := b.get_parent().find_child("*", true, false) if b.get_parent() != null else null
	for l in b.get_parent().get_parent().find_children("*", "Label", true, false) if b.get_parent() != null and b.get_parent().get_parent() != null else []:
		return "linha: " + (l as Label).text.left(20)
	return b.name


func _mouse(pos: Vector2, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	e.position = pos
	e.global_position = pos
	_last_pos = pos
	get_viewport().push_input(e, true)


var _last_pos := Vector2.ZERO


func _move(pos: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	e.position = pos
	e.global_position = pos
	e.relative = pos - _last_pos
	_last_pos = pos
	get_viewport().push_input(e, true)
