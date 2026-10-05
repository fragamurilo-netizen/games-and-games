extends SceneTree
## Raio-x dos elencos gerados: alguns clubes por extenso e números do mundo inteiro (diferença
## entre craque e média, papéis no elenco, idades, crias da casa, perfis de overall).
## godot --headless --path . --script res://tools/squad_report.gd [-- --clubs=Flamengo,Real Madrid]


func _initialize() -> void:
	process_frame.connect(_start, CONNECT_ONE_SHOT)


func _start() -> void:
	var runner: Node = load("res://tools/squad_report_runner.gd").new()
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		if kv.size() == 2:
			runner.set("opt_" + kv[0], kv[1])
	root.add_child(runner)
