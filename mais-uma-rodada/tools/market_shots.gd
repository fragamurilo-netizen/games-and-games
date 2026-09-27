extends SceneTree
## Capturas da tela de transferências (busca, lista de observação, movimentações).
## xvfb-run godot --path . --resolution 720x1280 --script res://tools/market_shots.gd -- --out=/tmp/mercado


func _initialize() -> void:
	process_frame.connect(_start, CONNECT_ONE_SHOT)


func _start() -> void:
	OS.low_processor_usage_mode = false
	var runner: Node = load("res://tools/market_shots_runner.gd").new()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			runner.set("out_dir", a.substr(6))
	DirAccess.make_dir_recursive_absolute(String(runner.get("out_dir")))
	root.add_child(runner)
