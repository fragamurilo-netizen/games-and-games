class_name PlayerTable
extends RefCounted
## Tabela de jogadores (Elenco, Base, Mercado, listas de clube): mesma coluna de nome e as
## mesmas colunas de números em todo lugar. A coluna do nome traz número, posição, nome e a
## situação na segunda linha (lesionado, suspenso, emprestado...), sem ícones soltos.
##
## mode: "squad" (dados exatos do próprio elenco), "market" (overall estimado e preço),
## "club" (outro clube, estimado, sem preço), "youth" (base).

const ROW_H := 88


## `extra`: colunas a mais logo depois de Geral/Idade (o mercado põe a comparação com o
## titular e o salário pedido). Sem "sort" no estado, mantém a ordem recebida (relevância).
static func make(w: GameWorld, players: Array, mode: String, state: Dictionary, on_tap: Callable, extra: Array = []) -> DataTable:
	var t := DataTable.new()
	t.row_height = ROW_H
	t.lead_width = 390.0
	if not state.has("sort") and mode != "market":
		state["sort"] = "pos"
		state["desc"] = false
	t.marker = func(p: Player) -> Color:
		if p.injury_weeks > 0 or p.suspension > 0:
			return UIColors.RED
		return Color(0, 0, 0, 0)
	t.row_pressed.connect(func(p: Variant): on_tap.call(p))
	var cols := columns(w, mode)
	for i in extra.size():
		cols.insert(3 + i, extra[i])
	return t.setup(cols, players, state)


static func columns(w: GameWorld, mode: String) -> Array:
	var y := w.year
	var exact := mode == "squad" or mode == "youth"
	var cols: Array = [{
		"key": "pos", "title": "Jogador", "first": "asc",
		"sort": func(p: Player) -> int: return Pos.DISPLAY_ORDER.find(p.position) * 1000 - int(p.ovr_f * 10),
		"cell": func(p: Player) -> Control: return lead_cell(w, p, mode),
	}]
	cols.append({"key": "ovr", "title": "Geral", "w": 76, "tip": "Overall",
		"sort": func(p: Player) -> float: return p.ovr_f if exact else float(PlayerRowView.estimate(w, p, p.overall)),
		"cell": func(p: Player) -> Control: return ovr_cell(w, p, exact)})
	cols.append({"key": "age", "title": "Idade", "w": 70, "first": "asc",
		"text": func(p: Player) -> String: return str(p.age(y)),
		"sort": func(p: Player) -> int: return p.age(y)})
	if mode == "market":
		cols.append({"key": "price", "title": "Preço", "w": 124,
			"text": func(p: Player) -> String: return Fmt.money(_price(w, p)),
			"sort": func(p: Player) -> float: return _price(w, p)})
		cols.append({"key": "club", "title": "Clube", "w": 150, "first": "asc",
			"text": func(p: Player) -> String: return "Livre" if p.club_id < 0 else w.club(p.club_id).short_name,
			"sort": func(p: Player) -> String: return "" if p.club_id < 0 else w.club(p.club_id).short_name,
			"color": func(_p: Player) -> Color: return UIColors.MUTED})
	if mode == "squad" or mode == "youth":
		cols.append({"key": "cond", "title": "Físico", "w": 70, "first": "asc",
			"text": func(p: Player) -> String: return "%d%%" % int(round(p.condition)),
			"sort": func(p: Player) -> float: return p.condition,
			"color": func(p: Player) -> Color: return UIColors.GREEN if p.condition >= 85.0 else (UIColors.ORANGE if p.condition >= 70.0 else UIColors.RED)})
		cols.append({"key": "morale", "title": "Moral", "w": 112,
			"text": func(p: Player) -> String: return UIColors.morale_label(p.morale),
			"sort": func(p: Player) -> float: return p.morale,
			"color": func(p: Player) -> Color: return UIColors.morale_color(p.morale)})
	cols.append({"key": "form", "title": "Nota", "w": 70, "tip": "Nota média na temporada",
		"text": func(p: Player) -> String:
			var apps := int(p.season_totals()[0])
			return Fmt.rating(ClubRecords.rating(p, apps)) if apps > 0 else "–",
		"sort": func(p: Player) -> float:
			var apps := int(p.season_totals()[0])
			return ClubRecords.rating(p, apps) if apps > 0 else 0.0,
		"color": func(p: Player) -> Color:
			var apps := int(p.season_totals()[0])
			return Fmt.match_rating_color(ClubRecords.rating(p, apps)) if apps > 0 else UIColors.DIM})
	cols.append({"key": "apps", "title": "J", "w": 52, "tip": "Jogos",
		"text": func(p: Player) -> String: return str(int(p.season_totals()[0])),
		"sort": func(p: Player) -> int: return int(p.season_totals()[0]),
		"color": func(_p: Player) -> Color: return UIColors.MUTED})
	cols.append({"key": "goals", "title": "G", "w": 52, "tip": "Gols",
		"text": func(p: Player) -> String: return str(int(p.season_totals()[1])),
		"sort": func(p: Player) -> int: return int(p.season_totals()[1]),
		"color": func(p: Player) -> Color: return UIColors.TEXT if int(p.season_totals()[1]) > 0 else UIColors.DIM})
	cols.append({"key": "assists", "title": "A", "w": 52, "tip": "Assistências",
		"text": func(p: Player) -> String: return str(int(p.season_totals()[2])),
		"sort": func(p: Player) -> int: return int(p.season_totals()[2]),
		"color": func(p: Player) -> Color: return UIColors.TEXT if int(p.season_totals()[2]) > 0 else UIColors.DIM})
	if mode == "squad":
		cols.append({"key": "contract", "title": "Contrato", "w": 100, "first": "asc",
			"text": func(p: Player) -> String: return str(p.contract_end),
			"sort": func(p: Player) -> int: return p.contract_end,
			"color": func(p: Player) -> Color: return UIColors.ORANGE if p.contract_end <= y else UIColors.MUTED})
		cols.append({"key": "wage", "title": "Salário", "w": 140,
			"text": func(p: Player) -> String: return Fmt.money_month(p.wage),
			"sort": func(p: Player) -> float: return p.wage,
			"color": func(_p: Player) -> Color: return UIColors.MUTED})
	cols.append({"key": "value", "title": "Valor", "w": 124,
		"text": func(p: Player) -> String: return Fmt.money(p.value),
		"sort": func(p: Player) -> float: return p.value,
		"color": func(_p: Player) -> Color: return UIColors.MUTED})
	return cols


static func _price(w: GameWorld, p: Player) -> float:
	var free := p.club_id < 0 or not p.loan.is_empty()
	return p.value if free else TransferManager.asking_price(w, p)


## Número, posição e nome; embaixo a situação que importa agora.
static func lead_cell(w: GameWorld, p: Player, mode: String) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override(&"separation", 10)
	var num := Label.new()
	num.text = str(p.shirt) if p.shirt > 0 and mode != "market" else ""
	num.custom_minimum_size.x = 34
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	num.add_theme_font_override(&"font", DataTable.tabular_font())
	num.add_theme_color_override(&"font_color", UIColors.DIM)
	num.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if mode != "market":
		h.add_child(num)
	var pos := Label.new()
	pos.text = Pos.code(p.position)
	pos.custom_minimum_size.x = 46
	pos.theme_type_variation = "Caps"
	pos.add_theme_color_override(&"font_color", UIColors.readable_on(Pos.group_color(p.position), [UIColors.BG], 4.5))
	pos.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(pos)
	if mode == "market" and p.nationality != "":
		var fl := UIKit.flag(p.nationality, 28)
		fl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(fl)
	else:
		# O rosto do jogador: o elenco é gente, não uma planilha.
		var face := UIKit.portrait(p, w.club(p.club_id) if p.club_id >= 0 else null, w.year, 60)
		face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(face)
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", -2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var nm := Label.new()
	nm.text = p.display_name()
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	v.add_child(nm)
	var st := status(w, p, mode)
	var sub := Label.new()
	sub.theme_type_variation = "Small"
	sub.text = st[0]
	sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	sub.add_theme_color_override(&"font_color", st[1])
	v.add_child(sub)
	h.add_child(v)
	return h


## Situação em uma linha e a cor dela. A ordem é a do que mais pesa para escalar.
static func status(w: GameWorld, p: Player, mode: String) -> Array:
	var own := p.club_id >= 0 and w.is_user_club(p.club_id)
	if p.injury_weeks > 0:
		return ["Lesionado · %d sem." % p.injury_weeks, UIColors.RED]
	if p.suspension > 0:
		return ["Suspenso · %d j." % p.suspension, UIColors.RED]
	if p.intl_duty:
		return ["Na seleção", UIColors.MUTED]
	if not p.loan.is_empty():
		var from := w.club(int(p.loan.get("from", -1))) if p.loan.has("from") else null
		return ["Emprestado" + (" · do " + from.short_name if from != null else ""), UIColors.ORANGE]
	if own and p.contract_end <= w.year:
		return ["Contrato acaba em %d" % p.contract_end, UIColors.ORANGE]
	if p.yellow_acc >= int(DatabaseManager.squad_rules()["yellow_limit"]) - 1 and own:
		return ["Pendurado", UIColors.ORANGE]
	if p.transfer_listed:
		return ["À venda · " + PlayStyle.of(p), UIColors.MUTED]
	if p.retiring:
		return ["Vai se aposentar", UIColors.MUTED]
	if mode == "market":
		var tags: Array = [PlayStyle.of(p)]
		if Scouting.is_scouted(w, p):
			tags.append("observado")
		if Shortlist.has(w, p):
			tags.append("na sua lista")
		return [" · ".join(tags), UIColors.MUTED]
	return ["%s · %s" % [PlayStyle.of(p), Player.STATUS_NAMES[p.squad_status]], UIColors.MUTED]


static func ovr_cell(w: GameWorld, p: Player, exact: bool) -> Control:
	var l := Label.new()
	var v := p.overall if exact else PlayerRowView.estimate(w, p, p.overall)
	l.text = str(v) if exact else "~%d" % v
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override(&"font", ThemeDB.get_project_theme().get_font(&"font", &"H3"))
	l.add_theme_font_size_override(&"font_size", 28)
	l.add_theme_color_override(&"font_color", UIColors.readable_on(Fmt.rating_color(v), [UIColors.BG], 4.5))
	return l
