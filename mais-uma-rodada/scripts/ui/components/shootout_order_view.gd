class_name ShootoutOrderView
extends RefCounted
## Ordem dos batedores na disputa de pênaltis: setas sobem e descem cada jogador.
## Os cinco primeiros batem as cobranças regulares; o resto segue nas alternadas.


## Nota de cobrança (0–100) que o jogo usa para ordenar a disputa automaticamente.
static func pen_rating(p: Player) -> int:
	return int(round(p.attr(Attr.FIN) * 0.45 + p.attr(Attr.FRI) * 0.35 + p.attr(Attr.DEC) * 0.1 + p.attr(Attr.INT) * 0.1))


## players: Players na ordem atual; auto_players: a ordem automática (botão "Automática").
## on_done recebe os ids na ordem escolhida (vazio = automática).
static func build(title: String, hint: String, players: Array, auto_players: Array, on_done: Callable) -> VBoxContainer:
	var v := UIKit.vbox(10)
	v.add_child(UIKit.label(title, "Title"))
	if hint != "":
		v.add_child(UIKit.label(hint, "Small", true))
	var list := UIKit.vbox(6)
	v.add_child(list)
	var order: Array = players.duplicate()
	var state := {"auto": false}
	var redraw := func(self_ref: Callable) -> void:
		UIKit.clear(list)
		for i in order.size():
			var p: Player = order[i]
			var row := UIKit.hbox(10)
			var n := UIKit.label("%d" % (i + 1), "H3" if i < 5 else "Muted")
			n.custom_minimum_size.x = 36
			row.add_child(n)
			var nm := UIKit.label(p.display_name(), "H3" if i < 5 else "")
			nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			nm.clip_text = true
			row.add_child(nm)
			row.add_child(UIKit.label("Cobrança %d" % pen_rating(p), "Small"))
			var idx := i
			var up := UIKit.icon_button("up", func():
				if idx > 0:
					order[idx] = order[idx - 1]
					order[idx - 1] = p
					state["auto"] = false
					self_ref.call(self_ref), "Subir")
			up.disabled = i == 0
			row.add_child(up)
			var down := UIKit.icon_button("down", func():
				if idx < order.size() - 1:
					order[idx] = order[idx + 1]
					order[idx + 1] = p
					state["auto"] = false
					self_ref.call(self_ref), "Descer")
			down.disabled = i == order.size() - 1
			row.add_child(down)
			list.add_child(row)
			if i == 4 and order.size() > 5:
				list.add_child(UIKit.label("Alternadas, se precisar:", "Small", true))
	redraw.call(redraw)
	var btns := UIKit.hbox(10)
	btns.add_child(UIKit.button("Automática", "GhostButton", func():
		order.clear()
		order.append_array(auto_players)
		state["auto"] = true
		redraw.call(redraw)))
	var ok := UIKit.button("Confirmar", "", func():
		var ids: Array = []
		if not state["auto"]:
			for p: Player in order:
				ids.append(p.id)
		on_done.call(ids))
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btns.add_child(ok)
	v.add_child(btns)
	return v


## Ordem de uma lista de Players: primeiro os de `ids`, depois o resto pela nota de
## cobrança, com goleiros por último.
static func ordered(players: Array, ids: Array) -> Array:
	var rest: Array = players.duplicate()
	var out: Array = []
	for pid in ids:
		for p: Player in rest:
			if p.id == int(pid):
				out.append(p)
				rest.erase(p)
				break
	rest.sort_custom(func(a: Player, b: Player):
		var ga := a.position == Pos.GK
		var gb := b.position == Pos.GK
		if ga != gb:
			return gb
		return pen_rating(a) > pen_rating(b))
	return out + rest
