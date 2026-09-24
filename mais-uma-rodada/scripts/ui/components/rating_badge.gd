@tool
class_name RatingBadge
extends Control
## Selo colorido com o overall (ou qualquer número curto). Cor pela faixa de qualidade.

@export var value: int = 70:
	set(v):
		value = v
		queue_redraw()
@export var text_override: String = "":
	set(v):
		text_override = v
		queue_redraw()
@export var color_override: Color = Color(0, 0, 0, 0):
	set(v):
		color_override = v
		queue_redraw()
@export var font_size: int = 26:
	set(v):
		font_size = v
		queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(56, 40)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var col := color_override if color_override.a > 0.0 else Fmt.rating_color(value)
	var r := Rect2(Vector2.ZERO, size)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(col.r, col.g, col.b, 0.16)
	box.border_color = col
	box.set_border_width_all(2)
	box.set_corner_radius_all(int(minf(size.y * 0.3, 12)))
	draw_style_box(box, r)
	var font := get_theme_font(&"font", &"Stat")
	var txt := text_override if text_override != "" else str(value)
	var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var asc := font.get_ascent(font_size)
	var desc := font.get_descent(font_size)
	draw_string(font, Vector2((size.x - w) * 0.5, (size.y + asc - desc) * 0.5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)
