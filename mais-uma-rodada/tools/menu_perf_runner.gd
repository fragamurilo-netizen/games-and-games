extends Node
## Ver menu_perf.gd.

const ROUTES := ["hub", "squad", "tactics", "market", "club", "table", "news", "inbox", "history",
	"academy", "league_stats", "team_stats", "settings", "training", "national", "contracts"]


func _ms(t0: int) -> float:
	return (Time.get_ticks_usec() - t0) / 1000.0


func _ready() -> void:
	_run()


## Tempo até a tela estar pronta: a chamada mais os quadros seguintes (layout, desenho).
func _settle(t: int) -> Array:
	var call := _ms(t)
	for i in 3:
		await get_tree().process_frame
	var guard := 0
	while (GameManager.is_busy() or GameManager.in_batch()) and guard < 3000:
		guard += 1
		await get_tree().process_frame
	for i in 2:
		await get_tree().process_frame
	return [call, _ms(t)]


func _refresh_ms(n: int) -> float:
	var cur := UIManager.current()
	var tot := 0.0
	for i in n:
		var t := Time.get_ticks_usec()
		cur.refresh()
		tot += _ms(t)
		await get_tree().process_frame
	return tot / n


func _run() -> void:
	await get_tree().process_frame
	get_tree().root.add_child(load("res://scenes/main.tscn").instantiate())
	await get_tree().process_frame
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	AppSettings.tutorial_done = true
	GameManager.start_career(w, w.clubs_in_league("BRA1")[2].id, "Teste", GameWorld.DIFF_NORMAL, 9)
	GameManager.slot = -1
	for i in 3:
		GameManager.play_instant()
	var t := Time.get_ticks_usec()
	UIManager.goto("menu")
	var r: Array = await _settle(t)
	print("menu principal       chamada %6.0f  pronto %6.0f" % r)
	for pass_name in ["frio", "quente"]:
		for route in ROUTES:
			if not UIManager.SCREENS.has(route):
				continue
			t = Time.get_ticks_usec()
			if route in UIManager.TABS:
				UIManager.goto(route)
			else:
				UIManager.push(route)
			r = await _settle(t)
			var cur := UIManager.current()
			print("%-6s %-14s chamada %6.0f  pronto %6.0f  (%s, ocupado=%s)" % [pass_name, route, r[0], r[1], cur.screen_name if cur else "-", GameManager.is_busy()])
	# Reconstrução pura de cada aba (o que acontece ao voltar a ela).
	for route in UIManager.TABS:
		UIManager.goto(route)
		await _settle(Time.get_ticks_usec())
		print("refresh %-14s %6.1f ms" % [route, await _refresh_ms(5)])
	# Trocar de aba e voltar com "voltar".
	UIManager.goto("hub")
	await _settle(Time.get_ticks_usec())
	for route in ["squad", "market", "club", "tactics", "hub"]:
		t = Time.get_ticks_usec()
		UIManager.switch_area(route)
		r = await _settle(t)
		print("aba -> %-10s chamada %6.0f  pronto %6.0f" % [route, r[0], r[1]])
	var star: Player = w.squad(w.user_club())[0]
	UIManager.switch_area("squad")
	await _settle(Time.get_ticks_usec())
	t = Time.get_ticks_usec()
	UIManager.push("player", {"id": star.id})
	var fr: Array = []
	var tf := Time.get_ticks_usec()
	for i in 12:
		await get_tree().process_frame
		fr.append("%.0f" % _ms(tf))
		tf = Time.get_ticks_usec()
	print("quadros do jogador: ", ", ".join(PackedStringArray(fr)))
	r = await _settle(t)
	print("abrir jogador        chamada %6.0f  pronto %6.0f" % r)
	t = Time.get_ticks_usec()
	UIManager.back()
	r = await _settle(t)
	print("voltar ao elenco     chamada %6.0f  pronto %6.0f" % r)
	get_tree().quit()
