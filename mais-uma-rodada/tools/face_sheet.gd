extends SceneTree
## Folha de rostos para conferir o gerador: cada linha é uma etnia, as colunas variam semente e idade.
## xvfb-run godot --path . --resolution 1200x1300 --script res://tools/face_sheet.gd -- --out=/tmp/faces.png

var _out := "user://faces.png"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	var bg := ColorRect.new()
	bg.color = Color("#0E1621")
	bg.size = Vector2(1200, 1300)
	root.add_child(bg)
	var ages := [18, 22, 26, 30, 34, 38, 42, 55]
	for e in 9:
		for k in 8:
			var v := PortraitView.new()
			v.position = Vector2(10 + k * 148, 10 + e * 143)
			v.size = Vector2(138, 138)
			v.face_seed = 1000 + e * 97 + k * 7919
			v.eth = e
			v.age = ages[k]
			v.shirt_color = Color.from_hsv(fmod(k * 0.13 + e * 0.07, 1.0), 0.7, 0.7)
			v.trim_color = Color.WHITE
			v.bg_color = v.shirt_color.darkened(0.6)
			if e == 8 and k == 7:
				v.suit = true
			root.add_child(v)


var _frames := 0


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 5:
		root.get_viewport().get_texture().get_image().save_png(_out)
		print("ok ", _out)
		return true
	return false
