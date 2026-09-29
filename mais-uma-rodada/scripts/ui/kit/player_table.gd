class_name PlayerTable
extends RefCounted
## Tabela de jogadores (Elenco, Base, Mercado, listas de clube): mesma coluna de nome e as
## mesmas colunas de números em todo lugar. A coluna do nome traz número, posição, nome e a
## situação na segunda linha (lesionado, suspenso, emprestado...), sem ícones soltos.
##
## mode: "squad" (dados exatos do próprio elenco), "market" (avaliação da comissão e preço),
## "club" (outro clube, estimado, sem preço), "youth" (base), "national" (convocação: sem número,
## o clube no lugar da situação).

const ROW_H := 88


## Visões do elenco (DESIGN.md › DataTable): cada uma troca as colunas de números; o nome fica.
const VIEWS := [["geral", "Geral"], ["forma", "Forma"], ["temporada", "Temporada"], ["contrato", "Contrato"]]


## `extra`: colunas a mais no fim (o mercado põe a comparação com o titular e o salário pedido).
## `view`: "geral", "forma", "temporada", "contrato" (elenco/base) ou "" (todas, mercado).
## `wide`: há espaço sobrando; entra a idade. Sem "sort" no estado, mantém a ordem recebida.
static func make(w: GameWorld, players: Array, mode: String, state: Dictionary, on_tap: Callable, extra: Array = [], view: String = "", wide: bool = false) -> DataTable:
	var t := DataTable.new()
	t.row_height = ROW_H
	t.lead_width = 290.0
	if not state.has("sort") and mode != "market":
		state["sort"] = "pos"
		state["desc"] = false
	t.marker = func(p: Player) -> Color:
		if p.injury_weeks > 0 or p.suspension > 0:
			return UIColors.RED
		return Color(0, 0, 0, 0)
	t.row_pressed.connect(func(p: Variant): on_tap.call(p))
	var cols := columns(w, mode, view, wide)
	cols.append_array(extra)
	return t.setup(cols, players, state)


static func columns(w: GameWorld, mode: String, view: String = "", wide: bool = false) -> Array:
	var y := w.year
	var exact := mode == "squad" or mode == "youth"
	var c := _all(w, mode, exact, y)
	var keys: Array = []
	match view:
		"geral":
			keys = ["ovr", "cond", "morale"]
		"forma":
			keys = ["ovr", "recent", "form", "apps"]
		"temporada":
			keys = ["apps", "goals", "assists", "form"]
		"contrato":
			keys = ["contract", "wage", "value"]
		"selecao":
			keys = ["ovr", "age"] if wide else ["ovr"]
		"treino":
			keys = ["ovr", "age", "cond", "morale"] if wide else ["ovr"]
		"base":
			keys = ["ovr", "pot", "age", "apps", "goals", "form"] if wide else ["ovr", "pot", "age"]
		_:
			if mode == "market":
				# Celular: o que decide olhar o jogador (nível, idade, preço). Com espaço, o resto.
				keys = ["ovr", "age", "price", "club", "form", "value"] if wide else ["ovr", "age", "price"]
			else:
				keys = ["ovr", "age", "cond", "morale", "form", "apps", "goals", "assists", "contract", "wage", "value"]
	# Com espaço sobrando (tablet em pé, desktop), a visão ganha colunas em vez de vazio.
	if wide and view != "":
		var more: Dictionary = {"geral": ["age", "form", "apps", "contract"], "forma": ["age", "cond", "morale"],
			"temporada": ["age", "ovr"], "contrato": ["age", "ovr", "morale"]}
		for k in more.get(view, []):
			if not k in keys:
				keys.append(k)
	var out: Array = [c["pos"]]
	for k in keys:
		if c.has(k):
			out.append(c[k])
	return out


static func _all(w: GameWorld, mode: String, exact: bool, y: int) -> Dictionary:
	var c := {}
	c["pos"] = {"key": "pos", "title": "Jogador", "first": "asc",
		"sort": func(p: Player) -> int: return Pos.DISPLAY_ORDER.find(p.position) * 1000 - int(PlayerAssessment.score(w,p) * 10),
		"cell": func(p: Player) -> Control: return lead_cell(w, p, mode)}
	c["ovr"] = {"key": "ovr", "title": "Avaliação", "w": 98, "tip": "Estimativa para a posição no seu elenco; estrelas claras indicam incerteza",
		"sort": func(p: Player) -> float: return PlayerAssessment.stars(w,p),
		"cell": func(p: Player) -> Control: return ovr_cell(w, p, exact)}
	c["pot"] = {"key": "pot", "title": "Projeção", "w": 100, "tip": "Estimativa da comissão",
		"sort": func(p: Player) -> float: return YouthManager.potential_stars(w, p),
		"cell": func(p: Player) -> Control:
			return UIKit.player_stars(w,p,17,true)}
	c["age"] = {"key": "age", "title": "Idade", "w": 60, "first": "asc",
		"text": func(p: Player) -> String: return str(p.age(y)),
		"sort": func(p: Player) -> int: return p.age(y)}
	c["price"] = {"key": "price", "title": "Preço", "w": 112,
		"text": func(p: Player) -> String: return Fmt.money(_price(w, p)),
		"sort": func(p: Player) -> float: return _price(w, p)}
	c["club"] = {"key": "club", "title": "Clube", "w": 150, "first": "asc",
		"text": func(p: Player) -> String: return "Livre" if p.club_id < 0 else w.club(p.club_id).short_name,
		"sort": func(p: Player) -> String: return "" if p.club_id < 0 else w.club(p.club_id).short_name,
		"color": func(_p: Player) -> Color: return UIColors.MUTED}
	c["cond"] = {"key": "cond", "title": "Físico", "w": 70, "first": "asc",
		"text": func(p: Player) -> String: return "%d%%" % int(round(p.condition)),
		"sort": func(p: Player) -> float: return p.condition,
		"color": func(p: Player) -> Color: return UIColors.TEXT if p.condition >= 85.0 else (UIColors.ORANGE if p.condition >= 70.0 else UIColors.RED)}
	c["morale"] = {"key": "morale", "title": "Moral", "w": 104,
		"text": func(p: Player) -> String: return UIColors.morale_label(p.morale),
		"sort": func(p: Player) -> float: return p.morale,
		"color": func(p: Player) -> Color: return UIColors.morale_color(p.morale)}
	c["recent"] = {"key": "recent", "title": "Últimos", "w": 104, "tip": "Notas dos últimos 3 jogos",
		"text": func(p: Player) -> String:
			var r: Array = p.recent_ratings.slice(maxi(0, p.recent_ratings.size() - 3))
			return " ".join(r.map(func(x) -> String: return Fmt.rating(float(x)))) if not r.is_empty() else "–",
		"sort": func(p: Player) -> float: return p.form() if not p.recent_ratings.is_empty() else 0.0,
		"color": func(p: Player) -> Color: return UIColors.MUTED}
	c["form"] = {"key": "form", "title": "Nota", "w": 60, "tip": "Nota média na temporada",
		"text": func(p: Player) -> String:
			var apps := int(p.season_totals()[0])
			return Fmt.rating(ClubRecords.rating(p, apps)) if apps > 0 else "–",
		"sort": func(p: Player) -> float:
			var apps := int(p.season_totals()[0])
			return ClubRecords.rating(p, apps) if apps > 0 else 0.0,
		"color": func(p: Player) -> Color:
			var apps := int(p.season_totals()[0])
			return Fmt.match_rating_color(ClubRecords.rating(p, apps)) if apps > 0 else UIColors.DIM}
	c["apps"] = {"key": "apps", "title": "J", "w": 44, "tip": "Jogos",
		"text": func(p: Player) -> String: return str(int(p.season_totals()[0])),
		"sort": func(p: Player) -> int: return int(p.season_totals()[0]),
		"color": func(_p: Player) -> Color: return UIColors.MUTED}
	c["goals"] = {"key": "goals", "title": "G", "w": 44, "tip": "Gols",
		"text": func(p: Player) -> String: return str(int(p.season_totals()[1])),
		"sort": func(p: Player) -> int: return int(p.season_totals()[1]),
		"color": func(p: Player) -> Color: return UIColors.TEXT if int(p.season_totals()[1]) > 0 else UIColors.DIM}
	c["assists"] = {"key": "assists", "title": "A", "w": 44, "tip": "Assistências",
		"text": func(p: Player) -> String: return str(int(p.season_totals()[2])),
		"sort": func(p: Player) -> int: return int(p.season_totals()[2]),
		"color": func(p: Player) -> Color: return UIColors.TEXT if int(p.season_totals()[2]) > 0 else UIColors.DIM}
	c["contract"] = {"key": "contract", "title": "Até", "w": 64, "first": "asc", "tip": "Fim do contrato",
		"text": func(p: Player) -> String: return str(p.contract_end) if p.club_id >= 0 else "–",
		"sort": func(p: Player) -> int: return p.contract_end,
		"color": func(p: Player) -> Color: return UIColors.ORANGE if p.contract_end <= y else UIColors.TEXT}
	c["wage"] = {"key": "wage", "title": "Salário", "w": 118,
		"text": func(p: Player) -> String: return Fmt.money_month(p.wage),
		"sort": func(p: Player) -> float: return p.wage,
		"color": func(_p: Player) -> Color: return UIColors.MUTED}
	c["value"] = {"key": "value", "title": "Valor", "w": 100,
		"text": func(p: Player) -> String: return Fmt.money(p.value),
		"sort": func(p: Player) -> float: return p.value,
		"color": func(_p: Player) -> Color: return UIColors.MUTED}
	return c


static func _price(w: GameWorld, p: Player) -> float:
	var free := p.club_id < 0 or not p.loan.is_empty()
	return p.value if free else TransferManager.asking_price(w, p)


## Rosto, nome e, embaixo, posição e a situação que importa agora (lesão, contrato, papel).
## Número da camisa pequeno antes do rosto no elenco; bandeira no mercado.
static func lead_cell(w: GameWorld, p: Player, mode: String) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override(&"separation", 10)
	h.tooltip_text = p.full_name()
	if mode != "market" and mode != "national":
		var num := Label.new()
		num.text = str(p.shirt) if p.shirt > 0 else ""
		num.custom_minimum_size.x = 28
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		num.theme_type_variation = "Meta"
		num.add_theme_font_override(&"font", DataTable.tabular_font())
		num.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(num)
	var face := UIKit.portrait(p, w.club(p.club_id) if p.club_id >= 0 else null, w.year, 56)
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
	var line := HBoxContainer.new()
	line.add_theme_constant_override(&"separation", 8)
	var pos := Label.new()
	pos.text = Pos.code(p.position)
	pos.theme_type_variation = "Caps"
	pos.add_theme_color_override(&"font_color", UIColors.readable_on(Pos.group_color(p.position), [UIColors.BG], 4.5))
	line.add_child(pos)
	if mode == "market" and p.nationality != "":
		var fl := UIKit.flag(p.nationality, 24)
		fl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(fl)
	var st := status(w, p, mode)
	var sub := Label.new()
	sub.theme_type_variation = "Small"
	sub.text = st[0]
	sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	sub.add_theme_color_override(&"font_color", st[1])
	line.add_child(sub)
	v.add_child(line)
	h.add_child(v)
	return h


## Situação em uma linha e a cor dela. A ordem é a do que mais pesa para escalar.
static func status(w: GameWorld, p: Player, mode: String) -> Array:
	var own := p.club_id >= 0 and w.is_user_club(p.club_id)
	if p.injury_weeks > 0:
		return ["Lesionado, %d sem." % p.injury_weeks, UIColors.RED]
	if p.suspension > 0:
		return ["Suspenso, %d jogo(s)" % p.suspension, UIColors.RED]
	if mode == "national":
		# Na seleção, o que situa o jogador é o clube onde joga.
		var cl := w.club(p.club_id) if p.club_id >= 0 else null
		return [cl.short_name if cl != null else "Sem clube", UIColors.TEXT if own else UIColors.MUTED]
	if p.intl_duty:
		return ["Na seleção", UIColors.MUTED]
	if mode == "youth":
		if p.age(w.year) >= YouthManager.MAX_AGE:
			return ["Última temporada na base", UIColors.ORANGE]
		return [YouthManager.potential_label_of(w, p), UIColors.MUTED]
	if not p.loan.is_empty():
		var from := w.club(int(p.loan.get("from", -1))) if p.loan.has("from") else null
		return [("Emprestado pelo " + from.short_name) if from != null else "Emprestado", UIColors.ORANGE]
	if own and p.contract_end <= w.year:
		return ["Último ano", UIColors.ORANGE]
	if p.yellow_acc >= int(DatabaseManager.squad_rules()["yellow_limit"]) - 1 and own:
		return ["Pendurado", UIColors.ORANGE]
	if p.transfer_listed:
		return ["À venda", UIColors.MUTED]
	if p.retiring:
		return ["Vai se aposentar", UIColors.MUTED]
	if mode == "market":
		if Shortlist.has(w, p):
			return ["Na sua lista", UIColors.TEXT]
		if Scouting.is_scouted(w, p):
			# Até 25 anos, o que o olheiro viu (potencial) diz mais que "observado".
			if p.age(w.year) <= 25:
				return [PlayerAssessment.summary(w,p,true), UIColors.MUTED]
			return ["Observado", UIColors.MUTED]
		return [PlayStyle.of(p), UIColors.MUTED]
	return [Player.STATUS_NAMES[p.squad_status], UIColors.MUTED]


static func ovr_cell(w: GameWorld, p: Player, _exact: bool) -> Control:
	return UIKit.player_stars(w,p,16)
