class_name MoneyballView
extends RefCounted
## Aba "Moneyball" do mercado: o que falta no elenco (comparado à liga) e a busca por números.

static var profile := "geral"
static var slot := -1 # índice em Moneyball.SLOTS (-1 = qualquer posição)
static var max_age := 40
static var in_budget := true


static func build(w: GameWorld, club: Club, width: float, redo: Callable) -> Control:
	var v := UIKit.vbox(14)
	var needs := Moneyball.needs(w, club)
	# Carências
	var nc := UIKit.card("Card", 8)
	nc.add_child(UIKit.section_header("O que falta no seu time"))
	var shown := 0
	for nd: Dictionary in needs:
		if (nd["reasons"] as Array).is_empty() or shown >= 4:
			continue
		shown += 1
		var h := UIKit.hbox(10)
		var col := UIKit.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UIKit.label(String(nd["label"]), "H3"))
		col.add_child(UIKit.label("; ".join(nd["reasons"]), "Small", true))
		h.add_child(col)
		var idx := _slot_index(String(nd["label"]))
		h.add_child(UIKit.button("Buscar", "GhostButton", func():
			slot = idx
			redo.call(), "search"))
		nc.add_child(h)
	if shown == 0:
		nc.add_child(UIKit.label("Elenco equilibrado.", "Muted", true))
	# Resumo por vaga
	nc.add_child(UIKit.label("Você × média da liga", "Caps"))
	for nd: Dictionary in needs:
		var row := UIKit.hbox(8)
		var nm := UIKit.label(String(nd["label"]), "Small")
		nm.custom_minimum_size.x = 130
		row.add_child(nm)
		var gap := float(nd["gap"])
		var bar := UIKit.bar(float(nd["mine"]), 95.0, UIColors.RED if gap > 2.0 else (UIColors.GREEN if gap < -2.0 else UIColors.BLUE), 8)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		row.add_child(UIKit.label("%d × %d" % [int(nd["mine"]), int(round(float(nd["league"])))], "Small"))
		nc.add_child(row)
	v.add_child(UIKit.card_panel(nc))
	# Filtros da busca
	var fc := UIKit.card("Card", 10)
	fc.add_child(UIKit.section_header("Buscar por números"))
	var profs: Array = []
	for p: Array in Moneyball.PROFILES:
		profs.append([p[0], p[1]])
	fc.add_child(UIKit.scroll_tabs(profs, profile, func(k: String):
		profile = k
		redo.call()))
	for p: Array in Moneyball.PROFILES:
		if p[0] == profile:
			fc.add_child(UIKit.label(String(p[2]), "Small", true))
	var slots: Array = [["-1", "Todas"]]
	for i in Moneyball.SLOTS.size():
		slots.append([str(i), String(Moneyball.SLOTS[i][0])])
	fc.add_child(UIKit.scroll_tabs(slots, str(slot), func(k: String):
		slot = int(k)
		redo.call()))
	fc.add_child(UIKit.segment([["40", "Qualquer idade"], ["29", "Até 29"], ["25", "Até 25"], ["21", "Até 21"]], str(max_age), func(k: String):
		max_age = int(k)
		redo.call()))
	fc.add_child(UIKit.segment([["1", "Cabe no orçamento"], ["0", "Sem limite"]], "1" if in_budget else "0", func(k: String):
		in_budget = k == "1"
		redo.call()))
	v.add_child(UIKit.card_panel(fc))
	# Resultado
	var positions: Array = Moneyball.SLOTS[slot][1] if slot >= 0 else []
	var min_ovr := 0
	if slot >= 0:
		for nd: Dictionary in needs:
			if String(nd["label"]) == String(Moneyball.SLOTS[slot][0]):
				min_ovr = int(nd["mine"]) - 2
	elif profile != "jovem":
		min_ovr = int(FinanceManager.level_of_rep(club.league_cfg(), club.reputation)) - 6
	if profile == "jovem":
		min_ovr = 0
	var fee := club.transfer_budget if in_budget else 0
	var res := Moneyball.search(w, club, profile, positions, max_age, fee, min_ovr)
	var rc := UIKit.card("Card", 4)
	rc.add_child(UIKit.label("%d nomes · ordenados por custo-benefício" % res.size(), "Caps"))
	if res.is_empty():
		rc.add_child(UIKit.label("Ninguém com esse perfil.", "Muted", true))
	for e: Dictionary in res:
		var p: Player = e["p"]
		var cl := w.club(p.club_id) if p.club_id >= 0 else null
		var h := UIKit.hbox(10)
		h.add_child(UIKit.pos_badge(p.position))
		var col := UIKit.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var nm := UIKit.label("%s · %d anos" % [p.display_name(), p.age(w.year)], "H3")
		nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		col.add_child(nm)
		var price := int(e["price"])
		col.add_child(UIKit.label("%s · %s" % [cl.short_name if cl != null else "Livre", String(e["text"])], "Small"))
		col.add_child(UIKit.label("%s · salário %s" % [Fmt.money(price) if price > 0 else "sem taxa", Fmt.money_month(int(e["wage"]))], "Small"))
		h.add_child(col)
		h.add_child(UIKit.player_stars(w,p,15))
		var cb := float(e["cb"])
		h.add_child(UIKit.pill(str(int(round(cb))), UIColors.GREEN if cb >= 70.0 else (UIColors.ACCENT if cb >= 50.0 else UIColors.MUTED), 15))
		var pid := p.id
		rc.add_child(UIKit.tap_row(h, func(): UIManager.push("player", {"id": pid}), "RowPanel"))
	v.add_child(UIKit.card_panel(rc))
	return v


static func _slot_index(label: String) -> int:
	for i in Moneyball.SLOTS.size():
		if String(Moneyball.SLOTS[i][0]) == label:
			return i
	return -1
