extends Control
## Raiz da interface: área segura, navegação e relayout coalescido fora do sinal de resize.

@onready var safe_area: MarginContainer = $SafeArea
@onready var top_bar: TopBar = $SafeArea/Layout/TopBar
@onready var middle: HBoxContainer = $SafeArea/Layout/Middle
@onready var screen_host: Control = $SafeArea/Layout/Middle/ScreenHost
@onready var bottom_nav: BottomNav = $SafeArea/Layout/BottomNav
@onready var modal_host: Control = $Overlay/ModalHost
@onready var toast_host: VBoxContainer = $Overlay/ToastBox/ToastHost

var _safe := Rect2()
var _keyboard_up := false
var _shadow: TextureRect
var _fade: TextureRect
var _size_class := -1
var _live := false
var _lp_wanted := true
var _layout_pending := false
var _refresh_pending := false
var _last_landscape := false
var _guard_elapsed := 0.0
var _wake_pending := false
var _wake_timer: Timer
const GUARD_INTERVAL := 0.15
const MOBILE_PORTRAIT_LAYERS := 240


func _ready() -> void:
	UIManager.register_main(self)
	_lp_wanted = OS.low_processor_usage_mode
	if OS.has_feature("mobile"):
		Engine.max_fps = 60
	UIColors.set_light(AppSettings.wants_light())
	_configure_window()
	UILayout.viewport = get_viewport_rect().size
	$Background.color = UIColors.BG
	add_child(TouchScroll.new())
	_shadow = _edge(Color(0, 0, 0, 0.45), Color(0, 0, 0, 0))
	_fade = _edge(Color(UIColors.BG, 0.0), Color(UIColors.BG, 0.92))
	_wake_timer = Timer.new()
	_wake_timer.one_shot = true
	_wake_timer.wait_time = 1.5
	_wake_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_wake_timer)
	_wake_timer.timeout.connect(_finish_wake)
	top_bar.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			var cur := UIManager.current()
			if is_instance_valid(cur):
				cur.scroll_to_top())
	get_viewport().size_changed.connect(_update_layout)
	_update_safe_area()
	_update_layout()
	top_bar.back_pressed.connect(func(): UIManager.handle_back())
	top_bar.menu_pressed.connect(NavMenu.open)
	bottom_nav.tab_selected.connect(_on_tab)
	GameManager.world_changed.connect(func(): UIManager.refresh_chrome())
	Sfx.start_music()
	UIManager.goto("menu")


func _configure_window() -> bool:
	var window := get_tree().root
	if window.size.x <= 0 or window.size.y <= 0:
		return false
	var base := UILayout.base_size_for(window.size, UILayout.is_tablet())
	var index := clampi(AppSettings.ui_scale, 0, AppSettings.UI_SCALES.size() - 1)
	var factor: float = AppSettings.UI_SCALES[index] * UILayout.device_scale()
	var changed := false
	if window.content_scale_size != base:
		window.content_scale_size = base
		changed = true
	if not is_equal_approx(window.content_scale_factor, factor):
		window.content_scale_factor = factor
		changed = true
	return changed


func restyle() -> void:
	$Background.color = UIColors.BG
	var g := (_fade.texture as GradientTexture2D).gradient
	g.set_color(0, Color(UIColors.BG, 0.0))
	g.set_color(1, Color(UIColors.BG, 0.92))
	bottom_nav.set_vertical(bottom_nav.vertical)
	UIManager._redraw_tree(self)


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


func _process(delta: float) -> void:
	var cur := UIManager.current()
	# A proteção roda a cada quadro (é barata: só a tela e o corpo dela); esperar o intervalo
	# deixava a tela nova aparecer "com zoom" por alguns quadros.
	_guard_layout(cur)
	_guard_elapsed += delta
	if _guard_elapsed >= GUARD_INTERVAL:
		_guard_elapsed = 0.0
		if OS.has_feature("mobile"):
			_trim_portrait_cache(MOBILE_PORTRAIT_LAYERS)
	var sc: ScrollContainer = cur.scroll() if is_instance_valid(cur) else null
	var top := 0.0
	var bottom := 0.0
	if is_instance_valid(sc) and sc.is_visible_in_tree():
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
	if not is_instance_valid(cur) or not cur.is_visible_in_tree() or cur.is_queued_for_deletion():
		return
	var host_w := screen_host.size.x
	# A tela é um Control simples: o mínimo dela não inclui o corpo (Body). layout_need olha só a
	# tela e os filhos diretos (mínimos em cache), sem percorrer a árvore.
	if host_w > 0.0 and (cur.size.x > host_w + 0.5 or UIKit.layout_need(cur) > host_w + 0.5):
		UIKit.fit_width(cur, host_w)
		var px := cur.position.x
		cur.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cur.position.x = px
	if not cur.scale.is_equal_approx(Vector2.ONE):
		cur.scale = Vector2.ONE


func _relayout() -> void:
	_update_layout()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var cur := UIManager.current()
	if is_instance_valid(cur):
		cur.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _ease_alpha(r: TextureRect, want: float) -> void:
	if not is_equal_approx(r.modulate.a, want):
		r.modulate.a = move_toward(r.modulate.a, want, 0.15)


func _on_tab(tab: String) -> void:
	var cur := UIManager.current()
	if is_instance_valid(cur) and cur.screen_name == tab:
		cur.scroll_to_top()
		return
	UIManager.goto(tab)


## Resize pode ser emitido de novo quando a escala muda. Nunca reconstruir a árvore
## dentro desse sinal; agrupar notificações e aplicar depois que o viewport estabilizar.
func _update_layout() -> void:
	if _layout_pending or not is_inside_tree():
		return
	_layout_pending = true
	_apply_layout.call_deferred()


func _apply_layout() -> void:
	_layout_pending = false
	if not is_inside_tree() or is_queued_for_deletion():
		return
	if _configure_window():
		_update_layout()
		return
	UILayout.viewport = get_viewport_rect().size
	_update_safe_area()
	var sc := UILayout.size_class()
	var landscape := UILayout.is_landscape()
	var first := _size_class < 0
	var changed := sc != _size_class or landscape != _last_landscape
	_size_class = sc
	_last_landscape = landscape
	if not changed:
		return
	var wide := sc != UILayout.COMPACT
	var target: Node = middle if wide else $SafeArea/Layout
	if bottom_nav.get_parent() != target:
		bottom_nav.reparent(target, false)
		if wide:
			target.move_child(bottom_nav, 0)
	bottom_nav.set_vertical(wide)
	if not first and not _refresh_pending:
		_refresh_pending = true
		_refresh_current_layout.call_deferred()


func _refresh_current_layout() -> void:
	_refresh_pending = false
	var cur := UIManager.current()
	if not is_instance_valid(cur) or cur.is_queued_for_deletion():
		return
	var sc := cur.scroll()
	var old_scroll := sc.scroll_vertical if is_instance_valid(sc) else 0
	# Girar o aparelho no meio de um trabalho em thread: a tela é refeita quando ele acabar.
	if not UIManager.refresh_current():
		return
	if is_instance_valid(sc):
		sc.set_deferred("scroll_vertical", old_scroll)


func safe_margins() -> Rect2:
	return _safe


func _update_safe_area() -> void:
	var win_size := Vector2(DisplayServer.window_get_size())
	var vp_size := get_viewport_rect().size
	var top := 0.0
	var bottom := 0.0
	var left := 0.0
	var right := 0.0
	if OS.has_feature("mobile") and win_size.x > 0.0 and win_size.y > 0.0:
		var safe := Rect2(DisplayServer.get_display_safe_area()).intersection(Rect2(Vector2.ZERO, win_size))
		if safe.has_area():
			var k := vp_size / win_size
			top = maxf(0.0, safe.position.y * k.y)
			left = maxf(0.0, safe.position.x * k.x)
			bottom = maxf(0.0, (win_size.y - safe.end.y) * k.y)
			right = maxf(0.0, (win_size.x - safe.end.x) * k.x)
	_safe = Rect2(left, top, right, bottom)
	for entry in [[&"margin_top", top], [&"margin_bottom", bottom], [&"margin_left", left], [&"margin_right", right]]:
		var value := int(entry[1])
		if safe_area.get_theme_constant(entry[0]) != value:
			safe_area.add_theme_constant_override(entry[0], value)


func apply_chrome(screen: BaseScreen, can_go_back: bool) -> void:
	UIColors.apply_context(GameManager.user_club() if GameManager.has_career() else null, screen.color_context() if GameManager.has_career() else {})
	if $Background.color != UIColors.BG:
		$Background.color = UIColors.BG
		var g := (_fade.texture as GradientTexture2D).gradient
		g.set_color(0, Color(UIColors.BG, 0.0))
		g.set_color(1, Color(UIColors.BG, 0.92))
	top_bar.visible = screen.show_top
	bottom_nav.visible = screen.show_nav and GameManager.has_career()
	if screen.show_top:
		var club: Club = GameManager.user_club() if GameManager.has_career() else null
		top_bar.set_state(screen.screen_title, screen.screen_subtitle, can_go_back, club, NavMenu.available(screen))
	bottom_nav.select(screen.nav_tab)


func _notification(what: int) -> void:
	if not is_node_ready():
		return
	if what == NOTIFICATION_OS_MEMORY_WARNING:
		# São somente comandos de desenho regeneráveis, nunca dados da carreira.
		_trim_portrait_cache(0)
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		UIManager.handle_back()
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if not _wake_pending:
			_wake_pending = true
			_wake_render.call_deferred()
		_relayout()
		if AppSettings.theme_mode == AppSettings.THEME_SYSTEM and AppSettings.wants_light() != UIColors.light:
			UIManager.apply_look.call_deferred()


func _trim_portrait_cache(limit: int) -> void:
	# Cache de três camadas por retrato, originalmente limitado a 720 camadas.
	# FIFO mantém o contrato do PortraitView e evita manter retratos antigos sem limite útil.
	while PortraitView._cmd_cache_order.size() > limit:
		PortraitView._cmd_cache.erase(PortraitView._cmd_cache_order.pop_front())
	if limit == 0:
		PortraitView._cmd_cache.clear()


func _wake_render() -> void:
	_wake_pending = false
	if not is_inside_tree() or is_queued_for_deletion():
		return
	OS.low_processor_usage_mode = false
	DecalCache.refresh()
	_redraw_all(get_tree().root)
	_wake_timer.start()


func _finish_wake() -> void:
	OS.low_processor_usage_mode = _lp_wanted and not _live


func set_live(on: bool) -> void:
	_live = on
	OS.low_processor_usage_mode = _lp_wanted and not on and (not is_instance_valid(_wake_timer) or _wake_timer.is_stopped())


func _redraw_all(n: Node) -> void:
	if n is CanvasItem:
		(n as CanvasItem).queue_redraw()
	for child in n.get_children():
		_redraw_all(child)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		UIManager.handle_back()
		get_viewport().set_input_as_handled()
