class_name BroadcasterLogo
extends Control
## Logo desenhado de uma emissora: selo arredondado nas cores dela, um símbolo próprio (anel,
## estrela, onda, barras, losango ou sol — escolhido pelo nome, sempre o mesmo) e a sigla.

const MARKS := ["anel", "estrela", "onda", "barras", "losango", "sol"]

var brand: Dictionary = {}:
	set(v):
		brand = v
		_fit()
		queue_redraw()
var px := 28.0 # altura


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


static func make(b: Dictionary, height: float = 28.0) -> BroadcasterLogo:
	var l := BroadcasterLogo.new()
	l.px = height
	l.brand = b
	return l


func _font() -> Font:
	var th := ThemeDB.get_project_theme()
	if th != null and th.has_font(&"font", &"Big"):
		return th.get_font(&"font", &"Big")
	return ThemeDB.fallback_font


func _fit() -> void:
	var f := _font()
	var fs := int(px * 0.62)
	var tw := f.get_string_size(String(brand.get("short", "TV")), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	custom_minimum_size = Vector2(px * 1.05 + tw + px * 0.45, px)


func _draw() -> void:
	if brand.is_empty():
		return
	var c1: Color = brand.get("c1", Color("#101010"))
	var c2: Color = brand.get("c2", Color.WHITE)
	var r := Rect2(Vector2.ZERO, size)
	var sb := StyleBoxFlat.new()
	sb.bg_color = c1
	sb.set_corner_radius_all(int(px * 0.28))
	sb.border_color = c2.lerp(c1, 0.55)
	sb.set_border_width_all(1)
	draw_style_box(sb, r)
	# Símbolo à esquerda
	var m := px * 0.5
	var cen := Vector2(px * 0.55, size.y * 0.5)
	var kind: String = MARKS[absi(hash(String(brand.get("name", "")))) % MARKS.size()]
	match kind:
		"anel":
			draw_arc(cen, m * 0.62, 0.0, TAU, 32, c2, px * 0.12, true)
			draw_circle(cen, m * 0.22, c2, true, -1.0, true)
		"estrela":
			var pts := PackedVector2Array()
			for i in 10:
				var a := -PI / 2.0 + i * TAU / 10.0
				pts.append(cen + Vector2(cos(a), sin(a)) * (m * 0.7 if i % 2 == 0 else m * 0.3))
			draw_colored_polygon(pts, c2)
		"onda":
			for k in 2:
				var pts2 := PackedVector2Array()
				for i in 13:
					var t := float(i) / 12.0
					pts2.append(cen + Vector2((t - 0.5) * m * 1.5, sin(t * TAU) * m * 0.22 + (k - 0.5) * m * 0.5))
				draw_polyline(pts2, c2, px * 0.09, true)
		"barras":
			for i in 3:
				var h := m * (0.5 + 0.35 * i)
				draw_rect(Rect2(cen + Vector2(-m * 0.6 + i * m * 0.45, m * 0.6 - h), Vector2(m * 0.3, h)), c2)
		"losango":
			draw_colored_polygon(PackedVector2Array([cen + Vector2(0, -m * 0.7), cen + Vector2(m * 0.6, 0), cen + Vector2(0, m * 0.7), cen + Vector2(-m * 0.6, 0)]), c2)
			draw_colored_polygon(PackedVector2Array([cen + Vector2(0, -m * 0.3), cen + Vector2(m * 0.25, 0), cen + Vector2(0, m * 0.3), cen + Vector2(-m * 0.25, 0)]), c1)
		"sol":
			draw_circle(cen, m * 0.34, c2, true, -1.0, true)
			for i in 8:
				var a2 := i * TAU / 8.0
				draw_line(cen + Vector2(cos(a2), sin(a2)) * m * 0.46, cen + Vector2(cos(a2), sin(a2)) * m * 0.72, c2, px * 0.07, true)
	# Sigla
	var f := _font()
	var fs := int(px * 0.62)
	var txt := String(brand.get("short", "TV"))
	var base := Vector2(px * 1.05, size.y * 0.5 + fs * 0.36)
	draw_string(f, base, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c2)
