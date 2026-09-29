extends BaseScreen
## Clube: identidade, diretoria e torcida, finanças, estrutura, história e ídolos.
## Com {"id": x} mostra outro clube (sem as opções de gestão).


var _club_id := -1
## Aba aberta: cada parte do clube numa aba, em vez de uma tela comprida.
static var _tab_own := "overview"
var _tab := "overview"


func _init() -> void:
	nav_tab = "club"
	screen_title = "Clube"


func setup(p: Dictionary) -> void:
	super.setup(p)
	_club_id = int(p.get("id", -1))
	_tab = String(p.get("tab", _tab_own if _club_id < 0 else "overview"))


func _own() -> bool:
	return _club_id < 0 or world().is_user_club(_club_id)


func refresh() -> void:
	var w := world()
	if w == null:
		return
	var club := w.user_club() if _own() else w.club(_club_id)
	if club==null:
		var missing:=content()
		UIKit.clear(missing)
		missing.add_child(UIKit.label("Clube não encontrado nesta carreira.","Muted",true))
		hide_footer()
		return
	if not _own():
		nav_tab = ""
		show_nav = false
	screen_title = club.short_name
	screen_subtitle = "%s · %s" % [w.league_name(club.league_id), club.city]
	UIManager.refresh_chrome()
	var c := content()
	UIKit.clear(c)
	var items: Array = [["overview", "Visão geral"]]
	if _own():
		items.append_array([["manage", "Gestão"], ["stats", "Estatísticas"], ["history", "História"], ["career", "Carreira"]])
	else:
		items.append_array([["squad", "Elenco"], ["stats", "Estatísticas"], ["history", "História"]])
	var keys: Array = items.map(func(it: Array) -> String: return String(it[0]))
	if not _tab in keys:
		_tab = "overview"
	c.add_child(UIKit.scroll_tabs(items, _tab, func(key: String):
		_tab = key
		if _own():
			_tab_own = key
		refresh()
		scroll_to_top()))
	var box := UIKit.vbox(UITokens.S4)
	c.add_child(box)
	var cards: Array = []
	match _tab:
		"overview":
			var ident := _identity_card(w, club)
			for ch in ident.get_children():
				ident.remove_child(ch)
				cards.append(ch)
			ident.free()
			if not _own():
				cards.append(_season_card(w, club))
			cards.append(ReputationScreen.club_card(w, club))
			cards.append(_dna_card(w, club))
			cards.append(SocialPost.mini_card(w, club.id, -1))
		"manage":
			cards.append(_finance_card(w, club))
			cards.append(_board_card(w, club))
			cards.append(_director_card(w, club))
			cards.append(_structure_card(w, club))
		"squad":
			cards.append(_squad_card(w, club))
			cards.append(_youth_card(w, club))
		"stats":
			for card in TeamStatsScreen.cards(w, club):
				cards.append(card)
		"history":
			var hid := club.id
			cards.append(UIKit.menu_group([
				UIKit.menu_row("star", "Melhor 11 de sempre e ano a ano", "", func(): UIManager.push("club_records", {"id": hid, "tab": "xi"})),
				UIKit.menu_row("swap", "Histórico de transferências", "", func(): UIManager.push("club_records", {"id": hid, "tab": "transfers"})),
			]))
			cards.append(_history_card(w, club))
			var idols := _idols_card(w, club)
			if idols != null:
				cards.append(idols)
		"career":
			cards.append(_manager_card(w))
			cards.append(UIKit.menu_group([UIKit.menu_row("swap", "Minhas transferências", "", func(): UIManager.push("club_records", {"mode": "manager"}))]))
			cards.append(_career_card(w))
	max_content_width = 1800.0
	UIKit.columns(box, cards, content_width(), 2, 1 if _tab == "overview" else 0)


func _identity_card(w: GameWorld, club: Club) -> Control:
	var out := UIKit.vbox(16)
	# Cabeçalho: escudo grande sobre o degradê do clube, nome em caixa alta e a identidade.
	var card := UIKit.card("Card", 12)
	var row := UIKit.hbox(18)
	var cr := UIKit.crest(club, 140)
	cr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(cr)
	var col := UIKit.vbox(4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if club.nickname != "":
		col.add_child(UIKit.eyebrow(club.nickname))
	var nm := UIKit.label(club.name, "Title", true)
	nm.uppercase = true
	col.add_child(nm)
	var place := UIKit.hbox(8)
	place.add_child(UIKit.flag(club.nation, 30))
	place.add_child(UIKit.label("%s, %s · fundado em %d" % [club.city, DatabaseManager.nation_name(club.nation), club.founded], "Small", true))
	col.add_child(place)
	var stars := StarsView.new()
	stars.star_size = 22.0
	stars.stars = clampf(club.reputation / 20.0, 0.5, 5.0)
	col.add_child(stars)
	row.add_child(col)
	card.add_child(row)
	var arch := club.arch()
	var tags := UIKit.flow(8)
	tags.add_child(UIKit.pill(String(arch.get("tag", "")).to_upper(), UIColors.ACCENT, 16))
	tags.add_child(UIKit.pill("FINANÇAS: " + FinanceManager.health_label(w, club).to_upper(), _health_color(FinanceManager.health_label(w, club)), 16))
	card.add_child(tags)
	out.add_child(HeroBackdrop.attach(UIKit.card_panel(card), club, 0.1))
	# Números rápidos: ranking mundial, estádio e ingresso.
	var tiles := UIKit.hbox(10)
	var rpos := ClubRanking.world_position(w, club.id)
	if rpos > 0:
		var rk := UIKit.stat_tile("%dº" % rpos, "Ranking mundial", UIColors.ACCENT)
		var rk_tap := UIKit.tap_row(rk, func(): UIManager.goto("table", {"rank": ""}), "PanelContainer")
		rk_tap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tiles.add_child(rk_tap)
	tiles.add_child(UIKit.stat_tile(Fmt.thousands(club.capacity), "Lugares"))
	tiles.add_child(UIKit.stat_tile(Fmt.money(FinanceManager.ticket_price(club)), "Ingresso"))
	out.add_child(tiles)
	# Estádio e uniformes da temporada.
	var kc := UIKit.card("Card", 12)
	kc.add_child(UIKit.section_header(club.stadium))
	# Foto e ficha do estádio, quando os dados (mods/licenciamento) ou o Editor trazem.
	var photo := DropIns.venue_photo(club)
	if photo != null:
		var tr := TextureRect.new()
		tr.texture = photo
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.custom_minimum_size = Vector2(0, 180)
		tr.clip_contents = true
		kc.add_child(tr)
	var vbits: Array = []
	if String(club.venue.get("nick", "")) != "":
		vbits.append("\"%s\"" % club.venue["nick"])
	if int(club.venue.get("built", 0)) > 0:
		vbits.append("inaugurado em %d" % int(club.venue["built"]))
	if LicensedData.venue_kind(club) != "":
		vbits.append(String(LicensedData.VENUE_KIND_NAMES[LicensedData.venue_kind(club)]).to_lower())
	if not vbits.is_empty():
		kc.add_child(UIKit.label(" · ".join(vbits), "Small", true))
	var kits := UIKit.hbox(8)
	for k in [[club.kit_home, "Titular"], [club.kit_away, "Reserva"], [club.third_kit(), "Terceiro"], [club.gk_kit(), "Goleiro"]]:
		var v := UIKit.vbox(4)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var kv := UIKit.kit(k[0], 96, 0, club.crest)
		kv.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(kv)
		var l := UIKit.label(String(k[1]).to_upper(), "Caps")
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
		kits.add_child(v)
	kc.add_child(kits)
	if _own():
		var pre := SponsorManager.is_preseason(w)
		if pre:
			kc.add_child(UIKit.button("Uniformes e patrocínios", "PrimaryButton", func(): UIManager.push("kit"), "shirt"))
	out.add_child(UIKit.card_panel(kc))
	# Atalhos do clube como lista de menu.
	var cid := club.id
	var rows: Array = []
	if _own():
		rows.append(UIKit.menu_row("shirt", "Uniformes e patrocínios", "", func(): UIManager.push("kit")))
	if not club.kit_history.is_empty():
		rows.append(UIKit.menu_row("palette", "Uniformes por temporada", "", func(): UIManager.push("kit_history", {"id": cid})))
	rows.append(UIKit.menu_row("star", "Melhor 11 de sempre e ano a ano", "", func(): UIManager.push("club_records", {"id": cid, "tab": "xi"})))
	rows.append(UIKit.menu_row("swap", "Histórico de transferências", "", func(): UIManager.push("club_records", {"id": cid, "tab": "transfers"})))
	rows.append(UIKit.menu_row("clock", "Elencos anteriores", "", func(): UIManager.push("past_squads", {"id": cid})))
	rows.append(UIKit.menu_row("up", "Revelados pela base", "", func(): UIManager.push("graduates", {"id": cid})))
	if _own():
		rows.append(UIKit.menu_row("info", "Apresentação do clube", "", func(): UIManager.push("welcome")))
	out.add_child(UIKit.menu_group(rows))
	var pol := ClubPolicy.of(club)
	if not pol.is_empty():
		var pcard := UIKit.card("Card", 10)
		pcard.add_child(UIKit.section("Filosofia"))
		var prow := UIKit.hbox(10)
		prow.add_child(UIKit.icon_rect("star" if pol.has("only") else "info", 30, UIColors.ACCENT))
		var pc := UIKit.vbox(0)
		pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pc.add_child(UIKit.label(String(pol.get("name", "")), "H3"))
		pc.add_child(UIKit.label(String(pol.get("desc", "")), "Small", true))
		prow.add_child(pc)
		pcard.add_child(prow)
		out.add_child(UIKit.card_panel(pcard))
	# Rivais de origem e rivalidades que nasceram no save, da mais quente para a mais fria
	var rivals := Rivalry.of_club(w, club.id).slice(0, 4)
	if not rivals.is_empty():
		var rc := UIKit.card("Card", 10)
		rc.add_child(UIKit.section("Rivais"))
		for e: Dictionary in rivals:
			rc.add_child(RivalryView.club_row(w, club.id, e))
		out.add_child(UIKit.card_panel(rc))
	return out


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
	for item in [["rec", "Filosofia de elenco", ClubDNA.rec(club)], ["mkt", "Alcance do mercado", ClubDNA.mkt(club)], ["tac", "Escola tática", ClubDNA.tac(club)]]:
		card.add_child(UIKit.kv(item[1], ClubDNA.name_of(item[0], item[2])))
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
		card.add_child(UIKit.label("Nenhuma virada ainda.", "Muted", true))
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
		var ult := UIKit.pill("ULTIMATO", UIColors.RED, 14)
		ult.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		card.add_child(ult)
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
	row.add_child(UIKit.stat(Fmt.money(fin["balance"]), "caixa do clube", UIColors.RED if int(fin["balance"]) < 0 else UIColors.TEXT))
	row.add_child(UIKit.stat(Fmt.money(fin["transfer_budget"]), "verba autorizada", UIColors.ACCENT))
	row.add_child(UIKit.stat(Fmt.money(fin["expected_revenue"]), "receita/ano"))
	card.add_child(row)
	var auth := BoardBudget.state(w,club)
	card.add_child(UIKit.label("O caixa pertence ao clube. A diretoria define a verba; parcelar não reduz o custo comprometido.","Small",true))
	card.add_child(UIKit.kv("Autorização inicial",Fmt.money(int(auth["approved"]))))
	card.add_child(UIKit.kv("Custos fixos contratados",Fmt.money(int(auth["spent"]))))
	card.add_child(UIKit.kv("Vendas liberadas pela diretoria",Fmt.money(int(auth["sales"]))))
	card.add_child(UIKit.kv("Caixa livre após reservas",Fmt.money(BoardBudget.available_cash(w,club))))
	card.add_child(UIKit.kv("Parcelas futuras a pagar",Fmt.money(BoardBudget.pending(w,club))))
	var over: bool = fin["wage_bill"] > fin["wage_budget"]
	card.add_child(UIKit.kv("Folha salarial (mês)", "%s / %s" % [Fmt.money(fin["wage_bill"]), Fmt.money(fin["wage_budget"])], UIColors.RED if over else UIColors.TEXT))
	var share := float(fin["wage_bill"]) * 12.0 / maxf(1.0, float(fin["expected_revenue"]))
	card.add_child(UIKit.kv("Folha consome da receita", "%d%%" % int(round(share * 100.0)), UIColors.RED if share > 0.85 else (UIColors.ORANGE if share > 0.7 else UIColors.TEXT)))
	var proj := FinanceManager.projected_balance(w, club)
	card.add_child(UIKit.kv("Caixa previsto no fim da temporada", Fmt.money(proj), UIColors.RED if proj < 0 else UIColors.TEXT))
	if club.debt > 0:
		var dr := FinanceManager.debt_ratio(club, float(fin["expected_revenue"]))
		card.add_child(UIKit.kv("Dívida de longo prazo", "%s · %s da receita" % [Fmt.money(club.debt), "%d%%" % int(round(dr * 100.0))],
			UIColors.RED if dr > 1.0 else (UIColors.ORANGE if dr > 0.5 else UIColors.TEXT)))
		card.add_child(UIKit.kv("Parcela da dívida (ano)", Fmt.money(FinanceManager.debt_service(club))))
	var deal := FinanceManager.tv_deal(w, club.league_id)
	card.add_child(UIKit.kv("Cota de TV (ano)", "%s%s" % [Fmt.money(club.income_tv), "" if absf(deal - 1.0) < 0.01 else " · contrato %s%d%%" % ["+" if deal > 1.0 else "−", int(round(absf(deal - 1.0) * 100.0))]]))
	var own := WorldEvents.owner_of(w, club.id)
	if not own.is_empty():
		card.add_child(UIKit.kv("Dona da SAF" if bool(own.get("saf", false)) or club.affairs.has("saf") else "Dono", "%s (desde %d)" % [own.get("who", ""), int(own.get("y", 0))]))
	if club.affairs.has("pres"):
		card.add_child(UIKit.kv("Presidente", String(club.affairs["pres"]) + ((" · " + String(club.affairs["pres_note"])) if club.affairs.has("pres_note") else "")))
	if club.affairs.has("master"):
		card.add_child(UIKit.kv("Patrocinadora master", String(club.affairs["master"])))
	if club.affairs.has("rj"):
		card.add_child(UIKit.colored("Em recuperação judicial desde %d%s." % [int(club.affairs["rj"]), (" (depois da saída da %s, dona da SAF)" % club.affairs["ex_owner"]) if club.affairs.has("ex_owner") else ""], UIColors.ORANGE, "Small", true))
	if ClubEvents.banned(w, club):
		card.add_child(UIKit.colored("Transfer ban", UIColors.RED, "Small", true))
	if int(club.affairs.get("closed", 0)) > 0:
		card.add_child(UIKit.colored("Punido com %d jogo(s) de portões fechados." % int(club.affairs["closed"]), UIColors.ORANGE, "Small", true))
	if club.balance < 0:
		card.add_child(UIKit.colored("Caixa no vermelho: contratações bloqueadas.", UIColors.ORANGE, "Small", true))
	elif FinanceManager.debt_ratio(club, float(fin["expected_revenue"])) > 1.0:
		card.add_child(UIKit.colored("Dívida acima de um ano de receita.", UIColors.ORANGE, "Small", true))
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
	var mk := SponsorManager.market_label(club)
	card.add_child(UIKit.kv("Momento comercial", String(mk[0]), mk[1]))


func _structure_card(w: GameWorld, club: Club) -> Control:
	var card := UIKit.card("Card", 10)
	card.add_child(UIKit.section("Estrutura · decisão do presidente"))
	for item in [["facilities", "Centro de treinamento", club.facilities], ["youth", "Categorias de base", club.youth_level], ["stadium", "Estádio", club.capacity]]:
		var kind: String = item[0]
		var level: int = item[2]
		var head := UIKit.hbox(8)
		head.add_child(UIKit.label(item[1], "H3"))
		head.add_child(UIKit.spacer())
		head.add_child(UIKit.label(("%d/100" % level) if kind != "stadium" else ("%s lugares" % Fmt.thousands(level)), "H3"))
		card.add_child(head)
		if kind != "stadium":
			card.add_child(UIKit.bar(level, 100.0, UIColors.BLUE, 10))
		var cost := BoardRequests.cost_of(w, kind)
		var wait := BoardRequests.wait_turns(w, kind)
		var od := BoardRequests.odds(w, kind)
		var chance := float(od[0])
		var label := "Pedir ao presidente (%s)" % Fmt.money(cost)
		if wait > 0:
			label = "Novo pedido em %d rodada(s)" % wait
		elif kind == "stadium" and w.stats.has("stadium_work"):
			label = "Obras em andamento"
		var b := UIKit.button(label, "GhostButton", func(): _ask(kind), "up")
		b.disabled = wait > 0 or level >= 99 and kind != "stadium" or (kind == "stadium" and w.stats.has("stadium_work"))
		card.add_child(b)
		if wait == 0:
			var mood := "boa" if chance >= 0.6 else ("difícil" if chance < 0.3 else "incerta")
			card.add_child(UIKit.label("Chance %s%s" % [mood, (" — " + String(od[1])) if String(od[1]) != "" else ""], "Small", true))
	return UIKit.card_panel(card)


func _ask(kind: String) -> void:
	var w := world()
	UIManager.confirm("Levar o pedido ao presidente?", "O diretor de futebol %s leva o pedido. Custo: %s." % [BoardRequests.director(w)["name"], Fmt.money(BoardRequests.cost_of(w, kind))], "Pedir", func():
		var r := BoardRequests.request(w, kind)
		AudioManager.play("sign" if r["ok"] else "lose", -6.0)
		UIManager.toast(String(r["msg"]), UIColors.GREEN if r["ok"] and not r["partial"] else (UIColors.ORANGE if r["ok"] else UIColors.RED))
		GameManager.save_now()
		refresh())


func _director_card(w: GameWorld, club: Club) -> Control:
	var d := BoardRequests.director(w)
	var card := UIKit.card("Card", 8)
	card.add_child(UIKit.section("Diretor de futebol"))
	var h := UIKit.hbox(10)
	var v := UIKit.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UIKit.label(String(d["name"]), "H3"))
	v.add_child(UIKit.label("%d anos · no clube desde %d" % [int(d["age"]), int(d["since"])], "Small"))
	h.add_child(v)
	card.add_child(h)
	for a in [["neg", "Negociação", "Arranca desconto nas compras"], ["net", "Rede de olheiros", "Conhece mais nomes para sugerir"], ["rel", "Relação com a diretoria", "Ajuda a aprovar pedidos"]]:
		var r := UIKit.hbox(8)
		var l := UIKit.label(a[1], "")
		l.custom_minimum_size.x = 260
		r.add_child(l)
		var bar := UIKit.bar(float(d[a[0]]), 100.0, UIColors.GREEN if int(d[a[0]]) >= 65 else (UIColors.BLUE if int(d[a[0]]) >= 45 else UIColors.ORANGE), 10)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.add_child(bar)
		r.add_child(UIKit.label(str(int(d[a[0]])), "H3"))
		card.add_child(r)
	card.add_child(UIKit.button("Sugestões de reforço do diretor", "GhostButton", func(): _show_suggestions(), "search"))
	return UIKit.card_panel(card)


func _show_suggestions() -> void:
	var w := world()
	var s := BoardRequests.suggestions(w)
	var root := UIKit.vbox(10)
	var names := ["Goleiro", "Defesa", "Meio-campo", "Ataque"]
	root.add_child(UIKit.label("Carência: %s" % names[int(s["group"])], "H2", true))
	root.add_child(UIKit.kv("Orçamento", Fmt.money(w.user_club().transfer_budget)))
	var ids: Array = s["ids"]
	if ids.is_empty():
		root.add_child(UIKit.label("Ninguém no orçamento.", "Muted", true))
	for pid in ids:
		var p := w.player(int(pid))
		if p == null:
			continue
		var cl := w.club(p.club_id)
		var h := UIKit.hbox(10)
		if cl != null:
			h.add_child(UIKit.crest(cl, 34))
		var v := UIKit.vbox(0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UIKit.label(p.display_name(), "H3"))
		v.add_child(UIKit.label("%s · %d anos · %s · %s" % [Pos.code(p.position), p.age(w.year), cl.short_name if cl != null else "livre", Fmt.money(p.value)], "Small"))
		h.add_child(v)
		h.add_child(UIKit.badge(p.overall, 52, 36, 22))
		var id := p.id
		root.add_child(UIKit.tap_row(h, func():
			UIManager.close_modal()
			UIManager.push("player", {"id": id}), "CardFlat"))
	root.add_child(UIKit.button("Fechar", "GhostButton", func(): UIManager.close_modal()))
	UIManager.show_modal(root, true)


## Base de outro clube: os garotos até 20 anos, com o potencial pelo olho dos seus olheiros
## (estimativa com ruído; o valor real nunca aparece).
func _youth_card(w: GameWorld, club: Club) -> Control:
	var card := UIKit.card("Card", 6)
	card.add_child(UIKit.section("Base · joias do clube"))
	card.add_child(UIKit.kv("Nível da base", "%d/100" % club.youth_level))
	var kids: Array = []
	for p: Player in w.squad(club):
		if p.age(w.year) <= 20:
			kids.append(p)
	var prec := 0.35 + float(BoardRequests.director(w).get("net", 50)) / 250.0
	kids.sort_custom(func(a: Player, b: Player): return a.potential_estimate(prec) > b.potential_estimate(prec))
	if kids.is_empty():
		card.add_child(UIKit.label("Nenhum garoto da base no elenco.", "Muted", true))
	for p: Player in kids.slice(0, 6):
		var h := UIKit.hbox(10)
		h.add_child(UIKit.pos_badge(p.position))
		var v := UIKit.vbox(0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UIKit.label(p.display_name(), "H3"))
		v.add_child(UIKit.label("%d anos · %s" % [p.age(w.year), Player.potential_label(p.potential_estimate(prec))], "Small"))
		h.add_child(v)
		h.add_child(UIKit.badge(p.overall, 52, 36, 22))
		var pid := p.id
		card.add_child(UIKit.tap_row(h, func(): UIManager.push("player", {"id": pid}), "CardFlat"))
	var cid := club.id
	card.add_child(UIKit.button("Revelados pelo clube", "GhostButton", func(): UIManager.push("graduates", {"id": cid}), "star"))
	return UIKit.card_panel(card)


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
		var crow := UIKit.hbox(12)
		crow.add_child(CoachScreen.portrait(w, co, club, 56))
		var ccol := UIKit.vbox(0)
		ccol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ccol.add_child(UIKit.label("Técnico", "Small"))
		ccol.add_child(UIKit.label("%s · %s" % [String(co["n"]), People.style_name(String(co["st"])).to_lower()], "H3", true))
		crow.add_child(ccol)
		var ccid := club.id
		card.add_child(UIKit.tap_row(crow, func(): UIManager.push("coach", {"club": ccid}), "CardFlat"))
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
		card.add_child(UIKit.label("Nenhum título desde %d." % DatabaseManager.start_year(), "Muted"))
	if club.history.is_empty():
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
			GameManager.close_career_async(func() -> void: UIManager.goto("menu"))), "back"))
	return UIKit.card_panel(card)


func _save_copy() -> void:
	var v := UIKit.vbox(10)
	v.custom_minimum_size.x = 600
	v.add_child(UIKit.label("Salvar cópia", "Title"))
	for s in range(1, SaveManager.SLOTS + 1):
		if s == GameManager.slot:
			continue
		var meta := SaveManager.read_meta(s)
		var txt := "Espaço %d · vazio" % s if meta.is_empty() else "Espaço %d · %s, %d" % [s, meta.get("short", "?"), int(meta.get("year", 0))]
		var slot := s
		v.add_child(UIKit.button(txt, "", func():
			var do_save := func():
				UIManager.close_all_modals()
				GameManager.save_copy_async(slot, func(ok: bool) -> void:
					if ok:
						UIManager.toast("Cópia salva no espaço %d." % slot, UIColors.GREEN)
					else:
						UIManager.toast("Falha ao salvar a cópia.", UIColors.RED))
			if meta.is_empty():
				do_save.call()
			else:
				UIManager.confirm("Sobrescrever espaço %d?" % slot, "O save que está lá será substituído.", "Sobrescrever", do_save)))
	v.add_child(UIKit.button("Cancelar", "GhostButton", func(): UIManager.close_modal()))
	UIManager.show_modal(v)


func color_context() -> Dictionary:
	return club_context(_club_id)
