extends BaseScreen
## Categorias de base: os garotos do clube, a liga sub-20, artilharia e jogos.

const TABS := [["players", "Garotos"], ["table", "Sub-20"], ["scorers", "Artilharia"], ["games", "Jogos"]]

var _tab := "players"


func _init() -> void:
	show_nav = false
	screen_title = "Categorias de base"


func setup(p: Dictionary) -> void:
	super.setup(p)
	_tab = String(p.get("tab", "players"))


func refresh() -> void:
	var w := world()
	if w == null:
		return
	YouthManager.ensure_academy(w)
	var club := w.user_club()
	screen_subtitle = "%s · %d garotos" % [club.short_name, w.academy.size()]
	UIManager.refresh_chrome()
	var c := content()
	UIKit.clear(c)
	c.add_child(_header(w, club))
	var g := ButtonGroup.new()
	var row := UIKit.hbox(8)
	for t in TABS:
		var key: String = t[0]
		var chip := UIKit.chip(t[1], key == _tab, g, func():
			_tab = key
			refresh())
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(chip)
	c.add_child(row)
	match _tab:
		"players":
			c.add_child(_players(w, club))
		"table":
			c.add_child(_table(w))
		"scorers":
			c.add_child(_scorers(w))
		"games":
			c.add_child(_games(w))


func _header(w: GameWorld, club: Club) -> Control:
	var card := UIKit.card("CardHighlight", 8)
	var row := UIKit.hbox(4)
	row.add_child(UIKit.stat(str(club.youth_level), "nível da base", UIColors.ACCENT))
	row.add_child(UIKit.stat("%d/%d" % [w.academy.size(), YouthManager.MAX_SIZE], "garotos"))
	var order := YouthManager.sorted_table(w)
	var pos := order.find(w.user_club_id) + 1
	var played := 0
	if pos > 0:
		played = int(w.youth_league["table"][w.user_club_id]["pl"])
	row.add_child(UIKit.stat(("%dº" % pos) if played > 0 else "—", "no sub-20"))
	row.add_child(UIKit.stat("%.0f" % YouthManager.user_strength(w), "força do time"))
	card.add_child(row)
	card.add_child(UIKit.label("Os garotos evoluem com o nível da base, a intensidade do treino e os jogos do sub-20. Com 19 anos é a última chance: suba ao profissional ou ele sai de graça no fim da temporada.", "Small", true))
	return UIKit.card_panel(card)


func _players(w: GameWorld, club: Club) -> Control:
	var card := UIKit.card("Card", 6)
	var list := YouthManager.academy(w)
	if list.is_empty():
		card.add_child(UIKit.label("A base está vazia. Novos garotos chegam na virada da temporada.", "Muted", true))
		return UIKit.card_panel(card)
	for p: Player in list:
		var row := UIKit.hbox(10)
		row.add_child(UIKit.portrait(p, club, w.year, 56))
		var col := UIKit.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_row := UIKit.hbox(8)
		name_row.add_child(UIKit.pos_badge(p.position))
		var nl := UIKit.label(p.display_name(), "H3")
		nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_row.add_child(nl)
		col.add_child(name_row)
		var age := p.age(w.year)
		var info := "%d anos · %s · %d J · %d G" % [age, Player.potential_label(p.potential_estimate(0.55)), p.stats[Player.S_APPS], p.stats[Player.S_GOALS]]
		col.add_child(UIKit.colored(info, UIColors.ORANGE if age >= YouthManager.MAX_AGE else UIColors.MUTED, "Small"))
		row.add_child(col)
		row.add_child(UIKit.badge(p.overall, 52, 38, 22))
		var pp := p
		card.add_child(UIKit.tap_row(row, func(): _actions(pp)))
	return UIKit.card_panel(card)


func _actions(p: Player) -> void:
	var w := world()
	var v := UIKit.vbox(12)
	var head := UIKit.hbox(12)
	head.add_child(UIKit.portrait(p, w.user_club(), w.year, 84))
	var col := UIKit.vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UIKit.label(p.full_name(), "Title", true))
	col.add_child(UIKit.label("%s · %d anos · %s" % [Pos.name_of(p.position), p.age(w.year), p.playstyle()], "Small", true))
	col.add_child(UIKit.label("Potencial: %s" % Player.potential_label(p.potential_estimate(0.55)), "Small", true))
	head.add_child(col)
	head.add_child(UIKit.badge(p.overall))
	v.add_child(head)
	var weakest := 99
	for q: Player in w.squad(w.user_club()):
		weakest = mini(weakest, q.overall)
	v.add_child(UIKit.label("O jogador mais fraco do elenco principal tem %d." % weakest, "Small", true))
	v.add_child(UIKit.button("SUBIR AO PROFISSIONAL", "PrimaryButton", func():
		UIManager.close_modal()
		UIManager.toast(YouthManager.promote(w, p))
		GameManager.save_now()
		refresh(), "up"))
	v.add_child(UIKit.button("Ver perfil completo", "", func():
		UIManager.close_modal()
		UIManager.push("player", {"id": p.id}), "info"))
	v.add_child(UIKit.button("Dispensar", "DangerButton", func():
		UIManager.close_modal()
		UIManager.confirm("Dispensar %s?" % p.display_name(), "Ele deixa a base do clube.", "Dispensar", func():
			YouthManager.release(w, p)
			refresh())))
	UIManager.show_modal(v, true)


func _table(w: GameWorld) -> Control:
	var card := UIKit.card("Card", 4)
	if not YouthManager.has_league(w):
		card.add_child(UIKit.label("Sem liga sub-20 nesta temporada.", "Muted"))
		return UIKit.card_panel(card)
	card.add_child(UIKit.section(String(w.youth_league["name"])))
	card.add_child(TableRows.header(true))
	var order := YouthManager.sorted_table(w)
	for i in order.size():
		var cid: int = order[i]
		var zone := CompetitionManager.zone_color(CompetitionManager.ZONE_TITLE) if i == 0 else Color(0, 0, 0, 0)
		card.add_child(TableRows.table_row(w, w.youth_league["table"][cid], cid, i + 1, true, zone))
	return UIKit.card_panel(card)


func _scorers(w: GameWorld) -> Control:
	var card := UIKit.card("Card", 6)
	card.add_child(UIKit.section("Artilharia do sub-20"))
	var list := YouthManager.top_scorers(w, 20)
	if list.is_empty():
		card.add_child(UIKit.label("Ninguém marcou ainda.", "Muted"))
	for i in list.size():
		var e: Dictionary = list[i]
		var row := UIKit.hbox(10)
		var rk := UIKit.label(str(i + 1), "H3")
		rk.custom_minimum_size.x = 36
		row.add_child(rk)
		var cl := w.club(int(e["c"]))
		row.add_child(UIKit.crest(cl, 32))
		var col := UIKit.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var nl := UIKit.label(String(e["n"]), "H3")
		if w.is_user_club(cl.id):
			nl.add_theme_color_override(&"font_color", UIColors.ACCENT)
		col.add_child(nl)
		col.add_child(UIKit.label(cl.short_name, "Small"))
		row.add_child(col)
		row.add_child(UIKit.label("%d gols" % int(e["g"]), "Stat"))
		card.add_child(row)
	return UIKit.card_panel(card)


func _games(w: GameWorld) -> Control:
	var card := UIKit.card("Card", 6)
	card.add_child(UIKit.section("Jogos do seu sub-20"))
	if not YouthManager.has_league(w):
		card.add_child(UIKit.label("Sem liga sub-20 nesta temporada.", "Muted"))
		return UIKit.card_panel(card)
	var uid := w.user_club_id
	var rounds: Array = w.youth_league["rounds"]
	var slots: Array = w.youth_league["slots"]
	for r in rounds.size():
		for g in rounds[r]:
			if int(g[0]) != uid and int(g[1]) != uid:
				continue
			var home := int(g[0]) == uid
			var opp := w.club(int(g[1]) if home else int(g[0]))
			var row := UIKit.hbox(10)
			if int(g[2]) >= 0:
				var mine := int(g[2]) if home else int(g[3])
				var theirs := int(g[3]) if home else int(g[2])
				var res := "V" if mine > theirs else ("E" if mine == theirs else "D")
				row.add_child(UIKit.text_badge(res, UIColors.result_color(res), 40, 34, 20))
			else:
				row.add_child(UIKit.text_badge("%d" % (r + 1), UIColors.MUTED, 40, 34, 18))
			row.add_child(UIKit.crest(opp, 30))
			var l := UIKit.label(("vs " if home else "@ ") + opp.short_name, "")
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(l)
			if int(g[2]) >= 0:
				row.add_child(UIKit.label("%d x %d" % [int(g[2]) if home else int(g[3]), int(g[3]) if home else int(g[2])], "Stat"))
			else:
				row.add_child(UIKit.label(w.season.date_label(int(slots[r]), false), "Small"))
			card.add_child(row)
	return UIKit.card_panel(card)
