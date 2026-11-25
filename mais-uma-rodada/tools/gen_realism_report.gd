extends SceneTree
## Realismo dos jogadores gerados no mundo novo: coerência entre atributos parecidos (velocidade x
## aceleração, marcação x desarme...), se o ponto forte de cada posição é da posição, idade e
## estrangeiros por divisão, altura e pé por posição.
## godot --headless --path . --script res://tools/gen_realism_report.gd


func _initialize() -> void:
	process_frame.connect(_start, CONNECT_ONE_SHOT)


func _start() -> void:
	var runner: Node = load("res://tools/gen_realism_report_runner.gd").new()
	root.add_child(runner)
