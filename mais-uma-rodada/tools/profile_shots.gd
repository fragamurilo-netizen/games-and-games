extends SceneTree
## Capturas só da tela do jogador (visão geral rolada, números, carreira), sem o passeio inteiro.
## xvfb-run godot --path . --resolution 720x1280 --script res://tools/profile_shots.gd -- --out=/tmp/perfil


func _initialize() -> void:
	process_frame.connect(_start, CONNECT_ONE_SHOT)


func _start() -> void:
	OS.low_processor_usage_mode = false
	var runner: Node = load("res://tools/profile_shots_runner.gd").new()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			runner.set("out_dir", a.substr(6))
	DirAccess.make_dir_recursive_absolute(String(runner.get("out_dir")))
	root.add_child(runner)
