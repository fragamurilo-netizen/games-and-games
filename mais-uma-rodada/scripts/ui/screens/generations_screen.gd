extends BaseScreen
## Gerações do futebol de um país: como anda a formação (em alta, estável, em baixa), as gerações
## excepcionais já descobertas (as escondidas não aparecem: ninguém sabe ainda) e as categorias por
## ano de nascimento — quantos entraram numa base, quantos viraram profissionais e quantos chegaram
## à seleção. No fim, as gerações pelo mundo.

var _nation := ""


func _init() -> void:
	screen_title = "Gerações"


func setup(p: Dictionary) -> void:
	super.setup(p)
	_nation = String(p.get("nation", ""))


func refresh() -> void:
	var w := world()
	if w == null:
		return
	if _nation == "":
		_nation = w.user_nation() if w.has_user() else "BRA"
	screen_subtitle = DatabaseManager.nation_name(_nation)
	UIManager.refresh_chrome()
	var c := content()
	UIKit.clear(c)
	c.add_child(_picker(w))
	c.add_child(_base_card(w))
	for wv: Dictionary in Generations.state(w)["waves"]:
		if String(wv["n"]) == _nation and int(wv["d"]) > 0:
			c.add_child(_wave_card(w, wv))
	c.add_child(_categories_card(w))
	var world_card := _world_card(w)
	if world_card != null:
		c.add_child(world_card)
	max_content_width = 1300
	columnize(c, 1, 2, 0)


func _picker(w: GameWorld) -> Control:
	var ob := OptionButton.new()
	ob.custom_minimum_size.y = 72
	var ns: Array = Generations._nations(w)
	ns.sort_custom(func(a, b): return DatabaseManager.nation_name(String(a)) < DatabaseManager.nation_name(String(b)))
	for i in ns.size():
		ob.add_item(DatabaseManager.nation_name(String(ns[i])), i)
		if String(ns[i]) == _nation:
			ob.select(i)
	ob.item_selected.connect(func(i: int):
		_nation = String(ns[i])
		refresh.call_deferred())
	return ob


func _base_card(w: GameWorld) -> Control:
	var card := UIKit.card("Card", 8)
	var head := UIKit.hbox(12)
	head.add_child(UIKit.flag(_nation, 54))
	var col := UIKit.vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UIKit.label(DatabaseManager.nation_name(_nation), "Section"))
	var tr := Generations.trend(w, _nation)
	var tc := UIColors.GREEN if tr == "em alta" else (UIColors.RED if tr == "em baixa" else UIColors.MUTED)
	col.add_child(UIKit.colored("Formação de jogadores %s" % tr, tc, "H3"))
	head.add_child(col)
	card.add_child(head)
	card.add_child(UIKit.label("Uma geração excepcional deixa herança: o país investe na base e forma melhor por anos. Sem ela, a base anda devagar para cima ou para baixo.", "Small", true))
	var hist: Array = Dictionary(Generations.state(w)["hist"]).get(_nation, [])
	if hist.size() >= 3:
		var labels: Array = []
		var vals: Array = []
		for h in hist:
			labels.append(str(int(h[0])))
			vals.append(float(Generations.index_of(float(h[1]))))
		card.add_child(UIKit.label("Índice da base (50 = o normal do país)", "Small"))
		var ch := StatChart.make(labels, [{"name": "", "values": vals, "color": UIColors.ACCENT}], 170.0)
		ch.value_fmt = "%d"
		ch.guides = [[50.0, ""]]
		card.add_child(ch)
	return UIKit.card_panel(card)


func _wave_card(w: GameWorld, wv: Dictionary) -> Control:
	var card := UIKit.card("CardHighlight", 6)
	card.add_child(UIKit.section(Generations.name_of(wv)))
	var status := "Descoberta em %d · nascidos de %d a %d" % [int(wv["d"]), int(wv["y0"]), int(wv["y1"])]
	if int(wv["pk"]) > 0:
		status = "No auge desde %d · nascidos de %d a %d" % [int(wv["pk"]), int(wv["y0"]), int(wv["y1"])]
	card.add_child(UIKit.label(status, "Small", true))
	for p: Player in Generations.members(w, wv, 6):
		card.add_child(_player_row(w, p))
	return UIKit.card_panel(card)


func _categories_card(w: GameWorld) -> Control:
	var card := UIKit.card("Card", 4)
	card.add_child(UIKit.section("Categorias"))
	card.add_child(UIKit.label("Por ano de nascimento, como na base. Profissional: 15 jogos ou mais entre os profissionais.", "Small", true))
	var shown := 0
	for by in range(w.year - 14, w.year - 40, -1):
		var cat := Generations.category(w, _nation, by)
		if int(cat["entered"]) == 0 and int(cat["active"]) < 5:
			continue
		var row := UIKit.hbox(10)
		var yl := UIKit.label(str(by), "H3")
		yl.custom_minimum_size.x = 78
		row.add_child(yl)
		var col := UIKit.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var parts: Array = []
		if int(cat["entered"]) > 0:
			parts.append(Fmt.plural(int(cat["entered"]), "garoto na base", "garotos na base"))
		parts.append(Fmt.plural(int(cat["pros"]), "profissional", "profissionais"))
		if int(cat["caps"]) > 0:
			parts.append("%d na seleção" % int(cat["caps"]))
		col.add_child(UIKit.label(" · ".join(PackedStringArray(parts)), "", true))
		var best: Array = cat["best"]
		if not best.is_empty():
			col.add_child(UIKit.label("Destaque: %s" % (best[0] as Player).display_name(), "Small"))
		var wv := Generations.wave_of(w, _nation, by)
		if not wv.is_empty() and int(wv["d"]) > 0:
			col.add_child(UIKit.colored(Generations.name_of(wv), UIColors.ACCENT, "Small"))
		row.add_child(col)
		var yy: int = by
		card.add_child(UIKit.tap_row(row, func(): _category_sheet(w, yy), "CardFlat"))
		shown += 1
		if shown >= 22:
			break
	if shown == 0:
		card.add_child(UIKit.label("Nenhuma categoria acompanhada ainda.", "Muted", true))
	return UIKit.card_panel(card)


func _category_sheet(w: GameWorld, by: int) -> void:
	var cat := Generations.category(w, _nation, by)
	var v := UIKit.vbox(10)
	v.add_child(UIKit.label("Categoria %d · %s" % [by, DatabaseManager.nation_name(_nation)], "Title", true))
	v.add_child(UIKit.label("%s · %s ainda jogando · %s" % [Fmt.plural(int(cat["entered"]), "garoto entrou", "garotos entraram") if int(cat["entered"]) > 0 else "Antes do início da carreira", str(int(cat["active"])), Fmt.plural(int(cat["pros"]), "profissional", "profissionais")], "Small", true))
	for p: Player in cat["best"]:
		v.add_child(_player_row(w, p))
	v.add_child(UIKit.button("Fechar", "GhostButton", func(): UIManager.close_modal()))
	UIManager.show_modal(v, true)


func _world_card(w: GameWorld) -> Control:
	var list: Array = []
	for wv: Dictionary in Generations.state(w)["waves"]:
		if int(wv["d"]) > 0:
			list.append(wv)
	if list.is_empty():
		return null
	list.sort_custom(func(a: Dictionary, b: Dictionary): return int(a["d"]) > int(b["d"]))
	var card := UIKit.card("Card", 4)
	card.add_child(UIKit.section("Gerações pelo mundo"))
	for wv: Dictionary in list.slice(0, 10):
		var row := UIKit.hbox(10)
		row.add_child(UIKit.flag(String(wv["n"]), 36))
		var col := UIKit.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UIKit.label(Generations.name_of(wv), "H3", true))
		var best := Generations.members(w, wv, 3)
		var names: Array = []
		for p: Player in best:
			names.append(p.display_name())
		col.add_child(UIKit.label(", ".join(PackedStringArray(names)), "Small", true))
		row.add_child(col)
		var n := String(wv["n"])
		card.add_child(UIKit.tap_row(row, func():
			_nation = n
			refresh()
			var sc := scroll()
			if sc != null:
				sc.scroll_vertical = 0, "CardFlat"))
	return UIKit.card_panel(card)


func _player_row(w: GameWorld, p: Player) -> Control:
	var h := UIKit.hbox(10)
	var cl := w.club(p.club_id)
	h.add_child(UIKit.photo(p, cl, w.year, Vector2(56, 56), "perfil"))
	var v := UIKit.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var n := UIKit.label(p.display_name(), "H3")
	n.clip_text = true
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(n)
	v.add_child(UIKit.label("%s · %d anos · %s" % [Pos.code(p.position), p.age(w.year), cl.short_name if cl != null else "sem clube"], "Small"))
	h.add_child(v)
	h.add_child(UIKit.player_stars(w, p, 15))
	var pid := p.id
	return UIKit.tap_row(h, func(): UIManager.push("player", {"id": pid}), "CardFlat")
