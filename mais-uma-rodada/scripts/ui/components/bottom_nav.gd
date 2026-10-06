class_name BottomNav
extends PanelContainer
## Navegação principal: Início · Elenco · Tática · Mercado · Clube. Embaixo no celular em
## retrato; em telas largas (paisagem, tablet) vira um trilho estreito na lateral esquerda.

signal tab_selected(tab: String)

const TABS := [
	["hub", "Início", "home"],
	["squad", "Elenco", "shirt"],
	["tactics", "Tática", "tactics"],
	["market", "Mercado", "swap"],
	["club", "Clube", "shield"],
]

var _buttons: Dictionary = {}
var _active := ""
var vertical := false


func _ready() -> void:
	var row: BoxContainer = $Row
	UIKit.clear(row)
	for t in TABS:
		var b := Button.new()
		b.theme_type_variation = "NavButton"
		b.text = t[1]
		b.icon = UIKit.icon(t[2])
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, UITokens.H_NAV - 8)
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_ALL
		UIKit.press_fx(b, null, 0.92)
		var tab: String = t[0]
		b.pressed.connect(func():
			Sfx.play("tab", -6.0)
			tab_selected.emit(tab))
		row.add_child(b)
		_buttons[tab] = b
	row.resized.connect(queue_redraw)


## Lateral (true) ou embaixo (false).
func set_vertical(on: bool) -> void:
	vertical = on
	# Troca o contêiner da fileira (HBox embaixo, VBox na lateral) mantendo os botões.
	var old: BoxContainer = get_node("Row")
	var want_v := on
	if (old is VBoxContainer) != want_v:
		var row: BoxContainer = VBoxContainer.new() if want_v else HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for b in old.get_children():
			old.remove_child(b)
			row.add_child(b)
		remove_child(old)
		old.queue_free()
		row.name = "Row"
		add_child(row)
		row.resized.connect(queue_redraw)
	var cur: BoxContainer = get_node("Row")
	cur.add_theme_constant_override(&"separation", 6 if on else 0)
	custom_minimum_size = Vector2(UILayout.RAIL_W, 0) if on else Vector2.ZERO
	# Sem a cópia anterior: ela guardava as cores do modo antigo (a barra ficava escura no claro).
	remove_theme_stylebox_override(&"panel")
	var sb := (get_theme_stylebox(&"panel", &"BottomBar") as StyleBoxFlat).duplicate() as StyleBoxFlat
	if on:
		sb.border_width_top = 0
		sb.border_width_right = 1
		sb.content_margin_top = UITokens.S1 if UILayout.viewport.y < 720.0 else 16
	add_theme_stylebox_override(&"panel", sb)
	for b: Button in _buttons.values():
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Five 104px items plus the header exceeded a landscape phone's 600px
		# canvas, pushing the entire shell above the safe area and clipping titles.
		var rail_height := UITokens.H_BUTTON if UILayout.viewport.y < 560.0 else (UITokens.H_ROW if UILayout.viewport.y < 720.0 else 104)
		b.custom_minimum_size = Vector2(0, rail_height if on else UITokens.H_NAV - 8)
	queue_redraw()


func select(tab: String) -> void:
	for k in _buttons:
		_buttons[k].set_pressed_no_signal(k == tab)
	_active = tab
	queue_redraw()


## Aba ativa: filete na cor do clube na borda (em cima da aba na barra de baixo, à esquerda
## no trilho lateral). Sem cápsula atrás do ícone.
func _draw() -> void:
	if not _buttons.has(_active):
		return
	var b: Button = _buttons[_active]
	var r := Rect2(b.position + (get_node("Row") as Control).position, b.size)
	if vertical:
		draw_rect(Rect2(0, r.position.y + 10.0, 3.0, r.size.y - 20.0), UIColors.ACCENT)
	else:
		var w := minf(56.0, r.size.x - 24.0)
		draw_rect(Rect2(r.get_center().x - w * 0.5, 0, w, 3.0), UIColors.ACCENT)
