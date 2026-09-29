class_name IdentityBand
extends Control
## Fundo de cabeçalho com a identidade do clube: um bloco chapado na cor principal à esquerda,
## com corte diagonal, e uma faixa fina na segunda cor, como a arte de uma transmissão ou a
## carta de um jogador. Vai como primeiro filho de um PanelContainer (ver `wrap`).

var c1 := Color(0, 0, 0, 0)
var c2 := Color(0, 0, 0, 0)
## Largura do bloco (px); o conteúdo que fica em cima dele (retrato, escudo) usa essa medida.
var block := 200.0
## Altura do bloco: só a faixa do retrato/escudo; o texto abaixo fica sobre o painel neutro.
var band_h := 200.0


## Painel de cabeçalho com a identidade de `club`. Devolve [painel, caixa do conteúdo].
static func wrap(club: Club, block_w: float = 200.0, height: float = 200.0) -> Array:
	var p := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = UIColors.SURFACE
	box.set_corner_radius_all(UITokens.R_SM)
	box.anti_aliasing = true
	p.add_theme_stylebox_override(&"panel", box)
	p.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	var bg := IdentityBand.new()
	bg.block = block_w
	bg.band_h = height
	if club != null:
		bg.c1 = club.primary_color()
		bg.c2 = club.secondary_color()
	p.add_child(bg)
	var body := UIKit.vbox(10)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(UIKit.margin(body, 18, 16, 18, 16))
	return [p, body]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	if c1.a <= 0.0 or size.x <= 1.0:
		return
	var h := minf(size.y, band_h)
	var cut := minf(h * 0.3, 60.0)
	draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(block + cut, 0), Vector2(block, h), Vector2(0, h)]), c1)
	if c2.a > 0.0 and not _same(c1, c2):
		var x := block + 10.0
		draw_colored_polygon(PackedVector2Array([Vector2(x + cut, 0), Vector2(x + cut + 12.0, 0), Vector2(x + 12.0, h), Vector2(x, h)]), c2)


static func _same(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) < 0.12
