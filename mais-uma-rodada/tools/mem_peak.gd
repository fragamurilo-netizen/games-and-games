extends SceneTree
## Pico de memória durante o save e o load (o que faz o Android fechar o jogo).


func _initialize() -> void:
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	var base := OS.get_static_memory_usage()
	var p0 := OS.get_static_memory_peak_usage()
	print("mundo na memória: %d MB (pico até aqui %d MB)" % [base / 1048576, p0 / 1048576])
	SaveManager.save_world(w, 9)
	var p1 := OS.get_static_memory_peak_usage()
	print("save: pico %d MB (+%d MB acima do mundo)" % [p1 / 1048576, (p1 - base) / 1048576])
	w = null
	var before := OS.get_static_memory_usage()
	var w2 := SaveManager.load_world(9)
	var after := OS.get_static_memory_usage()
	print("load: mundo carregado %d MB · pico geral %d MB" % [(after - before) / 1048576, OS.get_static_memory_peak_usage() / 1048576])
	SaveManager.delete_slot(9)
	quit()
