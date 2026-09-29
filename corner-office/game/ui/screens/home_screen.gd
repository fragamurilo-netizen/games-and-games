extends Screen
## Início: próximo evento + decisões que exigem atenção (Game Design Bible §15).


func title() -> String:
	return "Início"


func build() -> void:
	var w := Game.world
	var org := w.player_org()
	add_text(GameDate.format(w.date), Tokens.MUTED)
	add_text("%s — caixa US$ %s" % [org.name, String.num_int64(org.cash)])
	var b := Button.new()
	b.text = "Avançar semana"
	b.custom_minimum_size.y = Tokens.TOUCH_MIN
	b.pressed.connect(func():
		Game.sim.advance_week()
		refresh())
	body.add_child(b)
	add_todo("próximo evento, caixa de decisões (propostas, crises, contratos) e notícias.")
