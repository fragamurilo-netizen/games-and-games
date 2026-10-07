class_name BaseScreen
extends Control
## Base de todas as telas. Cada tela declara como quer a barra superior e a navegação, e
## reconstrói seu conteúdo em refresh() a partir do GameWorld. O esqueleto (Body › Scroll ›
## Margin › Content e o rodapé fixo) é montado aqui, igual ao das telas do Mais Uma Rodada.

var screen_name: String = ""
var params: Dictionary = {}
var screen_title: String = ""
var screen_subtitle: String = ""
var show_top: bool = true
var show_nav: bool = true

## Largura máxima do conteúdo em telas largas (o resto vira margem, centralizando).
var max_content_width := 1100.0:
	set(v):
		if not is_equal_approx(v, max_content_width):
			max_content_width = v
			_fit_content_width()


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var body := VBoxContainer.new()
	body.name = "Body"
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_constant_override(&"separation", 0)
	add_child(body)
	var sc := ScrollContainer.new()
	sc.name = "Scroll"
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.scroll_deadzone = 14
	sc.follow_focus = false
	body.add_child(sc)
	var m := MarginContainer.new()
	m.name = "Margin"
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.add_theme_constant_override(&"margin_left", UITokens.GUTTER)
	m.add_theme_constant_override(&"margin_right", UITokens.GUTTER)
	m.add_theme_constant_override(&"margin_top", UITokens.S3)
	m.add_theme_constant_override(&"margin_bottom", UITokens.S6)
	sc.add_child(m)
	var c := VBoxContainer.new()
	c.name = "Content"
	c.add_theme_constant_override(&"separation", UITokens.S4)
	m.add_child(c)
	var f := PanelContainer.new()
	f.name = "Footer"
	f.visible = false
	f.theme_type_variation = "BottomBar"
	body.add_child(f)
	var fb := VBoxContainer.new()
	fb.name = "FooterBox"
	fb.add_theme_constant_override(&"separation", UITokens.S2)
	f.add_child(fb)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_fit_content_width()


func _max_width() -> float:
	return max_content_width * UILayout.width_boost()


## Centraliza o conteúdo quando a tela é mais larga que `max_content_width`.
func _fit_content_width() -> void:
	var m := get_node_or_null("Body/Scroll/Margin") as MarginContainer
	if m == null:
		return
	var max_w := _max_width()
	var side := maxi(UITokens.GUTTER, int((size.x - max_w) * 0.5))
	if m.get_theme_constant(&"margin_left") != side:
		m.add_theme_constant_override(&"margin_left", side)
		m.add_theme_constant_override(&"margin_right", side)
	var f := get_node_or_null("Body/Footer/FooterBox") as Control
	if f != null:
		var fs := maxi(0, int((size.x - max_w) * 0.5))
		f.custom_minimum_size.x = 0
		if fs > 0:
			f.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			f.custom_minimum_size.x = minf(max_w, size.x)
		else:
			f.size_flags_horizontal = Control.SIZE_FILL


## Largura útil do conteúdo (para decidir quantas colunas cabem).
func content_width() -> float:
	var host := UILayout.viewport.x - (UILayout.RAIL_W if UILayout.is_wide() else 0.0)
	return minf(host, _max_width()) - UITokens.GUTTER * 2


func setup(p: Dictionary) -> void:
	params = p


## Chamado sempre que a tela aparece (inclusive ao voltar de outra).
func on_show() -> void:
	refresh()


func on_hide() -> void:
	pass


## Reconstrói o conteúdo. Cada tela implementa o seu.
func refresh() -> void:
	queue_redraw()


func world() -> GameWorld:
	return GameManager.world


func content() -> VBoxContainer:
	return get_node_or_null("Body/Scroll/Margin/Content") as VBoxContainer


## Limpa o conteúdo e o rodapé antes de reconstruir.
func reset() -> VBoxContainer:
	var c := content()
	UIKit.clear(c)
	var fb := get_node_or_null("Body/Footer/FooterBox") as VBoxContainer
	if fb != null:
		UIKit.clear(fb)
	hide_footer()
	return c


## Responsivo: redistribui os filhos de `c` a partir de `start` em colunas em telas largas.
func columnize(c: Container, start: int = 0, max_cols: int = 2, pinned: int = 0) -> void:
	if UILayout.columns_for(content_width(), max_cols) <= 1:
		return
	var cards: Array = []
	for ch in c.get_children().slice(start):
		c.remove_child(ch)
		cards.append(ch)
	UIKit.columns(c, cards, content_width(), max_cols, pinned)


## Área fixa na base da tela (o botão principal). Fica oculta até ser usada.
func footer() -> VBoxContainer:
	var f := get_node_or_null("Body/Footer") as Control
	if f != null:
		f.visible = true
	return get_node_or_null("Body/Footer/FooterBox") as VBoxContainer


func hide_footer() -> void:
	var f := get_node_or_null("Body/Footer") as Control
	if f != null:
		f.visible = false


func scroll() -> ScrollContainer:
	return get_node_or_null("Body/Scroll") as ScrollContainer


func scroll_to_top() -> void:
	var s := scroll()
	if s == null or s.scroll_vertical == 0:
		return
	var tw := s.create_tween()
	tw.tween_property(s, "scroll_vertical", 0, clampf(s.scroll_vertical / 4000.0, 0.15, 0.35)) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
