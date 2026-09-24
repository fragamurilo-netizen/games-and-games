class_name BottomNav
extends PanelContainer
## Navegação principal: JOGAR · ELENCO · MERCADO · TABELA · CLUBE.

signal tab_selected(tab: String)

const TABS := [
	["hub", "JOGAR", "ball"],
	["squad", "ELENCO", "shirt"],
	["market", "MERCADO", "swap"],
	["table", "TABELA", "table"],
	["club", "CLUBE", "shield"],
]

var _buttons: Dictionary = {}


func _ready() -> void:
	var row: HBoxContainer = $Row
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
		b.custom_minimum_size = Vector2(0, 92)
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		UIKit.press_fx(b, null, 0.92)
		var tab: String = t[0]
		b.pressed.connect(func():
			AudioManager.click()
			tab_selected.emit(tab))
		row.add_child(b)
		_buttons[tab] = b


func select(tab: String) -> void:
	for k in _buttons:
		_buttons[k].set_pressed_no_signal(k == tab)
