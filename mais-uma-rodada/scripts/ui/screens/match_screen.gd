extends BaseScreen
## Partida ao vivo: placar, campo 2D, narração, ajustes em tempo real e comemoração de gol.
## A simulação é exatamente a mesma do modo instantâneo; aqui só se controla o ritmo
## (segundos por minuto) e a apresentação dos eventos.

const PACE: Array[float] = [1.25, 0.32, 0.08] # segundos por minuto de jogo
const PACE_NAMES: Array[String] = ["Normal", "Rápido", "Turbo"]
const FEED_MAX := 70
const TEMPO: Array[float] = [1.45, 2.3, 4.2] # velocidade do motor visual em cada ritmo

var _sim: MatchSimulation
var _fx: Fixture
var _com: Commentary
var _entries: Array = []
var _div_entries: Array = []
var _user_side := 0
var _pace := 1
var _paused := false
var _halftime := false
var _pending_halftime := false
var _pending_final := false
var _pending_shootout := false
var _done := false
var _report: Dictionary = {}
var _clock := 0.9
var _hold := 0.0
var _elapsed := 0.0
var _queue: Array = [] # [{at, line, ev}]
var _ev_index := 0
var _announced: Array[bool] = [false, false]
var _scorers: Array = [[], []] # por lado: [[nome, [minutos]]]
var _shown_score: Array[int] = [0, 0] # placar mostrado: o gol só entra quando a bola entra no campo 2D
var _colors: Array[Color] = []
var _vis_rng := RandomNumberGenerator.new()
var _last_phase: Dictionary = {}
var _play_delay := 0.0 # quanto a jogada encenada no campo ainda leva (s): a narração acompanha
var _stadium: Dictionary = {}
var _highlight_timer := 0.0
var _ticker_t := 1.5
var _ticker_i := -1
var _ticker_seen: Dictionary = {}
## Faixa "ao vivo" embaixo do campo: todos os jogos da rodada com placar parcial; quando sai gol
## o chip acende com o autor e a faixa para nele por alguns segundos.
var _strip_scroll: ScrollContainer
var _strip_chips: Array = [] # {e, panel, score, info, box, flash, total}
var _strip_t := 0.0
var _strip_hold := 0.0
var _strip_x := 0.0
var _sub_out := -1
var _built := false
var _tab := "feed" # feed | stats | round | table
var _tab_minute := -99
var _other_seen: Dictionary = {} # índice da entrada -> gols já anunciados
var _day_entries: Array = [] # outros jogos do mesmo país na data (fora a competição do usuário)
var _stat_marks: Dictionary = {}
var _swapped := false

# Nós
var _root: VBoxContainer
var _home_name: Label
var _away_name: Label
var _score_lbl: Label
var _clock_lbl: Label
var _home_scorers: Label
var _away_scorers: Label
var _ticker: Label
var _pitch: PitchView
var _poss_home: ColorRect
var _poss_away: ColorRect
var _poss_lbl_h: Label
var _poss_lbl_a: Label
var _stats_lbl: Label
var _stats_box: VBoxContainer
var _feed_scroll: ScrollContainer
var _feed: VBoxContainer
var _controls: HBoxContainer
var _controls_panel: PanelContainer
var _play_btn: Button
var _speed_btn: Button
var _tac_btn: Button
var _shout_btn: Button = null
var _skip_btn: Button
var _overlay: GoalOverlay
var _tac_box: VBoxContainer
var _momentum: MomentumView
var _tabs_row: HBoxContainer
var _tab_scroll: ScrollContainer
var _tab_box: VBoxContainer


func _init() -> void:
	show_top = false
	show_nav = false


func on_show() -> void:
	if not _built:
		_build()
	set_process(true)


func on_hide() -> void:
	set_process(false)


func refresh() -> void:
	pass


# ---------------------------------------------------------------------------
# Montagem
# ---------------------------------------------------------------------------

func _build() -> void:
	_built = true
	var w := world()
	_sim = GameManager.user_sim()
	_fx = GameManager.user_fixture()
	if _sim == null or _fx == null:
		UIManager.goto("hub")
		return
	_entries = GameManager.matchday.get("entries", [])
	var user_nation := ""
	var ul := w.league_of(w.user_club_id)
	if ul != null:
		user_nation = ul.nation
	for e in _entries:
		var f: Fixture = e["f"]
		if f == _fx:
			continue
		if f.comp == _fx.comp and f.stage == _fx.stage:
			_div_entries.append(e)
		elif f.is_league() and user_nation != "" and w.league(f.comp) != null and w.league(f.comp).nation == user_nation:
			_day_entries.append(e)
	_user_side = 0 if _fx.home == w.user_club_id else 1
	_pace = 0 if AppSettings.match_speed == AppSettings.SPEED_NORMAL else 1
	var home: Club = _sim.teams[0].club
	var away: Club = _sim.teams[1].club
	_colors = _team_colors(home, away)
	var seed_base := (_fx.home * 131 + _fx.away) * 7919 + _fx.round * 97 + w.year
	_com = Commentary.new(_sim, home.stadium, seed_base)
	_vis_rng.seed = seed_base * 31 + 17

	_root = UIKit.vbox(0)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	_root.add_child(_build_scoreboard(home, away))
	# Campo
	_pitch = PitchView.new()
	_pitch.mode = "match"
	_pitch.horizontal = true
	_pitch.custom_minimum_size = Vector2(0, 440)
	_pitch.home_label = home.abbr
	_pitch.away_label = away.abbr
	_pitch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pitch.home_color = _colors[0]
	_pitch.home_color2 = _colors[1]
	_pitch.away_color = _colors[2]
	_pitch.away_color2 = _colors[3]
	var th := ScoreboardTheme.for_competition(w, _fx.comp)
	_pitch.comp_accent = th["accent"]
	_pitch.comp_bg = th["bg"]
	var refc := _ref_colors()
	_pitch.ref_color = refc[0]
	_pitch.ref_color2 = refc[1]
	_pitch.motion = PitchMotion.new(seed_base * 7 + 3)
	_pitch.motion.tempo = TEMPO[_pace]
	_stadium = StadiumStyle.for_match(w, _fx, home, away, _sim.neutral, _sim.attendance, seed_base)
	_pitch.stadium = _stadium
	_root.add_child(UIKit.margin(_pitch, 0, 6, 0, 4))
	if not _div_entries.is_empty() or not _day_entries.is_empty():
		_root.add_child(UIKit.margin(_build_strip(), 8, 0, 8, 4))
		_ticker.visible = false
	# Posse e números
	_stats_box = UIKit.vbox(4)
	var poss := UIKit.hbox(8)
	_poss_lbl_h = UIKit.label("50%", "H3")
	_poss_lbl_h.custom_minimum_size.x = 64
	poss.add_child(_poss_lbl_h)
	var bar := UIKit.hbox(0)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_poss_home = ColorRect.new()
	_poss_home.color = _colors[0]
	_poss_home.custom_minimum_size.y = 10
	_poss_home.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_poss_home.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_poss_away = ColorRect.new()
	_poss_away.color = _colors[2]
	_poss_away.custom_minimum_size.y = 10
	_poss_away.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_poss_away.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(_poss_home)
	bar.add_child(_poss_away)
	poss.add_child(bar)
	_poss_lbl_a = UIKit.label("50%", "H3")
	_poss_lbl_a.custom_minimum_size.x = 64
	_poss_lbl_a.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	poss.add_child(_poss_lbl_a)
	_stats_box.add_child(poss)
	_stats_lbl = UIKit.label("", "Small")
	_stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats_box.add_child(_stats_lbl)
	_momentum = MomentumView.new()
	_momentum.custom_minimum_size = Vector2(0, 50)
	_momentum.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_momentum.home_color = _side_color(0)
	_momentum.away_color = _side_color(1)
	_stats_box.add_child(_momentum)
	_root.add_child(UIKit.margin(_stats_box, 20, 2, 20, 6))
	# Abas: lances, números, outros jogos e tabela ao vivo (o jogo segue rolando em todas)
	_tabs_row = UIKit.hbox(6)
	_root.add_child(UIKit.margin(_tabs_row, 14, 0, 14, 4))
	_build_tabs()
	# Narração
	_feed_scroll = ScrollContainer.new()
	_feed_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_feed_scroll.scroll_deadzone = 14
	_feed_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_feed = UIKit.vbox(8)
	_feed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_feed_scroll.add_child(UIKit.margin(_feed, 18, 6, 18, 12))
	(_feed.get_parent() as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root.add_child(_feed_scroll)
	_tab_scroll = ScrollContainer.new()
	_tab_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tab_scroll.scroll_deadzone = 14
	_tab_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tab_scroll.visible = false
	_tab_box = UIKit.vbox(8)
	_tab_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tm := UIKit.margin(_tab_box, 18, 6, 18, 12)
	tm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_scroll.add_child(tm)
	_root.add_child(_tab_scroll)
	# Controles
	_controls_panel = PanelContainer.new()
	_controls_panel.theme_type_variation = "BottomBar"
	_controls = UIKit.hbox(8)
	_controls_panel.add_child(_controls)
	_root.add_child(_controls_panel)
	_build_controls()
	# Comemoração por cima de tudo
	_overlay = GoalOverlay.new()
	add_child(_overlay)
	_sync_slots()
	_update_board()
	var info := "%s · %s torcedores" % [home.stadium, Fmt.thousands(_sim.attendance)]
	if _sim.derby:
		info += " · CLÁSSICO"
	_add_line({"text": info, "style": "info", "side": -1, "minute": ""})
	var rs := Referees.summary(w, _sim.ref)
	if rs != "":
		_add_line({"text": "Árbitro: " + rs, "style": "info", "side": -1, "minute": ""})
	var wcat := "weather_" + String(_stadium.get("weather", ""))
	_add_line(_com.extra_line(wcat if DatabaseManager.commentary().has(wcat) else "weather", "info", 0, 1))
	var scat := "stadium_" + String(_stadium.get("kind", ""))
	if DatabaseManager.commentary().has(scat):
		_add_line(_com.extra_line(scat, "info", 0, 1))
	if not _sim.started and _sim.can_talk(_user_side):
		_open_talk.call_deferred(false)


func _build_scoreboard(home: Club, away: Club) -> Control:
	# Placar com a cara da competição: cores da liga/copa e um desenho próprio (faixa, TV,
	# angular, cápsula ou clássico), como os grafismos de cada transmissão.
	var th := ScoreboardTheme.for_competition(world(), _fx.comp)
	var layout := String(th.get("layout", "faixa"))
	var accent: Color = th["accent"]
	var panel := PanelContainer.new()
	panel.theme_type_variation = "TopBar"
	var sb := StyleBoxFlat.new()
	sb.bg_color = th["bg"]
	sb.border_color = accent
	sb.border_width_bottom = 4
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 10
	sb.content_margin_bottom = 8
	match layout:
		"tv":
			sb.border_width_bottom = 0
			sb.border_width_top = 3
		"capsula":
			sb.corner_radius_bottom_left = 26
			sb.corner_radius_bottom_right = 26
			sb.shadow_color = Color(accent.r, accent.g, accent.b, 0.35)
			sb.shadow_size = 6
		"classico":
			sb.bg_color = Color("#0B0B0B")
			sb.border_color = Color("#3A3A3A")
			sb.border_width_bottom = 5
	panel.add_theme_stylebox_override(&"panel", sb)
	var v := UIKit.vbox(2)
	panel.add_child(v)
	var strip := PanelContainer.new()
	var ss := StyleBoxFlat.new()
	ss.bg_color = th["bg2"]
	ss.set_corner_radius_all(8)
	ss.content_margin_left = 10
	ss.content_margin_right = 10
	ss.content_margin_top = 3
	ss.content_margin_bottom = 3
	var caps_col: Color = th["caps"]
	match layout:
		"tv":
			ss.bg_color = accent
			ss.set_corner_radius_all(0)
			caps_col = UIColors.on_color(accent)
		"angular":
			ss.bg_color = accent
			ss.skew = Vector2(0.35, 0)
			ss.set_corner_radius_all(0)
			caps_col = UIColors.on_color(accent)
		"capsula":
			ss.set_corner_radius_all(20)
			ss.border_color = accent
			ss.set_border_width_all(2)
		"classico":
			ss.bg_color = Color("#000000")
			ss.set_corner_radius_all(2)
			ss.border_color = Color("#3A3A3A")
			ss.set_border_width_all(1)
			caps_col = Color("#FFB000")
	strip.add_theme_stylebox_override(&"panel", ss)
	var comp_lbl := UIKit.label(CompText.fixture_title(world(), _fx).to_upper() if _fx.comp != "F" else "AMISTOSO", "Caps")
	comp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	comp_lbl.clip_text = true
	comp_lbl.add_theme_color_override(&"font_color", caps_col)
	strip.add_child(comp_lbl)
	v.add_child(strip)
	var row := UIKit.hbox(8)
	row.add_child(UIKit.crest(home, 58))
	if layout == "tv" or layout == "angular":
		row.add_child(_team_block(_colors[0], _colors[1], layout))
	_home_name = UIKit.label(home.short_name, "H2")
	_home_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_home_name.clip_text = true
	row.add_child(_home_name)
	var mid := UIKit.vbox(0)
	var score_box := PanelContainer.new()
	var sbx := StyleBoxFlat.new()
	sbx.bg_color = th["bg2"]
	sbx.border_color = accent
	sbx.set_border_width_all(2)
	sbx.set_corner_radius_all(10)
	sbx.content_margin_left = 14
	sbx.content_margin_right = 14
	var score_col: Color = th["text"]
	var clock_col := accent
	match layout:
		"tv":
			sbx.bg_color = accent
			sbx.set_corner_radius_all(0)
			sbx.set_border_width_all(0)
			score_col = UIColors.on_color(accent)
		"angular":
			sbx.skew = Vector2(0.22, 0)
			sbx.set_corner_radius_all(0)
			sbx.border_width_top = 0
			sbx.border_width_bottom = 0
			sbx.border_width_left = 5
			sbx.border_width_right = 5
		"capsula":
			sbx.set_corner_radius_all(24)
			sbx.set_border_width_all(3)
			sbx.shadow_color = Color(accent.r, accent.g, accent.b, 0.45)
			sbx.shadow_size = 8
		"classico":
			sbx.bg_color = Color("#050505")
			sbx.border_color = Color("#FFB000").darkened(0.5)
			sbx.set_corner_radius_all(3)
			sbx.set_border_width_all(3)
			score_col = Color("#FFB000")
			clock_col = Color("#FFB000")
	score_box.add_theme_stylebox_override(&"panel", sbx)
	_score_lbl = UIKit.label("0 – 0", "Score")
	_score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_lbl.add_theme_color_override(&"font_color", score_col)
	score_box.add_child(_score_lbl)
	mid.add_child(score_box)
	_clock_lbl = UIKit.label("0'", "Accent" if layout != "classico" else "Mono")
	_clock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock_lbl.add_theme_color_override(&"font_color", clock_col)
	if layout == "tv":
		# Relógio numa aba própria, como na barra de TV.
		var tab := PanelContainer.new()
		var tb := StyleBoxFlat.new()
		tb.bg_color = th["bg2"]
		tb.content_margin_left = 8
		tb.content_margin_right = 8
		tab.add_theme_stylebox_override(&"panel", tb)
		tab.add_child(_clock_lbl)
		mid.add_child(tab)
	else:
		mid.add_child(_clock_lbl)
	row.add_child(mid)
	_away_name = UIKit.label(away.short_name, "H2")
	_away_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_away_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_away_name.clip_text = true
	row.add_child(_away_name)
	if layout == "tv" or layout == "angular":
		row.add_child(_team_block(_colors[2], _colors[3], layout))
	row.add_child(UIKit.crest(away, 58))
	v.add_child(row)
	var sc := UIKit.hbox(8)
	_home_scorers = UIKit.label("", "Small", true)
	sc.add_child(_home_scorers)
	_away_scorers = UIKit.label("", "Small", true)
	_away_scorers.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sc.add_child(_away_scorers)
	v.add_child(sc)
	_ticker = UIKit.label("", "Small")
	_ticker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ticker.clip_text = true
	v.add_child(_ticker)
	return panel


## Bloco com as duas cores do time ao lado do nome (placares de TV e angular).
func _team_block(c1: Color, c2: Color, layout: String) -> Control:
	var p := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = c1
	st.border_color = c2
	st.border_width_bottom = 5
	if layout == "angular":
		st.skew = Vector2(0.3, 0)
	p.add_theme_stylebox_override(&"panel", st)
	p.custom_minimum_size = Vector2(12, 44)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return p


func _build_controls() -> void:
	UIKit.clear(_controls)
	if _done:
		var xr := UIKit.button("Raio-X", "", func():
			UIManager.replace("results", {"report": _report})
			UIManager.push("xray"), "search")
		xr.custom_minimum_size.y = 92
		_controls.add_child(xr)
		var cont := UIKit.button("CONTINUAR", "PrimaryButton", func(): UIManager.replace("results", {"report": _report}), "check")
		cont.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cont.custom_minimum_size.y = 92
		_controls.add_child(cont)
		return
	_play_btn = UIKit.button("", "", _toggle_play, "pause")
	_speed_btn = UIKit.button(PACE_NAMES[_pace], "", _cycle_speed, "fast")
	_tac_btn = UIKit.button("Tática", "", _open_tactics, "tactics")
	_shout_btn = UIKit.button("Gritar", "", _open_shouts, "whistle")
	_skip_btn = UIKit.button("Fim", "", _confirm_skip, "skip")
	_skip_btn.text = ""
	_skip_btn.tooltip_text = "Ir para o fim"
	for b in [_play_btn, _speed_btn, _tac_btn, _shout_btn, _skip_btn]:
		var icon_only: bool = b == _play_btn or b == _skip_btn
		b.size_flags_horizontal = Control.SIZE_FILL if icon_only else Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(88 if icon_only else 0, 80)
		b.add_theme_font_size_override(&"font_size", 21)
		_controls.add_child(b)
	_update_play_button()


func _update_play_button() -> void:
	if _play_btn == null or _done:
		return
	_play_btn.text = ""
	if _halftime:
		_play_btn.tooltip_text = "2º tempo"
		_play_btn.icon = UIKit.icon("play")
	elif _paused:
		_play_btn.tooltip_text = "Seguir"
		_play_btn.icon = UIKit.icon("play")
	else:
		_play_btn.tooltip_text = "Pausar"
		_play_btn.icon = UIKit.icon("pause")


static func _cdist(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


func _team_colors(home: Club, away: Club) -> Array[Color]:
	var h1 := Color(String(home.kit_home.get("c1", home.color1)))
	var h2 := Color(String(home.kit_home.get("c2", home.color2)))
	var a1 := Color(String(away.kit_home.get("c1", away.color1)))
	var a2 := Color(String(away.kit_home.get("c2", away.color2)))
	if _cdist(h1, a1) < 0.35:
		a1 = Color(String(away.kit_away.get("c1", "#FFFFFF")))
		a2 = Color(String(away.kit_away.get("c2", "#111111")))
		if _cdist(h1, a1) < 0.35:
			var third := away.third_kit()
			a1 = Color(String(third.get("c1", "#FFFFFF")))
			a2 = Color(String(third.get("c2", "#111111")))
		if _cdist(h1, a1) < 0.35:
			a1 = Color("#F4F4F4") if h1.get_luminance() < 0.5 else Color("#15181D")
			a2 = Color("#15181D") if h1.get_luminance() < 0.5 else Color("#F4F4F4")
	var out: Array[Color] = [h1, h2, a1, a2]
	return out


func _side_color(side: int) -> Color:
	if side < 0:
		return Color(0, 0, 0, 0)
	var c: Color = _colors[0] if side == 0 else _colors[2]
	# Cores muito escuras ficam invisíveis no fundo: usa a secundária.
	if c.get_luminance() < 0.12:
		c = _colors[1] if side == 0 else _colors[3]
	return c


# ---------------------------------------------------------------------------
# Laço de tempo
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _sim == null or _overlay == null:
		return
	GameManager.pump_ai(5.0)
	_elapsed += delta
	_flush_lines()
	_update_ticker(delta)
	_update_strip(delta)
	_refresh_tab_if_needed()
	_pitch.motion.frozen = _paused or _halftime or _done or UIManager.has_modal()
	if _highlight_timer > 0.0:
		_highlight_timer -= delta
		if _highlight_timer <= 0.0:
			_pitch.highlight_side = -1
			_pitch.highlight_slot = -1
	if _done or UIManager.has_modal():
		return
	if _hold > 0.0:
		_hold -= delta
		return
	if not _queue.is_empty() or _overlay.is_playing():
		return
	if _pending_final:
		_pending_final = false
		_on_final()
		return
	if _pending_halftime:
		_pending_halftime = false
		_halftime = true
		_update_play_button()
		_update_board()
		_show_halftime()
		return
	if _pending_shootout:
		_pending_shootout = false
		_show_shootout_order()
		return
	if _halftime or _paused:
		return
	_clock -= delta
	if _clock > 0.0:
		return
	_clock = PACE[_pace]
	_advance()


func _advance() -> void:
	_sim.step()
	# Primeiro o campo encena o lance; a narração do desfecho sai quando a jogada termina.
	_play_delay = 0.0
	_script_play()
	_drain(false)
	_play_delay = 0.0
	_after_step()


func _after_step() -> void:
	# Acréscimos anunciados quando o relógio chega a 45'/90'
	if _sim.half == 1 and _sim.minute >= 45 and _sim.stoppage[0] > 0 and not _announced[0]:
		_announced[0] = true
		_enqueue(_com.stoppage_line(_sim.stoppage[0], 1), {}, 0.2)
	if _sim.half == 2 and _sim.minute >= 90 and _sim.stoppage[1] > 0 and not _announced[1]:
		_announced[1] = true
		_enqueue(_com.stoppage_line(_sim.stoppage[1], 2), {}, 0.2)
	if _sim.finished:
		_pending_final = true
	elif _sim.is_halftime_pause():
		_pending_halftime = true
	_script_play()
	_update_sides()
	_stat_summary()
	if GameManager.ai_ready() and not _sim.finished:
		_announce_other_goals(_sim.minute, _sim.half)
	_sync_slots()
	_update_board()


## Processa os eventos novos da simulação (inclusive os gerados por ajustes do usuário).
func _drain(silent: bool) -> void:
	while _ev_index < _sim.events.size():
		var ev: Dictionary = _sim.events[_ev_index]
		_ev_index += 1
		_handle_event(ev, silent)


func _delay_scale() -> float:
	return clampf(PACE[_pace] / 0.32, 0.3, 1.6)


func _enqueue(line: Dictionary, ev: Dictionary, delay: float) -> void:
	_queue.append({"at": _elapsed + delay, "line": line, "ev": ev})


func _handle_event(ev: Dictionary, silent: bool) -> void:
	var t: int = ev["t"]
	var side: int = ev["s"]
	if (t == MatchSimulation.EV_GOAL or t == MatchSimulation.EV_OWN_GOAL) and silent:
		_record_scorer(ev)
		_shown_score = [int(ev["hs"]), int(ev["as"])]
	if t == MatchSimulation.EV_SHOOTOUT and not silent:
		_pending_shootout = true
	if t in [MatchSimulation.EV_KICKOFF, MatchSimulation.EV_SECOND_HALF, MatchSimulation.EV_EXTRA_TIME, MatchSimulation.EV_ET_SECOND]:
		_pitch.motion.kickoff(0 if _sim.half % 2 == 1 else 1, true)
		if not silent:
			AudioManager.play("whistle", -4.0)
	var scripted := _play_delay > 0.0 and t in SCRIPTED_EVENTS
	for line in _com.lines_for(ev):
		var style: String = line["style"]
		if silent and style in ["normal", "chance", "info", "crowd", "var", "pundit", "reporter"] and t != MatchSimulation.EV_FULLTIME and t != MatchSimulation.EV_HALFTIME:
			continue
		if silent:
			_add_line(line)
			continue
		var d := float(line["delay"]) * _delay_scale()
		if scripted:
			# Preparação no meio da jogada; desfecho quando a bola chega.
			d = d + _play_delay if d > 0.0 or style in ["goal", "card_y", "card_r", "big"] else _play_delay * 0.5
		_enqueue(line, ev, d)
	if silent:
		return
	if t == MatchSimulation.EV_HALFTIME:
		var an := _com.analysis_line(int(ev["m"]), int(ev["h"]))
		if not an.is_empty():
			_enqueue(an, {}, 1.2)
	_on_event_visual(ev)
	# Destaque do protagonista no campo
	var pid: int = ev.get("p", -1)
	if pid >= 0 and side >= 0:
		var mp: MatchPlayer = _sim.teams[side].by_id.get(pid, null)
		if mp != null and mp.on_pitch and mp.slot >= 0:
			_pitch.highlight_side = side
			_pitch.highlight_slot = mp.slot
			_highlight_timer = maxf(0.8, PACE[_pace] * 1.5)


func _flush_lines() -> void:
	while not _queue.is_empty() and float(_queue[0]["at"]) <= _elapsed:
		var item: Dictionary = _queue.pop_front()
		var line: Dictionary = item["line"]
		var ev: Dictionary = item["ev"]
		_add_line(line)
		_on_line_shown(line, ev)


func _on_line_shown(line: Dictionary, ev: Dictionary) -> void:
	if ev.is_empty():
		return
	var t: int = ev["t"]
	var style: String = line["style"]
	match style:
		"goal":
			_celebrate(ev)
		"card_y", "card_r":
			AudioManager.play("card", -6.0)
			AudioManager.vibrate(25)
			_hold = maxf(_hold, 0.5 * _delay_scale())
		"big":
			if t == MatchSimulation.EV_PEN_SAVE or t == MatchSimulation.EV_PEN_MISS or t == MatchSimulation.EV_PENALTY_AWARDED:
				AudioManager.play("chance", -4.0)
				_hold = maxf(_hold, 0.9 * _delay_scale())
		"chance":
			if t == MatchSimulation.EV_POST or (ev.has("x") and float(ev["x"].get("xg", 0.0)) >= 0.3):
				AudioManager.play("chance", -8.0)
		"var":
			_hold = maxf(_hold, 0.8 * _delay_scale())
	if t == MatchSimulation.EV_OFFSIDE and style == "big":
		AudioManager.play("whistle", -8.0)
		_hold = maxf(_hold, 0.9 * _delay_scale())
	if t == MatchSimulation.EV_HALFTIME:
		AudioManager.play("whistle", -4.0)
	elif t == MatchSimulation.EV_FULLTIME:
		AudioManager.play("whistle_end", -3.0)


func _celebrate(ev: Dictionary) -> void:
	_record_scorer(ev)
	_shown_score = [int(ev["hs"]), int(ev["as"])]
	var side: int = ev["s"]
	var x: Dictionary = ev.get("x", {})
	var tags: Array = x.get("tags", [])
	var imp: float = float(x.get("imp", 0.4))
	var ours := side == _user_side
	var level := GoalOverlay.level_for(imp, tags, ours)
	var scorer := _player_name(side, int(ev["p"]))
	var minute_txt := Fmt.minute(int(ev["m"]), int(ev["h"]))
	var info := "%s   %s %d – %d %s" % [minute_txt, _sim.teams[0].club.abbr, int(ev["hs"]), int(ev["as"]), _sim.teams[1].club.abbr]
	var title := "GOL"
	if ours:
		title = "GOOOOOOL!" if level == 3 else ("GOOOL!" if level == 2 else "GOL!")
	else:
		title = "GOL DO %s" % _sim.teams[side].club.short_name.to_upper()
	var c1: Color = _colors[0] if side == 0 else _colors[2]
	var c2: Color = _colors[1] if side == 0 else _colors[3]
	var dur := _overlay.play(level, title, scorer, GoalOverlay.tag_text(tags), info, c1, c2, 1.0 if _pace < 2 else 0.5)
	_hold = maxf(_hold, dur + 0.2)
	_pitch.goal_effect(side, c1)
	var sc_mp: MatchPlayer = _sim.teams[side].by_id.get(int(ev["p"]), null)
	_pitch.motion.celebrate(side, sc_mp.slot if sc_mp != null and sc_mp.on_pitch and int(ev["t"]) == MatchSimulation.EV_GOAL else -1)
	AudioManager.goal(imp if level != 3 else maxf(imp, 0.8), ours)
	if _pace == 0:
		_hold += 1.8 # tempo de ver os times voltando para a saída
	var tw := create_tween()
	tw.tween_interval(dur)
	tw.tween_callback(func(): _pitch.motion.kickoff(1 - side, false))


func _player_name(side: int, pid: int) -> String:
	for s in [side, 1 - side]:
		var mp: MatchPlayer = _sim.teams[s].by_id.get(pid, null)
		if mp != null:
			return mp.p.display_name()
	return ""


## Artilheiros a partir de todos os gols da simulação (ao pular para o fim, a narração pendente some).
func _rebuild_scorers() -> void:
	_scorers = [[], []]
	for ev in _sim.events:
		var t := int(ev["t"])
		if t == MatchSimulation.EV_GOAL or t == MatchSimulation.EV_OWN_GOAL:
			_record_scorer(ev)
	_shown_score = [_sim.score[0], _sim.score[1]]


func _record_scorer(ev: Dictionary) -> void:
	var side: int = ev["s"]
	var scorer := _player_name(side, int(ev["p"]))
	var x: Dictionary = ev.get("x", {})
	var suffix := ""
	if int(ev["t"]) == MatchSimulation.EV_OWN_GOAL:
		suffix = " (contra)"
	elif int(x.get("ct", -1)) == MatchSimulation.CH_PENALTY:
		suffix = " (p)"
	var m := Fmt.minute(int(ev["m"]), int(ev["h"])) + suffix
	var list: Array = _scorers[side]
	for item in list:
		if item[0] == scorer:
			item[1].append(m)
			return
	list.append([scorer, [m]])


const SCRIPTED_EVENTS: Array[int] = [MatchSimulation.EV_GOAL, MatchSimulation.EV_OWN_GOAL, MatchSimulation.EV_SAVE, MatchSimulation.EV_MISS,
	MatchSimulation.EV_POST, MatchSimulation.EV_BLOCK, MatchSimulation.EV_PEN_SAVE, MatchSimulation.EV_PEN_MISS, MatchSimulation.EV_PENALTY_AWARDED,
	MatchSimulation.EV_FOUL, MatchSimulation.EV_YELLOW, MatchSimulation.EV_RED, MatchSimulation.EV_OFFSIDE, MatchSimulation.EV_CORNER,
	MatchSimulation.EV_FREEKICK, MatchSimulation.EV_SKILL, MatchSimulation.EV_TACKLE, MatchSimulation.EV_KEEPER, MatchSimulation.EV_VAR]
const CHANCE_RES := {
	MatchSimulation.EV_GOAL: "goal", MatchSimulation.EV_OWN_GOAL: "goal", MatchSimulation.EV_SAVE: "save",
	MatchSimulation.EV_MISS: "miss", MatchSimulation.EV_POST: "post", MatchSimulation.EV_BLOCK: "block",
	MatchSimulation.EV_PEN_SAVE: "pen_save", MatchSimulation.EV_PEN_MISS: "miss",
}


func _slot_of(side: int, pid: int) -> int:
	if side < 0 or pid < 0:
		return -1
	var mp: MatchPlayer = _sim.teams[side].by_id.get(pid, null)
	return mp.slot if mp != null and mp.on_pitch else -1


func _find_ev(types: Array) -> Dictionary:
	for i in range(_sim.last_events.size() - 1, -1, -1):
		var e: Dictionary = _sim.last_events[i]
		if types.has(int(e["t"])):
			return e
	return {}


## Traduz a fase do minuto (e os eventos dele) numa jogada encenada pelo PitchMotion.
func _script_play() -> void:
	var ph: Dictionary = _sim.last_phase
	if ph.is_empty() or is_same(ph, _last_phase):
		return
	_last_phase = ph
	var ev := int(ph.get("ev", -1))
	if ev in [MatchSimulation.EV_KICKOFF, MatchSimulation.EV_SECOND_HALF, MatchSimulation.EV_EXTRA_TIME]:
		return
	var side := int(ph.get("side", 0))
	var info := {"side": side, "zone": float(ph.get("to", 0.5))}
	var mo := _pitch.motion
	if CHANCE_RES.has(ev):
		var e := _find_ev(CHANCE_RES.keys())
		if e.is_empty():
			mo.ambient(side, float(ph.get("to", 0.5)))
			return
		var t := int(e["t"])
		var x: Dictionary = e.get("x", {})
		info["kind"] = "chance"
		info["ct"] = int(ph.get("ct", x.get("ct", 0)))
		info["res"] = CHANCE_RES[t]
		if t == MatchSimulation.EV_OWN_GOAL:
			info["own"] = true
			info["sh"] = _slot_of(1 - side, int(e["p"]))
		else:
			info["sh"] = _slot_of(side, int(e["p"]))
			info["as"] = _slot_of(side, int(e.get("p2", -1)))
		if x.has("line"):
			info["line"] = _slot_of(1 - side, int(x["line"]))
		if x.has("culprit"):
			info["culprit"] = _slot_of(1 - side, int(x["culprit"]))
		if int(info["ct"]) == MatchSimulation.CH_PENALTY:
			var pa := _find_ev([MatchSimulation.EV_PENALTY_AWARDED])
			if not pa.is_empty():
				info["pen"] = {"victim": _slot_of(side, int(pa["p"])), "fouler": _slot_of(1 - side, int(pa.get("p2", -1)))}
	elif ev == MatchSimulation.EV_FOUL:
		var f := _find_ev([MatchSimulation.EV_FOUL])
		if f.is_empty():
			return
		info["kind"] = "foul"
		info["p"] = _slot_of(1 - side, int(f["p"]))
		info["p2"] = _slot_of(side, int(f.get("p2", -1)))
		info["danger"] = bool(f.get("x", {}).get("danger", false))
		info["zone"] = float(ph.get("to", 0.5))
		var c := _find_ev([MatchSimulation.EV_YELLOW, MatchSimulation.EV_RED])
		if not c.is_empty() and int(c["p"]) == int(f["p"]):
			info["card"] = 2 if int(c["t"]) == MatchSimulation.EV_RED else 1
			# Expulso: o slot já saiu do campo na simulação; o cartão aparece antes de ele sair.
			if info["p"] == -1:
				var mp: MatchPlayer = _sim.teams[1 - side].by_id.get(int(f["p"]), null)
				if mp != null:
					info["p"] = mp.slot
	elif ev == MatchSimulation.EV_OFFSIDE:
		var o := _find_ev([MatchSimulation.EV_OFFSIDE])
		info["kind"] = "offside"
		info["p"] = _slot_of(side, int(o.get("p", -1))) if not o.is_empty() else -1
	elif ev == MatchSimulation.EV_CORNER:
		var cn := _find_ev([MatchSimulation.EV_CORNER])
		info["kind"] = "corner"
		info["p"] = _slot_of(side, int(cn.get("p", -1))) if not cn.is_empty() else -1
	else:
		var fl := _find_ev([MatchSimulation.EV_SKILL, MatchSimulation.EV_TACKLE, MatchSimulation.EV_KEEPER])
		if fl.is_empty():
			mo.ambient(side, float(ph.get("to", 0.5)))
			return
		var ft := int(fl["t"])
		var fs := int(fl["s"])
		info["side"] = fs
		info["kind"] = {MatchSimulation.EV_SKILL: "skill", MatchSimulation.EV_TACKLE: "tackle", MatchSimulation.EV_KEEPER: "keeper"}[ft]
		info["p"] = _slot_of(fs, int(fl["p"]))
		info["p2"] = _slot_of(1 - fs, int(fl.get("p2", -1)))
	mo.play(info)
	# No ritmo normal a partida espera a jogada; no rápido, só os gols; no turbo, nada.
	var bt := mo.busy_time()
	if _pace == 0:
		_play_delay = minf(bt, 3.4)
	elif _pace == 1 and String(info.get("res", "")) == "goal":
		_play_delay = minf(bt, 1.6)


## Efeitos no campo que não dependem da jogada: lesão, jogador caído, VAR.
func _on_event_visual(ev: Dictionary) -> void:
	var t := int(ev["t"])
	var side := int(ev["s"])
	match t:
		MatchSimulation.EV_INJURY:
			var mp: MatchPlayer = _sim.teams[side].by_id.get(int(ev["p"]), null)
			if mp != null and mp.slot >= 0:
				_pitch.motion.player_down(side, mp.slot, 3.5)
				var a := _pitch.motion.ag(side, mp.slot)
				if a != null:
					a.hurt = 3.5
		MatchSimulation.EV_KNOCK:
			_pitch.motion.player_down(side, _slot_of(side, int(ev.get("p2", -1))), 2.2)
		MatchSimulation.EV_VAR:
			_pitch.motion.var_check(2.0)


## Cor do árbitro que não se confunde com nenhum dos dois uniformes.
func _ref_colors() -> Array[Color]:
	var opts := [[Color("#111111"), Color("#F5D547")], [Color("#F5D547"), Color("#111111")], [Color("#E5484D"), Color("#111111")],
		[Color("#3DBE7A"), Color("#111111")], [Color("#4EA8DE"), Color("#111111")], [Color("#9B5DE5"), Color("#FFFFFF")]]
	var best: Array = opts[0]
	var best_d := -1.0
	for o in opts:
		var c: Color = o[0]
		var d := minf(_cdist(c, _colors[0]), _cdist(c, _colors[2]))
		d = minf(d, minf(_cdist(c, _colors[1]), _cdist(c, _colors[3])) + 0.25)
		if d > best_d:
			best_d = d
			best = o
	var out: Array[Color] = [best[0], best[1]]
	return out


func _sync_slots() -> void:
	for side in 2:
		var t: MatchTeam = _sim.teams[side]
		var fslots: Array = t.formation["slots"]
		var arr: Array = []
		for i in fslots.size():
			var s: Dictionary = fslots[i]
			var mp: MatchPlayer = t.slots[i] if i < t.slots.size() else null
			var e := {"x": s["x"], "y": s["y"], "number": mp.p.shirt if mp != null else 0, "on": mp != null,
				"name": mp.p.display_name() if mp != null else "", "role": String(s.get("role", "CM")),
				"gk": String(s.get("role", "")) == "GK" or int(s.get("pos", -1)) == Pos.GK}
			if mp != null and mp.p.position == Pos.GK and int(s.get("pos", -1)) == Pos.GK:
				var gk := t.club.gk_kit()
				e["c1"] = Color(String(gk.get("c1", "#111111")))
				e["c2"] = Color(String(gk.get("c2", "#FFFFFF")))
			arr.append(e)
		if side == 0:
			_pitch.home_slots = arr
		else:
			_pitch.away_slots = arr
		_pitch.motion.set_team(side, arr)


func _update_board() -> void:
	if _done:
		_shown_score = [_sim.score[0], _sim.score[1]]
	_score_lbl.text = "%d – %d" % [_shown_score[0], _shown_score[1]]
	if _sim.shootout or _sim.pen_taken[0] + _sim.pen_taken[1] > 0:
		_score_lbl.text += "  (%d–%d)" % [_sim.pen_score[0], _sim.pen_score[1]]
	if _done or _sim.finished:
		_clock_lbl.text = "Fim de jogo"
	elif _halftime:
		_clock_lbl.text = "Prorrogação" if _sim.et_pending else "Intervalo"
	elif _sim.shootout:
		_clock_lbl.text = "Pênaltis"
	else:
		_clock_lbl.text = Fmt.minute(_sim.minute, _sim.half)
	if _pitch != null:
		_pitch.board = {"h": _sim.teams[0].club.abbr, "a": _sim.teams[1].club.abbr, "hs": _shown_score[0], "as": _shown_score[1], "clock": _clock_lbl.text}
	_home_scorers.text = _scorer_text(0)
	_away_scorers.text = _scorer_text(1)
	var ph := _sim.possession_pct(0)
	_poss_home.size_flags_stretch_ratio = maxf(0.05, ph)
	_poss_away.size_flags_stretch_ratio = maxf(0.05, 1.0 - ph)
	_poss_lbl_h.text = Fmt.percent(ph)
	_poss_lbl_a.text = Fmt.percent(1.0 - ph)
	var h: MatchTeam = _sim.teams[0]
	var a: MatchTeam = _sim.teams[1]
	_stats_lbl.text = "Finalizações %d – %d  ·  No gol %d – %d  ·  Escanteios %d – %d" % [h.shots, a.shots, h.on_target, a.on_target, h.corners, a.corners]
	if _momentum != null:
		_momentum.refresh(_sim.pressure, _goal_marks())


func _goal_marks() -> Array:
	var out: Array = []
	for ev in _sim.events:
		var t: int = ev["t"]
		if t == MatchSimulation.EV_GOAL or t == MatchSimulation.EV_OWN_GOAL:
			out.append([int(ev["h"]), int(ev["m"]), int(ev["s"])])
	return out


## Segundo tempo (e 2º da prorrogação): os times trocam de lado no campo.
func _update_sides() -> void:
	var sw := _sim.half % 2 == 0
	if sw == _swapped:
		return
	_swapped = sw
	_pitch.swapped = sw
	_pitch.motion.kickoff(1 if sw else 0, true)
	if sw and _sim.half == 2:
		_enqueue(_com.extra_line("sides_swap", "info", 0, 2), {}, 0.3)


## Resumo dos números a cada 15 minutos (na narração).
func _stat_summary() -> void:
	var m := _sim.minute
	if _sim.half > 2 or m % 15 != 0 or m == 0 or m == 45 or m == 90:
		return
	var key := "%d:%d" % [_sim.half, m]
	if _stat_marks.has(key):
		return
	_stat_marks[key] = true
	# Aos 30' e 75' fala o comentarista; aos 15' e 60' saem os números.
	if m == 30 or m == 75:
		var an := _com.analysis_line(m, _sim.half)
		if not an.is_empty():
			_enqueue(an, {}, 0.1)
			return
	var h: MatchTeam = _sim.teams[0]
	var a: MatchTeam = _sim.teams[1]
	var txt := "Números até aqui: posse %s x %s, finalizações %d x %d, no gol %d x %d." % [Fmt.percent(_sim.possession_pct(0)), Fmt.percent(_sim.possession_pct(1)), h.shots, a.shots, h.on_target, a.on_target]
	_enqueue({"text": txt, "style": "info", "side": -1, "minute": Fmt.minute(m, _sim.half)}, {}, 0.1)


func _scorer_text(side: int) -> String:
	var parts: Array[String] = []
	for item in _scorers[side]:
		parts.append("%s %s" % [item[0], ", ".join(PackedStringArray(item[1]))])
	return "\n".join(PackedStringArray(parts))


func _add_line(line: Dictionary) -> void:
	var style: String = line.get("style", "normal")
	var side: int = int(line.get("side", -1))
	var row := UIKit.hbox(10)
	var bar := ColorRect.new()
	bar.custom_minimum_size = Vector2(5, 0)
	bar.color = _side_color(side)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bar)
	var m := UIKit.label(String(line.get("minute", "")), "Mono")
	m.custom_minimum_size.x = 76
	m.add_theme_color_override(&"font_color", UIColors.DIM)
	row.add_child(m)
	var variation := "H3" if style in ["goal", "big"] else ""
	var t := UIKit.label(String(line.get("text", "")), variation, true)
	var col := UIColors.TEXT
	match style:
		"info":
			col = UIColors.MUTED
		"chance":
			col = Color("#FFE08A")
		"goal":
			col = UIColors.ACCENT
		"card_y":
			col = Color("#F5D547")
		"card_r":
			col = UIColors.RED
		"sub":
			col = UIColors.BLUE
		"injury":
			col = UIColors.ORANGE
		"crowd":
			col = Color("#B9C4D0")
		"var":
			col = Color("#9AD0FF")
		"tactic":
			col = UIColors.BLUE
		"pundit":
			col = Color("#8FD9C5")
		"reporter":
			col = Color("#F2C58A")
		"other":
			col = Color("#C9E7A8")
	t.add_theme_color_override(&"font_color", UIColors.ink(col))
	row.add_child(t)
	var node: Control = row
	if style == "goal":
		var p := PanelContainer.new()
		var box := StyleBoxFlat.new()
		var sc := _side_color(side)
		box.bg_color = Color(sc.r * 0.35, sc.g * 0.35, sc.b * 0.35, 0.9)
		box.border_color = UIColors.ACCENT
		box.border_width_left = 4
		box.set_corner_radius_all(10)
		box.content_margin_left = 8
		box.content_margin_right = 10
		box.content_margin_top = 8
		box.content_margin_bottom = 8
		p.add_theme_stylebox_override(&"panel", box)
		p.add_child(row)
		node = p
	_feed.add_child(node)
	_feed.move_child(node, 0)
	while _feed.get_child_count() > FEED_MAX:
		var last := _feed.get_child(_feed.get_child_count() - 1)
		_feed.remove_child(last)
		last.queue_free()


func _update_ticker(delta: float) -> void:
	if _ticker == null or _div_entries.is_empty() or _done:
		return
	_ticker_t -= delta
	if _ticker_t > 0.0:
		return
	_ticker_t = 3.2
	if not GameManager.ai_ready() and not _done:
		_ticker.text = "Outros jogos em andamento…"
		return
	var minute := _sim.minute
	var half := _sim.half
	# Primeiro: algum gol novo nos outros jogos da divisão?
	for i in _div_entries.size():
		var e: Dictionary = _div_entries[i]
		var sc := _score_of(e, minute, half)
		var total: int = sc[0] + sc[1]
		if total > int(_ticker_seen.get(i, 0)):
			_ticker_seen[i] = total
			_ticker.text = "GOL  ·  " + _entry_text(e, sc)
			_ticker.add_theme_color_override(&"font_color", UIColors.ACCENT)
			return
	_ticker_i = (_ticker_i + 1) % _div_entries.size()
	var e2: Dictionary = _div_entries[_ticker_i]
	_ticker.text = _entry_text(e2, _score_of(e2, minute, half))
	_ticker.add_theme_color_override(&"font_color", UIColors.MUTED)


func _build_strip() -> Control:
	_strip_scroll = ScrollContainer.new()
	_strip_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_strip_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_strip_scroll.custom_minimum_size.y = 58
	_strip_scroll.scroll_deadzone = 14
	var row := UIKit.hbox(6)
	_strip_scroll.add_child(row)
	var w := world()
	var live := PanelContainer.new()
	var lb := StyleBoxFlat.new()
	lb.bg_color = UIColors.RED.darkened(0.15)
	lb.set_corner_radius_all(8)
	lb.content_margin_left = 10
	lb.content_margin_right = 10
	live.add_theme_stylebox_override(&"panel", lb)
	var ll := UIKit.label("AO VIVO", "Caps")
	ll.add_theme_color_override(&"font_color", Color.WHITE)
	ll.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	live.add_child(ll)
	row.add_child(live)
	var list: Array = _div_entries.duplicate()
	list.append_array(_day_entries)
	for e in list:
		var f: Fixture = e["f"]
		var panel := PanelContainer.new()
		var box := StyleBoxFlat.new()
		box.bg_color = Color("#1B1E23")
		box.border_color = Color(1, 1, 1, 0.08)
		box.set_border_width_all(1)
		box.set_corner_radius_all(8)
		box.content_margin_left = 10
		box.content_margin_right = 10
		box.content_margin_top = 4
		box.content_margin_bottom = 4
		panel.add_theme_stylebox_override(&"panel", box)
		var col := UIKit.vbox(0)
		var line := UIKit.hbox(6)
		line.add_child(UIKit.crest(w.club(f.home), 22))
		var sc := UIKit.label("%s 0–0 %s" % [w.club(f.home).abbr, w.club(f.away).abbr], "H3")
		sc.add_theme_font_size_override(&"font_size", 19)
		line.add_child(sc)
		line.add_child(UIKit.crest(w.club(f.away), 22))
		col.add_child(line)
		var info := UIKit.label("", "Small")
		info.add_theme_font_size_override(&"font_size", 14)
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info.visible = false
		col.add_child(info)
		panel.add_child(col)
		row.add_child(panel)
		_strip_chips.append({"e": e, "panel": panel, "score": sc, "info": info, "box": box, "flash": 0.0, "total": 0})
	return _strip_scroll


func _update_strip(delta: float) -> void:
	if _strip_scroll == null:
		return
	# Rolagem contínua (para em cima de um gol recém-saído)
	if _strip_hold > 0.0:
		_strip_hold -= delta
	elif not _done:
		_strip_x += delta * 38.0
		var max_x := maxf(0.0, _strip_scroll.get_h_scroll_bar().max_value - _strip_scroll.size.x)
		if _strip_x > max_x + 60.0:
			_strip_x = 0.0
		_strip_scroll.scroll_horizontal = int(minf(_strip_x, max_x))
	for c: Dictionary in _strip_chips:
		if float(c["flash"]) > 0.0:
			c["flash"] = float(c["flash"]) - delta
			if float(c["flash"]) <= 0.0:
				(c["box"] as StyleBoxFlat).bg_color = Color("#1B1E23")
				(c["box"] as StyleBoxFlat).border_color = Color(1, 1, 1, 0.08)
				(c["info"] as Label).visible = false
	_strip_t -= delta
	if _strip_t > 0.0:
		return
	_strip_t = 0.4
	var w := world()
	var ready := GameManager.ai_ready() or _done
	var minute := _sim.minute
	var half := _sim.half
	for c: Dictionary in _strip_chips:
		var e: Dictionary = c["e"]
		var f: Fixture = e["f"]
		var sc: Array = _score_of(e, minute, half) if ready else [0, 0]
		(c["score"] as Label).text = "%s %d–%d %s" % [w.club(f.home).abbr, int(sc[0]), int(sc[1]), w.club(f.away).abbr]
		var total := int(sc[0]) + int(sc[1])
		if total > int(c["total"]):
			c["total"] = total
			var g := _last_goal(e, minute, half)
			if not g.is_empty():
				var pl: Player = w.player(int(g[2]))
				var who := pl.display_name() if pl != null else ""
				if int(g[3]) == Fixture.GOAL_OWN:
					who += " (contra)"
				(c["info"] as Label).text = "GOL  %s %d'" % [who, int(g[0])]
				(c["info"] as Label).visible = true
			var box: StyleBoxFlat = c["box"]
			box.bg_color = UIColors.ACCENT.darkened(0.55)
			box.border_color = UIColors.ACCENT
			c["flash"] = 6.0
			_strip_hold = 3.5
			var panel: Control = c["panel"]
			_strip_x = maxf(0.0, panel.position.x - 40.0)
			_strip_scroll.scroll_horizontal = int(_strip_x)


## Último gol de outro jogo até o minuto atual: [minuto, lado, jogador, tipo, tempo].
func _last_goal(e: Dictionary, minute: int, half: int) -> Array:
	var res: Dictionary = e["res"]
	if res.is_empty():
		return []
	var last: Array = []
	for g in res["goals"]:
		var gh: int = g[4]
		var gm: int = g[0]
		if gh > half or (gh == half and gm > minute):
			continue
		last = g
	return last


## Gols dos outros jogos da competição entram na narração com o autor.
func _announce_other_goals(minute: int, half: int) -> void:
	if _sim.half > 2:
		return
	var w := world()
	for i in _div_entries.size():
		var e: Dictionary = _div_entries[i]
		var res: Dictionary = e["res"]
		if res.is_empty():
			continue
		var goals: Array = res["goals"]
		var seen := int(_other_seen.get(i, 0))
		var f: Fixture = e["f"]
		var hs := 0
		var as_ := 0
		var n := 0
		for g in goals:
			var gh: int = g[4]
			var gm: int = g[0]
			if gh > half or (gh == half and gm > minute):
				continue
			if int(g[1]) == 0:
				hs += 1
			else:
				as_ += 1
			n += 1
			if n <= seen:
				continue
			var scorer: Player = w.player(int(g[2]))
			var who := scorer.display_name() if scorer != null else "?"
			if int(g[3]) == Fixture.GOAL_OWN:
				who += " (contra)"
			var txt := "%s marca, %s %d x %d %s" % [who, w.club(f.home).short_name, hs, as_, w.club(f.away).short_name]
			_enqueue(_com.extra_line("other_goal", "other", gm, gh, {"txt": txt}), {}, 0.1)
		_other_seen[i] = maxi(seen, n)


func _score_of(e: Dictionary, minute: int, half: int) -> Array:
	var res: Dictionary = e["res"]
	if _done and not res.is_empty():
		return [int(res["hg"]), int(res["ag"])]
	return GameManager.live_score(e, minute, half)


func _entry_text(e: Dictionary, sc: Array) -> String:
	var f: Fixture = e["f"]
	var w := world()
	return "%s %d – %d %s" % [w.club(f.home).short_name, sc[0], sc[1], w.club(f.away).short_name]


# ---------------------------------------------------------------------------
# Abas (lances, números, rodada, tabela ao vivo)
# ---------------------------------------------------------------------------

func _tab_list() -> Array:
	var out: Array = [["feed", "Lances"], ["stats", "Números"]]
	if not _div_entries.is_empty() or not _day_entries.is_empty():
		out.append(["round", "Rodada"])
	if _fx.is_league() or _fx.stage == Fixture.STAGE_GROUP:
		out.append(["table", "Tabela"])
	return out


func _build_tabs() -> void:
	UIKit.clear(_tabs_row)
	var g := ButtonGroup.new()
	for t in _tab_list():
		var key: String = t[0]
		var chip := UIKit.chip(t[1], key == _tab, g, func(): _set_tab(key))
		UIKit.shrink_button(chip)
		chip.add_theme_font_size_override(&"font_size", 18)
		_tabs_row.add_child(chip)


func _set_tab(key: String) -> void:
	if key != _tab:
		_tab = key
		_build_tabs()
	_feed_scroll.visible = key == "feed"
	_tab_scroll.visible = key != "feed"
	_tab_minute = -99
	_refresh_tab_if_needed()


## Redesenha a aba aberta quando o relógio anda (não a cada quadro).
func _refresh_tab_if_needed() -> void:
	if _tab == "feed" or _done or _tab_box == null:
		return
	var stamp := _sim.half * 1000 + _sim.minute
	if not GameManager.ai_ready() and _tab in ["round", "table"]:
		stamp -= 500 # atualiza de novo quando os outros jogos terminarem de calcular
	if stamp == _tab_minute:
		return
	_tab_minute = stamp
	UIKit.clear(_tab_box)
	match _tab:
		"stats":
			_render_stats_tab()
		"round":
			_render_round_tab()
		"table":
			_render_table_tab()


func _render_stats_tab() -> void:
	var card := UIKit.card("Card", 6)
	var hdr := UIKit.hbox(8)
	var hl := UIKit.label(_sim.teams[0].club.short_name, "H3")
	hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(hl)
	var al := UIKit.label(_sim.teams[1].club.short_name, "H3")
	al.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	al.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hdr.add_child(al)
	card.add_child(hdr)
	card.add_child(_stats_table(true))
	var fm := UIKit.label("%s  ·  Formação  ·  %s" % [_sim.teams[0].formation_name, _sim.teams[1].formation_name], "Small")
	fm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(fm)
	_tab_box.add_child(UIKit.card_panel(card))
	# Notas ao vivo e fôlego do seu time
	var rc := UIKit.card("Card", 4)
	rc.add_child(UIKit.section("Seu time em campo"))
	for mp: MatchPlayer in _sim.teams[_user_side].slots:
		if mp == null:
			continue
		var row := UIKit.hbox(10)
		row.add_child(UIKit.pos_badge(mp.pos))
		var col := UIKit.vbox(2)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var nm := mp.p.display_name()
		if mp.goals > 0:
			nm += "  %dG" % mp.goals
		if mp.assists > 0:
			nm += "  %dA" % mp.assists
		if mp.yellow > 0:
			nm += "  (amarelo)"
		col.add_child(UIKit.label(nm, ""))
		var cond_col := UIColors.GREEN if mp.cond >= 75.0 else (UIColors.ORANGE if mp.cond >= 60.0 else UIColors.RED)
		col.add_child(UIKit.bar(mp.cond, 100.0, cond_col, 6))
		row.add_child(col)
		var live := clampf(6.0 + mp.rating_pts, 3.0, 10.0)
		var r := UIKit.label(Fmt.rating(live), "H3")
		r.add_theme_color_override(&"font_color", Fmt.match_rating_color(live))
		r.custom_minimum_size.x = 48
		r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(r)
		rc.add_child(row)
	_tab_box.add_child(UIKit.card_panel(rc))


func _render_round_tab() -> void:
	if not GameManager.ai_ready():
		_tab_box.add_child(UIKit.label("Outros jogos em andamento… os placares aparecem em instantes.", "Muted", true))
		return
	var minute := _sim.minute if _sim.half <= 2 else 90
	var half := mini(_sim.half, 2)
	var clock := "Fim" if _sim.finished else Fmt.minute(_sim.minute, _sim.half)
	if not _div_entries.is_empty():
		_tab_box.add_child(_round_card("%s · %s" % [CompText.comp_short(world(), _fx.comp), clock], _div_entries, minute, half, true))
	if not _day_entries.is_empty():
		_tab_box.add_child(_round_card("Outras divisões · %s" % clock, _day_entries, minute, half, false))


func _round_card(title: String, list: Array, minute: int, half: int, scorers: bool) -> Control:
	var w := world()
	var card := UIKit.card("Card", 4)
	card.add_child(UIKit.section(title))
	var last_comp := ""
	for e in list:
		var f: Fixture = e["f"]
		if not scorers and f.comp != last_comp:
			last_comp = f.comp
			card.add_child(UIKit.label(CompText.comp_short(w, f.comp), "Caps"))
		var sc := _score_of(e, minute, half)
		var row := UIKit.hbox(8)
		var hn := UIKit.label(w.club(f.home).short_name, "")
		hn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hn.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hn.clip_text = true
		row.add_child(hn)
		row.add_child(UIKit.crest(w.club(f.home), 26))
		var sl := UIKit.label("%d – %d" % [sc[0], sc[1]], "H3")
		sl.custom_minimum_size.x = 76
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(sl)
		row.add_child(UIKit.crest(w.club(f.away), 26))
		var an := UIKit.label(w.club(f.away).short_name, "")
		an.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		an.clip_text = true
		row.add_child(an)
		card.add_child(row)
		if scorers:
			var txt := _entry_scorers(e, minute, half)
			if txt != "":
				var l := UIKit.label(txt, "Small", true)
				l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				card.add_child(l)
	return UIKit.card_panel(card)


func _entry_scorers(e: Dictionary, minute: int, half: int) -> String:
	var res: Dictionary = e["res"]
	if res.is_empty():
		return ""
	var parts: Array[String] = []
	for g in res["goals"]:
		var gh: int = g[4]
		var gm: int = g[0]
		if not _done and (gh > half or (gh == half and gm > minute)):
			continue
		var p: Player = world().player(int(g[2]))
		parts.append("%s %s%s" % [p.short_name() if p != null else "?", Fmt.minute(gm, gh), " (c)" if int(g[3]) == Fixture.GOAL_OWN else ""])
	return "  ·  ".join(PackedStringArray(parts))


## Classificação como estaria se os jogos acabassem agora (setas: posição antes da rodada).
func _render_table_tab() -> void:
	var w := world()
	var minute := _sim.minute if _sim.half <= 2 else 90
	var half := mini(_sim.half, 2)
	var ids: Array = []
	var base: Dictionary = {}
	var title := ""
	var league: League = null
	if _fx.is_league():
		league = w.league(_fx.comp)
		if league == null:
			return
		ids = league.club_ids
		base = league.table
		title = "Tabela ao vivo · %s" % league.short_name
	else:
		var cup: Cup = w.season.cups.get(_fx.comp, null)
		var g: Dictionary = cup.group_of(_fx.home) if cup != null else {}
		if g.is_empty():
			return
		ids = g["clubs"]
		base = g["table"]
		title = "Grupo %s ao vivo · %s" % [g["n"], cup.short_name]
	var before := CompetitionManager.sort_table(ids, base)
	var live: Dictionary = {}
	for cid in ids:
		live[cid] = base[cid].duplicate()
	var entries: Array = _div_entries.duplicate()
	entries.append({"f": _fx, "res": {}, "user": true})
	var pending := false
	for e in entries:
		var f: Fixture = e["f"]
		if not live.has(f.home) or not live.has(f.away):
			continue
		var sc: Array
		if e.has("user"):
			sc = [_sim.score[0], _sim.score[1]]
		else:
			if not GameManager.ai_ready():
				pending = true
			sc = _score_of(e, minute, half)
		var tmp := Fixture.new()
		tmp.home = f.home
		tmp.away = f.away
		tmp.hg = int(sc[0])
		tmp.ag = int(sc[1])
		CompetitionManager.apply_to_table(live, tmp)
	var order := CompetitionManager.sort_table(ids, live)
	var card := UIKit.card("Card", 2)
	card.add_child(UIKit.section(title))
	if pending:
		card.add_child(UIKit.label("Calculando os outros jogos…", "Muted"))
	for i in order.size():
		var cid: int = order[i]
		var pos := i + 1
		var zone := Color(0, 0, 0, 0)
		if league != null:
			zone = CompetitionManager.zone_color(CompetitionManager.zone_of(league, pos))
		elif pos <= 2:
			zone = CompetitionManager.zone_color(CompetitionManager.ZONE_PROMOTION)
		card.add_child(_live_row(cid, pos, before.find(cid) + 1, live[cid], zone))
	if league != null:
		card.add_child(UIKit.gap(6))
		card.add_child(TableRows.legend(league))
	_tab_box.add_child(UIKit.card_panel(card))


func _live_row(cid: int, pos: int, pos_before: int, r: Dictionary, zone: Color) -> Control:
	var w := world()
	var cl := w.club(cid)
	var is_user := w.is_user_club(cid)
	var h := UIKit.hbox(6)
	var bar := ColorRect.new()
	bar.custom_minimum_size = Vector2(5, 0)
	bar.color = zone
	h.add_child(bar)
	var pl := UIKit.label(str(pos), "H3")
	pl.custom_minimum_size.x = 34
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(pl)
	var mv := ""
	var mv_col := UIColors.DIM
	if pos < pos_before:
		mv = "▲"
		mv_col = UIColors.GREEN
	elif pos > pos_before:
		mv = "▼"
		mv_col = UIColors.RED
	var ml := UIKit.label(mv, "Small")
	ml.custom_minimum_size.x = 22
	ml.add_theme_color_override(&"font_color", mv_col)
	h.add_child(ml)
	h.add_child(UIKit.crest(cl, 28))
	var n := UIKit.label(cl.short_name, "H3" if is_user else "")
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if is_user:
		n.add_theme_color_override(&"font_color", UIColors.ACCENT)
	h.add_child(n)
	for v in [str(r["pl"]), Fmt.signed(int(r["gf"]) - int(r["ga"])), str(r["pts"])]:
		var l := UIKit.label(v, "H3" if v == str(r["pts"]) else "")
		l.custom_minimum_size.x = 50
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(l)
	return h


# ---------------------------------------------------------------------------
# Controles
# ---------------------------------------------------------------------------

func _toggle_play() -> void:
	if _done:
		return
	if _halftime:
		_start_second_half()
		return
	_paused = not _paused
	_update_play_button()


func _start_second_half() -> void:
	_halftime = false
	_paused = false
	_clock = 0.5
	UIManager.close_all_modals()
	_update_play_button()


func _cycle_speed() -> void:
	_pace = (_pace + 1) % PACE.size()
	_speed_btn.text = PACE_NAMES[_pace]
	_clock = minf(_clock, PACE[_pace])
	_pitch.motion.tempo = TEMPO[_pace]
	# A preferência padrão acompanha a escolha (Normal/Rápido); o turbo é só desta partida.
	if _pace < 2:
		AppSettings.match_speed = AppSettings.SPEED_NORMAL if _pace == 0 else AppSettings.SPEED_FAST
		AppSettings.save_settings()


func _confirm_skip() -> void:
	if _done:
		return
	UIManager.confirm("Ir para o fim?", "A partida será simulada até o apito final. Você não poderá mais fazer ajustes.", "Ir para o fim", _skip_to_end)


func _skip_to_end() -> void:
	_overlay.skip()
	_queue.clear()
	_hold = 0.0
	_halftime = false
	_pending_halftime = false
	_sim.run_to_end()
	_drain(true)
	_rebuild_scorers()
	_after_step()
	_pending_final = false
	_on_final()


## Antes da primeira cobrança: o técnico escolhe a ordem dos batedores em campo.
func _show_shootout_order() -> void:
	var players: Array = []
	for mp: MatchPlayer in _sim.shootout_kickers(_user_side):
		players.append(mp.p)
	var auto := ShootoutOrderView.ordered(players, [])
	var v := ShootoutOrderView.build("Disputa de pênaltis",
		"Escolha quem bate. Os cinco primeiros cobram as regulares; depois vêm as alternadas.",
		players, auto, func(ids: Array):
			_sim.set_shootout_order(_user_side, ids)
			UIManager.close_modal())
	v.custom_minimum_size.x = 600
	UIManager.show_modal(v, true, false)


# ---------------------------------------------------------------------------
# Intervalo
# ---------------------------------------------------------------------------

func _show_halftime() -> void:
	var v := UIKit.vbox(14)
	v.custom_minimum_size.x = 600
	var et := _sim.et_pending
	v.add_child(UIKit.label("Fim do tempo normal · prorrogação" if et else "Intervalo", "Title", true))
	var sc := UIKit.label("%s  %d – %d  %s" % [_sim.teams[0].club.short_name, _sim.score[0], _sim.score[1], _sim.teams[1].club.short_name], "H2", true)
	sc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sc)
	v.add_child(_stats_table(false))
	v.add_child(_halftime_hint())
	var others := _other_scores(90 if et else 45, 2 if et else 1)
	if others != null:
		v.add_child(others)
	var row := UIKit.vbox(10)
	var ut: MatchTeam = _sim.teams[_user_side]
	if _sim.can_talk(_user_side):
		row.add_child(UIKit.button("Palestra no vestiário", "", func():
			UIManager.close_modal()
			_open_talk(true), "mail"))
	elif ut.talk_key != "":
		row.add_child(UIKit.colored("Palestra: %s" % String(MatchSimulation.TALKS[ut.talk_key]["short"]), UIColors.ACCENT, "Small"))
	row.add_child(UIKit.button("Ajustes táticos e substituições", "", func():
		UIManager.close_modal()
		_open_tactics(), "tactics"))
	row.add_child(UIKit.button("INICIAR PRORROGAÇÃO" if et else "INICIAR 2º TEMPO", "PrimaryButton", _start_second_half, "whistle"))
	v.add_child(row)
	UIManager.show_modal(v, false, false)


## Leitura rápida do primeiro tempo para ajudar a decidir (sem números mágicos escondidos).
func _halftime_hint() -> Label:
	var me: MatchTeam = _sim.teams[_user_side]
	var op: MatchTeam = _sim.teams[1 - _user_side]
	var diff: int = _sim.score[_user_side] - _sim.score[1 - _user_side]
	var txt := ""
	if me.shots + 3 <= op.shots:
		txt = "O adversário finaliza muito mais. Reforçar a defesa ou mudar o estilo pode segurar a pressão."
	elif me.shots >= op.shots + 3 and diff <= 0:
		txt = "Vocês dominam, mas o gol não saiu. Mais presença na área pode transformar volume em gols."
	elif diff > 0:
		txt = "Vantagem no placar. Controlar o jogo pode ser mais valioso que buscar o segundo gol."
	elif diff < 0:
		txt = "Atrás no placar. Uma mentalidade mais ofensiva abre espaços dos dois lados."
	else:
		txt = "Jogo equilibrado. Observe o cansaço dos seus jogadores antes do segundo tempo."
	var tired := 0
	for mp: MatchPlayer in me.slots:
		if mp != null and mp.cond < 72.0:
			tired += 1
	if tired >= 2:
		txt += " %d jogadores já mostram cansaço." % tired
	return UIKit.label(txt, "Small", true)


func _stats_table(full: bool) -> VBoxContainer:
	var h: MatchTeam = _sim.teams[0]
	var a: MatchTeam = _sim.teams[1]
	var rows: Array = [
		["Posse", Fmt.percent(_sim.possession_pct(0)), Fmt.percent(_sim.possession_pct(1))],
		["Finalizações", str(h.shots), str(a.shots)],
		["Gols esperados (xG)", TacticalXRay.dec(h.xg, 1), TacticalXRay.dec(a.xg, 1)],
		["No gol", str(h.on_target), str(a.on_target)],
		["Escanteios", str(h.corners), str(a.corners)],
		["Faltas", str(h.fouls), str(a.fouls)],
	]
	if full:
		rows.append(["Impedimentos", str(h.offsides), str(a.offsides)])
		rows.append(["Cartões amarelos", str(h.yellows), str(a.yellows)])
		rows.append(["Cartões vermelhos", str(h.reds), str(a.reds)])
		rows.append(["Defesas do goleiro", str(h.saves), str(a.saves)])
	var v := UIKit.vbox(4)
	for r in rows:
		var row := UIKit.hbox(8)
		var l := UIKit.label(r[1], "H3")
		l.custom_minimum_size.x = 90
		row.add_child(l)
		var c := UIKit.label(r[0], "Muted")
		c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(c)
		var rr := UIKit.label(r[2], "H3")
		rr.custom_minimum_size.x = 90
		rr.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(rr)
		v.add_child(row)
	return v


func _other_scores(minute: int, half: int) -> VBoxContainer:
	if _div_entries.is_empty() or not GameManager.ai_ready():
		return null
	var v := UIKit.vbox(4)
	v.add_child(UIKit.section("Outros jogos · %s" % CompText.comp_short(world(), _fx.comp)))
	for e in _div_entries:
		var f: Fixture = e["f"]
		var sc := _score_of(e, minute, half)
		var row := UIKit.hbox(8)
		var hn := UIKit.label(world().club(f.home).short_name, "")
		hn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hn.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hn.clip_text = true
		row.add_child(hn)
		var s := UIKit.label("%d – %d" % [sc[0], sc[1]], "H3")
		s.custom_minimum_size.x = 84
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(s)
		var an := UIKit.label(world().club(f.away).short_name, "")
		an.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		an.clip_text = true
		row.add_child(an)
		v.add_child(row)
	return v


# ---------------------------------------------------------------------------
# Ajustes durante o jogo
# ---------------------------------------------------------------------------

## Palestra no vestiário (antes do pontapé inicial ou no intervalo). O relógio fica parado
## enquanto o modal está aberto; "Sem palestra" segue sem efeito.
func _open_talk(halftime: bool) -> void:
	if _sim == null or not _sim.can_talk(_user_side):
		return
	var v := UIKit.vbox(10)
	v.add_child(UIKit.label("Palestra no intervalo" if halftime else "Palestra antes do jogo", "Title"))
	var diff := _sim.score[_user_side] - _sim.score[1 - _user_side]
	if halftime:
		v.add_child(UIKit.label(("Vencendo por %d." % diff) if diff > 0 else (("Perdendo por %d." % -diff) if diff < 0 else "Empate."), "Muted"))
	for key in MatchSimulation.TALK_ORDER:
		var k: String = key
		var cfg: Dictionary = MatchSimulation.TALKS[k]
		var b := UIKit.button(String(cfg["name"]), "", func():
			var r := _sim.team_talk(_user_side, k)
			UIManager.close_modal()
			UIManager.toast(String(r["msg"]), UIColors.ACCENT if r["ok"] else UIColors.RED)
			_drain(false)
			if halftime:
				_show_halftime(), "")
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		v.add_child(b)
		v.add_child(UIKit.label(String(cfg["desc"]), "Small", true))
	v.add_child(UIKit.button("Sem palestra", "GhostButton", func():
		UIManager.close_modal()
		if halftime:
			_show_halftime()))
	UIManager.show_modal(v, true, false)


## Gritos da beira do campo: efeito curto e real no time (MatchSimulation.shout). O jogo segue rodando.
func _open_shouts() -> void:
	if _done or _sim == null:
		return
	var t: MatchTeam = _sim.teams[_user_side]
	var v := UIKit.vbox(10)
	var head := UIKit.hbox(10)
	var title := UIKit.label("Beira do campo", "Title")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(UIKit.icon_button("close", func(): UIManager.close_modal()))
	v.add_child(head)
	if t.sh_key != "":
		v.add_child(UIKit.colored("Em vigor: %s (até %d')" % [String(MatchSimulation.SHOUTS[t.sh_key]["short"]), t.sh_until], UIColors.ACCENT, "Small"))
	var wait := _sim.shout_wait(_user_side)
	if wait > 0:
		v.add_child(UIKit.label("O time ainda está digerindo o último grito: mais %d min." % wait, "Muted", true))
	for key in MatchSimulation.SHOUT_ORDER:
		var k: String = key
		var cfg: Dictionary = MatchSimulation.SHOUTS[k]
		var uses := int(t.sh_uses.get(k, 0))
		var b := UIKit.button(String(cfg["name"]), "PrimaryButton" if k == t.sh_key else "", func():
			var r := _sim.shout(_user_side, k)
			UIManager.close_modal()
			UIManager.toast(String(r["msg"]), UIColors.ACCENT if r["ok"] else UIColors.RED)
			if r["ok"]:
				_drain(false)
				_update_board(), String(cfg["icon"]))
		b.disabled = wait > 0
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		v.add_child(b)
		var d := String(cfg["desc"])
		if uses >= 1:
			d += " Já usado %s." % Fmt.plural(uses, "vez", "vezes")
		v.add_child(UIKit.label(d, "Small", true))
	UIManager.show_modal(v, true)


func _open_tactics() -> void:
	if _done:
		return
	_sub_out = -1
	_tac_box = UIKit.vbox(12)
	_tac_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_render_tactics()
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.custom_minimum_size = Vector2(0, 880)
	s.scroll_deadzone = 14
	s.add_child(_tac_box)
	UIManager.show_modal(s, true)


func _render_tactics() -> void:
	if _tac_box == null or not is_instance_valid(_tac_box):
		return
	UIKit.clear(_tac_box)
	var t: MatchTeam = _sim.teams[_user_side]
	var head := UIKit.hbox(10)
	var title := UIKit.label("Ajustes da partida" if _sub_out < 0 else "Quem entra?", "Title")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(UIKit.icon_button("close", func(): UIManager.close_modal()))
	_tac_box.add_child(head)
	if _sub_out >= 0:
		_render_bench_choice(t)
		return
	var tac := DatabaseManager.tactics()
	_tac_box.add_child(UIKit.section("Formação"))
	var gf := ButtonGroup.new()
	var fl := UIKit.flow(8)
	for fname in DatabaseManager.formation_names():
		var fn := fname
		fl.add_child(UIKit.chip(fn, fn == t.formation_name, gf, func():
			if _sim.set_formation(_user_side, fn):
				_drain(false)
				_sync_slots()
				_update_board()
			_render_tactics()))
	_tac_box.add_child(fl)
	var fam := TacticsManager.formation_fam(t.club, t.formation_name)
	var fam_l := UIKit.label("Entrosamento com o %s: %s." % [t.formation_name, TacticsManager.fam_label(fam).to_lower()], "Small", true)
	fam_l.add_theme_color_override(&"font_color", TacticsManager.fam_color(fam))
	_tac_box.add_child(fam_l)
	_tac_box.add_child(UIKit.section("Mentalidade"))
	var gm := ButtonGroup.new()
	var ml := UIKit.flow(8)
	for i in 5:
		var idx := i
		ml.add_child(UIKit.chip(String(tac["mentalities"][i]["name"]), i == t.mentality, gm, func():
			_sim.set_mentality(_user_side, idx)
			_drain(false)
			_render_tactics()))
	_tac_box.add_child(ml)
	_tac_box.add_child(UIKit.section("Estilo de jogo"))
	var gs := ButtonGroup.new()
	var sl := UIKit.flow(8)
	for i in 6:
		var idx := i
		sl.add_child(UIKit.chip(String(tac["styles"][i]["short"]), i == t.style, gs, func():
			_sim.set_style(_user_side, idx)
			_drain(false)
			_render_tactics()))
	_tac_box.add_child(sl)
	_tac_box.add_child(UIKit.label(String(tac["styles"][t.style]["desc"]), "Small", true))
	var auto := CheckButton.new()
	auto.text = "Assistente troca jogadores cansados"
	auto.button_pressed = t.auto_subs
	auto.focus_mode = Control.FOCUS_NONE
	auto.toggled.connect(func(v: bool): t.auto_subs = v)
	_tac_box.add_child(auto)
	var left := t.max_subs - t.subs_used
	_tac_box.add_child(UIKit.section("Em campo · substituições %d/%d" % [t.subs_used, t.max_subs]))
	if left <= 0:
		_tac_box.add_child(UIKit.label("Sem substituições restantes.", "Muted"))
	for mp: MatchPlayer in t.slots:
		if mp == null:
			continue
		var pid := mp.p.id
		_tac_box.add_child(_mp_row(mp, mp.pos, func():
			if t.subs_used >= t.max_subs:
				UIManager.toast("Limite de substituições atingido.", UIColors.RED)
				return
			_sub_out = pid
			_render_tactics()))


func _render_bench_choice(t: MatchTeam) -> void:
	var out_mp: MatchPlayer = t.by_id.get(_sub_out, null)
	if out_mp == null or not out_mp.on_pitch:
		_sub_out = -1
		_render_tactics()
		return
	_tac_box.add_child(UIKit.label("Sai: %s (%s, fôlego %d%%)" % [out_mp.p.display_name(), Pos.code(out_mp.pos), int(out_mp.cond)], "Muted", true))
	var cands: Array[MatchPlayer] = []
	for b: MatchPlayer in t.bench:
		if not b.used:
			cands.append(b)
	var pos := out_mp.pos
	cands.sort_custom(func(a: MatchPlayer, b: MatchPlayer): return a.p.rating_at(pos) > b.p.rating_at(pos))
	if cands.is_empty():
		_tac_box.add_child(UIKit.label("Não há reservas disponíveis.", "Muted"))
	for b: MatchPlayer in cands:
		var in_id := b.p.id
		_tac_box.add_child(_mp_row(b, pos, func():
			var err := _sim.user_substitution(_user_side, _sub_out, in_id)
			if err != "":
				UIManager.toast(err, UIColors.RED)
				return
			_sub_out = -1
			_drain(false)
			_sync_slots()
			_update_board()
			_render_tactics()))
	_tac_box.add_child(UIKit.button("Voltar", "GhostButton", func():
		_sub_out = -1
		_render_tactics()))


## Linha de jogador em campo/banco: posição, nome, nota na vaga, fôlego e nota do jogo.
func _mp_row(mp: MatchPlayer, pos: int, cb: Callable) -> Control:
	var row := UIKit.hbox(10)
	row.add_child(UIKit.pos_badge(pos))
	var col := UIKit.vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nm := mp.p.display_name()
	if mp.yellow > 0:
		nm += "  (amarelo)"
	col.add_child(UIKit.label(nm, "H3"))
	var cond_col := UIColors.GREEN if mp.cond >= 75.0 else (UIColors.ORANGE if mp.cond >= 60.0 else UIColors.RED)
	col.add_child(UIKit.bar(mp.cond, 100.0, cond_col, 8))
	row.add_child(col)
	row.add_child(UIKit.badge(int(round(mp.p.rating_at(pos))), 52, 36, 22))
	if mp.used:
		var live := clampf(6.0 + mp.rating_pts, 3.0, 10.0)
		var r := UIKit.label(Fmt.rating(live), "H3")
		r.add_theme_color_override(&"font_color", Fmt.match_rating_color(live))
		r.custom_minimum_size.x = 48
		r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(r)
	return UIKit.tap_row(row, cb)


# ---------------------------------------------------------------------------
# Fim de jogo
# ---------------------------------------------------------------------------

func _on_final() -> void:
	if _done:
		return
	_done = true
	UIManager.close_all_modals()
	_report = GameManager.finish_match()
	var mine: int = _sim.score[_user_side]
	var theirs: int = _sim.score[1 - _user_side]
	if mine > theirs:
		AudioManager.play("win", -4.0)
	elif mine < theirs:
		AudioManager.play("lose", -6.0)
	_update_board()
	_pitch.visible = false
	(_pitch.get_parent() as Control).visible = false
	_stats_box.visible = false
	(_tabs_row.get_parent() as Control).visible = false
	_tab = "feed"
	_feed_scroll.visible = true
	_tab_scroll.visible = false
	_ticker.text = ""
	_build_summary()
	_build_controls()


func _build_summary() -> void:
	UIKit.clear(_feed)
	var mine: int = _sim.score[_user_side]
	var theirs: int = _sim.score[1 - _user_side]
	var res := "VITÓRIA" if mine > theirs else ("DERROTA" if mine < theirs else "EMPATE")
	var res_col := UIColors.GREEN if mine > theirs else (UIColors.RED if mine < theirs else UIColors.MUTED)
	var top := UIKit.hbox(10)
	top.add_child(UIKit.pill(res, res_col, 22))
	top.add_child(UIKit.spacer())
	if _sim.derby:
		top.add_child(UIKit.pill("CLÁSSICO", UIColors.RED, 18))
	_feed.add_child(top)
	# Gols
	var goals := UIKit.card("Card", 6)
	goals.add_child(UIKit.section("Gols"))
	var any := false
	for ev in _sim.events:
		var t: int = ev["t"]
		if t != MatchSimulation.EV_GOAL and t != MatchSimulation.EV_OWN_GOAL:
			continue
		any = true
		var side: int = ev["s"]
		var txt := "%s  %s" % [Fmt.minute(int(ev["m"]), int(ev["h"])), _player_name(side, int(ev["p"]))]
		if t == MatchSimulation.EV_OWN_GOAL:
			txt += " (contra)"
		elif int(ev.get("x", {}).get("ct", -1)) == MatchSimulation.CH_PENALTY:
			txt += " (pên.)"
		var l := UIKit.label(txt, "")
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if side == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		l.add_theme_color_override(&"font_color", UIColors.TEXT if side == _user_side else UIColors.MUTED)
		goals.add_child(l)
	if not any:
		goals.add_child(UIKit.label("Nenhum gol.", "Muted"))
	_feed.add_child(UIKit.card_panel(goals))
	# Craque
	var motm := _sim.man_of_the_match()
	if motm != null:
		var row := UIKit.hbox(12)
		var club := motm.p.club_id
		row.add_child(UIKit.portrait(motm.p, world().club(club), world().year, 72))
		var col := UIKit.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UIKit.label("CRAQUE DO JOGO", "Caps"))
		col.add_child(UIKit.label(motm.p.display_name(), "H2"))
		var bits: Array[String] = []
		if motm.goals > 0:
			bits.append(Fmt.plural(motm.goals, "gol", "gols"))
		if motm.assists > 0:
			bits.append(Fmt.plural(motm.assists, "assistência", "assistências"))
		if motm.saves > 0:
			bits.append(Fmt.plural(motm.saves, "defesa", "defesas"))
		col.add_child(UIKit.label(world().club(club).short_name + ("  ·  " + ", ".join(PackedStringArray(bits)) if not bits.is_empty() else ""), "Small"))
		row.add_child(col)
		var r := UIKit.label(Fmt.rating(motm.final_rating), "Big")
		r.add_theme_color_override(&"font_color", Fmt.match_rating_color(motm.final_rating))
		row.add_child(r)
		var mid := motm.p.id
		_feed.add_child(UIKit.tap_row(row, func(): UIManager.push("player", {"id": mid}), "CardHighlight"))
	# Estatísticas
	var st := UIKit.card("Card", 6)
	var hdr := UIKit.hbox(8)
	var hl := UIKit.label(_sim.teams[0].club.short_name, "H3")
	hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(hl)
	var al := UIKit.label(_sim.teams[1].club.short_name, "H3")
	al.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	al.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hdr.add_child(al)
	st.add_child(hdr)
	st.add_child(_stats_table(true))
	st.add_child(UIKit.section("Pressão ao longo do jogo"))
	var mom := MomentumView.new()
	mom.custom_minimum_size = Vector2(0, 90)
	mom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mom.home_color = _side_color(0)
	mom.away_color = _side_color(1)
	mom.refresh(_sim.pressure, _goal_marks())
	st.add_child(mom)
	_feed.add_child(UIKit.card_panel(st))
	# Notas do seu time
	var rc := UIKit.card("Card", 4)
	rc.add_child(UIKit.section("Notas do seu time"))
	var used: Array[MatchPlayer] = []
	for mp: MatchPlayer in _sim.teams[_user_side].all:
		if mp.used:
			used.append(mp)
	used.sort_custom(func(a: MatchPlayer, b: MatchPlayer):
		if (a.start_min == 0) != (b.start_min == 0):
			return a.start_min == 0
		return Pos.DISPLAY_ORDER.find(a.pos) < Pos.DISPLAY_ORDER.find(b.pos))
	for mp: MatchPlayer in used:
		var row2 := UIKit.hbox(10)
		row2.add_child(UIKit.pos_badge(mp.pos))
		var pname := mp.p.display_name()
		if mp.start_min > 0:
			pname += "  (entrou %d')" % mp.start_min
		var nl := UIKit.label(pname, "")
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nl.clip_text = true
		row2.add_child(nl)
		var marks: Array[String] = []
		if mp.goals > 0:
			marks.append("%dG" % mp.goals)
		if mp.assists > 0:
			marks.append("%dA" % mp.assists)
		if mp.red:
			marks.append("VERM.")
		elif mp.yellow > 0:
			marks.append("AMAR.")
		if mp.injured:
			marks.append("LESÃO")
		if not marks.is_empty():
			row2.add_child(UIKit.label(" ".join(PackedStringArray(marks)), "Small"))
		var rl := UIKit.label(Fmt.rating(mp.final_rating), "H3")
		rl.add_theme_color_override(&"font_color", Fmt.match_rating_color(mp.final_rating))
		rl.custom_minimum_size.x = 52
		rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row2.add_child(rl)
		var ppid := mp.p.id
		rc.add_child(UIKit.tap_row(row2, func(): UIManager.push("player", {"id": ppid}), "CardFlat"))
	_feed.add_child(UIKit.card_panel(rc))
	var others := _other_scores(200, 2)
	if others != null:
		var oc := UIKit.card("Card", 4)
		oc.add_child(others)
		_feed.add_child(UIKit.card_panel(oc))
	_feed_scroll.scroll_vertical = 0
