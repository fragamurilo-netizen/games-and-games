extends Node

var out_dir := "user://perfil"


func _ready() -> void:
	_run()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	await _frames(6)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, shot_name])
	print("[tela] ", shot_name)


func _run() -> void:
	await _frames(2)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await _frames(6)
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	var club_id: int = w.clubs_in_league("BRA1")[0].id
	AppSettings.tutorial_done = true
	GameManager.start_career(w, club_id, "Murilo", GameWorld.DIFF_NORMAL, 5)
	UIManager.goto("hub")
	await _frames(6)
	UIManager.close_all_modals()
	var squad: Array = w.squad(w.user_club())
	squad.sort_custom(func(a: Player, b: Player) -> bool: return a.ovr_f > b.ovr_f)
	# Um do próprio elenco e um de outro clube
	var other: Player = null
	for c: Club in w.clubs_in_league("BRA1"):
		if c.id != club_id:
			other = w.squad(c)[0]
			break
	for pair: Array in [[squad[0], "p1"], [squad[squad.size() - 1], "p2"], [other, "p3"]]:
		var p: Player = pair[0]
		UIManager.push("player", {"id": p.id})
		await _frames(8)
		await _shot(pair[1] + "_visao")
		var sc: ScrollContainer = UIManager.current().scroll()
		sc.scroll_vertical = 700
		await _shot(pair[1] + "_visao_meio")
		sc.scroll_vertical = 1600
		await _shot(pair[1] + "_visao_fim")
		if pair[1] == "p1":
			for tab: String in ["numeros", "carreira"]:
				UIManager.current().set("_tab", tab)
				UIManager.current().refresh()
				await _shot(pair[1] + "_" + tab)
		UIManager.back()
		await _frames(4)
	get_tree().quit()
