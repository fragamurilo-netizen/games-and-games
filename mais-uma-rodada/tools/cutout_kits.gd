extends SceneTree
## Uniforme do KitView ao lado do retrato (cutout) vestindo o mesmo uniforme, para conferir que o
## retrato reflete o desenho do customizador (estampa, tom sobre tom, gola, mangas, vivos).
## xvfb-run godot --path . --resolution 1240x1240 --script res://tools/cutout_kits.gd -- --out=/tmp/cutouts.png

var _out := "user://cutouts.png"
var _frames := 0

const KITS: Array = [
	{"pattern": "stripes_v", "c1": "#B3122E", "c2": "#FFFFFF", "c3": "#111111", "collar": "crossover", "sleeve": "cuff", "trim": "none"},
	{"pattern": "pinstripes", "tonal": true, "c1": "#0B2A6B", "c2": "#FFFFFF", "c3": "#F2C14E", "collar": "ringer", "sleeve": "tipped", "trim": "shoulders"},
	{"pattern": "tricolor_v", "c1": "#1C7A3A", "c2": "#FFFFFF", "c3": "#C8102E", "collar": "round", "sleeve": "same"},
	{"pattern": "gradient", "c1": "#111111", "c2": "#F2C14E", "c3": "#F2C14E", "collar": "zip", "sleeve": "shoulder_stripe", "trim": "sides"},
	{"pattern": "halves", "c1": "#6A1B4D", "c2": "#F2C230", "c3": "#111111", "collar": "retro", "sleeve": "contrast"},
	{"pattern": "stripes_h", "c1": "#F2C230", "c2": "#0B2A6B", "c3": "#0B2A6B", "collar": "laced", "sleeve": "same", "trim": "both"},
	{"pattern": "diagonal", "c1": "#FFFFFF", "c2": "#B3122E", "c3": "#B3122E", "collar": "v", "sleeve": "raglan"},
	{"pattern": "topo", "tonal": true, "c1": "#2BB3A3", "c2": "#111111", "c3": "#111111", "collar": "mandarin", "sleeve": "cuff_double"},
	{"pattern": "chevron", "c1": "#4DA3E0", "c2": "#FFFFFF", "c3": "#0B2A6B", "collar": "polo", "sleeve": "stripes"},
	{"pattern": "fade_up", "c1": "#E4572E", "c2": "#111111", "c3": "#FFFFFF", "collar": "henley", "sleeve": "pattern"},
]


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.theme = load("res://assets/theme/main_theme.tres") if ResourceLoader.exists("res://assets/theme/main_theme.tres") else null
	var bg := ColorRect.new()
	bg.color = Color("#141414")
	bg.size = Vector2(4000, 4000)
	root.add_child(bg)
	var crest := {"shape": "shield", "symbol": "star", "c1": "#222222", "c2": "#FFFFFF", "border": "thin", "initials": "FC"}
	for i in KITS.size():
		var k: Dictionary = KITS[i].duplicate()
		k["sp"] = {"n": "Banco Sul", "c": "#FFFFFF", "t": "#111111"}
		k["sup"] = {"n": "Volt", "logo": "curva", "c": "#FFFFFF"}
		var col := i % 2
		var row := i / 2
		var pos := Vector2(10 + col * 615, 10 + row * 240)
		var kv := KitView.new()
		kv.kit = k
		kv.crest = crest
		kv.position = pos
		kv.size = Vector2(220, 220)
		root.add_child(kv)
		var pv := PortraitView.new()
		pv.position = pos + Vector2(240, 0)
		pv.size = Vector2(220, 220)
		pv.face_seed = 4000 + i * 131
		pv.eth = i % 8
		pv.age = 26
		pv.shirt_color = Color(String(k["c1"]))
		pv.trim_color = Color(String(k["c2"]))
		pv.bg_color = Color(String(k["c1"])).darkened(0.6)
		pv.kit = k
		pv.crest = crest
		root.add_child(pv)
		var l := Label.new()
		l.text = "%s%s\n%s\n%s" % [k["pattern"], " (tom)" if k.get("tonal", false) else "", k["collar"], k["sleeve"]]
		l.position = pos + Vector2(470, 20)
		root.add_child(l)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 12:
		root.get_viewport().get_texture().get_image().save_png(_out)
		print("ok ", _out)
		return true
	return false
