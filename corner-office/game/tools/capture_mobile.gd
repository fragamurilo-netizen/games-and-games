extends SceneTree
## Reproducible native mobile screenshots; never reads/writes the player's save.
## godot --path game -s res://tools/capture_mobile.gd -- output-dir
func _initialize() -> void:call_deferred("_capture")
func _capture() -> void:
	var game:=root.get_node("Game")
	game.new_game(2027)
	# Carregado em tempo de execução: depende de autoloads (EventBus).
	var career=load("res://tools/capture_career.gd")
	var played: String=career.play_one_night(game.world)
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
	# Perfil de um atleta que já lutou e o matchmaker com tale of the tape.
	root.size=Vector2i(720,1280);root.content_scale_size=Vector2i(720,1280)
	if played!="":
		scene._navigate("fighters",{"fighter_id":played})
		await _shot(output+"/fighter-profile-720x1280.png")
	var next: Dictionary=career.create_event(game.world,"Segunda Noite")
	scene._navigate("events",{"event_id":next.event_id})
	var scroll: ScrollContainer=scene._screens["events"].get_child(0)
	await _shot("")
	scroll.scroll_vertical=int(scroll.get_v_scroll_bar().max_value)
	await _shot(output+"/matchmaker-720x1280.png")
	var menu: Control=load("res://ui/game_menu.gd").new();menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(menu)
	for view in [Vector2i(720,1280),Vector2i(1280,720)]:
		root.size=view;root.content_scale_size=view
		for i in 3:await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output+"/main-menu-%dx%d.png"%[view.x,view.y])
	print("NATIVE CAPTURES "+output);quit()

func _shot(path: String) -> void:
	for i in 3:await process_frame
	await RenderingServer.frame_post_draw
	if path!="":root.get_texture().get_image().save_png(path)

