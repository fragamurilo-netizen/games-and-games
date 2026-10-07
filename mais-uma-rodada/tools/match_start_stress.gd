extends SceneTree
## Começa várias partidas seguidas pelo caminho do botão (Início › Jogar › Iniciar partida), com
## janela (xvfb), e imprime memória e tempo de cada etapa. Serve para achar o jogo fechando ao
## iniciar a partida. Uso: xvfb-run -a godot --path . --resolution 390x844
##   --script res://tools/match_start_stress.gd -- [--games=6] [--fast] [--no-wait-save]


func _initialize() -> void:
	process_frame.connect(_start, CONNECT_ONE_SHOT)


func _start() -> void:
	OS.low_processor_usage_mode = false
	root.add_child(load("res://tools/match_start_stress_runner.gd").new())
