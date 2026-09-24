@tool
class_name FlagView
extends Control
## Bandeira procedural a partir da especificação em nations.json (padrão, cores, emblema, cantão).
## Desenhada em proporção 3:2 dentro do retângulo disponível, com contorno fino para bandeiras claras.

@export var code: String = "BRA":
	set(v):
		code = v
		_spec = DatabaseManager.nation(v).get("flag", {}) if not Engine.is_editor_hint() else {}
		tooltip_text = DatabaseManager.nation_name(v) if not Engine.is_editor_hint() else v
		queue_redraw()

var _spec: Dictionary = {}


func set_nation(c: String) -> void:
	code = c


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 4.0 or h < 3.0:
		return
	# Retângulo 3:2 centralizado
	var fw := minf(w, h * 1.5)
	var fh := fw / 1.5
	var r := Rect2((w - fw) * 0.5, (h - fh) * 0.5, fw, fh)
	var spec := _spec
	var cols: Array = spec.get("c", ["#888888"])
	var p: String = spec.get("p", "solid")
	match p:
		"h":
			_bands(r, cols, spec.get("w", []), true)
		"v":
			_bands(r, cols, spec.get("w", []), false)
		"nordic":
			draw_rect(r, Color(cols[0]))
			var cx := r.position.x + r.size.x * 0.36
			var t := r.size.y * 0.2
			draw_rect(Rect2(cx - t * 0.5, r.position.y, t, r.size.y), Color(cols[1]))
			draw_rect(Rect2(r.position.x, r.position.y + (r.size.y - t) * 0.5, r.size.x, t), Color(cols[1]))
			if cols.size() > 2:
				var t2 := t * 0.5
				draw_rect(Rect2(cx - t2 * 0.5, r.position.y, t2, r.size.y), Color(cols[2]))
				draw_rect(Rect2(r.position.x, r.position.y + (r.size.y - t2) * 0.5, r.size.x, t2), Color(cols[2]))
		"cross":
			draw_rect(r, Color(cols[0]))
			var t := r.size.y * 0.2
			draw_rect(Rect2(r.position.x + (r.size.x - t) * 0.5, r.position.y, t, r.size.y), Color(cols[1]))
			draw_rect(Rect2(r.position.x, r.position.y + (r.size.y - t) * 0.5, r.size.x, t), Color(cols[1]))
		"saltire":
			if cols.size() >= 4:
				# Triângulos alternados (Jamaica)
				var c := r.get_center()
				draw_colored_polygon(PackedVector2Array([r.position, r.position + Vector2(r.size.x, 0), c]), Color(cols[2]))
				draw_colored_polygon(PackedVector2Array([r.position + Vector2(0, r.size.y), r.end, c]), Color(cols[2]))
				draw_colored_polygon(PackedVector2Array([r.position, r.position + Vector2(0, r.size.y), c]), Color(cols[3]))
				draw_colored_polygon(PackedVector2Array([r.position + Vector2(r.size.x, 0), r.end, c]), Color(cols[3]))
			else:
				draw_rect(r, Color(cols[0]))
			var lw := r.size.y * 0.16
			draw_line(r.position, r.end, Color(cols[1]), lw, true)
			draw_line(r.position + Vector2(0, r.size.y), r.position + Vector2(r.size.x, 0), Color(cols[1]), lw, true)
		"stripes":
			var n := int(spec.get("n", 9))
			for i in n:
				var y0 := r.position.y + r.size.y * i / n
				draw_rect(Rect2(r.position.x, y0, r.size.x, r.size.y / n + 0.5), Color(cols[i % 2]))
		"tri":
			_bands(r, cols, [], true)
			var tc := Color(spec.get("t", "#000000"))
			draw_colored_polygon(PackedVector2Array([r.position, r.position + Vector2(r.size.x * 0.5, r.size.y * 0.5), r.position + Vector2(0, r.size.y)]), tc)
		"diamond":
			draw_rect(r, Color(cols[0]))
			var c := r.get_center()
			var dx := r.size.x * 0.42
			var dy := r.size.y * 0.38
			draw_colored_polygon(PackedVector2Array([c + Vector2(-dx, 0), c + Vector2(0, -dy), c + Vector2(dx, 0), c + Vector2(0, dy)]), Color(cols[1]))
			draw_circle(c, r.size.y * 0.21, Color(cols[2]))
		"quarters":
			var hw := r.size.x * 0.5
			var hh := r.size.y * 0.5
			draw_rect(Rect2(r.position, Vector2(hw, hh)), Color(cols[0]))
			draw_rect(Rect2(r.position + Vector2(hw, 0), Vector2(hw, hh)), Color(cols[1]))
			draw_rect(Rect2(r.position + Vector2(0, hh), Vector2(hw, hh)), Color(cols[2]))
			draw_rect(Rect2(r.position + Vector2(hw, hh), Vector2(hw, hh)), Color(cols[3]))
		"pall":
			# Simplificação da bandeira sul-africana: faixas + "Y" verde + triângulo escuro.
			draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * 0.5)), Color(cols[0]))
			draw_rect(Rect2(r.position + Vector2(0, r.size.y * 0.5), Vector2(r.size.x, r.size.y * 0.5)), Color(cols[1]))
			var c := r.position + Vector2(r.size.x * 0.42, r.size.y * 0.5)
			var lw := r.size.y * 0.3
			draw_line(r.position, c, Color(cols[3]), lw * 1.35, true)
			draw_line(r.position + Vector2(0, r.size.y), c, Color(cols[3]), lw * 1.35, true)
			draw_rect(Rect2(c - Vector2(0, lw * 0.67), Vector2(r.end.x - c.x, lw * 1.35)), Color(cols[3]))
			draw_line(r.position, c, Color(cols[2]), lw, true)
			draw_line(r.position + Vector2(0, r.size.y), c, Color(cols[2]), lw, true)
			draw_rect(Rect2(c - Vector2(0, lw * 0.5), Vector2(r.end.x - c.x, lw)), Color(cols[2]))
			draw_colored_polygon(PackedVector2Array([r.position + Vector2(0, r.size.y * 0.18), c - Vector2(r.size.x * 0.12, 0), r.position + Vector2(0, r.size.y * 0.82)]), Color(cols[4]))
			draw_colored_polygon(PackedVector2Array([r.position + Vector2(0, r.size.y * 0.26), c - Vector2(r.size.x * 0.2, 0), r.position + Vector2(0, r.size.y * 0.74)]), Color(cols[5]))
		"serrated":
			draw_rect(r, Color(cols[1]))
			var x0 := r.position.x + r.size.x * 0.3
			var pts := PackedVector2Array([r.position, Vector2(x0, r.position.y)])
			var teeth := 9
			for i in teeth:
				var y := r.position.y + r.size.y * (i + 0.5) / teeth
				pts.append(Vector2(x0 + r.size.x * 0.08, y))
				pts.append(Vector2(x0, r.position.y + r.size.y * (i + 1) / teeth))
			pts.append(r.position + Vector2(0, r.size.y))
			draw_colored_polygon(pts, Color(cols[0]))
		"vband":
			var bw := r.size.x * 0.28
			var rest := Rect2(r.position + Vector2(bw, 0), Vector2(r.size.x - bw, r.size.y))
			_bands(rest, cols.slice(1), [], true)
			draw_rect(Rect2(r.position, Vector2(bw, r.size.y)), Color(cols[0]))
		"diag":
			draw_rect(r, Color(cols[0]))
			var lw := r.size.y * 0.3
			draw_line(r.position + Vector2(0, r.size.y), r.position + Vector2(r.size.x, 0), Color(cols[1]), lw, true)
			draw_line(r.position + Vector2(0, r.size.y), r.position + Vector2(r.size.x, 0), Color(cols[2]), lw * 0.6, true)
		_:
			draw_rect(r, Color(cols[0]))
	if spec.has("k"):
		var k: Dictionary = spec["k"]
		var kr := Rect2(r.position, Vector2(r.size.x * float(k.get("w", 0.4)), r.size.y * float(k.get("h", 0.5))))
		draw_rect(kr, Color(k.get("c", "#000000")))
		if k.has("e"):
			_emblem(kr, k["e"])
	if spec.has("e"):
		_emblem(r, spec["e"])
	draw_rect(r, Color(0, 0, 0, 0.35), false, 1.0)


func _bands(r: Rect2, cols: Array, weights: Array, horizontal: bool) -> void:
	var n := cols.size()
	var total := 0.0
	for i in n:
		total += float(weights[i]) if i < weights.size() else 1.0
	var acc := 0.0
	for i in n:
		var wv := float(weights[i]) if i < weights.size() else 1.0
		var a := acc / total
		acc += wv
		var b := acc / total
		var rr: Rect2
		if horizontal:
			rr = Rect2(r.position.x, r.position.y + r.size.y * a, r.size.x, r.size.y * (b - a) + 0.5)
		else:
			rr = Rect2(r.position.x + r.size.x * a, r.position.y, r.size.x * (b - a) + 0.5, r.size.y)
		draw_rect(rr, Color(cols[i]))


## Emblema dentro de `r`: e = {t, c, c2?, x, y, s} (x, y relativos; s relativo à altura).
func _emblem(r: Rect2, e: Dictionary) -> void:
	var c := Color(e.get("c", "#FFFFFF"))
	var c2 := Color(e.get("c2", "#000000"))
	var center := r.position + Vector2(r.size.x * float(e.get("x", 0.5)), r.size.y * float(e.get("y", 0.5)))
	var rad := r.size.y * float(e.get("s", 0.3)) * 0.5
	match String(e.get("t", "disc")):
		"disc":
			draw_circle(center, rad, c)
			if e.has("c2"):
				draw_circle(center, rad * 0.62, c2)
		"star":
			draw_colored_polygon(_star(center, rad, 5), c)
		"star_o":
			var pts := _star(center, rad, 5)
			pts.append(pts[0])
			draw_polyline(pts, c, maxf(1.0, rad * 0.18), true)
		"crescent":
			var bg := _color_at(r, center + Vector2(rad * 1.2, 0))
			draw_circle(center, rad, c)
			draw_circle(center + Vector2(rad * 0.3, 0), rad * 0.8, bg)
			draw_colored_polygon(_star(center + Vector2(rad * 1.15, 0), rad * 0.35, 5), c)
		"sun":
			for i in 12:
				var a := TAU * i / 12.0
				draw_line(center, center + Vector2(cos(a), sin(a)) * rad * 1.35, c, maxf(1.0, rad * 0.14), true)
			draw_circle(center, rad * 0.75, c)
		"leaf":
			draw_colored_polygon(_star(center, rad, 7), c)
		"cross_sq":
			var t := rad * 0.45
			draw_rect(Rect2(center.x - t * 0.5, center.y - rad, t, rad * 2.0), c)
			draw_rect(Rect2(center.x - rad, center.y - t * 0.5, rad * 2.0, t), c)
		"checker":
			var cell := rad * 2.0 / 3.0
			for i in 3:
				for j in 3:
					draw_rect(Rect2(center - Vector2(rad, rad) + Vector2(i * cell, j * cell), Vector2(cell, cell)), c if (i + j) % 2 == 0 else c2)
		"taeguk":
			draw_circle(center, rad, c2)
			draw_arc(center, rad * 0.5, PI, TAU, 16, c, rad, true)
			draw_circle(center + Vector2(-rad * 0.5, 0), rad * 0.5, c)
			draw_circle(center + Vector2(rad * 0.5, 0), rad * 0.5, c2)
		"stars_arc":
			for i in 8:
				var a := PI + PI * (i + 0.5) / 8.0
				draw_colored_polygon(_star(center + Vector2(cos(a), sin(a) * 0.6) * rad * 1.6, rad * 0.22, 5), c)
		"stars_grid":
			for i in 5:
				for j in 4:
					draw_circle(r.position + Vector2(r.size.x * (i + 0.5) / 5.0, r.size.y * (j + 0.5) / 4.0), maxf(0.6, rad * 0.12), c)
		"stars_ring":
			for i in 10:
				var a := TAU * i / 10.0
				draw_circle(center + Vector2(cos(a), sin(a)) * rad, maxf(0.6, rad * 0.14), c)
		"stars_diag":
			for i in 6:
				var t2 := (i + 0.5) / 6.0
				draw_circle(r.position + Vector2(r.size.x * (0.2 + t2 * 0.55), r.size.y * t2), maxf(0.6, r.size.y * 0.035), c)
		"stars_chn":
			var k := r.position + Vector2(r.size.x * 0.17, r.size.y * 0.27)
			draw_colored_polygon(_star(k, r.size.y * 0.13, 5), c)
			for off in [Vector2(0.33, 0.1), Vector2(0.4, 0.2), Vector2(0.4, 0.35), Vector2(0.33, 0.45)]:
				draw_colored_polygon(_star(r.position + Vector2(r.size.x * off.x, r.size.y * off.y), r.size.y * 0.045, 5), c)
		"stars_aus", "stars_nzl":
			for off in [Vector2(0.0, -0.8), Vector2(0.55, -0.2), Vector2(-0.45, 0.1), Vector2(0.05, 0.85)]:
				draw_colored_polygon(_star(center + off * rad, rad * 0.22, 5), c)
		"union":
			var lw := r.size.y * 0.12
			draw_line(r.position, r.end, c, lw, true)
			draw_line(r.position + Vector2(0, r.size.y), r.position + Vector2(r.size.x, 0), c, lw, true)
			draw_rect(Rect2(r.position.x, r.get_center().y - lw * 0.8, r.size.x, lw * 1.6), c)
			draw_rect(Rect2(r.get_center().x - lw * 0.8, r.position.y, lw * 1.6, r.size.y), c)
			draw_rect(Rect2(r.position.x, r.get_center().y - lw * 0.45, r.size.x, lw * 0.9), c2)
			draw_rect(Rect2(r.get_center().x - lw * 0.45, r.position.y, lw * 0.9, r.size.y), c2)
		"script":
			draw_rect(Rect2(center.x - rad * 1.4, center.y - rad * 0.25, rad * 2.8, rad * 0.18), c)
			draw_rect(Rect2(center.x - rad * 1.1, center.y + rad * 0.3, rad * 2.2, rad * 0.12), c)
		_:
			# Brasões (águia, escudo, dragão, mapa, engrenagem): silhueta simples.
			var pts := PackedVector2Array([center + Vector2(-rad * 0.8, -rad), center + Vector2(rad * 0.8, -rad),
				center + Vector2(rad * 0.8, rad * 0.2), center + Vector2(0, rad), center + Vector2(-rad * 0.8, rad * 0.2)])
			draw_colored_polygon(pts, c)
			if e.has("c2"):
				draw_circle(center, rad * 0.35, c2)


func _star(c: Vector2, r: float, points: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in points * 2:
		var a := -PI / 2.0 + PI * i / points
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	return pts


## Cor de fundo aproximada num ponto (para "recortar" o crescente).
func _color_at(_r: Rect2, _p: Vector2) -> Color:
	var cols: Array = _spec.get("c", ["#888888"])
	if _spec.get("p", "") == "v" and cols.size() >= 2:
		return Color(cols[1])
	return Color(cols[0])
