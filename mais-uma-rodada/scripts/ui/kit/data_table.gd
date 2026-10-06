class_name DataTable
extends VBoxContainer
## Tabela de dados de verdade: cabeçalho que ordena, números alinhados à direita com algarismos
## de largura fixa, coluna do nome presa à esquerda enquanto as de números rolam para o lado
## quando não cabem, e linhas finas separadas por filete. Listas longas (mercado com milhares de
## nomes) são desenhadas aos poucos: as primeiras linhas e um "mostrar mais".
##
## Colunas: [{key, title, w, align ("l"/"c"/"r"), text: Callable(item) -> String,
##   color: Callable(item) -> Color, cell: Callable(item) -> Control, sort: Callable(item) -> Variant,
##   tip: String}]
## A primeira coluna é a presa (nome); use `cell` para montar escudo/foto + nome.

signal row_pressed(item: Variant)
signal sort_changed(key: String, desc: bool)

const ROW_H := 76
const HEAD_H := 52
const PAGE := 80
## Respiro entre colunas de números.
const GAP := 12

var _layout_fit: Callable
var columns: Array = []
var items: Array = []
## Estado que a tela guarda entre reconstruções: {"sort": key, "desc": bool, "shown": int}.
var state: Dictionary = {}
var lead_width := 300.0
## Largura mínima da coluna do nome: abaixo disso as colunas de números rolam para o lado.
var lead_min := 220.0
var row_height := ROW_H
var zebra := false
## Item destacado (o clube do usuário na classificação, o jogador aberto no painel lateral).
var highlight: Callable = Callable()
## Filete colorido à esquerda da linha (zona da tabela, lesionado...). Color(0,0,0,0) = nenhum.
var marker: Callable = Callable()

static var _tnum: FontVariation = null


## Fonte com algarismos tabulares: colunas de números alinham casa a casa.
static func tabular_font() -> Font:
	if _tnum == null:
		_tnum = FontVariation.new()
		_tnum.base_font = ThemeDB.get_project_theme().get_font(&"font", &"Label") if ThemeDB.get_project_theme() != null else ThemeDB.fallback_font
		# Nested variations otherwise fall back to the variable font's default (Thin).
		if _tnum.base_font is FontVariation:
			var source := _tnum.base_font as FontVariation
			_tnum.variation_opentype = source.variation_opentype.duplicate()
			_tnum.spacing_top = source.spacing_top
			_tnum.spacing_bottom = source.spacing_bottom
		_tnum.opentype_features = {"tnum": 1, "lnum": 1}
	return _tnum


func _init() -> void:
	add_theme_constant_override(&"separation", 0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func setup(cols: Array, rows: Array, st: Dictionary = {}) -> DataTable:
	columns = cols
	items = rows
	state = st
	_apply_sort()
	_build()
	return self


func _apply_sort() -> void:
	var key := String(state.get("sort", ""))
	if key == "":
		return
	var col := _col(key)
	if col.is_empty():
		return
	var f: Callable = col.get("sort", col.get("text", Callable()))
	if not f.is_valid():
		return
	var desc := bool(state.get("desc", true))
	var keyed: Array = []
	for i in items.size():
		keyed.append([f.call(items[i]), i, items[i]])
	keyed.sort_custom(func(a: Array, b: Array) -> bool:
		if a[0] == b[0]:
			return a[1] < b[1]
		if typeof(a[0]) == TYPE_STRING or typeof(b[0]) == TYPE_STRING:
			return (String(a[0]).naturalnocasecmp_to(String(b[0])) > 0) == desc
		return (a[0] > b[0]) == desc)
	items = keyed.map(func(k: Array) -> Variant: return k[2])


func _col(key: String) -> Dictionary:
	for c: Dictionary in columns:
		if String(c.get("key", "")) == key:
			return c
	return {}


func _build() -> void:
	if _layout_fit.is_valid() and resized.is_connected(_layout_fit):
		resized.disconnect(_layout_fit)
	for ch in get_children():
		remove_child(ch)
		ch.queue_free()
	if columns.is_empty():
		return
	# Faixa fina acima do cabeçalho: mostra que há mais colunas para o lado e onde o dedo está.
	var hint_row := HBoxContainer.new()
	hint_row.add_theme_constant_override(&"separation", 0)
	hint_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_row.visible = false
	add_child(hint_row)
	var hint_gap := Control.new()
	hint_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_row.add_child(hint_gap)
	var hint := ScrollHint.new()
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint_row.add_child(hint)
	var body := HBoxContainer.new()
	body.add_theme_constant_override(&"separation", 0)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(body)
	# Coluna presa (nome) e bloco das colunas de números, que rola para o lado se precisar.
	var lead := VBoxContainer.new()
	lead.add_theme_constant_override(&"separation", 0)
	lead.custom_minimum_size.x = lead_width
	body.add_child(lead)
	var sc := ScrollContainer.new()
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.follow_focus = false
	body.add_child(sc)
	var grid := VBoxContainer.new()
	grid.add_theme_constant_override(&"separation", 0)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(grid)
	var num_w := 0.0
	for c: Dictionary in columns.slice(1):
		num_w += float(c.get("w", 72)) + GAP
	grid.custom_minimum_size.x = num_w
	# O nome tem largura mínima fixa; se sobrar espaço além dos números, o nome fica com ele.
	# Os números nunca empurram a tela para os lados: rolam dentro do próprio bloco.
	var lead_ref: WeakRef = weakref(lead)
	var sc_ref: WeakRef = weakref(sc)
	var fit := func():
		var cell: Control = lead_ref.get_ref()
		if cell != null and size.x > 0.0:
			# O nome cede espaço até lead_min antes de os números começarem a rolar para o lado.
			cell.custom_minimum_size.x = maxf(minf(lead_width, lead_min), size.x - num_w)
			hint_gap.custom_minimum_size.x = cell.custom_minimum_size.x
			var over := num_w > size.x - cell.custom_minimum_size.x + 1.0
			hint_row.visible = over
			var s2: ScrollContainer = sc_ref.get_ref()
			if over and s2 != null and int(state.get("hx", 0)) > 0:
				(func(): if is_instance_valid(s2): s2.scroll_horizontal = int(state.get("hx", 0))).call_deferred()
	_layout_fit = fit
	resized.connect(fit)
	fit.call_deferred()
	hint.track(sc, num_w)
	sc.get_h_scroll_bar().value_changed.connect(func(v: float): state["hx"] = int(v))
	lead.add_child(_head_cell(columns[0], true))
	grid.add_child(_head_row())
	var shown := mini(items.size(), maxi(PAGE, int(state.get("shown", PAGE))))
	for i in shown:
		_add_row(lead, grid, items[i], i)
	if shown < items.size():
		var more := UIKit.button("Mostrar mais %d de %d" % [mini(PAGE, items.size() - shown), items.size() - shown], "TextButton", func():
			state["shown"] = shown + PAGE
			_build())
		more.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		add_child(more)


func _head_row() -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override(&"separation", GAP)
	h.custom_minimum_size.y = HEAD_H
	for c: Dictionary in columns.slice(1):
		h.add_child(_head_cell(c, false))
	return h


func _head_cell(c: Dictionary, lead: bool) -> Control:
	var key := String(c.get("key", ""))
	var sortable: bool = c.has("sort") or c.has("text")
	var cur := String(state.get("sort", "")) == key
	var b := Button.new()
	b.theme_type_variation = "TableHead"
	b.focus_mode = Control.FOCUS_NONE
	b.flat = true
	b.clip_text = true
	var arrow := ("↓" if bool(state.get("desc", true)) else "↑") if cur else ""
	b.text = String(c.get("title", "")) + ((" " + arrow) if arrow != "" else "")
	b.tooltip_text = String(c.get("tip", ""))
	b.alignment = _align(String(c.get("align", "l" if lead else "r")))
	b.custom_minimum_size = Vector2(0.0 if lead else float(c.get("w", 72)), HEAD_H)
	if lead:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_color_override(&"font_color", UIColors.TEXT if cur else UIColors.DIM)
	if sortable and key != "":
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.pressed.connect(func():
			Sfx.click()
			if cur:
				state["desc"] = not bool(state.get("desc", true))
			else:
				state["sort"] = key
				state["desc"] = String(c.get("first", "desc")) == "desc"
			state["shown"] = PAGE
			sort_changed.emit(key, bool(state["desc"]))
			_apply_sort()
			_build())
	else:
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func _align(a: String) -> HorizontalAlignment:
	match a:
		"c":
			return HORIZONTAL_ALIGNMENT_CENTER
		"r":
			return HORIZONTAL_ALIGNMENT_RIGHT
	return HORIZONTAL_ALIGNMENT_LEFT


func _add_row(lead: VBoxContainer, grid: VBoxContainer, item: Variant, i: int) -> void:
	var hl := highlight.is_valid() and bool(highlight.call(item))
	var mk: Color = marker.call(item) if marker.is_valid() else Color(0, 0, 0, 0)
	var left := _row_panel(hl, zebra and i % 2 == 1, mk)
	var cell0 := _cell(columns[0], item, true)
	left.add_child(cell0)
	lead.add_child(left)
	var right := _row_panel(hl, zebra and i % 2 == 1, Color(0, 0, 0, 0))
	var h := HBoxContainer.new()
	h.add_theme_constant_override(&"separation", GAP)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c: Dictionary in columns.slice(1):
		h.add_child(_cell(c, item, false))
	right.add_child(h)
	grid.add_child(right)
	for p: PanelContainer in [left, right]:
		var tap := Button.new()
		tap.theme_type_variation = "RowOverlay"
		tap.focus_mode = Control.FOCUS_NONE
		tap.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tap.pressed.connect(func():
			Sfx.click()
			row_pressed.emit(item))
		UIKit.attach_row_overlay(p,tap)


func _row_panel(hl: bool, alt: bool, mk: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size.y = row_height
	var box := StyleBoxFlat.new()
	box.bg_color = UIColors.SURFACE_3 if hl else (Color(UIColors.SURFACE, 0.6) if alt else Color(0, 0, 0, 0))
	box.border_color = UITokens.HAIRLINE if not UIColors.light else UIColors.LINE
	box.border_width_bottom = 1
	if mk.a > 0.0:
		box.border_width_left = 3
		box.border_color = mk
		box.border_width_bottom = 0
	box.content_margin_left = 6
	box.content_margin_right = 4
	p.add_theme_stylebox_override(&"panel", box)
	if mk.a > 0.0:
		# O filete da esquerda não pode tingir a linha de baixo: desenhada à parte.
		var line := ColorRect.new()
		line.color = UITokens.HAIRLINE if not UIColors.light else UIColors.LINE
		line.custom_minimum_size.y = 1
		line.size_flags_vertical = Control.SIZE_SHRINK_END
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(line)
	return p


func _cell(c: Dictionary, item: Variant, lead: bool) -> Control:
	var w := float(c.get("w", 72))
	if c.has("cell"):
		var ctl: Control = (c["cell"] as Callable).call(item)
		# Tudo dentro da célula (retrato, selos, nome) deixa o toque passar para a linha: o botão
		# da linha fica atrás do conteúdo, e um retrato que segura o toque fazia o nome "não clicar".
		ctl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UIKit._ignore_mouse(ctl)
		if not lead:
			ctl.custom_minimum_size.x = maxf(ctl.custom_minimum_size.x, w)
		else:
			ctl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ctl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		return ctl
	var l := Label.new()
	l.text = String((c["text"] as Callable).call(item)) if c.has("text") else ""
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.horizontal_alignment = _align(String(c.get("align", "l" if lead else "r")))
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.clip_text = true
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if lead:
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		l.custom_minimum_size.x = w
		l.add_theme_font_override(&"font", tabular_font())
	if c.has("color"):
		l.add_theme_color_override(&"font_color", (c["color"] as Callable).call(item))
	if bool(c.get("strong", false)):
		l.add_theme_font_override(&"font", ThemeDB.get_project_theme().get_font(&"font", &"H3"))
	return l


## Trilho de 3 px com a parte visível das colunas em destaque. Só aparece quando os números
## não cabem: é o sinal de que dá para passar o dedo para o lado.
class ScrollHint extends Control:
	var _sc: ScrollContainer
	var _total := 0.0

	func _init() -> void:
		custom_minimum_size.y = 3
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func track(sc: ScrollContainer, total: float) -> void:
		_sc = sc
		_total = total
		sc.get_h_scroll_bar().value_changed.connect(func(_v: float): queue_redraw())
		sc.resized.connect(queue_redraw)

	func _draw() -> void:
		if _sc == null or not is_instance_valid(_sc) or _total <= 0.0:
			return
		draw_rect(Rect2(0, 0, size.x, size.y), UITokens.HAIRLINE if not UIColors.light else UIColors.LINE)
		var vis := clampf(_sc.size.x / _total, 0.08, 1.0)
		var span := maxf(1.0, _total - _sc.size.x)
		var t := clampf(float(_sc.scroll_horizontal) / span, 0.0, 1.0)
		var w := size.x * vis
		draw_rect(Rect2((size.x - w) * t, 0, w, size.y), UIColors.DIM)
