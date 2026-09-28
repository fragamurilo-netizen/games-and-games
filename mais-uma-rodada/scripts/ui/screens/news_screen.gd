extends BaseScreen
## Portal de notícias. Cada país tem o seu site (nome, cores da liga, manchetes de lá): troque o
## país no alto. Editorias em abas: capa, seu clube, mercado, resultados, tabela e artilharia,
## opinião (colunas geradas dos números) e o resto do mundo. Toque numa matéria para ler inteira.

const SECTIONS := [["capa", "Capa"], ["mine", "Meu clube"], ["market", "Mercado"], ["results", "Resultados"], ["table", "Tabela"], ["opinion", "Opinião"], ["world", "Mundo"], ["nat", "Seleções"]]
const PAGE := 30
## Portais fictícios por país (os demais usam o nome genérico com o país).
const PORTALS := {
	"BRA": "Bola na Rede", "ENG": "The Matchday Post", "ESP": "El Balón Diario", "ITA": "Calcio Oggi",
	"GER": "Fußball Heute", "FRA": "Le Ballon", "POR": "Bola Viva", "ARG": "Pase al Gol", "USA": "Pitch Report",
	"MEX": "La Cancha MX", "NED": "Voetbal Vandaag", "KSA": "Arabian Football Review", "TUR": "Futbol Gündemi",
	"URU": "La Celeste Hoy", "COL": "Golazo Colombia", "CHI": "El Arco", "BEL": "Voetbal Belgie", "SCO": "The Terrace Scot",
}

var _section := "capa"
var _nation := ""
var _limit := PAGE


func _init() -> void:
	show_nav = false
	screen_title = "Notícias"


func setup(p: Dictionary) -> void:
	if p.has("tab"):
		_section = String(p["tab"])
	if p.has("nation"):
		_nation = String(p["nation"])


func on_show() -> void:
	refresh()
	# O que foi exibido agora conta como lido (os marcadores de "nova" ficam até sair da tela).
	var w := world()
	if w != null:
		for n: NewsEvent in w.news:
			n.read = true


static func portal_name(nation: String) -> String:
	return String(PORTALS.get(nation, "Diário da Bola · %s" % DatabaseManager.nation_name(nation)))


func refresh() -> void:
	var w := world()
	if w == null:
		return
	if _nation == "":
		_nation = w.user_nation() if w.has_user() else "BRA"
	max_content_width = 1700
	screen_title = portal_name(_nation)
	screen_subtitle = "Temporada %d · %s" % [w.year, DatabaseManager.nation_name(_nation)]
	UIManager.refresh_chrome()
	var c := content()
	UIKit.clear(c)
	c.add_child(_masthead(w))
	c.add_child(UIKit.scroll_tabs(SECTIONS, _section, func(k: String):
		_section = k
		_limit = PAGE
		refresh()
		scroll_to_top()))
	match _section:
		"market":
			_market(w, c)
		"results":
			_results(w, c)
		"table":
			_table(w, c)
		"opinion":
			_opinion(w, c)
		_:
			_feed(w, c)


## Cabeçalho do portal nas cores da liga do país, com a troca de país.
func _masthead(w: GameWorld) -> Control:
	var v := UIKit.vbox(8)
	var lid := Reputation.top_league_of(_nation)
	var cols: Array = DatabaseManager.league_cfg(lid).get("colors", []) if lid != "" else []
	var bar := UIKit.hbox(10)
	bar.add_child(UIKit.flag(_nation, 44))
	var t := UIKit.label(portal_name(_nation).to_upper(), "Title")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if cols.size() >= 2:
		t.add_theme_color_override(&"font_color", Color(String(cols[1])) if Color(String(cols[1])).get_luminance() > 0.35 else UIColors.ACCENT)
	bar.add_child(t)
	v.add_child(bar)
	if cols.size() >= 2:
		var stripe := UIKit.comp_stripe(lid, 6)
		v.add_child(stripe)
	# Países: o seu primeiro, depois as ligas mais fortes com notícias
	var nations: Array = []
	if w.has_user():
		nations.append(w.user_nation())
	for code in ["BRA", "ENG", "ESP", "ITA", "GER", "FRA", "POR", "ARG", "NED", "USA", "MEX", "KSA"]:
		if not nations.has(code) and DatabaseManager.has_nation(code) and Reputation.top_league_of(code) != "":
			nations.append(code)
	if not nations.has(_nation):
		nations.append(_nation)
	var items: Array = []
	for code in nations:
		items.append([code, DatabaseManager.nation_name(code)])
	v.add_child(UIKit.scroll_tabs(items, _nation, func(k: String):
		_nation = k
		_limit = PAGE
		refresh()
		scroll_to_top()))
	return v


## País de uma notícia ("" se não der para saber).
static func nation_of(w: GameWorld, n: NewsEvent) -> String:
	var c := w.club(n.club_id) if n.club_id >= 0 else null
	if c == null and n.player_id >= 0:
		var p := w.player(n.player_id)
		if p != null and p.club_id >= 0:
			c = w.club(p.club_id)
	if c != null:
		return c.nation
	return String(n.media.get("code", ""))


func _passes(w: GameWorld, n: NewsEvent) -> bool:
	var nat := nation_of(w, n)
	match _section:
		"mine":
			if not w.has_user():
				return false
			var user := w.user_club()
			if n.club_id == user.id:
				return true
			var p := w.player(n.player_id) if n.player_id >= 0 else null
			return p != null and p.club_id == user.id
		"world":
			return nat != _nation
		"nat":
			return n.category == "selecao"
	return nat == _nation or nat == ""


func _feed(w: GameWorld, c: VBoxContainer) -> void:
	var items: Array = []
	for i in range(w.news.size() - 1, -1, -1):
		var n: NewsEvent = w.news[i]
		if _passes(w, n):
			items.append(n)
	if items.is_empty():
		var empty := UIKit.card("CardFlat", 10)
		empty.add_child(UIKit.icon_rect("news", 48, UIColors.DIM))
		empty.add_child(UIKit.label("Nenhuma notícia nesta editoria ainda.", "Muted"))
		c.add_child(UIKit.card_panel(empty))
		return
	# Manchete: importância, arte e recência.
	var lead: NewsEvent = items[0]
	var best := -1
	for k in mini(10, items.size()):
		var n: NewsEvent = items[k]
		if n.year != (items[0] as NewsEvent).year or n.day < (items[0] as NewsEvent).day - 2:
			break
		var score := n.importance * 10 + (1 if not n.media.is_empty() else 0)
		if score > best:
			best = score
			lead = n
	c.add_child(NewsRow.hero(w, lead))
	var cards: Array = []
	var last_key := ""
	var group: Array = []
	var title := ""
	var shown := 0
	var has_more := false
	for n: NewsEvent in items:
		if n == lead:
			continue
		if shown >= _limit:
			has_more = true
			break
		var key := "%d-%d" % [n.year, n.day]
		if key != last_key:
			if not group.is_empty():
				cards.append(_round_card(title, group))
			group = []
			last_key = key
			title = tr("Rodada %d · %d") % [n.day + 1, n.year] if n.day < 38 else tr("Temporada %d") % n.year
		if n.importance >= NewsEvent.IMP_HEADLINE or (n.importance >= NewsEvent.IMP_HIGH and String(n.media.get("type", "")) == "signing"):
			group.append(NewsRow.feature(w, n, 220, false))
		else:
			group.append(NewsRow.item(w, n))
		shown += 1
	if not group.is_empty():
		cards.append(_round_card(title, group))
	var holder := UIKit.vbox(UITokens.S4)
	c.add_child(holder)
	UIKit.columns(holder, cards, content_width())
	if has_more:
		c.add_child(UIKit.button("Mostrar mais notícias", "GhostButton", func():
			_limit += PAGE
			refresh(), "list"))


func _round_card(title: String, rows: Array) -> Control:
	var v := UIKit.vbox(UITokens.S2)
	v.add_child(UIKit.section_header(title))
	v.add_child(UIKit.menu_group(rows))
	return v


# ---------------------------------------------------------------------------
# Mercado do país
# ---------------------------------------------------------------------------

func _market(w: GameWorld, c: VBoxContainer) -> void:
	var rows: Array = []
	for i in range(w.transfer_log.size() - 1, -1, -1):
		var t: Transfer = w.transfer_log[i]
		var to := w.club(t.to_id)
		var from := w.club(t.from_id)
		if (to != null and to.nation == _nation) or (from != null and from.nation == _nation):
			rows.append(t)
	var top := rows.duplicate()
	top.sort_custom(func(a: Transfer, b: Transfer): return a.fee > b.fee)
	var cards: Array = []
	var big := UIKit.card("Card", 6)
	big.add_child(UIKit.section_header("Maiores negócios"))
	for t: Transfer in top.slice(0, 8):
		big.add_child(_transfer_row(w, t))
	if top.is_empty():
		big.add_child(UIKit.label("Nenhuma transferência neste país ainda.", "Muted"))
	cards.append(UIKit.card_panel(big))
	var last := UIKit.card("Card", 6)
	last.add_child(UIKit.section_header("Últimas movimentações"))
	for t: Transfer in rows.slice(0, 20):
		last.add_child(_transfer_row(w, t))
	cards.append(UIKit.card_panel(last))
	UIKit.columns(c, cards, content_width())


func _transfer_row(w: GameWorld, t: Transfer) -> Control:
	var to := w.club(t.to_id)
	var from := w.club(t.from_id)
	var h := UIKit.hbox(10)
	if to != null:
		h.add_child(UIKit.crest(to, 30))
	var col := UIKit.vbox(0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nm := UIKit.label("%s (%d anos, %d)" % [t.player_name, t.age, t.overall], "H3")
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(nm)
	col.add_child(UIKit.label("%s → %s · rodada %d" % [from.short_name if from != null else "livre", to.short_name if to != null else "sem clube", t.day + 1], "Small"))
	h.add_child(col)
	h.add_child(UIKit.label(Fmt.money(t.fee) if t.fee > 0 else Transfer.KIND_NAMES[t.kind], "Small"))
	var pid := t.player_id
	return UIKit.tap_row(h, func():
		if w.player(pid) != null:
			UIManager.push("player", {"id": pid}), "RowPanel")


# ---------------------------------------------------------------------------
# Resultados, tabela e artilharia da liga principal do país
# ---------------------------------------------------------------------------

func _league(w: GameWorld) -> League:
	var lid := Reputation.top_league_of(_nation)
	return w.league(lid) if lid != "" else null


func _results(w: GameWorld, c: VBoxContainer) -> void:
	var lg := _league(w)
	if lg == null:
		c.add_child(UIKit.label("Este país não tem liga no jogo.", "Muted"))
		return
	var last := -1
	for r in lg.rounds.size():
		var any := false
		for f: Fixture in lg.rounds[r]:
			if f.played:
				any = true
		if any:
			last = r
	var cards: Array = []
	for r in [last, last + 1]:
		if r < 0 or r >= lg.rounds.size():
			continue
		var card := UIKit.card("Card", 6)
		card.add_child(UIKit.section_header("%s · rodada %d%s" % [w.league_short(lg.id), r + 1, "" if r == last else " (próxima)"]))
		for f: Fixture in lg.rounds[r]:
			var hc := w.club(f.home)
			var ac := w.club(f.away)
			var h := UIKit.hbox(8)
			var hn := UIKit.label(hc.short_name, "")
			hn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hn.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			hn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			h.add_child(hn)
			h.add_child(UIKit.crest(hc, 24))
			var sc := UIKit.label("%d x %d" % [f.hg, f.ag] if f.played else "x", "H3")
			sc.custom_minimum_size.x = 64
			sc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			h.add_child(sc)
			h.add_child(UIKit.crest(ac, 24))
			var an := UIKit.label(ac.short_name, "")
			an.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			an.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			h.add_child(an)
			card.add_child(h)
		cards.append(UIKit.card_panel(card))
	if cards.is_empty():
		c.add_child(UIKit.label("A liga ainda não começou.", "Muted"))
		return
	UIKit.columns(c, cards, content_width())


func _table(w: GameWorld, c: VBoxContainer) -> void:
	var lg := _league(w)
	if lg == null:
		c.add_child(UIKit.label("Este país não tem liga no jogo.", "Muted"))
		return
	var cards: Array = []
	var tc := UIKit.card("Card", 4)
	tc.add_child(UIKit.section_header(w.league_name(lg.id)))
	var ids := CompetitionManager.sorted_ids(lg)
	for i in ids.size():
		var cl := w.club(int(ids[i]))
		var r: Dictionary = lg.table[cl.id]
		var h := UIKit.hbox(8)
		var pl := UIKit.label("%d" % (i + 1), "Mono")
		pl.custom_minimum_size.x = 30
		h.add_child(pl)
		h.add_child(UIKit.crest(cl, 24))
		var nm := UIKit.label(cl.short_name, "")
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(nm)
		h.add_child(UIKit.label("%d j · %+d" % [int(r["pl"]), int(r["gf"]) - int(r["ga"])], "Small"))
		var pts := UIKit.label(str(int(r["pts"])), "H3")
		pts.custom_minimum_size.x = 40
		pts.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(pts)
		var cid := cl.id
		tc.add_child(UIKit.tap_row(h, func():
			if w.is_user_club(cid):
				UIManager.goto("club")
			else:
				UIManager.push("club", {"id": cid}), "RowPanel"))
	cards.append(UIKit.card_panel(tc))
	var sc := UIKit.card("Card", 4)
	sc.add_child(UIKit.section_header("Artilharia"))
	for e: Array in _leaders(w, lg, Player.S_GOALS, 12):
		sc.add_child(_leader_row(w, e[0], "%d gols" % int(e[1])))
	sc.add_child(UIKit.section_header("Assistências"))
	for e: Array in _leaders(w, lg, Player.S_ASSISTS, 6):
		sc.add_child(_leader_row(w, e[0], "%d assist." % int(e[1])))
	cards.append(UIKit.card_panel(sc))
	UIKit.columns(c, cards, content_width())


func _leaders(w: GameWorld, lg: League, stat: int, n: int) -> Array:
	var out: Array = []
	for id in lg.club_ids:
		for p: Player in w.squad(w.club(int(id))):
			if p.stats[stat] > 0:
				out.append([p, p.stats[stat]])
	out.sort_custom(func(a, b): return int(a[1]) > int(b[1]))
	return out.slice(0, n)


func _leader_row(w: GameWorld, p: Player, txt: String) -> Control:
	var h := UIKit.hbox(8)
	h.add_child(UIKit.pos_badge(p.position))
	var nm := UIKit.label("%s · %s" % [p.short_name(), w.club(p.club_id).short_name], "")
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	h.add_child(nm)
	h.add_child(UIKit.label(txt, "H3"))
	var pid := p.id
	return UIKit.tap_row(h, func(): UIManager.push("player", {"id": pid}), "RowPanel")


# ---------------------------------------------------------------------------
# Opinião: colunas geradas dos números da liga
# ---------------------------------------------------------------------------

func _opinion(w: GameWorld, c: VBoxContainer) -> void:
	var lg := _league(w)
	if lg == null or lg.table.is_empty():
		c.add_child(UIKit.label("Sem liga para comentar.", "Muted"))
		return
	var ids := CompetitionManager.sorted_ids(lg)
	var cards: Array = []
	var started := int(lg.table[int(ids[0])]["pl"]) >= 3
	if not started:
		c.add_child(UIKit.label("As colunas começam depois das primeiras rodadas da %s." % w.league_short(lg.id), "Muted", true))
		return
	# Power ranking: pontos recentes (forma) + posição
	var pr: Array = []
	for id in ids:
		var cl := w.club(int(id))
		var form := cl.results.right(5)
		var fp := form.count("V") * 3 + form.count("E")
		pr.append([cl, fp * 2.0 - ids.find(id) * 0.6])
	pr.sort_custom(func(a, b): return float(a[1]) > float(b[1]))
	var pc := UIKit.card("Card", 6)
	pc.add_child(UIKit.section_header("Power ranking"))
	pc.add_child(UIKit.label("Quem chega melhor: forma nos últimos cinco jogos pesa mais que a tabela.", "Small", true))
	for i in mini(6, pr.size()):
		var cl: Club = pr[i][0]
		pc.add_child(UIKit.kv("%d. %s" % [i + 1, cl.short_name], "%s · %dº" % [cl.results.right(5), ids.find(cl.id) + 1]))
	cards.append(UIKit.card_panel(pc))
	# Decepção e surpresa: posição contra a reputação
	var by_rep := ids.duplicate()
	by_rep.sort_custom(func(a, b): return w.club(int(a)).reputation > w.club(int(b)).reputation)
	var worst: Club = null
	var worst_d := 0
	var best_c: Club = null
	var best_d := 0
	for id in ids:
		var d := ids.find(id) - by_rep.find(id)
		if d > worst_d:
			worst_d = d
			worst = w.club(int(id))
		if -d > best_d:
			best_d = -d
			best_c = w.club(int(id))
	var col := UIKit.card("Card", 8)
	col.add_child(UIKit.section_header("Coluna da semana"))
	if worst != null and worst_d >= 4:
		col.add_child(UIKit.label("O que acontece com o %s?" % worst.short_name, "H3", true))
		col.add_child(UIKit.label("Pelo tamanho do clube, era para estar %d posições acima. Hoje é %dº, com %s nos últimos jogos. A cobrança vai aumentar." % [worst_d, ids.find(worst.id) + 1, worst.results.right(5)], "", true))
	if best_c != null and best_d >= 4:
		col.add_child(UIKit.label("A surpresa tem nome: %s" % best_c.short_name, "H3", true))
		col.add_child(UIKit.label("Ninguém apostava, mas o %s está %d posições acima do que o elenco sugere. É %dº hoje." % [best_c.short_name, best_d, ids.find(best_c.id) + 1], "", true))
	if (worst == null or worst_d < 4) and (best_c == null or best_d < 4):
		col.add_child(UIKit.label("Liga sem grandes surpresas até aqui: a tabela respeita o tamanho de cada um.", "", true))
	cards.append(UIKit.card_panel(col))
	# Destaques individuais: melhor nota e revelação
	var best_p: Player = null
	var young: Player = null
	for id in lg.club_ids:
		for p: Player in w.squad(w.club(int(id))):
			if p.stats[Player.S_APPS] < 3:
				continue
			if best_p == null or p.avg_rating() > best_p.avg_rating():
				best_p = p
			if p.age(w.year) <= 21 and (young == null or p.avg_rating() > young.avg_rating()):
				young = p
	var dc := UIKit.card("Card", 6)
	dc.add_child(UIKit.section_header("Em alta"))
	if best_p != null:
		dc.add_child(_leader_row(w, best_p, "nota %.2f" % best_p.avg_rating()))
	if young != null:
		dc.add_child(UIKit.label("Revelação (até 21 anos)", "Caps"))
		dc.add_child(_leader_row(w, young, "nota %.2f" % young.avg_rating()))
	cards.append(UIKit.card_panel(dc))
	UIKit.columns(c, cards, content_width())


func color_context() -> Dictionary:
	var w := GameManager.world
	if w == null or _nation == "" or (w.has_user() and _nation == w.user_nation()):
		return {}
	var lid := Reputation.top_league_of(_nation)
	return {"league": lid} if lid != "" else {}
