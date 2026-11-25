class_name UIColors
extends RefCounted
## Paleta do jogo: cartaz de luta. Preto neutro em degraus (sem azul), texto cor de papel, o
## amarelo de cartaz para o que é ação e destaque, e os estados em cores vivas.
## Vermelho e azul dos corners (CORNER_RED / CORNER_BLUE) marcam os dois lados de uma luta. As
## cores da equipe do jogador aparecem no escudo e nos retratos da casa. Telas não escrevem cor
## solta.

const D_BG := Color("#0A0A0A")
const D_SURFACE := Color("#161514")
const D_SURFACE_2 := Color("#211F1D")
const D_SURFACE_3 := Color("#2F2C29")
const D_LINE := Color("#3D3935")
const D_TEXT := Color("#F3EEE4")
const D_MUTED := Color("#B9B2A6")
const D_DIM := Color("#8A837A")
const D_GOLD := Color("#FFCF0D")
const D_GOLD_DARK := Color("#C99B00")
const D_GREEN := Color("#3FC380")
const D_RED := Color("#F0555D")
const D_BLUE := Color("#5B9BF0")
const D_ORANGE := Color("#F5A342")

static var BG := D_BG
static var SURFACE := D_SURFACE
static var SURFACE_2 := D_SURFACE_2
static var SURFACE_3 := D_SURFACE_3
static var LINE := D_LINE
static var TEXT := D_TEXT
static var MUTED := D_MUTED
static var DIM := D_DIM
static var GOLD := D_GOLD
static var GOLD_DARK := D_GOLD_DARK
const ON_GOLD := Color("#0A0A0A")
static var GREEN := D_GREEN
static var RED := D_RED
static var BLUE := D_BLUE
static var ORANGE := D_ORANGE
## Fundo neutro dos retratos (o quadro em degradê do Portrait).
static var PORTRAIT := Color("#4A4641")
## Modo claro ainda não existe neste jogo; o nome fica para o código portado do MUR.
static var light := false

## Corners da luta: vermelho (esquerda) e azul (direita).
const CORNER_RED := Color("#C42B35")
const CORNER_BLUE := Color("#2F68C4")

## Destaque da interface: o dourado da marca, em todas as telas.
static var ACCENT := D_GOLD
static var ACCENT_DARK := D_GOLD_DARK
static var ON_ACCENT := ON_GOLD
## Cores da equipe (escudo, retratos da casa); transparentes fora de uma carreira.
static var TEAM_1 := Color(0, 0, 0, 0)
static var TEAM_2 := Color(0, 0, 0, 0)
## Tom da equipe para fundos de retrato e faixas: a mais viva das duas cores, visível no escuro.
static var TEAM_TONE := PORTRAIT


## Guarda as cores da equipe do jogador (c1 nulo = fora de uma carreira). O destaque da interface
## não muda mais com a equipe: é sempre o dourado da marca.
static func apply_colors(c1: Variant, c2: Variant) -> void:
	if c1 == null:
		TEAM_1 = Color(0, 0, 0, 0)
		TEAM_2 = Color(0, 0, 0, 0)
		TEAM_TONE = PORTRAIT
	else:
		TEAM_1 = c1
		TEAM_2 = c2
		TEAM_TONE = team_accent(c1, c2)


## A mais viva das duas cores, clareada até aparecer bem no fundo escuro.
static func team_accent(c1: Color, c2: Color) -> Color:
	var best := D_GOLD
	var best_score := -1.0
	for c: Color in [c1, c2]:
		var col := c
		for _i in 10:
			if col.get_luminance() >= 0.34:
				break
			col = col.lightened(0.14)
		var score := col.s * 1.4 + (0.35 if c.get_luminance() > 0.12 else 0.0) - absf(col.get_luminance() - 0.55) * 0.5
		if c.get_luminance() > 0.93 and c.s < 0.08:
			score = 0.25
		if score > best_score:
			best_score = score
			best = col
	return best


## Mantido para o código vindo do MUR: no modo escuro a cor fica como está.
static func themed(orig: Color) -> Color:
	return orig


static func touch_only() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")


static func _same_rgb(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 and absf(a.b - b.b) < 0.01


## Resultado de luta: V (vitória), D (derrota), E (empate) ou SR (sem resultado).
static func result_color(r: String) -> Color:
	match r:
		"V":
			return GREEN
		"D":
			return RED
		"E":
			return ORANGE
	return DIM


## Cor usada como texto sobre o fundo da interface.
static func ink(c: Color) -> Color:
	return readable_on(c, [SURFACE, SURFACE_2], 4.5)


static func on_color(bg: Color) -> Color:
	var dark := Color("#111111")
	return dark if contrast(dark, bg) >= contrast(Color.WHITE, bg) else Color.WHITE


static func rel_luminance(c: Color) -> float:
	var col := c
	if col.a < 1.0:
		col = BG.lerp(Color(col.r, col.g, col.b), col.a)
	var l := col.srgb_to_linear()
	return 0.2126 * l.r + 0.7152 * l.g + 0.0722 * l.b


static func contrast(a: Color, b: Color) -> float:
	var la := rel_luminance(a)
	var lb := rel_luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


## A mesma cor, clareada ou escurecida só o necessário para ter `ratio` de contraste com
## todos os fundos de `bgs` (mantém o matiz).
static func readable_on(c: Color, bgs: Array, ratio: float = 4.5) -> Color:
	if _min_contrast(c, bgs) >= ratio:
		return c
	var bg_l := 0.0
	for bg: Color in bgs:
		bg_l += rel_luminance(bg)
	var to_dark := bg_l / maxf(1.0, bgs.size()) > 0.18
	var col := Color(c, 1.0)
	for i in 40:
		if to_dark:
			col.v = maxf(0.0, col.v - 0.04)
		elif col.v < 1.0:
			col.v = minf(1.0, col.v + 0.04)
		else:
			col.s = maxf(0.0, col.s - 0.05)
		if _min_contrast(col, bgs) >= ratio:
			break
	col.a = c.a
	return col


static func _min_contrast(c: Color, bgs: Array) -> float:
	var m := 99.0
	for bg: Color in bgs:
		m = minf(m, contrast(c, bg))
	return m


## Tom de identidade a partir das duas cores de uma equipe: a mais saturada.
static func tone_of(a: Color, b: Color) -> Color:
	if a.s < 0.2 and b.s >= 0.2:
		return b
	if b.s > a.s + 0.25:
		return b
	if a.s < 0.2 and b.s < 0.2:
		return a if a.get_luminance() < b.get_luminance() else b
	return a


## Escala de atributos e notas: verde, lima, dourado, laranja, vermelho.
static func attr_color(v: float) -> Color:
	if v >= 80.0:
		return Color("#3FC380")
	if v >= 70.0:
		return Color("#9CCB52")
	if v >= 60.0:
		return Color("#F2C14E")
	if v >= 50.0:
		return Color("#F5A342")
	return Color("#F0555D")


## A cor `c` como fundo de etiqueta ou faixa: o mesmo matiz, escuro o bastante para texto claro.
static func tinted(c: Color, amount: float = 0.18) -> Color:
	return SURFACE.lerp(Color(c, 1.0), amount)
