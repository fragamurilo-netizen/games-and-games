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
	var r := Rect2(Vector2.ZERO, size)
	var box := StyleBoxFlat.new()
	box.anti_aliasing = true
	var txt := text_override if text_override != "" else str(value)
	var fg: Color
	if color_override.a > 0.0:
		# Etiqueta (posição, zona): fundo tingido, sem borda, texto na cor.
		var col := UIColors.ink(color_override)
		box.bg_color = Color(col.r, col.g, col.b, 0.2 if not UIColors.light else 0.14)
		box.set_corner_radius_all(int(minf(size.y * 0.22, 7)))
		fg = col
	else:
		# Overall: ladrilho cheio na cor da faixa, como nas cartas dos jogos de futebol.
		var col := Fmt._rating_color(value)
		box.bg_color = col
		box.border_color = col.darkened(0.3)
		box.border_width_bottom = 3
		box.set_corner_radius_all(int(minf(size.y * 0.22, 8)))
		fg = Color("#0B0E12") if col.get_luminance() > 0.45 else Color.WHITE
	draw_style_box(box, r)
	var font := get_theme_font(&"font", &"StatBig")
	var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var asc := font.get_ascent(font_size)
	var desc := font.get_descent(font_size)
	var dy := -1.5 if color_override.a <= 0.0 else 0.0
	draw_string(font, Vector2((size.x - w) * 0.5, (size.y + asc - desc) * 0.5 + dy), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, fg)
