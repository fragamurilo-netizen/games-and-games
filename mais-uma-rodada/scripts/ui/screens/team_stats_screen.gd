extends BaseScreen
class_name TeamStatsScreen
## Estatísticas de equipe (do seu time ou de qualquer outro): campanha, casa e fora, posição na
## liga em cada quesito, perfil do elenco e destaques da temporada. Os cartões também aparecem
## na aba "Estatísticas" da tela do clube.

var _club_id := -1


func _init() -> void:
	show_nav = false
	screen_title = "Estatísticas da equipe"


func setup(p: Dictionary) -> void:
	super.setup(p)
	_club_id = int(p.get("id", -1))


func refresh() -> void:
	var w := world()
	if w == null:
		return
	var club := w.club(_club_id) if _club_id >= 0 else w.user_club()
	if club == null:
		return
	screen_subtitle = club.short_name
	UIManager.refresh_chrome()
	var c := content()
	UIKit.clear(c)
	# Troca rápida entre os clubes da mesma liga.
	var league := w.league_of(club.id)
	if league != null:
		var items: Array = []
		for id in CompetitionManager.sorted_ids(league):
			items.append([str(id), w.club(int(id)).short_name])
		c.add_child(UIKit.scroll_tabs(items, str(club.id), func(k: String):
			_club_id = int(k)
			refresh()
			scroll_to_top()))
	var box := UIKit.vbox(16)
	c.add_child(box)
	UIKit.columns(box, cards(w, club), content_width(), 2, 0)


## Cartões de estatística de um clube.
static func cards(w: GameWorld, club: Club) -> Array:
	var out: Array = []
	var league := w.league_of(club.id)
	if league != null and league.table.has(club.id):
		out.append(_season_card(w, club, league))
		out.append(_ranks_card(w, club, league))
	out.append(squad_table(w, club))
	out.append(_squad_card(w, club))
	out.append(_leaders_card(w, club))
	var rec := _records_card(w, club)
	if rec != null:
		out.append(rec)
	return out


## Recordes do clube: sequências e placares desde o início do save, e as melhores campanhas do
## histórico de ligas.
static func _records_card(w: GameWorld, club: Club) -> Control:
	var mk := club.marks
	var rows: Array = []
	var ws: Array = mk.get("ws", [])
	if not ws.is_empty() and int(ws[0]) >= 2:
		rows.append(["Vitórias seguidas", "%s · %d" % [Fmt.n_of(int(ws[0]), "%d jogo", "%d jogos"), int(ws[1])]])
	var us: Array = mk.get("us", [])
	if not us.is_empty() and int(us[0]) >= 2:
		rows.append(["Invencibilidade", "%s · %d" % [Fmt.n_of(int(us[0]), "%d jogo", "%d jogos"), int(us[1])]])
	var cr: Array = mk.get("cr", [])
	if not cr.is_empty() and int(cr[0]) >= 2:
		rows.append(["Sem sofrer gol", "%s · %d" % [Fmt.n_of(int(cr[0]), "%d jogo", "%d jogos"), int(cr[1])]])
	var bw: Array = mk.get("bw", [])
	if not bw.is_empty():
		rows.append(["Maior vitória", "%d x %d %s · %d" % [int(bw[0]), int(bw[1]), String(bw[2]), int(bw[3])]])
	var bl: Array = mk.get("bl", [])
	if not bl.is_empty():
		rows.append(["Maior derrota", "%d x %d %s · %d" % [int(bl[0]), int(bl[1]), String(bl[2]), int(bl[3])]])
	var best_pts: Dictionary = {}
	var best_gf: Dictionary = {}
	var best_ga: Dictionary = {}
	for h in club.history:
		var hd: Dictionary = h
		var lg := w.league(String(hd.get("l", "")))
		if lg == null or lg.tier != club.tier:
			continue
		if best_pts.is_empty() or int(hd.get("pts", 0)) > int(best_pts.get("pts", 0)):
			best_pts = hd
		if best_gf.is_empty() or int(hd.get("gf", 0)) > int(best_gf.get("gf", 0)):
			best_gf = hd
		var games := int(hd.get("w", 0)) + int(hd.get("dr", 0)) + int(hd.get("lo", 0))
		if games > 0 and (best_ga.is_empty() or int(hd.get("ga", 0)) < int(best_ga.get("ga", 0))):
			best_ga = hd
	if not best_pts.is_empty():
		rows.append(["Mais pontos na liga", "%s · %d" % [Fmt.n_of(int(best_pts.get("pts", 0)), "%d ponto", "%d pontos"), int(best_pts.get("y", 0))]])
		rows.append(["Mais gols na liga", "%s · %d" % [Fmt.n_of(int(best_gf.get("gf", 0)), "%d gol", "%d gols"), int(best_gf.get("y", 0))]])
		if not best_ga.is_empty():
			rows.append(["Defesa menos vazada", "%s · %d" % [Fmt.n_of(int(best_ga.get("ga", 0)), "%d gol", "%d gols"), int(best_ga.get("y", 0))]])
	if rows.is_empty():
		return null
	var card := UIKit.card("Card", 8)
	card.add_child(UIKit.section_header("Recordes do clube"))
	for r: Array in rows:
		card.add_child(UIKit.kv(String(r[0]), String(r[1])))
	return UIKit.card_panel(card)


# ---------------------------------------------------------------------------
# Tabela do elenco: jogos, gols, assistências, minutos e nota, desta temporada ou das anteriores.
# ---------------------------------------------------------------------------

static var _tbl_club := -1
static var _tbl_year := 0
static var _tbl_sort := "a"


## Temporadas anteriores com registro: arquivo do clube (seu time) e a carreira de quem está no
## elenco hoje (só o elenco atual, para não abrir o histórico do mundo inteiro).
static func past_years(w: GameWorld, club: Club) -> Array:
	var ys := {}
	for k in club.squad_archive:
		ys[int(k)] = true
	for p: Player in w.squad(club):
		for h: Dictionary in p.history:
			if int(h.get("c", -1)) == club.id:
				ys[int(h.get("y", 0))] = true
	ys.erase(w.year)
	var out: Array = ys.keys()
	out.sort()
	out.reverse()
	return out


## Linhas {id, n, pos, a, g, as, r, m} do elenco numa temporada (0 = a atual, liga + copas).
static func table_rows(w: GameWorld, club: Club, year: int) -> Array:
	var rows: Array = []
	if year == 0 or year == w.year:
		for p: Player in w.squad(club):
			var t := p.season_totals()
			var mins := p.stats[Player.S_MINUTES]
			var rsum := p.stats[Player.S_RATING_SUM]
			for k in p.cup_stats:
				var st: PackedInt32Array = p.cup_stats[k]
				mins += st[Player.C_MINUTES]
				rsum += st[Player.C_RATING]
			rows.append({"id": p.id, "n": p.short_name(), "pos": p.position, "a": int(t[0]), "g": int(t[1]),
				"as": int(t[2]), "r": rsum / 10.0 / int(t[0]) if int(t[0]) > 0 else 0.0, "m": mins, "yc": p.stats[Player.S_YELLOWS]})
		return rows
	var seen := {}
	for r: Dictionary in club.squad_archive.get(str(year), []):
		var row := r.duplicate()
		row["m"] = -1
		rows.append(row)
		seen[int(r.get("id", -1))] = true
	for p: Player in w.squad(club):
		if seen.has(p.id):
			continue
		for h: Dictionary in p.history:
			if int(h.get("c", -1)) == club.id and int(h.get("y", 0)) == year:
				rows.append({"id": p.id, "n": p.short_name(), "pos": p.position, "m": -1,
					"a": int(h.get("a", 0)) + int(h.get("ca", 0)), "g": int(h.get("g", 0)) + int(h.get("cg", 0)),
					"as": int(h.get("as", 0)) + int(h.get("cas", 0)), "r": float(h.get("r", 0.0))})
				break
	return rows


static func squad_table(w: GameWorld, club: Club) -> Control:
	if _tbl_club != club.id:
		_tbl_club = club.id
		_tbl_year = 0
	var card := UIKit.card("Card", 8)
	var body := UIKit.vbox(8)
	card.add_child(UIKit.section_header("Estatísticas do elenco"))
	card.add_child(body)
	_fill_table(w, club, body)
	return UIKit.card_panel(card)


static func _fill_table(w: GameWorld, club: Club, body: VBoxContainer) -> void:
	UIKit.clear(body)
	var redo := func(): _fill_table(w, club, body)
	var years := past_years(w, club)
	var items: Array = [["0", "%d (atual)" % w.year]]
	for y in years.slice(0, 12):
		items.append([str(y), str(y)])
	body.add_child(UIKit.scroll_tabs(items, str(_tbl_year), func(k: String):
		_tbl_year = int(k)
		redo.call()))
	body.add_child(UIKit.segment([["a", "Jogos"], ["g", "Gols"], ["as", "Assist."], ["r", "Nota"]], _tbl_sort, func(k: String):
		_tbl_sort = k
		redo.call()))
	var rows := table_rows(w, club, _tbl_year)
	var key := _tbl_sort
	rows.sort_custom(func(a, b):
		var va := float(a.get(key, 0))
		var vb := float(b.get(key, 0))
		return va > vb if va != vb else int(a.get("a", 0)) > int(b.get("a", 0)))
	if rows.is_empty():
		body.add_child(UIKit.label("Sem registros desta temporada para este clube.", "Muted", true))
		return
	var current := _tbl_year == 0
	# Colunas de largura fixa, números em fonte condensada alinhados à direita; o cabeçalho usa as
	# mesmas margens das linhas para cada título ficar em cima da sua coluna. Zeros apagados.
	var cols: Array = [["a", "J", 44], ["g", "G", 44], ["as", "A", 44], ["r", "NOTA", 64]]
	if current:
		cols.append(["m", "MIN", 70])
	var head := UIKit.hbox(6)
	var hn := UIKit.label("JOGADOR", "Caps")
	hn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hn)
	for col: Array in cols:
		var hl := _cell(String(col[1]), "Caps", int(col[2]))
		if String(col[0]) == key:
			hl.add_theme_color_override(&"font_color", UIColors.ACCENT)
		head.add_child(hl)
	var tot := [0, 0, 0, 0]
	var list: Array = [_plain_row(head)]
	for r: Dictionary in rows:
		tot[0] += int(r.get("a", 0))
		tot[1] += int(r.get("g", 0))
		tot[2] += int(r.get("as", 0))
		tot[3] += maxi(0, int(r.get("m", 0)))
		var h := UIKit.hbox(6)
		h.add_child(UIKit.pos_badge(int(r.get("pos", 0))))
		var nm := UIKit.label(String(r.get("n", "")), "")
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nm.custom_minimum_size.x = 40
		if int(r.get("a", 0)) == 0:
			nm.add_theme_color_override(&"font_color", UIColors.MUTED)
		h.add_child(nm)
		for k in ["a", "g", "as"]:
			h.add_child(_num(int(r.get(k, 0)), 44, k == key))
		var rt := float(r.get("r", 0.0))
		var rl := _cell(Fmt.dec(rt, 2) if rt > 0.0 else "—", "Mono", 64)
		if rt >= 7.2:
			rl.add_theme_color_override(&"font_color", UIColors.GREEN)
		elif rt > 0.0 and rt < 6.3:
			rl.add_theme_color_override(&"font_color", UIColors.RED)
		elif rt <= 0.0:
			rl.add_theme_color_override(&"font_color", UIColors.DIM)
		h.add_child(rl)
		if current:
			var ml := _cell(Fmt.thousands(int(r.get("m", 0))) if int(r.get("m", 0)) > 0 else "—", "Mono", 70)
			ml.add_theme_color_override(&"font_color", UIColors.MUTED if int(r.get("m", 0)) > 0 else UIColors.DIM)
			h.add_child(ml)
		var pid := int(r.get("id", -1))
		if w.player(pid) != null:
			list.append(UIKit.tap_row(h, func(): UIManager.push("player", {"id": pid}), "RowPanel"))
		else:
			list.append(_plain_row(h))
	# Total na mesma grade das colunas (liga e copas).
	var th := UIKit.hbox(6)
	var tl := UIKit.label("TOTAL", "Caps")
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	th.add_child(tl)
	for i in 3:
		th.add_child(_cell(str(tot[i]), "Mono", 44))
	th.add_child(_cell("", "Mono", 64))
	if current:
		th.add_child(_cell(Fmt.thousands(tot[3]), "Mono", 70))
	list.append(_plain_row(th))
	body.add_child(UIKit.menu_group(list))


static func _plain_row(inner: Control) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_child(inner)
	return p


## Número de uma coluna: zero apagado; a coluna da ordenação em destaque.
static func _num(v: int, wdt: int, sorted: bool) -> Label:
	var l := _cell(str(v), "Mono", wdt)
	if v == 0:
		l.add_theme_color_override(&"font_color", UIColors.DIM)
	elif sorted:
		l.add_theme_font_override(&"font", l.get_theme_font(&"font", &"StatBig"))
	return l


static func _cell(t: String, variation: String, wdt: int) -> Label:
	var l := UIKit.label(t, variation)
	l.custom_minimum_size.x = wdt
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return l


static func _pct(a: float, b: float) -> String:
	return "%d%%" % int(round(100.0 * a / b)) if b > 0.0 else "—"


static func _season_card(w: GameWorld, club: Club, league: League) -> Control:
	var card := UIKit.card("Card", 8)
	card.add_child(UIKit.section_header("Campanha na %s" % w.league_short(league.id)))
	var r: Dictionary = league.table[club.id]
	var pl := int(r["pl"])
	var pos := CompetitionManager.position_of(league, club.id)
	card.add_child(UIKit.stat_grid([
		UIKit.stat_tile("%dº" % pos, "posição", UIColors.ACCENT),
		UIKit.stat_tile(str(int(r["pts"])), "pontos"),
		UIKit.stat_tile(_pct(int(r["pts"]), pl * 3.0), "aproveit."),
	], 600))
	if pl == 0:
		card.add_child(UIKit.label("A liga ainda não começou.", "Muted"))
		return UIKit.card_panel(card)
	card.add_child(UIKit.kv("Jogos", "%d · %dV %dE %dD" % [pl, int(r["w"]), int(r["d"]), int(r["l"])]))
	card.add_child(UIKit.kv("Gols", "%d pró · %d contra · saldo %+d" % [int(r["gf"]), int(r["ga"]), int(r["gf"]) - int(r["ga"])]))
	if pl > 0:
		card.add_child(UIKit.kv("Média por jogo", "%s marcados · %s sofridos" % [Fmt.dec(float(r["gf"]) / pl, 1), Fmt.dec(float(r["ga"]) / pl, 1)]))
	# Casa, fora, jogos sem sofrer gol e maior vitória a partir dos jogos da liga.
	var home := [0, 0, 0, 0] # jogos, pontos, gf, ga
	var away := [0, 0, 0, 0]
	var clean := 0
	var blank := 0
	var big := ""
	var big_d := 0
	for rnd: Array in league.rounds:
		for f: Fixture in rnd:
			if not f.played or not f.involves(club.id):
				continue
			var is_home := f.home == club.id
			var gf := f.hg if is_home else f.ag
			var ga := f.ag if is_home else f.hg
			var s: Array = home if is_home else away
			s[0] += 1
			s[1] += 3 if gf > ga else (1 if gf == ga else 0)
			s[2] += gf
			s[3] += ga
			if ga == 0:
				clean += 1
			if gf == 0:
				blank += 1
			if gf - ga > big_d:
				big_d = gf - ga
				var opp := w.club(f.away if is_home else f.home)
				big = "%d x %d no %s" % [gf, ga, opp.short_name] if opp != null else "%d x %d" % [gf, ga]
	card.add_child(UIKit.kv("Em casa", ("%d pts em %d jogo (%s) · %d:%d" if home[0] == 1 else "%d pts em %d jogos (%s) · %d:%d") % [home[1], home[0], _pct(home[1], home[0] * 3.0), home[2], home[3]]))
	card.add_child(UIKit.kv("Fora", ("%d pts em %d jogo (%s) · %d:%d" if away[0] == 1 else "%d pts em %d jogos (%s) · %d:%d") % [away[1], away[0], _pct(away[1], away[0] * 3.0), away[2], away[3]]))
	card.add_child(UIKit.kv("Sem sofrer gol", Fmt.n_of(clean, "%d jogo", "%d jogos")))
	card.add_child(UIKit.kv("Sem marcar", Fmt.n_of(blank, "%d jogo", "%d jogos")))
	if big != "":
		card.add_child(UIKit.kv("Maior vitória", big))
	var form := String(r.get("form", ""))
	if form != "":
		card.add_child(UIKit.kv("Últimos jogos", form.right(5)))
	return UIKit.card_panel(card)


## Média dos 11 melhores do elenco.
static func _xi_avg(w: GameWorld, c: Club) -> float:
	var ovr: Array = w.squad(c).map(func(p: Player) -> int: return p.overall)
	ovr.sort()
	ovr.reverse()
	var n := mini(11, ovr.size())
	var s := 0
	for i in n:
		s += int(ovr[i])
	return float(s) / maxf(1.0, n)


static func _squad_value(w: GameWorld, c: Club) -> float:
	var s := 0.0
	for p: Player in w.squad(c):
		s += p.value
	return s


static func _avg_age(w: GameWorld, c: Club) -> float:
	var sq := w.squad(c)
	var s := 0.0
	for p: Player in sq:
		s += p.age(w.year)
	return s / maxf(1.0, sq.size())


## Posição do clube na liga em vários quesitos.
static func _ranks_card(w: GameWorld, club: Club, league: League) -> Control:
	var card := UIKit.card("Card", 8)
	card.add_child(UIKit.section_header("Na liga"))
	var n := league.club_ids.size()
	var metrics := [
		["Ataque", func(c: Club) -> float: return float(league.row(c.id).get("gf", 0)), true, func(v: float) -> String: return Fmt.n_of(int(v), "%d gol", "%d gols")],
		["Defesa", func(c: Club) -> float: return float(league.row(c.id).get("ga", 0)), false, func(v: float) -> String: return "%d sofridos" % int(v)],
		["Força do time titular", func(c: Club) -> float: return _xi_avg(w, c), true, func(v: float) -> String: return Fmt.dec(v, 1)],
		["Valor do elenco", func(c: Club) -> float: return _squad_value(w, c), true, func(v: float) -> String: return Fmt.money(v)],
		["Folha salarial", func(c: Club) -> float: return float(FinanceManager.wage_bill(w, c)), true, func(v: float) -> String: return Fmt.money(v) + "/mês"],
		["Reputação", func(c: Club) -> float: return c.reputation, true, func(v: float) -> String: return "%d" % int(round(v))],
	]
	var started := int(league.row(club.id).get("pl", 0)) > 0
	for m: Array in metrics:
		if not started and String(m[0]) in ["Ataque", "Defesa"]:
			continue
		var f: Callable = m[1]
		var mine := float(f.call(club))
		var rank := 1
		for id in league.club_ids:
			if int(id) == club.id:
				continue
			var v := float(f.call(w.club(int(id))))
			if (v > mine) if bool(m[2]) else (v < mine):
				rank += 1
		var row := UIKit.hbox(10)
		var name := UIKit.label(String(m[0]), "Muted")
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name)
		row.add_child(UIKit.label((m[3] as Callable).call(mine), "Small"))
		var col := UIColors.GREEN if rank <= maxi(1, n / 4) else (UIColors.RED if rank > n - maxi(1, n / 4) else UIColors.TEXT)
		var rl := UIKit.colored("%dº" % rank, col, "H3")
		rl.custom_minimum_size.x = 48
		rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(rl)
		card.add_child(row)
	card.add_child(UIKit.label("Entre %d clubes" % n, "Small"))
	return UIKit.card_panel(card)


static func _squad_card(w: GameWorld, club: Club) -> Control:
	var card := UIKit.card("Card", 8)
	card.add_child(UIKit.section_header("Elenco"))
	var sq := w.squad(club)
	var foreign := 0
	var ovr := 0.0
	for p: Player in sq:
		ovr += p.overall
		if p.nationality != club.nation:
			foreign += 1
	card.add_child(UIKit.stat_grid([
		UIKit.stat_tile(Fmt.dec(_xi_avg(w, club), 1), "time titular", UIColors.ACCENT),
		UIKit.stat_tile(Fmt.dec(ovr / maxf(1.0, sq.size()), 1), "elenco"),
		UIKit.stat_tile(Fmt.dec(_avg_age(w, club), 1), "idade média"),
	], 600))
	card.add_child(UIKit.kv("Jogadores", "%d · %d estrangeiros" % [sq.size(), foreign]))
	card.add_child(UIKit.kv("Valor do elenco", Fmt.money(_squad_value(w, club))))
	card.add_child(UIKit.kv("Folha salarial", Fmt.money(FinanceManager.wage_bill(w, club)) + "/mês"))
	card.add_child(UIKit.label("Por setor", "Caps"))
	for g in 4:
		var list: Array = sq.filter(func(p: Player) -> bool: return Pos.GROUP[p.position] == g)
		var s := 0.0
		var best: Player = null
		for p: Player in list:
			s += p.overall
			if best == null or p.overall > best.overall:
				best = p
		var txt := "%d · média %s" % [list.size(), Fmt.dec(s / maxf(1.0, list.size()), 1)]
		if best != null:
			txt += " · melhor %s (%d)" % [best.short_name(), best.overall]
		card.add_child(UIKit.kv(Pos.GROUP_NAMES[g], txt))
	return UIKit.card_panel(card)


static func _leaders_card(w: GameWorld, club: Club) -> Control:
	var card := UIKit.card("Card", 8)
	card.add_child(UIKit.section_header("Destaques da temporada (liga)"))
	var sq := w.squad(club)
	var any := false
	var cats := [
		["Artilheiro", func(p: Player) -> float: return p.stat(Player.S_GOALS), func(p: Player) -> String: return Fmt.n_of(p.stat(Player.S_GOALS), "%d gol", "%d gols")],
		["Assistências", func(p: Player) -> float: return p.stat(Player.S_ASSISTS), func(p: Player) -> String: return "%d assist." % p.stat(Player.S_ASSISTS)],
		["Melhor nota", func(p: Player) -> float: return p.avg_rating() if p.stat(Player.S_APPS) >= 3 else 0.0, func(p: Player) -> String: return "%s em %d jogos" % [Fmt.dec(p.avg_rating(), 2), p.stat(Player.S_APPS)]],
		["Mais minutos", func(p: Player) -> float: return p.stat(Player.S_MINUTES), func(p: Player) -> String: return "%d min" % p.stat(Player.S_MINUTES)],
		["Craque do jogo", func(p: Player) -> float: return p.stat(Player.S_MOTM), func(p: Player) -> String: return "%dx" % p.stat(Player.S_MOTM)],
		["Gols por 90", func(p: Player) -> float: return p.per90(Player.S_GOALS) if p.stat(Player.S_MINUTES) >= 900 else 0.0, func(p: Player) -> String: return Fmt.dec(p.per90(Player.S_GOALS), 2)],
		["Passes decisivos", func(p: Player) -> float: return p.stat(Player.S_KEY_PASSES), func(p: Player) -> String: return "%d" % p.stat(Player.S_KEY_PASSES)],
		["Desarmes", func(p: Player) -> float: return p.stat(Player.S_TACKLES), func(p: Player) -> String: return "%d" % p.stat(Player.S_TACKLES)],
		["Interceptações", func(p: Player) -> float: return p.stat(Player.S_INTERCEPTIONS), func(p: Player) -> String: return "%d" % p.stat(Player.S_INTERCEPTIONS)],
		["Duelos aéreos", func(p: Player) -> float: return p.stat(Player.S_AERIAL), func(p: Player) -> String: return "%d" % p.stat(Player.S_AERIAL)],
		["Defesas (goleiro)", func(p: Player) -> float: return p.stat(Player.S_SAVES), func(p: Player) -> String: return "%d" % p.stat(Player.S_SAVES)],
		["Sem sofrer gol", func(p: Player) -> float: return p.stat(Player.S_CLEAN) if p.position == Pos.GK else 0.0, func(p: Player) -> String: return Fmt.n_of(p.stat(Player.S_CLEAN), "%d jogo", "%d jogos")],
		["Cartões", func(p: Player) -> float: return p.stat(Player.S_YELLOWS) + 3 * p.stat(Player.S_REDS), func(p: Player) -> String: return Fmt.n_of(p.stat(Player.S_YELLOWS), "%d amarelo", "%d amarelos") + " · " + Fmt.n_of(p.stat(Player.S_REDS), "%d vermelho", "%d vermelhos")],
	]
	for cat: Array in cats:
		var f: Callable = cat[1]
		var best: Player = null
		var bv := 0.0
		for p: Player in sq:
			var v := float(f.call(p))
			if v > bv:
				bv = v
				best = p
		if best == null:
			continue
		any = true
		var pid := best.id
		var h := UIKit.hbox(10)
		var k := UIKit.label(String(cat[0]), "Muted")
		k.custom_minimum_size.x = 180
		h.add_child(k)
		var nm := UIKit.label(best.short_name(), "H3")
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		h.add_child(nm)
		h.add_child(UIKit.label((cat[2] as Callable).call(best), "Small"))
		card.add_child(UIKit.tap_row(h, func(): UIManager.push("player", {"id": pid}), "RowPanel"))
	if not any:
		card.add_child(UIKit.label("A temporada ainda não começou.", "Muted"))
	return UIKit.card_panel(card)


func color_context() -> Dictionary:
	return club_context(_club_id)
