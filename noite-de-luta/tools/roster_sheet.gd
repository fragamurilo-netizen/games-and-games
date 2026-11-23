extends SceneTree
## Lutadores como o jogo gera de verdade (FighterGenerator, com o físico e o visual de cada um):
## retrato e corpo inteiro lado a lado, para conferir como o elenco aparece.
## xvfb-run -a -s "-screen 0 1900x1500x24" godot --path . --resolution 1840x1440 --script res://tools/roster_sheet.gd -- --out=/tmp/x.png
## Opções: --fem (só lutadoras), --male (só lutadores), --n=N, --cols=N, --size=N, --seed=N.


func _initialize() -> void:
	var out := "/tmp/roster.png"
	var px := 220
	var cols := 6
	var n := 18
	var seed_v := 5
	var sex := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--size="):
			px = int(a.substr(7))
		elif a.begins_with("--cols="):
			cols = int(a.substr(7))
		elif a.begins_with("--n="):
			n = int(a.substr(4))
		elif a.begins_with("--seed="):
			seed_v = int(a.substr(7))
		elif a == "--fem":
			sex = "f"
		elif a == "--male":
			sex = "m"
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var bg := ColorRect.new()
	bg.color = Color("#0B0B0D")
	bg.size = Vector2(4000, 4000)
	root.add_child(bg)
	var w := GameWorld.new()
	w.rng.seed = seed_v
	var nations := ["BRA", "USA", "NGA", "JPN", "RUS", "IRL", "MEX", "VEN", "JAM", "KOR", "SWE", "FRA", "ARG", "AUS", "CMR", "GEO", "THA", "ENG", "CUB", "POL", "NZL", "ESP", "KAZ", "NED"]
	var fdivs := ["F52", "F57", "F61", "F66"]
	var mdivs := ["M61", "M66", "M70", "M77", "M84", "M93", "M120"]
	var bw := int(px * 0.5)
	for i in n:
		var fem := sex == "f" or (sex == "" and i % 2 == 0)
		var div := String(fdivs[i % fdivs.size()]) if fem else String(mdivs[i % mdivs.size()])
		var f := FighterGenerator.make(w, div, 60.0 + (i * 7) % 30, 20 + (i * 5) % 16, false, String(nations[i % nations.size()]))
		var pos := Vector2(6 + (i % cols) * (px + bw + 10), 6 + (i / cols) * (px + 44))
		var p := PortraitView.new()
		p.position = pos
		p.size = Vector2(px, px)
		p.set_face(f.face_seed, f.eth, w.age_of(f), f.look)
		root.add_child(p)
		var b := BodyView.new()
		b.position = pos + Vector2(px + 2, 0)
		b.size = Vector2(bw, px)
		b.set_fighter(w, f)
		b.ref_cm = f.height_cm + 4
		b.shorts = Color("#7A1F3D")
		b.trim = Color("#E8E2D8")
		root.add_child(b)
		var l := Label.new()
		var lk := f.look
		l.text = "%s %s %d a · ms %.2f bf %.2f tr %.2f wt %.2f\n%s" % [div, f.nation, w.age_of(f), float(lk.get("ms", 0.5)), float(lk.get("bf", 0.15)),
			float(lk.get("tr", 0.0)), float(lk.get("wt", 0.0)), FaceGen.HAIR_STYLES[int(FaceGen.features(f.face_seed, f.eth, w.age_of(f), lk).get("style", 0))]]
		l.position = pos + Vector2(2, px)
		l.add_theme_font_size_override(&"font_size", 12)
		l.add_theme_color_override(&"font_color", Color(0.85, 0.85, 0.85))
		root.add_child(l)
	process_frame.connect(func():
		await process_frame
		await process_frame
		root.get_texture().get_image().save_png(out)
		print("ok ", out)
		quit(), CONNECT_ONE_SHOT)
