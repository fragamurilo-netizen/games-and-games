extends SceneTree
## Capturas da tela de patrocínios em clubes de vários países (marcas do BrandCatalog).
## xvfb-run godot --path . --resolution 720x1280 --script res://tools/sponsor_shots.gd -- --out=/tmp/sponsors --league=ENG1


func _initialize() -> void:
	process_frame.connect(_start, CONNECT_ONE_SHOT)


func _start() -> void:
	var runner: Node = load("res://tools/sponsor_shots_runner.gd").new()
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		if kv.size() == 2:
			runner.set("opt_" + kv[0], kv[1])
	DirAccess.make_dir_recursive_absolute(String(runner.get("opt_out")))
	root.add_child(runner)
