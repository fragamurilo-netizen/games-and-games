extends SceneTree
## Laboratório de retratos: poucos rostos grandes para ajustar o shader.
## xvfb-run godot --path . --rendering-driver opengl3 --resolution 1300x680 --script res://tools/face_lab.gd -- --out=/tmp/lab.png
## Opções: --size=N, --seeds=a,b,c, --eths=a,b,c, --ages=a,b,c, --look=hs:3;bd:2 (aplicado a todos)

var _out := "user://lab.png"


func _initialize() -> void:
	var px := 320
	var seeds: Array = [11, 222, 3333, 4444]
	var eths: Array = [1, 4, 7, 8]
	var ages: Array = [24, 27, 30, 22]
	var look := {}
	var kits := true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--size="):
			px = int(a.substr(7))
		elif a.begins_with("--seeds="):
			seeds = Array(a.substr(8).split(",")).map(func(x): return int(x))
		elif a.begins_with("--eths="):
			eths = Array(a.substr(7).split(",")).map(func(x): return int(x))
		elif a.begins_with("--ages="):
			ages = Array(a.substr(7).split(",")).map(func(x): return int(x))
		elif a.begins_with("--look="):
			for kv in a.substr(7).split(";"):
				var parts := kv.split(":")
				if parts.size() == 2:
					look[parts[0]] = int(parts[1]) if parts[1].is_valid_int() else float(parts[1])
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var bg := ColorRect.new()
	bg.color = Color("#0E1621")
	bg.size = Vector2(6000, 6000)
	root.add_child(bg)
	var n := seeds.size()
	for i in n:
		var v := PortraitView.new()
		v.position = Vector2(6 + i * (px + 6), 6)
		v.size = Vector2(px, px)
		v.face_seed = int(seeds[i])
		v.eth = int(eths[i % eths.size()])
		v.age = int(ages[i % ages.size()])
		v.look = look
		var hue := fmod(i * 0.27 + 0.05, 1.0)
		var c1 := Color.from_hsv(hue, 0.75, 0.72)
		v.kit = {"pattern": ["plain", "stripes_v", "halves", "stripes_h"][i % 4], "c1": c1.to_html(false), "c2": "#FFFFFF",
			"c3": c1.darkened(0.3).to_html(false), "collar": ["round", "v", "polo", "henley"][i % 4], "sleeve": "same",
			"sp": {"n": ["Banco Norte", "Aero Sul", "Nuvem", "Frigo Max"][i % 4], "c": "#FFFFFF"}, "sup": {"n": "Marca", "c": "#FFFFFF", "logo": "curva"}}
		if "crest" in v:
			v.set("crest", {"shape": "shield", "symbol": "star", "c1": c1.darkened(0.2).to_html(false), "c2": "#FFFFFF", "border": "thin"})
		v.bg_color = c1.darkened(0.62)
		root.add_child(v)


var _frames := 0


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 30:
		root.get_viewport().get_texture().get_image().save_png(_out)
		print("ok ", _out)
		return true
	return false
