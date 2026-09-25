extends SceneTree
## Folha de escudos para conferir o CrestView.
## xvfb-run godot --path . --resolution 1220x1220 --script res://tools/crest_sheet.gd -- --out=/tmp/crests.png
## Opções: --size=N, --cols=N, --demo (catálogo de formatos/campos/símbolos),
## --clubs (escudos dos clubes reais, na ordem dos arquivos), --offset=N, --league=id

var _out := "user://crests.png"


func _initialize() -> void:
	var px := 110
	var cols := 10
	var mode := "demo"
	var offset := 0
	var league := ""
	var only_syms: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--size="):
			px = int(a.substr(7))
		elif a.begins_with("--cols="):
			cols = int(a.substr(7))
		elif a.begins_with("--syms="):
			mode = "syms"
			only_syms = Array(a.substr(7).split(","))
		elif a == "--proc":
			mode = "proc"
		elif a == "--clubs":
			mode = "clubs"
		elif a.begins_with("--offset="):
			offset = int(a.substr(9))
		elif a.begins_with("--league="):
			league = a.substr(9)
			mode = "clubs"
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var bg := ColorRect.new()
	bg.color = Color("#0E1621")
	bg.size = Vector2(4000, 4000)
	root.add_child(bg)
	var specs: Array = []
	var names: Array = []
	if mode == "demo":
		specs = _demo()
	elif mode == "proc":
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for nat in ["BRA", "ARG", "ENG", "GER", "ITA", "ESP", "FRA", "TUR", "KSA", "JPN"]:
			for k in cols:
				var c := Club.new()
				c.nation = nat
				c.name = "Clube %d" % k
				c.short_name = c.name
				c.abbr = "CLU"
				c.founded = 1920
				var pal: Array = ClubGenerator.PALETTE[rng.randi_range(0, ClubGenerator.PALETTE.size() - 1)]
				c.color1 = pal[0]
				c.color2 = pal[1]
				ClubGenerator._make_crest(rng, c, {})
				specs.append(c.crest)
				names.append(nat)
	elif mode == "syms":
		for i in only_syms.size():
			specs.append({"shape": "iberian", "c1": ["#0B2A6B", "#B3122E", "#1C7A3A", "#111111"][i % 4], "c2": "#FFFFFF", "symbol": only_syms[i]})
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
			var list: Array = data.get("clubs", [])
			for cd: Dictionary in list:
				if league != "" and String(cd.get("league", "")) != league and f.get_basename() != league:
					continue
				var rng := RandomNumberGenerator.new()
				rng.seed = hash(String(cd.get("key", "")))
				var c := ClubGenerator.from_data(null, rng, cd, specs.size(), {"nation": f.get_basename(), "id": String(cd.get("league", "")), "tier": 1})
				specs.append(c.crest)
				names.append(c.name)
		specs = specs.slice(offset)
		names = names.slice(offset)
	var rows := int(ceil(float(specs.size()) / cols))
	var lh := 14 if not names.is_empty() else 0
	for i in specs.size():
		var k := i % cols
		var r := i / cols
		if 5 + r * (px + 3 + lh) > 1220:
			break
		var v := CrestView.new()
		v.position = Vector2(5 + k * (px + 3), 5 + r * (px + 3 + lh))
		v.size = Vector2(px, px)
		v.crest = specs[i]
		root.add_child(v)
		if not names.is_empty():
			var l := Label.new()
			l.text = String(names[i])
			l.position = v.position + Vector2(0, px - 2)
			l.size = Vector2(px, lh)
			l.clip_text = true
			l.add_theme_font_size_override(&"font_size", 10)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			root.add_child(l)
	if rows == 0:
		print("nenhum escudo")


func _demo() -> Array:
	var out: Array = []
	var shapes := ["shield", "heater", "iberian", "french", "swiss", "tall", "notched", "scallop", "modern", "round", "ring", "oval", "oval_ring", "octagon", "diamond", "hexagon", "square", "pennant"]
	var fields := ["plain", "stripes:3", "stripes:5", "hoops:4", "halves", "halves_h", "tierce", "quarters", "sash", "sash_r", "diag", "chevron", "cross", "saltire", "chief", "base", "pale", "lozenges", "checky", "bordure", "pile"]
	var syms := ["eagle", "lion", "lion_head", "rooster", "wolf", "bull", "bull_charging", "fox", "bird", "seagull", "devil", "cannon", "hammers", "ship", "caravel", "castle", "bat", "owl", "rose", "tree", "fleur", "clover", "shamrock", "bee", "dragon", "antlers", "ram", "cat", "horse", "cross_pattee", "anchor_oars", "trident", "swords", "key", "lighthouse", "ball", "torch", "mountain", "sunrise", "star", "southern_cross", "bolt", "anchor", "tower", "waves", "gear", "letter", "stars:3", "crown"]
	var pal := [["#B3122E", "#FFFFFF"], ["#0B2A6B", "#FFFFFF"], ["#1C7A3A", "#FFFFFF"], ["#111111", "#FFFFFF"], ["#6A1B4D", "#F2C230"], ["#F2C230", "#0B2A6B"], ["#FFFFFF", "#B3122E"], ["#4DA3E0", "#FFFFFF"]]
	for i in shapes.size():
		var p: Array = pal[i % pal.size()]
		out.append({"shape": shapes[i], "field": "plain", "c1": p[0], "c2": p[1], "symbol": syms[i % syms.size()], "text": "SPORT CLUB" if shapes[i].contains("ring") else "", "year": "1908", "initials": "SC"})
	for i in fields.size():
		var p: Array = pal[(i + 3) % pal.size()]
		out.append({"shape": ["shield", "iberian", "french", "round"][i % 4], "field": fields[i], "c1": p[0], "c2": p[1], "symbol": syms[(i * 3) % syms.size()], "initials": "AC"})
	for i in syms.size():
		var p: Array = pal[(i + 5) % pal.size()]
		out.append({"shape": "iberian", "field": "plain", "c1": p[0], "c2": p[1], "symbol": syms[i], "initials": "CR"})
	# Composições
	out.append({"shape": "ring", "c1": "#0B2A6B", "c2": "#FFFFFF", "field": "stripes:5", "symbol": "eagle", "text": "SPORT CLUB DO NORTE", "year": "1912", "stars": 3})
	out.append({"shape": "french", "c1": "#FFFFFF", "c2": "#B3122E", "field": "chief", "chief_text": "SCR", "symbol": "lion", "crown": 1})
	out.append({"shape": "iberian", "c1": "#1C7A3A", "c2": "#FFFFFF", "field": "hoops:4", "symbol": "letter", "initials": "SEP", "stars": 1, "laurel": true})
	out.append({"shape": "shield", "c1": "#111111", "c2": "#FFFFFF", "field": "stripes:5", "symbol": "none", "ribbon": "1904", "crown": 2, "border": "gold"})
	out.append({"shape": "round", "c1": "#B3122E", "c2": "#F2C230", "field": "quarters", "symbol": "cross_plain", "stars": 5, "border": "double"})
	out.append({"shape": "oval_ring", "c1": "#6A1B4D", "c2": "#FFFFFF", "symbol": "tower", "text": "ATLETICO", "text2": "MMXX"})
	return out


var _frames := 0


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 6:
		root.get_viewport().get_texture().get_image().save_png(_out)
		print("ok ", _out)
		return true
	return false
