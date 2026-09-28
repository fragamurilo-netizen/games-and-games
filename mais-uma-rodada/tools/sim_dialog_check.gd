extends SceneTree
## Confere o "Simular" em thread: abre uma carreira, simula N jogos pela folha e mede o maior
## quadro (a tela não pode travar enquanto as datas rodam) e se o save saiu no fim.
## Uso: godot --headless --path . --script res://tools/sim_dialog_check.gd -- --games=6


func _initialize() -> void:
	process_frame.connect(_start, CONNECT_ONE_SHOT)


func _start() -> void:
	OS.low_processor_usage_mode = false
	var runner: Node = load("res://tools/sim_dialog_check_runner.gd").new()
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		if kv.size() == 2:
			runner.set("opt_" + kv[0], kv[1])
	root.add_child(runner)
