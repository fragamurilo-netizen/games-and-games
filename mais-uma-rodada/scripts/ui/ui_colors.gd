class_name UIColors
extends RefCounted
## Paleta do jogo em dois modos: escuro (preto e grafite neutros, texto branco) e claro
## (cinzas quentes, texto quase preto), com o destaque na cor do clube.
## Use estas cores em vez de cores soltas; elas mudam quando o modo muda.

## Paleta escura (é a que está gravada no tema do projeto). Grafite azulado em camadas, como
## as interfaces de transmissão: fundo quase preto, superfícies que sobem de tom a cada nível.
const D_BG := Color("#090B0F")
const D_SURFACE := Color("#12151B")
const D_SURFACE_2 := Color("#1A1E26")
const D_SURFACE_3 := Color("#242A34")
const D_LINE := Color("#2B313C")
const D_TEXT := Color("#F3F5F8")
const D_MUTED := Color("#9AA2AF")
const D_DIM := Color("#848C99")
const D_GOLD := Color("#FFC940")
const D_GOLD_DARK := Color("#C99A1E")
const D_GREEN := Color("#34C77B")
const D_RED := Color("#EF4B55")
const D_BLUE := Color("#4DA8F0")
const D_ORANGE := Color("#F5A45B")
## Paleta clara: contraste de texto AA (4,5:1 ou mais) sobre o branco e sobre o fundo.
const LIGHT := {
	"BG": Color("#EDEFF3"), "SURFACE": Color("#FFFFFF"), "SURFACE_2": Color("#F4F6F9"),
	"SURFACE_3": Color("#E2E6EC"), "LINE": Color("#D3D8E0"), "TEXT": Color("#0E1117"),
	"MUTED": Color("#474E5A"), "DIM": Color("#5B6270"), "GOLD": Color("#8A5E00"),
	"GOLD_DARK": Color("#6B4900"), "GREEN": Color("#137A43"), "RED": Color("#C4262B"),
	"BLUE": Color("#1766A6"), "ORANGE": Color("#A5550A"),
}
const DARK := {
	"BG": D_BG, "SURFACE": D_SURFACE, "SURFACE_2": D_SURFACE_2, "SURFACE_3": D_SURFACE_3,
	"LINE": D_LINE, "TEXT": D_TEXT, "MUTED": D_MUTED, "DIM": D_DIM, "GOLD": D_GOLD,
	"GOLD_DARK": D_GOLD_DARK, "GREEN": D_GREEN, "RED": D_RED, "BLUE": D_BLUE, "ORANGE": D_ORANGE,
}
## Tons da paleta escura anterior ainda escritos em algumas telas: viram o tom novo equivalente.
const LEGACY := {
	"0A0B0D": "BG", "141518": "SURFACE", "1C1D21": "SURFACE_2", "26282D": "SURFACE_3",
	"2F3137": "LINE", "F2F3F5": "TEXT", "9EA2AA": "MUTED", "63676F": "DIM", "3DBE7A": "GREEN",
	"E5484D": "RED", "4EA8DE": "BLUE", "F0A35E": "ORANGE", "646C79": "DIM",
}
## Cores do tema escuro que não são da paleta acima e seus pares no modo claro.
const LIGHT_EXTRA := [
	[Color("#0E0F11"), Color("#E4E7EB")],
	[Color("#0D1015"), Color("#FFFFFF")],
	[Color("#1E232C"), Color("#DDE2E9")],
	[Color("#1F2126"), Color("#E9EBEE")],
	[Color("#20252F"), Color("#E9ECF1")],
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
## Fundo e menus tingidos com a cor do clube/liga (0 = neutro). Guarda a cor-base do tingimento.
static var tint := 0.0
static var _tint_col := Color(0, 0, 0, 0)
const TINT_KEYS := ["BG", "SURFACE", "SURFACE_2", "SURFACE_3", "LINE"]
## Cores de texto conferidas contra o fundo tingido (ver _apply_palette).
const INK_KEYS := ["MUTED", "DIM", "GOLD", "GREEN", "RED", "BLUE", "ORANGE"]
## Valor atual (tingido/ajustado) de cada chave da paleta em TINT_KEYS e INK_KEYS.
static var _cur := {}
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
	_apply_palette()
	# Recalcula o destaque (a cor do clube muda de tom com o modo) e repinta o tema.
	var key := _applied
	_applied = "~"
	if key == "":
		_set_accent(null, null)
	else:
		var parts := key.split("|")
		_set_accent(Color(parts[0]), Color(parts[1]))
		_tint_col = ACCENT
		_apply_palette()
	_applied = key
	_repaint_theme()


## Pinta a interface com as cores do clube (ou volta ao dourado com `club` nulo).
static func apply_club(club: Club, tint_amount := 0.0) -> void:
	if club == null:
		apply_colors(null, null, 0.0)
	else:
		apply_colors(Color(club.color1), Color(club.color2), tint_amount)


## Cores da interface conforme as opções: dourado, do clube ou da liga do clube, com o tingimento
## escolhido para fundo e menus. `club` nulo (menu principal) = dourado.
static func apply_colors_for(club: Club) -> void:
	var t: float = AppSettings.TINT_AMOUNTS[AppSettings.bg_tint]
	if club == null or AppSettings.color_source == 0:
		apply_colors(null, null, 0.0)
		return
	if AppSettings.color_source == 2:
		var cols: Array = DatabaseManager.league_cfg(club.league_id).get("colors", [])
		if cols.size() >= 2:
			apply_colors(Color(String(cols[0])), Color(String(cols[1])), t)
			return
	apply_colors(Color(club.color1), Color(club.color2), t)


## Cor da tela conforme o contexto: por padrão o clube do usuário; tabelas e competições nas
## cores da liga; outro clube (ou jogador de outro clube) nas cores dele.
## ctx: {} | {"club": Club} | {"league": id de liga ou copa}
static func apply_context(user: Club, ctx: Dictionary) -> void:
	if user == null or AppSettings.color_source == 0:
		apply_colors_for(user)
		return
	var t: float = AppSettings.TINT_AMOUNTS[AppSettings.bg_tint]
	var c: Variant = ctx.get("club", null)
	if c != null and c is Club:
		apply_colors(Color((c as Club).color1), Color((c as Club).color2), t)
		return
	var lid := String(ctx.get("league", ""))
	if lid != "":
		var cfg: Dictionary = DatabaseManager.league_cfg(lid) if DatabaseManager.has_league(lid) else DatabaseManager.cup_cfg(lid)
		var cols: Array = cfg.get("colors", [])
		if cols.size() >= 2:
			apply_colors(Color(String(cols[0])), Color(String(cols[1])), t)
			return
	apply_colors_for(user)


## Destaque com duas cores (clube, liga) e, opcionalmente, fundo e menus tingidos com elas.
static func apply_colors(c1: Variant, c2: Variant, tint_amount := 0.0) -> void:
	var key := "" if c1 == null else "#%s|#%s|%.2f" % [(c1 as Color).to_html(false), (c2 as Color).to_html(false), tint_amount]
	if key == _applied:
		return
	_applied = key
	tint = tint_amount if c1 != null else 0.0
	_set_accent(c1, c2)
	_tint_col = ACCENT if c1 != null else Color(0, 0, 0, 0)
	_apply_palette()
	_repaint_theme()


## Fundo, superfícies e linhas da paleta atual, com o tingimento aplicado; depois os textos
## (secundário, apagado e as cores de estado) são conferidos contra esses fundos, porque o
## tingimento forte aproxima o fundo do tom dos textos.
static func _apply_palette() -> void:
	var pal: Dictionary = LIGHT if light else DARK
	for k: String in TINT_KEYS:
		_cur[k] = _tinted(pal[k])
	BG = _cur["BG"]
	SURFACE = _cur["SURFACE"]
	SURFACE_2 = _cur["SURFACE_2"]
	SURFACE_3 = _cur["SURFACE_3"]
	LINE = _cur["LINE"]
	var grounds := [BG, SURFACE, SURFACE_2]
	for k: String in INK_KEYS:
		var bgs := grounds + [SURFACE_3] if k == "MUTED" else grounds
		_cur[k] = readable_on(pal[k], bgs, 4.5) if tint > 0.0 else pal[k]
	TEXT = pal["TEXT"]
	MUTED = _cur["MUTED"]
	DIM = _cur["DIM"]
	GOLD = _cur["GOLD"]
	GREEN = _cur["GREEN"]
	RED = _cur["RED"]
	BLUE = _cur["BLUE"]
	ORANGE = _cur["ORANGE"]
	RenderingServer.set_default_clear_color(BG)
	# Com o fundo tingido o contraste do destaque muda: confere de novo.
	_fit_accent()


## Mesmo brilho, com o matiz da cor do time (fundos continuam escuros no modo escuro e claros no
## claro). A luminância fica perto da original: matizes escuros (azul, vermelho) escureciam demais
## o modo claro e clareavam demais o escuro, e o texto perdia contraste.
static func _tinted(c: Color) -> Color:
	if tint <= 0.0 or _tint_col.a <= 0.0:
		return c
	# Destaque sem cor (clube de preto e branco): nada de matiz inventado (o vermelho do h = 0).
	# No claro a saturação é menor: com o brilho mantido, um verde forte virava menta néon.
	var sat := clampf(_tint_col.s, 0.3, 0.55 if light else 0.85) if _tint_col.s >= 0.15 else 0.0
	var target := Color.from_hsv(_tint_col.h, sat, c.v)
	# O fundo quase preto precisa de um pouco mais de luz para a cor aparecer.
	if not light:
		target = Color.from_hsv(_tint_col.h, sat, minf(1.0, c.v * (1.0 + tint * 1.2) + 0.02 * tint))
	var col := c.lerp(target, tint)
	var l0 := _lin_lum(c)
	var lo := l0 * (1.0 - 0.12 * tint) if light else l0
	var hi := l0 if light else l0 * (1.0 + 1.6 * tint) + 0.002 * tint
	var l := _lin_lum(col)
	if l >= lo and l <= hi:
		return col
	# Busca binária pelo quanto clarear (ou escurecer) até voltar à faixa.
	var want := clampf(l, lo, hi)
	var a := 0.0
	var b := 1.0
	var best := col
	for _i in 14:
		var m := (a + b) * 0.5
		var t := col.lightened(m) if l < lo else col.darkened(m)
		best = t
		var lt := _lin_lum(t)
		if (lt < want) == (l < lo):
			a = m
		else:
			b = m
	return best


static func _lin_lum(c: Color) -> float:
	var l := c.srgb_to_linear()
	return 0.2126 * l.r + 0.7152 * l.g + 0.0722 * l.b


static func _set_accent(c1: Variant, c2: Variant) -> void:
	if c1 == null:
		ACCENT = GOLD
		ACCENT_DARK = GOLD_DARK
		ON_ACCENT = Color.WHITE if light else ON_GOLD
		TEAM_1 = Color(0, 0, 0, 0)
		TEAM_2 = Color(0, 0, 0, 0)
		_fit_accent()
		return
	ACCENT = team_accent(c1, c2)
	TEAM_1 = c1
	TEAM_2 = c2
	_fit_accent()


## Ajusta o destaque para ser legível como texto sobre o fundo e as superfícies (4,5:1) e
## escolhe o texto que vai por cima dele (quase preto ou branco, o de maior contraste).
## Clubes de branco, amarelo ou preto continuam com a sua cor, só com o tom corrigido.
static func _fit_accent() -> void:
	ACCENT = readable_on(ACCENT, [BG, SURFACE, SURFACE_2], 4.5)
	ON_ACCENT = on_color(ACCENT)
	if ON_ACCENT.get_luminance() < 0.5 and _same_rgb(ACCENT, D_GOLD):
		ON_ACCENT = ON_GOLD # dourado mantém o texto marrom-escuro de sempre
	# Tom pressionado/base do botão primário: mais escuro, sem perder a leitura do texto.
	ACCENT_DARK = ACCENT
	for amt: float in [0.25, 0.2, 0.15, 0.1, 0.06]:
		var d := ACCENT.darkened(amt)
		if contrast(ON_ACCENT, d) >= 3.0:
			ACCENT_DARK = d
			break
	if ACCENT.get_luminance() < 0.08:
		# Destaque quase preto: escurecer não aparece, então o tom pressionado clareia.
		ACCENT_DARK = ACCENT.lightened(0.18)


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
	_fix_states(th)
	# Interruptores desenhados aqui: o padrão do Godot some no fundo claro e não usa o destaque.
	var on := _switch_icon(ACCENT, ON_ACCENT if ON_ACCENT.get_luminance() > 0.5 else Color.WHITE, true)
	var off := _switch_icon(Color("#AEB4BD") if light else Color("#3A3D44"), Color.WHITE if light else Color("#B4B8C0"), false)
	th.set_icon(&"checked", "CheckButton", on)
	th.set_icon(&"unchecked", "CheckButton", off)
	th.set_icon(&"checked_disabled", "CheckButton", on)
	th.set_icon(&"unchecked_disabled", "CheckButton", off)
	th.set_icon(&"checked_mirrored", "CheckButton", on)
	th.set_icon(&"unchecked_mirrored", "CheckButton", off)


## Estados dos botões que não saem do simples troca-cor: o "passar por cima" do primário acompanha
## o destaque (antes era sempre amarelo) e, em telas de toque, o passar por cima some. No celular o
## Godot deixa o ponteiro onde foi o último toque, então o botão ficava "aceso" depois de solto.
static func _fix_states(th: Theme) -> void:
	var ph := th.get_stylebox(&"hover", &"PrimaryButton") as StyleBoxFlat
	if ph != null:
		ph.bg_color = hover_of(ACCENT)
		ph.border_color = ACCENT_DARK
	if not touch_only():
		return
	for type in th.get_type_list():
		if not (th.has_stylebox(&"normal", type) and th.has_stylebox(&"hover", type)) or type == &"LineEdit":
			continue
		th.set_stylebox(&"hover", type, th.get_stylebox(&"normal", type))
		if th.has_stylebox(&"pressed", type):
			th.set_stylebox(&"hover_pressed", type, th.get_stylebox(&"pressed", type))
		for pair: Array in [[&"font_hover_color", &"font_color"], [&"font_hover_pressed_color", &"font_pressed_color"],
				[&"icon_hover_color", &"icon_normal_color"], [&"icon_hover_pressed_color", &"icon_pressed_color"]]:
			if th.has_color(pair[1], type):
				th.set_color(pair[0], type, th.get_color(pair[1], type))


## Aparelho só de toque (celular, tablet, navegador no celular): sem estado de "passar por cima".
static func touch_only() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")


## Fundo de "passar por cima" de um botão cheio na cor `c`: um passo na direção que aumenta o
## contraste com o texto dele (clareia sob texto escuro, escurece sob texto branco).
static func hover_of(c: Color) -> Color:
	var fg := on_color(c)
	if fg.get_luminance() < 0.5:
		return c.lightened(0.16) if c.get_luminance() < 0.92 else c.darkened(0.07)
	return c.darkened(0.14) if c.get_luminance() > 0.1 else c.lightened(0.14)


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
	var legacy: String = LEGACY.get(orig.to_html(false).to_upper(), "")
	if legacy != "":
		orig = Color(DARK[legacy], orig.a)
		nc = orig
		found = not light
	for k in accents.size():
		if found:
			break
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
	# Fundos tingidos e textos ajustados ao tingimento.
	if not _cur.is_empty() and not _same_rgb(nc, ACCENT):
		var pal: Dictionary = LIGHT if light else DARK
		for k: String in _cur:
			if _same_rgb(nc, pal[k]):
				nc = _cur[k]
				break
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
	return readable_on(c, [SURFACE, SURFACE_2], 4.5)


## Cor legível (quase preta ou branca) sobre um fundo: a de maior contraste.
static func on_color(bg: Color) -> Color:
	var dark := Color("#111111")
	return dark if contrast(dark, bg) >= contrast(Color.WHITE, bg) else Color.WHITE


## Luminância relativa (WCAG), com o fundo da interface por trás de cores translúcidas.
static func rel_luminance(c: Color) -> float:
	var col := c
	if col.a < 1.0:
		col = BG.lerp(Color(col.r, col.g, col.b), col.a)
	var l := col.srgb_to_linear()
	return 0.2126 * l.r + 0.7152 * l.g + 0.0722 * l.b


## Razão de contraste entre duas cores (1 a 21; texto comum pede 4,5, texto grande e ícones 3).
static func contrast(a: Color, b: Color) -> float:
	var la := rel_luminance(a)
	var lb := rel_luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


## A mesma cor, clareada ou escurecida só o necessário para ter `ratio` de contraste com
## todos os fundos de `bgs` (mantém o matiz: o verde continua verde).
static func readable_on(c: Color, bgs: Array, ratio: float = 4.5) -> Color:
	if _min_contrast(c, bgs) >= ratio:
		return c
	# Fundos claros pedem texto mais escuro; escuros, mais claro.
	var bg_l := 0.0
	for bg: Color in bgs:
		bg_l += rel_luminance(bg)
	var to_dark := bg_l / maxf(1.0, bgs.size()) > 0.18
	# Anda pelo brilho (HSV) antes de tirar saturação: o marinho vira um azul vivo, não um cinza.
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


## Cor que identifica o clube em fundos e degradês: a mais saturada das duas; em clubes de
## preto e branco, o tom que não é branco (branco sobre o fundo claro some).
static func club_tone(c: Club) -> Color:
	if c == null:
		return ACCENT
	return tone_of(Color(c.color1), Color(c.color2))


## Tom de identidade a partir das duas cores de um clube (também para saves, sem o Club).
static func tone_of(a: Color, b: Color) -> Color:
	if a.s < 0.2 and b.s >= 0.2:
		return b
	if b.s > a.s + 0.25:
		return b
	if a.s < 0.2 and b.s < 0.2:
		return a if a.get_luminance() < b.get_luminance() else b
	return a
