class_name ColorWheel
extends Control
## Roda de cores para toque: disco de matiz (ângulo) × saturação (raio) e, ao lado, a barra de
## brilho. Arrastar em qualquer um dos dois muda a cor na hora. `open()` mostra a roda numa folha
## com a cor antiga e a nova lado a lado, o código hexadecimal e o botão de confirmar.

signal changed(color: Color)

var h := 0.0
var s := 1.0
var v := 1.0
var _drag := 0 # 0 nada, 1 disco, 2 barra

const SEG := 48
const RINGS := 8


func _init() -> void:
	custom_minimum_size = Vector2(560, 440)
	mouse_filter = Control.MOUSE_FILTER_STOP


func set_color(c: Color) -> void:
	h = c.h
	s = c.s
	v = c.v
	queue_redraw()


func color() -> Color:
	return Color.from_hsv(h, s, v)


func _disc() -> Array:
	var bar_w := 64.0
	var r := minf(size.y * 0.5 - 8.0, (size.x - bar_w - 40.0) * 0.5)
	var c := Vector2(r + 8.0, size.y * 0.5)
	return [c, r, Rect2(c.x + r + 32.0, c.y - r, bar_w, r * 2.0)]


func _draw() -> void:
	var d := _disc()
	var c: Vector2 = d[0]
	var r: float = d[1]
	var bar: Rect2 = d[2]
	# Disco: anéis de saturação × fatias de matiz, com o brilho atual
	var pts := PackedVector2Array([c])
	var cols := PackedColorArray([Color.from_hsv(0.0, 0.0, v)])
	for ring in range(1, RINGS + 1):
		var sat := float(ring) / RINGS
		for i in SEG:
			var a := TAU * i / SEG
			pts.append(c + Vector2(cos(a), sin(a)) * r * sat)
			cols.append(Color.from_hsv(float(i) / SEG, sat, v))
	var idx := PackedInt32Array()
	for i in SEG:
		idx.append_array([0, 1 + i, 1 + (i + 1) % SEG])
	for ring in range(1, RINGS):
		var b0 := 1 + (ring - 1) * SEG
		var b1 := 1 + ring * SEG
		for i in SEG:
			var j := (i + 1) % SEG
			idx.append_array([b0 + i, b1 + i, b1 + j, b0 + i, b1 + j, b0 + j])
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), idx, pts, cols)
	draw_arc(c, r, 0.0, TAU, 96, Color(1, 1, 1, 0.35), 2.0, true)
	var m := c + Vector2(cos(h * TAU), sin(h * TAU)) * r * s
	draw_circle(m, 14.0, color(), true, -1.0, true)
	draw_arc(m, 14.0, 0.0, TAU, 32, Color.WHITE, 3.0, true)
	draw_arc(m, 17.0, 0.0, TAU, 32, Color(0, 0, 0, 0.5), 2.0, true)
	# Barra de brilho (do mais claro no alto ao preto embaixo)
	var bp := PackedVector2Array([bar.position, bar.position + Vector2(bar.size.x, 0), bar.end, bar.position + Vector2(0, bar.size.y)])
	var top := Color.from_hsv(h, s, 1.0)
	draw_polygon(bp, PackedColorArray([top, top, Color.BLACK, Color.BLACK]))
	draw_rect(bar, Color(1, 1, 1, 0.35), false, 2.0)
	var y := bar.position.y + (1.0 - v) * bar.size.y
	draw_rect(Rect2(bar.position.x - 6.0, y - 5.0, bar.size.x + 12.0, 10.0), Color.WHITE, false, 3.0)


func _gui_input(ev: InputEvent) -> void:
	var pos := Vector2.ZERO
	var pressed := false
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		pressed = ev.pressed
		pos = ev.position
		if not pressed:
			_drag = 0
			return
		var d := _disc()
		if (pos - Vector2(d[0])).length() <= float(d[1]) + 20.0:
			_drag = 1
		elif Rect2(d[2]).grow(24.0).has_point(pos):
			_drag = 2
	elif ev is InputEventMouseMotion and _drag != 0:
		pos = ev.position
	elif ev is InputEventScreenDrag and _drag != 0:
		pos = ev.position
	else:
		return
	_apply(pos)
	accept_event()


func _apply(pos: Vector2) -> void:
	var d := _disc()
	if _drag == 1:
		var rel: Vector2 = pos - Vector2(d[0])
		h = fposmod(atan2(rel.y, rel.x) / TAU, 1.0)
		s = clampf(rel.length() / float(d[1]), 0.0, 1.0)
	elif _drag == 2:
		var bar: Rect2 = d[2]
		v = clampf(1.0 - (pos.y - bar.position.y) / bar.size.y, 0.0, 1.0)
	queue_redraw()
	changed.emit(color())


## Folha com a roda. `on_pick(color)` só é chamado ao confirmar.
static func open(initial: Color, title: String, on_pick: Callable) -> void:
	var root := UIKit.vbox(12)
	root.add_child(UIKit.label(title, "H2", true))
	var wheel := ColorWheel.new()
	wheel.set_color(initial)
	wheel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	root.add_child(wheel)
	var row := UIKit.hbox(12)
	var old_sw := ColorRect.new()
	old_sw.color = initial
	old_sw.custom_minimum_size = Vector2(90, 56)
	var new_sw := ColorRect.new()
	new_sw.color = initial
	new_sw.custom_minimum_size = Vector2(90, 56)
	var hex := UIKit.label("#" + initial.to_html(false).to_upper(), "H3")
	hex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(UIKit.label("Antes", "Small"))
	row.add_child(old_sw)
	row.add_child(UIKit.label("Nova", "Small"))
	row.add_child(new_sw)
	row.add_child(hex)
	root.add_child(row)
	wheel.changed.connect(func(c: Color):
		new_sw.color = c
		hex.text = "#" + c.to_html(false).to_upper())
	var btns := UIKit.hbox(10)
	var cancel := UIKit.button("Cancelar", "GhostButton", func(): UIManager.close_modal())
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btns.add_child(cancel)
	var ok := UIKit.button("Usar esta cor", "PrimaryButton", func():
		var c := wheel.color()
		UIManager.close_modal()
		on_pick.call(c), "check")
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btns.add_child(ok)
	root.add_child(btns)
	UIManager.show_modal(root, true)
