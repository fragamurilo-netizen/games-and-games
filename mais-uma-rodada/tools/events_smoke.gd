extends SceneTree
## Monta cada tipo de evento do usuário, descreve e resolve todas as opções (pega erro de execução).
## godot --headless --path . --script res://tools/events_smoke.gd


func _initialize() -> void:
	process_frame.connect(func(): root.add_child(load("res://tools/events_smoke_runner.gd").new()), CONNECT_ONE_SHOT)
