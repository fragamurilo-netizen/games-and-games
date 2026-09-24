extends BaseScreen
## Futebol de seleções: torneios (Copa do Mundo, Eurocopa, Copa América...), eliminatórias em
## andamento, ranking de seleções e a convocação de cada país.

const TABS := [["tours", "Torneios"], ["quals", "Eliminatórias"], ["ranking", "Ranking"], ["squad", "Convocação"]]

var _tab := "tours"
var _tour := ""
var _camp := 0
var _nation := ""


func _init() -> void:
	show_nav = false
	screen_title = "Seleções"


func setup(p: Dictionary) -> void:
	super.setup(p)
	_tab = String(p.get("tab", "tours"))
	_nation = String(p.get("nation", ""))
	_tour = String(p.get("tour", ""))


func refresh() -> void:
	var w := world()
	if w == null:
		return
	if _nation == "":
		_nation = w.user_nation() if w.has_user() else "BRA"
	var nat_rank := NationalTeamManager.rank_of(w, _nation)
	screen_subtitle = "%s · %dº no ranking" % [DatabaseManager.nation_name(_nation), nat_rank]
	UIManager.refresh_chrome()
	var c := content()
	UIKit.clear(c)
	var g := ButtonGroup.new()
	var row := UIKit.flow(8)
	for t in TABS:
		var key: String = t[0]
		row.add_child(UIKit.chip(t[1], key == _tab, g, func():
			_tab = key
			refresh()))
	c.add_child(row)
	match _tab:
		"tours":
			_tours(w, c)
		"quals":
			_quals(w, c)
		"ranking":
			c.add_child(_ranking(w))
		"squad":
			_squad(w, c)


# ---------------------------------------------------------------------------
# Torneios
# ---------------------------------------------------------------------------

func _tours(w: GameWorld, c: VBoxContainer) -> void:
	var next := UIKit.card("Card", 6)
	next.add_child(UIKit.section("Próximos torneios"))
	var upcoming: Array = []
	for id in NationalTeamManager.tournament_ids():
		var y := NationalTeamManager.next_edition(id, w.year + 1)
		upcoming.append([y, id])
	upcoming.sort_custom(func(a, b): return int(a[0]) < int(b[0]) or (int(a[0]) == int(b[0]) and String(a[1]) < String(b[1])))
	for u in upcoming:
		var id: String = u[1]
		var y: int = u[0]
		var host := NationalTeamManager.host_of(id, y)
		var h := UIKit.hbox(10)
		h.add_child(UIKit.flag(host, 36))
		var l := UIKit.label("%s %d" % [NationalTeamManager.tournament_name(id), y], "H3")
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		h.add_child(UIKit.label("sede: %s" % DatabaseManager.nation_name(host), "Small"))
		next.add_child(h)
	c.add_child(UIKit.card_panel(next))
	var ids := NationalTeamManager.tournament_ids()
	if _tour == "":
		var tours: Array = NationalTeamManager.data(w)["tours"]
		_tour = String(tours[tours.size() - 1]["t"]) if not tours.is_empty() else String(ids[0])
	var g := ButtonGroup.new()
	var flow := UIKit.flow(8)
	for id in ids:
		var key: String = id
		flow.add_child(UIKit.chip(String(NationalTeamManager.tcfg(key).get("short", key)), key == _tour, g, func():
			_tour = key
			refresh()))
	c.add_child(flow)
	var rec := NationalTeamManager.last_edition(w, _tour)
	if rec.is_empty():
		c.add_child(UIKit.label("A primeira edição da %s no save será em %d." % [NationalTeamManager.tournament_name(_tour), NationalTeamManager.next_edition(_tour, w.year + 1)], "Muted", true))
	else:
		c.add_child(_edition(w, rec))
	c.add_child(_champions_list(w, _tour))


func _edition(w: GameWorld, rec: Dictionary) -> Control:
	var out := UIKit.vbox(12)
	var head := UIKit.card("CardHighlight", 8)
	head.add_child(UIKit.label("%s %d" % [rec["name"], int(rec["y"])], "Title"))
	head.add_child(UIKit.label("Sede: %s · %d seleções" % [DatabaseManager.nation_name(rec["host"]), (rec["teams"] as Array).size()], "Small"))
	var ch := UIKit.hbox(12)
	ch.add_child(UIKit.icon_rect("trophy", 36, UIColors.ACCENT))
	ch.add_child(UIKit.flag(rec["champion"], 48))
	var cl := UIKit.label("%s campeã" % DatabaseManager.nation_name(rec["champion"]), "H2")
	cl.add_theme_color_override(&"font_color", UIColors.ACCENT)
	ch.add_child(cl)
	head.add_child(ch)
	head.add_child(UIKit.label("Vice: %s" % DatabaseManager.nation_name(rec["runner_up"]), ""))
	var sc: Dictionary = rec.get("scorer", {})
	if not sc.is_empty():
		head.add_child(UIKit.label("Artilheiro: %s (%s), %d gols" % [sc["name"], DatabaseManager.nation_name(sc["nation"]), int(sc["goals"])], "Small"))
	out.add_child(UIKit.card_panel(head))
	# Mata-mata, da final para trás
	var ko: Array = rec.get("ko", [])
	for i in range(ko.size() - 1, -1, -1):
		var rd: Dictionary = ko[i]
		var card := UIKit.card("Card", 4)
		card.add_child(UIKit.section(String(rd["n"])))
		for m in rd["m"]:
			card.add_child(_match_row(w, m))
		out.add_child(UIKit.card_panel(card))
	# Grupos
	for gr in rec.get("groups", []):
		var card := UIKit.card("Card", 4)
		card.add_child(UIKit.section("Grupo %s" % gr["n"]))
		var order: Array = gr["order"]
		for i in order.size():
			card.add_child(_nation_table_row(w, order[i], gr["table"][order[i]], i + 1, i < 2))
		out.add_child(UIKit.card_panel(card))
	return out


## Linha de jogo de mata-mata: [a, b, ga, gb, pa, pb, et, vencedor].
func _match_row(w: GameWorld, m: Array) -> Control:
	var h := UIKit.hbox(8)
	var a := UIKit.label(DatabaseManager.nation_name(m[0]), "H3" if m[7] == m[0] else "")
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	a.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	h.add_child(a)
	h.add_child(UIKit.flag(m[0], 30))
	var score := "%d x %d" % [int(m[2]), int(m[3])]
	if int(m[4]) >= 0:
		score += "\n(%d x %d pên.)" % [int(m[4]), int(m[5])]
	elif bool(m[6]):
		score += "\n(prorr.)"
	var s := UIKit.label(score, "H3")
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.custom_minimum_size.x = 110
	h.add_child(s)
	h.add_child(UIKit.flag(m[1], 30))
	var b := UIKit.label(DatabaseManager.nation_name(m[1]), "H3" if m[7] == m[1] else "")
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	h.add_child(b)
	return h


func _nation_table_row(w: GameWorld, code: String, r: Dictionary, pos: int, highlight: bool) -> Control:
	var h := UIKit.hbox(8)
	var bar := ColorRect.new()
	bar.custom_minimum_size = Vector2(5, 0)
	bar.color = CompetitionManager.zone_color(CompetitionManager.ZONE_CONTINENTAL) if highlight else Color(0, 0, 0, 0)
	h.add_child(bar)
	var pl := UIKit.label(str(pos), "H3")
	pl.custom_minimum_size.x = 30
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(pl)
	h.add_child(UIKit.flag(code, 30))
	var mine := w.has_user() and code == w.user_nation()
	var n := UIKit.label(DatabaseManager.nation_name(code), "H3" if mine else "")
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if mine:
		n.add_theme_color_override(&"font_color", UIColors.ACCENT)
	h.add_child(n)
	var sg := int(r["gf"]) - int(r["ga"])
	var vals: Array = [str(int(r["pl"])), Fmt.signed(sg), str(int(r["pts"]))]
	for i in vals.size():
		var l := UIKit.label(vals[i], "H3" if i == vals.size() - 1 else "")
		l.custom_minimum_size.x = 46
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(l)
	var key := code
	return UIKit.tap_row(h, func():
		_nation = key
		_tab = "squad"
		refresh(), "CardFlat")


func _champions_list(w: GameWorld, id: String) -> Control:
	var card := UIKit.card("Card", 4)
	card.add_child(UIKit.section("Campeões no save"))
	var any := false
	var tours: Array = NationalTeamManager.data(w)["tours"]
	for i in range(tours.size() - 1, -1, -1):
		var r: Dictionary = tours[i]
		if String(r["t"]) != id:
			continue
		any = true
		var h := UIKit.hbox(10)
		var y := UIKit.label(str(int(r["y"])), "H3")
		y.custom_minimum_size.x = 64
		h.add_child(y)
		h.add_child(UIKit.flag(r["champion"], 32))
		var n := UIKit.label(DatabaseManager.nation_name(r["champion"]), "H3")
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(n)
		h.add_child(UIKit.label("vice: %s" % DatabaseManager.nation_name(r["runner_up"]), "Small"))
		card.add_child(h)
	if not any:
		card.add_child(UIKit.label("Nenhuma edição disputada ainda.", "Muted"))
	return UIKit.card_panel(card)


# ---------------------------------------------------------------------------
# Eliminatórias
# ---------------------------------------------------------------------------

func _quals(w: GameWorld, c: VBoxContainer) -> void:
	var camps: Array = NationalTeamManager.data(w)["camps"].duplicate()
	if camps.is_empty():
		c.add_child(UIKit.label("Nenhuma eliminatória em andamento. Elas acontecem nas datas FIFA das temporadas antes de cada torneio.", "Muted", true))
		return
	# A confederação do usuário primeiro
	var confed := String(DatabaseManager.nation(_nation).get("confed", ""))
	camps.sort_custom(func(a, b): return (String(a["confed"]) == confed and String(b["confed"]) != confed) or (String(a["confed"]) == String(b["confed"]) and int(a["y"]) < int(b["y"])))
	_camp = clampi(_camp, 0, camps.size() - 1)
	var ob := OptionButton.new()
	for i in camps.size():
		ob.add_item("%s %d" % [camps[i]["name"], int(camps[i]["y"])], i)
	ob.select(_camp)
	ob.item_selected.connect(func(i: int):
		_camp = i
		refresh())
	c.add_child(ob)
	var camp: Dictionary = camps[_camp]
	var info := UIKit.card("CardHighlight", 6)
	info.add_child(UIKit.label("%s %d" % [camp["name"], int(camp["y"])], "H2"))
	info.add_child(UIKit.label("Rodada %d de %d · %d vaga(s)%s" % [int(camp["md"]), int(camp["mdt"]), int(camp["spots"]), " · encerrada" if bool(camp["done"]) else ""], "Small"))
	if bool(camp["done"]):
		info.add_child(UIKit.label("Classificados: %s" % ", ".join((camp["q"] as Array).map(func(x): return DatabaseManager.nation_name(x))), "", true))
	c.add_child(UIKit.card_panel(info))
	var groups: Array = camp["groups"]
	var per_group := int(camp["spots"]) / maxi(1, groups.size())
	for g in groups:
		var card := UIKit.card("Card", 4)
		if groups.size() > 1:
			card.add_child(UIKit.section("Grupo %s" % g["n"]))
		var order := NationalTeamManager.sort_group(g)
		for i in order.size():
			var q := (camp["q"] as Array).has(order[i]) if bool(camp["done"]) else i < per_group
			card.add_child(_nation_table_row(w, order[i], g["table"][order[i]], i + 1, q))
		c.add_child(UIKit.card_panel(card))


# ---------------------------------------------------------------------------
# Ranking
# ---------------------------------------------------------------------------

func _ranking(w: GameWorld) -> Control:
	var card := UIKit.card("Card", 2)
	card.add_child(UIKit.section("Ranking de seleções"))
	var r := NationalTeamManager.ranking(w)
	var mine := w.user_nation() if w.has_user() else ""
	for i in r.size():
		var code: String = r[i][0]
		var h := UIKit.hbox(10)
		var pl := UIKit.label(str(i + 1), "H3")
		pl.custom_minimum_size.x = 40
		pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(pl)
		h.add_child(UIKit.flag(code, 34))
		var n := UIKit.label(DatabaseManager.nation_name(code), "H3" if code == mine else "")
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if code == mine:
			n.add_theme_color_override(&"font_color", UIColors.ACCENT)
		h.add_child(n)
		var titles := NationalTeamManager.titles_of(w, code).size()
		if titles > 0:
			h.add_child(UIKit.pill("%d título(s)" % titles, UIColors.ACCENT, 14))
		var pts := UIKit.label(str(int(round(float(r[i][1])))), "H3")
		pts.custom_minimum_size.x = 70
		pts.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(pts)
		var key := code
		card.add_child(UIKit.tap_row(h, func():
			_nation = key
			_tab = "squad"
			refresh(), "CardFlat"))
	return UIKit.card_panel(card)


# ---------------------------------------------------------------------------
# Convocação
# ---------------------------------------------------------------------------

func _squad(w: GameWorld, c: VBoxContainer) -> void:
	var nations: Array = DatabaseManager.nations().keys()
	nations.sort_custom(func(a, b): return DatabaseManager.nation_name(a) < DatabaseManager.nation_name(b))
	var ob := OptionButton.new()
	for i in nations.size():
		ob.add_item(DatabaseManager.nation_name(nations[i]), i)
		if nations[i] == _nation:
			ob.select(i)
	ob.item_selected.connect(func(i: int):
		_nation = String(nations[i])
		refresh())
	c.add_child(ob)
	var ids: Array = NationalTeamManager.data(w)["squads"].get(_nation, [])
	var squad: Array = []
	for pid in ids:
		var p := w.player(int(pid))
		if p != null:
			squad.append(p)
	var fresh := squad.is_empty()
	if fresh:
		# Ainda sem data FIFA: mostra quem seria chamado hoje.
		var pool: Array = []
		for p: Player in w.players.values():
			if p.nationality == _nation and p.club_id >= 0 and p.injury_weeks == 0:
				pool.append(p)
		squad = NationalTeamManager.call_up(pool)
	var head := UIKit.card("CardHighlight", 6)
	var hh := UIKit.hbox(12)
	hh.add_child(UIKit.flag(_nation, 64))
	var col := UIKit.vbox(2)
	col.add_child(UIKit.label(DatabaseManager.nation_name(_nation), "Title"))
	col.add_child(UIKit.label("%dº no ranking · força %d · %s" % [NationalTeamManager.rank_of(w, _nation), int(round(NationalTeamManager.strength_of(_nation, squad))),
		"lista provável" if fresh else "última convocação"], "Small"))
	hh.add_child(col)
	head.add_child(hh)
	var titles := NationalTeamManager.titles_of(w, _nation)
	if not titles.is_empty():
		var tf := UIKit.flow(6)
		for t in titles:
			tf.add_child(UIKit.pill("%s %d" % [String(NationalTeamManager.tcfg(t[0]).get("short", t[0])), int(t[1])], UIColors.ACCENT, 14))
		head.add_child(tf)
	c.add_child(UIKit.card_panel(head))
	if squad.is_empty():
		c.add_child(UIKit.label("Nenhum jogador desta nacionalidade atua em clubes do mundo do jogo.", "Muted", true))
		return
	squad.sort_custom(func(a, b): return Pos.DISPLAY_ORDER.find(a.position) < Pos.DISPLAY_ORDER.find(b.position) or (a.position == b.position and a.ovr_f > b.ovr_f))
	var card := UIKit.card("Card", 4)
	card.add_child(UIKit.section("%d convocados" % squad.size()))
	for p: Player in squad:
		var h := UIKit.hbox(10)
		h.add_child(UIKit.pos_badge(p.position))
		var cl: Club = w.club(p.club_id) if p.club_id >= 0 else null
		h.add_child(UIKit.crest(cl, 30))
		var v := UIKit.vbox(0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var n := UIKit.label(p.display_name(), "H3")
		n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		if w.has_user() and p.club_id == w.user_club_id:
			n.add_theme_color_override(&"font_color", UIColors.ACCENT)
		v.add_child(n)
		var caps := NationalTeamManager.caps_of(w, p.id)
		v.add_child(UIKit.label("%s · %d anos · %d jogos, %d gols" % [cl.short_name if cl != null else "sem clube", p.age(w.year), caps[0], caps[1]], "Small"))
		h.add_child(v)
		h.add_child(UIKit.badge(p.overall, 52, 36, 22))
		var pid := p.id
		card.add_child(UIKit.tap_row(h, func(): UIManager.push("player", {"id": pid}), "CardFlat"))
	c.add_child(UIKit.card_panel(card))
