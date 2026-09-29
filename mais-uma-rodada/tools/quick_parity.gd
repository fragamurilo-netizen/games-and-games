extends SceneTree
## Mede a velocidade de "Simular": joga N datas do usuário sem assistir e mostra o tempo de cada
## etapa (jogos, evolução, mercado...). Uso:
##   godot --headless --path . --script res://tools/sim_bench.gd -- --games=20


func _initialize() -> void:
	process_frame.connect(_start, CONNECT_ONE_SHOT)


func _start() -> void:
	var runner: Node = load("res://tools/quick_parity_runner.gd").new()
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		if kv.size() == 2:
			runner.set("opt_" + kv[0], kv[1])
	root.add_child(runner)
