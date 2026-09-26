extends BaseScreen
## Contratos do elenco: a folha (total, teto e quanto do teto já está comprometido), a projeção
## da folha nos próximos anos, e cada jogador com salário, fim de contrato (vermelho vence nesta
## temporada, amarelo na próxima), multa, papel no elenco e o atalho para renovar. Filtros por
## vencimento, emprestados e multa; ordem por vencimento, salário ou nível.

const FILTERS: Array[String] = ["Todos", "Vencem já", "Próx. ano", "Com multa", "Cedidos"]
const SORTS: Array[String] = ["Vencimento", "Salário", "Nível"]

var _filter := 0
var _sort := 0


func _init() -> void:
	show_nav = false
	screen_title = "Contratos"


func refresh() -> void:
	var w := world()
	if w == null:
		return
	var club := w.user_club()
	screen_subtitle = club.short_name
	UIManager.refresh_chrome()
	var c := content()
	UIKit.clear(c)
	var squad := w.squad(club)
	var lent: Array = []
	for p: Player in w.players.values():
		if not p.loan.is_empty() and int(p.loan.get("from", -1)) == club.id and p.club_id != club.id:
			lent.append(p)
	c.add_child(_summary(w, club, squad))
	c.add_child(_projection(w, squad))
	# Filtros e ordem
	var gf := ButtonGroup.new()
	var fr := UIKit.flow(8)
	for i in FILTERS.size():
		var idx := i
		var chip := UIKit.chip(FILTERS[i], i == _filter, gf, func():
			_filter = idx
			refresh())
		UIKit.shrink_button(chip)
		fr.add_child(chip)
	c.add_child(fr)
	var gs := ButtonGroup.new()
	var sr := UIKit.hbox(8)
	sr.add_child(UIKit.label("Ordem", "Small"))
	for i in SORTS.size():
		var idx := i
		var chip := UIKit.chip(SORTS[i], i == _sort, gs, func():
			_sort = idx
			refresh())
		UIKit.shrink_button(chip)
		sr.add_child(chip)
	c.add_child(sr)
	var list: Array = lent if _filter == 4 else squad.filter(func(p: Player): return _passes(w, p))
	match _sort:
		0:
			list.sort_custom(func(a: Player, b: Player): return a.contract_end < b.contract_end or (a.contract_end == b.contract_end and a.wage > b.wage))
		1:
			list.sort_custom(func(a: Player, b: Player): return a.wage > b.wage)
		2:
			list.sort_custom(func(a: Player, b: Player): return a.overall > b.overall)
	var card := UIKit.card("Card", 6)
	card.add_child(UIKit.section("%d jogadores" % list.size()))
	if list.is_empty():
		card.add_child(UIKit.label("Ninguém neste filtro.", "Small"))
	for p: Player in list:
		card.add_child(_row(w, club, p))
	c.add_child(UIKit.card_panel(card))


func _passes(w: GameWorld, p: Player) -> bool:
	match _filter:
		1:
			return p.contract_end <= w.year
		2:
			return p.contract_end == w.year + 1
		3:
			return p.release_clause > 0
	return true


func _summary(w: GameWorld, club: Club, squad: Array) -> Control:
	var card := UIKit.card("Card", 8)
	var total := 0
	var expiring := 0
	var next_year := 0
	var top: Player = null
	for p: Player in squad:
		total += p.wage
		if p.contract_end <= w.year:
			expiring += 1
		elif p.contract_end == w.year + 1:
			next_year += 1
		if top == null or p.wage > top.wage:
			top = p
	card.add_child(UIKit.section("Folha salarial"))
	var row := UIKit.hbox(4)
	row.add_child(UIKit.stat(Fmt.money_month(total), "folha"))
	row.add_child(UIKit.stat(Fmt.money_month(club.wage_budget), "teto da diretoria"))
	var pct := float(total) / maxf(1.0, club.wage_budget)
	var col := UIColors.GREEN if pct <= 0.9 else (Color("#E8C547") if pct <= 1.0 else UIColors.RED)
	row.add_child(UIKit.stat("%d%%" % int(round(pct * 100.0)), "do teto", col))
	card.add_child(row)
	card.add_child(UIKit.bar(minf(pct, 1.2), 1.2, col, 10))
	var row2 := UIKit.hbox(4)
	row2.add_child(UIKit.stat(str(expiring), "vencem nesta temporada", UIColors.RED if expiring > 0 else UIColors.TEXT))
	row2.add_child(UIKit.stat(str(next_year), "vencem na próxima", Color("#E8C547") if next_year > 0 else UIColors.TEXT))
	row2.add_child(UIKit.stat(Fmt.money_month(total / maxi(1, squad.size())), "média"))
	card.add_child(row2)
	if top != null:
		card.add_child(UIKit.kv("Maior salário", "%s · %s" % [top.short_name(), Fmt.money_month(top.wage)]))
	return UIKit.card_panel(card)


## Quanto da folha de hoje continua comprometido em cada um dos próximos anos.
func _projection(w: GameWorld, squad: Array) -> Control:
	var card := UIKit.card("Card", 6)
	card.add_child(UIKit.section("Folha já comprometida"))
	var totals: Array = []
	var peak := 1
	for k in 5:
		var y := w.year + k
		var s := 0
		for p: Player in squad:
			if p.contract_end >= y:
				s += p.wage
		totals.append(s)
		peak = maxi(peak, s)
	for k in 5:
		var r := UIKit.hbox(8)
		var yl := UIKit.label(str(w.year + k), "Small")
		yl.custom_minimum_size.x = 64
		r.add_child(yl)
		var b := UIKit.bar(float(totals[k]), float(peak), UIColors.BLUE if k > 0 else Color("#E8C547"), 12)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.add_child(b)
		var v := UIKit.label(Fmt.money(totals[k]), "Small")
		v.custom_minimum_size.x = 110
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		r.add_child(v)
		card.add_child(r)
	return UIKit.card_panel(card)


func _row(w: GameWorld, club: Club, p: Player) -> Control:
	var h := UIKit.hbox(10)
	h.add_child(UIKit.pos_badge(p.position))
	var v := UIKit.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var n := UIKit.label(p.display_name(), "H3")
	n.clip_text = true
	v.add_child(n)
	var bits: Array = ["%d anos" % p.age(w.year), Player.STATUS_NAMES[clampi(p.squad_status, 0, Player.STATUS_NAMES.size() - 1)]]
	if p.release_clause > 0:
		bits.append("multa " + Fmt.money(p.release_clause))
	if not p.loan.is_empty():
		var other := w.club(int(p.loan.get("from", -1)) if int(p.loan.get("from", -1)) != club.id else p.club_id)
		bits.append(("emprestado ao %s" if int(p.loan.get("from", -1)) == club.id else "emprestado pelo %s") % (other.short_name if other != null else "?"))
	v.add_child(UIKit.label(" · ".join(bits), "Small"))
	h.add_child(v)
	var right := UIKit.vbox(0)
	var wl := UIKit.label(Fmt.money_month(p.wage), "H3")
	wl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(wl)
	var yrs := p.contract_end - w.year
	var col := UIColors.RED if yrs <= 0 else (Color("#E8C547") if yrs == 1 else UIColors.GREEN)
	var el := UIKit.colored("até %d" % p.contract_end if yrs > 0 else "vence nesta temporada", col, "Small")
	el.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(el)
	h.add_child(right)
	h.add_child(UIKit.badge(p.overall, 52, 36, 22))
	var pid := p.id
	var outer := UIKit.vbox(4)
	outer.add_child(UIKit.tap_row(h, func(): UIManager.push("player", {"id": pid}), "CardFlat"))
	if p.club_id == club.id and p.loan.is_empty() and yrs <= 1:
		var rb := UIKit.button("Renovar contrato", "GhostButton", func(): Negotiation.open(w, p, "renew", refresh), "clock")
		rb.custom_minimum_size = Vector2(320, 64)
		rb.size_flags_horizontal = Control.SIZE_SHRINK_END
		outer.add_child(rb)
	return outer
