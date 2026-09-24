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


func scroll_to_top() -> void:
	var s := scroll()
	if s != null:
		s.scroll_vertical = 0
