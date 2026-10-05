extends BaseScreen
## Futebol de seleções: visão geral (cargo do usuário na seleção, datas FIFA, uniformes e jogos),
## torneios (Copa do Mundo, Eurocopa, Copa América...), eliminatórias em andamento, ranking de
## seleções e a convocação de cada país (editável na seleção que o usuário comanda).

const TABS := [["overview", "Visão geral"], ["squad", "Convocação"], ["tours", "Torneios"], ["quals", "Eliminatórias"], ["ranking", "Ranking"]]

var _tab := "overview"
var _tour := ""
var _camp := 0
var _nation := ""
var _squad_state := {}


func _init() -> void:
	screen_title = "Seleções"


func setup(p: Dictionary) -> void:
	super.setup(p)
	_tab = String(p.get("tab", "overview"))
	if _tab == "coach":
		_tab = "overview"
	_nation = String(p.get("nation", ""))
	_tour = String(p.get("tour", ""))


func refresh() -> void:
	var w := world()
	if w == null:
		return
	if _nation == "":
		_nation = NationalCoach.nation(w)
	if _nation == "":
		_nation = w.user_nation() if w.has_user() else "BRA"
	var nat_rank := NationalTeamManager.rank_of(w, _nation)
	screen_subtitle = "%s · %dº no ranking" % [DatabaseManager.nation_name(_nation), nat_rank]
	UIManager.refresh_chrome()
	var c := content()
	UIKit.clear(c)
	max_content_width = 1700
	var selector := OptionButton.new()
	selector.custom_minimum_size.y = UITokens.H_BUTTON
	selector.tooltip_text = "Consultar seleção"
	var nations: Array = DatabaseManager.nations().keys()
	nations.sort_custom(func(a,b): return DatabaseManager.nation_name(a) < DatabaseManager.nation_name(b))
	for code in nations:
		selector.add_item(DatabaseManager.nation_name(code))
	selector.select(nations.find(_nation))
	selector.item_selected.connect(func(i: int):
		_nation = nations[i]
		refresh())
	c.add_child(selector)
	c.add_child(_hero(w, nat_rank))
	c.add_child(UIKit.scroll_tabs(TABS, _tab, func(k: String):
		_tab = k
		refresh()))
	var start := c.get_child_count()
	match _tab:
		"overview":
			_overview(w, c)
		"tours":
			_tours(w, c)
		"quals":
			_quals(w, c)
		"ranking":
			c.add_child(_ranking(w))
		"squad":
			_squad(w, c)
	columnize(c, start, 2, 2 if _tab == "tours" else (1 if _tab == "squad" else 0))


## Cabeçalho da seleção: bandeira grande, nome, posição no ranking e confederação, no fundo
## com as cores da bandeira (como a tela de seleção de um jogo de futebol licenciado).
func _hero(w: GameWorld, rank: int) -> Control:
	var v := UIKit.card("Card", 10)
	var row := UIKit.hbox(UITokens.S3)
	var fl := UIKit.flag(_nation, 96)
	fl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(fl)
	var col := UIKit.vbox(0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	var nm := UIKit.label(DatabaseManager.nation_name(_nation), "Title")
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(nm)
	var line := tr("%dº no ranking") % rank
	if NationalCoach.nation(w) == _nation:
		line += " · " + tr("Seu comando")
	else:
		line += " · " + tr("Consulta")
	col.add_child(UIKit.label(line, "Muted", true))
	row.add_child(col)
	var kv := UIKit.kit(NationalKits.home(w, _nation), 84)
	kv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(kv)
	v.add_child(row)
	return UIKit.card_panel(v)


# ---------------------------------------------------------------------------
# Visão geral
# ---------------------------------------------------------------------------

func _overview(w: GameWorld, c: VBoxContainer) -> void:
	c.add_child(_job_card(w))
	c.add_child(_windows_card(w))
	c.add_child(_kits_card(w))
	c.add_child(_games_card(w))


## O cargo do usuário: a seleção que comanda (campanha, confiança da federação) ou os convites.
func _job_card(w: GameWorld) -> Control:
	var card := UIKit.card("CardHighlight", 8)
	var code := NationalCoach.nation(w)
	var st := NationalCoach.state(w)
	if code != "":
		card.add_child(UIKit.section("Seu cargo na seleção"))
		var h := UIKit.hbox(12)
		h.add_child(UIKit.flag(code, 56))
		var col := UIKit.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UIKit.label(DatabaseManager.nation_name(code), "H2", true))
		col.add_child(UIKit.label("Você é o técnico desde %d, junto com o %s" % [int(st.get("since", w.year)), w.user_club().short_name], "Small", true))
		h.add_child(col)
		card.add_child(h)
		card.add_child(StatStrip.make([
			["V-E-D", "%d-%d-%d" % [int(st.get("w", 0)), int(st.get("d", 0)), int(st.get("l", 0))]],
			["Gols", "%d:%d" % [int(st.get("gf", 0)), int(st.get("ga", 0))]],
			["Títulos", str((st.get("titles", []) as Array).size())]]))
		var sat := float(st.get("sat", 60.0))
		var sc := UIColors.GREEN if sat >= 60.0 else (UIColors.ACCENT if sat >= 35.0 else UIColors.RED)
		card.add_child(UIKit.kv("Confiança da federação", "%d%%" % int(round(sat)), sc))
		card.add_child(UIKit.bar(sat, 100.0, sc))
		card.add_child(UIKit.label("Meta: %s." % NationalCoach.expectation(w, code), "Small", true))
		var row := UIKit.flow(8)
		row.add_child(UIKit.button("Montar a lista", "PrimaryButton", func():
			_nation = code
			_tab = "squad"
			refresh(), "users"))
		row.add_child(UIKit.button("Uniformes", "GhostButton", func(): UIManager.push("kit", {"nation": code}), "shirt"))
		row.add_child(UIKit.button("Deixar o cargo", "GhostButton", func():
			UIManager.confirm("Deixar a seleção", "Você deixa o comando da seleção (%s) e segue só no clube." % DatabaseManager.nation_name(code), "Sair da seleção", func():
				NationalCoach.resign(w)
				GameManager.save_now()
				refresh()), "close"))
		card.add_child(row)
	else:
		card.add_child(UIKit.section("Seu cargo"))
		card.add_child(UIKit.label("Você comanda apenas o %s." % w.user_club().short_name, "", true))
		card.add_child(UIKit.kv("Sua reputação", str(int(round(People.manager_rep(w))))))
	var offers: Array = NationalCoach.offers(w)
	if not offers.is_empty():
		card.add_child(UIKit.section("Convites"))
	for o in offers:
		var oc := String(o["n"])
		var h := UIKit.hbox(10)
		h.add_child(UIKit.flag(oc, 40))
		var col := UIKit.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var nl := UIKit.label(DatabaseManager.nation_name(oc), "H3")
		nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		col.add_child(nl)
		col.add_child(UIKit.label("%dº no ranking · %s" % [NationalTeamManager.rank_of(w, oc), NationalCoach.expectation(w, oc)], "Small", true))
		h.add_child(col)
		card.add_child(h)
		var br := UIKit.hbox(8)
		var yes := UIKit.button("Assumir seleção", "PrimaryButton", func():
			UIManager.confirm("Assumir a seleção de %s" % DatabaseManager.nation_name(oc),
				"Você vai comandar esta seleção e continuar no %s." % w.user_club().short_name, "Assumir seleção", func():
					NationalCoach.accept(w, oc)
					_nation = oc
					GameManager.save_now()
					refresh()), "check")
		yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		br.add_child(yes)
		var no := UIKit.button("Recusar", "GhostButton", func():
			NationalCoach.decline(w, oc)
			refresh())
		no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		br.add_child(no)
		card.add_child(br)
	_vacancies(w, card)
	var hist: Array = st.get("hist", [])
	if not hist.is_empty():
		card.add_child(UIKit.section("Passagens"))
		for i in range(hist.size() - 1, -1, -1):
			var e: Dictionary = hist[i]
			card.add_child(UIKit.kv("%s (%d-%d)" % [DatabaseManager.nation_name(e["n"]), int(e["from"]), int(e["to"])], "%d-%d-%d · %s" % [int(e["w"]), int(e["d"]), int(e["l"]), e["why"]]))
	return UIKit.card_panel(card)


## Vagas abertas no mercado de técnicos de seleção: o usuário se candidata e a federação responde.
func _vacancies(w: GameWorld, card: VBoxContainer) -> void:
	var list: Array = NationalCoach.vacancies(w)
	card.add_child(UIKit.section("Vagas abertas (%d)" % list.size()))
	if list.is_empty():
		card.add_child(UIKit.label("Nenhuma seleção procura técnico agora.", "Muted", true))
		return
	for code in list.slice(0, 8):
		var oc := String(code)
		if NationalCoach.has_offer(w, oc):
			continue
		var h := UIKit.hbox(10)
		h.add_child(UIKit.flag(oc, 36))
		var col := UIKit.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var nl := UIKit.label(DatabaseManager.nation_name(oc), "H3")
		nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		col.add_child(nl)
		col.add_child(UIKit.label("%dº no ranking · %s · pede reputação %d · chance %s" % [NationalTeamManager.rank_of(w, oc),
			NationalCoach.vacancy_reason(w, oc).to_lower(), int(round(NationalCoach.required_rep(w, oc))), NationalCoach.chance_label(w, oc)], "Small", true))
		h.add_child(col)
		if NationalCoach.applied(w, oc):
			h.add_child(UIKit.colored("Candidatura enviada", UIColors.MUTED, "Small"))
		else:
			h.add_child(UIKit.button("Candidatar", "GhostButton", func():
				NationalCoach.apply(w, oc)
				GameManager.save_now()
				refresh()))
		card.add_child(h)


## Datas FIFA da temporada, com a próxima em destaque e quem do clube deve ir.
func _windows_card(w: GameWorld) -> Control:
	var card := UIKit.card("Card", 6)
	card.add_child(UIKit.section("Datas FIFA %s" % str(w.year)))
	var wins := NationalTeamManager.windows(w)
	if wins.is_empty():
		card.add_child(UIKit.label("Sem datas FIFA no calendário.", "Muted"))
		return UIKit.card_panel(card)
	card.add_child(UIKit.label("As ligas param e os convocados viajam." if NationalTeamManager.league_pauses(w)
		else "O campeonato não para: os convocados desfalcam os clubes durante a data.", "Small", true))
	var nxt := NationalTeamManager.next_window(w)
	var active := NationalTeamManager.active_window(w)
	for win in wins:
		var h := UIKit.hbox(10)
		var done: bool = w.season != null and int(win["slot"]) < w.season.day and win != active
		var is_next: bool = not nxt.is_empty() and int(win["slot"]) == int(nxt["slot"])
		h.add_child(UIKit.icon_rect("check" if done else ("clock" if is_next or win == active else "minus"), 24,
			UIColors.GREEN if done else (UIColors.ACCENT if is_next or win == active else UIColors.DIM)))
		var l := UIKit.label(NationalTeamManager.window_label(w, win), "H3" if is_next or win == active else "")
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		var tag := "em andamento" if win == active else ("próxima" if is_next else ("disputada" if done else ""))
		if tag != "":
			h.add_child(UIKit.colored(tag.capitalize(), UIColors.TEXT if tag != "disputada" else UIColors.DIM, "Small"))
		card.add_child(h)
	# Quem do clube do usuário está (ou deve estar) na próxima lista
	if w.has_user() and (not nxt.is_empty() or not active.is_empty()):
		var d := NationalTeamManager.data(w)
		var nats: Array = []
		for p in w.squad(w.user_club()):
			if not nats.has(p.nationality):
				nats.append(p.nationality)
		var src := NationalTeamManager.expected_lists(w, nats)
		var mine: Array = []
		for p in w.squad(w.user_club()):
			if (src.get(p.nationality, []) as Array).has(p.id):
				mine.append(p.display_name())
		var announced := d.has("next")
		var head := "Convocados do %s" % w.user_club().short_name if announced else "Prováveis convocados do %s" % w.user_club().short_name
		card.add_child(UIKit.kv(head, str(mine.size()), UIColors.ACCENT if mine.size() > 0 else UIColors.MUTED))
		if not mine.is_empty():
			card.add_child(UIKit.label(", ".join(mine), "Small", true))
	return UIKit.card_panel(card)


## Titular, reserva e goleiro da seleção, desenhados como os dos clubes.
func _kits_card(w: GameWorld) -> Control:
	var card := UIKit.card("Card", 6)
	card.add_child(UIKit.section("Uniformes"))
	var k := NationalKits.kits(w, _nation)
	var row := UIKit.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for pair in [["home", "Titular"], ["away", "Reserva"], ["gk", "Goleiro"]]:
		var v := UIKit.vbox(2)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		var kv := UIKit.kit(k[pair[0]], 104)
		kv.full = true
		kv.custom_minimum_size = Vector2(104, 104 / KitView.FULL_ASPECT)
		v.add_child(kv)
		var l := UIKit.label(String(pair[1]), "Caps")
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
		row.add_child(v)
	card.add_child(row)
	if NationalCoach.nation(w) == _nation:
		var code := _nation
		card.add_child(UIKit.button("Editar uniformes", "GhostButton", func(): UIManager.push("kit", {"nation": code}), "palette"))
	return UIKit.card_panel(card)


## Últimos jogos da seleção (eliminatórias, amistosos e torneios).
func _games_card(w: GameWorld) -> Control:
	var card := UIKit.card("Card", 4)
	card.add_child(UIKit.section("Últimos jogos"))
	var games := NationalTeamManager.recent_games(w, _nation, 8)
	if games.is_empty():
		card.add_child(UIKit.label("A seleção ainda não jogou nesta carreira.", "Muted", true))
	for g in games:
		var v := UIKit.vbox(0)
		v.add_child(UIKit.label("%s · %d" % [g["tag"] if String(g["tag"]) != "" else "Jogo", int(g["y"])], "Caps"))
		var m := [g["a"], g["b"], g["ga"], g["gb"], g["pa"], g["pb"], false, ""]
		var won: bool = (g["a"] == _nation and (int(g["ga"]) > int(g["gb"]) or int(g["pa"]) > int(g["pb"]))) or (g["b"] == _nation and (int(g["gb"]) > int(g["ga"]) or int(g["pb"]) > int(g["pa"])))
		m[7] = _nation if won else ""
		v.add_child(_match_row(w, m))
		card.add_child(v)
	return UIKit.card_panel(card)


# ---------------------------------------------------------------------------
# Torneios
# ---------------------------------------------------------------------------

func _tours(w: GameWorld, c: VBoxContainer) -> void:
	var next := UIKit.card("Card", 6)
	next.add_child(UIKit.section("Próximos torneios"))
	var upcoming: Array = []
	for id in NationalTeamManager.tournament_ids():
		var y := NationalTeamManager.next_edition(id, w.year + 1)
		upcoming.append([y, id])
	upcoming.sort_custom(func(a, b): return int(a[0]) < int(b[0]) or (int(a[0]) == int(b[0]) and String(a[1]) < String(b[1])))
	for u in upcoming:
		var id: String = u[1]
		var y: int = u[0]
		var host := NationalTeamManager.host_of(id, y)
		var h := UIKit.hbox(10)
		h.add_child(UIKit.flag(host, 36))
		var l := UIKit.label("%s %d" % [NationalTeamManager.tournament_name(id), y], "H3", true)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		next.add_child(h)
		if host != "":
			next.add_child(UIKit.label("Sede: " + NationalTeamManager._names(NationalTeamManager.hosts_of(id, y)), "Small", true))
	c.add_child(UIKit.card_panel(next))
	var ids := NationalTeamManager.tournament_ids()
	if _tour == "":
		var tours: Array = NationalTeamManager.data(w)["tours"]
		_tour = String(tours[tours.size() - 1]["t"]) if not tours.is_empty() else String(ids[0])
	var items: Array = []
	for id in ids:
		items.append([String(id), String(NationalTeamManager.tcfg(String(id)).get("short", id))])
	c.add_child(UIKit.scroll_tabs(items, _tour, func(k: String):
		_tour = k
		refresh()))
	var rec := NationalTeamManager.last_edition(w, _tour)
	c.add_child(UIKit.label(String(NationalTeamManager.tcfg(_tour).get("format", "")), "Small", true))
	if _tour in NationalLeagues.IDS:
		var live: Dictionary = NationalLeagues.states(w).get(_tour, {})
		if not live.is_empty() and not bool(live.get("done", false)):
			c.add_child(UIKit.label("Em disputa — %d" % int(live["y"]), "Section"))
			for group in live["groups"]:
				var table := UIKit.vbox(UITokens.S1)
				table.add_child(UIKit.section_header("Liga %s — Grupo %s" % ["ABCD"[int(group["level"])], group["n"]]))
				var order := NationalTeamManager.sort_group(group)
				for i in order.size():
					table.add_child(_nation_table_row(w, order[i], group["table"][order[i]], i + 1, i == 0))
				c.add_child(table)
	if rec.is_empty():
		c.add_child(UIKit.label("Primeira edição em %d." % NationalTeamManager.next_edition(_tour, w.year + 1), "Muted", true))
	else:
		c.add_child(_edition(w, rec))
	c.add_child(_champions_list(w, _tour))


func _edition(w: GameWorld, rec: Dictionary) -> Control:
	var out := UIKit.vbox(12)
	var head := UIKit.card("CardHighlight", 8)
	head.add_child(UIKit.label("%s %d" % [rec["name"], int(rec["y"])], "Title", true))
	head.add_child(UIKit.label("%d seleções" % (rec["teams"] as Array).size(), "Small"))
	if String(rec.get("host", "")) != "":
		head.add_child(UIKit.label("Sede: " + NationalTeamManager._names(rec.get("hosts", [rec["host"]])), "Small", true))
	var ch := UIKit.hbox(12)
	ch.add_child(UIKit.icon_rect("trophy", 36, UIColors.ACCENT))
	ch.add_child(UIKit.flag(rec["champion"], 48))
	var cl := UIKit.label("%s campeã" % DatabaseManager.nation_name(rec["champion"]), "H2", true)
	cl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cl.add_theme_color_override(&"font_color", UIColors.ACCENT)
	ch.add_child(cl)
	head.add_child(ch)
	head.add_child(UIKit.label("Vice: %s" % DatabaseManager.nation_name(rec["runner_up"]), ""))
	var sc: Dictionary = rec.get("scorer", {})
	if not sc.is_empty():
		head.add_child(UIKit.label("Artilheiro: %s (%s), %d gols" % [sc["name"], DatabaseManager.nation_name(sc["nation"]), int(sc["goals"])], "Small"))
	out.add_child(UIKit.card_panel(head))
	# Mata-mata, da final para trás
	var ko: Array = rec.get("ko", [])
	for i in range(ko.size() - 1, -1, -1):
		var rd: Dictionary = ko[i]
		var card := UIKit.card("Card", 4)
		card.add_child(UIKit.section(String(rd["n"])))
		for m in rd["m"]:
			card.add_child(_match_row(w, m))
		out.add_child(UIKit.card_panel(card))
	# Grupos
	for gr in rec.get("groups", []):
		var card := UIKit.card("Card", 4)
		card.add_child(UIKit.section("Grupo %s" % gr["n"]))
		var order: Array = gr["order"]
		for i in order.size():
			card.add_child(_nation_table_row(w, order[i], gr["table"][order[i]], i + 1, i < 2))
		out.add_child(UIKit.card_panel(card))
	return out


## Linha de jogo de mata-mata: [a, b, ga, gb, pa, pb, et, vencedor].
func _match_row(w: GameWorld, m: Array) -> Control:
	var h := UIKit.hbox(8)
	var a := UIKit.label(DatabaseManager.nation_name(m[0]), "H3" if m[7] == m[0] else "")
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	a.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	h.add_child(a)
	h.add_child(UIKit.flag(m[0], 30))
	var score := "%d x %d" % [int(m[2]), int(m[3])]
	if int(m[4]) >= 0:
		score += "\n(%d x %d pên.)" % [int(m[4]), int(m[5])]
	elif bool(m[6]):
		score += "\n(prorr.)"
	var s := UIKit.label(score, "H3")
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.custom_minimum_size.x = 110
	h.add_child(s)
	h.add_child(UIKit.flag(m[1], 30))
	var b := UIKit.label(DatabaseManager.nation_name(m[1]), "H3" if m[7] == m[1] else "")
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	h.add_child(b)
	return h


func _nation_table_row(w: GameWorld, code: String, r: Dictionary, pos: int, highlight: bool) -> Control:
	var h := UIKit.hbox(8)
	var bar := ColorRect.new()
	bar.custom_minimum_size = Vector2(5, 0)
	bar.color = CompetitionManager.zone_color(CompetitionManager.ZONE_CONTINENTAL) if highlight else Color(0, 0, 0, 0)
	h.add_child(bar)
	var pl := UIKit.label(str(pos), "H3")
	pl.custom_minimum_size.x = 30
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(pl)
	h.add_child(UIKit.flag(code, 30))
	var mine := code == NationalCoach.nation(w)
	var n := UIKit.label(DatabaseManager.nation_name(code), "H3" if mine else "")
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if mine:
		n.add_theme_color_override(&"font_color", UIColors.ACCENT)
	h.add_child(n)
	var sg := int(r["gf"]) - int(r["ga"])
	var vals: Array = [str(int(r["pl"])), Fmt.signed(sg), str(int(r["pts"]))]
	for i in vals.size():
		var l := UIKit.label(vals[i], "H3" if i == vals.size() - 1 else "")
		l.custom_minimum_size.x = 46
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(l)
	var key := code
	return UIKit.tap_row(h, func():
		_nation = key
		_tab = "squad"
		refresh(), "CardFlat")


func _champions_list(w: GameWorld, id: String) -> Control:
	var card := UIKit.card("Card", 4)
	card.add_child(UIKit.section("Campeões"))
	var any := false
	var tours: Array = NationalTeamManager.data(w)["tours"]
	for i in range(tours.size() - 1, -1, -1):
		var r: Dictionary = tours[i]
		if String(r["t"]) != id:
			continue
		any = true
		var h := UIKit.hbox(10)
		var y := UIKit.label(str(int(r["y"])), "H3")
		y.custom_minimum_size.x = 64
		h.add_child(y)
		h.add_child(UIKit.flag(r["champion"], 32))
		var n := UIKit.label(DatabaseManager.nation_name(r["champion"]), "H3")
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(n)
		h.add_child(UIKit.label("vice: %s" % DatabaseManager.nation_name(r["runner_up"]), "Small"))
		card.add_child(h)
	# Antes do save: os campeões reais (data/world/national_titles.json), do mais recente ao mais antigo.
	var src: Variant = DatabaseManager.get_data("national_titles")
	var past: Array = (src.get("titles", {}) as Dictionary).get(id, []) if src is Dictionary else []
	var first := int(NationalTeamManager.tcfg(id).get("first", 9999))
	for i in range(past.size() - 1, -1, -1):
		var e: Array = past[i]
		if int(e[0]) >= first:
			continue
		any = true
		var h := UIKit.hbox(10)
		var y := UIKit.label(str(int(e[0])), "H3")
		y.custom_minimum_size.x = 64
		h.add_child(y)
		h.add_child(UIKit.flag(String(e[1]), 32))
		var n := UIKit.label(DatabaseManager.nation_name(String(e[1])), "H3")
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(n)
		card.add_child(h)
	if not any:
		card.add_child(UIKit.label("Nenhuma edição disputada ainda.", "Muted"))
	return UIKit.card_panel(card)


# ---------------------------------------------------------------------------
# Eliminatórias
# ---------------------------------------------------------------------------

func _quals(w: GameWorld, c: VBoxContainer) -> void:
	var camps: Array = NationalTeamManager.data(w)["camps"].duplicate()
	if camps.is_empty():
		c.add_child(UIKit.label("Nenhuma eliminatória em andamento.", "Muted", true))
		return
	# A confederação do usuário primeiro
	var confed := String(DatabaseManager.nation(_nation).get("confed", ""))
	camps.sort_custom(func(a, b): return (String(a["confed"]) == confed and String(b["confed"]) != confed) or (String(a["confed"]) == String(b["confed"]) and int(a["y"]) < int(b["y"])))
	_camp = clampi(_camp, 0, camps.size() - 1)
	var ob := OptionButton.new()
	for i in camps.size():
		ob.add_item("%s %d" % [camps[i]["name"], int(camps[i]["y"])], i)
	ob.select(_camp)
	ob.item_selected.connect(func(i: int):
		_camp = i
		refresh())
	c.add_child(ob)
	var camp: Dictionary = camps[_camp]
	var info := UIKit.card("CardHighlight", 6)
	info.add_child(UIKit.label("%s %d" % [camp["name"], int(camp["y"])], "H2"))
	info.add_child(UIKit.label(("Rodada %d de %d · %d vaga%s" if int(camp["spots"]) == 1 else "Rodada %d de %d · %d vagas%s") % [int(camp["md"]), int(camp["mdt"]), int(camp["spots"]), " · encerrada" if bool(camp["done"]) else ""], "Small"))
	if bool(camp["done"]):
		info.add_child(UIKit.label("Classificados: %s" % ", ".join((camp["q"] as Array).map(func(x): return DatabaseManager.nation_name(x))), "", true))
	c.add_child(UIKit.card_panel(info))
	var groups: Array = camp["groups"]
	var per_group := int(camp["spots"]) / maxi(1, groups.size())
	for g in groups:
		var card := UIKit.card("Card", 4)
		if groups.size() > 1:
			card.add_child(UIKit.section("Grupo %s" % g["n"]))
		var order := NationalTeamManager.sort_group(g)
		for i in order.size():
			var q := (camp["q"] as Array).has(order[i]) if bool(camp["done"]) else i < per_group
			card.add_child(_nation_table_row(w, order[i], g["table"][order[i]], i + 1, q))
		c.add_child(UIKit.card_panel(card))


# ---------------------------------------------------------------------------
# Ranking
# ---------------------------------------------------------------------------

func _ranking(w: GameWorld) -> Control:
	var card := UIKit.card("Card", 2)
	card.add_child(UIKit.section("Ranking de seleções"))
	var r := NationalTeamManager.ranking(w)
	var mine := NationalCoach.nation(w)
	for i in r.size():
		var code: String = r[i][0]
		var h := UIKit.hbox(10)
		var pl := UIKit.label(str(i + 1), "H3")
		pl.custom_minimum_size.x = 40
		pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(pl)
		h.add_child(UIKit.flag(code, 34))
		var n := UIKit.label(DatabaseManager.nation_name(code), "H3" if code == mine else "")
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if code == mine:
			n.add_theme_color_override(&"font_color", UIColors.ACCENT)
		h.add_child(n)
		var titles := NationalTeamManager.titles_of(w, code).size()
		if titles > 0:
			h.add_child(UIKit.colored(("%d título" if titles == 1 else "%d títulos") % titles, UIColors.MUTED, "Small"))
		var pts := UIKit.label(str(int(round(float(r[i][1])))), "H3")
		pts.custom_minimum_size.x = 70
		pts.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(pts)
		var key := code
		card.add_child(UIKit.tap_row(h, func():
			_nation = key
			_tab = "squad"
			refresh(), "CardFlat"))
	return UIKit.card_panel(card)


# ---------------------------------------------------------------------------
# Convocação
# ---------------------------------------------------------------------------

func _squad(w: GameWorld, c: VBoxContainer) -> void:
	if NationalCoach.nation(w) == _nation:
		_my_squad(w, c)
		return
	var ids: Array = NationalTeamManager.data(w)["squads"].get(_nation, [])
	var squad: Array = []
	for pid in ids:
		var p := w.player(int(pid))
		if p != null:
			squad.append(p)
	var fresh := squad.is_empty()
	if fresh:
		# Ainda sem data FIFA: mostra quem seria chamado hoje.
		var pool: Array = []
		for p: Player in w.players.values():
			if NationalityManager.team(p) == _nation and p.club_id >= 0 and p.injury_weeks == 0:
				pool.append(p)
		squad = NationalTeamManager.call_up(pool)
	# O cabeçalho da tela já mostra bandeira e nome: aqui só o que é da lista.
	var bits: Array = [tr("Lista provável, se a convocação fosse hoje.") if fresh else tr("Última convocação.")]
	c.add_child(UIKit.label(" ".join(bits), "Muted", true))
	if squad.is_empty():
		c.add_child(UIKit.state_block("empty", "Nenhum jogador desta nacionalidade.", "Só entram jogadores com clube."))
		_add_titles(w, c)
		return
	var v := UIKit.vbox(UITokens.S1)
	v.add_child(UIKit.label("%d convocados" % squad.size(), "Section"))
	v.add_child(PlayerTable.make(w, squad, "national", _squad_state, func(p: Player): UIManager.push("player", {"id": p.id}),
		_caps_cols(w), "selecao", content_width() >= 760.0))
	c.add_child(v)
	_add_titles(w, c)


## Títulos da seleção (o passado real e os do save), um torneio por linha: quantos e em que anos.
func _add_titles(w: GameWorld, c: VBoxContainer) -> void:
	var sum := NationalTeamManager.titles_summary(w, _nation)
	if sum.is_empty():
		return
	var v := UIKit.vbox(0)
	v.add_child(UIKit.label("Títulos", "Section"))
	for e in sum:
		var row := UIKit.hbox(UITokens.S3)
		row.custom_minimum_size.y = UITokens.H_ROW
		var col := UIKit.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		col.add_child(UIKit.label(String(NationalTeamManager.tcfg(String(e[0])).get("name", e[0])), "H3"))
		var years: Array = []
		for y in e[2]:
			years.append(str(int(y)))
		var yl := UIKit.label(", ".join(years), "Muted", true)
		yl.add_theme_font_override(&"font", DataTable.tabular_font())
		col.add_child(yl)
		row.add_child(col)
		var n := UIKit.label("%d×" % int(e[1]), "Section")
		n.add_theme_font_override(&"font", DataTable.tabular_font())
		n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(n)
		var line := PanelContainer.new()
		line.theme_type_variation = "RowPanel"
		line.add_child(row)
		v.add_child(line)
	c.add_child(v)


## Jogos e gols pela seleção, no fim da tabela de convocados.
func _caps_cols(w: GameWorld) -> Array:
	return [
		{"key": "caps", "title": "Jogos", "w": 60, "tip": "Jogos pela seleção",
			"text": func(p: Player) -> String: return str(int(NationalTeamManager.caps_of(w, p.id)[0])),
			"sort": func(p: Player) -> int: return int(NationalTeamManager.caps_of(w, p.id)[0])},
		{"key": "ngoals", "title": "Gols", "w": 52, "tip": "Gols pela seleção",
			"text": func(p: Player) -> String: return str(int(NationalTeamManager.caps_of(w, p.id)[1])),
			"sort": func(p: Player) -> int: return int(NationalTeamManager.caps_of(w, p.id)[1]),
			"color": func(p: Player) -> Color: return UIColors.TEXT if int(NationalTeamManager.caps_of(w, p.id)[1]) > 0 else UIColors.DIM},
	]


## Lista do técnico usuário: chama e dispensa jogadores; vale para a próxima data FIFA.
func _my_squad(w: GameWorld, c: VBoxContainer) -> void:
	var list := NationalCoach.current_list(w)
	var chosen := not list.is_empty()
	if not chosen:
		list = NationalCoach.suggested(w, _nation)
	var head := UIKit.card("CardHighlight", 8)
	var hh := UIKit.hbox(12)
	hh.add_child(UIKit.flag(_nation, 56))
	var col := UIKit.vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UIKit.label("Sua lista: %d de %d" % [list.size(), NationalTeamManager.SQUAD_SIZE], "H2", true))
	col.add_child(UIKit.label("%d convocados" % list.size(), "Small"))
	hh.add_child(col)
	head.add_child(hh)
	var nxt := NationalTeamManager.next_window(w)
	var note := "Sugestão da comissão técnica." if not chosen else "Faltando gente, a comissão completa com os melhores disponíveis."
	if not nxt.is_empty():
		note = "Vale para a data FIFA de %s (a lista sai uma semana antes). " % NationalTeamManager.window_label(w, nxt) + note
	head.add_child(UIKit.label(note, "Small", true))
	var br := UIKit.flow(8)
	br.add_child(UIKit.button("Sugestão da comissão", "GhostButton", func():
		NationalCoach.fill_suggested(w)
		refresh(), "bolt"))
	head.add_child(br)
	c.add_child(UIKit.card_panel(head))
	list.sort_custom(func(a, b): return Pos.DISPLAY_ORDER.find(a.position) < Pos.DISPLAY_ORDER.find(b.position) or (a.position == b.position and a.ovr_f > b.ovr_f))
	var card := UIKit.card("Card", 4)
	card.add_child(UIKit.section("Convocados"))
	for p: Player in list:
		card.add_child(_pick_row(w, p, true))
	c.add_child(UIKit.card_panel(card))
	var pool := UIKit.card("Card", 4)
	pool.add_child(UIKit.section("Disponíveis"))
	var n := 0
	for p: Player in NationalCoach.eligible(w, _nation):
		if list.has(p):
			continue
		pool.add_child(_pick_row(w, p, false))
		n += 1
		if n >= 30:
			break
	if n == 0:
		pool.add_child(UIKit.label("Ninguém mais desta nacionalidade tem clube.", "Muted", true))
	c.add_child(UIKit.card_panel(pool))


func _pick_row(w: GameWorld, p: Player, called: bool) -> Control:
	var h := UIKit.hbox(10)
	h.add_child(UIKit.pos_badge(p.position))
	var cl: Club = w.club(p.club_id) if p.club_id >= 0 else null
	h.add_child(UIKit.crest(cl, 30))
	var v := UIKit.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nm := UIKit.label(p.display_name(), "H3")
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(nm)
	var caps := NationalTeamManager.caps_of(w, p.id)
	var info := "%s · %d anos · %d jogos" % [cl.short_name if cl != null else "sem clube", p.age(w.year), caps[0]]
	if p.injury_weeks > 0:
		info += " · lesionado"
	var il := UIKit.label(info, "Small")
	il.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(il)
	h.add_child(v)
	h.add_child(UIKit.player_stars(w,p,15))
	var pid := p.id
	var btn := UIKit.icon_button("minus" if called else "plus", func():
		if not NationalCoach.toggle(w, pid):
			UIManager.toast("A lista já tem %d nomes." % NationalTeamManager.SQUAD_SIZE, UIColors.RED)
		refresh(), "Dispensar" if called else "Convocar")
	h.add_child(btn)
	return UIKit.tap_row(h, func(): UIManager.push("player", {"id": pid}), "CardFlat")
