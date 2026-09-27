extends SceneTree
## Folha de escudos de alguns clubes (antes/depois de mexer no desenho dos escudos).
## xvfb-run godot --path . --resolution 1400x1400 --script res://tools/crest_sheet.gd -- --keys=BRA_RNC,ESP_MBL --out=/tmp/k.png
## Opções: --keys=chave,chave (clubes), --size=N (altura de cada uniforme), --cols=N (clubes por linha)

var _out := "user://crest_sheet.png"


func _initialize() -> void:
	var px := 140
	var cols := 6
	var keys: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--size="):
			px = int(a.substr(7))
		elif a.begins_with("--cols="):
			cols = int(a.substr(7))
		elif a.begins_with("--keys="):
			keys = Array(a.substr(7).split(","))
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var bg := ColorRect.new()
	bg.color = Color("#1B1E23")
	bg.size = Vector2(6000, 6000)
	root.add_child(bg)
	var by_key := {}
	var dir := "res://data/world/clubs/"
	for f: String in DirAccess.get_files_at(dir):
		if not f.ends_with(".json"):
			continue
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir + f))
		if typeof(data) != TYPE_DICTIONARY:
			continue
		for cd: Dictionary in data.get("clubs", []):
			by_key[String(cd.get("key", ""))] = [cd, f.get_basename()]
	var i := 0
	for key in keys:
		if not by_key.has(key):
			continue
		var cd: Dictionary = by_key[key][0]
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(String(key))
		var c := ClubGenerator.from_data(null, rng, cd, i, {"nation": by_key[key][1], "id": String(cd.get("league", "")), "tier": 1})
		var origin := Vector2(12 + (i % cols) * (px + 24), 12 + (i / cols) * (px + 40))
		var v := CrestView.new()
		v.position = origin
		v.size = Vector2(px, px)
		v.crest = c.crest
		root.add_child(v)
		var l := Label.new()
		l.text = c.short_name
		l.position = origin + Vector2(0, px + 2)
		l.size = Vector2(px, 18)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override(&"font_size", 12)
		root.add_child(l)
		i += 1


var _frames := 0


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 6:
		root.get_viewport().get_texture().get_image().save_png(_out)
		print("ok ", _out)
		return true
	return false
