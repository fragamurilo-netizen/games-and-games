@tool
class_name Sparkline
extends Control
## Linha de tendência sem eixos: os últimos valores de uma medida (caixa, reputação). O último
## ponto leva uma bolinha; a área embaixo é um degradê fraco da mesma cor. Com `zero` ligado, uma
## linha fina marca o zero quando a série cruza para o negativo.

var values: Array = []:
	set(v):
		values = v
		queue_redraw()
var color: Color = UIColors.TEXT:
	set(v):
		color = v
		queue_redraw()
var zero := true
## 0 a 1: quanto da linha já foi desenhada (para a animação de entrada).
var reveal := 1.0:
	set(v):
		reveal = clampf(v, 0.0, 1.0)
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(80, 40)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _draw() -> void:
	var n := values.size()
	if n < 2:
		return
	var lo := float(values[0])
	var hi := lo
	for v in values:
		lo = minf(lo, float(v))
		hi = maxf(hi, float(v))
	if is_equal_approx(lo, hi):
		hi = lo + 1.0
		lo -= 1.0
	var pad := 5.0
	var w := size.x - pad * 2.0
	var h := size.y - pad * 2.0
	var pts := PackedVector2Array()
	for i in n:
		var t := float(i) / float(n - 1)
		pts.append(Vector2(pad + w * t, pad + h * (1.0 - (float(values[i]) - lo) / (hi - lo))))
	if zero and lo < 0.0 and hi > 0.0:
		var zy := pad + h * (1.0 - (0.0 - lo) / (hi - lo))
		draw_line(Vector2(pad, zy), Vector2(size.x - pad, zy), Color(UIColors.MUTED, 0.35), 1.0)
	# Só o trecho já revelado.
	var upto := 1.0 + reveal * float(n - 1)
	var shown := PackedVector2Array()
	for i in n:
		if float(i) + 1.0 <= upto:
			shown.append(pts[i])
		else:
			var k := upto - float(i)
			if k > 0.0 and i > 0:
				shown.append(pts[i - 1].lerp(pts[i], k))
			break
	if shown.size() < 2:
		return
	var poly := PackedVector2Array(shown)
	poly.append(Vector2(shown[shown.size() - 1].x, size.y))
	poly.append(Vector2(shown[0].x, size.y))
	var cols := PackedColorArray()
	for p in shown:
		cols.append(Color(color, 0.18 * (1.0 - (p.y - pad) / maxf(1.0, h)) + 0.04))
	cols.append(Color(color, 0.0))
	cols.append(Color(color, 0.0))
	if Geometry2D.triangulate_polygon(poly).size() >= 3:
		draw_polygon(poly, cols)
	draw_polyline(shown, color, 2.0, true)
	var last := shown[shown.size() - 1]
	draw_circle(last, 4.5, UIColors.SURFACE)
	draw_circle(last, 3.0, color)
