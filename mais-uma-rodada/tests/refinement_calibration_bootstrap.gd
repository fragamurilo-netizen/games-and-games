extends SceneTree
func _initialize()->void:_run.call_deferred()
func _run()->void:
	await process_frame
	await load("res://tests/refinement_calibration.gd").new().run(self)
