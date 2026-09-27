extends SceneTree
## Prévia do kit 3D cru (sem o estúdio): xvfb-run godot --path . --resolution 600x700 --script res://tools/face3d_preview.gd -- --out=/tmp/f.png --hair=hair_short02 --w=eth_afr:1

func _initialize() -> void:
	var out := "/tmp/face3d.png"
	var hair := "hair_short02"
	var weights := {}
	var yaw := 0.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--hair="):
			hair = a.substr(7)
		elif a.begins_with("--yaw="):
			yaw = float(a.substr(6))
		elif a.begins_with("--w="):
			for kv in a.substr(4).split(","):
				var p := kv.split(":")
				weights[p[0]] = float(p[1])
	var root3 := Node3D.new()
	root.add_child(root3)
	var bp := Face3DKit.body_positions(weights)
	var skin := StandardMaterial3D.new()
	skin.albedo_texture = Face3DKit.texture("skin_light.png")
	skin.roughness = 0.6
	var body := MeshInstance3D.new()
	body.mesh = Face3DKit.body_mesh(bp)
	body.material_override = skin
	root3.add_child(body)
	for key in [hair, "brow_a", "eyes", "lashes", "shirt"]:
		if key == "":
			continue
		var m := MeshInstance3D.new()
		m.mesh = Face3DKit.proxy_mesh(key, bp)
		var mat := StandardMaterial3D.new()
		var tx := String(Face3DKit.load_bin(key)["meta"]["tex"])
		if tx != "" and key != "shirt":
			mat.albedo_texture = Face3DKit.texture(tx)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			mat.alpha_scissor_threshold = 0.4
		if key == "shirt":
			mat.albedo_color = Color("#C8102E")
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.material_override = mat
		root3.add_child(m)
	root3.rotation.y = deg_to_rad(yaw)
	var cam := Camera3D.new()
	cam.fov = 22
	cam.position = Vector3(0, 0.7, 1.45)
	root3.add_child(cam)
	cam.look_at_from_position(cam.position, Vector3(0, 0.66, 0))
	cam.make_current()
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-25, 30, 0)
	key.light_energy = 1.2
	root3.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-10, -120, 0)
	fill.light_energy = 0.4
	root3.add_child(fill)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#20242B")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.65)
	env.environment.ambient_light_energy = 0.5
	root3.add_child(env)
	# Mostra o enquadramento com base na malha
	var aabb := body.mesh.get_aabb()
	print("aabb ", aabb)
	_out = out


var _out := ""
var _frames := 0


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 8:
		root.get_viewport().get_texture().get_image().save_png(_out)
		print("salvo ", _out)
		return true
	return false
