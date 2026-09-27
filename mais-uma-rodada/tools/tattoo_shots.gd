extends SceneTree
## Grade de retratos com cada tatuagem (1..12) para conferir o desenho.
## Uso: xvfb-run godot --path . --resolution 1000x800 --script res://tools/tattoo_shots.gd -- --out=/pasta


func _initialize() -> void:
	process_frame.connect(_go, CONNECT_ONE_SHOT)


func _go() -> void:
	var out := "user://"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	var bg := ColorRect.new()
	bg.color = Color("#15171B")
	bg.size = Vector2(1000, 800)
	root.add_child(bg)
	var grid := GridContainer.new()
	grid.columns = 4
	root.add_child(grid)
	var ps: Array = w.players.values().slice(100, 112)
	for k in 12:
		var p: Player = ps[k]
		p.look = {"tt": k + 1}
		var v := VBoxContainer.new()
		v.add_child(UIKit.portrait(p, w.club(p.club_id), w.year, 230))
		var l := Label.new()
		l.text = FaceGen.TATTOOS[k + 1]
		v.add_child(l)
		grid.add_child(v)
	for i in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.path_join("tattoos.png"))
	quit()
