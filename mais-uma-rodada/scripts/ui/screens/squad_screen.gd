extends BaseScreen
## Elenco: filtros por setor, ordenação e acesso rápido a escalação e perfil.

const FILTERS := ["Todos", "GOL", "DEF", "MEI", "ATA"]
const SORTS := [["pos", "Posição"], ["ovr", "Overall"], ["age", "Idade"], ["contract", "Contrato"], ["value", "Valor"]]

var _filter := 0
var _sort := "pos"


func _init() -> void:
	nav_tab = "squad"
	screen_title = "Elenco"


func setup(p: Dictionary) -> void:
	super.setup(p)
	_sort = p.get("sort", "pos")


func refresh() -> void:
	var w := world()
	if w == null:
		return
	var club := w.user_club()
	var squad := w.squad(club)
	var ages := 0.0
	for p in squad:
		ages += p.age(w.year)
	screen_subtitle = "%d jogadores · idade média %s" % [squad.size(), Fmt._decimal(ages / maxf(1.0, squad.size()), 1)]
	UIManager.refresh_chrome()
	var c := content()
	UIKit.clear(c)
	var top := UIKit.hbox(10)
	var lineup := UIKit.button("Escalação e tática", "", func(): UIManager.push("prematch", {"edit": true}), "tactics")
	lineup.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(lineup)
	c.add_child(top)
	var fin := FinanceManager.summary(w, club)
	var bill := UIKit.hbox(8)
	bill.add_child(UIKit.label("Folha salarial", "Muted"))
	var bl := UIKit.label("%s / %s" % [Fmt.money_month(fin["wage_bill"]), Fmt.money(fin["wage_budget"])], "H3")
	bl.add_theme_color_override(&"font_color", UIColors.RED if fin["wage_bill"] > fin["wage_budget"] else UIColors.TEXT)
	bill.add_child(UIKit.spacer())
	bill.add_child(bl)
	c.add_child(bill)
	var g := ButtonGroup.new()
	var frow := UIKit.hbox(8)
	for i in FILTERS.size():
		var idx := i
		frow.add_child(UIKit.chip(FILTERS[i], i == _filter, g, func():
			_filter = idx
			refresh()))
	c.add_child(frow)
	var g2 := ButtonGroup.new()
	var srow := UIKit.hbox(6)
	srow.add_child(UIKit.label("Ordenar", "Small"))
	for s in SORTS:
		var key: String = s[0]
		var chip := UIKit.chip(s[1], key == _sort, g2, func():
			_sort = key
			refresh())
		chip.add_theme_font_size_override(&"font_size", 17)
		srow.add_child(chip)
	c.add_child(srow)
	var list: Array = []
	for p in squad:
		if _filter == 0 or Pos.group(p.position) == _filter - 1:
			list.append(p)
	var y := w.year
	match _sort:
		"ovr":
			list.sort_custom(func(a, b): return a.ovr_f > b.ovr_f)
		"age":
			list.sort_custom(func(a, b): return a.age(y) < b.age(y))
		"contract":
			list.sort_custom(func(a, b): return a.contract_end < b.contract_end or (a.contract_end == b.contract_end and a.ovr_f > b.ovr_f))
		"value":
			list.sort_custom(func(a, b): return a.value > b.value)
		_:
			list.sort_custom(func(a, b):
				var ia := Pos.DISPLAY_ORDER.find(a.position)
				var ib := Pos.DISPLAY_ORDER.find(b.position)
				if ia != ib:
					return ia < ib
				return a.ovr_f > b.ovr_f)
	var last_group := -1
	for p: Player in list:
		if _sort == "pos" and Pos.group(p.position) != last_group:
			last_group = Pos.group(p.position)
			c.add_child(UIKit.section(Pos.GROUP_NAMES[last_group]))
		var pid := p.id
		c.add_child(PlayerRowView.make(w, p, {"mode": "squad"}, func(): UIManager.push("player", {"id": pid})))
	var out := TransferManager.loaned_out(w)
	if not out.is_empty():
		c.add_child(UIKit.section("Emprestados (voltam no fim da temporada)"))
		for p: Player in out:
			var pid := p.id
			c.add_child(PlayerRowView.make(w, p, {"mode": "market"}, func(): UIManager.push("player", {"id": pid})))
