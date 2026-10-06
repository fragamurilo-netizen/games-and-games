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
static var _active: SimDialog = null

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
var _log_start := 0
var _routine_start: Array = [0, 0]


## Folha com as opções de simulação.
static func open(done: Callable) -> void:
	var w := GameManager.world
	if w == null or w.season == null:
		return
	var v := UIKit.vbox(12)
	v.add_child(UIKit.eyebrow("Simulação"))
	v.add_child(UIKit.label("Simular sem assistir", "Title"))
	var opts: Array = [[MODE_GAMES, 1, "Próximo jogo", "play"], [MODE_GAMES, 3, "Próximos 3 jogos", "fast"], [MODE_MONTH, 0, "Até o fim do mês", "clock"]]
	if w.transfer_window_open():
		opts.append([MODE_WINDOW_END, 0, "Até fechar a janela de transferências", "swap"])
	elif w.next_window_day() >= 0:
		opts.append([MODE_WINDOW_OPEN, 0, "Até abrir a janela de transferências", "swap"])
	opts.append([MODE_SEASON, 0, "Até o fim da temporada", "trophy"])
	var rows: Array = []
	for o in opts:
		var m: int = o[0]
		var n: int = o[1]
		rows.append(UIKit.menu_row(String(o[3]), String(o[2]), "", func():
			UIManager.close_modal()
			start(m, n, done)))
	v.add_child(UIKit.menu_group(rows))
	v.add_child(UIKit.section_header("Quem decide"))
	var mode_box := UIKit.vbox(0)
	_mode_rows(mode_box)
	v.add_child(mode_box)
	v.add_child(UIKit.section_header("Opções"))
	if Autopilot.mode == Autopilot.MODE_OFF:
		v.add_child(_toggle("Parar em decisões, propostas e lesões", stop_on_events, func(on: bool): stop_on_events = on))
	v.add_child(_toggle("Assistente escala o time a cada jogo", auto_lineup, func(on: bool): auto_lineup = on))
	v.add_child(UIKit.button("Cancelar", "GhostButton", func(): UIManager.close_modal()))
	UIManager.show_modal(v, true)


## Os três jeitos de delegar ao auxiliar (Autopilot), como linhas de escolha única.
static func _mode_rows(box: VBoxContainer) -> void:
	UIKit.clear(box)
	for i in Autopilot.MODE_NAMES.size():
		var h := UIKit.hbox(12)
		var on := i == Autopilot.mode
		h.add_child(UIKit.icon_rect("check" if on else "minus", 24, UIColors.ACCENT if on else UIColors.DIM))
		var col := UIKit.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UIKit.label(String(Autopilot.MODE_NAMES[i]), "H3"))
		col.add_child(UIKit.label(String(Autopilot.MODE_DESC[i]), "Muted", true))
		h.add_child(col)
		var idx := i
		var row := UIKit.tap_row(h, func():
			Autopilot.mode = idx
			if idx != Autopilot.MODE_OFF:
				auto_lineup = true
			_mode_rows(box))
		row.custom_minimum_size.y = UITokens.H_ROW
		box.add_child(row)


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
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override(&"separation", 12)
	var w := GameManager.world
	add_child(UIKit.label("Simulando...", "Title"))
	_status = UIKit.label("", "", true)
	add_child(_status)
	_bar = UIKit.bar(0.0, 1.0, UIColors.ACCENT, 14)
	add_child(_bar)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size.y = clampf(get_viewport_rect().size.y * 0.35, 144.0, 420.0)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list = UIKit.vbox(6)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_list)
	add_child(sc)
	add_child(UIKit.button("Parar", "GhostButton", func(): _stop_reason = "Simulação interrompida."))
	_start_month = w.season.month_of(w.season.day)
	_log_start = Autopilot.log_mark(w)
	_routine_start = Autopilot.routine(w)
	var league := w.league_of(w.user_club_id)
	if league != null and int(league.table[w.user_club_id]["pl"]) > 0:
		_pos_before = CompetitionManager.position_of(league, w.user_club_id)
	_running = true


## "Voltar" do Android no meio do "Simular": para depois da data em curso.
static func request_stop() -> void:
	if is_instance_valid(_active) and _active._running and _active._stop_reason == "":
		_active._stop_reason = "Simulação interrompida."


func _enter_tree() -> void:
	_active = self


func _process(_delta: float) -> void:
	if not _running:
		return
	# A data roda numa thread de trabalho; aqui só se confere se ela acabou.
	var report = GameManager.sim_step_poll()
	if report != null:
		_after_step(report)
	if GameManager.is_busy():
		return
	if _stop_reason == "":
		_step()
	if _stop_reason != "" and not GameManager.is_busy():
		_running = false
		GameManager.end_batch()
		_finish()


## Fechada no meio (troca de tela): termina a data em curso e grava o que já foi jogado.
func _exit_tree() -> void:
	if _active == self:
		_active = null
	if _running:
		_running = false
		GameManager.end_batch()


var _offers_before := 0
var _injured_before := {}


## Confere se é hora de parar e, se não, dispara a próxima data.
func _step() -> void:
	var w := GameManager.world
	if GameManager.season_over():
		_stop_reason = "Temporada encerrada."
		return
	var club := w.user_club()
	var f := FixtureManager.next_fixture_for(w, club.id)
	if f == null:
		_stop_reason = "Seu time não joga mais nesta temporada."
		GameManager.advance_to_end_async(Callable())
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
		Autopilot.prepare_match(w, club) # o auxiliar estuda o rival e ajusta o plano
	else:
		ClubAI.validate_user_sheet(w, club)
	_offers_before = TransferManager.pending_offers(w).size()
	_injured_before = {}
	for p: Player in w.squad(club):
		if p.is_injured():
			_injured_before[p.id] = true
	GameManager.begin_batch()
	GameManager.sim_step_start()


## Depois de cada data: resultado na lista e as paradas automáticas.
func _after_step(report: Dictionary) -> void:
	var w := GameManager.world
	var club := w.user_club()
	if report.is_empty():
		_stop_reason = "Nada a simular."
		return
	var uf: Fixture = report.get("user", {}).get("fixture", null)
	if uf != null:
		_results.append(uf)
		_list.add_child(_result_row(w, uf))
	_status.text = Fmt.n_of(_results.size(), "%d jogo", "%d jogos") + " · " + w.season.date_label(w.season.day, false)
	_bar.value = _progress(w)
	_new_events.append_array(report.get("events", []))
	if _stop_reason != "":
		return # "Parar" tocado durante a data
	if Autopilot.mode != Autopilot.MODE_OFF:
		_stop_reason = Autopilot.handle(w)
		return
	if stop_on_events:
		if not report.get("events", []).is_empty():
			_stop_reason = "Uma decisão espera por você."
		elif TransferManager.pending_offers(w).size() > _offers_before:
			_stop_reason = "Chegou uma proposta por um jogador seu."
		else:
			for p: Player in w.squad(club):
				if p.injury_weeks >= 3 and not _injured_before.has(p.id) and p.squad_status <= Player.STATUS_STARTER:
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
	var sub := Fmt.n_of(_results.size(), "%d jogo", "%d jogos") + " · " + w.season.date_label(w.season.day, false)
	if _stop_reason != "" and _stop_reason != "Pronto.":
		sub = _stop_reason + "  ·  " + sub
	var sub_l := UIKit.label(sub, "Muted", true)
	add_child(sub_l)
	var stats := UIKit.hbox(4)
	stats.add_child(UIKit.stat(str(wins), "vitória" if wins == 1 else "vitórias", UIColors.GREEN))
	stats.add_child(UIKit.stat(str(draws), "empate" if draws == 1 else "empates"))
	stats.add_child(UIKit.stat(str(losses), "derrota" if losses == 1 else "derrotas", UIColors.RED))
	var league := w.league_of(w.user_club_id)
	if league != null and not w.season.finished and int(league.table[w.user_club_id]["pl"]) > 0:
		var pos := CompetitionManager.position_of(league, w.user_club_id)
		var arrow := "" if _pos_before == 0 or pos == _pos_before else (" ▲" if pos < _pos_before else " ▼")
		stats.add_child(UIKit.stat("%dº%s" % [pos, arrow], "na liga"))
	add_child(stats)
	if not _results.is_empty():
		var list := UIKit.vbox(6)
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for f: Fixture in _results:
			list.add_child(_result_row(w, f))
		# A lista só ocupa o que precisa: com poucos jogos, a caixa fixa de 300 px deixava um vão.
		if _results.size() > 6:
			var sc := ScrollContainer.new()
			sc.custom_minimum_size.y = 300
			sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			sc.add_child(list)
			add_child(sc)
		else:
			add_child(list)
	var done_by_aux := Autopilot.log_since(w, _log_start)
	var rt := Autopilot.routine(w)
	var press := int(rt[0]) - int(_routine_start[0])
	var talks := int(rt[1]) - int(_routine_start[1])
	if not done_by_aux.is_empty() or press + talks > 0:
		add_child(UIKit.label("O que %s decidiu" % Assistant.name_of(w), "Section"))
		if press + talks > 0:
			add_child(UIKit.label("Atendeu %s e %s no seu lugar." % [Fmt.n_of(press, "%d coletiva", "%d coletivas"), Fmt.n_of(talks, "%d conversa com jogador", "%d conversas com jogadores")], "Muted", true))
		var box := UIKit.vbox(4)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for e: Dictionary in done_by_aux:
			box.add_child(UIKit.label("%s · %s" % [String(e["d"]), String(e["w"])], "H3", true))
			if String(e["r"]) != "":
				box.add_child(UIKit.label(String(e["r"]), "Small", true))
		if done_by_aux.size() > 4:
			var sc2 := ScrollContainer.new()
			sc2.custom_minimum_size.y = 260
			sc2.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			sc2.add_child(box)
			add_child(sc2)
		else:
			add_child(box)
	var pending := EventManager.pending(w)
	if not pending.is_empty():
		var ev: Dictionary = pending[0]
		var rb := UIKit.button("Responder: %s" % EventManager.describe(w, ev)["title"], "PrimaryButton", func():
			UIManager.close_modal()
			if on_done.is_valid():
				on_done.call()
			EventDialog.open(ev, on_done), "info")
		UIKit.shrink_button(rb)
		add_child(rb)
	add_child(UIKit.button("OK", "GhostButton" if not pending.is_empty() else "PrimaryButton", func():
		UIManager.close_modal()
		if on_done.is_valid():
			on_done.call()))
