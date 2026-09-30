extends SceneTree
## Capturas da Enciclopédia do universo (portrait); nunca toca no save do jogador.
## godot --path game -s res://tools/capture_universe.gd -- pasta
func _initialize() -> void:call_deferred("_capture")
func _capture() -> void:
	root.get_node("Game").new_game(2027)
	var output:=OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "user://captures"
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(720,1280);root.content_scale_size=Vector2i(720,1280)
	var view=load("res://ui/universe_view.gd").open_over(self)
	var pages:=[["home",null],["org","org_crown"],["lineage",["org_crown","m_lightweight"]],["city","city_rio_de_janeiro"],["person","ftr_reed"],["fight","hf_01519"],["history",null],["country","BR"]]
	for p in pages:
		if p[0]!="home":view.screen.open(p[0],p[1])
		for i in 3:await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output+"/universe-%s.png"%p[0])
	print("UNIVERSE CAPTURES "+output);quit()
