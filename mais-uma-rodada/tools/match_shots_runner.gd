extends Node
## Lógica do match_shots.gd (carregada depois dos autoloads).

var opt_out := ""
var opt_league := "BRA1"
var opt_kind := ""
var opt_pace := "0"
var opt_secs := "40"
var opt_night := ""
var opt_skip := ""
var opt_rain := ""
var shots := false
var n := 0


func _ready() -> void:
	_run()


func _frames(k: int) -> void:
	for i in k:
		await get_tree().process_frame


func _wait(sec: float) -> void:
	var t := Time.get_ticks_msec() + int(sec * 1000.0)
	while Time.get_ticks_msec() < t:
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	n += 1
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
	var clubs := w.clubs_in_league(opt_league)
	clubs.sort_custom(func(a: Club, b: Club): return a.capacity > b.capacity)
	var club_id: int = clubs[0].id
	AppSettings.tutorial_done = true
	GameManager.start_career(w, club_id, "Teste", GameWorld.DIFF_NORMAL, 5)
	UIManager.goto("hub")
	await _frames(6)
	UIManager.close_all_modals()
	GameManager.begin_match()
	UIManager.replace("match")
	await _frames(6)
	var ms: BaseScreen = UIManager.current()
	UIManager.close_all_modals()
	var pitch: PitchView = ms.get("_pitch")
	if opt_kind != "" or opt_night != "" or opt_rain != "":
		var st: Dictionary = pitch.stadium.duplicate()
		if opt_kind != "":
			st["kind"] = opt_kind
		if opt_night != "":
			st["night"] = opt_night == "1"
		if opt_rain != "":
			st["rain"] = opt_rain == "1"
		pitch.stadium = st
	ms.set("_pace", int(opt_pace))
	pitch.motion.tempo = [1.45, 2.3, 4.2][int(opt_pace)]
	print("estádio: ", pitch.stadium.get("kind"), " clima: ", pitch.stadium.get("weather"), " placar: ", ScoreboardTheme.layout_for(GameManager.user_fixture().comp))
	var secs := float(opt_secs)
	var t0 := Time.get_ticks_msec()
	var k := 0
	var got_goal := false
	var sim0: MatchSimulation = ms.get("_sim")
	var seen := 0
	var goal_seq := 0
	var next_shot := Time.get_ticks_msec() + int(secs * 1000.0 / 6.0)
	while Time.get_ticks_msec() - t0 < int(secs * 1000.0) and not bool(ms.get("_done")):
		await get_tree().process_frame
		# Gol novo na simulação: fotografa a jogada enquanto o campo encena o lance.
		while seen < sim0.events.size():
			var e: Dictionary = sim0.events[seen]
			seen += 1
			if int(e["t"]) == MatchSimulation.EV_GOAL and goal_seq < 2:
				goal_seq += 1
				for j in 5:
					await _wait(0.45)
					await _shot("gol%d_%d" % [goal_seq, j])
		if Time.get_ticks_msec() < next_shot:
			continue
		next_shot = Time.get_ticks_msec() + int(secs * 1000.0 / 6.0)
		if UIManager.has_modal():
			UIManager.close_all_modals()
			if bool(ms.get("_halftime")):
				ms.call("_start_second_half")
		k += 1
		var mo := pitch.motion
		print("  dono: ", mo.owner.name if mo.owner != null else "-", " modo: ", mo.mode, " fila: ", mo._queue.size(), " voo: ", not mo._fl.is_empty(), " posse: ", mo.poss)
		await _shot("partida_%02d" % k)
		var ov: GoalOverlay = ms.get("_overlay")
		if not got_goal and ov != null and ov.is_playing():
			got_goal = true
	if opt_skip == "1":
		ms.call("_skip_to_end")
	# Resto do jogo em turbo (confere que roda até o fim sem erro).
	ms.set("_pace", 2)
	pitch.motion.tempo = 4.2
	var guard := Time.get_ticks_msec() + 240000
	var half_shot := false
	while not bool(ms.get("_done")) and Time.get_ticks_msec() < guard:
		await get_tree().process_frame
		if bool(ms.get("_halftime")):
			if not half_shot:
				half_shot = true
				await _frames(4)
				await _shot("intervalo")
			UIManager.close_all_modals()
			ms.call("_start_second_half")
		elif UIManager.has_modal():
			UIManager.close_all_modals()
	await _frames(10)
	await _shot("fim")
	var sim: MatchSimulation = ms.get("_sim")
	print("fim: %d x %d, eventos %d, minuto %d" % [sim.score[0], sim.score[1], sim.events.size(), sim.minute])
	get_tree().quit()
