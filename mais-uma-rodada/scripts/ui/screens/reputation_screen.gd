extends BaseScreen
class_name ReputationScreen
## Reputação do mundo em abas: competições (e quanto vale cada título), clubes e jogadores.

static var _tab := "comps"
static var _comp_kind := "leagues"
var _all := false


func _init() -> void:
	show_nav = false
	screen_title = "Reputação"


func refresh() -> void:
	var w := world()
	if w == null:
		return
	screen_subtitle = "Competições, clubes e jogadores"
	UIManager.refresh_chrome()
	var c := content()
	UIKit.clear(c)
	c.add_child(UIKit.tabs([["comps", "Competições"], ["clubs", "Clubes"], ["players", "Jogadores"]], _tab, func(k: String):
		_tab = k
		_all = false
		refresh()
		scroll_to_top()))
	match _tab:
		"comps":
			_comps(w, c)
		"clubs":
			_clubs(w, c)
		"players":
			_players(w, c)


func _comps(w: GameWorld, c: VBoxContainer) -> void:
	c.add_child(UIKit.segment([["leagues", "Ligas"], ["cups", "Copas"]], _comp_kind, func(k: String):
		_comp_kind = k
		_all = false
		refresh()))
	c.add_child(UIKit.label("Cada título soma pontos de prestígio ao clube e aos jogadores. Quanto maior a reputação da competição, mais o título vale.", "Muted", true))
	var rows: Array = []
	if _comp_kind == "leagues":
		for id in DatabaseManager.league_ids():
			rows.append({"k": "L:" + id, "r": Reputation.league_rep(id)})
	else:
		for id in DatabaseManager.cups_cfg():
			rows.append({"k": CupManager.title_key(id), "r": Reputation.cup_rep(id)})
	rows.sort_custom(func(a, b): return float(a["r"]) > float(b["r"]))
	var list := UIKit.card("Card", 4)
	var n := rows.size() if _all else mini(30, rows.size())
	for i in n:
		var r: Dictionary = rows[i]
		var key: String = r["k"]
		var h := UIKit.hbox(10)
		var pos := UIKit.label("%d" % (i + 1), "Mono")
		pos.custom_minimum_size.x = 34
		h.add_child(pos)
		h.add_child(UIKit.comp_logo(key.substr(2), 28))
		var col := UIKit.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var nm := UIKit.label(Reputation.comp_name(w, key), "H3")
		nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		col.add_child(nm)
		col.add_child(UIKit.label("%s · título vale %d pts" % [Reputation.label(float(r["r"])), int(round(Reputation.title_value(key)))], "Small"))
		h.add_child(col)
		h.add_child(UIKit.pill(str(int(round(float(r["r"])))), Reputation.color(float(r["r"])), 16))
		list.add_child(h)
	c.add_child(UIKit.card_panel(list))
	if not _all and rows.size() > n:
		c.add_child(UIKit.button("Mostrar todas (%d)" % rows.size(), "GhostButton", func():
			_all = true
			refresh(), "plus"))


func _clubs(w: GameWorld, c: VBoxContainer) -> void:
	var clubs: Array = []
	for cl: Club in w.clubs:
		if cl != null and cl.league_id != "":
			clubs.append(cl)
	clubs.sort_custom(func(a: Club, b: Club): return a.reputation > b.reputation or (a.reputation == b.reputation and a.id < b.id))
	if w.has_user():
		var me := w.user_club()
		c.add_child(UIKit.label("%s é o %dº em reputação no mundo (%d · %s)." % [me.short_name, Reputation.club_world_rank(w, me), int(round(me.reputation)), Reputation.label(me.reputation)], "Muted", true))
	var list := UIKit.card("Card", 4)
	var n := mini(100 if _all else 40, clubs.size())
	for i in n:
		var cl: Club = clubs[i]
		var h := UIKit.hbox(10)
		var pos := UIKit.label("%d" % (i + 1), "Mono")
		pos.custom_minimum_size.x = 34
		h.add_child(pos)
		h.add_child(UIKit.crest(cl, 30))
		var col := UIKit.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UIKit.label(cl.short_name, "H3"))
		col.add_child(UIKit.label("%s · %s · prestígio %d" % [w.league_short(cl.league_id), Reputation.label(cl.reputation), int(round(Reputation.club_prestige(cl)))], "Small"))
		h.add_child(col)
		h.add_child(UIKit.pill(str(int(round(cl.reputation))), Reputation.color(cl.reputation), 16))
		var cid := cl.id
		list.add_child(UIKit.tap_row(h, func():
			if w.is_user_club(cid):
				UIManager.goto("club")
			else:
				UIManager.push("club", {"id": cid}), "RowPanel"))
	c.add_child(UIKit.card_panel(list))
	if not _all and clubs.size() > n:
		c.add_child(UIKit.button("Mostrar top 100", "GhostButton", func():
			_all = true
			refresh(), "plus"))


func _players(w: GameWorld, c: VBoxContainer) -> void:
	var pool: Array = []
	for p: Player in w.players.values():
		if p.club_id >= 0 and p.overall >= 76:
			pool.append([Reputation.player_rep(w, p), p])
	pool.sort_custom(func(a, b): return float(a[0]) > float(b[0]))
	c.add_child(UIKit.label("Mistura nível, clube, títulos (pesados pela competição) e prêmios individuais.", "Muted", true))
	var list := UIKit.card("Card", 4)
	var n := mini(100 if _all else 40, pool.size())
	for i in n:
		var rep: float = pool[i][0]
		var p: Player = pool[i][1]
		var cl := w.club(p.club_id)
		var h := UIKit.hbox(10)
		var pos := UIKit.label("%d" % (i + 1), "Mono")
		pos.custom_minimum_size.x = 34
		h.add_child(pos)
		h.add_child(UIKit.pos_badge(p.position))
		var col := UIKit.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var nm := UIKit.label(p.display_name(), "H3")
		nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		col.add_child(nm)
		col.add_child(UIKit.label("%s · %d · %d títulos · %s" % [cl.short_name if cl != null else "", p.overall, p.titles, Reputation.player_label(rep)], "Small"))
		h.add_child(col)
		h.add_child(UIKit.pill(str(int(round(rep))), Reputation.color(rep), 16))
		var pid := p.id
		list.add_child(UIKit.tap_row(h, func(): UIManager.push("player", {"id": pid}), "RowPanel"))
	c.add_child(UIKit.card_panel(list))
	if not _all and pool.size() > n:
		c.add_child(UIKit.button("Mostrar top 100", "GhostButton", func():
			_all = true
			refresh(), "plus"))


## Cartão de reputação de um clube (visão geral da tela do clube).
static func club_card(w: GameWorld, club: Club) -> Control:
	var card := UIKit.card("Card", 8)
	card.add_child(UIKit.section_header("Reputação", "Ranking", func(): UIManager.push("reputation")))
	var tiles: Array = [
		UIKit.stat_tile(str(int(round(club.reputation))), Reputation.label(club.reputation), Reputation.color(club.reputation)),
		UIKit.stat_tile("%dº" % Reputation.club_world_rank(w, club), "no mundo"),
		UIKit.stat_tile(str(int(round(Reputation.club_prestige(club)))), "prestígio"),
	]
	card.add_child(UIKit.stat_grid(tiles, 600))
	if club.league_id != "":
		var lr := Reputation.league_rep(club.league_id)
		card.add_child(UIKit.kv("Liga", "%s · %d (%s)" % [w.league_short(club.league_id), int(round(lr)), Reputation.label(lr)]))
	var best := Reputation.club_titles_by_value(club)
	if best.is_empty():
		card.add_child(UIKit.label("Sem títulos ainda. Uma liga forte vale muito mais prestígio que uma fraca.", "Small", true))
	else:
		card.add_child(UIKit.label("Títulos que mais pesam", "Caps"))
		for i in mini(3, best.size()):
			var t: Dictionary = best[i]
			card.add_child(UIKit.kv("%dx %s" % [int(t["n"]), Reputation.comp_name(w, String(t["k"]))], "%d pts cada" % int(round(float(t["v"])))))
	return UIKit.card_panel(card)
