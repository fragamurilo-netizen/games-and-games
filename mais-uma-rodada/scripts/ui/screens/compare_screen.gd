extends BaseScreen
## Comparador de jogadores: dois lado a lado (perfil, atributos, temporada e carreira).
## Sem o segundo jogador, mostra sugestões (mesma posição no seu elenco) e uma busca por nome.
## Atributos de quem não é do seu clube aparecem como o olheiro vê (aproximados), igual ao perfil.

var _a := -1
var _b := -1
var _query := ""


func _init() -> void:
	show_nav = false
	screen_title = "Comparar"


func setup(p: Dictionary) -> void:
	super.setup(p)
	_a = int(p.get("a", -1))
	_b = int(p.get("b", -1))


func refresh() -> void:
	var w := world()
	if w == null:
		return
	var pa := w.player(_a)
	var c := content()
	UIKit.clear(c)
	hide_footer()
	if pa == null:
		c.add_child(UIKit.label("Jogador não encontrado.", "Muted"))
		return
	var pb := w.player(_b)
	if pb == null:
		screen_subtitle = pa.display_name()
		UIManager.refresh_chrome()
		_picker(w, pa, c)
		return
	screen_subtitle = "%s × %s" % [pa.display_name(), pb.display_name()]
	UIManager.refresh_chrome()
	c.add_child(_heads(w, pa, pb))
	c.add_child(_attrs(w, pa, pb))
	c.add_child(_season(w, pa, pb))
	c.add_child(_career_card(w, pa, pb))
	var f := footer()
	UIKit.clear(f)
	var row := UIKit.hbox(10)
	var sw := UIKit.button("Inverter", "", func():
		var t := _a
		_a = _b
		_b = t
		refresh(), "swap")
	sw.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sw)
	var other := UIKit.button("Trocar jogador", "", func():
		_b = -1
		refresh(), "search")
	other.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(other)
	f.add_child(row)
	f.visible = true


# ---------------------------------------------------------------------------
# Escolha do segundo jogador
# ---------------------------------------------------------------------------

func _picker(w: GameWorld, pa: Player, c: VBoxContainer) -> void:
	var card := UIKit.card("Card", 8)
	card.add_child(UIKit.section("Comparar %s com…" % pa.display_name()))
	var le := LineEdit.new()
	le.placeholder_text = "Buscar jogador pelo nome"
	le.text = _query
	le.clear_button_enabled = true
	card.add_child(le)
	var results := UIKit.vbox(6)
	card.add_child(results)
	var fill := func(q: String):
		_query = q
		UIKit.clear(results)
		var list := _suggestions(w, pa) if q.strip_edges().length() < 3 else _search(w, pa, q.strip_edges())
		if list.is_empty():
			results.add_child(UIKit.label("Ninguém encontrado.", "Muted"))
		if q.strip_edges().length() < 3:
			results.add_child(UIKit.label("Mesma posição no seu elenco e os melhores do mundo na função", "Caps"))
		for p: Player in list:
			results.add_child(_pick_row(w, p))
	le.text_changed.connect(func(t: String): fill.call(t))
	fill.call(_query)
	c.add_child(UIKit.card_panel(card))


func _pick_row(w: GameWorld, p: Player) -> Control:
	var row := UIKit.hbox(10)
	row.add_child(UIKit.pos_badge(p.position))
	var col := UIKit.vbox(0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UIKit.label(p.display_name(), "H3"))
	var cl := w.club(p.club_id) if p.club_id >= 0 else null
	col.add_child(UIKit.label("%d anos · %s" % [p.age(w.year), cl.short_name if cl != null else "sem clube"], "Small"))
	row.add_child(col)
	row.add_child(UIKit.badge(_seen_ovr(w, p)))
	var pid := p.id
	return UIKit.tap_row(row, func():
		_b = pid
		refresh())


func _suggestions(w: GameWorld, pa: Player) -> Array:
	var out: Array = []
	var grp := Pos.group(pa.position)
	if w.has_user():
		for p: Player in w.squad(w.user_club()):
			if p.id != pa.id and Pos.group(p.position) == grp:
				out.append(p)
	out.sort_custom(func(x: Player, y: Player): return x.overall > y.overall)
	out = out.slice(0, 6)
	var best: Array = []
	for p: Player in w.players.values():
		if p.id != pa.id and p.position == pa.position and p.club_id >= 0 and p.overall >= 80:
			best.append(p)
	best.sort_custom(func(x: Player, y: Player): return x.overall > y.overall)
	for p in best.slice(0, 4):
		if not out.has(p):
			out.append(p)
	return out


func _search(w: GameWorld, pa: Player, q: String) -> Array:
	var ql := q.to_lower()
	var out: Array = []
	for p: Player in w.players.values():
		if p.id == pa.id:
			continue
		if p.display_name().to_lower().contains(ql) or p.full_name().to_lower().contains(ql):
			out.append(p)
	out.sort_custom(func(x: Player, y: Player): return x.overall > y.overall)
	return out.slice(0, 20)


# ---------------------------------------------------------------------------
# Comparação
# ---------------------------------------------------------------------------

func _own(w: GameWorld, p: Player) -> bool:
	return p.club_id >= 0 and w.is_user_club(p.club_id)


## Atributo como o treinador enxerga (exato no próprio elenco; aproximado nos outros).
func _seen(w: GameWorld, p: Player, a: int) -> int:
	var v: int = p.attrs[a]
	if not _own(w, p):
		v = clampi(v + int(round(RngUtil.noise(p.id, a, 7) * 5.0)), 1, 99)
	return v


func _seen_ovr(w: GameWorld, p: Player) -> int:
	return p.overall if _own(w, p) else clampi(p.overall + int(round(RngUtil.noise(p.id, 99, 7) * 2.0)), 1, 99)


func _heads(w: GameWorld, pa: Player, pb: Player) -> Control:
	var card := UIKit.card("Card", 10)
	var row := UIKit.hbox(8)
	row.add_child(_head(w, pa, HORIZONTAL_ALIGNMENT_LEFT))
	var vs := UIKit.label("×", "Title")
	vs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(vs)
	row.add_child(_head(w, pb, HORIZONTAL_ALIGNMENT_RIGHT))
	card.add_child(row)
	var ca := w.club(pa.club_id) if pa.club_id >= 0 else null
	var cb := w.club(pb.club_id) if pb.club_id >= 0 else null
	for r in [
		["Overall", _seen_ovr(w, pa), _seen_ovr(w, pb), true, ""],
		["Idade", pa.age(w.year), pb.age(w.year), false, ""],
		["Valor", pa.value, pb.value, true, "money"],
		["Salário", pa.wage, pb.wage, false, "wage"],
		["Contrato até", pa.contract_end if pa.club_id >= 0 else 0, pb.contract_end if pb.club_id >= 0 else 0, true, "year"],
	]:
		card.add_child(_line(String(r[0]), r[1], r[2], bool(r[3]), String(r[4])))
	card.add_child(_text_line("Clube", ca.short_name if ca != null else "—", cb.short_name if cb != null else "—"))
	card.add_child(_text_line("Posição", Pos.name_of(pa.position), Pos.name_of(pb.position)))
	card.add_child(_text_line("Estilo", PlayStyle.of(pa), PlayStyle.of(pb)))
	return UIKit.card_panel(card)


func _head(w: GameWorld, p: Player, align: int) -> Control:
	var col := UIKit.vbox(4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cl := w.club(p.club_id) if p.club_id >= 0 else null
	var top := UIKit.hbox(6)
	top.alignment = BoxContainer.ALIGNMENT_BEGIN if align == HORIZONTAL_ALIGNMENT_LEFT else BoxContainer.ALIGNMENT_END
	top.add_child(UIKit.portrait(p, cl, w.year, 110))
	col.add_child(top)
	var n := UIKit.label(p.display_name(), "H3")
	n.horizontal_alignment = align
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(n)
	var pid := p.id
	var b := UIKit.button("Perfil", "GhostButton", func(): UIManager.push("player", {"id": pid}))
	col.add_child(b)
	return col


## Linha numérica: o melhor lado fica destacado (higher_better decide a direção).
func _line(caption: String, va, vb, higher_better: bool, fmt: String) -> Control:
	var row := UIKit.hbox(8)
	var fa := _fmt(va, fmt)
	var fb := _fmt(vb, fmt)
	var la := UIKit.label(fa, "H3")
	la.custom_minimum_size.x = 160
	var lb := UIKit.label(fb, "H3")
	lb.custom_minimum_size.x = 160
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if float(va) != float(vb) and fmt != "wage":
		var a_better: bool = (float(va) > float(vb)) == higher_better
		(la if a_better else lb).add_theme_color_override(&"font_color", UIColors.GREEN)
	row.add_child(la)
	var cl := UIKit.label(caption, "Small")
	cl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(cl)
	row.add_child(lb)
	return row


func _text_line(caption: String, a: String, b: String) -> Control:
	var row := UIKit.hbox(8)
	var la := UIKit.label(a, "")
	la.custom_minimum_size.x = 200
	la.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(la)
	var cl := UIKit.label(caption, "Small")
	cl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(cl)
	var lb := UIKit.label(b, "")
	lb.custom_minimum_size.x = 200
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lb.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(lb)
	return row


func _fmt(v, fmt: String) -> String:
	match fmt:
		"money":
			return Fmt.money(int(v))
		"wage":
			return Fmt.money_month(int(v))
		"year":
			return "—" if int(v) <= 0 else str(int(v))
		"dec":
			return TacticalXRay.dec(float(v), 2)
		"rating":
			return "—" if float(v) <= 0.0 else Fmt.rating(float(v))
	return str(v)


## Atributos em barras espelhadas: A cresce para a esquerda, B para a direita.
func _attrs(w: GameWorld, pa: Player, pb: Player) -> Control:
	var card := UIKit.card("Card", 6)
	var own_both := _own(w, pa) and _own(w, pb)
	card.add_child(UIKit.section("Atributos" + ("" if own_both else " (olheiro: valores aproximados)")))
	var gk := pa.position == Pos.GK or pb.position == Pos.GK
	var wins := [0, 0]
	for g in Attr.UI_GROUPS:
		if String(g[0]) == "Goleiro" and not gk:
			continue
		card.add_child(UIKit.label(g[0], "Caps"))
		for a in g[1]:
			var va := _seen(w, pa, a)
			var vb := _seen(w, pb, a)
			if va > vb:
				wins[0] += 1
			elif vb > va:
				wins[1] += 1
			var row := UIKit.hbox(6)
			var na := UIKit.label(str(va), "Mono")
			na.custom_minimum_size.x = 44
			na.add_theme_color_override(&"font_color", Fmt.rating_color(va) if va >= vb else UIColors.MUTED)
			row.add_child(na)
			var ba := UIKit.bar(va, 100.0, Fmt.rating_color(va) if va >= vb else UIColors.DIM, 10)
			ba.fill_mode = ProgressBar.FILL_END_TO_BEGIN
			ba.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			ba.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(ba)
			var nm := UIKit.label(Attr.NAMES[a], "Small")
			nm.custom_minimum_size.x = 170
			nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			row.add_child(nm)
			var bb := UIKit.bar(vb, 100.0, Fmt.rating_color(vb) if vb >= va else UIColors.DIM, 10)
			bb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			bb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(bb)
			var nb := UIKit.label(str(vb), "Mono")
			nb.custom_minimum_size.x = 44
			nb.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			nb.add_theme_color_override(&"font_color", Fmt.rating_color(vb) if vb >= va else UIColors.MUTED)
			row.add_child(nb)
			card.add_child(row)
	card.add_child(UIKit.separator())
	card.add_child(_line("atributos melhores", wins[0], wins[1], true, ""))
	return UIKit.card_panel(card)


func _season(w: GameWorld, pa: Player, pb: Player) -> Control:
	var card := UIKit.card("Card", 6)
	card.add_child(UIKit.section("Temporada %d (liga)" % w.year))
	var ta := pa.season_totals()
	var tb := pb.season_totals()
	card.add_child(_line("Jogos (todas)", int(ta[0]), int(tb[0]), true, ""))
	card.add_child(_line("Gols (todas)", int(ta[1]), int(tb[1]), true, ""))
	card.add_child(_line("Assistências (todas)", int(ta[2]), int(tb[2]), true, ""))
	card.add_child(_line("Nota média", pa.avg_rating() if pa.stats[Player.S_APPS] > 0 else 0.0, pb.avg_rating() if pb.stats[Player.S_APPS] > 0 else 0.0, true, "rating"))
	var gk := pa.position == Pos.GK and pb.position == Pos.GK
	if gk:
		card.add_child(_line("Defesas /90", pa.per90(Player.S_SAVES), pb.per90(Player.S_SAVES), true, "dec"))
		card.add_child(_line("Jogos sem sofrer gol", pa.stats[Player.S_CLEAN], pb.stats[Player.S_CLEAN], true, ""))
	else:
		card.add_child(_line("xG", pa.xg(), pb.xg(), true, "dec"))
		card.add_child(_line("Chutes /90", pa.per90(Player.S_SHOTS), pb.per90(Player.S_SHOTS), true, "dec"))
		card.add_child(_line("Passes decisivos /90", pa.per90(Player.S_KEY_PASSES), pb.per90(Player.S_KEY_PASSES), true, "dec"))
		card.add_child(_line("Dribles /90", pa.per90(Player.S_DRIBBLES), pb.per90(Player.S_DRIBBLES), true, "dec"))
		card.add_child(_line("Desarmes /90", pa.per90(Player.S_TACKLES), pb.per90(Player.S_TACKLES), true, "dec"))
		card.add_child(_line("Passes certos %", int(round(pa.pass_pct())), int(round(pb.pass_pct())), true, ""))
	return UIKit.card_panel(card)


func _career_card(w: GameWorld, pa: Player, pb: Player) -> Control:
	var card := UIKit.card("Card", 6)
	card.add_child(UIKit.section("Carreira"))
	card.add_child(_line("Jogos", pa.career_apps, pb.career_apps, true, ""))
	card.add_child(_line("Gols", pa.career_goals, pb.career_goals, true, ""))
	card.add_child(_line("Assistências", pa.career_assists, pb.career_assists, true, ""))
	card.add_child(_line("Títulos", pa.titles, pb.titles, true, ""))
	card.add_child(_line("Prêmios", pa.awards.size(), pb.awards.size(), true, ""))
	var caps_a := NationalTeamManager.caps_of(w, pa.id)
	var caps_b := NationalTeamManager.caps_of(w, pb.id)
	card.add_child(_line("Jogos pela seleção", int(caps_a[0]), int(caps_b[0]), true, ""))
	return UIKit.card_panel(card)
