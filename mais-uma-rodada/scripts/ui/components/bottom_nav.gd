class_name BottomNav
extends PanelContainer
## Navegação principal: JOGAR · ELENCO · MERCADO · TABELA · CLUBE. Embaixo no celular em
## retrato; em telas largas (paisagem, tablet) vira uma coluna na lateral esquerda.

signal tab_selected(tab: String)

const TABS := [
	["hub", "JOGAR", "ball"],
	["squad", "ELENCO", "shirt"],
	["market", "MERCADO", "swap"],
	["table", "TABELA", "table"],
	["club", "CLUBE", "shield"],
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
		b.focus_mode = Control.FOCUS_NONE
		UIKit.press_fx(b, null, 0.92)
		var tab: String = t[0]
		b.pressed.connect(func():
			AudioManager.click()
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
		sb.content_margin_top = 16
	add_theme_stylebox_override(&"panel", sb)
	for b: Button in _buttons.values():
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 112 if on else UITokens.H_NAV - 8)
	queue_redraw()


func select(tab: String) -> void:
	for k in _buttons:
		_buttons[k].set_pressed_no_signal(k == tab)
	_active = tab
	queue_redraw()


## Indicador da aba ativa: só uma cápsula suave na cor do clube atrás do ícone (o texto
## também fica na cor do clube). Na lateral, a cápsula ocupa a largura do botão.
func _draw() -> void:
	if not _buttons.has(_active):
		return
	var b: Button = _buttons[_active]
	var r := Rect2(b.position + (get_node("Row") as Control).position, b.size)
	var icon_h := 34.0
	var text_h := b.get_theme_font_size(&"font_size") * 1.25
	var top := r.position.y + (r.size.y - icon_h - text_h) * 0.5 # conteúdo centralizado no botão
	var pill := StyleBoxFlat.new()
	pill.bg_color = Color(UIColors.ACCENT, 0.18)
	pill.set_corner_radius_all(20)
	pill.anti_aliasing = true
	var w := 76.0 if not vertical else minf(96.0, r.size.x - 16.0)
	draw_style_box(pill, Rect2(r.get_center().x - w * 0.5, top - 5.0, w, icon_h + 10.0))
