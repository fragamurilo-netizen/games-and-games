extends SceneTree
## Catálogo de penteados ou de barbas com o nome embaixo de cada retrato, para revisar o desenho.
## xvfb-run godot --path . --resolution 1400x1400 --script res://tools/hair_catalog.gd -- --kind=hs --out=/tmp/hs.png
## Opções: --kind=hs|bd, --from=N, --to=N (exclusivo), --size=N, --cols=N, --eth=1,7,3 (etnias em rodízio),
## --age=N, --hc=N (cor do cabelo), --seed=N, --zoom=1.7 (aproxima a cabeça),
## --dy=0.1 (desce o enquadramento com zoom), --list=3,18,60 (só esses índices).
## Nos penteados a barba fica raspada; nas barbas o cabelo fica na máquina, para um não esconder o outro.

var _out := "user://catalogo.png"


func _initialize() -> void:
	var kind := "hs"
	var from := 0
	var to := -1
	var px := 150
	var cols := 8
	var eths: Array = [1, 7, 3, 4, 8, 6, 2, 0]
	var age := 29
	var hc := -1
	var seed_base := 4242
	var zoom := 1.0
	var only: Array = []
	var dy := 0.1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--kind="):
			kind = a.substr(7)
		elif a.begins_with("--from="):
			from = int(a.substr(7))
		elif a.begins_with("--to="):
			to = int(a.substr(5))
		elif a.begins_with("--size="):
			px = int(a.substr(7))
		elif a.begins_with("--cols="):
			cols = int(a.substr(7))
		elif a.begins_with("--eth="):
			eths = Array(a.substr(6).split(",")).map(func(x): return int(x))
		elif a.begins_with("--age="):
			age = int(a.substr(6))
		elif a.begins_with("--hc="):
			hc = int(a.substr(5))
		elif a.begins_with("--zoom="):
			zoom = float(a.substr(7))
		elif a.begins_with("--list="):
			only = Array(a.substr(7).split(",")).map(func(x): return int(x))
		elif a.begins_with("--dy="):
			dy = float(a.substr(5))
		elif a.begins_with("--seed="):
			seed_base = int(a.substr(7))
	var lists := {"hs": FaceGen.HAIR_STYLES, "bd": FaceGen.BEARDS, "fs": FaceGen.FACE_SHAPES, "es": FaceGen.EYE_SHAPES,
		"ns": FaceGen.NOSE_TYPES, "mt": FaceGen.MOUTH_TYPES, "bw": FaceGen.BROW_TYPES, "er": FaceGen.EAR_TYPES,
		"cn": FaceGen.CHIN_TYPES, "ex": FaceGen.EXPRESSIONS}
	var names: Array = []
	if lists.has(kind):
		names = lists[kind]
	else:
		# Escalas contínuas: ms (fino → gordo), bt (feio → bonito), age (idade, uma mesma pessoa)
		var n := to if to > 0 else 8
		for i in n:
			var t := float(i) / maxf(1.0, n - 1.0)
			match kind:
				"ms":
					names.append("massa %.1f" % lerpf(-1.0, 1.0, t))
				"bt":
					names.append("beleza %.2f" % t)
				"age":
					names.append("%d anos" % int(lerpf(18.0, 72.0, t)))
	if to < 0 or to > names.size():
		to = names.size()
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var bg := ColorRect.new()
	bg.color = Color("#0E1621")
	bg.size = Vector2(6000, 6000)
	root.add_child(bg)
	var font := ThemeDB.fallback_font
	var cell_h := px + 22
	if only.is_empty():
		only = range(from, to)
	for n in only.size():
		var idx: int = only[n]
		var r := n / cols
		var k := n % cols
		var holder := Control.new()
		holder.clip_contents = true
		holder.position = Vector2(6 + k * (px + 6), 6 + r * cell_h)
		holder.size = Vector2(px, px)
		root.add_child(holder)
		var v := PortraitView.new()
		v.size = Vector2(px, px) * zoom
		v.position = Vector2(-(zoom - 1.0) * 0.5 * px, -(zoom - 1.0) * dy * px)
		v.face_seed = seed_base + idx * 31
		v.eth = eths[idx % eths.size()]
		v.age = age
		var look := {}
		match kind:
			"hs":
				look = {"hs": idx, "bd": 0}
			"bd":
				look = {"bd": idx, "hs": FaceGen.H_CREW}
			"ms", "bt", "age":
				var t := float(idx) / maxf(1.0, names.size() - 1.0)
				v.face_seed = seed_base
				if kind == "ms":
					look = {"ms": lerpf(-1.0, 1.0, t), "bd": 0, "ex": 0}
				elif kind == "bt":
					look = {"bt": t, "bd": 0, "ex": 0}
					v.face_seed = seed_base + idx * 31
				else:
					look = {"ex": 0}
					v.age = int(lerpf(18.0, 72.0, t))
					v.eth = eths[0]
			_:
				look = {kind: idx, "bd": 0, "hs": FaceGen.H_CREW}
				if kind != "ex":
					look["ex"] = 0
		if hc >= 0:
			look["hc"] = hc
		v.look = look
		v.shirt_color = Color.from_hsv(fmod(idx * 0.13, 1.0), 0.55, 0.55)
		v.trim_color = Color.WHITE
		v.bg_color = v.shirt_color.darkened(0.6)
		holder.add_child(v)
		var l := Label.new()
		l.text = "%d %s" % [idx, names[idx]]
		l.position = Vector2(6 + k * (px + 6), 6 + r * cell_h + px)
		l.size = Vector2(px, 20)
		l.clip_text = true
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 12)
		l.add_theme_color_override("font_color", Color("#DDE6F0"))
		root.add_child(l)


var _frames := 0


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 12:
		root.get_viewport().get_texture().get_image().save_png(_out)
		print("ok ", _out)
		return true
	return false
