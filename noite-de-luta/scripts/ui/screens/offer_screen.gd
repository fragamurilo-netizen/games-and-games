extends BaseScreen
## Proposta de luta: quem, onde, quando, quanto, e a ficha dos dois lado a lado.


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
	screen_subtitle = ev.name
	UIManager.refresh_chrome()
	var card := UIKit.card("CardHighlight", UITokens.S2)
	card.add_child(UIKit.label("%s · %s, %s" % [Rankings.tier_name(ev.tier), ev.city, GameWorld.fight_date_text(ev.week)], "Small"))
	card.add_child(FightKit.faceoff(w, f, opp, 130, false))
	c.add_child(UIKit.card_panel(card))
	var money := UIKit.card("Card", UITokens.S1)
	money.add_child(UIKit.label("Bolsa", "Section"))
	var cut := float(f.contract.get("cut", 0.2))
	money.add_child(UIKit.kv("Para lutar", Fmt.money(float(o["show"]))))
	money.add_child(UIKit.kv("Bônus de vitória", Fmt.money(float(o["win"]))))
	money.add_child(UIKit.kv("Para a academia (%d%%)" % int(round(cut * 100.0)), "%s a %s" % [Fmt.money(float(o["show"]) * cut), Fmt.money((float(o["show"]) + float(o["win"])) * cut)], UIColors.GREEN))
	money.add_child(UIKit.kv("Rounds", "3 de 5 minutos"))
	money.add_child(UIKit.kv("Responder até", w.weeks_from_now(int(o["expires"]))))
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
	var row := UIKit.hbox(UITokens.S2)
	var no := UIKit.button("Recusar", "GhostButton", func():
		w.offers.erase(o)
		GameManager.save_now()
		UIManager.back())
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(no)
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
