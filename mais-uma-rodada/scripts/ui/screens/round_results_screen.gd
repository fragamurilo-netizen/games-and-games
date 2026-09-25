extends BaseScreen
## Resultados da rodada: seu jogo, os demais placares da divisão, a tabela atualizada e o mercado.

var _report: Dictionary = {}


func _init() -> void:
	show_nav = false
	screen_title = "Resultados"


func setup(p: Dictionary) -> void:
	super.setup(p)
	_report = p.get("report", GameManager.last_report)


func refresh() -> void:
	var w := world()
	if w == null:
		return
	var club := w.user_club()
	var user: Dictionary = _report.get("user", {})
	var f: Fixture = user.get("fixture", null)
	screen_subtitle = CompText.fixture_title(w, f) if f != null else w.league_name(club.league_id)
	UIManager.refresh_chrome()
	var c := content()
	UIKit.clear(c)
	if f != null:
		c.add_child(_user_card(w, f, user))
	for ev in _report.get("cups", []):
		var txt := CompText.cup_event_text(w, ev)
		if txt != "" and (w.is_user_club(int(ev.get("club", -1))) or ev.get("t", "") == "cwc"):
			c.add_child(_notice("trophy", UIColors.ACCENT, txt))
	if _report.get("window_opened", false):
		c.add_child(_notice("swap", UIColors.GREEN, "A janela de transferências abriu. Até %s você pode comprar e vender." % w.season.date_label(w.window_end_day(), false)))
	elif _report.get("window_closed", false):
		c.add_child(_notice("swap", UIColors.ORANGE, "A janela de transferências fechou. Agora só jogadores livres podem ser contratados."))
	if f != null:
		c.add_child(_round_card(w, f))
		if f.is_league():
			var tw := _totw_card(w)
			if tw != null:
				c.add_child(tw)
	var tc := _table_card(w, club, f)
	if tc != null:
		c.add_child(tc)
	var tr := _transfers_card(w)
	if tr != null:
		c.add_child(tr)
	var ret := _retiring_card(w)
	if ret != null:
		c.add_child(ret)
	_build_footer()


func _notice(icon_name: String, color: Color, text: String) -> Control:
	var row := UIKit.hbox(12)
	row.add_child(UIKit.icon_rect(icon_name, 30, color))
	row.add_child(UIKit.label(text, "", true))
	var card := UIKit.card("CardFlat", 0)
	card.add_child(row)
	return UIKit.card_panel(card)


func _user_card(w: GameWorld, f: Fixture, user: Dictionary) -> Control:
	var club := w.user_club()
	var res: String = user.get("result", f.result_for(club.id))
	var card := UIKit.card("CardHighlight", 12)
	var head := UIKit.hbox(8)
	var names := {"V": "VITÓRIA", "E": "EMPATE", "D": "DERROTA"}
	head.add_child(UIKit.pill(names.get(res, res), UIColors.result_color(res), 22))
	head.add_child(UIKit.spacer())
	if MatchEngine.is_derby(w, f.home, f.away):
		head.add_child(UIKit.pill("CLÁSSICO", UIColors.RED, 18))
	card.add_child(head)
	var row := UIKit.hbox(8)
	for side in 2:
		var cl := w.club(f.home if side == 0 else f.away)
		var v := UIKit.vbox(4)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cr := UIKit.crest(cl, 84)
		cr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(cr)
		var n := UIKit.label(cl.short_name, "H3")
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		v.add_child(n)
		row.add_child(v)
		if side == 0:
			var s := UIKit.label("%d – %d" % [f.hg, f.ag], "Score")
			s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			row.add_child(s)
	card.add_child(row)
	card.add_child(_goals_box(w, f))
	var motm := w.player(f.motm)
	if motm != null:
		card.add_child(UIKit.kv("Craque do jogo", "%s (%s)" % [motm.display_name(), w.club(motm.club_id).short_name if motm.club_id >= 0 else "—"], UIColors.ACCENT))
	var before := int(user.get("pos_before", 0))
	var after := int(user.get("pos_after", 0))
	if after > 0:
		var prow := UIKit.hbox(10)
		prow.add_child(UIKit.label("Posição na tabela", "Muted"))
		prow.add_child(UIKit.spacer())
		if before > 0 and before != after:
			var up := after < before
			prow.add_child(UIKit.icon_rect("up" if up else "down", 24, UIColors.GREEN if up else UIColors.RED))
			prow.add_child(UIKit.label("%dº → %dº" % [before, after], "H3"))
		else:
			prow.add_child(UIKit.label("%dº" % after, "H3"))
		card.add_child(prow)
	return UIKit.card_panel(card)


func _goals_box(w: GameWorld, f: Fixture) -> Control:
	var row := UIKit.hbox(10)
	for side in 2:
		var v := UIKit.vbox(0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for g in f.goals:
			if int(g[1]) != side:
				continue
			var p := w.player(int(g[2]))
			var txt := "%s %s" % [p.short_name() if p != null else "?", Fmt.minute(int(g[0]), int(g[4]) if g.size() > 4 else 0)]
			if int(g[3]) == Fixture.GOAL_PENALTY:
				txt += " (p)"
			elif int(g[3]) == Fixture.GOAL_OWN:
				txt += " (contra)"
			var l := UIKit.label(txt, "Small")
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if side == 0 else HORIZONTAL_ALIGNMENT_RIGHT
			v.add_child(l)
		row.add_child(v)
	return row


## Seleção da rodada da liga do usuário (1-4-3-3), com destaque para quem é do seu time.
func _totw_card(w: GameWorld) -> Control:
	var tw: Dictionary = w.stats.get("totw", {})
	if tw.is_empty() or int(tw.get("y", 0)) != w.year:
		return null
	var ids: Array = tw.get("ids", [])
	var rts: Array = tw.get("rt", [])
	var card := UIKit.card("Card", 4)
	card.add_child(UIKit.section("Seleção da %dª rodada" % int(tw.get("r", 0))))
	var lines := [[0, 1], [1, 5], [5, 8], [8, 11]]
	for ln in lines:
		var flow := UIKit.flow(8)
		for i in range(int(ln[0]), mini(int(ln[1]), ids.size())):
			var p := w.player(int(ids[i]))
			if p == null:
				continue
			var mine := p.club_id >= 0 and w.is_user_club(p.club_id)
			var star := int(ids[i]) == int(tw.get("best", -1))
			var txt := "%s%s %s" % ["★ " if star else "", p.display_name(), Fmt.rating(float(rts[i]) if i < rts.size() else 0.0)]
			flow.add_child(UIKit.pill(txt, UIColors.ACCENT if mine else (UIColors.GREEN if star else UIColors.BLUE), 16))
		card.add_child(flow)
	return UIKit.card_panel(card)


func _round_card(w: GameWorld, uf: Fixture) -> Control:
	var card := UIKit.card("Card", 6)
	card.add_child(UIKit.section(CompText.fixture_title(w, uf)))
	for f: Fixture in CompText.sibling_fixtures(w, uf):
		if not f.played:
			continue
		var row := UIKit.hbox(8)
		var hn := UIKit.label(w.club(f.home).short_name, "H3" if f.hg > f.ag else "")
		hn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hn.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(hn)
		row.add_child(UIKit.crest(w.club(f.home), 30))
		var s := UIKit.label("%d – %d%s" % [f.hg, f.ag, "*" if f.has_penalties() else ""], "H3")
		s.custom_minimum_size.x = 86
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(s)
		row.add_child(UIKit.crest(w.club(f.away), 30))
		var an := UIKit.label(w.club(f.away).short_name, "H3" if f.ag > f.hg else "")
		an.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		an.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(an)
		if f.involves(w.user_club_id):
			for l in [hn, an]:
				l.add_theme_color_override(&"font_color", UIColors.ACCENT)
		var ff := f
		card.add_child(UIKit.tap_row(row, func(): TableRows.fixture_details(w, ff), "CardFlat"))
	return UIKit.card_panel(card)


func _table_card(w: GameWorld, club: Club, f: Fixture) -> Control:
	var card := UIKit.card("Card", 2)
	if f != null and f.stage == Fixture.STAGE_GROUP:
		var cup: Cup = w.season.cups.get(f.comp, null)
		var g: Dictionary = cup.group_of(club.id) if cup != null else {}
		if g.is_empty():
			return null
		card.add_child(UIKit.section("%s · Grupo %s" % [cup.short_name, g["n"]]))
		card.add_child(TableRows.header(true))
		var order := CompetitionManager.sort_table(g["clubs"], g["table"])
		for i in order.size():
			var zone := CompetitionManager.zone_color(CompetitionManager.ZONE_PROMOTION) if i < 2 else Color(0, 0, 0, 0)
			card.add_child(TableRows.table_row(w, g["table"][order[i]], int(order[i]), i + 1, true, zone))
		var cid := cup.id
		card.add_child(UIKit.button("Ver a copa", "GhostButton", func(): UIManager.goto("table", {"cup": cid}), "trophy"))
		return UIKit.card_panel(card)
	if f != null and f.stage == Fixture.STAGE_KO:
		return null
	var league := w.league_of(club.id)
	card.add_child(UIKit.section("Classificação · %s" % league.short_name))
	card.add_child(TableRows.header(true))
	var ids := CompetitionManager.sorted_ids(league)
	for i in ids.size():
		card.add_child(TableRows.row(w, league, int(ids[i]), i + 1, true))
	card.add_child(UIKit.gap(6))
	card.add_child(UIKit.button("Tabela completa e artilharia", "GhostButton", func(): UIManager.goto("table"), "table"))
	return UIKit.card_panel(card)


func _transfers_card(w: GameWorld) -> Control:
	var list: Array = _report.get("transfers", [])
	if list.is_empty():
		return null
	var nat := w.user_nation()
	var sorted: Array = list.filter(func(t: Transfer):
		var fc := w.club(t.from_id)
		var tc := w.club(t.to_id)
		return t.fee >= 20_000_000 or (fc != null and fc.nation == nat) or (tc != null and tc.nation == nat))
	if sorted.is_empty():
		return null
	sorted.sort_custom(func(a: Transfer, b: Transfer): return a.fee > b.fee)
	var card := UIKit.card("Card", 6)
	card.add_child(UIKit.section("Mercado · %s" % Fmt.plural(sorted.size(), "negócio", "negócios")))
	for i in mini(6, sorted.size()):
		var t: Transfer = sorted[i]
		var row := UIKit.hbox(10)
		row.add_child(UIKit.badge(t.overall, 48, 34, 20))
		var col := UIKit.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UIKit.label("%s, %d anos" % [t.player_name, t.age], "H3"))
		var from_name := w.club(t.from_id).short_name if t.from_id >= 0 else "sem clube"
		var to_name := w.club(t.to_id).short_name if t.to_id >= 0 else "sem clube"
		col.add_child(UIKit.label("%s → %s" % [from_name, to_name], "Small"))
		row.add_child(col)
		row.add_child(UIKit.label(Fmt.money(t.fee) if t.fee > 0 else Transfer.KIND_NAMES[t.kind], "H3"))
		var pid := t.player_id
		card.add_child(UIKit.tap_row(row, func():
			if w.player(pid) != null:
				UIManager.push("player", {"id": pid}), "CardFlat"))
	if sorted.size() > 6:
		card.add_child(UIKit.label("e mais %d." % (sorted.size() - 6), "Small"))
	return UIKit.card_panel(card)


func _retiring_card(w: GameWorld) -> Control:
	var list: Array = _report.get("retiring", [])
	if list.is_empty():
		return null
	var sorted: Array = list.filter(func(p: Player): return p.club_id >= 0 and (w.club(p.club_id).nation == w.user_nation() or p.career_apps >= 400))
	if sorted.is_empty():
		return null
	sorted.sort_custom(func(a: Player, b: Player): return a.career_apps > b.career_apps)
	var card := UIKit.card("Card", 6)
	card.add_child(UIKit.section("Anunciaram aposentadoria ao fim da temporada"))
	for i in mini(5, sorted.size()):
		var p: Player = sorted[i]
		var club_name := w.club(p.club_id).short_name if p.club_id >= 0 else "sem clube"
		var pid := p.id
		var row := UIKit.hbox(10)
		row.add_child(UIKit.pos_badge(p.position))
		var l := UIKit.label("%s · %d anos · %s" % [p.display_name(), p.age(w.year), club_name], "", true)
		row.add_child(l)
		card.add_child(UIKit.tap_row(row, func(): UIManager.push("player", {"id": pid}), "CardFlat"))
	return UIKit.card_panel(card)


func _build_footer() -> void:
	var f := footer()
	UIKit.clear(f)
	if GameManager.season_over():
		f.add_child(UIKit.button("FIM DE TEMPORADA", "PrimaryButton", func():
			UIManager.goto("hub")
			UIManager.push("season_end"), "trophy"))
		return
	var row := UIKit.hbox(10)
	var hub := UIKit.button("CONTINUAR", "PrimaryButton", func(): UIManager.goto("hub"), "home")
	hub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(hub)
	var next := UIKit.button("Próximo jogo", "", func():
		UIManager.goto("hub")
		UIManager.push("prematch"), "play")
	next.custom_minimum_size.x = 250
	row.add_child(next)
	f.add_child(row)
