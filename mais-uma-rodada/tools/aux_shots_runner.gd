extends Node
## Lógica do aux_shots.gd (carregada depois dos autoloads).

var opt_out := ""
var opt_league := "BRA1"
var opt_days := "10"
var shots := false


func _ready() -> void:
	_run()


func _frames(k: int) -> void:
	for i in k:
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	print("[captura] ", shot_name)
	if not shots:
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [opt_out, shot_name])


func _run() -> void:
	await _frames(2)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await _frames(6)
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	# Algumas rodadas antes: os clubes já têm diário tático para estudar.
	for i in int(opt_days):
		SeasonManager.play_matchday_instant(w)
	var clubs := w.clubs_in_league(opt_league)
	clubs.sort_custom(func(a: Club, b: Club): return a.capacity > b.capacity)
	AppSettings.tutorial_done = true
	GameManager.start_career(w, clubs[0].id, "Teste", GameWorld.DIFF_NORMAL, 5)
	UIManager.goto("hub")
	await _frames(6)
	UIManager.close_all_modals()
	UIManager.push("prematch")
	await _frames(10)
	await _shot("a01_dossie")
	var pre: BaseScreen = UIManager.current()
	pre.scroll().scroll_vertical = 700
	await _frames(6)
	await _shot("a02_dossie_plano")
	GameManager.begin_match()
	UIManager.replace("match")
	await _frames(6)
	var ms: BaseScreen = UIManager.current()
	UIManager.close_all_modals()
	ms.set("_pace", 2)
	var got_aux := 0
	var got_half := false
	var guard := Time.get_ticks_msec() + 180000
	while not bool(ms.get("_done")) and Time.get_ticks_msec() < guard:
		await get_tree().process_frame
		UIManager.close_all_modals() if not bool(ms.get("_halftime")) and UIManager.has_modal() else null
		var bar: PanelContainer = ms.get("_aux_bar")
		if got_aux < 3 and bar != null and bar.visible:
			got_aux += 1
			await _frames(3)
			var sim0: MatchSimulation = ms.get("_sim")
			print("auxiliar %s': %s" % [sim0.display_minute(), (ms.get("_aux_text") as Label).text])
			await _shot("a%02d_auxiliar_ao_vivo" % (2 + got_aux))
			ms.call("_hide_aux")
		if not got_half and bool(ms.get("_halftime")):
			got_half = true
			await _frames(8)
			await _shot("a06_intervalo")
			UIManager.close_all_modals()
			ms.call("_open_tactics")
			await _frames(6)
			await _shot("a07_ajustes")
			UIManager.close_all_modals()
			ms.call("_start_second_half")
	var sim: MatchSimulation = ms.get("_sim")
	for ev in sim.events:
		if int(ev["t"]) == MatchSimulation.EV_TACTIC:
			print("mudança %d' lado %d: %s" % [ev["m"], ev["s"], str(ev.get("x", {}))])
	print("fim: %d x %d" % [sim.score[0], sim.score[1]])
	get_tree().quit()
