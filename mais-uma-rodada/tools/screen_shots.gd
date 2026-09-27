extends SceneTree
## Capturas de telas quaisquer: --screens=squad,contracts (param opcional: --pid=auto para a ficha do melhor jogador).
##
## Só teste (headless):  godot --headless --path . --script res://tools/screen_shots.gd
## Com capturas:         xvfb-run godot --path . --resolution 720x1280 --script res://tools/screen_shots.gd -- --out=/tmp/shots


func _initialize() -> void:
	process_frame.connect(_start, CONNECT_ONE_SHOT)


func _start() -> void:
	OS.low_processor_usage_mode = false
	var runner: Node = load("res://tools/screen_shots_runner.gd").new()
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		if kv.size() == 2:
			runner.set("opt_" + kv[0], kv[1])
	runner.set("shots", DisplayServer.get_name() != "headless" and String(runner.get("opt_out")) != "")
	if bool(runner.get("shots")):
		DirAccess.make_dir_recursive_absolute(String(runner.get("opt_out")))
	root.add_child(runner)
