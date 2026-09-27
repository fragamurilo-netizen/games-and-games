extends SceneTree
## Cutouts grandes para conferir realismo: cabelos, barbas e camisa com a luz de estúdio.
## xvfb-run godot --path . --resolution 1280x660 --script res://tools/cutout_closeup.gd -- --out=/tmp/closeup.png
## --size=N (lado de cada retrato), --only=a,b (só esses casos), --clean (rostos limpos)

var _out := "user://closeup.png"
var _frames := 0

## Com --clean: rostos sem barba e com cabelo curto, para julgar só o rosto.
const CLEAN: Array = [
	{"eth": 0, "age": 24, "look": {"hs": 3, "bd": 0}, "kit": {"pattern": "plain", "c1": "#B3122E", "c2": "#FFFFFF", "c3": "#FFFFFF", "collar": "round", "sleeve": "same"}},
	{"eth": 2, "age": 28, "look": {"hs": 8, "bd": 0}, "kit": {"pattern": "plain", "c1": "#0B2A6B", "c2": "#FFFFFF", "c3": "#FFFFFF", "collar": "v", "sleeve": "same"}},
	{"eth": 6, "age": 23, "look": {"hs": 1, "bd": 0}, "kit": {"pattern": "plain", "c1": "#FFFFFF", "c2": "#111111", "c3": "#111111", "collar": "round", "sleeve": "same"}},
	{"eth": 4, "age": 31, "look": {"hs": 5, "bd": 0}, "kit": {"pattern": "plain", "c1": "#1C7A3A", "c2": "#FFFFFF", "c3": "#FFFFFF", "collar": "polo", "sleeve": "same"}},
]

const CASES: Array = [
	{"eth": 0, "age": 27, "look": {"hs": 6, "bd": 3, "hc": 1}, "kit": {"pattern": "stripes_v", "c1": "#B3122E", "c2": "#FFFFFF", "c3": "#111111", "collar": "crossover", "sleeve": "cuff"}},
	{"eth": 2, "age": 24, "look": {"hs": 20, "bd": 12}, "kit": {"pattern": "plain", "c1": "#F2C230", "c2": "#0B2A6B", "c3": "#0B2A6B", "collar": "v", "sleeve": "same"}},
	{"eth": 4, "age": 31, "look": {"hs": 45, "bd": 25, "hc": 3}, "kit": {"pattern": "halves", "c1": "#0B2A6B", "c2": "#FFFFFF", "c3": "#F2C14E", "collar": "polo", "sleeve": "contrast"}},
	{"eth": 1, "age": 34, "look": {"hs": 88, "bd": 55}, "kit": {"pattern": "plain", "c1": "#FFFFFF", "c2": "#111111", "c3": "#B3122E", "collar": "round", "sleeve": "tipped"}},
	{"eth": 6, "age": 22, "look": {"hs": 100, "bd": 0}, "kit": {"pattern": "hoops", "c1": "#1C7A3A", "c2": "#FFFFFF", "c3": "#111111", "collar": "ringer", "sleeve": "same"}},
	{"eth": 3, "age": 29, "look": {"hs": 12, "bd": 60, "hc": 2}, "kit": {"pattern": "plain", "c1": "#111111", "c2": "#F2C14E", "c3": "#F2C14E", "collar": "zip", "sleeve": "shoulder_stripe"}},
	{"eth": 5, "age": 38, "look": {"hs": 30, "bd": 40}, "kit": {"pattern": "stripes_h", "c1": "#4DA3E0", "c2": "#FFFFFF", "c3": "#0B2A6B", "collar": "laced", "sleeve": "same"}},
	{"eth": 7, "age": 25, "look": {"hs": 70, "bd": 8, "hc": 0}, "kit": {"pattern": "diagonal", "c1": "#6A1B4D", "c2": "#F2C230", "c3": "#111111", "collar": "mandarin", "sleeve": "raglan"}},
]


func _initialize() -> void:
	var px := 310
	var only: Array = []
	var cases: Array = CASES
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--size="):
			px = int(a.substr(7))
		elif a == "--clean":
			cases = CLEAN
		elif a.begins_with("--only="):
			only = Array(a.substr(7).split(",")).map(func(x): return int(x))
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var bg := ColorRect.new()
	bg.color = Color("#141414")
	bg.size = Vector2(6000, 6000)
	root.add_child(bg)
	var crest := {"shape": "shield", "symbol": "star", "c1": "#222222", "c2": "#FFFFFF", "border": "thin", "initials": "FC"}
	var ids: Array = only if not only.is_empty() else range(cases.size())
	for slot in ids.size():
		var i: int = ids[slot]
		var cs: Dictionary = cases[i]
		var k: Dictionary = cs["kit"].duplicate()
		k["sp"] = {"n": "Banco Sul", "c": "#FFFFFF", "t": "#111111"}
		k["sup"] = {"n": "Volt", "logo": "curva", "c": "#FFFFFF"}
		var pv := PortraitView.new()
		pv.position = Vector2(10 + (slot % 4) * (px + 10), 10 + (slot / 4) * (px + 10))
		pv.size = Vector2(px, px)
		pv.face_seed = 7100 + i * 97
		pv.eth = int(cs["eth"])
		pv.age = int(cs["age"])
		pv.look = cs["look"]
		pv.shirt_color = Color(String(k["c1"]))
		pv.trim_color = Color(String(k["c2"]))
		pv.bg_color = Color(String(k["c1"])).darkened(0.6)
		pv.kit = k
		pv.crest = crest
		root.add_child(pv)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 14:
		root.get_viewport().get_texture().get_image().save_png(_out)
		print("ok ", _out)
		return true
	return false
