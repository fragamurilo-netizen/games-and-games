extends BaseScreen
## A noite de luta da organização, ao lado do octógono: o card na ordem em que as lutas
## acontecem (das preliminares à principal). Cada luta dá para assistir na transmissão ou
## simular. No fim, o presidente escolhe os bônus da noite e vê as contas.


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
	screen_subtitle = "%s · %s" % [ev.city, "pay-per-view" if ev.ppv else "Fight Night"]
	UIManager.refresh_chrome()
	var lst := Org.event_bouts(w, ev)
	var foot := footer()
	UIKit.clear(foot)
	if ev.closed:
		_report(w, ev, c)
		foot.add_child(UIKit.button("Voltar ao início", "PrimaryButton", func(): UIManager.goto("hub")))
		return
	if lst.is_empty():
		c.add_child(UIKit.state_block("empty", "Nenhuma luta no card", "Sem lutas, a noite é cancelada e a organização perde prestígio.", "Cancelar a noite", func():
			Org.close_event(w, ev, {})
			GameManager.save_now()
			refresh()))
		return
	var pending := lst.filter(func(b: Bout) -> bool: return b.status == "marcada")
	c.add_child(UIKit.label("O card na ordem das lutas: das preliminares à principal.", "Muted", true))
	for i in lst.size():
		var b: Bout = lst[i]
		var box := UIKit.vbox(UITokens.S1)
		var label := "Luta principal" if b.main_event else ("Co-principal" if i == lst.size() - 2 else "Luta %d" % (i + 1))
		box.add_child(UIKit.label(label, "Caps"))
		box.add_child(OrgKit.bout_row(w, b, func(): pass))
		if b.status == "marcada":
			var row := UIKit.hbox(UITokens.S2)
			var bid := b.id
			var watch := UIKit.button("Assistir", "GhostButton", func(): UIManager.push("fight", {"bout": bid, "spectator": true}))
			watch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var sim := UIKit.button("Simular", "GhostButton", func():
				Career.simulate(w, w.bout(bid))
				GameManager.save_now()
				refresh())
			sim.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(watch)
			row.add_child(sim)
			box.add_child(row)
		c.add_child(box)
	if not pending.is_empty():
		var next: Bout = pending[0]
		var nid := next.id
		var row2 := UIKit.hbox(UITokens.S2)
		var rest := UIKit.button("Simular as que faltam", "GhostButton", func():
			for b: Bout in pending:
				if b.status == "marcada":
					Career.simulate(w, b)
			GameManager.save_now()
			refresh())
		var go := UIKit.button("Assistir a próxima", "PrimaryButton", func(): UIManager.push("fight", {"bout": nid, "spectator": true}))
		go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row2.add_child(rest)
		row2.add_child(go)
		foot.add_child(row2)
	else:
		foot.add_child(UIKit.button("Fechar a noite", "PrimaryButton", func(): _bonus_sheet(w, ev)))


## Bônus da noite: a luta da noite (os dois lutadores ganham) e duas performances. Vem com a
## sugestão do matchmaker; o presidente troca se quiser.
func _bonus_sheet(w: GameWorld, ev: FightEvent) -> void:
	var sug := Org.auto_bonuses(w, ev)
	var state := {"fotn": int(sug["fotn"]), "potn": (sug["potn"] as Array).duplicate()}
	var v := UIKit.vbox(UITokens.S2)
	v.custom_minimum_size.x = 560
	v.add_child(UIKit.label("Bônus da noite", "Section"))
	v.add_child(UIKit.label("US$ %s mil para cada. Bônus dá fama a quem recebe e mostra que a organização paga bem." % str(int(Org.BONUS / 1000.0)), "Small", true))
	v.add_child(UIKit.label("Luta da noite", "Caps"))
	var g := ButtonGroup.new()
	var fl := UIKit.flow(8)
	for b: Bout in Org.event_bouts(w, ev):
		var bid := b.id
		fl.add_child(UIKit.chip("%s × %s" % [w.fighter(b.a).short_name(), w.fighter(b.b).short_name()], bid == int(state["fotn"]), g, func(): state["fotn"] = bid))
	v.add_child(fl)
	v.add_child(UIKit.label("Performance da noite (até duas)", "Caps"))
	var fl2 := UIKit.flow(8)
	for b: Bout in Org.event_bouts(w, ev):
		var wid := int(b.result.get("winner_id", -1))
		if wid < 0:
			continue
		var f := w.fighter(wid)
		var ch := UIKit.chip(f.short_name(), (state["potn"] as Array).has(wid), null, func(): pass)
		ch.toggled.connect(func(on: bool):
			var lst: Array = state["potn"]
			if on and not lst.has(wid):
				if lst.size() >= 2:
					ch.set_pressed_no_signal(false)
					UIManager.toast("São duas performances por noite.")
					return
				lst.append(wid)
			elif not on:
				lst.erase(wid))
		fl2.add_child(ch)
	v.add_child(fl2)
	v.add_child(UIKit.button("Pagar e fechar a noite", "PrimaryButton", func():
		Org.close_event(w, ev, state)
		GameManager.save_now()
		UIManager.close_modal()
		Sfx.play("achievement", -6.0)
		refresh()))
	UIManager.show_modal(v, true)


func _report(w: GameWorld, ev: FightEvent, c: VBoxContainer) -> void:
	var r := ev.report
	c.add_child(OrgKit.money_card(r, "Contas da noite", ev.ppv))
	var bonus := UIKit.card("Card", UITokens.S1)
	bonus.add_child(UIKit.label("Bônus", "Section"))
	var fb := w.bout(int(r.get("fotn", -1)))
	if fb != null:
		bonus.add_child(UIKit.kv("Luta da noite", "%s × %s" % [w.fighter(fb.a).short_name(), w.fighter(fb.b).short_name()]))
	for fid in r.get("potn", []):
		var f := w.fighter(int(fid))
		if f != null:
			bonus.add_child(UIKit.kv("Performance da noite", f.display_name()))
	if fb == null and (r.get("potn", []) as Array).is_empty():
		bonus.add_child(UIKit.label("Nenhum bônus pago.", "Muted"))
	c.add_child(UIKit.card_panel(bonus))
	c.add_child(UIKit.section_header("Resultados"))
	var ids: Array = Org.event_bouts(w, ev).map(func(b: Bout) -> int: return b.id)
	ids.reverse()
	for bid: int in ids:
		c.add_child(OrgKit.bout_row(w, w.bout(bid)))
	columnize(c, 0, 2, 0)
