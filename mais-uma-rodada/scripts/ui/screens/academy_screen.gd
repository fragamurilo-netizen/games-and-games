extends BaseScreen
## Categorias de base: os garotos por categoria, as ligas sub-20 e sub-17, os jogos, a captação
## (com a peneira) e os revelados pela base.

const TABS := [["players", "Garotos"], ["u20", "Sub-20"], ["u17", "Sub-17"], ["games", "Jogos"], ["scout", "Captação"], ["grads", "Revelados"]]

var _tab := "players"


func _init() -> void:
	show_nav = false
	screen_title = "Categorias de base"


func setup(p: Dictionary) -> void:
	super.setup(p)
	_tab = String(p.get("tab", "players"))
	if _tab == "table":
		_tab = "u20"


func refresh() -> void:
	var w := world()
	if w == null:
		return
	YouthManager.ensure_academy(w)
	var club := w.user_club()
	screen_subtitle = "%s · %d garotos" % [club.short_name, w.academy.size()]
	UIManager.refresh_chrome()
	var c := content()
	UIKit.clear(c)
	c.add_child(_header(w, club))
	var g := ButtonGroup.new()
	var row := UIKit.flow(8)
	for t in TABS:
		var key: String = t[0]
		var chip := UIKit.chip(t[1], key == _tab, g, func():
			_tab = key
			refresh())
		row.add_child(chip)
	c.add_child(row)
	match _tab:
		"players":
			for cat in YouthManager.CATEGORIES:
				var box := _players(w, club, cat)
				if box != null:
					c.add_child(box)
		"u20", "u17":
			c.add_child(_table(w, _tab))
			c.add_child(_scorers(w, _tab))
		"games":
			c.add_child(_games(w))
		"scout":
			c.add_child(_scouting(w))
			c.add_child(_trial(w))
		"grads":
			c.add_child(_grads(w))


func _header(w: GameWorld, club: Club) -> Control:
	var card := UIKit.card("CardHighlight", 8)
	var row := UIKit.hbox(4)
	row.add_child(UIKit.stat(str(club.youth_level), "nível da base", UIColors.ACCENT))
	row.add_child(UIKit.stat("%d/%d" % [w.academy.size(), YouthManager.MAX_SIZE], "garotos"))
	row.add_child(UIKit.stat(_pos_text(w, "u20"), "no sub-20"))
	row.add_child(UIKit.stat(_pos_text(w, "u17"), "no sub-17"))
	card.add_child(row)
	card.add_child(UIKit.label("Estrelas: estimativa da comissão, não o teto real.", "Small", true))
	return UIKit.card_panel(card)


func _pos_text(w: GameWorld, key: String) -> String:
	if not YouthManager.has_league(w, key):
		return "—"
	var yl := YouthManager.league(w, key)
	if not yl["table"].has(w.user_club_id) or int(yl["table"][w.user_club_id]["pl"]) == 0:
		return "—"
	return "%dº" % (YouthManager.sorted_table(w, key).find(w.user_club_id) + 1)


# ---------------------------------------------------------------------------
# Garotos
# ---------------------------------------------------------------------------

func _players(w: GameWorld, club: Club, cat: Array) -> Control:
	var list := YouthManager.in_category(w, String(cat[0]))
	var card := UIKit.card("Card", 6)
	card.add_child(UIKit.section("%s · %s · %d" % [cat[1], cat[2], list.size()]))
	if list.is_empty():
		card.add_child(UIKit.label("Nenhum garoto nesta categoria. Novos garotos chegam na virada da temporada ou pela peneira.", "Muted", true))
		return UIKit.card_panel(card)
	for p: Player in list:
		card.add_child(UIKit.tap_row(_kid_row(w, club, p), func(): _actions(p)))
	return UIKit.card_panel(card)


func _kid_row(w: GameWorld, club: Club, p: Player) -> Control:
	var row := UIKit.hbox(10)
	row.add_child(UIKit.portrait(p, club, w.year, 56))
	var col := UIKit.vbox(0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_row := UIKit.hbox(8)
	name_row.add_child(UIKit.pos_badge(p.position))
	var nl := UIKit.label(p.display_name(), "H3")
	nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(nl)
	col.add_child(name_row)
	var age := p.age(w.year)
	var info := "%d anos · %s" % [age, YouthManager.potential_label_of(w, p)]
	if p.stats[Player.S_APPS] > 0:
		info += " · %d J %d G · %.1f" % [p.stats[Player.S_APPS], p.stats[Player.S_GOALS], p.avg_rating()]
	col.add_child(UIKit.colored(info, UIColors.ORANGE if age >= YouthManager.MAX_AGE else UIColors.MUTED, "Small"))
	row.add_child(col)
	row.add_child(_stars(w, p, 14))
	row.add_child(UIKit.badge(p.overall, 52, 38, 22))
	return row


func _stars(w: GameWorld, p: Player, px: float) -> StarsView:
	var st := StarsView.new()
	st.star_size = px
	st.stars = YouthManager.potential_stars(w, p)
	st.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return st


func _actions(p: Player) -> void:
	var w := world()
	var v := UIKit.vbox(12)
	var head := UIKit.hbox(12)
	head.add_child(UIKit.portrait(p, w.user_club(), w.year, 84))
	var col := UIKit.vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UIKit.label(p.full_name(), "Title", true))
	col.add_child(UIKit.label("%s · %d anos · %s · %s" % [Pos.name_of(p.position), p.age(w.year), YouthManager.category_name(YouthManager.category(p, w.year)), p.playstyle()], "Small", true))
	col.add_child(UIKit.label("Estimativa da base: %s" % YouthManager.potential_text(w, p), "Small", true))
	col.add_child(_stars(w, p, 20))
	head.add_child(col)
	head.add_child(UIKit.badge(p.overall))
	v.add_child(head)
	var yrs := YouthManager.years_in(w, p)
	var pr := YouthManager.precision(w, p)
	var know := "Ainda conhecemos pouco dele." if pr < 0.5 else ("Já dá para ter uma boa ideia do teto dele." if pr < 0.75 else "Conhecemos bem o garoto.")
	v.add_child(UIKit.label("%s na base. %s" % ["Chegou nesta temporada" if yrs == 0 else ("%d ano(s)" % yrs), know], "Small", true))
	if p.stats[Player.S_APPS] > 0:
		v.add_child(UIKit.label("Temporada: %d jogos · %d gols · %d assistências · nota %.1f · %d min" % [p.stats[Player.S_APPS], p.stats[Player.S_GOALS], p.stats[Player.S_ASSISTS], p.avg_rating(), p.stats[Player.S_MINUTES]], "Small", true))
	var pf := YouthManager.play_factor(w, p)
	if pf < 0.95:
		v.add_child(UIKit.colored("Joga pouco e está evoluindo menos que os outros.", UIColors.ORANGE, "Small", true))
	elif pf > 1.08:
		v.add_child(UIKit.colored("Titular da categoria: os jogos aceleram a evolução.", UIColors.GREEN, "Small", true))
	var weakest := 99
	for q: Player in w.squad(w.user_club()):
		weakest = mini(weakest, q.overall)
	v.add_child(UIKit.label("O jogador mais fraco do elenco principal tem %d." % weakest, "Small", true))
	v.add_child(UIKit.button("SUBIR AO PROFISSIONAL", "PrimaryButton", func():
		UIManager.close_modal()
		UIManager.toast(YouthManager.promote(w, p))
		GameManager.save_now()
		refresh(), "up"))
	v.add_child(UIKit.button("Ver perfil completo", "", func():
		UIManager.close_modal()
		UIManager.push("player", {"id": p.id}), "info"))
	v.add_child(UIKit.button("Dispensar", "DangerButton", func():
		UIManager.close_modal()
		UIManager.confirm("Dispensar %s?" % p.display_name(), "Ele deixa a base do clube.", "Dispensar", func():
			YouthManager.release(w, p)
			refresh())))
	UIManager.show_modal(v, true)


# ---------------------------------------------------------------------------
# Ligas e jogos
# ---------------------------------------------------------------------------

func _table(w: GameWorld, key: String) -> Control:
	var card := UIKit.card("Card", 4)
	if not YouthManager.has_league(w, key):
		card.add_child(UIKit.label("Sem liga %s nesta temporada. Ela começa na próxima." % ("sub-20" if key == "u20" else "sub-17"), "Muted", true))
		return UIKit.card_panel(card)
	var yl := YouthManager.league(w, key)
	card.add_child(UIKit.section(String(yl["name"])))
	card.add_child(TableRows.header(true))
	var order := YouthManager.sorted_table(w, key)
	for i in order.size():
		var cid: int = order[i]
		var zone := CompetitionManager.zone_color(CompetitionManager.ZONE_TITLE) if i == 0 else Color(0, 0, 0, 0)
		card.add_child(TableRows.table_row(w, yl["table"][cid], cid, i + 1, true, zone))
	return UIKit.card_panel(card)


func _scorers(w: GameWorld, key: String) -> Control:
	var card := UIKit.card("Card", 6)
	card.add_child(UIKit.section("Artilharia do %s" % ("sub-20" if key == "u20" else "sub-17")))
	var list := YouthManager.top_scorers(w, 12, key)
	if list.is_empty():
		card.add_child(UIKit.label("Ninguém marcou ainda.", "Muted"))
	for i in list.size():
		var e: Dictionary = list[i]
		var row := UIKit.hbox(10)
		var rk := UIKit.label(str(i + 1), "H3")
		rk.custom_minimum_size.x = 36
		row.add_child(rk)
		var cl := w.club(int(e["c"]))
		row.add_child(UIKit.crest(cl, 32))
		var col := UIKit.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var nl := UIKit.label(String(e["n"]), "H3")
		nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		if w.is_user_club(cl.id):
			nl.add_theme_color_override(&"font_color", UIColors.ACCENT)
		col.add_child(nl)
		col.add_child(UIKit.label(cl.short_name, "Small"))
		row.add_child(col)
		row.add_child(UIKit.label("%d gols" % int(e["g"]), "Stat"))
		card.add_child(row)
	return UIKit.card_panel(card)


func _games(w: GameWorld) -> Control:
	var box := UIKit.vbox(12)
	for key in ["u20", "u17"]:
		var card := UIKit.card("Card", 6)
		card.add_child(UIKit.section("Jogos do seu %s" % ("sub-20" if key == "u20" else "sub-17")))
		if not YouthManager.has_league(w, key):
			card.add_child(UIKit.label("Sem liga nesta temporada.", "Muted"))
			box.add_child(UIKit.card_panel(card))
			continue
		var yl := YouthManager.league(w, key)
		var uid := w.user_club_id
		var rounds: Array = yl["rounds"]
		var slots: Array = yl["slots"]
		for r in rounds.size():
			for g in rounds[r]:
				if int(g[0]) != uid and int(g[1]) != uid:
					continue
				card.add_child(_game_row(w, g, r, slots, uid))
		box.add_child(UIKit.card_panel(card))
	return box


func _game_row(w: GameWorld, g: Array, r: int, slots: Array, uid: int) -> Control:
	var home := int(g[0]) == uid
	var opp := w.club(int(g[1]) if home else int(g[0]))
	var v := UIKit.vbox(2)
	var row := UIKit.hbox(10)
	if int(g[2]) >= 0:
		var mine := int(g[2]) if home else int(g[3])
		var theirs := int(g[3]) if home else int(g[2])
		var res := "V" if mine > theirs else ("E" if mine == theirs else "D")
		row.add_child(UIKit.text_badge(res, UIColors.result_color(res), 40, 34, 20))
	else:
		row.add_child(UIKit.text_badge("%d" % (r + 1), UIColors.MUTED, 40, 34, 18))
	row.add_child(UIKit.crest(opp, 30))
	var l := UIKit.label(("vs " if home else "@ ") + opp.short_name, "")
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	if int(g[2]) >= 0:
		row.add_child(UIKit.label("%d x %d" % [int(g[2]) if home else int(g[3]), int(g[3]) if home else int(g[2])], "Stat"))
	else:
		row.add_child(UIKit.label(w.season.date_label(int(slots[r]), false), "Small"))
	v.add_child(row)
	if g.size() > 4 and g[4] is Dictionary:
		var info: Dictionary = g[4]
		var parts: Array = []
		if not Array(info.get("g", [])).is_empty():
			parts.append("Gols: " + ", ".join(PackedStringArray(info["g"])))
		if String(info.get("best", "")) != "":
			parts.append("Melhor em campo: " + String(info["best"]))
		if not parts.is_empty():
			v.add_child(UIKit.margin(UIKit.label(" · ".join(PackedStringArray(parts)), "Small", true), 50, 0, 0, 0))
	return v


# ---------------------------------------------------------------------------
# Captação e peneira
# ---------------------------------------------------------------------------

func _scouting(w: GameWorld) -> Control:
	var s := YouthManager.state(w)
	var club := w.user_club()
	var card := UIKit.card("Card", 8)
	card.add_child(UIKit.section("Onde procurar garotos"))
	for rk in YouthManager.REGION_ORDER:
		var cfg: Dictionary = YouthManager.REGIONS[rk]
		var sel := String(s["region"]) == rk
		var col := UIKit.vbox(2)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var top := UIKit.hbox(8)
		var nl := UIKit.label(String(cfg["name"]), "H3")
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if sel:
			nl.add_theme_color_override(&"font_color", UIColors.ACCENT)
		top.add_child(nl)
		var cost := YouthManager.scouting_cost(w, rk)
		top.add_child(UIKit.label("grátis" if cost == 0 else "%s/ano" % Fmt.money(cost), "Small"))
		col.add_child(top)
		col.add_child(UIKit.label(String(cfg["desc"]), "Small", true))
		var line := UIKit.hbox(10)
		line.add_child(col)
		var mark := UIKit.icon_rect("check", 30, UIColors.ACCENT)
		mark.modulate.a = 1.0 if sel else 0.0
		line.add_child(mark)
		card.add_child(UIKit.tap_row(line, func():
			YouthManager.set_region(w, rk)
			GameManager.save_now()
			refresh()))
	card.add_child(UIKit.section("Setor prioritário"))
	var g := ButtonGroup.new()
	var fl := UIKit.flow(8)
	for fk in YouthManager.FOCUS_ORDER:
		var chip := UIKit.chip(String(YouthManager.FOCUS[fk]["name"]), String(s["focus"]) == fk, g, func():
			YouthManager.set_focus(w, fk)
			GameManager.save_now()
			refresh())
		fl.add_child(chip)
	card.add_child(fl)
	card.add_child(UIKit.label("Chegam cerca de %d garotos por temporada." % YouthManager.intake_count(w, club), "Small", true))
	return UIKit.card_panel(card)


func _trial(w: GameWorld) -> Control:
	var card := UIKit.card("Card", 8)
	card.add_child(UIKit.section("Peneira"))
	var cands := YouthManager.candidates(w)
	if YouthManager.can_trial(w):
		card.add_child(UIKit.label("Uma por temporada, para garotos de 14 a 17 anos.", "Small", true))
		card.add_child(UIKit.button("FAZER PENEIRA · %s" % Fmt.money(YouthManager.trial_cost(w)), "PrimaryButton", func():
			var got := YouthManager.run_trial(w)
			UIManager.toast("%d garotos se destacaram na peneira." % got.size())
			GameManager.save_now()
			refresh(), "search"))
	elif cands.is_empty():
		card.add_child(UIKit.label("A peneira desta temporada já foi feita. A próxima abre na temporada que vem.", "Muted", true))
	if cands.is_empty():
		return UIKit.card_panel(card)
	card.add_child(UIKit.label("Destaques da peneira. Aprove quem quiser: ele entra na base agora.", "Small", true))
	var club := w.user_club()
	for p: Player in cands:
		var row := UIKit.hbox(10)
		row.add_child(UIKit.portrait(p, club, w.year, 52))
		var col := UIKit.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var nr := UIKit.hbox(8)
		nr.add_child(UIKit.pos_badge(p.position))
		var nl := UIKit.label(p.display_name(), "H3")
		nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nr.add_child(nl)
		col.add_child(nr)
		col.add_child(UIKit.label("%d anos · %s · %s" % [p.age(w.year), YouthManager.potential_label_of(w, p), p.hometown if p.hometown != "" else DatabaseManager.nation_name(p.nationality)], "Small"))
		row.add_child(col)
		row.add_child(UIKit.badge(p.overall, 48, 36, 20))
		var pid := p.id
		var ok := UIKit.icon_button("check", func():
			UIManager.toast(YouthManager.accept_candidate(w, pid))
			GameManager.save_now()
			refresh(), "Aprovar")
		row.add_child(ok)
		card.add_child(row)
	card.add_child(UIKit.button("Dispensar os demais", "", func():
		YouthManager.dismiss_candidates(w)
		GameManager.save_now()
		refresh()))
	return UIKit.card_panel(card)


# ---------------------------------------------------------------------------
# Revelados
# ---------------------------------------------------------------------------

func _grads(w: GameWorld) -> Control:
	var card := UIKit.card("Card", 6)
	var list := YouthManager.graduates(w)
	card.add_child(UIKit.section("Revelados pela base · %d" % list.size()))
	var total := YouthManager.sales_total(w)
	if total > 0:
		card.add_child(UIKit.kv("Arrecadado com vendas da base", Fmt.money(total), UIColors.GREEN))
	if list.is_empty():
		card.add_child(UIKit.label("Ninguém revelado ainda.", "Muted", true))
		return UIKit.card_panel(card)
	for e in list:
		var p: Player = e["p"]
		var row := UIKit.hbox(10)
		var cl: Club = w.club(p.club_id) if p != null and p.club_id >= 0 else null
		if cl != null:
			row.add_child(UIKit.crest(cl, 34))
		else:
			row.add_child(UIKit.text_badge("—", UIColors.MUTED, 34, 34, 18))
		var col := UIKit.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var nl := UIKit.label(String(e["n"]), "H3")
		nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		col.add_child(nl)
		var how := "subiu em %d" % int(e["y"])
		if int(e.get("fee", 0)) > 0:
			how = "vendido em %d por %s" % [int(e["y"]), Fmt.money(int(e["fee"]))]
		var now := "aposentado ou fora do futebol"
		if p != null:
			now = "%d anos · %s" % [p.age(w.year), cl.short_name if cl != null else "sem clube"]
		col.add_child(UIKit.label("%s · %s" % [how, now], "Small", true))
		row.add_child(col)
		row.add_child(UIKit.badge(p.overall if p != null else int(e.get("o", 0)), 48, 36, 20))
		if p != null:
			var pid := p.id
			card.add_child(UIKit.tap_row(row, func(): UIManager.push("player", {"id": pid})))
		else:
			card.add_child(row)
	return UIKit.card_panel(card)
