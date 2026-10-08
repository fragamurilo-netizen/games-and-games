class_name StaffRow
extends RefCounted
## Linha de staff: retrato de terno, nome, idade, qualidade em estrelas e salário.


static func make(w: GameWorld, s: Dictionary, cb: Callable) -> PanelContainer:
	var h := UIKit.hbox(UITokens.S2)
	var t := w.user_team()
	h.add_child(FightKit.staff_portrait(s, 56, t.color1 if t != null else UIColors.ACCENT))
	var v := UIKit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var top := UIKit.hbox(8)
	top.add_child(UIKit.flag(String(s.get("nation", "BRA")), 30))
	var n := UIKit.label(String(s["name"]), "H3")
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(n)
	v.add_child(top)
	var st := StarsView.new()
	st.star_size = 16
	st.stars = StarsView.from_value(float(s["quality"]))
	var line := UIKit.hbox(8)
	line.add_child(st)
	line.add_child(UIKit.label("%d anos" % int(s["age"]), "Small"))
	v.add_child(line)
	h.add_child(v)
	var wage := UIKit.label(Fmt.money(float(s["wage"])) + "/sem", "Caps")
	wage.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(wage)
	var row := UIKit.tap_row(h, cb)
	row.custom_minimum_size.y = UITokens.H_ROW
	return row
