extends SceneTree
## Teste com renderização real: texturas continuam válidas depois de expulsas do cache.
## godot --path . --script res://tests/render_lifecycle.gd -- --out=DIR

func _initialize() -> void:
	process_frame.connect(func(): root.add_child(load("res://tests/render_lifecycle_runner.gd").new()), CONNECT_ONE_SHOT)
