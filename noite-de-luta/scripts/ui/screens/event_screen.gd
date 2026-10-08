extends BaseScreen
## Card de uma noite: as lutas da principal para a primeira, com resultado quando já foi.


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
	c.add_child(UIKit.label(Rankings.tier_name(ev.tier), "Caps"))
	var ids: Array = ev.bouts.duplicate()
	ids.reverse()
	for bid: int in ids:
		var b := w.bout(bid)
		if b == null:
			continue
		var fa := w.fighter(b.a)
		var fb := w.fighter(b.b)
		var card := UIKit.card("CardHighlight" if (w.is_user_fighter(fa) or w.is_user_fighter(fb)) else "Card", UITokens.S1)
		var cap := ("Luta principal · " if b.main_event else "") + ("Cinturão · " if b.title else "") + Matchmaker.division_short(b.division)
		card.add_child(UIKit.label(cap, "Caps"))
		for i in 2:
			var f := fa if i == 0 else fb
			var h := UIKit.hbox(UITokens.S2)
			var bar := ColorRect.new()
			bar.color = UIColors.CORNER_RED if i == 0 else UIColors.CORNER_BLUE
			bar.custom_minimum_size = Vector2(4, 48)
			h.add_child(bar)
			h.add_child(FightKit.portrait(w, f, 48))
			var n := UIKit.label(f.display_name(), "H3")
			n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			h.add_child(n)
			var won := b.status == "feita" and int(b.result.get("winner_id", -1)) == f.id
			if won:
				h.add_child(UIKit.colored("Venceu", UIColors.GREEN, "Caps"))
			h.add_child(UIKit.label(w.rank_text(f), "Caps"))
			card.add_child(h)
		if b.status == "feita":
			var rt := FightKit.result_text(b)
			if String(b.result.get("method", "")) == "DEC":
				rt += " (%s)" % FightKit.cards_text(b)
			card.add_child(UIKit.label(rt, "Small", true))
		c.add_child(UIKit.card_panel(card))
