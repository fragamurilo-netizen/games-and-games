extends BaseScreen
## Elenco: filtros por setor, ordenação e acesso rápido a escalação e perfil.

const FILTERS := ["Todos", "GOL", "DEF", "MEI", "ATA"]
const VIEWS := ["Lista", "Profundidade", "Papéis"]
const SORTS := [["pos", "Posição"], ["ovr", "Overall"], ["age", "Idade"], ["contract", "Contrato"], ["value", "Valor"]]

var _filter := 0
var _sort := "pos"
var _view := 0


func _init() -> void:
	nav_tab = "squad"
	screen_title = "Elenco"


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
	var r1 := UIKit.hbox(4)
	r1.add_child(UIKit.stat(str(squad.size()), "jogadores"))
	r1.add_child(UIKit.stat(str(foreign), "estrangeiros"))
	r1.add_child(UIKit.stat(str(home), "crias da casa", UIColors.GREEN))
	r1.add_child(UIKit.stat(str(int(round(xi))), "força titular", UIColors.ACCENT))
	card.add_child(r1)
	var rule := SquadRules.describe(club)
	if rule != "":
		var used := SquadRules.count(w, club, (club.sheet.starters + club.sheet.bench) if club.sheet != null else [])
		var lim := int(SquadRules.limit(club)["max"])
		card.add_child(UIKit.colored("%s: %d/%d na escalação atual." % [rule, used, lim], UIColors.ORANGE if used > lim else UIColors.MUTED, "Small", true))
	var alerts: Array = []
	if hurt > 0:
		alerts.append("%d lesionado(s)" % hurt)
	if expiring > 0:
		alerts.append("%d contrato(s) acabando" % expiring)
	if not alerts.is_empty():
		card.add_child(UIKit.colored(" · ".join(PackedStringArray(alerts)), UIColors.ORANGE, "Small", true))
	var fin := FinanceManager.summary(w, club)
	var bill := UIKit.hbox(8)
	bill.add_child(UIKit.label("Folha salarial", "Muted"))
	var bl := UIKit.label("%s / %s" % [Fmt.money_month(fin["wage_bill"]), Fmt.money(fin["wage_budget"])], "H3")
	bl.add_theme_color_override(&"font_color", UIColors.RED if fin["wage_bill"] > fin["wage_budget"] else UIColors.TEXT)
	bill.add_child(UIKit.spacer())
	bill.add_child(bl)
	card.add_child(bill)
	return UIKit.card_panel(card)


func setup(p: Dictionary) -> void:
	super.setup(p)
	_sort = p.get("sort", "pos")


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
	var top := UIKit.hbox(10)
	var lineup := UIKit.button("Escalação e tática", "", func(): UIManager.push("prematch", {"edit": true}), "tactics")
	lineup.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(lineup)
	top.add_child(UIKit.button("Numeração", "", func(): UIManager.push("numbers"), "shirt"))
	c.add_child(top)
	c.add_child(_summary_card(w, club, squad))
	var gv := ButtonGroup.new()
	var vrow := UIKit.hbox(8)
	for i in VIEWS.size():
		var idx := i
		var chip := UIKit.chip(VIEWS[i], i == _view, gv, func():
			_view = idx
			refresh())
		UIKit.shrink_button(chip)
		vrow.add_child(chip)
	c.add_child(vrow)
	if _view == 1:
		_build_depth(w, club, c)
		return
	if _view == 2:
		_build_roles(w, club, c)
		return
	var g := ButtonGroup.new()
	var frow := UIKit.hbox(8)
	for i in FILTERS.size():
		var idx := i
		frow.add_child(UIKit.chip(FILTERS[i], i == _filter, g, func():
			_filter = idx
			refresh()))
	c.add_child(frow)
	var g2 := ButtonGroup.new()
	var srow := UIKit.hbox(6)
	srow.add_child(UIKit.label("Ordenar", "Small"))
	for s in SORTS:
		var key: String = s[0]
		var chip := UIKit.chip(s[1], key == _sort, g2, func():
			_sort = key
			refresh())
		chip.add_theme_font_size_override(&"font_size", 17)
		srow.add_child(chip)
	c.add_child(srow)
	var list: Array = []
	for p in squad:
		if _filter == 0 or Pos.group(p.position) == _filter - 1:
			list.append(p)
	var y := w.year
	match _sort:
		"ovr":
			list.sort_custom(func(a, b): return a.ovr_f > b.ovr_f)
		"age":
			list.sort_custom(func(a, b): return a.age(y) < b.age(y))
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
			c.add_child(UIKit.section(Pos.GROUP_NAMES[last_group]))
		var pid := p.id
		c.add_child(PlayerRowView.make(w, p, {"mode": "squad"}, func(): UIManager.push("player", {"id": pid})))
	var out := TransferManager.loaned_out(w)
	if not out.is_empty():
		c.add_child(UIKit.section("Emprestados (voltam no fim da temporada)"))
		for p: Player in out:
			var pid := p.id
			c.add_child(PlayerRowView.make(w, p, {"mode": "market"}, func(): UIManager.push("player", {"id": pid})))


## Profundidade: os três melhores por posição e onde falta gente boa.
func _build_depth(w: GameWorld, club: Club, c: VBoxContainer) -> void:
	c.add_child(UIKit.label("Em laranja: falta reposição.", "Small", true))
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
	c.add_child(UIKit.label("Promover anima; rebaixar derruba a moral.", "Small", true))
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
		box.add_child(UIKit.label(SquadManager.STATUS_DESC[s], "Small", true))
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
