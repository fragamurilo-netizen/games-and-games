extends BaseScreen
## Elenco: filtros por setor, ordenação e acesso rápido a escalação e perfil.

const FILTERS := ["Todos", "GOL", "DEF", "MEI", "ATA"]
const VIEWS := ["Jogadores", "Números", "Profundidade", "Papéis"]
const SORTS := [["pos", "Posição"], ["ovr", "Overall"], ["form", "Nota"], ["cond", "Condição"], ["age", "Idade"], ["contract", "Contrato"], ["value", "Valor"]]
## Recortes rápidos da lista (tocáveis também nos alertas do resumo).
const QUICK := [["all", "Todos"], ["ok", "Disponíveis"], ["hurt", "Lesionados"], ["exp", "Contrato acabando"], ["u21", "Sub-21"], ["tired", "Cansados"]]

var _filter := 0
var _quick := "all"
var _sort := "pos"
var _view := 0


var _table_state := {}
var _loan_state := {}


func _init() -> void:
	nav_tab = "squad"
	screen_title = "Elenco"
	max_content_width = 1700.0


## Resumo em uma linha: o que muda decisão (tamanho, força do time titular, folha, regra de
## estrangeiros). Lesionados e contratos acabando viram recortes da tabela.
func _summary(w: GameWorld, club: Club, squad: Array) -> Control:
	var v := UIKit.vbox(2)
	var ages := 0.0
	for p: Player in squad:
		ages += p.age(w.year)
	var xi := 0.0
	if club.sheet != null:
		xi = ClubAI.lineup_strength(w, club.sheet.formation, club.sheet.starters) / 11.0
	var fin := FinanceManager.summary(w, club)
	var over: bool = fin["wage_bill"] > fin["wage_budget"]
	var line := RichTextLabel.new()
	line.bbcode_enabled = true
	line.fit_content = true
	line.scroll_active = false
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_color_override(&"default_color", UIColors.MUTED)
	var bill := "[color=#%s]%s[/color]" % [(UIColors.RED if over else UIColors.TEXT).to_html(false), Fmt.money_month(fin["wage_bill"])]
	line.text = "%d jogadores · %s anos em média · time titular [color=#%s]%d[/color] · folha %s de %s" % [
		squad.size(), Fmt._decimal(ages / maxf(1.0, squad.size()), 1), UIColors.TEXT.to_html(false), int(round(xi)), bill, Fmt.money(fin["wage_budget"])]
	v.add_child(line)
	var rule := SquadRules.describe(club)
	if rule != "":
		var used := SquadRules.count(w, club, (club.sheet.starters + club.sheet.bench) if club.sheet != null else [])
		var lim := int(SquadRules.limit(club)["max"])
		if used > lim:
			v.add_child(UIKit.colored("%s: %d/%d" % [rule, used, lim], UIColors.ORANGE, "Small", true))
	return v


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
	if _sort != "pos":
		_table_state = {"sort": _sort, "desc": _sort not in ["contract", "age", "cond"]}
	if p.has("tab"):
		_view = clampi(int(p["tab"]), 0, VIEWS.size() - 1)


func refresh() -> void:
	var w := world()
	if w == null:
		return
	var club := w.user_club()
	var squad := w.squad(club)
	screen_subtitle = ""
	UIManager.refresh_chrome()
	var c := content()
	UIKit.clear(c)
	var vitems: Array = []
	for i in VIEWS.size():
		vitems.append([str(i), VIEWS[i]])
	c.add_child(UIKit.tabs(vitems, str(_view), func(key: String):
		_view = int(key)
		refresh()))
	if _view == 1:
		c.add_child(TeamStatsScreen.squad_table(w, club))
		return
	if _view == 2:
		_build_depth(w, club, c)
		return
	if _view == 3:
		_build_roles(w, club, c)
		return
	c.add_child(_summary(w, club, squad))
	# Filtros numa fileira só: setor e recorte (lesionados, contrato acabando...).
	var bar := UIKit.hbox(10)
	var fitems: Array = []
	for i in FILTERS.size():
		fitems.append([str(i), FILTERS[i]])
	var seg := UIKit.segment(fitems, str(_filter), func(key: String):
		_filter = int(key)
		_table_state["shown"] = 0
		refresh())
	seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(seg)
	var counts := _quick_counts(w, squad)
	var qname := ""
	for q in QUICK:
		if q[0] == _quick:
			qname = String(q[1])
	var qb := UIKit.button(qname if _quick != "all" else "Recorte", "ChipButton", _quick_sheet.bind(counts))
	if _quick != "all":
		qb.add_theme_color_override(&"font_color", UIColors.ink(UIColors.ACCENT))
	elif int(counts.get("hurt", 0)) + int(counts.get("exp", 0)) > 0:
		qb.text = "Recorte · %d" % (int(counts.get("hurt", 0)) + int(counts.get("exp", 0)))
	bar.add_child(qb)
	c.add_child(bar)
	var list: Array = []
	for p in squad:
		if (_filter == 0 or Pos.group(p.position) == _filter - 1) and _passes_quick(w, p):
			list.append(p)
	if list.is_empty():
		c.add_child(UIKit.state_block("empty", "Ninguém nesse recorte.", "", "Mostrar todos", func():
			_filter = 0
			_quick = "all"
			refresh()))
	else:
		c.add_child(PlayerTable.make(w, list, "squad", _table_state, func(p: Player): UIManager.push("player", {"id": p.id})))
	var out := TransferManager.loaned_out(w)
	if not out.is_empty():
		c.add_child(UIKit.section_header("Emprestados · %d" % out.size()))
		c.add_child(PlayerTable.make(w, out, "club", _loan_state, func(p: Player): UIManager.push("player", {"id": p.id})))
	c.add_child(UIKit.gap(12))
	c.add_child(UIKit.menu_group([
		UIKit.menu_row("", "Estatísticas da equipe", "", func(): UIManager.push("team_stats")),
		UIKit.menu_row("", "Numeração", "", func(): UIManager.push("numbers")),
		UIKit.menu_row("", "Contratos", "", func(): UIManager.push("contracts")),
		UIKit.menu_row("", "Vestiário", "", func(): UIManager.push("dressing_room")),
		UIKit.menu_row("", "Base", "", func(): UIManager.push("academy")),
	]))


func _quick_counts(w: GameWorld, squad: Array) -> Dictionary:
	var out := {}
	for q in QUICK:
		var k := String(q[0])
		var n := 0
		var keep := _quick
		_quick = k
		for p: Player in squad:
			if _passes_quick(w, p):
				n += 1
		_quick = keep
		out[k] = n
	return out


func _quick_sheet(counts: Dictionary) -> void:
	var v := UIKit.vbox(0)
	v.add_child(UIKit.label("Recorte", "H2"))
	v.add_child(UIKit.gap(8))
	for q in QUICK:
		var k := String(q[0])
		var h := UIKit.hbox(8)
		var l := UIKit.label(String(q[1]))
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if k == _quick:
			l.add_theme_color_override(&"font_color", UIColors.ink(UIColors.ACCENT))
		h.add_child(l)
		var n := int(counts.get(k, 0))
		h.add_child(UIKit.colored(str(n), (UIColors.ORANGE if k in ["hurt", "exp", "tired"] and n > 0 else UIColors.MUTED), "Small"))
		var row := UIKit.tap_row(h, func():
			_quick = k
			_table_state["shown"] = 0
			UIManager.close_modal()
			refresh())
		row.custom_minimum_size.y = 72
		v.add_child(row)
	UIManager.show_modal(v, true)


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
