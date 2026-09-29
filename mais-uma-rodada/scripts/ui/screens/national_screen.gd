extends BaseScreen
## Futebol de seleções: torneios (Copa do Mundo, Eurocopa, Copa América...), eliminatórias em
## andamento, ranking de seleções e a convocação de cada país.

const TABS := [["tours", "Torneios"], ["quals", "Eliminatórias"], ["ranking", "Ranking"], ["squad", "Convocação"], ["command", "Comando"], ["calendar", "Data FIFA"], ["kits", "Uniformes"]]

var _tab := "tours"
var _tour := ""
var _camp := 0
var _nation := ""
var _candidate_page := 0
var _candidate_query := ""
var _candidate_group := -1


func _init() -> void:
	show_nav = false
	screen_title = "Seleções"


func setup(p: Dictionary) -> void:
	super.setup(p)
	_tab = String(p.get("tab", "tours"))
	_nation = String(p.get("nation", ""))
	_tour = String(p.get("tour", ""))


func refresh() -> void:
	var w := world()
	if w == null:
		return
	if _nation == "":
		_nation = w.user_nation() if w.has_user() else "BRA"
	var nat_rank := NationalTeamManager.rank_of(w, _nation)
	screen_subtitle = "%s · %dº no ranking" % [DatabaseManager.nation_name(_nation), nat_rank]
	UIManager.refresh_chrome()
	var c := content()
	UIKit.clear(c)
	max_content_width = 1700
	c.add_child(_hero(w, nat_rank))
	c.add_child(UIKit.scroll_tabs(TABS, _tab, func(k: String):
		_tab = k
		refresh()))
	var start := c.get_child_count()
	match _tab:
		"tours":
			_tours(w, c)
		"quals":
			_quals(w, c)
		"ranking":
			c.add_child(_ranking(w))
		"squad":
			_squad(w, c)
		"command":
			_command(w,c)
		"calendar":
			_calendar(w,c)
		"kits":
			_kits(c)
	columnize(c, start, 2, 2 if _tab == "tours" else 0)


## Cabeçalho da seleção: bandeira grande, nome, posição no ranking e confederação, no fundo
## com as cores da bandeira (como a tela de seleção de um jogo de futebol licenciado).
func _hero(w: GameWorld, rank: int) -> Control:
	var v := UIKit.card("Card", 10)
	var row := UIKit.hbox(18)
	var fl := UIKit.flag(_nation, 120)
	fl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(fl)
	var col := UIKit.vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(UIKit.eyebrow("Seleção"))
	col.add_child(UIKit.label(DatabaseManager.nation_name(_nation).to_upper(), "Title", true))
	row.add_child(col)
	var rk := UIKit.stat_tile("%dº" % rank, "Ranking", UIColors.ACCENT)
	rk.size_flags_horizontal = Control.SIZE_SHRINK_END
	rk.custom_minimum_size.x = 140
	row.add_child(rk)
	v.add_child(row)
	return UIKit.card_panel(v)


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
		var l := UIKit.label("%s %d" % [NationalTeamManager.tournament_name(id), y], "H3")
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		h.add_child(UIKit.label("sede: %s" % DatabaseManager.nation_name(host), "Small"))
		next.add_child(h)
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
	if rec.is_empty():
		c.add_child(UIKit.label("Primeira edição em %d." % NationalTeamManager.next_edition(_tour, w.year + 1), "Muted", true))
	else:
		c.add_child(_edition(w, rec))
	c.add_child(_champions_list(w, _tour))


func _edition(w: GameWorld, rec: Dictionary) -> Control:
	var out := UIKit.vbox(12)
	var head := UIKit.card("CardHighlight", 8)
	head.add_child(UIKit.label("%s %d" % [rec["name"], int(rec["y"])], "Title"))
	head.add_child(UIKit.label("Sede: %s · %d seleções" % [DatabaseManager.nation_name(rec["host"]), (rec["teams"] as Array).size()], "Small"))
	var ch := UIKit.hbox(12)
	ch.add_child(UIKit.icon_rect("trophy", 36, UIColors.ACCENT))
	ch.add_child(UIKit.flag(rec["champion"], 48))
	var cl := UIKit.label("%s campeã" % DatabaseManager.nation_name(rec["champion"]), "H2")
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
	var mine := w.has_user() and code == w.user_nation()
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
	card.add_child(UIKit.section("Campeões no save"))
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
	info.add_child(UIKit.label("Rodada %d de %d · %d vaga(s)%s" % [int(camp["md"]), int(camp["mdt"]), int(camp["spots"]), " · encerrada" if bool(camp["done"]) else ""], "Small"))
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
	var mine := w.user_nation() if w.has_user() else ""
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
			h.add_child(UIKit.pill("%d título(s)" % titles, UIColors.ACCENT, 14))
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
	var nations: Array = DatabaseManager.nations().keys()
	nations.sort_custom(func(a, b): return DatabaseManager.nation_name(a) < DatabaseManager.nation_name(b))
	var ob := OptionButton.new()
	for i in nations.size():
		ob.add_item(DatabaseManager.nation_name(nations[i]), i)
		if nations[i] == _nation:
			ob.select(i)
	ob.item_selected.connect(func(i: int):
		_nation = String(nations[i])
		refresh())
	c.add_child(ob)
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
			if p.nationality == _nation and p.club_id >= 0 and p.injury_weeks == 0:
				pool.append(p)
		squad = NationalTeamManager.call_up(pool)
	var head := UIKit.card("CardHighlight", 6)
	var hh := UIKit.hbox(12)
	hh.add_child(UIKit.flag(_nation, 64))
	var col := UIKit.vbox(2)
	col.add_child(UIKit.label(DatabaseManager.nation_name(_nation), "Title"))
	col.add_child(UIKit.label("%dº no ranking · força %d · %s" % [NationalTeamManager.rank_of(w, _nation), int(round(NationalTeamManager.strength_of(_nation, squad))),
		"lista provável" if fresh else "última convocação"], "Small"))
	hh.add_child(col)
	head.add_child(hh)
	var titles := NationalTeamManager.titles_of(w, _nation)
	if not titles.is_empty():
		var tf := UIKit.flow(6)
		for t in titles:
			tf.add_child(UIKit.pill("%s %d" % [String(NationalTeamManager.tcfg(t[0]).get("short", t[0])), int(t[1])], UIColors.ACCENT, 14))
		head.add_child(tf)
	c.add_child(UIKit.card_panel(head))
	if squad.is_empty():
		c.add_child(UIKit.label("Nenhum jogador desta nacionalidade.", "Muted", true))
		return
	squad.sort_custom(func(a, b): return Pos.DISPLAY_ORDER.find(a.position) < Pos.DISPLAY_ORDER.find(b.position) or (a.position == b.position and a.ovr_f > b.ovr_f))
	var card := UIKit.card("Card", 4)
	card.add_child(UIKit.section("%d convocados" % squad.size()))
	for p: Player in squad:
		var h := UIKit.hbox(10)
		h.add_child(UIKit.pos_badge(p.position))
		var cl: Club = w.club(p.club_id) if p.club_id >= 0 else null
		h.add_child(UIKit.crest(cl, 30))
		var v := UIKit.vbox(0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var n := UIKit.label(p.display_name(), "H3")
		n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		if w.has_user() and p.club_id == w.user_club_id:
			n.add_theme_color_override(&"font_color", UIColors.ACCENT)
		v.add_child(n)
		var caps := NationalTeamManager.caps_of(w, p.id)
		v.add_child(UIKit.label("%s · %d anos · %d jogos · %d gols · %d assist." % [cl.short_name if cl != null else "sem clube", p.age(w.year), caps[0], caps[1], caps[2]], "Small"))
		h.add_child(v)
		h.add_child(UIKit.badge(p.overall, 52, 36, 22))
		var pid := p.id
		card.add_child(UIKit.tap_row(h, func(): UIManager.push("player", {"id": pid}), "CardFlat"))
	c.add_child(UIKit.card_panel(card))


func _choice(c: VBoxContainer, title: String, names: Array, selected: int, action: Callable) -> void:
	c.add_child(UIKit.label(title,"H3"))
	var options := OptionButton.new()
	options.custom_minimum_size.y = 54
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for text in names: options.add_item(String(text))
	options.select(clampi(selected,0,maxi(0,names.size()-1)))
	options.item_selected.connect(action)
	c.add_child(options)

func _message(error: String, success: String) -> void:
	UIManager.toast(success if error == "" else error)
	refresh()

func _command(w: GameWorld, c: VBoxContainer) -> void:
	var data := InternationalCareer.data(w)
	var managed := InternationalCareer.nation(w)
	var box := UIKit.card("Card",10)
	if managed == "":
		box.add_child(UIKit.label("Carreira de seleções","H2"))
		box.add_child(UIKit.label("Acumule o comando de uma seleção com o clube. A federação avalia sua reputação antes de oferecer o cargo.","",true))
		var codes := DatabaseManager.nations().keys()
		codes.sort()
		_choice(box,"Federação",codes.map(func(code): return DatabaseManager.nation_name(code)),codes.find(_nation),func(i):
			_nation = codes[i]; refresh())
		box.add_child(UIKit.kv("Sua reputação / exigência","%.0f / %.0f" % [InternationalCareer.reputation(w),InternationalCareer.requirement(_nation)]))
		box.add_child(UIKit.button("Candidatar-se ao comando","Primary",func():
			_message(InternationalCareer.apply(w,_nation),"Cargo assumido. Prepare a convocação.")))
		c.add_child(UIKit.card_panel(box))
		return
	box.add_child(UIKit.label("Técnico de "+DatabaseManager.nation_name(managed),"H2"))
	box.add_child(UIKit.kv("Confiança da federação","%.0f/100" % float(data["trust"])))
	box.add_child(UIKit.label("A escalação e o plano definidos aqui serão usados nas partidas da seleção. Os jogos são simulados; este painel não é uma transmissão ao vivo.","Muted",true))
	box.add_child(UIKit.button("Encerrar vínculo","",func(): UIManager.confirm("Deixar a seleção?","Seu clube continua sob seu comando.","Confirmar",func():
		InternationalCareer.resign(w); refresh())))
	c.add_child(UIKit.card_panel(box))
	var plan := InternationalCareer.plan(w,managed)
	var tactics := UIKit.card("Card",8)
	tactics.add_child(UIKit.label("Plano e titulares preferidos","H2"))
	var formations := DatabaseManager.formation_names()
	_choice(tactics,"Formação",formations,formations.find(plan["formation"]),func(i):
		InternationalCareer.set_plan(w,"formation",formations[i]); refresh())
	var db := DatabaseManager.tactics()
	for pair in [["style","Estilo","styles"],["mentality","Mentalidade","mentalities"],["pressing","Pressão","pressing"],["line","Linha defensiva","line"],["passing","Passe","passing"]]:
		var key: String = pair[0]
		_choice(tactics,pair[1],Array(db[pair[2]]).map(func(x): return x["name"]),int(plan[key]),func(i):
			InternationalCareer.set_plan(w,key,i))
	tactics.add_child(UIKit.label("Entrosamento: %.0f/100. Mudar o plano tem custo de adaptação." % float(plan["cohesion"]),"Small",true))
	c.add_child(UIKit.card_panel(tactics))
	var roster := UIKit.card("Card",6)
	var is_locked := InternationalCareer.locked(w)
	roster.add_child(UIKit.label("Convocação: %d/26%s" % [data["roster"].size()," · anunciada" if is_locked else ""],"H2"))
	roster.add_child(UIKit.label("Três goleiros; cobertura mínima de defesa, meio e ataque. Marque até 11 titulares preferidos. Vagas sem preferência são preenchidas pelo encaixe na formação.","Small",true))
	if not is_locked:
		roster.add_child(UIKit.button("Sugerir lista por forma e condição","",func():
			data["roster"] = InternationalCareer.auto_roster(InternationalCareer.eligible(w,managed),w.year)
			plan["xi"] = []; refresh()))
		roster.add_child(UIKit.button("Anunciar convocação","Primary",func(): _message(InternationalCareer.publish(w),"Convocação anunciada.")))
	for pid in data["roster"]:
		var p := w.player(int(pid))
		if p == null: continue
		var row := UIKit.hbox(8)
		var text := UIKit.label("%s · %s · %d · cond. %.0f" % [p.display_name(),Pos.CODES[p.position],p.overall,p.condition],"",true)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		row.add_child(UIKit.button("XI ✓" if Array(plan["xi"]).has(p.id) else "+ XI","",func(): _message(InternationalCareer.toggle_starter(w,p.id),"Preferência atualizada.")))
		if not is_locked: row.add_child(UIKit.button("Retirar","",func(): _message(InternationalCareer.toggle(w,p.id),"Lista atualizada.")))
		roster.add_child(row)
	c.add_child(UIKit.card_panel(roster))
	if not is_locked:
		var candidates := UIKit.card("Card",6)
		candidates.add_child(UIKit.label("Observação de jogadores","H2"))
		var search := LineEdit.new()
		search.placeholder_text = "Nome do jogador e Enter para buscar"
		search.text = _candidate_query
		search.text_submitted.connect(func(text): _candidate_query = text; _candidate_page = 0; refresh())
		candidates.add_child(search)
		_choice(candidates,"Setor",["Todos","Goleiros","Defensores","Meias","Atacantes"],_candidate_group+1,func(i):
			_candidate_group = i-1; _candidate_page = 0; refresh())
		var pool := InternationalCareer.eligible(w,managed).filter(func(p):
			return not Array(data["roster"]).has(p.id) and (_candidate_group < 0 or Pos.group(p.position)==_candidate_group) and (_candidate_query=="" or p.display_name().to_lower().contains(_candidate_query.to_lower())))
		_candidate_page = clampi(_candidate_page,0,maxi(0,(pool.size()-1)/32))
		for p: Player in pool.slice(_candidate_page*32,(_candidate_page+1)*32):
			candidates.add_child(UIKit.button("Convocar: %s · %s · %d · forma %.1f" % [p.display_name(),Pos.CODES[p.position],p.overall,p.form()],"",func():
				_message(InternationalCareer.toggle(w,p.id),"Lista atualizada.")))
		var pages := UIKit.hbox(8)
		if _candidate_page>0: pages.add_child(UIKit.button("Anterior","",func(): _candidate_page-=1; refresh()))
		if (_candidate_page+1)*32<pool.size(): pages.add_child(UIKit.button("Próxima","",func(): _candidate_page+=1; refresh()))
		candidates.add_child(pages)
		c.add_child(UIKit.card_panel(candidates))
	var results := UIKit.card("Card",6)
	results.add_child(UIKit.label("Últimos compromissos","H2"))
	for r in Array(data["results"]).slice(maxi(0,data["results"].size()-8)):
		results.add_child(UIKit.label("%s · %s %d x %d %s" % [r["date"],r["a"],r["ga"],r["gb"],r["b"]],"",true))
		if Array(r.get("xg",[])).size()==2: results.add_child(UIKit.label("xG: %.2f x %.2f" % [float(r["xg"][0]),float(r["xg"][1])],"Small"))
	c.add_child(UIKit.card_panel(results))

func _calendar(w: GameWorld, c: VBoxContainer) -> void:
	var now := InternationalCalendar.season_date(w)
	var box := UIKit.card("Card",10)
	box.add_child(UIKit.label("Calendário de seleções","H2"))
	box.add_child(UIKit.label("Datas de 2026 a 2030 seguem as janelas masculinas publicadas pela FIFA. Após 2030, o jogo usa uma projeção. Formatos das eliminatórias permanecem uma adaptação do jogo.","Small",true))
	for win in InternationalCalendar.upcoming(now).slice(0,5):
		box.add_child(UIKit.label("%s a %s · até %d jogos%s" % [win["start"],win["end"],win["max_matches"]," · projeção" if win["projected"] else ""],"H3",true))
		box.add_child(UIKit.label("Convocação: a partir de "+InternationalCalendar.iso(int(win["a"])-14*86400),"Small"))
	c.add_child(UIKit.card_panel(box))
	var history := UIKit.card("Card",8)
	history.add_child(UIKit.label("Convocações anunciadas","H2"))
	for item in InternationalCareer.data(w)["announcements"]:
		history.add_child(UIKit.label("%s · %s · %d jogadores" % [item["window"],DatabaseManager.nation_name(item["nation"]),item["players"].size()],"",true))
	c.add_child(UIKit.card_panel(history))

func _kits(c: VBoxContainer) -> void:
	var box := UIKit.card("Card",10)
	box.add_child(UIKit.label("Uniformes de "+DatabaseManager.nation_name(_nation),"H2",true))
	box.add_child(UIKit.label("Desenhos próprios inspirados nas cores nacionais, sem reproduzir modelos comerciais licenciados.","Small",true))
	for entry in [["home","Titular"],["away","Reserva"],["gk","Goleiro"]]:
		box.add_child(UIKit.label(entry[1],"H3"))
		box.add_child(UIKit.kit(InternationalCareer.kit(_nation,entry[0]),180))
	c.add_child(UIKit.card_panel(box))
