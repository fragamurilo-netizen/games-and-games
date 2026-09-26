extends SceneTree
## Auxiliar técnico: dossiê do pré-jogo, leituras durante a partida, intervalo e ajustes finos.
##
## Só teste (headless):  godot --headless --path . --script res://tools/aux_shots.gd
## Com capturas:         xvfb-run godot --path . --resolution 720x1280 --script res://tools/aux_shots.gd -- --out=/tmp/shots


func _initialize() -> void:
	process_frame.connect(_start, CONNECT_ONE_SHOT)


func _start() -> void:
	OS.low_processor_usage_mode = false
	var runner: Node = load("res://tools/aux_shots_runner.gd").new()
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		if kv.size() == 2:
			runner.set("opt_" + kv[0], kv[1])
	runner.set("shots", DisplayServer.get_name() != "headless" and String(runner.get("opt_out")) != "")
	if bool(runner.get("shots")):
		DirAccess.make_dir_recursive_absolute(String(runner.get("opt_out")))
	root.add_child(runner)
