extends BaseScreen
## Card de uma noite visto de fora (empresário, fã): o termômetro de hype com os motivos e as
## lutas em blocos, da principal para as preliminares, com o resultado quando já foi. Tocar numa
## luta mostra por que ela vende e leva ao perfil dos dois.


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
	var lst := Card.bouts(w, ev)
	var head := UIKit.card("Card", UITokens.S1)
	var hh := UIKit.hbox(8)
	var tl := UIKit.label(Rankings.tier_name(ev.tier), "Section")
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hh.add_child(tl)
	hh.add_child(UIKit.label(Fmt.plural(lst.size(), "luta", "lutas"), "H3"))
	head.add_child(hh)
	head.add_child(UIKit.label("%s, %s · %s" % [ev.city, DataDB.nation_name(ev.nation), w.weeks_from_now(ev.week)], "Small", true))
	c.add_child(UIKit.card_panel(head))
	if lst.is_empty():
		c.add_child(UIKit.state_block("empty", "Card ainda vazio", "As lutas desta noite ainda não foram anunciadas."))
		return
	if not ev.done and ev.week >= w.week:
		c.add_child(EventKit.thermometer(Hype.event(w, ev)))
	c.add_child(EventKit.card_blocks(w, ev, func(b: Bout): _bout_sheet(w, ev, b)))


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
	if b.status == "marcada":
		v.add_child(EventKit.thermometer(Hype.bout(w, b), "Hype da luta", "", false, 5))
	var rows: Array = []
	for fid: int in [b.a, b.b]:
		var f := w.fighter(fid)
		rows.append(UIKit.menu_row("user", f.display_name(), "%s · %s" % [w.rank_text(f), f.record_text()], func():
			UIManager.close_modal()
			UIManager.push("fighter", {"id": fid})))
	v.add_child(UIKit.menu_group(rows))
	UIManager.show_modal(v, true)
