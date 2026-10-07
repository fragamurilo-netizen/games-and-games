extends SceneTree
## Onde o carregamento do save gasta tempo, etapa por etapa (leitura, jogadores, mundo, ajustes).
## godot --headless --path . --script res://tools/load_profile.gd [-- --keep]
## Gera um mundo, começa uma carreira, salva no slot 19 e carrega medindo. --keep reaproveita o
## slot 19 de uma execução anterior (pula a geração).


func _initialize() -> void:
	process_frame.connect(_start, CONNECT_ONE_SHOT)


func _start() -> void:
	OS.low_processor_usage_mode = false
	var r: Node = load("res://tools/load_profile_runner.gd").new()
	r.set("keep", "--keep" in OS.get_cmdline_user_args())
	root.add_child(r)
