class_name BaseScreen
extends Control
## Base de todas as telas. Cada tela declara como quer a barra superior e a navegação,
## e reconstrói seu conteúdo em refresh() a partir do GameWorld.

var screen_name: String = ""
var params: Dictionary = {}
var screen_title: String = ""
var screen_subtitle: String = ""
var show_top: bool = true
var show_nav: bool = true
var nav_tab: String = ""


## Largura máxima do conteúdo em telas largas (o resto vira margem, centralizando). Telas
## que distribuem cartões em colunas (UIKit.columns) aumentam este valor.
var max_content_width := 1100.0:
	set(v):
		if not is_equal_approx(v, max_content_width):
			max_content_width = v
			_fit_content_width()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_fit_content_width()


## Centraliza o conteúdo quando a tela é mais larga que `max_content_width`.
func _fit_content_width() -> void:
	var m := get_node_or_null("Body/Scroll/Margin") as MarginContainer
	if m == null:
		return
	var side := maxi(UITokens.GUTTER, int((size.x - max_content_width) * 0.5))
	if m.get_theme_constant(&"margin_left") != side:
		m.add_theme_constant_override(&"margin_left", side)
		m.add_theme_constant_override(&"margin_right", side)
	var f := get_node_or_null("Body/Footer/FooterBox") as Control
	if f != null:
		var fp := f.get_parent() as Control
		var fs := maxi(0, int((size.x - max_content_width) * 0.5))
		f.custom_minimum_size.x = 0
		if fp is PanelContainer and fs > 0:
			f.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			f.custom_minimum_size.x = minf(max_content_width, size.x)
		else:
			f.size_flags_horizontal = Control.SIZE_FILL


## Largura útil do conteúdo (para decidir quantas colunas cabem).
func content_width() -> float:
	var host := UILayout.viewport.x - (UILayout.RAIL_W if UILayout.is_wide() else 0.0)
	return minf(host, max_content_width) - UITokens.GUTTER * 2


func setup(p: Dictionary) -> void:
	params = p


## Chamado sempre que a tela aparece (inclusive ao voltar de outra).
func on_show() -> void:
	refresh()


func on_hide() -> void:
	set_process(false)


## Reconstrói o conteúdo. Cada tela implementa o seu.
func refresh() -> void:
	queue_redraw()


func world() -> GameWorld:
	return GameManager.world


func content() -> VBoxContainer:
	return get_node_or_null("Body/Scroll/Margin/Content") as VBoxContainer


## Área fixa na base da tela (botão principal da tela). Fica oculta até ser usada.
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


## Volta ao topo deslizando (tocar de novo na aba atual ou no título da barra superior).
func scroll_to_top() -> void:
	var s := scroll()
	if s == null or s.scroll_vertical == 0:
		return
	var tw := s.create_tween()
	tw.tween_property(s, "scroll_vertical", 0, clampf(s.scroll_vertical / 4000.0, 0.15, 0.35)) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
