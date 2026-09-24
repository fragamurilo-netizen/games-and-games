extends Node
## Lógica do passeio pelas telas (carregada em tempo de execução pelo screenshot_tour.gd,
## depois que os autoloads existem).

var out_dir := ""
var shots := false
var lang := ""
var count := 0


func _ready() -> void:
	_run()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait(sec: float) -> void:
	var t := Time.get_ticks_msec() + int(sec * 1000.0)
	while Time.get_ticks_msec() < t:
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	await _frames(3)
	await _wait(0.3) # transições de tela e de modal terminarem
	count += 1
	print("[tela] ", shot_name)
	if not shots:
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [out_dir, shot_name])


func _screen() -> BaseScreen:
	return UIManager.current()


func _run() -> void:
	await _frames(2)
	if lang != "":
		I18n.apply(lang)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await _frames(10)
	await _shot("01_menu")
	UIManager.push("new_career")
	await _frames(10)
	await _shot("02_nova_carreira")
	# Carreira de teste (mundo padrão, clube da 2ª divisão)
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	var club_id := -1
	for c: Club in w.clubs_in_league("BRA1"):
		if c.archetype == "tradicional_decadente" or club_id < 0:
			club_id = c.id
	AppSettings.tutorial_done = false
	GameManager.start_career(w, club_id, "Murilo", GameWorld.DIFF_NORMAL, 5)
	UIManager.goto("hub")
	await _frames(12)
	await _shot("03_tutorial")
	UIManager.close_all_modals()
	await _frames(4)
	await _shot("04_hub")
	UIManager.push("preseason")
	await _frames(8)
	await _shot("04a_pre_temporada")
	_screen().scroll().scroll_vertical = 1100
	await _frames(6)
	await _shot("04b_pre_temporada_elenco")
	PreseasonManager.choose_camp(GameManager.world, "tatica")
	PreseasonManager.play_friendlies(GameManager.world)
	_screen().refresh()
	_screen().scroll().scroll_vertical = 100000
	await _frames(8)
	await _shot("04c_pre_temporada_amistosos")
	UIManager.goto("hub")
	await _frames(6)
	await _shot("04d_hub_pre_temporada")
	UIManager.goto("squad")
	await _frames(8)
	await _shot("05_elenco")
	var star: Player = null
	for p in w.squad(w.user_club()):
		if star == null or p.ovr_f > star.ovr_f:
			star = p
	UIManager.push("player", {"id": star.id})
	await _frames(8)
	await _shot("06_perfil")
	# Pré-temporada: uniformes e patrocínios
	UIManager.push("kit")
	await _frames(8)
	await _shot("06a_uniforme")
	_screen().set("_part", "shorts")
	_screen().refresh()
	await _frames(4)
	await _shot("06b_uniforme_calcao")
	var ks := _screen().scroll()
	ks.scroll_vertical = 100000
	await _frames(4)
	await _shot("06c_patrocinios")
	SponsorManager.sign(w, "master", 0)
	_screen().refresh()
	await _frames(4)
	ks.scroll_vertical = 0
	await _frames(4)
	await _shot("06d_uniforme_master")
	for sl in ["fornecedor", "manga", "costas", "calcao"]:
		SponsorManager.sign(w, sl, 0)
	_screen().refresh()
	await _frames(4)
	await _shot("06d2_uniforme_todos")
	_screen().set("_back", true)
	_screen().refresh()
	await _frames(4)
	await _shot("06d3_uniforme_costas")
	UIManager.back()
	# Proposta com troca por um jogador de outro clube
	var other: Club = w.club(w.user_club().main_rival())
	var tgt: Player = w.squad(other)[2]
	UIManager.push("player", {"id": tgt.id})
	await _frames(8)
	await _shot("06e_perfil_rival")
	var neg_swap := {"swap": [w.squad(w.user_club())[4].id]}
	Negotiation.open(w, tgt, "buy", Callable())
	await _frames(6)
	await _shot("06f_proposta")
	UIManager.close_all_modals()
	var n2 := Negotiation.new()
	n2.w = w
	n2.p = tgt
	n2.mode = "buy"
	n2._init_values()
	n2.deal["swap"] = neg_swap["swap"]
	n2.box = UIKit.vbox(14)
	n2.box.custom_minimum_size.x = 600
	n2._render()
	UIManager.show_modal(n2.box, true)
	await _frames(6)
	await _shot("06g_proposta_troca")
	n2.picking_swap = true
	n2._render()
	await _frames(6)
	await _shot("06h_escolher_troca")
	UIManager.close_all_modals()
	UIManager.back()
	UIManager.goto("hub")
	UIManager.push("prematch")
	await _frames(8)
	await _shot("07_pre_jogo")
	# Partida ao vivo em modo turbo
	GameManager.begin_match()
	UIManager.replace("match")
	await _frames(6)
	var ms := _screen()
	ms.set("_pace", 2)
	await _wait(2.5)
	await _shot("08_partida")
	var got_goal := false
	var got_half := false
	var guard := Time.get_ticks_msec() + 120000
	while not bool(ms.get("_done")) and Time.get_ticks_msec() < guard:
		await get_tree().process_frame
		var ov: GoalOverlay = ms.get("_overlay")
		if not got_goal and ov != null and ov.is_playing():
			got_goal = true
			await _wait(0.45)
			await _shot("09_gol")
		if not got_half and bool(ms.get("_halftime")):
			got_half = true
			await _frames(6)
			await _shot("10_intervalo")
			UIManager.close_all_modals()
			ms.call("_open_tactics")
			await _frames(6)
			await _shot("11_ajustes")
			var sim: MatchSimulation = ms.get("_sim")
			var us: int = ms.get("_user_side")
			sim.set_formation(us, "4-3-3" if sim.teams[us].formation_name != "4-3-3" else "4-4-2")
			ms.call("_drain", false)
			ms.call("_sync_slots")
			ms.call("_render_tactics")
			await _frames(6)
			await _shot("11b_formacao")
			UIManager.close_all_modals()
			ms.call("_start_second_half")
			await _wait(2.0)
			await _shot("11c_segundo_tempo")
			for tab in ["stats", "round", "table"]:
				ms.call("_set_tab", tab)
				await _frames(6)
				await _shot("11d_aba_" + tab)
			ms.call("_set_tab", "feed")
	await _frames(8)
	await _shot("12_fim_de_jogo")
	var report: Dictionary = ms.get("_report")
	UIManager.replace("results", {"report": report})
	await _frames(8)
	await _shot("13_resultados")
	UIManager.goto("table")
	await _frames(8)
	await _shot("14_tabela")
	_screen().set("_tab", "scorers")
	_screen().refresh()
	await _frames(6)
	await _shot("15_artilharia")
	_screen().set("_tab", "rounds")
	_screen().refresh()
	await _frames(6)
	await _shot("16_rodadas")
	# Estadual do clube do usuário (clube brasileiro no passeio), ou o Paulistão.
	var state_id := "SPE"
	for cid in CupManager.state_ids():
		if w.season.cups.has(cid) and w.season.cups[cid].has_club(w.user_club_id):
			state_id = cid
	if w.season.cups.has(state_id):
		UIManager.goto("table", {"cup": state_id})
		await _frames(8)
		await _shot("16b_estadual")
	UIManager.goto("table", {"rank": ""})
	await _frames(8)
	await _shot("16b_ranking")
	UIManager.goto("market")
	await _frames(8)
	await _shot("17_mercado")
	_screen().set("_tab", "free")
	_screen().refresh()
	await _frames(6)
	await _shot("18_livres")
	_screen().set("_tab", "offers")
	_screen().refresh()
	await _frames(4)
	UIManager.goto("club")
	await _frames(8)
	await _shot("19_clube")
	_screen().scroll().scroll_vertical = 1400
	await _frames(4)
	await _shot("19b_clube_financas")
	var rival := w.user_club().main_rival()
	if rival >= 0:
		UIManager.push("club", {"id": rival})
		await _frames(8)
		await _shot("20_clube_rival")
	UIManager.goto("hub")
	UIManager.push("news")
	await _frames(8)
	await _shot("21_noticias")
	UIManager.push("settings")
	await _frames(6)
	await _shot("22_opcoes")
	# Telas novas: treino, base, editor, história, simulação, decisões e negociação
	UIManager.goto("hub")
	UIManager.push("training")
	await _frames(8)
	await _shot("30_treino")
	TrainingSheet.open(star)
	await _frames(6)
	await _shot("31_treino_individual")
	UIManager.close_all_modals()
	UIManager.push("academy")
	await _frames(8)
	await _shot("32_base")
	_screen().set("_tab", "table")
	_screen().refresh()
	await _frames(6)
	await _shot("33_sub20")
	UIManager.push("editor")
	await _frames(6)
	await _shot("34_editor")
	var ed := _screen()
	ed.set("_club", w.user_club())
	ed.call("_go", "club")
	await _frames(8)
	await _shot("35_editor_clube")
	ed.set("_pid", star.id)
	ed.call("_go", "player")
	await _frames(8)
	await _shot("36_editor_jogador")
	ed.set("_comp_kind", "leagues")
	ed.set("_comp_id", w.user_league_id())
	ed.call("_go", "comp")
	await _frames(8)
	await _shot("36b_editor_liga")
	UIManager.goto("hub")
	UIManager.push("history")
	await _frames(6)
	await _shot("37_historia")
	UIManager.goto("hub")
	await _frames(4)
	SimDialog.open(func(): pass)
	await _frames(6)
	await _shot("38_simular_opcoes")
	UIManager.close_all_modals()
	SimDialog.start(SimDialog.MODE_GAMES, 3, func(): pass)
	var sim_guard := Time.get_ticks_msec() + 90000
	while GameManager.world.current_turn() < 4 and Time.get_ticks_msec() < sim_guard:
		await get_tree().process_frame
	await _frames(12)
	await _shot("39_simular_resumo")
	UIManager.close_all_modals()
	var ev := EventManager._build(w, "sponsor")
	ev["id"] = 999
	ev["turn"] = w.current_turn()
	ev["exp"] = w.current_turn() + 3
	w.events.append(ev)
	UIManager.goto("hub")
	await _frames(8)
	await _shot("40_hub_decisoes")
	EventDialog.open(ev)
	await _frames(6)
	await _shot("41_decisao")
	UIManager.close_all_modals()
	var target: Player = null
	for q: Player in w.players.values():
		if q.club_id >= 0 and not w.is_user_club(q.club_id) and q.overall >= 66 and q.loan.is_empty():
			target = q
			break
	Negotiation.open(w, target, "buy", Callable())
	await _frames(6)
	await _shot("42_negociacao")
	UIManager.close_all_modals()
	# Relações: todas as abas e uma conversa de cada tipo
	var tabs: Array = ["squad", "staff", "board", "fans", "press", "coaches"]
	for i in tabs.size():
		UIManager.goto("hub")
		UIManager.push("relations", {"tab": tabs[i]})
		await _frames(6)
		await _shot("%d_relacoes_%s" % [50 + i, tabs[i]])
	var talker: Player = w.squad(w.user_club())[3]
	TalkDialog.open("player", talker.id)
	await _frames(6)
	await _shot("56_conversa_jogador")
	UIManager.close_all_modals()
	var pc := Talks.start(w, "press")
	while not pc["done"]:
		Talks.choose(w, pc, "0")
	TalkDialog.open("board")
	await _frames(6)
	await _shot("57_conversa_presidente")
	UIManager.close_all_modals()
	UIManager.goto("menu")
	UIManager.push("load")
	await _frames(6)
	await _shot("23_carregar")
	# Resto da temporada no instantâneo, com passagens pelo hub e pelos resultados
	UIManager.goto("hub")
	var rounds := 1
	while not GameManager.season_over():
		var r := GameManager.play_instant()
		rounds += 1
		if rounds == 19:
			UIManager.goto("hub")
			UIManager.push("results", {"report": r})
			await _frames(6)
			await _shot("24_resultados_meio")
	UIManager.goto("hub")
	await _frames(8)
	await _shot("25_hub_fim")
	_screen().scroll().scroll_vertical = 1100
	await _frames(6)
	await _shot("25b_hub_fim_rolado")
	UIManager.push("season_end")
	await _wait(0.6)
	await _shot("26_fim_de_temporada")
	await _wait(4.0)
	await _shot("27_fim_de_temporada_resumo")
	_screen().scroll().scroll_vertical = 1000
	await _frames(6)
	await _shot("27b_fim_de_temporada_numeros")
	_screen().scroll().scroll_vertical = 2000
	await _frames(6)
	await _shot("27c_fim_de_temporada_destaques")
	UIManager.goto("hub")
	await _frames(8)
	await _shot("28_hub_nova_temporada")
	UIManager.push("history", {"tab": "champions"})
	await _frames(8)
	await _shot("43_historia_campeoes")
	_screen().set("_tab", "awards")
	_screen().refresh()
	await _frames(6)
	await _shot("44_historia_premios")
	_screen().set("_tab", "career")
	_screen().refresh()
	await _frames(6)
	await _shot("45_historia_carreira")
	_screen().set("_tab", "seasons")
	_screen().refresh()
	await _frames(6)
	await _shot("46_historia_temporadas")
	for view in ["sc", "rt", "aw"]:
		_screen().set("_arch_view", view)
		_screen().refresh()
		await _frames(4)
		await _shot("47_historia_temporadas_" + view)
	_screen().set("_tab", "club")
	_screen().refresh()
	await _frames(6)
	await _shot("48_historia_trofeus")
	var champ_club := -1
	var last: Dictionary = GameManager.world.history[GameManager.world.history.size() - 1]
	for lid in last.get("leagues", {}):
		champ_club = int(last["leagues"][lid]["champion"])
		break
	if champ_club >= 0:
		UIManager.push("club", {"id": champ_club})
		await _frames(8)
		await _shot("49_clube_campeao_trofeus")
	var veteran: Player = null
	for q: Player in GameManager.world.squad(GameManager.world.user_club()):
		if q.history.size() >= 1 and (veteran == null or q.overall > veteran.overall):
			veteran = q
	if veteran != null:
		UIManager.push("player", {"id": veteran.id})
		await _frames(8)
		await _shot("50_perfil_temporadas")
	UIManager.goto("hub")
	UIManager.push("national")
	await _frames(8)
	await _shot("51_selecoes_torneios")
	for tab in ["quals", "ranking", "squad"]:
		_screen().set("_tab", tab)
		_screen().refresh()
		await _frames(6)
		await _shot("52_selecoes_" + tab)
	print("TOUR OK: %d telas, temporada %d, rodadas %d" % [count, GameManager.world.year, rounds])
	GameManager.close_career()
	SaveManager.delete_slot(5)
	main.queue_free()
	await _frames(2)
	get_tree().quit(0)
