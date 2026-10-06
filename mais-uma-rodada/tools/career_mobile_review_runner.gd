extends "res://tools/mobile_match_review_runner.gd"

func _labels(root_node: Node, phrase: String) -> Array:
	var found: Array = []
	if root_node is Label and root_node.text.contains(phrase):
		found.append(root_node)
	for child in root_node.get_children():
		found.append_array(_labels(child, phrase))
	return found

func _button(root_node: Node, phrase: String) -> Button:
	if root_node is Button and root_node.text == phrase:
		return root_node
	for child in root_node.get_children():
		var found := _button(child, phrase)
		if found != null: return found
	return null

func _run() -> void:
	_check(OS.get_user_data_dir().contains("QA"), "isolated user data")
	if failures > 0:
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await _frames()
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	AppSettings.tutorial_done = true
	GameManager.start_career(w, w.clubs_in_league("ENG1")[0].id, "QA", GameWorld.DIFF_NORMAL, 97)
	var player: Player = w.squad(w.user_club())[0]
	player.known_as = "Alexandre Maximiliano"
	# Keep real generated nationality and birthplace; stress only the display name.
	var other: Club = w.clubs_in_league("ENG1")[1]
	var sample := Fixture.new()
	sample.home = w.user_club_id; sample.away = other.id; sample.hg = 2; sample.ag = 1
	sample.comp = "ENG1"; sample.played = true
	FootballMemory.on_match(w, sample)
	AppSettings.currency = AppSettings.CURRENCY_EUR
	for dimensions in SIZES:
		await _resize(dimensions)
		UIManager.goto("hub")
		await _frames()
		main.top_bar.menu_btn.pressed.emit()
		await _frames()
		_check(not _labels(main.modal_host, "Confrontos").is_empty(), "menu contents reachable " + str(dimensions))
		await _shot("menu")
		UIManager.close_all_modals()
		for tab in ["geral", "atributos", "origem", "contrato", "carreira"]:
			UIManager.push("player", {"id":player.id, "tab":tab})
			await _frames()
			_check(UIManager.current().content().size.x <= get_viewport().get_visible_rect().size.x + 1, "player width " + tab)
			await _shot("player-" + tab)
			UIManager.back()
		Negotiation.open(w, player, "sell", func(): pass)
		await _frames()
		var n := Negotiation.last
		var field: MoneyInput = n.get("_money")
		field.edit.text = "1234567"
		field.edit.text_changed.emit(field.edit.text)
		_check(n.fee == 1234567, "typed transfer amount reaches proposal")
		await _shot("negotiation")
		var sell := _button(n.box, "Anunciar jogador")
		_check(sell != null, "sell action")
		sell.pressed.emit()
		_check(player.asking_price == 1234567, "submission uses typed amount")
		UIManager.close_all_modals()
		Negotiation.open(w, player, "renew", func(): pass)
		await _frames()
		n = Negotiation.last
		field = n.get("_money")
		field.edit.text = "9999"
		field.edit.text_changed.emit(field.edit.text)
		_check(n.wage == 9999, "typed wage reaches contract")
		field.edit.text = "-1"
		field.edit.text_changed.emit(field.edit.text)
		_check(not n.call("_valid_amount"), "negative wage rejected before submission")
		field.set_amount(9999)
		await _shot("contract-offer")
		UIManager.close_all_modals()
		UIManager.push("rivalry", {"a":w.user_club_id})
		await _shot("opponents")
		UIManager.push("rivalry", {"a":w.user_club_id,"b":other.id})
		await _shot("head-to-head")
		for id in ["UEL", "UECL"]:
			UIManager.goto("table", {"cup":id,"tab":"rounds"})
			await _shot("games-" + id)
		UIManager.push("national", {"tab":"tours", "tour":"UNL"})
		await _shot("nations-league")
	# Broadcasts use real fixture/club data, each retaining the same match controls.
	GameManager.begin_match()
	var original_comp := GameManager.user_fixture().comp
	for comp in ["ENG1", "BRA1", "GER1", "ITA1", "ESP1", "FRA1", "UCL", "UEL", "UECL"]:
		GameManager.user_fixture().comp = comp
		UIManager.replace("match")
		await _frames()
		var screen := UIManager.current()
		screen.set("_paused", true)
		UIManager.close_all_modals()
		for dimensions in [SIZES[0], SIZES[1]]:
			await _resize(dimensions)
			await _shot("match-" + comp)
			var control: Control = screen.get("_controls_panel")
			_check(control.get_global_rect().end.y <= get_viewport().get_visible_rect().size.y + 1, "broadcast controls " + comp + str(dimensions))
	GameManager.user_fixture().comp = original_comp
	GameManager.matchday = {}
	UIManager.goto("hub")
	GameManager.save_blocking()
	SaveManager.delete_slot(97)
	print("CAREER_MOBILE_REVIEW failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
