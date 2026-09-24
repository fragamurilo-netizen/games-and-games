extends BaseScreen
## Tabelas: classificação, artilharia, assistências e rodadas das quatro divisões.

const TABS := [["table", "Tabela"], ["scorers", "Artilharia"], ["assists", "Assistências"], ["rounds", "Rodadas"]]

var _div := -1
var _tab := "table"
var _round := -1


func _init() -> void:
	nav_tab = "table"
	screen_title = "Tabelas"


func setup(p: Dictionary) -> void:
	super.setup(p)
	_div = int(p.get("div", -1))
	_tab = p.get("tab", "table")


func refresh() -> void:
	var w := world()
	if w == null:
		return
	if _div < 0:
		_div = w.user_club().division
	var league: League = w.season.leagues[_div]
	if _round < 0:
		_round = _last_played_round(league)
	screen_subtitle = "%s · temporada %d" % [w.division_name(_div), w.year]
	UIManager.refresh_chrome()
	var c := content()
	UIKit.clear(c)
	# Divisões
	var gd := ButtonGroup.new()
	var drow := UIKit.hbox(8)
	for d in w.season.leagues.size():
		var dd := d
		var chip := UIKit.chip(w.division_short(d), d == _div, gd, func():
			_div = dd
			_round = -1
			refresh())
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		drow.add_child(chip)
	c.add_child(drow)
	# Abas
	var gt := ButtonGroup.new()
	var trow := UIKit.hbox(8)
	for t in TABS:
		var key: String = t[0]
		var chip := UIKit.chip(t[1], key == _tab, gt, func():
			_tab = key
			refresh())
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.add_theme_font_size_override(&"font_size", 18)
		trow.add_child(chip)
	c.add_child(trow)
	match _tab:
		"scorers":
			_ranking(c, w, Player.S_GOALS, "gols", "Artilharia")
		"assists":
			_ranking(c, w, Player.S_ASSISTS, "assist.", "Assistências")
		"rounds":
			_rounds(c, w, league)
		_:
			_table(c, w, league)


func _last_played_round(league: League) -> int:
	var last := 0
	for r in league.rounds.size():
		for f: Fixture in league.rounds[r]:
			if f.played:
				last = r
				break
	return last


func _table(c: VBoxContainer, w: GameWorld, league: League) -> void:
	var card := UIKit.card("Card", 2)
	card.add_child(TableRows.header(false))
	var ids := CompetitionManager.sorted_ids(league)
	for i in ids.size():
		card.add_child(TableRows.row(w, league, int(ids[i]), i + 1, false))
	c.add_child(UIKit.card_panel(card))
	c.add_child(TableRows.legend(league))
	# Curiosidades da divisão
	var info := UIKit.card("Card", 6)
	info.add_child(UIKit.section("Destaques"))
	var att := CompetitionManager.best_attack(league)
	var dfn := CompetitionManager.best_defense(league)
	if att >= 0 and int(league.table[att]["pl"]) > 0:
		info.add_child(UIKit.kv("Melhor ataque", "%s (%d gols)" % [w.club(att).short_name, int(league.table[att]["gf"])]))
	if dfn >= 0 and int(league.table[dfn]["pl"]) > 0:
		info.add_child(UIKit.kv("Melhor defesa", "%s (%d sofridos)" % [w.club(dfn).short_name, int(league.table[dfn]["ga"])]))
	var top := CompetitionManager.player_ranking(w, _div, Player.S_GOALS, 1)
	if not top.is_empty():
		var p: Player = top[0]
		info.add_child(UIKit.kv("Artilheiro", "%s (%d)" % [p.display_name(), p.stats[Player.S_GOALS]]))
	if info.get_child_count() > 1:
		c.add_child(UIKit.card_panel(info))


func _ranking(c: VBoxContainer, w: GameWorld, stat: int, unit: String, title: String) -> void:
	var card := UIKit.card("Card", 4)
	card.add_child(UIKit.section(title))
	var list := CompetitionManager.player_ranking(w, _div, stat, 25)
	if list.is_empty():
		card.add_child(UIKit.label("Ninguém marcou ainda nesta temporada.", "Muted"))
	var rank := 0
	var last_v := -1
	for i in list.size():
		var p: Player = list[i]
		var v: int = p.stats[stat]
		if v != last_v:
			rank = i + 1
			last_v = v
		var apps: int = p.stats[Player.S_APPS]
		card.add_child(TableRows.ranking_row(w, p, rank, str(v), "%s · %s" % [Pos.code(p.position), Fmt.plural(apps, "jogo", "jogos")]))
	c.add_child(UIKit.card_panel(card))
	c.add_child(UIKit.label("Toque em um jogador para ver o perfil. Em caso de empate, fica à frente quem jogou menos minutos.", "Small", true))


func _rounds(c: VBoxContainer, w: GameWorld, league: League) -> void:
	_round = clampi(_round, 0, league.rounds.size() - 1)
	var nav := UIKit.hbox(10)
	var prev := UIKit.icon_button("back", func():
		_round = maxi(0, _round - 1)
		refresh())
	nav.add_child(prev)
	var t := UIKit.label("Rodada %d de %d" % [_round + 1, league.rounds.size()], "H2")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_child(t)
	var nxt := UIKit.icon_button("play", func():
		_round = mini(league.rounds.size() - 1, _round + 1)
		refresh())
	nav.add_child(nxt)
	c.add_child(nav)
	var card := UIKit.card("Card", 4)
	for f: Fixture in league.fixtures_of_round(_round):
		var row := UIKit.hbox(8)
		var hn := UIKit.label(w.club(f.home).short_name, "H3" if f.played and f.hg > f.ag else "")
		hn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hn.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(hn)
		row.add_child(UIKit.crest(w.club(f.home), 30))
		var s := UIKit.label("%d – %d" % [f.hg, f.ag] if f.played else "×", "H3")
		s.custom_minimum_size.x = 80
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if not f.played:
			s.add_theme_color_override(&"font_color", UIColors.DIM)
		row.add_child(s)
		row.add_child(UIKit.crest(w.club(f.away), 30))
		var an := UIKit.label(w.club(f.away).short_name, "H3" if f.played and f.ag > f.hg else "")
		an.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		an.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(an)
		if f.involves(w.user_club_id):
			hn.add_theme_color_override(&"font_color", UIColors.ACCENT)
			an.add_theme_color_override(&"font_color", UIColors.ACCENT)
		var ff := f
		card.add_child(UIKit.tap_row(row, func(): _fixture_details(w, ff), "CardFlat"))
	c.add_child(UIKit.card_panel(card))


func _fixture_details(w: GameWorld, f: Fixture) -> void:
	var v := UIKit.vbox(12)
	v.custom_minimum_size.x = 600
	var home := w.club(f.home)
	var away := w.club(f.away)
	var t := UIKit.label("%s %s %s" % [home.short_name, ("%d – %d" % [f.hg, f.ag]) if f.played else "×", away.short_name], "Title", true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	v.add_child(UIKit.label("%s · %s" % [home.stadium, home.city], "Small"))
	if not f.played:
		var lh: Dictionary = w.league_of(home.id).table[home.id]
		var la: Dictionary = w.league_of(away.id).table[away.id]
		v.add_child(UIKit.kv("Campanha de %s" % home.short_name, "%d pts, %dV %dE %dD" % [lh["pts"], lh["w"], lh["d"], lh["l"]]))
		v.add_child(UIKit.kv("Campanha de %s" % away.short_name, "%d pts, %dV %dE %dD" % [la["pts"], la["w"], la["d"], la["l"]]))
		if MatchEngine.is_derby(w, f.home, f.away):
			v.add_child(UIKit.colored("Clássico regional.", UIColors.RED, "H3"))
	else:
		for side in 2:
			for g in f.goals:
				if int(g[1]) != side:
					continue
				var p := w.player(int(g[2]))
				var txt := "%s  %s" % [Fmt.minute(int(g[0]), int(g[4]) if g.size() > 4 else 0), p.display_name() if p != null else "?"]
				if int(g[3]) == Fixture.GOAL_PENALTY:
					txt += " (p)"
				elif int(g[3]) == Fixture.GOAL_OWN:
					txt += " (contra)"
				var l := UIKit.label(txt, "")
				l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if side == 0 else HORIZONTAL_ALIGNMENT_RIGHT
				v.add_child(l)
		var motm := w.player(f.motm)
		if motm != null:
			v.add_child(UIKit.kv("Craque do jogo", motm.display_name(), UIColors.ACCENT))
		if f.attendance > 0:
			v.add_child(UIKit.kv("Público", Fmt.thousands(f.attendance)))
	v.add_child(UIKit.button("Fechar", "GhostButton", func(): UIManager.close_modal()))
	UIManager.show_modal(v)
