extends Control
## Casca da aplicação (Game Design Bible §15), na linguagem de menus de
## UFC Undisputed 3: foto dessaturada ao fundo, faixa vermelha de título,
## painéis claros e faixa vermelha de comandos com a descrição embaixo.
##  - Landscape/tablet: menu de áreas num painel à esquerda, conteúdo à direita.
##  - Portrait: conteúdo no alto e faixa de áreas acima dos comandos.
## Regra de navegação: qualquer área em 1 toque, qualquer ação em até 3.
## Telas só leem estado via Game.world e disparam ações nos serviços de
## simulação; nenhuma regra de jogo mora em ui/.

## Linha de descrição de cada área (faixa inferior, como em 2012).
const TAB_HINTS := {
	"home": "Central da promoção: tudo o que exige atenção agora, a um toque.",
	"fighters": "Elenco, rankings e a ficha completa de cada atleta.",
	"events": "Monte o card, negocie confrontos e realize a noite.",
	"market": "Agentes livres e contratos.",
	"organization": "Caixa, balanços de cada noite e a sua promoção.",
}

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
var _header: Ud3Chrome.TitleBar
var _hints: Ud3Chrome.HintBar
var _safe: MarginContainer
var _history: Array = []
var _swipe_from := Vector2.INF


func _ready() -> void:
	get_tree().quit_on_go_back=false
	theme = Tokens.build_theme()
	var bg := Ud3Chrome.Backdrop.new()
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
		screen.navigate.connect(_navigate)
		screen.hint_changed.connect(func(text): _hints.set_hint(text))
		_content.add_child(screen)
		_screens[tab.id] = screen

	_stage=VBoxContainer.new()
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.add_theme_constant_override("separation",0)
	_safe=MarginContainer.new();_safe.set_anchors_and_offsets_preset(PRESET_FULL_RECT);add_child(_safe);_safe.add_child(_stage)
	_header=Ud3Chrome.TitleBar.new()
	_stage.add_child(_header)
	_hints=Ud3Chrome.HintBar.new()
	_hints.back_pressed.connect(func(): go_back())
	_hints.menu_pressed.connect(_open_menu)
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


## Toda troca de tela passa por aqui e fica no histórico do Voltar, para que
## hub, abas e atalhos entre telas funcionem como uma central só.
func _navigate(id: String, payload: Dictionary) -> void:
	if _current != "":
		_history.append({"tab": _current, "state": _screens[_current].snapshot()})
		if _history.size() > 40:
			_history.pop_front()
	_open(id, payload)


func _open(id: String, payload: Dictionary) -> void:
	var screen: Screen = _screens[id]
	screen.receive(payload)
	screen.pending_scroll = int(payload.get("scroll", -1))
	if _current == id:
		screen.refresh()
		for tab_id in _buttons:
			_buttons[tab_id].button_pressed = tab_id == id
	else:
		show_tab(id)
	_refresh_header()


## Tocar na aba já aberta volta à raiz dela (ex.: do perfil para a lista).
func _tab_pressed(id: String) -> void:
	_navigate(id, {"reset": true} if id == _current else {})


## Volta um passo. Retorna false quando não há para onde voltar.
func go_back() -> bool:
	if _history.is_empty():
		return false
	var step: Dictionary = _history.pop_back()
	_open(step.tab, step.state)
	return true


## Deslizar na horizontal troca de aba, na ordem da faixa.
func _input(event: InputEvent) -> void:
	if not visible or get_children().any(func(node): return node is GameMenu):
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_swipe_from = event.position
		elif _swipe_from != Vector2.INF:
			var delta: Vector2 = event.position - _swipe_from
			_swipe_from = Vector2.INF
			if absf(delta.x) > 180 and absf(delta.x) > absf(delta.y) * 2.5:
				var ids: Array = TABS.map(func(t): return t.id)
				var i: int = ids.find(_current) + (1 if delta.x < 0 else -1)
				if i >= 0 and i < ids.size():
					_navigate(ids[i], {})


func _is_landscape() -> bool:
	var s := get_viewport_rect().size
	return s.x > s.y


func _rebuild_layout() -> void:
	var landscape := _is_landscape()
	if _layout and _layout.has_meta("landscape") and bool(_layout.get_meta("landscape")) == landscape:
		return
	if _layout:
		_content.get_parent().remove_child(_content)
		_stage.remove_child(_hints)
		var old_margin := _layout.get_parent()
		_stage.remove_child(old_margin)
		old_margin.queue_free()
	_layout = HBoxContainer.new() if landscape else VBoxContainer.new()
	_layout.set_meta("landscape", landscape)
	_layout.size_flags_vertical=Control.SIZE_EXPAND_FILL
	_layout.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_layout.add_theme_constant_override("separation", Tokens.SPACE_M if landscape else Tokens.SPACE_S)
	var margin := MarginContainer.new()
	margin.size_flags_vertical=Control.SIZE_EXPAND_FILL
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_"+side, Tokens.SPACE_M if landscape or side!="bottom" else Tokens.SPACE_S)
	margin.add_child(_layout)
	_stage.add_child(margin)
	_stage.add_child(_hints)

	# Menu de áreas: lista num painel claro (landscape) ou faixa (portrait).
	var nav_panel := PanelContainer.new()
	var nav_box := Tokens.panel_box()
	nav_box.content_margin_left=Tokens.SPACE_S;nav_box.content_margin_right=Tokens.SPACE_S
	nav_box.content_margin_top=Tokens.SPACE_S;nav_box.content_margin_bottom=Tokens.SPACE_S
	nav_panel.add_theme_stylebox_override("panel", nav_box)
	var nav_column := VBoxContainer.new()
	nav_column.add_theme_constant_override("separation", Tokens.SPACE_XS)
	nav_panel.add_child(nav_column)
	if landscape:
		nav_panel.custom_minimum_size.x = 300
		nav_column.add_child(Ud3Chrome.header_bar("Carreira"))
	_nav = VBoxContainer.new() if landscape else HBoxContainer.new()
	_nav.add_theme_constant_override("separation", Tokens.SPACE_XS)
	nav_column.add_child(_nav)
	_buttons.clear()
	for tab in TABS:
		var b := Button.new()
		b.text = tab.label.to_upper()
		b.toggle_mode = true
		b.clip_text = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT if landscape else HORIZONTAL_ALIGNMENT_CENTER
		b.custom_minimum_size = Vector2(0, Tokens.TOUCH_MIN - 16)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 24 if landscape else 15)
		if not landscape:
			for state in ["normal","hover","pressed","hover_pressed","focus"]:
				var box: StyleBox = theme.get_stylebox(state, "Button").duplicate()
				box.content_margin_left = Tokens.SPACE_XS
				box.content_margin_right = Tokens.SPACE_XS
				b.add_theme_stylebox_override(state, box)
		b.pressed.connect(_tab_pressed.bind(tab.id))
		b.mouse_entered.connect(func(): _hints.set_hint(TAB_HINTS.get(tab.id, "")))
		b.button_pressed = tab.id == _current
		_nav.add_child(b)
		_buttons[tab.id] = b

	var content_panel := PanelContainer.new()
	content_panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	content_panel.size_flags_vertical=Control.SIZE_EXPAND_FILL
	var content_box := Tokens.panel_box()
	content_box.content_margin_left=0;content_box.content_margin_right=0
	content_box.content_margin_top=0;content_box.content_margin_bottom=0
	content_panel.add_theme_stylebox_override("panel", content_box)
	content_panel.add_child(_content)
	if landscape:
		_layout.add_child(nav_panel)
		_layout.add_child(content_panel)
	else:
		_layout.add_child(content_panel)
		_layout.add_child(nav_panel)


func _open_menu() -> void:
	var menu:=GameMenu.new();menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(menu)
	menu.continued.connect(func():_current="";show_tab("home"))

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_GO_BACK_REQUEST:
		if get_tree().root.get_children().any(func(node):return node is FightReplayView or node is NewsCenter):return
		get_viewport().set_input_as_handled()
		if get_children().any(func(node):return node is GameMenu):return
		if not go_back():_open_menu()


func _refresh_header() -> void:
	if _hints:
		_hints.set_can_go_back(not _history.is_empty())
		if _current != "":_hints.set_hint(_screens[_current].hint() if not _screens[_current].hint().is_empty() else TAB_HINTS.get(_current,""))
	if _header and Game.has_world():
		if _current != "":_header.title=_screens[_current].tab_label
		_header.context=Game.world.player_org().short_name+" · "+GameDate.format(Game.world.date)+" · "+CareerText.money(Game.world.player_org().cash)
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
