extends BaseScreen
## Categorias de base: os garotos por categoria, as competições (ligas sub-20 e sub-17, copas de
## juniores, liga jovem continental e Mundial de seleções), os jogos, a estrutura (técnicos por
## categoria), a captação (com a peneira) e os revelados pela base.

const TABS := [["players", "Garotos"], ["comps", "Competições"], ["games", "Jogos"], ["staff", "Estrutura"], ["scout", "Captação"], ["grads", "Revelados"]]

var _tab := "players"
## Competição aberta na aba de competições ("u20", "u17" ou uma chave de YouthCups).
var _comp := "u20"


func _init() -> void:
	screen_title = "Categorias de base"


func setup(p: Dictionary) -> void:
	super.setup(p)
	_tab = String(p.get("tab", "players"))
	if _tab in ["table", "u20", "u17", "cup20", "cup17", "cont", "intl"]:
		_comp = "u20" if _tab == "table" else _tab
		_tab = "comps"


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
	max_content_width = 1700
	c.add_child(_header(w, club))
	c.add_child(UIKit.scroll_tabs(TABS, _tab, func(k: String):
		_tab = k
		refresh()))
	var start := c.get_child_count()
	match _tab:
		"players":
			for cat in YouthManager.CATEGORIES:
				var box := _players(w, club, cat)
				if box != null:
					c.add_child(box)
		"comps":
			YouthCups.ensure(w)
			c.add_child(_comp_picker(w))
			start = c.get_child_count()
			if _comp in ["u20", "u17"]:
				c.add_child(_table(w, _comp))
				c.add_child(_scorers(w, _comp))
			else:
				for card in _cup_cards(w, YouthCups.comp(w, _comp)):
					c.add_child(card)
			c.add_child(_honours(w))
		"games":
			c.add_child(_games(w))
			c.add_child(_cup_games(w))
		"staff":
			c.add_child(_facilities(w, club))
			c.add_child(_coaches(w))
		"scout":
			c.add_child(_scouting(w))
			c.add_child(_trial(w))
		"grads":
			c.add_child(_grads(w))
	columnize(c, start)


func _header(w: GameWorld, club: Club) -> Control:
	var v := UIKit.vbox(6)
	v.add_child(UIKit.stat_grid([
		UIKit.stat_tile(str(club.youth_level), "Base · %s" % YouthAcademy.tier_name(club), UIColors.ACCENT),
		UIKit.stat_tile("%d/%d" % [w.academy.size(), YouthManager.MAX_SIZE], "Garotos"),
		UIKit.stat_tile(_pos_text(w, "u20"), "No sub-20"),
		UIKit.stat_tile(_pos_text(w, "u17"), "No sub-17"),
	], content_width()))
	return v


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
	card.add_child(UIKit.section_header("%s · %s · %d" % [cat[1], cat[2], list.size()]))
	if list.is_empty():
		card.add_child(UIKit.label("Nenhum garoto nesta categoria.", "Muted", true))
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
	var v := UIKit.vbox(12)
	_fill_kid(v, p)
	UIManager.show_modal(v, true)


## Ficha do garoto: estimativa, números por competição, histórico na base, plano individual e decisões.
func _fill_kid(v: VBoxContainer, p: Player) -> void:
	var w := world()
	UIKit.clear(v)
	var head := UIKit.hbox(12)
	head.add_child(UIKit.portrait(p, w.user_club(), w.year, 84))
	var col := UIKit.vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UIKit.label(p.full_name(), "Title", true))
	col.add_child(UIKit.label("%s · %d anos · %s · %s" % [Pos.name_of(p.position), p.age(w.year), YouthManager.category_name(YouthManager.category(p, w.year)), p.playstyle()], "Small", true))
	col.add_child(UIKit.label("Estimativa da base: %s" % YouthManager.potential_text(w, p), "Small", true))
	col.add_child(_stars(w, p, 20))
	head.add_child(col)
	var bd := UIKit.badge(p.overall)
	bd.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	head.add_child(bd)
	var xb := UIKit.icon_button("close", func(): UIManager.close_modal())
	xb.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	head.add_child(xb)
	v.add_child(head)
	var yrs := YouthManager.years_in(w, p)
	var line := "%s na base" % ["Chegou nesta temporada" if yrs == 0 else ("%d ano(s)" % yrs)]
	var pf := YouthManager.play_factor(w, p)
	if pf < 0.95:
		line += " · joga pouco"
	elif pf > 1.08:
		line += " · titular da categoria"
	v.add_child(UIKit.colored(line, UIColors.ORANGE if pf < 0.95 else UIColors.MUTED, "Small", true))
	# Números da temporada, por competição
	v.add_child(UIKit.section("Temporada"))
	if p.stats[Player.S_APPS] > 0:
		v.add_child(UIKit.label("%d jogos · %d gols · %d assistências · nota %.1f · %d min" % [p.stats[Player.S_APPS], p.stats[Player.S_GOALS], p.stats[Player.S_ASSISTS], p.avg_rating(), p.stats[Player.S_MINUTES]], "Small", true))
		var by := YouthAcademy.season_by_comp(w, p.id)
		for k in by:
			var e: Array = by[k]
			v.add_child(UIKit.kv(YouthAcademy.comp_label(w, String(k)), "%d J · %d G · %d A" % [int(e[0]), int(e[1]), int(e[2])]))
	else:
		v.add_child(UIKit.label("Ainda não jogou nesta temporada.", "Muted", true))
	var hist := YouthAcademy.history(w, p.id)
	if not hist.is_empty():
		v.add_child(UIKit.section("Na base, ano a ano"))
		for i in range(hist.size() - 1, -1, -1):
			var r: Dictionary = hist[i]
			var avg := float(r["r"]) / 10.0 / maxf(1.0, float(r["a"]))
			v.add_child(UIKit.kv("%d · %s" % [int(r["y"]), YouthManager.category_name(String(r["cat"]))], "%d J · %d G · %d A · %.1f · ovr %d" % [int(r["a"]), int(r["g"]), int(r["as"]), avg, int(r.get("o", 0))]))
	# Plano individual
	var plan := YouthAcademy.plan_of(w, p)
	v.add_child(UIKit.section("Plano individual"))
	var fl := GridContainer.new()
	fl.columns = 3
	fl.add_theme_constant_override(&"h_separation", 8)
	fl.add_theme_constant_override(&"v_separation", 8)
	var g := ButtonGroup.new()
	for fk in YouthAcademy.PLAN_ORDER:
		if fk == "goleiro" and p.position != Pos.GK:
			continue
		var key: String = fk
		var chip := UIKit.chip(String(YouthAcademy.PLANS[fk]["name"]), String(plan["f"]) == fk, g, func():
			YouthAcademy.set_plan(w, p, key, int(YouthAcademy.plan_of(w, p)["i"]))
			GameManager.save_now()
			_fill_kid(v, p))
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fl.add_child(chip)
	v.add_child(fl)
	var coach := YouthAcademy.coach_of(w, YouthManager.category(p, w.year))
	var focus_desc := String(YouthAcademy.PLANS[plan["f"]]["desc"])
	if String(plan["f"]) == "auto":
		focus_desc = "Segue o técnico %s (%s): %s." % [coach["n"], String(YouthAcademy.SPECIALTIES[coach["sp"]]["name"]).to_lower(), String(YouthAcademy.SPECIALTIES[coach["sp"]]["desc"]).to_lower()]
	v.add_child(UIKit.label(focus_desc, "Small", true))
	var items: Array = []
	for i in YouthAcademy.INTENSITY.size():
		items.append([str(i), String(YouthAcademy.INTENSITY[i]["name"])])
	v.add_child(UIKit.segment(items, str(int(plan["i"])), func(k: String):
		YouthAcademy.set_plan(w, p, String(YouthAcademy.plan_of(w, p)["f"]), int(k))
		GameManager.save_now()
		_fill_kid(v, p)))
	v.add_child(UIKit.label(["Carga leve: evolui um pouco menos e fica mais feliz.", "Carga normal.", "Carga intensa: evolui mais rápido, mas cansa a cabeça e pode lesionar."][int(plan["i"])], "Small", true))
	# Decisões
	var weakest := 99
	for q: Player in w.squad(w.user_club()):
		weakest = mini(weakest, q.overall)
	v.add_child(UIKit.section("Decisão"))
	v.add_child(UIKit.label("Mais fraco do elenco profissional: %d" % weakest, "Small", true))
	v.add_child(UIKit.button("SUBIR AO PROFISSIONAL", "PrimaryButton", func():
		UIManager.close_modal()
		UIManager.toast(YouthManager.promote(w, p))
		GameManager.save_now()
		refresh(), "up"))
	var loan_why := YouthAcademy.loan_block(w, p)
	var do_loan := func():
		var r := YouthAcademy.loan_kid(w, p)
		UIManager.toast(String(r["msg"]), UIColors.GREEN if r["ok"] else UIColors.RED)
		GameManager.save_now()
		refresh()
	var lb := UIKit.button("Emprestar para ganhar minutos", "", func():
		UIManager.close_modal()
		UIManager.confirm("Emprestar %s?" % p.display_name(), "Ele assina o primeiro contrato profissional e vai para um clube onde deve jogar, até o fim da temporada.", "Emprestar", do_loan), "swap")
	lb.disabled = loan_why != ""
	v.add_child(lb)
	if loan_why != "":
		v.add_child(UIKit.label(loan_why, "Small", true))
	var row := UIKit.hbox(8)
	var prof := UIKit.button("Perfil completo", "", func():
		UIManager.close_modal()
		UIManager.push("player", {"id": p.id}), "info")
	prof.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(prof)
	var rel := UIKit.button("Dispensar", "DangerButton", func():
		UIManager.close_modal()
		UIManager.confirm("Dispensar %s?" % p.display_name(), "Ele deixa a base do clube.", "Dispensar", func():
			YouthManager.release(w, p)
			refresh()))
	rel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(rel)
	v.add_child(row)


# ---------------------------------------------------------------------------
# Ligas e jogos
# ---------------------------------------------------------------------------

func _table(w: GameWorld, key: String) -> Control:
	var card := UIKit.card("Card", 4)
	if not YouthManager.has_league(w, key):
		card.add_child(UIKit.label("Sem liga %s nesta temporada." % ("sub-20" if key == "u20" else "sub-17"), "Muted", true))
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
	card.add_child(UIKit.section_header("Onde procurar garotos"))
	var items: Array = []
	for rk in YouthManager.REGION_ORDER:
		var cfg: Dictionary = YouthManager.REGIONS[rk]
		var cost := YouthManager.scouting_cost(w, rk)
		items.append([rk, String(cfg["name"]), "%s · %s" % [tr("grátis") if cost == 0 else tr("%s/ano") % Fmt.money(cost), tr(String(cfg["desc"]))], "search"])
	card.add_child(UIKit.option_grid(items, String(s["region"]), func(rk: String):
		YouthManager.set_region(w, rk)
		GameManager.save_now()
		refresh(), 2 if UILayout.is_wide() else 1))
	card.add_child(UIKit.section_header("Setor prioritário"))
	var fitems: Array = []
	for fk in YouthManager.FOCUS_ORDER:
		fitems.append([fk, String(YouthManager.FOCUS[fk]["name"])])
	card.add_child(UIKit.segment(fitems, String(s["focus"]), func(fk: String):
		YouthManager.set_focus(w, fk)
		GameManager.save_now()
		refresh()))
	card.add_child(UIKit.label("Chegam cerca de %d garotos por temporada." % YouthManager.intake_count(w, club), "Small", true))
	return UIKit.card_panel(card)


func _trial(w: GameWorld) -> Control:
	var card := UIKit.card("Card", 8)
	card.add_child(UIKit.section("Peneira"))
	var cands := YouthManager.candidates(w)
	if YouthManager.can_trial(w):
		card.add_child(UIKit.button("FAZER PENEIRA · %s" % Fmt.money(YouthManager.trial_cost(w)), "PrimaryButton", func():
			var got := YouthManager.run_trial(w)
			UIManager.toast("%d garotos se destacaram na peneira." % got.size())
			GameManager.save_now()
			refresh(), "search"))
	elif cands.is_empty():
		card.add_child(UIKit.label("Próxima na temporada que vem.", "Muted", true))
	if cands.is_empty():
		return UIKit.card_panel(card)
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


# ---------------------------------------------------------------------------
# Competições: ligas, copas de juniores, liga continental e Mundial
# ---------------------------------------------------------------------------

func _comp_picker(w: GameWorld) -> Control:
	var items: Array = [["u20", "Liga Sub-20"], ["u17", "Liga Sub-17"]]
	for k in YouthCups.keys(w):
		items.append([k, String(YouthCups.comp(w, k)["short"])])
	return UIKit.scroll_tabs(items, _comp, func(k: String):
		_comp = k
		refresh())


func _cup_cards(w: GameWorld, d: Dictionary) -> Array:
	var out: Array = []
	if d.is_empty():
		var card := UIKit.card("Card", 6)
		card.add_child(UIKit.label("Essa competição não acontece nesta temporada.", "Muted", true))
		out.append(UIKit.card_panel(card))
		return out
	out.append(_cup_status(w, d))
	if d["kind"] == "intl":
		if not bool(d.get("done", false)):
			out.append(_intl_prospects(w, d))
		if bool(d.get("done", false)):
			out.append(_intl_called(w, d))
			for r in range(d["rounds"].size() - 1, 0, -1):
				out.append(_round_card(w, d, d["rounds"][r], true))
			out.append(_group_tables(w, d, true))
		out.append(_cup_scorers(w, d, true))
		return out
	var rounds: Array = d["rounds"]
	for r in range(rounds.size() - 1, -1, -1):
		if not rounds[r]["games"].is_empty() and bool(rounds[r].get("ko", false)):
			out.append(_round_card(w, d, rounds[r], false))
	if d["kind"] == "groups":
		out.append(_group_tables(w, d, false))
		out.append(_group_games(w, d))
	out.append(_cup_scorers(w, d, false))
	return out


## Cabeçalho da competição: formato, campanha do clube e o próximo jogo (ou o campeão).
func _cup_status(w: GameWorld, d: Dictionary) -> Control:
	var card := UIKit.card("CardHighlight", 6)
	card.add_child(UIKit.eyebrow(String(d["name"]).to_upper()))
	var fmt := ""
	match String(d["kind"]):
		"ko":
			fmt = "%d clubes do país em mata-mata de jogo único (empate vai para os pênaltis). A final é em campo neutro." % d["teams"].size()
		"groups":
			fmt = "Os 16 grandes do continente: 4 grupos de 4 em turno e returno; os 2 primeiros vão às quartas, em jogo único."
		"intl":
			fmt = "16 seleções com os melhores garotos de cada país (%s): grupos, quartas, semifinal e final, disputados de uma vez." % ("até 19 anos" if d["age"] == "u20" else "até 16 anos")
	card.add_child(UIKit.label(fmt, "Small", true))
	if bool(d.get("done", false)) and d["champion"] is String:
		card.add_child(_nation_line(String(d["champion"]), "Campeão", UIColors.ACCENT))
	elif bool(d.get("done", false)) and int(d["champion"]) >= 0:
		var ch := w.club(int(d["champion"]))
		var row := UIKit.hbox(10)
		row.add_child(UIKit.icon_rect("trophy", 28, UIColors.ACCENT))
		row.add_child(UIKit.crest(ch, 34))
		row.add_child(UIKit.label("%s campeão" % ch.short_name, "H3"))
		card.add_child(row)
	if d["kind"] != "intl":
		var res := YouthCups.result_text(w, d)
		card.add_child(UIKit.kv("Seu clube", res, UIColors.GREEN if res.begins_with("Campeão") else (UIColors.RED if res.begins_with("Eliminado") else UIColors.TEXT)))
	var nx := YouthCups.next_slot(w, d)
	if nx >= 0 and not bool(d.get("done", false)):
		card.add_child(UIKit.kv("Próxima data", w.season.date_label(nx, false)))
	return UIKit.card_panel(card)


func _nation_line(code: String, caption: String, color: Color) -> Control:
	var row := UIKit.hbox(10)
	row.add_child(UIKit.icon_rect("trophy", 28, color))
	row.add_child(UIKit.flag(code, 40))
	row.add_child(UIKit.label("%s · %s" % [DatabaseManager.nation_name(code), caption], "H3"))
	return row


## Placar de um jogo: mandante, placar e visitante (clubes ou seleções).
func _score_row(w: GameWorld, g: Dictionary, nations: bool) -> Control:
	var row := UIKit.hbox(8)
	var played := int(g["hg"]) >= 0
	for side in 2:
		var id: Variant = g["h"] if side == 0 else g["a"]
		var nm := ""
		var mark: Control
		if nations:
			nm = DatabaseManager.nation_name(String(id))
			mark = UIKit.flag(String(id), 34)
		else:
			var cl := w.club(int(id))
			nm = cl.short_name
			mark = UIKit.crest(cl, 28)
		var l := UIKit.label(nm, "")
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.clip_text = true
		var won: bool = played and str(g.get("w", "")) == str(id)
		var mine := not nations and w.is_user_club(int(id))
		if mine:
			l.add_theme_color_override(&"font_color", UIColors.ACCENT)
		elif not won and played:
			l.add_theme_color_override(&"font_color", UIColors.MUTED)
		if side == 0:
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			row.add_child(l)
			row.add_child(mark)
			var sc := UIKit.label(("%d x %d" % [int(g["hg"]), int(g["ag"])]) if played else "x", "Stat")
			sc.custom_minimum_size.x = 86
			sc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			row.add_child(sc)
		else:
			row.add_child(mark)
			row.add_child(l)
	if not bool(g.get("pen", false)):
		return row
	var v := UIKit.vbox(0)
	v.add_child(row)
	var wn: String = DatabaseManager.nation_name(String(g["w"])) if nations else w.club(int(g["w"])).short_name
	var pl := UIKit.label("%s nos pênaltis" % wn, "Small")
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(pl)
	return v


func _round_card(w: GameWorld, d: Dictionary, round: Dictionary, nations: bool) -> Control:
	var card := UIKit.card("Card", 6)
	var title := String(round["name"])
	if not nations and int(round["games"][0]["hg"]) < 0:
		title += " · " + w.season.date_label(int(round["slot"]), false)
	card.add_child(UIKit.section(title))
	var games: Array = round["games"].duplicate()
	if not nations:
		# O jogo do seu clube primeiro
		var mine: Array = games.filter(func(g: Dictionary): return w.is_user_club(int(g["h"])) or w.is_user_club(int(g["a"])))
		var rest: Array = games.filter(func(g: Dictionary): return not (w.is_user_club(int(g["h"])) or w.is_user_club(int(g["a"]))))
		games = mine + rest
	for g: Dictionary in games:
		card.add_child(_score_row(w, g, nations))
		var info: Dictionary = g.get("info", {})
		if not Array(info.get("g", [])).is_empty():
			var gl := UIKit.label("Gols: " + ", ".join(PackedStringArray(info["g"])) + ((" · melhor em campo: " + String(info["best"])) if String(info.get("best", "")) != "" else ""), "Small", true)
			gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			card.add_child(gl)
	return UIKit.card_panel(card)


## Tabelas dos grupos (liga continental: clubes; Mundial: seleções).
func _group_tables(w: GameWorld, d: Dictionary, nations: bool) -> Control:
	var card := UIKit.card("Card", 4)
	card.add_child(UIKit.section("Fase de grupos"))
	var letters := "ABCD"
	for gi in d["groups"].size():
		var ids: Array = d["groups"][gi]
		var order := CompetitionManager.sort_table(ids, d["gtable"])
		card.add_child(UIKit.label("Grupo %s" % letters[gi], "Caps"))
		if not nations:
			card.add_child(TableRows.header(true))
		for i in order.size():
			var id: Variant = order[i]
			var zone := CompetitionManager.zone_color(CompetitionManager.ZONE_CONTINENTAL) if i < 2 else Color(0, 0, 0, 0)
			if nations:
				card.add_child(_nation_table_row(String(id), d["gtable"][id], i + 1, zone))
			else:
				card.add_child(TableRows.table_row(w, d["gtable"][id], int(id), i + 1, true, zone))
	return UIKit.card_panel(card)


func _nation_table_row(code: String, r: Dictionary, pos: int, zone: Color) -> Control:
	var row := UIKit.hbox(8)
	var bar := ColorRect.new()
	bar.color = zone
	bar.custom_minimum_size = Vector2(5, 30)
	row.add_child(bar)
	var pl := UIKit.label(str(pos), "H3")
	pl.custom_minimum_size.x = 30
	row.add_child(pl)
	row.add_child(UIKit.flag(code, 34))
	var nl := UIKit.label(DatabaseManager.nation_name(code), "")
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nl.clip_text = true
	row.add_child(nl)
	row.add_child(UIKit.label("%d J" % int(r["pl"]), "Small"))
	row.add_child(UIKit.label("%+d" % (int(r["gf"]) - int(r["ga"])), "Small"))
	var pts := UIKit.label("%d" % int(r["pts"]), "Stat")
	pts.custom_minimum_size.x = 44
	pts.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(pts)
	return row


## Jogos do seu clube na fase de grupos.
func _group_games(w: GameWorld, d: Dictionary) -> Control:
	var card := UIKit.card("Card", 6)
	card.add_child(UIKit.section("Seus jogos nos grupos"))
	var any := false
	for r in d["rounds"]:
		if bool(r.get("ko", false)):
			continue
		for g: Dictionary in r["games"]:
			if w.is_user_club(int(g["h"])) or w.is_user_club(int(g["a"])):
				any = true
				var v := UIKit.vbox(0)
				v.add_child(UIKit.label("%s · %s" % [String(r["name"]).trim_prefix("Grupos · "), w.season.date_label(int(r["slot"]), false)], "Small"))
				v.add_child(_score_row(w, g, false))
				card.add_child(v)
	if not any:
		card.add_child(UIKit.label("Seu clube não disputa esta edição: acompanhe os grandes do continente.", "Muted", true))
	return UIKit.card_panel(card)


func _cup_scorers(w: GameWorld, d: Dictionary, nations: bool) -> Control:
	var card := UIKit.card("Card", 6)
	card.add_child(UIKit.section("Artilharia"))
	var list := YouthCups.top_scorers(d, 10)
	if list.is_empty():
		card.add_child(UIKit.label("Ninguém marcou ainda.", "Muted"))
	for i in list.size():
		var e: Dictionary = list[i]
		var row := UIKit.hbox(10)
		var rk := UIKit.label(str(i + 1), "H3")
		rk.custom_minimum_size.x = 36
		row.add_child(rk)
		var cl := w.club(int(e.get("c", -1))) if int(e.get("c", -1)) >= 0 else null
		if nations:
			row.add_child(UIKit.flag(String(e.get("nat", "")), 36))
		elif cl != null:
			row.add_child(UIKit.crest(cl, 32))
		var col := UIKit.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var nl := UIKit.label(String(e["n"]), "H3")
		nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		if cl != null and w.is_user_club(cl.id):
			nl.add_theme_color_override(&"font_color", UIColors.ACCENT)
		col.add_child(nl)
		col.add_child(UIKit.label(cl.short_name if cl != null else "sem clube", "Small"))
		row.add_child(col)
		row.add_child(UIKit.label("%d gols" % int(e["g"]), "Stat"))
		var pid := int(e.get("pid", -1))
		if pid >= 0 and (w.players.has(pid) or w.academy.has(pid)):
			card.add_child(UIKit.tap_row(row, func(): UIManager.push("player", {"id": pid})))
		else:
			card.add_child(row)
	return UIKit.card_panel(card)


## Garotos do clube convocados para o Mundial.
func _intl_called(w: GameWorld, d: Dictionary) -> Control:
	var card := UIKit.card("Card", 6)
	var mine := YouthCups.user_called(w, d)
	card.add_child(UIKit.section("Convocados do %s · %d" % [w.user_club().short_name, mine.size()]))
	if mine.is_empty():
		card.add_child(UIKit.label("Nenhum garoto do clube foi chamado desta vez.", "Muted", true))
	for e in mine:
		var row := UIKit.hbox(10)
		row.add_child(UIKit.flag(String(e["nat"]), 36))
		var nl := UIKit.label(String(e["n"]), "H3")
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(nl)
		row.add_child(UIKit.label("%d J · %d G" % [int(e["a"]), int(e["g"])], "Stat"))
		card.add_child(row)
	return UIKit.card_panel(card)


## Galeria da base: títulos e vices do clube nas competições de base.
func _honours(w: GameWorld) -> Control:
	var card := UIKit.card("Card", 6)
	card.add_child(UIKit.section("Galeria da base"))
	var hon: Array = w.youth.get("hon", []).filter(func(h: Dictionary): return int(h.get("c", -1)) == w.user_club_id)
	for i in range(hon.size() - 1, -1, -1):
		var h: Dictionary = hon[i]
		var row := UIKit.hbox(10)
		row.add_child(UIKit.icon_rect("trophy", 26, UIColors.ACCENT if String(h["r"]) == "Campeão" else UIColors.MUTED))
		var l := UIKit.label("%d · %s" % [int(h["y"]), String(h["n"])], "")
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(l)
		row.add_child(UIKit.label(String(h["r"]), "Small"))
		card.add_child(row)
	if hon.is_empty():
		card.add_child(UIKit.label("As campanhas de destaque nas copas de base ficam registradas aqui.", "Muted", true))
	return UIKit.card_panel(card)


## Jogos do clube nas copas de base, na ordem das datas.
func _cup_games(w: GameWorld) -> Control:
	var card := UIKit.card("Card", 6)
	card.add_child(UIKit.section("Jogos nas copas de base"))
	var rows: Array = []
	for k in YouthCups.keys(w):
		var d := YouthCups.comp(w, k)
		if d["kind"] == "intl":
			continue
		for r in d["rounds"]:
			for g: Dictionary in r["games"]:
				if w.is_user_club(int(g["h"])) or w.is_user_club(int(g["a"])):
					rows.append([int(r["slot"]), String(d["short"]) + " · " + String(r["name"]).trim_prefix("Grupos · "), g])
	rows.sort_custom(func(a, b): return int(a[0]) < int(b[0]))
	if rows.is_empty():
		card.add_child(UIKit.label("Sem jogos de copa marcados agora.", "Muted", true))
	for e in rows:
		var v := UIKit.vbox(0)
		v.add_child(UIKit.label("%s · %s" % [w.season.date_label(int(e[0]), false), e[1]], "Small"))
		v.add_child(_score_row(w, e[2], false))
		card.add_child(v)
	return UIKit.card_panel(card)


# ---------------------------------------------------------------------------
# Estrutura: instalações e técnicos por categoria
# ---------------------------------------------------------------------------

func _facilities(w: GameWorld, club: Club) -> Control:
	var card := UIKit.card("Card", 8)
	card.add_child(UIKit.section_header("Instalações da base"))
	var head := UIKit.hbox(8)
	head.add_child(UIKit.label(YouthAcademy.tier_name(club), "H2"))
	head.add_child(UIKit.spacer())
	head.add_child(UIKit.label("%d/100" % club.youth_level, "H3"))
	card.add_child(head)
	card.add_child(UIKit.bar(club.youth_level, 100.0, UIColors.BLUE, 10))
	card.add_child(UIKit.label(YouthAcademy.tier_desc(club), "Small", true))
	card.add_child(UIKit.kv("Garotos por temporada", "cerca de %d" % YouthManager.intake_count(w, club)))
	card.add_child(UIKit.kv("Ritmo de evolução", "%d%%" % int(round(YouthAcademy.facility_growth(club) * 100.0))))
	var nxt := YouthAcademy.tier_index(club) + 1
	if nxt < YouthAcademy.TIERS.size():
		card.add_child(UIKit.kv("Próxima faixa", "%s aos %d" % [YouthAcademy.TIERS[nxt][1], int(YouthAcademy.TIERS[nxt][0])]))
	var wait := BoardRequests.wait_turns(w, "youth")
	var lbl := "Pedir investimento (%s)" % Fmt.money(BoardRequests.cost_of(w, "youth"))
	if wait > 0:
		lbl = "Novo pedido em %d rodada(s)" % wait
	var b := UIKit.button(lbl, "GhostButton", func():
		UIManager.confirm("Levar o pedido ao presidente?", "O diretor de futebol leva o pedido de investimento na base. Custo: %s." % Fmt.money(BoardRequests.cost_of(w, "youth")), "Pedir", func():
			var r := BoardRequests.request(w, "youth")
			UIManager.toast(String(r["msg"]), UIColors.GREEN if r["ok"] else UIColors.RED)
			GameManager.save_now()
			refresh()), "up")
	b.disabled = wait > 0 or club.youth_level >= 99
	card.add_child(b)
	if wait == 0:
		var od := BoardRequests.odds(w, "youth")
		var chance := float(od[0])
		card.add_child(UIKit.label("Chance %s%s" % ["boa" if chance >= 0.6 else ("difícil" if chance < 0.3 else "incerta"), (" — " + String(od[1])) if String(od[1]) != "" else ""], "Small", true))
	return UIKit.card_panel(card)


func _coaches(w: GameWorld) -> Control:
	var card := UIKit.card("Card", 8)
	card.add_child(UIKit.section_header("Técnicos das categorias"))
	for cat in YouthManager.CATEGORIES:
		var ck := String(cat[0])
		var c := YouthAcademy.coach_of(w, ck)
		var row := UIKit.hbox(10)
		var col := UIKit.vbox(2)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UIKit.label("%s · %s" % [cat[1], c["n"]], "H3", true))
		var sp: Dictionary = YouthAcademy.SPECIALTIES.get(String(c["sp"]), YouthAcademy.SPECIALTIES["formador"])
		col.add_child(UIKit.label("%s: %s · %s/ano" % [sp["name"], String(sp["desc"]).to_lower(), Fmt.money(YouthAcademy.coach_wage(w, int(c["l"])))], "Small", true))
		var st := StarsView.new()
		st.star_size = 18
		st.stars = float(c["l"])
		col.add_child(st)
		row.add_child(col)
		var tb := UIKit.button("Trocar", "", func(): _coach_picker(ck), "swap")
		tb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(tb)
		card.add_child(row)
	card.add_child(UIKit.separator())
	card.add_child(UIKit.kv("Folha dos técnicos da base", "%s/ano" % Fmt.money(YouthAcademy.coaches_cost(w))))
	card.add_child(UIKit.label("Cada estrela a mais acelera a evolução dos garotos da categoria (cerca de 7%) e melhora a leitura do potencial. Sem plano individual, o garoto segue a linha do técnico.", "Small", true))
	return UIKit.card_panel(card)


func _coach_picker(cat: String) -> void:
	var w := world()
	var v := UIKit.vbox(10)
	var head := UIKit.hbox(8)
	var t := UIKit.label("Novo técnico do %s" % YouthManager.category_name(cat), "Title", true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(UIKit.icon_button("close", func(): UIManager.close_modal()))
	v.add_child(head)
	v.add_child(UIKit.label("Multa para dispensar o atual: %s. O novo recebe metade do salário anual na assinatura." % Fmt.money(YouthAcademy.coach_severance(w, cat)), "Small", true))
	for cand: Dictionary in YouthAcademy.coach_candidates(w, cat):
		var sp: Dictionary = YouthAcademy.SPECIALTIES[cand["sp"]]
		var col := UIKit.vbox(2)
		col.add_child(UIKit.label("%s, %d anos" % [cand["n"], int(cand["a"])], "H3", true))
		var st := StarsView.new()
		st.star_size = 18
		st.stars = float(cand["l"])
		col.add_child(st)
		col.add_child(UIKit.label("%s: %s · %s/ano" % [sp["name"], String(sp["desc"]).to_lower(), Fmt.money(YouthAcademy.coach_wage(w, int(cand["l"])))], "Small", true))
		var cc: Dictionary = cand
		v.add_child(UIKit.tap_row(col, func():
			UIManager.close_modal()
			UIManager.toast(YouthAcademy.hire_coach(w, cat, cc))
			GameManager.save_now()
			refresh()))
	UIManager.show_modal(v, true)


## Antes do Mundial: garotos do clube com nível de seleção (os prováveis convocados).
func _intl_prospects(w: GameWorld, d: Dictionary) -> Control:
	var card := UIKit.card("Card", 6)
	card.add_child(UIKit.section("Prováveis convocados do clube"))
	var max_age := int(d.get("max_age", 19))
	var list: Array = []
	for p: Player in YouthManager.academy(w) + w.squad(w.user_club()):
		if p.age(w.year) > max_age:
			continue
		if p.ovr_f >= YouthCups._nation_level(p.nationality, String(d["age"])) - 3.0:
			list.append(p)
	if list.is_empty():
		card.add_child(UIKit.label("Nenhum garoto do clube tem nível de seleção por enquanto. Quem jogar bem até lá pode entrar na lista.", "Muted", true))
	for p: Player in list.slice(0, 8):
		var row := UIKit.hbox(10)
		row.add_child(UIKit.flag(p.nationality, 36))
		var nl := UIKit.label(p.display_name(), "H3")
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(nl)
		row.add_child(UIKit.label("%d anos" % p.age(w.year), "Small"))
		row.add_child(UIKit.badge(p.overall, 48, 36, 20))
		card.add_child(row)
	return UIKit.card_panel(card)
