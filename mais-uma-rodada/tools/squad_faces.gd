extends SceneTree
## Rostos de jogadores sorteados do mundo gerado, em grade, para julgar cabelos e barbas.
## xvfb-run godot --path . --resolution 1290x810 --script res://tools/squad_faces.gd -- --out=/tmp/rostos.png --league=BRA1 --seed=1

var _out := "user://rostos.png"
var _frames := 0


func _initialize() -> void:
	var lg := "BRA1"
	var sd := 1
	var px := 150
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--league="):
			lg = a.substr(9)
		elif a.begins_with("--seed="):
			sd = int(a.substr(7))
		elif a.begins_with("--size="):
			px = int(a.substr(7))
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var bg := ColorRect.new()
	bg.color = Color("#1E1E1E")
	bg.size = Vector2(6000, 6000)
	root.add_child(bg)
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	var pool: Array = []
	for c: Club in w.clubs_in_league(lg):
		for p2 in w.squad_of(c.id):
			pool.append([p2, c])
	var r := RandomNumberGenerator.new()
	r.seed = sd
	var cols := 8
	for k in 24:
		var pick: Array = pool[r.randi_range(0, pool.size() - 1)]
		var p: Player = pick[0]
		var pv := PortraitView.new()
		pv.position = Vector2(10 + (k % cols) * (px + 10), 10 + (k / cols) * (px + 10))
		pv.size = Vector2(px, px)
		var club: Club = pick[1]
		pv.face_seed = p.face_seed
		pv.eth = p.eth
		pv.age = p.age(w.year)
		pv.look = p.look
		pv.shirt_color = club.primary_color()
		pv.trim_color = club.secondary_color()
		pv.bg_color = club.primary_color().darkened(0.6)
		root.add_child(pv)
		var lb := Label.new()
		lb.text = "%d %s" % [p.age(w.year), FaceGen.HAIR_STYLES[int(FaceGen.features(p.face_seed, p.eth, p.age(w.year), p.look)["style"])].substr(0, 18)]
		lb.position = pv.position + Vector2(2, px - 16)
		lb.add_theme_font_size_override("font_size", 11)
		root.add_child(lb)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 14:
		root.get_viewport().get_texture().get_image().save_png(_out)
		print("ok ", _out)
		return true
	return false
