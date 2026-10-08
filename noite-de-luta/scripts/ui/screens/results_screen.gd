extends BaseScreen
## Central de resultados: todas as noites de uma semana, da liga ao circuito regional, com o
## resultado de cada luta. É como o fã acompanha quem está subindo antes de chegar à elite.

var _wk := -1


func setup(p: Dictionary) -> void:
	super.setup(p)
	screen_title = "Resultados"
	show_nav = false


func refresh() -> void:
	var w := world()
	if w == null:
		return
	if _wk < 0:
		_wk = w.week - 1
		# Presidente na semana da noite, depois de fechar: mostra a semana atual.
		for e: FightEvent in Calendar.events_in_week(w, w.week):
			if e.done or e.closed or Org.event_bouts(w, e).any(func(b: Bout) -> bool: return b.status == "feita"):
				_wk = w.week
	screen_subtitle = "Semana de " + GameWorld.week_text(_wk)
	UIManager.refresh_chrome()
	var c := reset()
	var items: Array = []
	for i in range(4):
		var k := w.week - i
		items.append([str(k), "Esta" if i == 0 else ("Passada" if i == 1 else "Há %d" % i)])
	c.add_child(UIKit.segment(items, str(_wk), func(k: String):
		_wk = int(k)
		refresh()))
	var evs := Calendar.events_in_week(w, _wk)
	var any := false
	for ev: FightEvent in evs:
		var done := Org.event_bouts(w, ev).filter(func(b: Bout) -> bool: return b.status == "feita")
		if done.is_empty():
			continue
		any = true
		var tier_name := w.league_name() if ev.tier == 2 else Rankings.tier_name(ev.tier)
		var eid := ev.id
		c.add_child(UIKit.section_header("%s · %s" % [ev.name, tier_name], "Card", func(): UIManager.push("event", {"id": eid})))
		var ids: Array = done.map(func(b: Bout) -> int: return b.id)
		ids.reverse()
		for bid: int in ids:
			var b := w.bout(bid)
			c.add_child(OrgKit.bout_row(w, b, func(): UIManager.push("fighter", {"id": b.a})))
	if not any:
		c.add_child(UIKit.state_block("empty", "Sem lutas nessa semana", "Os resultados aparecem depois do sábado."))
