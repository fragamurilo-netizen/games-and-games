extends SceneTree

func _initialize() -> void:
	process_frame.connect(_start, CONNECT_ONE_SHOT)

func _start() -> void:
	OS.low_processor_usage_mode = false
	var runner: Node = load("res://tools/career_mobile_review_runner.gd").new()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			runner.set("out_dir", arg.substr(6))
	root.add_child(runner)
