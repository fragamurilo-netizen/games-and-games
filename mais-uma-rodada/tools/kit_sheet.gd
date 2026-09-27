extends SceneTree
## Folha de uniformes para conferir o KitView.
## xvfb-run godot --path . --resolution 1220x1220 --script res://tools/kit_sheet.gd -- --out=/tmp/kits.png
## Opções: --size=N (altura), --cols=N, --demo (catálogo de estampas), --clubs (titular e reserva dos
## clubes dos arquivos), --league=id, --offset=N, --shirt (só a camisa), --back (costas)

var _out := "user://kits.png"


func _initialize() -> void:
	var px := 200
	var cols := 8
	var mode := "demo"
	var offset := 0
	var league := ""
	var full := true
	var back := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--size="):
			px = int(a.substr(7))
		elif a.begins_with("--cols="):
			cols = int(a.substr(7))
		elif a == "--clubs":
			mode = "clubs"
		elif a == "--proc":
			mode = "proc"
		elif a == "--details":
			mode = "details"
		elif a == "--shirt":
			full = false
		elif a == "--back":
			back = true
		elif a.begins_with("--offset="):
			offset = int(a.substr(9))
		elif a.begins_with("--league="):
			league = a.substr(9)
			mode = "clubs"
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.theme = load("res://assets/theme/main_theme.tres") if ResourceLoader.exists("res://assets/theme/main_theme.tres") else null
	var bg := ColorRect.new()
	bg.color = Color("#141414")
	bg.size = Vector2(4000, 4000)
	root.add_child(bg)
	var specs: Array = []
	var names: Array = []
	var crests: Array = []
	if mode == "demo":
		var pal := [["#B3122E", "#FFFFFF"], ["#0B2A6B", "#FFFFFF"], ["#1C7A3A", "#FFFFFF"], ["#111111", "#F2C14E"], ["#6A1B4D", "#F2C230"], ["#F2C230", "#0B2A6B"], ["#FFFFFF", "#B3122E"], ["#4DA3E0", "#FFFFFF"]]
		var i := 0
		for p in KitView.PATTERNS:
			var c: Array = pal[i % pal.size()]
			specs.append({"pattern": p[0], "c1": c[0], "c2": c[1], "collar": KitView.COLLARS[i % KitView.COLLARS.size()][0],
				"sleeve": KitView.SLEEVES[i % KitView.SLEEVES.size()][0], "shorts_style": KitView.SHORTS_STYLES[i % KitView.SHORTS_STYLES.size()][0],
				"socks_style": KitView.SOCKS_STYLES[i % KitView.SOCKS_STYLES.size()][0],
				"sp": {"n": "Banco Sul", "c": "#FFFFFF", "t": "#111111"}, "sup": {"n": "Volt", "logo": ["curva", "barras", "raio", "asas"][i % 4], "c": "#FFFFFF"}})
			names.append(String(p[1]))
			i += 1
	elif mode == "details":
		var i := 0
		for col in KitView.COLLARS:
			specs.append({"pattern": "plain", "c1": "#0B2A6B", "c2": "#FFFFFF", "c3": "#F2C14E", "collar": col[0]})
			names.append("Gola: " + String(col[1]))
		for sl in KitView.SLEEVES:
			specs.append({"pattern": "plain", "c1": "#FFFFFF", "c2": "#B3122E", "c3": "#111111", "sleeve": sl[0]})
			names.append("Manga: " + String(sl[1]))
		for sh in KitView.SHORTS_STYLES:
			specs.append({"pattern": "plain", "c1": "#1C7A3A", "c2": "#FFFFFF", "shorts": "#FFFFFF", "shorts2": "#1C7A3A", "shorts_style": sh[0]})
			names.append("Calção: " + String(sh[1]))
		for so in KitView.SOCKS_STYLES:
			specs.append({"pattern": "plain", "c1": "#111111", "c2": "#F2C14E", "socks": "#111111", "socks2": "#F2C14E", "socks_style": so[0]})
			names.append("Meião: " + String(so[1]))
		i += 1
	elif mode == "proc":
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		for k in cols * 4:
			var c := Club.new()
			c.key = "P%d" % k
			var pal: Array = ClubGenerator.PALETTE[rng.randi_range(0, ClubGenerator.PALETTE.size() - 1)]
			c.color1 = pal[0]
			c.color2 = pal[1]
			c.reputation = rng.randf_range(10, 90)
			ClubGenerator._make_kits(rng, c, "")
			specs.append(c.kit_home)
			names.append("Procedural %d" % k)
			specs.append(c.kit_away)
			names.append("reserva")
	else:
		var dir := "res://data/world/clubs/"
		var files := Array(DirAccess.get_files_at(dir))
		files.sort()
		for f: String in files:
			if not f.ends_with(".json"):
				continue
			var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir + f))
			if typeof(data) != TYPE_DICTIONARY:
				continue
			for cd: Dictionary in data.get("clubs", []):
				if league != "" and String(cd.get("league", "")) != league and f.get_basename() != league:
					continue
				var rng := RandomNumberGenerator.new()
				rng.seed = hash(String(cd.get("key", "")))
				var c := ClubGenerator.from_data(null, rng, cd, specs.size(), {"nation": f.get_basename(), "id": String(cd.get("league", "")), "tier": 1})
				specs.append(c.kit_home)
				names.append(c.short_name)
				specs.append(c.kit_away)
				names.append("reserva")
				specs.append(c.third_kit())
				names.append("terceiro")
				for i in 3:
					crests.append(c.crest)
		specs = specs.slice(offset)
		names = names.slice(offset)
		crests = crests.slice(offset)
	var w := int(px * (KitView.FULL_ASPECT if full else 1.0))
	var lh := 16
	for i in specs.size():
		var k := i % cols
		var r := i / cols
		var pos := Vector2(6 + k * (w + 8), 6 + r * (px + 8 + lh))
		if pos.y + px > 2400:
			break
		var v := KitView.new()
		v.position = pos
		v.size = Vector2(w, px)
		v.full = full
		v.back = back
		v.number = 10
		v.back_name = "SILVA"
		v.kit = specs[i]
		if i < crests.size():
			v.crest = crests[i]
		root.add_child(v)
		var l := Label.new()
		l.text = String(names[i])
		l.position = pos + Vector2(0, px)
		l.size = Vector2(w, lh)
		l.clip_text = true
		l.add_theme_font_size_override(&"font_size", 11)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		root.add_child(l)


var _frames := 0


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 6:
		root.get_viewport().get_texture().get_image().save_png(_out)
		print("ok ", _out)
		return true
	return false
