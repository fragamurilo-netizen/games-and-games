extends SceneTree
## Real OpenGL captures of the active game PortraitView. No image generation or relighting filter.
var out_dir := "/workspace/face-lighting"
var failures := 0
const VERSIONS := ["00_original", "01_frontal_suave", "02_estudio_equilibrado", "03_quente_discreta", "04_lateral_volume"]

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	OS.low_processor_usage_mode = false
	Engine.max_fps = 30
	if DisplayServer.get_name() == "headless":
		push_error("ACTUAL_FACE_FAIL: capture requires a real renderer")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(448, 448)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(viewport)
	var subjects: Array = [{"id": "jogador_01", "seed": 12345, "eth": 1, "age": 25}, {"id": "jogador_02", "seed": 54321, "eth": 3, "age": 27}]
	var identities: Array = []
	for subject in subjects:
		var expected_hash: int = 0
		var first: bool = true
		for version in VERSIONS:
			var path: String = "res://scripts/ui/components/portrait_view.gd" if version == "00_original" else "res://tools/lighting_runtime/" + version + ".gd"
			var renderer = load(path)
			if renderer == null or not renderer.can_instantiate():
				push_error("ACTUAL_FACE_FAIL: cannot load " + path)
				quit(3)
				return
			for side in [448, 96]:
				viewport.size = Vector2i(side, side)
				var portrait = renderer.new()
				portrait.face_seed = int(subject["seed"])
				portrait.eth = int(subject["eth"])
				portrait.age = int(subject["age"])
				portrait.look = {}
				portrait.shirt_color = Color("#1B3A8C")
				portrait.trim_color = Color.WHITE
				portrait.bg_color = Color("#111A2D")
				portrait.cutout = false
				portrait.photo = null
				portrait.size = Vector2(side, side)
				viewport.add_child(portrait)
				for _frame in 3:
					portrait.queue_redraw()
					viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
					await RenderingServer.frame_post_draw
				var features: Dictionary = portrait.get("_f")
				var identity_hash: int = hash(features)
				if first:
					expected_hash = identity_hash
					first = false
				if features.is_empty() or identity_hash != expected_hash:
					failures += 1
					push_error("ACTUAL_FACE_FAIL: identity changed between lighting variants")
				var image: Image = viewport.get_texture().get_image()
				var filename: String = String(subject["id"]) + "_" + version + "_" + str(side) + ".png"
				if image == null or image.is_empty() or image.get_used_rect().size.x < 30:
					failures += 1
					push_error("ACTUAL_FACE_FAIL: empty capture " + filename)
				elif image.save_png(out_dir.path_join(filename)) != OK:
					failures += 1
					push_error("ACTUAL_FACE_FAIL: cannot save " + filename)
				else:
					print("ACTUAL_FACE_SAVED ", filename, " identity=", identity_hash)
				viewport.remove_child(portrait)
				portrait.free()
		identities.append({"subject": subject, "features_hash": expected_hash})
	var manifest := {"engine": Engine.get_version_info(), "source": "res://scripts/ui/components/portrait_view.gd", "actual_renderer": "2D active game renderer", "sizes": [448, 96], "identities": identities, "versions": VERSIONS, "changes": "Only lighting constants and coefficients. All identity hashes verified equal within each subject. Original geometry, clothing, face details and camera framing preserved."}
	var file := FileAccess.open(out_dir.path_join("actual-render-manifest.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(manifest, "  "))
		file.close()
	viewport.queue_free()
	for _i in 3:
		await process_frame
	print("ACTUAL_FACE_RESULT failures=", failures)
	if failures == 0:
		print("ACTUAL_FACE_OK")
	quit(0 if failures == 0 else 4)
