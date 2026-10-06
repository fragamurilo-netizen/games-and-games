extends BaseScreen
## Elenco: filtros por setor, ordenação e acesso rápido a escalação e perfil.

const FILTERS := ["Todos", "GOL", "DEF", "MEI", "ATA"]
## Seções além da lista (abertas pelo pé da tela; a lista é sempre a primeira coisa).
const VIEWS := ["Jogadores", "Números", "Profundidade", "Papéis"]
const SORTS := [["pos", "Posição"], ["ovr", "Avaliação"], ["form", "Nota"], ["cond", "Condição"], ["age", "Idade"], ["contract", "Contrato"], ["value", "Valor"]]
## Recortes rápidos da lista (tocáveis também nos alertas do resumo).
const QUICK := [["all", "Todos"], ["ok", "Disponíveis"], ["hurt", "Lesionados"], ["exp", "Contrato acabando"], ["u21", "Sub-21"], ["tired", "Cansados"]]

var _filter := 0
var _quick := "all"
var _sort := "pos"
var _view := 0


var _table_state := {}
var _loan_state := {}
## Visão da tabela (PlayerTable.VIEWS) e jogador aberto no painel de detalhe (tela larga).
var _cols := "geral"
var _sel := -1


func _init() -> void:
	nav_tab = "squad"
	screen_title = "Elenco"
	max_content_width = 1700.0


## Resumo em uma frase (sem painel de indicadores): tamanho, idade, time titular e folha.
## A regra de estrangeiros só aparece quando estourada.
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
	var txt := "%d jogadores, idade média de %s anos. Folha de %s por mês, limite de %s." % [
		squad.size(), Fmt._decimal(ages / maxf(1.0, squad.size()), 1), Fmt.money(fin["wage_bill"]), Fmt.money(fin["wage_budget"])]
	v.add_child(UIKit.label(txt, "Muted", true))
	if over:
		v.add_child(UIKit.colored("A folha passou do limite da diretoria.", UIColors.RED, "Small", true))
	var rule := SquadRules.describe(club)
	if rule != "":
		# Com regra de estrangeiros na liga: quantos estão entre os relacionados, do limite.
		var used := SquadRules.count(w, club, (club.sheet.starters + club.sheet.bench) if club.sheet != null else [])
		var lim := int(SquadRules.limit(club)["max"])
		if used > lim:
			v.add_child(UIKit.colored("%s: %d de %d." % [rule, used, lim], UIColors.ORANGE, "Small", true))
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
	if _view != 0:
		# Seção secundária: volta à lista com um toque.
		var back := UIKit.button("Voltar à lista", "TextButton", func():
			_view = 0
			refresh(), "back")
		back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		c.add_child(back)
		c.add_child(UIKit.label(VIEWS[_view], "Title"))
		match _view:
			1:
				c.add_child(TeamStatsScreen.squad_table(w, club))
			2:
				_build_depth(w, club, c)
			3:
				_build_roles(w, club, c)
		return
	# Mestre/detalhe em tela larga: a lista à esquerda, o jogador escolhido à direita.
	var wide := content_width() >= 1000.0
	var main: VBoxContainer = c
	var side: VBoxContainer = null
	if wide:
		var split := UIKit.hbox(UITokens.S6)
		main = UIKit.vbox(UITokens.S3)
		main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		main.size_flags_stretch_ratio = 1.7
		side = UIKit.vbox(UITokens.S3)
		side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		split.add_child(main)
		split.add_child(side)
		c.add_child(split)
	main.add_child(_summary(w, club, squad))
	# Visão: troca as colunas (Geral, Forma, Temporada, Contrato). Setor e recorte embaixo.
	main.add_child(UIKit.segment(PlayerTable.VIEWS, _cols, func(key: String):
		_cols = key
		refresh()))
	var bar := UIKit.hbox(UITokens.S2)
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
	var alerts := int(counts.get("hurt", 0)) + int(counts.get("exp", 0))
	var qb := UIKit.button(qname if _quick != "all" else ("Filtro (%d)" % alerts if alerts > 0 else "Filtro"), "ChipButton", _quick_sheet.bind(counts))
	qb.custom_minimum_size.y = UITokens.H_CHIP
	if _quick != "all":
		qb.button_pressed = true
		qb.toggle_mode = true
	bar.add_child(qb)
	main.add_child(bar)
	var list: Array = []
	for p in squad:
		if (_filter == 0 or Pos.group(p.position) == _filter - 1) and _passes_quick(w, p):
			list.append(p)
	if list.is_empty():
		main.add_child(UIKit.state_block("empty", "Ninguém nesse recorte.", "", "Mostrar todos", func():
			_filter = 0
			_quick = "all"
			refresh()))
	else:
		var tap := func(p: Player):
			if wide:
				_sel = p.id
				refresh()
			else:
				UIManager.push("player", {"id": p.id})
		# Sem painel de detalhe mas com largura de sobra (tablet em pé): mais colunas.
		var dense := wide or content_width() >= 760.0
		var tbl := PlayerTable.make(w, list, "squad", _table_state, tap, [], _cols, dense and not wide or content_width() >= 1500.0)
		if wide:
			if _sel < 0 and not list.is_empty(): _sel = list[0].id
			tbl.highlight = func(p: Player) -> bool: return p.id == _sel
			tbl._build()
		main.add_child(tbl)
	var out := TransferManager.loaned_out(w)
	if not out.is_empty():
		main.add_child(UIKit.label("Emprestados", "Section"))
		main.add_child(PlayerTable.make(w, out, "club", _loan_state, func(p: Player): UIManager.push("player", {"id": p.id}), [], "geral", wide))
	main.add_child(UIKit.gap(UITokens.S2))
	main.add_child(UIKit.menu_group([
		UIKit.menu_row("", "Profundidade por posição", "", func():
			_view = 2
			refresh()),
		UIKit.menu_row("", "Papéis e promessas", "", func():
			_view = 3
			refresh()),
		UIKit.menu_row("", "Números da temporada", "", func():
			_view = 1
			refresh()),
		UIKit.menu_row("", "Contratos", "", func(): UIManager.push("contracts")),
		UIKit.menu_row("", "Numeração", "", func(): UIManager.push("numbers")),
		UIKit.menu_row("", "Vestiário", "", func(): UIManager.push("dressing_room")),
	]))
	if side != null:
		var sel := w.player(_sel)
		if sel == null or sel.club_id != club.id:
			sel = null
			for p in list:
				sel = p
				break
		if sel != null:
			_sel = sel.id
			side.add_child(PlayerBrief.make(w, sel, true))


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
			line.add_child(UIKit.player_stars(w,p,15,false,int(row["pos"][0])))
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
