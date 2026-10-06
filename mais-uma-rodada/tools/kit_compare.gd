extends SceneTree
## Folha com os quatro uniformes (titular, reserva, terceiro e goleiro) de alguns clubes, para
## comparar antes e depois de mexer nos uniformes.
## xvfb-run godot --path . --resolution 1400x1400 --script res://tools/kit_compare.gd -- --keys=BRA_RNC,ESP_MBL --out=/tmp/k.png
## Opções: --keys=chave,chave (clubes), --size=N (altura de cada uniforme), --cols=N (clubes por linha)

var _out := "user://kit_compare.png"


func _initialize() -> void:
	var px := 150
	var cols := 2
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
	var w := int(px * KitView.FULL_ASPECT)
	var block_w := 4 * (w + 6) + 16
	var lh := 18
	var i := 0
	for key in keys:
		if not by_key.has(key):
			push_warning("clube não encontrado: " + String(key))
			continue
		var cd: Dictionary = by_key[key][0]
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(String(key))
		var c := ClubGenerator.from_data(null, rng, cd, i, {"nation": by_key[key][1], "id": String(cd.get("league", "")), "tier": 1})
		var origin := Vector2(8 + (i % cols) * block_w, 8 + (i / cols) * (px + lh * 2 + 12))
		var title := Label.new()
		title.text = c.short_name
		title.position = origin
		title.add_theme_font_size_override(&"font_size", 14)
		root.add_child(title)
		var kits := [c.kit_home, c.kit_away, c.third_kit(), c.gk_kit()]
		var names := ["Titular", "Reserva", "Terceiro", "Goleiro"]
		for j in 4:
			var v := KitView.new()
			v.position = origin + Vector2(j * (w + 6), lh)
			v.size = Vector2(w, px)
			v.full = true
			v.number = 1 if j == 3 else 10
			v.kit = kits[j]
			v.crest = c.crest
			root.add_child(v)
			var l := Label.new()
			l.text = names[j]
			l.position = origin + Vector2(j * (w + 6), lh + px)
			l.size = Vector2(w, lh)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.add_theme_font_size_override(&"font_size", 11)
			l.add_theme_color_override(&"font_color", Color("#AAB2BD"))
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
