extends Node
## Lógica do social_shots.gd (carregada depois que os autoloads existem).

var out_dir := "/tmp/social"


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


func _run() -> void:
	await _frames(2)
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
	var club := w.user_club()
	# Uniforme do ano passado no histórico (para a torcida comparar).
	var real_year := w.year
	w.year = real_year - 1
	KitDesign.record(w, club)
	w.year = real_year
	UIManager.goto("hub")
	await _frames(10)
	UIManager.close_all_modals()
	UIManager.push("kit", {"launch": true})
	await _frames(8)
	var col := KitDesign.collection(club, w.year, 0)
	_scr().call("_apply_collection", club, col)
	_scr().call("_finish")
	await _frames(10)
	await _shot("s01_apresentacao_uniformes")
	var sc: ScrollContainer = null
	for n in get_tree().root.find_children("*", "ScrollContainer", true, false):
		if n.is_visible_in_tree() and n.custom_minimum_size.y == 560:
			sc = n
	if sc != null:
		sc.scroll_vertical = 100000
	await _shot("s02_apresentacao_aprovacao")
	UIManager.close_all_modals()
	PreseasonManager.play_friendlies(GameManager.world)
	for i in 8:
		if GameManager.season_over():
			break
		GameManager.play_instant()
	PressRoom.add_quote(w, "title", "Esse grupo vai brigar lá em cima, pode escrever.", int(People.journalists(w)[0]["id"]))
	var f: Dictionary = People.data(w)["fans"]
	var chants: Array = f.get("chants", [])
	chants.append({"t": "\"Vamos, %s!\"" % club.short_name, "turn": w.current_turn()})
	f["chants"] = chants
	UIManager.goto("hub")
	UIManager.close_all_modals()
	await _frames(8)
	_scr().scroll().scroll_vertical = 100000
	await _frames(4)
	var social_y := 0.0
	for n in _scr().content().get_children():
		for l in n.find_children("*", "Label", true, false):
			if (l as Label).text.to_lower() == "feed das redes":
				social_y = n.position.y
	_scr().scroll().scroll_vertical = int(social_y)
	await _shot("s03_hub_nas_redes")
	UIManager.push("social")
	await _frames(8)
	await _shot("s04_redes_para_voce")
	_scr().scroll().scroll_vertical = 1400
	await _shot("s05_redes_rolado")
	for fk in ["mine", "kits", "press", "fans"]:
		_scr().set("_filter", fk)
		_scr().refresh()
		_scr().scroll().scroll_vertical = 0
		await _shot("s06_redes_" + fk)
	_scr().set("_filter", "kits")
	_scr().refresh()
	_scr().scroll().scroll_vertical = 1100
	await _shot("s07_redes_kits_rivais")
	# Perfis: um gigante, um clube médio e um jogador.
	var big: Club = null
	for cc: Club in w.clubs_in_league("BRA1"):
		if big == null or cc.reputation > big.reputation:
			big = cc
	UIManager.push("social", {"club": big.id})
	await _frames(8)
	await _shot("s10_perfil_gigante")
	UIManager.push("social", {"club": club.id})
	await _frames(8)
	await _shot("s11_perfil_meu_clube")
	var star: Player = w.squad(big)[0]
	for pp: Player in w.squad(big):
		if pp.overall > star.overall:
			star = pp
	UIManager.push("social", {"player": star.id})
	await _frames(8)
	await _shot("s12_perfil_jogador")
	UIManager.push("club", {"id": big.id})
	await _frames(8)
	_scr().scroll().scroll_vertical = 700
	await _shot("s13_clube_card_redes")
	for cc2: Club in [big, club]:
		print("SEG ", cc2.short_name, " ", SocialFeed.followers(cc2, w))
	for lid in ["BRA1", "BRA3", "ENG1", "ESP1"]:
		for cc3: Club in w.clubs_in_league(lid):
			print("SEG ", lid, " ", cc3.short_name, " ", SocialFeed.count(SocialFeed.followers(cc3, w)))
	UIManager.goto("hub")
	TalkDialog.open("press")
	await _frames(10)
	await _shot("s08_coletiva")
	await _frames(40)
	await _shot("s09_coletiva_flash")
	get_tree().quit()
