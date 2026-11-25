extends SceneTree

func _initialize() -> void:
	process_frame.connect(func(): root.add_child(load("res://tests/save_resilience_runner.gd").new()), CONNECT_ONE_SHOT)
