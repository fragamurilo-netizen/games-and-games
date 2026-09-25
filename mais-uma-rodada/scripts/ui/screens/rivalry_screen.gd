extends BaseScreen
## Linha do tempo de uma rivalidade: termômetro, retrospecto e os momentos que a criaram.

var _a := -1
var _b := -1


func _init() -> void:
	show_nav = false
	screen_title = "Rivalidade"


func setup(p: Dictionary) -> void:
	super.setup(p)
	_a = int(p.get("a", -1))
	_b = int(p.get("b", -1))


func refresh() -> void:
	var w := world()
	if w == null:
		return
	var ca := w.club(_a)
	var cb := w.club(_b)
	if ca == null or cb == null:
		return
	var h := Rivalry.heat(w, _a, _b)
	screen_subtitle = "%s x %s" % [ca.short_name, cb.short_name]
	UIManager.refresh_chrome()
	var c := content()
	UIKit.clear(c)
	# Cabeçalho
	var card := UIKit.card("Card", 10)
	var row := UIKit.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(_side(ca))
	var mid := UIKit.vbox(2)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lv := Rivalry.level_name(h)
	var big := UIKit.colored(str(int(round(h))), RivalryView.heat_color(h), "Title")
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(big)
	var cap := UIKit.label(lv if lv != "" else "Sem rixa", "Caps")
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(cap)
	row.add_child(mid)
	row.add_child(_side(cb))
	card.add_child(row)
	card.add_child(RivalryView.meter(h))
	var rec := Rivalry.record_for(w, _a, _b)
	if int(rec["g"]) > 0:
		var stats := UIKit.hbox(8)
		stats.add_child(UIKit.stat(str(rec["w"]), "Vitórias " + ca.short_name, UIColors.GREEN))
		stats.add_child(UIKit.stat(str(rec["d"]), "Empates", UIColors.MUTED))
		stats.add_child(UIKit.stat(str(rec["l"]), "Vitórias " + cb.short_name, UIColors.RED))
		card.add_child(stats)
	card.add_child(UIKit.label(RivalryView.record_text(w, _a, _b), "Small", true))
	var r := Rivalry.get_rec(w, _a, _b)
	if ca.is_rival(_b) or cb.is_rival(_a):
		card.add_child(UIKit.label("Rivais de origem: a rivalidade nunca esfria de verdade.", "Small", true))
	elif not r.is_empty():
		card.add_child(UIKit.label("Nasceu dentro do save. Pico: %d." % int(round(float(r.get("pk", 0.0)))), "Small", true))
	c.add_child(UIKit.card_panel(card))
	# Momentos
	var ev: Array = r.get("ev", [])
	var mc := UIKit.card("Card", 8)
	mc.add_child(UIKit.section("Momentos"))
	if ev.is_empty():
		mc.add_child(UIKit.label("Nada marcante ainda. Eliminações, finais, títulos decididos no detalhe e jogadores trocando de lado esquentam o confronto.", "Small", true))
	for i in range(ev.size() - 1, -1, -1):
		var e: Dictionary = ev[i]
		var er := UIKit.hbox(10)
		var y := UIKit.label(str(int(e["y"])), "H3")
		y.custom_minimum_size.x = 70
		y.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		er.add_child(y)
		var t := UIKit.label(String(e["t"]), "Small", true)
		er.add_child(t)
		er.add_child(UIKit.colored("+%d" % int(round(float(e["p"]))), RivalryView.heat_color(h), "Small"))
		mc.add_child(er)
	c.add_child(UIKit.card_panel(mc))


func _side(club: Club) -> Control:
	var v := UIKit.vbox(4)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var cr := UIKit.crest(club, 72)
	cr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(cr)
	var l := UIKit.label(club.short_name, "H3")
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	var cid := club.id
	var open := func():
		if world().is_user_club(cid):
			UIManager.goto("club")
		else:
			UIManager.push("club", {"id": cid})
	var b := UIKit.tap_row(v, open, "CardFlat")
	b.custom_minimum_size.x = 150
	return b
