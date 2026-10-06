extends BaseScreen
## RodadaScore: a página de estatísticas de uma liga, no molde dos sites de números de futebol.
## Resumo (quem joga melhor, os times que se destacam, a liga em números), Times e Jogadores em
## tabelas que rolam para o lado (o nome fica preso) e a Seleção da temporada pela nota.

const TABS := [["summary", "Resumo"], ["teams", "Times"], ["players", "Jogadores"], ["xi", "Seleção"]]
const TEAM_VIEWS := [["sum", "Geral"], ["att", "Ataque"], ["def", "Defesa"], ["disc", "Disciplina"]]
const PLAYER_VIEWS := [["sum", "Geral"], ["att", "Ataque"], ["def", "Defesa"], ["pass", "Passe"], ["gk", "Goleiros"]]
const GROUPS := [["-1", "Todos"], ["0", "GOL"], ["1", "DEF"], ["2", "MEI"], ["3", "ATA"]]

var _league_id := ""
var _tab := "summary"
var _team_view := "sum"
var _player_view := "sum"
var _group := -1
var _per90 := false
var _regulars := true
var _team_state := {}
var _player_state := {}


func _init() -> void:
	nav_tab = "club"
	screen_title = "Estatísticas"


func setup(p: Dictionary) -> void:
	super.setup(p)
	_league_id = String(p.get("league", ""))
	_tab = String(p.get("tab", "summary"))


func refresh() -> void:
	var w := world()
	if w == null:
		return
	if _league_id == "" or w.league(_league_id) == null:
		_league_id = w.user_league_id()
	var league := w.league(_league_id)
	screen_subtitle = "%s · %d" % [league.short_name, w.year]
	UIManager.refresh_chrome()
	max_content_width = 1500.0
	var c := content()
	UIKit.clear(c)
	c.add_child(_header(w, league))
	c.add_child(UIKit.scroll_tabs(TABS, _tab, func(k: String):
		_tab = k
		refresh()
		scroll_to_top()))
	if int(league.rounds_played()) == 0 and LeagueStats.players(w, league).is_empty():
		c.add_child(UIKit.state_block("empty", "A liga ainda não começou.", "Os números aparecem depois da primeira rodada."))
	else:
		match _tab:
			"teams":
				_teams(c, w, league)
			"players":
				_players(c, w, league)
			"xi":
				_xi(c, w, league)
			_:
				_summary(c, w, league)
	c.add_child(_powered())


# ---------------------------------------------------------------------------
# Cabeçalho e marca
# ---------------------------------------------------------------------------

func _tint() -> Color:
	var cols := CompText.colors(_league_id)
	var t: Color = cols[0] if not cols.is_empty() else UIColors.ACCENT
	if t.get_luminance() < 0.12 and cols.size() > 1:
		t = cols[1]
	return t


func _header(w: GameWorld, league: League) -> Control:
	var v := UIKit.vbox(UITokens.S1)
	var row := UIKit.hbox(UITokens.S2)
	row.add_child(UIKit.comp_logo(_league_id, 48))
	var col := UIKit.vbox(0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nm := UIKit.label(league.name, "H2")
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(nm)
	var played := league.rounds_played()
	col.add_child(UIKit.label("Temporada %d · %s" % [w.year, ("rodada %d" % played) if played > 0 else "antes da 1ª rodada"], "Small"))
	row.add_child(col)
	row.add_child(_wordmark(26))
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_width_bottom = 3
	sb.border_color = _tint()
	sb.content_margin_bottom = 10
	p.add_theme_stylebox_override(&"panel", sb)
	p.add_child(row)
	v.add_child(p)
	# Outras divisões do mesmo país, a um toque.
	var nation := String(DatabaseManager.league_cfg(_league_id).get("nation", league.nation))
	var ids := DatabaseManager.leagues_of_nation(nation)
	if ids.size() > 1:
		var divs: Array = []
		for lid in ids:
			divs.append([String(lid), String(DatabaseManager.league_cfg(String(lid)).get("short", lid))])
		v.add_child(UIKit.segment(divs, _league_id, func(id: String):
			_league_id = id
			_team_state = {}
			_player_state = {}
			refresh()))
	return v


## "RodadaScore": a palavra em giz e o "Score" na cor da competição.
func _wordmark(size: int) -> Control:
	var h := UIKit.hbox(0)
	h.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var a := UIKit.label("Rodada", "H3")
	a.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	a.add_theme_font_size_override(&"font_size", size)
	h.add_child(a)
	var b := UIKit.colored("Score", UIColors.readable_on(_tint(), [UIColors.BG], 3.0), "H3")
	b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	b.add_theme_font_size_override(&"font_size", size)
	h.add_child(b)
	return h


func _powered() -> Control:
	var h := UIKit.hbox(UITokens.S1)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	var l := UIKit.label("Powered by", "Small")
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	h.add_child(_wordmark(UITokens.F_SMALL + 2))
	var m := MarginContainer.new()
	m.add_theme_constant_override(&"margin_top", UITokens.S3)
	m.add_child(h)
	return m


# ---------------------------------------------------------------------------
# Resumo
# ---------------------------------------------------------------------------

func _summary(c: VBoxContainer, w: GameWorld, league: League) -> void:
	var rows := LeagueStats.teams(w, league)
	var cards: Array = []
	cards.append(_top_rated(w, league))
	cards.append(_team_leaders(w, league, rows))
	cards.append(_league_numbers(w, league, rows))
	var box := UIKit.vbox(UITokens.S3)
	c.add_child(box)
	UIKit.columns(box, cards, content_width(), 2, 0)


## Melhores notas da liga: quem jogou ao menos metade dos jogos do clube.
func _top_rated(w: GameWorld, league: League) -> Control:
	var card := UIKit.card("Card", 4)
	card.add_child(UIKit.section_header("Melhores notas", "Ver todos", func():
		_tab = "players"
		_player_view = "sum"
		_player_state = {"sort": "rs", "desc": true}
		refresh()
		scroll_to_top()))
	var list := _regular_players(w, league)
	list.sort_custom(func(a: Player, b: Player): return LeagueStats.player_rating(a) > LeagueStats.player_rating(b))
	var rows: Array = []
	for i in mini(8, list.size()):
		var p: Player = list[i]
		rows.append(_rating_row(w, p, i + 1))
	if rows.is_empty():
		card.add_child(UIKit.label("Ninguém com jogos suficientes ainda.", "Muted", true))
	else:
		card.add_child(TableRows.ranking_list(rows))
	return UIKit.card_panel(card)


func _rating_row(w: GameWorld, p: Player, rank: int) -> Control:
	var h := UIKit.hbox(UITokens.S1 + 4)
	var rl := UIKit.label(str(rank), "Caps")
	rl.custom_minimum_size.x = 22
	rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(rl)
	var cl := w.club(p.club_id)
	h.add_child(UIKit.crest(cl, 30))
	var col := UIKit.vbox(-2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nl := UIKit.label(p.display_name(), "H3" if rank == 1 else "")
	nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if w.is_user_club(p.club_id):
		nl.add_theme_color_override(&"font_color", UIColors.ink(UIColors.ACCENT))
	col.add_child(nl)
	col.add_child(UIKit.label("%s · %s" % [Pos.code(p.position), cl.short_name if cl != null else ""], "Small"))
	h.add_child(col)
	h.add_child(_rating_chip(LeagueStats.player_rating(p)))
	var pid := p.id
	var row := UIKit.tap_row(h, func(): UIManager.push("player", {"id": pid}), "CardFlat")
	row.custom_minimum_size.y = UITokens.H_ROW
	return row


## Nota em bloco na cor da escala de partida, como nos sites de números.
func _rating_chip(r: float) -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Fmt.match_rating_color(r)
	sb.set_corner_radius_all(UITokens.R_SM)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	p.add_theme_stylebox_override(&"panel", sb)
	var l := UIKit.label(Fmt.rating(r), "H3")
	l.add_theme_font_override(&"font", DataTable.tabular_font())
	l.add_theme_color_override(&"font_color", UIColors.D_BG)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size.x = 40
	p.add_child(l)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return p


## Times que lideram cada quesito.
func _team_leaders(w: GameWorld, _league: League, rows: Array) -> Control:
	var card := UIKit.card("Card", 4)
	card.add_child(UIKit.section_header("Times em destaque", "Ver todos", func():
		_tab = "teams"
		refresh()
		scroll_to_top()))
	var cats := [["Melhor ataque", "gf", true, "%d gols"], ["Melhor defesa", "ga", false, "%d sofridos"],
		["Mais posse", "poss", true, "%s%%"], ["Mais finalizações", "sh", true, "%s por jogo"],
		["Melhor nota", "rt", true, "%s"], ["Mais disciplinado", "fc", false, "%s faltas por jogo"]]
	var out: Array = []
	for cat: Array in cats:
		var key := String(cat[1])
		var best: Dictionary = {}
		for r: Dictionary in rows:
			if int(r["pl"]) == 0 or float(r.get(key, -1.0)) < 0.0:
				continue
			if best.is_empty() or ((float(r[key]) > float(best[key])) if bool(cat[2]) else (float(r[key]) < float(best[key]))):
				best = r
		if best.is_empty():
			continue
		var v := float(best[key])
		var txt := ""
		if key in ["gf", "ga"]:
			txt = String(cat[3]) % int(v)
		elif key == "poss":
			txt = String(cat[3]) % str(int(round(v)))
		elif key == "rt":
			txt = Fmt.rating(v)
		else:
			txt = String(cat[3]) % Fmt.dec(v, 1)
		out.append(_leader_row(w, String(cat[0]), int(best["id"]), txt))
	if out.is_empty():
		card.add_child(UIKit.label("Sem jogos ainda.", "Muted", true))
	else:
		card.add_child(TableRows.ranking_list(out))
	return UIKit.card_panel(card)


func _leader_row(w: GameWorld, what: String, cid: int, value: String) -> Control:
	var h := UIKit.hbox(UITokens.S1 + 4)
	var cl := w.club(cid)
	h.add_child(UIKit.crest(cl, 30))
	var col := UIKit.vbox(-2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UIKit.label(what, "Small"))
	var nl := UIKit.label(cl.short_name, "H3")
	nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if w.is_user_club(cid):
		nl.add_theme_color_override(&"font_color", UIColors.ink(UIColors.ACCENT))
	col.add_child(nl)
	h.add_child(col)
	var vl := UIKit.label(value, "")
	vl.add_theme_font_override(&"font", DataTable.tabular_font())
	vl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(vl)
	var lg := _league_id
	var row := UIKit.tap_row(h, func(): _team_sheet(w, w.league(lg), cid), "CardFlat")
	row.custom_minimum_size.y = UITokens.H_ROW
	return row


## A liga em números: médias por jogo e como terminam os jogos.
func _league_numbers(w: GameWorld, league: League, rows: Array) -> Control:
	var card := UIKit.card("Card", 6)
	card.add_child(UIKit.section_header("A liga em números"))
	var games := 0
	var goals := 0
	var home := 0
	var draw := 0
	var away := 0
	var zero := 0
	for r in league.rounds:
		for f: Fixture in r:
			if not f.played:
				continue
			games += 1
			goals += f.hg + f.ag
			if f.hg > f.ag:
				home += 1
			elif f.hg == f.ag:
				draw += 1
			else:
				away += 1
			if f.hg == 0 or f.ag == 0:
				zero += 1
	if games == 0:
		card.add_child(UIKit.label("Sem jogos ainda.", "Muted", true))
		return UIKit.card_panel(card)
	var yc := 0
	var rc := 0
	var poss_known := false
	var sh := 0.0
	for t: Dictionary in rows:
		yc += int(t["yc"])
		rc += int(t["rc"])
		sh += float(t["sh"]) * int(t["pl"])
		poss_known = poss_known or float(t["poss"]) >= 0.0
	var g := float(games)
	card.add_child(UIKit.kv("Jogos", str(games)))
	card.add_child(UIKit.kv("Gols por jogo", Fmt.dec(goals / g, 2)))
	card.add_child(UIKit.kv("Finalizações por jogo", Fmt.dec(sh / g, 1)))
	card.add_child(UIKit.kv("Cartões amarelos por jogo", Fmt.dec(yc / g, 1)))
	card.add_child(UIKit.kv("Expulsões", str(rc)))
	card.add_child(UIKit.kv("Algum time sem marcar", "%d%%" % int(round(100.0 * zero / g))))
	# Mandante, empate e visitante numa barra só, com os números escritos.
	card.add_child(UIKit.gap(UITokens.S1))
	card.add_child(UIKit.label("Como terminam os jogos", "Caps"))
	card.add_child(_result_bar(home, draw, away))
	return UIKit.card_panel(card)


func _result_bar(home: int, draw: int, away: int) -> Control:
	var v := UIKit.vbox(4)
	var total := maxf(1.0, float(home + draw + away))
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override(&"separation", 2)
	bar.custom_minimum_size.y = 12
	for part: Array in [[home, UIColors.GREEN], [draw, UIColors.DIM], [away, UIColors.BLUE]]:
		if int(part[0]) == 0:
			continue
		var r := ColorRect.new()
		r.color = part[1]
		r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.size_flags_stretch_ratio = float(part[0])
		bar.add_child(r)
	v.add_child(bar)
	var legend := UIKit.hbox(UITokens.S2)
	for part: Array in [["Mandante", home], ["Empate", draw], ["Visitante", away]]:
		var l := UIKit.label("%s %d%%" % [part[0], int(round(100.0 * int(part[1]) / total))], "Small")
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		legend.add_child(l)
	v.add_child(legend)
	return v


# ---------------------------------------------------------------------------
# Times
# ---------------------------------------------------------------------------

func _teams(c: VBoxContainer, w: GameWorld, league: League) -> void:
	c.add_child(UIKit.segment(TEAM_VIEWS, _team_view, func(k: String):
		_team_view = k
		_team_state = {}
		refresh()))
	var rows := LeagueStats.teams(w, league).filter(func(r: Dictionary) -> bool: return int(r["pl"]) > 0)
	var cols := _team_columns(w, league)
	var order: Dictionary = {"sum": ["rt", "gf", "sh", "poss", "pp", "yc", "rc"],
		"att": ["gf", "xg", "sh", "so", "kp", "dr"],
		"def": ["ga", "xga", "sha", "tk", "it", "ad", "cs"],
		"disc": ["fc", "yc", "rc"]}
	var keys: Array = order.get(_team_view, order["sum"]).duplicate()
	for k in ["rt", "gf", "ga", "xg", "xga", "sh", "so", "sha", "kp", "dr", "poss", "pp", "tk", "it", "ad", "cs", "fc", "yc", "rc"]:
		if not k in keys:
			keys.append(k)
	var picked: Array = [cols["team"]]
	for k in keys:
		picked.append(cols[k])
	if _team_state.is_empty():
		var first := String(keys[0])
		_team_state = {"sort": first, "desc": not first in ["ga", "xga", "sha", "fc", "yc", "rc"]}
	var t := DataTable.new()
	t.row_height = 76
	t.lead_width = 240.0
	t.lead_min = 190.0
	t.highlight = func(r: Dictionary) -> bool: return w.is_user_club(int(r["id"]))
	t.row_pressed.connect(func(r: Variant): _team_sheet(w, league, int((r as Dictionary)["id"])))
	t.setup(picked, rows, _team_state)
	c.add_child(t)
	if rows.any(func(r: Dictionary) -> bool: return float(r["poss"]) < 0.0):
		c.add_child(UIKit.label("Posse e números do adversário contam a partir desta versão.", "Small", true))


func _team_columns(w: GameWorld, _league: League) -> Dictionary:
	var num := func(key: String, title: String, tip: String, places: int, width: int, good_high: bool = true) -> Dictionary:
		return {"key": key, "title": title, "w": width, "tip": tip, "first": "desc" if good_high else "asc",
			"text": func(r: Dictionary) -> String:
				var v := float(r.get(key, -1.0))
				if v < 0.0:
					return "–"
				return str(int(v)) if places == 0 else Fmt.dec(v, places),
			"sort": func(r: Dictionary) -> float: return float(r.get(key, -1.0)),
			"color": func(_r: Dictionary) -> Color: return UIColors.TEXT}
	var c := {}
	c["team"] = {"key": "team", "title": "Time", "first": "asc",
		"sort": func(r: Dictionary) -> String: return w.club(int(r["id"])).short_name,
		"cell": func(r: Dictionary) -> Control: return _team_cell(w, int(r["id"]))}
	c["rt"] = {"key": "rt", "title": "Nota", "w": 64, "tip": "Nota média RodadaScore",
		"text": func(r: Dictionary) -> String: return Fmt.rating(float(r["rt"])) if float(r["rt"]) > 0.0 else "–",
		"sort": func(r: Dictionary) -> float: return float(r["rt"]),
		"color": func(r: Dictionary) -> Color: return Fmt.match_rating_color(float(r["rt"]))}
	c["gf"] = num.call("gf", "Gols", "Gols marcados", 0, 56)
	c["ga"] = num.call("ga", "Sofr.", "Gols sofridos", 0, 56, false)
	c["xg"] = num.call("xg", "xG", "Gols esperados", 1, 56)
	c["xga"] = num.call("xga", "xGC", "Gols esperados contra", 1, 60, false)
	c["sh"] = num.call("sh", "Fin/j", "Finalizações por jogo", 1, 64)
	c["so"] = num.call("so", "Alvo/j", "Finalizações no alvo por jogo", 1, 68)
	c["sha"] = num.call("sha", "FinC/j", "Finalizações sofridas por jogo", 1, 72, false)
	c["kp"] = num.call("kp", "PD/j", "Passes decisivos por jogo", 1, 60)
	c["dr"] = num.call("dr", "Dri/j", "Dribles certos por jogo", 1, 60)
	c["poss"] = {"key": "poss", "title": "Posse", "w": 64, "tip": "Posse de bola média",
		"text": func(r: Dictionary) -> String: return ("%d%%" % int(round(float(r["poss"])))) if float(r["poss"]) >= 0.0 else "–",
		"sort": func(r: Dictionary) -> float: return float(r["poss"])}
	c["pp"] = {"key": "pp", "title": "Passe", "w": 64, "tip": "% de passes certos",
		"text": func(r: Dictionary) -> String: return ("%d%%" % int(round(float(r["pp"])))) if float(r["pp"]) > 0.0 else "–",
		"sort": func(r: Dictionary) -> float: return float(r["pp"])}
	c["tk"] = num.call("tk", "Des/j", "Desarmes por jogo", 1, 60)
	c["it"] = num.call("it", "Int/j", "Interceptações por jogo", 1, 60)
	c["ad"] = num.call("ad", "Aér/j", "Duelos aéreos ganhos por jogo", 1, 60)
	c["cs"] = num.call("cs", "SG", "Jogos sem sofrer gol", 0, 48)
	c["fc"] = num.call("fc", "Falt/j", "Faltas cometidas por jogo", 1, 66, false)
	c["yc"] = {"key": "yc", "title": "CA", "w": 48, "tip": "Cartões amarelos", "first": "asc",
		"text": func(r: Dictionary) -> String: return str(int(r["yc"])),
		"sort": func(r: Dictionary) -> int: return int(r["yc"]),
		"color": func(_r: Dictionary) -> Color: return UIColors.TEXT}
	c["rc"] = {"key": "rc", "title": "CV", "w": 48, "tip": "Cartões vermelhos", "first": "asc",
		"text": func(r: Dictionary) -> String: return str(int(r["rc"])),
		"sort": func(r: Dictionary) -> int: return int(r["rc"]),
		"color": func(r: Dictionary) -> Color: return UIColors.RED if int(r["rc"]) > 0 else UIColors.TEXT}
	return c


func _team_cell(w: GameWorld, cid: int) -> Control:
	var h := UIKit.hbox(UITokens.S1)
	var cl := w.club(cid)
	var crest := UIKit.crest(cl, 32)
	crest.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(crest)
	var nl := UIKit.label(cl.short_name, "H3" if w.is_user_club(cid) else "")
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if w.is_user_club(cid):
		nl.add_theme_color_override(&"font_color", UIColors.ink(UIColors.ACCENT))
	h.add_child(nl)
	h.tooltip_text = cl.name
	return h


## Folha do time: pontos fortes, fracos e o estilo, pela posição em cada quesito na liga.
func _team_sheet(w: GameWorld, league: League, cid: int) -> void:
	var cl := w.club(cid)
	var rows := LeagueStats.teams(w, league)
	var prof := LeagueStats.profile(rows, cid)
	var v := UIKit.vbox(UITokens.S2)
	var head := UIKit.hbox(UITokens.S2)
	head.add_child(UIKit.crest(cl, 56))
	var col := UIKit.vbox(0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UIKit.label(cl.name, "H2", true))
	col.add_child(UIKit.label("%dº na %s" % [CompetitionManager.position_of(league, cid), league.short_name], "Small"))
	head.add_child(col)
	v.add_child(head)
	var parts := [["Pontos fortes", prof["strong"], UIColors.GREEN], ["Pontos fracos", prof["weak"], UIColors.ORANGE]]
	for part: Array in parts:
		v.add_child(UIKit.label(String(part[0]), "Section"))
		var list: Array = part[1]
		if list.is_empty():
			v.add_child(UIKit.label("Nada que se destaque.", "Muted"))
			continue
		for it: Array in list:
			var h := UIKit.hbox(UITokens.S1)
			var n := UIKit.label(String(it[0]))
			n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(n)
			h.add_child(UIKit.colored("%dº" % int(it[1]), part[2], "H3"))
			v.add_child(h)
	var style: Array = prof["style"]
	if not style.is_empty():
		v.add_child(UIKit.label("Estilo de jogo", "Section"))
		for s in style:
			v.add_child(UIKit.label(String(s)))
	var id := cid
	v.add_child(UIKit.gap(UITokens.S1))
	v.add_child(UIKit.button("Estatísticas da equipe", "SecondaryButton", func():
		UIManager.close_modal()
		UIManager.push("team_stats", {"id": id})))
	UIManager.show_modal(v, true)


# ---------------------------------------------------------------------------
# Jogadores
# ---------------------------------------------------------------------------

## Jogou ao menos metade dos jogos do clube na liga.
func _regular_players(w: GameWorld, league: League) -> Array:
	return LeagueStats.players(w, league).filter(func(p: Player) -> bool:
		var pl := int(league.table.get(p.club_id, {}).get("pl", 0))
		return p.stats[Player.S_APPS] >= maxi(1, int(ceil(pl / 2.0))))


func _players(c: VBoxContainer, w: GameWorld, league: League) -> void:
	c.add_child(UIKit.segment(PLAYER_VIEWS, _player_view, func(k: String):
		_player_view = k
		_player_state = {}
		refresh()))
	var bar := UIKit.flow(UITokens.S1)
	var g := ButtonGroup.new()
	for it: Array in GROUPS:
		var gi := int(it[0])
		bar.add_child(UIKit.chip(String(it[1]), _group == gi, g, func():
			_group = gi
			refresh()))
	var reg := UIKit.chip("Regulares", _regulars, null, func():
		_regulars = not _regulars
		refresh())
	reg.tooltip_text = "Só quem jogou metade dos jogos do clube"
	bar.add_child(reg)
	var p90 := UIKit.chip("Por 90 min", _per90, null, func():
		_per90 = not _per90
		refresh())
	bar.add_child(p90)
	c.add_child(bar)
	var list := _regular_players(w, league) if _regulars else LeagueStats.players(w, league)
	if _player_view == "gk":
		list = list.filter(func(p: Player) -> bool: return p.position == Pos.GK)
	elif _group >= 0:
		list = list.filter(func(p: Player) -> bool: return Pos.group(p.position) == _group)
	if list.is_empty():
		c.add_child(UIKit.state_block("empty", "Ninguém nesse recorte.", "", "Mostrar todos", func():
			_group = -1
			_regulars = false
			refresh()))
		return
	var cols := _player_columns(w)
	var order: Dictionary = {"sum": ["rs", "apps", "mins", "goals", "assists", "motm"],
		"att": ["goals", "xg", "shots", "son", "conv", "kp", "dr"],
		"def": ["tk", "it", "ad", "fc", "yc"],
		"pass": ["pp", "kp", "assists"],
		"gk": ["rs", "sv", "svp", "conc", "cs"]}
	var keys: Array = order.get(_player_view, order["sum"]).duplicate()
	var rest := ["rs", "apps", "mins", "goals", "assists", "xg", "shots", "son", "kp", "dr", "pp", "tk", "it", "ad", "fc", "yc", "rc", "motm"]
	if _player_view == "gk":
		rest = ["apps", "mins", "pp", "yc", "motm"]
	for k in rest:
		if not k in keys:
			keys.append(k)
	var picked: Array = [cols["player"]]
	for k in keys:
		picked.append(cols[k])
	if _player_state.is_empty():
		var first := String(keys[0])
		_player_state = {"sort": first, "desc": not first in ["fc", "yc", "conc"]}
	var t := DataTable.new()
	t.row_height = 80
	t.lead_width = 270.0
	t.lead_min = 236.0
	t.highlight = func(p: Player) -> bool: return w.is_user_club(p.club_id)
	t.row_pressed.connect(func(p: Variant): UIManager.push("player", {"id": (p as Player).id}))
	t.setup(picked, list, _player_state)
	c.add_child(UIKit.label(Fmt.plural(list.size(), "jogador", "jogadores") + (" · por 90 minutos" if _per90 else ""), "Small"))
	c.add_child(t)


func _player_columns(w: GameWorld) -> Dictionary:
	var per := _per90
	var stat := func(key: String, title: String, tip: String, idx: int, width: int, low_first: bool = false) -> Dictionary:
		return {"key": key, "title": title, "w": width, "tip": tip + (" por 90 min" if per else ""), "first": "asc" if low_first else "desc",
			"text": func(p: Player) -> String: return Fmt.dec(p.per90(idx), 2) if per else str(p.stats[idx]),
			"sort": func(p: Player) -> float: return p.per90(idx) if per else float(p.stats[idx]),
			"color": func(p: Player) -> Color: return UIColors.TEXT if p.stats[idx] > 0 else UIColors.DIM}
	var c := {}
	c["player"] = {"key": "player", "title": "Jogador", "first": "asc",
		"sort": func(p: Player) -> String: return p.display_name(),
		"cell": func(p: Player) -> Control: return _player_cell(w, p)}
	c["rs"] = {"key": "rs", "title": "Nota", "w": 64, "tip": "Nota média RodadaScore",
		"text": func(p: Player) -> String: return Fmt.rating(LeagueStats.player_rating(p)),
		"sort": func(p: Player) -> float: return LeagueStats.player_rating(p),
		"color": func(p: Player) -> Color: return Fmt.match_rating_color(LeagueStats.player_rating(p))}
	c["apps"] = {"key": "apps", "title": "J", "w": 44, "tip": "Jogos (titular)",
		"text": func(p: Player) -> String: return "%d(%d)" % [p.stats[Player.S_STARTS], p.stats[Player.S_APPS] - p.stats[Player.S_STARTS]] if p.stats[Player.S_APPS] > p.stats[Player.S_STARTS] else str(p.stats[Player.S_APPS]),
		"sort": func(p: Player) -> int: return p.stats[Player.S_APPS],
		"color": func(_p: Player) -> Color: return UIColors.MUTED}
	c["apps"]["w"] = 64
	c["mins"] = {"key": "mins", "title": "Min", "w": 64, "tip": "Minutos",
		"text": func(p: Player) -> String: return str(p.stats[Player.S_MINUTES]),
		"sort": func(p: Player) -> int: return p.stats[Player.S_MINUTES],
		"color": func(_p: Player) -> Color: return UIColors.MUTED}
	c["goals"] = stat.call("goals", "G", "Gols", Player.S_GOALS, 52)
	c["assists"] = stat.call("assists", "A", "Assistências", Player.S_ASSISTS, 52)
	c["shots"] = stat.call("shots", "Fin", "Finalizações", Player.S_SHOTS, 56)
	c["son"] = stat.call("son", "Alvo", "Finalizações no alvo", Player.S_SHOTS_ON, 56)
	c["kp"] = stat.call("kp", "PD", "Passes decisivos", Player.S_KEY_PASSES, 56)
	c["dr"] = stat.call("dr", "Dri", "Dribles certos", Player.S_DRIBBLES, 56)
	c["tk"] = stat.call("tk", "Des", "Desarmes", Player.S_TACKLES, 56)
	c["it"] = stat.call("it", "Int", "Interceptações", Player.S_INTERCEPTIONS, 56)
	c["ad"] = stat.call("ad", "Aér", "Duelos aéreos ganhos", Player.S_AERIAL, 56)
	c["fc"] = stat.call("fc", "Falt", "Faltas cometidas", Player.S_FOULS, 56, true)
	c["sv"] = stat.call("sv", "Def", "Defesas", Player.S_SAVES, 56)
	c["conc"] = stat.call("conc", "Sofr", "Gols sofridos", Player.S_CONCEDED, 56, true)
	c["cs"] = stat.call("cs", "SG", "Jogos sem sofrer gol", Player.S_CLEAN, 48)
	c["motm"] = stat.call("motm", "Craque", "Craque do jogo", Player.S_MOTM, 72)
	c["yc"] = {"key": "yc", "title": "CA", "w": 44, "tip": "Cartões amarelos", "first": "asc",
		"text": func(p: Player) -> String: return str(p.stats[Player.S_YELLOWS]),
		"sort": func(p: Player) -> int: return p.stats[Player.S_YELLOWS],
		"color": func(p: Player) -> Color: return UIColors.TEXT if p.stats[Player.S_YELLOWS] > 0 else UIColors.DIM}
	c["rc"] = {"key": "rc", "title": "CV", "w": 44, "tip": "Cartões vermelhos", "first": "asc",
		"text": func(p: Player) -> String: return str(p.stats[Player.S_REDS]),
		"sort": func(p: Player) -> int: return p.stats[Player.S_REDS],
		"color": func(p: Player) -> Color: return UIColors.RED if p.stats[Player.S_REDS] > 0 else UIColors.DIM}
	c["xg"] = {"key": "xg", "title": "xG", "w": 56, "tip": "Gols esperados" + (" por 90 min" if per else ""),
		"text": func(p: Player) -> String: return Fmt.dec(p.xg() * 90.0 / p.stats[Player.S_MINUTES], 2) if per and p.stats[Player.S_MINUTES] > 0 else Fmt.dec(p.xg(), 1),
		"sort": func(p: Player) -> float: return p.xg() * 90.0 / maxf(1.0, p.stats[Player.S_MINUTES]) if per else p.xg()}
	c["conv"] = {"key": "conv", "title": "Conv", "w": 60, "tip": "Gols por finalização",
		"text": func(p: Player) -> String: return ("%d%%" % int(round(p.conversion()))) if p.stats[Player.S_SHOTS] > 0 else "–",
		"sort": func(p: Player) -> float: return p.conversion()}
	c["pp"] = {"key": "pp", "title": "Passe", "w": 64, "tip": "% de passes certos",
		"text": func(p: Player) -> String: return "%d%%" % int(round(p.pass_pct())),
		"sort": func(p: Player) -> float: return p.pass_pct()}
	c["svp"] = {"key": "svp", "title": "%Def", "w": 64, "tip": "% das finalizações no alvo defendidas",
		"text": func(p: Player) -> String: return ("%d%%" % int(round(p.save_pct()))) if p.stats[Player.S_SAVES] + p.stats[Player.S_CONCEDED] > 0 else "–",
		"sort": func(p: Player) -> float: return p.save_pct()}
	return c


func _player_cell(w: GameWorld, p: Player) -> Control:
	var h := UIKit.hbox(UITokens.S1)
	var cl := w.club(p.club_id)
	var crest := UIKit.crest(cl, 30)
	crest.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(crest)
	var v := UIKit.vbox(-2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var nl := UIKit.label(p.display_name())
	nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nl.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	if w.is_user_club(p.club_id):
		nl.add_theme_color_override(&"font_color", UIColors.ink(UIColors.ACCENT))
	v.add_child(nl)
	var sub := UIKit.label("%s · %d anos" % [Pos.code(p.position), p.age(w.year)], "Small")
	sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(sub)
	h.add_child(v)
	h.tooltip_text = "%s (%s)" % [p.full_name(), cl.short_name if cl != null else ""]
	return h


# ---------------------------------------------------------------------------
# Seleção da temporada
# ---------------------------------------------------------------------------

func _xi(c: VBoxContainer, w: GameWorld, league: League) -> void:
	var xi := LeagueStats.best_xi(w, league)
	var card := UIKit.card("Card", 8)
	card.add_child(UIKit.section_header("Seleção da temporada"))
	card.add_child(UIKit.label("4-3-3 pela nota média, entre quem jogou metade dos jogos do clube.", "Small", true))
	if xi.size() < 11:
		card.add_child(UIKit.label("Ainda não há jogadores suficientes com jogos.", "Muted", true))
		c.add_child(UIKit.card_panel(card))
		return
	var ids: Array = []
	var rts: Array = []
	var best := -1
	var best_r := 0.0
	for p: Player in xi:
		ids.append(p.id)
		var r := LeagueStats.player_rating(p)
		rts.append(r)
		if r > best_r:
			best_r = r
			best = p.id
	card.add_child(XIPitch.make(w, ids, rts, best, 720))
	var rows: Array = []
	for i in xi.size():
		rows.append(_rating_row(w, xi[i], i + 1))
	card.add_child(TableRows.ranking_list(rows))
	c.add_child(UIKit.card_panel(card))
