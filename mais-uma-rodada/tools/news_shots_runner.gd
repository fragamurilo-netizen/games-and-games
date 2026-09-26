extends Node
## Lógica do news_shots.gd (carregada depois que os autoloads existem).
var out_dir := "/tmp/news"
var quick := false
func _ready() -> void:
	_run()
func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
func _wait(sec: float) -> void:
	var t := Time.get_ticks_msec() + int(sec * 1000)
	while Time.get_ticks_msec() < t:
		await get_tree().process_frame
func _shot(shot_name: String) -> void:
	await _frames(3)
	print("[tela] ", shot_name)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, shot_name])
func _scr() -> BaseScreen:
	return UIManager.current()
func _best(w: GameWorld, lid: String, min_rep: float) -> Player:
	var best: Player = null
	for c: Club in w.clubs_in_league(lid):
		if c.reputation < min_rep:
			continue
		for p: Player in w.squad(c):
			if best == null or p.overall > best.overall:
				best = p
	return best
func _run() -> void:
	await _frames(2)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await _frames(8)
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	var club_id := -1
	for c: Club in w.clubs_in_league("BRA1"):
		if club_id < 0 or c.reputation > w.club(club_id).reputation:
			club_id = c.id
	AppSettings.tutorial_done = true
	GameManager.start_career(w, club_id, "Calitos", GameWorld.DIFF_NORMAL, 5)
	UIManager.goto("hub")
	await _frames(10)
	UIManager.close_all_modals()
	var user := w.user_club()
	# Reforço de peso: o melhor jogador de outro clube brasileiro.
	var star: Player = null
	for c: Club in w.clubs_in_league("BRA1"):
		if c.id == user.id:
			continue
		for p: Player in w.squad(c):
			if star == null or p.overall > star.overall:
				star = p
	TransferManager.complete_transfer(w, star, user, 18_000_000, star.wage * 2, 4)
	print("pendentes: ", w.pending_signings.size())
	SigningCeremony.play_pending(w)
	await _wait(0.9)
	await _shot("c01_escudo")
	await _wait(1.6)
	await _shot("c02_foto")
	await _wait(1.9)
	await _shot("c03_ficha")
	if quick:
		get_tree().quit()
		return
	UIManager.close_all_modals()
	var cer := get_tree().root.get_node_or_null("SigningCeremony")
	if cer != null:
		cer.get_child(0).call("_end")
	await _frames(4)
	# Reforço comum (não anima; vira notícia com a foto).
	var sq := w.squad(user)
	var minor: Player = null
	for c: Club in w.clubs_in_league("BRA2"):
		for p: Player in w.squad(c):
			if minor == null or p.overall > minor.overall:
				minor = p
	TransferManager.complete_transfer(w, minor, user, 1_200_000, minor.wage, 3)
	w.pending_signings.clear()
	# Mercado internacional.
	for pair in [["ENG1", "ESP1"], ["ITA1", "ENG1"], ["GER1", "FRA1"]]:
		var p2 := _best(w, pair[0], 70.0)
		var to: Club = null
		for c: Club in w.clubs_in_league(pair[1]):
			if to == null or c.reputation > to.reputation:
				to = c
		if p2 != null and to != null:
			TransferManager.complete_transfer(w, p2, to, 85_000_000, p2.wage, 5)
	for i in 34:
		if GameManager.season_over():
			break
		GameManager.play_instant()
	UIManager.goto("hub")
	UIManager.close_all_modals()
	var c2 := get_tree().root.get_node_or_null("SigningCeremony")
	if c2 != null:
		c2.get_child(0).call("_end")
	await _frames(6)
	await _wait(0.6)
	await _shot("a00_aviso_conquista")
	await _wait(8.0)
	UIManager.push("achievements")
	await _frames(8)
	await _shot("a01_conquistas")
	_scr().scroll().scroll_vertical = 1200
	await _shot("a02_conquistas_rolado")
	UIManager.back()
	await _frames(6)
	var news_y := 0.0
	for n in _scr().content().get_children():
		for l in n.find_children("*", "Label", true, false):
			if (l as Label).text.to_lower() == "notícias":
				news_y = n.position.y
	_scr().scroll().scroll_vertical = int(news_y)
	await _shot("n00_hub")
	UIManager.push("news")
	await _frames(10)
	await _wait(0.5)
	await _shot("n01_destaques")
	_scr().scroll().scroll_vertical = 900
	await _shot("n02_destaques_rolado")
	_scr().scroll().scroll_vertical = 2200
	await _shot("n03_destaques_rolado2")
	for fk in ["market", "world", "nat", "mine"]:
		_scr().set("_filter", fk)
		_scr().refresh()
		_scr().scroll().scroll_vertical = 0
		await _frames(6)
		await _shot("n_" + fk)
		_scr().scroll().scroll_vertical = 1000
		await _shot("n_" + fk + "_rolado")
	var cats := {}
	for n: NewsEvent in w.news:
		cats[n.category + ":" + String(n.media.get("type", "-"))] = int(cats.get(n.category + ":" + String(n.media.get("type", "-")), 0)) + 1
	print(cats)
	get_tree().quit()
