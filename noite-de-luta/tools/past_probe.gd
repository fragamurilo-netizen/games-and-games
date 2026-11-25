extends SceneTree
## Confere as lutas de antes do jogo (PastFights): o total bate com o cartel, a sequência do fim
## bate com `streak`, as datas vão em ordem e ninguém estreia antes dos 18. Mostra três exemplos.
## godot --headless --path . --script res://tools/past_probe.gd


func _initialize() -> void:
	process_frame.connect(_start, CONNECT_ONE_SHOT)


func _start() -> void:
	var runner: Node = load("res://tools/past_probe_runner.gd").new()
	root.add_child(runner)
