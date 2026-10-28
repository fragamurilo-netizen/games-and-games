extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.add_child(load("res://tests/divisions_regression_runner.gd").new())
