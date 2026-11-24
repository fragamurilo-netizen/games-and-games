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

## Entrada animada dos cartões: vale na primeira vez que a tela aparece e sempre que alguém
## religar (o Início, depois de avançar a semana). `play_intro` consome.
var intro_pending := true
## Telas que montam o conteúdo aos poucos (a luta) desligam a entrada.
var intro_enabled := true
## Peças do esqueleto, guardadas por referência: uma tela pode mudar a rolagem e o rodapé de
## lugar (a luta, com o celular deitado, põe os dois numa coluna ao lado do palco).
var _scroll_node: ScrollContainer
var _margin_node: MarginContainer
var _content_node: VBoxContainer
var _footer_node: PanelContainer
var _footer_box: VBoxContainer

## Largura máxima do conteúdo em telas largas (o resto vira margem, centralizando).
## Falso para telas que cuidam da própria largura (a luta em duas colunas).
var fit_content := true
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
	_scroll_node = sc
	var m := MarginContainer.new()
	m.name = "Margin"
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.add_theme_constant_override(&"margin_left", UITokens.GUTTER)
	m.add_theme_constant_override(&"margin_right", UITokens.GUTTER)
	m.add_theme_constant_override(&"margin_top", UITokens.S3)
	m.add_theme_constant_override(&"margin_bottom", UITokens.S6)
	sc.add_child(m)
	_margin_node = m
	var c := VBoxContainer.new()
	c.name = "Content"
	c.add_theme_constant_override(&"separation", UITokens.S4)
	m.add_child(c)
	_content_node = c
	var f := PanelContainer.new()
	f.name = "Footer"
	f.visible = false
	f.theme_type_variation = "BottomBar"
	body.add_child(f)
	var fb := VBoxContainer.new()
	fb.name = "FooterBox"
	fb.add_theme_constant_override(&"separation", UITokens.S2)
	f.add_child(fb)
	_footer_node = f
	_footer_box = fb


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_fit_content_width()


func _max_width() -> float:
	return max_content_width * UILayout.width_boost()


## Centraliza o conteúdo quando a tela é mais larga que `max_content_width`.
func _fit_content_width() -> void:
	var m := _margin_node
	if m == null or not fit_content:
		return
	var max_w := _max_width()
	var side := maxi(UITokens.GUTTER, int((size.x - max_w) * 0.5))
	if m.get_theme_constant(&"margin_left") != side:
		m.add_theme_constant_override(&"margin_left", side)
		m.add_theme_constant_override(&"margin_right", side)
	var f: Control = _footer_box
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


## O estado em que o conteúdo foi montado (ver `_stamp`).
var _built_stamp := ""


## Chamado sempre que a tela aparece (inclusive ao voltar de outra). Voltar a uma tela que já
## estava montada, sem nada ter mudado no mundo nem no formato da janela, não remonta nada: ela
## reaparece na hora.
func on_show() -> void:
	var st := _stamp()
	if st == _built_stamp and _content_node != null and _content_node.get_child_count() > 0:
		return
	refresh()
	_built_stamp = _stamp()


func _stamp() -> String:
	var w := GameManager.world
	return "%d|%d|%s|%s" % [GameManager.rev, w.week if w != null else -1, UILayout.viewport, AppSettings.reduce_motion]


func on_hide() -> void:
	pass


## Reconstrói o conteúdo. Cada tela implementa o seu.
func refresh() -> void:
	queue_redraw()


func world() -> GameWorld:
	return GameManager.world


func content() -> VBoxContainer:
	return _content_node


## Limpa o conteúdo e o rodapé antes de reconstruir.
func reset() -> VBoxContainer:
	var c := content()
	UIKit.clear(c)
	if _footer_box != null:
		UIKit.clear(_footer_box)
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


## Toca a entrada dos cartões do conteúdo (em colunas, na ordem de leitura), uma vez.
func play_intro() -> void:
	if not intro_pending:
		return
	intro_pending = false
	var c := content()
	if c == null or not intro_enabled:
		return
	var nodes: Array = []
	for ch in c.get_children():
		if not ch.has_meta(&"columns"):
			nodes.append(ch)
			continue
		var k := 0
		var more := true
		while more:
			more = false
			for col in ch.get_children():
				if k < col.get_child_count():
					nodes.append(col.get_child(k))
					more = true
			k += 1
	Anim.stagger(nodes)


## Área fixa na base da tela (o botão principal). Fica oculta até ser usada.
func footer() -> VBoxContainer:
	if _footer_node != null:
		_footer_node.visible = true
	return _footer_box


func hide_footer() -> void:
	if _footer_node != null:
		_footer_node.visible = false


func scroll() -> ScrollContainer:
	return _scroll_node


func scroll_to_top() -> void:
	var s := scroll()
	if s == null or s.scroll_vertical == 0:
		return
	var tw := s.create_tween()
	tw.tween_property(s, "scroll_vertical", 0, clampf(s.scroll_vertical / 4000.0, 0.15, 0.35)) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
