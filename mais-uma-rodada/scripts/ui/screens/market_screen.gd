extends BaseScreen
## Mercado: busca de jogadores, livres, pré-contratos, lista de observação, olheiros, propostas
## recebidas e jogadores à venda.
## A busca abre ordenada por relevância (quanto o jogador melhora seu time e se cabe no bolso),
## com busca por nome, faixa de preço, sugestões do diretor de futebol e, em cada linha, a
## comparação com o seu titular no setor e o preço pedido na cor do orçamento.

const TABS := [["search", "Buscar"], ["free", "Livres"], ["pre", "Pré-contrato"], ["watch", "Lista"], ["scout", "Olheiros"], ["offers", "Propostas"], ["listed", "À venda"]]
const GROUPS := ["Todos", "GOL", "DEF", "MEI", "ATA"]
const AGES := [["Todas", 99], ["≤ 21", 21], ["≤ 25", 25], ["≤ 29", 29]]
const SORTS := [["rel", "Relevância"], ["ovr", "Nível"], ["value", "Valor"], ["age", "Idade"]]
## Faixa de preço pedido em relação à verba: qualquer, até a verba, até 2x a verba.
const PRICES := [["Qualquer preço", 0.0], ["Cabe na verba", 1.0], ["Até 2x a verba", 2.0]]
const MAX_ROWS := 40

var _tab := "search"
var _group := 0
var _age := 0
var _sort := "rel"
var _upgrades := false
var _price := 0
var _query := ""
var _sug_turn := -1
var _sug: Dictionary = {}
var _origin := "all"
var _scouted_only := false


func _init() -> void:
	nav_tab = "market"
	screen_title = "Mercado"


func setup(p: Dictionary) -> void:
	super.setup(p)
	_tab = p.get("tab", "search")
	_group = int(p.get("group", 0))
	_upgrades = bool(p.get("upgrades", false))
	_origin = String(p.get("origin", "all"))


func refresh() -> void:
	var w := world()
	if w == null:
		return
	var club := w.user_club()
	screen_subtitle = "Janela aberta" if w.transfer_window_open() else "Janela fechada"
	UIManager.refresh_chrome()
	var c := content()
	UIKit.clear(c)
	c.add_child(_banner(w, club))
	var gt := ButtonGroup.new()
	var trow := UIKit.flow(8)
	var n_offers := TransferManager.pending_offers(w).size()
	for t in TABS:
		var key: String = t[0]
		var text: String = t[1]
		if key == "offers" and n_offers > 0:
			text += " (%d)" % n_offers
		elif key == "watch" and not _watch(w).is_empty():
			text += " (%d)" % _watch(w).size()
		var chip := UIKit.chip(text, key == _tab, gt, func():
			_tab = key
			refresh())
		chip.add_theme_font_size_override(&"font_size", 18)
		trow.add_child(chip)
	c.add_child(trow)
	match _tab:
		"free":
			_free_tab(c, w)
		"pre":
			_pre_tab(c, w, club)
		"watch":
			_watch_tab(c, w, club)
		"scout":
			_scout_tab(c, w, club)
		"offers":
			_offers_tab(c, w)
		"listed":
			_listed_tab(c, w, club)
		_:
			_search_tab(c, w, club)


func _banner(w: GameWorld, club: Club) -> Control:
	var card := UIKit.card("Card", 8)
	var row := UIKit.hbox(12)
	var open := w.transfer_window_open()
	row.add_child(UIKit.icon_rect("swap", 32, UIColors.GREEN if open else UIColors.ORANGE))
	var txt := ""
	if open:
		txt = "Janela aberta até a rodada %d." % (w.window_end_day() + 1)
	else:
		var nxt := w.next_window_day()
		txt = "Janela fechada. Reabre na rodada %d; até lá, só jogadores livres." % (nxt + 1) if nxt >= 0 else "Janela fechada. Reabre na próxima temporada; até lá, só jogadores livres."
	row.add_child(UIKit.label(txt, "", true))
	card.add_child(row)
	var fin := FinanceManager.summary(w, club)
	var stats := UIKit.hbox(8)
	stats.add_child(UIKit.stat(Fmt.money(club.transfer_budget), "para contratar", UIColors.ACCENT))
	var over: bool = fin["wage_bill"] > fin["wage_budget"]
	stats.add_child(UIKit.stat(Fmt.money(fin["wage_bill"]), "folha / mês", UIColors.RED if over else UIColors.TEXT))
	stats.add_child(UIKit.stat(Fmt.money(fin["wage_budget"]), "limite da folha"))
	card.add_child(stats)
	var rules := DatabaseManager.squad_rules()
	card.add_child(UIKit.label("Elenco: %d jogadores (mín. %d, máx. %d)." % [club.player_ids.size(), int(rules["min_players"]), int(rules["max_players"])], "Small"))
	return UIKit.card_panel(card)


## Nacional/estrangeiro sempre em relação ao país do seu clube.
func _origin_chips(c: VBoxContainer, club: Club) -> void:
	var g := ButtonGroup.new()
	var row := UIKit.hbox(6)
	var fl := UIKit.flag(club.nation, 30)
	fl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(fl)
	for o in Scouting.ORIGINS:
		var key: String = o[0]
		var chip := UIKit.chip(o[1], key == _origin, g, func():
			_origin = key
			refresh())
		chip.add_theme_font_size_override(&"font_size", 17)
		row.add_child(chip)
	c.add_child(row)


func _group_chips(c: VBoxContainer) -> void:
	var g := ButtonGroup.new()
	var row := UIKit.hbox(8)
	for i in GROUPS.size():
		var idx := i
		var chip := UIKit.chip(GROUPS[i], i == _group, g, func():
			_group = idx
			refresh())
		UIKit.shrink_button(chip)
		row.add_child(chip)
	c.add_child(row)


## Overall do seu titular mais fraco em cada setor (referência de "reforço").
func _weakest_starter_by_group(w: GameWorld, club: Club) -> Array:
	var out: Array = [99.0, 99.0, 99.0, 99.0]
	var sheet := club.sheet
	if sheet == null:
		return out
	var slots: Array = DatabaseManager.formation(sheet.formation)["slots"]
	for i in sheet.starters.size():
		var p := w.player(sheet.starters[i])
		if p == null or i >= slots.size():
			continue
		var g := Pos.group(int(slots[i]["pos"]))
		out[g] = minf(out[g], p.rating_at(int(slots[i]["pos"])))
	return out


func _search_tab(c: VBoxContainer, w: GameWorld, club: Club) -> void:
	# Busca por nome
	var srow := UIKit.hbox(8)
	var le := LineEdit.new()
	le.placeholder_text = "Buscar pelo nome (mín. 3 letras)"
	le.text = _query
	le.clear_button_enabled = true
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	le.custom_minimum_size.y = 64
	le.text_submitted.connect(func(t: String):
		_query = t.strip_edges()
		refresh())
	srow.add_child(le)
	srow.add_child(UIKit.icon_button("search", func():
		_query = le.text.strip_edges()
		refresh(), "Buscar"))
	c.add_child(srow)
	if _query.length() < 3 and _sort == "rel":
		var sug := _suggest_card(w, club)
		if sug != null:
			c.add_child(sug)
	_group_chips(c)
	_origin_chips(c, club)
	var ga := ButtonGroup.new()
	var arow := UIKit.flow(6)
	arow.add_child(UIKit.label("Idade", "Small"))
	for i in AGES.size():
		var idx := i
		var chip := UIKit.chip(AGES[i][0], i == _age, ga, func():
			_age = idx
			refresh())
		chip.add_theme_font_size_override(&"font_size", 17)
		arow.add_child(chip)
	c.add_child(arow)
	var prow := UIKit.flow(6)
	var gp := ButtonGroup.new()
	for i in PRICES.size():
		var idx := i
		var chip := UIKit.chip(PRICES[i][0], i == _price, gp, func():
			_price = idx
			refresh())
		chip.add_theme_font_size_override(&"font_size", 17)
		prow.add_child(chip)
	var up := UIKit.chip("Só reforços", _upgrades, null, func():
		_upgrades = not _upgrades
		refresh())
	up.add_theme_font_size_override(&"font_size", 17)
	prow.add_child(up)
	var sc := UIKit.chip("Observados", _scouted_only, null, func():
		_scouted_only = not _scouted_only
		refresh())
	sc.add_theme_font_size_override(&"font_size", 17)
	prow.add_child(sc)
	c.add_child(prow)
	var frow := UIKit.flow(6)
	frow.add_child(UIKit.label("Ordem", "Small"))
	var gs := ButtonGroup.new()
	for s in SORTS:
		var key: String = s[0]
		var chip := UIKit.chip(s[1], key == _sort, gs, func():
			_sort = key
			refresh())
		chip.add_theme_font_size_override(&"font_size", 17)
		frow.add_child(chip)
	c.add_child(frow)
	var weakest := _weakest_starter_by_group(w, club)
	var max_age: int = AGES[_age][1]
	var budget := float(maxi(1, club.transfer_budget))
	var cap := float(PRICES[_price][1])
	var q := _query.to_lower() if _query.length() >= 3 else ""
	var list: Array = []
	for p: Player in w.players.values():
		if p.club_id < 0 or p.club_id == club.id or p.retiring:
			continue
		if q != "" and p.display_name().to_lower().find(q) < 0 and (p.first_name + " " + p.display_name()).to_lower().find(q) < 0:
			continue
		if _group > 0 and Pos.group(p.position) != _group - 1:
			continue
		if p.age(w.year) > max_age or not Scouting.origin_ok(p, club, _origin):
			continue
		if _scouted_only and not Scouting.is_scouted(w, p):
			continue
		# O valor de mercado é um filtro barato antes do preço pedido (que depende do vendedor)
		if cap > 0.0 and float(p.value) > budget * cap * 1.6:
			continue
		var est := PlayerRowView.estimate(w, p, p.overall)
		var gain := float(est) - float(weakest[Pos.group(p.position)])
		if _upgrades and gain <= 0.0:
			continue
		if cap > 0.0 and float(TransferManager.asking_price(w, p)) > budget * cap:
			continue
		list.append([p, est, _relevance(w, p, gain, budget)])
	match _sort:
		"value":
			list.sort_custom(func(a, b): return a[0].value > b[0].value)
		"age":
			list.sort_custom(func(a, b): return a[0].age(w.year) < b[0].age(w.year) or (a[0].age(w.year) == b[0].age(w.year) and a[1] > b[1]))
		"ovr":
			list.sort_custom(func(a, b): return a[1] > b[1] or (a[1] == b[1] and a[0].value < b[0].value))
		_:
			list.sort_custom(func(a, b): return float(a[2]) > float(b[2]))
	c.add_child(UIKit.label("%s encontrados%s. O nível de jogadores de outros clubes é uma estimativa dos seus olheiros." % [Fmt.plural(list.size(), "jogador", "jogadores"), " (mostrando %d)" % MAX_ROWS if list.size() > MAX_ROWS else ""], "Small", true))
	for i in mini(MAX_ROWS, list.size()):
		c.add_child(_market_row(w, club, list[i][0], weakest))
	if list.is_empty():
		c.add_child(UIKit.label("Ninguém com esse perfil. Tente afrouxar os filtros.", "Muted", true))


## Relevância: o quanto melhora o time (ou promete, se for jovem), com desconto pelo que custa
## além da verba. Jogador que não melhora nada ainda aparece, mas lá embaixo.
func _relevance(w: GameWorld, p: Player, gain: float, budget: float) -> float:
	var v := clampf(gain, -12.0, 12.0) * 2.0
	var age := p.age(w.year)
	if age <= 22:
		v += clampf(float(p.potential_estimate(0.5) - p.overall), 0.0, 15.0) * 0.4
	elif age >= 32:
		v -= float(age - 31) * 1.5
	var ratio := float(p.value) / budget
	if ratio > 1.0:
		v -= log(ratio) / log(2.0) * 9.0
	if Scouting.is_scouted(w, p):
		v += 1.0
	return v


## Linha do mercado: a linha padrão do jogador e, embaixo, a comparação com seu titular no setor,
## preço pedido e salário pretendido nas cores do orçamento, e a estrela da lista de observação.
func _market_row(w: GameWorld, club: Club, p: Player, weakest: Array) -> Control:
	var pid := p.id
	var box := UIKit.vbox(2)
	box.add_child(PlayerRowView.make(w, p, {"mode": "market"}, func(): UIManager.push("player", {"id": pid})))
	var info := UIKit.hbox(10)
	var est := PlayerRowView.estimate(w, p, p.overall)
	var ref := float(weakest[Pos.group(p.position)])
	if ref < 98.0:
		var d := est - int(round(ref))
		var txt := ("+%d sobre seu pior titular no setor" % d) if d > 0 else ("mesmo nível do seu titular" if d == 0 else "%d abaixo do seu titular" % d)
		info.add_child(UIKit.colored(txt, UIColors.GREEN if d > 0 else (UIColors.MUTED if d == 0 else UIColors.ORANGE), "Small"))
	info.add_child(UIKit.spacer())
	if p.club_id >= 0:
		var ask := TransferManager.asking_price(w, p)
		var col := UIColors.GREEN if ask <= club.transfer_budget else (UIColors.ORANGE if ask <= club.transfer_budget * 2 else UIColors.RED)
		info.add_child(UIKit.colored("pedem " + Fmt.money(ask), col, "Small"))
	var wage := TransferManager.wage_ask(w, p, club)
	var fin := FinanceManager.summary(w, club)
	var room := int(fin["wage_budget"]) - int(fin["wage_bill"])
	info.add_child(UIKit.colored(Fmt.money_month(wage), UIColors.TEXT if wage <= room else UIColors.ORANGE, "Small"))
	var on := _watch(w).has(pid)
	var star := UIKit.icon_button("star", func():
		_toggle_watch(w, pid)
		refresh(), "Lista de observação")
	star.custom_minimum_size = Vector2(48, 44)
	star.modulate = UIColors.ACCENT if on else Color(1, 1, 1, 0.35)
	info.add_child(star)
	box.add_child(UIKit.margin(info, 12, 0, 8, 4))
	return box


# Lista de observação: ids em world.stats["watch"]
func _watch(w: GameWorld) -> Array:
	return w.stats.get("watch", [])


func _toggle_watch(w: GameWorld, pid: int) -> void:
	var arr: Array = w.stats.get("watch", [])
	if arr.has(pid):
		arr.erase(pid)
		UIManager.toast("Saiu da lista de observação.")
	else:
		arr.append(pid)
		UIManager.toast("Adicionado à lista de observação.", UIColors.ACCENT)
	w.stats["watch"] = arr


func _watch_tab(c: VBoxContainer, w: GameWorld, club: Club) -> void:
	var weakest := _weakest_starter_by_group(w, club)
	var list: Array = []
	var gone: Array = []
	for pid in _watch(w):
		var p := w.player(int(pid))
		if p == null or p.retiring or p.club_id == club.id:
			gone.append(pid)
			continue
		list.append(p)
	# Quem já veio para o seu clube ou se aposentou sai sozinho da lista
	for pid in gone:
		_watch(w).erase(pid)
	if list.is_empty():
		c.add_child(UIKit.label("Sua lista está vazia. Toque na estrela de um jogador na busca para acompanhá-lo aqui: preço, salário e situação de contrato num lugar só.", "Muted", true))
		return
	list.sort_custom(func(a: Player, b: Player): return PlayerRowView.estimate(w, a, a.overall) > PlayerRowView.estimate(w, b, b.overall))
	c.add_child(UIKit.label("%s na lista." % Fmt.plural(list.size(), "jogador", "jogadores"), "Small"))
	for p: Player in list:
		var card := UIKit.card("CardFlat", 4)
		card.add_child(_market_row(w, club, p, weakest))
		var bits: Array = []
		if p.club_id < 0:
			bits.append("livre: sem taxa")
		elif p.contract_end <= w.year:
			bits.append("contrato termina nesta temporada")
			if TransferManager.precontract_block(w, p, club) == "":
				bits.append("aceita pré-contrato")
		else:
			bits.append("contrato até %d" % p.contract_end)
		if p.transfer_listed:
			bits.append("à venda")
		if p.injury_weeks > 0:
			bits.append("lesionado (%d sem.)" % p.injury_weeks)
		var pre := TransferManager.precontract_of(w, p)
		if not pre.is_empty():
			var pc := w.club(int(pre.get("club", -1)))
			bits.append("já assinou com o %s" % (pc.short_name if pc != null else "outro clube"))
		card.add_child(UIKit.margin(UIKit.label(" · ".join(bits), "Caps", true), 12, 0, 8, 4))
		c.add_child(UIKit.card_panel(card))


## Jogadores em último ano de contrato: podem assinar pré-contrato a partir da metade da temporada.
func _pre_tab(c: VBoxContainer, w: GameWorld, club: Club) -> void:
	var prog := TransferManager.season_progress(w)
	var head := UIKit.card("Card", 6)
	head.add_child(UIKit.section("Contratos terminando"))
	if prog < 0.5:
		head.add_child(UIKit.label("Estes jogadores ficam livres no fim da temporada. O pré-contrato pode ser proposto a partir da metade da temporada; até lá, só dá para comprá-los (mais barato, pelo contrato curto).", "Small", true))
	else:
		head.add_child(UIKit.label("Já é possível propor pré-contrato: o jogador chega de graça na próxima temporada. Abra o perfil e toque em \"Propor pré-contrato\".", "Small", true))
	c.add_child(UIKit.card_panel(head))
	_group_chips(c)
	var weakest := _weakest_starter_by_group(w, club)
	var budget := float(maxi(1, club.transfer_budget))
	var list: Array = []
	var signed := 0
	for p: Player in w.players.values():
		if p.club_id < 0 or p.club_id == club.id or p.retiring or p.contract_end > w.year or not p.loan.is_empty():
			continue
		if _group > 0 and Pos.group(p.position) != _group - 1:
			continue
		if not TransferManager.precontract_of(w, p).is_empty():
			signed += 1
			continue
		var est := PlayerRowView.estimate(w, p, p.overall)
		list.append([p, _relevance(w, p, float(est) - float(weakest[Pos.group(p.position)]), budget * 4.0)])
	list.sort_custom(func(a, b): return float(a[1]) > float(b[1]))
	c.add_child(UIKit.label("%s disponíveis%s." % [Fmt.plural(list.size(), "jogador", "jogadores"), (" · %d já assinaram com outros clubes" % signed) if signed > 0 else ""], "Small", true))
	for i in mini(MAX_ROWS, list.size()):
		c.add_child(_market_row(w, club, list[i][0], weakest))
	if list.is_empty():
		c.add_child(UIKit.label("Ninguém nesse setor com contrato terminando.", "Muted", true))


## Sugestões do diretor de futebol: o setor mais carente e nomes que cabem no bolso.
func _suggest_card(w: GameWorld, club: Club) -> Control:
	if _sug_turn != w.current_turn():
		_sug = BoardRequests.suggestions(w)
		_sug_turn = w.current_turn()
	var ids: Array = _sug.get("ids", [])
	if ids.is_empty():
		return null
	var d := BoardRequests.director(w)
	var card := UIKit.card("Card", 6)
	var head := UIKit.hbox(10)
	head.add_child(UIKit.icon_rect("chat", 28, UIColors.ACCENT))
	head.add_child(UIKit.label("%s, diretor de futebol: \"Onde mais precisamos: %s. Estes cabem no nosso bolso.\"" % [String(d.get("name", "O diretor")), ["goleiro", "defesa", "meio-campo", "ataque"][int(_sug.get("group", 1))]], "Small", true))
	head.get_child(1).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(head)
	var weakest := _weakest_starter_by_group(w, club)
	for pid in ids.slice(0, 3):
		var p := w.player(int(pid))
		if p != null:
			card.add_child(_market_row(w, club, p, weakest))
	return UIKit.card_panel(card)


func _free_tab(c: VBoxContainer, w: GameWorld) -> void:
	_group_chips(c)
	var club := w.user_club()
	_origin_chips(c, club)
	var list: Array = []
	for p: Player in w.free_agents():
		if p.retiring or not Scouting.origin_ok(p, club, _origin):
			continue
		if _group > 0 and Pos.group(p.position) != _group - 1:
			continue
		list.append(p)
	list.sort_custom(func(a: Player, b: Player): return a.overall > b.overall)
	c.add_child(UIKit.label("Sem taxa de transferência, só salário.", "Small", true))
	var weakest := _weakest_starter_by_group(w, club)
	for i in mini(MAX_ROWS, list.size()):
		c.add_child(_market_row(w, club, list[i], weakest))
	if list.is_empty():
		c.add_child(UIKit.label("Nenhum jogador livre nessa posição agora.", "Muted"))


func _offers_tab(c: VBoxContainer, w: GameWorld) -> void:
	var offers := TransferManager.pending_offers(w)
	if offers.is_empty():
		c.add_child(UIKit.label("Nenhuma proposta pelo seu elenco.", "Muted", true))
		return
	for o: TransferOffer in offers:
		c.add_child(_offer_card(w, o))


func _offer_card(w: GameWorld, o: TransferOffer) -> Control:
	var p := w.player(o.player_id)
	var buyer := w.club(o.buyer_id)
	var card := UIKit.card("Card", 10)
	if p == null or buyer == null:
		card.add_child(UIKit.label("Proposta indisponível.", "Muted"))
		return UIKit.card_panel(card)
	var head := UIKit.hbox(12)
	head.add_child(UIKit.crest(buyer, 56))
	var col := UIKit.vbox(0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UIKit.label("%s quer %s" % [buyer.short_name, p.display_name()], "H3", true))
	var days_left := maxi(0, o.expires_day - w.current_turn())
	col.add_child(UIKit.label("%s · %s · valor de mercado %s · expira em %s" % [w.league_short(buyer.league_id), buyer.arch().get("tag", ""), Fmt.money(p.value), Fmt.plural(days_left + 1, "jogo", "jogos")], "Small", true))
	head.add_child(col)
	card.add_child(head)
	var fee := UIKit.label(Fmt.money(o.fee), "Big")
	fee.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fee.add_theme_color_override(&"font_color", UIColors.ACCENT)
	card.add_child(fee)
	var pid := p.id
	card.add_child(PlayerRowView.make(w, p, {"mode": "squad"}, func(): UIManager.push("player", {"id": pid})))
	if p.trait_sum("ambition") >= 25.0 and buyer.reputation > w.user_club().reputation:
		card.add_child(UIKit.colored("%s é ambicioso: recusar a chance de ir para um clube maior vai abalar a moral dele." % p.display_name(), UIColors.ORANGE, "Small"))
	if not o.raised and o.rounds < TransferManager.MAX_COUNTERS:
		var left := TransferManager.MAX_COUNTERS - o.rounds
		card.add_child(UIKit.label("Contraproposta (%s):" % Fmt.plural(left, "rodada restante", "rodadas restantes"), "Small"))
		var crow := UIKit.hbox(8)
		for m in [1.1, 1.25, 1.5]:
			var ask := Valuation.round_value(o.fee * m)
			var more := UIKit.button(Fmt.money(ask), "ChipButton", func(): _respond(o, "counter", ask), "up")
			more.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			crow.add_child(more)
		card.add_child(crow)
	var row := UIKit.hbox(8)
	var accept := UIKit.button("Aceitar", "PrimaryButton", func(): _respond(o, "accept", 0), "check")
	accept.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	accept.add_theme_font_size_override(&"font_size", 24)
	row.add_child(accept)
	var reject := UIKit.button("Recusar", "GhostButton", func(): _respond(o, "reject", 0), "close")
	reject.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(reject)
	card.add_child(row)
	return UIKit.card_panel(card)


func _respond(o: TransferOffer, action: String, counter_fee: int) -> void:
	var w := world()
	if action == "accept":
		var p := w.player(o.player_id)
		var pname := p.display_name() if p != null else "o jogador"
		UIManager.confirm("Vender %s?" % pname, "Por %s ao %s. Essa decisão não pode ser desfeita." % [Fmt.money(o.fee), w.club(o.buyer_id).short_name], "Vender", func():
			var msg := TransferManager.respond_offer(w, o, "accept")
			AudioManager.play("sign")
			UIManager.toast(msg, UIColors.GREEN)
			GameManager.save_now()
			refresh())
		return
	var msg2 := TransferManager.respond_offer(w, o, action, counter_fee)
	UIManager.toast(msg2, UIColors.ACCENT if o.is_pending() else UIColors.TEXT)
	GameManager.save_now()
	refresh()


func _listed_tab(c: VBoxContainer, w: GameWorld, club: Club) -> void:
	var list: Array = []
	for p in w.squad(club):
		if p.transfer_listed:
			list.append(p)
	if list.is_empty():
		c.add_child(UIKit.label("Nenhum jogador anunciado. Para vender, abra o perfil de um jogador do seu elenco e toque em \"Vender\".", "Muted", true))
		return
	c.add_child(UIKit.label("Jogadores anunciados recebem propostas durante a janela.", "Small", true))
	for p: Player in list:
		var card := UIKit.card("CardFlat", 6)
		var pid := p.id
		card.add_child(PlayerRowView.make(w, p, {"mode": "squad"}, func(): UIManager.push("player", {"id": pid})))
		var row := UIKit.hbox(8)
		row.add_child(UIKit.label("Preço pedido: %s" % Fmt.money(p.asking_price if p.asking_price > 0 else p.value), "H3"))
		row.add_child(UIKit.spacer())
		row.add_child(UIKit.button("Retirar", "GhostButton", func():
			p.transfer_listed = false
			p.asking_price = 0
			UIManager.toast("%s saiu da lista de venda." % p.display_name())
			refresh(), "close"))
		card.add_child(row)
		c.add_child(UIKit.card_panel(card))


func _scout_tab(c: VBoxContainer, w: GameWorld, club: Club) -> void:
	var card := UIKit.card("Card", 8)
	var head := UIKit.hbox(12)
	head.add_child(UIKit.icon_rect("search", 32, UIColors.ACCENT))
	var lvl := People.staff_level(w, "olheiro")
	var q := "excelente" if lvl >= 0.85 else ("bom" if lvl >= 0.6 else ("regular" if lvl >= 0.4 else "fraco"))
	head.add_child(UIKit.label("Olheiro-chefe %s: observa até %s por missão, uma missão por rodada." % [q, Fmt.plural(Scouting.capacity(w), "jogador", "jogadores")], "", true))
	card.add_child(head)
	card.add_child(UIKit.label("Escolha o perfil. Ele volta com os melhores nomes que o clube pode pagar e com avaliação quase exata de nível e potencial.", "Small", true))
	_group_chips(card)
	_origin_chips(card, club)
	var ga := ButtonGroup.new()
	var arow := UIKit.hbox(6)
	arow.add_child(UIKit.label("Idade", "Small"))
	for i in AGES.size():
		var idx := i
		var chip := UIKit.chip(AGES[i][0], i == _age, ga, func():
			_age = idx
			refresh())
		chip.add_theme_font_size_override(&"font_size", 17)
		arow.add_child(chip)
	card.add_child(arow)
	var ready := Scouting.can_send(w)
	var go := UIKit.button("Enviar olheiro" if ready else "Olheiro em campo até a próxima rodada", "PrimaryButton" if ready else "GhostButton", func():
		if not Scouting.can_send(w):
			return
		var found := Scouting.send_mission(w, _origin, _group - 1, int(AGES[_age][1]))
		if found.is_empty():
			UIManager.toast("O olheiro não achou ninguém nesse perfil ao alcance do clube.", UIColors.ORANGE)
		else:
			UIManager.toast("Relatório pronto: %s." % Fmt.plural(found.size(), "jogador observado", "jogadores observados"), UIColors.GREEN)
		GameManager.save_now()
		refresh(), "search")
	go.disabled = not ready
	card.add_child(go)
	c.add_child(UIKit.card_panel(card))
	var list := Scouting.reports(w)
	list.sort_custom(func(a: Player, b: Player): return PlayerRowView.estimate(w, a, a.overall) > PlayerRowView.estimate(w, b, b.overall))
	c.add_child(UIKit.section("Relatórios (%d)" % list.size()))
	if list.is_empty():
		c.add_child(UIKit.label("Nenhum relatório ainda. Envie o olheiro para começar.", "Muted", true))
		return
	for p: Player in list:
		var pid := p.id
		var row_card := UIKit.card("CardFlat", 4)
		row_card.add_child(PlayerRowView.make(w, p, {"mode": "market"}, func(): UIManager.push("player", {"id": pid})))
		var info := UIKit.hbox(8)
		var pot := p.potential_estimate(0.75)
		var age := p.age(w.year)
		var pot_txt := Player.potential_label(pot) if age <= 25 else ("No auge" if age <= 30 else "Veterano")
		var price := "sem taxa" if p.club_id < 0 else "pedem %s" % Fmt.money(TransferManager.asking_price(w, p))
		info.add_child(UIKit.label("%s · %s · %s" % [DatabaseManager.nation_adj(p.nationality), pot_txt, price], "Small", true))
		info.get_child(0).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var drop := UIKit.button("Descartar", "GhostButton", func():
			Scouting.forget(w, p)
			refresh(), "close")
		UIKit.shrink_button(drop)
		drop.add_theme_font_size_override(&"font_size", 17)
		info.add_child(drop)
		row_card.add_child(info)
		c.add_child(UIKit.card_panel(row_card))
