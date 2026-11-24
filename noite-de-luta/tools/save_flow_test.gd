extends SceneTree
## Teste do caminho real de salvar: funda uma carreira, vira semanas pelo botão do Início (com o
## aviso "Fechando a semana"), confere que o arquivo só é escrito quando o jogador para de tocar,
## que duas semanas seguidas gravam na hora, que pausar o app grava, e que "Continuar" no menu
## abre a carreira de volta. Usa o save de verdade em user:// (apaga no fim).
## xvfb-run -a -s "-screen 0 1900x1900x24" godot --path . --resolution 780x1688 --script res://tools/save_flow_test.gd -- --out=DIR


func _initialize() -> void:
	process_frame.connect(_start, CONNECT_ONE_SHOT)


func _start() -> void:
	OS.low_processor_usage_mode = false
	# A abertura animada fica desligada (--abertura liga, para quem quer capturá-la).
	AppSettings.intro = "--abertura" in OS.get_cmdline_user_args()
	var runner: Node = load("res://tools/save_flow_test_runner.gd").new()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			runner.set("out_dir", a.substr(6))
	root.add_child(runner)
