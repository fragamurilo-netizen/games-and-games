extends BaseScreen
## Caixa de entrada: as pendências (cada uma com os botões de ação) e os avisos do que
## aconteceu com a equipe. Filtra por pendentes, tudo ou assunto. As mensagens que apareceram
## na tela ficam lidas quando o jogador sai dela.

var _view := "pend"
var _cat := ""
var _shown: Array = []


func setup(p: Dictionary) -> void:
	super.setup(p)
	screen_title = "Caixa de entrada"
	show_nav = false


func on_hide() -> void:
	for m: Dictionary in _shown:
		Inbox.mark_read(m)
	_shown = []
	GameManager.save_now()


func refresh() -> void:
	var w := world()
	if w == null:
		return
	Inbox.scan(w)
	var pend := Inbox.pending(w)
	var unread := Inbox.unread(w)
	screen_subtitle = "%s · %s" % [Fmt.plural(pend.size(), "pendência", "pendências"), "%d não lidas" % unread if unread != 1 else "1 não lida"]
	UIManager.refresh_chrome()
	var c := reset()
	_shown = []
	c.add_child(UIKit.segment([["pend", "Pendentes (%d)" % pend.size()], ["tudo", "Tudo"]], _view, func(k: String):
		_view = k
		_cat = ""
		refresh()
		scroll_to_top()))
	if _view == "pend":
		if pend.is_empty():
			c.add_child(UIKit.state_block("empty", "Nada esperando decisão", "O que precisar de você aparece aqui: propostas, contratos, imprevistos. Os avisos ficam em Tudo.", "Ver tudo", func():
				_view = "tudo"
				refresh()))
		_bulk(c, w, pend)
		for m: Dictionary in pend:
			c.add_child(InboxKit.card(w, m, refresh))
			_shown.append(m)
		columnize(c, 1, 2)
		hide_footer()
		return
	var lst := Inbox.all(w)
	var cats: Array = [["", "Tudo"]]
	var have := {}
	for m: Dictionary in lst:
		have[String(m["cat"])] = true
	for k: String in Inbox.CATS:
		if have.has(k):
			cats.append([k, String(Inbox.CATS[k])])
	if cats.size() > 2:
		c.add_child(UIKit.scroll_tabs(cats, _cat, func(k: String):
			_cat = k
			refresh()))
	if _cat != "":
		lst = lst.filter(func(m: Dictionary) -> bool: return String(m["cat"]) == _cat)
	if lst.is_empty():
		c.add_child(UIKit.state_block("empty", "Caixa vazia", "As mensagens chegam com o passar das semanas."))
	var rows: Array = []
	var last_wk := -99999
	for m: Dictionary in lst.slice(0, 60):
		var wk := int(m["wk"])
		if wk != last_wk:
			if not rows.is_empty():
				c.add_child(UIKit.menu_group(rows))
				rows = []
			last_wk = wk
			c.add_child(UIKit.section_header(_cap(w.weeks_from_now(wk))))
		if Inbox.is_open(m):
			if not rows.is_empty():
				c.add_child(UIKit.menu_group(rows))
				rows = []
			c.add_child(InboxKit.card(w, m, refresh))
		else:
			rows.append(InboxKit.row(w, m, refresh))
		_shown.append(m)
	if not rows.is_empty():
		c.add_child(UIKit.menu_group(rows))
	var foot := footer()
	foot.add_child(UIKit.button("Marcar tudo como lido", "GhostButton", func():
		Inbox.mark_all_read(w)
		GameManager.save_now()
		refresh()))
	foot.get_parent().visible = unread > 0
	TutorialKit.tip(self, "inbox")


static func _cap(t: String) -> String:
	return t.substr(0, 1).to_upper() + t.substr(1)


## Um toque para o que é rotina: o matchmaker fecha cards e cinturões vagos (presidente) e o
## técnico toca os camps como estão (manager). O que pede escolha de verdade continua na lista.
func _bulk(c: Control, w: GameWorld, pend: Array) -> void:
	if w.is_president():
		var n := pend.filter(func(m: Dictionary) -> bool:
			return String(m["act"]) == "org_event" or String(m.get("key", "")).begins_with("vago:")).size()
		if n < 2:
			return
		c.add_child(UIKit.button("Deixar %d com o matchmaker" % n, "GhostButton", func():
			var res := Org.matchmaker_now(w, Inbox.CARD_WEEKS)
			GameManager.save_now()
			var fights := int(res["fights"])
			var belts := int(res["belts"])
			if fights + belts == 0:
				UIManager.toast("Ninguém livre para fechar agora.")
			else:
				Sfx.play("sign", -4.0)
				UIManager.toast("Matchmaker: %s e %s." % [Fmt.plural(fights, "luta fechada", "lutas fechadas"), Fmt.plural(belts, "disputa de cinturão", "disputas de cinturão")], UIColors.GREEN)
			refresh(), "bolt"))
	else:
		var camps := pend.filter(func(m: Dictionary) -> bool: return String(m["act"]) == "camp")
		if camps.size() < 2:
			return
		c.add_child(UIKit.button("Deixar %d camps com o técnico" % camps.size(), "GhostButton", func():
			for m: Dictionary in camps:
				Inbox.handle(m)
			GameManager.save_now()
			UIManager.toast("O técnico toca os camps como estão.", UIColors.GREEN)
			refresh(), "bolt"))
