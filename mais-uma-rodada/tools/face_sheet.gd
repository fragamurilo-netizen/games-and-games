extends SceneTree
## Folha de rostos para conferir o gerador: cada linha é uma etnia, as colunas variam semente e idade.
## xvfb-run godot --path . --resolution 1220x1220 --script res://tools/face_sheet.gd -- --out=/tmp/faces.png
## Opções: --size=N (lado de cada retrato), --cols=N, --seed=N, --eth=a,b,c, --ages=16,20,…
## --aging: cada linha é a mesma pessoa envelhecendo pelas idades das colunas.
## --catalog=hs ou --catalog=bd: um retrato por penteado ou por barba, na ordem da lista.
## --beauty: com --aging, as colunas vão da pessoa mais feia à mais bonita.

var _out := "user://faces.png"


func _initialize() -> void:
	var px := 90
	var cols := 13
	var seed_base := 1000
	var eths: Array = range(13)
	var ages: Array = [15, 17, 19, 21, 23, 26, 29, 32, 35, 38, 42, 48, 58]
	var aging := false
	var beauty := false
	var kits := false
	var offset := 0
	var catalog := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--size="):
			px = int(a.substr(7))
		elif a.begins_with("--cols="):
			cols = int(a.substr(7))
		elif a.begins_with("--seed="):
			seed_base = int(a.substr(7))
		elif a.begins_with("--eth="):
			eths = Array(a.substr(6).split(",")).map(func(x): return int(x))
		elif a.begins_with("--catalog="):
			catalog = a.substr(10)
		elif a.begins_with("--offset="):
			offset = int(a.substr(9))
		elif a == "--kits":
			kits = true
		elif a == "--beauty":
			beauty = true
		elif a == "--aging":
			aging = true
		elif a.begins_with("--ages="):
			ages = Array(a.substr(7).split(",")).map(func(x): return int(x))
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var bg := ColorRect.new()
	bg.color = Color("#0E1621")
	bg.size = Vector2(4000, 4000)
	root.add_child(bg)
	for r in eths.size():
		var e: int = eths[r]
		for k in cols:
			var v := PortraitView.new()
			v.position = Vector2(5 + k * (px + 3), 5 + r * (px + 3))
			v.size = Vector2(px, px)
			v.face_seed = seed_base + e * 97 + (r * 131 if aging else k * 7919)
			v.eth = e
			v.age = ages[k % ages.size()]
			if catalog != "":
				v.look = {catalog: offset + r * cols + k}
				v.eth = [1, 7, 3, 4, 8, 6, 2][(r * cols + k) % 7]
				v.age = 30
			if beauty:
				v.look = {"bt": float(k) / maxf(1.0, cols - 1.0)}
			v.shirt_color = Color.from_hsv(fmod((0 if aging else k) * 0.13 + r * 0.07, 1.0), 0.7, 0.7)
			v.trim_color = Color.WHITE
			if kits:
				var i := r * cols + k
				v.trim_color = Color.from_hsv(fmod(i * 0.37, 1.0), 0.6, 0.9) if i % 3 == 0 else Color.WHITE
				var c1 := v.shirt_color
				var c2 := Color.WHITE if i % 3 != 0 else Color.from_hsv(fmod(i * 0.37, 1.0), 0.6, 0.9)
				v.kit = {
					"pattern": ["plain", "stripes_v", "plain", "halves", "stripes_h", "faixa", "diagonal"][i % 7],
					"c1": c1.to_html(false), "c2": c2.to_html(false), "c3": (c2 if i % 2 == 0 else c1.darkened(0.4)).to_html(false),
					"collar": ["round", "v", "polo", "wide", "henley", "mandarin"][i % 6],
					"sleeve": ["same", "contrast", "raglan", "stripes", "cuff"][i % 5],
					"sp": {"n": ["Banco Norte", "Aero Sul", "Nuvem", "Frigo Max"][i % 4], "c": "#FFFFFF", "t": "#FFFFFF"} if i % 2 == 0 else {},
					"sup": {"n": "Marca", "c": "#FFFFFF", "logo": "curva"},
				}
			v.bg_color = v.shirt_color.darkened(0.6)
			if k == cols - 1 and r % 4 == 3:
				v.suit = true
			root.add_child(v)


var _frames := 0
var _t0 := 0


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_t0 = Time.get_ticks_usec()
	if _frames == 2:
		print("primeiro quadro em ", (Time.get_ticks_usec() - _t0) / 1000.0, " ms")
	if _frames == 5:
		root.get_viewport().get_texture().get_image().save_png(_out)
		print("ok ", _out)
		return true
	return false
