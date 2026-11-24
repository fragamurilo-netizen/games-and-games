extends BaseScreen
## Sede e ingressos de uma noite da organização (presidente): em que cidade, em que tipo de
## arena e a que preço. Cada escolha mostra a conta na hora: quanta gente quer ir, quanta cabe,
## a bilheteria e o resultado previsto da noite. A sede e a arena travam quando os ingressos vão
## à venda (três semanas antes); o preço pode mudar até a semana da luta.


func setup(p: Dictionary) -> void:
	super.setup(p)
	show_nav = false


func refresh() -> void:
	var w := world()
	var ev := w.event(int(params["id"]))
	var c := reset()
	hide_footer()
	if ev == null:
		c.add_child(UIKit.state_block("empty", "Evento não encontrado"))
		return
	screen_title = "Sede e ingressos"
	screen_subtitle = "%s · %s" % [ev.name, GameWorld.fight_date_text(ev.week)]
	UIManager.refresh_chrome()
	var pr := Org.projection(w, ev)
	var locked := Venue.locked(w, ev)
	var frozen := ev.done or ev.closed or ev.week <= w.week
	c.add_child(_summary(w, ev, pr, locked, frozen))
	c.add_child(_ticket_card(w, ev, frozen))
	c.add_child(_arena_card(w, ev, locked))
	var cities := UIKit.vbox(UITokens.S2)
	cities.add_child(UIKit.section_header("Sede"))
	cities.add_child(UIKit.label("Cada cidade com a conta desta noite: mercado, poder de compra, lutadores da casa no card e quantas vezes a liga passou por lá." if not locked else "Os ingressos já estão à venda: a sede não muda mais.", "Small", true))
	var rows: Array = []
	for it: Array in Venue.cities():
		var city := String(it[0])
		var nation := String(it[1])
		var p2 := Venue.preview(w, ev, city, nation, ev.venue, ev.ticket)
		rows.append([float(p2["profit"]), city, nation, p2])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	for r: Array in rows:
		cities.add_child(_city_row(w, ev, String(r[1]), String(r[2]), r[3], locked))
	c.add_child(cities)
	columnize(c, 1, 2)


func _summary(w: GameWorld, ev: FightEvent, pr: Dictionary, locked: bool, frozen: bool) -> Control:
	var card := UIKit.card("CardHighlight", UITokens.S1)
	var head := UIKit.hbox(8)
	var t := UIKit.label("%s, %s" % [ev.city, DataDB.nation_name(ev.nation)], "Section")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(t)
	head.add_child(EventKit.hype_tag(float(pr["draw"]), true))
	card.add_child(head)
	var cap := int(pr["capacity"])
	var want := int(pr["demand"])
	var crowd := int(pr["crowd"])
	var tiles := UIKit.hbox(0)
	tiles.add_child(UIKit.stat_tile(Fmt.thousands(want), "Querem ir", UIColors.GREEN if want >= cap else (UIColors.ORANGE if want >= cap * 0.75 else UIColors.RED)))
	tiles.add_child(UIKit.stat_tile(Fmt.thousands(cap), "Lugares"))
	tiles.add_child(UIKit.stat_tile(Fmt.money(float(pr["ticket"])), "Ingresso"))
	card.add_child(tiles)
	card.add_child(UIKit.bar(float(crowd), float(maxi(1, cap)), UIColors.GREEN if crowd >= cap * 0.98 else (UIColors.ORANGE if crowd >= cap * 0.75 else UIColors.RED), 10))
	var note := Venue.fill_text(ev, crowd)
	if want > cap * 1.5:
		note = "Casa cheia com folga: %s ficam de fora. Cabe um lugar maior ou um ingresso mais caro." % Fmt.thousands(want - cap)
	elif crowd >= cap * 0.98:
		note = "Casa cheia: dá prestígio para a organização."
	card.add_child(UIKit.label(note, "Small", true))
	card.add_child(UIKit.kv("Bilheteria", Fmt.money(float(pr["gate"])), UIColors.GREEN))
	card.add_child(UIKit.kv("Aluguel e produção", Fmt.money(-float(pr["production"])), UIColors.RED))
	var pf := float(pr["profit"])
	card.add_child(UIKit.kv("Resultado previsto da noite", Fmt.money(pf), UIColors.GREEN if pf >= 0.0 else UIColors.RED))
	var facts := Venue.crowd_factors(w, ev)
	if not facts.is_empty():
		card.add_child(UIKit.separator())
		card.add_child(UIKit.eyebrow("O que mexe com a procura aqui"))
		var rs: Array = []
		for f: Array in facts:
			rs.append([String(f[0]), float(f[1]) * 100.0])
		for r: Array in rs:
			var k := float(r[1])
			var hr := UIKit.hbox(10)
			var l := UIKit.label(String(r[0]), "Small", true)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hr.add_child(l)
			hr.add_child(UIKit.colored("%s%d%%" % ["+" if k >= 0.0 else "−", int(round(absf(k)))], UIColors.GREEN if k >= 0.0 else UIColors.RED, "Small"))
			card.add_child(hr)
	if frozen:
		card.add_child(UIKit.colored("Na semana da luta nada mais muda.", UIColors.MUTED, "Small", true))
	elif locked:
		card.add_child(UIKit.colored("Ingressos à venda: sede e arena travadas. O preço ainda pode mudar.", UIColors.MUTED, "Small", true))
	else:
		card.add_child(UIKit.colored("Sede e arena travam em %s, quando os ingressos vão à venda." % Fmt.plural(ev.week - w.week - Venue.LOCK_WEEKS, "semana", "semanas"), UIColors.MUTED, "Small", true))
	return UIKit.card_panel(card)


func _ticket_card(w: GameWorld, ev: FightEvent, frozen: bool) -> Control:
	var card := UIKit.card("Card", UITokens.S1)
	card.add_child(UIKit.label("Preço do ingresso", "Section"))
	var rows: Array = []
	var cols: Array = []
	for i in Venue.PRICE_NAMES.size():
		var p := Venue.preview(w, ev, ev.city, ev.nation, ev.venue, i)
		rows.append([String(Venue.PRICE_NAMES[i]), Fmt.money(float(p["ticket"])), Fmt.thousands(int(p["crowd"])), Fmt.money(float(p["gate"]))])
		cols.append(UIColors.GREEN if i == ev.ticket else Color(0, 0, 0, 0))
	card.add_child(EventKit.pick_table(["Faixa", "Preço", "Público", "Bilheteria"], rows, [92, 92, 128], ev.ticket, func(i: int):
		var why := Venue.set_ticket(w, ev, i)
		if why != "":
			UIManager.toast(why, UIColors.RED)
		else:
			GameManager.save_now()
		refresh(), cols, frozen))
	card.add_child(UIKit.label("Mais caro rende mais por pessoa e afasta gente. Casa vazia aparece na transmissão e tira prestígio.", "Small", true))
	return UIKit.card_panel(card)


func _arena_card(w: GameWorld, ev: FightEvent, locked: bool) -> Control:
	var card := UIKit.card("Card", UITokens.S1)
	card.add_child(UIKit.label("Arena", "Section"))
	var rows: Array = []
	var cols: Array = []
	var sel := Venue.ORDER.find(ev.venue)
	for k: String in Venue.ORDER:
		var p := Venue.preview(w, ev, ev.city, ev.nation, k, ev.ticket)
		var pf := float(p["profit"])
		rows.append([String(Venue.TYPES[k]["name"]), Fmt.thousands(int(p["capacity"])), Fmt.thousands(int(p["crowd"])), Fmt.money(pf)])
		cols.append(UIColors.GREEN if pf >= 0.0 else UIColors.RED)
	card.add_child(EventKit.pick_table(["Tipo", "Lugares", "Público", "Resultado"], rows, [92, 92, 128], sel, func(i: int):
		var why := Venue.set_type(w, ev, String(Venue.ORDER[i]))
		if why != "":
			UIManager.toast(why, UIColors.RED)
		else:
			GameManager.save_now()
		refresh(), cols, locked))
	card.add_child(UIKit.label(String(Venue.type_of(ev)["help"]), "Small", true))
	return UIKit.card_panel(card)


func _city_row(w: GameWorld, ev: FightEvent, city: String, nation: String, pr: Dictionary, locked: bool) -> Control:
	var current := city == ev.city
	var h := UIKit.hbox(UITokens.S2)
	var fl := UIKit.flag(nation, 44)
	fl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(fl)
	var v := UIKit.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top := UIKit.hbox(8)
	var nm := UIKit.label(city, "H3")
	top.add_child(nm)
	if current:
		var cur := UIKit.colored("Sede atual", UIColors.ACCENT, "Caps")
		cur.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(cur)
	v.add_child(top)
	var bits: Array = ["%s lugares" % Fmt.thousands(int(pr["capacity"]))]
	if int(pr["crowd"]) < int(pr["capacity"]):
		bits.append("%s de público" % Fmt.thousands(int(pr["crowd"])))
	var sub := UIKit.label(" · ".join(bits), "Small")
	sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(sub)
	var facts: Array = []
	var wl := Venue.wealth(city)
	if wl >= 1.3:
		facts.append("público rico")
	elif wl <= 0.85:
		facts.append("ingresso barato")
	for f: Array in Venue.crowd_factors(w, ev, city, nation):
		facts.append(String(f[0]).to_lower())
	if not facts.is_empty():
		var fl2 := UIKit.label(_cap(", ".join(facts)), "Small", true)
		fl2.add_theme_color_override(&"font_color", UIColors.MUTED)
		v.add_child(fl2)
	h.add_child(v)
	var pf := float(pr["profit"])
	var right := UIKit.vbox(0)
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var val := UIKit.colored(Fmt.money(pf), UIColors.GREEN if pf >= 0.0 else UIColors.RED, "H3")
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(val)
	var cap := UIKit.label("resultado", "Caps")
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(cap)
	h.add_child(right)
	var row := UIKit.tap_row(h, func():
		if current:
			return
		var why := Venue.set_city(w, ev, city, nation)
		if why != "":
			UIManager.toast(why, UIColors.RED)
			return
		GameManager.save_now()
		Sfx.play("tab", -6.0)
		UIManager.toast("A %s vai para %s." % [ev.name, city], UIColors.GREEN)
		refresh()
		scroll_to_top(), "RowPanel", true)
	if current:
		UIKit.set_row_selected(row, true)
	elif locked:
		row.modulate.a = 0.6
	return row


static func _cap(t: String) -> String:
	return t.substr(0, 1).to_upper() + t.substr(1)
