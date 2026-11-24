extends BaseScreen
## Semana de luta: pesagem, ficha dos dois, leitura do técnico e o plano para o primeiro round.

static var plans: Dictionary = {} # id da luta -> plano escolhido

var _plan: Dictionary = {}
var _side := 0


func setup(p: Dictionary) -> void:
	super.setup(p)
	screen_title = "Plano de luta"
	show_nav = false


func refresh() -> void:
	var w := world()
	var b := w.bout(int(params["bout"]))
	var c := reset()
	if b == null or b.status != "marcada":
		c.add_child(UIKit.state_block("empty", "Esta luta já aconteceu"))
		return
	_side = 0 if w.is_user_fighter(w.fighter(b.a)) else 1
	var me := w.fighter(b.a if _side == 0 else b.b)
	var opp := w.fighter(b.b if _side == 0 else b.a)
	if _plan.is_empty():
		_plan = plans.get(b.id, FightPlan.suggest(me, opp)).duplicate()
	var ev := w.event(b.event_id)
	screen_subtitle = "%s · %s" % [ev.name, ev.city]
	UIManager.refresh_chrome()
	var top := UIKit.card("CardHighlight", UITokens.S2)
	top.add_child(UIKit.label("%s · %d rounds%s" % [Matchmaker.division_short(b.division), b.rounds, " · valendo o cinturão" if b.title else ""], "Caps"))
	top.add_child(FightKit.faceoff(w, w.fighter(b.a), w.fighter(b.b), 130))
	c.add_child(UIKit.card_panel(top))
	# Primeiro a decisão: o que o técnico leu e o plano do primeiro round. Como os dois chegam
	# (pesagem e camp), a ficha e os atributos do adversário ficam logo abaixo, para consulta.
	var pc := UIKit.card("Card", UITokens.S2)
	var ph := UIKit.hbox(8)
	var pt := UIKit.label("Plano para o 1º round", "Section")
	pt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ph.add_child(pt)
	var reset_btn := UIKit.button("Plano do técnico", "TextButton", func():
		_plan = FightPlan.suggest(me, opp)
		plans[b.id] = _plan.duplicate()
		refresh())
	reset_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ph.add_child(reset_btn)
	pc.add_child(ph)
	var read := UIKit.hbox(UITokens.S2)
	var ri := UIKit.icon_rect("whistle", 24, UIColors.ACCENT)
	ri.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	read.add_child(ri)
	read.add_child(UIKit.label(PlanEditor.coach_read(me, opp), "Small", true))
	var rp := PanelContainer.new()
	rp.theme_type_variation = "CardInset"
	rp.add_child(read)
	pc.add_child(rp)
	pc.add_child(PlanEditor.build(_plan, func(): plans[b.id] = _plan.duplicate()))
	c.add_child(UIKit.card_panel(pc))
	# Como chegam: a pesagem e o camp de cada um, num cartão só.
	var wi := Career.weigh_in(w, b)
	var wc := UIKit.card("Card", UITokens.S1)
	wc.add_child(UIKit.label("Como chegam", "Section"))
	var limit := float(DataDB.division(b.division).get("limit_kg", 70.0))
	# Fora de disputa de cinturão vale meio quilo de tolerância (a mesma conta de Career.weigh_in).
	wc.add_child(UIKit.label("Pesagem · limite de %s" % (Fmt.kg(limit) + ", sem tolerância" if b.title else Fmt.kg(limit + 0.5)), "Caps"))
	for i in 2:
		var f := w.fighter(b.a if i == 0 else b.b)
		var missed: bool = (wi["missed"] as Array).has(f.id)
		var cut := float((wi["cut"] as Array)[i])
		var txt := "%s · %s" % [Fmt.kg(float((wi["kg"] as Array)[i])), "errou o peso, perde 20% da bolsa" if missed else "no peso"]
		wc.add_child(UIKit.kv(f.short_name(), txt, UIColors.RED if missed else (UIColors.ORANGE if cut > 0.11 else UIColors.TEXT)))
	var my_cut := float((wi["cut"] as Array)[_side])
	if my_cut > 0.11:
		wc.add_child(UIKit.label("Corte de %d%% do peso: %s chega com menos fôlego e queixo. Um nutricionista ajuda." % [int(round(my_cut * 100.0)), me.short_name()], "Small", true))
	if me.condition < 90.0:
		wc.add_child(UIKit.label("%s está com %d%% da condição física." % [me.short_name(), int(me.condition)], "Small", true))
	var camps: Array = wi.get("camp", [])
	if camps.size() >= 2:
		wc.add_child(UIKit.separator())
		wc.add_child(UIKit.label("Camp", "Caps"))
		for i in 2:
			var f := w.fighter(b.a if i == 0 else b.b)
			var o := w.fighter(b.b if i == 0 else b.a)
			var cd: Dictionary = camps[i]
			var pts := float(cd.get("pts", 0.0))
			wc.add_child(UIKit.kv(f.short_name(), "%s (%d%%)" % [Camp.label(pts), int(round(pts))], UIColors.GREEN if pts >= 65.0 else (UIColors.ORANGE if pts < 45.0 else UIColors.TEXT)))
			var focus := String(cd.get("focus", "plano"))
			var lines := Camp.gain_lines(Camp.mods_for(pts, focus, f, o, b, bool(cd.get("spar", false))))
			var what := String(Camp.FOCUS[focus]["name"]).to_lower() if Camp.FOCUS.has(focus) else focus
			wc.add_child(UIKit.label("Foco: %s. %s" % [what, (", ".join(lines) + ".") if i == _side and not lines.is_empty() else ""], "Small", true))
		var mm := Morale.fight_mods(me)
		if not mm.is_empty():
			wc.add_child(UIKit.label("%s entra %s: %s." % [me.short_name(), Morale.label(me).to_lower(), ", ".join(Camp.gain_lines(mm))], "Small", true))
	c.add_child(UIKit.card_panel(wc))
	var tape := UIKit.card("Card", UITokens.S1)
	tape.add_child(UIKit.label("Ficha", "Section"))
	tape.add_child(FightKit.tape(w, w.fighter(b.a), w.fighter(b.b)))
	c.add_child(UIKit.card_panel(tape))
	c.add_child(UIKit.section_header("Atributos de %s" % opp.short_name()))
	c.add_child(FightKit.attr_card(opp, me))
	var foot := footer()
	var row := UIKit.hbox(UITokens.S2)
	var sim := UIKit.button("Simular", "GhostButton", func():
		plans[b.id] = _plan.duplicate()
		var e := Career.engine_for(w, b, true)
		e.set_plan(_side, _plan)
		var res := e.run_all()
		Career.resolve(w, b, res, e)
		FightScreen.keep_log(b, e)
		GameManager.save_now()
		UIManager.replace("fight", {"bout": b.id, "fresh": true}))
	sim.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sim.size_flags_stretch_ratio = 0.6
	row.add_child(sim)
	var go := UIKit.button("Ir para a luta", "PrimaryButton", func():
		plans[b.id] = _plan.duplicate()
		UIManager.replace("fight", {"bout": b.id, "plan": _plan.duplicate()}))
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(go)
	foot.add_child(row)
	TutorialKit.tip(self, "fight_plan")
