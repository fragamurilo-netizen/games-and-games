extends SceneTree
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	await process_frame
	var script=load("res://tests/realism_suite.gd")
	if script==null or not script.can_instantiate(): quit(2);return
	var code:int=await script.new().run(self)
	quit(code)
