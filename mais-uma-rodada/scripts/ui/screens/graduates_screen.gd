extends BaseScreen
## Revelados pela base de qualquer clube: quem estreou profissionalmente ali (primeira passagem
## da carreira, até os 19 anos), onde joga hoje, o nível e a seleção. Inclui os aposentados.

var _club_id := -1
var _filter := "active"


func _init() -> void:
	show_nav = false
	screen_title = "Revelados pela base"


func setup(p: Dictionary) -> void:
	super.setup(p)
	_club_id = int(p.get("id", -1))


func refresh() -> void:
	var w := world()
	if w == null:
		return
	if _club_id < 0:
		_club_id = w.user_club_id
	var club := w.club(_club_id)
	if club == null:
		return
	screen_subtitle = club.name
	UIManager.refresh_chrome()
	var c := content()
	UIKit.clear(c)
	var list := Graduates.of_club(w, club.id)
	var retired := Graduates.retired_of(w, club.id)
	c.add_child(_header(w, club, list, retired))
	var g := ButtonGroup.new()
	var row := UIKit.flow(8)
	for t in [["active", "Em atividade · %d" % list.size()], ["retired", "Aposentados · %d" % retired.size()]]:
		var key: String = t[0]
		row.add_child(UIKit.chip(t[1], key == _filter, g, func():
			_filter = key
			refresh()))
	c.add_child(row)
	if _filter == "active":
		c.add_child(_active(w, club, list))
	else:
		c.add_child(_retired(w, retired))


func _header(w: GameWorld, club: Club, list: Array, retired: Array) -> Control:
	var card := UIKit.card("Card", 8)
	var row := UIKit.hbox(14)
	row.add_child(UIKit.crest(club, 90))
	var col := UIKit.vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UIKit.label("Fábrica de talentos", "Caps"))
	col.add_child(UIKit.label(club.name, "Title", true))
	col.add_child(UIKit.label("Base %d/100" % club.youth_level, "Small"))
	row.add_child(col)
	card.add_child(row)
	var home := 0
	var abroad := 0
	var intl := 0
	for p: Player in list:
		if p.club_id == club.id:
			home += 1
		elif p.club_id >= 0 and w.club(p.club_id).nation != club.nation:
			abroad += 1
		if NationalTeamManager.caps_of(w, p.id)[0] > 0:
			intl += 1
	var stats := UIKit.hbox(4)
	stats.add_child(UIKit.stat(str(list.size()), "em atividade"))
	stats.add_child(UIKit.stat(str(home), "no clube", UIColors.ACCENT))
	stats.add_child(UIKit.stat(str(abroad), "no exterior"))
	stats.add_child(UIKit.stat(str(intl), "seleção", UIColors.GREEN))
	card.add_child(stats)
	return HeroBackdrop.attach(UIKit.card_panel(card), club)


func _active(w: GameWorld, club: Club, list: Array) -> Control:
	var card := UIKit.card("Card", 6)
	if list.is_empty():
		card.add_child(UIKit.label("Nenhum jogador em atividade saiu da base deste clube.", "Muted", true))
		return UIKit.card_panel(card)
	for p: Player in list.slice(0, 60):
		var row := UIKit.hbox(10)
		var cur: Club = w.club(p.club_id) if p.club_id >= 0 else null
		row.add_child(UIKit.portrait(p, cur, w.year, 56))
		var col := UIKit.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var nr := UIKit.hbox(8)
		nr.add_child(UIKit.pos_badge(p.position))
		var nl := UIKit.label(p.display_name(), "H3")
		nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nr.add_child(nl)
		col.add_child(nr)
		var where := cur.short_name if cur != null else "sem clube"
		if cur != null and cur.id == club.id:
			where = "no clube"
		var caps := NationalTeamManager.caps_of(w, p.id)
		col.add_child(UIKit.label("%d anos · %s%s" % [p.age(w.year), where, (" · %d jogos pela seleção" % caps[0]) if caps[0] > 0 else ""], "Small", true))
		row.add_child(col)
		if cur != null:
			row.add_child(UIKit.crest(cur, 34))
		row.add_child(UIKit.badge(p.overall if w.is_user_club(p.club_id) else PlayerRowView.estimate(w, p, p.overall), 50, 36, 20))
		var pid := p.id
		card.add_child(UIKit.tap_row(row, func(): UIManager.push("player", {"id": pid})))
	if list.size() > 60:
		card.add_child(UIKit.label("E mais %d." % (list.size() - 60), "Small"))
	return UIKit.card_panel(card)


func _retired(w: GameWorld, retired: Array) -> Control:
	var card := UIKit.card("Card", 6)
	if retired.is_empty():
		card.add_child(UIKit.label("Nenhum aposentado notável formado aqui (ainda).", "Muted", true))
		return UIKit.card_panel(card)
	for r in retired.slice(0, 40):
		var row := UIKit.hbox(10)
		row.add_child(UIKit.flag(String(r.get("nat", "")), 36))
		var col := UIKit.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UIKit.label(String(r.get("ka", r.get("name", "—"))), "H3", true))
		col.add_child(UIKit.label("%d jogos · %d gols · %d títulos" % [int(r.get("apps", 0)), int(r.get("goals", 0)), int(r.get("titles", 0))], "Small"))
		row.add_child(col)
		row.add_child(UIKit.badge(int(r.get("ovr", 0)), 50, 36, 20))
		card.add_child(row)
	return UIKit.card_panel(card)
