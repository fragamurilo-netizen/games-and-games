extends SceneTree
## Confere o laboratório de rostos: abre pelo Editor do menu inicial, troca semente e ajustes, gera
## a grade de 100 e salva capturas.
## Headless:      godot --headless --path . --script res://tools/face_lab_check.gd
## Com capturas:  xvfb-run godot --path . --resolution 720x1280 --script res://tools/face_lab_check.gd -- --out=DIR


func _initialize() -> void:
	process_frame.connect(_start, CONNECT_ONE_SHOT)


func _start() -> void:
	OS.low_processor_usage_mode = false
	var runner: Node = load("res://tools/face_lab_check_runner.gd").new()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			runner.set("out_dir", a.substr(6))
	root.add_child(runner)
