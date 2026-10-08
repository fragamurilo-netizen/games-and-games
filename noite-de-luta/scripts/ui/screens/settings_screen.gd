extends BaseScreen
## Opções do aparelho: som, vibração, velocidade da luta ao vivo e movimento.


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


func _toggle(text: String, on: bool, cb: Callable) -> Control:
	var b := CheckButton.new()
	b.text = text
	b.button_pressed = on
	b.custom_minimum_size.y = UITokens.H_BUTTON
	b.toggled.connect(func(v: bool):
		cb.call(v)
		AppSettings.save_settings())
	return b
