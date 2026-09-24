extends Control
## Raiz da interface: fundo, área segura (notch/barras do Android), barra superior,
## área das telas, navegação inferior e camadas de modais/toasts.

@onready var safe_area: MarginContainer = $SafeArea
@onready var top_bar: TopBar = $SafeArea/Layout/TopBar
@onready var screen_host: Control = $SafeArea/Layout/ScreenHost
@onready var bottom_nav: BottomNav = $SafeArea/Layout/BottomNav
@onready var modal_host: Control = $Overlay/ModalHost
@onready var toast_host: VBoxContainer = $Overlay/ToastBox/ToastHost

var _safe := Rect2()


func _ready() -> void:
	UIManager.register_main(self)
	add_child(TouchScroll.new())
	get_viewport().size_changed.connect(_update_safe_area)
	_update_safe_area()
	top_bar.back_pressed.connect(func(): UIManager.handle_back())
	bottom_nav.tab_selected.connect(_on_tab)
	GameManager.world_changed.connect(func(): UIManager.refresh_chrome())
	UIManager.goto("menu")


func _on_tab(tab: String) -> void:
	var cur := UIManager.current()
	if cur != null and cur.screen_name == tab:
		cur.scroll_to_top()
		return
	UIManager.goto(tab)


## Margens seguras (em coordenadas do viewport): position.y = topo, size.y = base.
func safe_margins() -> Rect2:
	return _safe


func _update_safe_area() -> void:
	var win_size := Vector2(DisplayServer.window_get_size())
	var vp_size := get_viewport_rect().size
	var top := 0.0
	var bottom := 0.0
	var left := 0.0
	var right := 0.0
	if OS.has_feature("mobile") and win_size.x > 0:
		var safe := Rect2(DisplayServer.get_display_safe_area())
		var k := vp_size.x / win_size.x
		top = safe.position.y * k
		left = safe.position.x * k
		bottom = maxf(0.0, (win_size.y - safe.end.y) * k)
		right = maxf(0.0, (win_size.x - safe.end.x) * k)
	_safe = Rect2(left, top, right, bottom)
	safe_area.add_theme_constant_override(&"margin_top", int(top))
	safe_area.add_theme_constant_override(&"margin_bottom", int(bottom))
	safe_area.add_theme_constant_override(&"margin_left", int(left))
	safe_area.add_theme_constant_override(&"margin_right", int(right))


func apply_chrome(screen: BaseScreen, can_go_back: bool) -> void:
	top_bar.visible = screen.show_top
	bottom_nav.visible = screen.show_nav and GameManager.has_career()
	if screen.show_top:
		var club: Club = GameManager.user_club() if GameManager.has_career() else null
		top_bar.set_state(screen.screen_title, screen.screen_subtitle, can_go_back, club)
	bottom_nav.select(screen.nav_tab)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		UIManager.handle_back()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		UIManager.handle_back()
		get_viewport().set_input_as_handled()
