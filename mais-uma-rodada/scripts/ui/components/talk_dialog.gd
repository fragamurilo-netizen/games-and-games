class_name TalkDialog
extends RefCounted
## Folha de conversa (Talks): balões do interlocutor e seus, opções de resposta e, no fim,
## o resumo do que mudou nas relações.


static func open(kind: String, target: int = -1, on_done: Callable = Callable()) -> void:
	var w := GameManager.world
	if w == null:
		return
	var conv := Talks.start(w, kind, target)
	var root := UIKit.vbox(12)
	root.custom_minimum_size.x = 600
	UIManager.show_modal(root, true)
	_render(root, conv, on_done)


static func _render(root: VBoxContainer, conv: Dictionary, on_done: Callable) -> void:
	var w := GameManager.world
	UIKit.clear(root)
	var head := UIKit.hbox(12)
	var p: Player = w.player(int(conv.get("p", -1)))
	if p != null:
		head.add_child(UIKit.portrait(p, w.club(p.club_id), w.year, 72))
	else:
		head.add_child(UIKit.icon_rect(_icon(String(conv["k"])), 44, UIColors.ACCENT))
	var col := UIKit.vbox(0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UIKit.label(String(conv["who"]), "H2", true))
	if String(conv.get("sub", "")) != "":
		col.add_child(UIKit.label(String(conv["sub"]), "Small", true))
	head.add_child(col)
	root.add_child(head)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = 260
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var lines := UIKit.vbox(10)
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(lines)
	for ln in conv["lines"]:
		lines.add_child(_bubble(String(ln[0]), String(ln[1])))
	root.add_child(scroll)
	scroll.ready.connect(func(): scroll.set_deferred("scroll_vertical", 100000))
	if conv.get("done", false):
		var fx: Array = conv.get("fx", [])
		if not fx.is_empty():
			var box := UIKit.card("CardFlat", 4)
			box.add_child(UIKit.label("O que mudou", "Caps"))
			for t in fx:
				box.add_child(UIKit.label("• " + String(t), "Small", true))
			root.add_child(UIKit.card_panel(box))
		root.add_child(UIKit.button("Fechar", "PrimaryButton", func():
			UIManager.close_modal()
			GameManager.save_now()
			if on_done.is_valid():
				on_done.call()))
		return
	for o in conv["opts"]:
		var v := UIKit.vbox(2)
		v.add_child(UIKit.label(String(o["t"]), "H3", true))
		if String(o.get("hint", "")) != "":
			v.add_child(UIKit.label(String(o["hint"]), "Small", true))
		var id := String(o["id"])
		root.add_child(UIKit.tap_row(v, func():
			Talks.choose(w, conv, id)
			_render(root, conv, on_done), "Card"))


static func _bubble(who: String, text: String) -> Control:
	var row := UIKit.hbox(0)
	var lbl := UIKit.label(text, "" if who != "info" else "Small", true)
	lbl.custom_minimum_size.x = 380
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	match who:
		"me":
			panel.add_theme_stylebox_override(&"panel", _bubble_box(Color(UIColors.ACCENT.r, UIColors.ACCENT.g, UIColors.ACCENT.b, 0.18), UIColors.ACCENT_DARK))
			row.add_child(UIKit.gap(60))
			row.add_child(panel)
		"npc":
			panel.add_theme_stylebox_override(&"panel", _bubble_box(UIColors.SURFACE_3, UIColors.LINE))
			row.add_child(panel)
			row.add_child(UIKit.gap(60))
		_:
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.add_theme_color_override(&"font_color", UIColors.MUTED)
			row.add_child(lbl)
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			return row
	panel.add_child(UIKit.margin(lbl, 14, 10, 14, 10))
	return row


static func _bubble_box(bg: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(18)
	return box


static func _icon(kind: String) -> String:
	match kind:
		"board":
			return "shield"
		"staff":
			return "tactics"
		"fans":
			return "heart"
		"coach":
			return "whistle"
		"press":
			return "news"
	return "info"
