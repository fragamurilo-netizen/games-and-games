class_name KitStage
extends Control
## Fundo da foto de lançamento dos uniformes: parede nas cores do clube, luz de estúdio sobre
## o chão e a legenda embaixo. Os uniformes entram como filhos.

var col1 := Color("#1C1D21")
var col2 := Color("#FFFFFF")
var caption := ""


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func _draw() -> void:
	var w := size.x
	var h := size.y
	var base := col1.darkened(0.55)
	# Parede: degradê vertical na cor principal.
	var steps := 16
	for i in steps:
		var t := float(i) / float(steps)
		draw_rect(Rect2(0, h * t, w, h / steps + 1.0), base.lerp(col1.darkened(0.2), 1.0 - absf(t - 0.35) * 1.4))
	# Faixas diagonais na cor secundária, bem sutis.
	var band := Color(col2.r, col2.g, col2.b, 0.07)
	var x := -h
	while x < w + h:
		draw_colored_polygon(PackedVector2Array([Vector2(x, h), Vector2(x + 26, h), Vector2(x + 26 + h, 0), Vector2(x + h, 0)]), band)
		x += 90.0
	# Luz de estúdio atrás dos uniformes.
	var c := Vector2(w * 0.5, h * 0.45)
	for i in 10:
		var rr := h * (0.75 - i * 0.06)
		draw_circle(c, rr, Color(1, 1, 1, 0.025), true, -1.0, true)
	# Chão.
	draw_rect(Rect2(0, h * 0.8, w, h * 0.2), Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2(w * 0.5, h * 0.84), 0.0, Vector2(1.0, 0.12))
	draw_circle(Vector2.ZERO, w * 0.32, Color(1, 1, 1, 0.08), true, -1.0, true)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if caption != "":
		var font := get_theme_font(&"font", &"Stat")
		var fs := 18
		var tw := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pos := Vector2(w * 0.5 - tw * 0.5, h - 9)
		var tc := col2 if absf(col2.get_luminance() - base.get_luminance()) > 0.3 else Color.WHITE
		draw_string(font, pos, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, tc)
