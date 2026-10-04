extends BaseScreen
## Elenco: filtros por setor, ordenação e acesso rápido a escalação e perfil.

const FILTERS := ["Todos", "GOL", "DEF", "MEI", "ATA"]
const VIEWS := ["Lista", "Números", "Profundidade", "Papéis"]
const SORTS := [["pos", "Posição"], ["ovr", "Overall"], ["form", "Nota"], ["cond", "Condição"], ["age", "Idade"], ["contract", "Contrato"], ["value", "Valor"]]
## Recortes rápidos da lista (tocáveis também nos alertas do resumo).
const QUICK := [["all", "Todos"], ["ok", "Disponíveis"], ["hurt", "Lesionados"], ["exp", "Contrato acabando"], ["u21", "Sub-21"], ["tired", "Cansados"]]

var _filter := 0
var _quick := "all"
var _sort := "pos"
var _view := 0


func _init() -> void:
	nav_tab = "squad"
	screen_title = "Elenco"
	max_content_width = 1700.0


## Resumo do elenco: tamanho, idade, estrangeiros (com a regra da liga), crias da casa, força do
## time titular, lesionados e folha salarial.
func _summary_card(w: GameWorld, club: Club, squad: Array) -> Control:
	var card := UIKit.card("Card", 8)
	var foreign := 0
	var home := 0
	var hurt := 0
	var expiring := 0
	for p: Player in squad:
		if p.nationality != club.nation:
			foreign += 1
		if Graduates.origin_of(p.spells, p.birth_year) == club.id:
			home += 1
		if p.injury_weeks > 0:
			hurt += 1
		if p.contract_end <= w.year:
			expiring += 1
	var xi := 0.0
	if club.sheet != null:
		xi = ClubAI.lineup_strength(w, club.sheet.formation, club.sheet.starters) / 11.0
	var ages := 0.0
	var cond := 0.0
	var mor := 0.0
	for p: Player in squad:
		ages += p.age(w.year)
		cond += p.condition
		mor += p.morale
	var n := maxf(1.0, squad.size())
	# Tamanho e idade já estão no subtítulo da barra: aqui só o que muda de rodada a rodada.
	var r1 := UIKit.hbox(4)
	r1.add_child(UIKit.stat(str(int(round(xi))), "força titular", UIColors.ACCENT))
	r1.add_child(UIKit.stat("%d%%" % int(round(cond / n)), "condição", UIColors.GREEN if cond / n >= 85.0 else UIColors.ORANGE))
	r1.add_child(UIKit.stat(UIColors.morale_label(mor / n), "moral", UIColors.morale_color(mor / n)))
	var rule := SquadRules.describe(club)
	if rule != "":
		# Com regra de estrangeiros na liga: quantos estão entre os relacionados, do limite.
		var used := SquadRules.count(w, club, (club.sheet.starters + club.sheet.bench) if club.sheet != null else [])
		var lim := int(SquadRules.limit(club)["max"])
		r1.add_child(UIKit.stat("%d/%d" % [used, lim], "estrangeiros", UIColors.ORANGE if used > lim else UIColors.TEXT))
	else:
		r1.add_child(UIKit.stat(str(foreign), "estrangeiros"))
	card.add_child(r1)
	# Alertas viram atalhos para o recorte da lista.
	var alerts := UIKit.hbox(8)
	if hurt > 0:
		alerts.add_child(_alert_chip(Fmt.plural(hurt, "lesionado", "lesionados"), "hurt"))
	if expiring > 0:
		alerts.add_child(_alert_chip(Fmt.plural(expiring, "contrato acabando", "contratos acabando"), "exp"))
	if alerts.get_child_count() > 0:
		card.add_child(alerts)
	var fin := FinanceManager.summary(w, club)
	var bill := UIKit.hbox(8)
	bill.add_child(UIKit.label("Folha salarial", "Muted"))
	var bl := UIKit.label("%s / %s" % [Fmt.money_month(fin["wage_bill"]), Fmt.money(fin["wage_budget"])], "H3")
	bl.add_theme_color_override(&"font_color", UIColors.RED if fin["wage_bill"] > fin["wage_budget"] else UIColors.TEXT)
	bill.add_child(UIKit.spacer())
	bill.add_child(bl)
	card.add_child(bill)
	return UIKit.card_panel(card)


func _alert_chip(text: String, key: String) -> Control:
	var b := UIKit.button(text, "ChipButton", func():
		_quick = key
		_view = 0
		refresh())
	b.add_theme_color_override(&"font_color", UIColors.ORANGE)
	b.add_theme_font_size_override(&"font_size", 17)
	return b


func _passes_quick(w: GameWorld, p: Player) -> bool:
	match _quick:
		"ok":
			return p.is_available()
		"hurt":
			return p.injury_weeks > 0
		"exp":
			return p.contract_end <= w.year
		"u21":
			return p.age(w.year) <= 21
		"tired":
			return p.condition < 85.0
	return true


## Colunas de números nas linhas conforme a largura (tablet): jogos, gols, assistências e nota;
## com mais espaço, também valor e salário.
static func stat_cols(width: float) -> int:
	if width >= 1250.0:
		return 6
	if width >= 900.0:
		return 4
	return 0


func setup(p: Dictionary) -> void:
	super.setup(p)
	_sort = p.get("sort", "pos")
	if p.has("tab"):
		_view = clampi(int(p["tab"]), 0, VIEWS.size() - 1)


func refresh() -> void:
	var w := world()
	if w == null:
		return
	var club := w.user_club()
	var squad := w.squad(club)
	var ages := 0.0
	for p in squad:
		ages += p.age(w.year)
	screen_subtitle = "%d jogadores · idade média %s" % [squad.size(), Fmt._decimal(ages / maxf(1.0, squad.size()), 1)]
	UIManager.refresh_chrome()
	var c := content()
	UIKit.clear(c)
	# A ação principal (escalar) em destaque; os atalhos do elenco em blocos iguais, ícone sobre o texto.
	c.add_child(UIKit.button("Escalação e tática", "PrimaryButton", func(): UIManager.push("prematch", {"edit": true}), "tactics"))
	var top := GridContainer.new()
	top.columns = 4
	top.add_theme_constant_override(&"h_separation", 8)
	for it in [["Estatísticas", "team_stats", "chart"], ["Camisas", "numbers", "hash"], ["Contratos", "contracts", "money"], ["Vestiário", "dressing_room", "heart"]]:
		var dest := String(it[1])
		var b := UIKit.button(String(it[0]), "GhostButton", func(): UIManager.push(dest), String(it[2]))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.custom_minimum_size.y = 92
		b.add_theme_font_size_override(&"font_size", 17)
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		top.add_child(b)
	c.add_child(top)
	c.add_child(_summary_card(w, club, squad))
	var vitems: Array = []
	for i in VIEWS.size():
		vitems.append([str(i), VIEWS[i]])
	var vrow := UIKit.tabs(vitems, str(_view), func(key: String):
		_view = int(key)
		refresh())
	c.add_child(vrow)
	if _view == 1:
		c.add_child(TeamStatsScreen.squad_table(w, club))
		return
	if _view == 2:
		_build_depth(w, club, c)
		return
	if _view == 3:
		_build_roles(w, club, c)
		return
	var fitems: Array = []
	for i in FILTERS.size():
		fitems.append([str(i), FILTERS[i]])
	var frow := UIKit.segment(fitems, str(_filter), func(key: String):
		_filter = int(key)
		refresh())
	c.add_child(frow)
	# Recorte e ordem numa fileira só, cada um abrindo a sua lista (antes eram duas barras de
	# abas rolando para o lado, uma em cima da outra).
	var picks := UIKit.hbox(8)
	picks.add_child(_picker("Mostrar", "list", QUICK, _quick, func(k: String):
		_quick = k
		refresh()))
	picks.add_child(_picker("Ordenar", "down", SORTS, _sort, func(k: String):
		_sort = k
		refresh()))
	c.add_child(picks)
	var list: Array = []
	for p in squad:
		if (_filter == 0 or Pos.group(p.position) == _filter - 1) and _passes_quick(w, p):
			list.append(p)
	if list.is_empty():
		c.add_child(UIKit.label("Ninguém nesse recorte.", "Muted", true))
	# Tela larga (tablet): jogos, gols, assistências, nota, valor e salário na própria linha
	var ncols := stat_cols(content_width())
	if ncols > 0 and not list.is_empty():
		c.add_child(PlayerRowView.stat_header("squad", ncols))
	var y := w.year
	match _sort:
		"ovr":
			list.sort_custom(func(a, b): return a.ovr_f > b.ovr_f)
		"age":
			list.sort_custom(func(a, b): return a.age(y) < b.age(y))
		"form":
			list.sort_custom(func(a, b): return ClubRecords.rating(a, int(a.season_totals()[0])) > ClubRecords.rating(b, int(b.season_totals()[0])))
		"cond":
			list.sort_custom(func(a, b): return a.condition < b.condition)
		"contract":
			list.sort_custom(func(a, b): return a.contract_end < b.contract_end or (a.contract_end == b.contract_end and a.ovr_f > b.ovr_f))
		"value":
			list.sort_custom(func(a, b): return a.value > b.value)
		_:
			list.sort_custom(func(a, b):
				var ia := Pos.DISPLAY_ORDER.find(a.position)
				var ib := Pos.DISPLAY_ORDER.find(b.position)
				if ia != ib:
					return ia < ib
				return a.ovr_f > b.ovr_f)
	var last_group := -1
	for p: Player in list:
		if _sort == "pos" and Pos.group(p.position) != last_group:
			last_group = Pos.group(p.position)
			var cnt := 0
			var ovr := 0
			for q: Player in list:
				if Pos.group(q.position) == last_group:
					cnt += 1
					ovr += q.overall
			c.add_child(UIKit.section("%s · %d · média %d" % [Pos.GROUP_NAMES[last_group], cnt, int(round(float(ovr) / maxi(1, cnt)))]))
		var pid := p.id
		c.add_child(PlayerRowView.make(w, p, {"mode": "squad", "cols": ncols}, func(): UIManager.push("player", {"id": pid})))
	var out := TransferManager.loaned_out(w)
	if not out.is_empty():
		c.add_child(UIKit.section("Emprestados"))
		for p: Player in out:
			var pid := p.id
			c.add_child(PlayerRowView.make(w, p, {"mode": "market"}, func(): UIManager.push("player", {"id": pid})))


## Botão "Rótulo: escolha atual" que abre as opções numa folha.
func _picker(caption: String, icon_name: String, items: Array, selected: String, cb: Callable) -> Button:
	var cur := ""
	for it: Array in items:
		if String(it[0]) == selected:
			cur = tr(String(it[1]))
	var b := UIKit.button("%s: %s" % [tr(caption), cur], "GhostButton", func():
		var v := UIKit.vbox(12)
		v.add_child(UIKit.label(caption, "Title"))
		v.add_child(UIKit.option_grid(items, selected, func(k: String):
			UIManager.close_modal()
			cb.call(k), 2))
		UIManager.show_modal(v, true), icon_name)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if selected != String(items[0][0]):
		for st in [&"font_color", &"font_hover_color", &"icon_normal_color", &"icon_hover_color"]:
			b.add_theme_color_override(st, UIColors.ACCENT)
	return b


## Profundidade: os três melhores por posição e onde falta gente boa.
func _build_depth(w: GameWorld, club: Club, c: VBoxContainer) -> void:
	for row in SquadManager.depth(w, club):
		var card := UIKit.card("Card", 4)
		var head := UIKit.hbox(8)
		var codes: Array = []
		for pos in row["pos"]:
			codes.append(Pos.code(pos))
		head.add_child(UIKit.label("/".join(codes), "H3"))
		head.add_child(UIKit.spacer())
		if row["weak"]:
			head.add_child(UIKit.colored("Carência", UIColors.ORANGE, "Caps"))
		card.add_child(head)
		if row["best"].is_empty():
			card.add_child(UIKit.colored("Ninguém do elenco joga aqui.", UIColors.RED, "Small"))
		for item in row["best"]:
			var p: Player = item[0]
			var pid := p.id
			var line := UIKit.hbox(8)
			var nm := UIKit.label("%s · %s" % [p.display_name(), PlayStyle.of(p)], "Small")
			nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			line.add_child(nm)
			if not p.is_available():
				line.add_child(UIKit.icon_rect("cross", 18, UIColors.RED))
			line.add_child(UIKit.badge(int(round(item[1])), 48, 32, 20))
			card.add_child(UIKit.tap_row(line, func(): UIManager.push("player", {"id": pid})))
		c.add_child(UIKit.card_panel(card))


## Papéis: o que foi prometido a cada jogador. Mexer aqui mexe na moral.
func _build_roles(w: GameWorld, club: Club, c: VBoxContainer) -> void:
	var want := SquadManager.wants_more_minutes(w, club)
	if not want.is_empty():
		var names: Array = []
		for p: Player in want:
			names.append(p.display_name())
		c.add_child(UIKit.colored("Querem jogar mais: " + ", ".join(names) + ".", UIColors.ORANGE, "Small", true))
	var squad := w.squad(club)
	for st in [Player.STATUS_STAR, Player.STATUS_STARTER, Player.STATUS_ROTATION, Player.STATUS_PROSPECT, Player.STATUS_BACKUP]:
		var list: Array = []
		for p: Player in squad:
			if p.squad_status == st:
				list.append(p)
		if list.is_empty():
			continue
		list.sort_custom(func(a, b): return a.ovr_f > b.ovr_f)
		c.add_child(UIKit.section("%s (%d)" % [Player.STATUS_NAMES[st], list.size()]))
		for p: Player in list:
			var pp := p
			c.add_child(PlayerRowView.make(w, p, {"mode": "squad"}, func(): _pick_status(pp)))


func _pick_status(p: Player) -> void:
	var w := world()
	var club := w.user_club()
	var v := UIKit.vbox(8)
	v.add_child(UIKit.label("Papel de %s" % p.display_name(), "Title"))
	v.add_child(UIKit.label("Hoje: %s · %s" % [Player.STATUS_NAMES[p.squad_status], UIColors.morale_label(p.morale)], "Small"))
	for st in Player.STATUS_NAMES.size():
		var s := st
		var box := UIKit.vbox(2)
		var head := UIKit.hbox(8)
		head.add_child(UIKit.label(Player.STATUS_NAMES[s], "H3"))
		head.add_child(UIKit.spacer())
		var react := SquadManager.status_reaction(p, s)
		if s == p.squad_status:
			head.add_child(UIKit.colored("atual", UIColors.GREEN, "Caps"))
		elif react != "":
			head.add_child(UIKit.colored(react, UIColors.GREEN if react == "Vai gostar." else UIColors.ORANGE, "Small"))
		box.add_child(head)
		v.add_child(UIKit.tap_row(box, func():
			var err := SquadManager.set_status(w, club, p, s)
			if err != "":
				UIManager.toast(err, UIColors.RED)
				return
			UIManager.close_modal()
			refresh()))
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(0, 760)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	UIManager.show_modal(sc, true)
