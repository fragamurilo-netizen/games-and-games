extends BaseScreen
## Proposta de luta (empresário): quem, onde, quando, quanto, em que lugar do card e quanto a
## luta interessa ao público. Dá para aceitar, recusar ou negociar antes: a folha "Negociar"
## mostra a força do lutador na mesa, a paciência da organização e a chance de cada pedido
## (mais dinheiro, outro formato de bolsa, outra data, um lugar melhor no card).


func setup(p: Dictionary) -> void:
	super.setup(p)
	screen_title = "Proposta de luta"
	show_nav = false


func _offer() -> Dictionary:
	for o: Dictionary in world().offers:
		if int(o["id"]) == int(params["id"]):
			return o
	return {}


func refresh() -> void:
	var w := world()
	var c := reset()
	var o := _offer()
	if o.is_empty():
		c.add_child(UIKit.state_block("empty", "Esta proposta não vale mais"))
		return
	var f := w.fighter(int(o["fighter"]))
	var opp := w.fighter(int(o["opp"]))
	var ev := w.event(int(o["event"]))
	var title := bool(o.get("title", false))
	var interim := bool(o.get("interim", false))
	var slot := Negotiation.slot_of(w, o)
	screen_subtitle = ev.name
	UIManager.refresh_chrome()
	var card := UIKit.card("CardHighlight", UITokens.S2)
	card.add_child(UIKit.label("%s · %s, %s" % [Rankings.tier_name(ev.tier), ev.city, GameWorld.fight_date_text(ev.week)], "Small"))
	card.add_child(FightKit.faceoff(w, f, opp, 130, false))
	if title:
		var it := Titles.interim_of(w, f.division)
		var unify := it != null and (it.id == f.id or it.id == opp.id) and int(w.champions.get(f.division, -1)) >= 0
		card.add_child(UIKit.colored("%s dos %s" % ["Unificação do cinturão" if unify else "Valendo o cinturão", Matchmaker.division_name(f.division, true)], UIColors.GOLD, "H3", true))
	elif interim:
		card.add_child(UIKit.colored("Valendo o cinturão interino dos %s" % Matchmaker.division_name(f.division, true), UIColors.GOLD, "H3", true))
		var out := Titles.champion_out(w, f.division)
		if out != "":
			card.add_child(UIKit.label("%s. Quem vencer enfrenta o campeão na volta." % (out.substr(0, 1).to_upper() + out.substr(1)), "Small", true))
	card.add_child(UIKit.kv("Lugar no card", Card.slot_name(slot)))
	var kf := Card.fame_k(slot)
	if kf > 1.01:
		card.add_child(UIKit.label("Mais gente vê: a fama de quem vence cresce %d%% a mais." % int(round((kf - 1.0) * 100.0)), "Small", true))
	elif kf < 0.99:
		card.add_child(UIKit.label("Nas preliminares pouca gente vê: a fama cresce %d%% a menos." % int(round((1.0 - kf) * 100.0)), "Small", true))
	if not title and not interim and Matchmaker.shot_promised(w, f):
		card.add_child(UIKit.colored("A liga sinalizou a próxima disputa de cinturão para %s. Aceitar esta luta tira a vez %s." % [f.short_name(), "dela" if f.is_female() else "dele"], UIColors.GOLD, "Small", true))
	c.add_child(UIKit.card_panel(card))
	c.add_child(EventKit.thermometer(Hype.pair(w, f, opp, title, interim, ev.nation), "Hype da luta", "Luta quente paga melhor e dá força para negociar.", true, 5))
	var money := UIKit.card("Card", UITokens.S1)
	money.add_child(UIKit.label("Bolsa", "Section"))
	var cut := float(f.contract.get("cut", 0.2))
	money.add_child(UIKit.kv("Para lutar", Fmt.money(float(o["show"]))))
	money.add_child(UIKit.kv("Bônus de vitória", Fmt.money(float(o["win"]))))
	money.add_child(UIKit.kv("Para a academia (%d%%)" % int(round(cut * 100.0)), "%s a %s" % [Fmt.money(float(o["show"]) * cut), Fmt.money((float(o["show"]) + float(o["win"])) * cut)], UIColors.GREEN))
	var five := title or interim or (slot == "principal" and ev.tier == 2)
	money.add_child(UIKit.kv("Rounds", "%d de 5 minutos" % (5 if five else 3)))
	money.add_child(UIKit.kv("Responder até", w.weeks_from_now(int(o["expires"]))))
	# Quanto de camp dá para fazer até lá (o camp completo são oito semanas).
	var camp_w := clampi(int(o["week"]) - w.week, 0, Camp.WEEKS)
	money.add_child(UIKit.kv("Tempo de camp", "%s de %d" % [Fmt.plural(camp_w, "semana", "semanas"), Camp.WEEKS], UIColors.ORANGE if camp_w <= 3 else UIColors.TEXT))
	if camp_w <= 3:
		money.add_child(UIKit.label("Luta em cima da hora: %s chega com pouco camp." % f.short_name(), "Small", true))
	var asked: Array = o.get("asked", [])
	if not asked.is_empty():
		var names := {"bolsa": "o valor", "formato": "o formato da bolsa", "data": "a data", "card": "o lugar no card"}
		money.add_child(UIKit.colored("Já negociado: %s." % ", ".join(asked.map(func(g: String) -> String: return String(names.get(g, g)))), UIColors.MUTED, "Small", true))
	c.add_child(UIKit.card_panel(money))
	var tape := UIKit.card("Card", UITokens.S1)
	tape.add_child(UIKit.label("Ficha", "Section"))
	tape.add_child(FightKit.tape(w, f, opp))
	c.add_child(UIKit.card_panel(tape))
	c.add_child(UIKit.section_header("Atributos de %s" % opp.short_name()))
	for x: Control in FightKit.attr_blocks(opp, f):
		c.add_child(x)
	c.add_child(UIKit.label("Os números verdes e vermelhos são a diferença para %s." % f.short_name(), "Small", true))
	columnize(c, 1, 2, 1)
	var foot := footer()
	var row := UIKit.hbox(UITokens.S1)
	var no := UIKit.button("Recusar", "GhostButton", func():
		w.offers.erase(o)
		GameManager.save_now()
		UIManager.back())
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(no)
	var neg := UIKit.button("Negociar", "GhostButton", func(): _negotiate(w, o))
	neg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	neg.disabled = Negotiation.patience(o) <= 0
	row.add_child(neg)
	var yes := UIKit.button("Aceitar", "PrimaryButton", func():
		var err := Matchmaker.accept_offer(w, o)
		if err != "":
			UIManager.toast(err, UIColors.RED)
		else:
			Sfx.play("sign", -4.0)
			UIManager.toast("Luta fechada: %s × %s." % [f.short_name(), opp.short_name()], UIColors.GREEN)
		GameManager.save_now()
		UIManager.back())
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(yes)
	foot.add_child(row)


## Folha de negociação: a força na mesa com os motivos, a paciência que resta e cada pedido com
## a chance de ser aceito.
func _negotiate(w: GameWorld, o: Dictionary) -> void:
	var f := w.fighter(int(o["fighter"]))
	var lev := Negotiation.leverage(w, o)
	var lv := float(lev["value"])
	var v := UIKit.vbox(UITokens.S2)
	v.custom_minimum_size.x = 560
	var head := UIKit.hbox(8)
	var tl := UIKit.vbox(0)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tl.add_child(UIKit.eyebrow("Força de %s na mesa" % f.short_name()))
	var col := UIColors.GREEN if lv >= 0.18 else (UIColors.ORANGE if lv >= 0.02 else UIColors.RED)
	tl.add_child(UIKit.colored(Negotiation.leverage_label(lv).capitalize(), col, "Section"))
	head.add_child(tl)
	var pat := Negotiation.patience(o)
	var pl := UIKit.vbox(0)
	var pn := UIKit.label(str(pat), "Section")
	pn.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pl.add_child(pn)
	var pc := UIKit.label("paciência", "Caps")
	pc.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pl.add_child(pc)
	head.add_child(pl)
	v.add_child(head)
	var rs: Array = []
	for r: Array in lev["reasons"]:
		rs.append([String(r[0]), float(r[1]) * 100.0])
	EventKit.reasons(v, rs)
	v.add_child(UIKit.label("Cada pedido recusado gasta a paciência da organização. No zero, ou num dia ruim, ela retira a proposta e chama outro lutador. Cada assunto só pode ser pedido uma vez.", "Small", true))
	var rows: Array = []
	for key: String in Negotiation.ORDER:
		var a: Dictionary = Negotiation.ASKS[key]
		var why := Negotiation.block_reason(w, o, key)
		var sub := String(a["help"])
		if key == "data":
			var e := Negotiation.later_event(w, o)
			if e != null:
				sub = "Passa para a %s, %s." % [e.name, GameWorld.fight_date_text(e.week)]
		elif key == "card" and why == "":
			sub = "Hoje: %s. %s" % [Card.slot_name(Negotiation.slot_of(w, o)).to_lower(), sub]
		var p := Negotiation.chance(w, o, key)
		rows.append(_ask_row(String(a["name"]), why if why != "" else sub, Signing.chance_label(p) if why == "" else "", p, why != "", func():
			UIManager.close_modal()
			var r := Negotiation.ask(w, o, key)
			GameManager.save_now()
			if bool(r["gone"]):
				UIManager.info("Proposta retirada", String(r["text"]))
				UIManager.back()
				return
			if bool(r["ok"]):
				Sfx.play("sign", -6.0)
			UIManager.toast(String(r["text"]), UIColors.GREEN if bool(r["ok"]) else UIColors.RED)
			refresh()))
	v.add_child(UIKit.menu_group(rows))
	UIManager.show_modal(v, true)


func _ask_row(title: String, sub: String, chance: String, p: float, blocked: bool, cb: Callable) -> PanelContainer:
	var h := UIKit.hbox(12)
	var tv := UIKit.vbox(0)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_child(UIKit.label(title))
	var s := UIKit.label(sub, "Small", true)
	s.add_theme_color_override(&"font_color", UIColors.MUTED)
	tv.add_child(s)
	h.add_child(tv)
	if chance != "":
		var cl := UIKit.colored(chance, UIColors.GREEN if p >= 0.5 else (UIColors.ORANGE if p >= 0.3 else UIColors.RED), "Caps")
		cl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(cl)
	var row := UIKit.tap_row(h, cb if not blocked else Callable())
	if blocked:
		row.modulate.a = 0.55
	return row
