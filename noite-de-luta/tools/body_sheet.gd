extends SceneTree
## Corpos inteiros gerados como no jogo, uma categoria por coluna (mosca → pesado).
## xvfb-run -a -s "-screen 0 1600x1000x24" godot --path . --resolution 1500x900 --script res://tools/body_sheet.gd -- --out=/tmp/corpos.png [--fem] [--nations=BRA,RUS]

func _initialize() -> void:
	var out := "/tmp/corpos.png"
	var fem := false
	var nations := ["BRA", "USA"]
	var h := 380
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a == "--fem":
			fem = true
		elif a.begins_with("--nations="):
			nations = Array(a.substr(10).split(","))
		elif a.begins_with("--h="):
			h = int(a.substr(4))
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var bg := ColorRect.new()
	bg.color = Color("#1A1B20")
	bg.size = Vector2(4000, 4000)
	root.add_child(bg)
	var w := GameWorld.new()
	w.rng.seed = 11
	var divs := ["M57", "M61", "M66", "M70", "M77", "M84", "M93", "M120"] if not fem else ["F52", "F57", "F61", "F66"]
	var colw := int(h * 0.42)
	for r in nations.size():
		for k in divs.size():
			var f := FighterGenerator.make(w, divs[k], w.rng.randf_range(58.0, 80.0), 0, false, String(nations[r]))
			var v := BodyView.new()
			v.position = Vector2(6 + k * (colw + 6), 6 + r * (h + 40))
			v.size = Vector2(colw, h)
			v.face_seed = f.face_seed
			v.eth = f.eth
			v.age = w.age_of(f)
			v.look = f.look
			v.height_cm = f.height_cm
			v.shorts = Color.from_hsv(w.rng.randf(), 0.7, 0.55)
			v.trim = Color("#F1F0EC")
			root.add_child(v)
			var l := Label.new()
			l.text = "%s %s %dcm\n%s ms%.1f bf%.2f tr%.1f" % [divs[k], f.short_name(), f.height_cm, Styles.short(f.base), float(f.look.get("ms", 0)), float(f.look.get("bf", 0)), float(f.look.get("tr", 0))]
			l.position = v.position + Vector2(0, h)
			l.add_theme_font_size_override(&"font_size", 10)
			root.add_child(l)
	await process_frame
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(out)
	quit()
