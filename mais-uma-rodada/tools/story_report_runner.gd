extends Node
## Lógica de tools/story_report.gd (carregada depois dos autoloads).

const TOP_LEAGUES := ["ENG1", "ESP1", "GER1", "ITA1", "FRA1", "POR1", "NED1", "BRA1", "ARG1", "MEX1", "USA1", "TUR1"]

var opt_seasons := "5"
var opt_league := "BRA1"
var opt_seed := ""

var champs := {} # liga -> [ids]
var races: Array = [] # [liga, ano, pontos de diferença, rank esperado do campeão]
var dev_rows: Array = [] # [idade, delta overall]
var top_sets: Array = [] # conjuntos dos 50 melhores por temporada
var star_moves: Array = [] # [ano, nome, de, para, taxa, ovr]
var news_titles: Array = []
var news_cats := {}
var event_kinds := {}
var season_lines: Array = []
var _seen_news := {}
var squad_rows: Array = [] # [ano, idade média, tamanho, crias da base com minutos] dos grandes
var rep0 := {}


func _ready() -> void:
	var seed_v := int(opt_seed) if opt_seed != "" else WorldGenerator.DEFAULT_SEED
	var w := WorldGenerator.generate(seed_v, "padrao")
	AppSettings.tutorial_done = true
	GameManager.start_career(w, w.clubs_in_league(opt_league)[4].id, "Teste", GameWorld.DIFF_NORMAL, 9)
	GameManager.slot = -1 # sem gravar
	for c: Club in w.clubs:
		rep0[c.id] = c.reputation
	for s in int(opt_seasons):
		var t0 := Time.get_ticks_msec()
		_season(w)
		print("temporada %d: %d s" % [s + 1, (Time.get_ticks_msec() - t0) / 1000])
	_report(w)
	get_tree().quit()


func _season(w: GameWorld) -> void:
	var ovr0 := {}
	for p: Player in w.players.values():
		ovr0[p.id] = p.ovr_f
	var exp := {}
	for lid in TOP_LEAGUES:
		var cl := w.clubs_in_league(lid)
		cl.sort_custom(func(a: Club, b: Club): return ClubAI.team_strength(w, a) > ClubAI.team_strength(w, b))
		for i in cl.size():
			exp[cl[i].id] = i + 1
	var ev_seen := {}
	var guard := 0
	while not GameManager.season_over() and guard < 400:
		guard += 1
		var c := w.user_club()
		if c.sheet != null:
			c.sheet = ClubAI.auto_sheet(w, c, c.sheet.formation)
		var before := w.events.size()
		var r := GameManager.play_instant()
		_collect_news(w)
		if r.is_empty() and not GameManager.season_over():
			GameManager.advance_to_end()
		for ev in w.events:
			var k := String(ev.get("type", ev.get("k", "?")))
			if not ev_seen.has(ev.get("id", -1)):
				ev_seen[ev.get("id", -1)] = true
				event_kinds[k] = int(event_kinds.get(k, 0)) + 1
		# O piloto automático recusa tudo: eventos e propostas não travam a temporada.
		w.events.clear()
		w.offers.clear()
	# Final da temporada: tabelas das ligas grandes antes de virar o ano.
	for lid in TOP_LEAGUES:
		var lg := w.league(lid)
		if lg == null:
			continue
		var order := CompetitionManager.sort_table(lg.table.keys(), lg.table)
		var ch: int = order[0]
		if not champs.has(lid):
			champs[lid] = []
		champs[lid].append(ch)
		var gap := int(lg.table[order[0]]["pts"]) - int(lg.table[order[1]]["pts"])
		races.append([lid, w.year, gap, int(exp.get(ch, 0))])
	for t: Transfer in w.transfer_log:
		if t.year == w.year and t.overall >= 78 and t.fee > 0:
			star_moves.append([t.year, t.player_name, _cn(w, t.from_id), _cn(w, t.to_id), t.fee, t.overall, t.age])
	_collect_news(w)
	# Elencos dos 4 maiores clubes de cada liga grande
	var ages := 0.0
	var sizes := 0.0
	var hg := 0.0
	var nclubs := 0
	for lid in TOP_LEAGUES:
		var cl := w.clubs_in_league(lid)
		cl.sort_custom(func(a: Club, b: Club): return a.reputation > b.reputation)
		for c: Club in cl.slice(0, 4):
			var sq := w.squad(c)
			nclubs += 1
			sizes += sq.size()
			for p: Player in sq:
				ages += p.age(w.year)
				var sp: Array = p.spells
				if not sp.is_empty() and int(sp[0].get("c", -1)) == c.id and p.minutes_season >= 900:
					hg += 1
	squad_rows.append([w.year, ages / maxf(1.0, sizes), sizes / maxf(1, nclubs), hg / maxf(1, nclubs)])
	var ranked: Array = w.players.values().filter(func(p: Player): return p.club_id >= 0)
	ranked.sort_custom(func(a: Player, b: Player): return a.ovr_f > b.ovr_f)
	var top := {}
	for i in mini(50, ranked.size()):
		top[ranked[i].id] = true
	top_sets.append(top)
	SeasonManager.timings.clear()
	GameManager.end_season()
	_collect_news(w)
	for p: Player in w.players.values():
		if ovr0.has(p.id):
			dev_rows.append([p.age(w.year - 1), p.ovr_f - float(ovr0[p.id])])


## A lista do mundo guarda só as últimas notícias: conta cada uma quando aparece.
func _collect_news(w: GameWorld) -> void:
	for n: NewsEvent in w.news:
		var k := n.get_instance_id()
		if _seen_news.has(k):
			continue
		_seen_news[k] = true
		news_titles.append(n.title)
		news_cats[n.category] = int(news_cats.get(n.category, 0)) + 1


func _cn(w: GameWorld, id: int) -> String:
	var c := w.club(id)
	return c.short_name if c != null else "livre"


func _report(w: GameWorld) -> void:
	print("\n=== DISPUTA PELOS TÍTULOS ===")
	for lid in champs:
		var ids: Array = champs[lid]
		var uniq := {}
		for i in ids:
			uniq[i] = true
		var names: Array = ids.map(func(i): return _cn(w, int(i)))
		print("%-5s %d campeões diferentes em %d: %s" % [lid, uniq.size(), ids.size(), ", ".join(names)])
	var gaps: Array = races.map(func(r): return int(r[2]))
	var close := gaps.filter(func(g): return g <= 3).size()
	var surprise := races.filter(func(r): return int(r[3]) >= 3).size()
	print("disputas decididas por até 3 pontos: %d de %d; campeão fora dos 2 favoritos: %d" % [close, races.size(), surprise])
	print("\n=== VIDA DOS JOGADORES (variação do overall numa temporada) ===")
	for band in [[16, 19], [20, 22], [23, 26], [27, 29], [30, 32], [33, 40]]:
		var ds: Array = dev_rows.filter(func(r): return int(r[0]) >= band[0] and int(r[0]) <= band[1]).map(func(r): return float(r[1]))
		if ds.is_empty():
			continue
		ds.sort()
		var n := ds.size()
		var up := ds.filter(func(d): return d >= 6.0).size()
		var down := ds.filter(func(d): return d <= -5.0).size()
		print("%2d-%2d anos: n=%5d  mediana %+.1f  p10 %+.1f  p90 %+.1f  saltos>=+6: %.1f%%  quedas<=-5: %.1f%%" % [band[0], band[1], n,
			ds[n / 2], ds[n / 10], ds[n * 9 / 10], 100.0 * up / n, 100.0 * down / n])
	var churn: Array = []
	for i in range(1, top_sets.size()):
		var new := 0
		for id in top_sets[i]:
			if not top_sets[i - 1].has(id):
				new += 1
		churn.append(new)
	print("renovação do top 50 mundial por temporada: %s" % str(churn))
	var young := w.players.values().filter(func(p: Player): return p.age(w.year) <= 21 and p.ovr_f >= 75.0).size()
	print("garotos (≤21) com 75+ no fim: %d" % young)
	print("\n=== ELENCOS DOS GRANDES (4 maiores de cada liga) ===")
	for r in squad_rows:
		print("  %d: idade média %.1f · %.1f jogadores · %.1f crias da base com 900+ min" % [r[0], r[1], r[2], r[3]])
	var ups: Array = []
	var downs: Array = []
	for c: Club in w.clubs:
		var d := c.reputation - float(rep0.get(c.id, c.reputation))
		if d >= 5.0:
			ups.append("%s %+.0f" % [c.short_name, d])
		elif d <= -5.0:
			downs.append("%s %+.0f" % [c.short_name, d])
	print("clubes que subiram de patamar (reputação +5): %d · caíram (−5): %d" % [ups.size(), downs.size()])
	print("  subiram: %s" % ", ".join(ups.slice(0, 15)))
	print("  caíram: %s" % ", ".join(downs.slice(0, 15)))
	print("\n=== MERCADO DAS ESTRELAS (78+) ===")
	print("transferências: %d" % star_moves.size())
	for m in star_moves.slice(0, 25):
		print("  %d %s (%d anos, %d): %s → %s por %s" % [m[0], m[1], m[6], m[5], m[2], m[3], Fmt.money(int(m[4]))])
	print("\n=== NOTÍCIAS ===")
	print("total: %d em %s temporadas" % [news_titles.size(), opt_seasons])
	var skel := {}
	var re := RegEx.create_from_string("[0-9]+|[A-ZÁÉÍÓÚÂÊÔÃÕÇ][\\wÀ-ú'.-]*")
	for t in news_titles:
		var k := re.sub(String(t), "#", true)
		skel[k] = int(skel.get(k, 0)) + 1
	var sk: Array = skel.keys()
	sk.sort_custom(func(a, b): return skel[a] > skel[b])
	print("moldes diferentes: %d (de %d notícias)" % [sk.size(), news_titles.size()])
	for k in sk.slice(0, 15):
		print("  %4d× %s" % [skel[k], k])
	var cats: Array = news_cats.keys()
	cats.sort_custom(func(a, b): return news_cats[a] > news_cats[b])
	print("categorias: %s" % ", ".join(cats.map(func(c): return "%s %d" % [c, news_cats[c]])))
	print("\n=== EVENTOS DO TREINADOR ===")
	var ek: Array = event_kinds.keys()
	ek.sort_custom(func(a, b): return event_kinds[a] > event_kinds[b])
	print(", ".join(ek.map(func(k): return "%s %d" % [k, event_kinds[k]])))
