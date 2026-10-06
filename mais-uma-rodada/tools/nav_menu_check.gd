extends SceneTree
## Confere o menu ☰ da barra superior: abre o menu, toca em cada item e vê se a tela abre.
## Headless:      godot --headless --path . --script res://tools/nav_menu_check.gd
## Com capturas:  xvfb-run godot --path . --resolution 720x1280 --script res://tools/nav_menu_check.gd -- --out=DIR


func _initialize() -> void:
	process_frame.connect(_start, CONNECT_ONE_SHOT)


func _start() -> void:
	OS.low_processor_usage_mode = false
	var runner: Node = load("res://tools/nav_menu_check_runner.gd").new()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			runner.set("out_dir", a.substr(6))
	root.add_child(runner)
