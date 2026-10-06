class_name TvLayer
extends Control
## Camada do grafismo de TV por cima da partida: tarjas embaixo do campo, peças grandes no meio
## (números, tabela) e avisos em cima, uma de cada vez por lugar, com fila curta (peça velha
## demais é descartada: a TV não mostra o número de dez minutos atrás). O jogo segue rolando por
## baixo; tocar numa peça a tira da tela. A faixa do gol é à parte: limpa a tela e tem tempo
## próprio (a partida espera por ela).

const LOWER := 0
const CENTER := 1
const TOP := 2
const STALE_MS := 14000
const MAX_QUEUE := 3

## Área de referência (o campo) em coordenadas desta camada.
var area: Callable = Callable()
## Relógio parado (modal aberto, intervalo).
var paused := false

var _slots: Array = [null, null, null]
var _timers: Array[float] = [0.0, 0.0, 0.0]
var _queue: Array = [[], [], []]
var _banner: Control = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_relayout)


func busy(slot: int) -> bool:
	return _slots[slot] != null or not (_queue[slot] as Array).is_empty()


## Mostra uma peça num lugar por `secs` segundos (na fila se o lugar estiver ocupado).
func show_piece(node: Control, slot: int, secs: float) -> void:
	if node == null:
		return
	if _slots[slot] == null and _banner == null:
		_present(node, slot, secs)
		return
	var q: Array = _queue[slot]
	q.append([node, secs, Time.get_ticks_msec()])
	while q.size() > MAX_QUEUE:
		var old: Array = q.pop_front()
		(old[0] as Control).queue_free()


## Faixa do gol: tira o resto da tela, entra varrendo da esquerda e sai pela direita.
## Devolve quanto tempo fica (a partida espera esse tanto).
func play_banner(node: Control, secs: float, epic: bool = false) -> float:
	for s in 3:
		_dismiss(s, true)
	if _banner != null and is_instance_valid(_banner):
		_banner.queue_free()
	_banner = node
	node.mouse_filter = Control.MOUSE_FILTER_STOP
	node.gui_input.connect(func(e: InputEvent):
		if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
			_end_banner(node))
	add_child(node)
	var r := _area()
	var w := minf(r.size.x - 16.0, 760.0)
	var h := node.get_combined_minimum_size().y
	node.size = Vector2(w, h)
	node.position = Vector2(r.position.x + (r.size.x - w) * 0.5, r.position.y + clampf(r.size.y * 0.42 - h * 0.5, 0.0, maxf(0.0, r.size.y - h)))
	if AppSettings.reduce_motion:
		node.modulate.a = 0.0
		create_tween().tween_property(node, "modulate:a", 1.0, 0.15)
	else:
		node.pivot_offset = Vector2(0, h * 0.5)
		node.scale = Vector2(0.0, 1.0)
		var tw := create_tween()
		tw.tween_property(node, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		var word := node.find_child("Word", true, false) as Control
		if word != null:
			word.modulate.a = 0.0
			var tw2 := create_tween()
			tw2.tween_interval(0.18)
			tw2.tween_property(word, "modulate:a", 1.0, 0.18)
		if epic:
			_flash()
	get_tree().create_timer(secs).timeout.connect(func(): _end_banner(node))
	return secs


func _end_banner(node: Control) -> void:
	if not is_instance_valid(node) or node != _banner:
		return
	_banner = null
	if AppSettings.reduce_motion:
		node.queue_free()
		return
	node.pivot_offset = Vector2(node.size.x, node.size.y * 0.5)
	var tw := create_tween()
	tw.tween_property(node, "scale", Vector2(0.0, 1.0), 0.22).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.tween_callback(node.queue_free)


func _flash() -> void:
	var f := ColorRect.new()
	f.color = Color(1, 1, 1, 0.35)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(f)
	move_child(f, 0)
	var tw := create_tween()
	tw.tween_property(f, "color:a", 0.0, 0.4)
	tw.tween_callback(f.queue_free)


## Tira tudo da tela e esvazia as filas (pular para o fim, apito final).
func clear() -> void:
	for s in 3:
		_dismiss(s, true)
		for it in _queue[s]:
			(it[0] as Control).queue_free()
		(_queue[s] as Array).clear()
	if _banner != null and is_instance_valid(_banner):
		_banner.queue_free()
	_banner = null


func _process(delta: float) -> void:
	if paused:
		return
	for s in 3:
		if _slots[s] != null:
			_timers[s] -= delta
			if _timers[s] <= 0.0:
				_dismiss(s)
		elif _banner == null:
			var q: Array = _queue[s]
			while not q.is_empty():
				var it: Array = q.pop_front()
				if Time.get_ticks_msec() - int(it[2]) > STALE_MS:
					(it[0] as Control).queue_free()
					continue
				_present(it[0], s, float(it[1]))
				break


func _present(node: Control, slot: int, secs: float) -> void:
	_slots[slot] = node
	_timers[slot] = secs
	node.mouse_filter = Control.MOUSE_FILTER_STOP
	node.gui_input.connect(func(e: InputEvent):
		if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
			if _slots[slot] == node:
				_dismiss(slot))
	add_child(node)
	_place(node, slot)
	var end_pos := node.position
	node.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(node, "modulate:a", 1.0, 0.22)
	if not AppSettings.reduce_motion:
		match slot:
			LOWER:
				node.position = end_pos + Vector2(0, 26)
				tw.tween_property(node, "position", end_pos, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			TOP:
				node.position = end_pos + Vector2(0, -18)
				tw.tween_property(node, "position", end_pos, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			_:
				node.pivot_offset = node.size * 0.5
				node.scale = Vector2(0.96, 0.96)
				tw.tween_property(node, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _dismiss(slot: int, instant: bool = false) -> void:
	var node: Control = _slots[slot]
	_slots[slot] = null
	if node == null or not is_instance_valid(node):
		return
	if instant or AppSettings.reduce_motion:
		node.queue_free()
		return
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := create_tween()
	tw.tween_property(node, "modulate:a", 0.0, 0.25)
	tw.tween_callback(node.queue_free)


func _area() -> Rect2:
	if area.is_valid():
		var r: Variant = area.call()
		if r is Rect2 and (r as Rect2).size.x > 40.0 and (r as Rect2).size.y > 40.0:
			return r
	return Rect2(Vector2.ZERO, size)


func _place(node: Control, slot: int) -> void:
	var r := _area()
	var w := minf(r.size.x - 20.0, 640.0 if slot != CENTER else 600.0)
	node.size = Vector2(w, 0)
	var h := node.get_combined_minimum_size().y
	node.size = Vector2(w, h)
	var x := r.position.x + (r.size.x - w) * 0.5
	var y := 0.0
	match slot:
		LOWER:
			y = r.end.y - h - 10.0
		TOP:
			y = r.position.y + 8.0
		_:
			y = r.position.y + (r.size.y - h) * 0.5
	# Peça maior que o campo: encosta no alto do campo e desce por cima da narração.
	y = clampf(y, minf(r.position.y, maxf(0.0, size.y - h)), maxf(0.0, size.y - h))
	node.position = Vector2(x, y)


func _relayout() -> void:
	for s in 3:
		var n: Control = _slots[s]
		if n != null and is_instance_valid(n):
			_place(n, s)
