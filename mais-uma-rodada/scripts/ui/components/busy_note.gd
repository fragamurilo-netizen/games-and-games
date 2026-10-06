class_name BusyNote
extends VBoxContainer
## Aviso "processando" enquanto uma thread de trabalho mexe no mundo (fechar a rodada, fim de
## temporada, carregar): texto, barra de andamento e um anel girando para mostrar que não travou.

var text := ""
var _bar: ProgressBar
var _spin: Control
var _t := 0.0


func _ready() -> void:
	custom_minimum_size.x = 480
	add_theme_constant_override(&"separation", 16)
	_spin = Control.new()
	_spin.custom_minimum_size = Vector2(56, 56)
	_spin.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_spin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spin.draw.connect(_draw_spin)
	add_child(_spin)
	var l := UIKit.label(text, "H3", true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(l)
	_bar = UIKit.bar(0.0, 100.0, UIColors.ACCENT, 10)
	_bar.visible = false
	add_child(_bar)


func _process(delta: float) -> void:
	_t += delta
	_spin.queue_redraw()
	var p := SeasonManager.progress
	if p > 0:
		_bar.visible = true
		_bar.value = lerpf(_bar.value, float(p), minf(1.0, delta * 8.0))


func _draw_spin() -> void:
	var c := _spin.size * 0.5
	var r := minf(c.x, c.y) - 4.0
	_spin.draw_arc(c, r, 0.0, TAU, 48, Color(UIColors.TEXT, 0.12), 5.0, true)
	var a := fmod(_t * 5.0, TAU)
	_spin.draw_arc(c, r, a, a + 1.9, 24, UIColors.ACCENT, 5.0, true)
