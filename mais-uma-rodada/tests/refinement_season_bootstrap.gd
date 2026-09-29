extends SceneTree
func _initialize()->void:
	_run.call_deferred()
func _run()->void:
	await process_frame
	var worker=load("res://tests/refinement_season.gd").new()
	await worker.run(self)
