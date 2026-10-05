extends BaseScreen
## Partida ao vivo: placar, campo 2D, narração, ajustes em tempo real e comemoração de gol.
## A simulação é exatamente a mesma do modo instantâneo; aqui só se controla o ritmo
## (segundos por minuto) e a apresentação dos eventos.

const PACE: Array[float] = [1.25, 0.32, 0.08] # segundos por minuto de jogo
const PACE_NAMES: Array[String] = ["Normal", "Rápido", "Turbo"]
const FEED_MAX := 70
const PITCH_COMPACT := 0.23 # fração da altura do campo (deitado) quando os lances estão em destaque
const FEED_FS := 24 # corpo da narração
const FEED_FS_NEW := 27 # lance mais recente, em cima
const FEED_MIN_H := 130.0 # altura mínima da narração/abas embaixo do campo
const PITCH_MIN_TALL := 320.0 # em pé o campo parte disso e cresce com o espaço que sobra
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
## Narração presa ao campo: cada lance encenado tem marcos (começo, momento decisivo, apito do
## pênalti) e as linhas dele só saem quando a bola chega lá.
var _gates: Dictionary = {} # id do marco -> _elapsed quando o campo passou por ele
var _ev_gate: Dictionary = {} # índice do evento em _sim.events -> {role, s, h, f}
var _gate_clock := 0.0 # só anda com o campo rodando (pausa e janelas não estouram o limite)
var _beat_n := 0
var _busy_wait := 0.0
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
var _bug: Control # selo da emissora + "AO VIVO"
var _l3: PanelContainer # tarja do gol
## Auxiliar durante o jogo: o que já disse e a sugestão que está na tela.
var _aux_state: Dictionary = {}
var _aux_bar: PanelContainer
var _aux_text: Label
var _aux_btn: Button
var _aux_act: Dictionary = {}
var _aux_timer := 0.0
## Replay dos gols: recortes gravados pelo PitchMotion (chave do gol -> recorte), a linha do gol
## na narração (para o botão "Rever") e o que fazer quando o replay acaba.
var _clips: Dictionary = {}
var _goal_rows: Dictionary = {}
var _replay_on := false
var _replay_after: Callable = Callable()
var _pressure_side := -1

# Nós
var _root: VBoxContainer
var _home_name: Label
var _away_name: Label
var _score_lbl: Label
var _clock_lbl: Label
var _home_scorers: Label
var _away_scorers: Label
var _ticker: Label
var _board: ScoreboardView # placar da transmissão (desenha o estado; os rótulos acima são dele)
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
var _sound_btn: Button = null
var _skip_btn: Button
var _overlay: GoalOverlay
var _tac_box: VBoxContainer
var _momentum: MomentumView
var _conditions: Control
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
	_set_live(true)


func on_hide() -> void:
	set_process(false)
	Sfx.crowd_stop()
	_set_live(false)


func _exit_tree() -> void:
	_set_live(false)


func _set_live(on: bool) -> void:
	if is_instance_valid(UIManager.main) and not UIManager.main.is_queued_for_deletion() and UIManager.main.has_method("set_live"):
		UIManager.main.set_live(on)



## Chamado quando a tela troca de ponto de quebra (girar o aparelho): só rearruma.
func refresh() -> void:
	if _built:
		_responsive_layout()


var _wide_body: HBoxContainer = null
var _field_nodes: Array[Control] = []


## Paisagem e tablet: campo e números à esquerda, abas e narração numa coluna à direita.
## No celular em retrato fica tudo empilhado (o placar em cima e os controles embaixo sempre).
func _responsive_layout() -> void:
	var wide := UILayout.is_wide() and UILayout.is_landscape()
	var short_view := wide and get_viewport_rect().size.y < 720.0
	# Em paisagem no celular, preserve campo e comandos. Os detalhes seguem no painel.
	# Em pé com os lances em destaque (ou só narração), a linha de estádio e clima sai do placar:
	# a abertura da narração já diz isso.
	var compact := not wide and AppSettings.match_view != 1
	if is_instance_valid(_conditions):
		_conditions.visible = not short_view and not compact
	if is_instance_valid(_stats_lbl):
		_stats_lbl.visible = not short_view
	if is_instance_valid(_momentum):
		_momentum.visible = not short_view
	# O campo é o protagonista: em pé ele fica vertical e ocupa a maior parte da altura.
	# Com os lances em destaque (padrão), o campo fica deitado e baixo em pé também.
	_pitch.horizontal = wide or AppSettings.match_view == 0
	_pitch.custom_minimum_size.y = _pitch_height()
	if not wide:
		# Em pé o campo cresce com o espaço que sobra, mas a narração sempre fica com umas
		# linhas à vista: com gols no placar ela sumia atrás da barra de botões.
		_pitch.custom_minimum_size.y = minf(_pitch_height(), PITCH_MIN_TALL)
		# Com os lances em destaque, o espaço que sobra vai para a narração, não para o campo.
		var pb := _pitch.get_parent() as Control
		pb.size_flags_vertical = Control.SIZE_EXPAND_FILL if AppSettings.match_view == 1 else Control.SIZE_FILL
		pb.size_flags_stretch_ratio = 6.0
	if wide == (_wide_body != null):
		return
	var pitch_box := _pitch.get_parent()
	var tabs_box := _tabs_row.get_parent()
	# Keep stable references: after rotation these nodes no longer belong to _root.
	# Looking them up by sibling index could select the wide container itself and
	# delete the goal banner when rotating back to portrait.
	var right_nodes: Array = [tabs_box, _feed_scroll, _tab_scroll]
	if wide:
		var at := pitch_box.get_index()
		_wide_body = UIKit.hbox(0)
		_wide_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var lv := UIKit.vbox(0)
		lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lv.size_flags_stretch_ratio = 1.4
		var rv := UIKit.vbox(0)
		rv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for n: Node in _field_nodes:
			n.get_parent().remove_child(n)
			lv.add_child(n)
		for n: Node in right_nodes:
			_root.remove_child(n)
			rv.add_child(n)
		(pitch_box as Control).size_flags_vertical = Control.SIZE_EXPAND_FILL
		_wide_body.add_child(lv)
		var sep := ColorRect.new()
		sep.color = UITokens.HAIRLINE if not UIColors.light else UIColors.LINE
		sep.custom_minimum_size.x = 1
		sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_wide_body.add_child(sep)
		_wide_body.add_child(rv)
		_root.add_child(_wide_body)
		_root.move_child(_wide_body, at)
	else:
		var at := _wide_body.get_index()
		var order: Array = _field_nodes + right_nodes
		for n: Node in order:
			n.get_parent().remove_child(n)
			_root.add_child(n)
			_root.move_child(n, at)
			at += 1
		(pitch_box as Control).size_flags_vertical = Control.SIZE_EXPAND_FILL if AppSettings.match_view == 1 else Control.SIZE_FILL
		_root.remove_child(_wide_body)
		_wide_body.queue_free()
		_wide_body = null


## Altura do campo: deitado ele enche a coluna. Em pé, com os lances em destaque, é uma faixa
## deitada de ~1/4 da tela; com o campo grande, fica vertical com metade da tela.
func _pitch_height() -> float:
	if UILayout.is_wide() and UILayout.is_landscape():
		return 120.0 if get_viewport_rect().size.y < 720.0 else 220.0
	var h := get_viewport_rect().size.y
	if AppSettings.match_view == 0:
		return clampf(h * PITCH_COMPACT, 250.0, 380.0)
	return clampf(h * 0.5, 420.0, 760.0)


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
	_pace = {AppSettings.SPEED_NORMAL: 0, AppSettings.SPEED_TURBO: 2}.get(AppSettings.match_speed, 1)
	var home: Club = _sim.teams[0].club
	var away: Club = _sim.teams[1].club
	_colors = _team_colors(home, away)
	var seed_base := (_fx.home * 131 + _fx.away) * 7919 + _fx.round * 97 + w.year
	_com = Commentary.new(_sim, home.stadium, seed_base)
	# Motor da partida: o minuto a minuto estatístico (o mesmo dos outros jogos do mundo), encenado
	# pelo PitchMotion.
	_aux_state = {"seed": seed_base, "ev": 0, "given": {}}
	_vis_rng.seed = seed_base * 31 + 17

	_root = UIKit.vbox(0)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	_root.add_child(_build_scoreboard(home, away))
	# Campo
	_pitch = PitchView.new()
	_pitch.mode = "match"
	_pitch.horizontal = UILayout.is_wide() or AppSettings.match_view == 0
	_pitch.custom_minimum_size = Vector2(0, _pitch_height())
	_pitch.home_label = home.abbr
	_pitch.away_label = away.abbr
	_pitch.mouse_filter = Control.MOUSE_FILTER_PASS # toque no campo pula o replay
	_pitch.replay_skipped.connect(_on_replay_skipped)
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
	_pitch.motion.on_mark = _on_mark
	_stadium = StadiumStyle.for_match(w, _fx, home, away, _sim.neutral, _sim.attendance, seed_base)
	StadiumStyle.apply_weather(_stadium, _sim.wx)
	_pitch.stadium = _stadium
	_pitch.classic = AppSettings.match_gfx == 0
	# Torcida: cada clube com o seu som, a visitante na fatia dela do estádio
	Sfx.crowd_start(CrowdProfile.for_club(home), CrowdProfile.for_club(away), float(_stadium.get("fill", 0.7)), float(_stadium.get("away_share", 0.1)))
	_add_field_node(UIKit.margin(_pitch, 0, 6, 0, 4))
	# Tarja do gol por cima do pé do campo (fora do fluxo: não empurra a narração para baixo).
	_l3 = _build_l3()
	_l3.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_l3.offset_left = 8
	_l3.offset_right = -8
	_l3.offset_bottom = -6
	_l3.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_l3.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pitch.add_child(_l3)
	if not _div_entries.is_empty() or not _day_entries.is_empty():
		_add_field_node(UIKit.margin(_build_strip(), 8, 0, 8, 4))
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
	_momentum.custom_minimum_size = Vector2(0, 30)
	_momentum.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_momentum.home_color = _side_color(0)
	_momentum.away_color = _side_color(1)
	_stats_box.add_child(_momentum)
	_add_field_node(UIKit.margin(_stats_box, 20, 0, 20, 2))
	# Abas: lances, números, outros jogos e tabela ao vivo (o jogo segue rolando em todas)
	_tabs_row = UIKit.hbox(6)
	_root.add_child(UIKit.margin(_tabs_row, 14, 0, 14, 4))
	_build_tabs()
	# Narração
	_feed_scroll = ScrollContainer.new()
	_feed_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_feed_scroll.scroll_deadzone = 14
	_feed_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_feed_scroll.custom_minimum_size.y = FEED_MIN_H
	_feed = UIKit.vbox(12)
	_feed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_feed_scroll.add_child(UIKit.margin(_feed, 18, 6, 18, 12))
	(_feed.get_parent() as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root.add_child(_feed_scroll)
	_tab_scroll = ScrollContainer.new()
	_tab_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tab_scroll.scroll_deadzone = 14
	_tab_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tab_scroll.custom_minimum_size.y = FEED_MIN_H
	_tab_scroll.visible = false
	_tab_box = UIKit.vbox(8)
	_tab_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tm := UIKit.margin(_tab_box, 18, 6, 18, 12)
	tm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_scroll.add_child(tm)
	_root.add_child(_tab_scroll)
	# Sugestão do auxiliar (aparece quando ele tem algo a propor)
	_root.add_child(_build_aux_bar())
	# Controles
	_controls_panel = PanelContainer.new()
	_controls_panel.theme_type_variation = "BottomBar"
	_controls = UIKit.hbox(UITokens.S1)
	_controls_panel.add_child(_controls)
	_root.add_child(_controls_panel)
	_build_controls()
	_responsive_layout()
	_apply_match_view()
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
	if not _sim.started:
		# Abertura da transmissão e, depois dela, a palestra
		_open_intro.call_deferred()


func _add_field_node(node: Control) -> void:
	_field_nodes.append(node)
	_root.add_child(node)


func _open_intro() -> void:
	BroadcastIntro.show(world(), _sim, _fx, _stadium, func():
		if not _sim.started and _sim.can_talk(_user_side):
			_open_talk(false), [_colors[0], _colors[1], _colors[2], _colors[3]])


## Texto do selo da emissora: "AO VIVO", "INTERVALO" ou "FIM DE JOGO".
func _set_bug(text: String, col: Color) -> void:
	if _bug == null or _bug.get_child_count() < 2:
		return
	var l := _bug.get_child(1) as Label
	l.text = text
	l.add_theme_color_override(&"font_color", col)


## Tarja de TV depois do gol: artilheiro, número do gol no jogo e na temporada.
func _lower_third(ev: Dictionary) -> void:
	var side: int = ev["s"]
	var mp: MatchPlayer = _sim.teams[side].by_id.get(int(ev["p"]), null)
	if mp == null or _l3 == null:
		return
	var in_game := 0
	for e in _sim.events:
		if int(e["t"]) == MatchSimulation.EV_GOAL and int(e.get("p", -1)) == mp.p.id and int(e["s"]) == side and int(e["m"]) <= int(ev["m"]):
			in_game += 1
	var season_g: int = mp.p.stats[Player.S_GOALS] if mp.p.stats.size() > Player.S_GOALS else 0
	var b := Broadcaster.for_competition(world(), _fx.comp)
	(_l3.get_theme_stylebox(&"panel") as StyleBoxFlat).bg_color = b["c1"]
	var name_l := _l3.get_node("R/V/N") as Label
	var info_l := _l3.get_node("R/V/I") as Label
	name_l.text = "%s  %s" % [mp.p.display_name().to_upper(), Fmt.minute(int(ev["m"]), int(ev["h"]))]
	name_l.add_theme_color_override(&"font_color", b["c2"])
	var parts: Array = [_sim.teams[side].club.short_name, "%dº gol no jogo" % maxi(1, in_game), "%d na temporada" % (season_g + maxi(1, in_game))]
	info_l.text = " · ".join(parts)
	_l3.visible = true
	_l3.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_l3, "modulate:a", 1.0, 0.25)
	tw.tween_interval(4.5)
	tw.tween_property(_l3, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func(): _l3.visible = false)


func _build_l3() -> PanelContainer:
	var p := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color("#101010")
	st.border_color = Color(1, 1, 1, 0.25)
	st.border_width_left = 6
	st.content_margin_left = 12
	st.content_margin_right = 12
	st.content_margin_top = 6
	st.content_margin_bottom = 6
	p.add_theme_stylebox_override(&"panel", st)
	var r := UIKit.hbox(10)
	r.name = "R"
	var v := UIKit.vbox(0)
	v.name = "V"
	var n := UIKit.label("", "H3")
	n.name = "N"
	v.add_child(n)
	var i := UIKit.label("", "Small")
	i.name = "I"
	v.add_child(i)
	r.add_child(v)
	p.add_child(r)
	p.visible = false
	return p


func _build_scoreboard(home: Club, away: Club) -> Control:
	# Placar da transmissão com a cara da competição (desenho e cores dos dados, mods ou Editor).
	var title := CompText.fixture_title(world(), _fx).to_upper() if _fx.comp != "F" else "AMISTOSO"
	_conditions = _conditions_row()
	_board = ScoreboardView.make(world(), _fx.comp, title, home, away, _colors, _conditions, true, _fx.leg == 1)
	_score_lbl = _board.score_proxy
	_clock_lbl = _board.clock_proxy
	_home_name = _board.home_name
	_away_name = _board.away_name
	_home_scorers = _board.home_scorers
	_away_scorers = _board.away_scorers
	_ticker = _board.ticker
	_bug = _board.bug
	return _board


## Condições do jogo: clima (ícone), temperatura, dia/noite, altitude e público.
func _conditions_row() -> Control:
	var body := UIKit.vbox(UITokens.S1)
	var venue := UIKit.label("Campo neutro" if _sim.neutral else _sim.teams[0].club.stadium, "Small", true)
	venue.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(venue)
	var row := UIKit.hbox(UITokens.S1)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var wx: Dictionary = _sim.wx
	var bits: Array = []
	if not wx.is_empty():
		row.add_child(WeatherIcon.new(String(wx.get("kind", "cloud")), bool(wx.get("night", false)), 26))
		bits.append("%s · %d°C" % [Weather.NAMES.get(String(wx.get("kind", "")), ""), int(wx.get("temp", 20))])
		bits.append("%dh" % int(wx.get("hour", 16)))
		if wx.has("alt"):
			bits.append("%s m de altitude" % Fmt.thousands(int(wx["alt"])))
	if _sim.attendance > 0:
		bits.append("%s torcedores" % Fmt.thousands(_sim.attendance))
	else:
		bits.append("portões fechados")
	var l := UIKit.label(" · ".join(bits), "Small", true)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(l)
	body.add_child(row)
	return body


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
	# As três decisões do jogo em destaque; tempo e o resto, compactos (DESIGN.md › Partida).
	_play_btn = _ctl_btn("Pausar", "pause", _toggle_play)
	_speed_btn = _ctl_btn(PACE_NAMES[_pace], "fast", _cycle_speed)
	for b in [_play_btn, _speed_btn]:
		_compact(b)
	_tac_btn = _ctl_btn("Tática", "tactics", _open_tactics)
	_shout_btn = _ctl_btn("Instruções", "whistle", _open_shouts)
	var sub := _ctl_btn("Substituir", "swap", _open_subs)
	var more := _ctl_btn("Mais", "menu", _match_menu)
	_compact(more)
	_sound_btn = null
	_skip_btn = null
	for b in [_play_btn, _speed_btn, _tac_btn, _shout_btn, sub, more]:
		_controls.add_child(b)
	_update_play_button()


## Controle secundário (tempo, menu): mais estreito e discreto, mas com o nome embaixo do ícone
## como os outros (só o ícone deixava a barra desigual e o botão de tempo sem dizer o ritmo).
func _compact(b: Button) -> void:
	b.size_flags_horizontal = Control.SIZE_FILL
	b.custom_minimum_size.x = UITokens.H_BUTTON + 12
	b.theme_type_variation = "GhostButton"
	b.tooltip_text = b.text
	b.add_theme_font_size_override(&"font_size", 15)


## Menu do resto: painel com os números, som e ir para o fim.
func _match_menu() -> void:
	var v := UIKit.vbox(0)
	v.add_child(UIKit.label("Partida", "Section"))
	v.add_child(UIKit.gap(UITokens.S1))
	var muted := Sfx.match_muted()
	var items := [
		["Painel da partida", "Posse, finalizações, xG e notas dos jogadores", _open_panel],
		["Ligar o som" if muted else "Desligar o som", "", _toggle_match_sound],
		["Ir para o fim", "Simula o resto do jogo", _confirm_skip],
	]
	for it in items:
		var box := UIKit.vbox(0)
		box.add_child(UIKit.label(String(it[0]), "H3"))
		if String(it[1]) != "":
			box.add_child(UIKit.label(String(it[1]), "Muted"))
		var cb: Callable = it[2]
		var row := UIKit.tap_row(box, func():
			UIManager.close_modal()
			cb.call())
		row.custom_minimum_size.y = UITokens.H_ROW
		v.add_child(row)
	UIManager.show_modal(v, true)


## Painel da partida numa folha: os números sem tirar o campo da tela.
func _open_panel() -> void:
	var keep := _tab_box
	var v := UIKit.vbox(UITokens.S2)
	v.add_child(UIKit.label("Painel da partida", "Section"))
	_tab_box = v
	_render_stats_tab()
	_tab_box = keep
	UIManager.show_modal(v, true)


## Botão da barra: ícone em cima e o nome embaixo (cabe em qualquer largura de celular).
func _ctl_btn(text: String, icon_name: String, cb: Callable) -> Button:
	var b := UIKit.button(text, "", cb, icon_name)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 88)
	b.clip_text = false
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_font_size_override(&"font_size", 17)
	# Margem interna menor que a do botão comum: o nome inteiro cabe no celular.
	for st in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]:
		var sb := b.get_theme_stylebox(st)
		if sb != null:
			var d := sb.duplicate()
			d.content_margin_left = 6
			d.content_margin_right = 6
			b.add_theme_stylebox_override(st, d)
	return b


func _toggle_match_sound() -> void:
	Sfx.set_match_muted(not Sfx.match_muted())
	_update_sound_button()


func _update_sound_button() -> void:
	if _sound_btn == null or not is_instance_valid(_sound_btn):
		return
	if _sound_btn == null:
		return
	var muted := Sfx.match_muted()
	_sound_btn.text = "Mudo" if muted else "Som"
	_sound_btn.tooltip_text = "Ligar som da partida" if muted else "Desligar som da partida"
	_sound_btn.modulate.a = 0.58 if muted else 1.0


func _update_play_button() -> void:
	if _play_btn == null or _done:
		return
	if _halftime:
		_play_btn.text = "2º tempo"
		_play_btn.icon = UIKit.icon("play")
	elif _paused:
		_play_btn.text = "Seguir"
		_play_btn.icon = UIKit.icon("play")
	else:
		_play_btn.text = "Pausar"
		_play_btn.icon = UIKit.icon("pause")
	_play_btn.tooltip_text = _play_btn.text
	if _play_btn.has_meta(&"compact"):
		_play_btn.text = ""


static func _cdist(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


func _team_colors(home: Club, away: Club) -> Array[Color]:
	# No campinho cada time é a cor que mais aparece no uniforme (Grêmio é azul, não o branco do
	# c1 das listras), com a outra cor de contorno. O visitante usa o uniforme que mais se
	# distingue do mandante pela cor das bolinhas; se ainda ficar parecido, vai de neutro.
	var hk := home.kit_home
	var hd := _dot_colors(hk)
	var kits: Array = []
	var pref := KitDesign.away_choice(home, away)
	for which in [pref, "home", "away", "third"]:
		var k: Dictionary = away.kit_home if which == "home" else (away.kit_away if which == "away" else (away.third_kit() if which == "third" else {}))
		if not k.is_empty():
			kits.append(k)
	var best: Array = []
	var best_d := -1.0
	for k in kits:
		var dc := _dot_colors(k)
		var d := KitDesign.delta_e(dc[0], hd[0])
		if d >= DOT_MIN_DE:
			best = dc
			break
		if d > best_d:
			best_d = d
			best = dc
	if best.is_empty() or KitDesign.delta_e(best[0], hd[0]) < DOT_MIN_DE:
		var dark: bool = (hd[0] as Color).get_luminance() >= 0.5
		best = [Color("#15181D"), Color("#F4F4F4")] if dark else [Color("#F4F4F4"), Color("#15181D")]
		if KitDesign.delta_e(best[0], hd[0]) < DOT_MIN_DE:
			best = [Color("#F5D547"), Color("#15181D")]
	var out: Array[Color] = [hd[0], hd[1], best[0], best[1]]
	return out


const DOT_MIN_DE := 32.0
const GK_OPTS: Array[String] = ["#F28C28", "#3DBE7A", "#F5D547", "#9B5DE5", "#E84A8A", "#4EA8DE", "#15181D"]


## Goleiro com cor própria: se a camisa dele lembrar a de algum dos dois times (ou o outro goleiro),
## troca pela opção mais distante de todas.
func _gk_color(c: Color, side: int) -> Color:
	var avoid: Array = [_colors[0], _colors[2]]
	var other := _sim.teams[1 - side].club.gk_kit()
	if side == 1:
		avoid.append(_gk_color(Color(String(other.get("c1", "#111111"))), 0))
	var near := func(x: Color) -> float:
		var m := 999.0
		for a in avoid:
			m = minf(m, KitDesign.delta_e(x, a))
		return m
	if near.call(c) >= 25.0:
		return c
	var best := c
	var best_d := -1.0
	for h in GK_OPTS:
		var d: float = near.call(Color(h))
		if d > best_d:
			best_d = d
			best = Color(h)
	return best # diferença mínima (CIE ΔE) entre as bolinhas dos dois times


## [cor da bolinha, cor do contorno] de um uniforme: a cor dominante e a que mais contrasta com ela.
static func _dot_colors(k: Dictionary) -> Array:
	var dom := KitDesign.dominant(k)
	var ring := Color("#15181D") if dom.get_luminance() >= 0.5 else Color("#F4F4F4")
	var best := 0.0
	for sw in KitDesign.swatches(k):
		var c: Color = sw[0]
		var d := KitDesign.delta_e(c, dom)
		if d > best and d > 25.0:
			best = d
			ring = c
	return [dom, ring]


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
	if _aux_timer > 0.0 and not _paused and not _halftime:
		_aux_timer -= delta
		if _aux_timer <= 0.0:
			_hide_aux()
	# O replay roda mesmo com o jogo pausado (botão "Rever"), mas não por baixo de um modal.
	_pitch.motion.frozen = UIManager.has_modal() or ((_paused or _halftime or _done) and not _replay_on)
	if not _pitch.motion.frozen:
		_gate_clock += delta
	if _replay_on and not _pitch.motion.replaying:
		_replay_on = false
		_hold = minf(_hold, 0.25)
		var after := _replay_after
		_replay_after = Callable()
		if after.is_valid():
			after.call()
	if _highlight_timer > 0.0:
		_highlight_timer -= delta
		if _highlight_timer <= 0.0:
			_pitch.highlight_side = -1
			_pitch.highlight_slot = -1
	if _done or UIManager.has_modal():
		return
	# O relógio do minuto corre junto com a jogada e a narração (o minuto dura o maior dos dois).
	if not (_halftime or _paused):
		_clock -= delta
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
		_set_bug("INTERVALO", Color("#FFC940"))
		_show_halftime()
		return
	if _pending_shootout:
		_pending_shootout = false
		_show_shootout_order()
		return
	if _halftime or _paused:
		return
	if _clock > 0.0:
		return
	# No ritmo normal o próximo minuto espera a jogada encenada terminar (a bola não "teleporta").
	if _pace == 0 and _pitch.motion.scripted_busy() and _busy_wait < 3.0:
		_busy_wait += delta
		return
	_clock = PACE[_pace]
	_busy_wait = 0.0
	_advance()


func _advance() -> void:
	_sim.step()
	# Primeiro o campo monta o lance; a narração de cada parte sai quando a bola chega nela.
	_script_play()
	_drain(false)
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
	if not _sim.finished:
		_assistant_tick()


## Processa os eventos novos da simulação (inclusive os gerados por ajustes do usuário).
func _drain(silent: bool) -> void:
	while _ev_index < _sim.events.size():
		var ev: Dictionary = _sim.events[_ev_index]
		_ev_index += 1
		_handle_event(ev, silent, _ev_gate.get(_ev_index - 1, {}))
		_ev_gate.erase(_ev_index - 1)


func _delay_scale() -> float:
	return clampf(PACE[_pace] / 0.32, 0.3, 1.6)


func _enqueue(line: Dictionary, ev: Dictionary, delay: float, gate: String = "") -> void:
	var item := {"at": _elapsed + delay, "line": line, "ev": ev}
	if gate != "":
		item["gate"] = gate
		item["rel"] = delay
		item["lim"] = _gate_clock + 7.0 # nunca fica presa: se o campo não chegar lá, sai assim mesmo
	_queue.append(item)


func _on_mark(id: String) -> void:
	_gates[id] = _elapsed


const OUTCOME_STYLES: Array[String] = ["goal", "card_y", "card_r", "big", "var"]


## Em que marco do campo cada linha do lance sai, e quanto depois dele.
func _gate_for(g: Dictionary, line: Dictionary, d: float) -> Array:
	var style := String(line.get("style", ""))
	var outcome := d >= 0.5 or style in OUTCOME_STYLES
	match String(g.get("role", "")):
		"start":
			return [g["s"], d * 0.6]
		"hit":
			return [g["h"], maxf(0.0, d - 0.2) + (0.5 if style in ["card_y", "card_r"] else 0.0)]
		"pen":
			return [g["f"], d * 0.6]
		"pen_chance":
			return [g["h"], maxf(0.0, d - 0.5)] if outcome else [g["f"], 0.9 + d]
	# chance: a preparação sai enquanto a jogada se arma, o desfecho quando a bola chega.
	if outcome:
		return [g["h"], maxf(0.0, d - 0.5)]
	return [g["s"], 0.25 + d * 1.5]


func _handle_event(ev: Dictionary, silent: bool, g: Dictionary = {}) -> void:
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
			Sfx.play("whistle", -4.0)
	var gated := not g.is_empty() and not silent
	for line in _com.lines_for(ev):
		var style: String = line["style"]
		if silent and style in ["normal", "chance", "info", "crowd", "var", "pundit", "reporter"] and t != MatchSimulation.EV_FULLTIME and t != MatchSimulation.EV_HALFTIME:
			continue
		if silent:
			_add_line(line)
			continue
		if gated:
			var gt := _gate_for(g, line, float(line["delay"]))
			_enqueue(line, ev, float(gt[1]) * _delay_scale(), String(gt[0]))
			continue
		_enqueue(line, ev, float(line["delay"]) * _delay_scale())
	if silent:
		return
	if t == MatchSimulation.EV_HALFTIME:
		var an := _com.analysis_line(int(ev["m"]), int(ev["h"]))
		if not an.is_empty():
			_enqueue(an, {}, 1.2)
	if not (gated and t == MatchSimulation.EV_KNOCK): # caído depois da falta: o campo já encena
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
	while not _queue.is_empty():
		var head: Dictionary = _queue[0]
		if head.has("gate"):
			var gid := String(head["gate"])
			if not _gates.has(gid):
				if _gate_clock < float(head["lim"]):
					break
				_gates[gid] = _elapsed
			if float(_gates[gid]) + float(head["rel"]) > _elapsed:
				break
		elif float(head["at"]) > _elapsed:
			break
		var item: Dictionary = _queue.pop_front()
		var line: Dictionary = item["line"]
		var ev: Dictionary = item["ev"]
		_add_line(line)
		if String(line.get("style", "")) == "goal" and not ev.is_empty() and _feed.get_child_count() > 0:
			_goal_rows[_goal_key(ev)] = _feed.get_child(0)
		_on_line_shown(line, ev)


func _on_line_shown(line: Dictionary, ev: Dictionary) -> void:
	if is_instance_valid(_pitch) and _pitch.classic:
		var sd := int(line.get("side", -1))
		_pitch.show_caption(String(line.get("text", "")), _side_color(sd) if sd >= 0 else UIColors.MUTED)
	if ev.is_empty():
		return
	var t: int = ev["t"]
	var style: String = line["style"]
	if line.has("hl") and _pace < 2:
		_callout(String(line["hl"]), int(ev.get("s", -1)))
	match style:
		"goal":
			_celebrate(ev)
		"card_y", "card_r":
			Sfx.crowd_event("card", int(ev["s"]))
			Sfx.play("card", -6.0)
			Sfx.vibrate(25)
			_hold = maxf(_hold, 0.5 * _delay_scale())
		"big":
			if t == MatchSimulation.EV_PEN_SAVE or t == MatchSimulation.EV_PEN_MISS or t == MatchSimulation.EV_PENALTY_AWARDED:
				Sfx.play("chance", -4.0)
				_hold = maxf(_hold, 0.9 * _delay_scale())
		"chance":
			Sfx.crowd_event("danger", int(ev["s"]))
			if t == MatchSimulation.EV_SAVE and int(ev["s"]) == 1:
				Sfx.crowd_event("save", 0) # defesa do goleiro da casa: aplausos
			if t == MatchSimulation.EV_POST or (ev.has("x") and float(ev["x"].get("xg", 0.0)) >= 0.3):
				Sfx.play("chance", -8.0)
		"var":
			_hold = maxf(_hold, 0.8 * _delay_scale())
	if t == MatchSimulation.EV_OFFSIDE and style == "big":
		Sfx.play("whistle", -8.0)
		_hold = maxf(_hold, 0.9 * _delay_scale())
	if t == MatchSimulation.EV_FOUL:
		Sfx.crowd_event("foul", int(ev["s"]))
	if t == MatchSimulation.EV_HALFTIME:
		Sfx.play("whistle", -4.0)
		Sfx.crowd_event("half", 0)
	elif t == MatchSimulation.EV_FULLTIME:
		Sfx.play("whistle_end", -3.0)
		var hs := int(_sim.score[0])
		var as_ := int(_sim.score[1])
		Sfx.crowd_event("end", 0 if hs >= as_ else 1)


const CALLOUTS := {
	"post": ["NA TRAVE!", "#FFE08A"], "post_bar": ["NO TRAVESSÃO!", "#FFE08A"], "post_inside_out": ["NÃO ENTROU!", "#FFE08A"],
	"save_big": ["QUE DEFESA!", "#9AD0FF"], "save_double": ["DEFESA DUPLA!", "#9AD0FF"], "save_fingertip": ["PONTA DOS DEDOS!", "#9AD0FF"],
	"save_one_on_one": ["FECHOU O GOL!", "#9AD0FF"], "miss_big": ["UUUUH!", "#FFFFFF"], "miss_sky": ["ISOLOU!", "#FFFFFF"],
	"block_line": ["EM CIMA DA LINHA!", "#9AD0FF"], "block_last_ditch": ["SALVOU!", "#9AD0FF"], "var_goal": ["GOL?", "#FFFFFF"],
	"var_off": ["ANULADO!", "#E5484D"], "offside_goal": ["IMPEDIDO!", "#E5484D"], "pen": ["PÊNALTI!", "#FFC940"],
	"pen_save": ["DEFENDEU!", "#9AD0FF"], "pen_miss": ["PERDEU!", "#FFFFFF"], "red": ["EXPULSO!", "#E5484D"],
}


## Letreiro sobre o campo nos lances de destaque, com a reação da torcida.
func _callout(kind: String, side: int) -> void:
	var key := kind
	if not CALLOUTS.has(key):
		if kind.begins_with("save"):
			key = "save_big"
		elif kind.begins_with("miss"):
			key = "miss_big"
		elif kind.begins_with("post"):
			key = "post"
		elif kind.begins_with("block"):
			key = "block_line"
		else:
			return
	var c: Array = CALLOUTS[key]
	_pitch.show_callout(String(c[0]), Color(String(c[1])), 1.5 if _pace == 0 else 1.1)
	if key in ["post", "post_bar", "post_inside_out", "miss_big", "miss_sky", "var_off"] and side >= 0:
		_pitch.crowd_jump = maxf(_pitch.crowd_jump, 0.45)
		_pitch.crowd_side = side
	Sfx.vibrate(15)


func _goal_key(ev: Dictionary) -> String:
	return "%d:%d:%d:%d" % [int(ev.get("h", 1)), int(ev.get("m", 0)), int(ev.get("s", 0)), int(ev.get("p", -1))]


## Depois da comemoração: replay do lance (ritmos normal e rápido), a tarja do artilheiro
## durante o replay e a saída de bola quando ele acaba.
func _after_goal(ev: Dictionary) -> void:
	var side := int(ev["s"])
	var clip: Dictionary = _pitch.motion.goal_clip() if _pace < 2 else {}
	if int(ev["t"]) == MatchSimulation.EV_GOAL:
		_lower_third(ev)
	var resume := func(): _pitch.motion.kickoff(1 - side, false)
	if clip.is_empty():
		resume.call()
		return
	var key := _goal_key(ev)
	_clips[key] = clip
	_add_replay_button(key)
	_play_replay(clip, resume)


func _play_replay(clip: Dictionary, after: Callable) -> void:
	# Só narração: sem campo na tela, não há replay para mostrar.
	var dur := _pitch.motion.start_replay(clip) if AppSettings.match_view != 2 else 0.0
	if dur <= 0.0:
		if after.is_valid():
			after.call()
		return
	_replay_on = true
	_replay_after = after
	_hold = maxf(_hold, dur + 0.3)


func _on_replay_skipped() -> void:
	# O PitchView já encerrou o replay; o _process devolve o jogo no próximo quadro.
	_hold = minf(_hold, 0.25)


## "Rever gol" na linha do gol da narração.
func _add_replay_button(key: String) -> void:
	var node: Control = _goal_rows.get(key, null)
	if node == null or not is_instance_valid(node):
		return
	var row: HBoxContainer = node.get_child(0) as HBoxContainer if node is PanelContainer else node as HBoxContainer
	if row == null or row.has_node("Rever"):
		return
	var b := UIKit.button("Rever", "ChipButton", _rewatch.bind(key), "play")
	b.name = "Rever"
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(b)


func _rewatch(key: String) -> void:
	if _replay_on or _overlay.is_playing() or _done:
		return
	var clip: Dictionary = _clips.get(key, {})
	if clip.is_empty():
		return
	_play_replay(clip, Callable())


func _celebrate(ev: Dictionary) -> void:
	_record_scorer(ev)
	_shown_score = [int(ev["hs"]), int(ev["as"])]
	_update_board() # placar muda na hora do gol, não só no próximo minuto
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
	Sfx.goal(imp if level != 3 else maxf(imp, 0.8), ours)
	Sfx.crowd_event("goal", side)
	if _pace == 0:
		_hold += 1.8 # tempo de ver os times voltando para a saída
	var tw := create_tween()
	tw.tween_interval(dur)
	tw.tween_callback(_after_goal.bind(ev))


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


func _script_play() -> void:
	var ph: Dictionary = _sim.last_phase
	if ph.is_empty() or is_same(ph, _last_phase):
		return
	_last_phase = ph
	var ev := int(ph.get("ev", -1))
	if ev in [MatchSimulation.EV_KICKOFF, MatchSimulation.EV_SECOND_HALF, MatchSimulation.EV_EXTRA_TIME]:
		return
	if _queue.is_empty():
		_gates.clear()
	var evs: Array = _sim.last_events
	var base := _sim.events.size() - evs.size()
	var beats := _beats(evs, base, ph)
	var mo := _pitch.motion
	if beats.is_empty():
		mo.ambient(int(ph.get("side", 0)), float(ph.get("to", 0.5)))
		return
	# Narração presa ao campo no normal e no rápido (no rápido, os toques de bola sem perigo
	# não seguram o minuto); no turbo e sem campo na tela, a narração corre solta.
	var sync := _pace < 2 and AppSettings.match_view != 2
	for i in beats.size():
		var b: Dictionary = beats[i]
		var info: Dictionary = b["info"]
		info["append"] = i > 0
		if sync and (_pace == 0 or bool(b["key"])):
			_beat_n += 1
			var id := "b%d" % _beat_n
			info["start"] = id + "s"
			info["hit"] = id + "h"
			if b.has("pen"):
				info["fhit"] = id + "f"
			for item in b["evs"]:
				_ev_gate[int(item[0])] = {"role": String(item[1]), "s": id + "s", "h": id + "h", "f": id + "f"}
		mo.play(info)


const FLAVOR_HIT: Array[String] = ["intercept", "cross_cut", "long", "press"]


## Lances do minuto na ordem em que aconteceram, cada um com a jogada do campo e os eventos da
## narração que ele mostra ([índice do evento, papel]: start, hit, chance, pen, pen_chance).
func _beats(evs: Array, base: int, ph: Dictionary) -> Array:
	var out: Array = []
	var pre: Array = [] # eventos que entram na próxima chance (escanteio, falta, pênalti marcado)
	var ctk := -1 # quem foi para a bandeira
	var i := 0
	var n := evs.size()
	while i < n:
		var e: Dictionary = evs[i]
		var t := int(e["t"])
		var s := int(e["s"])
		var x: Dictionary = e.get("x", {})
		var idx := base + i
		i += 1
		match t:
			MatchSimulation.EV_POSSESSION:
				var k := String(x.get("kind", ""))
				if k.begins_with("read_"):
					continue
				var inf := {"kind": "poss", "pk": k, "side": s, "p": _slot_of(s, int(e["p"])), "p2": _slot_of(s, int(e.get("p2", -1))),
					"d": _slot_of(1 - s, int(x.get("d", -1))), "zone": float(ph.get("to", 0.5))}
				out.append({"info": inf, "key": false, "evs": [[idx, "hit" if k in FLAVOR_HIT else "start"]]})
			MatchSimulation.EV_SKILL, MatchSimulation.EV_TACKLE, MatchSimulation.EV_KEEPER:
				var kd: String = {MatchSimulation.EV_SKILL: "skill", MatchSimulation.EV_TACKLE: "tackle", MatchSimulation.EV_KEEPER: "keeper"}[t]
				var inf2 := {"kind": kd, "side": s, "p": _slot_of(s, int(e["p"])), "p2": _slot_of(1 - s, int(e.get("p2", -1))), "zone": float(ph.get("to", 0.5))}
				out.append({"info": inf2, "key": false, "evs": [[idx, "hit"]]})
			MatchSimulation.EV_FOUL:
				# Junta o que vem colado na falta: cartão, jogador caído, pênalti ou cobrança perigosa.
				var group: Array = [[idx, "hit"]]
				var card := 0
				var knock := false
				var pen := false
				var fk := false
				var j := i
				while j < n:
					var e2: Dictionary = evs[j]
					var t2 := int(e2["t"])
					if t2 in [MatchSimulation.EV_YELLOW, MatchSimulation.EV_RED] and int(e2["p"]) == int(e["p"]):
						card = 2 if t2 == MatchSimulation.EV_RED else 1
					elif t2 == MatchSimulation.EV_KNOCK:
						knock = true
					elif t2 == MatchSimulation.EV_PENALTY_AWARDED:
						pen = true
					elif t2 == MatchSimulation.EV_VAR and String(e2.get("x", {}).get("kind", "")) == "pen_ok":
						pass
					elif t2 == MatchSimulation.EV_FREEKICK:
						fk = true
						break
					elif t2 == MatchSimulation.EV_INJURY:
						pass
					else:
						break
					group.append([base + j, "hit"])
					j += 1
				i = j
				if pen:
					# O pênalti encena a falta antes da cobrança: tudo isso sai no apito.
					for gi in group:
						pre.append([gi[0], "pen"])
					continue
				var side := 1 - s # quem sofre
				var inf3 := {"kind": "foul", "side": side, "p": _slot_of(s, int(e["p"])), "p2": _slot_of(side, int(e.get("p2", -1))),
					"danger": bool(x.get("danger", false)), "zone": float(ph.get("to", 0.5)) if not fk else maxf(0.72, float(ph.get("to", 0.75))),
					"card": card, "knock": knock, "fk": fk}
				if card > 0 and int(inf3["p"]) == -1:
					# Expulso: a vaga já está vazia na simulação, mas o cartão aparece antes de ele sair.
					var mp: MatchPlayer = _sim.teams[s].by_id.get(int(e["p"]), null)
					if mp != null:
						inf3["p"] = mp.slot
				# No rápido só a falta que vale alguma coisa (cartão, bola parada perigosa) segura o minuto.
				out.append({"info": inf3, "key": card > 0 or fk or bool(x.get("danger", false)), "evs": group})
			MatchSimulation.EV_FREEKICK:
				pre.append([idx, "start"])
			MatchSimulation.EV_CORNER:
				# Escanteio que vira finalização: a cobrança faz parte da chance.
				if i < n and int(evs[i]["t"]) in CHANCE_RES and int(evs[i].get("x", {}).get("ct", -1)) == MatchSimulation.CH_CORNER:
					pre.append([idx, "start"])
					ctk = _slot_of(s, int(e["p"]))
					continue
				out.append({"info": {"kind": "corner", "side": s, "p": _slot_of(s, int(e["p"]))}, "key": false, "evs": [[idx, "start"]]})
			MatchSimulation.EV_OFFSIDE:
				out.append({"info": {"kind": "offside", "side": s, "p": _slot_of(s, int(e["p"])), "zone": 0.8}, "key": bool(x.get("goal", false)), "evs": [[idx, "hit"]]})
			_:
				if not CHANCE_RES.has(t):
					continue
				var ct := int(x.get("ct", 0))
				var inf4 := {"kind": "chance", "side": s, "ct": ct, "res": CHANCE_RES[t], "zone": float(ph.get("to", 0.9))}
				if t == MatchSimulation.EV_OWN_GOAL:
					inf4["own"] = true
					inf4["sh"] = _slot_of(1 - s, int(e["p"]))
				else:
					inf4["sh"] = _slot_of(s, int(e["p"]))
					inf4["as"] = _slot_of(s, int(e.get("p2", -1)))
				if x.has("line"):
					inf4["line"] = _slot_of(1 - s, int(x["line"]))
				if x.has("culprit"):
					inf4["culprit"] = _slot_of(1 - s, int(x["culprit"]))
				if x.has("fin"):
					inf4["fin"] = String(x["fin"])
				if x.has("ln"):
					inf4["ln"] = int(x["ln"])
				if ctk >= 0 and ct == MatchSimulation.CH_CORNER:
					inf4["ctk"] = ctk
				ctk = -1
				if _pace == 0 and (t in [MatchSimulation.EV_GOAL, MatchSimulation.EV_OWN_GOAL, MatchSimulation.EV_POST] or float(x.get("xg", 0.0)) >= 0.3):
					inf4["big"] = true # chance clara: o chute sai em câmera lenta
				var group2: Array = pre.duplicate()
				pre.clear()
				var b := {"info": inf4, "key": true, "evs": group2}
				if ct == MatchSimulation.CH_PENALTY:
					b["pen"] = true
					var pa := {}
					for pe in evs:
						if int(pe["t"]) == MatchSimulation.EV_PENALTY_AWARDED:
							pa = pe
					if not pa.is_empty():
						inf4["pen"] = {"victim": _slot_of(s, int(pa["p"])), "fouler": _slot_of(1 - s, int(pa.get("p2", -1))),
							"how": String(pa.get("x", {}).get("how", ""))}
					group2.append([idx, "pen_chance"])
				else:
					group2.append([idx, "chance"])
				# O que a narração diz logo depois do gol (VAR confirmando, técnico reclamando).
				while i < n and int(evs[i]["t"]) in [MatchSimulation.EV_VAR, MatchSimulation.EV_CROWD] and t in [MatchSimulation.EV_GOAL, MatchSimulation.EV_OWN_GOAL]:
					group2.append([base + i, "hit"])
					i += 1
				out.append(b)
	return out


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
		MatchSimulation.EV_CRAMP:
			_pitch.motion.player_down(side, _slot_of(side, int(ev.get("p", -1))), 3.0)
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
				e["c1"] = _gk_color(Color(String(gk.get("c1", "#111111"))), side)
				e["c2"] = Color(String(gk.get("c2", "#FFFFFF")))
			arr.append(e)
		if side == 0:
			_pitch.home_slots = arr
		else:
			_pitch.away_slots = arr
		_pitch.motion.set_team(side, arr)
		_pitch.motion.set_tactics(side, {"line": t.line, "width": t.width_i, "press": t.pressing, "ment": t.mentality})


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
	# Linha dos goleadores só aparece quando alguém marcou (placar compacto)
	(_home_scorers.get_parent() as Control).visible = _home_scorers.text != "" or _away_scorers.text != ""
	if _board != null:
		_board.sync(_sim, _shown_score, _halftime, _done)
	var ph := _sim.possession_pct(0)
	_poss_home.size_flags_stretch_ratio = maxf(0.05, ph)
	_poss_away.size_flags_stretch_ratio = maxf(0.05, 1.0 - ph)
	_poss_lbl_h.text = Fmt.percent(ph)
	_poss_lbl_a.text = Fmt.percent(1.0 - ph)
	var h: MatchTeam = _sim.teams[0]
	var a: MatchTeam = _sim.teams[1]
	_stats_lbl.text = "Finalizações %d – %d  ·  No gol %d – %d  ·  xG %s – %s" % [h.shots, a.shots, h.on_target, a.on_target, TacticalXRay.dec(h.xg, 1), TacticalXRay.dec(a.xg, 1)]
	_update_pressure()
	if _momentum != null:
		_momentum.refresh(_sim.pressure, _goal_marks())


## Selo "PRESSÃO" no campo quando um time empurra o outro nos últimos minutos (mesma
## leitura do gráfico de momento). Some quando o jogo equilibra.
func _update_pressure() -> void:
	if _pitch == null:
		return
	var pr: Array = _sim.pressure
	var n := mini(6, pr.size())
	var sum := 0.0
	for i in n:
		sum += float(pr[pr.size() - 1 - i][2])
	var avg := sum / maxf(1.0, float(n))
	var side := -1
	if n >= 4 and absf(avg) >= 0.26:
		side = 0 if avg > 0.0 else 1
	elif _pressure_side >= 0 and absf(avg) >= 0.18 and (avg > 0.0) == (_pressure_side == 0):
		side = _pressure_side # histerese: não fica piscando
	_pressure_side = side
	if side < 0 or _done or _sim.finished:
		_pitch.pressure_text = ""
		return
	_pitch.pressure_text = "PRESSÃO DO %s" % _sim.teams[side].club.abbr
	_pitch.pressure_color = _side_color(side)


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


## Minutos do "tempo e placar" (entre os resumos de números de 15 em 15).
const CLOCK_MINUTES: Array[int] = [8, 22, 38, 52, 68, 83]


## Resumo dos números a cada 15 minutos (na narração) e, entre eles, o "tempo e placar".
func _stat_summary() -> void:
	var m := _sim.minute
	if _sim.half <= 2 and m in CLOCK_MINUTES and not _stat_marks.has("c%d" % m):
		_stat_marks["c%d" % m] = true
		var cl := _com.clock_line(m, _sim.half)
		if not cl.is_empty():
			_enqueue(cl, {}, 0.1)
		return
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
	m.custom_minimum_size.x = 70
	m.add_theme_font_size_override(&"font_size", 22)
	m.add_theme_color_override(&"font_color", UIColors.DIM)
	row.add_child(m)
	var variation := "H3" if style in ["goal", "big"] else ""
	var t := UIKit.label(String(line.get("text", "")), variation, true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if variation == "":
		# O lance mais recente entra maior; o anterior volta ao corpo normal.
		t.add_theme_font_size_override(&"font_size", FEED_FS_NEW)
		row.set_meta("fresh", t)
	if _feed.get_child_count() > 0:
		var prev := _feed.get_child(0)
		var inner: Node = prev.get_child(0) if prev is PanelContainer and prev.get_child_count() > 0 else prev
		if inner.has_meta("fresh"):
			(inner.get_meta("fresh") as Label).add_theme_font_size_override(&"font_size", FEED_FS)
			inner.remove_meta("fresh")
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
		"assistant":
			col = Color("#6FD3C1")
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
		sc.add_theme_color_override(&"font_color", Color("#F2F4F7")) # fundo sempre escuro: texto claro em qualquer tema
		line.add_child(sc)
		line.add_child(UIKit.crest(w.club(f.away), 22))
		col.add_child(line)
		var info := UIKit.label("", "Small")
		info.add_theme_font_size_override(&"font_size", 14)
		info.add_theme_color_override(&"font_color", Color("#7CFFB2"))
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
			# Gol: verde escuro com borda verde viva (antes a cor do clube escurecida, que sumia com o texto)
			box.bg_color = Color("#0F3D26")
			box.border_color = Color("#2ECC71")
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
	var out: Array = [["feed", "Lances"]]
	if not _div_entries.is_empty() or not _day_entries.is_empty():
		out.append(["round", "Rodada"])
	if _fx.is_league() or _fx.stage == Fixture.STAGE_GROUP:
		out.append(["table", "Tabela"])
	return out


func _build_tabs() -> void:
	UIKit.clear(_tabs_row)
	var t := UIKit.tabs(_tab_list(), _tab, func(key: String): _set_tab(key))
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for b in t.get_children():
		(b as Button).custom_minimum_size.y = 56
	_tabs_row.add_child(t)
	var vb := UIKit.icon_button("pitch", _open_view_sheet, "Campo e narração")
	vb.custom_minimum_size = Vector2(56, 56)
	_tabs_row.add_child(vb)


## Folha de visualização: espaço do campo (menor, grande, só narração) e visual do campo
## (clássico 2D ou transmissão). Vale na hora e fica salvo nas opções.
func _open_view_sheet() -> void:
	var v := UIKit.vbox(12)
	v.add_child(UIKit.label("Campo e narração", "Title"))
	v.add_child(UIKit.eyebrow("Espaço na tela"))
	var views: Array = []
	for i in AppSettings.MATCH_VIEW_NAMES.size():
		views.append([str(i), AppSettings.MATCH_VIEW_NAMES[i]])
	v.add_child(UIKit.segment(views, str(AppSettings.match_view), func(k: String):
		AppSettings.match_view = int(k)
		AppSettings.save_settings()
		_apply_match_view()))
	v.add_child(UIKit.eyebrow("Visual do campo"))
	var gfx: Array = []
	for i in AppSettings.MATCH_GFX_NAMES.size():
		gfx.append([str(i), AppSettings.MATCH_GFX_NAMES[i]])
	v.add_child(UIKit.segment(gfx, str(AppSettings.match_gfx), func(k: String):
		AppSettings.match_gfx = int(k)
		AppSettings.save_settings()
		_pitch.classic = AppSettings.match_gfx == 0
		_pitch.queue_redraw()))
	v.add_child(UIKit.button("Fechar", "GhostButton", func(): UIManager.close_modal()))
	UIManager.show_modal(v, true, true)


func _apply_match_view() -> void:
	if not is_instance_valid(_pitch):
		return
	var box := _pitch.get_parent() as Control
	box.visible = AppSettings.match_view != 2
	_responsive_layout()


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
		_tab_box.add_child(UIKit.label("Outros jogos em andamento…", "Muted", true))
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
	var cup: Cup = null
	if _fx.is_league():
		league = w.league(_fx.comp)
		if league == null:
			return
		ids = league.club_ids
		base = league.table
		title = "Tabela ao vivo · %s" % league.short_name
	else:
		cup = w.season.cups.get(_fx.comp, null)
		var g: Dictionary = cup.group_of(_fx.home) if cup != null else {}
		if g.is_empty():
			return
		ids = g["clubs"]
		base = g["table"]
		title = "Fase de liga ao vivo · %s" % cup.short_name if cup.league_phase else "Grupo %s ao vivo · %s" % [g["n"], cup.short_name]
	var modern := cup != null and cup.league_phase
	var before := LeaguePhase.sorted_ids(cup) if modern else CompetitionManager.sort_table(ids, base)
	var live: Dictionary = {}
	var live_scores := {}
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
		live_scores[f] = sc
		var tmp := Fixture.new()
		tmp.home = f.home
		tmp.away = f.away
		tmp.hg = int(sc[0])
		tmp.ag = int(sc[1])
		CompetitionManager.apply_to_table(live, tmp)
	var order := LeaguePhase.sorted_ids(cup, live, live_scores) if modern else CompetitionManager.sort_table(ids, live)
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
		elif pos <= (8 if modern else 2):
			zone = CompetitionManager.zone_color(CompetitionManager.ZONE_PROMOTION)
		elif modern and pos <= 24:
			zone = UIColors.ORANGE
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
	_set_bug("● AO VIVO", Color("#FF4B4B"))
	Sfx.crowd_event("second", 0)
	_halftime = false
	_paused = false
	_clock = 0.5
	UIManager.close_all_modals()
	_update_play_button()


func _cycle_speed() -> void:
	_pace = (_pace + 1) % PACE.size()
	_speed_btn.tooltip_text = PACE_NAMES[_pace]
	if not _speed_btn.has_meta(&"compact"):
		_speed_btn.text = PACE_NAMES[_pace]
	_clock = minf(_clock, PACE[_pace])
	_pitch.motion.tempo = TEMPO[_pace]
	# A preferência padrão acompanha a escolha: o próximo jogo começa no mesmo ritmo.
	AppSettings.match_speed = [AppSettings.SPEED_NORMAL, AppSettings.SPEED_FAST, AppSettings.SPEED_TURBO][_pace]
	AppSettings.save_settings()


func _confirm_skip() -> void:
	if _done:
		return
	UIManager.confirm("Ir para o fim?", "A partida será simulada até o apito final. Você não poderá mais fazer ajustes.", "Ir para o fim", _skip_to_end)


func _skip_to_end() -> void:
	_overlay.skip()
	_pitch.motion.stop_replay()
	_replay_on = false
	_replay_after = Callable()
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
		"",
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
	var km := _key_moments(3 if et else 1)
	if km != null:
		v.add_child(km)
	var aux := _halftime_assistant()
	if aux.get_child_count() > 0:
		v.add_child(aux)
	else:
		var hint := _halftime_hint()
		if hint != null:
			v.add_child(hint)
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


## Lances que marcaram o jogo até o intervalo: gols, bolas na trave, defesaças, gols anulados,
## pênaltis perdidos e expulsões (os mais recentes por último, no máximo seis).
func _key_moments(max_half: int) -> VBoxContainer:
	var rows: Array = []
	for ev in _sim.events:
		if int(ev["h"]) > max_half:
			continue
		var t := int(ev["t"])
		var x: Dictionary = ev.get("x", {})
		var side := int(ev["s"])
		if side < 0:
			continue
		var who := _player_name(side, int(ev.get("p", -1)))
		var what := ""
		match t:
			MatchSimulation.EV_GOAL:
				what = "Gol de %s" % who
			MatchSimulation.EV_OWN_GOAL:
				what = "Gol contra de %s" % who
			MatchSimulation.EV_POST:
				what = "Bola na trave de %s" % who
			MatchSimulation.EV_SAVE:
				if float(x.get("xg", 0.0)) >= 0.3 or String(x.get("fin", "")) in ["double", "fingertip", "one_on_one"]:
					what = "Defesaça em chute de %s" % who
			MatchSimulation.EV_MISS:
				if String(x.get("fin", "")) == "var_off":
					what = "Gol de %s anulado pelo VAR" % who
				elif float(x.get("xg", 0.0)) >= 0.35:
					what = "%s perde chance clara" % who
			MatchSimulation.EV_BLOCK:
				if x.has("line"):
					what = "Bola salva em cima da linha"
			MatchSimulation.EV_PEN_SAVE, MatchSimulation.EV_PEN_MISS:
				what = "%s perde pênalti" % who
			MatchSimulation.EV_RED:
				what = "%s expulso" % who
			MatchSimulation.EV_OFFSIDE:
				if x.get("goal", false):
					what = "Gol de %s anulado (impedimento)" % who
		if what != "":
			rows.append([Fmt.minute(int(ev["m"]), int(ev["h"])), side, what, t == MatchSimulation.EV_GOAL or t == MatchSimulation.EV_OWN_GOAL])
	if rows.is_empty():
		return null
	var v := UIKit.vbox(4)
	v.add_child(UIKit.section("Lances do jogo"))
	for r in rows.slice(maxi(0, rows.size() - 6)):
		var row := UIKit.hbox(10)
		var bar := ColorRect.new()
		bar.custom_minimum_size = Vector2(4, 0)
		bar.color = _side_color(int(r[1]))
		row.add_child(bar)
		var m := UIKit.label(String(r[0]), "Mono")
		m.custom_minimum_size.x = 64
		m.add_theme_color_override(&"font_color", UIColors.DIM)
		row.add_child(m)
		var l := UIKit.label(String(r[2]), "H3" if bool(r[3]) else "", true)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if bool(r[3]):
			l.add_theme_color_override(&"font_color", UIColors.ink(UIColors.ACCENT))
		row.add_child(l)
		v.add_child(row)
	return v


## Cansaço no intervalo (só quando pesa).
func _halftime_hint() -> Label:
	var me: MatchTeam = _sim.teams[_user_side]
	var tired := 0
	for mp: MatchPlayer in me.slots:
		if mp != null and mp.cond < 72.0:
			tired += 1
	if tired < 2:
		return null
	return UIKit.colored("%d cansados" % tired, UIColors.ORANGE, "Small")


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
## enquanto o modal está aberto; "Sem palestra" segue sem efeito. Cada tom aparece com uma fala
## sorteada para o momento (TeamTalk), e depois vem a reação do grupo.
func _open_talk(halftime: bool) -> void:
	if _sim == null or not _sim.can_talk(_user_side):
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var v := UIKit.vbox(10)
	v.add_child(UIKit.label("Palestra no intervalo" if halftime else "Palestra antes do jogo", "Title"))
	v.add_child(UIKit.label(_talk_context(halftime), "Muted", true))
	var ut: MatchTeam = _sim.teams[_user_side]
	for opt in TeamTalk.options(_sim, _user_side, rng):
		var k := String(opt["key"])
		var say := String(opt["text"])
		var inner := UIKit.vbox(4)
		var head := String(opt["short"])
		if halftime and ut.talk_key == k:
			head += " · mesmo tom de antes do jogo"
		inner.add_child(UIKit.eyebrow(head))
		inner.add_child(UIKit.label("“%s”" % say, "", true))
		v.add_child(UIKit.tap_row(inner, func():
			var r := _sim.team_talk(_user_side, k, say)
			UIManager.close_modal()
			if not r["ok"]:
				UIManager.toast(String(r["msg"]), UIColors.RED)
				if halftime:
					_show_halftime()
				return
			_drain(false)
			_show_talk_reaction(k, r, halftime, rng)))
	v.add_child(UIKit.button("Sem palestra", "GhostButton", func():
		UIManager.close_modal()
		if halftime:
			_show_halftime()))
	UIManager.show_modal(v, true, false)


## Uma linha sobre o momento: placar no intervalo; antes do jogo, mando, favoritismo e peso.
func _talk_context(halftime: bool) -> String:
	var opp: MatchTeam = _sim.teams[1 - _user_side]
	if halftime:
		var diff := _sim.score[_user_side] - _sim.score[1 - _user_side]
		var txt := ("Vencendo por %d." % diff) if diff > 0 else (("Perdendo por %d." % -diff) if diff < 0 else "Empate.")
		var xd := _sim.teams[_user_side].xg - opp.xg
		if xd >= 0.6:
			txt += " Mandando no jogo."
		elif xd <= -0.6:
			txt += " O adversário está melhor."
		return txt
	var parts: Array[String] = []
	parts.append("Contra o %s%s" % [opp.club.short_name, "" if _sim.neutral else (", em casa" if _user_side == 0 else ", fora de casa")])
	var sit := TeamTalk.situation(_sim, _user_side)
	if sit.has("pre_derby"):
		parts.append("clássico")
	if sit.has("pre_big"):
		parts.append("jogo decisivo")
	if sit.has("pre_fav"):
		parts.append("somos favoritos")
	elif sit.has("pre_under"):
		parts.append("eles são favoritos")
	return ", ".join(parts) + "."


## Reação do vestiário: resumo e quem respondeu (ou sentiu) a conversa.
func _show_talk_reaction(key: String, r: Dictionary, halftime: bool, rng: RandomNumberGenerator) -> void:
	var rx := TeamTalk.reaction(_sim, _user_side, key, r.get("up", []), r.get("down", []), bool(r.get("repeat", false)), rng)
	var v := UIKit.vbox(10)
	v.add_child(UIKit.label("Reação no vestiário", "Title"))
	v.add_child(UIKit.label(String(rx["summary"]), "H3", true))
	for line in rx["lines"]:
		v.add_child(UIKit.label(String(line), "", true))
	v.add_child(UIKit.button("Voltar ao intervalo" if halftime else "Ir para o jogo", "PrimaryButton", func():
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
		v.add_child(UIKit.label("Próximo grito em %d min." % wait, "Muted", true))
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
		if uses >= 1:
			v.add_child(UIKit.label("Já usado %s." % Fmt.plural(uses, "vez", "vezes"), "Small", true))
	UIManager.show_modal(v, true)


var _subs_only := false


## Substituir: lista de quem está em campo; toque em quem sai e depois em quem entra.
func _open_subs() -> void:
	if _done:
		return
	_subs_only = true
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


func _open_tactics() -> void:
	if _done:
		return
	_subs_only = false
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
	var title := UIKit.label(("Substituir" if _subs_only else "Tática") if _sub_out < 0 else "Quem entra?", "Section")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(UIKit.icon_button("close", func(): UIManager.close_modal()))
	_tac_box.add_child(head)
	if _sub_out >= 0:
		_render_bench_choice(t)
		return
	if _subs_only:
		_render_subs(t)
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
	# Ajustes finos também no meio do jogo
	var fine := [["Pressão", tac["pressing"], t.pressing, func(i): _sim.set_pressing(_user_side, i)],
		["Linha defensiva", tac["line"], t.line, func(i): _sim.set_line(_user_side, i)],
		["Largura", [{"name": TeamSheet.WIDTH_NAMES[0]}, {"name": TeamSheet.WIDTH_NAMES[1]}, {"name": TeamSheet.WIDTH_NAMES[2]}], t.width_i, func(i): _sim.set_width(_user_side, i)],
		["Intensidade", tac["intensity"], t.intensity, func(i): _sim.set_intensity(_user_side, i)]]
	# Instruções de equipe (ritmo, passe, marcação, perda da bola, foco, cera, escanteios)
	for k in TacticsManager.DEEP.size():
		var dkey: String = TacticsManager.DEEP[k]
		fine.append([String(TacticsManager.DEEP_TITLES[dkey]), TacticsManager.deep_options(dkey), int(t.deep[k]), func(i): _sim.set_deep(_user_side, dkey, i)])
	for item in fine:
		_tac_box.add_child(UIKit.section(String(item[0])))
		var g := ButtonGroup.new()
		var fl2 := UIKit.flow(8)
		var opts: Array = item[1]
		for i in opts.size():
			var idx := i
			var setter: Callable = item[3]
			fl2.add_child(UIKit.chip(String(opts[i]["name"]), i == int(item[2]), g, func():
				setter.call(idx)
				_drain(false)
				_render_tactics()))
		_tac_box.add_child(fl2)


## Quem está em campo, com fôlego, nota e cartão: tocar escolhe quem sai.
func _render_subs(t: MatchTeam) -> void:
	var auto := CheckButton.new()
	auto.text = "Assistente troca jogadores cansados"
	auto.button_pressed = t.auto_subs
	auto.focus_mode = Control.FOCUS_NONE
	auto.toggled.connect(func(v: bool): t.auto_subs = v)
	_tac_box.add_child(auto)
	var left := t.max_subs - t.subs_used
	_tac_box.add_child(UIKit.label("Quem sai? %d de %d trocas feitas." % [t.subs_used, t.max_subs], "Muted"))
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
	row.add_child(UIKit.player_stars(world(),mp.p,15,false,pos))
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
	_set_bug("FIM DE JOGO", UIColors.MUTED)
	_hide_aux() # sugestão tática não faz sentido depois do apito final
	UIManager.close_all_modals()
	# A data inteira fecha numa thread de trabalho (a tela não trava; o aviso mostra o andamento).
	GameManager.finish_match_async(_after_final)


func _after_final(report: Dictionary) -> void:
	_report = report
	if not is_inside_tree() or is_queued_for_deletion():
		return
	var mine: int = _sim.score[_user_side]
	var theirs: int = _sim.score[1 - _user_side]
	if mine > theirs:
		Sfx.play("win", -4.0)
	elif mine < theirs:
		Sfx.play("lose", -6.0)
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
	# Mesa-redonda dos comentaristas nos jogos grandes
	if Pundits.is_big(_sim):
		var lg := world().league(_fx.comp)
		_feed.add_child(Pundits.card("Mesa-redonda", Pundits.review(world(), _sim, lg.nation if lg != null else _sim.teams[0].club.nation)))
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


# ---------------------------------------------------------------------------
# Auxiliar ao vivo
# ---------------------------------------------------------------------------

func _build_aux_bar() -> Control:
	_aux_bar = PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.07, 0.19, 0.23, 0.96)
	box.border_color = Color("#6FD3C1")
	box.border_width_left = 5
	box.set_corner_radius_all(10)
	box.content_margin_left = 14
	box.content_margin_right = 10
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	_aux_bar.add_theme_stylebox_override(&"panel", box)
	var row := UIKit.hbox(10)
	row.add_child(UIKit.icon_rect("tactics", 30, Color("#6FD3C1")))
	_aux_text = UIKit.label("", "Small", true)
	_aux_text.add_theme_color_override(&"font_color", Color("#E6FFF9"))
	_aux_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_aux_text)
	var col := UIKit.vbox(6)
	_aux_btn = UIKit.button("Aplicar", "PrimaryButton", _apply_aux)
	_aux_btn.custom_minimum_size = Vector2(190, 58)
	_aux_btn.add_theme_font_size_override(&"font_size", 20)
	col.add_child(_aux_btn)
	var no := UIKit.button("Dispensar", "GhostButton", _hide_aux)
	no.custom_minimum_size = Vector2(190, 50)
	no.add_theme_font_size_override(&"font_size", 19)
	col.add_child(no)
	row.add_child(col)
	_aux_bar.add_child(row)
	_aux_bar.visible = false
	return UIKit.margin(_aux_bar, 12, 2, 12, 4)


## Depois de cada minuto: o auxiliar tem algo a dizer?
func _assistant_tick() -> void:
	if _aux_state.is_empty() or _done:
		return
	var w := world()
	var reads := Assistant.live(w, _sim, _user_side, _aux_state)
	for r: Dictionary in reads:
		var txt := "%s: %s" % [Assistant.name_of(w), String(r["text"])]
		_enqueue({"text": txt, "style": "assistant", "side": _user_side, "minute": _sim.display_minute()}, {}, 0.4)
		var act: Dictionary = r.get("act", {})
		_show_aux(String(r["text"]), act)


func _show_aux(text: String, act: Dictionary) -> void:
	if _aux_bar == null or _done:
		return
	_aux_act = act
	_aux_text.text = text
	_aux_btn.visible = not act.is_empty()
	if not act.is_empty():
		_aux_btn.text = "Abrir" if String(act.get("kind", "")) == "tactics" else Assistant.act_label(act)
	_aux_bar.get_parent().visible = true
	_aux_bar.visible = true
	_aux_timer = 12.0


func _hide_aux() -> void:
	if _aux_bar == null:
		return
	_aux_bar.visible = false
	_aux_act = {}
	_aux_timer = 0.0


func _apply_aux() -> void:
	var act := _aux_act
	_hide_aux()
	if act.is_empty() or _done:
		return
	if String(act.get("kind", "")) == "tactics":
		_open_tactics()
		return
	var msg := Assistant.apply_live(_sim, _user_side, act)
	_drain(false)
	_sync_slots()
	_update_board()
	if msg != "":
		UIManager.toast(msg)


## No intervalo: as leituras mais importantes do auxiliar, cada uma com o ajuste pronto.
func _halftime_assistant() -> Control:
	var w := world()
	var reads := Assistant.halftime(_sim, _user_side)
	var card := UIKit.vbox(8)
	if reads.is_empty():
		return card
	card.add_child(UIKit.colored("%s, no vestiário:" % Assistant.name_of(w), Color("#6FD3C1"), "Caps"))
	for r: Dictionary in reads:
		var row := UIKit.hbox(8)
		var l := UIKit.label("• " + String(r["text"]), "Small", true)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var act: Dictionary = r.get("act", {})
		if not act.is_empty() and String(act.get("kind", "")) != "tactics":
			var b := UIKit.button(Assistant.act_label(act), "GhostButton")
			b.custom_minimum_size = Vector2(170, 56)
			b.pressed.connect(func():
				var msg := Assistant.apply_live(_sim, _user_side, act)
				_drain(false)
				_sync_slots()
				_update_board()
				b.disabled = true
				b.text = "Feito"
				if msg != "":
					UIManager.toast(msg))
			row.add_child(b)
		card.add_child(row)
	return card
