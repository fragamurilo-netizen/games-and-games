extends SceneTree
## Sonda das telas: abre um save (de preferência de carreira longa) e mede quanto tempo cada
## tela leva para ser montada. Serve para achar tela pesada em celular fraco.
## xvfb-run -a -s "-screen 0 1900x1900x24" godot --path . --resolution 780x1688 --script res://tools/screens_perf.gd -- --in=SAVE.json
## A lógica fica em screens_perf_runner.gd, carregado depois do primeiro quadro (autoloads).


func _initialize() -> void:
	process_frame.connect(_start, CONNECT_ONE_SHOT)


func _start() -> void:
	OS.low_processor_usage_mode = false
	var runner: Node = load("res://tools/screens_perf_runner.gd").new()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--in="):
			runner.set("in_path", a.substr(5))
	root.add_child(runner)
