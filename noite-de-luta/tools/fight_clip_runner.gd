extends Node
## Um trecho de luta para mostrar a animação, gravado com o Movie Maker (quadro a quadro).
## xvfb-run -a -s "-screen 0 1900x1900x24" godot --path . --write-movie DIR/luta.avi --fixed-fps 30 \
##   --script res://tools/design_shots.gd -- --runner=fight_clip_runner
## O log marca "[trecho] luta início fim" em quadros do vídeo.

var out_dir := "user://shots"
var prefix := ""


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	GameManager.delete_save()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await _frames(8)
	var w := Career.new_career("Equipe Nova Era", "", "BRA", "Recife", Color("#B3262E"), Color("#F1F0EC"), 250000.0, 2027)
	var y := w.year()
	var m := w.month()
	var pros: Array = w.fighters.values().filter(func(f: Fighter) -> bool: return f.team_id < 0 and f.stage(y, m) == "profissional")
	pros.sort_custom(func(a: Fighter, b: Fighter) -> bool: return a.level() > b.level())
	for f: Fighter in [pros[2], pros[5], pros[9]]:
		f.team_id = w.user_team_id
		f.contract = {"cut": 0.2, "fights": 5}
	GameManager.start_career(w)
	w.tut["on"] = false
	w.tut["skipped"] = true
	w.tut["tips_on"] = false
	w.pops.clear()
	var guard := 0
	while Career.pending_user_bouts(w).is_empty() and guard < 30:
		guard += 1
		if not w.offers.is_empty() and guard > 2:
			Matchmaker.accept_offer(w, w.offers[0])
		Career.advance_week(w)
	w.pops.clear()
	var b: Bout = Career.pending_user_bouts(w)[0]
	UIManager.goto("hub")
	UIManager.push("fight", {"bout": b.id})
	var fs := UIManager.current()
	fs.set("_speed", 0)
	AppSettings.fight_speed = 0
	fs.call("_controls")
	await _frames(6)
	var g := 0
	while Portraits.pending() > 0 and g < 1200:
		await get_tree().process_frame
		g += 1
	var f0 := Engine.get_frames_drawn()
	await _frames(330)
	if String(fs.get("_state")) == "round":
		fs.call("_shout", FightScreen.SHOUTS["pe"][0])
	await _frames(int(OS.get_environment("CLIP_FRAMES")) if OS.get_environment("CLIP_FRAMES") != "" else 600)
	print("[trecho] luta %d %d" % [f0, Engine.get_frames_drawn()])
	GameManager.delete_save()
	get_tree().quit()
