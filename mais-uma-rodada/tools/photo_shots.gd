extends SceneTree
## Folha de conferência das fotos (PhotoPortrait): os seis cenários lado a lado para alguns
## jogadores, nos formatos quadrado, em pé e deitado.
## xvfb-run -a -s "-screen 0 1800x1400x24" godot --path . --resolution 1700x1300 --script res://tools/photo_shots.gd -- --out=/tmp/photos.png

var _out := "user://photos.png"
var _frames := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var bg := ColorRect.new()
	bg.color = Color("#15181B")
	bg.size = Vector2(4000, 4000)
	root.add_child(bg)
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	var club: Club = w.clubs_in_league("BRA1")[0]
	var squad: Array = w.squad(club)
	squad.sort_custom(func(a: Player, b: Player): return a.overall > b.overall)
	var picks: Array = [squad[0], squad[3], squad[7]]
	var other: Club = w.clubs_in_league("ENG1")[0]
	var sq2: Array = w.squad(other)
	sq2.sort_custom(func(a: Player, b: Player): return a.overall > b.overall)
	picks.append(sq2[1])
	var s := 230.0
	for r in picks.size():
		var p: Player = picks[r]
		var cl: Club = w.club(p.club_id)
		for m in 6:
			var ph := PhotoPortrait.new()
			ph.mood = m
			ph.position = Vector2(10 + m * (s + 10), 10 + r * (s + 10))
			ph.size = Vector2(s, s)
			root.add_child(ph)
			ph.set_player(p, cl, w.year)
	# Formatos: em pé e deitado
	var y0 := 10 + picks.size() * (s + 10)
	var tall := PhotoPortrait.new()
	tall.mood = PhotoPortrait.TUNNEL
	tall.position = Vector2(10, y0)
	tall.size = Vector2(180, 260)
	root.add_child(tall)
	tall.set_player(picks[0], club, w.year)
	var wide := PhotoPortrait.new()
	wide.mood = PhotoPortrait.PRESS
	wide.focus_x = 0.75
	wide.position = Vector2(200, y0)
	wide.size = Vector2(460, 260)
	root.add_child(wide)
	wide.set_player(picks[1], club, w.year)
	var coach := PhotoPortrait.new()
	coach.mood = PhotoPortrait.PRESS
	coach.position = Vector2(680, y0)
	coach.size = Vector2(260, 260)
	root.add_child(coach)
	coach.set_person(4242, 1, 51, club)
	var bust := PhotoPortrait.new()
	bust.mood = PhotoPortrait.FILM
	bust.bust = true
	bust.position = Vector2(960, y0)
	bust.size = Vector2(260, 260)
	root.add_child(bust)
	bust.set_player(picks[2], club, w.year)
	process_frame.connect(_tick)


func _tick() -> void:
	_frames += 1
	if _frames == 120:
		var img := root.get_texture().get_image()
		img.save_png(_out)
		print("ok ", _out)
		quit()
