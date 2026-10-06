class_name LiveTicker
extends PanelContainer
## "Acontecendo agora" no Início: o noticiário do mundo passando sozinho, uma manchete por vez
## (contratações, demissões, resultados lá fora, recordes), com o escudo de quem está na notícia e
## uma barra fina que mostra quando vem a próxima. Tocar abre a matéria; o "›" pula para a seguinte.
## Para enquanto a tela não está visível.

const HOLD := 5.0

var _w: GameWorld
var _items: Array = []
var _i := 0
var _t := 0.0
var _body: MarginContainer
var _icon_box: Control
var _kicker: Label
var _title: Label
var _count: Label
var _bar: ColorRect


static func make(w: GameWorld, items: Array) -> LiveTicker:
	var t := LiveTicker.new()
	t._w = w
	t._items = items
	return t


func _ready() -> void:
	theme_type_variation = "Card"
	mouse_filter = Control.MOUSE_FILTER_STOP
	var v := UIKit.vbox(6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var head := UIKit.hbox(8)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dot := UIKit.label("●", "Caps")
	dot.add_theme_color_override(&"font_color", UIColors.RED)
	head.add_child(dot)
	var ht := UIKit.label("Acontecendo agora", "Caps")
	ht.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(ht)
	_count = UIKit.label("", "Caps")
	_count.add_theme_color_override(&"font_color", UIColors.DIM)
	head.add_child(_count)
	var nb := UIKit.icon_button("forward", _next, "Próxima")
	nb.custom_minimum_size = Vector2(56, 48)
	head.add_child(nb)
	v.add_child(head)
	_body = MarginContainer.new()
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.custom_minimum_size.y = 76
	var row := UIKit.hbox(12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_box = CenterContainer.new()
	_icon_box.custom_minimum_size = Vector2(56, 56)
	_icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_icon_box)
	var col := UIKit.vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_kicker = UIKit.label("", "Caps")
	_kicker.clip_text = true
	_kicker.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(_kicker)
	_title = UIKit.label("", "H3", true)
	_title.max_lines_visible = 2
	col.add_child(_title)
	row.add_child(col)
	_body.add_child(row)
	v.add_child(_body)
	var track := ColorRect.new()
	track.color = UIColors.LINE
	track.custom_minimum_size.y = 3
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar = ColorRect.new()
	_bar.color = UIColors.ACCENT
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	track.add_child(_bar)
	v.add_child(track)
	add_child(v)
	gui_input.connect(_on_input)
	_show(false)


func _on_input(e: InputEvent) -> void:
	var tap: bool = (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed)
	if tap and not _items.is_empty():
		accept_event()
		NewsRow._open(_w, _items[_i])


func _process(delta: float) -> void:
	if _items.size() <= 1 or not is_visible_in_tree() or UIManager.has_modal():
		return
	_t += delta
	var track := _bar.get_parent() as Control
	_bar.size.x = track.size.x * clampf(_t / HOLD, 0.0, 1.0)
	if _t >= HOLD:
		_next()


func _next() -> void:
	if _items.is_empty():
		return
	_i = (_i + 1) % _items.size()
	_show(true)


func _show(animate: bool) -> void:
	_t = 0.0
	if _items.is_empty():
		return
	var n: NewsEvent = _items[_i]
	UIKit.clear(_icon_box)
	var c := _w.club(n.club_id) if n.club_id >= 0 else null
	if c != null:
		_icon_box.add_child(UIKit.crest(c, 52))
	else:
		var ic := UIKit.icon_rect("news", 34, NewsRow._icon_color(n))
		_icon_box.add_child(ic)
	_kicker.text = NewsRow.kicker(_w, n)
	_kicker.add_theme_color_override(&"font_color", UIColors.ink(NewsRow._icon_color(n)))
	_title.text = n.title
	_count.text = "%d/%d" % [_i + 1, _items.size()]
	if animate and not AppSettings.reduce_motion:
		_body.modulate.a = 0.0
		_body.add_theme_constant_override(&"margin_left", 28)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(_body, "modulate:a", 1.0, 0.25)
		tw.tween_method(func(v: int): _body.add_theme_constant_override(&"margin_left", v), 28, 0, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
