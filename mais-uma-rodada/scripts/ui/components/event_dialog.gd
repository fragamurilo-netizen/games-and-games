class_name EventDialog
extends RefCounted
## Folha de decisão de um evento da carreira (EventManager): contexto, jogador envolvido
## e as opções com a consequência resumida.


static func open(ev: Dictionary, on_done: Callable = Callable()) -> void:
	var w := GameManager.world
	if w == null:
		return
	var desc := EventManager.describe(w, ev)
	var kind: Dictionary = EventManager.KINDS.get(String(ev["k"]), {})
	var v := UIKit.vbox(14)
	var head := UIKit.hbox(12)
	head.add_child(UIKit.icon_rect(String(kind.get("icon", "info")), 40, color_of(ev)))
	var t := UIKit.label(String(desc["title"]), "Title", true)
	head.add_child(t)
	v.add_child(head)
	var p: Player = w.player(int(ev.get("p", -1)))
	if p != null:
		var row := UIKit.hbox(12)
		row.add_child(UIKit.portrait(p, w.club(p.club_id), w.year, 76))
		var col := UIKit.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UIKit.label(p.full_name(), "H3", true))
		col.add_child(UIKit.label("%d anos · %s · moral %s" % [p.age(w.year), Pos.name_of(p.position), UIColors.morale_label(p.morale).to_lower()], "Small", true))
		row.add_child(col)
		row.add_child(UIKit.badge(p.overall))
		v.add_child(row)
	v.add_child(UIKit.label(String(desc["body"]), "", true))
	var left := int(ev["exp"]) - w.current_turn()
	v.add_child(UIKit.label("Responda em até %d jogo(s). Sem resposta: \"%s\"." % [maxi(1, left), desc["options"][int(desc.get("def", 0))]["t"]], "Small", true))
	var opts: Array = desc["options"]
	for i in opts.size():
		var o: Dictionary = opts[i]
		var col := UIKit.vbox(2)
		col.add_child(UIKit.label(String(o["t"]), "H3", true))
		if String(o.get("hint", "")) != "":
			col.add_child(UIKit.label(String(o["hint"]), "Small", true))
		var idx := i
		v.add_child(UIKit.tap_row(col, func():
			var msg := EventManager.resolve(w, ev, idx)
			UIManager.close_modal()
			if msg != "":
				UIManager.toast(msg)
			GameManager.save_now()
			if on_done.is_valid():
				on_done.call(), "Card"))
	v.add_child(UIKit.button("Decidir depois", "GhostButton", func(): UIManager.close_modal()))
	UIManager.show_modal(v, true)


static func color_of(ev: Dictionary) -> Color:
	var kind: Dictionary = EventManager.KINDS.get(String(ev["k"]), {})
	match String(kind.get("color", "")):
		"RED":
			return UIColors.RED
		"GREEN":
			return UIColors.GREEN
		"ORANGE":
			return UIColors.ORANGE
		"BLUE":
			return UIColors.BLUE
	return UIColors.ACCENT
