class_name Grass
extends RefCounted
## Gramado desenhado, para as peças da interface que ficam "no campo" (barra superior, bloco de
## jogo, cabeçalhos): faixas de corte e marcações de cal. É o mesmo verde do PitchView
## (UIColors.PITCH_A/B), escurecido quando há texto por cima (grama à noite, sob o refletor).
## Só desenha: quem chama é um CanvasItem dentro do próprio _draw.

## Texto e ícones sobre o gramado são sempre de cal, no modo escuro e no claro.
const CHALK := Color("#F4F2EA")


static func tone(i: int, dark: float = 0.0) -> Color:
	var c := UIColors.PITCH_A if i % 2 == 0 else UIColors.PITCH_B
	return c.darkened(dark) if dark > 0.0 else c


static func chalk(alpha: float = 0.8) -> Color:
	return Color(CHALK, alpha)


## Faixas de corte verticais (o campo visto de cima, de lado a lado). `stripe` é a largura de
## cada faixa; `x0` desloca o desenho para duas peças vizinhas continuarem a mesma grama.
static func stripes(ci: CanvasItem, r: Rect2, stripe: float = 72.0, dark: float = 0.0, x0: float = 0.0) -> void:
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return
	ci.draw_rect(r, tone(0, dark))
	var first := int(floor((r.position.x - x0) / stripe))
	var x := x0 + first * stripe
	var i := first
	while x < r.end.x:
		if posmod(i, 2) == 1:
			var a := maxf(x, r.position.x)
			var b := minf(x + stripe, r.end.x)
			if b > a:
				ci.draw_rect(Rect2(a, r.position.y, b - a, r.size.y), tone(1, dark))
		x += stripe
		i += 1


## Faixas de corte horizontais (o campo visto de trás do gol).
static func bands(ci: CanvasItem, r: Rect2, band: float = 48.0, dark: float = 0.0) -> void:
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return
	ci.draw_rect(r, tone(0, dark))
	var y := r.position.y + band
	while y < r.end.y:
		ci.draw_rect(Rect2(r.position.x, y, r.size.x, minf(band, r.end.y - y)), tone(1, dark))
		y += band * 2.0


## Círculo central com a marca do meio e a linha do meio-campo passando por ele, dentro de `clip`
## (a linha vai de cima a baixo do recorte).
static func center_mark(ci: CanvasItem, c: Vector2, radius: float, clip: Rect2, alpha: float = 0.5, width: float = 3.0) -> void:
	var col := chalk(alpha)
	ci.draw_line(Vector2(c.x, clip.position.y), Vector2(c.x, clip.end.y), col, width)
	ci.draw_arc(c, radius, 0.0, TAU, 48, col, width, true)
