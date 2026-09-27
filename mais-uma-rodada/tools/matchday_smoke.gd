extends SceneTree
## Dia de jogo completo com janela (xvfb): carreira nova, save em segundo plano, pré-jogo, partida
## inteira na tela, resultado, próximo dia. Imprime cada etapa para achar onde o jogo fecha.


func _initialize() -> void:
	process_frame.connect(_start, CONNECT_ONE_SHOT)


func _start() -> void:
	OS.low_processor_usage_mode = false
	root.add_child(load("res://tools/matchday_smoke_runner.gd").new())
