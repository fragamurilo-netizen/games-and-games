extends SceneTree
## Folha de escudos e logos para conferir o CrestView (antes/depois de mexer no desenho).
## xvfb-run -a godot --path . --resolution 1400x1400 --script res://tools/crest_sheet.gd -- --keys=BRA_RNC,ESP_MBL --out=/tmp/k.png
## Opções: --size=N (lado de cada escudo), --cols=N, --h=N (altura útil da tela), --offset=N
##   --keys=chave,chave  clubes pela chave        --names=Nome,Nome  clubes pelo nome
##   --clubs  todos os clubes reais               --league=ID|NAÇÃO  só os de uma liga ou país
##   --syms=a,b  símbolos do CrestArt             --proc  escudos gerados por país
##   --logos  logos de ligas, copas e torneios (cada um também em 40 px, como aparece nas listas)
##   --comps=A,B  só essas competições

var _out := "user://crest_sheet.png"


func _initialize() -> void:
	var px := 120
	var cols := 8
	var mode := "clubs"
	var offset := 0
	var league := ""
	var max_h := 1400
	var keys: Array = []
	var only_names: Array = []
	var only_syms: Array = []
	var only_comps: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--size="):
			px = int(a.substr(7))
		elif a.begins_with("--cols="):
			cols = int(a.substr(7))
		elif a.begins_with("--h="):
			max_h = int(a.substr(4))
		elif a.begins_with("--offset="):
			offset = int(a.substr(9))
		elif a.begins_with("--keys="):
			keys = Array(a.substr(7).split(","))
		elif a.begins_with("--names="):
			only_names = Array(a.substr(8).split(","))
		elif a.begins_with("--league="):
			league = a.substr(9)
		elif a.begins_with("--syms="):
			mode = "syms"
			only_syms = Array(a.substr(7).split(","))
		elif a == "--proc":
			mode = "proc"
		elif a == "--logos":
			mode = "logos"
		elif a.begins_with("--comps="):
			mode = "logos"
			only_comps = Array(a.substr(8).split(","))
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var bg := ColorRect.new()
	bg.color = Color("#15181B")
	bg.size = Vector2(8000, 8000)
	root.add_child(bg)
	var specs: Array = []
	var names: Array = []
	match mode:
		"logos":
			for id in _comp_ids():
				if not only_comps.is_empty() and not only_comps.has(id):
					continue
				specs.append(CompText.logo(id))
				names.append(id)
		"syms":
			for i in only_syms.size():
				specs.append({"shape": "iberian", "c1": ["#0B2A6B", "#B3122E", "#1C7A3A", "#111111"][i % 4], "c2": "#FFFFFF", "symbol": only_syms[i]})
				names.append(only_syms[i])
		"proc":
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
		_:
			var dir := "res://data/world/clubs/"
			var files := Array(DirAccess.get_files_at(dir))
			files.sort()
			var by_key := {}
			for f: String in files:
				if not f.ends_with(".json"):
					continue
				var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir + f))
				if typeof(data) != TYPE_DICTIONARY:
					continue
				for cd: Dictionary in data.get("clubs", []):
					by_key[String(cd.get("key", ""))] = [cd, f.get_basename()]
			var order: Array = keys if not keys.is_empty() else by_key.keys()
			for key in order:
				if not by_key.has(key):
					continue
				var cd: Dictionary = by_key[key][0]
				var nat: String = by_key[key][1]
				if league != "" and String(cd.get("league", "")) != league and nat != league:
					continue
				if not only_names.is_empty() and not only_names.has(String(cd.get("name", ""))) and not only_names.has(String(cd.get("short", ""))):
					continue
				var rng := RandomNumberGenerator.new()
				rng.seed = hash(String(key))
				var c := ClubGenerator.from_data(null, rng, cd, specs.size(), {"nation": nat, "id": String(cd.get("league", "")), "tier": 1})
				specs.append(c.crest)
				names.append(c.short_name)
	specs = specs.slice(offset)
	names = names.slice(offset)
	var small := 40 if mode == "logos" else 0
	var cell_w := px + (small + 6 if small > 0 else 0) + 10
	var lh := 16
	var shown := 0
	for i in specs.size():
		var k := i % cols
		var r := i / cols
		var origin := Vector2(8 + k * cell_w, 8 + r * (px + lh + 10))
		if origin.y + px + lh > max_h:
			break
		var v := CrestView.new()
		v.position = origin
		v.size = Vector2(px, px)
		v.crest = specs[i]
		root.add_child(v)
		if small > 0:
			var sv := CrestView.new()
			sv.position = origin + Vector2(px + 4, px - small)
			sv.size = Vector2(small, small)
			sv.crest = specs[i]
			root.add_child(sv)
		var l := Label.new()
		l.text = String(names[i])
		l.position = origin + Vector2(0, px + 1)
		l.size = Vector2(cell_w - 10, lh)
		l.clip_text = true
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override(&"font_size", 12)
		l.add_theme_color_override(&"font_color", Color("#A5ABB2"))
		root.add_child(l)
		shown += 1
	print("escudos: %d de %d" % [shown, specs.size()])


## Ligas, copas (continentais, estaduais, nacionais) e torneios de seleções, na ordem dos dados.
func _comp_ids() -> Array:
	var out: Array = []
	for id in DatabaseManager.league_ids():
		out.append(id)
	for id in DatabaseManager.cups_cfg():
		out.append(id)
	for id in DatabaseManager.international_cfg().get("tournaments", {}):
		out.append(id)
	return out


var _frames := 0


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 6:
		root.get_viewport().get_texture().get_image().save_png(_out)
		print("ok ", _out)
		return true
	return false
