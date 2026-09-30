extends Control
## Casca da aplicação (Game Design Bible §15), na linguagem de menus de
## UFC Undisputed 3: placa vermelha com o nome da aba e faixa de abas em
## paralelogramo, a aba ativa acesa em vermelho.
##  - Portrait: faixa de abas embaixo, ao alcance do polegar.
##  - Landscape/tablet: faixa de abas no alto, logo abaixo do cabeçalho.
## Telas só leem estado via Game.world e disparam ações nos serviços de
## simulação; nenhuma regra de jogo mora em ui/.

const TABS := [
	{"id": "home", "label": "Início", "script": preload("res://ui/screens/home_screen.gd")},
	{"id": "fighters", "label": "Lutadores", "script": preload("res://ui/screens/fighters_screen.gd")},
	{"id": "events", "label": "Eventos", "script": preload("res://ui/screens/events_screen.gd")},
	{"id": "market", "label": "Mercado", "script": preload("res://ui/screens/market_screen.gd")},
	{"id": "organization", "label": "Organização", "script": preload("res://ui/screens/organization_screen.gd")},
]

var _content: Control
var _nav: BoxContainer
var _layout: BoxContainer
var _screens := {}
var _buttons := {}
var _current := ""
var _stage: VBoxContainer
var _header: BrandBanner
var _safe: MarginContainer


func _ready() -> void:
	get_tree().quit_on_go_back=false
	theme = Tokens.build_theme()
	var bg := ColorRect.new()
	bg.color = Tokens.CANVAS
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_content = Control.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for tab in TABS:
		var screen: Control = tab.script.new()
		screen.name = tab.id
		screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		screen.visible = false
		screen.tab_label = tab.label
		_content.add_child(screen)
		_screens[tab.id] = screen

	_stage=VBoxContainer.new()
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.add_theme_constant_override("separation",0)
	_safe=MarginContainer.new();_safe.set_anchors_and_offsets_preset(PRESET_FULL_RECT);add_child(_safe);_safe.add_child(_stage)
	_header=BrandBanner.new();_header.custom_minimum_size.y=78
	_stage.add_child(_header)
	if not Game.has_world():
		if Game.load_game("autosave")!=OK:
			Game.new_game(Time.get_ticks_usec())
			Game.save_game("autosave")

	get_viewport().size_changed.connect(_rebuild_layout)
	get_viewport().size_changed.connect(_update_safe_area)
	EventBus.day_advanced.connect(func(_date):_refresh_header())
	EventBus.world_loaded.connect(_refresh_header)
	_update_safe_area()
	_rebuild_layout()
	show_tab("home")
	if not OS.get_cmdline_user_args().has("capture"):_open_menu()


func show_tab(id: String) -> void:
	if _current == id:
		return
	if _current != "":
		_screens[_current].visible = false
	_current = id
	_screens[id].visible = true
	_screens[id].refresh()
	_refresh_header()
	for tab_id in _buttons:
		_buttons[tab_id].button_pressed = tab_id == id


func _is_landscape() -> bool:
	var s := get_viewport_rect().size
	return s.x > s.y


func _rebuild_layout() -> void:
	var landscape := _is_landscape()
	if _layout and _layout.has_meta("landscape") and bool(_layout.get_meta("landscape")) == landscape:
		return
	if _layout:
		_layout.remove_child(_content)
		_layout.queue_free()
	_layout = VBoxContainer.new()
	_layout.set_meta("landscape", landscape)
	_layout.size_flags_vertical=Control.SIZE_EXPAND_FILL
	_layout.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_layout.add_theme_constant_override("separation", 0)
	_stage.add_child(_layout)

	_nav = HBoxContainer.new()
	_nav.add_theme_constant_override("separation", Tokens.SPACE_XS)
	_buttons.clear()
	for tab in TABS:
		var b := Button.new()
		b.text = tab.label.to_upper()
		b.toggle_mode = true
		b.clip_text = true
		b.custom_minimum_size = Vector2(0, Tokens.TOUCH_MIN)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", Tokens.FONT_SMALL if landscape else 15)
		# Abas estreitas no portrait: recuo menor que o das barras de lista.
		for state in ["normal","hover","pressed","hover_pressed","disabled","focus"]:
			var box: StyleBox = theme.get_stylebox(state, "Button").duplicate()
			box.content_margin_left = Tokens.SPACE_S + Tokens.SPACE_XS
			box.content_margin_right = Tokens.SPACE_S + Tokens.SPACE_XS
			b.add_theme_stylebox_override(state, box)
		b.pressed.connect(show_tab.bind(tab.id))
		b.button_pressed = tab.id == _current
		_nav.add_child(b)
		_buttons[tab.id] = b
	var strip := PanelContainer.new()
	var strip_box := StyleBoxFlat.new()
	strip_box.bg_color = Tokens.CANVAS
	strip_box.content_margin_left = Tokens.SPACE_M
	strip_box.content_margin_right = Tokens.SPACE_M
	strip_box.content_margin_top = Tokens.SPACE_XS
	strip_box.content_margin_bottom = Tokens.SPACE_XS
	strip.add_theme_stylebox_override("panel", strip_box)
	strip.add_child(_nav)

	if landscape:
		_layout.add_child(strip)
		_layout.add_child(_content)
	else:
		_layout.add_child(_content)
		_layout.add_child(strip)


func _open_menu() -> void:
	var menu:=GameMenu.new();menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(menu)
	menu.continued.connect(func():_current="";show_tab("home"))

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_GO_BACK_REQUEST:
		if get_tree().root.get_children().any(func(node):return node is FightReplayView):return
		get_viewport().set_input_as_handled()
		if not get_children().any(func(node):return node is GameMenu):_open_menu()


func _refresh_header() -> void:
	if _header and Game.has_world():
		if _current != "":_header.headline=_screens[_current].tab_label
		_header.subtitle=Game.world.player_org().short_name+" / "+GameDate.format(Game.world.date)+" / CARREIRA REGIONAL"
		_header.queue_redraw()

func _update_safe_area() -> void:
	if OS.get_name()!="Android":return
	var safe:=DisplayServer.get_display_safe_area()
	var window:=DisplayServer.window_get_size()
	var scale:=get_viewport_rect().size/Vector2(window)
	_safe.add_theme_constant_override("margin_left",int(safe.position.x*scale.x))
	_safe.add_theme_constant_override("margin_top",int(safe.position.y*scale.y))
	_safe.add_theme_constant_override("margin_right",int(maxi(0,window.x-safe.end.x)*scale.x))
	_safe.add_theme_constant_override("margin_bottom",int(maxi(0,window.y-safe.end.y)*scale.y))
