class_name AttrRadar
extends Control
## Radar das médias por grupo de atributos (ataque, técnica, físico...), no estilo das fichas de
## jogador: grade em anéis de 20 em 20, área na cor da faixa do overall e o número em cada ponta.

## [[rótulo, valor 1..99], ...]
var axes: Array = []:
	set(v):
		axes = v
		queue_redraw()
var tint := Color(0, 0, 0, 0):
	set(v):
		tint = v
		queue_redraw()


static func make(values: Array, px: int, color: Color = Color(0, 0, 0, 0)) -> AttrRadar:
	var r := AttrRadar.new()
	r.axes = values
	r.tint = color
	r.custom_minimum_size = Vector2(0, px)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _point(i: int, rad: float) -> Vector2:
	var n := axes.size()
	var a := -PI * 0.5 + TAU * float(i) / float(n)
	return _center() + Vector2(cos(a), sin(a)) * rad


func _center() -> Vector2:
	return Vector2(size.x * 0.5, size.y * 0.53)


func _radius() -> float:
	return minf(size.x * 0.3, size.y * 0.36)


func _draw() -> void:
	var n := axes.size()
	if n < 3:
		return
	var rad := _radius()
	var grid := UIColors.LINE
	# Anéis 20/40/60/80/100 e raios
	for ring in range(1, 6):
		var pts := PackedVector2Array()
		for i in n + 1:
			pts.append(_point(i % n, rad * ring / 5.0))
		if ring == 5:
			draw_colored_polygon(pts, Color(UIColors.SURFACE_2, 0.6))
		draw_polyline(pts, Color(grid, 0.9 if ring == 5 else 0.55), 1.5 if ring == 5 else 1.0, true)
	for i in n:
		draw_line(_center(), _point(i, rad), Color(grid, 0.5), 1.0, true)
	# Área do jogador
	var total := 0.0
	var shape := PackedVector2Array()
	for i in n:
		var v := clampf(float(axes[i][1]), 0.0, 99.0)
		total += v
		shape.append(_point(i, rad * v / 100.0))
	var col := tint if tint.a > 0.0 else Fmt.rating_color(int(round(total / n)))
	draw_colored_polygon(shape, Color(col, 0.28))
	var closed := shape.duplicate()
	closed.append(shape[0])
	draw_polyline(closed, col, 2.5, true)
	for p in shape:
		draw_circle(p, 4.0, col)
	# Rótulos e valores nas pontas
	var font := get_theme_font(&"font", &"Label")
	var num_font := get_theme_font(&"font", &"Stat")
	var fs := clampi(int(size.x / 20.0), 14, 20)
	var nfs := fs + 6
	for i in n:
		var label := String(axes[i][0])
		var val := int(axes[i][1])
		var tip := _point(i, rad + fs * 1.9)
		var lw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var vw := num_font.get_string_size(str(val), HORIZONTAL_ALIGNMENT_LEFT, -1, nfs).x
		var total_h := fs + nfs
		var top := tip.y - total_h * 0.5
		draw_string(num_font, Vector2(tip.x - vw * 0.5, top + num_font.get_ascent(nfs)), str(val), HORIZONTAL_ALIGNMENT_LEFT, -1, nfs, Fmt.rating_color(val))
		draw_string(font, Vector2(tip.x - lw * 0.5, top + nfs + font.get_ascent(fs) - 2.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UIColors.MUTED)
