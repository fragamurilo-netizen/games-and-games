@tool
class_name SupportBar
extends Control
## Termômetro do apoio da cidade (academia) ou da confiança dos sócios (presidente): quatro
## faixas separadas nos limites que mudam alguma coisa (crise, sem benefício, benefício),
## preenchidas até o valor na cor da faixa atual, com um marcador em cima. `need` desenha a
## marca do ultimato.

const BOUNDS := [0.0, 20.0, 40.0, 75.0, 100.0]

var value: float = 50.0:
	set(v):
		value = clampf(v, 0.0, 100.0)
		queue_redraw()
var bar_h: float = 12.0:
	set(v):
		bar_h = v
		custom_minimum_size = Vector2(0, bar_h + (14.0 if marker else 0.0))
		queue_redraw()
var marker: bool = true:
	set(v):
		marker = v
		custom_minimum_size = Vector2(0, bar_h + (14.0 if marker else 0.0))
		queue_redraw()
var need: float = -1.0:
	set(v):
		need = v
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, bar_h + 14.0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


static func tone(v: float) -> Color:
	if v < 20.0:
		return UIColors.RED
	if v < 40.0:
		return UIColors.ORANGE
	if v < 75.0:
		return UIColors.BLUE
	return UIColors.GREEN


func _draw() -> void:
	var w := size.x
	var y := size.y - bar_h
	var gap := 4.0
	var back := StyleBoxFlat.new()
	back.bg_color = UIColors.SURFACE_3
	var fill := StyleBoxFlat.new()
	fill.bg_color = tone(value)
	for i in 4:
		var x0 := w * float(BOUNDS[i]) / 100.0 + (gap * 0.5 if i > 0 else 0.0)
		var x1 := w * float(BOUNDS[i + 1]) / 100.0 - (gap * 0.5 if i < 3 else 0.0)
		draw_style_box(back, Rect2(x0, y, x1 - x0, bar_h))
		var to := clampf(w * value / 100.0, x0, x1)
		if to - x0 >= 2.0:
			draw_style_box(fill, Rect2(x0, y, to - x0, bar_h))
	if need >= 0.0:
		var nx := w * need / 100.0
		draw_rect(Rect2(nx - 1.5, y - 4.0, 3.0, bar_h + 4.0), UIColors.TEXT)
	if marker:
		var mx := clampf(w * value / 100.0, 7.0, w - 7.0)
		draw_colored_polygon(PackedVector2Array([Vector2(mx - 7.0, y - 12.0), Vector2(mx + 7.0, y - 12.0), Vector2(mx, y - 2.0)]), UIColors.TEXT)
