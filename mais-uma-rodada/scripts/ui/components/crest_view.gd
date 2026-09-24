@tool
class_name CrestView
extends Control
## Escudo procedural: formato + cores + símbolo + borda (+ listras opcionais).

@export var crest: Dictionary = {"shape": "shield", "symbol": "star", "c1": "#1B3A8C", "c2": "#FFFFFF", "border": "thin", "initials": "RA"}:
	set(v):
		crest = v
		queue_redraw()


func set_club(c: Club) -> void:
	if c == null:
		return
	crest = c.crest
	tooltip_text = c.name


func _draw() -> void:
	var s := minf(size.x, size.y)
	if s <= 2.0:
		return
	var off := Vector2((size.x - s) * 0.5, (size.y - s) * 0.5)
	var c1 := Color(crest.get("c1", "#1B3A8C"))
	var c2 := Color(crest.get("c2", "#FFFFFF"))
	var shape := unit_shape(crest.get("shape", "shield"))
	var poly := _xf(shape, s, off)
	# Sombra suave
	var shadow := PackedVector2Array()
	for p in poly:
		shadow.append(p + Vector2(0, s * 0.03))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.25))
	draw_colored_polygon(poly, c1)
	if crest.get("stripes", false):
		for i in 3:
			var x0 := 0.2 + i * 0.24
			var band := _xf(PackedVector2Array([Vector2(x0, 0), Vector2(x0 + 0.1, 0), Vector2(x0 + 0.1, 1), Vector2(x0, 1)]), s, off)
			for piece in Geometry2D.intersect_polygons(band, poly):
				draw_colored_polygon(piece, c2.lerp(c1, 0.25))
	_draw_symbol(crest.get("symbol", "star"), s, off, c2, c1)
	var border: String = crest.get("border", "thin")
	var closed := poly.duplicate()
	closed.append(poly[0])
	match border:
		"thin":
			draw_polyline(closed, c2, maxf(1.0, s * 0.03), true)
		"thick":
			draw_polyline(closed, c2, maxf(2.0, s * 0.065), true)
		"double":
			draw_polyline(closed, c2, maxf(1.0, s * 0.03), true)
			var inner := _xf(_shrink(shape, 0.1), s, off)
			inner.append(inner[0])
			draw_polyline(inner, c2, maxf(1.0, s * 0.02), true)


static func unit_shape(shape: String) -> PackedVector2Array:
	var pts := PackedVector2Array()
	match shape:
		"round":
			for i in 48:
				var a := TAU * i / 48.0
				pts.append(Vector2(0.5 + cos(a) * 0.47, 0.5 + sin(a) * 0.47))
		"oval":
			for i in 48:
				var a := TAU * i / 48.0
				pts.append(Vector2(0.5 + cos(a) * 0.38, 0.5 + sin(a) * 0.48))
		"pennant":
			pts = PackedVector2Array([Vector2(0.06, 0.06), Vector2(0.94, 0.06), Vector2(0.94, 0.2), Vector2(0.5, 0.97), Vector2(0.06, 0.2)])
		"modern":
			pts = PackedVector2Array([Vector2(0.5, 0.02), Vector2(0.93, 0.26), Vector2(0.93, 0.74), Vector2(0.5, 0.98), Vector2(0.07, 0.74), Vector2(0.07, 0.26)])
		"square":
			var r := 0.14
			for corner in [Vector2(0.9 - r, 0.1 + r), Vector2(0.9 - r, 0.9 - r), Vector2(0.1 + r, 0.9 - r), Vector2(0.1 + r, 0.1 + r)]:
				var start := 0.0
				if corner.x > 0.5 and corner.y < 0.5:
					start = -PI / 2
				elif corner.x > 0.5:
					start = 0.0
				elif corner.y > 0.5:
					start = PI / 2
				else:
					start = PI
				for k in 7:
					var a: float = start + (PI / 2) * k / 6.0
					pts.append(corner + Vector2(cos(a), sin(a)) * r)
		_:
			# Escudo tradicional: topo reto com ombros e ponta arredondada.
			pts.append(Vector2(0.08, 0.05))
			pts.append(Vector2(0.5, 0.1))
			pts.append(Vector2(0.92, 0.05))
			for i in 13:
				var t := i / 12.0
				var p := _bezier(Vector2(0.92, 0.05), Vector2(0.95, 0.72), Vector2(0.5, 0.98), t)
				pts.append(p)
			for i in range(1, 12):
				var t := i / 12.0
				var p := _bezier(Vector2(0.5, 0.98), Vector2(0.05, 0.72), Vector2(0.08, 0.05), t)
				pts.append(p)
	return pts


static func _bezier(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
	return a.lerp(b, t).lerp(b.lerp(c, t), t)


static func _shrink(pts: PackedVector2Array, amount: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(Vector2(0.5, 0.5) + (p - Vector2(0.5, 0.5)) * (1.0 - amount))
	return out


static func _xf(pts: PackedVector2Array, s: float, off: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(off + p * s)
	return out


func _draw_symbol(sym: String, s: float, off: Vector2, col: Color, bg: Color) -> void:
	var c := off + Vector2(0.5, 0.48) * s
	var r := s * 0.22
	match sym:
		"star":
			draw_colored_polygon(_star(c, r, r * 0.45, 5), col)
		"ball":
			draw_circle(c, r, col)
			draw_colored_polygon(_ngon(c, r * 0.42, 5, -PI / 2), bg)
		"crown":
			var pts := PackedVector2Array([c + Vector2(-r, r * 0.6), c + Vector2(-r, -r * 0.4), c + Vector2(-r * 0.5, 0), c + Vector2(0, -r * 0.8),
				c + Vector2(r * 0.5, 0), c + Vector2(r, -r * 0.4), c + Vector2(r, r * 0.6)])
			draw_colored_polygon(pts, col)
		"bolt":
			var pts2 := PackedVector2Array([c + Vector2(r * 0.2, -r), c + Vector2(-r * 0.6, r * 0.15), c + Vector2(-r * 0.05, r * 0.15),
				c + Vector2(-r * 0.25, r), c + Vector2(r * 0.6, -r * 0.2), c + Vector2(r * 0.05, -r * 0.2)])
			draw_colored_polygon(pts2, col)
		"wave":
			for k in 3:
				var pts3 := PackedVector2Array()
				for i in 17:
					var t := i / 16.0
					pts3.append(c + Vector2((t - 0.5) * 2.0 * r, (k - 1) * r * 0.55 + sin(t * TAU) * r * 0.18))
				draw_polyline(pts3, col, maxf(1.5, s * 0.045), true)
		"sun":
			draw_circle(c, r * 0.5, col)
			for i in 10:
				var a := TAU * i / 10.0
				draw_line(c + Vector2(cos(a), sin(a)) * r * 0.65, c + Vector2(cos(a), sin(a)) * r, col, maxf(1.5, s * 0.035), true)
		"mountain":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r, r * 0.7), c + Vector2(-r * 0.2, -r * 0.7), c + Vector2(r * 0.25, 0), c + Vector2(r * 0.5, -r * 0.35), c + Vector2(r, r * 0.7)]), col)
		"tower":
			var pts4 := PackedVector2Array([c + Vector2(-r * 0.55, r * 0.8), c + Vector2(-r * 0.45, -r * 0.4), c + Vector2(-r * 0.7, -r * 0.4), c + Vector2(-r * 0.7, -r * 0.85),
				c + Vector2(-r * 0.35, -r * 0.85), c + Vector2(-r * 0.35, -r * 0.6), c + Vector2(-r * 0.12, -r * 0.6), c + Vector2(-r * 0.12, -r * 0.85),
				c + Vector2(r * 0.12, -r * 0.85), c + Vector2(r * 0.12, -r * 0.6), c + Vector2(r * 0.35, -r * 0.6), c + Vector2(r * 0.35, -r * 0.85),
				c + Vector2(r * 0.7, -r * 0.85), c + Vector2(r * 0.7, -r * 0.4), c + Vector2(r * 0.45, -r * 0.4), c + Vector2(r * 0.55, r * 0.8)])
			draw_colored_polygon(pts4, col)
		"letter":
			var font := get_theme_font(&"font", &"Big")
			var txt: String = crest.get("initials", "FC")
			var fs := int(s * (0.36 if txt.length() <= 2 else 0.28))
			var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
			draw_string(font, c + Vector2(-w * 0.5, fs * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		"chevron":
			for k in 2:
				var y := c.y - r * 0.35 + k * r * 0.6
				draw_polyline(PackedVector2Array([Vector2(c.x - r, y - r * 0.4), Vector2(c.x, y + r * 0.2), Vector2(c.x + r, y - r * 0.4)]), col, maxf(2.0, s * 0.06), true)
		"cross":
			draw_rect(Rect2(c.x - r * 0.22, c.y - r, r * 0.44, r * 2.0), col)
			draw_rect(Rect2(c.x - r, c.y - r * 0.22, r * 2.0, r * 0.44), col)
		"diamond":
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.75, 0), c + Vector2(0, r), c + Vector2(-r * 0.75, 0)]), col)
		"gear":
			draw_colored_polygon(_star(c, r, r * 0.75, 8), col)
			draw_circle(c, r * 0.32, bg)
		"anchor":
			var w2 := maxf(1.5, s * 0.045)
			draw_line(c + Vector2(0, -r * 0.8), c + Vector2(0, r * 0.8), col, w2, true)
			draw_line(c + Vector2(-r * 0.45, -r * 0.45), c + Vector2(r * 0.45, -r * 0.45), col, w2, true)
			draw_arc(c + Vector2(0, r * 0.1), r * 0.75, 0.2, PI - 0.2, 16, col, w2, true)
			draw_circle(c + Vector2(0, -r * 0.95), r * 0.16, col)
		_:
			draw_circle(c, r * 0.6, col)


static func _star(c: Vector2, r1: float, r2: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n * 2:
		var a := -PI / 2 + PI * i / n
		var r := r1 if i % 2 == 0 else r2
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


static func _ngon(c: Vector2, r: float, n: int, rot: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := rot + TAU * i / n
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts
