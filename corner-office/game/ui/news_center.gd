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
var _open := ""          # id da notícia aberta em tela cheia
var _lightbox: Control
var _scroll: ScrollContainer


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
	_scroll = scroll
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", Tokens.SPACE_M)
	scroll.add_child(_list)
	_render()


func close() -> void:
	Game.save_game("autosave")
	closed.emit()
	queue_free()


## Voltar fecha a foto ampliada, depois a notícia aberta, depois o site;
## só então fecha a central.
func _back() -> void:
	if _lightbox:
		_lightbox.queue_free()
		_lightbox = null
	elif not _open.is_empty():
		_open = ""
		_render()
	elif _view == "sites" and not _site.is_empty():
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
	_open = ""
	_view = id
	_filter = "all"
	_site = ""
	_shown = PAGE
	for b: Button in _tabs.get_children():
		b.button_pressed = b.get_meta("view") == id
	_render()


func _set_filter(id: String) -> void:
	_open = ""
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
	_scroll.scroll_vertical = 0
	if not _open.is_empty() and w.news.has(_open):
		_render_detail(w, w.news[_open])
		return
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


func _article(n: NewsItem) -> Control:
	var w := Game.world
	var labels: Array = Media.config().importance_labels
	var row := _row()
	var text := _row()
	var meta := "%s · %s · %s" % [Media.outlet(n.outlet_id).name.to_upper(), GameDate.format(n.created_at), str(labels[clampi(n.importance, 0, labels.size() - 1)]).to_upper()]
	_add_label(text, ("NOVA · " if not n.read else "") + meta, Tokens.INK if not n.read else Tokens.MUTED).add_theme_font_size_override("font_size", Tokens.FONT_SMALL)
	var headline := _add_label(text, n.headline, Tokens.INK)
	if n.importance >= 3:
		headline.add_theme_font_override("font", Tokens.DISPLAY_FONT)
		headline.add_theme_font_size_override("font_size", 32)
		row.add_child(_photo(w, n, Vector2(0, 300)))
		row.add_child(text)
	else:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", Tokens.SPACE_M)
		line.mouse_filter = MOUSE_FILTER_PASS
		line.add_child(_photo(w, n, Vector2(150, 150)))
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(text)
		row.add_child(line)
	if not n.body.is_empty() and n.importance >= 3:
		_add_label(text, n.body, Tokens.MUTED)
	row.add_child(HSeparator.new())
	_tappable(row, n.id)
	return row


const PHOTO_POSTS := ["social_org_announce", "social_win", "social_callout", "social_signing", "social_number_one"]


func _post(w: WorldState, n: NewsItem) -> Control:
	var row := _row()
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", Tokens.SPACE_S)
	head.mouse_filter = MOUSE_FILTER_PASS
	var avatar := _avatar(w, n.author_id)
	if avatar:
		head.add_child(avatar)
	var author := _add_label(head, "%s\n%s" % [Media.author_name(w, n.author_id), Media.handle(w, n.author_id)], Tokens.INK)
	author.add_theme_font_override("font", Tokens.DISPLAY_FONT)
	author.add_theme_font_size_override("font_size", Tokens.FONT_SMALL)
	author.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(head)
	_add_label(row, n.headline, Tokens.INK)
	if n.topic in PHOTO_POSTS:
		row.add_child(_photo(w, n, Vector2(0, 280)))
	_add_label(row, "%s%s · %s curtidas · %s compartilhamentos" % ["NOVO · " if not n.read else "", GameDate.format(n.created_at), Media.compact(n.reach), Media.compact(n.reach / 9)], Tokens.MUTED).add_theme_font_size_override("font_size", Tokens.FONT_SMALL)
	row.add_child(HSeparator.new())
	_tappable(row, n.id)
	return row


## Avatar redondo-quadrado do autor: rosto do atleta, ou nada para contas
## de organização e torcida (o nome e o @ bastam).
func _avatar(w: WorldState, author_id: String) -> Control:
	if not w.fighters.has(author_id):
		return null
	var stub := NewsItem.new()
	stub.entity_ids = [author_id]
	var p := NewsPhoto.make(w, stub, Vector2(64, 64))
	p.mouse_filter = MOUSE_FILTER_IGNORE
	return p


func _photo(w: WorldState, n: NewsItem, box: Vector2) -> NewsPhoto:
	var p := NewsPhoto.make(w, n, box)
	p.opened.connect(_open_item.bind(n.id))
	return p


func _tappable(row: Control, id: String) -> void:
	row.mouse_filter = MOUSE_FILTER_PASS
	var press := [Vector2.INF]
	row.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				press[0] = e.position
			elif press[0] != Vector2.INF and e.position.distance_to(press[0]) < NewsPhoto.TAP_SLOP:
				press[0] = Vector2.INF
				_open_item(id))


func _open_item(id: String) -> void:
	if _open == id:
		_show_lightbox(Game.world.news[id])
		return
	_open = id
	_render()


## Notícia aberta: foto grande (toque amplia), texto completo, quem está
## envolvido e o que mais saiu sobre essas mesmas pessoas e noites.
func _render_detail(w: WorldState, n: NewsItem) -> void:
	var close_button := Button.new()
	close_button.text = "← VOLTAR À LISTA"
	close_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	close_button.custom_minimum_size.y = Tokens.TOUCH_MIN
	close_button.pressed.connect(_back)
	_list.add_child(close_button)
	var social := n.channel == "social"
	var source: String = "%s %s" % [Media.author_name(w, n.author_id), Media.handle(w, n.author_id)] if social else Media.outlet(n.outlet_id).name
	_add_label(_list, "%s · %s" % [source.to_upper(), GameDate.format(n.created_at)], Tokens.MUTED).add_theme_font_size_override("font_size", Tokens.FONT_SMALL)
	var photo := _photo(w, n, Vector2(0, 420))
	_list.add_child(photo)
	_add_label(_list, photo.caption() + " · toque para ampliar", Tokens.MUTED).add_theme_font_size_override("font_size", Tokens.FONT_SMALL)
	var headline := _add_label(_list, n.headline, Tokens.INK)
	if not social:
		headline.add_theme_font_override("font", Tokens.DISPLAY_FONT)
		headline.add_theme_font_size_override("font_size", 34)
	if not n.body.is_empty():
		_add_label(_list, n.body, Tokens.INK)
	if social:
		_add_label(_list, "%s curtidas · %s compartilhamentos" % [Media.compact(n.reach), Media.compact(n.reach / 9)], Tokens.MUTED)
	var people: Array = n.entity_ids.filter(func(id: String): return w.fighters.has(id))
	if not people.is_empty():
		_list.add_child(HSeparator.new())
		_add_label(_list, "ENVOLVIDOS", Tokens.MUTED).add_theme_font_size_override("font_size", Tokens.FONT_SMALL)
		for id: String in people:
			var f: Fighter = w.fighters[id]
			var org: Organization = w.organizations.get(f.organization_id)
			var line := HBoxContainer.new()
			line.add_theme_constant_override("separation", Tokens.SPACE_S)
			line.add_child(_avatar(w, id))
			_add_label(line, "%s  %s\n%s · %s · %s" % [f.display_name(), Media.handle(w, id), f.record_string(), Media.division_name(f.division), org.name if org else "Agente livre"], Tokens.INK).size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_list.add_child(line)
	var related := Media.related(w, n, 6)
	if not related.is_empty():
		_list.add_child(HSeparator.new())
		_add_label(_list, "RELACIONADAS", Tokens.MUTED).add_theme_font_size_override("font_size", Tokens.FONT_SMALL)
		for r: NewsItem in related:
			_list.add_child(_post(w, r) if r.channel == "social" else _article(r))
	Media.mark_read(w, [n.id])


## Foto em tela cheia com legenda; toque ou voltar fecha.
func _show_lightbox(n: NewsItem) -> void:
	if _lightbox:
		_lightbox.queue_free()
	var box := ColorRect.new()
	box.color = Tokens.CANVAS
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", Tokens.SPACE_S)
	box.add_child(column)
	var photo := NewsPhoto.make(Game.world, n, Vector2.ZERO)
	photo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	photo.opened.connect(_back)
	column.add_child(photo)
	var caption := _add_label(column, photo.caption(), Tokens.INK)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hint := _add_label(column, "Toque na foto para fechar", Tokens.MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.custom_minimum_size.y = Tokens.TOUCH_MIN
	add_child(box)
	_lightbox = box


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
