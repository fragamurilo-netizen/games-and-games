extends SceneTree

func _initialize() -> void:
	process_frame.connect(func(): root.add_child(load("res://tests/asset_cache_regression_runner.gd").new()), CONNECT_ONE_SHOT)
