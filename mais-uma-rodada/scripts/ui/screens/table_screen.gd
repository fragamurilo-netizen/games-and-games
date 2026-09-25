extends BaseScreen
## Tabelas do mundo inteiro: ligas de qualquer país (classificação, artilharia, assistências, rodadas)
## e as copas da temporada (grupos, mata-mata e artilharia), além do ranking mundial de clubes.

const LEAGUE_TABS := [["table", "Tabela"], ["scorers", "Artilharia"], ["assists", "Assist."], ["numbers", "Números"], ["rounds", "Rodadas"], ["teams", "Seleções"], ["history", "Campeões"]]
const CUP_TABS := [["groups", "Grupos"], ["ko", "Mata-mata"], ["scorers", "Artilharia"]]

var _league_id := ""
var _cup_id := ""
var _tab := "table"
var _round := -1
## Ranking de clubes: ativo quando _rank_scope != "-" ("" mundo, "C:<confed>", "N:<nação>").
var _rank_scope := "-"
const RANK_SHOW := 50
## Seleção mostrada na aba Seleções: "w" (rodada) ou o índice do mês fechado.
var _xi_pick := "w"
## Visão da classificação: geral, casa, fora ou momento (TableRows.VIEW_*).
var _view := TableRows.VIEW_ALL


func _init() -> void:
	nav_tab = "table"
	screen_title = "Tabelas"


func setup(p: Dictionary) -> void:
	super.setup(p)
	_league_id = p.get("league", "")
	_cup_id = p.get("cup", "")
	_tab = p.get("tab", "groups" if _cup_id != "" else "table")
	_round = -1
	_rank_scope = String(p.get("rank", "-"))


func refresh() -> void:
	var w := world()
	if w == null:
		return
	if _league_id == "" and _cup_id == "":
		_league_id = w.user_league_id()
	if _cup_id != "" and not w.season.cups.has(_cup_id):
		_cup_id = ""
		_league_id = w.user_league_id()
		_tab = "table"
	var c := content()
	UIKit.clear(c)
	if _rank_scope != "-":
		_rank_view(c, w)
		UIManager.refresh_chrome()
		return
	c.add_child(_picker_row(w))
	if _cup_id != "":
		_cup_view(c, w, w.season.cups[_cup_id])
	else:
		_league_view(c, w, w.league(_league_id))
	UIManager.refresh_chrome()


## Competição atual + botão para trocar (qualquer liga do mundo ou copa).
func _picker_row(w: GameWorld) -> Control:
	var row := UIKit.hbox(10)
	if _cup_id != "":
		row.add_child(UIKit.comp_logo(_cup_id, 42))
		var cup: Cup = w.season.cups[_cup_id]
		var l := UIKit.label(cup.name, "H2")
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(l)
		screen_subtitle = "%s · temporada %d" % [cup.name, w.year]
	else:
		var cfg := DatabaseManager.league_cfg(_league_id)
		row.add_child(UIKit.flag(String(cfg.get("nation", "")), 42))
		row.add_child(UIKit.comp_logo(_league_id, 42))
		var l := UIKit.label(String(cfg.get("name", _league_id)), "H2")
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(l)
		screen_subtitle = "%s · temporada %d" % [cfg.get("name", _league_id), w.year]
	row.add_child(UIKit.button("Trocar", "GhostButton", func(): _open_picker(w), "table"))
	var v := UIKit.vbox(8)
	v.add_child(row)
	v.add_child(UIKit.comp_stripe(_cup_id if _cup_id != "" else _league_id))
	# Divisões e copas do país: a liga e a copa nacional ficam a um toque uma da outra.
	var nation := ""
	if _cup_id == "":
		nation = String(DatabaseManager.league_cfg(_league_id).get("nation", ""))
	elif CupManager.is_domestic(_cup_id) or CupManager.is_super(_cup_id):
		nation = String(CupManager.cfg(_cup_id).get("nation", ""))
	if nation != "":
		var gd := ButtonGroup.new()
		var ids := DatabaseManager.leagues_of_nation(nation)
		if ids.size() > 1 or _cup_id != "":
			var drow := UIKit.hbox(8)
			for lid in ids:
				var id: String = lid
				var chip := UIKit.chip(String(DatabaseManager.league_cfg(id).get("short", id)), _cup_id == "" and id == _league_id, gd, func():
					_pick_league(id))
				UIKit.shrink_button(chip)
				drow.add_child(chip)
			v.add_child(drow)
		var crow := UIKit.flow(8)
		for cid in CupManager.cups_of_country(nation):
			var id: String = cid
			if CupManager.is_state(id) or not w.season.cups.has(id):
				continue
			var chip := UIKit.chip(w.season.cups[id].short_name, id == _cup_id, gd, func(): _pick_cup(id))
			crow.add_child(chip)
		if crow.get_child_count() > 0:
			v.add_child(crow)
	var tabs: Array = LEAGUE_TABS
	if _cup_id != "":
		tabs = CUP_TABS.filter(func(t): return t[0] != "groups" or not w.season.cups[_cup_id].groups.is_empty())
	var gt := ButtonGroup.new()
	var trow := UIKit.flow(8) # quebra em duas linhas quando há muitas abas (nada cortado)
	for t in tabs:
		var key: String = t[0]
		var chip := UIKit.chip(t[1], key == _tab, gt, func():
			_tab = key
			refresh())
		chip.add_theme_font_size_override(&"font_size", 18)
		trow.add_child(chip)
	v.add_child(trow)
	return v


# ---------------------------------------------------------------------------
# Seletor de competição
# ---------------------------------------------------------------------------

func _open_picker(w: GameWorld) -> void:
	var v := UIKit.vbox(12)
	v.custom_minimum_size.x = 640
	v.add_child(UIKit.label("Escolha a competição", "Title"))
	# Atalhos: minha liga e copas da temporada
	var mine := UIKit.flow(8)
	var ul := w.user_league_id()
	mine.add_child(UIKit.button(w.league_short(ul), "", func(): _pick_league(ul), "table"))
	for cid in w.season.cups:
		var id: String = cid
		# Estaduais e copas de outros países ficam nas suas seções; aqui só as do seu clube.
		if not CupManager.is_international(id) and not w.season.cups[id].has_club(w.user_club_id):
			continue
		mine.add_child(UIKit.button(w.season.cups[id].short_name, "", func(): _pick_cup(id), "trophy"))
	mine.add_child(UIKit.button("Ranking de clubes", "", func(): _pick_rank(""), "star"))
	v.add_child(UIKit.section("Atalhos"))
	v.add_child(mine)
	var states := UIKit.flow(8)
	for cid in CupManager.state_ids():
		var sid: String = cid
		if w.season.cups.has(sid):
			var inner := UIKit.hbox(8)
			inner.add_child(UIKit.comp_logo(sid, 30))
			inner.add_child(UIKit.label(w.season.cups[sid].short_name, "Small"))
			states.add_child(UIKit.tap_row(inner, func(): _pick_cup(sid), "CardFlat"))
	if states.get_child_count() > 0:
		v.add_child(UIKit.section("Estaduais do Brasil"))
		v.add_child(states)
	var confeds := {"UEFA": "Europa", "CONMEBOL": "América do Sul", "CONCACAF": "América do Norte", "CAF": "África", "AFC": "Ásia"}
	for cf in confeds:
		var flow := UIKit.flow(8)
		for n in DatabaseManager.league_nations():
			if DatabaseManager.nation(n).get("confed", "") != cf:
				continue
			var code: String = n
			var inner := UIKit.hbox(8)
			inner.add_child(UIKit.flag(code, 34))
			inner.add_child(UIKit.label(DatabaseManager.nation_name(code), "Small"))
			flow.add_child(UIKit.tap_row(inner, func(): _pick_league(DatabaseManager.leagues_of_nation(code)[0]), "CardFlat"))
		v.add_child(UIKit.section(confeds[cf]))
		v.add_child(flow)
	v.add_child(UIKit.button("Fechar", "GhostButton", func(): UIManager.close_modal()))
	UIManager.show_modal(v, true)


func _pick_league(id: String) -> void:
	UIManager.close_modal()
	_rank_scope = "-"
	_league_id = id
	_cup_id = ""
	if not LEAGUE_TABS.any(func(t): return t[0] == _tab):
		_tab = "table"
	_round = -1
	refresh()


func _pick_cup(id: String) -> void:
	UIManager.close_modal()
	_rank_scope = "-"
	_cup_id = id
	if not CUP_TABS.any(func(t): return t[0] == _tab):
		_tab = "groups"
	if _tab == "groups" and world().season.cups.has(id) and world().season.cups[id].groups.is_empty():
		_tab = "ko"
	refresh()


# ---------------------------------------------------------------------------
# Ligas
# ---------------------------------------------------------------------------

func _league_view(c: VBoxContainer, w: GameWorld, league: League) -> void:
	if league == null:
		c.add_child(UIKit.label("Liga indisponível.", "Muted"))
		return
	if _round < 0:
		_round = _last_played_round(league)
	match _tab:
		"scorers":
			_ranking(c, w, Player.S_GOALS, "Artilharia")
		"assists":
			_ranking(c, w, Player.S_ASSISTS, "Assistências")
		"rounds":
			_rounds(c, w, league)
		"teams":
			_teams(c, w, league)
		"numbers":
			_numbers(c, w)
		"history":
			_league_history(c, w, league)
		_:
			_table(c, w, league)


## Maiores campeões e a lista temporada a temporada (desde 1990 no mundo padrão), com vice,
## artilheiro e craque das temporadas jogadas no save.
func _league_history(c: VBoxContainer, w: GameWorld, league: League) -> void:
	var key := "L:" + league.id
	var ranking: Array = []
	for cl: Club in w.clubs:
		var n := cl.title_count(key)
		if n > 0:
			ranking.append([cl, n])
	ranking.sort_custom(func(a, b): return int(a[1]) > int(b[1]) or (int(a[1]) == int(b[1]) and (a[0] as Club).reputation > (b[0] as Club).reputation))
	if not ranking.is_empty():
		var card := UIKit.card("Card", 6)
		card.add_child(UIKit.section("Maiores campeões"))
		var top := int(ranking[0][1])
		for e in ranking.slice(0, 10):
			var cl: Club = e[0]
			var row := UIKit.hbox(10)
			row.add_child(UIKit.crest(cl, 34))
			var nl := UIKit.label(cl.short_name, "H3")
			nl.custom_minimum_size.x = 190
			nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			if w.is_user_club(cl.id):
				nl.add_theme_color_override(&"font_color", UIColors.ACCENT)
			row.add_child(nl)
			var bar := UIKit.bar(float(e[1]), float(top), UIColors.ACCENT, 12)
			bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(bar)
			var cnt := UIKit.label(str(int(e[1])), "Stat")
			cnt.custom_minimum_size.x = 48
			cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			row.add_child(cnt)
			var cid := cl.id
			card.add_child(UIKit.tap_row(row, func(): UIManager.push("club", {"id": cid}), "CardFlat"))
		c.add_child(UIKit.card_panel(card))
	var year_cal := String(league.cfg().get("calendar", "")) == "ano"
	var list := UIKit.card("Card", 4)
	list.add_child(UIKit.section("Temporada a temporada"))
	var any := false
	for i in range(w.history.size() - 1, -1, -1):
		var h: Dictionary = w.history[i]
		var lg: Dictionary = h.get("leagues", {}).get(league.id, {})
		if lg.is_empty():
			continue
		var champ := w.club(int(lg.get("champion", -1)))
		if champ == null:
			continue
		any = true
		var y := int(h["y"])
		var row := UIKit.hbox(10)
		var yl := UIKit.label(str(y) if year_cal else "%d/%02d" % [y, (y + 1) % 100], "Mono")
		yl.custom_minimum_size.x = 104
		row.add_child(yl)
		row.add_child(UIKit.crest(champ, 32))
		var col := UIKit.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cn := UIKit.label(champ.short_name, "H3")
		if w.is_user_club(champ.id):
			cn.add_theme_color_override(&"font_color", UIColors.ACCENT)
		col.add_child(cn)
		var extra: Array = []
		var ru := w.club(int(lg.get("runner_up", -1)))
		if ru != null:
			extra.append("vice: %s" % ru.short_name)
		var sc: Dictionary = lg.get("scorer", {})
		if not sc.is_empty():
			extra.append("artilheiro: %s (%d)" % [String(sc.get("name", "")), int(sc.get("goals", 0))])
		var aw: Dictionary = lg.get("awards", {})
		if aw.has("mvp"):
			extra.append("craque: %s" % String(aw["mvp"].get("name", "")))
		if not extra.is_empty():
			col.add_child(UIKit.label(" · ".join(extra), "Small", true))
		row.add_child(col)
		list.add_child(row)
	if not any:
		list.add_child(UIKit.label("Sem campeões registrados antes do início do jogo nesta liga.", "Muted", true))
	c.add_child(UIKit.card_panel(list))


## Líderes da liga nas estatísticas detalhadas (top 5 de cada).
func _numbers(c: VBoxContainer, w: GameWorld) -> void:
	var cats := [[Player.S_SHOTS, "Finalizações"], [Player.S_KEY_PASSES, "Passes decisivos"], [Player.S_DRIBBLES, "Dribles certos"],
		[Player.S_TACKLES, "Desarmes"], [Player.S_INTERCEPTIONS, "Interceptações"], [Player.S_SAVES, "Defesas"], [Player.S_XG, "xG"]]
	for cat in cats:
		var stat: int = cat[0]
		var list := CompetitionManager.player_ranking(w, _league_id, stat, 5)
		if list.is_empty():
			continue
		var card := UIKit.card("Card", 4)
		card.add_child(UIKit.section(String(cat[1])))
		for i in list.size():
			var p: Player = list[i]
			var row := UIKit.hbox(10)
			var rk := UIKit.label(str(i + 1), "H3")
			rk.custom_minimum_size.x = 30
			row.add_child(rk)
			row.add_child(UIKit.crest(w.club(p.club_id), 28))
			var nl := UIKit.label(p.display_name(), "")
			nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			if w.is_user_club(p.club_id):
				nl.add_theme_color_override(&"font_color", UIColors.ACCENT)
			row.add_child(nl)
			row.add_child(UIKit.label(("%.1f" % p.xg()) if stat == Player.S_XG else str(p.stats[stat]), "Stat"))
			var pid := p.id
			card.add_child(UIKit.tap_row(row, func(): UIManager.push("player", {"id": pid}), "CardFlat"))
		c.add_child(UIKit.card_panel(card))


## Seleção da rodada e seleções do mês da liga do usuário, no campinho.
func _teams(c: VBoxContainer, w: GameWorld, league: League) -> void:
	var card := UIKit.card("Card", 8)
	if league.id != w.user_league_id():
		card.add_child(UIKit.label("As seleções da rodada e do mês são da liga do seu clube.", "Muted", true))
		c.add_child(UIKit.card_panel(card))
		return
	var tw: Dictionary = w.stats.get("totw", {})
	var months: Array = w.stats.get("totm_list", [])
	var g := ButtonGroup.new()
	var fl := UIKit.flow(8)
	var has_w := not tw.is_empty() and int(tw.get("y", 0)) == w.year
	if has_w:
		fl.add_child(UIKit.chip("Rodada %d" % int(tw.get("r", 0)), _xi_pick == "w", g, func():
			_xi_pick = "w"
			refresh()))
	for i in months.size():
		var key := str(i)
		fl.add_child(UIKit.chip(WeeklyAwards.month_label(int(months[i]["m"])).capitalize(), _xi_pick == key, g, func():
			_xi_pick = key
			refresh()))
	card.add_child(fl)
	var sel: Dictionary = {}
	var title := ""
	if _xi_pick == "w" and has_w:
		sel = tw
		title = "Seleção da %dª rodada" % int(tw.get("r", 0))
	elif _xi_pick.is_valid_int() and int(_xi_pick) < months.size():
		sel = months[int(_xi_pick)]
		title = "Seleção de %s" % WeeklyAwards.month_label(int(sel["m"]))
	elif has_w:
		sel = tw
		title = "Seleção da %dª rodada" % int(tw.get("r", 0))
	if sel.is_empty():
		card.add_child(UIKit.label("As seleções aparecem depois da primeira rodada.", "Muted", true))
		c.add_child(UIKit.card_panel(card))
		return
	card.add_child(UIKit.section(title))
	card.add_child(XIPitch.make(w, sel.get("ids", []), sel.get("rt", []), int(sel.get("best", -1))))
	var best := w.player(int(sel.get("best", -1)))
	if best != null:
		card.add_child(UIKit.label("★ Craque: %s" % best.display_name(), "Small", true))
	c.add_child(UIKit.card_panel(card))


func _last_played_round(league: League) -> int:
	var last := 0
	for r in league.rounds.size():
		for f: Fixture in league.rounds[r]:
			if f.played:
				last = r
				break
	return last


func _table(c: VBoxContainer, w: GameWorld, league: League) -> void:
	var po := _playoff_card(w, league)
	if po != null:
		c.add_child(po)
	var mine := _user_card(w, league)
	if mine != null:
		c.add_child(mine)
	# Geral, só em casa, só fora, ou o momento de cada um (últimos 5 jogos)
	var gv := ButtonGroup.new()
	var vrow := UIKit.hbox(8)
	for vv in [[TableRows.VIEW_ALL, "Geral"], [TableRows.VIEW_HOME, "Casa"], [TableRows.VIEW_AWAY, "Fora"], [TableRows.VIEW_FORM, "Momento"]]:
		var key: String = vv[0]
		var chip := UIKit.chip(vv[1], key == _view, gv, func():
			_view = key
			refresh())
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.add_theme_font_size_override(&"font_size", 18)
		vrow.add_child(chip)
	c.add_child(vrow)
	var card := UIKit.card("Card", 2)
	var played := league.rounds_played()
	var head := UIKit.hbox(8)
	var rl := UIKit.label(("Rodada %d de %d" % [played, league.rounds.size()]) if played > 0 else "Antes da 1ª rodada", "Caps")
	rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(rl)
	var hint := {TableRows.VIEW_HOME: "Só jogos em casa", TableRows.VIEW_AWAY: "Só jogos fora", TableRows.VIEW_FORM: "Últimos 5 jogos"}
	if hint.has(_view):
		head.add_child(UIKit.colored(String(hint[_view]), UIColors.ACCENT, "Caps"))
	var hp := MarginContainer.new()
	hp.add_theme_constant_override(&"margin_left", TableRows.ROW_PAD)
	hp.add_theme_constant_override(&"margin_right", TableRows.ROW_PAD)
	hp.add_theme_constant_override(&"margin_bottom", 6)
	hp.add_child(head)
	card.add_child(hp)
	card.add_child(TableRows.header(false, _view))
	var side := _view == TableRows.VIEW_HOME or _view == TableRows.VIEW_AWAY
	var t: Dictionary = TableRows.side_table(league, _view) if side else league.table
	var ids: Array = CompetitionManager.sort_table(league.club_ids, t) if side else CompetitionManager.sorted_ids(league)
	var prev: Dictionary = {} if side else TableRows.previous_positions(league)
	# Split: separador no começo de cada grupo da segunda fase
	var starts := {}
	var acc := 0
	var ng := league.phase_groups.size()
	if not side:
		for gi in ng:
			starts[acc] = "Grupo do título" if gi == 0 else ("Grupo do rebaixamento" if gi == ng - 1 else "Grupo intermediário")
			acc += Array(league.phase_groups[gi]).size()
	var last_zone := -1
	for i in ids.size():
		var cid := int(ids[i])
		# Casa/fora: a faixa mostra a zona da classificação geral do clube, não a desta visão.
		var zpos := CompetitionManager.position_of(league, cid) if side else i + 1
		var zone := CompetitionManager.zone_of(league, zpos)
		if starts.has(i):
			card.add_child(UIKit.label(String(starts[i]).to_upper(), "Caps"))
		elif not side and i > 0 and zone != last_zone:
			# Fronteira entre zonas (vaga, acesso, rebaixamento): uma linha fina ajuda a ler o corte.
			card.add_child(_zone_line())
		last_zone = zone
		var move := 0
		if prev.has(cid):
			move = int(prev[cid]) - (i + 1)
		var lg := league
		card.add_child(TableRows.table_row(w, t[cid], cid, i + 1, false, CompetitionManager.zone_color(zone), _view, move,
			func(): _club_sheet(w, lg, cid)))
	c.add_child(UIKit.card_panel(card))
	c.add_child(TableRows.legend(league))
	var tip := "Toque num clube para ver a campanha em casa e fora, os últimos jogos e os próximos."
	if not prev.is_empty():
		tip = "As setas comparam com a rodada anterior. " + tip
	c.add_child(UIKit.label(tip, "Small", true))
	var fdesc := LeagueFormat.describe(league)
	if fdesc != "":
		c.add_child(_format_card(league.id, fdesc))
	_highlights(c, w, league)


func _zone_line() -> Control:
	var m := MarginContainer.new()
	m.add_theme_constant_override(&"margin_left", TableRows.ROW_PAD)
	m.add_theme_constant_override(&"margin_right", TableRows.ROW_PAD)
	var r := ColorRect.new()
	r.color = UIColors.LINE
	r.custom_minimum_size.y = 2
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(r)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return m


## Resumo da campanha do clube do usuário: posição, pontos, forma e a distância para as zonas.
func _user_card(w: GameWorld, league: League) -> Control:
	var uid := w.user_club_id
	if not league.table.has(uid):
		return null
	var r: Dictionary = league.table[uid]
	var pl := int(r["pl"])
	if pl == 0:
		return null
	var ids := CompetitionManager.sorted_ids(league)
	var pos := ids.find(uid) + 1
	var pts := int(r["pts"])
	var card := UIKit.card("CardHighlight", 8)
	var top := UIKit.hbox(14)
	var big := UIKit.colored("%dº" % pos, UIColors.ACCENT, "Huge")
	big.add_theme_font_size_override(&"font_size", 64)
	big.custom_minimum_size.x = 96
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(big)
	var col := UIKit.vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UIKit.label("SUA CAMPANHA", "Caps"))
	col.add_child(UIKit.label("%s · %d pts" % [w.club(uid).short_name, pts], "H3"))
	var sg := int(r["gf"]) - int(r["ga"])
	col.add_child(UIKit.label("%dV %dE %dD · %d gols, saldo %s" % [int(r["w"]), int(r["d"]), int(r["l"]), int(r["gf"]), Fmt.signed(sg)], "Small"))
	top.add_child(col)
	var fcol := UIKit.vbox(4)
	fcol.add_child(UIKit.label("FORMA", "Caps"))
	fcol.add_child(TableRows.form_dots(String(r.get("form", "")), 16))
	fcol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(fcol)
	card.add_child(top)
	# Distâncias que importam: líder, a zona boa mais próxima acima e o rebaixamento.
	var facts := UIKit.flow(8)
	var pts_at := func(p: int) -> int: return int(league.table[ids[clampi(p, 1, ids.size()) - 1]]["pts"])
	if pos == 1:
		if ids.size() > 1:
			facts.add_child(UIKit.pill("%s à frente do 2º" % Fmt.plural(pts - int(pts_at.call(2)), "pt", "pts"), UIColors.GREEN))
	else:
		facts.add_child(UIKit.pill("%s atrás do líder" % Fmt.plural(int(pts_at.call(1)) - pts, "pt", "pts"), UIColors.MUTED))
	var my_zone := CompetitionManager.zone_of(league, pos)
	if my_zone == CompetitionManager.ZONE_NONE or my_zone == CompetitionManager.ZONE_RELEGATION:
		for q in range(pos - 1, 1, -1):
			var z := CompetitionManager.zone_of(league, q)
			if z != CompetitionManager.ZONE_NONE and z != CompetitionManager.ZONE_RELEGATION:
				facts.add_child(UIKit.pill("%s para %s (%dº)" % [Fmt.plural(int(pts_at.call(q)) - pts, "pt", "pts"), _zone_name(league, q, z), q],
					CompetitionManager.zone_color(z)))
				break
	var down := league.relegated_count()
	if down > 0 and ids.size() > down:
		var first_down := ids.size() - down + 1
		if pos < first_down:
			facts.add_child(UIKit.pill("%s acima do Z%d" % [Fmt.plural(pts - int(pts_at.call(first_down)), "pt", "pts"), down], UIColors.MUTED))
		else:
			facts.add_child(UIKit.pill("%s para sair do Z%d" % [Fmt.plural(int(pts_at.call(first_down - 1)) - pts, "pt", "pts"), down], UIColors.RED))
	var left := CompetitionManager.remaining_rounds(league, uid)
	if left > 0:
		facts.add_child(UIKit.pill("Faltam %s" % Fmt.plural(left, "jogo", "jogos"), UIColors.MUTED))
	card.add_child(facts)
	return UIKit.card_panel(card)


func _zone_name(league: League, pos: int, zone: int) -> String:
	match zone:
		CompetitionManager.ZONE_TITLE:
			return "a liderança"
		CompetitionManager.ZONE_PROMOTION:
			return "o acesso"
	var cup := CupManager.cup_for_position(league, pos)
	return ("a " + CupManager.cup_short(cup)) if cup != "" else "a zona"


## Ficha rápida do clube na liga: campanha geral, em casa e fora, últimos e próximos jogos.
func _club_sheet(w: GameWorld, league: League, cid: int) -> void:
	var cl := w.club(cid)
	var v := UIKit.vbox(12)
	v.custom_minimum_size.x = 640
	var head := UIKit.hbox(14)
	head.add_child(UIKit.crest(cl, 64))
	var hc := UIKit.vbox(2)
	hc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_l := UIKit.label(cl.name, "Title", true)
	hc.add_child(name_l)
	var pos := CompetitionManager.position_of(league, cid)
	var r: Dictionary = league.table[cid]
	hc.add_child(UIKit.label("%dº no %s · %d pts" % [pos, league.short_name, int(r["pts"])], "Small"))
	head.add_child(hc)
	v.add_child(head)
	# Campanha: geral, casa e fora lado a lado
	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override(&"h_separation", 10)
	grid.add_theme_constant_override(&"v_separation", 6)
	for h in ["", "J", "V", "E", "D", "GP", "GC", "PTS"]:
		var hl := UIKit.label(h, "Caps")
		hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if h != "" else HORIZONTAL_ALIGNMENT_LEFT
		if h == "":
			hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		else:
			hl.custom_minimum_size.x = 48
		grid.add_child(hl)
	var rows := [["Geral", r], ["Casa", TableRows.side_table(league, TableRows.VIEW_HOME)[cid]], ["Fora", TableRows.side_table(league, TableRows.VIEW_AWAY)[cid]]]
	for rr in rows:
		var d: Dictionary = rr[1]
		grid.add_child(UIKit.label(String(rr[0]), "Small"))
		for k in ["pl", "w", "d", "l", "gf", "ga", "pts"]:
			var l := UIKit.label(str(d[k]), "H3" if k == "pts" else "")
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			if k != "pts":
				l.add_theme_color_override(&"font_color", UIColors.MUTED)
			grid.add_child(l)
	v.add_child(grid)
	var pl := int(r["pl"])
	if pl > 0:
		var kv := UIKit.flow(8)
		kv.add_child(UIKit.pill("Aproveitamento %d%%" % roundi(100.0 * int(r["pts"]) / (3.0 * pl)), UIColors.MUTED))
		kv.add_child(UIKit.pill("%.1f gols por jogo" % (float(r["gf"]) / pl), UIColors.MUTED))
		kv.add_child(UIKit.pill("%.1f sofridos por jogo" % (float(r["ga"]) / pl), UIColors.MUTED))
		v.add_child(kv)
	# Últimos 5 e próximos 3 jogos na liga
	var past: Array = []
	var next: Array = []
	for rnd in league.rounds:
		for f: Fixture in rnd:
			if f.involves(cid):
				if f.played:
					past.append(f)
				elif next.size() < 3:
					next.append(f)
	if not past.is_empty():
		v.add_child(UIKit.section("Últimos jogos"))
		for f in past.slice(maxi(0, past.size() - 5)):
			v.add_child(_sheet_game(w, f, cid))
	if not next.is_empty():
		v.add_child(UIKit.section("Próximos jogos"))
		for f in next:
			v.add_child(_sheet_game(w, f, cid))
	var top: Player = null
	for p in w.squad(cl):
		if top == null or p.stats[Player.S_GOALS] > top.stats[Player.S_GOALS]:
			top = p
	if top != null and top.stats[Player.S_GOALS] > 0:
		v.add_child(UIKit.kv("Artilheiro do clube", "%s (%d)" % [top.display_name(), top.stats[Player.S_GOALS]]))
	var btns := UIKit.hbox(10)
	var go := UIKit.button("Ver clube", "PrimaryButton", func():
		UIManager.close_modal()
		if w.is_user_club(cid):
			UIManager.goto("club")
		else:
			UIManager.push("club", {"id": cid}), "club")
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btns.add_child(go)
	var close := UIKit.button("Fechar", "GhostButton", func(): UIManager.close_modal())
	close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btns.add_child(close)
	v.add_child(btns)
	UIManager.show_modal(v, true)


## Jogo na ficha do clube: resultado (V/E/D), adversário, mando e placar.
func _sheet_game(w: GameWorld, f: Fixture, cid: int) -> Control:
	var home := f.home == cid
	var opp := w.club(f.away if home else f.home)
	var row := UIKit.hbox(10)
	if f.played:
		var gf := f.hg if home else f.ag
		var ga := f.ag if home else f.hg
		var res := "V" if gf > ga else ("E" if gf == ga else "D")
		var badge := UIKit.pill(res, {"V": UIColors.GREEN, "E": UIColors.MUTED, "D": UIColors.RED}[res], 16)
		badge.custom_minimum_size.x = 44
		row.add_child(badge)
	else:
		var dl := UIKit.label(w.season.date_label(f.slot, false), "Small")
		dl.custom_minimum_size.x = 90
		row.add_child(dl)
	row.add_child(UIKit.crest(opp, 28))
	var n := UIKit.label(("%s (casa)" if home else "%s (fora)") % opp.short_name, "")
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(n)
	if f.played:
		row.add_child(UIKit.label("%d – %d" % [f.hg, f.ag], "H3"))
	return row


## Números da liga: ataque, defesa, mandantes, visitantes, momento, média de gols e campeões.
func _highlights(c: VBoxContainer, w: GameWorld, league: League) -> void:
	var info := UIKit.card("Card", 6)
	info.add_child(UIKit.section("Destaques"))
	var att := CompetitionManager.best_attack(league)
	var dfn := CompetitionManager.best_defense(league)
	if att >= 0 and int(league.table[att]["pl"]) > 0:
		info.add_child(UIKit.kv("Melhor ataque", "%s (%d gols)" % [w.club(att).short_name, int(league.table[att]["gf"])]))
	if dfn >= 0 and int(league.table[dfn]["pl"]) > 0:
		info.add_child(UIKit.kv("Melhor defesa", "%s (%d sofridos)" % [w.club(dfn).short_name, int(league.table[dfn]["ga"])]))
	var games := 0
	var goals := 0
	for cid in league.table:
		games += int(league.table[cid]["pl"])
		goals += int(league.table[cid]["gf"])
	if games > 0:
		for side in [[TableRows.VIEW_HOME, "Melhor mandante"], [TableRows.VIEW_AWAY, "Melhor visitante"]]:
			var st := TableRows.side_table(league, side[0])
			var best := int(CompetitionManager.sort_table(league.club_ids, st)[0])
			var b: Dictionary = st[best]
			if int(b["pl"]) > 0:
				info.add_child(UIKit.kv(side[1], "%s (%d pts em %d)" % [w.club(best).short_name, int(b["pts"]), int(b["pl"])]))
		# Melhor momento: mais pontos nos últimos 5 (desempate pelo saldo geral)
		var hot := -1
		var hot_pts := -1
		for cid in league.club_ids:
			var fp := 0
			for ch in String(league.table[cid].get("form", "")):
				fp += 3 if ch == "V" else (1 if ch == "E" else 0)
			if fp > hot_pts:
				hot_pts = fp
				hot = int(cid)
		if hot >= 0 and hot_pts > 0:
			info.add_child(UIKit.kv("Melhor momento", "%s (%d de %d pts)" % [w.club(hot).short_name, hot_pts, 3 * String(league.table[hot]["form"]).length()]))
		info.add_child(UIKit.kv("Média de gols", "%.2f por jogo (%d gols)" % [2.0 * goals / games, goals]))
	var top := CompetitionManager.player_ranking(w, _league_id, Player.S_GOALS, 1)
	if not top.is_empty():
		var p: Player = top[0]
		info.add_child(UIKit.kv("Artilheiro", "%s (%d)" % [p.display_name(), p.stats[Player.S_GOALS]]))
	# Últimos campeões
	var champs: Array = []
	for i in range(w.history.size() - 1, -1, -1):
		var h: Dictionary = w.history[i]
		var hl: Dictionary = h.get("leagues", {}).get(_league_id, {})
		if not hl.is_empty():
			var cl := w.club(int(hl["champion"]))
			if cl != null:
				champs.append("%d %s" % [int(h["y"]), cl.short_name])
		if champs.size() >= 3:
			break
	if not champs.is_empty():
		info.add_child(UIKit.kv("Últimos campeões", ", ".join(champs)))
	if info.get_child_count() > 1:
		c.add_child(UIKit.card_panel(info))


func _ranking(c: VBoxContainer, w: GameWorld, stat: int, title: String) -> void:
	var card := UIKit.card("Card", 4)
	card.add_child(UIKit.section(title))
	var list := CompetitionManager.player_ranking(w, _league_id, stat, 25)
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
	c.add_child(UIKit.label("Empate: fica à frente quem jogou menos minutos.", "Small", true))


func _rounds(c: VBoxContainer, w: GameWorld, league: League) -> void:
	_round = clampi(_round, 0, league.rounds.size() - 1)
	var nav := UIKit.hbox(10)
	nav.add_child(UIKit.icon_button("back", func():
		_round = maxi(0, _round - 1)
		refresh()))
	var t := UIKit.label("Rodada %d de %d · %s" % [_round + 1, league.rounds.size(), w.season.date_label(league.round_slots[_round], false)], "H2")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_child(t)
	nav.add_child(UIKit.icon_button("play", func():
		_round = mini(league.rounds.size() - 1, _round + 1)
		refresh()))
	c.add_child(nav)
	var card := UIKit.card("Card", 4)
	for f: Fixture in league.fixtures_of_round(_round):
		card.add_child(_fixture_row(w, f))
	c.add_child(UIKit.card_panel(card))


## Linha de jogo (mandante, placar, visitante); toque abre os detalhes.
func _fixture_row(w: GameWorld, f: Fixture) -> Control:
	var row := UIKit.hbox(8)
	var hn := UIKit.label(w.club(f.home).short_name, "H3" if f.played and f.hg > f.ag else "")
	hn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hn.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(hn)
	row.add_child(UIKit.crest(w.club(f.home), 30))
	var score := ("%d – %d" % [f.hg, f.ag]) if f.played else "×"
	if f.played and f.has_penalties():
		score += "*"
	var s := UIKit.label(score, "H3")
	s.custom_minimum_size.x = 86
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
	return UIKit.tap_row(row, func(): TableRows.fixture_details(w, ff), "CardFlat")


# ---------------------------------------------------------------------------
# Copas
# ---------------------------------------------------------------------------

func _cup_view(c: VBoxContainer, w: GameWorld, cup: Cup) -> void:
	if cup.champion >= 0:
		var champ := UIKit.card("CardHighlight", 6)
		var row := UIKit.hbox(12)
		row.add_child(UIKit.crest(w.club(cup.champion), 72))
		var col := UIKit.vbox(2)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UIKit.label("CAMPEÃO %d" % w.year, "Caps"))
		col.add_child(UIKit.label(w.club(cup.champion).name, "H2", true))
		if cup.runner_up >= 0:
			col.add_child(UIKit.label("Vice: %s" % w.club(cup.runner_up).short_name, "Small"))
		row.add_child(col)
		champ.add_child(row)
		c.add_child(UIKit.card_panel(champ))
	match _tab:
		"ko":
			_cup_ko(c, w, cup)
		"scorers":
			_cup_scorers(c, w, cup)
		_:
			if cup.groups.is_empty():
				_cup_ko(c, w, cup)
			else:
				_cup_groups(c, w, cup)
	var fmt := String(CupManager.cfg(cup.id).get("format", ""))
	if fmt != "":
		c.add_child(_format_card(cup.id, fmt))


## Chaveamento dos playoffs de uma liga (quando já começaram).
func _playoff_card(w: GameWorld, league: League) -> Control:
	if league.po.is_empty() or Array(league.po.get("ties", [])).is_empty():
		return null
	var card := UIKit.card("CardHighlight", 6)
	var promo := LeagueFormat.kind(league) == "promo"
	card.add_child(UIKit.section("Playoffs de acesso" if promo else "Playoffs"))
	var ko: Array = LeagueFormat.cfg(league).get("ko", [])
	var champ := int(league.po.get("champ", -1))
	if champ >= 0:
		var cr := UIKit.hbox(10)
		cr.add_child(UIKit.crest(w.club(champ), 48))
		cr.add_child(UIKit.label(("%s conquistou o acesso" if promo else "Campeão: %s") % w.club(champ).name, "H3", true))
		card.add_child(cr)
	var last_r := -1
	for t in league.po["ties"]:
		var r := int(t["r"])
		if r != last_r:
			last_r = r
			card.add_child(UIKit.label(String(LeagueFormat.KO_NAMES.get(ko[clampi(r, 0, ko.size() - 1)], "Fase")).to_upper(), "Caps"))
		var row := UIKit.hbox(8)
		var a := w.club(int(t["a"]))
		var b := w.club(int(t["b"]))
		var won := int(t["w"])
		for cl in [a, b]:
			row.add_child(UIKit.crest(cl, 28))
			var nl := UIKit.label(cl.short_name, "H3" if won == cl.id else "")
			nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			if w.is_user_club(cl.id):
				nl.add_theme_color_override(&"font_color", UIColors.ACCENT)
			row.add_child(nl)
		var fx := LeagueFormat._tie_fixtures(league, t)
		var ga := 0
		var gb := 0
		var played := false
		for g: Fixture in fx:
			if not g.played:
				continue
			played = true
			if g.home == a.id:
				ga += g.hg
				gb += g.ag
			else:
				ga += g.ag
				gb += g.hg
		row.add_child(UIKit.label("%d x %d" % [ga, gb] if played else "—", "Stat"))
		card.add_child(row)
	return UIKit.card_panel(card)


## Regulamento da competição (formato real) com o logo.
func _format_card(comp: String, text: String) -> Control:
	var card := UIKit.card("Card", 6)
	var row := UIKit.hbox(12)
	row.add_child(UIKit.comp_logo(comp, 56))
	var col := UIKit.vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UIKit.label("Regulamento", "Caps"))
	col.add_child(UIKit.label(text, "Small", true))
	row.add_child(col)
	card.add_child(row)
	return UIKit.card_panel(card)


func _cup_groups(c: VBoxContainer, w: GameWorld, cup: Cup) -> void:
	# Estaduais: avançam os líderes de grupo e os melhores dos demais (não os 2 de cada grupo).
	var state_q: Array = CupManager.state_qualified(cup) if CupManager.is_state(cup.id) else []
	if CupManager.is_state(cup.id):
		var n := int(CupManager.cfg(cup.id).get("qualify", 4))
		c.add_child(UIKit.label(("Os %d primeiros vão à semifinal." if cup.groups.size() == 1 else "Avançam os líderes dos grupos e os melhores entre os demais, até completar %d semifinalistas.") % n, "Small", true))
	for g in cup.groups:
		var card := UIKit.card("Card", 2)
		card.add_child(UIKit.section("Grupo %s" % g["n"]))
		card.add_child(TableRows.header(false))
		var order := CompetitionManager.sort_table(g["clubs"], g["table"])
		for i in order.size():
			var qualifies: bool = state_q.has(order[i]) if CupManager.is_state(cup.id) else i < 2
			var zone := CompetitionManager.zone_color(CompetitionManager.ZONE_PROMOTION) if qualifies else Color(0, 0, 0, 0)
			card.add_child(TableRows.table_row(w, g["table"][order[i]], int(order[i]), i + 1, false, zone))
		# Jogos do grupo com o usuário (ou os próximos) ficam a um toque
		var mine: Array = []
		for f: Fixture in cup.fixtures:
			if f.stage == Fixture.STAGE_GROUP and g["clubs"].has(f.home) and f.involves(w.user_club_id):
				mine.append(f)
		for f in mine:
			card.add_child(_fixture_row(w, f))
		c.add_child(UIKit.card_panel(card))
	c.add_child(UIKit.label("Os dois primeiros de cada grupo avançam ao mata-mata.", "Small", true))


func _cup_ko(c: VBoxContainer, w: GameWorld, cup: Cup) -> void:
	if cup.ties.is_empty():
		var card := UIKit.card("Card", 6)
		card.add_child(UIKit.label("O mata-mata é sorteado depois da fase de grupos.", "Muted", true))
		c.add_child(UIKit.card_panel(card))
		return
	for r in cup.round_names.size():
		var ties := cup.ties_of_round(r)
		if ties.is_empty():
			continue
		var card := UIKit.card("Card", 4)
		card.add_child(UIKit.section(String(cup.round_names[r])))
		for t in ties:
			card.add_child(_tie_row(w, cup, t))
		c.add_child(UIKit.card_panel(card))


func _tie_row(w: GameWorld, cup: Cup, t: Dictionary) -> Control:
	var a := w.club(int(t["a"]))
	var b := w.club(int(t["b"]))
	var win := int(t["w"])
	var row := UIKit.hbox(8)
	var an := UIKit.label(a.short_name, "H3" if win == a.id else "")
	an.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	an.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	an.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(an)
	row.add_child(UIKit.crest(a, 30))
	var summary := CupManager.tie_summary(cup, t)
	var s := UIKit.label(summary if summary != "" else "×", "Small" if summary.length() > 6 else "H3")
	s.custom_minimum_size.x = 120
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(s)
	row.add_child(UIKit.crest(b, 30))
	var bn := UIKit.label(b.short_name, "H3" if win == b.id else "")
	bn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(bn)
	if a.id == w.user_club_id or b.id == w.user_club_id:
		an.add_theme_color_override(&"font_color", UIColors.ACCENT)
		bn.add_theme_color_override(&"font_color", UIColors.ACCENT)
	var fx := cup.fixtures_of_tie(t)
	return UIKit.tap_row(row, func():
		if not fx.is_empty():
			TableRows.fixture_details(w, fx[fx.size() - 1] if fx[fx.size() - 1].played else fx[0]), "CardFlat")


func _cup_scorers(c: VBoxContainer, w: GameWorld, cup: Cup) -> void:
	var card := UIKit.card("Card", 4)
	card.add_child(UIKit.section("Artilharia"))
	var list := CupManager.scorers(w, cup.id, 25)
	if list.is_empty():
		card.add_child(UIKit.label("Ninguém marcou ainda.", "Muted"))
	var rank := 0
	var last_v := -1
	for i in list.size():
		var p: Player = list[i]
		var st: PackedInt32Array = p.cup_stats[cup.id]
		var v := st[Player.C_GOALS]
		if v != last_v:
			rank = i + 1
			last_v = v
		card.add_child(TableRows.ranking_row(w, p, rank, str(v), "%s · %s" % [Pos.code(p.position), Fmt.plural(st[Player.C_APPS], "jogo", "jogos")]))
	c.add_child(UIKit.card_panel(card))


# ---------------------------------------------------------------------------
# Ranking mundial de clubes
# ---------------------------------------------------------------------------

func _pick_rank(scope: String) -> void:
	UIManager.close_modal()
	_rank_scope = scope
	refresh()


func _rank_view(c: VBoxContainer, w: GameWorld) -> void:
	screen_subtitle = "Ranking de clubes · %d" % w.year
	var head := UIKit.hbox(10)
	head.add_child(UIKit.icon_rect("star", 36, UIColors.ACCENT))
	var l := UIKit.label("Ranking de clubes", "H2")
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(l)
	head.add_child(UIKit.button("Trocar", "GhostButton", func(): _open_picker(w), "table"))
	c.add_child(head)
	var u := w.user_club() if w.has_user() else null
	var scopes: Array = [["", "Mundo"]]
	if u != null:
		var confed := String(DatabaseManager.nation(u.nation).get("confed", ""))
		scopes.append(["C:" + confed, {"UEFA": "Europa", "CONMEBOL": "Am. do Sul", "CONCACAF": "Am. do Norte", "CAF": "África", "AFC": "Ásia"}.get(confed, confed)])
		scopes.append(["N:" + u.nation, DatabaseManager.nation_name(u.nation)])
	var g := ButtonGroup.new()
	var trow := UIKit.hbox(8)
	for sc in scopes:
		var key: String = sc[0]
		var chip := UIKit.chip(sc[1], key == _rank_scope, g, func():
			_rank_scope = key
			refresh())
		UIKit.shrink_button(chip)
		chip.add_theme_font_size_override(&"font_size", 18)
		trow.add_child(chip)
	c.add_child(trow)
	var table := ClubRanking.table(w, _rank_scope)
	var card := UIKit.card("Card", 2)
	var user_shown := false
	for i in mini(RANK_SHOW, table.size()):
		card.add_child(_rank_row(w, table[i], i + 1))
		if u != null and int(table[i]["id"]) == u.id:
			user_shown = true
	if u != null and not user_shown:
		for i in table.size():
			if int(table[i]["id"]) == u.id:
				card.add_child(UIKit.separator())
				card.add_child(_rank_row(w, table[i], i + 1))
				break
	c.add_child(UIKit.card_panel(card))
	c.add_child(UIKit.label("Soma das últimas %d temporadas, contando a atual: posição na liga (pesa mais nas ligas fortes) e campanhas continentais e no Mundial. A seta compara com o ranking ao fim da temporada passada." % ClubRanking.SEASONS, "Small", true))


func _rank_row(w: GameWorld, entry: Dictionary, pos: int) -> Control:
	var cl := w.club(int(entry["id"]))
	var is_user := w.is_user_club(cl.id)
	var h := UIKit.hbox(8)
	var pl := UIKit.label(str(pos), "H3")
	pl.custom_minimum_size.x = 44
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(pl)
	h.add_child(UIKit.crest(cl, 32))
	var col := UIKit.vbox(0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var n := UIKit.label(cl.short_name, "H3")
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if is_user:
		n.add_theme_color_override(&"font_color", UIColors.ACCENT)
	col.add_child(n)
	var sub := UIKit.hbox(6)
	sub.add_child(UIKit.flag(cl.nation, 22))
	sub.add_child(UIKit.label(w.league_short(cl.league_id), "Small"))
	col.add_child(sub)
	h.add_child(col)
	# Movimento em relação ao fim da temporada passada (só faz sentido no ranking mundial)
	if _rank_scope == "" and cl.rank_prev > 0 and cl.rank_prev != pos:
		var up := cl.rank_prev > pos
		h.add_child(UIKit.colored(("▲" if up else "▼") + str(absi(cl.rank_prev - pos)), UIColors.GREEN if up else UIColors.RED, "Small"))
	var v := UIKit.label("%.1f" % float(entry["pts"]), "Stat")
	v.custom_minimum_size.x = 96
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(v)
	var cid := cl.id
	return UIKit.tap_row(h, func():
		if w.is_user_club(cid):
			UIManager.goto("club")
		else:
			UIManager.push("club", {"id": cid}), "CardFlat")
