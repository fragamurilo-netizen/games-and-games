extends BaseScreen
## Clube: identidade, diretoria e torcida, finanças, estrutura, história e ídolos.
## Com {"id": x} mostra outro clube (sem as opções de gestão).

const INVEST_POINTS := 5

var _club_id := -1


func _init() -> void:
	nav_tab = "club"
	screen_title = "Clube"


func setup(p: Dictionary) -> void:
	super.setup(p)
	_club_id = int(p.get("id", -1))


func _own() -> bool:
	return _club_id < 0 or world().is_user_club(_club_id)


func refresh() -> void:
	var w := world()
	if w == null:
		return
	var club := w.user_club() if _own() else w.club(_club_id)
	if not _own():
		nav_tab = ""
		show_nav = false
	screen_title = club.short_name
	screen_subtitle = "%s · %s" % [w.league_name(club.league_id), club.city]
	UIManager.refresh_chrome()
	var c := content()
	UIKit.clear(c)
	c.add_child(_identity_card(w, club))
	c.add_child(_dna_card(w, club))
	if _own():
		c.add_child(_board_card(w, club))
		c.add_child(_finance_card(w, club))
		c.add_child(_structure_card(w, club))
	else:
		c.add_child(_season_card(w, club))
		c.add_child(_squad_card(w, club))
	c.add_child(_history_card(w, club))
	var idols := _idols_card(w, club)
	if idols != null:
		c.add_child(idols)
	if _own():
		c.add_child(_manager_card(w))
		c.add_child(_career_card(w))


func _identity_card(w: GameWorld, club: Club) -> Control:
	var card := UIKit.card("Card", 12)
	var row := UIKit.hbox(16)
	row.add_child(UIKit.crest(club, 128))
	var col := UIKit.vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UIKit.label(club.name, "Title", true))
	if club.nickname != "":
		col.add_child(UIKit.label("\"%s\"" % club.nickname, "Accent"))
	var place := UIKit.hbox(8)
	place.add_child(UIKit.flag(club.nation, 30))
	place.add_child(UIKit.label("%s, %s · fundado em %d" % [club.city, DatabaseManager.nation_name(club.nation), club.founded], "Small", true))
	col.add_child(place)
	var stars := StarsView.new()
	stars.star_size = 22.0
	stars.stars = clampf(club.reputation / 20.0, 0.5, 5.0)
	col.add_child(stars)
	var rpos := ClubRanking.world_position(w, club.id)
	if rpos > 0:
		var rk := UIKit.label("%dº no ranking mundial" % rpos, "Small")
		col.add_child(UIKit.tap_row(rk, func(): UIManager.goto("table", {"rank": ""}), "CardFlat"))
	row.add_child(col)
	card.add_child(row)
	var arch := club.arch()
	var tags := UIKit.flow(8)
	tags.add_child(UIKit.pill(String(arch.get("tag", "")).to_upper(), UIColors.ACCENT, 16))
	tags.add_child(UIKit.pill("FINANÇAS: " + FinanceManager.health_label(w, club).to_upper(), _health_color(FinanceManager.health_label(w, club)), 16))
	card.add_child(tags)
	if arch.has("desc"):
		card.add_child(UIKit.label(String(arch["desc"]), "Small", true))
	var kits := UIKit.hbox(12)
	for k in [[club.kit_home, "Titular"], [club.kit_away, "Reserva"], [club.third_kit(), "Terceiro"], [club.gk_kit(), "Goleiro"]]:
		var v := UIKit.vbox(2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var kv := UIKit.kit(k[0], 72, 0, club.crest)
		kv.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(kv)
		var l := UIKit.label(k[1], "Small")
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
		kits.add_child(v)
	var st := UIKit.vbox(2)
	st.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	st.add_child(UIKit.label(club.stadium, "H3", true))
	st.add_child(UIKit.label("%s lugares" % Fmt.thousands(club.capacity), "Small"))
	st.add_child(UIKit.label("Ingresso: %s" % Fmt.money(FinanceManager.ticket_price(club)), "Small"))
	kits.add_child(st)
	card.add_child(kits)
	if _own():
		var pre := SponsorManager.is_preseason(w)
		card.add_child(UIKit.button("Uniformes e patrocínios" + (" (pré-temporada)" if pre else ""), "PrimaryButton" if pre else "GhostButton", func(): UIManager.push("kit"), "shirt"))
	var cid := club.id
	card.add_child(UIKit.button("Elencos anteriores", "GhostButton", func(): UIManager.push("past_squads", {"id": cid}), "clock"))
	card.add_child(UIKit.button("Revelados pela base", "GhostButton", func(): UIManager.push("graduates", {"id": cid}), "up"))
	if _own():
		card.add_child(UIKit.button("Apresentação do clube", "GhostButton", func(): UIManager.push("welcome"), "info"))
	var pol := ClubPolicy.of(club)
	if not pol.is_empty():
		card.add_child(UIKit.section("Filosofia"))
		var prow := UIKit.hbox(10)
		prow.add_child(UIKit.icon_rect("star" if pol.has("only") else "info", 30, UIColors.ACCENT))
		var pc := UIKit.vbox(0)
		pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pc.add_child(UIKit.label(String(pol.get("name", "")), "H3"))
		pc.add_child(UIKit.label(String(pol.get("desc", "")), "Small", true))
		prow.add_child(pc)
		card.add_child(prow)
	# Rivais de origem e rivalidades que nasceram no save, da mais quente para a mais fria
	var rivals := Rivalry.of_club(w, club.id).slice(0, 4)
	if not rivals.is_empty():
		card.add_child(UIKit.section("Rivais"))
		for e: Dictionary in rivals:
			card.add_child(RivalryView.club_row(w, club.id, e))
	return HeroBackdrop.attach(UIKit.card_panel(card), club, 0.1)


## DNA: o que o clube é (filosofia, mercado, escola, números) e as viradas da sua história.
func _dna_card(w: GameWorld, club: Club) -> Control:
	var d := ClubDNA.of(club)
	var card := UIKit.card("Card", 10)
	card.add_child(UIKit.section("DNA do clube"))
	var era_id := ClubDNA.era(club)
	var era_row := UIKit.flow(8)
	era_row.add_child(UIKit.pill(ClubDNA.name_of("eras", era_id).to_upper(), _era_color(era_id), 16))
	era_row.add_child(UIKit.label("desde %d" % int(d.get("since", w.year)), "Small"))
	card.add_child(era_row)
	card.add_child(UIKit.label(String(ClubDNA.info("eras", era_id).get("desc", "")), "Small", true))
	for item in [["rec", "Filosofia de elenco", ClubDNA.rec(club)], ["mkt", "Alcance do mercado", ClubDNA.mkt(club)], ["tac", "Escola tática", ClubDNA.tac(club)]]:
		card.add_child(UIKit.kv(item[1], ClubDNA.name_of(item[0], item[2])))
		card.add_child(UIKit.label(String(ClubDNA.info(item[0], item[2]).get("desc", "")), "Small", true))
	for k in ClubDNA.PARAMS:
		var v := ClubDNA.val(club, k)
		var head := UIKit.hbox(8)
		var l := UIKit.label(ClubDNA.name_of("params", k), "Muted")
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(l)
		head.add_child(UIKit.label("%d" % int(round(v)), "H3"))
		card.add_child(head)
		card.add_child(UIKit.bar(v, 100.0, UIColors.BLUE, 8))
	var lg: Array = d.get("log", [])
	card.add_child(UIKit.section("Linha do tempo"))
	if lg.is_empty():
		card.add_child(UIKit.label("Nenhuma virada ainda. A história do clube começa agora.", "Muted", true))
	for i in range(lg.size() - 1, maxi(-1, lg.size() - 7), -1):
		var e: Dictionary = lg[i]
		var row := UIKit.hbox(10)
		row.add_child(UIKit.label(str(int(e.get("y", 0))), "H3"))
		var t := UIKit.label(String(e.get("t", "")), "Small", true)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(t)
		card.add_child(row)
	return UIKit.card_panel(card)


static func _era_color(e: String) -> Color:
	match e:
		"potencia", "crescendo":
			return UIColors.GREEN
		"crise", "decadencia":
			return UIColors.RED
		"fabrica":
			return UIColors.BLUE
		"novo_rico":
			return UIColors.GOLD
	return UIColors.MUTED


func _open_club(cid: int) -> void:
	if world().is_user_club(cid):
		UIManager.goto("club")
	else:
		UIManager.push("club", {"id": cid})


static func _health_color(label_text: String) -> Color:
	match label_text:
		"Crise":
			return UIColors.RED
		"Endividado":
			return UIColors.ORANGE
		"Apertado":
			return UIColors.ACCENT
	return UIColors.GREEN


func _board_card(w: GameWorld, club: Club) -> Control:
	var card := UIKit.card("Card", 10)
	card.add_child(UIKit.section("Diretoria e torcida"))
	var goal := SeasonManager.goal_of(w, club.id)
	card.add_child(UIKit.kv("Meta da temporada", String(goal[0])))
	var conf := club.board_confidence
	var row := UIKit.hbox(10)
	row.add_child(UIKit.label("Confiança", "Muted"))
	row.add_child(UIKit.spacer())
	row.add_child(UIKit.colored(BoardManager.label(conf), BoardManager.color(conf), "H3"))
	card.add_child(row)
	card.add_child(UIKit.bar(conf, 100.0, BoardManager.color(conf), 12))
	if conf < BoardManager.ULTIMATUM:
		card.add_child(UIKit.colored("Ultimato: sem reação, a diretoria pode trocar o treinador a qualquer momento.", UIColors.RED, "Small"))
	var frow := UIKit.hbox(10)
	frow.add_child(UIKit.label("Torcida", "Muted"))
	frow.add_child(UIKit.spacer())
	frow.add_child(UIKit.colored(UIColors.fans_label(club.fan_mood), UIColors.morale_color(club.fan_mood), "H3"))
	card.add_child(frow)
	card.add_child(UIKit.bar(club.fan_mood, 100.0, UIColors.morale_color(club.fan_mood), 12))
	var pr := People.president(w, club.id)
	card.add_child(UIKit.kv("Presidente", "%s (%s)" % [String(pr["n"]), String(People.pres_style(w, club.id)["name"]).to_lower()]))
	card.add_child(UIKit.button("Relações: presidente, comissão, torcida e imprensa", "GhostButton", func(): UIManager.push("relations", {"tab": "board"}), "heart"))
	return UIKit.card_panel(card)


func _finance_card(w: GameWorld, club: Club) -> Control:
	var fin := FinanceManager.summary(w, club)
	var card := UIKit.card("Card", 8)
	card.add_child(UIKit.section("Finanças"))
	var row := UIKit.hbox(8)
	row.add_child(UIKit.stat(Fmt.money(fin["balance"]), "em caixa", UIColors.RED if int(fin["balance"]) < 0 else UIColors.TEXT))
	row.add_child(UIKit.stat(Fmt.money(fin["transfer_budget"]), "p/ contratar", UIColors.ACCENT))
	row.add_child(UIKit.stat(Fmt.money(fin["expected_revenue"]), "receita/ano"))
	card.add_child(row)
	var over: bool = fin["wage_bill"] > fin["wage_budget"]
	card.add_child(UIKit.kv("Folha salarial (mês)", "%s / %s" % [Fmt.money(fin["wage_bill"]), Fmt.money(fin["wage_budget"])], UIColors.RED if over else UIColors.TEXT))
	var share := float(fin["wage_bill"]) * 12.0 / maxf(1.0, float(fin["expected_revenue"]))
	card.add_child(UIKit.kv("Folha consome da receita", "%d%%" % int(round(share * 100.0)), UIColors.RED if share > 0.85 else (UIColors.ORANGE if share > 0.7 else UIColors.TEXT)))
	var proj := FinanceManager.projected_balance(w, club)
	card.add_child(UIKit.kv("Caixa previsto no fim da temporada", Fmt.money(proj), UIColors.RED if proj < 0 else UIColors.TEXT))
	var deal := FinanceManager.tv_deal(w, club.league_id)
	card.add_child(UIKit.kv("Cota de TV (ano)", "%s%s" % [Fmt.money(club.income_tv), "" if absf(deal - 1.0) < 0.01 else " · contrato %s%d%%" % ["+" if deal > 1.0 else "−", int(round(absf(deal - 1.0) * 100.0))]]))
	var own := WorldEvents.owner_of(w, club.id)
	if not own.is_empty():
		card.add_child(UIKit.kv("Dono", "%s (desde %d)" % [own.get("who", ""), int(own.get("y", 0))]))
	if club.balance < 0:
		card.add_child(UIKit.colored("Com o caixa no vermelho, a diretoria não libera contratações e paga juros sobre a dívida.", UIColors.ORANGE, "Small", true))
	card.add_child(UIKit.separator())
	card.add_child(UIKit.label("Temporada %d" % w.year, "Caps"))
	var any := false
	for k in FinanceManager.INCOME_CATS:
		var v := int(club.ledger.get(k, 0))
		if v != 0:
			any = true
			card.add_child(UIKit.kv(FinanceManager.CAT_NAMES[k], "+" + Fmt.money(v), UIColors.GREEN))
	for k in FinanceManager.EXPENSE_CATS:
		var v := int(club.ledger.get(k, 0))
		if v != 0:
			any = true
			card.add_child(UIKit.kv(FinanceManager.CAT_NAMES[k], "−" + Fmt.money(absi(v)), UIColors.RED))
	if not any:
		card.add_child(UIKit.label("Nenhuma movimentação ainda nesta temporada.", "Muted"))
	else:
		var net: int = int(fin["income"]) - int(fin["expense"])
		card.add_child(UIKit.kv("Resultado", ("+" if net >= 0 else "−") + Fmt.money(absi(net)), UIColors.GREEN if net >= 0 else UIColors.RED))
	_sponsor_lines(w, club, card)
	return UIKit.card_panel(card)


## Contratos de patrocínio e material esportivo que compõem a receita de patrocínio.
func _sponsor_lines(w: GameWorld, club: Club, card: VBoxContainer) -> void:
	card.add_child(UIKit.separator())
	card.add_child(UIKit.label("Patrocínios (por ano)", "Caps"))
	var total := 0
	for b: Dictionary in SponsorManager.breakdown(club):
		var cap := String(b["name"])
		if String(b["slot"]) != "":
			cap += " · %s até %d" % [String(b["slot"]).to_lower(), int(b["y"])]
		var val := "+" + Fmt.money(int(b["v"]))
		if int(b["e"]) > 0:
			val += " (+%s bônus)" % Fmt.money(int(b["e"]))
		card.add_child(UIKit.kv(cap, val, UIColors.GREEN))
		total += int(b["v"]) + int(b["e"])
	card.add_child(UIKit.kv("Total de patrocínio", Fmt.money(total), UIColors.GREEN))
	if club.sponsors.size() < SponsorManager.SLOTS.size():
		var hint := "Espaços livres no uniforme: feche contratos na pré-temporada." if SponsorManager.is_preseason(w) else "Espaços livres no uniforme podem ser vendidos na próxima pré-temporada."
		card.add_child(UIKit.button(hint, "GhostButton", func(): UIManager.push("kit"), "money"))


func _structure_card(w: GameWorld, club: Club) -> Control:
	var card := UIKit.card("Card", 10)
	card.add_child(UIKit.section("Estrutura"))
	for item in [["facilities", "Centro de treinamento", club.facilities, "Acelera a evolução de todo o elenco."], ["youth", "Categorias de base", club.youth_level, "Revela mais jovens, e melhores, a cada temporada."]]:
		var kind: String = item[0]
		var level: int = item[2]
		var head := UIKit.hbox(8)
		head.add_child(UIKit.label(item[1], "H3"))
		head.add_child(UIKit.spacer())
		head.add_child(UIKit.label("%d/100" % level, "H3"))
		card.add_child(head)
		card.add_child(UIKit.bar(level, 100.0, UIColors.BLUE, 10))
		card.add_child(UIKit.label(item[3], "Small", true))
		var cost := 0
		for i in INVEST_POINTS:
			cost += FinanceManager.upgrade_cost(club, level + i)
		var b := UIKit.button("Investir +%d (%s)" % [INVEST_POINTS, Fmt.money(cost)], "GhostButton", func(): _invest(kind), "up")
		b.disabled = level >= 99 or cost > club.balance
		card.add_child(b)
	card.add_child(UIKit.label("Investimentos saem do caixa do clube. A estrutura se desgasta um pouco a cada ano.", "Small", true))
	return UIKit.card_panel(card)


func _invest(kind: String) -> void:
	var w := world()
	var club := w.user_club()
	var level := club.facilities if kind == "facilities" else club.youth_level
	var cost := 0
	for i in INVEST_POINTS:
		cost += FinanceManager.upgrade_cost(club, level + i)
	UIManager.confirm("Confirmar investimento?", "Custo: %s. Caixa atual: %s." % [Fmt.money(cost), Fmt.money(club.balance)], "Investir", func():
		var paid := FinanceManager.invest(club, kind, INVEST_POINTS)
		if paid <= 0:
			UIManager.toast("Dinheiro insuficiente em caixa.", UIColors.RED)
			return
		AudioManager.play("sign", -6.0)
		UIManager.toast("Investimento feito: %s." % Fmt.money(paid), UIColors.GREEN)
		GameManager.save_now()
		refresh())


func _season_card(w: GameWorld, club: Club) -> Control:
	var league := w.league_of(club.id)
	var card := UIKit.card("Card", 8)
	card.add_child(UIKit.section("Temporada %d" % w.year))
	var row := UIKit.hbox(8)
	var r: Dictionary = league.table[club.id]
	var pos := CompetitionManager.position_of(league, club.id)
	row.add_child(UIKit.stat(("%dº" % pos) if int(r["pl"]) > 0 else "—", "posição"))
	row.add_child(UIKit.stat(str(r["pts"]), "pontos"))
	row.add_child(UIKit.stat("%d-%d-%d" % [r["w"], r["d"], r["l"]], "V-E-D"))
	card.add_child(row)
	var fd := FormDots.new()
	fd.dot = 18
	fd.form = r["form"]
	card.add_child(fd)
	var goal := SeasonManager.goal_of(w, club.id)
	card.add_child(UIKit.kv("Meta da diretoria", String(goal[0])))
	var co := People.coach_of(w, club.id)
	if not co.is_empty():
		card.add_child(UIKit.kv("Técnico", "%s (%s)" % [String(co["n"]), People.style_name(String(co["st"])).to_lower()]))
		var rel := People.coach_rel(w, int(co["id"]))
		if absf(rel) >= 12.0:
			card.add_child(UIKit.kv("Relação com você", People.coach_rel_label(rel), UIColors.GREEN if rel > 0 else UIColors.RED))
	card.add_child(UIKit.kv("Presidente", String(People.president(w, club.id)["n"])))
	if club.sheet != null:
		var tac := DatabaseManager.tactics()
		card.add_child(UIKit.kv("Jeito de jogar", "%s · %s" % [club.sheet.formation, String(tac["styles"][club.sheet.style]["name"])]))
	return UIKit.card_panel(card)


func _squad_card(w: GameWorld, club: Club) -> Control:
	var card := UIKit.card("Card", 6)
	var squad := w.squad(club)
	var total := 0
	for p in squad:
		total += p.value
	card.add_child(UIKit.section("Elenco · %d jogadores · %s" % [squad.size(), Fmt.money(total)]))
	squad.sort_custom(func(a, b):
		var ia := Pos.DISPLAY_ORDER.find(a.position)
		var ib := Pos.DISPLAY_ORDER.find(b.position)
		if ia != ib:
			return ia < ib
		return a.ovr_f > b.ovr_f)
	for p: Player in squad:
		var pid := p.id
		card.add_child(PlayerRowView.make(w, p, {"mode": "market"}, func(): UIManager.push("player", {"id": pid})))
	return UIKit.card_panel(card)


func _history_card(w: GameWorld, club: Club) -> Control:
	var card := UIKit.card("Card", 6)
	card.add_child(UIKit.section("Títulos e história"))
	var any_title := false
	for k in club.titles:
		if club.title_count(k) > 0:
			any_title = true
	if any_title:
		card.add_child(TrophyView.cabinet(w, club, 64))
	else:
		card.add_child(UIKit.label("Nenhum título registrado desde %d. Ainda." % DatabaseManager.start_year(), "Muted"))
	if club.history.is_empty():
		card.add_child(UIKit.label("A primeira temporada deste save está em andamento.", "Small"))
		return UIKit.card_panel(card)
	var best: Dictionary = {}
	for h in club.history:
		var tier := int(DatabaseManager.league_cfg(String(h["l"])).get("tier", 9))
		var btier := int(DatabaseManager.league_cfg(String(best.get("l", ""))).get("tier", 9)) if not best.is_empty() else 99
		if best.is_empty() or tier < btier or (tier == btier and int(h["p"]) < int(best["p"])):
			best = h
	card.add_child(UIKit.kv("Melhor campanha", "%dº na %s (%d)" % [int(best["p"]), w.league_short(String(best["l"])), int(best["y"])]))
	card.add_child(UIKit.label("Últimas temporadas", "Caps"))
	var list: Array = club.history.duplicate()
	list.reverse()
	for i in mini(10, list.size()):
		var h: Dictionary = list[i]
		var row := UIKit.hbox(10)
		var yl := UIKit.label(str(h["y"]), "Mono")
		yl.custom_minimum_size.x = 72
		row.add_child(yl)
		var dl := UIKit.label(w.league_short(String(h["l"])), "Small")
		dl.custom_minimum_size.x = 120
		row.add_child(dl)
		var pl := UIKit.label("%dº" % int(h["p"]), "H3")
		pl.custom_minimum_size.x = 56
		if int(h["p"]) == 1:
			pl.add_theme_color_override(&"font_color", UIColors.ACCENT)
		row.add_child(pl)
		var rl := UIKit.label("%d pts · %dV %dE %dD · %d:%d" % [int(h["pts"]), int(h["w"]), int(h["dr"]), int(h["lo"]), int(h["gf"]), int(h["ga"])], "Small")
		rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(rl)
		card.add_child(row)
	return UIKit.card_panel(card)


## Ordem dos títulos: mundial, continentais, ligas, acessos.
static func _title_rank(k: String) -> int:
	match k.substr(0, 2):
		"W:":
			return 0
		"C:":
			return 1
		"D:":
			return 7
		"S:":
			return 8
		"U:":
			return 9
		"L:":
			return 2 + int(DatabaseManager.league_cfg(k.substr(2)).get("tier", 1))
	return 10


static func _title_text(w: GameWorld, k: String, n: int) -> String:
	var id := k.substr(2)
	match k.substr(0, 2):
		"W:", "C:", "S:", "D:", "U:":
			return "%dx %s" % [n, CupManager.cup_name(id)]
		"L:":
			return "%dx campeão %s" % [n, w.league_short(id)]
		"P:":
			return "%dx acesso da %s" % [n, w.league_short(id)]
		"Y:":
			return "%dx campeão %s Sub-20" % [n, w.league_short(id)]
		"Z:":
			return "%dx campeão %s Sub-17" % [n, w.league_short(id)]
	return "%dx %s" % [n, k]


static func _title_color(k: String) -> Color:
	match k.substr(0, 2):
		"W:", "C:", "S:", "D:", "U:":
			return UIColors.ACCENT
		"L:":
			return UIColors.ACCENT
	return UIColors.GREEN


## Ídolos: aposentados que marcaram o clube (Hall da Fama do save).
func _idols_card(w: GameWorld, club: Club) -> Control:
	var idols: Array = []
	for r in w.retired:
		var apps := 0
		var goals := 0
		for s in r.get("spells", []):
			if int(s.get("c", -1)) == club.id:
				apps += int(s.get("a", 0))
				goals += int(s.get("g", 0))
		if apps >= 60 or (apps >= 30 and goals >= 20):
			idols.append([apps + goals * 2, r, apps, goals])
	if idols.is_empty():
		return null
	idols.sort_custom(func(a, b): return a[0] > b[0])
	var card := UIKit.card("Card", 6)
	card.add_child(UIKit.section("Hall da fama"))
	for i in mini(8, idols.size()):
		var r: Dictionary = idols[i][1]
		var row := UIKit.hbox(10)
		row.add_child(UIKit.pos_badge(int(r.get("pos", 0))))
		var col := UIKit.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UIKit.label(String(r.get("ka", r.get("name", ""))), "H3"))
		col.add_child(UIKit.label("%d jogos, %d gols pelo clube · aposentou-se em %d" % [idols[i][2], idols[i][3], int(r.get("year", 0))], "Small", true))
		row.add_child(col)
		card.add_child(row)
	return UIKit.card_panel(card)


func _manager_card(w: GameWorld) -> Control:
	var s := w.manager_stats
	var card := UIKit.card("Card", 8)
	card.add_child(UIKit.section("Treinador"))
	var head := UIKit.hbox(14)
	head.add_child(ManagerProfile.portrait(w, 96))
	var hc := UIKit.vbox(2)
	hc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hc.add_child(UIKit.label(w.manager_name, "H3", true))
	var m := ManagerProfile.data(w)
	var nr := UIKit.hbox(8)
	nr.add_child(UIKit.flag(String(m["nat"]), 30))
	nr.add_child(UIKit.label("%d anos · %s" % [ManagerProfile.age(w), ManagerProfile.style_name(String(m["style"]))], "Small", true))
	hc.add_child(nr)
	var fame := CoachIdentity.headline(w)
	if fame != "":
		var fp := UIKit.pill(fame.to_upper(), UIColors.ACCENT, 14)
		fp.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		hc.add_child(fp)
	head.add_child(hc)
	card.add_child(UIKit.tap_row(head, func(): UIManager.push("manager"), "CardFlat"))
	var row := UIKit.hbox(8)
	row.add_child(UIKit.stat(str(int(s.get("games", 0))), "jogos"))
	row.add_child(UIKit.stat("%d-%d-%d" % [int(s.get("w", 0)), int(s.get("d", 0)), int(s.get("l", 0))], "V-E-D"))
	row.add_child(UIKit.stat(str(int(s.get("titles", 0))), "títulos", UIColors.ACCENT))
	row.add_child(UIKit.stat(str(int(s.get("promotions", 0))), "acessos", UIColors.GREEN))
	card.add_child(row)
	card.add_child(UIKit.label("Dificuldade: %s · temporada nº %d" % [GameWorld.DIFF_NAMES[w.difficulty], w.season_number], "Small"))
	card.add_child(UIKit.button("Personalizar o treinador", "GhostButton", func(): UIManager.push("manager"), "star"))
	return UIKit.card_panel(card)


func _career_card(w: GameWorld) -> Control:
	var card := UIKit.card("Card", 10)
	card.add_child(UIKit.section("Carreira · espaço %d" % GameManager.slot))
	card.add_child(UIKit.button("Salvar agora", "", func():
		if GameManager.save_now():
			UIManager.toast("Jogo salvo.", UIColors.GREEN)
		else:
			UIManager.toast("Não foi possível salvar agora.", UIColors.RED), "save"))
	card.add_child(UIKit.button("Salvar cópia em outro espaço", "GhostButton", _save_copy, "plus"))
	card.add_child(UIKit.button("Configurações", "GhostButton", func(): UIManager.push("settings"), "gear"))
	card.add_child(UIKit.button("Sair para o menu", "GhostButton", func():
		UIManager.confirm("Sair para o menu?", "Seu progresso é salvo automaticamente.", "Sair", func():
			GameManager.close_career()
			UIManager.goto("menu")), "back"))
	return UIKit.card_panel(card)


func _save_copy() -> void:
	var v := UIKit.vbox(10)
	v.custom_minimum_size.x = 600
	v.add_child(UIKit.label("Salvar cópia", "Title"))
	v.add_child(UIKit.label("A carreira continua no espaço atual; a cópia fica guardada no espaço escolhido.", "Small", true))
	for s in range(1, SaveManager.SLOTS + 1):
		if s == GameManager.slot:
			continue
		var meta := SaveManager.read_meta(s)
		var txt := "Espaço %d · vazio" % s if meta.is_empty() else "Espaço %d · %s, %d" % [s, meta.get("short", "?"), int(meta.get("year", 0))]
		var slot := s
		v.add_child(UIKit.button(txt, "", func():
			var do_save := func():
				UIManager.close_all_modals()
				if GameManager.save_copy(slot):
					UIManager.toast("Cópia salva no espaço %d." % slot, UIColors.GREEN)
				else:
					UIManager.toast("Falha ao salvar a cópia.", UIColors.RED)
			if meta.is_empty():
				do_save.call()
			else:
				UIManager.confirm("Sobrescrever espaço %d?" % slot, "O save que está lá será substituído.", "Sobrescrever", do_save)))
	v.add_child(UIKit.button("Cancelar", "GhostButton", func(): UIManager.close_modal()))
	UIManager.show_modal(v)
