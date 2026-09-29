extends SceneTree
func _initialize()->void:
	_start.call_deferred()
func _start()->void:
	await process_frame
	var runner=load("res://tests/refinement_visual_runner.gd").new()
	root.add_child(runner)
