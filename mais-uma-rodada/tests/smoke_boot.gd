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
	var host := main.get_node_or_null("SafeArea/Layout/ScreenHost")
	if host == null:
		push_error("SMOKE_BOOT: ScreenHost missing")
		quit(12)
		return
	if host.get_child_count() < 1:
		push_error("SMOKE_BOOT: no initial screen rendered")
		quit(13)
		return
	var first := host.get_child(0)
	print("SMOKE_BOOT_OK child=", first.name, " type=", first.get_class())
	quit(0)
