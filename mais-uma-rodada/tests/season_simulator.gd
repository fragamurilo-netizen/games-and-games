extends SceneTree
## Simula N temporadas sem interface e gera um relatório de balanceamento.
## Uso:
##   godot --headless --path . --script res://tests/season_simulator.gd -- --seasons=100 --seed=123 --type=padrao --out=user://relatorio.md
##
## A lógica fica em season_simulator_runner.gd, carregado só depois do primeiro quadro: scripts usados
## direto por um --script são compilados antes dos autoloads existirem.


func _initialize() -> void:
	process_frame.connect(_start, CONNECT_ONE_SHOT)


func _start() -> void:
	root.add_child(load("res://tests/season_simulator_runner.gd").new())
