@tool
class_name FormDots
extends Control
## Sequência de resultados (V/E/D) em bolinhas coloridas, mais recente à direita.

@export var form: String = "VEDVV":
	set(v):
		form = v
		queue_redraw()
@export var dot: float = 22.0:
	set(v):
		dot = v
		_update_min()
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_min()


func _update_min() -> void:
	custom_minimum_size = Vector2(dot * 5 + 4 * 6, dot)


func _draw() -> void:
	var font := get_theme_font(&"font", &"Caps")
	var fs := int(dot * 0.6)
	for i in 5:
		var x := i * (dot + 6.0) + dot * 0.5
		var c := Vector2(x, size.y * 0.5)
		if i >= form.length():
			draw_circle(c, dot * 0.5, UIColors.SURFACE_3)
			continue
		var r := form[i]
		draw_circle(c, dot * 0.5, UIColors.result_color(r))
		var w := font.get_string_size(r, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, c + Vector2(-w * 0.5, fs * 0.36), r, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#0E1621"))
