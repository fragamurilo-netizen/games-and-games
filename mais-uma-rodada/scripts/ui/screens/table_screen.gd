extends BaseScreen
## Tabelas do mundo inteiro: ligas de qualquer país (classificação, artilharia, assistências, rodadas)
## e as copas da temporada (grupos, mata-mata e artilharia), além do ranking mundial de clubes.

const LEAGUE_TABS := [["table", "Tabela"], ["scorers", "Artilharia"], ["assists", "Assist."], ["rounds", "Rodadas"]]
const CUP_TABS := [["groups", "Grupos"], ["ko", "Mata-mata"], ["scorers", "Artilharia"]]

var _league_id := ""
var _cup_id := ""
var _tab := "table"
var _round := -1
## Ranking de clubes: ativo quando _rank_scope != "-" ("" mundo, "C:<confed>", "N:<nação>").
var _rank_scope := "-"
const RANK_SHOW := 50


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
	# Divisões do país (liga) ou abas (copa)
	if _cup_id == "":
		var nation: String = DatabaseManager.league_cfg(_league_id).get("nation", "")
		var ids := DatabaseManager.leagues_of_nation(nation)
		if ids.size() > 1:
			var gd := ButtonGroup.new()
			var drow := UIKit.hbox(8)
			for lid in ids:
				var id: String = lid
				var chip := UIKit.chip(String(DatabaseManager.league_cfg(id).get("short", id)), id == _league_id, gd, func():
					_league_id = id
					_round = -1
					refresh())
				UIKit.shrink_button(chip)
				drow.add_child(chip)
			v.add_child(drow)
	var tabs: Array = CUP_TABS if _cup_id != "" else LEAGUE_TABS
	var gt := ButtonGroup.new()
	var trow := UIKit.hbox(8)
	for t in tabs:
		var key: String = t[0]
		var chip := UIKit.chip(t[1], key == _tab, gt, func():
			_tab = key
			refresh())
		UIKit.shrink_button(chip)
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
		# Estaduais: só o do seu clube aqui; todos aparecem na seção "Estaduais do Brasil".
		if CupManager.is_state(id) and not w.season.cups[id].has_club(w.user_club_id):
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
	# Curiosidades da liga
	var info := UIKit.card("Card", 6)
	info.add_child(UIKit.section("Destaques"))
	var att := CompetitionManager.best_attack(league)
	var dfn := CompetitionManager.best_defense(league)
	if att >= 0 and int(league.table[att]["pl"]) > 0:
		info.add_child(UIKit.kv("Melhor ataque", "%s (%d gols)" % [w.club(att).short_name, int(league.table[att]["gf"])]))
	if dfn >= 0 and int(league.table[dfn]["pl"]) > 0:
		info.add_child(UIKit.kv("Melhor defesa", "%s (%d sofridos)" % [w.club(dfn).short_name, int(league.table[dfn]["ga"])]))
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
	c.add_child(UIKit.label("Toque em um jogador para ver o perfil. Em caso de empate, fica à frente quem jogou menos minutos.", "Small", true))


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


func _cup_groups(c: VBoxContainer, w: GameWorld, cup: Cup) -> void:
	# Estaduais: avançam os líderes de grupo e os melhores dos demais (não os 2 de cada grupo).
	var state_q: Array = CupManager.state_qualified(cup) if CupManager.is_state(cup.id) else []
	if CupManager.is_state(cup.id):
		var n := int(CupManager.cfg(cup.id).get("qualify", 4))
		c.add_child(UIKit.label(("Os %d primeiros vão à semifinal." if cup.groups.size() == 1 else "Avançam os líderes dos grupos e os melhores entre os demais, até completar %d semifinalistas.") % n, "Small", true))
	for g in cup.groups:
		var card := UIKit.card("Card", 2)
		card.add_child(UIKit.section("Grupo %s" % g["n"]))
		card.add_child(TableRows.header(true))
		var order := CompetitionManager.sort_table(g["clubs"], g["table"])
		for i in order.size():
			var qualifies: bool = state_q.has(order[i]) if CupManager.is_state(cup.id) else i < 2
			var zone := CompetitionManager.zone_color(CompetitionManager.ZONE_PROMOTION) if qualifies else Color(0, 0, 0, 0)
			card.add_child(TableRows.table_row(w, g["table"][order[i]], int(order[i]), i + 1, true, zone))
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
