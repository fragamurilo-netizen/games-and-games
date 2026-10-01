class_name NewsCenter
extends Control
## Central de mídia em tela cheia (Game Design Bible §10, §15; MMA Bible §27).
## Três visões: Notícias (todas as matérias, com filtros por editoria),
## Sites (a página de cada veículo) e Redes (posts de atletas, organizações e
## torcida). Só lê Game.world; textos, veículos e pesos vêm de simulation/media.
## O que é exibido fica marcado como lido.

signal closed

const PAGE := 30
const VIEWS := [{"id": "news", "label": "Notícias"}, {"id": "sites", "label": "Sites"}, {"id": "social", "label": "Redes"}]

var _view := "news"
var _filter := "all"
var _site := ""
var _list: VBoxContainer
var _tabs: HBoxContainer
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
	title.text = "MÍDIA"
	title.add_theme_font_override("font", Tokens.DISPLAY_FONT)
	title.add_theme_font_size_override("font_size", Tokens.FONT_TITLE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var back := Button.new()
	back.text = "VOLTAR"
	back.custom_minimum_size = Vector2(160, Tokens.TOUCH_MIN)
	back.pressed.connect(_back)
	top.add_child(back)
	column.add_child(top)

	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", Tokens.SPACE_S)
	for view: Dictionary in VIEWS:
		var b := _toggle(str(view.label), view.id == _view)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.set_meta("view", view.id)
		b.pressed.connect(_set_view.bind(str(view.id)))
		_tabs.add_child(b)
	column.add_child(_tabs)
	_count = Label.new()
	_count.add_theme_color_override("font_color", Tokens.MUTED)
	column.add_child(_count)
	_filters = HFlowContainer.new()
	_filters.add_theme_constant_override("h_separation", Tokens.SPACE_S)
	_filters.add_theme_constant_override("v_separation", Tokens.SPACE_S)
	column.add_child(_filters)

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


## Voltar sai de um site para a lista de sites; senão fecha a central.
func _back() -> void:
	if _view == "sites" and not _site.is_empty():
		_site = ""
		_render()
	else:
		close()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_inside_tree():
		get_viewport().set_input_as_handled()
		_back()


func _toggle(text: String, pressed: bool) -> Button:
	var b := Button.new()
	b.text = text.to_upper()
	b.toggle_mode = true
	b.button_pressed = pressed
	b.custom_minimum_size.y = Tokens.TOUCH_MIN
	b.add_theme_font_size_override("font_size", Tokens.FONT_SMALL)
	return b


func _set_view(id: String) -> void:
	_view = id
	_filter = "all"
	_site = ""
	_shown = PAGE
	for b: Button in _tabs.get_children():
		b.button_pressed = b.get_meta("view") == id
	_render()


func _set_filter(id: String) -> void:
	_filter = id
	_shown = PAGE
	_render()


func _open_site(id: String) -> void:
	_site = id
	_shown = PAGE
	_render()


func _items() -> Array:
	var w := Game.world
	var items: Array = w.news.values().filter(func(n: NewsItem):
		if _view == "social":
			return n.channel == "social" and (_filter != "mine" or Media.involves_player(w, n))
		if n.channel != "site":
			return false
		if _view == "sites":
			return n.outlet_id == _site
		if _filter == "mine":
			return Media.involves_player(w, n)
		return _filter == "all" or n.category == _filter)
	items.reverse()
	return items


func _render() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	for c in _filters.get_children():
		_filters.remove_child(c)
		c.queue_free()
	var w := Game.world
	_count.text = "%d publicações · %d novas" % [w.news.size(), Media.unread_count(w)]
	if _view == "sites" and _site.is_empty():
		_render_directory()
		return
	var options: Array = [{"id": "all", "label": "Tudo"}, {"id": "mine", "label": "Minha organização"}]
	if _view == "news":
		options.append_array(Media.config().categories)
	if _view != "sites":
		for option: Dictionary in options:
			var b := _toggle(str(option.label), option.id == _filter)
			b.pressed.connect(_set_filter.bind(str(option.id)))
			_filters.add_child(b)
	else:
		var site := Media.outlet(_site)
		_add_label(_list, str(site.get("domain", "")).to_upper(), Tokens.MUTED)
		var name := _add_label(_list, str(site.name), Tokens.INK)
		name.add_theme_font_override("font", Tokens.DISPLAY_FONT)
		name.add_theme_font_size_override("font_size", Tokens.FONT_TITLE)
		_add_label(_list, "%s %s" % [site.get("tagline", ""), site.get("tone", "")], Tokens.MUTED)
		_list.add_child(HSeparator.new())
	var items := _items()
	if items.is_empty():
		_add_label(_list, "Nada publicado aqui ainda. Tudo nasce dos fatos: cards anunciados, resultados, contratos e rankings.", Tokens.MUTED)
	var seen: Array = []
	for n: NewsItem in items.slice(0, _shown):
		_list.add_child(_post(w, n) if n.channel == "social" else _article(n))
		seen.append(n.id)
	if items.size() > _shown:
		var more := Button.new()
		more.text = "Mais (%d)" % (items.size() - _shown)
		more.custom_minimum_size.y = Tokens.TOUCH_MIN
		more.pressed.connect(func():
			_shown += PAGE
			_render())
		_list.add_child(more)
	Media.mark_read(w, seen)


func _render_directory() -> void:
	var w := Game.world
	for o: Dictionary in ContentDB.load_json("media_outlets.json"):
		var total := 0
		var unread := 0
		for n: NewsItem in w.news.values():
			if n.channel == "site" and n.outlet_id == o.id:
				total += 1
				if not n.read:
					unread += 1
		var b := Button.new()
		b.text = "%s\n%s · %d matérias%s" % [o.name, o.domain, total, " · %d novas" % unread if unread > 0 else ""]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size.y = Tokens.TOUCH_MIN + Tokens.SPACE_L
		b.pressed.connect(_open_site.bind(str(o.id)))
		_list.add_child(b)
		_add_label(_list, str(o.tone), Tokens.MUTED)


func _article(n: NewsItem) -> VBoxContainer:
	var labels: Array = Media.config().importance_labels
	var row := _row()
	var meta := "%s · %s · %s" % [Media.outlet(n.outlet_id).name.to_upper(), GameDate.format(n.created_at), str(labels[clampi(n.importance, 0, labels.size() - 1)]).to_upper()]
	_add_label(row, ("NOVA · " if not n.read else "") + meta, Tokens.INK if not n.read else Tokens.MUTED).add_theme_font_size_override("font_size", Tokens.FONT_SMALL)
	var headline := _add_label(row, n.headline, Tokens.INK)
	if n.importance >= 3:
		headline.add_theme_font_override("font", Tokens.DISPLAY_FONT)
		headline.add_theme_font_size_override("font_size", 32)
	if not n.body.is_empty():
		_add_label(row, n.body, Tokens.MUTED)
	row.add_child(HSeparator.new())
	return row


func _post(w: WorldState, n: NewsItem) -> VBoxContainer:
	var row := _row()
	var author := _add_label(row, "%s  %s" % [Media.author_name(w, n.author_id), Media.handle(w, n.author_id)], Tokens.INK)
	author.add_theme_font_override("font", Tokens.DISPLAY_FONT)
	author.add_theme_font_size_override("font_size", Tokens.FONT_SMALL)
	_add_label(row, n.headline, Tokens.INK)
	_add_label(row, "%s%s · %s curtidas · %s compartilhamentos" % ["NOVO · " if not n.read else "", GameDate.format(n.created_at), Media.compact(n.reach), Media.compact(n.reach / 9)], Tokens.MUTED).add_theme_font_size_override("font_size", Tokens.FONT_SMALL)
	row.add_child(HSeparator.new())
	return row


func _row() -> VBoxContainer:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", Tokens.SPACE_XS)
	return row


func _add_label(parent: Control, text: String, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l
