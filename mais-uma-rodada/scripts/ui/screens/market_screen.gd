extends BaseScreen
## Mercado: busca de jogadores, livres, propostas recebidas e jogadores à venda.

const TABS := [["search", "Buscar"], ["free", "Livres"], ["offers", "Propostas"], ["listed", "À venda"]]
const GROUPS := ["Todos", "GOL", "DEF", "MEI", "ATA"]
const AGES := [["Todas", 99], ["≤ 21", 21], ["≤ 25", 25], ["≤ 29", 29]]
const SORTS := [["ovr", "Nível"], ["value", "Valor"], ["age", "Idade"]]
const MAX_ROWS := 40

var _tab := "search"
var _group := 0
var _age := 0
var _sort := "ovr"
var _upgrades := false
var _affordable := false


func _init() -> void:
	nav_tab = "market"
	screen_title = "Mercado"


func setup(p: Dictionary) -> void:
	super.setup(p)
	_tab = p.get("tab", "search")
	_group = int(p.get("group", 0))
	_upgrades = bool(p.get("upgrades", false))


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
	var trow := UIKit.hbox(8)
	var n_offers := TransferManager.pending_offers(w).size()
	for t in TABS:
		var key: String = t[0]
		var text: String = t[1]
		if key == "offers" and n_offers > 0:
			text += " (%d)" % n_offers
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


func _group_chips(c: VBoxContainer) -> void:
	var g := ButtonGroup.new()
	var row := UIKit.hbox(8)
	for i in GROUPS.size():
		var idx := i
		var chip := UIKit.chip(GROUPS[i], i == _group, g, func():
			_group = idx
			refresh())
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	_group_chips(c)
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
	c.add_child(arow)
	var frow := UIKit.hbox(6)
	var up := UIKit.chip("Só reforços", _upgrades, null, func():
		_upgrades = not _upgrades
		refresh())
	up.add_theme_font_size_override(&"font_size", 17)
	frow.add_child(up)
	var af := UIKit.chip("Cabe no orçamento", _affordable, null, func():
		_affordable = not _affordable
		refresh())
	af.add_theme_font_size_override(&"font_size", 17)
	frow.add_child(af)
	frow.add_child(UIKit.spacer())
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
	var list: Array = []
	for p: Player in w.players.values():
		if p.club_id < 0 or p.club_id == club.id or p.retiring:
			continue
		if _group > 0 and Pos.group(p.position) != _group - 1:
			continue
		if p.age(w.year) > max_age:
			continue
		var est := PlayerRowView.estimate(w, p, p.overall)
		if _upgrades and est <= weakest[Pos.group(p.position)]:
			continue
		if _affordable and TransferManager.asking_price(w, p) > club.transfer_budget:
			continue
		list.append([p, est])
	match _sort:
		"value":
			list.sort_custom(func(a, b): return a[0].value > b[0].value)
		"age":
			list.sort_custom(func(a, b): return a[0].age(w.year) < b[0].age(w.year) or (a[0].age(w.year) == b[0].age(w.year) and a[1] > b[1]))
		_:
			list.sort_custom(func(a, b): return a[1] > b[1] or (a[1] == b[1] and a[0].value < b[0].value))
	c.add_child(UIKit.label("%s encontrados%s. O nível de jogadores de outros clubes é uma estimativa dos seus olheiros." % [Fmt.plural(list.size(), "jogador", "jogadores"), " (mostrando %d)" % MAX_ROWS if list.size() > MAX_ROWS else ""], "Small", true))
	for i in mini(MAX_ROWS, list.size()):
		var p: Player = list[i][0]
		var pid := p.id
		c.add_child(PlayerRowView.make(w, p, {"mode": "market"}, func(): UIManager.push("player", {"id": pid})))
	if list.is_empty():
		c.add_child(UIKit.label("Ninguém com esse perfil. Tente afrouxar os filtros.", "Muted", true))


func _free_tab(c: VBoxContainer, w: GameWorld) -> void:
	_group_chips(c)
	var list: Array = []
	for p: Player in w.free_agents():
		if p.retiring:
			continue
		if _group > 0 and Pos.group(p.position) != _group - 1:
			continue
		list.append(p)
	list.sort_custom(func(a: Player, b: Player): return a.overall > b.overall)
	c.add_child(UIKit.label("Jogadores sem clube podem ser contratados a qualquer momento, sem taxa, só com salário.", "Small", true))
	for i in mini(MAX_ROWS, list.size()):
		var p: Player = list[i]
		var pid := p.id
		c.add_child(PlayerRowView.make(w, p, {"mode": "market"}, func(): UIManager.push("player", {"id": pid})))
	if list.is_empty():
		c.add_child(UIKit.label("Nenhum jogador livre nessa posição agora.", "Muted"))


func _offers_tab(c: VBoxContainer, w: GameWorld) -> void:
	var offers := TransferManager.pending_offers(w)
	if offers.is_empty():
		c.add_child(UIKit.label("Nenhuma proposta pelo seu elenco no momento. Com a janela aberta, clubes interessados aparecem aqui — jogadores anunciados à venda atraem mais propostas.", "Muted", true))
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
