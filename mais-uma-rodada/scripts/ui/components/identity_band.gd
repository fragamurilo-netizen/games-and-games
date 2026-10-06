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
## Ficha do jogador (como no FM): degradê na cor do clube atrás do recorte, sumindo para a direita.
var gradient := false


## Painel de cabeçalho com a identidade de `club`. Devolve [painel, caixa do conteúdo].
static func wrap(club: Club, block_w: float = 200.0, height: float = 200.0, gradient_: bool = false) -> Array:
	var p := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = UIColors.SURFACE
	box.set_corner_radius_all(UITokens.R_SM)
	box.anti_aliasing = true
	p.add_theme_stylebox_override(&"panel", box)
	p.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	var bg := IdentityBand.new()
	bg.gradient = gradient_
	bg.block = block_w
	bg.band_h = height
	if club != null:
		bg.c1 = club.primary_color()
		bg.c2 = club.secondary_color()
		# Camisa clara (branca, creme): o bloco vai na segunda cor e o claro vira a faixa,
		# para não virar um retângulo branco estourado sobre a ardósia.
		if bg.c1.get_luminance() > 0.75 and bg.c2.get_luminance() < 0.6:
			var t := bg.c1
			bg.c1 = bg.c2
			bg.c2 = t
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
	if gradient:
		_draw_gradient(h)
		return
	var cut := minf(h * 0.3, 60.0)
	draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(block + cut, 0), Vector2(block, h), Vector2(0, h)]), c1)
	if c2.a > 0.0 and not _same(c1, c2):
		var x := block + 10.0
		draw_colored_polygon(PackedVector2Array([Vector2(x + cut, 0), Vector2(x + cut + 12.0, 0), Vector2(x + 12.0, h), Vector2(x, h)]), c2)


## Degradê da ficha: cor do clube cheia atrás do jogador, sumindo até ~2,4 vezes a largura do
## bloco; uma sombra leve na base dá chão ao recorte.
func _draw_gradient(h: float) -> void:
	var base := c1.darkened(0.15)
	var x1 := minf(size.x, block * 2.4)
	var steps := [[0.0, 0.95], [0.45, 0.8], [0.75, 0.4], [1.0, 0.0]]
	for i in steps.size() - 1:
		var xa := x1 * float(steps[i][0])
		var xb := x1 * float(steps[i + 1][0])
		var ca := Color(base, float(steps[i][1]))
		var cb := Color(base, float(steps[i + 1][1]))
		draw_polygon(PackedVector2Array([Vector2(xa, 0), Vector2(xb, 0), Vector2(xb, h), Vector2(xa, h)]),
			PackedColorArray([ca, cb, cb, ca]))
	# Chão: escurece os últimos 30% da faixa, onde ficam os ombros
	var y0 := h * 0.7
	var dark := Color(UIColors.BG, 0.0)
	var dark2 := Color(UIColors.BG, 0.45)
	draw_polygon(PackedVector2Array([Vector2(0, y0), Vector2(x1, y0), Vector2(x1, h), Vector2(0, h)]),
		PackedColorArray([dark, dark, Color(UIColors.BG, 0.0), dark2]))


static func _same(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) < 0.12
