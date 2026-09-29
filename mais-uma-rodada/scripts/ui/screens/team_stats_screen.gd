extends BaseScreen
class_name TeamStatsScreen
## Estatísticas de equipe (do seu time ou de qualquer outro): campanha, casa e fora, posição na
## liga em cada quesito, perfil do elenco e destaques da temporada. Os cartões também aparecem
## na aba "Estatísticas" da tela do clube.

var _club_id := -1


func _init() -> void:
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
	return out


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
	var head := UIKit.hbox(6)
	var hn := UIKit.label("JOGADOR", "Caps")
	hn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hn)
	var cols := ["J", "G", "A", "NOTA"] + (["MIN"] if current else [])
	for t in cols:
		head.add_child(_cell(t, "Caps", 58 if t == "MIN" else 46))
	body.add_child(head)
	var tot := [0, 0, 0]
	for r: Dictionary in rows:
		tot[0] += int(r.get("a", 0))
		tot[1] += int(r.get("g", 0))
		tot[2] += int(r.get("as", 0))
		var h := UIKit.hbox(6)
		h.add_child(UIKit.pos_badge(int(r.get("pos", 0))))
		var nm := UIKit.label(String(r.get("n", "")), "")
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nm.custom_minimum_size.x = 40
		h.add_child(nm)
		h.add_child(_cell(str(int(r.get("a", 0))), "", 46))
		h.add_child(_cell(str(int(r.get("g", 0))), "H3" if int(r.get("g", 0)) > 0 else "", 46))
		h.add_child(_cell(str(int(r.get("as", 0))), "", 46))
		var rt := float(r.get("r", 0.0))
		var rl := _cell("%.2f" % rt if rt > 0.0 else "—", "", 46)
		if rt >= 7.2:
			rl.add_theme_color_override(&"font_color", UIColors.GREEN)
		elif rt > 0.0 and rt < 6.3:
			rl.add_theme_color_override(&"font_color", UIColors.RED)
		h.add_child(rl)
		if current:
			h.add_child(_cell(str(int(r.get("m", 0))), "Small", 58))
		var pid := int(r.get("id", -1))
		if w.player(pid) != null:
			body.add_child(UIKit.tap_row(h, func(): UIManager.push("player", {"id": pid}), "RowPanel"))
		else:
			body.add_child(h)
	body.add_child(UIKit.label("Total: %d jogos · %d gols · %d assistências (liga e copas)" % tot, "Small", true))


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
		card.add_child(UIKit.kv("Média por jogo", "%.1f marcados · %.1f sofridos" % [float(r["gf"]) / pl, float(r["ga"]) / pl]))
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
	card.add_child(UIKit.kv("Em casa", "%d pts em %d jogos (%s) · %d:%d" % [home[1], home[0], _pct(home[1], home[0] * 3.0), home[2], home[3]]))
	card.add_child(UIKit.kv("Fora", "%d pts em %d jogos (%s) · %d:%d" % [away[1], away[0], _pct(away[1], away[0] * 3.0), away[2], away[3]]))
	card.add_child(UIKit.kv("Sem sofrer gol", "%d jogos" % clean))
	card.add_child(UIKit.kv("Sem marcar", "%d jogos" % blank))
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
		["Ataque", func(c: Club) -> float: return float(league.row(c.id).get("gf", 0)), true, func(v: float) -> String: return "%d gols" % int(v)],
		["Defesa", func(c: Club) -> float: return float(league.row(c.id).get("ga", 0)), false, func(v: float) -> String: return "%d sofridos" % int(v)],
		["Força do time titular", func(c: Club) -> float: return _xi_avg(w, c), true, func(v: float) -> String: return "%.1f" % v],
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
		UIKit.stat_tile("%.1f" % _xi_avg(w, club), "time titular", UIColors.ACCENT),
		UIKit.stat_tile("%.1f" % (ovr / maxf(1.0, sq.size())), "elenco"),
		UIKit.stat_tile("%.1f" % _avg_age(w, club), "idade média"),
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
		var txt := "%d · média %.1f" % [list.size(), s / maxf(1.0, list.size())]
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
		["Artilheiro", func(p: Player) -> float: return p.stat(Player.S_GOALS), func(p: Player) -> String: return "%d gols" % p.stat(Player.S_GOALS)],
		["Assistências", func(p: Player) -> float: return p.stat(Player.S_ASSISTS), func(p: Player) -> String: return "%d assist." % p.stat(Player.S_ASSISTS)],
		["Melhor nota", func(p: Player) -> float: return p.avg_rating() if p.stat(Player.S_APPS) >= 3 else 0.0, func(p: Player) -> String: return "%.2f em %d jogos" % [p.avg_rating(), p.stat(Player.S_APPS)]],
		["Mais minutos", func(p: Player) -> float: return p.stat(Player.S_MINUTES), func(p: Player) -> String: return "%d min" % p.stat(Player.S_MINUTES)],
		["Craque do jogo", func(p: Player) -> float: return p.stat(Player.S_MOTM), func(p: Player) -> String: return "%dx" % p.stat(Player.S_MOTM)],
		["Desarmes", func(p: Player) -> float: return p.stat(Player.S_TACKLES), func(p: Player) -> String: return "%d" % p.stat(Player.S_TACKLES)],
		["Defesas (goleiro)", func(p: Player) -> float: return p.stat(Player.S_SAVES), func(p: Player) -> String: return "%d" % p.stat(Player.S_SAVES)],
		["Cartões", func(p: Player) -> float: return p.stat(Player.S_YELLOWS) + 3 * p.stat(Player.S_REDS), func(p: Player) -> String: return "%d amarelos · %d vermelhos" % [p.stat(Player.S_YELLOWS), p.stat(Player.S_REDS)]],
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
		k.custom_minimum_size.x = 150
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
