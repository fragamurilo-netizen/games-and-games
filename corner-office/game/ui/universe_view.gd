class_name UniverseView
extends Control
## Camada de tela cheia com a Enciclopédia do universo (UniverseScreen).
## Abre por cima de qualquer tela; "voltar" do Android navega dentro dela.

var screen: UniverseScreen


static func open_over(tree: SceneTree, page: String = "home", arg: Variant = null) -> UniverseView:
	var view := UniverseView.new()
	view.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	tree.root.add_child(view)
	if page != "home":
		view.screen.open(page, arg)
		view.screen._stack.clear()
		view.screen._stack.append(["home", null])
	return view


func _init() -> void:
	theme = Tokens.build_theme()
	mouse_filter = MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Tokens.CANVAS
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(column)
	var bar := HBoxContainer.new()
	bar.custom_minimum_size.y = Tokens.TOUCH_MIN
	column.add_child(bar)
	var close := Button.new()
	close.text = "✕ FECHAR"
	close.flat = true
	close.custom_minimum_size = Vector2(Tokens.TOUCH_MIN * 2, Tokens.TOUCH_MIN)
	close.pressed.connect(queue_free)
	bar.add_child(close)
	screen = UniverseScreen.new()
	screen.size_flags_vertical = SIZE_EXPAND_FILL
	column.add_child(screen)


func _ready() -> void:
	var safe := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
	if safe.size.x > 0 and win.y > 0:
		var scale := get_viewport_rect().size.y / float(win.y)
		offset_top = safe.position.y * scale
	screen.refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_inside_tree():
		if not screen.back():
			queue_free()
