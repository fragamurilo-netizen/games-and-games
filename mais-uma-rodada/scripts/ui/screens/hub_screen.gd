extends BaseScreen
## Tela inicial da carreira: a próxima partida no centro e o que está em jogo.

const HOOK_ICONS := {"derby": "bolt", "table": "table", "streak": "up", "player": "shirt", "market": "swap", "contract": "clock", "season": "trophy"}
const HOOK_COLORS := {"derby": UIColors.RED, "table": UIColors.ACCENT, "streak": UIColors.GREEN, "player": UIColors.BLUE, "market": UIColors.ORANGE, "contract": UIColors.ORANGE, "season": UIColors.ACCENT}


func _init() -> void:
	nav_tab = "hub"


func on_show() -> void:
	refresh()
	if BoardManager.pending_job_offers(world()).is_empty():
		Tutorial.maybe_show()


func refresh() -> void:
	var w := world()
	if w == null:
		return
	var club := w.user_club()
	screen_title = club.short_name
	screen_subtitle = "%s · temporada %d" % [w.division_name(club.division), w.year]
	var jobs := BoardManager.pending_job_offers(w)
	show_nav = jobs.is_empty()
	UIManager.refresh_chrome()
	var c := content()
	UIKit.clear(c)
	if not jobs.is_empty():
		c.add_child(_jobs_card(w, jobs))
		return
	if w.season.finished:
		c.add_child(_season_over_card(w))
	else:
		c.add_child(_next_match_card(w, club))
	c.add_child(_status_card(w, club))
	var alerts := _alerts_card(w, club)
	if alerts != null:
		c.add_child(alerts)
	c.add_child(_news_card(w))
	c.add_child(_form_card(w, club))


func _team_block(w: GameWorld, cl: Club, league: League) -> VBoxContainer:
	var v := UIKit.vbox(6)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var cr := UIKit.crest(cl, 104)
	cr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(cr)
	var n := UIKit.label(cl.short_name, "H2")
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(n)
	var pos := CompetitionManager.position_of(league, cl.id)
	var played: int = league.table[cl.id]["pl"]
	var sub := UIKit.label(("%dº · %d pts" % [pos, league.table[cl.id]["pts"]]) if played > 0 else "Estreia", "Small")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var fd := FormDots.new()
	fd.dot = 18
	fd.form = league.table[cl.id]["form"]
	fd.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(fd)
	return v


func _next_match_card(w: GameWorld, club: Club) -> Control:
	var f := FixtureManager.next_fixture_for(w, club.id)
	var card := UIKit.card("CardHighlight", 14)
	if f == null:
		card.add_child(UIKit.label("Sem jogos pela frente.", "Muted"))
		return UIKit.card_panel(card)
	var league := w.league_of(club.id)
	var derby := MatchEngine.is_derby(w, f.home, f.away)
	var head := UIKit.section("Próxima partida · Rodada %d de %d · %s" % [f.round + 1, league.rounds.size(), w.division_short(club.division)])
	card.add_child(head)
	var row := UIKit.hbox(6)
	row.add_child(_team_block(w, w.club(f.home), league))
	var mid := UIKit.vbox(2)
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	var vs := UIKit.label("x", "Big")
	vs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vs.add_theme_color_override(&"font_color", UIColors.DIM)
	mid.add_child(vs)
	var where := UIKit.label("EM CASA" if f.home == club.id else "FORA", "Caps")
	where.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	where.add_theme_color_override(&"font_color", UIColors.GREEN if f.home == club.id else UIColors.ORANGE)
	mid.add_child(where)
	row.add_child(mid)
	row.add_child(_team_block(w, w.club(f.away), league))
	card.add_child(row)
	var stadium := UIKit.label("%s · %s" % [w.club(f.home).stadium, w.club(f.home).city], "Small")
	stadium.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(stadium)
	if derby:
		var d := UIKit.label("CLÁSSICO", "H2")
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		d.add_theme_color_override(&"font_color", UIColors.RED)
		card.add_child(d)
	for hk in StoryHooks.for_next_match(w):
		if hk["kind"] == "derby":
			continue
		var line := UIKit.hbox(10)
		line.add_child(UIKit.icon_rect(HOOK_ICONS.get(hk["kind"], "info"), 26, HOOK_COLORS.get(hk["kind"], UIColors.MUTED)))
		var t := UIKit.label(hk["text"], "", true)
		line.add_child(t)
		card.add_child(line)
	var play := UIKit.button("JOGAR", "PrimaryButton", func(): UIManager.push("prematch"), "play")
	play.custom_minimum_size.y = 112
	card.add_child(play)
	var sub := UIKit.hbox(10)
	var lineup := UIKit.button("Escalação e tática", "GhostButton", func(): UIManager.push("prematch", {"edit": true}), "tactics")
	lineup.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub.add_child(lineup)
	var quick := UIKit.button("Simular", "GhostButton", _instant, "fast")
	quick.tooltip_text = "Joga a rodada sem assistir"
	sub.add_child(quick)
	card.add_child(sub)
	return UIKit.card_panel(card)


func _instant() -> void:
	var w := world()
	var msgs := ClubAI.validate_user_sheet(w, w.user_club())
	for m in msgs:
		UIManager.toast(m)
	var report := GameManager.play_instant()
	if report.is_empty():
		return
	UIManager.push("results", {"report": report})


## Depois de uma demissão: escolher o próximo clube (não dá para jogar sem clube).
func _jobs_card(w: GameWorld, jobs: Array) -> Control:
	var card := UIKit.card("CardHighlight", 12)
	card.add_child(UIKit.section("Sem clube"))
	var fired: Dictionary = w.stats.get("fired", {})
	var old := w.club(int(fired.get("from", -1)))
	card.add_child(UIKit.label("A diretoria do %s decidiu trocar o comando técnico." % (old.short_name if old != null else "clube"), "Title", true))
	card.add_child(UIKit.label("Alguns clubes querem conversar. Escolha onde recomeçar — a carreira, os números e a história continuam com você.", "Muted", true))
	for cid in jobs:
		var cl := w.club(int(cid))
		if cl == null:
			continue
		var row := UIKit.hbox(12)
		row.add_child(UIKit.crest(cl, 64))
		var col := UIKit.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UIKit.label(cl.name, "H3", true))
		var goal := SeasonManager.goal_of(w, cl.id)
		col.add_child(UIKit.label("%s · %s · meta: %s" % [w.division_short(cl.division), cl.arch().get("tag", ""), String(goal[0]).to_lower()], "Small", true))
		row.add_child(col)
		var ccid: int = int(cid)
		card.add_child(UIKit.tap_row(row, func():
			UIManager.confirm("Assumir o %s?" % cl.short_name, "Você será o novo treinador do clube a partir de agora.", "Assumir", func():
				BoardManager.take_job(w, ccid)
				GameManager.save_now()
				AudioManager.play("sign")
				UIManager.goto("hub")), "Card"))
	return UIKit.card_panel(card)


func _season_over_card(w: GameWorld) -> Control:
	var card := UIKit.card("CardHighlight", 14)
	card.add_child(UIKit.section("Fim de temporada"))
	var league := w.league_of(w.user_club_id)
	var pos := CompetitionManager.position_of(league, w.user_club_id)
	var t := UIKit.label("Temporada %d encerrada: %dº lugar" % [w.year, pos], "Title", true)
	card.add_child(t)
	card.add_child(UIKit.label("Veja campeões, acessos, rebaixamentos e o que muda para a próxima temporada.", "Muted", true))
	var b := UIKit.button("VER RESUMO DA TEMPORADA", "PrimaryButton", func(): UIManager.push("season_end"), "trophy")
	b.custom_minimum_size.y = 104
	card.add_child(b)
	return UIKit.card_panel(card)


func _status_card(w: GameWorld, club: Club) -> Control:
	var card := UIKit.card("Card", 12)
	var league := w.league_of(club.id)
	var pos := CompetitionManager.position_of(league, club.id)
	var zone := CompetitionManager.zone_of(league, pos)
	var row := UIKit.hbox(4)
	var pcol := UIColors.TEXT
	if zone != CompetitionManager.ZONE_NONE:
		pcol = CompetitionManager.zone_color(zone)
	var played: int = league.table[club.id]["pl"]
	row.add_child(UIKit.stat(("%dº" % pos) if played > 0 else "—", "posição", pcol))
	row.add_child(UIKit.stat(str(league.table[club.id]["pts"]), "pontos"))
	var morale := _team_morale(w, club)
	row.add_child(UIKit.stat(UIColors.morale_label(morale), "moral", UIColors.morale_color(morale)))
	row.add_child(UIKit.stat(UIColors.fans_label(club.fan_mood), "torcida", UIColors.morale_color(club.fan_mood)))
	card.add_child(row)
	var goal: Array = SeasonManager.goal_of(w, club.id)
	var g := UIKit.hbox(10)
	g.add_child(UIKit.icon_rect("trophy", 26, UIColors.ACCENT))
	var ok := played > 0 and pos <= int(goal[1])
	var gl := UIKit.label("Meta da diretoria: %s" % goal[0], "", true)
	g.add_child(gl)
	if played >= 5:
		g.add_child(UIKit.colored("no caminho" if ok else "abaixo", UIColors.GREEN if ok else UIColors.ORANGE, "Small"))
	card.add_child(g)
	return UIKit.card_panel(card)


static func _team_morale(w: GameWorld, club: Club) -> float:
	var s := 0.0
	var n := 0
	for p in w.squad(club):
		s += p.morale
		n += 1
	return s / maxf(1.0, n)


func _alerts_card(w: GameWorld, club: Club) -> Control:
	var items: Array = []
	var offers := TransferManager.pending_offers(w)
	if not offers.is_empty():
		items.append(["swap", UIColors.ACCENT, "%d proposta(s) pelo seu elenco" % offers.size(), func(): UIManager.goto("market", {"tab": "offers"})])
	if w.transfer_window_open():
		items.append(["swap", UIColors.GREEN, "Janela de transferências aberta até a rodada %d" % (w.window_end_day() + 1), func(): UIManager.goto("market")])
	var injured: Array = []
	var suspended: Array = []
	var expiring := 0
	for p in w.squad(club):
		if p.injury_weeks > 0:
			injured.append("%s (%d sem.)" % [p.display_name(), p.injury_weeks])
		if p.suspension > 0:
			suspended.append(p.display_name())
		if p.contract_end <= w.year:
			expiring += 1
	if not injured.is_empty():
		items.append(["cross", UIColors.RED, "Lesionados: " + ", ".join(injured.slice(0, 3)) + (" e mais %d" % (injured.size() - 3) if injured.size() > 3 else ""), func(): UIManager.goto("squad")])
	if not suspended.is_empty():
		items.append(["card", UIColors.ORANGE, "Suspenso(s) no próximo jogo: " + ", ".join(suspended), func(): UIManager.goto("squad")])
	if expiring > 0 and w.season.day >= 10:
		items.append(["clock", UIColors.ORANGE, "%d contrato(s) terminam no fim da temporada — renove quem você quer manter" % expiring, func(): UIManager.goto("squad", {"sort": "contract"})])
	var rules := DatabaseManager.squad_rules()
	if club.player_ids.size() < int(rules["min_players"]):
		items.append(["shirt", UIColors.RED, "Elenco curto: só %d jogadores" % club.player_ids.size(), func(): UIManager.goto("market")])
	var bill := FinanceManager.wage_bill(w, club)
	if bill > club.wage_budget:
		items.append(["money", UIColors.RED, "Folha salarial acima do limite da diretoria", func(): UIManager.goto("club")])
	if club.board_confidence < BoardManager.ULTIMATUM:
		items.append(["info", UIColors.RED, "Ultimato da diretoria: é preciso reagir até o fim da temporada", func(): UIManager.goto("club")])
	if items.is_empty():
		return null
	var card := UIKit.card("Card", 8)
	card.add_child(UIKit.section("Atenção"))
	for it in items:
		var row := UIKit.hbox(12)
		row.add_child(UIKit.icon_rect(it[0], 28, it[1]))
		var l := UIKit.label(it[2], "", true)
		row.add_child(l)
		card.add_child(UIKit.tap_row(row, it[3]))
	return UIKit.card_panel(card)


func _news_card(w: GameWorld) -> Control:
	var card := UIKit.card("Card", 10)
	var head := UIKit.hbox(8)
	var sec := UIKit.section("Notícias")
	sec.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sec)
	var unread := w.unread_news_count()
	if unread > 0:
		head.add_child(UIKit.colored("%d nova(s)" % unread, UIColors.ACCENT, "Small"))
	card.add_child(head)
	var items: Array = w.news.duplicate()
	items.reverse()
	var shown := 0
	for n: NewsEvent in items:
		if shown >= 4:
			break
		card.add_child(NewsRow.make(w, n, true))
		shown += 1
	if shown == 0:
		card.add_child(UIKit.label("Nada por aqui ainda.", "Muted"))
	card.add_child(UIKit.button("Ver todas as notícias", "GhostButton", func(): UIManager.push("news"), "news"))
	return UIKit.card_panel(card)


func _form_card(w: GameWorld, club: Club) -> Control:
	var card := UIKit.card("Card", 10)
	card.add_child(UIKit.section("Últimos jogos"))
	var recent := FixtureManager.recent_fixtures(w, club.id, 4)
	if recent.is_empty():
		card.add_child(UIKit.label("A temporada ainda não começou.", "Muted"))
		return UIKit.card_panel(card)
	for f: Fixture in recent:
		var row := UIKit.hbox(10)
		var res := f.result_for(club.id)
		row.add_child(UIKit.text_badge(res, UIColors.result_color(res), 40, 36, 20))
		var opp := w.club(f.opponent_of(club.id))
		row.add_child(UIKit.crest(opp, 36))
		var l := UIKit.label(("vs " if f.home == club.id else "@ ") + opp.short_name, "")
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var mine := f.hg if f.home == club.id else f.ag
		var theirs := f.ag if f.home == club.id else f.hg
		row.add_child(UIKit.label("%d x %d" % [mine, theirs], "Stat"))
		card.add_child(row)
	return UIKit.card_panel(card)
