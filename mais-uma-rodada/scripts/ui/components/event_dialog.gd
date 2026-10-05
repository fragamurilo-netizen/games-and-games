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
	var head := UIKit.hbox(14)
	var tile := PanelContainer.new()
	tile.theme_type_variation = "IconTile"
	tile.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	tile.add_child(UIKit.icon_rect(String(kind.get("icon", "info")), 32, color_of(ev)))
	head.add_child(tile)
	var hc := UIKit.vbox(2)
	hc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var left := int(ev["exp"]) - w.current_turn()
	var eb := UIKit.hbox(8)
	eb.add_child(UIKit.eyebrow("Decisão", color_of(ev)))
	eb.add_child(UIKit.pill(I18n.t(("%d jogo para responder" if maxi(1, left) == 1 else "%d jogos para responder")) % maxi(1, left), UIColors.ORANGE if left <= 1 else UIColors.MUTED, 14))
	hc.add_child(eb)
	hc.add_child(UIKit.label(String(desc["title"]), "Title", true))
	head.add_child(hc)
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
		row.add_child(UIKit.player_stars(w,p,15))
		var pc := UIKit.card("CardInset", 0)
		pc.add_child(row)
		v.add_child(UIKit.card_panel(pc))
	v.add_child(UIKit.label(String(desc["body"]), "", true))
	v.add_child(UIKit.section_header("Sua resposta"))
	var opts: Array = desc["options"]
	var def := int(desc.get("def", 0))
	for i in opts.size():
		var o: Dictionary = opts[i]
		var row := UIKit.hbox(14)
		var letter := UIKit.pill(["A", "B", "C", "D", "E"][mini(i, 4)], UIColors.ACCENT, 18)
		letter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(letter)
		var col := UIKit.vbox(2)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UIKit.label(String(o["t"]), "H3", true))
		if has_terms(String(o.get("hint", ""))):
			col.add_child(UIKit.label(String(o["hint"]), "Small", true))
		if i == def:
			var dp := UIKit.pill("PADRÃO", UIColors.MUTED, 13)
			dp.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			col.add_child(dp)
		row.add_child(col)
		row.add_child(UIKit.icon_rect("forward", 22, UIColors.DIM))
		var idx := i
		v.add_child(UIKit.tap_row(row, func():
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


## Só mostra a dica da opção quando ela traz termos concretos (valores, prazos, números).
static func has_terms(h: String) -> bool:
	for ch in h:
		if ch >= "0" and ch <= "9":
			return true
	return false
