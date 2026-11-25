extends SceneTree
## Tempo para abrir cada menu, frio e quente, e para voltar a ele (aba e "voltar").
## xvfb-run -a godot --path . --resolution 390x844 --script res://tools/menu_perf.gd
## A lógica fica em menu_perf_runner.gd (carregado depois dos autoloads).


func _initialize() -> void:
	process_frame.connect(_start, CONNECT_ONE_SHOT)


func _start() -> void:
	OS.low_processor_usage_mode = false
	root.add_child(load("res://tools/menu_perf_runner.gd").new())
