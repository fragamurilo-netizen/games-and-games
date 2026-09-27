extends Node
## Lógica do market_shots.gd (carregada depois que os autoloads existem).

var out_dir := "/tmp/mercado"
var tablet := false


func _ready() -> void:
	_run()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	await _frames(4)
	var t := Time.get_ticks_msec() + 450
	while Time.get_ticks_msec() < t:
		await get_tree().process_frame
	print("[tela] ", shot_name)
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, shot_name])


func _scr() -> BaseScreen:
	return UIManager.current()


func _market(tab: String, props: Dictionary = {}) -> void:
	UIManager.goto("market")
	await _frames(6)
	_scr().set("_tab", tab)
	for k in props:
		_scr().set(k, props[k])
	_scr().refresh()
	await _frames(6)


func _run() -> void:
	await _frames(2)
	UILayout.force_tablet = tablet
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await _frames(8)
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	var club_id := -1
	for c: Club in w.clubs_in_league("BRA1"):
		if club_id < 0 or c.archetype == "tradicional_decadente":
			club_id = c.id
	AppSettings.tutorial_done = true
	GameManager.start_career(w, club_id, "Murilo", GameWorld.DIFF_NORMAL, 5)
	UIManager.goto("hub")
	await _frames(10)
	UIManager.close_all_modals()
	PreseasonManager.play_friendlies(GameManager.world)
	for i in 3:
		if GameManager.season_over():
			break
		GameManager.play_instant()
	UIManager.close_all_modals()
	# Movimenta o mercado da IA para a aba de movimentações ter o que mostrar.
	for i in 3:
		MarketAI.matchday(w)
	var club := w.user_club()
	# Lista de observação: alguns nomes da liga, um deles depois posto à venda e mais barato.
	var picks: Array = []
	for p: Player in w.players.values():
		if p.club_id >= 0 and p.club_id != club.id and w.club(p.club_id).league_id == club.league_id and p.age(w.year) <= 27 and not p.retiring:
			picks.append(p)
	picks.sort_custom(func(a: Player, b: Player): return a.overall > b.overall)
	for p: Player in picks.slice(4, 9):
		Shortlist.toggle(w, p)
	if picks.size() > 6:
		var hot: Player = picks[5]
		hot.transfer_listed = true
		var late: Player = picks[6]
		late.contract_end = w.year
	await _market("search")
	await _shot("m01_busca")
	await _market("search", {"_listed_only": true, "_sort": "price"})
	await _shot("m02_busca_a_venda")
	await _market("search", {"_listed_only": false, "_query": "a", "_sort": "ovr"})
	await _market("shortlist")
	await _shot("m03_lista")
	await _market("moves", {"_query": ""})
	await _shot("m04_movimentacoes_liga")
	await _market("moves", {"_move_scope": "all", "_move_sort": "fee"})
	await _shot("m05_movimentacoes_maiores")
	if not picks.is_empty():
		UIManager.push("player", {"id": picks[5].id})
		await _frames(8)
		await _shot("m06_perfil_estrela")
	get_tree().quit()
