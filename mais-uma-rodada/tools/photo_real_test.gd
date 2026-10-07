extends SceneTree
## Teste do acabamento de foto (photo_real.gdshader) nos retratos: o desenho de hoje ao lado do
## mesmo jogador com a luz do busto (FaceShade) e o acabamento de foto (desenhado em 2x).
## xvfb-run -a -s "-screen 0 1400x1400x24" godot --path . --resolution 1270x1000 --script res://tools/photo_real_test.gd -- --out=/tmp/foto.png
## --size=N, --pairs=N, --only=a,b (casos do face_light_test), --nolight (sem a luz do busto),
## --bg=#rrggbb (fundo atrás do recorte)

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

var _out := "user://photo_real.png"
var _frames := 0
var _shots: Array = [] # [PortraitView do 2x, ShaderMaterial, lado do retrato]


func _initialize() -> void:
	var px := 300
	var pairs := 2
	var ids: Array = [0, 1, 6, 7, 8, 11]
	var light := true
	var bgc := Color("#141414")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--size="):
			px = int(a.substr(7))
		elif a.begins_with("--pairs="):
			pairs = int(a.substr(8))
		elif a.begins_with("--only="):
			ids = Array(a.substr(7).split(",")).map(func(x): return int(x))
		elif a == "--nolight":
			light = false
		elif a.begins_with("--bg="):
			bgc = Color(a.substr(5))
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var bg := ColorRect.new()
	bg.color = bgc
	bg.size = Vector2(8000, 8000)
	root.add_child(bg)
	var crest := {"shape": "shield", "symbol": "star", "c1": "#222222", "c2": "#FFFFFF", "border": "thin", "initials": "FC"}
	var shader: Shader = load("res://scripts/ui/components/photo_real.gdshader")
	var gap := 10
	var label_h := 22
	for slot in ids.size():
		var cs: Dictionary = CASES[int(ids[slot])]
		var x0 := gap + (slot % pairs) * (2 * px + 3 * gap)
		var y0 := gap + (slot / pairs) * (px + label_h + gap)
		for side in 2:
			var pv := _portrait(cs, crest)
			var pos := Vector2(x0 + side * (px + gap), y0 + label_h)
			if side == 0:
				pv.position = pos
				pv.size = Vector2(px, px)
				root.add_child(pv)
			else:
				pv.mesh_light = 1 if light else 0
				var vp := SubViewport.new()
				vp.size = Vector2i(px * 2, px * 2)
				vp.transparent_bg = true
				vp.disable_3d = true
				vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
				pv.size = Vector2(px * 2, px * 2)
				vp.add_child(pv)
				root.add_child(vp)
				var tr := TextureRect.new()
				tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				tr.stretch_mode = TextureRect.STRETCH_SCALE
				tr.texture = vp.get_texture()
				tr.position = pos
				tr.size = Vector2(px, px)
				tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
				var mat := ShaderMaterial.new()
				mat.shader = shader
				mat.set_shader_parameter(&"texel", Vector2(1.0 / (px * 2), 1.0 / (px * 2)))
				mat.set_shader_parameter(&"seed", float(int(cs["seed"]) % 997))
				tr.material = mat
				root.add_child(tr)
				_shots.append([pv, mat, float(px * 2)])
			var lb := Label.new()
			lb.text = ("antes  ·  caso %d" % int(ids[slot])) if side == 0 else "foto (luz + acabamento de câmera)"
			lb.position = Vector2(pos.x, y0)
			lb.add_theme_font_size_override("font_size", 14)
			lb.add_theme_color_override("font_color", Color("#C8CCD4") if side == 0 else Color("#F2C14E"))
			root.add_child(lb)


func _portrait(cs: Dictionary, crest: Dictionary) -> PortraitView:
	var c1 := String(cs["kit"][0])
	var c2 := String(cs["kit"][1])
	var pv := PortraitView.new()
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
	pv.mesh_light = 0
	return pv


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 4:
		# Foco: o rosto de cada retrato (geometria do PortraitView depois do primeiro desenho)
		for s: Array in _shots:
			var pv: PortraitView = s[0]
			var side: float = s[2]
			var mat: ShaderMaterial = s[1]
			mat.set_shader_parameter(&"face_c", Vector2(pv._hc.x / side, (pv._hc.y + pv._fh * 0.05) / side))
			mat.set_shader_parameter(&"face_r", Vector2(pv._fw * 1.05 / side, pv._fh * 1.1 / side))
	if _frames == 18:
		root.get_viewport().get_texture().get_image().save_png(_out)
		print("ok ", _out)
		return true
	return false
