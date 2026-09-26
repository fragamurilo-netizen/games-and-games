class_name InitialsDot
extends Control
## Avatar redondo com iniciais (jornalistas, portais e torcedores das redes sociais).
## Com `flag`, o fundo vira uma bandeira da torcida em duas cores.

var text := ""
var bg := Color("#4EA8DE")
var fg := Color(0, 0, 0, 0)
var flag := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN


func _draw() -> void:
	var r := minf(size.x, size.y) * 0.5
	var c := Vector2(size.x * 0.5, r)
	draw_circle(c, r, bg, true, -1.0, true)
	if flag:
		var pts := PackedVector2Array()
		for i in 25:
			var a := PI * 0.25 + PI * float(i) / 24.0
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		draw_colored_polygon(pts, fg)
		draw_circle(c, r, Color(1, 1, 1, 0.25), false, 1.5, true)
	var tc := fg if fg.a > 0.0 and not flag else (Color.WHITE if bg.get_luminance() < 0.6 else Color("#111111"))
	var font := get_theme_font(&"font", &"Stat")
	var fs := int(r * 0.8)
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if flag:
		draw_string_outline(font, c + Vector2(-tw * 0.5, fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.6))
		tc = Color.WHITE
	draw_string(font, c + Vector2(-tw * 0.5, fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, tc)
