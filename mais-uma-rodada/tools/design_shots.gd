extends SceneTree
## Capturas rápidas das telas principais (revisão do sistema de design).
## (qualquer erro de script aparece no log) e, com vídeo disponível, capturas de tela.
##
## Headless (só teste):  godot --headless --path . --script res://tools/screenshot_tour.gd
## Com capturas:         xvfb-run godot --path . --resolution 720x1280 --script res://tools/screenshot_tour.gd -- --out=/tmp/shots
## Em outro idioma:      acrescente --lang=en (ou es) depois do "--".
## Com --only=...: --light (modo claro), --club=nome (clube escolhido pelo nome, em qualquer liga)
## e --tint=0|1|2 (tingimento do fundo com a cor do clube); --nt=BRA: o técnico também comanda a seleção.
##
## A lógica fica em design_shots_runner.gd, carregado só depois do primeiro quadro: scripts usados
## direto por um --script são compilados antes dos autoloads existirem.


func _initialize() -> void:
	process_frame.connect(_start, CONNECT_ONE_SHOT)


func _start() -> void:
	# Em modo de baixo consumo só há novo quadro quando algo muda; as capturas precisam de todos.
	OS.low_processor_usage_mode = false
	var runner: Node = load("res://tools/design_shots_runner.gd").new()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			runner.set("out_dir", a.substr(6))
		if a == "--tablet":
			runner.set("tablet", true)
		if a.begins_with("--prefix="):
			runner.set("prefix", a.substr(9))
		if a.begins_with("--only="):
			runner.set("only", a.substr(7))
		if a.begins_with("--rounds="):
			runner.set("rounds", int(a.substr(9)))
		if a == "--light":
			runner.set("light", true)
		if a.begins_with("--nt="):
			runner.set("nt", a.substr(5))
		if a.begins_with("--club="):
			runner.set("club_name", a.substr(7))
		if a.begins_with("--tint="):
			runner.set("tint", int(a.substr(7)))
		if a.begins_with("--lang="):
			runner.set("lang", a.substr(7))
	var out: String = runner.get("out_dir")
	runner.set("shots", DisplayServer.get_name() != "headless" and out != "")
	if bool(runner.get("shots")):
		DirAccess.make_dir_recursive_absolute(out)
	root.add_child(runner)
