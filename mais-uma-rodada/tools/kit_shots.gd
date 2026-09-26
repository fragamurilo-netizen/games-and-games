extends SceneTree
## Capturas do editor de uniformes, do convite de lançamento e do histórico.
## xvfb-run godot --path . --resolution 720x1280 --script res://tools/kit_shots.gd -- --out=/tmp/kits


func _initialize() -> void:
	process_frame.connect(_start, CONNECT_ONE_SHOT)


func _start() -> void:
	OS.low_processor_usage_mode = false
	var runner: Node = load("res://tools/kit_shots_runner.gd").new()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			runner.set("out_dir", a.substr(6))
	DirAccess.make_dir_recursive_absolute(String(runner.get("out_dir")))
	root.add_child(runner)
