extends SceneTree
## Visual-only experiment. No production scene, face geometry, skin shader, or save is changed.
## Run with an actual OpenGL renderer, not --headless. The native face texture remains 448 px.
const SOURCE_COMMIT := "0721da80a98148912aa954101185cf6531633e5b"
const PRESETS := [
	{"id": "01_frontal_suave", "name": "Frontal suave", "ambient": 0.48,
	 "ambient_color": [0.70, 0.72, 0.76],
	 "lights": [
		{"rot": [-12.0, -12.0, 0.0], "energy": 0.86, "color": [1.0, 0.98, 0.96], "specular": 0.65},
		{"rot": [-8.0, 38.0, 0.0], "energy": 0.58, "color": [0.94, 0.97, 1.0], "specular": 0.40},
		{"rot": [-20.0, 150.0, 0.0], "energy": 0.32, "color": [1.0, 0.98, 0.95], "specular": 0.65}]},
	{"id": "02_estudio_equilibrado", "name": "Estudio equilibrado", "ambient": 0.34,
	 "ambient_color": [0.65, 0.67, 0.71],
	 "lights": [
		{"rot": [-25.0, -32.0, 0.0], "energy": 1.05, "color": [1.0, 0.97, 0.94], "specular": 0.75},
		{"rot": [-8.0, 45.0, 0.0], "energy": 0.42, "color": [0.93, 0.96, 1.0], "specular": 0.40},
		{"rot": [-22.0, 145.0, 0.0], "energy": 0.62, "color": [0.94, 0.97, 1.0], "specular": 0.70}]},
	{"id": "03_quente_discreta", "name": "Quente discreta", "ambient": 0.38,
	 "ambient_color": [0.72, 0.67, 0.61],
	 "lights": [
		{"rot": [-18.0, -27.0, 0.0], "energy": 1.02, "color": [1.0, 0.89, 0.76], "specular": 0.70},
		{"rot": [-5.0, 42.0, 0.0], "energy": 0.50, "color": [0.92, 0.96, 1.0], "specular": 0.35},
		{"rot": [-18.0, 150.0, 0.0], "energy": 0.50, "color": [1.0, 0.88, 0.75], "specular": 0.65}]},
	{"id": "04_lateral_volume", "name": "Lateral com volume", "ambient": 0.26,
	 "ambient_color": [0.60, 0.63, 0.69],
	 "lights": [
		{"rot": [-25.0, -52.0, 0.0], "energy": 1.12, "color": [1.0, 0.97, 0.94], "specular": 0.70},
		{"rot": [-5.0, 35.0, 0.0], "energy": 0.24, "color": [0.91, 0.95, 1.0], "specular": 0.35},
		{"rot": [-20.0, 145.0, 0.0], "energy": 0.64, "color": [0.92, 0.96, 1.0], "specular": 0.65}]}
]
var out_dir := "/workspace/face-lighting"
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	if DisplayServer.get_name() == "headless":
		push_error("FACE_LIGHTING_FAIL: a real renderer is required")
		quit(2)
		return
	OS.low_processor_usage_mode = false
	Engine.max_fps = 30
	if OS.get_environment("FACE_LIGHTING_OUT") != "":
		out_dir = OS.get_environment("FACE_LIGHTING_OUT")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var kit_script = load("res://scripts/ui/face3d/face3d_kit.gd")
	if not kit_script.available():
		push_error("FACE_LIGHTING_FAIL: original game face assets unavailable")
		quit(3)
		return
	# Runtime loading preserves the normal autoload initialization order of the game.
	var studio_script = load("res://scripts/ui/face3d/face3d_studio.gd")
	var studio = studio_script.new()
	studio.name = "LightingPreviewStudio"
	root.add_child(studio)
	studio.set_process(false)
	await process_frame
	var vp: SubViewport = studio.get("_vp")
	var kit_vp: SubViewport = studio.get("_kit_vp")
	var lights: Array = []
	var env: Environment = null
	for child in vp.get_children():
		if child is DirectionalLight3D:
			lights.append(child)
		elif child is WorldEnvironment:
			env = child.environment
	if lights.size() < 3 or env == null:
		push_error("FACE_LIGHTING_FAIL: original studio lighting not found")
		quit(4)
		return
	var original_lights: Array = []
	for light in lights:
		original_lights.append({"rot": light.rotation_degrees, "energy": light.light_energy,
			"color": light.light_color, "specular": light.light_specular, "visible": light.visible})
	var original_ambient: float = env.ambient_light_energy
	var original_color: Color = env.ambient_light_color
	# These are real procedural game identities: the same FaceGen -> Face3DLook -> Face3DStudio
	# path used by PortraitView, not external photography or AI-generated face replacements.
	var subjects: Array = [
		{"id": "jogador_01", "seed": 12345, "eth": 1, "age": 25},
		{"id": "jogador_02", "seed": 54321, "eth": 3, "age": 27}
	]
	for subject in subjects:
		var spec: Dictionary = {"seed": subject["seed"], "eth": subject["eth"], "age": subject["age"],
			"look": {}, "shirt": Color("#1B3A8C"), "trim": Color.WHITE, "suit": false,
			"kit": {}, "crest": {}}
		print("FACE_LIGHTING_PREPARE ", subject["id"])
		studio.setup(spec)
		kit_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		for i in lights.size():
			var saved: Dictionary = original_lights[i]
			lights[i].rotation_degrees = saved["rot"]
			lights[i].light_energy = saved["energy"]
			lights[i].light_color = saved["color"]
			lights[i].light_specular = saved["specular"]
			lights[i].visible = saved["visible"]
		env.ambient_light_energy = original_ambient
		env.ambient_light_color = original_color
		await _capture(vp, String(subject["id"]) + "_00_original")
		for preset in PRESETS:
			_apply_lighting(lights, env, preset)
			await _capture(vp, String(subject["id"]) + "_" + String(preset["id"]))
		print("FACE_LIGHTING_SUBJECT_OK ", subject["id"])
	var manifest := {"source_commit": SOURCE_COMMIT, "engine": Engine.get_version_info(),
		"renderer": RenderingServer.get_current_rendering_method(), "native_texture_px": vp.size.x,
		"subjects": subjects, "presets": PRESETS,
		"notes": "Only existing light direction, energy, color, specular contribution and ambient fill vary. Original geometry, camera, skin/hair/eye/shirt shaders, texture resolution and MSAA are unchanged. No new shadow or postprocessing effects are enabled. Production game files and saves are unchanged."}
	var f := FileAccess.open(out_dir.path_join("manifest.json"), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(manifest, "  "))
		f.close()
	studio.queue_free()
	for _i in 4:
		await process_frame
	print("FACE_LIGHTING_RESULT failures=", failures)
	if failures == 0:
		print("FACE_LIGHTING_OK")
	quit(0 if failures == 0 else 5)

func _apply_lighting(lights: Array, env: Environment, preset: Dictionary) -> void:
	var values: Array = preset["lights"]
	for i in lights.size():
		var light: DirectionalLight3D = lights[i]
		light.visible = i < values.size()
		if i >= values.size():
			continue
		var p: Dictionary = values[i]
		var r: Array = p["rot"]
		light.rotation_degrees = Vector3(r[0], r[1], r[2])
		light.light_energy = float(p["energy"])
		light.light_color = _color(p["color"])
		light.light_specular = float(p["specular"])
		# The production studio has shadows disabled. Keep the same lightweight approach.
		light.shadow_enabled = false
	env.ambient_light_energy = float(preset["ambient"])
	env.ambient_light_color = _color(preset["ambient_color"])

func _capture(vp: SubViewport, file_name: String) -> void:
	# Render fresh frames after changing lighting; never reuse the disk portrait cache.
	for _frame in 3:
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
	var image: Image = vp.get_texture().get_image()
	if image == null or image.is_empty():
		failures += 1
		push_error("FACE_LIGHTING_FAIL: empty image " + file_name)
		return
	var used: Rect2i = image.get_used_rect()
	if used.size.x < 50 or used.size.y < 50:
		failures += 1
		push_error("FACE_LIGHTING_FAIL: face did not render " + file_name)
		return
	var err := image.save_png(out_dir.path_join(file_name + ".png"))
	if err != OK:
		failures += 1
		push_error("FACE_LIGHTING_FAIL: PNG save error " + str(err))
		return
	print("FACE_LIGHTING_SAVED ", file_name, " ", image.get_size())

func _color(a: Array) -> Color:
	return Color(float(a[0]), float(a[1]), float(a[2]), 1.0)
