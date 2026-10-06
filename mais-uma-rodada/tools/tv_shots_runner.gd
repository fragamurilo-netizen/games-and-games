extends Node
## Ver tv_shots.gd.

var out_dir := "/tmp/tv"
var league := "ENG1"


func _ready() -> void:
	_run()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait(ms: int) -> void:
	var t := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < t:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await _wait(400)
	print("[tv] ", name)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s_%s.png" % [out_dir, league, name])


func _run() -> void:
	await _frames(2)
	I18n.apply("pt")
	get_tree().root.content_scale_factor = UILayout.device_scale()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await _frames(10)
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	var clubs: Array = w.clubs_in_league(league)
	clubs.sort_custom(func(a: Club, b: Club): return a.reputation > b.reputation)
	AppSettings.tutorial_done = true
	AppSettings.tv_graphics = 2
	GameManager.start_career(w, clubs[0].id, "Murilo", GameWorld.DIFF_NORMAL, 5)
	UIManager.apply_look()
	await _frames(10)
	# Pula supercopas e copas até o primeiro jogo da liga
	for i in 12:
		var nf := FixtureManager.next_fixture_for(w, w.user_club_id)
		if nf == null or nf.comp == league:
			break
		GameManager.play_instant()
	UIManager.goto("hub")
	await _frames(4)
	GameManager.begin_match()
	UIManager.replace("match")
	await _frames(12)
	var ms: Node = UIManager.current()
	UIManager.close_all_modals()
	ms.set("_paused", true)
	await _frames(6)
	var sim: MatchSimulation = ms.get("_sim")
	var tv: TvLayer = ms.get("_tv")
	var pk: Dictionary = ms.get("_pk")
	var home: Club = sim.teams[0].club
	var away: Club = sim.teams[1].club
	print("[tv] pacote: ", pk.get("id", ""), "  ", home.name, " x ", away.name)
	ms.call("_tv_info")
	await _wait(600)
	await _shot("01_inicio")
	tv.clear()
	var star: Player = null
	for mp: MatchPlayer in sim.teams[0].slots:
		if mp != null and Pos.group(mp.pos) == Pos.G_ATT and (star == null or mp.p.overall > star.overall):
			star = mp.p
	tv.play_banner(TvGraphics.goal_banner(pk, home, "23'"), 30.0, false)
	await _wait(700)
	await _shot("02_faixa_gol")
	tv.clear()
	tv.show_piece(TvGraphics.scorer_card(pk, w, star, home, "Gol  23'  ·  DE VIRADA", "2º gol no jogo  ·  9 gols na temporada"), TvLayer.LOWER, 60.0)
	await _wait(1600)
	await _shot("03_goleador")
	tv.clear()
	tv.show_piece(ms.call("_tv_stats", "Até aqui  ·  15'", false, true), TvLayer.CENTER, 60.0)
	await _wait(500)
	await _shot("04_numeros")
	tv.clear()
	var tb: Control = ms.call("_tv_table_piece")
	if tb != null:
		tv.show_piece(tb, TvLayer.CENTER, 60.0)
		await _wait(500)
		await _shot("05_tabela")
		tv.clear()
	var xi: Array = []
	for mp: MatchPlayer in sim.teams[1].slots:
		if mp != null:
			xi.append(mp.p)
	tv.show_piece(TvGraphics.sub_card(pk, away, xi[3], xi[8], "67'"), TvLayer.LOWER, 60.0)
	tv.show_piece(TvGraphics.other_goal(pk, clubs[2], clubs[5], 1, 0, 0, "Fulano 52'"), TvLayer.TOP, 60.0)
	await _wait(500)
	await _shot("06_subst_outro_jogo")
	tv.clear()
	tv.show_piece(TvGraphics.booking_card(pk, away, xi[5], true, "71'", true), TvLayer.LOWER, 60.0)
	await _wait(500)
	await _shot("07_cartao")
	tv.clear()
	# Titulares por setor (página da abertura) e melhor em campo, num diálogo
	var sp := UIKit.vbox(8)
	for sec in TvGraphics.sectors(sim.teams[0]):
		sp.add_child(TvGraphics.sector_card(pk, w, home, String(sec[0]), sec[1]))
	UIManager.show_modal(sp, true, false)
	await _wait(1800)
	await _shot("08_titulares")
	UIManager.close_all_modals()
	await _frames(4)
	var pv := UIKit.vbox(8)
	pv.add_child(TvGraphics.potm_card(pk, w, star, home, 8.7, "2 gols, 1 assistência"))
	UIManager.show_modal(pv, true, false)
	await _wait(1600)
	await _shot("09_melhor")
	UIManager.close_all_modals()
	await _frames(4)
	# Intervalo e fim de jogo de verdade
	ms.set("_paused", false)
	ms.set("_pace", 2)
	while sim.half == 1 and not sim.finished:
		sim.step()
	ms.call("_drain", true)
	ms.call("_show_halftime")
	await _wait(900)
	await _shot("10_intervalo")
	UIManager.close_all_modals()
	await _frames(4)
	ms.call("_skip_to_end")
	await _wait(6000)
	await _shot("11_fim")
	var sc: ScrollContainer = ms.get("_feed_scroll")
	sc.scroll_vertical = 700
	await _wait(600)
	await _shot("12_fim_b")
	get_tree().quit()
