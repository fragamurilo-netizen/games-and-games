extends SceneTree

func _initialize() -> void:
	process_frame.connect(func():
		OS.low_processor_usage_mode = false
		root.add_child(load("res://tests/audio_regression_runner.gd").new()), CONNECT_ONE_SHOT)
