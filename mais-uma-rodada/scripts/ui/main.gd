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
var _keyboard_up := false
var _shadow: TextureRect
var _fade: TextureRect


func _ready() -> void:
	UIManager.register_main(self)
	add_child(TouchScroll.new())
	_shadow = _edge(Color(0, 0, 0, 0.45), Color(0, 0, 0, 0))
	_fade = _edge(Color(UIColors.BG, 0.0), Color(UIColors.BG, 0.92))
	# Tocar na barra superior leva a tela de volta ao topo.
	top_bar.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			var cur := UIManager.current()
			if cur != null:
				cur.scroll_to_top())
	get_viewport().size_changed.connect(_update_safe_area)
	_update_safe_area()
	top_bar.back_pressed.connect(func(): UIManager.handle_back())
	bottom_nav.tab_selected.connect(_on_tab)
	GameManager.world_changed.connect(func(): UIManager.refresh_chrome())
	UIManager.goto("menu")


## Bordas da área rolável: uma sombra sob a barra superior quando o conteúdo rolou por
## baixo dela, e um esmaecido no pé quando ainda há conteúdo abaixo (sinal de que dá para
## descer).
func _edge(from: Color, to: Color) -> TextureRect:
	var g := Gradient.new()
	g.set_color(0, from)
	g.set_color(1, to)
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 4
	tex.height = 32
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.z_index = 5
	r.modulate.a = 0.0
	screen_host.add_child(r)
	return r


func _process(_delta: float) -> void:
	var cur := UIManager.current()
	_guard_layout(cur)
	var sc: ScrollContainer = cur.scroll() if cur != null else null
	var top := 0.0
	var bottom := 0.0
	if sc != null and sc.is_visible_in_tree():
		var area := Rect2(sc.get_global_rect().position - screen_host.global_position, sc.size)
		_shadow.position = area.position
		_shadow.size = Vector2(area.size.x, 18)
		_fade.position = Vector2(area.position.x, area.end.y - 56)
		_fade.size = Vector2(area.size.x, 56)
		var bar := sc.get_v_scroll_bar()
		top = 1.0 if top_bar.visible and sc.scroll_vertical > 4 else 0.0
		bottom = 1.0 if bar.max_value - bar.page - sc.scroll_vertical > 8 else 0.0
	_ease_alpha(_shadow, top)
	_ease_alpha(_fade, bottom)


## Proteção contra a "tela com zoom": nada pode ficar maior que o espaço que tem. A raiz volta
## ao tamanho da janela, a tela atual ao tamanho da área das telas (textos que empurravam a
## largura passam a cortar com "…") e, quando o teclado do celular fecha, tudo é recalculado.
func _guard_layout(cur: BaseScreen) -> void:
	var vp := get_viewport_rect().size
	if not size.is_equal_approx(vp) or not position.is_zero_approx():
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		safe_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		var up := DisplayServer.virtual_keyboard_get_height() > 0
		if _keyboard_up and not up:
			_relayout()
		_keyboard_up = up
	if cur == null or not cur.is_visible_in_tree():
		return
	var host_w := screen_host.size.x
	if host_w > 0.0 and cur.size.x > host_w + 0.5:
		UIKit.fit_width(cur, host_w)
		var px := cur.position.x
		cur.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cur.position.x = px
	if not cur.scale.is_equal_approx(Vector2.ONE):
		cur.scale = Vector2.ONE


func _relayout() -> void:
	_update_safe_area()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var cur := UIManager.current()
	if cur != null:
		cur.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _ease_alpha(r: TextureRect, want: float) -> void:
	if not is_equal_approx(r.modulate.a, want):
		r.modulate.a = move_toward(r.modulate.a, want, 0.15)


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
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_relayout.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		UIManager.handle_back()
		get_viewport().set_input_as_handled()
