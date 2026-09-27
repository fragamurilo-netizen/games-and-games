class_name FaceColorSystem
extends RefCounted
## Cores do rosto: pele (tom, subtom e o ajuste "de foto"), lábios, esclera e sombra de barba.
##
## A escala de pele do FaceGen (SKIN_COLORS) é boa como escala, mas saturada demais para uma foto:
## a pele laranja deixava lábios e sombras com cara de tinta. `photo_skin` baixa a saturação um
## pouco (com teto nos tons escuros, onde a saturação era a maior) e mantém o subtom de cada um
## (rosado, neutro, oliva, dourado). O resto das cores deriva da pele já ajustada.

const UNDERTONES: Array[String] = ["rosado", "neutro", "oliva", "dourado"]


## Pele como aparece numa foto de estúdio.
static func photo_skin(c: Color) -> Color:
	var s := minf(c.s * 0.86, lerpf(0.5, 0.56, clampf(c.v * 1.4, 0.0, 1.0)))
	return Color.from_hsv(c.h, s, c.v, c.a)


## Pele escurecida com sombra quente (o vermelho some por último), igual ao shader.
static func shade(base: Color, lum: float) -> Color:
	var l := maxf(lum, 0.0)
	return Color(minf(base.r * pow(l, 0.82), 1.0), minf(base.g * l, 1.0), minf(base.b * pow(l, 1.12), 1.0), base.a)


## Lábios [de cima, de baixo] a partir da pele: mais escuros e mais vermelhos que a pele em volta
## (sem puxar para o roxo); em pele escura o de baixo fica um pouco mais rosado.
static func lips(skin: Color, darkness: float) -> Array[Color]:
	var sk := shade(skin, 0.8)
	var red := Color(0.7, 0.33, 0.28)
	var rr := sk.get_luminance() / maxf(0.05, red.get_luminance()) * 0.95
	var lip := sk.lerp(Color(minf(1.0, red.r * rr), minf(1.0, red.g * rr), minf(1.0, red.b * rr)), 0.5 - darkness * 0.2).darkened(0.08 + darkness * 0.06)
	var upper := lip.darkened(0.14 + darkness * 0.08)
	var rose := Color(0.6, 0.36, 0.37)
	var rk := lip.get_luminance() / maxf(0.05, rose.get_luminance())
	var lower := lip.lerp(Color(minf(1.0, rose.r * rk), minf(1.0, rose.g * rk), minf(1.0, rose.b * rk)), darkness * 0.3)
	return [upper, lower]


## Branco do olho: cinza quente, nunca branco puro, levemente puxado para a pele.
static func sclera(skin: Color) -> Color:
	return Color(0.87, 0.84, 0.8).lerp(skin, 0.2)
