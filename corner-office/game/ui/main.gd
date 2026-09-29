extends Control
## Casca da aplicação (Game Design Bible §15):
##  - Portrait: bottom navigation com 5 abas.
##  - Landscape/tablet: rail lateral compacta (master-detail nas telas).
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


func _ready() -> void:
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
		_content.add_child(screen)
		_screens[tab.id] = screen

	if not Game.has_world():
		Game.new_game(Time.get_ticks_usec())

	get_viewport().size_changed.connect(_rebuild_layout)
	_rebuild_layout()
	show_tab("home")


func show_tab(id: String) -> void:
	if _current == id:
		return
	if _current != "":
		_screens[_current].visible = false
	_current = id
	_screens[id].visible = true
	_screens[id].refresh()
	for tab_id in _buttons:
		_buttons[tab_id].button_pressed = tab_id == id


func _is_landscape() -> bool:
	var s := get_viewport_rect().size
	return s.x > s.y


func _rebuild_layout() -> void:
	var landscape := _is_landscape()
	if _layout and (_layout is HBoxContainer) == landscape:
		return
	if _layout:
		_layout.remove_child(_content)
		_layout.queue_free()
	_layout = HBoxContainer.new() if landscape else VBoxContainer.new()
	_layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layout.add_theme_constant_override("separation", 0)
	add_child(_layout)

	_nav = VBoxContainer.new() if landscape else HBoxContainer.new()
	_nav.add_theme_constant_override("separation", 0)
	_buttons.clear()
	for tab in TABS:
		var b := Button.new()
		b.text = tab.label
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(160 if landscape else 0, Tokens.TOUCH_MIN)
		b.size_flags_horizontal = Control.SIZE_FILL if landscape else Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", Tokens.FONT_SMALL)
		b.pressed.connect(show_tab.bind(tab.id))
		b.button_pressed = tab.id == _current
		_nav.add_child(b)
		_buttons[tab.id] = b

	if landscape:
		_layout.add_child(_nav)
		_layout.add_child(_content)
	else:
		_layout.add_child(_content)
		_layout.add_child(_nav)
