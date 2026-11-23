extends SceneTree
## Capturas do editor de visual (tela "look") numa carreira de teste: uma lutadora e um lutador,
## aba por aba.
## xvfb-run -a -s "-screen 0 1400x1400x24" godot --path . --resolution 390x844 --script res://tools/look_shots.gd -- --out=DIR
## A lógica fica em look_shots_runner.gd, carregado depois do primeiro quadro (autoloads).


func _initialize() -> void:
	process_frame.connect(_start, CONNECT_ONE_SHOT)


func _start() -> void:
	OS.low_processor_usage_mode = false
	var runner: Node = load("res://tools/look_shots_runner.gd").new()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			runner.set("out_dir", a.substr(6))
	DirAccess.make_dir_recursive_absolute(String(runner.get("out_dir")))
	root.add_child(runner)
