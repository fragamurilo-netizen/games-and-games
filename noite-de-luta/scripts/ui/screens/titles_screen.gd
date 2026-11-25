extends BaseScreen
## Cinturões: o campeão de cada categoria e a linhagem (quem teve o cinturão, quando e contra
## quem). É a página que o fã abre para saber quem manda em cada divisão.


func setup(p: Dictionary) -> void:
	super.setup(p)
	screen_title = "Cinturões"


func refresh() -> void:
	var w := world()
	if w == null:
		return
	screen_subtitle = w.league_name()
	UIManager.refresh_chrome()
	var c := reset()
	c.add_child(UIKit.menu_group([UIKit.menu_row("trophy", "Legado da liga", "", func(): UIManager.push("legacy"))]))
	for d: Dictionary in DataDB.divisions():
		var div := String(d["id"])
		c.add_child(_division(w, div))
	columnize(c, 1, 2)


func _division(w: GameWorld, div: String) -> Control:
	var card := UIKit.card("Card", UITokens.S1)
	var head := UIKit.hbox(8)
	var t := UIKit.label(Matchmaker.division_title(div), "Section")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(t)
	head.add_child(UIKit.label(Fmt.kg(float(DataDB.division(div).get("limit_kg", 0.0))), "Caps"))
	card.add_child(head)
	var champ := w.fighter(int(w.champions.get(div, -1)))
	if champ == null:
		card.add_child(UIKit.colored("Cinturão vago", UIColors.GOLD, "H3"))
	else:
		var cid := champ.id
		var line := "%s · %s" % [champ.record_text(), "%d defesas" % champ.title_defenses if champ.title_defenses != 1 else "1 defesa"]
		card.add_child(FightKit.fighter_row(w, champ, func(): UIManager.push("fighter", {"id": cid}), line, UIColors.GOLD, "Campeão"))
		var b := w.bout(champ.bout_id)
		var it := Titles.interim_of(w, div)
		if b != null and b.status == "marcada" and b.title:
			var ev := w.event(b.event_id)
			var unify := it != null and b.has(it.id)
			card.add_child(UIKit.label("%s %s na %s, %s." % ["Unifica o cinturão contra" if unify else "Defende contra", w.fighter(b.other(champ.id)).display_name(), ev.name if ev != null else "", w.weeks_from_now(b.week)], "Small", true))
		var out := Titles.champion_out(w, div)
		if out != "":
			card.add_child(UIKit.colored("%s." % (out.substr(0, 1).to_upper() + out.substr(1)), UIColors.ORANGE, "Small", true))
		if it != null:
			var iid := it.id
			card.add_child(FightKit.fighter_row(w, it, func(): UIManager.push("fighter", {"id": iid}), "%s · espera a unificação" % it.record_text(), UIColors.GOLD, "Interino"))
		else:
			var ib := Titles.booked(w, div)
			if ib != null and ib.interim:
				var iev := w.event(ib.event_id)
				card.add_child(UIKit.colored("Cinturão interino em jogo: %s × %s na %s, %s." % [w.fighter(ib.a).short_name(), w.fighter(ib.b).short_name(), iev.name if iev != null else "", w.weeks_from_now(ib.week)], UIColors.GOLD, "Small", true))
	var hist: Array = w.title_history.get(div, [])
	if hist.size() > 1 or (hist.size() == 1 and champ == null):
		card.add_child(UIKit.label("Linhagem", "Caps"))
		for i in range(hist.size() - 1, maxi(-1, hist.size() - 7), -1):
			var h: Dictionary = hist[i]
			var txt := "%s · %s" % [String(h.get("name", "")), GameWorld.fight_date_text(int(h.get("week", 0)))]
			var how := String(h.get("how", ""))
			if how != "":
				txt += " · " + how
			var l := UIKit.label(txt, "Small", true)
			var hid := int(h.get("id", -1))
			card.add_child(UIKit.tap_row(l, func(): if w.fighter(hid) != null: UIManager.push("fighter", {"id": hid})))
	return UIKit.card_panel(card)
