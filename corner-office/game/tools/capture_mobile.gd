extends SceneTree
## Reproducible native mobile screenshots; never reads/writes the player's save.
## godot --path game -s res://tools/capture_mobile.gd -- output-dir
func _initialize() -> void:call_deferred("_capture")
func _capture() -> void:
	var game:=root.get_node("Game")
	game.new_game(2027)
	var output:=OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "user://captures"
	DirAccess.make_dir_recursive_absolute(output)
	var scene: Control=load("res://ui/main.tscn").instantiate()
	root.add_child(scene)
	for child in scene.get_children():
		if child.get_script() and child.get_script().resource_path=="res://ui/game_menu.gd":child.queue_free()
	for view in [Vector2i(720,1280),Vector2i(1280,720)]:
		root.size=view;root.content_scale_size=view
		for screen in ["home","fighters","events","market","organization"]:
			scene.show_tab(screen)
			for i in 3:await process_frame
			await RenderingServer.frame_post_draw
			var path: String=output+"/%s-%dx%d.png"%[screen,view.x,view.y]
			root.get_texture().get_image().save_png(path)
	var menu: Control=load("res://ui/game_menu.gd").new();menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(menu)
	for view in [Vector2i(720,1280),Vector2i(1280,720)]:
		root.size=view;root.content_scale_size=view
		for i in 3:await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output+"/main-menu-%dx%d.png"%[view.x,view.y])
	print("NATIVE CAPTURES "+output);quit()
