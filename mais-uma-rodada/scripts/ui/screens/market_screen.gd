extends BaseScreen
## Mercado: busca de jogadores, livres, propostas recebidas e jogadores à venda.

const TABS := [["search", "Buscar"], ["free", "Livres"], ["scout", "Olheiros"], ["shortlist", "Lista"], ["offers", "Propostas"], ["listed", "À venda"], ["moves", "Movimentações"]]
const GROUPS := ["Todos", "GOL", "DEF", "MEI", "ATA"]
const AGES := [["Todas", 99], ["≤ 21", 21], ["≤ 25", 25], ["≤ 29", 29]]
const SORTS := [["ovr", "Nível"], ["value", "Valor"], ["price", "Preço"], ["age", "Idade"]]
const MOVE_SCOPES := [["mine", "Seu clube"], ["league", "Sua liga"], ["all", "Mundo"]]
const MOVE_SORTS := [["recent", "Recentes"], ["fee", "Maiores"]]
const MAX_ROWS := 40

var _tab := "search"
var _group := 0
var _age := 0
var _sort := "ovr"
var _upgrades := false
var _affordable := false
var _origin := "all"
var _scouted_only := false
var _listed_only := false
var _expiring_only := false
var _query := ""
var _move_scope := "league"
var _move_sort := "recent"


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
	trow.mouse_filter = Control.MOUSE_FILTER_PASS
	var n_offers := TransferManager.pending_offers(w).size()
	var n_short := Shortlist.news_count(w)
	for t in TABS:
		var key: String = t[0]
		var text: String = t[1]
		if key == "offers" and n_offers > 0:
			text += " (%d)" % n_offers
		elif key == "shortlist" and n_short > 0:
			text += " (%d)" % n_short
		var chip := UIKit.chip(text, key == _tab, gt, func():
			_tab = key
			refresh())
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.add_theme_font_size_override(&"font_size", 18)
		trow.add_child(chip)
	c.add_child(trow)
	match _tab:
		"free":
			_free_tab(c, w)
		"scout":
			_scout_tab(c, w, club)
		"offers":
			_offers_tab(c, w)
		"listed":
			_listed_tab(c, w, club)
		"shortlist":
			_shortlist_tab(c, w)
		"moves":
			_moves_tab(c, w, club)
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


func _small_chip(text: String, pressed: bool, group: ButtonGroup, cb: Callable) -> Button:
	var chip := UIKit.chip(text, pressed, group, cb)
	chip.add_theme_font_size_override(&"font_size", 17)
	return chip


func _search_tab(c: VBoxContainer, w: GameWorld, club: Club) -> void:
	# Busca pelo nome: só a lista é refeita enquanto digita, para o campo não perder o foco.
	var le := LineEdit.new()
	le.placeholder_text = "Buscar pelo nome"
	le.text = _query
	le.clear_button_enabled = true
	c.add_child(le)
	_group_chips(c)
	_origin_chips(c, club)
	var ga := ButtonGroup.new()
	var arow := UIKit.hbox(6)
	arow.add_child(UIKit.label("Idade", "Small"))
	for i in AGES.size():
		var idx := i
		arow.add_child(_small_chip(AGES[i][0], i == _age, ga, func():
			_age = idx
			refresh()))
	c.add_child(arow)
	var frow := UIKit.flow(6)
	frow.mouse_filter = Control.MOUSE_FILTER_PASS
	frow.add_child(_small_chip("Só reforços", _upgrades, null, func():
		_upgrades = not _upgrades
		refresh()))
	frow.add_child(_small_chip("Cabe no orçamento", _affordable, null, func():
		_affordable = not _affordable
		refresh()))
	frow.add_child(_small_chip("À venda", _listed_only, null, func():
		_listed_only = not _listed_only
		refresh()))
	frow.add_child(_small_chip("Fim de contrato", _expiring_only, null, func():
		_expiring_only = not _expiring_only
		refresh()))
	frow.add_child(_small_chip("Observados", _scouted_only, null, func():
		_scouted_only = not _scouted_only
		refresh()))
	c.add_child(frow)
	var srow := UIKit.hbox(6)
	srow.add_child(UIKit.label("Ordenar", "Small"))
	var gs := ButtonGroup.new()
	for s in SORTS:
		var key: String = s[0]
		srow.add_child(_small_chip(s[1], key == _sort, gs, func():
			_sort = key
			refresh()))
	c.add_child(srow)
	var results := UIKit.vbox(12)
	c.add_child(results)
	le.text_changed.connect(func(q: String):
		_query = q
		_fill_search(results, w, club))
	_fill_search(results, w, club)


func _fill_search(results: VBoxContainer, w: GameWorld, club: Club) -> void:
	UIKit.clear(results)
	var weakest := _weakest_starter_by_group(w, club)
	var max_age: int = AGES[_age][1]
	var q := _query.strip_edges().to_lower()
	var list: Array = []
	for p: Player in w.players.values():
		if p.club_id < 0 or p.club_id == club.id or p.retiring:
			continue
		if q != "" and not p.display_name().to_lower().contains(q) and not p.full_name().to_lower().contains(q):
			continue
		if _group > 0 and Pos.group(p.position) != _group - 1:
			continue
		if p.age(w.year) > max_age or not Scouting.origin_ok(p, club, _origin):
			continue
		if _scouted_only and not Scouting.is_scouted(w, p):
			continue
		if _listed_only and not p.transfer_listed:
			continue
		if _expiring_only and p.contract_years_left(w.year) > 0:
			continue
		var est := PlayerRowView.estimate(w, p, p.overall)
		if _upgrades and est <= weakest[Pos.group(p.position)]:
			continue
		var ask := TransferManager.asking_price(w, p)
		if _affordable and ask > club.transfer_budget:
			continue
		list.append([p, est, ask])
	match _sort:
		"value":
			list.sort_custom(func(a, b): return a[0].value > b[0].value)
		"price":
			list.sort_custom(func(a, b): return a[2] < b[2] or (a[2] == b[2] and a[1] > b[1]))
		"age":
			list.sort_custom(func(a, b): return a[0].age(w.year) < b[0].age(w.year) or (a[0].age(w.year) == b[0].age(w.year) and a[1] > b[1]))
		_:
			list.sort_custom(func(a, b): return a[1] > b[1] or (a[1] == b[1] and a[0].value < b[0].value))
	results.add_child(UIKit.label("%s encontrados%s. O nível de jogadores de outros clubes é uma estimativa dos seus olheiros; o preço é o que o clube pede hoje." % [Fmt.plural(list.size(), "jogador", "jogadores"), " (mostrando %d)" % MAX_ROWS if list.size() > MAX_ROWS else ""], "Small", true))
	for i in mini(MAX_ROWS, list.size()):
		var p: Player = list[i][0]
		var pid := p.id
		results.add_child(PlayerRowView.make(w, p, {"mode": "market"}, func(): UIManager.push("player", {"id": pid})))
	if list.is_empty():
		results.add_child(UIKit.label("Ninguém com esse perfil. Tente afrouxar os filtros.", "Muted", true))


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
	for i in mini(MAX_ROWS, list.size()):
		var p: Player = list[i]
		var pid := p.id
		c.add_child(PlayerRowView.make(w, p, {"mode": "market"}, func(): UIManager.push("player", {"id": pid})))
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


# ---------------------------------------------------------------------------
# Lista de observação
# ---------------------------------------------------------------------------

func _shortlist_tab(c: VBoxContainer, w: GameWorld) -> void:
	var list := Shortlist.players(w)
	if list.is_empty():
		c.add_child(UIKit.label("Sua lista está vazia. Abra o perfil de um jogador de outro clube e toque na estrela para acompanhá-lo: aqui você vê o preço, a chance de ele topar vir e tudo o que mudar (venda, fim de contrato, troca de clube).", "Muted", true))
		return
	c.add_child(UIKit.label("%s na lista (máx. %d). Novidades desde que cada um entrou aparecem em destaque." % [Fmt.plural(list.size(), "jogador", "jogadores"), Shortlist.MAX_ENTRIES], "Small", true))
	# Quem tem novidade primeiro, depois pelo nível estimado.
	var rows: Array = []
	for p: Player in list:
		rows.append([p, Shortlist.changes(w, p), PlayerRowView.estimate(w, p, p.overall)])
	rows.sort_custom(func(a, b): return (not a[1].is_empty() and b[1].is_empty()) or (a[1].is_empty() == b[1].is_empty() and a[2] > b[2]))
	for r in rows:
		c.add_child(_shortlist_card(w, r[0], r[1]))


func _shortlist_card(w: GameWorld, p: Player, changes: Array) -> Control:
	var card := UIKit.card("CardFlat", 6)
	var pid := p.id
	card.add_child(PlayerRowView.make(w, p, {"mode": "market"}, func(): UIManager.push("player", {"id": pid})))
	if not changes.is_empty():
		var tags := UIKit.flow(6)
		for ch in changes:
			tags.add_child(UIKit.pill(ch[0], ch[1], 16))
		card.add_child(tags)
	var info := UIKit.hbox(8)
	var il := Shortlist.interest_label(w, p)
	var txt := UIKit.label("Livre, sem taxa de transferência" if p.club_id < 0 else "Contrato até %d · %s" % [p.contract_end, Player.STATUS_NAMES[p.squad_status].to_lower()], "Small", true)
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(txt)
	info.add_child(UIKit.pill(il[0], il[1], 16))
	card.add_child(info)
	var brow := UIKit.hbox(8)
	var can_bid := p.club_id < 0 or w.transfer_window_open()
	var mode := "free" if p.club_id < 0 else "buy"
	var bid := UIKit.button("Contratar" if p.club_id < 0 else ("Fazer proposta" if can_bid else "Janela fechada"), "" if can_bid else "GhostButton", func():
		Negotiation.open(w, p, mode, func(): refresh()), "swap")
	bid.disabled = not can_bid
	bid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brow.add_child(bid)
	var drop := UIKit.button("Tirar", "GhostButton", func():
		Shortlist.toggle(w, p)
		GameManager.save_now()
		refresh(), "close")
	brow.add_child(drop)
	card.add_child(brow)
	return UIKit.card_panel(card)


# ---------------------------------------------------------------------------
# Movimentações: transferências concluídas e o saldo da sua janela
# ---------------------------------------------------------------------------

func _moves_tab(c: VBoxContainer, w: GameWorld, club: Club) -> void:
	c.add_child(_balance_card(w, club))
	var g := ButtonGroup.new()
	var row := UIKit.hbox(6)
	for s in MOVE_SCOPES:
		var key: String = s[0]
		row.add_child(_small_chip(s[1], key == _move_scope, g, func():
			_move_scope = key
			refresh()))
	row.add_child(UIKit.spacer())
	var gs := ButtonGroup.new()
	for s in MOVE_SORTS:
		var key2: String = s[0]
		row.add_child(_small_chip(s[1], key2 == _move_sort, gs, func():
			_move_sort = key2
			refresh()))
	c.add_child(row)
	var league := club.league_id
	var list: Array = []
	for t: Transfer in w.transfer_log:
		if t.kind == Transfer.KIND_RELEASE:
			continue
		match _move_scope:
			"mine":
				if t.from_id != club.id and t.to_id != club.id:
					continue
			"league":
				var a := w.club(t.from_id) if t.from_id >= 0 else null
				var b := w.club(t.to_id) if t.to_id >= 0 else null
				if (a == null or a.league_id != league) and (b == null or b.league_id != league):
					continue
		list.append(t)
	if _move_sort == "fee":
		list.sort_custom(func(a: Transfer, b: Transfer): return a.fee > b.fee)
	else:
		list.sort_custom(func(a: Transfer, b: Transfer): return a.year > b.year or (a.year == b.year and a.day > b.day))
	c.add_child(UIKit.label("%s nesta temporada e na anterior%s." % [Fmt.plural(list.size(), "transferência", "transferências"), " (mostrando %d)" % MAX_ROWS if list.size() > MAX_ROWS else ""], "Small", true))
	for i in mini(MAX_ROWS, list.size()):
		c.add_child(_move_row(w, list[i], club))
	if list.is_empty():
		c.add_child(UIKit.label("Nenhuma transferência por aqui ainda.", "Muted", true))


## Gastos e receitas do seu clube com transferências na temporada.
func _balance_card(w: GameWorld, club: Club) -> Control:
	var card := UIKit.card("Card", 8)
	card.add_child(UIKit.section("Seu balanço em %d" % w.year))
	var spent := 0
	var got := 0
	var n_in := 0
	var n_out := 0
	for t: Transfer in w.transfer_log:
		if t.year != w.year or t.kind == Transfer.KIND_RELEASE:
			continue
		if t.to_id == club.id:
			spent += t.fee
			n_in += 1
		elif t.from_id == club.id:
			got += t.fee
			n_out += 1
	var stats := UIKit.hbox(8)
	stats.add_child(UIKit.stat(Fmt.money(spent), "gastos (%d chegadas)" % n_in, UIColors.RED if spent > 0 else UIColors.TEXT))
	stats.add_child(UIKit.stat(Fmt.money(got), "vendas (%d saídas)" % n_out, UIColors.GREEN if got > 0 else UIColors.TEXT))
	var net := got - spent
	stats.add_child(UIKit.stat(("+" if net > 0 else "") + Fmt.money(net), "saldo", UIColors.GREEN if net > 0 else (UIColors.RED if net < 0 else UIColors.TEXT)))
	card.add_child(stats)
	var inst := TransferManager.pending_installments(w)
	var extra: Array = []
	if inst > 0:
		extra.append("Parcelas a pagar: %s." % Fmt.money(inst))
	var loans := TransferManager.loaned_out(w).size()
	if loans > 0:
		extra.append("%s." % Fmt.plural(loans, "jogador emprestado", "jogadores emprestados"))
	if not extra.is_empty():
		card.add_child(UIKit.label(" ".join(extra), "Small", true))
	return UIKit.card_panel(card)


func _move_row(w: GameWorld, t: Transfer, club: Club) -> Control:
	var row := UIKit.hbox(10)
	var from := w.club(t.from_id) if t.from_id >= 0 else null
	var to := w.club(t.to_id) if t.to_id >= 0 else null
	var col := UIKit.vbox(0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nm := UIKit.label(t.player_name, "H3")
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(nm)
	var route := "%s → %s" % [from.short_name if from != null else "Livre", to.short_name if to != null else "?"]
	var when := "rodada %d" % (t.day + 1) if t.year == w.year else str(t.year)
	var sub := UIKit.label("%d anos · nível %d · %s · %s" % [t.age, t.overall, route, when], "Small")
	sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(sub)
	if from != null:
		row.add_child(UIKit.crest(from, 40))
	else:
		row.add_child(UIKit.icon_rect("plus", 40, UIColors.MUTED))
	row.add_child(UIKit.icon_rect("forward", 22, UIColors.MUTED))
	if to != null:
		row.add_child(UIKit.crest(to, 40))
	row.add_child(col)
	var fee := UIKit.label(Fmt.money(t.fee) if t.fee > 0 else "Livre", "Stat")
	fee.add_theme_font_size_override(&"font_size", 22)
	if t.to_id == club.id:
		fee.add_theme_color_override(&"font_color", UIColors.RED)
	elif t.from_id == club.id:
		fee.add_theme_color_override(&"font_color", UIColors.GREEN)
	row.add_child(fee)
	var pid := t.player_id
	return UIKit.tap_row(row, func():
		if w.player(pid) != null:
			UIManager.push("player", {"id": pid}))
