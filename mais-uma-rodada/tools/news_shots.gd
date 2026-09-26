extends SceneTree
## Capturas da apresentação de reforço e da aba de notícias.
## xvfb-run godot --path . --resolution 720x1280 --script res://tools/news_shots.gd
func _initialize() -> void:
	process_frame.connect(_start, CONNECT_ONE_SHOT)
func _start() -> void:
	OS.low_processor_usage_mode = false
	var runner: Node = load("res://tools/news_shots_runner.gd").new()
	DirAccess.make_dir_recursive_absolute(String(runner.get("out_dir")))
	root.add_child(runner)
