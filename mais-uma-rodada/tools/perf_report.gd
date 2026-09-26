extends SceneTree
## Tempos das operações pesadas (gerar mundo, salvar, carregar, avançar até o jogo do usuário).
## Uso: godot --headless --path . --script res://tools/perf_report.gd


func _initialize() -> void:
	var t := Time.get_ticks_msec()
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	print("gerar mundo: %d ms" % (Time.get_ticks_msec() - t))
	w.user_club_id = w.clubs_in_league("BRA1")[0].id
	t = Time.get_ticks_msec()
	var d := w.to_dict()
	print("to_dict: %d ms" % (Time.get_ticks_msec() - t))
	t = Time.get_ticks_msec()
	SaveManager.save_world(w, 9)
	print("salvar: %d ms (%d KB)" % [Time.get_ticks_msec() - t, FileAccess.get_file_as_bytes(SaveManager.slot_path(9)).size() / 1024])
	t = Time.get_ticks_msec()
	var w2 := SaveManager.load_world(9)
	print("carregar: %d ms (%s)" % [Time.get_ticks_msec() - t, "ok" if w2 != null else "falhou"])
	t = Time.get_ticks_msec()
	SaveManager.save_world(w2, 9)
	print("salvar depois de carregar: %d ms" % (Time.get_ticks_msec() - t))
	t = Time.get_ticks_msec()
	var f := FileAccess.open_compressed(SaveManager.slot_path(9), FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	var raw: Variant = f.get_var(false)
	print("  ler+descomprimir: %d ms" % (Time.get_ticks_msec() - t))
	t = Time.get_ticks_msec()
	var un: Variant = SaveManager._unpack_file(raw)
	print("  abrir blocos: %d ms" % (Time.get_ticks_msec() - t))
	t = Time.get_ticks_msec()
	GameWorld.from_dict(un)
	print("  from_dict: %d ms" % (Time.get_ticks_msec() - t))
	for i in 3:
		t = Time.get_ticks_msec()
		SeasonManager.advance_to_user(w)
		print("avançar até o jogo %d: %d ms" % [i, Time.get_ticks_msec() - t])
	SaveManager.delete_slot(9)
	d.clear()
	quit()
