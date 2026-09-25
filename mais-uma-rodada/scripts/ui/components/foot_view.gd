@tool
class_name FootView
extends Control
## Os dois pés vistos de cima (esquerdo e direito): o preferido aceso, o outro apagado.
## Ambidestro acende os dois. Substitui o texto "pé direito/esquerdo".

@export var foot: int = 0:
	set(v):
		foot = v
		tooltip_text = ["Pé direito", "Pé esquerdo", "Ambidestro"][clampi(v, 0, 2)]
		queue_redraw()
@export var on_color: Color = Color("#FFC940")
@export var off_color: Color = Color(1, 1, 1, 0.16)

## Sola (pé direito, de cima), coordenadas 0..1 numa caixa 0.42 × 1; o esquerdo é espelhado.
const SOLE := [Vector2(0.52, 0.30), Vector2(0.62, 0.40), Vector2(0.66, 0.55), Vector2(0.64, 0.72), Vector2(0.58, 0.9),
	Vector2(0.47, 0.98), Vector2(0.36, 0.95), Vector2(0.30, 0.82), Vector2(0.31, 0.64), Vector2(0.27, 0.48),
	Vector2(0.28, 0.35), Vector2(0.36, 0.28)]
## Dedos: [centro, raio] do dedão ao mindinho.
const TOES := [[Vector2(0.33, 0.2), 0.085], [Vector2(0.44, 0.15), 0.06], [Vector2(0.53, 0.17), 0.052], [Vector2(0.6, 0.21), 0.046], [Vector2(0.65, 0.27), 0.04]]


static func make(foot_v: int, px: int) -> FootView:
	var f := FootView.new()
	f.custom_minimum_size = Vector2(px * 1.1, px)
	f.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	f.mouse_filter = Control.MOUSE_FILTER_PASS
	f.foot = foot_v
	return f


func _draw() -> void:
	var h := minf(size.y, size.x / 1.1)
	var w := h * 0.55
	var ox := (size.x - w * 2.0) * 0.5
	var oy := (size.y - h) * 0.5
	# Esquerdo à esquerda (dedão para dentro), direito à direita
	_foot(Vector2(ox, oy), w, h, true, foot == Player.FOOT_LEFT or foot == Player.FOOT_BOTH)
	_foot(Vector2(ox + w, oy), w, h, false, foot == Player.FOOT_RIGHT or foot == Player.FOOT_BOTH)


func _foot(o: Vector2, w: float, h: float, left: bool, lit: bool) -> void:
	var col := on_color if lit else off_color
	var pts := PackedVector2Array()
	for p in SOLE:
		pts.append(_pt(o, w, h, p, left))
	draw_colored_polygon(pts, col)
	for t in TOES:
		draw_circle(_pt(o, w, h, t[0], left), float(t[1]) * h, col)


## O desenho-base é o pé direito (dedão à esquerda); o esquerdo é o espelho.
func _pt(o: Vector2, w: float, h: float, p: Vector2, left: bool) -> Vector2:
	var x := p.x if not left else 1.0 - p.x
	return o + Vector2((x - 0.15) / 0.7 * w, p.y * h)
