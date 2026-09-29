extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	await process_frame
	var suite = load("res://tests/depth_suite.gd")
	if suite == null or not suite.can_instantiate():
		push_error("DEPTH_FAIL: suite compilation")
		quit(2)
		return
	var result: int = await suite.new().run(self)
	quit(result)
