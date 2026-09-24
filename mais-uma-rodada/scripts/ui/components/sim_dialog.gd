class_name SimDialog
extends VBoxContainer
## "Simular até...": joga vários jogos seguidos sem assistir, com progresso na tela e
## parada automática quando algo pede a atenção do treinador (decisão, proposta, lesão).

const MODE_GAMES := 0
const MODE_MONTH := 1
const MODE_WINDOW_END := 2
const MODE_WINDOW_OPEN := 3
const MODE_SEASON := 4

static var stop_on_events := true
static var auto_lineup := true

var mode := MODE_GAMES
var games_target := 1
var on_done: Callable
var _running := false
var _stop_reason := ""
var _results: Array = [] # [Fixture]
var _start_month := 0
var _pos_before := 0
var _status: Label
var _bar: ProgressBar
var _list: VBoxContainer
var _new_events: Array = []


## Folha com as opções de simulação.
static func open(done: Callable) -> void:
	var w := GameManager.world
	if w == null or w.season == null:
		return
	var v := UIKit.vbox(12)
	v.add_child(UIKit.label("Simular sem assistir", "Title"))
	v.add_child(UIKit.label("Os jogos são disputados no motor completo, só que sem a transmissão. Você pode parar a qualquer momento.", "Small", true))
	var opts: Array = [[MODE_GAMES, 1, "Próximo jogo", "play"], [MODE_GAMES, 3, "Próximos 3 jogos", "fast"], [MODE_MONTH, 0, "Até o fim do mês", "clock"]]
	if w.transfer_window_open():
		opts.append([MODE_WINDOW_END, 0, "Até fechar a janela de transferências", "swap"])
	elif w.next_window_day() >= 0:
		opts.append([MODE_WINDOW_OPEN, 0, "Até abrir a janela de transferências", "swap"])
	opts.append([MODE_SEASON, 0, "Até o fim da temporada", "trophy"])
	for o in opts:
		var row := UIKit.hbox(12)
		row.add_child(UIKit.icon_rect(String(o[3]), 30, UIColors.ACCENT))
		var l := UIKit.label(String(o[2]), "H3")
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var m: int = o[0]
		var n: int = o[1]
		v.add_child(UIKit.tap_row(row, func():
			UIManager.close_modal()
			start(m, n, done), "Card"))
	v.add_child(_toggle("Parar em decisões, propostas e lesões", stop_on_events, func(on: bool): stop_on_events = on))
	v.add_child(_toggle("Assistente escala o time a cada jogo", auto_lineup, func(on: bool): auto_lineup = on))
	v.add_child(UIKit.button("Cancelar", "GhostButton", func(): UIManager.close_modal()))
	UIManager.show_modal(v, true)


static func _toggle(text: String, on: bool, cb: Callable) -> Control:
	var row := UIKit.hbox(10)
	var l := UIKit.label(text, "", true)
	row.add_child(l)
	var cbx := CheckButton.new()
	cbx.button_pressed = on
	cbx.toggled.connect(cb)
	row.add_child(cbx)
	return row


static func start(m: int, n: int, done: Callable) -> void:
	var d := SimDialog.new()
	d.mode = m
	d.games_target = n
	d.on_done = done
	UIManager.show_modal(d, false, false)


func _ready() -> void:
	custom_minimum_size.x = 580
	add_theme_constant_override(&"separation", 12)
	var w := GameManager.world
	add_child(UIKit.label("Simulando...", "Title"))
	_status = UIKit.label("", "", true)
	add_child(_status)
	_bar = UIKit.bar(0.0, 1.0, UIColors.ACCENT, 14)
	add_child(_bar)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size.y = 420
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list = UIKit.vbox(6)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_list)
	add_child(sc)
	add_child(UIKit.button("Parar", "GhostButton", func(): _stop_reason = "Simulação interrompida."))
	_start_month = w.season.month_of(w.season.day)
	var league := w.league_of(w.user_club_id)
	if league != null and int(league.table[w.user_club_id]["pl"]) > 0:
		_pos_before = CompetitionManager.position_of(league, w.user_club_id)
	_running = true


func _process(_delta: float) -> void:
	if not _running:
		return
	if _stop_reason == "":
		_step()
	if _stop_reason != "":
		_running = false
		_finish()


func _step() -> void:
	var w := GameManager.world
	if GameManager.season_over():
		_stop_reason = "Temporada encerrada."
		return
	var club := w.user_club()
	var f := FixtureManager.next_fixture_for(w, club.id)
	if f == null:
		GameManager.advance_to_end()
		_stop_reason = "Seu time não joga mais nesta temporada."
		return
	match mode:
		MODE_GAMES:
			if _results.size() >= games_target:
				_stop_reason = "Pronto."
				return
		MODE_MONTH:
			if w.season.month_of(f.slot) != _start_month:
				_stop_reason = "Fim do mês."
				return
		MODE_WINDOW_END:
			if not w.window_open_at(f.slot):
				_stop_reason = "A janela de transferências fechou."
				return
		MODE_WINDOW_OPEN:
			if w.window_open_at(f.slot) or w.transfer_window_open():
				_stop_reason = "A janela de transferências abriu."
				return
	if auto_lineup and club.sheet != null:
		club.sheet = ClubAI.auto_sheet(w, club, club.sheet.formation)
	else:
		ClubAI.validate_user_sheet(w, club)
	var offers_before := TransferManager.pending_offers(w).size()
	var injured_before := {}
	for p: Player in w.squad(club):
		if p.is_injured():
			injured_before[p.id] = true
	var report := GameManager.play_instant()
	if report.is_empty():
		_stop_reason = "Nada a simular."
		return
	var uf: Fixture = report.get("user", {}).get("fixture", null)
	if uf != null:
		_results.append(uf)
		_list.add_child(_result_row(w, uf))
	_status.text = "%d jogo(s) · %s" % [_results.size(), w.season.date_label(w.season.day, false)]
	_bar.value = _progress(w)
	_new_events.append_array(report.get("events", []))
	if stop_on_events:
		if not report.get("events", []).is_empty():
			_stop_reason = "Uma decisão espera por você."
		elif TransferManager.pending_offers(w).size() > offers_before:
			_stop_reason = "Chegou uma proposta por um jogador seu."
		else:
			for p: Player in w.squad(club):
				if p.injury_weeks >= 3 and not injured_before.has(p.id) and p.squad_status <= Player.STATUS_STARTER:
					_stop_reason = "%s se lesionou (%d semanas)." % [p.display_name(), p.injury_weeks]
					break


func _progress(w: GameWorld) -> float:
	match mode:
		MODE_GAMES:
			return float(_results.size()) / maxf(1.0, games_target)
		MODE_SEASON:
			return float(w.season.day) / maxf(1.0, w.season.calendar.size())
	return clampf(float(_results.size()) / 5.0, 0.0, 0.95)


func _result_row(w: GameWorld, f: Fixture) -> Control:
	var uid := w.user_club_id
	var row := UIKit.hbox(10)
	var res := f.result_for(uid)
	row.add_child(UIKit.text_badge(res, UIColors.result_color(res), 40, 34, 20))
	var opp := w.club(f.opponent_of(uid))
	row.add_child(UIKit.crest(opp, 32))
	var l := UIKit.label(("vs " if f.home == uid else "@ ") + opp.short_name, "")
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(l)
	var mine := f.hg if f.home == uid else f.ag
	var theirs := f.ag if f.home == uid else f.hg
	var score := "%d x %d" % [mine, theirs]
	if f.pen_h >= 0 or f.pen_a >= 0:
		score += " (pên.)"
	row.add_child(UIKit.label(score, "Stat"))
	row.add_child(UIKit.label(CompText.comp_short(w, f.comp), "Small"))
	return row


func _finish() -> void:
	var w := GameManager.world
	UIKit.clear(self)
	var wins := 0
	var draws := 0
	var losses := 0
	for f: Fixture in _results:
		match f.result_for(w.user_club_id):
			"V":
				wins += 1
			"E":
				draws += 1
			_:
				losses += 1
	add_child(UIKit.label("Simulação concluída", "Title"))
	add_child(UIKit.label(_stop_reason, "H3", true))
	var stats := UIKit.hbox(4)
	stats.add_child(UIKit.stat(str(wins), "vitórias", UIColors.GREEN))
	stats.add_child(UIKit.stat(str(draws), "empates"))
	stats.add_child(UIKit.stat(str(losses), "derrotas", UIColors.RED))
	var league := w.league_of(w.user_club_id)
	if league != null and not w.season.finished and int(league.table[w.user_club_id]["pl"]) > 0:
		var pos := CompetitionManager.position_of(league, w.user_club_id)
		var arrow := "" if _pos_before == 0 or pos == _pos_before else (" ▲" if pos < _pos_before else " ▼")
		stats.add_child(UIKit.stat("%dº%s" % [pos, arrow], "na liga"))
	add_child(stats)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size.y = 300
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := UIKit.vbox(6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for f: Fixture in _results:
		list.add_child(_result_row(w, f))
	sc.add_child(list)
	add_child(sc)
	var pending := EventManager.pending(w)
	if not pending.is_empty():
		var ev: Dictionary = pending[0]
		add_child(UIKit.button("RESPONDER: %s" % EventManager.describe(w, ev)["title"], "PrimaryButton", func():
			UIManager.close_modal()
			if on_done.is_valid():
				on_done.call()
			EventDialog.open(ev, on_done), "info"))
	add_child(UIKit.button("OK", "GhostButton" if not pending.is_empty() else "PrimaryButton", func():
		UIManager.close_modal()
		if on_done.is_valid():
			on_done.call()))
