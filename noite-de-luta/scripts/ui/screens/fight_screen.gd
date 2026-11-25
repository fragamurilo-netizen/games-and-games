class_name FightScreen
extends BaseScreen
## A luta ao vivo, como numa transmissão: o placar (round, relógio, fôlego, dano e a linha de
## números da luta), o palco com a luta animada e três abas embaixo: os lances narrados, os
## números ao vivo (round ou luta inteira) e o placar não oficial da transmissão.
## No intervalo, o corner: números do round, a leitura do técnico e o plano para o round
## seguinte. No fim, a ficha dos juízes round a round, o resultado e a bolsa.
## Com `spectator` (presidente, ou um fã assistindo), ninguém é "a sua equipe": os dois corners
## ajustam o plano sozinhos e o intervalo mostra o que cada um pediu.
## Com o aparelho deitado, o placar e o palco ficam à esquerda e as abas, o conteúdo e o rodapé
## vão para uma coluna à direita.

const TABS := [["lances", "Lances"], ["numeros", "Números"], ["placar", "Placar"]]
## Gritos do corner durante o round: [chave, texto do botão, o que muda no plano, o que volta ao soltar].
const SHOUTS := {
	"pe": [
		["cima", "Pra cima!", {"postura": 2, "ritmo": 2}, {"postura": 1, "ritmo": 1}],
		["calma", "Respira!", {"postura": 0, "ritmo": 0, "contra": 1}, {"postura": 1, "ritmo": 1, "contra": 0}],
		["derruba", "Derruba!", {"jogo": 2}, {"jogo": 1}],
		["em_pe", "Em pé!", {"jogo": 0}, {"jogo": 1}],
	],
	"cima": [
		["bate", "Bate!", {"por_cima": 0}, {}],
		["finaliza", "Finaliza!", {"por_cima": 1}, {}],
		["segura", "Segura!", {"por_cima": 2}, {}],
		["solta", "Solta!", {"por_cima": 3}, {}],
	],
	"baixo": [
		["levanta", "Levanta!", {"por_baixo": 0}, {}],
		["raspa", "Raspa!", {"por_baixo": 1}, {}],
		["finaliza", "Finaliza!", {"por_baixo": 2}, {}],
	],
}
## Quantos lances narrados ficam na tela durante o round.
const FEED_LINES := 3

var _e: FightEngine
var _b: Bout
var _side := 0
var _state := "round" # round | corner | done
var _events: Array = []
var _shown := 0
var _clock := 0.0
var _paused := false
var _speed := 1
var _plan: Dictionary = {}
var _feed: VBoxContainer
var _board: PanelContainer
var _board_holder: MarginContainer
var _clock_lbl: Label
var _round_lbl: Label
var _pips: FightHud.Pips
var _bars: Array = [] # [ProgressBar fôlego, ProgressBar dano] por lado
var _pos_lbl: Label
var _bars_box: Control
var _mini: FightHud.MiniLine
var _spectator := false
## Onde a luta está na tela (pe | cima | baixo): escolhe os gritos do corner.
var _ctx := "pe"
var _shout_row: HBoxContainer
## Luta animada (lances do motor encenados) e onde ela está na lista de lances.
var _stage: FightStage2D
var _stage_holder: MarginContainer
var _view3d: FightView3D
var _bi := 0
var _skip := false
## Abas embaixo do palco e os números ao vivo: `_base` soma os rounds que já acabaram e
## `_live` é o round atual até o último lance mostrado (o motor corre o round inteiro antes).
var _tab := "lances"
var _tabs_holder: MarginContainer
var _scope := "luta"
var _num_box: VBoxContainer
var _num_panel: FightHud.StatPanel
var _score_box: VBoxContainer
var _lean_bar: FightHud.DuelBar
var _lean_lbl: Label
var _base: Array = [{}, {}]
var _live: Array = [{}, {}]
## Esqueleto: em pé é uma coluna só; deitado, placar e palco à esquerda e o resto numa coluna.
var _body: VBoxContainer
var _split: HBoxContainer
var _side_col: VBoxContainer
var _land := false
var _laid := false
## Revelação dos cartões na decisão (um juiz por vez).
var _reveal: Tween
var _reveal_nodes: Array = []
var _after_reveal := Callable()


func setup(p: Dictionary) -> void:
	super.setup(p)
	show_nav = false
	screen_title = "Luta"
	intro_enabled = false
	_speed = AppSettings.fight_speed
	# O que estava para salvar vai para o arquivo agora, para a gravação não cair no meio da luta.
	GameManager.flush()


func _ready() -> void:
	var w := world()
	_body = get_node("Body")
	_b = w.bout(int(params["bout"]))
	var ev := w.event(_b.event_id)
	screen_title = ev.name
	screen_subtitle = "%s × %s" % [w.fighter(_b.a).short_name(), w.fighter(_b.b).short_name()]
	_spectator = bool(params.get("spectator", false))
	_side = -1 if _spectator else (0 if w.is_user_fighter(w.fighter(_b.a)) else 1)
	_base = [FightHud.blank(), FightHud.blank()]
	_live = [FightHud.blank(), FightHud.blank()]
	_build_board(w)
	if _b.status != "feita":
		_build_stage(w)
	_build_tabs()
	_layout()
	if _b.status == "feita":
		_state = "done"
		_board_done()
		# `fresh`: a luta acabou de ser simulada a pedido (o resultado ainda é novidade).
		_show_result(bool(params.get("fresh", false)))
		return
	_plan = (params.get("plan", {}) as Dictionary).duplicate()
	_e = Career.engine_for(w, _b, true)
	if _side >= 0:
		if not _plan.is_empty():
			_e.set_plan(_side, _plan)
		else:
			_plan = (_e.plans[_side] as Dictionary).duplicate()
	_start_round()


## A luta é montada uma vez; girar o aparelho só troca o esqueleto de lugar.
func refresh() -> void:
	if _body != null:
		_layout()


# --- Esqueleto --------------------------------------------------------------------------

func _layout() -> void:
	var land := UILayout.is_landscape() and _stage_holder != null
	if not _laid or land != _land:
		_laid = true
		_land = land
		for n: Control in [_board_holder, _stage_holder, _tabs_holder, _scroll_node, _footer_node]:
			if n != null and n.get_parent() != null:
				n.get_parent().remove_child(n)
		if _split != null:
			_split.queue_free()
			_split = null
			_side_col = null
		if land:
			_split = HBoxContainer.new()
			_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
			_split.add_theme_constant_override(&"separation", 0)
			_body.add_child(_split)
			var left := VBoxContainer.new()
			left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			left.add_theme_constant_override(&"separation", 0)
			_split.add_child(left)
			left.add_child(_board_holder)
			left.add_child(_stage_holder)
			_side_col = VBoxContainer.new()
			_side_col.add_theme_constant_override(&"separation", 0)
			_split.add_child(_side_col)
			for n: Control in [_tabs_holder, _scroll_node, _footer_node]:
				_side_col.add_child(n)
		else:
			for n: Control in [_board_holder, _stage_holder, _tabs_holder, _scroll_node, _footer_node]:
				if n != null:
					_body.add_child(n)
		fit_content = not land
		_tabs_holder.add_theme_constant_override(&"margin_left", 0 if land else UITokens.GUTTER_DENSE)
		if land:
			_margin_node.add_theme_constant_override(&"margin_left", 0)
			_margin_node.add_theme_constant_override(&"margin_right", UITokens.GUTTER_DENSE)
			_footer_box.custom_minimum_size.x = 0
			_footer_box.size_flags_horizontal = Control.SIZE_FILL
		else:
			_fit_content_width()
	if _side_col != null:
		_side_col.custom_minimum_size.x = clampf(UILayout.viewport.x * 0.5, 440.0, 680.0)
	if _stage_holder != null:
		_stage_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_stage_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL if _land else Control.SIZE_FILL
		_stage_holder.add_theme_constant_override(&"margin_bottom", UITokens.S2 if _land else 0)
		_size_stage()


## Em pé, o palco encolhe quando a luta acaba: o resultado precisa do espaço.
func _stage_h() -> float:
	if _land:
		return 220.0
	return FightStage2D.stage_height() * (0.6 if _state == "done" else (0.5 if _state == "corner" else 1.0))


func _size_stage(animate: bool = false) -> void:
	var h := _stage_h()
	for n: Control in [_stage, _view3d]:
		if n == null:
			continue
		if animate and Anim.on() and n.custom_minimum_size.y > h:
			var tw := n.create_tween()
			tw.tween_property(n, "custom_minimum_size:y", h, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		else:
			n.custom_minimum_size.y = h


# --- Placar fixo ------------------------------------------------------------------------

func _build_board(w: GameWorld) -> void:
	_board = PanelContainer.new()
	_board.theme_type_variation = "Card"
	var v := UIKit.vbox(UITokens.S1)
	var top := UIKit.hbox(UITokens.S2)
	for i in 2:
		var f := w.fighter(_b.a if i == 0 else _b.b)
		var side := UIKit.hbox(8)
		side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var bar := ColorRect.new()
		bar.color = FightHud.corner_color(i)
		bar.custom_minimum_size = Vector2(5, 52)
		var p := FightKit.portrait(w, f, 52)
		var tv := UIKit.vbox(-2)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var n := UIKit.label(f.short_name(), "H3")
		n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var rk := w.rank_text(f)
		var sub := UIKit.label("Sua equipe" if i == _side else ("%s · %s" % [rk, f.record_text()] if rk != "Sem ranking" else f.record_text()), "Meta")
		sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		if i == _side:
			sub.add_theme_color_override(&"font_color", UIColors.GOLD)
		tv.add_child(n)
		tv.add_child(sub)
		if i == 0:
			side.add_child(bar)
			side.add_child(p)
			side.add_child(tv)
		else:
			n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			side.add_child(tv)
			side.add_child(p)
			side.add_child(bar)
		top.add_child(side)
		if i == 0:
			var mid := UIKit.vbox(-4)
			mid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			_round_lbl = UIKit.label("R1", "Caps")
			_round_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			mid.add_child(_round_lbl)
			_clock_lbl = UIKit.label("5:00", "Stat")
			_clock_lbl.add_theme_font_override(&"font", DataTable.tabular_font())
			_clock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			mid.add_child(_clock_lbl)
			_pips = FightHud.Pips.new()
			_pips.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			_pips.set_round(1, _b.rounds)
			mid.add_child(UIKit.margin(_pips, 0, 4, 0, 0))
			top.add_child(mid)
	v.add_child(top)
	# Fôlego e dano: uma linha para cada, com o rótulo no meio (vermelho à esquerda, azul à direita).
	var bars := UIKit.vbox(4)
	_bars_box = bars
	_bars = [[null, null], [null, null]]
	var defs := [["Fôlego", UIColors.GREEN, 8, 100.0], ["Dano", UIColors.RED, 6, 0.0]]
	for k in defs.size():
		var row := UIKit.hbox(UITokens.S2)
		for i in 2:
			var pb := UIKit.bar(float(defs[k][3]), 100.0, defs[k][1], int(defs[k][2]))
			pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			if i == 1:
				pb.fill_mode = ProgressBar.FILL_END_TO_BEGIN
			_bars[i][k] = pb
			row.add_child(pb)
			if i == 0:
				var cap := UIKit.label(String(defs[k][0]), "Caps")
				cap.custom_minimum_size.x = 76
				cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				row.add_child(cap)
		bars.add_child(row)
	v.add_child(bars)
	_mini = FightHud.MiniLine.new()
	_mini.set_stats(_base[0], _base[1])
	v.add_child(_mini)
	_pos_lbl = UIKit.label("Em pé, no centro", "Meta")
	_pos_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pos_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(_pos_lbl)
	_board.add_child(v)
	_board_holder = UIKit.margin(_board, UITokens.GUTTER_DENSE, UITokens.S2, UITokens.GUTTER_DENSE, 0)


## Luta que já acabou sem passar na tela (simulada): o placar mostra onde ela terminou, sem as
## barras de fôlego e dano de uma luta que ninguém viu.
func _board_done() -> void:
	var r := _b.result
	var finish := not (String(r.get("method", "")) in ["DEC", "EMP"])
	var last := int(r.get("round", 1)) if finish else _b.rounds
	_round_lbl.text = "Fim · R%d" % last
	_clock_lbl.text = Fmt.clock(maxf(0.0, FightEngine.ROUND_S - float(r.get("time", 0.0)))) if finish else "0:00"
	_pips.set_round(last, _b.rounds, true)
	_bars_box.visible = false
	_pos_lbl.text = "Luta encerrada"
	var st: Array = r.get("stats", [])
	if st.size() == 2:
		_mini.set_stats(st[0], st[1])
	else:
		_mini.visible = false


func _build_stage(w: GameWorld) -> void:
	_stage = FightStage2D.new()
	_stage.setup(w, w.fighter(_b.a), w.fighter(_b.b))
	var ev0 := w.event(_b.event_id)
	if ev0 != null and ev0.name.rstrip("0123456789 ") != "":
		_stage.logo = ev0.name.rstrip("0123456789 ").to_upper()
	_stage_holder = MarginContainer.new()
	_stage_holder.add_theme_constant_override(&"margin_left", UITokens.GUTTER_DENSE)
	_stage_holder.add_theme_constant_override(&"margin_right", UITokens.GUTTER_DENSE)
	_stage_holder.add_theme_constant_override(&"margin_top", UITokens.S2)
	_mount_view()


func _build_tabs() -> void:
	var seg := UIKit.segment(TABS, _tab, func(k: String): _set_tab(k))
	_tabs_holder = UIKit.margin(seg, UITokens.GUTTER_DENSE, UITokens.S2, UITokens.GUTTER_DENSE, 0)
	_tabs_holder.visible = false


## Põe a luta na vista escolhida (2D, 3D ou escondida no modo texto, onde ela segue tocando).
func _mount_view() -> void:
	if _view3d != null:
		_view3d.release()
		_view3d.queue_free()
		_view3d = null
	if _stage.get_parent() != null:
		_stage.get_parent().remove_child(_stage)
	if AppSettings.fight_view == "3d":
		_view3d = FightView3D.new()
		var ev := world().event(_b.event_id)
		var logo := ev.name.rstrip("0123456789 ") if ev != null else ""
		_view3d.setup(_stage, UIColors.CORNER_RED, logo)
		_stage_holder.add_child(_view3d)
	else:
		_stage.visible = true
		_stage_holder.add_child(_stage)
	_stage_holder.visible = AppSettings.fight_view != "texto"
	_size_stage()


func _feed_stage() -> void:
	if _stage == null:
		return
	_stage.time_scale = [1.0, 1.4, 2.4][clampi(_speed, 0, 2)]
	while _bi < _e.beats.size() and float((_e.beats[_bi] as Dictionary)["t"]) <= _clock:
		_stage.add_beat(_e.beats[_bi])
		_bi += 1
	if _skip:
		_skip = false
		_stage.skip()


func _toggle_view() -> void:
	var i := AppSettings.FIGHT_VIEWS.find(AppSettings.fight_view)
	AppSettings.fight_view = AppSettings.FIGHT_VIEWS[(i + 1) % AppSettings.FIGHT_VIEWS.size()]
	AppSettings.save_settings()
	if _stage != null:
		_mount_view()
	if _state == "round":
		_controls()


func _update_board(ev: Dictionary) -> void:
	var st: Array = ev.get("st", [1.0, 1.0])
	var hd: Array = ev.get("hd", [0.0, 0.0])
	if _stage != null:
		_stage.stamina = [float(st[0]), float(st[1])]
	for i in 2:
		(_bars[i][0] as ProgressBar).value = float(st[i]) * 100.0
		(_bars[i][1] as ProgressBar).value = clampf(float(hd[i]) / 3.0, 0.0, 1.0) * 100.0
	var pos := String(ev.get("pos", "solto"))
	var ctx := "pe"
	if pos.begins_with("chao:") and _side >= 0:
		ctx = "cima" if int(pos.split(":")[2]) == _side else "baixo"
	if ctx != _ctx:
		_ctx = ctx
		_fill_shouts()
	if pos.begins_with("chao:"):
		var parts := pos.split(":")
		var tp := int(parts[2])
		var w := world()
		var who := w.fighter(_b.a if tp == 0 else _b.b).short_name()
		_pos_lbl.text = "No chão: %s por cima (%s)" % [who, String(FightEngine.GPOS_NAME.get(parts[1], parts[1]))]
	elif pos == "clinch":
		_pos_lbl.text = "No clinch"
	else:
		_pos_lbl.text = "Em pé"


## Números ao vivo: a linha do placar (luta inteira) e a aba aberta.
func _refresh_live() -> void:
	var tot := [FightHud.sum([_base[0], _live[0]]), FightHud.sum([_base[1], _live[1]])]
	_mini.set_stats(tot[0], tot[1])
	if _state != "round" or _num_box == null:
		return
	if _tab == "numeros" and _num_panel != null:
		if _scope == "luta":
			_num_panel.set_stats(tot[0], tot[1])
		else:
			_num_panel.set_stats(_live[0], _live[1])
	elif _tab == "placar" and _lean_bar != null:
		var w := world()
		_lean_bar.set_values(FightHud.weight(_live[0]), FightHud.weight(_live[1]))
		_lean_lbl.text = FightHud.lean_text(_live[0], _live[1], w.fighter(_b.a).short_name(), w.fighter(_b.b).short_name())


func _set_tab(k: String) -> void:
	_tab = k
	if _feed != null:
		_feed.visible = k == "lances"
	if _num_box != null:
		_num_box.visible = k == "numeros"
	if _score_box != null:
		_score_box.visible = k == "placar"
	_refresh_live()
	var sc := scroll()
	if k == "lances":
		(func(): if is_instance_valid(sc): sc.scroll_vertical = int(sc.get_v_scroll_bar().max_value)).call_deferred()
	else:
		sc.scroll_vertical = 0


# --- Round ao vivo ----------------------------------------------------------------------

func _start_round() -> void:
	_state = "round"
	# O round corre aos poucos, junto com o relógio: o grito do corner vale dali em diante.
	_events = _e.begin_round()
	_shown = 0
	_clock = 0.0
	_round_lbl.text = "R%d de %d" % [_e.round_no, _e.rounds]
	_pips.set_round(_e.round_no, _e.rounds)
	var prev: Array = [[], []]
	for r in _e.round_stats.size() - 1:
		for i in 2:
			(prev[i] as Array).append(_e.round_stats[r][i])
	_base = [FightHud.sum(prev[0]), FightHud.sum(prev[1])]
	_live = [FightHud.blank(), FightHud.blank()]
	var c := reset()
	_feed = UIKit.vbox(UITokens.S1)
	c.add_child(_feed)
	_num_box = null
	_score_box = null
	_num_panel = null
	_lean_bar = null
	_tabs_holder.visible = false
	_tab = "lances"
	_ctx = "pe"
	_mini.visible = false
	_pos_lbl.visible = false
	_size_stage(true)
	_controls()
	set_process(true)


## Aba "Números": a comparação completa, da luta inteira ou só do round que está correndo.
func _build_numbers(c: Container) -> void:
	_num_box = UIKit.vbox(UITokens.S2)
	_num_box.add_child(UIKit.segment([["luta", "Luta inteira"], ["round", "%dº round" % _e.round_no]], _scope, func(k: String):
		_scope = k
		_refresh_live()))
	_num_panel = FightHud.StatPanel.new()
	_num_box.add_child(_num_panel)
	c.add_child(_num_box)


## Aba "Placar": os rounds fechados pela conta da transmissão e quem leva o round de agora.
func _build_score(c: Container) -> void:
	var w := world()
	_score_box = UIKit.vbox(UITokens.S2)
	_score_box.add_child(FightHud.legend(w.fighter(_b.a).short_name(), w.fighter(_b.b).short_name()))
	_score_box.add_child(FightHud.cards_table(["Transmissão"], [FightHud.broadcast_cards(_e.round_stats, _e.round_no - 1)], _e.rounds, _e.round_no - 1))
	_lean_lbl = UIKit.label("Round ainda sem dono", "H3")
	_lean_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_box.add_child(_lean_lbl)
	_lean_bar = FightHud.DuelBar.new(8)
	_score_box.add_child(_lean_bar)
	_score_box.add_child(UIKit.label("Placar não oficial, pelos números da transmissão. Os cartões dos juízes só saem no fim.", "Meta", true))
	c.add_child(_score_box)


func _controls() -> void:
	var foot := footer()
	UIKit.clear(foot)
	_shout_row = null
	if _side >= 0:
		# O corner grita e o lutador muda o jeito de lutar dali em diante.
		_shout_row = UIKit.hbox(UITokens.S1)
		foot.add_child(_shout_row)
		_fill_shouts()
	var row := UIKit.hbox(UITokens.S2)
	var items: Array = []
	for i in AppSettings.FIGHT_SPEED_NAMES.size():
		items.append([str(i), AppSettings.FIGHT_SPEED_NAMES[i]])
	var seg := UIKit.segment(items, str(_speed), func(k: String):
		_speed = int(k)
		AppSettings.fight_speed = _speed
		AppSettings.save_settings())
	seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(seg)
	row.add_child(UIKit.button("Pular", "GhostButton", func():
		_clock = 99999.0
		_skip = true))
	foot.add_child(row)


func _shout_on(sh: Array) -> bool:
	for k: String in (sh[2] as Dictionary):
		if int(_plan.get(k, -1)) != int(sh[2][k]):
			return false
	return true


func _fill_shouts() -> void:
	if _shout_row == null or not is_instance_valid(_shout_row):
		return
	UIKit.clear(_shout_row)
	for sh: Array in SHOUTS[_ctx]:
		var on := _shout_on(sh)
		var b := UIKit.chip(String(sh[1]), on, null, func(): _shout(sh))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 56
		b.add_theme_font_size_override(&"font_size", 17)
		_shout_row.add_child(b)


## Grito do corner: troca o plano na hora. Gritar de novo a mesma ordem solta (volta ao equilíbrio).
func _shout(sh: Array) -> void:
	var release := _shout_on(sh) and not (sh[3] as Dictionary).is_empty()
	var change: Dictionary = sh[3] if release else sh[2]
	for k: String in change:
		_plan[k] = int(change[k])
	_e.set_plan(_side, _plan)
	if not release and _feed != null:
		var me := world().fighter(_b.a if _side == 0 else _b.b)
		var h := UIKit.hbox(8)
		var t := UIKit.label(Fmt.clock(FightEngine.ROUND_S - minf(_clock, FightEngine.ROUND_S)), "Meta")
		t.custom_minimum_size.x = 52
		t.add_theme_font_override(&"font", DataTable.tabular_font())
		h.add_child(t)
		var mark := ColorRect.new()
		mark.custom_minimum_size = Vector2(3, 0)
		mark.color = UIColors.GOLD
		h.add_child(mark)
		h.add_child(UIKit.colored("Corner de %s: “%s”" % [me.short_name(), String(sh[1])], UIColors.GOLD, "Small", true))
		_push_line(h)
	_fill_shouts()


## Põe uma linha na narração e deixa só as últimas na tela.
func _push_line(h: Control) -> void:
	_feed.add_child(h)
	var kids := _feed.get_children().filter(func(n: Node) -> bool: return not n.is_queued_for_deletion())
	while kids.size() > FEED_LINES:
		(kids.pop_front() as Node).queue_free()
	var n := kids.size()
	for i in n:
		(kids[i] as Control).modulate.a = [0.4, 0.7, 1.0][clampi(i + 3 - n, 0, 2)]


func _process(delta: float) -> void:
	if _state != "round" or _paused:
		return
	# Na apresentação dos lutadores (round 1, vista 2D) o relógio espera; "Pular" passa por cima.
	var held := _stage != null and _stage_holder.visible and _stage.holding() and _clock < 9000.0
	if not held:
		_clock += delta * AppSettings.FIGHT_SPEEDS[clampi(_speed, 0, AppSettings.FIGHT_SPEEDS.size() - 1)]
	var guard := 0
	while _e.round_live and _e.t <= _clock and guard < 400:
		_e.step_round()
		guard += 1
	var last: Dictionary = {}
	while _shown < _events.size() and float((_events[_shown] as Dictionary)["t"]) <= _clock:
		last = _events[_shown]
		_add_line(last)
		_shown += 1
	if not last.is_empty():
		_update_board(last)
		_refresh_live()
	_feed_stage()
	var shown_clock := minf(_clock, FightEngine.ROUND_S)
	if _shown > 0 and _shown >= _events.size():
		shown_clock = float((_events.back() as Dictionary)["t"])
	_clock_lbl.text = Fmt.clock(FightEngine.ROUND_S - shown_clock)
	var stage_busy := _stage != null and _stage_holder.visible and not _stage.idle()
	if not _e.round_live and _shown >= _events.size() and (_clock >= FightEngine.ROUND_S or _e.finished) and not stage_busy:
		set_process(false)
		_end_round()


func _add_line(ev: Dictionary) -> void:
	var kind := String(ev.get("kind", "info"))
	var side := int(ev.get("side", -1))
	var h := UIKit.hbox(8)
	var t := UIKit.label(Fmt.clock(FightEngine.ROUND_S - float(ev["t"])), "Meta")
	t.custom_minimum_size.x = 52
	t.add_theme_font_override(&"font", DataTable.tabular_font())
	h.add_child(t)
	var mark := ColorRect.new()
	mark.custom_minimum_size = Vector2(3, 0)
	mark.color = Color(0, 0, 0, 0) if side < 0 else FightHud.corner_color(side)
	h.add_child(mark)
	var var_name := "H3" if kind in ["forte", "kd", "fin", "fim", "queda"] else ("Small" if kind == "info" else "")
	var l := UIKit.label(String(ev["text"]), var_name, true)
	l.max_lines_visible = 2
	if kind in ["kd", "fim"]:
		l.add_theme_color_override(&"font_color", UIColors.GOLD)
	elif kind == "fin":
		l.add_theme_color_override(&"font_color", UIColors.ORANGE)
	h.add_child(l)
	_push_line(h)
	var ls: Array = ev.get("ls", [])
	if ls.size() == 2:
		_live = ls
	if kind == "kd":
		Sfx.play("applause" if _side < 0 or side == _side else "boo", -8.0)
		Sfx.vibrate(60)
		Anim.pulse(_mini, 1.05, 0.4)


func _end_round() -> void:
	if not _e.finished and _e.round_no < _e.rounds:
		_e.between_rounds()
	if _e.finished or _e.round_no >= _e.rounds:
		_finish()
		return
	_corner()


# --- Corner -----------------------------------------------------------------------------

## O cartão do intervalo: os números do round que acabou e o placar da transmissão até aqui.
func _interval_cards(c: Container) -> VBoxContainer:
	var w := world()
	var rs: Array = _e.round_stats.back()
	var card := UIKit.card("CardHighlight", UITokens.S2)
	card.add_child(UIKit.label("Intervalo · fim do %dº round" % _e.round_no, "Section"))
	var panel := FightHud.StatPanel.new(["sig", "kd", "td", "sub_att", "ctrl"])
	panel.set_stats(rs[0], rs[1])
	card.add_child(panel)
	c.add_child(UIKit.card_panel(card))
	var sc := UIKit.card("Card", UITokens.S1)
	sc.add_child(UIKit.label("Placar da transmissão", "Section"))
	sc.add_child(FightHud.legend(w.fighter(_b.a).short_name(), w.fighter(_b.b).short_name()))
	sc.add_child(FightHud.cards_table(["Transmissão"], [FightHud.broadcast_cards(_e.round_stats, _e.round_no)], _e.rounds))
	sc.add_child(UIKit.label("Não oficial: os cartões dos juízes só saem no fim.", "Meta", true))
	c.add_child(UIKit.card_panel(sc))
	return card


func _corner() -> void:
	_state = "corner"
	_tabs_holder.visible = false
	_size_stage(true)
	if _spectator:
		_corner_both()
		return
	var w := world()
	var me := w.fighter(_b.a if _side == 0 else _b.b)
	var opp := w.fighter(_b.b if _side == 0 else _b.a)
	var rs: Array = _e.round_stats.back()
	var c := reset()
	_feed = null
	_num_panel = null
	_lean_bar = null
	var card := _interval_cards(c)
	card.add_child(UIKit.label(_read_for(rs, _side), "", true))
	var stam := float(_e.s[_side]["st"])
	card.add_child(UIKit.kv("Fôlego de %s" % me.short_name(), "%d%%" % int(stam * 100.0), UIColors.GREEN if stam > 0.6 else (UIColors.ORANGE if stam > 0.35 else UIColors.RED)))
	if float(_e.s[_side]["cut"]) > 0.5:
		card.add_child(UIKit.colored("O corte está feio. Mais um round apanhando e o médico pode parar a luta.", UIColors.RED, "Small", true))
	# O plano inteiro fica guardado: quem quiser mexer em tudo abre; o resto se grita no round.
	var pc := UIKit.card("Card", UITokens.S2)
	var pc_panel := UIKit.card_panel(pc)
	pc_panel.visible = false
	pc.add_child(PlanEditor.build(_plan, func(): pass, false))
	var open := UIKit.button("Plano: %s" % FightPlan.summary(_plan), "GhostButton", Callable())
	open.pressed.connect(func():
		pc_panel.visible = not pc_panel.visible
		open.visible = false)
	open.clip_text = true
	c.add_child(open)
	c.add_child(pc_panel)
	var foot := footer()
	UIKit.clear(foot)
	foot.add_child(UIKit.button("Começar o %dº round" % (_e.round_no + 1), "PrimaryButton", func():
		_e.set_plan(_side, _plan)
		var other := 1 - _side
		var lost := _e._rounds_lost(other)
		_e.plans[other] = FightPlan.adjust(_e.plans[other], _e.f[other], lost, float(_e.s[other]["st"]), _e.rounds - _e.round_no)
		_start_round()))
	scroll().scroll_vertical = 0
	Anim.stagger(c.get_children())


## Intervalo visto de fora: os números do round e o que cada corner pediu para o próximo.
func _corner_both() -> void:
	var w := world()
	var rs: Array = _e.round_stats.back()
	var c := reset()
	_feed = null
	_num_panel = null
	_lean_bar = null
	_interval_cards(c)
	for i in 2:
		var me := w.fighter(_b.a if i == 0 else _b.b)
		var lost := _e._rounds_lost(i)
		_e.plans[i] = FightPlan.adjust(_e.plans[i], _e.f[i], lost, float(_e.s[i]["st"]), _e.rounds - _e.round_no)
		var cc := UIKit.card("Card", UITokens.S1)
		var head := UIKit.hbox(8)
		var bar := ColorRect.new()
		bar.color = FightHud.corner_color(i)
		bar.custom_minimum_size = Vector2(4, 30)
		head.add_child(bar)
		head.add_child(UIKit.label("Corner de %s" % me.short_name(), "H3"))
		cc.add_child(head)
		cc.add_child(UIKit.label(_read_for(rs, i), "", true))
		cc.add_child(UIKit.label("Plano: " + FightPlan.summary(_e.plans[i]) + ".", "Small", true))
		var stam := float(_e.s[i]["st"])
		cc.add_child(UIKit.kv("Fôlego", "%d%%" % int(stam * 100.0), UIColors.GREEN if stam > 0.6 else (UIColors.ORANGE if stam > 0.35 else UIColors.RED)))
		if float(_e.s[i]["cut"]) > 0.5:
			cc.add_child(UIKit.colored("Corte feio: o médico olha de perto.", UIColors.RED, "Small"))
		c.add_child(UIKit.card_panel(cc))
	var foot := footer()
	UIKit.clear(foot)
	foot.add_child(UIKit.button("Começar o %dº round" % (_e.round_no + 1), "PrimaryButton", func(): _start_round()))
	scroll().scroll_vertical = 0
	Anim.stagger(c.get_children())


## O que o corner `i` diz no intervalo, pelos números do round (o técnico chuta quem levou o
## round; não vê os cartões dos juízes).
func _read_for(rs: Array, i: int) -> String:
	var mine := FightHud.weight(rs[i])
	var theirs := FightHud.weight(rs[1 - i])
	if mine > theirs * 1.25:
		return "“Esse round é nosso. Continua assim.”"
	if theirs > mine * 1.25:
		return "“Perdemos esse round. Precisa mudar alguma coisa.”"
	return "“Round apertado, pode ter ido para qualquer lado.”"


# --- Fim --------------------------------------------------------------------------------

func _finish() -> void:
	_state = "done"
	var res := _e.finalize()
	var w := world()
	Career.resolve(w, _b, res, _e)
	keep_log(_b, _e)
	GameManager.save_now()
	_pips.set_round(_e.round_no, _e.rounds, true)
	_mini.visible = true
	_size_stage(true)
	_show_result(true)


## Guarda os lances principais da luta para rever no perfil.
static func keep_log(b: Bout, e: FightEngine) -> void:
	var lg: Array = []
	for ev: Dictionary in e.events:
		if String(ev["kind"]) in ["forte", "kd", "fin", "fim", "queda"]:
			lg.append({"r": int(ev["r"]), "t": float(ev["t"]), "text": String(ev["text"]), "side": int(ev["side"])})
	b.log = lg.slice(maxi(0, lg.size() - 60))


## O resultado. Na decisão, a ficha dos juízes vem antes do anúncio e, se a luta acabou agora
## na tela (`fresh`), cada juiz aparece na sua vez. Depois de uma finalização ou nocaute, os
## cartões entram mais abaixo, em "Como estava nos cartões".
func _show_result(fresh: bool = false) -> void:
	set_process(false)
	_tabs_holder.visible = false
	var w := world()
	var c := reset()
	_feed = null
	_num_panel = null
	_lean_bar = null
	var res := _b.result
	var wid := int(res.get("winner_id", -1))
	var dec := String(res.get("method", "")) in ["DEC", "EMP"]
	var rcards: Array = res.get("rcards", [])
	var has_cards := rcards.size() == 3 and not (rcards[0] as Array).is_empty()
	var fa := w.fighter(_b.a)
	var fb := w.fighter(_b.b)
	var me: Fighter = null if _side < 0 else (fa if _side == 0 else fb)
	var judge_rows: Array = []
	if dec and has_cards:
		var jc := UIKit.card("Card", UITokens.S1)
		jc.add_child(UIKit.label("Cartões dos juízes", "Section"))
		jc.add_child(FightHud.legend(fa.short_name(), fb.short_name()))
		var table := FightHud.cards_table(FightHud.judge_names(_b), rcards, _b.rounds)
		jc.add_child(table)
		judge_rows = table.get_meta(&"rows")
		c.add_child(UIKit.card_panel(jc))
	var card := UIKit.card("CardHighlight", UITokens.S2)
	var hl := UIKit.label("Empate" if wid < 0 else "Vitória de %s!" % w.fighter(wid).display_name(), "Title", true)
	if wid >= 0 and (me != null and wid == me.id or me == null and _b.title):
		hl.add_theme_color_override(&"font_color", UIColors.GOLD)
	card.add_child(hl)
	card.add_child(UIKit.label(FightKit.result_text(_b), "H3", true))
	if dec and not has_cards:
		card.add_child(UIKit.kv("Juízes", FightKit.cards_text(_b)))
	if me != null:
		_result_mine(w, card, me, wid)
	else:
		_result_neutral(w, card, wid)
	var result_panel := UIKit.card_panel(card)
	c.add_child(result_panel)
	var rest: Array = []
	if not dec and has_cards:
		var kc := UIKit.card("Card", UITokens.S1)
		kc.add_child(UIKit.label("Como estava nos cartões", "Section"))
		kc.add_child(FightHud.legend(fa.short_name(), fb.short_name()))
		kc.add_child(FightHud.cards_table(FightHud.judge_names(_b), rcards, _b.rounds))
		rest.append(UIKit.card_panel(kc))
	var totals := FightHud.totals_panel(_b)
	if totals != null:
		var nc := UIKit.card("Card", UITokens.S2)
		nc.add_child(UIKit.label("Números da luta", "Section"))
		nc.add_child(FightHud.legend(fa.short_name(), fb.short_name()))
		nc.add_child(totals)
		rest.append(UIKit.card_panel(nc))
	if not _b.log.is_empty():
		var lc := UIKit.vbox(UITokens.S1)
		lc.add_child(UIKit.section_header("Lances principais"))
		for ev: Dictionary in _b.log:
			var h := UIKit.hbox(8)
			var tl := UIKit.label("R%d %s" % [int(ev["r"]), Fmt.clock(FightEngine.ROUND_S - float(ev["t"]))], "Meta")
			tl.custom_minimum_size.x = 84
			tl.add_theme_font_override(&"font", DataTable.tabular_font())
			h.add_child(tl)
			var mark := ColorRect.new()
			mark.custom_minimum_size = Vector2(3, 0)
			var sd := int(ev.get("side", -1))
			mark.color = Color(0, 0, 0, 0) if sd < 0 else FightHud.corner_color(sd)
			h.add_child(mark)
			h.add_child(UIKit.label(String(ev["text"]), "Small", true))
			lc.add_child(h)
		rest.append(lc)
	for n: Control in rest:
		c.add_child(n)
	scroll().scroll_vertical = 0
	var done := func():
		_reveal_nodes = []
		# Som e destaque só na hora em que a luta acaba; rever uma luta antiga é em silêncio.
		if fresh:
			if me == null:
				Sfx.play("applause", -6.0)
			elif wid == me.id:
				Sfx.play("win", -4.0)
			elif wid >= 0:
				Sfx.play("lose", -6.0)
			Anim.pulse(hl, 1.06, 0.4)
			_show_headline(result_panel)
			SeasonKit.celebrate_later(1.4)
		var foot := footer()
		UIKit.clear(foot)
		foot.add_child(UIKit.button("Continuar", "PrimaryButton", func():
			if me != null:
				UIManager.goto("hub")
			else:
				UIManager.back()))
	if fresh and not judge_rows.is_empty() and Anim.on():
		_play_reveal(judge_rows, [result_panel] + rest, done)
	else:
		done.call()
		if fresh:
			Anim.stagger(c.get_children())


## Depois dos cartões, a rolagem desce o que faltar para o anúncio aparecer inteiro.
func _show_headline(panel: Control) -> void:
	var sc := scroll()
	(func():
		if not is_instance_valid(sc) or not is_instance_valid(panel):
			return
		var top := panel.global_position.y - sc.global_position.y + sc.scroll_vertical
		var want := int(clampf(top + minf(panel.size.y, 260.0) - sc.size.y, 0.0, top))
		if want <= sc.scroll_vertical:
			return
		if Anim.on():
			var tw := sc.create_tween()
			tw.tween_property(sc, "scroll_vertical", want, 0.35).set_delay(0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		else:
			sc.scroll_vertical = want).call_deferred()


## A parte do resultado que só interessa a quem tem um lutador na luta: o dinheiro, o cartel,
## o ranking, os marcos e a moral.
func _result_mine(w: GameWorld, card: VBoxContainer, me: Fighter, wid: int) -> void:
	var p := _b.purse_of(me.id)
	var earned := (float(p["show"]) + (float(p["win"]) if wid == me.id else 0.0)) * float(me.contract.get("cut", 0.2))
	card.add_child(UIKit.kv("Para a academia", Fmt.money(earned), UIColors.GREEN))
	card.add_child(UIKit.kv("Cartel de %s" % me.short_name(), me.record_text()))
	card.add_child(UIKit.kv("Ranking", w.rank_text(me)))
	# Marcos que chegaram com esta luta e como ficou a moral.
	for mk: Array in me.marks:
		if int(mk[1]) == w.week and String(mk[0]) != "estreia":
			var mrow := UIKit.hbox(8)
			mrow.add_child(UIKit.icon_rect("medal", 24, UIColors.GOLD))
			mrow.add_child(UIKit.colored("Marco: %s" % CareerStats.mark_sentence(String(mk[0])), UIColors.GOLD, "H3", true))
			card.add_child(mrow)
	var mood_d := 0
	for e: Array in me.mood_log:
		if int(e[0]) == w.week:
			mood_d += int(e[1])
	card.add_child(UIKit.kv("Moral", "%s (%s)" % [Morale.label(me).to_lower(), Fmt.signed(mood_d)] if mood_d != 0 else Morale.label(me).to_lower(), UIColors.GREEN if mood_d > 0 else (UIColors.RED if mood_d < 0 else UIColors.TEXT)))
	if not me.injury.is_empty():
		card.add_child(UIKit.colored("%s saiu com %s (%d semanas)." % [me.short_name(), String(me.injury["name"]).to_lower(), int(me.injury["weeks"])], UIColors.RED, "Small", true))


## Resultado visto de fora (presidente ou fã): o cinturão, os cartéis e o ranking dos dois.
func _result_neutral(w: GameWorld, card: VBoxContainer, wid: int) -> void:
	if _b.title and wid >= 0:
		card.add_child(UIKit.colored("%s é o campeão dos %s." % [w.fighter(wid).short_name(), Matchmaker.division_name(_b.division, true)], UIColors.GOLD, "H3", true))
	for fid: int in [_b.a, _b.b]:
		var f := w.fighter(fid)
		card.add_child(UIKit.kv(f.short_name(), "%s · %s" % [f.record_text(), w.rank_text(f)]))
		if not f.injury.is_empty():
			card.add_child(UIKit.colored("%s saiu com %s (%d semanas)." % [f.short_name(), String(f.injury["name"]).to_lower(), int(f.injury["weeks"])], UIColors.RED, "Small", true))


## Um juiz por vez, depois o anúncio. O botão do rodapé corta a espera.
func _play_reveal(rows: Array, after: Array, done: Callable) -> void:
	_reveal_nodes = rows + after
	_after_reveal = done
	for n: Control in _reveal_nodes:
		n.modulate.a = 0.0
	var foot := footer()
	UIKit.clear(foot)
	foot.add_child(UIKit.button("Ver o resultado", "PrimaryButton", _end_reveal))
	_reveal = create_tween()
	_reveal.tween_interval(0.5)
	for r: Control in rows:
		_reveal.tween_callback(func(): Sfx.play("score", -4.0))
		_reveal.tween_property(r, "modulate:a", 1.0, 0.25)
		_reveal.tween_interval(0.85)
	_reveal.tween_interval(0.35)
	_reveal.tween_callback(_end_reveal)


func _end_reveal() -> void:
	if _reveal != null and _reveal.is_valid():
		_reveal.kill()
	_reveal = null
	var nodes := _reveal_nodes
	for n: Control in nodes:
		if is_instance_valid(n) and n.modulate.a < 1.0:
			var tw := n.create_tween()
			tw.tween_property(n, "modulate:a", 1.0, 0.2)
	var cb := _after_reveal
	_after_reveal = Callable()
	if cb.is_valid():
		cb.call()
