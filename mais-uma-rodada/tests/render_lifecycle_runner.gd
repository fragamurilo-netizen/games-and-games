extends Node

var failures := 0

class DrawRequester:
	extends Control
	var texture: Texture2D
	func _draw() -> void:
		texture = DecalCache.text_texture("Requested in draw", self)
		if DecalCache.is_ready(texture):
			draw_texture_rect(texture, Rect2(Vector2.ZERO, size), false)

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("RENDER_LIFECYCLE_FAIL: " + message)

func frames(n: int = 4) -> void:
	for i in n:
		await get_tree().process_frame
		RenderingServer.force_draw()

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("RENDER_LIFECYCLE requires a graphical renderer")
		get_tree().quit(2)
		return
	OS.low_processor_usage_mode = false
	var crest := {"shape": "shield", "symbol": "star", "c1": "#1B3A8C", "c2": "#FFFFFF", "initials": "RA"}
	var original := DecalCache.crest_texture(crest, null)
	var sponsor := DecalCache.text_texture("Retained sponsor", null)
	var requester := DrawRequester.new()
	requester.position = Vector2(20, 220)
	requester.size = Vector2(300, 50)
	add_child(requester)
	var portrait := PortraitView.new()
	portrait.crest = crest
	portrait.kit = {"sp": {"n": "Retained"}}
	portrait.face_seed = 471
	portrait.size = Vector2(180, 180)
	add_child(portrait)
	await frames(8)
	check(DecalCache.is_ready(original), "crest finishes rendering")
	check(DecalCache.is_ready(sponsor), "sponsor finishes rendering")
	check(DecalCache.is_ready(requester.texture), "request from _draw finishes after attaching viewport")
	if not DecalCache.is_ready(original) or not DecalCache.is_ready(sponsor) or not DecalCache.is_ready(requester.texture):
		get_tree().quit(1)
		return
	check(requester.texture.get_image().get_used_rect().has_area(), "first capture contains drawn pixels")
	var size_before := original.get_size()
	var bytes_before := original.get_image().get_data()
	var sponsor_before := sponsor.get_image().get_data()
	var sponsor_size := sponsor.get_size()
	var commands := PortraitView._cmd_cache.duplicate()
	check(bytes_before.size() > 0 and original.get_image().get_used_rect().has_area(), "crest has visible pixels")
	var live_decals := 0
	for layer: Array in commands.values():
		for command: Array in layer:
			if int(command[0]) == 9:
				live_decals += 1
	check(live_decals > 0, "real portrait commands retain shirt textures")
	# A UI pode ser fechada enquanto ainda espera o desenho da estampa.
	var discarded := Control.new()
	DecalCache.text_texture("Closed requester", discarded)
	discarded.free()
	for cycle in 3:
		for i in DecalCache.MAX_ENTRIES + 8:
			DecalCache.text_texture("Cycle %d sponsor %d" % [cycle, i], null)
		await frames()
		check(original.get_size() == size_before, "evicted crest keeps dimensions")
		check(sponsor.get_size() == sponsor_size, "evicted sponsor keeps dimensions")
		check(original.get_image().get_data() == bytes_before, "evicted crest keeps pixels")
		check(sponsor.get_image().get_data() == sponsor_before, "evicted sponsor keeps pixels")
		check(is_equal_approx(DecalCache.aspect(sponsor), sponsor_size.x / sponsor_size.y), "evicted sponsor keeps aspect")
		check(DecalCache._entries.size() <= DecalCache.MAX_ENTRIES, "cache remains bounded")
		for e: Dictionary in DecalCache._entries.values():
			check(not is_instance_valid(e["vp"]), "completed entries release their render targets")
		for layer: Array in commands.values():
			for command: Array in layer:
				if int(command[0]) == 9:
					check((command[5] as Texture2D).get_size().x > 0, "cached mesh texture remains valid")
		DecalCache.refresh()
		portrait.queue_redraw()
		await frames(8)
	check(DecalCache._pending.is_empty(), "pending captures settle")
	for tex: Texture2D in [original, sponsor]:
		var rect := TextureRect.new()
		rect.texture = tex
		rect.position = Vector2(200, 20) if tex == original else Vector2(20, 290)
		rect.size = Vector2(128, 128) if tex == original else Vector2(330, 54)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		add_child(rect)
	await frames()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			var output := arg.substr(6)
			DirAccess.make_dir_recursive_absolute(output)
			get_viewport().get_texture().get_image().save_png(output.path_join("retained-textures.png"))
	print("RENDER_LIFECYCLE_RESULT failures=", failures, " retained_mesh_decals=", live_decals)
	get_tree().quit(0 if failures == 0 else 1)
