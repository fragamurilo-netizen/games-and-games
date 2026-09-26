extends Node
## Lógica do sponsor_shots.gd (carregada depois dos autoloads).

var opt_out := "/tmp/sponsors"
var opt_league := "ENG1"
var opt_pick := "0"


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
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [opt_out, shot_name])


func _run() -> void:
	await _frames(2)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await _frames(8)
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	var clubs := w.clubs_in_league(opt_league)
	var club: Club = clubs[clampi(int(opt_pick), 0, clubs.size() - 1)]
	AppSettings.tutorial_done = true
	GameManager.start_career(w, club.id, "Murilo", GameWorld.DIFF_NORMAL, 5)
	for b in BrandCatalog.for_club(w, club):
		print("  %s: %s (%s)" % [b["slot"], b["n"], b["s"]])
	UIManager.goto("hub")
	await _frames(6)
	UIManager.close_all_modals()
	UIManager.push("kit", {})
	await _frames(8)
	await _shot("%s_uniforme" % opt_league)
	var scr: BaseScreen = UIManager.current()
	scr.scroll().scroll_vertical = 100000
	await _shot("%s_patrocinios" % opt_league)
	get_tree().quit()
