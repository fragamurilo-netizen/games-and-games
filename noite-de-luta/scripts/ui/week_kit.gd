class_name WeekKit
extends RefCounted
## Peças da vida de presidente: os imprevistos da semana da luta (cartão no Início e na noite,
## folha de decisão) e a coletiva de imprensa depois da noite. As regras estão em FightWeek.


## Cartões dos imprevistos que esperam decisão (todos, ou só os de uma noite).
static func incidents_section(w: GameWorld, c: VBoxContainer, ev: FightEvent, on_change: Callable) -> int:
	var lst := FightWeek.pending(w, ev)
	if lst.is_empty():
		return 0
	c.add_child(UIKit.section_header("Problemas da semana"))
	for i: Dictionary in lst:
		c.add_child(incident_card(w, i, on_change))
	return lst.size()


static func incident_card(w: GameWorld, i: Dictionary, on_change: Callable) -> PanelContainer:
	var card := UIKit.card("CardHighlight", UITokens.S1)
	var ev := w.event(int(i["event"]))
	var kind := "Lesão" if String(i["kind"]) == "lesao" else "Balança"
	card.add_child(UIKit.colored("%s · %s" % [kind, ev.name], UIColors.RED, "Caps"))
	card.add_child(UIKit.label(FightWeek.incident_title(w, i), "H3", true))
	card.add_child(FightKit.faceoff(w, w.fighter(int(i["fighter"])), w.fighter(int(i["opp"])), 72))
	card.add_child(UIKit.label(FightWeek.incident_text(w, i), "Small", true))
	card.add_child(UIKit.button("Decidir", "PrimaryButton", func(): open_incident(w, i, on_change)))
	return UIKit.card_panel(card)


## Folha de decisão de um imprevisto. Fecha sozinha quando ele é resolvido.
static func open_incident(w: GameWorld, i: Dictionary, on_change: Callable) -> void:
	var v := UIKit.vbox(UITokens.S2)
	v.custom_minimum_size.x = 560
	v.add_child(UIKit.label(FightWeek.incident_title(w, i), "Section", true))
	v.add_child(UIKit.label(FightWeek.incident_text(w, i), "Small", true))
	var b := w.bout(int(i["bout"]))
	var opp := w.fighter(int(i["opp"]))
	var after := func(r: Dictionary) -> void:
		UIManager.toast(String(r["text"]), UIColors.GREEN if bool(r["ok"]) else UIColors.RED)
		GameManager.save_now()
		UIManager.close_modal()
		if not bool(i.get("done", false)):
			open_incident(w, i, on_change)
		on_change.call()
	if String(i["kind"]) == "lesao":
		v.add_child(UIKit.label("Substituto em cima da hora", "Caps"))
		var subs := FightWeek.substitutes(w, i)
		if subs.is_empty():
			v.add_child(UIKit.label("Ninguém livre e em forma nessa categoria para aceitar agora.", "Muted", true))
		for s: Fighter in subs:
			var ch := FightWeek.sub_chances(w, i, s)
			var p := int(round(float(ch[0]) * float(ch[1]) * 100.0))
			var row := UIKit.hbox(UITokens.S2)
			row.add_child(FightKit.portrait(w, s, 56))
			var tv := UIKit.vbox(0)
			tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var nm := UIKit.label(s.display_name(), "H3")
			nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			tv.add_child(nm)
			tv.add_child(UIKit.label("%s · %s · chance de fechar ~%d%%" % [w.rank_text(s), s.record_text(), p], "Small", true))
			tv.add_child(UIKit.label("Prêmio por aceitar: %s" % Fmt.money(FightWeek.sub_bonus(w, b, s)), "Small"))
			row.add_child(tv)
			var sid := s.id
			var btn := UIKit.button("Oferecer", "GhostButton", func(): after.call(FightWeek.offer_sub(w, i, w.fighter(sid))))
			btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(btn)
			v.add_child(row)
		v.add_child(UIKit.label("Tirar a luta do card", "Caps"))
		var show := float(b.purse_of(opp.id)["show"])
		v.add_child(UIKit.button("Cancelar e pagar a bolsa de %s (%s)" % [opp.short_name(), Fmt.money(show)], "GhostButton", func(): after.call(FightWeek.cancel_injury(w, i, true))))
		v.add_child(UIKit.button("Cancelar sem pagar (a organização perde prestígio)", "GhostButton", func(): after.call(FightWeek.cancel_injury(w, i, false))))
	else:
		var fine := FightWeek.fine_of(w, i)
		var c1 := int(round(FightWeek.catch_chance(w, i, false) * 100.0))
		var c2 := int(round(FightWeek.catch_chance(w, i, true) * 100.0))
		v.add_child(UIKit.label("%s da bolsa de %s vai para %s em qualquer luta em peso combinado." % [Fmt.money(fine), w.fighter(int(i["fighter"])).short_name(), opp.short_name()], "Small", true))
		if not bool(i.get("asked", false)):
			v.add_child(UIKit.button("Peso combinado (~%d%% de %s aceitar)" % [c1, opp.short_name()], "GhostButton", func(): after.call(FightWeek.catchweight(w, i, false))))
		if (i.get("refused", []) as Array).is_empty():
			v.add_child(UIKit.button("Peso combinado + extra de %s (~%d%%)" % [Fmt.money(FightWeek.catch_extra(w, i)), c2], "GhostButton", func(): after.call(FightWeek.catchweight(w, i, true))))
		v.add_child(UIKit.button("Cancelar a luta (a organização paga metade da bolsa de %s)" % opp.short_name(), "GhostButton", func(): after.call(FightWeek.cancel_weight(w, i))))
	for n in v.get_children():
		if n is Button:
			(n as Button).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UIManager.show_modal(v, true)


## Coletiva de imprensa depois da noite: as falas escolhidas (com o que deu) e as que faltam.
static func presser_section(w: GameWorld, ev: FightEvent, c: VBoxContainer, on_change: Callable) -> void:
	var card := UIKit.card("Card", UITokens.S1)
	card.add_child(UIKit.label("Coletiva de imprensa", "Section"))
	var said: Array = ev.report.get("presser", [])
	if not said.is_empty():
		card.add_child(UIKit.label("O que você disse", "Caps"))
	for s: Dictionary in said:
		card.add_child(UIKit.label(String(s["title"]), "H3", true))
		card.add_child(UIKit.label(String(s["result"]), "Small", true))
	if FightWeek.presser_done(ev):
		if said.is_empty():
			card.add_child(UIKit.label("O presidente saiu sem falar com a imprensa.", "Muted", true))
		c.add_child(UIKit.card_panel(card))
		return
	var keys: Array = said.map(func(s: Dictionary) -> String: return String(s["key"]))
	var opts := FightWeek.presser_options(w, ev).filter(func(o: Dictionary) -> bool: return not keys.has(String(o["key"])))
	card.add_child(UIKit.label("Outras falas" if not said.is_empty() else "Falas", "Caps"))
	card.add_child(UIKit.label("Escolha até %d falas. Cada uma vira manchete, e algumas custam caro." % FightWeek.PRESSER_PICKS, "Muted", true))
	for o: Dictionary in opts:
		var box := UIKit.vbox(2)
		box.add_child(UIKit.label(String(o["title"]) + ("  ·  " + Fmt.money(float(o["cost"])) if float(o["cost"]) > 0.0 else ""), "H3", true))
		box.add_child(UIKit.label(String(o["text"]), "Small", true))
		var oo := o
		card.add_child(UIKit.tap_row(box, func():
			var res := FightWeek.presser_pick(w, ev, oo)
			UIManager.toast(res)
			GameManager.save_now()
			on_change.call()))
	card.add_child(UIKit.button("Encerrar a coletiva", "GhostButton", func():
		ev.report["presser_closed"] = true
		GameManager.save_now()
		on_change.call()))
	c.add_child(UIKit.card_panel(card))
