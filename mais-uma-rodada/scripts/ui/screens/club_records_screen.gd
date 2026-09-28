extends BaseScreen
## Memória do clube: melhor 11 de sempre e de cada temporada, e o histórico de transferências
## (do clube ou, com {"mode": "manager"}, de toda a carreira do técnico).

const TABS := [["xi", "Melhor 11"], ["transfers", "Transferências"]]
const DIRS := [["all", "Todas"], ["in", "Chegadas"], ["out", "Saídas"]]
const MAX_ROWS := 80

var _club_id := -1
var _tab := "xi"
var _manager := false
var _year := "all"
var _tyear := "all"
var _dir := "all"


func _init() -> void:
	show_nav = false
	screen_title = "Memória do clube"


func setup(p: Dictionary) -> void:
	super.setup(p)
	_club_id = int(p.get("id", -1))
	_tab = String(p.get("tab", _tab))
	_manager = String(p.get("mode", "")) == "manager"
	if _manager:
		_tab = "transfers"


func refresh() -> void:
	var w := world()
	if w == null:
		return
	var club := w.club(_club_id) if _club_id >= 0 else w.user_club()
	if club == null and not _manager:
		return
	screen_title = "Minhas transferências" if _manager else "Memória do clube"
	screen_subtitle = w.manager_name if _manager else (club.short_name if club != null else "")
	UIManager.refresh_chrome()
	var c := content()
	UIKit.clear(c)
	if not _manager:
		c.add_child(UIKit.tabs(TABS, _tab, func(k: String):
			_tab = k
			refresh()
			scroll_to_top()))
	if _tab == "transfers":
		_transfers(w, club, c)
	else:
		_xi(w, club, c)


# ---------------------------------------------------------------------------
# Melhor 11
# ---------------------------------------------------------------------------

func _xi(w: GameWorld, club: Club, c: VBoxContainer) -> void:
	var items: Array = [["all", "De sempre"]]
	for y in ClubRecords.years(w, club):
		items.append([str(y), str(y) if int(y) != w.year else "%d (atual)" % int(y)])
	c.add_child(UIKit.scroll_tabs(items, _year, func(k: String):
		_year = k
		refresh()))
	var cands: Array = ClubRecords.all_time(w, club) if _year == "all" else ClubRecords.season_candidates(w, club, int(_year))
	if cands.size() < 11:
		c.add_child(UIKit.label("Jogos insuficientes nesta temporada.", "Muted", true))
		if cands.is_empty():
			return
	var slots := ClubRecords.pick_xi(cands)
	var card := UIKit.card("Card", 12)
	var title := "Melhor 11 de sempre" if _year == "all" else "Melhor 11 de %s" % _year
	card.add_child(UIKit.section_header(title))
	var pitch := UIKit.vbox(10)
	var chip_w := clampf((content_width() - 240.0) / 4.0, 100.0, 170.0)
	for line: Array in [[8, 10, 9], [6, 5, 7], [4, 1, 2, 3], [0]]:
		var h := HBoxContainer.new()
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_theme_constant_override(&"separation", 8)
		for i: int in line:
			h.add_child(_chip(w, club, slots[i], _year == "all", chip_w))
		pitch.add_child(h)
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = UIColors.GREEN.darkened(0.72)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	pc.add_theme_stylebox_override(&"panel", sb)
	pc.add_child(pitch)
	card.add_child(pc)
	c.add_child(UIKit.card_panel(card))
	# Ranking completo
	var lc := UIKit.card("Card", 4)
	lc.add_child(UIKit.section_header("Lendas do clube" if _year == "all" else "Destaques de %s" % _year))
	var sorted := cands.duplicate()
	sorted.sort_custom(func(a, b): return float(a["score"]) > float(b["score"]))
	for i in mini(15, sorted.size()):
		lc.add_child(_rank_row(w, i + 1, sorted[i], _year == "all"))
	c.add_child(UIKit.card_panel(lc))


func _chip(w: GameWorld, club: Club, slot: Array, all_time: bool, cw: float) -> Control:
	var v := UIKit.vbox(2)
	v.custom_minimum_size.x = cw
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var cd: Variant = slot[2]
	if cd == null:
		var l := UIKit.label(String(slot[0]), "Small")
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
		return v
	var d: Dictionary = cd
	var p := w.player(int(d["id"]))
	var top := CenterContainer.new()
	if p != null:
		top.add_child(UIKit.portrait(p, club, w.year, 72))
	else:
		top.add_child(UIKit.pos_badge(int(d["pos"])))
	v.add_child(top)
	var nm := UIKit.label(p.short_name() if p != null else String(d["n"]), "H3")
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.custom_minimum_size.x = cw - 4
	v.add_child(nm)
	var txt := ""
	if all_time:
		txt = "%d j · %d g · %.2f" % [int(d["a"]), int(d["g"]), float(d["r"])]
	else:
		txt = "%.2f · %d j · %d g" % [float(d["r"]), int(d["a"]), int(d["g"])]
	var st := UIKit.label(txt, "Small")
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(st)
	var pid := int(d["id"])
	if p == null:
		return v
	var tr := UIKit.tap_row(v, func(): UIManager.push("player", {"id": pid}), "CardFlat")
	return tr


func _rank_row(w: GameWorld, n: int, d: Dictionary, all_time: bool) -> Control:
	var h := UIKit.hbox(10)
	var num := UIKit.label(str(n), "H3")
	num.custom_minimum_size.x = 30
	num.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	num.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(num)
	var badge := UIKit.pos_badge(int(d["pos"]))
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	h.add_child(badge)
	var col := UIKit.vbox(0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nm := UIKit.label(String(d["n"]), "H3")
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(nm)
	var sub := ""
	if all_time:
		var span := str(int(d["from"])) if int(d["from"]) == int(d["to"]) else "%d–%d" % [int(d["from"]), int(d["to"])]
		sub = "%s · %d j · %d g · %d a" % [span, int(d["a"]), int(d["g"]), int(d["as"])]
	else:
		sub = "%d j · %d g · %d a · nível %d" % [int(d["a"]), int(d["g"]), int(d["as"]), int(d["o"])]
	var sl := UIKit.label(sub, "Small")
	sl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(sl)
	h.add_child(col)
	var rt := UIKit.label("%.2f" % float(d["r"]), "H3")
	rt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(rt)
	var pid := int(d["id"])
	if w.player(pid) == null:
		return UIKit.margin(h, 8, 6, 8, 6)
	return UIKit.tap_row(h, func(): UIManager.push("player", {"id": pid}), "RowPanel")


# ---------------------------------------------------------------------------
# Transferências
# ---------------------------------------------------------------------------

func _transfers(w: GameWorld, club: Club, c: VBoxContainer) -> void:
	# [Transfer, id do "nosso" clube naquela negociação]
	var all: Array = []
	if _manager:
		for e: Array in ClubRecords.manager_transfers(w):
			all.append([e[0], int(e[1])])
	else:
		for t: Transfer in ClubRecords.club_transfers(w, club):
			all.append([t, club.id])
	var ys := {}
	for e: Array in all:
		ys[(e[0] as Transfer).year] = true
	var yl: Array = ys.keys()
	yl.sort()
	yl.reverse()
	var items: Array = [["all", "Todas as temporadas"]]
	for y in yl:
		items.append([str(y), str(y)])
	c.add_child(UIKit.scroll_tabs(items, _tyear, func(k: String):
		_tyear = k
		refresh()))
	c.add_child(UIKit.segment(DIRS, _dir, func(k: String):
		_dir = k
		refresh()))
	var list: Array = []
	var spent := 0
	var got := 0
	var n_in := 0
	var n_out := 0
	var best_in: Array = []
	var best_out: Array = []
	for e: Array in all:
		var t: Transfer = e[0]
		var ours := int(e[1])
		if t.kind == Transfer.KIND_RELEASE and _dir == "in":
			continue
		if _tyear != "all" and str(t.year) != _tyear:
			continue
		var incoming := t.to_id == ours
		if (_dir == "in" and not incoming) or (_dir == "out" and incoming):
			continue
		list.append(e)
		if t.kind == Transfer.KIND_RELEASE:
			continue
		if incoming:
			spent += t.fee
			n_in += 1
			if best_in.is_empty() or t.fee > (best_in[0] as Transfer).fee:
				best_in = e
		else:
			got += t.fee
			n_out += 1
			if best_out.is_empty() or t.fee > (best_out[0] as Transfer).fee:
				best_out = e
	var sc := UIKit.card("Card", 10)
	sc.add_child(UIKit.section_header("Balanço" + ("" if _tyear == "all" else " de " + _tyear)))
	var net := got - spent
	sc.add_child(UIKit.stat_grid([
		UIKit.stat_tile(Fmt.money(spent), "gastos · %d chegadas" % n_in, UIColors.RED if spent > 0 else UIColors.TEXT),
		UIKit.stat_tile(Fmt.money(got), "vendas · %d saídas" % n_out, UIColors.GREEN if got > 0 else UIColors.TEXT),
		UIKit.stat_tile(("+" if net > 0 else "") + Fmt.money(net), "saldo", UIColors.GREEN if net > 0 else (UIColors.RED if net < 0 else UIColors.TEXT)),
	], content_width() - 40))
	if not best_in.is_empty() and (best_in[0] as Transfer).fee > 0:
		var t: Transfer = best_in[0]
		sc.add_child(UIKit.kv("Maior contratação", "%s · %s (%d)" % [t.player_name, Fmt.money(t.fee), t.year]))
	if not best_out.is_empty() and (best_out[0] as Transfer).fee > 0:
		var t: Transfer = best_out[0]
		sc.add_child(UIKit.kv("Maior venda", "%s · %s (%d)" % [t.player_name, Fmt.money(t.fee), t.year]))
	c.add_child(UIKit.card_panel(sc))
	var lc := UIKit.card("Card", 4)
	lc.add_child(UIKit.label(Fmt.plural(list.size(), "negociação", "negociações"), "Caps"))
	if list.is_empty():
		lc.add_child(UIKit.label("Nenhuma negociação.", "Muted", true))
	for i in mini(MAX_ROWS, list.size()):
		lc.add_child(_move_row(w, list[i][0], int(list[i][1])))
	c.add_child(UIKit.card_panel(lc))


func _move_row(w: GameWorld, t: Transfer, ours: int) -> Control:
	var row := UIKit.hbox(10)
	var incoming := t.to_id == ours
	var other_id := t.from_id if incoming else t.to_id
	var other := w.club(other_id) if other_id >= 0 else null
	var tag := UIKit.pill("CHEGOU" if incoming else ("SAIU" if t.kind != Transfer.KIND_RELEASE else "RESCISÃO"), UIColors.GREEN if incoming else UIColors.RED, 13)
	tag.custom_minimum_size.x = 96
	row.add_child(tag)
	if other != null:
		row.add_child(UIKit.crest(other, 40))
	var col := UIKit.vbox(0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nm := UIKit.label(t.player_name, "H3")
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(nm)
	var where := ("de " if incoming else "para ") + (other.short_name if other != null else ("livre" if incoming else "sem clube"))
	if _manager:
		var mine := w.club(ours)
		where += " · " + (mine.short_name if mine != null else "")
	var when := "rodada %d · %d" % [t.day + 1, t.year] if t.day < 38 else str(t.year)
	var sub := UIKit.label("%s · %d anos · nível %d · %s" % [where, t.age, t.overall, when], "Small")
	sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(sub)
	row.add_child(col)
	var fee := UIKit.label(Fmt.money(t.fee) if t.fee > 0 else "—", "Stat")
	fee.add_theme_font_size_override(&"font_size", 22)
	row.add_child(fee)
	var pid := t.player_id
	if w.player(pid) == null:
		return UIKit.margin(row, 8, 6, 8, 6)
	return UIKit.tap_row(row, func(): UIManager.push("player", {"id": pid}), "RowPanel")


func color_context() -> Dictionary:
	return club_context(_club_id)
