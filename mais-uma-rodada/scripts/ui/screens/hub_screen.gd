extends BaseScreen
## Tela inicial da carreira: a próxima partida no centro e o que está em jogo.

const HOOK_ICONS := {"derby": "bolt", "table": "table", "streak": "up", "player": "shirt", "market": "swap", "contract": "clock", "season": "trophy"}


## Aba da tela inicial: resumo do dia, a temporada e o que acontece em volta do clube.
static var _tab := "today"


func _init() -> void:
	nav_tab = "hub"


## Tabela e temporada usam o destaque do clube; o resto tem cor fixa.
static func _hook_color(kind: String) -> Color:
	if kind in ["table", "season"]:
		return UIColors.ACCENT
	return {"derby": UIColors.RED, "streak": UIColors.GREEN, "player": UIColors.BLUE, "market": UIColors.ORANGE, "contract": UIColors.ORANGE}.get(kind, UIColors.MUTED)


func on_show() -> void:
	refresh()
	if BoardManager.pending_job_offers(world()).is_empty():
		var tutorial_now := not AppSettings.tutorial_done
		Tutorial.maybe_show()
		if not tutorial_now and KitDesign.launch_pending(world()):
			_kit_launch_prompt(world())
	# Conquistas de contador de saves antigos e avisos pendentes.
	Achievements.check_counters(world())
	# Reforço importante fechado fora da negociação (eventos, propostas): apresentação animada.
	SigningCeremony.play_pending(world())


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
	# Início com ritmo editorial (DESIGN.md › Editorial): a data como manchete, o jogo como o
	# acontecimento principal, o que pede decisão e, depois, o mundo do futebol. Em tela larga,
	# a coluna da direita traz a temporada (tabela e próximos jogos).
	max_content_width = 1500.0
	screen_subtitle = ""
	var left: VBoxContainer = c
	var right: VBoxContainer = c
	if content_width() >= 1050.0:
		var split := UIKit.hbox(UITokens.S8)
		left = UIKit.vbox(UITokens.S4)
		right = UIKit.vbox(UITokens.S4)
		left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left.size_flags_stretch_ratio = 1.3
		right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		split.add_child(left)
		split.add_child(right)
		c.add_child(split)
	left.add_child(_date_line(w, club))
	if Store.locked(w):
		left.add_child(_paywall_card(w))
	elif preseason:
		left.add_child(_preseason_card(w))
	if Store.locked(w):
		pass
	elif w.season.finished:
		left.add_child(_season_over_card(w))
	else:
		left.add_child(_next_match_card(w, club))
	var attention := _attention(w, club)
	if attention != null:
		left.add_child(attention)
	var backstage: Control = RelationsScreen.pending_card(w, func(): refresh(), false)
	if backstage != null:
		left.add_child(backstage)
	var news := _news_card(w)
	if right == c:
		left.add_child(news)
	if not preseason:
		right.add_child(_mini_table_card(w, club))
	for extra in [_upcoming_card(w, club), _cups_card(w, club)]:
		if extra != null:
			right.add_child(extra)
	if right != c:
		left.add_child(news)


## Data do dia como manchete e, embaixo, onde o clube está e o que a diretoria espera.
func _date_line(w: GameWorld, club: Club) -> Control:
	var v := UIKit.vbox(0)
	var slot := clampi(w.season.day, 0, maxi(0, w.season.total_days() - 1))
	var date := w.season.long_date_label(slot)
	# Em coluna estreita (celular deitado) a data quebra em duas linhas em vez de cortar.
	v.add_child(UIKit.label(date if date != "" else "Temporada %d" % w.year, "Title", true))
	var league := w.league_of(club.id)
	var where := w.league_name(club.league_id)
	if league != null and int(league.table[club.id]["pl"]) > 0:
		where = "%dº no %s, %d pontos" % [CompetitionManager.position_of(league, club.id), w.league_name(club.league_id), int(league.table[club.id]["pts"])]
	var sub := UIKit.label(where, "Muted", true)
	v.add_child(sub)
	var goal: Array = SeasonManager.goal_of(w, club.id)
	if not goal.is_empty():
		v.add_child(UIKit.label("Meta da diretoria: %s" % String(goal[0]).to_lower(), "Muted", true))
	return v


## Tudo o que pede uma decisão agora, numa lista só: eventos com prazo, propostas, lesões,
## suspensões, contratos, folha, diretoria e mensagens não lidas. Cada linha leva ao lugar certo.
func _attention(w: GameWorld, club: Club) -> Control:
	var rows: Array = []
	for ev in EventManager.pending(w):
		var d := EventManager.describe(w, ev)
		var left := maxi(1, int(ev["exp"]) - w.current_turn())
		var e: Dictionary = ev
		rows.append([EventDialog.color_of(ev), String(d["title"]), "Responder em até %d jogo(s)" % left, func(): EventDialog.open(e, func(): refresh())])
	var old := _alerts_items(w, club)
	for it in old:
		rows.append([it[1], String(it[2]), "", it[3]])
	var unread := InboxManager.unread_count(w)
	if unread > 0:
		rows.append([UIColors.MUTED, Fmt.plural(unread, "mensagem não lida", "mensagens não lidas"), "", func(): UIManager.push("inbox")])
	if rows.is_empty():
		return null
	var out := UIKit.vbox(UITokens.S2)
	out.add_child(UIKit.section_header("Precisa da sua atenção"))
	var v := UIKit.card("Card", 0)
	for r in rows:
		var h := UIKit.hbox(14)
		var mark := ColorRect.new()
		mark.color = r[0]
		mark.custom_minimum_size = Vector2(4, 36)
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(mark)
		var col := UIKit.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		col.add_child(UIKit.label(String(r[1]), "", true))
		if String(r[2]) != "":
			col.add_child(UIKit.label(String(r[2]), "Muted"))
		h.add_child(col)
		h.add_child(UIKit.icon_rect("forward", 20, UIColors.DIM))
		var row := UIKit.tap_row(h, r[3])
		row.custom_minimum_size.y = UITokens.H_ROW
		v.add_child(row)
	out.add_child(UIKit.card_panel(v))
	return out


## Bloco de um time na próxima partida: escudo, nome, posição (na liga ou no grupo da copa) e forma.
func _team_block(w: GameWorld, cl: Club, f: Fixture) -> VBoxContainer:
	var v := UIKit.vbox(6)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var cr := UIKit.crest(cl, 88 if UILayout.is_short() else 112)
	cr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(cr)
	var n := UIKit.label(cl.short_name, "H2")
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.tooltip_text = cl.name
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
			var order := LeaguePhase.sorted_ids(cup) if cup.league_phase else CompetitionManager.sort_table(g["clubs"], g["table"])
			text = "%dº na fase de liga" % [order.find(cl.id) + 1] if cup.league_phase else "%dº no grupo %s" % [order.find(cl.id) + 1, g["n"]]
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
		card.add_child(UIKit.label("Outras ligas e copas ainda estão em andamento.", "Muted", true))
		var adv := UIKit.button("Avançar até o fim da temporada", "PrimaryButton", func():
			GameManager.advance_to_end_async(func() -> void:
				if is_inside_tree():
					refresh()), "fast")
		adv.custom_minimum_size.y = 104
		card.add_child(adv)
		return UIKit.card_panel(card)
	var derby := MatchEngine.is_derby(w, f.home, f.away)
	# Dia de jogo como objeto do jogo: faixa da competição (cores da transmissão), os dois
	# clubes com escudo grande sobre as cores deles, e a ação de jogar.
	var hero := MatchHero.wrap(w, f.comp, w.club(f.home), w.club(f.away))
	var band: HBoxContainer = hero[1]
	var st := ScoreboardTheme.for_competition(w, f.comp)
	band.add_child(UIKit.comp_logo(f.comp, 36))
	var bt := UIKit.vbox(-2)
	bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ct := UIKit.label(CompText.fixture_title(w, f), "H3")
	ct.add_theme_color_override(&"font_color", st["caps"])
	ct.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	bt.add_child(ct)
	var dl := UIKit.label(w.season.date_label(f.slot), "Small")
	dl.add_theme_color_override(&"font_color", Color(st["text"], 0.8))
	bt.add_child(dl)
	band.add_child(bt)
	var where := "Neutro" if f.neutral else ("Em casa" if f.home == club.id else "Fora")
	var wl := UIKit.label(where, "Caps")
	wl.add_theme_color_override(&"font_color", Color(st["text"], 0.9))
	wl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	band.add_child(wl)
	var body: VBoxContainer = hero[2]
	var row := UIKit.hbox(6)
	row.add_child(_club_tap(w, _team_block(w, w.club(f.home), f), f.home))
	var vs := UIKit.label("×", "Title")
	vs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vs.add_theme_color_override(&"font_color", UIColors.DIM)
	row.add_child(vs)
	row.add_child(_club_tap(w, _team_block(w, w.club(f.away), f), f.away))
	body.add_child(row)
	var venue := UIKit.label("Campo neutro" if f.neutral else "%s · %s" % [w.club(f.home).stadium, w.club(f.home).city], "Muted")
	venue.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(venue)
	if derby:
		var d := UIKit.label("Clássico", "H2")
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		d.add_theme_color_override(&"font_color", UIColors.RED)
		body.add_child(d)
	for hk in StoryHooks.for_next_match(w):
		if hk["kind"] == "derby":
			continue
		var line := UIKit.hbox(10)
		line.add_child(UIKit.icon_rect(HOOK_ICONS.get(hk["kind"], "info"), 24, _hook_color(String(hk["kind"]))))
		line.add_child(UIKit.label(hk["text"], "", true))
		body.add_child(line)
	var act := UIKit.hbox(10)
	var play := UIKit.button("Jogar", "PrimaryButton", func(): UIManager.push("prematch"), "whistle")
	play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play.custom_minimum_size.y = 92
	act.add_child(play)
	var quick := UIKit.button("Simular", "GhostButton", func(): SimDialog.open(func(): refresh()), "fast")
	quick.tooltip_text = "Joga um ou vários jogos sem assistir"
	quick.custom_minimum_size.y = 92
	act.add_child(quick)
	body.add_child(act)
	return hero[0]


## Uma linha de time no bloco do jogo: escudo, nome, campanha e forma recente.
func _team_line(w: GameWorld, cl: Club, f: Fixture, mine: bool) -> Control:
	var h := UIKit.hbox(14)
	h.add_child(UIKit.crest(cl, 52))
	var n := UIKit.label(cl.short_name, "H2")
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if not mine:
		n.add_theme_color_override(&"font_color", UIColors.TEXT)
	h.add_child(n)
	var text := ""
	var form := cl.recent_form(5)
	if f.is_league():
		var league := w.league(f.comp)
		var row: Dictionary = league.table.get(cl.id, {})
		if not row.is_empty() and int(row["pl"]) > 0:
			text = "%dº · %d pts" % [CompetitionManager.position_of(league, cl.id), int(row["pts"])]
			form = row["form"]
	else:
		text = w.league_short(cl.league_id)
	var sub := UIKit.label(text, "Muted")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(sub)
	var fd := FormDots.new()
	fd.dot = 16
	fd.form = form
	fd.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(fd)
	h.custom_minimum_size.y = 64
	return h


## Toque no time abre a ficha dele (o seu clube vai para a aba Clube).
func _club_tap(w: GameWorld, inner: Control, cid: int) -> Control:
	var expand := inner.size_flags_horizontal
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := UIKit.tap_row(inner, func():
		if w.is_user_club(cid):
			UIManager.goto("club")
		else:
			UIManager.push("club", {"id": cid}), "")
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return row


func _instant() -> void:
	var w := world()
	var msgs := ClubAI.validate_user_sheet(w, w.user_club())
	for m in msgs:
		UIManager.toast(m)
	GameManager.play_instant_async(func(report: Dictionary) -> void:
		if not report.is_empty():
			UIManager.push("results", {"report": report}))


## Temporada de demonstração encerrada: o convite para seguir com a Carreira Completa.
func _paywall_card(w: GameWorld) -> Control:
	var card := UIKit.card("CardHighlight", 12)
	card.add_child(UIKit.section("Temporada %d" % w.year))
	card.add_child(UIKit.label("Mais uma temporada?", "Title", true))
	card.add_child(UIKit.label("Siga com o %s por quantos anos quiser." % w.user_club().short_name, "Muted", true))
	var b := UIKit.button("CONTINUAR A CARREIRA · %s" % Store.price(), "PrimaryButton", func(): UIManager.push("paywall"), "star")
	b.custom_minimum_size.y = 104
	card.add_child(b)
	return UIKit.card_panel(card)


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
		col.add_child(UIKit.label(("Responda em até %d jogo" if left == 1 else "Responda em até %d jogos") % left, "Small"))
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
		["book", "História", "Campeões e prêmios", func(): UIManager.push("history")],
		["globe", "Seleções", _nt_line(w), func(): UIManager.push("national")],
		["gear", "Editor", "Escudos, fotos, nomes", func(): UIManager.push("editor")],
		["mail", "Mensagens", ("%d não lida" if InboxManager.unread_count(w) == 1 else "%d não lidas") % InboxManager.unread_count(w), func(): UIManager.push("inbox")],
		["news", "Notícias", ("%d nova" if w.unread_news_count() == 1 else "%d novas") % w.unread_news_count(), func(): UIManager.push("news")],
		["chat", "Redes", SocialFeed.count(SocialFeed.followers(w.user_club(), w)) + " seguidores", func(): UIManager.push("social")],
		["trophy", "Conquistas", "%d de %d" % [Achievements.unlocked(w).size(), Achievements.CATALOG.size()], func(): UIManager.push("achievements")],
	]
	for it in items:
		var v := UIKit.vbox(4)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		var ic := PanelContainer.new()
		ic.theme_type_variation = "IconTile"
		ic.add_child(UIKit.icon_rect(String(it[0]), 32, UIColors.ACCENT))
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
	var oname := old.short_name if old != null else "clube"
	if bool(fired.get("res", false)):
		card.add_child(UIKit.label("Você entregou o cargo no %s." % oname, "Title", true))
	else:
		card.add_child(UIKit.label("A diretoria do %s decidiu trocar o comando técnico." % oname, "Title", true))
	card.add_child(UIKit.label("Alguns clubes querem conversar. Também dá para mandar currículo para quem está com vaga aberta.", "Muted", true))
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
				JobMarket.accept(w, ccid)
				GameManager.save_now()
				Sfx.play("sign")
				UIManager.goto("hub")), "Card"))
	card.add_child(UIKit.button("Vagas abertas e entrevistas", "GhostButton", func(): UIManager.push("jobs"), "search"))
	return UIKit.card_panel(card)


func _season_over_card(w: GameWorld) -> Control:
	var card := UIKit.card("CardHighlight", 14)
	card.add_child(UIKit.section("Fim de temporada"))
	var league := w.league_of(w.user_club_id)
	var pos := CompetitionManager.position_of(league, w.user_club_id)
	var t := UIKit.label("Temporada %d encerrada: %dº lugar" % [w.year, pos], "Title", true)
	card.add_child(t)
	var b := UIKit.button("Ver resumo da temporada", "PrimaryButton", func(): UIManager.push("season_end"))
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
			status = cup.round_names[r] if r >= 0 else ("Fase de liga" if cup.league_phase else "Fase de grupos")
			color = UIColors.GREEN
		else:
			var g := cup.group_of(club.id)
			if not g.is_empty():
				var order := LeaguePhase.sorted_ids(cup) if cup.league_phase else CompetitionManager.sort_table(g["clubs"], g["table"])
				status = "%dº · %d pts" % [order.find(club.id) + 1, int(g["table"][club.id]["pts"])] if cup.league_phase else "%dº no grupo %s · %d pts" % [order.find(club.id) + 1, g["n"], int(g["table"][club.id]["pts"])]
			else:
				status = "Classificado"
		if status != "CAMPEÃO" and status != "Eliminado" and cup.byes.has(club.id) and cup.round_names.size() > 1:
			var played_tie := false
			for t in cup.ties:
				if int(t["a"]) == club.id or int(t["b"]) == club.id:
					played_tie = true
			if not played_tie:
				status = "Estreia na %s" % String(cup.round_names[1]).to_lower()
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


## Atalho de seleções: a que o usuário comanda (com a posição no ranking) ou a do país do clube.
static func _nt_line(w: GameWorld) -> String:
	var code := NationalCoach.nation(w)
	if code != "":
		return "Técnico: %s · %dº" % [DatabaseManager.nation_name(code), NationalTeamManager.rank_of(w, code)]
	if not NationalCoach.offers(w).is_empty():
		return ("%d convite de seleção" if NationalCoach.offers(w).size() == 1 else "%d convites de seleção") % NationalCoach.offers(w).size()
	return "%s · %dº" % [DatabaseManager.nation_name(w.user_nation()), NationalTeamManager.rank_of(w, w.user_nation())]


## Data FIFA chegando (ou em andamento): datas, convocados do elenco e a lista do técnico de seleção.
func _fifa_alert(w: GameWorld, club: Club) -> Array:
	var active := NationalTeamManager.active_window(w)
	if not active.is_empty():
		var away := 0
		for p in w.squad(club):
			if p.intl_duty:
				away += 1
		return ["globe", UIColors.ACCENT, ("Data FIFA até %s: %d jogador a serviço da seleção" if away == 1 else "Data FIFA até %s: %d jogadores a serviço da seleção") % [NationalTeamManager.day_label(w, int(active["to"])), away],
			func(): UIManager.push("national")]
	var nxt := NationalTeamManager.next_window(w)
	if nxt.is_empty() or w.season == null:
		return []
	# Só avisa nas duas semanas anteriores (o anúncio das listas sai uma semana antes).
	var today := int(w.season.calendar[mini(w.season.day, w.season.calendar.size() - 1)]["d"])
	if int(nxt["from"]) - today > 16:
		return []
	var code := NationalCoach.nation(w)
	if code != "" and not NationalTeamManager.data(w).has("next"):
		return ["globe", UIColors.ACCENT, "%s: monte a lista para a data FIFA de %s" % [DatabaseManager.nation_name(code), NationalTeamManager.window_label(w, nxt)],
			func(): UIManager.push("national", {"tab": "squad", "nation": code})]
	var d := NationalTeamManager.data(w)
	var nats: Array = []
	for p in w.squad(club):
		if not nats.has(p.nationality):
			nats.append(p.nationality)
	var src := NationalTeamManager.expected_lists(w, nats)
	var n := 0
	for p in w.squad(club):
		if (src.get(p.nationality, []) as Array).has(p.id):
			n += 1
	return ["globe", UIColors.ACCENT, "Data FIFA de %s: %d %s do elenco" % [NationalTeamManager.window_label(w, nxt), n, ("convocado" if n == 1 else "convocados") if d.has("next") else ("provável convocado" if n == 1 else "prováveis convocados")],
		func(): UIManager.push("national")]


func _alerts_card(w: GameWorld, club: Club) -> Control:
	var items := _alerts_items(w, club)
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


func _alerts_items(w: GameWorld, club: Club) -> Array:
	var items: Array = []
	if SponsorManager.is_preseason(w):
		if not KitDesign.launched(w):
			items.append(["shirt", UIColors.ACCENT, "Apresente os uniformes de %d" % w.year, func(): UIManager.push("kit", {"launch": true})])
	var offers := TransferManager.pending_offers(w)
	if not offers.is_empty():
		items.append(["swap", UIColors.ACCENT, ("%d proposta pelo seu elenco" if offers.size() == 1 else "%d propostas pelo seu elenco") % offers.size(), func(): UIManager.goto("market", {"tab": "offers"})])
	if w.transfer_window_open():
		items.append(["swap", UIColors.GREEN, "Janela de transferências aberta até %s" % w.season.date_label(w.window_end_day(), false), func(): UIManager.goto("market")])
	var fifa := _fifa_alert(w, club)
	if not fifa.is_empty():
		items.append(fifa)
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
		items.append(["card", UIColors.ORANGE, ("Suspenso no próximo jogo: " if suspended.size() == 1 else "Suspensos no próximo jogo: ") + ", ".join(suspended), func(): UIManager.goto("squad")])
	if expiring > 0 and w.season.day >= 14:
		items.append(["clock", UIColors.ORANGE, ("%d contrato termina no fim da temporada" if expiring == 1 else "%d contratos terminam no fim da temporada") % expiring, func(): UIManager.goto("squad", {"sort": "contract"})])
	var rules := DatabaseManager.squad_rules()
	if club.player_ids.size() < int(rules["min_players"]):
		items.append(["shirt", UIColors.RED, "Elenco curto: só %d jogadores" % club.player_ids.size(), func(): UIManager.goto("market")])
	var bill := FinanceManager.wage_bill(w, club)
	if bill > club.wage_budget:
		items.append(["money", UIColors.RED, "Folha salarial acima do limite da diretoria", func(): UIManager.goto("club")])
	if club.board_confidence < BoardManager.ULTIMATUM:
		items.append(["info", UIColors.RED, "Ultimato da diretoria", func(): UIManager.push("relations", {"tab": "board"})])
	return items


## Caixa de entrada: as mensagens novas mais recentes (ou um atalho quando está tudo lido).
func _inbox_card(w: GameWorld) -> Control:
	var unread := InboxManager.unread_count(w)
	var card := UIKit.card("CardHighlight" if unread > 0 else "Card", 8)
	var head := UIKit.hbox(8)
	head.add_child(UIKit.icon_rect("mail", 28, UIColors.ACCENT))
	var sec := UIKit.section("Caixa de entrada")
	sec.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sec)
	if unread > 0:
		head.add_child(UIKit.colored(("%d não lida" if unread == 1 else "%d não lidas") % unread, UIColors.ACCENT, "Small"))
	card.add_child(head)
	var items: Array = w.inbox.duplicate()
	items.reverse()
	var shown := 0
	for m: Dictionary in items:
		if shown >= 3:
			break
		# Pedidos em aberto já aparecem nos cartões de decisões e bastidores acima.
		if bool(m.get("r", false)) or InboxManager.action_open(w, m):
			continue
		card.add_child(InboxScreen.row(w, m, func(): refresh()))
		shown += 1
	if shown == 0:
		card.add_child(UIKit.label("Nenhuma mensagem nova." if unread == 0 else "Respostas pendentes acima.", "Muted", true))
	card.add_child(UIKit.button("Abrir caixa de entrada", "GhostButton", func(): UIManager.push("inbox"), "mail"))
	return UIKit.card_panel(card)


## Mundo do futebol: uma manchete com foto e, embaixo, as outras notícias como lista editorial.
func _news_card(w: GameWorld) -> Control:
	var out := UIKit.vbox(UITokens.S2)
	out.add_child(UIKit.section_header("Mundo do futebol", "Todas as notícias", func(): UIManager.push("news")))
	# O que importa primeiro: notícias do seu país e as grandes; o mundo completa se faltar.
	var picked: Array = []
	var rest: Array = []
	for i in range(w.news.size() - 1, maxi(-1, w.news.size() - 60), -1):
		var n: NewsEvent = w.news[i]
		if picked.size() >= 5:
			break
		if n.importance >= NewsEvent.IMP_HIGH or (n.importance >= NewsEvent.IMP_NORMAL and not NewsRow.is_foreign(w, n)):
			picked.append(n)
		elif rest.size() < 5:
			rest.append(n)
	while picked.size() < 5 and not rest.is_empty():
		picked.append(rest.pop_front())
	if picked.is_empty():
		out.add_child(UIKit.state_block("empty", "Nenhuma notícia ainda.", "O noticiário começa com a primeira rodada."))
		return out
	# Manchete: a mais importante das escolhidas; o resto na ordem do mais recente.
	var lead: NewsEvent = picked[0]
	for n: NewsEvent in picked:
		if n.importance > lead.importance:
			lead = n
	picked.erase(lead)
	out.add_child(NewsRow.feature(w, lead, 300, true))
	for n: NewsEvent in picked:
		out.add_child(NewsRow.make(w, n, true))
	return out


## O post mais recente sobre o seu clube nas redes.
func _social_card(w: GameWorld) -> Control:
	var posts := SocialFeed.latest_for_user(w, 3)
	if posts.is_empty():
		return null
	var card := UIKit.vbox(12)
	var head := UIKit.hbox(8)
	var sec := UIKit.section("Feed das redes")
	sec.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sec)
	head.add_child(UIKit.label("%s · %s seguidores" % [SocialFeed.club_acc(w.user_club())["handle"], SocialFeed.count(SocialFeed.followers(w.user_club(), w))], "Small"))
	card.add_child(head)
	for p in posts:
		card.add_child(SocialPost.make(w, p, false))
	card.add_child(UIKit.button("Abrir o feed completo", "GhostButton", func(): UIManager.push("social"), "chat"))
	return card


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
		card.add_child(_club_tap(w, row, opp.id))
	return UIKit.card_panel(card)


## Pré-temporada em andamento: atalho com os passos que faltam.
func _preseason_card(w: GameWorld) -> Control:
	var card := UIKit.card("Card", 10)
	card.add_child(UIKit.section("Pré-temporada %d" % w.year))
	card.add_child(UIKit.label("Antes da estreia", "H2", true))
	var steps := PreseasonManager.steps(w)
	var names := ["Raio-x e planejamento do elenco", "Intertemporada", "Três amistosos de preparação"]
	for i in 3:
		var row := UIKit.hbox(12)
		if steps[i]:
			row.add_child(UIKit.icon_rect("check", 24, UIColors.GREEN))
		else:
			var n := UIKit.label(str(i + 1), "Stat")
			n.custom_minimum_size.x = 24
			n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			n.add_theme_color_override(&"font_color", UIColors.DIM)
			row.add_child(n)
		var l := UIKit.label(names[i], "" if not steps[i] else "Muted", true)
		row.add_child(l)
		card.add_child(row)
	if SponsorManager.is_preseason(w):
		var kit_done := KitDesign.launched(w)
		var krow := UIKit.hbox(10)
		krow.add_child(UIKit.icon_rect("check" if kit_done else "shirt", 26, UIColors.GREEN if kit_done else UIColors.ACCENT))
		krow.add_child(UIKit.label("Uniformes da temporada", "Muted" if kit_done else "", true))
		card.add_child(krow if kit_done else UIKit.tap_row(krow, func(): UIManager.push("kit", {"launch": true})))
	var b := UIKit.button("Abrir pré-temporada", "PrimaryButton", func(): UIManager.push("preseason"))
	b.custom_minimum_size.y = 84
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
	var sec := UIKit.label(league.name, "Section")
	sec.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sec.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(sec)
	for t in ["J", "SG", "Pts"]:
		var hl := UIKit.label(t, "Caps")
		hl.custom_minimum_size.x = 52
		hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hl.size_flags_vertical = Control.SIZE_SHRINK_END
		head.add_child(hl)
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
			pos.add_theme_color_override(&"font_color", UIColors.ink(CompetitionManager.zone_color(zone)))
		row.add_child(pos)
		row.add_child(UIKit.crest(cl, 30))
		var n := UIKit.label(cl.short_name, "H3" if cl.id == club.id else "")
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		if cl.id == club.id:
			n.add_theme_color_override(&"font_color", UIColors.ACCENT)
		row.add_child(n)
		for val in [str(int(r["pl"])), Fmt.signed(int(r["gf"]) - int(r["ga"])), str(int(r["pts"]))]:
			var nl2 := UIKit.label(val)
			nl2.custom_minimum_size.x = 52
			nl2.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			nl2.add_theme_font_override(&"font", DataTable.tabular_font())
			row.add_child(nl2)
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
		col.add_child(UIKit.label(String(it[1]), "Caps"))
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
		card.add_child(_club_tap(w, row, opp.id))
	return UIKit.card_panel(card)


## Convite de lançamento dos uniformes, uma vez por pré-temporada.
func _kit_launch_prompt(w: GameWorld) -> void:
	KitDesign.mark_asked(w)
	var club := w.user_club()
	var sup: Dictionary = club.sponsors.get("fornecedor", {})
	var brand := String(sup.get("n", "")) if not sup.is_empty() else "A fornecedora"
	var v := UIKit.vbox(16)
	v.custom_minimum_size.x = 600
	var head := UIKit.hbox(14)
	head.add_child(UIKit.icon_rect("shirt", 56, UIColors.ACCENT))
	head.add_child(UIKit.label("Uniformes %d" % w.year, "Title", true))
	v.add_child(head)
	v.add_child(UIKit.label("%s mandou três coleções para a nova temporada." % brand, "", true))
	var row := UIKit.hbox(8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for k in [club.kit_home, club.kit_away, club.third_kit()]:
		var kv := UIKit.kit(k, 84, 0, club.crest)
		kv.full = true
		kv.custom_minimum_size = Vector2(96, 160)
		row.add_child(kv)
	v.add_child(UIKit.label("Hoje em campo", "Caps"))
	v.add_child(row)
	v.add_child(UIKit.button("VER AS COLEÇÕES", "PrimaryButton", func():
		UIManager.close_modal()
		UIManager.push("kit", {"launch": true}), "shirt"))
	v.add_child(UIKit.button("Desenhar do zero", "", func():
		UIManager.close_modal()
		UIManager.push("kit", {"launch": true, "part": "models"}), "tactics"))
	v.add_child(UIKit.button("Manter os uniformes atuais", "GhostButton", func():
		UIManager.close_modal()
		KitDesign.mark_launched(w)
		GameManager.save_now()
		refresh()
		SocialPost.show_launch(w)))
	UIManager.show_modal(v)
