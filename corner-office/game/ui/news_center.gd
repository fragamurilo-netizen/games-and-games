class_name NewsCenter
extends Control
## Central de notícias em tela cheia (Game Design Bible §10, §15; MMA Bible §27).
## Só lê Game.world; manchetes, veículos e pesos vêm de simulation/media.
## Abrir a central marca as notícias exibidas como lidas.

signal closed

const PAGE := 30

var _filter := "all"
var _list: VBoxContainer
var _filters: HFlowContainer
var _count: Label
var _shown := PAGE


func _ready() -> void:
	theme = Tokens.build_theme()
	var bg := ColorRect.new()
	bg.color = Tokens.CANVAS
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, Tokens.SPACE_M)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", Tokens.SPACE_S)
	margin.add_child(column)

	var top := HBoxContainer.new()
	var title := Label.new()
	title.text = "NOTICIÁRIO"
	title.add_theme_font_override("font", Tokens.DISPLAY_FONT)
	title.add_theme_font_size_override("font_size", Tokens.FONT_TITLE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var back := Button.new()
	back.text = "VOLTAR"
	back.custom_minimum_size = Vector2(160, Tokens.TOUCH_MIN)
	back.pressed.connect(close)
	top.add_child(back)
	column.add_child(top)
	_count = Label.new()
	_count.add_theme_color_override("font_color", Tokens.MUTED)
	column.add_child(_count)

	_filters = HFlowContainer.new()
	_filters.add_theme_constant_override("h_separation", Tokens.SPACE_S)
	_filters.add_theme_constant_override("v_separation", Tokens.SPACE_S)
	column.add_child(_filters)
	var options: Array = [{"id": "all", "label": "Tudo"}, {"id": "mine", "label": "Minha organização"}]
	options.append_array(Media.config().categories)
	for option: Dictionary in options:
		var b := Button.new()
		b.text = str(option.label).to_upper()
		b.toggle_mode = true
		b.button_pressed = option.id == _filter
		b.custom_minimum_size.y = Tokens.TOUCH_MIN
		b.add_theme_font_size_override("font_size", Tokens.FONT_SMALL)
		b.pressed.connect(_set_filter.bind(str(option.id)))
		b.set_meta("filter", option.id)
		_filters.add_child(b)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", Tokens.SPACE_M)
	scroll.add_child(_list)
	_render()


func close() -> void:
	Game.save_game("autosave")
	closed.emit()
	queue_free()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_inside_tree():
		get_viewport().set_input_as_handled()
		close()


func _set_filter(id: String) -> void:
	_filter = id
	_shown = PAGE
	for b: Button in _filters.get_children():
		b.button_pressed = b.get_meta("filter") == id
	_render()


func _items() -> Array:
	var w := Game.world
	var items: Array = w.news.values().filter(func(n: NewsItem):
		if _filter == "mine":
			return Media.involves_player(w, n)
		return _filter == "all" or n.category == _filter)
	items.reverse()
	return items


func _render() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	var w := Game.world
	var items := _items()
	_count.text = "%d notícias · %d novas" % [w.news.size(), Media.unread_count(w)]
	if items.is_empty():
		_add_label(_list, "Nenhuma notícia aqui ainda. As manchetes nascem dos fatos: cards anunciados, resultados, contratos e rankings.", Tokens.MUTED)
	var labels: Array = Media.config().importance_labels
	var seen: Array = []
	for n: NewsItem in items.slice(0, _shown):
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", Tokens.SPACE_XS)
		var meta := "%s · %s · %s" % [Media.outlet(n.outlet_id).name.to_upper(), GameDate.format(n.created_at), str(labels[clampi(n.importance, 0, labels.size() - 1)]).to_upper()]
		if not n.read:
			meta = "NOVA · " + meta
		_add_label(row, meta, Tokens.INK if not n.read else Tokens.MUTED).add_theme_font_size_override("font_size", Tokens.FONT_SMALL)
		var headline := _add_label(row, n.headline, Tokens.INK)
		if n.importance >= 3:
			headline.add_theme_font_override("font", Tokens.DISPLAY_FONT)
			headline.add_theme_font_size_override("font_size", 32)
		if not n.body.is_empty():
			_add_label(row, n.body, Tokens.MUTED)
		row.add_child(HSeparator.new())
		_list.add_child(row)
		seen.append(n.id)
	if items.size() > _shown:
		var more := Button.new()
		more.text = "Mais notícias (%d)" % (items.size() - _shown)
		more.custom_minimum_size.y = Tokens.TOUCH_MIN
		more.pressed.connect(func():
			_shown += PAGE
			_render())
		_list.add_child(more)
	Media.mark_read(w, seen)


func _add_label(parent: Control, text: String, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l
