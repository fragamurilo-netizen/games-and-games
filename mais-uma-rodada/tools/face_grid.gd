extends SceneTree
## Grade de rostos para revisão (ciclos de refinamento, antes/depois, variedade).
## xvfb-run godot --path . --resolution 1600x1000 --script res://tools/face_grid.gd -- --n=50 --cols=10 --size=160 --out=/tmp/grade.png
## Opções: --seed=N (primeira semente), --n=N, --cols=N, --size=PX, --ages=16,38 (faixa),
## --eth=0,3,7 (só essas etnias), --plain (fundo neutro, sem camisa de clube), --legacy (sem o
## shader da pele, para comparar). Imprime o tempo médio de geração por retrato.

var _out := "user://face_grid.png"
var _n := 50
var _views: Array = []


func _initialize() -> void:
	var cols := 10
	var px := 160
	var seed_base := 7001
	var age_lo := 16
	var age_hi := 38
	var eths: Array = range(13)
	var plain := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--n="):
			_n = int(a.substr(4))
		elif a.begins_with("--cols="):
			cols = int(a.substr(7))
		elif a.begins_with("--size="):
			px = int(a.substr(7))
		elif a.begins_with("--seed="):
			seed_base = int(a.substr(7))
		elif a.begins_with("--ages="):
			var r := a.substr(7).split(",")
			age_lo = int(r[0])
			age_hi = int(r[1])
		elif a.begins_with("--eth="):
			eths = Array(a.substr(6).split(",")).map(func(x): return int(x))
		elif a == "--plain":
			plain = true
		elif a == "--legacy":
			PortraitView.use_skin_shader = false
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var bg := ColorRect.new()
	bg.color = Color("#111418")
	bg.size = Vector2(6000, 6000)
	root.add_child(bg)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_base
	for i in _n:
		var v := PortraitView.new()
		v.position = Vector2(4 + (i % cols) * (px + 4), 4 + (i / cols) * (px + 4))
		v.size = Vector2(px, px)
		v.face_seed = seed_base * 31 + i * 7919
		v.eth = int(eths[rng.randi() % eths.size()])
		v.age = rng.randi_range(age_lo, age_hi)
		var hue := rng.randf()
		v.shirt_color = Color.from_hsv(hue, 0.65, 0.72) if not plain else Color("#2B3440")
		v.trim_color = Color.WHITE if rng.randf() < 0.6 else Color.from_hsv(fmod(hue + 0.5, 1.0), 0.6, 0.9)
		v.bg_color = v.shirt_color.darkened(0.6) if not plain else Color("#3A3F46")
		if not plain and rng.randf() < 0.5:
			v.kit = {"pattern": ["plain", "stripes_v", "plain", "halves", "stripes_h"][rng.randi() % 5],
				"c1": v.shirt_color.to_html(false), "c2": v.trim_color.to_html(false), "c3": v.trim_color.to_html(false),
				"collar": ["round", "v", "polo", "henley"][rng.randi() % 4], "sleeve": "same"}
		root.add_child(v)
		_views.append(v)


var _frames := 0
var _t0 := 0


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_t0 = Time.get_ticks_usec()
	if _frames == 2:
		var ms := (Time.get_ticks_usec() - _t0) / 1000.0
		print("FACE_GRID %d retratos em %.0f ms (média %.1f ms por retrato)" % [_n, ms, ms / maxf(1.0, _n)])
	if _frames == 10:
		root.get_viewport().get_texture().get_image().save_png(_out)
		print("ok ", _out)
		return true
	return false
