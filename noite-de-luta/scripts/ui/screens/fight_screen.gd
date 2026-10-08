class_name FightScreen
extends BaseScreen
## A luta ao vivo, em texto (como no LEATHER): placar com o relógio do round, fôlego e dano de
## cada um e a narração lance a lance. No intervalo, o corner: números do round, a leitura do
## técnico e o plano para o round seguinte. No fim, o resultado e a bolsa.
## Com `spectator` (presidente, ou um fã assistindo), ninguém é "a sua equipe": os dois corners
## ajustam o plano sozinhos e o intervalo mostra o que cada um pediu.

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
var _clock_lbl: Label
var _round_lbl: Label
var _bars: Array = [] # [ProgressBar fôlego, ProgressBar dano] por lado
var _pos_lbl: Label
var _spectator := false


func setup(p: Dictionary) -> void:
	super.setup(p)
	show_nav = false
	screen_title = "Luta"
	_speed = AppSettings.fight_speed


func _ready() -> void:
	var w := world()
	_b = w.bout(int(params["bout"]))
	var ev := w.event(_b.event_id)
	screen_title = ev.name
	screen_subtitle = "%s × %s" % [w.fighter(_b.a).short_name(), w.fighter(_b.b).short_name()]
	_spectator = bool(params.get("spectator", false))
	_side = -1 if _spectator else (0 if w.is_user_fighter(w.fighter(_b.a)) else 1)
	_build_board(w)
	if _b.status == "feita":
		_state = "done"
		_show_result()
		return
	_plan = (params.get("plan", {}) as Dictionary).duplicate()
	_e = Career.engine_for(w, _b, true)
	if _side >= 0:
		if not _plan.is_empty():
			_e.set_plan(_side, _plan)
		else:
			_plan = (_e.plans[_side] as Dictionary).duplicate()
	_start_round()


func refresh() -> void:
	pass # a luta é montada uma vez; nada reconstrói no meio


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
		bar.color = UIColors.CORNER_RED if i == 0 else UIColors.CORNER_BLUE
		bar.custom_minimum_size = Vector2(5, 52)
		var p := FightKit.portrait(w, f, 52)
		var n := UIKit.label(f.short_name(), "H3")
		n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if i == 0:
			side.add_child(bar)
			side.add_child(p)
			side.add_child(n)
		else:
			n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			side.add_child(n)
			side.add_child(p)
			side.add_child(bar)
		top.add_child(side)
		if i == 0:
			var mid := UIKit.vbox(-4)
			_round_lbl = UIKit.label("R1", "Caps")
			_round_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			mid.add_child(_round_lbl)
			_clock_lbl = UIKit.label("5:00", "Stat")
			_clock_lbl.add_theme_font_override(&"font", DataTable.tabular_font())
			_clock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			mid.add_child(_clock_lbl)
			top.add_child(mid)
	v.add_child(top)
	var bars := UIKit.hbox(UITokens.S3)
	for i in 2:
		var bv := UIKit.vbox(3)
		bv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var st := UIKit.bar(100.0, 100.0, UIColors.GREEN, 8)
		var dm := UIKit.bar(0.0, 100.0, UIColors.RED, 5)
		var cap := UIKit.label("Sua equipe · fôlego e dano" if i == _side else "Fôlego e dano", "Meta")
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if i == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		bv.add_child(st)
		bv.add_child(dm)
		bv.add_child(cap)
		if i == 1:
			st.fill_mode = ProgressBar.FILL_END_TO_BEGIN
			dm.fill_mode = ProgressBar.FILL_END_TO_BEGIN
		bars.add_child(bv)
		_bars.append([st, dm])
	v.add_child(bars)
	_pos_lbl = UIKit.label("Em pé, no centro", "Small")
	_pos_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_pos_lbl)
	_board.add_child(UIKit.margin(v, 0, 0, 0, 0))
	var body := get_node("Body")
	var holder := UIKit.margin(_board, UITokens.GUTTER_DENSE, UITokens.S2, UITokens.GUTTER_DENSE, 0)
	body.add_child(holder)
	body.move_child(holder, 0)


func _update_board(ev: Dictionary) -> void:
	var st: Array = ev.get("st", [1.0, 1.0])
	var hd: Array = ev.get("hd", [0.0, 0.0])
	for i in 2:
		(_bars[i][0] as ProgressBar).value = float(st[i]) * 100.0
		(_bars[i][1] as ProgressBar).value = clampf(float(hd[i]) / 3.0, 0.0, 1.0) * 100.0
	var pos := String(ev.get("pos", "solto"))
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


# --- Round ao vivo ----------------------------------------------------------------------

func _start_round() -> void:
	_state = "round"
	_events = _e.run_round()
	_shown = 0
	_clock = 0.0
	_round_lbl.text = "R%d de %d" % [_e.round_no, _e.rounds]
	var c := reset()
	_feed = UIKit.vbox(UITokens.S1)
	c.add_child(_feed)
	_controls()
	set_process(true)


func _controls() -> void:
	var foot := footer()
	UIKit.clear(foot)
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
	row.add_child(UIKit.button("Pular", "GhostButton", func(): _clock = 99999.0))
	foot.add_child(row)


func _process(delta: float) -> void:
	if _state != "round" or _paused:
		return
	_clock += delta * AppSettings.FIGHT_SPEEDS[clampi(_speed, 0, AppSettings.FIGHT_SPEEDS.size() - 1)]
	var last_t := 0.0
	while _shown < _events.size() and float((_events[_shown] as Dictionary)["t"]) <= _clock:
		var ev: Dictionary = _events[_shown]
		_add_line(ev)
		last_t = float(ev["t"])
		_shown += 1
	var shown_clock := minf(_clock, FightEngine.ROUND_S)
	if _shown > 0 and _shown >= _events.size():
		shown_clock = float((_events.back() as Dictionary)["t"])
	_clock_lbl.text = Fmt.clock(FightEngine.ROUND_S - shown_clock)
	if _shown >= _events.size() and (_clock >= FightEngine.ROUND_S or _e.finished):
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
	mark.color = Color(0, 0, 0, 0) if side < 0 else (UIColors.CORNER_RED if side == 0 else UIColors.CORNER_BLUE)
	h.add_child(mark)
	var var_name := "H3" if kind in ["forte", "kd", "fin", "fim", "queda"] else ("Small" if kind == "info" else "")
	var l := UIKit.label(String(ev["text"]), var_name, true)
	if kind in ["kd", "fim"]:
		l.add_theme_color_override(&"font_color", UIColors.GOLD)
	elif kind == "fin":
		l.add_theme_color_override(&"font_color", UIColors.ORANGE)
	h.add_child(l)
	_feed.add_child(h)
	_update_board(ev)
	if kind == "kd":
		Sfx.play("applause" if _side < 0 or side == _side else "boo", -8.0)
		Sfx.vibrate(60)
	var sc := scroll()
	(func(): if is_instance_valid(sc): sc.scroll_vertical = int(sc.get_v_scroll_bar().max_value)).call_deferred()


func _end_round() -> void:
	if not _e.finished and _e.round_no < _e.rounds:
		_e.between_rounds()
	if _e.finished or _e.round_no >= _e.rounds:
		_finish()
		return
	_corner()


# --- Corner -----------------------------------------------------------------------------

func _corner() -> void:
	_state = "corner"
	if _spectator:
		_corner_both()
		return
	var w := world()
	var me := w.fighter(_b.a if _side == 0 else _b.b)
	var opp := w.fighter(_b.b if _side == 0 else _b.a)
	var rs: Array = _e.round_stats.back()
	var c := reset()
	_feed = null
	var card := UIKit.card("CardHighlight", UITokens.S1)
	card.add_child(UIKit.label("Intervalo · fim do %dº round" % _e.round_no, "Section"))
	var stats := [["Golpes certos", "sig_land"], ["Quedas", "td"], ["Knockdowns", "kd"], ["Tentativas de finalização", "sub_att"]]
	for s: Array in stats:
		card.add_child(_versus(String(s[0]), float(rs[0][s[1]]), float(rs[1][s[1]])))
	card.add_child(_versus("Controle (s)", roundf(float(rs[0]["ctrl"])), roundf(float(rs[1]["ctrl"]))))
	card.add_child(UIKit.label(_corner_read(rs), "", true))
	var stam := float(_e.s[_side]["st"])
	card.add_child(UIKit.kv("Fôlego de %s" % me.short_name(), "%d%%" % int(stam * 100.0), UIColors.GREEN if stam > 0.6 else (UIColors.ORANGE if stam > 0.35 else UIColors.RED)))
	if float(_e.s[_side]["cut"]) > 0.5:
		card.add_child(UIKit.colored("O corte está feio. Mais um round apanhando e o médico pode parar a luta.", UIColors.RED, "Small", true))
	c.add_child(UIKit.card_panel(card))
	c.add_child(UIKit.section_header("Plano para o %dº round" % (_e.round_no + 1)))
	var pc := UIKit.card("Card", UITokens.S2)
	pc.add_child(PlanEditor.build(_plan, func(): pass, false))
	c.add_child(UIKit.card_panel(pc))
	c.add_child(UIKit.label("Plano do técnico para %s contra %s: %s." % [me.short_name(), opp.short_name(), FightPlan.summary(FightPlan.suggest(me, opp))], "Small", true))
	var foot := footer()
	UIKit.clear(foot)
	foot.add_child(UIKit.button("Começar o %dº round" % (_e.round_no + 1), "PrimaryButton", func():
		_e.set_plan(_side, _plan)
		var other := 1 - _side
		var lost := _e._rounds_lost(other)
		_e.plans[other] = FightPlan.adjust(_e.plans[other], _e.f[other], lost, float(_e.s[other]["st"]), _e.rounds - _e.round_no)
		_start_round()))
	scroll().scroll_vertical = 0


## Intervalo visto de fora: os números do round e o que cada corner pediu para o próximo.
func _corner_both() -> void:
	var w := world()
	var rs: Array = _e.round_stats.back()
	var c := reset()
	_feed = null
	var card := UIKit.card("CardHighlight", UITokens.S1)
	card.add_child(UIKit.label("Intervalo · fim do %dº round" % _e.round_no, "Section"))
	for s: Array in [["Golpes certos", "sig_land"], ["Quedas", "td"], ["Knockdowns", "kd"], ["Tentativas de finalização", "sub_att"]]:
		card.add_child(_versus(String(s[0]), float(rs[0][s[1]]), float(rs[1][s[1]])))
	card.add_child(_versus("Controle (s)", roundf(float(rs[0]["ctrl"])), roundf(float(rs[1]["ctrl"]))))
	c.add_child(UIKit.card_panel(card))
	for i in 2:
		var me := w.fighter(_b.a if i == 0 else _b.b)
		var lost := _e._rounds_lost(i)
		_e.plans[i] = FightPlan.adjust(_e.plans[i], _e.f[i], lost, float(_e.s[i]["st"]), _e.rounds - _e.round_no)
		var cc := UIKit.card("Card", UITokens.S1)
		var head := UIKit.hbox(8)
		var bar := ColorRect.new()
		bar.color = UIColors.CORNER_RED if i == 0 else UIColors.CORNER_BLUE
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


## O que o corner `i` diz no intervalo, pelos números do round.
func _read_for(rs: Array, i: int) -> String:
	var sc := [0.0, 0.0]
	for k in 2:
		var st: Dictionary = rs[k]
		sc[k] = float(st["sig_land"]) + float(st["kd"]) * 8.0 + float(st["td"]) * 2.5 + float(st["ctrl"]) / 25.0 + float(st["sub_att"]) * 1.5 + float(st["dmg"]) * 1.5
	var mine: float = sc[i]
	var theirs: float = sc[1 - i]
	if mine > theirs * 1.25:
		return "“Esse round é nosso. Continua assim.”"
	if theirs > mine * 1.25:
		return "“Perdemos esse round. Precisa mudar alguma coisa.”"
	return "“Round apertado, pode ter ido para qualquer lado.”"


func _versus(label: String, a: float, b: float) -> Control:
	return UIKit.versus_row(label, str(int(a)), str(int(b)), a, b)


## O técnico chuta quem levou o round, pelos números (não vê os cartões dos juízes).
func _corner_read(rs: Array) -> String:
	var sc := [0.0, 0.0]
	for i in 2:
		var st: Dictionary = rs[i]
		sc[i] = float(st["sig_land"]) + float(st["kd"]) * 8.0 + float(st["td"]) * 2.5 + float(st["ctrl"]) / 25.0 + float(st["sub_att"]) * 1.5 + float(st["dmg"]) * 1.5
	var mine: float = sc[_side]
	var theirs: float = sc[1 - _side]
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
	_show_result()


## Guarda os lances principais da luta para rever no perfil.
static func keep_log(b: Bout, e: FightEngine) -> void:
	var lg: Array = []
	for ev: Dictionary in e.events:
		if String(ev["kind"]) in ["forte", "kd", "fin", "fim", "queda"]:
			lg.append({"r": int(ev["r"]), "t": float(ev["t"]), "text": String(ev["text"]), "side": int(ev["side"])})
	b.log = lg.slice(maxi(0, lg.size() - 60))


func _show_result() -> void:
	set_process(false)
	if _side < 0:
		_show_result_neutral()
		return
	var w := world()
	var c := reset()
	var log_box := UIKit.vbox(UITokens.S1)
	if true:
		for ev: Dictionary in _b.log:
			var h := UIKit.hbox(8)
			h.add_child(UIKit.label("R%d %s" % [int(ev["r"]), Fmt.clock(FightEngine.ROUND_S - float(ev["t"]))], "Meta"))
			h.add_child(UIKit.label(String(ev["text"]), "Small", true))
			log_box.add_child(h)
	var me := w.fighter(_b.a if _side == 0 else _b.b)
	var wid := int(_b.result.get("winner_id", -1))
	var card := UIKit.card("CardHighlight", UITokens.S2)
	var headline := "Empate" if wid < 0 else ("Vitória de %s!" % w.fighter(wid).display_name())
	var hl := UIKit.label(headline, "Title", true)
	if wid >= 0:
		hl.add_theme_color_override(&"font_color", UIColors.GOLD if wid == me.id else UIColors.TEXT)
	card.add_child(hl)
	card.add_child(UIKit.label(FightKit.result_text(_b), "H3", true))
	if String(_b.result.get("method", "")) in ["DEC", "EMP"]:
		card.add_child(UIKit.kv("Juízes", FightKit.cards_text(_b)))
	var p := _b.purse_of(me.id)
	var earned := (float(p["show"]) + (float(p["win"]) if wid == me.id else 0.0)) * float(me.contract.get("cut", 0.2))
	card.add_child(UIKit.kv("Para a academia", Fmt.money(earned), UIColors.GREEN))
	card.add_child(UIKit.kv("Cartel de %s" % me.short_name(), me.record_text()))
	card.add_child(UIKit.kv("Ranking", w.rank_text(me)))
	if not me.injury.is_empty():
		card.add_child(UIKit.colored("%s saiu com %s (%d semanas)." % [me.short_name(), String(me.injury["name"]).to_lower(), int(me.injury["weeks"])], UIColors.RED, "Small", true))
	c.add_child(UIKit.card_panel(card))
	if log_box.get_child_count() > 0:
		c.add_child(UIKit.section_header("Lances principais"))
		c.add_child(log_box)
	if wid == me.id:
		Sfx.play("win", -4.0)
	elif wid >= 0:
		Sfx.play("lose", -6.0)
	var foot := footer()
	UIKit.clear(foot)
	foot.add_child(UIKit.button("Continuar", "PrimaryButton", func(): UIManager.goto("hub")))
	scroll().scroll_vertical = 0


## Resultado visto de fora (presidente ou fã): o vencedor, como foi, os cartões, os cartéis e o
## ranking dos dois, e os lances principais.
func _show_result_neutral() -> void:
	var w := world()
	var c := reset()
	var wid := int(_b.result.get("winner_id", -1))
	var card := UIKit.card("CardHighlight", UITokens.S2)
	var hl := UIKit.label("Empate" if wid < 0 else "Vitória de %s!" % w.fighter(wid).display_name(), "Title", true)
	if _b.title and wid >= 0:
		hl.add_theme_color_override(&"font_color", UIColors.GOLD)
	card.add_child(hl)
	card.add_child(UIKit.label(FightKit.result_text(_b), "H3", true))
	if String(_b.result.get("method", "")) in ["DEC", "EMP"]:
		card.add_child(UIKit.kv("Juízes", FightKit.cards_text(_b)))
	if _b.title and wid >= 0:
		card.add_child(UIKit.colored("%s é o campeão dos %s." % [w.fighter(wid).short_name(), Matchmaker.division_name(_b.division, true)], UIColors.GOLD, "H3", true))
	for fid: int in [_b.a, _b.b]:
		var f := w.fighter(fid)
		card.add_child(UIKit.kv(f.short_name(), "%s · %s" % [f.record_text(), w.rank_text(f)]))
		if not f.injury.is_empty():
			card.add_child(UIKit.colored("%s saiu com %s (%d semanas)." % [f.short_name(), String(f.injury["name"]).to_lower(), int(f.injury["weeks"])], UIColors.RED, "Small", true))
	c.add_child(UIKit.card_panel(card))
	if not _b.log.is_empty():
		c.add_child(UIKit.section_header("Lances principais"))
		for ev: Dictionary in _b.log:
			var h := UIKit.hbox(8)
			h.add_child(UIKit.label("R%d %s" % [int(ev["r"]), Fmt.clock(FightEngine.ROUND_S - float(ev["t"]))], "Meta"))
			h.add_child(UIKit.label(String(ev["text"]), "Small", true))
			c.add_child(h)
	Sfx.play("applause", -6.0)
	var foot := footer()
	UIKit.clear(foot)
	foot.add_child(UIKit.button("Continuar", "PrimaryButton", func(): UIManager.back()))
	scroll().scroll_vertical = 0
