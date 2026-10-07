extends SceneTree
## Teste da luz de estúdio por malha nos retratos (FaceShade): o mesmo boneco antes (luz pintada
## em cada peça) e com a luz do busto inteiro por cima de rosto, cabelo, barba, pescoço e camisa.
## xvfb-run -a -s "-screen 0 1400x1400x24" godot --path . --resolution 1300x1000 --script res://tools/face_light_test.gd -- --out=/tmp/faces.png
## --set=clean|beard|all, --size=N (lado de cada retrato), --pairs=N (pares por linha),
## --only=a,b (casos), --modes=0,1 (colunas: 0 antes, 1 luz por malha), --classic (busto no círculo)

var _out := "user://face_light.png"
var _frames := 0

const CASES: Array = [
	{"eth": 0, "age": 24, "seed": 7100, "look": {"hs": 3, "bd": 0}, "kit": ["#B3122E", "#FFFFFF"]},
	{"eth": 7, "age": 26, "seed": 7391, "look": {"hs": 1, "bd": 0}, "kit": ["#F2C230", "#0B2A6B"]},
	{"eth": 2, "age": 28, "seed": 7197, "look": {"hs": 8, "bd": 0}, "kit": ["#0B2A6B", "#FFFFFF"]},
	{"eth": 8, "age": 23, "seed": 7488, "look": {"hs": 5, "bd": 0}, "kit": ["#FFFFFF", "#111111"]},
	{"eth": 4, "age": 31, "seed": 7585, "look": {"hs": 5, "bd": 0}, "kit": ["#1C7A3A", "#FFFFFF"]},
	{"eth": 3, "age": 36, "seed": 7682, "look": {"hs": 12, "bd": 0}, "kit": ["#111111", "#F2C14E"]},
	{"eth": 1, "age": 30, "seed": 7779, "look": {"hs": 6, "bd": 3}, "kit": ["#4DA3E0", "#FFFFFF"]},
	{"eth": 6, "age": 25, "seed": 7876, "look": {"hs": 20, "bd": 12}, "kit": ["#6A1B4D", "#F2C230"]},
	{"eth": 9, "age": 33, "seed": 7973, "look": {"hs": 30, "bd": 40}, "kit": ["#B3122E", "#111111"]},
	{"eth": 10, "age": 34, "seed": 8070, "look": {"hs": 88, "bd": 55}, "kit": ["#FFFFFF", "#0B2A6B"]},
	{"eth": 5, "age": 27, "seed": 8167, "look": {"hs": 45, "bd": 0}, "kit": ["#0B2A6B", "#F2C14E"]},
	{"eth": 12, "age": 29, "seed": 8264, "look": {"hs": 70, "bd": 8}, "kit": ["#1C7A3A", "#111111"]},
]


func _initialize() -> void:
	var px := 300
	var pairs := 2
	var ids: Array = []
	var set_name := "clean"
	var modes: Array = [0, 1]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--size="):
			px = int(a.substr(7))
		elif a.begins_with("--pairs="):
			pairs = int(a.substr(8))
		elif a.begins_with("--set="):
			set_name = a.substr(6)
		elif a.begins_with("--only="):
			ids = Array(a.substr(7).split(",")).map(func(x): return int(x))
		elif a.begins_with("--modes="):
			modes = Array(a.substr(8).split(",")).map(func(x): return int(x))
		elif a == "--classic":
			PortraitView.default_framing = PortraitView.FRAME_CLASSIC
	if ids.is_empty():
		match set_name:
			"clean":
				ids = [0, 1, 2, 3, 4, 5]
			"beard":
				ids = [6, 7, 8, 9, 10, 11]
			_:
				ids = range(CASES.size())
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var bg := ColorRect.new()
	bg.color = Color("#141414")
	bg.size = Vector2(8000, 8000)
	root.add_child(bg)
	var crest := {"shape": "shield", "symbol": "star", "c1": "#222222", "c2": "#FFFFFF", "border": "thin", "initials": "FC"}
	var gap := 10
	var label_h := 22
	for slot in ids.size():
		var cs: Dictionary = CASES[int(ids[slot])]
		var col := slot % pairs
		var row := slot / pairs
		var x0 := gap + col * (modes.size() * px + (modes.size() + 1) * gap)
		var y0 := gap + row * (px + label_h + gap)
		for side in modes.size():
			var c1 := String(cs["kit"][0])
			var c2 := String(cs["kit"][1])
			var pv := PortraitView.new()
			pv.position = Vector2(x0 + side * (px + gap), y0 + label_h)
			pv.size = Vector2(px, px)
			pv.face_seed = int(cs["seed"])
			pv.eth = int(cs["eth"])
			pv.age = int(cs["age"])
			pv.look = cs["look"]
			pv.shirt_color = Color(c1)
			pv.trim_color = Color(c2)
			pv.bg_color = Color(c1).darkened(0.6)
			pv.kit = {"pattern": "plain", "c1": c1, "c2": c2, "c3": c2, "collar": "round", "sleeve": "same",
				"sp": {"n": "Banco Sul", "c": "#FFFFFF", "t": "#111111"}}
			pv.crest = crest
			pv.mesh_light = int(modes[side])
			root.add_child(pv)
			var lb := Label.new()
			lb.text = ["antes", "luz de estúdio por malha"][int(modes[side])] + ("  ·  caso %d" % int(ids[slot]) if side == 0 else "")
			lb.position = Vector2(x0 + side * (px + gap), y0)
			lb.add_theme_font_size_override("font_size", 14)
			lb.add_theme_color_override("font_color", Color("#C8CCD4") if int(modes[side]) == 0 else Color("#F2C14E"))
			root.add_child(lb)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 16:
		root.get_viewport().get_texture().get_image().save_png(_out)
		print("ok ", _out)
		return true
	return false
