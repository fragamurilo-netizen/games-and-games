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
	await process_frame
	await process_frame
	await process_frame
	var current := UIManager.current()
	if current == null:
		push_error("SMOKE_BOOT: UIManager has no current screen")
		quit(12)
		return
	if String(current.screen_name) != "menu":
		push_error("SMOKE_BOOT: expected menu, got %s" % current.screen_name)
		quit(13)
		return
	var content := current.get_node_or_null("Body/Scroll/Margin/Content")
	if content == null:
		push_error("SMOKE_BOOT: menu content node is missing")
		quit(14)
		return
	if content.get_child_count() < 5:
		push_error("SMOKE_BOOT: menu rendered too few items (%d)" % content.get_child_count())
		quit(15)
		return
	print("SMOKE_BOOT_OK screen=menu items=", content.get_child_count())
	quit(0)
