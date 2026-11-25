@tool
class_name HeatBar
extends Control
## Termômetro de hype: cinco faixas (frio, morno, aquecendo, quente, pegando fogo) preenchidas
## até o valor, com um marcador em cima. A cor é a da faixa em que o valor está.

## Onde cada faixa termina (as mesmas de `Hype.LEVELS`).
const BOUNDS := [0.0, 35.0, 52.0, 70.0, 85.0, 100.0]

var value: float = 0.0:
	set(v):
		value = clampf(v, 0.0, 100.0)
		queue_redraw()
var bar_h: float = 14.0:
	set(v):
		bar_h = v
		custom_minimum_size = Vector2(0, bar_h + 14.0)
		queue_redraw()
var marker: bool = true


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, bar_h + 14.0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _draw() -> void:
	var w := size.x
	var y := size.y - bar_h
	var gap := 4.0
	var col := EventKit.tone_color(value)
	var back := StyleBoxFlat.new()
	back.bg_color = UIColors.SURFACE_3
	var fill := StyleBoxFlat.new()
	fill.bg_color = col
	for i in 5:
		var x0 := w * float(BOUNDS[i]) / 100.0 + (gap * 0.5 if i > 0 else 0.0)
		var x1 := w * float(BOUNDS[i + 1]) / 100.0 - (gap * 0.5 if i < 4 else 0.0)
		draw_style_box(back, Rect2(x0, y, x1 - x0, bar_h))
		var to := clampf(w * value / 100.0, x0, x1)
		if to - x0 >= 2.0:
			draw_style_box(fill, Rect2(x0, y, to - x0, bar_h))
	if marker:
		var mx := clampf(w * value / 100.0, 7.0, w - 7.0)
		draw_colored_polygon(PackedVector2Array([Vector2(mx - 7.0, y - 12.0), Vector2(mx + 7.0, y - 12.0), Vector2(mx, y - 2.0)]), UIColors.TEXT)
