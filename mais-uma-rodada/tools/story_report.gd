extends SceneTree
## "O mundo conta histórias?" — joga N temporadas com um clube de usuário no piloto automático e
## mede o que faz um save de gestão ficar vivo (ou previsível): disputa pelos títulos, vida dos
## jogadores (revelações, decadências, viradas), mercado das estrelas e variedade das notícias.
## Uso: godot --headless --path . --script res://tools/story_report.gd -- --seasons=5 --league=BRA1


func _initialize() -> void:
	process_frame.connect(func():
		var r: Node = load("res://tools/story_report_runner.gd").new()
		for a in OS.get_cmdline_user_args():
			var kv := a.trim_prefix("--").split("=")
			if kv.size() == 2:
				r.set("opt_" + kv[0], kv[1])
		root.add_child(r), CONNECT_ONE_SHOT)
