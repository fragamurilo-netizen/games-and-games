extends SceneTree
## O mesmo lutador ao longo da carreira: corpo inteiro aos ~23, ~31 e ~39 anos (aposentado na
## última coluna), com o visual mudando pelo Development.yearly_look.
## xvfb-run -a -s "-screen 0 1700x1300x24" godot --path . --resolution 1600x1200 --script res://tools/aging_sheet.gd -- --out=/tmp/idade.png [--nations=BRA,DAG,USA,RUS]

func _initialize() -> void:
	var out := "/tmp/idade.png"
	var nations := ["BRA", "DAG", "USA", "RUS", "JPN", "NGA"]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--nations="):
			nations = Array(a.substr(10).split(","))
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var bg := ColorRect.new()
	bg.color = Color("#1A1B20")
	bg.size = Vector2(4000, 4000)
	root.add_child(bg)
	var w := GameWorld.new()
	w.rng.seed = 5
	var h := 340
	var colw := int(h * 0.42)
	var stages := [0, 8, 16]
	for r in nations.size():
		var f := FighterGenerator.make(w, ["M70", "M77", "M84", "M93"][r % 4], 64.0, 23, false, String(nations[r]))
		w.fighters[f.id] = f
		var done := 0
		for k in stages.size():
			while done < int(stages[k]):
				f.birth_year -= 1
				if done == 13:
					f.retired = true
				Development.yearly_look(w)
				done += 1
			var v := BodyView.new()
			v.position = Vector2(6 + (r % 3) * (colw * 3 + 40) + k * (colw + 6), 6 + int(r / 3) * (h + 44))
			v.size = Vector2(colw, h)
			v.face_seed = f.face_seed
			v.eth = f.eth
			v.age = w.age_of(f)
			v.look = f.look.duplicate()
			v.height_cm = f.height_cm
			v.shorts = Color.from_hsv(float(r) / nations.size(), 0.7, 0.55)
			v.trim = Color("#F1F0EC")
			root.add_child(v)
			var l := Label.new()
			l.text = "%s %d anos%s\nhs %s bd %s bf %.2f" % [f.short_name(), w.age_of(f), " (apos.)" if f.retired else "", str(f.look.get("hs", "-")), str(f.look.get("bd", "-")), float(f.look.get("bf", 0))]
			l.position = v.position + Vector2(0, h)
			l.add_theme_font_size_override(&"font_size", 11)
			root.add_child(l)
	await process_frame
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(out)
	quit()
