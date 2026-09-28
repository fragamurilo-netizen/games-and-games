extends BaseScreen
## Listas de joias: NXGN (ranking sub-21 do portal Golaço) e Next Generation (os talentos de 17
## anos do Albion Post), ano a ano. Toque no jogador para abrir a ficha.

var _list := "nx"
var _year := 0


func _init() -> void:
	show_nav = false
	screen_title = "Joias do futebol"


func refresh() -> void:
	var w := world()
	if w == null:
		return
	var all := NextGen.lists(w)
	var years: Array = all.keys()
	years.sort()
	years.reverse()
	if _year == 0 or not all.has(str(_year)):
		_year = int(years[0]) if not years.is_empty() else w.year
	screen_subtitle = "NXGN e Next Generation"
	UIManager.refresh_chrome()
	var c := content()
	UIKit.clear(c)
	var g := ButtonGroup.new()
	var row := UIKit.hbox(8)
	for t in [["nx", "NXGN · sub-21"], ["ng", "Next Generation · 17 anos"]]:
		var key: String = t[0]
		var chip := UIKit.chip(t[1], key == _list, g, func():
			_list = key
			refresh())
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(chip)
	c.add_child(row)
	if years.size() > 1:
		var gy := ButtonGroup.new()
		var yr := UIKit.flow(8)
		for y in years:
			var yy := int(y)
			var ch := UIKit.chip(str(yy), yy == _year, gy, func():
				_year = yy
				refresh())
			UIKit.shrink_button(ch)
			yr.add_child(ch)
		c.add_child(yr)
	var cur: Dictionary = all.get(str(_year), {})
	var ids: Array = cur.get(_list, [])
	var card := UIKit.card("Card", 6)
	if _list == "nx":
		card.add_child(UIKit.section("NXGN %d · portal Golaço" % _year))
		card.add_child(UIKit.label("Os 50 melhores jogadores sub-21 do mundo, em ordem.", "Small", true))
	else:
		card.add_child(UIKit.section("Next Generation %d · The Albion Post" % _year))
		card.add_child(UIKit.label("Os melhores talentos nascidos em %d, um por clube (sem ordem)." % (_year - 17), "Small", true))
	if ids.is_empty():
		card.add_child(UIKit.label("A lista %s sai %s da temporada." % ["NXGN" if _list == "nx" else "Next Generation", "na segunda metade" if _list == "nx" else "no começo"], "Muted", true))
	for i in ids.size():
		var p := w.player(int(ids[i]))
		if p != null:
			card.add_child(_row(w, p, i + 1 if _list == "nx" else 0))
	c.add_child(UIKit.card_panel(card))


func _row(w: GameWorld, p: Player, rank: int) -> Control:
	var h := UIKit.hbox(10)
	if rank > 0:
		var r := UIKit.label(str(rank), "H2" if rank <= 3 else "H3")
		r.custom_minimum_size.x = 48
		r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if rank == 1:
			r.add_theme_color_override(&"font_color", UIColors.ink(Color("#E8C547")))
		h.add_child(r)
	var cl := w.club(p.club_id)
	if cl != null:
		h.add_child(UIKit.crest(cl, 36))
	var v := UIKit.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var n := UIKit.label(p.display_name(), "H3")
	n.clip_text = true
	if w.has_user() and p.club_id == w.user_club_id:
		n.add_theme_color_override(&"font_color", UIColors.ACCENT)
	v.add_child(n)
	v.add_child(UIKit.label("%s · %d anos · %s" % [Pos.code(p.position), p.age(w.year), cl.short_name if cl != null else "sem clube"], "Small"))
	h.add_child(v)
	h.add_child(UIKit.flag(p.nationality, 30))
	h.add_child(UIKit.badge(p.overall, 52, 36, 22))
	var pid := p.id
	return UIKit.tap_row(h, func(): UIManager.push("player", {"id": pid}), "CardFlat")
