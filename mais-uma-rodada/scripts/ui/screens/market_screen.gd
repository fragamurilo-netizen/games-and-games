extends BaseScreen
## Mercado: busca de jogadores, livres, propostas recebidas e jogadores à venda.

const TABS := [["search", "Buscar"], ["moneyball", "Moneyball"], ["free", "Livres"], ["pre", "Pré-contrato"], ["scout", "Olheiros"], ["shortlist", "Lista"], ["offers", "Propostas"], ["listed", "À venda"], ["moves", "Movimentações"]]
const GROUPS := ["Todos", "GOL", "DEF", "MEI", "ATA"]
const AGES := [["Todas", 99], ["≤ 21", 21], ["≤ 25", 25], ["≤ 29", 29]]
const SORTS := [["rel", "Relevância"], ["ovr", "Nível"], ["value", "Valor"], ["price", "Preço"], ["age", "Idade"]]
const MOVE_SCOPES := [["mine", "Seu clube"], ["league", "Sua liga"], ["all", "Mundo"]]
const MOVE_SORTS := [["recent", "Recentes"], ["fee", "Maiores"]]
## Linhas levadas para a tabela (ela mostra 80 e "mostrar mais").
const MAX_ROWS := 200

var _tab := "search"
var _filters_open := false
var _group := 0
var _age := 0
var _sort := "rel"
var _sug_turn := -1
var _sug: Dictionary = {}
var _upgrades := false
var _affordable := false
var _origin := "all"
var _scouted_only := false
var _listed_only := false
var _expiring_only := false
var _query := ""
var _move_scope := "league"
var _move_sort := "recent"
## Colunas de números (jogos, gols, assistências, nota) nas linhas quando sobra largura (tablet).
var _row_cols := 0


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
	max_content_width = 1700.0
	c.add_child(_banner(w, club))
	var n_offers := TransferManager.pending_offers(w).size()
	var n_short := Shortlist.news_count(w)
	var items: Array = []
	for t in TABS:
		var text: String = t[1]
		if t[0] == "offers" and n_offers > 0:
			text += " (%d)" % n_offers
		elif t[0] == "shortlist" and n_short > 0:
			text += " (%d)" % n_short
		items.append([t[0], text])
	var trow := UIKit.scroll_tabs(items, _tab, func(key: String):
		_tab = key
		refresh())
	c.add_child(trow)
	match _tab:
		"free":
			_free_tab(c, w)
		"pre":
			_pre_tab(c, w, club)
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
		"moneyball":
			c.add_child(MoneyballView.build(w, club, content_width(), func(): refresh()))
		_:
			_search_tab(c, w, club)


## Situação do mercado em duas linhas: janela e dinheiro. Nada de painel de indicadores.
func _banner(w: GameWorld, club: Club) -> Control:
	var out := UIKit.vbox(0)
	var open := w.transfer_window_open()
	var txt := ""
	if open:
		txt = "Janela aberta até a rodada %d" % (w.window_end_day() + 1)
	else:
		var nxt := w.next_window_day()
		txt = "Janela fechada · reabre na rodada %d" % (nxt + 1) if nxt >= 0 else "Janela fechada · reabre na próxima temporada"
	out.add_child(UIKit.colored(txt, UIColors.GREEN if open else UIColors.ORANGE, "", true))
	var fin := FinanceManager.summary(w, club)
	var over: bool = fin["wage_bill"] > fin["wage_budget"]
	var rules := DatabaseManager.squad_rules()
	var line := RichTextLabel.new()
	line.bbcode_enabled = true
	line.fit_content = true
	line.scroll_active = false
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_color_override(&"default_color", UIColors.MUTED)
	var hi := UIColors.TEXT.to_html(false)
	line.text = "Verba [color=#%s]%s[/color] · folha [color=#%s]%s[/color] de %s · elenco %d (%d–%d)" % [
		hi, Fmt.money(club.transfer_budget), (UIColors.RED if over else UIColors.TEXT).to_html(false), Fmt.money_month(fin["wage_bill"]),
		Fmt.money(fin["wage_budget"]), club.player_ids.size(), int(rules["min_players"]), int(rules["max_players"])]
	out.add_child(line)
	return out


## Nacional/estrangeiro sempre em relação ao país do seu clube.
func _origin_chips(c: VBoxContainer, club: Club) -> void:
	var row := UIKit.hbox(10)
	var fl := UIKit.flag(club.nation, 30)
	fl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(fl)
	var seg := UIKit.segment(Scouting.ORIGINS, _origin, func(key: String):
		_origin = key
		refresh())
	seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(seg)
	c.add_child(row)


## Rótulo pequeno acima de um grupo de filtros.
func _filter_label(text: String) -> Label:
	return UIKit.label(text, "Caps")


func _group_chips(c: VBoxContainer) -> void:
	var items: Array = []
	for i in GROUPS.size():
		items.append([str(i), GROUPS[i]])
	c.add_child(UIKit.segment(items, str(_group), func(key: String):
		_group = int(key)
		refresh()))


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


var _table_state := {}
var _free_state := {}
var _pre_state := {}


func _search_tab(c: VBoxContainer, w: GameWorld, club: Club) -> void:
	# Busca primeiro; filtros numa folha; resultados numa tabela que ordena pelo cabeçalho.
	var bar := UIKit.hbox(10)
	# Busca pelo nome: só a lista é refeita enquanto digita, para o campo não perder o foco.
	var le := LineEdit.new()
	le.placeholder_text = "Buscar pelo nome"
	le.text = _query
	le.clear_button_enabled = true
	le.right_icon = UIKit.icon_sized("search", 30)
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(le)
	var n_on := _active_filters()
	var fb := UIKit.button(("Filtros · %d" % n_on) if n_on > 0 else "Filtros", "ChipButton", func(): _filters_sheet(w, club))
	fb.custom_minimum_size.y = 64
	if n_on > 0:
		fb.add_theme_color_override(&"font_color", UIColors.ink(UIColors.ACCENT))
	bar.add_child(fb)
	c.add_child(bar)
	var results := UIKit.vbox(10)
	results.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_child(results)
	le.text_changed.connect(func(q: String):
		_query = q
		_fill_search(results, w, club))
	_fill_search(results, w, club)


func _active_filters() -> int:
	return int(_group > 0) + int(_origin != "all") + int(_age > 0) + int(_upgrades) + int(_affordable) + int(_listed_only) + int(_expiring_only) + int(_scouted_only)


## Filtros da busca numa folha: setor, origem, idade e recortes. Cada toque já filtra a lista.
func _filters_sheet(w: GameWorld, club: Club) -> void:
	var fc := UIKit.vbox(10)
	var head := UIKit.hbox(8)
	var t := UIKit.label("Filtros", "H2")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(UIKit.button("Limpar", "TextButton", func():
		_group = 0
		_origin = "all"
		_age = 0
		_upgrades = false
		_affordable = false
		_listed_only = false
		_expiring_only = false
		_scouted_only = false
		UIManager.close_modal()
		refresh()))
	fc.add_child(head)
	_filter_controls(fc, club)
	fc.add_child(UIKit.button("Ver resultados", "PrimaryButton", func():
		UIManager.close_modal()
		refresh()))
	UIManager.show_modal(fc, true)


func _filter_controls(fc: VBoxContainer, club: Club) -> void:
	fc.add_child(_filter_label("Setor"))
	_group_chips(fc)
	fc.add_child(_filter_label("Origem"))
	_origin_chips(fc, club)
	fc.add_child(_filter_label("Idade"))
	var ages: Array = []
	for i in AGES.size():
		ages.append([str(i), AGES[i][0]])
	fc.add_child(UIKit.segment(ages, str(_age), func(key: String):
		_age = int(key)
		refresh()))
	fc.add_child(_filter_label("Mostrar só"))
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
	fc.add_child(frow)


func _fill_search(results: VBoxContainer, w: GameWorld, club: Club) -> void:
	UIKit.clear(results)
	var weakest := _weakest_starter_by_group(w, club)
	var max_age: int = AGES[_age][1]
	var q := _query.strip_edges().to_lower()
	var budget := float(maxi(1, club.transfer_budget))
	if q == "" and _sort == "rel":
		var sug := _suggest_card(w, club)
		if sug != null:
			results.add_child(sug)
	var list: Array = []
	# O mundo tem ~27 mil jogadores: a avaliação e a relevância de cada um ficam guardadas enquanto
	# a tela está aberta (trocar filtro, ordem ou digitar o nome só filtra de novo), e o preço
	# pedido só é calculado para "cabe no orçamento" e "preço".
	# A ordem vem do cabeçalho da tabela; sem coluna escolhida, relevância.
	_sort = String(_table_state.get("sort", "rel"))
	if not _sort in ["ovr", "value", "price", "age"]:
		_sort = "rel"
	var need_ask := _affordable or _sort == "price"
	var scouted: Dictionary = w.stats["scouting"]["ids"] if w.stats.has("scouting") else {}
	var ask_memo := {"on": true}
	for e: Array in _search_base(w, club, weakest, budget, scouted):
		var p: Player = e[0]
		if q != "" and not _name_key(p).contains(q):
			continue
		if _group > 0 and Pos.group(p.position) != _group - 1:
			continue
		if p.age(w.year) > max_age or not Scouting.origin_ok(p, club, _origin):
			continue
		if _scouted_only and not scouted.has(str(p.id)):
			continue
		if _listed_only and not p.transfer_listed:
			continue
		if _expiring_only and p.contract_years_left(w.year) > 0:
			continue
		var est: int = e[1]
		if _upgrades and est <= weakest[Pos.group(p.position)]:
			continue
		var ask := TransferManager.asking_price(w, p, ask_memo) if need_ask else 0
		if _affordable and ask > club.transfer_budget:
			continue
		list.append([p, est, ask, e[2]])
	var total := list.size()
	# Só as MAX_ROWS primeiras aparecem: um corte pela chave principal (ordenação nativa de números)
	# e a ordem completa só entre quem passou do corte (antes: ordenar os ~26 mil com lambdas).
	match _sort:
		"value":
			list = _top(list, func(e: Array) -> float: return float(e[0].value), true)
			list.sort_custom(func(a, b): return a[0].value > b[0].value)
		"price":
			list = _top(list, func(e: Array) -> float: return float(e[2]), false)
			list.sort_custom(func(a, b): return a[2] < b[2] or (a[2] == b[2] and a[1] > b[1]))
		"age":
			list = _top(list, func(e: Array) -> float: return float(e[0].age(w.year)), false)
			list.sort_custom(func(a, b): return a[0].age(w.year) < b[0].age(w.year) or (a[0].age(w.year) == b[0].age(w.year) and a[1] > b[1]))
		"ovr":
			list = _top(list, func(e: Array) -> float: return float(e[1]), true)
			list.sort_custom(func(a, b): return a[1] > b[1] or (a[1] == b[1] and a[0].value < b[0].value))
		_:
			list = _top(list, func(e: Array) -> float: return float(e[3]), true)
			list.sort_custom(func(a, b): return float(a[3]) > float(b[3]))
	var shown := mini(MAX_ROWS, list.size())
	var head := "%s" % Fmt.plural(total, "jogador encontrado", "jogadores encontrados")
	if total > shown:
		head += " · os %d primeiros %s" % [shown, "mais relevantes" if _sort == "rel" else "pela coluna escolhida"]
	results.add_child(UIKit.label(head, "Muted", true))
	if list.is_empty():
		results.add_child(UIKit.state_block("empty", "Ninguém com esse perfil.", "Tente outro nome ou menos filtros.", "Limpar filtros" if _active_filters() > 0 else "", func():
			_group = 0
			_origin = "all"
			_age = 0
			_upgrades = false
			_affordable = false
			_listed_only = false
			_expiring_only = false
			_scouted_only = false
			refresh()))
		return
	var players: Array = []
	for i in shown:
		players.append(list[i][0])
	var tbl := PlayerTable.make(w, players, "market", _table_state, func(p: Player): UIManager.push("player", {"id": p.id}), _market_cols(w, club, weakest))
	tbl.sort_changed.connect(func(_k: String, _d: bool): _fill_search.call_deferred(results, w, club))
	results.add_child(tbl)


## Colunas do mercado além das comuns: quanto melhora o seu pior titular no setor e o salário
## que ele pede (laranja quando não cabe na folha).
func _market_cols(w: GameWorld, club: Club, weakest: Array) -> Array:
	var fin := FinanceManager.summary(w, club)
	var room := int(fin["wage_budget"]) - int(fin["wage_bill"])
	var gain := func(p: Player) -> int:
		var ref := float(weakest[Pos.group(p.position)])
		return PlayerRowView.estimate(w, p, p.overall) - int(round(ref)) if ref < 98.0 else 0
	return [
		{"key": "gain", "title": "± tit.", "w": 72, "tip": "Diferença para o seu titular mais fraco no setor",
			"text": func(p: Player) -> String:
				var d: int = gain.call(p)
				return ("+%d" % d) if d > 0 else str(d),
			"sort": func(p: Player) -> int: return gain.call(p),
			"color": func(p: Player) -> Color:
				var d: int = gain.call(p)
				return UIColors.GREEN if d > 0 else (UIColors.MUTED if d == 0 else UIColors.ORANGE)},
		{"key": "wask", "title": "Pede", "w": 130, "tip": "Salário pretendido",
			"text": func(p: Player) -> String: return Fmt.money_month(TransferManager.wage_ask(w, p, club)),
			"sort": func(p: Player) -> float: return float(TransferManager.wage_ask(w, p, club)),
			"color": func(p: Player) -> Color: return UIColors.TEXT if TransferManager.wage_ask(w, p, club) <= room else UIColors.ORANGE},
	]


var _base: Array = [] # [jogador, avaliação, relevância] de quem pode ser contratado
var _base_key := ""


## Base da busca: todos os jogadores de outros clubes com avaliação e relevância, refeita quando
## algo que pesa nelas muda (rodada, verba, elenco, olheiros, jogadores novos) ou a tela reaparece.
func _search_base(w: GameWorld, club: Club, weakest: Array, budget: float, scouted: Dictionary) -> Array:
	var key := "%d|%d|%d|%d|%d|%s" % [w.current_turn(), club.transfer_budget, w.players.size(), scouted.size(), club.player_ids.size(), str(weakest)]
	if key == _base_key:
		return _base
	_base_key = key
	_base = []
	for p: Player in w.players.values():
		if p.club_id < 0 or p.club_id == club.id or p.retiring:
			continue
		var est := PlayerRowView.estimate(w, p, p.overall)
		_base.append([p, est, _relevance(w, p, float(est) - float(weakest[Pos.group(p.position)]), budget)])
	return _base


func on_show() -> void:
	_base_key = "" # voltando de outra tela (negociação, perfil): o mundo pode ter mudado
	super.on_show()


## Nome e nome completo em minúsculas, guardados enquanto a tela existe: a busca por nome roda a
## cada letra digitada e passava por todos os jogadores montando os textos de novo.
var _names := {}


func _name_key(p: Player) -> String:
	var k: Variant = _names.get(p.id)
	if k == null:
		k = p.display_name().to_lower() + "\n" + p.full_name().to_lower()
		_names[p.id] = k
	return k


## Quem pode estar entre as MAX_ROWS primeiras pela chave principal `key` (maior primeiro se
## `desc`): todos os empatados no corte entram, então a ordem completa depois dá o mesmo topo.
static func _top(list: Array, key: Callable, desc: bool) -> Array:
	if list.size() <= MAX_ROWS:
		return list
	var keys := PackedFloat64Array()
	keys.resize(list.size())
	for i in list.size():
		keys[i] = key.call(list[i])
	var sorted := keys.duplicate()
	sorted.sort()
	var cut: float = sorted[sorted.size() - MAX_ROWS] if desc else sorted[MAX_ROWS - 1]
	var out: Array = []
	for i in list.size():
		if (keys[i] >= cut) if desc else (keys[i] <= cut):
			out.append(list[i])
	return out


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
	if list.is_empty():
		c.add_child(UIKit.state_block("empty", "Nenhum jogador livre nessa posição agora."))
		return
	c.add_child(UIKit.label(Fmt.plural(list.size(), "jogador livre", "jogadores livres"), "Muted"))
	c.add_child(PlayerTable.make(w, list.slice(0, MAX_ROWS), "market", _free_state, func(p: Player): UIManager.push("player", {"id": p.id})))


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
	var terms: Array = []
	if o.inst > 1:
		terms.append("em %d parcelas (%s agora)" % [o.inst, Fmt.money(int(ceil(float(o.fee) / o.inst)))])
	if o.addon > 0:
		terms.append("+ %s após %d jogos" % [Fmt.money(o.addon), DealTerms.ADDON_APPS])
	if o.so > 0.0:
		terms.append("%d%% de revenda para você" % int(round(o.so * 100.0)))
	if o.bb > 0:
		terms.append("recompra por %s até %d" % [Fmt.money(o.bb), w.year + DealTerms.BUYBACK_YEARS])
	if not terms.is_empty():
		var tl := UIKit.label(" · ".join(PackedStringArray(terms)), "Small", true)
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(tl)
	var pid := p.id
	card.add_child(PlayerRowView.make(w, p, {"mode": "squad"}, func(): UIManager.push("player", {"id": pid})))
	if p.trait_sum("ambition") >= 25.0 and buyer.reputation > w.user_club().reputation:
		card.add_child(UIKit.colored("%s quer ir." % p.display_name(), UIColors.ORANGE, "Small"))
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
		var clr := UIKit.hbox(8)
		if o.so <= 0.0:
			var sob := UIKit.button("Pedir 15% de revenda", "ChipButton", func(): _respond(o, "so", 0), "plus")
			sob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			clr.add_child(sob)
		if o.bb <= 0 and p.age(w.year) <= 23:
			var bbb := UIKit.button("Pedir recompra", "ChipButton", func(): _respond(o, "bb", 0), "back")
			bbb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			clr.add_child(bbb)
		if clr.get_child_count() > 0:
			card.add_child(clr)
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
			Sfx.play("sign")
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
		c.add_child(UIKit.label("Nenhum jogador anunciado.", "Muted", true))
		return
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
	head.add_child(UIKit.label("Olheiro-chefe %s · %s por missão" % [q, Fmt.plural(Scouting.capacity(w), "jogador", "jogadores")], "", true))
	card.add_child(head)
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
	var go := UIKit.button("Enviar olheiro" if ready else "Olheiro em campo", "PrimaryButton" if ready else "GhostButton", func():
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
		c.add_child(UIKit.label("Nenhum relatório ainda.", "Muted", true))
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
		c.add_child(UIKit.label("Sua lista está vazia.", "Muted", true))
		return
	c.add_child(UIKit.label("%s na lista · máx. %d" % [Fmt.plural(list.size(), "jogador", "jogadores"), Shortlist.MAX_ENTRIES], "Small", true))
	# Quem tem novidade primeiro, depois pelo nível estimado.
	var rows: Array = []
	for p: Player in list:
		rows.append([p, Shortlist.changes(w, p), PlayerRowView.estimate(w, p, p.overall)])
	rows.sort_custom(func(a, b): return (not a[1].is_empty() and b[1].is_empty()) or (a[1].is_empty() == b[1].is_empty() and a[2] > b[2]))
	var cards: Array = []
	for r in rows:
		cards.append(_shortlist_card(w, r[0], r[1]))
	UIKit.columns(c, cards, content_width())


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
	var row := UIKit.hbox(10)
	var scope := UIKit.segment(MOVE_SCOPES, _move_scope, func(key: String):
		_move_scope = key
		refresh())
	scope.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scope.size_flags_stretch_ratio = 1.6
	row.add_child(scope)
	var sort := UIKit.segment(MOVE_SORTS, _move_sort, func(key: String):
		_move_sort = key
		refresh())
	sort.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sort)
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
	c.add_child(UIKit.label(Fmt.plural(list.size(), "transferência", "transferências"), "Small", true))
	for i in mini(MAX_ROWS, list.size()):
		c.add_child(_move_row(w, list[i], club))
	if list.is_empty():
		c.add_child(UIKit.label("Nenhuma transferência.", "Muted", true))


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
	box.add_child(PlayerRowView.make(w, p, {"mode": "market", "cols": _row_cols}, func(): UIManager.push("player", {"id": pid})))
	var info := UIKit.hbox(10)
	var est := PlayerRowView.estimate(w, p, p.overall)
	var ref := float(weakest[Pos.group(p.position)])
	if ref < 98.0:
		var d := est - int(round(ref))
		var txt := ("+%d sobre seu pior titular no setor" % d) if d > 0 else ("mesmo nível do seu titular" if d == 0 else "%d abaixo do seu titular" % d)
		info.add_child(UIKit.colored(txt, UIColors.GREEN if d > 0 else (UIColors.MUTED if d == 0 else UIColors.ORANGE), "Small"))
	info.add_child(UIKit.spacer())
	var wage := TransferManager.wage_ask(w, p, club)
	var fin := FinanceManager.summary(w, club)
	var room := int(fin["wage_budget"]) - int(fin["wage_bill"])
	info.add_child(UIKit.colored(Fmt.money_month(wage), UIColors.TEXT if wage <= room else UIColors.ORANGE, "Small"))
	var on := Shortlist.has(w, p)
	var star := UIKit.icon_button("star", func():
		if not Shortlist.has(w, p) and Shortlist.is_full(w):
			UIManager.toast("Sua lista está cheia (%d)." % Shortlist.MAX_ENTRIES, UIColors.ORANGE)
			return
		Shortlist.toggle(w, p)
		GameManager.save_now()
		refresh(), "Lista de observação")
	star.custom_minimum_size = Vector2(48, 44)
	star.modulate = UIColors.ACCENT if on else Color(1, 1, 1, 0.35)
	info.add_child(star)
	box.add_child(UIKit.margin(info, 12, 0, 8, 4))
	return box


# Lista de observação: ids em world.stats["watch"]


## Jogadores em último ano de contrato: podem assinar pré-contrato a partir da metade da temporada.
func _pre_tab(c: VBoxContainer, w: GameWorld, club: Club) -> void:
	var prog := TransferManager.season_progress(w)
	var head := UIKit.card("Card", 6)
	head.add_child(UIKit.section("Contratos terminando"))
	var pre_pill := UIKit.pill("PRÉ-CONTRATO LIBERADO" if prog >= 0.5 else "PRÉ-CONTRATO NO 2º TURNO", UIColors.GREEN if prog >= 0.5 else UIColors.ORANGE, 15)
	pre_pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	head.add_child(pre_pill)
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
	var total := list.size()
	list = _top(list, func(e: Array) -> float: return float(e[1]), true)
	list.sort_custom(func(a, b): return float(a[1]) > float(b[1]))
	c.add_child(UIKit.label("%s disponíveis%s." % [Fmt.plural(total, "jogador", "jogadores"), (" · %d já assinaram com outros clubes" % signed) if signed > 0 else ""], "Small", true))
	if list.is_empty():
		c.add_child(UIKit.state_block("empty", "Ninguém nesse setor."))
		return
	var players: Array = []
	for e in list.slice(0, MAX_ROWS):
		players.append(e[0])
	c.add_child(PlayerTable.make(w, players, "market", _pre_state, func(p: Player): UIManager.push("player", {"id": p.id}), _market_cols(w, club, weakest)))


## Sugestões do diretor de futebol: o setor mais carente e nomes que cabem no bolso.
func _suggest_card(w: GameWorld, club: Club) -> Control:
	if _sug_turn != w.current_turn():
		_sug = BoardRequests.suggestions(w)
		_sug_turn = w.current_turn()
	var ids: Array = _sug.get("ids", [])
	if ids.is_empty():
		return null
	var d := BoardRequests.director(w)
	var v := UIKit.vbox(4)
	v.add_child(UIKit.section_header("Indicação de %s · falta %s" % [String(d.get("name", "o diretor")), ["goleiro", "defesa", "meio-campo", "ataque"][int(_sug.get("group", 1))]]))
	var weakest := _weakest_starter_by_group(w, club)
	var players: Array = []
	for pid in ids.slice(0, 3):
		var p := w.player(int(pid))
		if p != null:
			players.append(p)
	if players.is_empty():
		return null
	v.add_child(PlayerTable.make(w, players, "market", {}, func(p: Player): UIManager.push("player", {"id": p.id}), _market_cols(w, club, weakest)))
	v.add_child(UIKit.gap(12))
	return v
