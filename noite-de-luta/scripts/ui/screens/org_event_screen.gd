extends BaseScreen
## Montagem de uma noite da liga, do ponto de vista do presidente: o termômetro de hype com os
## motivos, a sede e os ingressos, a previsão das contas e o card em blocos (luta principal,
## co-principal, card principal e preliminares). Tocar numa luta abre a ficha dela: por que ela
## vende, subir ou descer no card, virar a luta principal, tirar do card.
## Depois da noite, os resultados e o fechamento.


func setup(p: Dictionary) -> void:
	super.setup(p)
	show_nav = false


func refresh() -> void:
	var w := world()
	var ev := w.event(int(params["id"]))
	var c := reset()
	if ev == null:
		c.add_child(UIKit.state_block("empty", "Evento não encontrado"))
		return
	screen_title = ev.name
	screen_subtitle = "%s · %s" % [ev.city, GameWorld.fight_date_text(ev.week)]
	UIManager.refresh_chrome()
	var lst := Org.event_bouts(w, ev)
	var open := not (ev.closed or ev.done)
	var head := UIKit.card("CardHighlight" if ev.ppv else "Card", UITokens.S1)
	var hh := UIKit.hbox(8)
	var tl := UIKit.label("Evento numerado" if ev.ppv else "Fight Night", "Section")
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hh.add_child(tl)
	hh.add_child(UIKit.label("%d de %d lutas" % [lst.size(), ev.slots], "H3"))
	head.add_child(hh)
	head.add_child(UIKit.label("%s, %s · %s · %s" % [ev.city, DataDB.nation_name(ev.nation), Venue.type_name(ev).to_lower(), w.weeks_from_now(ev.week)], "Small", true))
	c.add_child(UIKit.card_panel(head))
	if ev.closed:
		var hv := float(ev.report.get("draw", 0.0))
		var hc := UIKit.card("Card", UITokens.S1)
		var hr := UIKit.hbox(8)
		var hl := UIKit.label("Hype da noite", "Section")
		hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hr.add_child(hl)
		hr.add_child(EventKit.hype_tag(hv, true))
		hc.add_child(hr)
		var hb := HeatBar.new()
		hb.value = hv
		hc.add_child(hb)
		c.add_child(UIKit.card_panel(hc))
		c.add_child(OrgKit.money_card(ev.report, "Contas da noite", ev.ppv))
	elif open:
		var pr := Org.projection(w, ev)
		var note := ""
		if lst.is_empty():
			note = "Comece pela luta principal: ela é quase todo o hype da noite."
		c.add_child(EventKit.thermometer(Hype.event(w, ev), "Termômetro da noite", note))
		c.add_child(EventKit.venue_card(w, ev, pr, func(): UIManager.push("venue", {"id": ev.id})))
		c.add_child(OrgKit.money_card(pr, "Previsão das contas", ev.ppv))
	var cardbox := UIKit.vbox(UITokens.S2)
	if lst.is_empty():
		cardbox.add_child(UIKit.section_header("Card"))
		cardbox.add_child(UIKit.state_block("empty", "Card vazio", "Comece pela luta principal: a mais vendável que você conseguir fechar."))
	else:
		cardbox.add_child(EventKit.card_blocks(w, ev, func(b: Bout): _bout_sheet(w, ev, b)))
		if open and ev.manual:
			cardbox.add_child(UIKit.button("Deixar a organização ordenar o card", "GhostButton", func():
				ev.manual = false
				Card.sort(w, ev, true)
				Card.ensure_main(w, ev)
				GameManager.save_now()
				refresh()))
	c.add_child(cardbox)
	columnize(c, 1, 2)
	var foot := footer()
	UIKit.clear(foot)
	if not open:
		foot.add_child(UIKit.button("Voltar", "GhostButton", func(): UIManager.back()))
		return
	if ev.week == w.week:
		foot.add_child(UIKit.button("Ir para a noite de luta", "PrimaryButton", func(): UIManager.push("night", {"id": ev.id})))
		return
	var row := UIKit.hbox(UITokens.S2)
	var full := lst.size() >= ev.slots
	var add := UIKit.button("Adicionar luta", "PrimaryButton", func(): UIManager.push("book", {"event": ev.id}))
	add.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add.disabled = full
	var auto := UIKit.button("Completar", "GhostButton", func():
		var n := Org.auto_fill(w, ev)
		GameManager.save_now()
		UIManager.toast("O matchmaker fechou %s." % Fmt.plural(n, "luta", "lutas") if n > 0 else "Ninguém disponível para completar o card.")
		refresh())
	auto.disabled = full
	row.add_child(auto)
	row.add_child(add)
	foot.add_child(row)
	TutorialKit.tip(self, "org_event")
	Tutorial.mark(world(), "org_event")


## Ficha da luta: por que ela vende, as bolsas e o que dá para fazer com ela no card.
func _bout_sheet(w: GameWorld, ev: FightEvent, b: Bout) -> void:
	var fa := w.fighter(b.a)
	var fb := w.fighter(b.b)
	var v := UIKit.vbox(UITokens.S2)
	v.custom_minimum_size.x = 560
	var head := UIKit.hbox(8)
	var nm := UIKit.label("%s × %s" % [fa.short_name(), fb.short_name()], "Section")
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(nm)
	head.add_child(UIKit.label(Card.slot_name(Card.slot(w, ev, b)), "Caps"))
	v.add_child(head)
	var open := b.status == "marcada" and not ev.done and not ev.closed
	if open:
		v.add_child(EventKit.thermometer(Hype.bout(w, b), "Hype da luta", "", false, 5))
	v.add_child(UIKit.label("Bolsas: %s (+%s) e %s (+%s)" % [Fmt.money(float(b.purse_a["show"])), Fmt.money(float(b.purse_a["win"])), Fmt.money(float(b.purse_b["show"])), Fmt.money(float(b.purse_b["win"]))], "Small", true))
	var rows: Array = []
	if open and ev.week > w.week:
		var lst := Card.bouts(w, ev)
		var i := lst.find(b)
		var top := lst.size() - 1
		if i >= 0 and i < top:
			rows.append(UIKit.menu_row("trophy", "Tornar a luta principal", "Vai para o topo do card, em cinco rounds", func(): _reorder(w, ev, Card.set_main(w, ev, b))))
			if i < top - 1:
				rows.append(UIKit.menu_row("up", "Subir no card", "Mais gente vê: a fama de quem vence cresce mais", func(): _reorder(w, ev, Card.move(w, ev, b, 1))))
		if i > 0:
			rows.append(UIKit.menu_row("down", "Descer no card", "Abre espaço para outra luta mais acima", func(): _reorder(w, ev, Card.move(w, ev, b, -1))))
	for fid: int in [b.a, b.b]:
		var f := w.fighter(fid)
		rows.append(UIKit.menu_row("user", f.display_name(), "%s · %s" % [w.rank_text(f), f.record_text()], func():
			UIManager.close_modal()
			UIManager.push("fighter", {"id": fid})))
	if open:
		rows.append(UIKit.menu_row("close", "Tirar do card", "As equipes não gostam: a organização perde um pouco de prestígio", func():
			UIManager.close_modal()
			UIManager.confirm("Tirar a luta do card?", "%s × %s sai da %s." % [fa.short_name(), fb.short_name(), ev.name], "Remover", func():
				Org.cancel(w, b)
				GameManager.save_now()
				refresh())))
	v.add_child(UIKit.menu_group(rows))
	UIManager.show_modal(v, true)


func _reorder(_w: GameWorld, _ev: FightEvent, why: String) -> void:
	UIManager.close_modal()
	if why != "":
		UIManager.toast(why, UIColors.RED)
		return
	GameManager.save_now()
	Sfx.play("tab", -6.0)
	refresh()
