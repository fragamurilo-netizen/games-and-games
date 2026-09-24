@tool
class_name KitView
extends Control
## Camisa procedural: cor principal/secundária, padrão, gola e manga.

@export var kit: Dictionary = {"pattern": "stripes_v", "c1": "#B3122E", "c2": "#F2C14E", "collar": "round", "sleeve": "same"}:
	set(v):
		kit = v
		queue_redraw()
@export var number: int = 0:
	set(v):
		number = v
		queue_redraw()

const BODY := [Vector2(0.3, 0.06), Vector2(0.4, 0.1), Vector2(0.5, 0.12), Vector2(0.6, 0.1), Vector2(0.7, 0.06),
	Vector2(0.77, 0.3), Vector2(0.77, 0.95), Vector2(0.23, 0.95), Vector2(0.23, 0.3)]
const SLEEVE_R := [Vector2(0.7, 0.06), Vector2(0.96, 0.2), Vector2(0.88, 0.4), Vector2(0.77, 0.34), Vector2(0.77, 0.3)]
const SLEEVE_L := [Vector2(0.3, 0.06), Vector2(0.23, 0.3), Vector2(0.23, 0.34), Vector2(0.12, 0.4), Vector2(0.04, 0.2)]


func _draw() -> void:
	var s := minf(size.x, size.y)
	if s <= 2.0:
		return
	var off := Vector2((size.x - s) * 0.5, (size.y - s) * 0.5)
	var c1 := Color(kit.get("c1", "#FFFFFF"))
	var c2 := Color(kit.get("c2", "#000000"))
	var body := _xf(BODY, s, off)
	var sr := _xf(SLEEVE_R, s, off)
	var sl := _xf(SLEEVE_L, s, off)
	var sleeve_col := c2 if kit.get("sleeve", "same") == "contrast" else c1
	draw_colored_polygon(sr, sleeve_col)
	draw_colored_polygon(sl, sleeve_col)
	draw_colored_polygon(body, c1)
	for band in pattern_bands(kit.get("pattern", "plain")):
		for piece in Geometry2D.intersect_polygons(_xf(band, s, off), body):
			draw_colored_polygon(piece, c2)
	# Gola
	var collar: String = kit.get("collar", "round")
	var neck: PackedVector2Array
	if collar == "v":
		neck = _xf([Vector2(0.38, 0.08), Vector2(0.5, 0.22), Vector2(0.62, 0.08)], s, off)
	elif collar == "polo":
		neck = _xf([Vector2(0.36, 0.07), Vector2(0.44, 0.15), Vector2(0.5, 0.13), Vector2(0.56, 0.15), Vector2(0.64, 0.07)], s, off)
	else:
		neck = _xf([Vector2(0.38, 0.07), Vector2(0.44, 0.12), Vector2(0.5, 0.13), Vector2(0.56, 0.12), Vector2(0.62, 0.07)], s, off)
	draw_polyline(neck, c2 if c2 != c1 else c1.darkened(0.4), maxf(1.5, s * 0.04), true)
	# Contorno sutil
	var outline := body.duplicate()
	outline.append(body[0])
	draw_polyline(outline, Color(0, 0, 0, 0.35), maxf(1.0, s * 0.012), true)
	if number > 0:
		var font := get_theme_font(&"font", &"Big")
		var fs := int(s * 0.3)
		var txt := str(number)
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var fg := UIColors.on_color(c1)
		draw_string(font, off + Vector2(0.5 * s - w * 0.5, 0.62 * s), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, fg)


## Faixas do padrão em coordenadas unitárias (serão recortadas pelo corpo da camisa).
static func pattern_bands(pattern: String) -> Array:
	var out: Array = []
	match pattern:
		"stripes_v":
			for i in 3:
				var x := 0.3 + i * 0.16
				out.append(PackedVector2Array([Vector2(x, 0), Vector2(x + 0.08, 0), Vector2(x + 0.08, 1), Vector2(x, 1)]))
		"stripes_h":
			for i in 4:
				var y := 0.22 + i * 0.19
				out.append(PackedVector2Array([Vector2(0, y), Vector2(1, y), Vector2(1, y + 0.09), Vector2(0, y + 0.09)]))
		"faixa":
			out.append(PackedVector2Array([Vector2(0, 0.36), Vector2(1, 0.36), Vector2(1, 0.5), Vector2(0, 0.5)]))
		"diagonal":
			out.append(PackedVector2Array([Vector2(0.15, 0.05), Vector2(0.33, 0.05), Vector2(0.9, 0.95), Vector2(0.72, 0.95)]))
		"halves":
			out.append(PackedVector2Array([Vector2(0.5, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0.5, 1)]))
	return out


static func _xf(pts: Array, s: float, off: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(off + p * s)
	return out
