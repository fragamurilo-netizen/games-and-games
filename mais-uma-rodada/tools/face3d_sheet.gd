extends SceneTree
## Folha de rostos 3D do estúdio (jogadores sorteados de várias etnias e idades).
## xvfb-run godot --path . --resolution 800x600 --script res://tools/face3d_sheet.gd -- --out=/tmp/f.png --n=12 --seed=1
## --eth=7 fixa a etnia; --age=30 fixa a idade; --look=hs:6,bd:3 força traços (chaves do look).

var _out := "/tmp/face3d_sheet.png"
var _specs: Array = []
var _frames := 0
var _cols := 6


func _initialize() -> void:
	var n := 12
	var sd := 1
	var eth := -1
	var age := -1
	var look := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--n="):
			n = int(a.substr(4))
		elif a.begins_with("--seed="):
			sd = int(a.substr(7))
		elif a.begins_with("--eth="):
			eth = int(a.substr(6))
		elif a.begins_with("--age="):
			age = int(a.substr(6))
		elif a.begins_with("--cols="):
			_cols = int(a.substr(7))
		elif a.begins_with("--look="):
			for kv in a.substr(7).split(","):
				var p := kv.split(":")
				look[p[0]] = float(p[1]) if "." in p[1] else int(p[1])
	Face3DStudio.enabled = true
	for fn in DirAccess.get_files_at("user://face3d"):
		DirAccess.remove_absolute("user://face3d/" + fn)
	var rng := RandomNumberGenerator.new()
	rng.seed = sd
	var kits := [{"pattern": "stripes_v", "c1": "#B3122E", "c2": "#111111", "collar": "round"},
		{"pattern": "plain", "c1": "#F4F4F4", "c2": "#1B3A8C", "c3": "#1B3A8C", "collar": "v"},
		{"pattern": "hoops", "c1": "#0B7A3E", "c2": "#FFFFFF", "collar": "polo"},
		{"pattern": "plain", "c1": "#FDD116", "c2": "#1A6E3A", "c3": "#1A6E3A", "collar": "round", "sp": {"n": "Banco"}}]
	for i in n:
		var e: int = eth if eth >= 0 else [0, 1, 2, 4, 6, 7, 8, 9, 3, 10, 5, 12][i % 12]
		var ag := age if age > 0 else rng.randi_range(17, 36)
		_specs.append({"seed": rng.randi(), "eth": e, "age": ag, "look": look, "kit": kits[i % kits.size()]})


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 3:
		return false
	var done := 0
	var texs: Array = []
	for s: Dictionary in _specs:
		var t := Face3DStudio.request(s, null)
		texs.append(t)
		if t != null:
			done += 1
	if done < _specs.size() and _frames < 2000:
		return false
	var px := Face3DStudio.PX
	var rows := int(ceil(_specs.size() / float(_cols)))
	var sheet := Image.create(px * _cols, px * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("#2A2E36"))
	for i in texs.size():
		if texs[i] == null:
			continue
		var img: Image = (texs[i] as Texture2D).get_image()
		img.convert(Image.FORMAT_RGBA8)
		sheet.blend_rect(img, Rect2i(0, 0, px, px), Vector2i((i % _cols) * px, (i / _cols) * px))
	sheet.resize(sheet.get_width() / 2, sheet.get_height() / 2, Image.INTERPOLATE_LANCZOS)
	sheet.save_png(_out)
	print("salvo ", _out, " frames ", _frames)
	return true
