extends SceneTree
## Fluxos relatados pelos testadores; usa o espaço 99, fora dos saves do jogador.

func _initialize() -> void:
	process_frame.connect(_start, CONNECT_ONE_SHOT)


func _start() -> void:
	OS.low_processor_usage_mode = false
	root.add_child(load("res://tests/android_reliability_runner.gd").new())
