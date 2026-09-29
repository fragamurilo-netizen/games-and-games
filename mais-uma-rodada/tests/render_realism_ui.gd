extends SceneTree
var out:="/mnt/data/dev/screens"
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	await process_frame
	var lang=load("res://scripts/core/i18n.gd")
	lang.apply("pt")
	var gm=root.get_node("GameManager")
	var ui=root.get_node("UIManager")
	var layout=load("res://scripts/ui/ui_layout.gd")
	var generator=load("res://scripts/generation/world_generator.gd")
	var w=generator.generate(19031911,"padrao")
	w.user_club_id=w.club_by_key("BRA_VPA").id
	w.manager_name="Teste Visual"
	var main=load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	gm.world=w
	OS.low_processor_usage_mode=false
	Engine.max_fps=30
	if OS.get_environment("REALISM_SHOTS")!="":out=OS.get_environment("REALISM_SHOTS")
	DirAccess.make_dir_recursive_absolute(out)
	for device in [{"id":"celular_paisagem","size":Vector2i(1280,720),"tablet":false},{"id":"tablet_paisagem","size":Vector2i(1600,1200),"tablet":true}]:
		layout.force_tablet=device["tablet"]
		root.size=device["size"]
		DisplayServer.window_set_size(device["size"])
		for i in 8:await process_frame
		for screen in ["numbers","club","player"]:
			var params:Dictionary={"id":w.user_club().player_ids[10],"tab":"numeros"} if screen=="player" else ({"tab":"manage"} if screen=="club" else {})
			ui.goto(screen,params)
			for i in 15:await process_frame
			await RenderingServer.frame_post_draw
			var image:Image=root.get_texture().get_image()
			image.save_png(out.path_join(device["id"]+"_"+screen+".png"))
			print("REALISM_UI_CAPTURE ",device["id"]," ",screen)
	ui.goto("menu");gm.world=null
	main.queue_free()
	for i in 4:await process_frame
	print("REALISM_UI_RENDER_OK")
	quit()
