extends Node
## Regression of hidden screens, modal lifecycle and formatted translations.
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("UI_LOCALE_FAIL: " + message)

func frames(count: int = 4) -> void:
	for i in count:
		await get_tree().process_frame

func _ready() -> void:
	_run()

func _run() -> void:
	AppSettings.reduce_motion = true
	I18n.apply("en")
	var table := PatternTranslation.new()
	table.locale = "en"
	table.load_entries({
		"Confiança: %d%%": "Confidence: %d%%",
		"Saldo: %+d": "Balance: %+d",
		"Rodada %02d": "Matchday %02d",
		"Posições: %s": "Positions: %s",
		"Texto: %s": "Text: %s",
		"Pressão": "Pressure",
		"De Graafschap": "De Graafschap",
		"De %s": "From %s",
		"O {team} tem {n}% de posse.": "{team} has {n}% possession.",
	})
	check(table.lookup("Confiança: 75%") == "Confidence: 75%", "formatted percentage and literal percent")
	check(table.lookup("Saldo: +3") == "Balance: +3", "signed format")
	check(table.lookup("Rodada 03") == "Matchday 03", "padded format")
	check(table.lookup("Posições: 1º, 11º, 21º e 2ª") == "Positions: 1st, 11th, 21st e 2nd", "ordinal boundaries and feminine ordinal")
	check(table.lookup("Texto: Pressão\nDe Graafschap") == "Text: Pressure\nDe Graafschap", "multiline capture and proper name")
	check(table.lookup("De Graafschap") == "De Graafschap", "identity precedes generic pattern")
	check(table.lookup("O De Graafschap tem 65% de posse.") == "De Graafschap has 65% possession.", "literal percentage before Portuguese 'de' is not a format token")
	for code in ["en", "es"]:
		I18n.apply(code)
		var data := DataTable.new()
		data.state = {"sort": "age", "desc": true}
		var header := data._head_cell({"key": "age", "title": "Idade", "w": 60, "text": func(_v): return "20"}, false)
		check(header.text == ("Age ↓" if code == "en" else "Edad ↓"), "sorted table header remains translated " + code)
		header.free()
		data.free()
		check(I18n.t("23 anos · Titular") == ("23 years old · Starter" if code == "en" else "23 años · Titular"), "age in composed player description " + code)
		check(I18n.t("12 jogos · 3 gols · 1 títulos") == ("12 matches · 3 goals · 1 titles" if code == "en" else "12 partidos · 3 goles · 1 títulos"), "graduate history text " + code)
	I18n.apply("en")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await frames(8)
	var menu := UIManager.current()
	UIManager.push("settings")
	await frames()
	check(menu.process_mode == Node.PROCESS_MODE_DISABLED, "hidden screen and descendants stop processing")
	UIManager.pop_to_root()
	await frames()
	check(menu.process_mode == Node.PROCESS_MODE_INHERIT, "root processes again after returning")
	var busy_panel := UIManager.show_modal(UIKit.label("Working", "", true), false, false)
	UIManager.back()
	check(UIManager.has_modal() and not busy_panel.is_queued_for_deletion(), "back respects nondismissible modal")
	UIManager.close_all_modals()
	await frames()
	for i in 8:
		var control := UIKit.label("Long text ".repeat(24), "", true)
		var modal := UIManager.show_modal(control, true)
		await frames(2)
		for dims in [Vector2i(390, 844), Vector2i(844, 390)]:
			get_tree().root.size = dims
			main.call("_update_layout")
			await frames(8)
			var panel: PanelContainer = modal.find_children("*", "PanelContainer", true, false)[0]
			var rect := panel.get_global_rect()
			var vp := get_viewport().get_visible_rect()
			check(rect.position.x >= -1 and rect.end.x <= vp.size.x + 1, "modal fits rotated width")
			check(rect.position.y >= -1 and rect.end.y <= vp.size.y + 1, "modal fits rotated height")
		UIManager.close_all_modals()
		await frames(2)
	AppSettings.reduce_motion = false
	var animated := UIManager.show_modal(UIKit.label("Animated modal", "", true), true)
	await get_tree().create_timer(0.35).timeout
	var animated_panel: PanelContainer = animated.find_children("*", "PanelContainer", true, false)[0]
	check(animated_panel.get_global_rect().end.y <= get_viewport().get_visible_rect().size.y + 1, "animated modal settles inside the viewport")
	UIManager.close_all_modals()
	await frames(2)
	UIManager.push("load")
	await frames()
	var recoverable: Control = UIManager.current().call("_slot_card", 1, {}, true)
	check(recoverable.find_children("*", "Button", true, false).any(func(b): return b.text == I18n.t("CARREGAR")), "save without metadata still has a load button")
	recoverable.free()
	UIManager.pop_to_root()
	AppSettings.reduce_motion = true
	var screen_before := UIManager.current()
	GameManager.run_work(func(): OS.delay_msec(80))
	UIManager.push("settings")
	check(UIManager.current() == screen_before, "navigation blocked while worker owns world")
	while GameManager.is_busy():
		await frames(1)
	await frames()
	# Closing a confirmation immediately before quitting exercises deferred
	# layout callbacks and nested button callbacks during native teardown.
	UIManager.confirm("Apagar o espaço 2?", "Isso apaga a carreira para sempre.", "Apagar", func(): pass)
	await get_tree().create_timer(0.35).timeout
	UIManager.close_all_modals()
	print("UI_LOCALE_RESULT failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
