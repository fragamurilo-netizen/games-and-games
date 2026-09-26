extends Node
## Lógica do screen_shots.gd: abre uma carreira e fotografa as telas pedidas (rolando até o fim).

var opt_out := ""
var opt_league := "BRA1"
var opt_days := "6"
var opt_screens := "squad,contracts"
var opt_scrolls := "0,900"
var opt_tab := ""
var opt_pick := "best" # best: o melhor do elenco · veteran: o mais velho (histórico longo)
var shots := false


func _ready() -> void:
	_run()


func _frames(k: int) -> void:
	for i in k:
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	print("[captura] ", shot_name)
	if not shots:
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [opt_out, shot_name])


func _run() -> void:
	await _frames(2)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await _frames(6)
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	for i in int(opt_days):
		SeasonManager.play_matchday_instant(w)
	var clubs := w.clubs_in_league(opt_league)
	clubs.sort_custom(func(a: Club, b: Club): return a.reputation > b.reputation)
	AppSettings.tutorial_done = true
	GameManager.start_career(w, clubs[0].id, "Teste", GameWorld.DIFF_NORMAL, 5)
	UIManager.goto("hub")
	await _frames(6)
	UIManager.close_all_modals()
	var best: Player = null
	for p: Player in w.squad(clubs[0]):
		if opt_pick == "veteran":
			if best == null or p.age(w.year) > best.age(w.year):
				best = p
		elif best == null or p.overall > best.overall:
			best = p
	for sc in opt_screens.split(","):
		var params := {}
		if sc == "player":
			params = {"id": best.id}
		UIManager.push(sc, params)
		await _frames(10)
		var cur: BaseScreen = UIManager.current()
		if opt_tab != "":
			cur.set("_tab", opt_tab)
			cur.refresh()
			await _frames(6)
		for sy in opt_scrolls.split(","):
			if cur.scroll() != null:
				cur.scroll().scroll_vertical = int(sy)
			await _frames(6)
			await _shot("%s_%s" % [sc, sy])
		UIManager.back()
		await _frames(4)
	get_tree().quit()
