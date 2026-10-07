extends SceneTree
## Desempenho do que o jogador sente: gerar o mundo, começar a carreira, cada data (até o próximo
## jogo), o fim de temporada (por etapa), salvar e carregar, e abrir as telas principais.
## godot --headless --path . --script res://tools/perf_deep.gd -- [--days=12] [--season] [--screens]
## A lógica fica em perf_deep_runner.gd (carregado depois dos autoloads).


func _initialize() -> void:
	process_frame.connect(_start, CONNECT_ONE_SHOT)


func _start() -> void:
	OS.low_processor_usage_mode = false
	var r: Node = load("res://tools/perf_deep_runner.gd").new()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--days="):
			r.set("days", int(a.substr(7)))
		if a == "--season":
			r.set("season", true)
		if a == "--screens":
			r.set("screens", true)
	root.add_child(r)
