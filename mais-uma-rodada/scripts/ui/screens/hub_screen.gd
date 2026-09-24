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
	screen_subtitle = "%s · temporada %d" % [w.league_name(club.league_id), w.year]
	var jobs := BoardManager.pending_job_offers(w)
	show_nav = jobs.is_empty()
	UIManager.refresh_chrome()
	var c := content()
	UIKit.clear(c)
	if not jobs.is_empty():
		c.add_child(_jobs_card(w, jobs))
		return
	var preseason := PreseasonManager.is_active(w)
	if preseason:
		c.add_child(_preseason_card(w))
	if w.season.finished:
		c.add_child(_season_over_card(w))
	else:
		c.add_child(_next_match_card(w, club))
	var decisions := _decisions_card(w)
	if decisions != null:
		c.add_child(decisions)
	c.add_child(_status_card(w, club))
	var alerts := _alerts_card(w, club)
	if alerts != null:
		c.add_child(alerts)
	if not preseason:
		c.add_child(_mini_table_card(w, club))
		var stars := _highlights_card(w, club)
		if stars != null:
			c.add_child(stars)
	var upcoming := _upcoming_card(w, club)
	if upcoming != null:
		c.add_child(upcoming)
	var cups := _cups_card(w, club)
	if cups != null:
		c.add_child(cups)
	c.add_child(_shortcuts_card(w))
	c.add_child(_news_card(w))
	c.add_child(_form_card(w, club))


## Bloco de um time na próxima partida: escudo, nome, posição (na liga ou no grupo da copa) e forma.
func _team_block(w: GameWorld, cl: Club, f: Fixture) -> VBoxContainer:
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
	var text := ""
	var form := cl.recent_form(5)
	if f.is_league():
		var league := w.league(f.comp)
		var row: Dictionary = league.table.get(cl.id, {})
		if not row.is_empty() and int(row["pl"]) > 0:
			text = "%dº · %d pts" % [CompetitionManager.position_of(league, cl.id), int(row["pts"])]
			form = row["form"]
		else:
			text = "Estreia"
	else:
		var cup: Cup = w.season.cups.get(f.comp, null)
		var g: Dictionary = cup.group_of(cl.id) if cup != null else {}
		if f.stage == Fixture.STAGE_GROUP and not g.is_empty():
			var order := CompetitionManager.sort_table(g["clubs"], g["table"])
			text = "%dº no grupo %s" % [order.find(cl.id) + 1, g["n"]]
		else:
			text = "%s · %s" % [DatabaseManager.nation_name(cl.nation), w.league_short(cl.league_id)]
	var sub := UIKit.label(text, "Small")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var fd := FormDots.new()
	fd.dot = 18
	fd.form = form
	fd.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(fd)
	return v


func _next_match_card(w: GameWorld, club: Club) -> Control:
	var f := FixtureManager.next_fixture_for(w, club.id)
	var card := UIKit.card("CardHighlight", 14)
	if f == null:
		card.add_child(UIKit.section("Temporada"))
		card.add_child(UIKit.label("Seu time não joga mais nesta temporada.", "Title", true))
		card.add_child(UIKit.label("As outras ligas e as finais das copas ainda estão em andamento. Avance para ver os campeões e o resumo do ano.", "Muted", true))
		var adv := UIKit.button("AVANÇAR ATÉ O FIM DA TEMPORADA", "PrimaryButton", func():
			GameManager.advance_to_end()
			refresh(), "fast")
		adv.custom_minimum_size.y = 104
		card.add_child(adv)
		return UIKit.card_panel(card)
	var derby := MatchEngine.is_derby(w, f.home, f.away)
	var head := UIKit.section("Próxima partida · %s · %s" % [CompText.fixture_title(w, f), w.season.date_label(f.slot)])
	card.add_child(head)
	var row := UIKit.hbox(6)
	row.add_child(_team_block(w, w.club(f.home), f))
	var mid := UIKit.vbox(2)
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	var vs := UIKit.label("x", "Big")
	vs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vs.add_theme_color_override(&"font_color", UIColors.DIM)
	mid.add_child(vs)
	var where := UIKit.label("NEUTRO" if f.neutral else ("EM CASA" if f.home == club.id else "FORA"), "Caps")
	where.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	where.add_theme_color_override(&"font_color", UIColors.MUTED if f.neutral else (UIColors.GREEN if f.home == club.id else UIColors.ORANGE))
	mid.add_child(where)
	row.add_child(mid)
	row.add_child(_team_block(w, w.club(f.away), f))
	card.add_child(row)
	var stadium := UIKit.label(("Campo neutro" if f.neutral else "%s · %s" % [w.club(f.home).stadium, w.club(f.home).city]), "Small")
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
	var quick := UIKit.button("Simular", "GhostButton", func(): SimDialog.open(func(): refresh()), "fast")
	quick.tooltip_text = "Joga um ou vários jogos sem assistir"
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


## Decisões pendentes (eventos da carreira).
func _decisions_card(w: GameWorld) -> Control:
	var evs := EventManager.pending(w)
	if evs.is_empty():
		return null
	var card := UIKit.card("CardHighlight", 8)
	card.add_child(UIKit.section("Decisões pendentes (%d)" % evs.size()))
	for ev in evs:
		var d := EventManager.describe(w, ev)
		var row := UIKit.hbox(12)
		row.add_child(UIKit.icon_rect(String(EventManager.KINDS.get(String(ev["k"]), {}).get("icon", "info")), 32, EventDialog.color_of(ev)))
		var col := UIKit.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UIKit.label(String(d["title"]), "H3", true))
		var left := maxi(1, int(ev["exp"]) - w.current_turn())
		col.add_child(UIKit.label("Responda em até %d jogo(s)" % left, "Small"))
		row.add_child(col)
		row.add_child(UIKit.label("›", "H2"))
		var e: Dictionary = ev
		card.add_child(UIKit.tap_row(row, func(): EventDialog.open(e, func(): refresh()), "Card"))
	return UIKit.card_panel(card)


## Atalhos para o dia a dia do clube.
func _shortcuts_card(w: GameWorld) -> Control:
	var card := UIKit.card("Card", 10)
	card.add_child(UIKit.section("Central do clube"))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override(&"h_separation", 10)
	grid.add_theme_constant_override(&"v_separation", 10)
	var yl_pos := YouthManager.sorted_table(w).find(w.user_club_id) + 1
	var items: Array = [
		["tactics", "Treino", TrainingManager.focus_of(w.user_club())["name"], func(): UIManager.push("training")],
		["up", "Base", "%d garotos%s" % [w.academy.size(), (" · %dº" % yl_pos) if yl_pos > 0 and YouthManager.has_league(w) and int(w.youth_league["table"][w.user_club_id]["pl"]) > 0 else ""], func(): UIManager.push("academy")],
		["money", "Finanças", Fmt.money(w.user_club().balance), func(): UIManager.goto("club")],
		["trophy", "História", "Campeões e prêmios", func(): UIManager.push("history")],
		["gear", "Editor", "Escudos, fotos, nomes", func(): UIManager.push("editor")],
		["news", "Notícias", "%d nova(s)" % w.unread_news_count(), func(): UIManager.push("news")],
	]
	for it in items:
		var v := UIKit.vbox(4)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		var ic := UIKit.icon_rect(String(it[0]), 40, UIColors.ACCENT)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(ic)
		var t := UIKit.label(String(it[1]), "H3")
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(t)
		var s := UIKit.label(String(it[2]), "Small")
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		v.add_child(s)
		var tile := UIKit.tap_row(v, it[3], "CardFlat")
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.custom_minimum_size.y = 128
		grid.add_child(tile)
	card.add_child(grid)
	return UIKit.card_panel(card)


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
		col.add_child(UIKit.label("%s · %s · meta: %s" % [w.league_short(cl.league_id), cl.arch().get("tag", ""), String(goal[0]).to_lower()], "Small", true))
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
	# Andamento da temporada e campanha na liga
	var rounds := league.round_count()
	var prog := UIKit.hbox(10)
	var pl := UIKit.label("Rodada %d de %d" % [played, rounds], "Small")
	pl.custom_minimum_size.x = 170
	prog.add_child(pl)
	var pb := UIKit.bar(float(played), float(maxi(1, rounds)), UIColors.ACCENT, 10)
	pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	prog.add_child(pb)
	card.add_child(prog)
	if played > 0:
		var row_t: Dictionary = league.table[club.id]
		var rec := "%dV %dE %dD · %d gols pró, %d contra · aproveitamento %d%%" % [int(row_t["w"]), int(row_t["d"]), int(row_t["l"]), int(row_t["gf"]), int(row_t["ga"]),
			int(round(100.0 * int(row_t["pts"]) / maxf(1.0, played * 3.0)))]
		card.add_child(UIKit.label(rec, "Small", true))
	return UIKit.card_panel(card)


## Situação do clube nas copas da temporada (grupo, fase atual, eliminação ou título).
func _cups_card(w: GameWorld, club: Club) -> Control:
	var rows: Array = []
	for cid in w.season.cups:
		var cup: Cup = w.season.cups[cid]
		if not cup.has_club(club.id):
			continue
		var status := ""
		var color := UIColors.TEXT
		if cup.champion == club.id:
			status = "CAMPEÃO"
			color = UIColors.ACCENT
		elif not cup.is_alive(club.id):
			status = "Eliminado"
			color = UIColors.MUTED
		elif not cup.ties.is_empty():
			var r := -1
			for t in cup.ties:
				if int(t["a"]) == club.id or int(t["b"]) == club.id:
					r = maxi(r, int(t["r"]))
			status = cup.round_names[r] if r >= 0 else "Fase de grupos"
			color = UIColors.GREEN
		else:
			var g := cup.group_of(club.id)
			if not g.is_empty():
				var order := CompetitionManager.sort_table(g["clubs"], g["table"])
				status = "%dº no grupo %s · %d pts" % [order.find(club.id) + 1, g["n"], int(g["table"][club.id]["pts"])]
			else:
				status = "Classificado"
		rows.append([cup, status, color])
	if rows.is_empty():
		return null
	var card := UIKit.card("Card", 8)
	card.add_child(UIKit.section("Copas"))
	for r in rows:
		var cup: Cup = r[0]
		var row := UIKit.hbox(12)
		row.add_child(UIKit.icon_rect("trophy", 30, UIColors.ACCENT))
		var name := UIKit.label(cup.name, "")
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name)
		row.add_child(UIKit.colored(r[1], r[2], "Small"))
		var id := cup.id
		card.add_child(UIKit.tap_row(row, func(): UIManager.goto("table", {"cup": id})))
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
		items.append(["swap", UIColors.GREEN, "Janela de transferências aberta até %s" % w.season.date_label(w.window_end_day(), false), func(): UIManager.goto("market")])
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


## Pré-temporada em andamento: atalho com os passos que faltam.
func _preseason_card(w: GameWorld) -> Control:
	var card := UIKit.card("CardHighlight", 10)
	card.add_child(UIKit.section("Pré-temporada %d" % w.year))
	card.add_child(UIKit.label("Prepare o time antes da estreia", "Title", true))
	var steps := PreseasonManager.steps(w)
	var names := ["Raio-x e planejamento do elenco", "Intertemporada (físico, tático, excursão ou base)", "Três amistosos de preparação"]
	for i in 3:
		var row := UIKit.hbox(10)
		row.add_child(UIKit.icon_rect("check" if steps[i] else "clock", 26, UIColors.GREEN if steps[i] else UIColors.MUTED))
		var l := UIKit.label(names[i], "" if not steps[i] else "Muted", true)
		row.add_child(l)
		card.add_child(row)
	var b := UIKit.button("ABRIR PRÉ-TEMPORADA", "PrimaryButton", func(): UIManager.push("preseason"), "tactics")
	b.custom_minimum_size.y = 96
	card.add_child(b)
	return UIKit.card_panel(card)


## Trecho da tabela em volta do clube do usuário.
func _mini_table_card(w: GameWorld, club: Club) -> Control:
	var league := w.league_of(club.id)
	var ids := CompetitionManager.sorted_ids(league)
	var me := ids.find(club.id)
	var from := clampi(me - 2, 0, maxi(0, ids.size() - 5))
	var card := UIKit.card("Card", 4)
	var head := UIKit.hbox(8)
	var sec := UIKit.section(league.name)
	sec.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sec)
	head.add_child(UIKit.label("J    SG    PTS", "Small"))
	card.add_child(head)
	for i in range(from, mini(from + 5, ids.size())):
		var cl := w.club(int(ids[i]))
		var r: Dictionary = league.table[cl.id]
		var row := UIKit.hbox(10)
		var zone := CompetitionManager.zone_of(league, i + 1)
		var pos := UIKit.label("%d" % (i + 1), "H3")
		pos.custom_minimum_size.x = 34
		pos.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if zone != CompetitionManager.ZONE_NONE:
			pos.add_theme_color_override(&"font_color", CompetitionManager.zone_color(zone))
		row.add_child(pos)
		row.add_child(UIKit.crest(cl, 30))
		var n := UIKit.label(cl.short_name, "H3" if cl.id == club.id else "")
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		if cl.id == club.id:
			n.add_theme_color_override(&"font_color", UIColors.ACCENT)
		row.add_child(n)
		var nums := UIKit.label("%2d   %s   %3d" % [int(r["pl"]), Fmt.signed(int(r["gf"]) - int(r["ga"])), int(r["pts"])], "Mono")
		row.add_child(nums)
		card.add_child(UIKit.tap_row(row, func(): UIManager.goto("table"), "CardFlat" if cl.id == club.id else "RowPanel"))
	return UIKit.card_panel(card)


## Destaques do elenco na temporada: artilheiro, garçom, melhor nota e quem está em alta.
func _highlights_card(w: GameWorld, club: Club) -> Control:
	var best := {}
	var vals := {"g": 0.0, "a": 0.0, "r": 0.0, "f": 0.0}
	for p: Player in w.squad(club):
		var tot := p.season_totals()
		if int(tot[0]) == 0:
			continue
		var cand := {"g": float(tot[1]) + int(tot[0]) * 0.001, "a": float(tot[2]) + int(tot[0]) * 0.001,
			"r": p.avg_rating() if p.stats[Player.S_APPS] >= 3 else 0.0, "f": p.form() if p.recent_ratings.size() >= 3 else 0.0}
		for k in cand:
			if float(cand[k]) > float(vals[k]) and (k != "g" or int(tot[1]) > 0) and (k != "a" or int(tot[2]) > 0):
				vals[k] = cand[k]
				best[k] = p
	if best.is_empty():
		return null
	var card := UIKit.card("Card", 8)
	card.add_child(UIKit.section("Destaques do elenco"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 10)
	grid.add_theme_constant_override(&"v_separation", 10)
	var items := [["g", "Artilheiro", "ball"], ["a", "Garçom", "star"], ["r", "Melhor nota", "trophy"], ["f", "Em alta", "up"]]
	for it in items:
		if not best.has(it[0]):
			continue
		var p: Player = best[it[0]]
		var tot := p.season_totals()
		var value := ""
		match it[0]:
			"g":
				value = Fmt.plural(int(tot[1]), "gol", "gols")
			"a":
				value = Fmt.plural(int(tot[2]), "assistência", "assistências")
			"r":
				value = "nota %s" % Fmt.rating(p.avg_rating())
			"f":
				value = "últimos jogos: %s" % Fmt.rating(p.form())
		var row := UIKit.hbox(8)
		row.add_child(UIKit.portrait(p, club, w.year, 56))
		var col := UIKit.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UIKit.label(String(it[1]).to_upper(), "Caps"))
		var nl := UIKit.label(p.display_name(), "H3")
		nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		col.add_child(nl)
		col.add_child(UIKit.label(value, "Small"))
		row.add_child(col)
		var pid := p.id
		var tile := UIKit.tap_row(row, func(): UIManager.push("player", {"id": pid}), "CardFlat")
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(tile)
	card.add_child(grid)
	return UIKit.card_panel(card)


## Os jogos seguintes ao próximo (liga e copas).
func _upcoming_card(w: GameWorld, club: Club) -> Control:
	var next := FixtureManager.next_fixture_for(w, club.id)
	if next == null:
		return null
	var list: Array = []
	for f: Fixture in FixtureManager.season_fixtures(w, club.id):
		if not f.played and f != next and f.slot >= next.slot:
			list.append(f)
		if list.size() >= 3:
			break
	if list.is_empty():
		return null
	var card := UIKit.card("Card", 6)
	card.add_child(UIKit.section("Próximos jogos"))
	for f: Fixture in list:
		var opp := w.club(f.opponent_of(club.id))
		var row := UIKit.hbox(10)
		var d := UIKit.label(w.season.date_label(f.slot, false), "Small")
		d.custom_minimum_size.x = 96
		row.add_child(d)
		row.add_child(UIKit.crest(opp, 34))
		var col := UIKit.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var nl := UIKit.label(("vs " if f.home == club.id else "@ ") + opp.short_name, "H3")
		nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		if MatchEngine.is_derby(w, f.home, f.away):
			nl.add_theme_color_override(&"font_color", UIColors.RED)
		col.add_child(nl)
		col.add_child(UIKit.label(CompText.fixture_title(w, f), "Small"))
		row.add_child(col)
		var league := w.league_of(opp.id)
		if league != null and league.id == club.league_id and int(league.table[opp.id]["pl"]) > 0:
			row.add_child(UIKit.label("%dº" % CompetitionManager.position_of(league, opp.id), "H3"))
		card.add_child(row)
	return UIKit.card_panel(card)
