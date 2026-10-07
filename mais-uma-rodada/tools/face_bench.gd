extends SceneTree
## Custo de geração e repetição do cache dos retratos, sem gerar um mundo.
## godot --path . --resolution 1280x960 --script res://tools/face_bench.gd -- --size=320 --count=12
## --portrait=res://...gd permite comparar a mesma cena com uma revisão anterior do desenho.
## --ml=N liga a luz por malha nos rostos (1 integrada, 2 relevo).
## O teste força queue_redraw; a mediana mede repetição dos comandos, não o FPS do jogo parado.


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	OS.low_processor_usage_mode = false
	var px := 90
	var count := 12
	var portrait: Script = PortraitView
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--size="):
			px = clampi(int(arg.substr(7)), 24, 640)
		elif arg.begins_with("--count="):
			count = clampi(int(arg.substr(8)), 1, 48)
		elif arg.begins_with("--ml="):
			PortraitView.mesh_light_default = int(arg.substr(5))
		elif arg.begins_with("--portrait="):
			portrait = load(arg.substr(11))
	var views: Array[Control] = []
	var started := Time.get_ticks_usec()
	for i in count:
		var view: Control = portrait.new()
		view.size = Vector2(px, px)
		view.position = Vector2((i % 4) * px, (i / 4) * px)
		view.set("face_seed", 1000 + i * 7919)
		view.set("eth", i % 13)
		view.set("age", 18 + i * 3)
		root.add_child(view)
		views.append(view)
	await RenderingServer.frame_post_draw
	var cold_ms := (Time.get_ticks_usec() - started) / 1000.0
	var samples: Array[float] = []
	for i in 12:
		await process_frame
		started = Time.get_ticks_usec()
		for view in views:
			view.queue_redraw()
		await RenderingServer.frame_post_draw
		samples.append((Time.get_ticks_usec() - started) / 1000.0)
	samples.sort()
	print(JSON.stringify({"size": px, "count": count, "cold_ms": cold_ms, "cached_median_ms": samples[6]}))
	quit()
