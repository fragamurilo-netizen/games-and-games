extends SceneTree
## Laboratório de visual feminino: a mesma lutadora com vários penteados (ou qualquer outra chave
## do `look`), para conferir o que fica bonito.
## xvfb-run -a -s "-screen 0 1700x1500x24" godot --path . --resolution 1620x1380 --script res://tools/fem_lab.gd -- --out=/tmp/x.png
## Opções: --size=N, --cols=N, --seeds=1,2,3 (uma linha por rosto), --eth=1,7,4 (etnia de cada linha),
## --key=hs (chave do look que varia por coluna), --vals=8,32,76, --look=bt:0.9,mk:2 (fixo em todos),
## --age=N, --male (homens), --body (corpo inteiro em vez do retrato).

var _out := "user://fem_lab.png"


func _initialize() -> void:
	var px := 300
	var cols := 5
	var seeds: Array = [4128, 12047, 20311]
	var eths: Array = [1, 7, 4]
	var key := "hs"
	var vals: Array = []
	var fixed := {}
	var age := 26
	var fem := true
	var body := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--size="):
			px = int(a.substr(7))
		elif a.begins_with("--cols="):
			cols = int(a.substr(7))
		elif a.begins_with("--seeds="):
			seeds = Array(a.substr(8).split(",")).map(func(x): return int(x))
		elif a.begins_with("--eth="):
			eths = Array(a.substr(6).split(",")).map(func(x): return int(x))
		elif a.begins_with("--key="):
			key = a.substr(6)
		elif a.begins_with("--vals="):
			vals = Array(a.substr(7).split(",")).map(func(x): return float(x))
		elif a.begins_with("--age="):
			age = int(a.substr(6))
		elif a == "--male":
			fem = false
		elif a == "--body":
			body = true
		elif a.begins_with("--look="):
			for kv in a.substr(7).split(","):
				var p := kv.split(":")
				if p.size() == 2:
					fixed[p[0]] = float(p[1]) if p[1].contains(".") else int(p[1])
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var bg := ColorRect.new()
	bg.color = Color("#0B0B0D")
	bg.size = Vector2(4000, 4000)
	root.add_child(bg)
	if vals.is_empty():
		vals = [-1.0]
	var n := vals.size()
	var per_row := mini(cols, n)
	var rows_per_seed := int(ceil(float(n) / per_row))
	var ch := px * (2.2 if body else 1.0)
	for r in seeds.size():
		for k in n:
			var look := fixed.duplicate()
			if fem:
				look["fem"] = 1
			if not look.has("wt"):
				look["wt"] = 0.3
			var v: float = vals[k]
			if v >= 0.0:
				look[key] = int(v) if is_equal_approx(v, roundf(v)) else v
			var pos := Vector2(6 + (k % per_row) * (px + 6), 6 + (r * rows_per_seed + k / per_row) * (ch + 22))
			var e: int = eths[r % eths.size()]
			if body:
				var b := BodyView.new()
				b.position = pos
				b.size = Vector2(px, ch)
				b.face_seed = seeds[r]
				b.eth = e
				b.age = age
				b.look = look
				b.height_cm = 168
				b.ref_cm = 175
				b.shorts = Color("#7A1F3D")
				b.trim = Color("#E8E2D8")
				root.add_child(b)
			else:
				var p := PortraitView.new()
				p.position = pos
				p.size = Vector2(px, px)
				p.set_face(seeds[r], e, age, look)
				root.add_child(p)
			var l := Label.new()
			l.text = "%s=%s" % [key, str(look.get(key, "-"))]
			if key == "hs" and v >= 0.0:
				l.text = "%d %s" % [int(v), FaceGen.HAIR_STYLES[int(v)]]
			l.position = pos + Vector2(2, ch)
			l.add_theme_font_size_override(&"font_size", 12)
			l.add_theme_color_override(&"font_color", Color(0.85, 0.85, 0.85))
			root.add_child(l)
	process_frame.connect(_shot, CONNECT_ONE_SHOT)


func _shot() -> void:
	await process_frame
	await process_frame
	var img := root.get_texture().get_image()
	img.save_png(_out)
	print("ok ", _out)
	quit()
