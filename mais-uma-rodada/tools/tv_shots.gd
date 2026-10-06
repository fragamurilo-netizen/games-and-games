extends SceneTree
## Capturas do grafismo de TV de uma liga (placar do pacote, faixa do gol, goleador, números,
## tabela, substituição, cartão, outro jogo, informação, melhor em campo e titulares por setor).
## xvfb-run -a -s "-screen 0 1400x1400x24" godot --path . --resolution 390x844 --script res://tools/tv_shots.gd -- --out=DIR --league=ENG1
## A lógica fica em tv_shots_runner.gd (carregado depois do primeiro quadro, com os autoloads).


func _initialize() -> void:
	process_frame.connect(_start, CONNECT_ONE_SHOT)


func _start() -> void:
	OS.low_processor_usage_mode = false
	var runner: Node = load("res://tools/tv_shots_runner.gd").new()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			runner.set("out_dir", a.substr(6))
		if a.begins_with("--league="):
			runner.set("league", a.substr(9))
	DirAccess.make_dir_recursive_absolute(String(runner.get("out_dir")))
	root.add_child(runner)
