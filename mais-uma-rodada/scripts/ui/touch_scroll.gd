class_name TouchScroll
extends Node
## Rolagem por arrasto em qualquer ScrollContainer, com inércia.
##
## O ScrollContainer do Godot só rola quando o arrasto começa numa área "vazia": como quase
## toda linha do jogo é um botão (tap_row, chips, cards clicáveis), no celular a tela
## praticamente não descia. Aqui o arrasto é tratado antes da GUI: passou do limiar, o toque
## vira rolagem, o botão sob o dedo é cancelado (não dispara) e, ao soltar, a lista segue
## deslizando e desacelera. Também funciona com o mouse no PC (clicar e arrastar).

## Distância (px do viewport) para um toque virar arrasto. Menor que o scroll_deadzone das
## telas, para o arrasto nativo nunca começar em paralelo.
const DRAG_THRESHOLD := 12.0
## Desaceleração da inércia (maior = para mais rápido).
const FRICTION := 3.2
const MAX_SPEED := 7000.0
const MIN_SPEED := 30.0

var _pressing := false
var _dragging := false
var _injecting := false
var _start := Vector2.ZERO
var _candidates: Array[ScrollContainer] = []
var _target: ScrollContainer = null
var _vertical := true
var _velocity := 0.0
var _last_usec := 0
var _fling := 0.0
var _fling_target: ScrollContainer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)


func _input(event: InputEvent) -> void:
	if _injecting:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_on_press(event.position)
		else:
			_on_release()
	elif event is InputEventMouseMotion and _pressing:
		_on_motion(event)
	elif _dragging and (event is InputEventScreenDrag):
		# O toque bruto também chega à GUI; durante nossa rolagem ninguém mais o trata.
		get_viewport().set_input_as_handled()


func _on_press(pos: Vector2) -> void:
	_stop_fling()
	_pressing = false
	_dragging = false
	_target = null
	if _over_blocking_control(pos):
		return
	_candidates = _scrolls_at(pos)
	if _candidates.is_empty():
		return
	_pressing = true
	_start = pos
	_velocity = 0.0
	_last_usec = Time.get_ticks_usec()


func _on_motion(event: InputEventMouseMotion) -> void:
	if not _dragging:
		var moved: Vector2 = event.position - _start
		if moved.length() < DRAG_THRESHOLD:
			return
		_vertical = absf(moved.y) >= absf(moved.x)
		_target = _pick(_vertical)
		if _target == null:
			_pressing = false
			return
		_dragging = true
		_cancel_gui_press()
	if not is_instance_valid(_target) or not _target.is_visible_in_tree():
		_pressing = false
		_dragging = false
		return
	var delta: float = event.relative.y if _vertical else event.relative.x
	_scroll_by(_target, -delta)
	var now := Time.get_ticks_usec()
	var dt := maxf(float(now - _last_usec) / 1000000.0, 0.001)
	_last_usec = now
	var inst := clampf(-delta / dt, -MAX_SPEED, MAX_SPEED)
	_velocity = lerpf(_velocity, inst, 0.35)
	get_viewport().set_input_as_handled()


func _on_release() -> void:
	if not _pressing:
		return
	_pressing = false
	if not _dragging:
		return
	_dragging = false
	# Dedo parado antes de soltar = sem inércia.
	if Time.get_ticks_usec() - _last_usec > 90000:
		_velocity = 0.0
	if absf(_velocity) > MIN_SPEED * 4.0 and is_instance_valid(_target):
		_fling = _velocity
		_fling_target = _target
		set_process(true)
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not is_instance_valid(_fling_target) or not _fling_target.is_visible_in_tree():
		_stop_fling()
		return
	var moved := _scroll_by(_fling_target, _fling * delta)
	_fling *= exp(-FRICTION * delta)
	if not moved or absf(_fling) < MIN_SPEED:
		_stop_fling()


func _stop_fling() -> void:
	_fling = 0.0
	_fling_target = null
	set_process(false)


## Rola e diz se de fato andou (false = bateu no início ou no fim).
func _scroll_by(sc: ScrollContainer, amount: float) -> bool:
	if _vertical:
		var before := sc.scroll_vertical
		sc.scroll_vertical = before + roundi(amount)
		return sc.scroll_vertical != before
	var before_h := sc.scroll_horizontal
	sc.scroll_horizontal = before_h + roundi(amount)
	return sc.scroll_horizontal != before_h


## Cancela o botão que recebeu o toque: o "dedo" sai de cima dele (o botão passa a se
## considerar solto do lado de fora) e é solto longe, então ele volta ao normal sem emitir
## pressed e a GUI deixa de acompanhar esse toque.
func _cancel_gui_press() -> void:
	var far := Vector2(-100000, -100000)
	var mm := InputEventMouseMotion.new()
	mm.button_mask = MOUSE_BUTTON_MASK_LEFT
	mm.position = far
	mm.global_position = far
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = false
	mb.button_mask = 0
	mb.position = far
	mb.global_position = far
	_injecting = true
	get_viewport().push_input(mm)
	get_viewport().push_input(mb)
	_injecting = false


## Rolagens visíveis sob o ponto, da mais interna para a mais externa. Com um modal aberto,
## só as de dentro dele (a tela por trás não deve rolar).
func _scrolls_at(pos: Vector2) -> Array[ScrollContainer]:
	var root := get_tree().root
	var modal_host: Node = null
	if UIManager.main != null and UIManager.has_modal():
		modal_host = UIManager.main.modal_host
	var base: Node = modal_host if modal_host != null else root
	var found: Array[ScrollContainer] = []
	for n in base.find_children("*", "ScrollContainer", true, false):
		var sc := n as ScrollContainer
		if sc.is_visible_in_tree() and sc.get_global_rect().has_point(pos):
			found.append(sc)
	# find_children devolve em ordem de árvore: pais antes dos filhos.
	found.reverse()
	return found


func _pick(vertical: bool) -> ScrollContainer:
	for sc in _candidates:
		if not is_instance_valid(sc):
			continue
		if vertical and sc.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED \
				and sc.get_v_scroll_bar().max_value > sc.size.y + 1.0:
			return sc
		if not vertical and sc.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED \
				and sc.get_h_scroll_bar().max_value > sc.size.x + 1.0:
			return sc
	return null


## Controles que usam o arrasto para si (sliders, texto de várias linhas).
func _over_blocking_control(pos: Vector2) -> bool:
	for cls in ["Slider", "TextEdit"]:
		for n in get_tree().root.find_children("*", cls, true, false):
			var c := n as Control
			if c.is_visible_in_tree() and c.get_global_rect().has_point(pos):
				return true
	return false
