extends BaseScreen
## Linha do tempo de uma rivalidade: termômetro, retrospecto e os momentos que a criaram.

var _a := -1
var _b := -1


func _init() -> void:
	screen_title = "Confrontos"


func setup(p: Dictionary) -> void:
	super.setup(p)
	_a = int(p.get("a", -1))
	_b = int(p.get("b", -1))


func refresh() -> void:
	var w := world()
	if w == null:
		return
	if _a < 0:
		_a = w.user_club_id
	var ca := w.club(_a)
	var cb := w.club(_b)
	if ca == null:
		return
	if cb == null or _a == _b:
		_choose_opponent(w, ca)
		return
	var h := Rivalry.heat(w, _a, _b)
	screen_subtitle = "%s x %s" % [ca.short_name, cb.short_name]
	UIManager.refresh_chrome()
	var c := content()
	UIKit.clear(c)
	max_content_width = 1500
	c.add_child(UIKit.button("Escolher adversário", "GhostButton", func():
		_b = -1
		refresh(), "search"))
	# Cabeçalho: o clássico no fundo das cores dos dois clubes, com a faixa da liga.
	var hero := MatchHero.wrap(w, ca.league_id, ca, cb)
	var band: HBoxContainer = hero[1]
	var bl := UIKit.label(tr("Clássico") if ca.is_rival(_b) or cb.is_rival(_a) else tr("Confrontos"), "Caps")
	bl.add_theme_color_override(&"font_color", Color.WHITE)
	bl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	band.add_child(bl)
	var card: VBoxContainer = hero[2]
	var row := UIKit.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(_side(ca))
	var mid := UIKit.vbox(2)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lv := Rivalry.level_name(h)
	var big := UIKit.colored(str(int(round(h))), RivalryView.heat_color(h), "Title")
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(big)
	var cap := UIKit.label(lv if lv != "" else "Sem rixa", "Caps")
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(cap)
	row.add_child(mid)
	row.add_child(_side(cb))
	card.add_child(row)
	card.add_child(RivalryView.meter(h))
	c.add_child(hero[0])
	card = UIKit.card("Card", 10)
	card.add_child(UIKit.section_header("Retrospecto"))
	var rec := FootballMemory.head_to_head(w, _a, _b)
	if int(rec["games"]) > 0:
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override(&"h_separation", UITokens.S2)
		grid.add_child(UIKit.stat_tile(str(rec["wins"]), ca.short_name, UIColors.GREEN))
		grid.add_child(UIKit.stat_tile(str(rec["draws"]), "Empates"))
		grid.add_child(UIKit.stat_tile(str(rec["losses"]), cb.short_name, UIColors.RED))
		card.add_child(grid)
		card.add_child(UIKit.label("%d jogos registrados, de %d a %d. Gols: %d a %d." % [rec["games"], rec["first"], rec["last"], rec["gf"], rec["ga"]], "Small", true))
	else:
		card.add_child(UIKit.label("Nenhum confronto registrado nesta carreira.", "Muted", true))
	card.add_child(UIKit.section_header("Últimos confrontos"))
	var recent: Array = rec["recent"].duplicate()
	recent.reverse()
	for game: Dictionary in recent:
		var home: Club = ca if int(game["home"]) == _a else cb
		var away: Club = cb if home == ca else ca
		card.add_child(UIKit.label("%d — %s" % [game["y"], FootballMemory.comp_name(w, game["comp"])], "Small", true))
		card.add_child(UIKit.label("%s %d × %d %s" % [home.short_name, game["hg"], game["ag"], away.short_name], "H3", true))
		var pens: Array = game["pens"]
		if pens.size() == 2 and int(pens[0]) >= 0:
			card.add_child(UIKit.label("Pênaltis: %d × %d" % [pens[0], pens[1]], "Small"))
	var r := Rivalry.get_rec(w, _a, _b)
	if ca.is_rival(_b) or cb.is_rival(_a):
		card.add_child(UIKit.label("Rivais de origem", "Small", true))
	elif not r.is_empty():
		card.add_child(UIKit.label("Nasceu no save · pico %d" % int(round(float(r.get("pk", 0.0)))), "Small", true))
	var start := c.get_child_count()
	c.add_child(UIKit.card_panel(card))
	# Momentos
	var ev: Array = r.get("ev", [])
	var mc := UIKit.card("Card", 8)
	mc.add_child(UIKit.section_header("Momentos"))
	if ev.is_empty():
		mc.add_child(UIKit.label("Nada marcante ainda.", "Small", true))
	for i in range(ev.size() - 1, -1, -1):
		var e: Dictionary = ev[i]
		var er := UIKit.hbox(10)
		var y := UIKit.colored(str(int(e["y"])), UIColors.ACCENT, "H3")
		y.custom_minimum_size.x = 70
		y.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		er.add_child(y)
		var t := UIKit.label(String(e["t"]), "Small", true)
		er.add_child(t)
		er.add_child(UIKit.colored("+%d" % int(round(float(e["p"]))), RivalryView.heat_color(h), "Small"))
		var ep := UIKit.card("CardInset", 0)
		ep.add_child(er)
		mc.add_child(UIKit.card_panel(ep))
	c.add_child(UIKit.card_panel(mc))
	columnize(c, start)


func _choose_opponent(w: GameWorld, club: Club) -> void:
	screen_subtitle = club.short_name
	UIManager.refresh_chrome()
	var c := content()
	UIKit.clear(c)
	var search := LineEdit.new()
	search.placeholder_text = "Buscar adversário"
	search.tooltip_text = "Buscar clube pelo nome"
	search.custom_minimum_size.y = UITokens.H_BUTTON
	c.add_child(search)
	var list := UIKit.vbox(UITokens.S1)
	c.add_child(list)
	var recent := FootballMemory.opponents_of(w, club.id, 40)
	var render := func(query: String):
		UIKit.clear(list)
		var candidates: Array = []
		if query.strip_edges().is_empty():
			for entry in recent:
				candidates.append(w.club(int(entry["id"])))
			if candidates.is_empty():
				candidates = w.clubs_in_league(club.league_id).duplicate()
		else:
			for other: Club in w.clubs:
				if other.name.to_lower().contains(query.strip_edges().to_lower()) or other.short_name.to_lower().contains(query.strip_edges().to_lower()):
					candidates.append(other)
		var shown := 0
		for other: Club in candidates:
			if other == null or other.id == club.id or shown >= 40:
				continue
			var oid := other.id
			var h := FootballMemory.head_to_head(w, club.id, oid)
			var body := UIKit.hbox(UITokens.S2)
			body.add_child(UIKit.crest(other, 48))
			var labels := UIKit.vbox(0)
			labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			labels.add_child(UIKit.label(other.short_name, "H3", true))
			labels.add_child(UIKit.label("%d jogos — %dV %dE %dD" % [h["games"], h["wins"], h["draws"], h["losses"]], "Small", true))
			body.add_child(labels)
			var row := UIKit.tap_row(body, func():
				_b = oid
				refresh()
				scroll_to_top())
			row.custom_minimum_size.y = UITokens.H_ROW
			list.add_child(row)
			shown += 1
		if shown == 0:
			list.add_child(UIKit.label("Nenhum clube encontrado.", "Muted"))
	search.text_changed.connect(render)
	render.call("")


func _side(club: Club) -> Control:
	var v := UIKit.vbox(4)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var cr := UIKit.crest(club, 72)
	cr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(cr)
	var l := UIKit.label(club.short_name, "H3", true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	var cid := club.id
	var open := func():
		if world().is_user_club(cid):
			UIManager.goto("club")
		else:
			UIManager.push("club", {"id": cid})
	var b := UIKit.tap_row(v, open, "CardFlat")
	b.custom_minimum_size.x = 150
	return b
