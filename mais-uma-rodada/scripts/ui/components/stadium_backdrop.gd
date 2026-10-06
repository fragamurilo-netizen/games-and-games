class_name StadiumBackdrop
extends Control
## Fundo de estádio à noite para as telas de abertura (menu, nova carreira, apresentação):
## céu escuro, feixes dos refletores, arquibancada em silhueta e o gramado em perspectiva,
## com o brilho na cor de destaque (dourado no menu, cor do clube na carreira).

var tint := Color(0, 0, 0, 0)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)


## Coloca o fundo atrás de tudo numa tela.
static func attach(screen: Control, color: Color = Color(0, 0, 0, 0)) -> StadiumBackdrop:
	var old := screen.get_node_or_null("StadiumBackdrop")
	if old != null:
		(old as StadiumBackdrop).tint = color
		old.queue_redraw()
		return old
	var b := StadiumBackdrop.new()
	b.name = "StadiumBackdrop"
	b.tint = color
	screen.add_child(b)
	screen.move_child(b, 0)
	return b


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 1.0:
		return
	var acc := tint if tint.a > 0.0 else UIColors.ACCENT
	var light := UIColors.light
	var sky_top := UIColors.BG
	var sky_bot := UIColors.BG.lerp(acc, 0.10 if not light else 0.06)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([sky_top, sky_top, sky_bot, sky_bot]))
	# Horizonte: onde a arquibancada encontra o gramado.
	var hz := h * 0.62
	# Feixes dos refletores, saindo de quatro torres e abrindo para baixo.
	var beam := Color(1, 1, 1, 0.07) if not light else Color(acc, 0.06)
	var beam0 := Color(beam, 0.0)
	for tx: float in [0.08, 0.3, 0.7, 0.92]:
		var top := Vector2(w * tx, h * 0.14)
		var spread := w * 0.28
		var dir := -1.0 if tx > 0.5 else 1.0
		draw_polygon(PackedVector2Array([top, top + Vector2(dir * spread * 0.2, 0), Vector2(w * 0.5 + dir * spread * 0.9, hz), Vector2(w * 0.5 + dir * spread * 0.1, hz)]),
			PackedColorArray([beam, beam, beam0, beam0]))
		# Torre e a grade de lâmpadas.
		var pole := Color(UIColors.TEXT, 0.12)
		draw_rect(Rect2(top.x - 2, top.y, 4, hz - top.y), pole)
		var lamp := Color(1, 1, 0.92, 0.85) if not light else Color(acc, 0.7)
		for i in 3:
			for j in 2:
				draw_rect(Rect2(top.x - 13 + i * 9, top.y - 14 + j * 7, 7, 5), lamp)
	# Arquibancada: faixas escuras com pontinhos de torcida.
	var stand := UIColors.BG.darkened(0.25) if not light else UIColors.SURFACE_3
	var sy := h * 0.40
	draw_polygon(PackedVector2Array([Vector2(0, sy + 30), Vector2(w, sy + 30), Vector2(w, hz), Vector2(0, hz)]),
		PackedColorArray([Color(stand, 0.0), Color(stand, 0.0), stand, stand]))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var dots := int(w * 0.5)
	for i in dots:
		var x := rng.randf() * w
		var y := lerpf(sy + 40.0, hz - 6.0, pow(rng.randf(), 0.7))
		var c := acc if rng.randf() < 0.35 else Color(UIColors.TEXT)
		c.a = 0.10 + 0.14 * (y - sy) / (hz - sy)
		draw_rect(Rect2(x, y, 3, 3), c)
	# Gramado em perspectiva com listras.
	var g1 := Color("#1F5E37") if not light else Color("#5FA873")
	var g2 := Color("#1B5431") if not light else Color("#58A06C")
	var stripes := 10
	for i in stripes:
		var t0 := float(i) / stripes
		var t1 := float(i + 1) / stripes
		var y0 := lerpf(hz, h, pow(t0, 1.4))
		var y1 := lerpf(hz, h, pow(t1, 1.4))
		var c := g1 if i % 2 == 0 else g2
		draw_rect(Rect2(0, y0, w, y1 - y0 + 1.0), c)
	# Linha do meio-campo e o círculo central achatado.
	var line := Color(1, 1, 1, 0.22)
	draw_line(Vector2(0, hz + (h - hz) * 0.45), Vector2(w, hz + (h - hz) * 0.45), line, 2.0)
	var cc := Vector2(w * 0.5, hz + (h - hz) * 0.45)
	var pts := PackedVector2Array()
	for i in 49:
		var a := TAU * i / 48.0
		pts.append(cc + Vector2(cos(a) * w * 0.2, sin(a) * (h - hz) * 0.12))
	draw_polyline(pts, line, 2.0, true)
	# Véu: o gramado some no fundo para o conteúdo ficar legível.
	var veil := Color(UIColors.BG, 0.0)
	var veil2 := Color(UIColors.BG, 0.9)
	draw_polygon(PackedVector2Array([Vector2(0, hz), Vector2(w, hz), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([Color(UIColors.BG, 0.35), Color(UIColors.BG, 0.35), veil2, veil2]))
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h * 0.3), Vector2(0, h * 0.3)]),
		PackedColorArray([Color(UIColors.BG, 0.6), Color(UIColors.BG, 0.6), veil, veil]))
