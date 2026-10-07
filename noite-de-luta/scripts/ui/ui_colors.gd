class_name UIColors
extends RefCounted
## Paleta do jogo (DESIGN.md › Colors): grafite em degraus de tom, texto de giz e estados sóbrios.
## O destaque é a cor da equipe do jogador; no menu, o dourado. Vermelho e azul dos corners só
## existem no contexto da luta (CORNER_RED / CORNER_BLUE). Telas não escrevem cor solta.

const D_BG := Color("#121416")
const D_SURFACE := Color("#1A1D20")
const D_SURFACE_2 := Color("#23272B")
const D_SURFACE_3 := Color("#2F3439")
const D_LINE := Color("#363C42")
const D_TEXT := Color("#F1F0EC")
const D_MUTED := Color("#A5ABB2")
const D_DIM := Color("#8A9199")
const D_GOLD := Color("#D3A94A")
const D_GOLD_DARK := Color("#A8843A")
const D_GREEN := Color("#57976B")
const D_RED := Color("#C75B5B")
const D_BLUE := Color("#6F93B8")
const D_ORANGE := Color("#D39B45")

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
const ON_GOLD := Color("#1A1300")
static var GREEN := D_GREEN
static var RED := D_RED
static var BLUE := D_BLUE
static var ORANGE := D_ORANGE
## Modo claro ainda não existe neste jogo; o nome fica para o código portado do MUR.
static var light := false

## Corners da luta: vermelho (esquerda) e azul (direita). Só no cartaz, na luta e no resultado.
const CORNER_RED := Color("#B3262E")
const CORNER_BLUE := Color("#2E5C9E")

## Destaque da interface: dourado no menu; na carreira, a cor da equipe do jogador.
static var ACCENT := D_GOLD
static var ACCENT_DARK := D_GOLD_DARK
static var ON_ACCENT := ON_GOLD
## Cores da equipe (faixa da barra superior); transparentes fora de uma carreira.
static var TEAM_1 := Color(0, 0, 0, 0)
static var TEAM_2 := Color(0, 0, 0, 0)
static var _theme_refs: Array = []
static var _applied := ""


## Pinta o destaque com as cores da equipe (c1 nulo = dourado do menu).
static func apply_colors(c1: Variant, c2: Variant) -> void:
	var key := "" if c1 == null else "#%s|#%s" % [(c1 as Color).to_html(false), (c2 as Color).to_html(false)]
	if key == _applied:
		return
	_applied = key
	if c1 == null:
		ACCENT = D_GOLD
		TEAM_1 = Color(0, 0, 0, 0)
		TEAM_2 = Color(0, 0, 0, 0)
	else:
		ACCENT = team_accent(c1, c2)
		TEAM_1 = c1
		TEAM_2 = c2
	_fit_accent()
	_repaint_theme()


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


static func _fit_accent() -> void:
	ACCENT = readable_on(ACCENT, [BG, SURFACE, SURFACE_2], 4.5)
	ON_ACCENT = on_color(ACCENT)
	if ON_ACCENT.get_luminance() < 0.5 and _same_rgb(ACCENT, D_GOLD):
		ON_ACCENT = ON_GOLD
	ACCENT_DARK = ACCENT
	for amt: float in [0.25, 0.2, 0.15, 0.1, 0.06]:
		var d := ACCENT.darkened(amt)
		if contrast(ON_ACCENT, d) >= 3.0:
			ACCENT_DARK = d
			break


## O tema é gravado com o dourado; aqui o dourado do tema vira o destaque atual.
static func _repaint_theme() -> void:
	var th := ThemeDB.get_project_theme()
	if th == null:
		return
	th.set_block_signals(true)
	if _theme_refs.is_empty():
		for type in th.get_type_list():
			for nm in th.get_stylebox_list(type):
				var sb := th.get_stylebox(nm, type) as StyleBoxFlat
				if sb == null:
					continue
				for prop in ["bg_color", "border_color"]:
					var c: Color = sb.get(prop)
					if _is_gold(c):
						_theme_refs.append([sb, prop, c])
			for nm in th.get_color_list(type):
				var c := th.get_color(nm, type)
				if _is_gold(c):
					_theme_refs.append([th, [type, nm], c])
	for r: Array in _theme_refs:
		var orig: Color = r[2]
		var nc := Color(ACCENT, orig.a) if _same_rgb(orig, D_GOLD) else (Color(ACCENT_DARK, orig.a) if _same_rgb(orig, D_GOLD_DARK) else Color(ON_ACCENT, orig.a))
		if r[1] is Array:
			(r[0] as Theme).set_color(r[1][1], r[1][0], nc)
		else:
			(r[0] as Object).set(String(r[1]), nc)
	th.set_block_signals(false)
	th.emit_changed()


static func _is_gold(c: Color) -> bool:
	return _same_rgb(c, D_GOLD) or _same_rgb(c, D_GOLD_DARK) or _same_rgb(c, ON_GOLD)


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


## Escala de atributos e notas (DESIGN.md › Colors): sálvia, oliva, ocre, ferrugem, tijolo.
static func attr_color(v: float) -> Color:
	if v >= 80.0:
		return Color("#7FB28C")
	if v >= 70.0:
		return Color("#9DB46C")
	if v >= 60.0:
		return Color("#C4AE5C")
	if v >= 50.0:
		return Color("#C98A4B")
	return Color("#C75B5B")
