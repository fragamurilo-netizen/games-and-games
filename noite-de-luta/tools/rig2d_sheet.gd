extends SceneTree
## Bonecos 2D (Rig2D) grandes, em várias guardas e físicos, para afinar o desenho.
## xvfb-run -a -s "-screen 0 1700x1000x24" godot --path . --resolution 1600x900 --script res://tools/rig2d_sheet.gd -- --out=/tmp/rig2d.png
## Com --fem, só lutadoras.

class Sheet extends Control:
	var rigs: Array = []
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1600, 900), Color("#8A8D93"))
		draw_rect(Rect2(0, 860, 1600, 40), Color("#C9C6BE"))
		draw_rect(Rect2(0, 300, 1600, 12), Color("#C9C6BE"))
		for it: Array in rigs:
			(it[0] as Rig2D).draw(self, float(it[1]), float(it[2]), float(it[3]))


func _initialize() -> void:
	var out := "/tmp/rig2d.png"
	var fem := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a == "--fem":
			fem = true
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var w := GameWorld.new()
	w.rng.seed = 21
	var sh := Sheet.new()
	sh.size = Vector2(1600, 900)
	var specs := [["M61", "BRA", "boxe", 1.0], ["M77", "USA", "muay_thai", -1.0], ["M120", "NGA", "wrestling", 1.0], ["F57", "JPN", "karate", -1.0],
		["M84", "RUS", "sambo", 1.0], ["M70", "IRL", "boxe", -1.0], ["M93", "BRA", "jiu_jitsu", 1.0], ["F61", "USA", "muay_thai", -1.0]]
	if fem:
		# Só lutadoras (--fem): as quatro categorias e as guardas, para afinar o corpo feminino.
		specs = [["F52", "BRA", "boxe", 1.0], ["F57", "USA", "muay_thai", -1.0], ["F61", "NGA", "wrestling", 1.0], ["F66", "JPN", "karate", -1.0],
			["F52", "RUS", "sambo", 1.0], ["F57", "IRL", "boxe", -1.0], ["F61", "BRA", "jiu_jitsu", 1.0], ["F66", "USA", "muay_thai", -1.0]]
	var x := 170.0
	for i in specs.size():
		var sp: Array = specs[i]
		var f := FighterGenerator.make(w, String(sp[0]), 72.0, 24 + i * 2, false, String(sp[1]))
		f.base = String(sp[2])
		if i == 5:
			f.southpaw = true
		var r := Rig2D.from_fighter(w, f, float(sp[3]))
		if i >= 4:
			r.pose["tw"] = 0.0
		var big := i < 4
		sh.rigs.append([r, x if big else 120.0 + (i - 4) * 250.0, 865.0 if big else 305.0, 55.0 if big else 28.0])
		if big:
			x += 420.0
	var rr := Rig2D.referee(w.rng)
	sh.rigs.append([rr, 1150.0, 305.0, 28.0])
	var kd := Rig2D.from_fighter(w, FighterGenerator.make(w, "M77", 70.0, 30, false, "BRA"), 1.0)
	kd.pose = {"x": 0.0, "y": 0.0, "crouch": 0.0, "sit": 1.0, "rot": -92.0, "torso": 0.0, "head": 0.0, "na_s": -40.0, "na_e": 20.0, "fa_s": 30.0, "fa_e": 40.0, "nl_h": 30.0, "nl_k": 50.0, "fl_h": 10.0, "fl_k": 10.0}
	kd.ko = true
	sh.rigs.append([kd, 1400.0, 305.0, 28.0])
	root.add_child(sh)
	for i in 3:
		await process_frame
	root.get_texture().get_image().save_png(out)
	quit()
