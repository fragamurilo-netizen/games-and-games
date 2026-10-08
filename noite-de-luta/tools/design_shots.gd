extends SceneTree
## Capturas das telas do jogo numa carreira de teste.
## xvfb-run -a -s "-screen 0 1400x1400x24" godot --path . --resolution 390x844 --script res://tools/design_shots.gd -- --out=DIR [--role=presidente]
## A lógica fica em design_shots_runner.gd, carregado depois do primeiro quadro (autoloads).


func _initialize() -> void:
	process_frame.connect(_start, CONNECT_ONE_SHOT)


func _start() -> void:
	OS.low_processor_usage_mode = false
	var path := "res://tools/design_shots_runner.gd"
	for a in OS.get_cmdline_user_args():
		if a == "--role=presidente":
			path = "res://tools/president_shots_runner.gd"
	var runner: Node = load(path).new()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			runner.set("out_dir", a.substr(6))
		if a.begins_with("--prefix="):
			runner.set("prefix", a.substr(9))
	DirAccess.make_dir_recursive_absolute(String(runner.get("out_dir")))
	root.add_child(runner)
