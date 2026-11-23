extends SceneTree
## Corpos 3D (Body3D) em pose de descanso, de frente, de lado e de costas, para afinar a malha.
## xvfb-run -a -s "-screen 0 1700x1000x24" godot --path . --resolution 1600x900 --script res://tools/body3d_sheet.gd -- --out=/tmp/corpos3d.png

func _initialize() -> void:
	var out := "/tmp/corpos3d.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#15171C")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.55, 0.7)
	env.ambient_light_energy = 0.3
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	root.add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, -150, 0)
	rim.light_energy = 0.5
	rim.light_color = Color(0.7, 0.8, 1.0)
	root.add_child(rim)
	var cam := Camera3D.new()
	cam.fov = 30.0
	cam.position = Vector3(0, 2.0, 21.0)
	root.add_child(cam)
	var w := GameWorld.new()
	w.rng.seed = 21
	var specs := [["M61", "BRA", 0.0], ["M77", "USA", 0.0], ["M120", "NGA", 0.0], ["F57", "JPN", 0.0]]
	var x := -8.4
	for sp: Array in specs:
		var f := FighterGenerator.make(w, String(sp[0]), 72.0, 28, false, String(sp[1]))
		var r := Rig2D.from_fighter(w, f, 1.0)
		for ang: float in [-90.0, -30.0, 90.0]:
			var holder := Node3D.new()
			holder.position = Vector3(x, 3.75 * r.height_k - 1.9 + 0.0, 0)
			holder.rotation_degrees.y = ang
			root.add_child(holder)
			Body3D.build(r, holder)
			x += 1.45
		x += 0.3
	var rr := Rig2D.referee(w.rng)
	var hold := Node3D.new()
	hold.position = Vector3(x, 3.75 - 1.9, 0)
	hold.rotation_degrees.y = 60.0
	root.add_child(hold)
	Body3D.build(rr, hold)
	for i in 4:
		await process_frame
	root.get_texture().get_image().save_png(out)
	quit()
