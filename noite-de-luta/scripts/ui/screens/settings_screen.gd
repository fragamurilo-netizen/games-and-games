extends BaseScreen
## Opções do aparelho (som, vibração, velocidade da luta ao vivo e movimento) e, com uma carreira
## aberta, as dicas de primeira vez das telas.


func setup(p: Dictionary) -> void:
	super.setup(p)
	screen_title = "Opções"
	show_nav = false


func refresh() -> void:
	var c := reset()
	c.add_child(_toggle("Som", AppSettings.sound, func(on: bool): AppSettings.sound = on))
	c.add_child(_toggle("Vibração", AppSettings.vibration, func(on: bool): AppSettings.vibration = on))
	c.add_child(_toggle("Menos animação", AppSettings.reduce_motion, func(on: bool): AppSettings.reduce_motion = on))
	c.add_child(UIKit.section_header("Velocidade da luta ao vivo"))
	var items: Array = []
	for i in AppSettings.FIGHT_SPEED_NAMES.size():
		items.append([str(i), AppSettings.FIGHT_SPEED_NAMES[i]])
	c.add_child(UIKit.segment(items, str(AppSettings.fight_speed), func(k: String):
		AppSettings.fight_speed = int(k)
		AppSettings.save_settings()))
	var w := world()
	if w == null:
		return
	# Da carreira aberta: as dicas de primeira vez das telas.
	c.add_child(UIKit.section_header("Ajuda nesta carreira"))
	var tips := CheckButton.new()
	tips.text = "Dicas na primeira visita a cada tela"
	tips.button_pressed = bool(w.tut.get("tips_on", false))
	tips.custom_minimum_size.y = UITokens.H_BUTTON
	tips.toggled.connect(func(v: bool):
		w.tut["tips_on"] = v
		GameManager.save_now())
	c.add_child(tips)
	c.add_child(UIKit.button("Mostrar todas as dicas de novo", "GhostButton", func():
		w.tut["tips"] = {}
		w.tut["tips_on"] = true
		GameManager.save_now()
		UIManager.toast("As dicas voltam a aparecer na próxima visita a cada tela.")
		refresh()))


func _toggle(text: String, on: bool, cb: Callable) -> Control:
	var b := CheckButton.new()
	b.text = text
	b.button_pressed = on
	b.custom_minimum_size.y = UITokens.H_BUTTON
	b.toggled.connect(func(v: bool):
		cb.call(v)
		AppSettings.save_settings())
	return b
