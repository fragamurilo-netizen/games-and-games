extends Node
## Lógica do broadcast_shots.gd (carregada depois dos autoloads).

var opt_out := ""
var opt_league := "ARG1"
var opt_days := "3"
var opt_wx := "" # força o clima: sun, cloud, rain, storm, snow, heat, wind, fog
var opt_night := "0"
var opt_quick := "0" # 1: só abertura, placar e um trecho do jogo
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
	for i in int(opt_days):
		SeasonManager.play_matchday_instant(w)
	var clubs := w.clubs_in_league(opt_league)
	clubs.sort_custom(func(a: Club, b: Club): return a.reputation > b.reputation)
	AppSettings.tutorial_done = true
	GameManager.start_career(w, clubs[0].id, "Teste", GameWorld.DIFF_NORMAL, 5)
	UIManager.goto("hub")
	await _frames(6)
	UIManager.close_all_modals()
	GameManager.begin_match()
	if opt_wx != "":
		var sim0 := GameManager.user_sim()
		sim0.wx = {"kind": opt_wx, "night": opt_night == "1", "temp": 20, "fx": Weather.effects(opt_wx, 20.0)}
	UIManager.replace("match")
	await _frames(12)
	await _shot("b01_abertura")
	var ms: BaseScreen = UIManager.current()
	UIManager.close_all_modals()
	await _frames(4)
	UIManager.close_all_modals()
	await _frames(4)
	await _shot("b02_placar_emissora")
	if opt_quick == "1":
		ms.set("_pace", 1)
		for i in 240:
			await get_tree().process_frame
			if UIManager.has_modal():
				UIManager.close_all_modals()
		await _shot("b03_jogo")
		get_tree().quit()
		return
	ms.set("_pace", 1)
	var got_goal := false
	var got_half := false
	var guard := Time.get_ticks_msec() + 240000
	while not bool(ms.get("_done")) and Time.get_ticks_msec() < guard:
		await get_tree().process_frame
		if UIManager.has_modal() and not bool(ms.get("_halftime")):
			UIManager.close_all_modals()
		var l3: PanelContainer = ms.get("_l3")
		if not got_goal and l3 != null and l3.visible and l3.modulate.a > 0.9:
			got_goal = true
			await _shot("b03_tarja_gol")
		if not got_half and bool(ms.get("_halftime")):
			got_half = true
			await _frames(8)
			await _shot("b04_intervalo")
			UIManager.close_all_modals()
			ms.call("_start_second_half")
	await _frames(10)
	UIManager.close_all_modals()
	await _frames(4)
	await _shot("b05_fim")
	var sim: MatchSimulation = ms.get("_sim")
	print("fim: %d x %d · torcida tocando: %s" % [sim.score[0], sim.score[1], str(AudioManager.get("_crowd_p")[0].playing)])
	get_tree().quit()
