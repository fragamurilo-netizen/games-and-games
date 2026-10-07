extends SceneTree
## Compara anatomias na MESMA pessoa, sem cabelo/barba escondendo o traço.
## godot --path . --resolution 1640x705 --script res://tools/face_anatomy.gd -- --kind=es --out=olhos.png
## kind: fs, es, ns, mt, er. --eth=N e --seed=N mantêm o teste reproduzível.

var _out := "user://anatomia.png"
var _frames := 0


func _initialize() -> void:
	var kind := "es"
	var eth := 1
	var seed_value := 10007
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--kind="):
			kind = arg.substr(7)
		elif arg.begins_with("--eth="):
			eth = int(arg.substr(6))
		elif arg.begins_with("--seed="):
			seed_value = int(arg.substr(7))
	var catalogs := {"fs": [FaceGen.FACE_SHAPES, 18], "es": [FaceGen.EYE_SHAPES, 30], "ns": [FaceGen.NOSE_TYPES, 32], "mt": [FaceGen.MOUTH_TYPES, 26], "er": [FaceGen.EAR_TYPES, 12]}
	if not catalogs.has(kind):
		push_error("kind deve ser fs, es, ns, mt ou er")
		quit(1)
		return
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var bg := ColorRect.new()
	bg.color = Color("#0E1621")
	bg.size = Vector2(4000, 4000)
	root.add_child(bg)
	var catalog: Array = catalogs[kind][0]
	var first: int = catalogs[kind][1]
	for i in catalog.size() - first:
		var view := PortraitView.new()
		view.face_seed = seed_value
		view.eth = eth
		view.age = 28
		view.look = {"hs": FaceGen.H_BALD, "bd": FaceGen.B_NONE, "fs": 0, "es": 0, "ns": 0, "mt": 0, "er": 0, "ex": 0}
		view.look[kind] = first + i
		view.size = Vector2(200, 200)
		view.position = Vector2(5 + (i % 8) * 204, 5 + (i / 8) * 350)
		root.add_child(view)
		var caption := Control.new()
		caption.clip_contents = true
		caption.position = view.position + Vector2(0, 200)
		caption.size = Vector2(200, 43)
		root.add_child(caption)
		var label := Label.new()
		label.text = _caption("%d · %s" % [first + i, catalog[first + i]])
		label.clip_text = true
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override(&"font_size", 12)
		label.size = Vector2(200, 43)
		caption.add_child(label)
		# Ampliação nativa da mesma anatomia, sem recortar um bitmap depois.
		var crop := Control.new()
		crop.clip_contents = true
		crop.position = view.position + Vector2(0, 246)
		crop.size = Vector2(200, 96)
		root.add_child(crop)
		var detail := PortraitView.new()
		detail.face_seed = seed_value
		detail.eth = eth
		detail.age = 28
		detail.look = view.look.duplicate()
		detail.size = Vector2(480, 480)
		detail.position = Vector2(-140, -195)
		match kind:
			"ns": detail.position.y = -242
			"mt": detail.position.y = -292
			"er": detail.position = Vector2(-20, -200)
			"fs": detail.position.y = -340
		crop.add_child(detail)


func _caption(text: String) -> String:
	var lines := ""
	var line := ""
	for word in text.split(" ", false):
		if line.length() + word.length() > 26:
			lines += line + "\n"
			line = ""
		line += (" " if line != "" else "") + word
	return lines + line


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 6:
		var error := root.get_texture().get_image().save_png(_out)
		print("anatomia: ", error_string(error), " · ", _out)
		return true
	return false
