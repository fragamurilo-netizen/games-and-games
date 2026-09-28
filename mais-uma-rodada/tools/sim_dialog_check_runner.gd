extends Node
## Lógica de tools/sim_dialog_check.gd (carregada depois dos autoloads).

const SLOT := 98

var opt_games := "6"


func _ready() -> void:
	_run()


func _run() -> void:
	await get_tree().process_frame
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await get_tree().process_frame
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	AppSettings.tutorial_done = true
	GameManager.start_career(w, w.clubs_in_league("BRA1")[3].id, "Teste", GameWorld.DIFF_NORMAL, SLOT)
	UIManager.goto("hub")
	UIManager.close_all_modals()
	await get_tree().process_frame
	var n := int(opt_games)
	SimDialog.stop_on_events = false
	var turn0 := w.season.turn
	SimDialog.start(SimDialog.MODE_GAMES, n, func(): pass)
	var t0 := Time.get_ticks_msec()
	var worst := 0
	var frames := 0
	var last := Time.get_ticks_msec()
	for i in 3:
		await get_tree().process_frame
	if not GameManager.in_batch():
		print("o Simular não começou")
	while GameManager.is_simulating() or GameManager.in_batch():
		await get_tree().process_frame
		var now := Time.get_ticks_msec()
		worst = maxi(worst, now - last)
		last = now
		frames += 1
		if now - t0 > 600000:
			break
	var played := w.season.turn - turn0
	print("jogos: %d em %d ms · %d quadros · maior quadro %d ms" % [played, Time.get_ticks_msec() - t0, frames, worst])
	var ok := played == n and not GameManager.in_batch()
	print("save no fim: ", FileAccess.file_exists(SaveManager.slot_path(SLOT)))
	SaveManager.delete_slot(SLOT)
	print("SIM_DIALOG_CHECK ", "OK" if ok else "FALHOU")
	get_tree().quit(0 if ok else 1)
