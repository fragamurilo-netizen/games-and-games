extends SceneTree
## Passeio automático por todas as telas com uma carreira real: teste de fumaça da UI
## (qualquer erro de script aparece no log) e, com vídeo disponível, capturas de tela.
##
## Headless (só teste):  godot --headless --path . --script res://tools/screenshot_tour.gd
## Com capturas:         xvfb-run godot --path . --resolution 720x1280 --script res://tools/screenshot_tour.gd -- --out=/tmp/shots
##
## A lógica fica em tour_runner.gd, carregado só depois do primeiro quadro: scripts usados
## direto por um --script são compilados antes dos autoloads existirem.


func _initialize() -> void:
	process_frame.connect(_start, CONNECT_ONE_SHOT)


func _start() -> void:
	# Em modo de baixo consumo só há novo quadro quando algo muda; as capturas precisam de todos.
	OS.low_processor_usage_mode = false
	var runner: Node = load("res://tools/tour_runner.gd").new()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			runner.set("out_dir", a.substr(6))
	var out: String = runner.get("out_dir")
	runner.set("shots", DisplayServer.get_name() != "headless" and out != "")
	if bool(runner.get("shots")):
		DirAccess.make_dir_recursive_absolute(out)
	root.add_child(runner)
