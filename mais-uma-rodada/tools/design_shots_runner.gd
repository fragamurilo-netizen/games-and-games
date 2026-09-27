extends Node
## Capturas rápidas das telas principais, nos modos escuro e claro, para revisar o visual.
## xvfb-run godot --path . --resolution 720x1280 --script res://tools/design_shots.gd -- --out=DIR

var out_dir := ""
var shots := false
var lang := ""
## --tablet: simula um tablet (escala menor da interface); --prefix=: só as telas principais,
## no modo escuro, com esse prefixo no nome (capturas de paisagem e tablet).
var tablet := false
var prefix := ""
## --only=rota,rota:aba,...: só essas telas (depois de --rounds=N rodadas jogadas), modo escuro.
var only := ""
var rounds := 3


func _ready() -> void:
	_run()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	await _frames(4)
	var t := Time.get_ticks_msec() + 350
	while Time.get_ticks_msec() < t:
		await get_tree().process_frame
	print("[tela] ", shot_name)
	if not shots:
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, shot_name])


func _screen() -> BaseScreen:
	return UIManager.current()


func _scroll(px: int) -> void:
	var s := _screen().scroll()
	if s != null:
		s.scroll_vertical = px


func _run() -> void:
	await _frames(2)
	if lang != "":
		I18n.apply(lang)
	UILayout.force_tablet = tablet
	get_tree().root.content_scale_factor = UILayout.device_scale()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await _frames(10)
	if only != "":
		await _only_pass()
		get_tree().quit()
		return
	await _shot(prefix + "01_menu")
	UIManager.push("new_career")
	await _frames(8)
	await _shot(prefix + "02_nova_carreira_1")
	var nc := _screen()
	nc.set("_step", 1)
	nc.call("_build")
	await _shot(prefix + "02_nova_carreira_2")
	var until := Time.get_ticks_msec() + 30000
	while nc.get("_world") == null and Time.get_ticks_msec() < until:
		await get_tree().process_frame
	nc.set("_step", 2)
	nc.call("_build")
	await _frames(4)
	var nw: GameWorld = nc.get("_world")
	if nw != null:
		nc.set("_selected", nw.clubs_in_league("BRA1")[3].id)
		nc.call("_build")
	await _shot(prefix + "02_nova_carreira_3")
	UIManager.back()
	await _frames(4)
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	var club_id := -1
	for c: Club in w.clubs_in_league("BRA1"):
		if c.archetype == "tradicional_decadente" or club_id < 0:
			club_id = c.id
	AppSettings.tutorial_done = true
	GameManager.start_career(w, club_id, "Murilo", GameWorld.DIFF_NORMAL, 5)
	GameManager.save_now()
	UIManager.goto("welcome")
	await _frames(8)
	await _shot(prefix + "03_boas_vindas")
	UIManager.push("load")
	await _frames(8)
	await _shot(prefix + "03b_carregar")
	UIManager.goto("settings")
	await _frames(8)
	await _shot(prefix + "03c_opcoes")
	if prefix != "":
		await _wide_pass(w)
		get_tree().quit()
		return
	for mode in ["claro", "escuro"]:
		AppSettings.theme_mode = AppSettings.THEME_LIGHT if mode == "claro" else AppSettings.THEME_DARK
		UIManager.apply_look()
		await _pass(w, mode)
	get_tree().quit()


func _pass(w: GameWorld, m: String) -> void:
	UIManager.goto("hub")
	await _frames(8)
	UIManager.close_all_modals()
	await _shot(m + "_04_hub")
	_scroll(1100)
	await _shot(m + "_04b_hub_rolado")
	UIManager.goto("squad")
	await _frames(8)
	await _shot(m + "_05_elenco")
	var star: Player = null
	for p in w.squad(w.user_club()):
		if star == null or p.ovr_f > star.ovr_f:
			star = p
	UIManager.push("player", {"id": star.id})
	await _frames(8)
	await _shot(m + "_06_perfil")
	_scroll(900)
	await _shot(m + "_06b_perfil_rolado")
	UIManager.goto("club")
	await _frames(8)
	await _shot(m + "_19_clube")
	_scroll(1000)
	await _shot(m + "_19b_clube_rolado")
	UIManager.goto("table")
	await _frames(8)
	await _shot(m + "_14_tabela")
	UIManager.goto("market")
	await _frames(8)
	await _shot(m + "_17_mercado")
	if m == "escuro":
		UIManager.goto("hub")
		UIManager.push("prematch")
		await _frames(8)
		await _shot(m + "_07_pre_jogo")
		GameManager.begin_match()
		UIManager.replace("match")
		await _frames(12)
		var ms := _screen()
		UIManager.close_all_modals()
		ms.call("_drain", false)
		ms.set("_pace", 2)
		var t := Time.get_ticks_msec() + 2500
		while Time.get_ticks_msec() < t:
			await get_tree().process_frame
		await _shot(m + "_08_partida")


func _wide_pass(w: GameWorld) -> void:
	UIManager.goto("hub")
	await _frames(10)
	UIManager.close_all_modals()
	await _shot(prefix + "04_hub")
	UIManager.goto("squad")
	await _frames(8)
	await _shot(prefix + "05_elenco")
	var star: Player = null
	for p in w.squad(w.user_club()):
		if star == null or p.ovr_f > star.ovr_f:
			star = p
	UIManager.push("player", {"id": star.id})
	await _frames(8)
	await _shot(prefix + "06_perfil")
	UIManager.goto("club")
	await _frames(8)
	await _shot(prefix + "19_clube")
	UIManager.goto("table")
	await _frames(8)
	await _shot(prefix + "14_tabela")
	UIManager.goto("market")
	await _frames(8)
	await _shot(prefix + "17_mercado")
	UIManager.goto("hub")
	UIManager.push("prematch")
	await _frames(8)
	await _shot(prefix + "07_pre_jogo")
	GameManager.begin_match()
	UIManager.replace("match")
	await _frames(12)
	var ms := _screen()
	UIManager.close_all_modals()
	ms.call("_drain", false)
	ms.set("_pace", 2)
	var t := Time.get_ticks_msec() + 2500
	while Time.get_ticks_msec() < t:
		await get_tree().process_frame
	await _shot(prefix + "08_partida")


func _only_pass() -> void:
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	var club_id := -1
	for c: Club in w.clubs_in_league("BRA1"):
		if c.archetype == "tradicional_decadente" or club_id < 0:
			club_id = c.id
	AppSettings.tutorial_done = true
	GameManager.start_career(w, club_id, "Murilo", GameWorld.DIFF_NORMAL, 5)
	for i in rounds:
		GameManager.play_instant()
		await _frames(2)
	UIManager.goto("hub")
	await _frames(6)
	UIManager.close_all_modals()
	for spec in only.split(","):
		var parts := spec.split(":")
		var route := parts[0]
		var args := {}
		if parts.size() > 1:
			args["tab"] = parts[1]
		if route == "player":
			var star: Player = null
			for p in w.squad(w.user_club()):
				if star == null or p.ovr_f > star.ovr_f:
					star = p
			args["id"] = star.id
		if route == "coach":
			var u2 := w.user_club()
			for oc: Club in w.clubs_in_league(u2.league_id):
				if oc.id != u2.id:
					args = {"club": oc.id}
					break
		if route == "compare":
			var sq := w.squad(w.user_club())
			sq.sort_custom(func(a, b): return a.overall > b.overall)
			args = {"a": sq[0].id, "b": sq[1].id}
		if route == "rivalry":
			var u := w.user_club()
			args = {"a": u.id, "b": int(u.rivals[0]) if not u.rivals.is_empty() else w.clubs_in_league(u.league_id)[0].id}
		if route in UIManager.TABS:
			UIManager.goto(route, args)
		else:
			UIManager.goto("hub")
			await _frames(2)
			UIManager.push(route, args)
		await _frames(8)
		UIManager.close_all_modals()
		var shot_name := prefix + spec.replace(":", "_")
		await _shot(shot_name)
		var sc := _screen().scroll()
		if sc != null and sc.get_v_scroll_bar().max_value > sc.size.y + 200:
			sc.scroll_vertical = int(sc.size.y * 0.85)
			await _shot(shot_name + "_b")
