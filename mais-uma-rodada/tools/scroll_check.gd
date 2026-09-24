extends SceneTree
## Verifica a rolagem por arrasto (TouchScroll) simulando toques de verdade:
## arrastar sobre as linhas do elenco rola a tela sem abrir o jogador, um toque simples
## ainda abre o perfil e, ao voltar, a lista continua onde estava.
##
## godot --headless --path . --script res://tools/scroll_check.gd


func _initialize() -> void:
	process_frame.connect(_start, CONNECT_ONE_SHOT)


func _start() -> void:
	OS.low_processor_usage_mode = false
	root.add_child(load("res://tools/scroll_check_runner.gd").new())
