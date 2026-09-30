extends SceneTree
## Soak de combate (Game Design Bible §21): milhares de lutas entre atletas
## gerados, na mesma categoria. Mede a distribuição de métodos por sexo, a taxa
## de vitória do favorito técnico e o round das finalizações.
## godot --headless --path game -s res://tools/soak_fights.gd -- [lutas] [seed]
## O "favorito" usa uma média de atributos só para medir; o motor não a usa.
## A lógica fica em soak_lib.gd, carregada depois dos autoloads.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var total := int(args[0]) if args.size() > 0 else 2000
	var seed_base := int(args[1]) if args.size() > 1 else 1
	var lib: GDScript = load("res://tools/soak_lib.gd")
	print(JSON.stringify(lib.run(total, seed_base)))
	quit()
