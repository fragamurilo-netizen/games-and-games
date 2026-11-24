extends BaseScreen
## Contrato de TV da organização (presidente): o contrato em vigor, a força que a organização
## tem na mesa e, quando o contrato está para acabar, as propostas dos três tipos de parceiro.
## Cada proposta pode ser assinada ou empurrada para cima ("pedir mais"), com risco de o
## parceiro sair da mesa.


func setup(p: Dictionary) -> void:
	super.setup(p)
	show_nav = false
	screen_title = "Contrato de TV"


func refresh() -> void:
	var w := world()
	var c := reset()
	hide_footer()
	if w == null:
		return
	TVDeal.ensure(w)
	screen_subtitle = w.user_team().name
	UIManager.refresh_chrome()
	c.add_child(_current(w))
	c.add_child(_leverage(w))
	if TVDeal.pending(w):
		c.add_child(UIKit.section_header("Propostas na mesa"))
		c.add_child(UIKit.label("Assine uma delas antes de o contrato acabar. O valor fica travado até o fim: contrato longo protege, contrato curto deixa renegociar quando a organização crescer.", "Small", true))
		for o: Dictionary in w.tv_offers.duplicate():
			c.add_child(_offer_card(w, o))
	elif w.tv.has("next"):
		var nx: Dictionary = w.tv["next"]
		var p := TVDeal.partner(String(nx["partner"]))
		var card := UIKit.card("Card", UITokens.S1)
		card.add_child(UIKit.label("Próximo contrato, já assinado", "Section"))
		card.add_child(UIKit.kv(String(p["name"]), String(p["kind"])))
		card.add_child(UIKit.kv("Por Fight Night", Fmt.money(float(nx["fee"])), UIColors.GREEN))
		card.add_child(UIKit.kv("Por evento numerado", Fmt.money(float(nx["fee_ppv"])), UIColors.GREEN))
		card.add_child(UIKit.kv("Vale por", TVDeal.years_text(int(nx["until"]) - int(nx["start"]))))
		c.add_child(UIKit.card_panel(card))
	else:
		c.add_child(UIKit.state_block("empty", "Nenhuma proposta por enquanto", "As propostas chegam %d semanas antes do fim do contrato. Noites quentes e prestígio alto fazem os parceiros pagarem mais." % TVDeal.NOTICE))
	columnize(c, 0, 2)


func _current(w: GameWorld) -> Control:
	var p := TVDeal.partner_of(w)
	var card := UIKit.card("CardHighlight", UITokens.S1)
	card.add_child(UIKit.eyebrow("Contrato em vigor"))
	var head := UIKit.hbox(8)
	var nm := UIKit.label(String(p["name"]), "Section")
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(nm)
	head.add_child(UIKit.label(String(p["kind"]), "Caps"))
	card.add_child(head)
	card.add_child(UIKit.label(String(p["help"]), "Small", true))
	card.add_child(UIKit.kv("Por Fight Night", Fmt.money(float(w.tv.get("fee", 0.0))), UIColors.GREEN))
	card.add_child(UIKit.kv("Por evento numerado", Fmt.money(float(w.tv.get("fee_ppv", 0.0))), UIColors.GREEN))
	card.add_child(UIKit.kv("Pay-per-view", "é da organização" if float(p["ppv_k"]) > 0.0 else "dentro do contrato"))
	var left := TVDeal.weeks_left(w)
	card.add_child(UIKit.kv("Termina", "em %s" % Fmt.plural(left, "semana", "semanas"), UIColors.ORANGE if left <= TVDeal.NOTICE else UIColors.TEXT))
	card.add_child(UIKit.label("Bônus de audiência: %d%% a mais quando a noite passa de %d de hype." % [int(TVDeal.BONUS_K * 100.0), int(TVDeal.BONUS_HYPE)], "Small", true))
	return UIKit.card_panel(card)


func _leverage(w: GameWorld) -> Control:
	var t := w.user_team()
	var lv := TVDeal.leverage(w)
	var card := UIKit.card("Card", UITokens.S1)
	var head := UIKit.hbox(8)
	var tl := UIKit.label("Força na mesa", "Section")
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tl)
	head.add_child(UIKit.colored(TVDeal.leverage_label(lv), UIColors.GREEN if lv >= 0.55 else (UIColors.ORANGE if lv >= 0.4 else UIColors.RED), "H3"))
	card.add_child(head)
	card.add_child(UIKit.bar(lv * 100.0, 100.0, UIColors.ACCENT, 8))
	card.add_child(UIKit.kv("Prestígio da organização", "%d de 100" % int(t.reputation)))
	var au := TVDeal.audience(w)
	var ar := UIKit.hbox(8)
	var al := UIKit.label("Hype médio das últimas noites", "Muted")
	al.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	al.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	ar.add_child(al)
	ar.add_child(EventKit.hype_tag(au, true))
	card.add_child(ar)
	card.add_child(UIKit.label("É com isso que os parceiros fazem a conta. Noites quentes antes da renovação valem dinheiro por anos.", "Small", true))
	return UIKit.card_panel(card)


static func _delta(now: float, was: float) -> String:
	if was <= 0.0:
		return ""
	var d := (now / was - 1.0) * 100.0
	if absf(d) < 0.5:
		return " (igual)"
	return " (%s%d%%)" % ["+" if d > 0.0 else "−", int(round(absf(d)))]


func _offer_card(w: GameWorld, o: Dictionary) -> Control:
	var p := TVDeal.partner(String(o["partner"]))
	var same := String(o["partner"]) == String(w.tv.get("partner", ""))
	var card := UIKit.card("Card", UITokens.S1)
	var head := UIKit.hbox(8)
	var nm := UIKit.label(String(p["name"]), "Section")
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(nm)
	head.add_child(UIKit.label(String(p["kind"]), "Caps"))
	card.add_child(head)
	card.add_child(UIKit.label(String(p["help"]) + (" É o parceiro atual." if same else ""), "Small", true))
	card.add_child(UIKit.kv("Duração", TVDeal.years_text(int(o["weeks"]))))
	var fee := float(o["fee"])
	var fee_ppv := float(o["fee_ppv"])
	card.add_child(UIKit.kv("Por Fight Night", Fmt.money(fee) + _delta(fee, float(w.tv.get("fee", 0.0))), UIColors.GREEN))
	card.add_child(UIKit.kv("Por evento numerado", Fmt.money(fee_ppv) + _delta(fee_ppv, float(w.tv.get("fee_ppv", 0.0))), UIColors.GREEN))
	card.add_child(UIKit.kv("Pay-per-view", "continua seu" if float(p["ppv_k"]) > 0.0 else "entra no contrato"))
	var sk := float(p["sponsor_k"])
	if absf(sk - 1.0) >= 0.02:
		card.add_child(UIKit.kv("Patrocínio", "%s%d%%" % ["+" if sk > 1.0 else "−", int(round(absf(sk - 1.0) * 100.0))], UIColors.GREEN if sk > 1.0 else UIColors.RED))
	var fk := float(p["fame_k"])
	if absf(fk - 1.0) >= 0.02:
		card.add_child(UIKit.kv("Fama dos lutadores", "cresce %d%% %s" % [int(round(absf(fk - 1.0) * 100.0)), "mais rápido" if fk > 1.0 else "mais devagar"], UIColors.GREEN if fk > 1.0 else UIColors.RED))
	card.add_child(UIKit.kv("Garantido por ano (26 noites)", Fmt.money((fee + fee_ppv) * 13.0)))
	var oid := int(o["id"])
	var asked := int(o.get("asks", 0))
	var row := UIKit.flow(8)
	for step: float in TVDeal.ASK_STEPS:
		var ch := TVDeal.ask_chance(w, o, step)
		var st := step
		var b := UIKit.button("Pedir %d%% a mais · chance %s" % [int(round(step * 100.0)), Signing.chance_label(ch).to_lower()], "GhostButton", func():
			var cur := TVDeal.offer(w, oid)
			if cur.is_empty():
				return
			var r := TVDeal.ask(w, cur, st)
			GameManager.save_now()
			UIManager.toast(String(r["text"]), UIColors.GREEN if bool(r["ok"]) else UIColors.RED)
			refresh())
		UIKit.shrink_button(b)
		row.add_child(b)
	card.add_child(row)
	if asked > 0:
		card.add_child(UIKit.colored("Você já pediu mais uma vez. No segundo não, o parceiro sai da mesa.", UIColors.ORANGE, "Small", true))
	card.add_child(UIKit.button("Assinar com a %s" % String(p["name"]), "PrimaryButton", func():
		var cur := TVDeal.offer(w, oid)
		if cur.is_empty():
			return
		UIManager.confirm("Assinar o contrato?", "%s (%s) por %s: %s por Fight Night e %s por evento numerado. O valor fica travado até o fim." % [String(p["name"]), String(p["kind"]).to_lower(), TVDeal.years_text(int(cur["weeks"])), Fmt.money(float(cur["fee"])), Fmt.money(float(cur["fee_ppv"]))], "Assinar", func():
			TVDeal.sign(w, cur)
			GameManager.save_now()
			Sfx.play("sign", -4.0)
			UIManager.toast("Contrato assinado com a %s." % String(p["name"]), UIColors.GREEN)
			refresh())))
	return UIKit.card_panel(card)
