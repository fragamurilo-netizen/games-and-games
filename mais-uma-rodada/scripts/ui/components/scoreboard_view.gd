class_name ScoreboardView
extends PanelContainer
## Placar da partida no estilo das transmissões de TV (desenhos originais, sem marcas reais).
## O desenho vem da competição (ScoreboardTheme.layout_for: dados, mods ou Editor):
##   faixa    — faixa arredondada, placar numa caixa com borda
##   tv       — barra reta, blocos na cor de cada time e placar cheio na cor da liga
##   angular  — peças inclinadas
##   capsula  — tudo arredondado, com brilho na cor da competição
##   classico — placar de estádio antigo: caixa preta e números âmbar
##   compacto — selo no canto: logo, siglas em fichas coloridas, placar e relógio numa linha só
##   painel   — um time por linha (placar empilhado), relógio numa coluna ao lado
##   neon     — vidro escuro, filetes acesos na cor da competição e números grandes
## Em todos: logo da competição, relógio com acréscimo ("+4"), aviso de gol na ficha do time,
## estado do jogo (intervalo, fim, pênaltis) e o agregado dos mata-matas de ida e volta.
##
## A tela da partida lê `score_proxy` e `clock_proxy` (textos que ela mesma monta) e chama
## sync() a cada atualização; home_name/away_name, home_scorers/away_scorers, ticker e bug são os
## mesmos rótulos de antes.

const LIMITS := [45, 90, 105, 120]
const AMBER := Color("#FFB000")

var th: Dictionary = {}
var layout := "faixa"
var comp := ""
var abbrs: Array = ["", ""]
var cols: Array = [] # [casa1, casa2, fora1, fora2]

var score_proxy: Label
var clock_proxy: Label
var home_name: Label
var away_name: Label
var home_scorers: Label
var away_scorers: Label
var ticker: Label
var bug: Control

var _digits: Array = [null, null]
var _chips: Array = [null, null]
var _score_box: Control
var _clock: Label
var _clock_box: PanelContainer
var _extra_box: PanelContainer
var _extra: Label
var _state_box: PanelContainer
var _state: Label
var _goal_box: PanelContainer
var _goal: Label
var _pens: Label
var _agg_box: PanelContainer
var _agg: Label
var _last: Array = [-1, -1]
var _goal_serial := 0
var _cur_state := ""
var _cur_extra := ""


## Monta o placar. `teams`: [casa, fora] (Club); `colors`: as quatro cores de camisa em campo.
## `extra`: linha que entra embaixo (condições do jogo). `second_leg`: jogo de volta (mostra o agregado).
## `force_layout`: outro desenho no lugar do da competição (prévias).
static func make(w: GameWorld, comp_id: String, title: String, home: Club, away: Club, colors: Array, extra: Control = null, live := true, second_leg := false, force_layout := "") -> ScoreboardView:
	var v := ScoreboardView.new()
	v.comp = comp_id
	v.th = ScoreboardTheme.for_competition(w, comp_id)
	v.layout = force_layout if ScoreboardTheme.LAYOUTS.has(force_layout) else String(v.th.get("layout", "faixa"))
	v.abbrs = [home.abbr, away.abbr]
	v.cols = colors
	v._build(w, title, home, away, extra, live)
	v.set_meta("second_leg", second_leg)
	return v


## Prévia para o Editor: um jogo de mentira (2 x 1 aos 67', agregado nas copas).
static func preview(w: GameWorld, comp_id: String, force_layout := "") -> Control:
	var h := _fake("Mandante", "MAN", "#C8102E", "#FFFFFF")
	var a := _fake("Visitante", "VIS", "#1B3A8C", "#F2C94C")
	var title := String((DatabaseManager.league_cfg(comp_id) if DatabaseManager.has_league(comp_id) else DatabaseManager.cup_cfg(comp_id)).get("name", comp_id))
	var v := make(w, comp_id, title.to_upper(), h, a, [Color(h.color1), Color(h.color2), Color(a.color1), Color(a.color2)], null, true, false, force_layout)
	v.show_state(2, 1, "67'", "", "", "" if DatabaseManager.has_league(comp_id) else "AGREGADO  MAN 3–2 VIS")
	v.home_scorers.text = "Fulano 12', 58'"
	v.away_scorers.text = "Beltrano 40'"
	v.home_scorers.get_parent().visible = true
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v


static func _fake(name: String, abbr: String, c1: String, c2: String) -> Club:
	var c := Club.new()
	c.name = name
	c.short_name = name
	c.abbr = abbr
	c.color1 = c1
	c.color2 = c2
	c.crest = {"shape": "shield", "field": "plain", "c1": c1, "c2": c2, "symbol": "letter", "initials": abbr.left(1), "border": "thin"}
	return c


# ---------------------------------------------------------------------------
# Estado
# ---------------------------------------------------------------------------

## Atualiza tudo a partir da simulação (a tela já montou os textos em score_proxy/clock_proxy).
func sync(sim: MatchSimulation, shown: Array, halftime: bool, done: bool) -> void:
	var state := ""
	if done or sim.finished:
		state = "FIM DE JOGO"
	elif halftime:
		state = "PRORROGAÇÃO" if sim.et_pending else "INTERVALO"
	elif sim.shootout:
		state = "PÊNALTIS"
	var clock := "%d'" % sim.minute
	var extra := ""
	var hi := clampi(sim.half - 1, 0, 3)
	if state == "" and sim.minute > int(LIMITS[hi]) and sim.stoppage[hi] > 0:
		extra = "+%d" % sim.stoppage[hi]
	elif state == "" and not sim.started:
		clock = "0'"
	var pens := ""
	if sim.shootout or sim.pen_taken[0] + sim.pen_taken[1] > 0:
		pens = "PÊN %d–%d" % [sim.pen_score[0], sim.pen_score[1]]
	var agg := ""
	if sim.knockout and (sim.agg[0] + sim.agg[1] > 0 or bool(get_meta("second_leg", false))):
		agg = "AGREGADO  %s %d–%d %s" % [abbrs[0], int(shown[0]) + sim.agg[0], int(shown[1]) + sim.agg[1], abbrs[1]]
	show_state(int(shown[0]), int(shown[1]), clock, extra, state, agg, pens)


func show_state(h: int, a: int, clock: String, extra: String, state: String, agg: String, pens: String = "") -> void:
	var sc := [h, a]
	for side in 2:
		if _digits[side] != null:
			(_digits[side] as Label).text = str(sc[side])
		if _last[side] >= 0 and sc[side] > _last[side]:
			_flash(side)
	_last = sc
	_clock.text = clock
	_cur_state = state
	_cur_extra = extra
	_extra.text = extra
	_state.text = state if layout != "compacto" else _short_state(state)
	_tab_visibility()
	_pens.visible = pens != ""
	_pens.text = pens
	_agg_box.visible = agg != ""
	_agg.text = agg


## A aba do tempo mostra uma coisa só: o aviso de gol, o estado do jogo ou o relógio (+ acréscimo).
func _tab_visibility() -> void:
	var goal := _goal_box.visible
	_clock_box.visible = not goal and _cur_state == ""
	_extra_box.visible = not goal and _cur_state == "" and _cur_extra != ""
	_state_box.visible = not goal and _cur_state != ""


static func _short_state(s: String) -> String:
	return {"FIM DE JOGO": "FIM", "INTERVALO": "INT", "PRORROGAÇÃO": "PRORR.", "PÊNALTIS": "PÊN"}.get(s, s)


## Gol: a ficha do time pisca, o número pula e a aba "GOL" aparece no lugar do relógio por um tempo.
func _flash(side: int) -> void:
	if not is_inside_tree():
		return
	_goal_serial += 1
	var serial := _goal_serial
	_goal.text = ("GOL  %s" % abbrs[side]) if layout != "compacto" else "GOL"
	_goal_box.visible = true
	_tab_visibility()
	var chip: Control = _chips[side]
	if chip != null:
		var tw := create_tween()
		for i in 3:
			tw.tween_property(chip, "self_modulate", Color(1.8, 1.8, 1.8), 0.14)
			tw.tween_property(chip, "self_modulate", Color.WHITE, 0.22)
	var dg: Label = _digits[side]
	if dg != null:
		dg.pivot_offset = dg.size * 0.5
		var t2 := create_tween()
		t2.tween_property(dg, "scale", Vector2(1.35, 1.35), 0.12).set_trans(Tween.TRANS_BACK)
		t2.tween_property(dg, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	get_tree().create_timer(4.0).timeout.connect(func():
		if is_instance_valid(self) and serial == _goal_serial:
			_goal_box.visible = false
			_tab_visibility())


# ---------------------------------------------------------------------------
# Peças
# ---------------------------------------------------------------------------

static func _box(bg: Color, radius: int = 0, border: Color = Color(0, 0, 0, 0), bw: int = 0, mx: int = 8, my: int = 2, skew: float = 0.0) -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(bw)
	s.content_margin_left = mx
	s.content_margin_right = mx
	s.content_margin_top = my
	s.content_margin_bottom = my
	s.skew = Vector2(skew, 0)
	s.anti_aliasing = true
	p.add_theme_stylebox_override(&"panel", s)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


static func _style(p: PanelContainer) -> StyleBoxFlat:
	return p.get_theme_stylebox(&"panel") as StyleBoxFlat


static func _lbl(text: String, variation: String, col: Color, size: int = 0) -> Label:
	var l := UIKit.label(text, variation)
	l.add_theme_color_override(&"font_color", col)
	if size > 0:
		l.add_theme_font_size_override(&"font_size", size)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _accent() -> Color:
	return th["accent"]


func _text() -> Color:
	return th["text"]


## Logo da competição (amistoso não tem).
func _logo(px: int) -> Control:
	if comp == "F" or comp == "":
		var sp := Control.new()
		sp.custom_minimum_size = Vector2(0, px)
		return sp
	var l := UIKit.comp_logo(comp, px)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Ficha do time: blocos das duas cores e, se `abbr`, a sigla.
func _chip(side: int, abbr: bool, h: int, skew: float = 0.0, radius: int = 0) -> PanelContainer:
	var c1: Color = cols[side * 2]
	var c2: Color = cols[side * 2 + 1]
	var p := _box(c1, radius, c2, 0, 10 if abbr else 0, 0, skew)
	var s := _style(p)
	s.border_width_bottom = 5
	p.custom_minimum_size = Vector2(12 if not abbr else 72, h)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if abbr:
		var l := _lbl(String(abbrs[side]), "H3", UIColors.on_color(c1), 24)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		p.add_child(l)
	_chips[side] = p
	return p


func _digit(side: int, col: Color, size: int, variation := "Score") -> Label:
	var l := _lbl("0", variation, col, size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size.x = size * 0.62
	_digits[side] = l
	return l


## Relógio, acréscimo, estado e aviso de gol: a "aba do tempo" (todos os desenhos têm uma).
func _time_tab(clock_bg: Color, clock_col: Color, radius: int, variation := "H3", size := 22) -> HBoxContainer:
	var row := UIKit.hbox(0)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_clock_box = _box(clock_bg, radius, Color(0, 0, 0, 0), 0, 10, 1)
	_clock = _lbl("0'", variation, clock_col, size)
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock.custom_minimum_size.x = 52
	_clock_box.add_child(_clock)
	row.add_child(_clock_box)
	var acc := _accent()
	# Acréscimo: na cor da competição; se o relógio já estiver nela, em branco.
	var ex_bg := acc if layout != "classico" else AMBER
	if clock_bg.is_equal_approx(acc):
		ex_bg = Color("#F4F6F8")
	_extra_box = _box(ex_bg, radius, Color(0, 0, 0, 0), 0, 7, 1)
	_extra = _lbl("", variation, UIColors.on_color(ex_bg), size - 4)
	_extra_box.add_child(_extra)
	_extra_box.visible = false
	row.add_child(_extra_box)
	_state_box = _box(acc if layout != "classico" else Color("#050505"), radius, AMBER if layout == "classico" else Color(0, 0, 0, 0), 1 if layout == "classico" else 0, 12, 1)
	_state = _lbl("", "Caps", UIColors.on_color(acc) if layout != "classico" else AMBER, 18)
	_state_box.add_child(_state)
	_state_box.visible = false
	row.add_child(_state_box)
	_goal_box = _box(Color("#FFFFFF"), radius, Color(0, 0, 0, 0), 0, 10, 1)
	_goal = _lbl("GOL", "Caps", Color("#111111"), 18)
	_goal_box.add_child(_goal)
	_goal_box.visible = false
	row.add_child(_goal_box)
	return row


func _pens_label(col: Color) -> Label:
	_pens = _lbl("", "Caps", col, 16)
	_pens.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pens.visible = false
	return _pens


func _agg_row() -> Control:
	var acc := _accent()
	_agg_box = _box(th["bg2"] if layout != "classico" else Color("#050505"), 12 if layout in ["capsula", "faixa", "neon"] else 0, acc if layout != "classico" else AMBER.darkened(0.4), 1, 12, 1)
	_agg = _lbl("", "Caps", th["caps"] if layout != "classico" else AMBER, 16)
	_agg_box.add_child(_agg)
	_agg_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_agg_box.visible = false
	return _agg_box


func _name(text: String, right: bool, col: Color, upper := false) -> Label:
	var l := _lbl(text.to_upper() if upper else text, "H3", col)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if right:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return l


# ---------------------------------------------------------------------------
# Montagem
# ---------------------------------------------------------------------------

func _build(w: GameWorld, title: String, home: Club, away: Club, extra: Control, live: bool) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme_type_variation = "TopBar"
	var acc := _accent()
	var sb := StyleBoxFlat.new()
	sb.bg_color = th["bg"]
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 6
	sb.content_margin_bottom = 4
	match layout:
		"faixa":
			sb.border_color = acc
			sb.border_width_bottom = 4
		"tv":
			sb.border_color = acc
			sb.border_width_top = 3
		"angular":
			sb.border_color = acc
			sb.border_width_bottom = 3
		"capsula":
			sb.corner_radius_bottom_left = 26
			sb.corner_radius_bottom_right = 26
			sb.border_color = acc
			sb.border_width_bottom = 2
			sb.shadow_color = Color(acc.r, acc.g, acc.b, 0.35)
			sb.shadow_size = 6
		"classico":
			sb.bg_color = Color("#0B0B0B")
			sb.border_color = Color("#3A3A3A")
			sb.border_width_bottom = 5
		"compacto":
			sb.bg_color = Color(th["bg"]).darkened(0.35)
			sb.content_margin_left = 12
			sb.content_margin_top = 10
		"painel":
			sb.border_color = acc
			sb.border_width_left = 0
			sb.border_width_bottom = 3
		"neon":
			sb.bg_color = Color(th["bg"]).darkened(0.55)
			sb.border_color = acc
			sb.border_width_bottom = 2
			sb.border_width_top = 1
			sb.shadow_color = Color(acc.r, acc.g, acc.b, 0.45)
			sb.shadow_size = 10
	add_theme_stylebox_override(&"panel", sb)
	var v := UIKit.vbox(4)
	add_child(v)
	# Rótulos que a tela da partida escreve (o placar desenhado lê o estado em sync()).
	score_proxy = Label.new()
	score_proxy.visible = false
	clock_proxy = Label.new()
	clock_proxy.visible = false
	v.add_child(score_proxy)
	v.add_child(clock_proxy)
	bug = Broadcaster.bug(Broadcaster.for_competition(w, comp), live)
	home_name = _name(home.short_name, false, _text(), layout in ["tv", "angular", "classico", "painel"])
	away_name = _name(away.short_name, layout != "painel", _text(), layout in ["tv", "angular", "classico", "painel"])
	match layout:
		"compacto":
			_build_compact(v, title, home, away)
		"painel":
			v.add_child(_strip(title))
			_build_stacked(v, home, away)
		_:
			v.add_child(_strip(title))
			_build_row(v, home, away)
	v.add_child(_agg_row())
	var sc := UIKit.hbox(8)
	home_scorers = UIKit.label("", "Small", true)
	home_scorers.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(home_scorers)
	away_scorers = UIKit.label("", "Small", true)
	away_scorers.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	away_scorers.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sc.add_child(away_scorers)
	sc.visible = false
	v.add_child(sc)
	if extra != null:
		v.add_child(extra)
	ticker = UIKit.label("", "Small")
	ticker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ticker.clip_text = true
	v.add_child(ticker)


## Faixa de cima: selo da emissora, logo da competição e o nome do jogo.
func _strip(title: String) -> Control:
	var acc := _accent()
	var caps_col: Color = th["caps"]
	var strip: PanelContainer
	match layout:
		"tv":
			strip = _box(acc, 0, Color(0, 0, 0, 0), 0, 10, 2)
			caps_col = UIColors.on_color(acc)
		"angular":
			strip = _box(acc, 0, Color(0, 0, 0, 0), 0, 14, 2, 0.35)
			caps_col = UIColors.on_color(acc)
		"capsula":
			strip = _box(th["bg2"], 20, acc, 2, 12, 2)
		"classico":
			strip = _box(Color("#000000"), 2, Color("#3A3A3A"), 1, 10, 2)
			caps_col = AMBER
		"painel":
			strip = _box(th["bg2"], 0, acc, 0, 10, 2)
			_style(strip).border_width_left = 6
		"neon":
			strip = _box(Color(0, 0, 0, 0), 0, acc, 0, 4, 0)
			_style(strip).border_width_bottom = 1
			caps_col = acc
		_:
			strip = _box(th["bg2"], 8, Color(0, 0, 0, 0), 0, 10, 2)
	var row := UIKit.hbox(8)
	if layout in ["tv", "angular"]:
		# Selo da emissora numa pastilha escura (o vermelho do "AO VIVO" some sobre a cor da faixa).
		var pill := _box(Color(th["bg"]).darkened(0.3), 4, Color(0, 0, 0, 0), 0, 6, 1, 0.35 if layout == "angular" else 0.0)
		pill.add_child(bug)
		row.add_child(pill)
	else:
		row.add_child(bug)
	var t := _lbl(title, "Caps", caps_col)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.clip_text = true
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(t)
	row.add_child(_logo(30))
	strip.add_child(row)
	return strip


## Linha única: escudo, nome, placar e relógio no meio (faixa, tv, angular, cápsula, clássico, neon).
func _build_row(v: VBoxContainer, home: Club, away: Club) -> void:
	var acc := _accent()
	var row := UIKit.hbox(8)
	var hc := UIKit.crest(home, 40)
	row.add_child(hc)
	var chip_skew := 0.3 if layout == "angular" else 0.0
	if layout in ["tv", "angular"]:
		row.add_child(_chip(0, false, 44, chip_skew))
	if layout in ["neon", "faixa", "capsula"]:
		row.add_child(_underlined(home_name, 0))
	else:
		row.add_child(home_name)
	var mid := UIKit.vbox(2)
	var box: PanelContainer
	var digit_col := _text()
	var clock_bg := Color(0, 0, 0, 0)
	var clock_col := acc
	var radius := 0
	match layout:
		"tv":
			box = _box(acc, 0, Color(0, 0, 0, 0), 0, 14, 0)
			digit_col = UIColors.on_color(acc)
			clock_bg = th["bg2"]
			clock_col = _text()
		"angular":
			box = _box(th["bg2"], 0, acc, 0, 16, 0, 0.22)
			_style(box).border_width_left = 5
			_style(box).border_width_right = 5
			clock_bg = acc
			clock_col = UIColors.on_color(acc)
		"capsula":
			box = _box(th["bg2"], 24, acc, 3, 16, 0)
			_style(box).shadow_color = Color(acc.r, acc.g, acc.b, 0.45)
			_style(box).shadow_size = 8
			radius = 12
		"classico":
			box = _box(Color("#050505"), 3, AMBER.darkened(0.5), 3, 14, 0)
			digit_col = AMBER
			clock_bg = Color("#050505")
			clock_col = AMBER
		"neon":
			box = _box(Color(0, 0, 0, 0), 0, Color(0, 0, 0, 0), 0, 6, 0)
			clock_bg = Color(0, 0, 0, 0.35)
			radius = 14
		_:
			box = _box(th["bg2"], 10, acc, 2, 14, 0)
	var digits := UIKit.hbox(6)
	digits.alignment = BoxContainer.ALIGNMENT_CENTER
	var dvar := "Mono" if layout == "classico" else "Score"
	digits.add_child(_digit(0, digit_col, 40, dvar))
	var sep := _lbl(":" if layout == "neon" else "–", dvar, acc if layout == "neon" else digit_col, 34)
	digits.add_child(sep)
	digits.add_child(_digit(1, digit_col, 40, dvar))
	box.add_child(digits)
	_score_box = box
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mid.add_child(box)
	mid.add_child(_pens_label(acc if layout != "classico" else AMBER))
	var tab := _time_tab(clock_bg, clock_col, radius, "Mono" if layout == "classico" else "H3", 22)
	if layout == "neon":
		_style(_clock_box).border_color = acc
		_style(_clock_box).set_border_width_all(1)
	mid.add_child(tab)
	row.add_child(mid)
	if layout in ["neon", "faixa", "capsula"]:
		row.add_child(_underlined(away_name, 1))
	else:
		row.add_child(away_name)
	if layout in ["tv", "angular"]:
		row.add_child(_chip(1, false, 44, chip_skew))
	var ac := UIKit.crest(away, 40)
	row.add_child(ac)
	v.add_child(row)
	if _chips[0] == null:
		# Sem ficha colorida: quem pisca no gol é o escudo.
		_chips[0] = hc
		_chips[1] = ac


## Nome com um filete na cor da camisa embaixo (a "ficha" do time na faixa, cápsula e neon).
func _underlined(l: Label, side: int) -> Control:
	var col := UIKit.vbox(3)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(l)
	var c1: Color = cols[side * 2]
	var c2: Color = cols[side * 2 + 1]
	var bar := _box(c1 if c1.get_luminance() > 0.08 else c2, 3 if layout != "neon" else 0, c2, 0, 0, 0)
	_style(bar).border_width_right = 18 if layout == "faixa" else 0
	bar.custom_minimum_size = Vector2(64, 5)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_END if side == 1 else Control.SIZE_SHRINK_BEGIN
	col.add_child(bar)
	_chips[side] = bar
	return col


## Compacto: um selo só no canto, como o placar pequeno das grandes transmissões.
func _build_compact(v: VBoxContainer, title: String, home: Club, away: Club) -> void:
	var acc := _accent()
	var top := UIKit.hbox(0)
	var logo_box := _box(Color("#F4F6F8"), 0, Color(0, 0, 0, 0), 0, 6, 4)
	logo_box.add_child(_logo(36))
	top.add_child(logo_box)
	for side in 2:
		if side == 1:
			var box := _box(th["bg2"], 0, Color(0, 0, 0, 0), 0, 12, 0)
			var digits := UIKit.hbox(8)
			digits.add_child(_digit(0, _text(), 32))
			var sep := _lbl("–", "Score", Color(_text(), 0.6), 26)
			digits.add_child(sep)
			digits.add_child(_digit(1, _text(), 32))
			box.add_child(digits)
			_score_box = box
			top.add_child(box)
		var chip := _chip(side, true, 48)
		_style(chip).border_width_bottom = 4
		top.add_child(chip)
	var tab := _time_tab(Color("#000000", 0.55), Color("#FFFFFF"), 0, "H3", 22)
	for b: PanelContainer in [_clock_box, _extra_box, _state_box, _goal_box]:
		b.custom_minimum_size.y = 48
	_style(_clock_box).bg_color = Color(th["bg"]).darkened(0.6)
	top.add_child(tab)
	var row := UIKit.hbox(8)
	row.add_child(top)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	row.add_child(bug)
	v.add_child(row)
	# Linha fina embaixo: nomes completos, pênaltis e a competição.
	var sub := UIKit.hbox(6)
	var bar := ColorRect.new()
	bar.color = acc
	bar.custom_minimum_size = Vector2(4, 18)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sub.add_child(bar)
	home_name.size_flags_horizontal = Control.SIZE_FILL
	away_name.size_flags_horizontal = Control.SIZE_FILL
	away_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	for l: Label in [home_name, away_name]:
		l.clip_text = false
		l.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		l.add_theme_font_size_override(&"font_size", 18)
		l.add_theme_color_override(&"font_color", Color(_text(), 0.85))
	sub.add_child(home_name)
	sub.add_child(_lbl("x", "Small", Color(_text(), 0.5)))
	sub.add_child(away_name)
	sub.add_child(_pens_label(acc))
	var t := _lbl("· " + title, "Caps", th["caps"], 15)
	t.clip_text = true
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub.add_child(t)
	v.add_child(sub)


## Painel: um time por linha (ficha, escudo, nome e placar) e o relógio numa coluna.
func _build_stacked(v: VBoxContainer, home: Club, away: Club) -> void:
	var acc := _accent()
	var row := UIKit.hbox(10)
	var clock_col := UIKit.vbox(4)
	clock_col.alignment = BoxContainer.ALIGNMENT_CENTER
	clock_col.custom_minimum_size.x = 150
	var tab := _time_tab(acc, UIColors.on_color(acc), 4, "Score", 30)
	_clock.custom_minimum_size.x = 80
	# No painel a aba vira coluna: relógio em cima, acréscimo embaixo.
	var col_tab := UIKit.vbox(4)
	for ch in tab.get_children():
		tab.remove_child(ch)
		(ch as Control).size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col_tab.add_child(ch)
	tab.queue_free()
	clock_col.add_child(col_tab)
	clock_col.add_child(_pens_label(acc))
	row.add_child(clock_col)
	var rows := UIKit.vbox(4)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in 2:
		var club := home if side == 0 else away
		var r := _box(th["bg2"], 4, Color(0, 0, 0, 0), 0, 0, 0)
		_style(r).content_margin_right = 0
		var line := UIKit.hbox(10)
		line.add_child(_chip(side, false, 44, 0.0))
		line.add_child(UIKit.crest(club, 34))
		line.add_child(home_name if side == 0 else away_name)
		var sbox := _box(Color(th["bg"]).darkened(0.3), 0, Color(0, 0, 0, 0), 0, 12, 0)
		sbox.custom_minimum_size.x = 64
		sbox.add_child(_digit(side, _text(), 32))
		line.add_child(sbox)
		r.add_child(line)
		rows.add_child(r)
	away_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(rows)
	v.add_child(row)
