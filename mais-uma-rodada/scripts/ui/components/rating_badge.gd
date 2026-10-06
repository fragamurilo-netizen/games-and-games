@tool
class_name RatingBadge
extends Control
## Overall (ou qualquer número curto) na cor da faixa de qualidade.

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


## Sem selo: o número (ou a etiqueta) na cor da faixa, alinhado como numa tabela. Um
## ladrilho colorido em cada linha virava ruído; a cor sozinha já diz a faixa.
func _draw() -> void:
	var txt := text_override if text_override != "" else str(value)
	var bgs := [UIColors.BG, UIColors.SURFACE, UIColors.SURFACE_2]
	var fg: Color
	var fs := font_size
	var font := get_theme_font(&"font", &"StatBig")
	if color_override.a > 0.0:
		fg = UIColors.readable_on(Color(color_override, 1.0), bgs, 4.5)
		font = get_theme_font(&"font", &"Caps")
		fs = int(font_size * 0.9)
	else:
		fg = UIColors.readable_on(Fmt._rating_color(value), bgs, 3.0)
	var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var asc := font.get_ascent(fs)
	var desc := font.get_descent(fs)
	draw_string(font, Vector2((size.x - w) * 0.5, (size.y + asc - desc) * 0.5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, fg)
