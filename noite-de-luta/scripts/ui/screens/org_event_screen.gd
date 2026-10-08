extends BaseScreen
## Card de uma noite da liga, do ponto de vista do presidente: as lutas da principal para a
## primeira, a previsão das contas, adicionar luta, tirar luta e deixar o matchmaker completar.
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
	var head := UIKit.card("CardHighlight" if ev.ppv else "Card", UITokens.S1)
	var hh := UIKit.hbox(8)
	var tl := UIKit.label("Pay-per-view" if ev.ppv else "Fight Night", "Section")
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hh.add_child(tl)
	hh.add_child(UIKit.label("%d de %d lutas" % [lst.size(), ev.slots], "H3"))
	head.add_child(hh)
	head.add_child(UIKit.label("%s, %s · %s" % [ev.city, DataDB.nation_name(ev.nation), w.weeks_from_now(ev.week)], "Small"))
	head.add_child(UIKit.kv("Arena", "%s lugares" % Fmt.thousands(Org.capacity(ev.city))))
	c.add_child(UIKit.card_panel(head))
	if ev.closed:
		c.add_child(OrgKit.money_card(ev.report, "Contas da noite", ev.ppv))
	else:
		var pr := Org.projection(w, ev)
		var pc := UIKit.card("Card", UITokens.S1)
		pc.add_child(UIKit.label("Previsão", "Section"))
		pc.add_child(UIKit.kv("Apelo da noite", "%d de 100" % int(pr["draw"])))
		pc.add_child(UIKit.kv("Público esperado", Fmt.thousands(int(pr["crowd"]))))
		if ev.ppv:
			pc.add_child(UIKit.kv("Compras de pay-per-view", Fmt.thousands(int(pr["ppv_buys"]))))
		pc.add_child(UIKit.kv("Bolsas (com metade dos bônus de vitória)", Fmt.money(-float(pr["purses"])), UIColors.RED))
		var pf := float(pr["profit"])
		pc.add_child(UIKit.kv("Resultado previsto", Fmt.money(pf), UIColors.GREEN if pf >= 0.0 else UIColors.RED))
		pc.add_child(UIKit.label("A luta principal vende a noite. Estrelas e cinturão enchem a arena e o pay-per-view.", "Small", true))
		c.add_child(UIKit.card_panel(pc))
	c.add_child(UIKit.section_header("Card"))
	if lst.is_empty():
		c.add_child(UIKit.state_block("empty", "Card vazio", "Comece pela luta principal: a mais vendável que você conseguir fechar."))
	var ids: Array = lst.map(func(b: Bout) -> int: return b.id)
	ids.reverse()
	for bid: int in ids:
		var b := w.bout(bid)
		c.add_child(OrgKit.bout_row(w, b, func(): _bout_sheet(w, ev, b)))
	columnize(c, 2, 2)
	var foot := footer()
	UIKit.clear(foot)
	if ev.closed or ev.done:
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


func _bout_sheet(w: GameWorld, ev: FightEvent, b: Bout) -> void:
	var v := UIKit.vbox(UITokens.S2)
	v.add_child(UIKit.label("%s × %s" % [w.fighter(b.a).short_name(), w.fighter(b.b).short_name()], "Section"))
	v.add_child(UIKit.label("Bolsas: %s (+%s) e %s (+%s)" % [Fmt.money(float(b.purse_a["show"])), Fmt.money(float(b.purse_a["win"])), Fmt.money(float(b.purse_b["show"])), Fmt.money(float(b.purse_b["win"]))], "Small", true))
	var rows: Array = []
	for fid: int in [b.a, b.b]:
		var f := w.fighter(fid)
		rows.append(UIKit.menu_row("user", f.display_name(), "%s · %s" % [w.rank_text(f), f.record_text()], func():
			UIManager.close_modal()
			UIManager.push("fighter", {"id": fid})))
	if b.status == "marcada" and not ev.done:
		rows.append(UIKit.menu_row("close", "Tirar do card", "As equipes não gostam: a organização perde um pouco de prestígio", func():
			UIManager.close_modal()
			UIManager.confirm("Tirar a luta do card?", "%s × %s sai da %s." % [w.fighter(b.a).short_name(), w.fighter(b.b).short_name(), ev.name], "Remover", func():
				Org.cancel(w, b)
				GameManager.save_now()
				refresh())))
	v.add_child(UIKit.menu_group(rows))
	UIManager.show_modal(v, true)
