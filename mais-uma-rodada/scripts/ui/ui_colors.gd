class_name UIColors
extends RefCounted
## Paleta do jogo em dois modos: escuro (preto e grafite neutros, texto branco) e claro
## (cinzas quentes, texto quase preto), com o destaque na cor do clube.
## Use estas cores em vez de cores soltas; elas mudam quando o modo muda.

## Paleta escura original (é a que está gravada no tema do projeto).
const D_BG := Color("#0A0B0D")
const D_SURFACE := Color("#141518")
const D_SURFACE_2 := Color("#1C1D21")
const D_SURFACE_3 := Color("#26282D")
const D_LINE := Color("#2F3137")
const D_TEXT := Color("#F2F3F5")
const D_MUTED := Color("#9EA2AA")
const D_DIM := Color("#63676F")
const D_GOLD := Color("#FFC940")
const D_GOLD_DARK := Color("#C99A1E")
const D_GREEN := Color("#3DBE7A")
const D_RED := Color("#E5484D")
const D_BLUE := Color("#4EA8DE")
const D_ORANGE := Color("#F0A35E")
## Paleta clara: contraste de texto AA (4,5:1 ou mais) sobre o branco e sobre o fundo.
const LIGHT := {
	"BG": Color("#ECEEF1"), "SURFACE": Color("#FFFFFF"), "SURFACE_2": Color("#F5F6F8"),
	"SURFACE_3": Color("#E1E4E8"), "LINE": Color("#C5CAD1"), "TEXT": Color("#101216"),
	"MUTED": Color("#484D55"), "DIM": Color("#5C6169"), "GOLD": Color("#8A5E00"),
	"GOLD_DARK": Color("#6B4900"), "GREEN": Color("#157A43"), "RED": Color("#C4262B"),
	"BLUE": Color("#1766A6"), "ORANGE": Color("#A5550A"),
}
const DARK := {
	"BG": D_BG, "SURFACE": D_SURFACE, "SURFACE_2": D_SURFACE_2, "SURFACE_3": D_SURFACE_3,
	"LINE": D_LINE, "TEXT": D_TEXT, "MUTED": D_MUTED, "DIM": D_DIM, "GOLD": D_GOLD,
	"GOLD_DARK": D_GOLD_DARK, "GREEN": D_GREEN, "RED": D_RED, "BLUE": D_BLUE, "ORANGE": D_ORANGE,
}
## Cores do tema escuro que não são da paleta acima e seus pares no modo claro.
const LIGHT_EXTRA := [
	[Color("#0E0F11"), Color("#E4E7EB")],
	[Color("#1F2126"), Color("#E9EBEE")],
	[Color("#FFB3B5"), Color("#B3261E")],
	[Color("#4A2224"), Color("#FBD9DA")],
	[Color("#3A1C1E"), Color("#FDE6E6")],
	[Color("#FFD466"), Color("#6B4900")],
]

## true = modo claro.
static var light := false
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
## Destaque da interface: dourado no menu; na carreira, a cor do clube do jogador.
static var ACCENT := D_GOLD
static var ACCENT_DARK := D_GOLD_DARK
static var ON_ACCENT := ON_GOLD
## Cores do clube (faixa da barra superior); transparentes fora de uma carreira.
static var TEAM_1 := Color(0, 0, 0, 0)
static var TEAM_2 := Color(0, 0, 0, 0)
static var _theme_refs: Array = [] # [objeto, propriedade ou [tipo, nome], cor original]
static var _applied := ""
const PITCH_A := Color("#2E7D4B")
const PITCH_B := Color("#2A7445")
const PITCH_LINE := Color(0.87, 0.95, 0.89, 0.75)


## Cor de destaque a partir das cores do clube: a mais viva que aparece bem no fundo.
## Time de preto (ou marinho) usa a outra cor; time de branco com cor forte usa a cor forte.
## No modo claro a cor escurece até ter contraste com o fundo claro.
static func team_accent(c1: Color, c2: Color) -> Color:
	var best := GOLD
	var best_score := -1.0
	for c: Color in [c1, c2]:
		var col := c
		for _i in 10:
			if light:
				if col.get_luminance() <= 0.40:
					break
				col = col.darkened(0.14)
			else:
				if col.get_luminance() >= 0.34:
					break
				col = col.lightened(0.14)
		var sat := col.s
		var score: float
		if light:
			# Preto puro vira texto, não destaque; cores vivas ganham.
			score = sat * 1.4 + (0.35 if c.get_luminance() < 0.88 else 0.0) - absf(col.get_luminance() - 0.3) * 0.5
			if c.get_luminance() < 0.1 and c.s < 0.15:
				score = 0.25
			if c.get_luminance() > 0.93 and c.s < 0.08:
				score = 0.1
		else:
			score = sat * 1.4 + (0.35 if c.get_luminance() > 0.12 else 0.0) - absf(col.get_luminance() - 0.55) * 0.5
			if c.get_luminance() > 0.93 and c.s < 0.08:
				score = 0.25 # branco puro: só se não houver outra cor boa
		if score > best_score:
			best_score = score
			best = col
	return best


## Liga o modo claro (true) ou escuro (false): troca a paleta, o tema e o fundo.
static func set_light(on: bool) -> void:
	if on == light and not _theme_refs.is_empty():
		return
	light = on
	var pal: Dictionary = LIGHT if on else DARK
	BG = pal["BG"]
	SURFACE = pal["SURFACE"]
	SURFACE_2 = pal["SURFACE_2"]
	SURFACE_3 = pal["SURFACE_3"]
	LINE = pal["LINE"]
	TEXT = pal["TEXT"]
	MUTED = pal["MUTED"]
	DIM = pal["DIM"]
	GOLD = pal["GOLD"]
	GOLD_DARK = pal["GOLD_DARK"]
	GREEN = pal["GREEN"]
	RED = pal["RED"]
	BLUE = pal["BLUE"]
	ORANGE = pal["ORANGE"]
	RenderingServer.set_default_clear_color(BG)
	# Recalcula o destaque (a cor do clube muda de tom com o modo) e repinta o tema.
	var key := _applied
	_applied = "~"
	if key == "":
		_set_accent(null, null)
	else:
		var parts := key.split("|")
		_set_accent(Color(parts[0]), Color(parts[1]))
	_applied = key
	_repaint_theme()


## Pinta a interface com as cores do clube (ou volta ao dourado com `club` nulo).
static func apply_club(club: Club) -> void:
	var key := "" if club == null else "%s|%s" % [club.color1, club.color2]
	if key == _applied:
		return
	_applied = key
	if club == null:
		_set_accent(null, null)
	else:
		_set_accent(Color(club.color1), Color(club.color2))
	_repaint_theme()


static func _set_accent(c1: Variant, c2: Variant) -> void:
	if c1 == null:
		ACCENT = GOLD
		ACCENT_DARK = GOLD_DARK
		ON_ACCENT = Color.WHITE if light else ON_GOLD
		TEAM_1 = Color(0, 0, 0, 0)
		TEAM_2 = Color(0, 0, 0, 0)
		return
	ACCENT = team_accent(c1, c2)
	ACCENT_DARK = ACCENT.darkened(0.25)
	ON_ACCENT = Color("#12161C") if ACCENT.get_luminance() > 0.5 else Color.WHITE
	TEAM_1 = c1
	TEAM_2 = c2


## Troca, no tema do projeto, cada cor da paleta escura original pela cor atual: o dourado
## vira a cor de destaque e, no modo claro, fundos, textos e linhas viram os pares claros.
static func _repaint_theme() -> void:
	var th := ThemeDB.get_project_theme()
	if th == null:
		return
	if _theme_refs.is_empty():
		for type in th.get_type_list():
			for nm in th.get_stylebox_list(type):
				var sb := th.get_stylebox(nm, type) as StyleBoxFlat
				if sb == null:
					continue
				for prop in ["bg_color", "border_color", "shadow_color"]:
					_theme_refs.append([sb, prop, sb.get(prop)])
			for nm in th.get_color_list(type):
				_theme_refs.append([th, [type, nm], th.get_color(nm, type)])
	for r: Array in _theme_refs:
		var nc := themed(r[2])
		if r[1] is Array:
			(r[0] as Theme).set_color(r[1][1], r[1][0], nc)
		else:
			(r[0] as Object).set(String(r[1]), nc)
	# Interruptores desenhados aqui: o padrão do Godot some no fundo claro e não usa o destaque.
	var on := _switch_icon(ACCENT, ON_ACCENT if ON_ACCENT.get_luminance() > 0.5 else Color.WHITE, true)
	var off := _switch_icon(Color("#AEB4BD") if light else Color("#3A3D44"), Color.WHITE if light else Color("#B4B8C0"), false)
	th.set_icon(&"checked", "CheckButton", on)
	th.set_icon(&"unchecked", "CheckButton", off)
	th.set_icon(&"checked_disabled", "CheckButton", on)
	th.set_icon(&"unchecked_disabled", "CheckButton", off)
	th.set_icon(&"checked_mirrored", "CheckButton", on)
	th.set_icon(&"unchecked_mirrored", "CheckButton", off)


## Interruptor (trilho arredondado + botão), com borda suavizada; ligado = botão à direita.
static func _switch_icon(track: Color, knob: Color, on: bool) -> ImageTexture:
	var w := 76
	var h := 44
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var r := h * 0.5
	var kr := r - 5.0
	var kc := Vector2(w - r if on else r, r)
	for y in h:
		for x in w:
			var p := Vector2(x + 0.5, y + 0.5)
			# Distância ao trilho (cápsula) e ao botão (círculo), com 1 px de antisserrilhado.
			var cx := clampf(p.x, r, w - r)
			var dt := p.distance_to(Vector2(cx, r)) - r
			var at := clampf(0.5 - dt, 0.0, 1.0)
			var ak := clampf(0.5 - (p.distance_to(kc) - kr), 0.0, 1.0)
			if at <= 0.0:
				continue
			var col := track.lerp(knob, ak)
			col.a = at
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


## Cor da paleta escura original convertida para o modo e o destaque atuais (mantém o alfa).
## Serve também para cores fixas do código escritas pensando no fundo escuro.
static func themed(orig: Color) -> Color:
	var nc := orig
	var accents := [D_GOLD, D_GOLD_DARK, ON_GOLD]
	var news := [ACCENT, ACCENT_DARK, ON_ACCENT]
	var found := false
	for k in accents.size():
		if _same_rgb(orig, accents[k]):
			nc = news[k]
			found = true
			break
	if not found and light:
		for key: String in DARK:
			if _same_rgb(orig, DARK[key]):
				nc = LIGHT[key]
				found = true
				break
		if not found:
			for pair: Array in LIGHT_EXTRA:
				if _same_rgb(orig, pair[0]):
					nc = pair[1]
					found = true
					break
		# Véus brancos translúcidos (realces sobre o fundo escuro) viram véus pretos.
		if not found and orig.a < 1.0 and _same_rgb(orig, Color.WHITE):
			nc = Color.BLACK
	nc.a = orig.a
	return nc


static func _same_rgb(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 and absf(a.b - b.b) < 0.01


static func result_color(r: String) -> Color:
	match r:
		"V":
			return GREEN
		"D":
			return RED
		"E":
			return ORANGE
	return DIM


static func morale_color(m: float) -> Color:
	if m >= 75.0:
		return GREEN
	if m >= 55.0:
		return Color("#3F8F4A") if light else Color("#8FD694")
	if m >= 35.0:
		return ORANGE
	return RED


static func morale_label(m: float) -> String:
	if m >= 80.0:
		return "Excelente"
	if m >= 65.0:
		return "Boa"
	if m >= 45.0:
		return "Normal"
	if m >= 30.0:
		return "Baixa"
	return "Péssima"


static func fans_label(m: float) -> String:
	if m >= 85.0:
		return "Apaixonada"
	if m >= 70.0:
		return "Empolgada"
	if m >= 55.0:
		return "Satisfeita"
	if m >= 40.0:
		return "Indiferente"
	if m >= 25.0:
		return "Frustrada"
	return "Revoltada"


## Cor usada como texto (ou traço fino) sobre o fundo da interface: no modo claro, tons claros
## escurecem até ficarem legíveis sobre o branco; no escuro a cor fica como está.
static func ink(c: Color) -> Color:
	if not light:
		return c
	var col := c
	for _i in 10:
		if col.get_luminance() <= 0.42:
			break
		col = col.darkened(0.12)
	return col


## Cor legível (preta ou branca) sobre um fundo.
static func on_color(bg: Color) -> Color:
	return Color("#111111") if bg.get_luminance() > 0.6 else Color.WHITE
