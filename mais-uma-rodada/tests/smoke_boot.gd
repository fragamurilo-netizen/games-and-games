extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		push_error("SMOKE_BOOT: main.tscn could not be loaded")
		quit(10)
		return

	var main := packed.instantiate()
	if main == null:
		push_error("SMOKE_BOOT: main.tscn could not be instantiated")
		quit(11)
		return

	root.add_child(main)
	for _i in 8:
		await process_frame

	var menu := main.find_child("MainMenuScreen", true, false)
	if menu == null:
		push_error("SMOKE_BOOT: MainMenuScreen was not rendered")
		quit(12)
		return

	var content := menu.get_node_or_null("Body/Scroll/Margin/Content")
	if content == null:
		push_error("SMOKE_BOOT: menu content node is missing")
		quit(13)
		return

	if content.get_child_count() < 5:
		push_error("SMOKE_BOOT: menu rendered too few items (%d)" % content.get_child_count())
		quit(14)
		return

	print("SMOKE_BOOT_OK screen=MainMenuScreen items=", content.get_child_count())
	quit(0)
