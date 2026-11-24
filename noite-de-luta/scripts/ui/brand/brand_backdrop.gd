class_name BrandBackdrop
extends Control
## Luz de arena atrás da marca: um clarão no ponto de foco e dois fachos, o vermelho vindo do
## canto esquerdo e o azul do direito. `beam` vai de 0 (fachos fora da tela) a 1 (no foco), e
## é o que a abertura anima.

const BEAM := preload("res://assets/brand/facho.png")

## Onde a luz bate, em fração do tamanho (o centro do emblema).
var focus := Vector2(0.5, 0.5):
	set(v):
		focus = v
		queue_redraw()
var beam := 1.0:
	set(v):
		beam = v
		queue_redraw()
## Força geral da luz (o menu usa menos que a abertura).
var strength := 1.0:
	set(v):
		strength = v
		queue_redraw()

static var _glow: GradientTexture2D


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


static func glow_texture() -> GradientTexture2D:
	if _glow == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.45, Color(1, 1, 1, 0.38))
		_glow = GradientTexture2D.new()
		_glow.gradient = g
		_glow.fill = GradientTexture2D.FILL_RADIAL
		_glow.fill_from = Vector2(0.5, 0.5)
		_glow.fill_to = Vector2(1.0, 0.5)
		_glow.width = 128
		_glow.height = 128
	return _glow


func _draw() -> void:
	if size.x < 2.0 or size.y < 2.0 or strength <= 0.0:
		return
	var f := focus * size
	var r := minf(size.x, size.y) * 0.95
	draw_texture_rect(glow_texture(), Rect2(f - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(0.42, 0.50, 0.66, 0.20 * strength))
	if beam <= 0.0:
		return
	_beam(Vector2(-0.06 * size.x, -0.03 * size.y), f, UIColors.CORNER_RED.lightened(0.25), -1.0)
	_beam(Vector2(1.06 * size.x, -0.03 * size.y), f, UIColors.CORNER_BLUE.lightened(0.3), 1.0)
	draw_set_transform(Vector2.ZERO)


## Um facho da origem (fora da tela) até um pouco além do foco. Com `beam` menor que 1 ele
## ainda está a caminho: aponta para fora e vem girando.
func _beam(from: Vector2, to: Vector2, color: Color, side: float) -> void:
	var dir := to - from
	var length := dir.length() * 1.45
	var width := minf(size.x, size.y) * 0.62
	var k := 1.0 - clampf(beam, 0.0, 1.0)
	var angle := dir.angle() - PI * 0.5 + side * k * 0.85
	draw_set_transform(from, angle)
	draw_texture_rect(BEAM, Rect2(-width * 0.5, 0.0, width, length), false, Color(color, 0.34 * strength * clampf(beam * 1.6, 0.0, 1.0)))
