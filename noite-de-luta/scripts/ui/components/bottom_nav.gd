class_name BottomNav
extends PanelContainer
## Navegação principal: Início · Equipe · Rankings · Mercado · Academia. Embaixo no celular em
## retrato; em telas largas vira um trilho estreito na lateral esquerda.

signal tab_selected(tab: String)

const TABS_BY_ROLE := {
	"empresario": [
		["hub", "Início", "home"],
		["team", "Equipe", "users"],
		["rankings", "Rankings", "belt"],
		["market", "Mercado", "swap"],
		["gym", "Academia", "shield"],
	],
	"presidente": [
		["hub", "Início", "home"],
		["events", "Eventos", "glove"],
		["rankings", "Rankings", "list"],
		["titles", "Cinturões", "belt"],
		["org", "Organização", "shield"],
	],
}

var _buttons: Dictionary = {}
var _active := ""
var vertical := false
var role := ""


func _ready() -> void:
	set_role("empresario")


## Monta os botões do papel (empresário ou presidente); nada muda se o papel é o mesmo.
func set_role(r: String) -> void:
	if r == role:
		return
	role = r
	var old := get_node_or_null("Row")
	if old != null:
		remove_child(old)
		old.queue_free()
	_buttons.clear()
	var row: BoxContainer = VBoxContainer.new() if vertical else HBoxContainer.new()
	row.name = "Row"
	row.add_theme_constant_override(&"separation", 6 if vertical else 0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	for t in TABS_BY_ROLE.get(r, TABS_BY_ROLE["empresario"]):
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
	if is_inside_tree():
		set_vertical(vertical)
		select(_active)


## Lateral (true) ou embaixo (false).
func set_vertical(on: bool) -> void:
	vertical = on
	var old: BoxContainer = get_node("Row")
	if (old is VBoxContainer) != on:
		var row: BoxContainer = VBoxContainer.new() if on else HBoxContainer.new()
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
	remove_theme_stylebox_override(&"panel")
	var sb := (get_theme_stylebox(&"panel", &"BottomBar") as StyleBoxFlat).duplicate() as StyleBoxFlat
	if on:
		sb.border_width_top = 0
		sb.border_width_right = 1
		sb.content_margin_top = UITokens.S1 if UILayout.viewport.y < 720.0 else 16
	add_theme_stylebox_override(&"panel", sb)
	for b: Button in _buttons.values():
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var rail_height := UITokens.H_BUTTON if UILayout.viewport.y < 560.0 else (UITokens.H_ROW if UILayout.viewport.y < 720.0 else 104)
		b.custom_minimum_size = Vector2(0, rail_height if on else UITokens.H_NAV - 8)
	queue_redraw()


func select(tab: String) -> void:
	for k in _buttons:
		_buttons[k].set_pressed_no_signal(k == tab)
	_active = tab
	queue_redraw()


## Aba ativa: filete na cor da equipe na borda. Sem cápsula atrás do ícone.
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
