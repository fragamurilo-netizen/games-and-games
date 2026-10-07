extends Node
## Ver perf_deep.gd.

var days := 12
var season := false
var screens := false


func _ready() -> void:
	_run()


func _ms(t0: int) -> float:
	return (Time.get_ticks_usec() - t0) / 1000.0


func _top(d: Dictionary, n: int, label: String) -> void:
	var keys := d.keys()
	keys.sort_custom(func(a, b): return int(d[a]) > int(d[b]))
	var parts: Array = []
	for k in keys.slice(0, n):
		parts.append("%s %.0f" % [k, int(d[k]) / 1000.0])
	print("  %s: %s" % [label, ", ".join(PackedStringArray(parts))])


func _run() -> void:
	await get_tree().process_frame
	get_tree().root.add_child(load("res://scenes/main.tscn").instantiate())
	await get_tree().process_frame
	var t := Time.get_ticks_usec()
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	print("gerar mundo: %.0f ms (%d clubes, %d jogadores)" % [_ms(t), w.clubs.size(), w.players.size()])
	AppSettings.tutorial_done = true
	t = Time.get_ticks_usec()
	GameManager.start_career(w, w.clubs_in_league("BRA1")[2].id, "Teste", GameWorld.DIFF_NORMAL, 9)
	print("começar carreira: %.0f ms" % _ms(t))
	GameManager.slot = -1
	SeasonManager.timings.clear()
	var tot := 0.0
	for i in days:
		if GameManager.season_over():
			break
		t = Time.get_ticks_usec()
		GameManager.play_instant()
		var ms := _ms(t)
		tot += ms
		print("data %2d (jogo do usuário + até o próximo): %.0f ms" % [i + 1, ms])
	print("média por data: %.0f ms" % (tot / maxf(1.0, days)))
	_top(SeasonManager.timings, 12, "etapas (ms)")
	if season:
		var guard := 0
		t = Time.get_ticks_usec()
		while not GameManager.season_over() and guard < 400:
			GameManager.play_instant()
			guard += 1
		print("resto da temporada: %.0f ms (%d datas)" % [_ms(t), guard])
		SeasonManager.timings.clear()
		t = Time.get_ticks_usec()
		SeasonManager.end_season(w)
		print("fim de temporada: %.0f ms" % _ms(t))
		_top(SeasonManager.timings, 14, "fim de temporada (ms)")
	t = Time.get_ticks_usec()
	var d := w.to_dict()
	print("to_dict: %.0f ms" % _ms(t))
	d.clear()
	t = Time.get_ticks_usec()
	SaveManager.save_world(w, 9)
	print("salvar: %.0f ms (%d KB)" % [_ms(t), FileAccess.get_file_as_bytes(SaveManager.slot_path(9)).size() / 1024])
	t = Time.get_ticks_usec()
	var w2 := SaveManager.load_world(9)
	print("carregar: %.0f ms (%s)" % [_ms(t), "ok" if w2 != null else "falhou"])
	SaveManager.delete_slot(9)
	if screens:
		for route in ["hub", "squad", "tactics", "market", "club", "table", "news", "history", "academy", "inbox", "league_stats", "team_stats"]:
			t = Time.get_ticks_usec()
			UIManager.goto(route)
			await get_tree().process_frame
			var a := _ms(t)
			await get_tree().process_frame
			print("tela %-10s %.0f ms (+%.0f no quadro seguinte)" % [route, a, _ms(t) - a])
		var star: Player = w.squad(w.user_club())[0]
		t = Time.get_ticks_usec()
		UIManager.push("player", {"id": star.id})
		await get_tree().process_frame
		print("tela player     %.0f ms" % _ms(t))
	get_tree().quit()
