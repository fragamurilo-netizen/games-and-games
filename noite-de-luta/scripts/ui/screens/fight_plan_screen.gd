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
	# Pesagem
	var wi := Career.weigh_in(w, b)
	var wc := UIKit.card("Card", UITokens.S1)
	wc.add_child(UIKit.label("Pesagem", "Section"))
	var limit := float(DataDB.division(b.division).get("limit_kg", 70.0))
	for i in 2:
		var f := w.fighter(b.a if i == 0 else b.b)
		var missed: bool = (wi["missed"] as Array).has(f.id)
		var cut := float((wi["cut"] as Array)[i])
		var txt := "%s (limite %s)" % [Fmt.kg(float((wi["kg"] as Array)[i])), Fmt.kg(limit)]
		if missed:
			txt += " · errou o peso, perde 20% da bolsa"
		wc.add_child(UIKit.kv(f.short_name(), txt, UIColors.RED if missed else (UIColors.ORANGE if cut > 0.11 else UIColors.TEXT)))
	var my_cut := float((wi["cut"] as Array)[_side])
	if my_cut > 0.11:
		wc.add_child(UIKit.label("Corte de %d%% do peso: %s chega com menos fôlego e queixo. Um nutricionista ajuda." % [int(round(my_cut * 100.0)), me.short_name()], "Small", true))
	if me.condition < 90.0:
		wc.add_child(UIKit.label("%s está com %d%% da condição física." % [me.short_name(), int(me.condition)], "Small", true))
	c.add_child(UIKit.card_panel(wc))
	var read := UIKit.card("Card", UITokens.S1)
	read.add_child(UIKit.label("Leitura do técnico", "Section"))
	read.add_child(UIKit.label(PlanEditor.coach_read(me, opp), "", true))
	read.add_child(UIKit.button("Usar o plano do técnico", "GhostButton", func():
		_plan = FightPlan.suggest(me, opp)
		refresh()))
	c.add_child(UIKit.card_panel(read))
	var tape := UIKit.card("Card", UITokens.S1)
	tape.add_child(UIKit.label("Ficha", "Section"))
	tape.add_child(FightKit.tape(w, w.fighter(b.a), w.fighter(b.b)))
	c.add_child(UIKit.card_panel(tape))
	c.add_child(UIKit.section_header("Atributos de %s" % opp.short_name()))
	for x: Control in FightKit.attr_blocks(opp, me):
		c.add_child(x)
	c.add_child(UIKit.section_header("Plano para o 1º round"))
	var pc := UIKit.card("Card", UITokens.S2)
	pc.add_child(PlanEditor.build(_plan, func(): plans[b.id] = _plan.duplicate()))
	c.add_child(UIKit.card_panel(pc))
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
		UIManager.replace("fight", {"bout": b.id}))
	sim.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sim.size_flags_stretch_ratio = 0.6
	row.add_child(sim)
	var go := UIKit.button("Ir para a luta", "PrimaryButton", func():
		plans[b.id] = _plan.duplicate()
		UIManager.replace("fight", {"bout": b.id, "plan": _plan.duplicate()}))
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(go)
	foot.add_child(row)
