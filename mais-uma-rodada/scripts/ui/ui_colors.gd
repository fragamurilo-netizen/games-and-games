class_name UIColors
extends RefCounted
## Paleta do jogo (escura, elegante, levemente retrô). Use estas constantes em vez de cores soltas.

const BG := Color("#0E1621")
const SURFACE := Color("#162231")
const SURFACE_2 := Color("#1D2B3C")
const SURFACE_3 := Color("#26374B")
const LINE := Color("#2A3B50")
const TEXT := Color("#EAF0F6")
const MUTED := Color("#8FA3B8")
const DIM := Color("#5D7189")
const GOLD := Color("#FFC940")
const GOLD_DARK := Color("#C99A1E")
const ON_GOLD := Color("#1A1300")
## Destaque da interface: dourado no menu; na carreira, a cor do clube do jogador.
static var ACCENT := GOLD
static var ACCENT_DARK := GOLD_DARK
static var ON_ACCENT := ON_GOLD
## Cores do clube (faixa da barra superior); transparentes fora de uma carreira.
static var TEAM_1 := Color(0, 0, 0, 0)
static var TEAM_2 := Color(0, 0, 0, 0)
static var _theme_refs: Array = [] # [objeto, propriedade ou [tipo, nome], cor original]
static var _applied := ""
const GREEN := Color("#3DBE7A")
const RED := Color("#E5484D")
const BLUE := Color("#4EA8DE")
const ORANGE := Color("#F0A35E")
const PITCH_A := Color("#2E7D4B")
const PITCH_B := Color("#2A7445")
const PITCH_LINE := Color(0.87, 0.95, 0.89, 0.75)


## Cor de destaque a partir das cores do clube: a mais viva que aparece bem no fundo escuro.
## Time de preto (ou marinho) usa a outra cor; time de branco com cor forte usa a cor forte.
static func team_accent(c1: Color, c2: Color) -> Color:
	var best := GOLD
	var best_score := -1.0
	for c: Color in [c1, c2]:
		var col := c
		# Clareia até ter contraste com o fundo
		for _i in 8:
			if col.get_luminance() >= 0.34:
				break
			col = col.lightened(0.14)
		var sat := col.s
		var score := sat * 1.4 + (0.35 if c.get_luminance() > 0.12 else 0.0) - absf(col.get_luminance() - 0.55) * 0.5
		if c.get_luminance() > 0.93 and c.s < 0.08:
			score = 0.25 # branco puro: só se não houver outra cor boa
		if score > best_score:
			best_score = score
			best = col
	return best


## Pinta a interface com as cores do clube (ou volta ao dourado com `club` nulo).
static func apply_club(club: Club) -> void:
	var key := "" if club == null else "%s|%s" % [club.color1, club.color2]
	if key == _applied:
		return
	_applied = key
	if club == null:
		ACCENT = GOLD
		ACCENT_DARK = GOLD_DARK
		ON_ACCENT = ON_GOLD
		TEAM_1 = Color(0, 0, 0, 0)
		TEAM_2 = Color(0, 0, 0, 0)
	else:
		var c1 := Color(club.color1)
		var c2 := Color(club.color2)
		ACCENT = team_accent(c1, c2)
		ACCENT_DARK = ACCENT.darkened(0.25)
		ON_ACCENT = Color("#12161C") if ACCENT.get_luminance() > 0.5 else Color.WHITE
		TEAM_1 = c1
		TEAM_2 = c2
	_repaint_theme()


## Troca, no tema do projeto, toda cor que era o dourado pela cor de destaque atual.
static func _repaint_theme() -> void:
	var th := ThemeDB.get_project_theme()
	if th == null:
		return
	if _theme_refs.is_empty():
		var olds := [GOLD, GOLD_DARK, ON_GOLD]
		for type in th.get_type_list():
			for nm in th.get_stylebox_list(type):
				var sb := th.get_stylebox(nm, type) as StyleBoxFlat
				if sb == null:
					continue
				for prop in ["bg_color", "border_color"]:
					var col: Color = sb.get(prop)
					for k in olds.size():
						if _same_rgb(col, olds[k]):
							_theme_refs.append([sb, prop, col, k])
			for nm in th.get_color_list(type):
				var col2 := th.get_color(nm, type)
				for k in olds.size():
					if _same_rgb(col2, olds[k]):
						_theme_refs.append([th, [type, nm], col2, k])
	var news := [ACCENT, ACCENT_DARK, ON_ACCENT]
	for r: Array in _theme_refs:
		var orig: Color = r[2]
		var nc: Color = news[int(r[3])]
		nc.a = orig.a
		if r[1] is Array:
			(r[0] as Theme).set_color(r[1][1], r[1][0], nc)
		else:
			(r[0] as Object).set(String(r[1]), nc)


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
		return Color("#8FD694")
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


## Cor legível (preta ou branca) sobre um fundo.
static func on_color(bg: Color) -> Color:
	return Color("#111111") if bg.get_luminance() > 0.6 else Color.WHITE
