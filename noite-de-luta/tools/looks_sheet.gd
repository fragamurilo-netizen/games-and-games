extends SceneTree
## Variedade de lutadores na luta (cabelo, barba, físico): 12 duplas diferentes paradas na guarda,
## no 2D ou no 3D, com o nome do penteado e da barba de cada um.
## xvfb-run -a -s "-screen 0 1700x1300x24" godot --path . --resolution 1600x1230 --script res://tools/looks_sheet.gd -- --out=/tmp/visual.png [--3d] [--seed=9]

const PW := 390
const PH := 300


func _initialize() -> void:
	var out := "/tmp/visual.png"
	var three := false
	var seed_v := 9
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a == "--3d":
			three = true
		elif a.begins_with("--seed="):
			seed_v = int(a.substr(7))
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var bg := ColorRect.new()
	bg.color = Color("#1A1B20")
	bg.size = Vector2(4000, 4000)
	root.add_child(bg)
	var w := GameWorld.new()
	w.rng.seed = seed_v
	var nations := ["BRA", "USA", "NGA", "JPN", "RUS", "IRL", "MEX", "DAG", "JAM", "KOR", "SWE", "FRA", "ARG", "AUS", "CMR", "GEO", "THA", "ENG", "CUB", "POL", "NZL", "ESP", "KAZ", "NED"]
	var divs := ["M61", "M66", "M70", "M77", "M84", "M93", "M120", "F52", "F57", "F61", "M70", "M77"]
	var stages: Array = []
	for i in 12:
		var div := String(divs[i])
		var fa := FighterGenerator.make(w, div, 70.0, 20 + (i * 5) % 19, false, String(nations[(i * 2) % nations.size()]))
		var fb := FighterGenerator.make(w, div, 70.0, 22 + (i * 7) % 18, false, String(nations[(i * 2 + 1) % nations.size()]))
		var st := FightStage2D.new()
		st.setup(w, fa, fb)
		var holder: Control = st
		if three:
			var v := FightView3D.new()
			v.setup(st, Color("#C8102E"), "Noite de Luta")
			holder = v
		holder.position = Vector2(4 + (i % 4) * (PW + 4), 4 + (i / 4) * (PH + 104))
		holder.size = Vector2(PW, PH)
		root.add_child(holder)
		var l := Label.new()
		var la := (st.rigs[0] as Rig2D).face
		var lb := (st.rigs[1] as Rig2D).face
		l.text = "%s · %s\n%s · %s\n%s · %s" % [div, String(nations[(i * 2) % nations.size()]) + " x " + String(nations[(i * 2 + 1) % nations.size()]),
			FaceGen.HAIR_STYLES[int(la.get("style", 0))], FaceGen.BEARDS[int(la.get("beard", 0))], FaceGen.HAIR_STYLES[int(lb.get("style", 0))], FaceGen.BEARDS[int(lb.get("beard", 0))]]
		l.position = holder.position + Vector2(6, PH + 2)
		l.add_theme_font_size_override(&"font_size", 13)
		root.add_child(l)
		stages.append(holder)
	await process_frame
	for h: Control in stages:
		h.set_process(false)
		if h is FightView3D:
			(h as FightView3D).brain.set_process(false)
	for h: Control in stages:
		var st: FightStage2D = (h as FightView3D).brain if h is FightView3D else h
		for k in 80:
			st._process(1.0 / 60.0)
		if h is FightView3D:
			(h as FightView3D)._shot = "fechado"
			(h as FightView3D)._shot_left = 99.0
			for k in 200:
				h._process(1.0 / 60.0)
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(out)
	quit()
