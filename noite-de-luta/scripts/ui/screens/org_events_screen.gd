extends BaseScreen
## Eventos da organização: as próximas noites (para montar o card) e as que já aconteceram (com
## as contas). Aqui fica a escolha de deixar o matchmaker completar as vagas sozinho.

var _view := "next"


func setup(p: Dictionary) -> void:
	super.setup(p)
	screen_title = "Eventos"


func refresh() -> void:
	var w := world()
	if w == null:
		return
	screen_subtitle = w.league_name()
	UIManager.refresh_chrome()
	var c := reset()
	c.add_child(UIKit.tabs([["next", "Próximas"], ["past", "Anteriores"]], _view, func(k: String):
		_view = k
		refresh()))
	if _view == "next":
		var del := CheckButton.new()
		del.text = "Matchmaker completa as vagas"
		del.button_pressed = w.delegate_cards
		del.custom_minimum_size.y = UITokens.H_BUTTON
		del.toggled.connect(func(on: bool):
			w.delegate_cards = on
			GameManager.save_now())
		c.add_child(del)
		c.add_child(UIKit.label("Ligado, o matchmaker da organização fecha as lutas que faltarem %d semanas antes de cada noite. As disputas de cinturão e as lutas principais são sempre suas." % Org.DELEGATE_WEEKS, "Small", true))
		var ups := Org.upcoming_events(w)
		if ups.is_empty():
			c.add_child(UIKit.state_block("empty", "Nenhuma noite marcada", "O calendário marca uma noite da liga a cada duas semanas."))
		for ev: FightEvent in ups:
			var id := ev.id
			c.add_child(OrgKit.event_card(w, ev, func(): UIManager.push("org_event", {"id": id})))
	else:
		var past := Org.past_events(w)
		if past.is_empty():
			c.add_child(UIKit.state_block("empty", "Nenhuma noite fechada ainda", "As contas de cada noite aparecem aqui depois do evento."))
		for ev: FightEvent in past:
			var id := ev.id
			c.add_child(OrgKit.event_card(w, ev, func(): UIManager.push("org_event", {"id": id})))
	columnize(c, 3 if _view == "next" else 1, 2)
