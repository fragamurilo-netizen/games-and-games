class_name ModalLayout
extends Node
## Ajusta apenas um modal vivo; conexões por método se desfazem quando este nó é liberado.
## Reserva cabeçalho externo, alça, área segura e bordas antes de dimensionar a rolagem.
var holder: MarginContainer
var panel: PanelContainer
var body: ScrollContainer
var content: Control
var main: Control
var sheet := false
var _queued := false
var _wanted_height := 0.0
var _wanted_width := 0.0

func _ready() -> void:
	_wanted_height = content.custom_minimum_size.y
	_wanted_width = content.custom_minimum_size.x
	get_viewport().size_changed.connect(_queue_refit)
	content.minimum_size_changed.connect(_queue_refit)
	panel.theme_changed.connect(_queue_refit)
	_queue_refit()

func _queue_refit() -> void:
	if _queued or not is_inside_tree() or is_queued_for_deletion():
		return
	_queued = true
	_refit.call_deferred()

func _refit() -> void:
	_queued = false
	if not is_inside_tree() or not is_instance_valid(content) or not is_instance_valid(panel) or not is_instance_valid(main):
		return
	var vp := get_viewport().get_visible_rect().size
	var safe: Rect2 = main.safe_margins()
	var gap := 18.0 if vp.y < 900.0 else 32.0
	var cap := 820.0 if sheet else 680.0
	var side := maxf(0.0 if sheet else 16.0, (vp.x-cap)*0.5)
	holder.add_theme_constant_override("margin_left", int(maxf(side,safe.position.x)))
	holder.add_theme_constant_override("margin_right", int(maxf(side,safe.size.x)))
	holder.add_theme_constant_override("margin_top", int(safe.position.y+gap))
	holder.add_theme_constant_override("margin_bottom", 0 if sheet else int(safe.size.y+gap))
	var style := panel.get_theme_stylebox("panel")
	var border := style.get_minimum_size() if style != null else Vector2.ZERO
	var reserved := safe.position.y+safe.size.y+gap+(20.0 if sheet else gap)+border.y
	var max_h := maxf(0.0, vp.y-reserved)
	var width := maxf(1.0,vp.x-maxf(side,safe.position.x)-maxf(side,safe.size.x)-border.x)
	if content != body:
		content.custom_minimum_size.x = minf(_wanted_width,width)
		if content.get_combined_minimum_size().x > width+1.0:
			UIKit.fit_width(content,width)
	var desired := _wanted_height if content == body and _wanted_height > 0.0 else max_h
	if content != body:
		desired = content.get_combined_minimum_size().y
	var height := minf(max_h, maxf(0.0,desired))
	if not is_equal_approx(body.custom_minimum_size.y,height):
		body.custom_minimum_size.y=height
