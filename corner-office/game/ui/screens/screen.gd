class_name Screen
extends MarginContainer
## Base das telas de aba. Subclasses sobrescrevem `title()` e `build()`.
## `refresh()` é chamado sempre que a aba fica visível.

## Pede à casca para abrir outra aba (ex.: tocar num atleta na Início).
signal navigate(tab: String, payload: Dictionary)
## Texto da linha de descrição (faixa inferior) para o item em foco.
signal hint_changed(text: String)

var body: VBoxContainer
## Seções recolhidas pelo jogador; sobrevivem ao refresh.
var collapsed: Dictionary = {}
## Seção para onde rolar no próximo refresh (pedido vindo de outra aba ou do hub).
var focus_section:=""
var _scroll: ScrollContainer
var _focus_node: Control
## Rolagem a restaurar no próximo refresh (histórico do Voltar).
var pending_scroll:=-1
## Nome da aba, já exibido na placa do cabeçalho.
var tab_label:=""
var feedback:=""
var _working:=false


func _init() -> void:
	for side in ["left", "right", "top", "bottom"]:
		add_theme_constant_override("margin_" + side, Tokens.SPACE_M)
	var scroll := ScrollContainer.new()
	_scroll = scroll
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", Tokens.SPACE_S)
	scroll.add_child(body)


func title() -> String:
	return ""


func build() -> void:
	pass


## Descrição padrão da tela na faixa inferior; vazio usa a da área.
func hint() -> String:
	return ""


## Liga um controle à linha de descrição: tocar, passar o mouse ou focar mostra `text`.
func describe(control: Control, text: String) -> void:
	if text.is_empty():return
	control.mouse_entered.connect(func():hint_changed.emit(text))
	control.focus_entered.connect(func():hint_changed.emit(text))
	if control is BaseButton:control.button_down.connect(func():hint_changed.emit(text))


## Recebe o pedido de outra aba antes de ser mostrada (ver `navigate`).
func receive(_payload: Dictionary) -> void:
	pass


func refresh() -> void:
	for c in body.get_children():
		body.remove_child(c)
		c.queue_free()
	if title().to_upper()!=tab_label.to_upper():add_heading(title())
	if not feedback.is_empty():add_text(feedback,Tokens.MUTED)
	build()
	if _focus_node or pending_scroll>=0:_restore_scroll.call_deferred(_focus_node,pending_scroll)
	focus_section="";_focus_node=null;pending_scroll=-1


func _restore_scroll(node: Control, value: int) -> void:
	await get_tree().process_frame
	if is_instance_valid(node):_scroll.scroll_vertical=int(node.position.y)
	elif value>=0:_scroll.scroll_vertical=value


## Estado para o botão Voltar: o que `receive` precisa para reabrir esta tela
## como estava. Subclasses somam seus campos (atleta aberto, evento, modo).
func snapshot() -> Dictionary:
	return {"scroll":_scroll.scroll_vertical}


## Cabeçalho de seção: faixa cinza-escura com texto claro centralizado.
func add_heading(text: String) -> Label:
	var bar:=Ud3Chrome.header_bar(text,52)
	var l: Label=bar.get_child(0);l.add_theme_font_size_override("font_size",26)
	body.add_child(bar)
	return l


## Cabeçalho que recolhe/expande a seção. Retorna false se a seção está fechada.
func add_section(text: String, open_by_default: bool=true) -> bool:
	var key:=text
	var is_open: bool=not collapsed.get(key,not open_by_default)
	var button:=Button.new();button.text=("▾  " if is_open else "▸  ")+text.to_upper()
	button.alignment=HORIZONTAL_ALIGNMENT_CENTER;button.custom_minimum_size.y=56
	button.add_theme_font_size_override("font_size",24)
	var box:=Tokens.slanted_box(Tokens.HEADER_BAR,56);box.content_margin_top=4;box.content_margin_bottom=4
	var lit:=Tokens.slanted_box(Tokens.FIGHT_RED,56);lit.content_margin_top=4;lit.content_margin_bottom=4
	button.add_theme_stylebox_override("normal",box)
	for state in ["hover","pressed","hover_pressed","focus"]:button.add_theme_stylebox_override(state,lit)
	button.add_theme_color_override("font_color",Tokens.HEADER_TEXT)
	button.pressed.connect(func():collapsed[key]=is_open;refresh())
	describe(button,("Toque para recolher " if is_open else "Toque para abrir ")+text.to_lower()+".")
	body.add_child(button)
	if text==focus_section:_focus_node=button
	return is_open


func add_node(node: Control) -> Control:
	body.add_child(node);return node


func add_tiles(tiles: Array) -> void:
	body.add_child(StatWidgets.tile_row(tiles,get_viewport_rect().size.x))


func add_bar(label: String, value: float, maximum: float=100.0, text: String="", color: Color=Tokens.INK) -> void:
	body.add_child(StatWidgets.bar(label,value,maximum,text,color))


## Faixa de sub-abas em paralelogramo (ex.: Elenco / Ranking / WCI).
func add_segments(options: Array, selected: String, on_pick: Callable) -> void:
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",Tokens.SPACE_XS)
	for option: Dictionary in options:
		var b:=Button.new();b.text=str(option.label).to_upper();b.toggle_mode=true
		b.button_pressed=str(option.id)==selected;b.size_flags_horizontal=SIZE_EXPAND_FILL
		b.custom_minimum_size.y=Tokens.TOUCH_MIN-16;b.clip_text=true
		b.add_theme_font_size_override("font_size",Tokens.FONT_SMALL-2)
		b.pressed.connect(func():on_pick.call(option.id))
		row.add_child(b)
	body.add_child(row)


## Dois botões lado a lado: um confronto com cada atleta tocável.
func add_pair(left: String, on_left: Callable, right: String, on_right: Callable) -> void:
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",Tokens.SPACE_XS)
	for side in [[left,on_left,Tokens.FIGHT_RED],[right,on_right,Tokens.CORNER_BLUE]]:
		var b:=Button.new();b.text=str(side[0]).to_upper();b.size_flags_horizontal=SIZE_EXPAND_FILL
		b.custom_minimum_size.y=Tokens.TOUCH_MIN;b.clip_text=true;b.alignment=HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size",Tokens.FONT_SMALL)
		var box:=Tokens.flat_box(Color(Tokens.PANEL_ROW,.9),side[2],0);box.border_width_left=8;box.border_color=side[2]
		b.add_theme_stylebox_override("normal",box)
		b.pressed.connect(side[1]);row.add_child(b)
	body.add_child(row)


func add_text(text: String, color: Color = Tokens.INK) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Texto vai sobre painel claro: as cores de tela escura viram tinta escura.
	if color == Tokens.INK: color = Tokens.PANEL_INK
	elif color == Tokens.MUTED: color = Tokens.PANEL_MUTED
	l.add_theme_color_override("font_color", color)
	body.add_child(l)
	return l


func add_todo(text: String) -> void:
	add_text("TODO — " + text, Tokens.MUTED)


func add_button(text: String, callback: Callable, hint_text: String="") -> Button:
	var button:=Button.new()
	# Itens de menu em caixa alta, alinhados à esquerda como em Undisputed 3.
	button.text=text.to_upper();button.alignment=HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size.y=Tokens.TOUCH_MIN
	button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	button.pressed.connect(callback);body.add_child(button)
	describe(button,hint_text)
	return button

## Foto grande do lutador (perfil, contrato).
func add_portrait(f: Fighter, width: float = 176) -> FighterPortrait:
	var photo:=FighterPortrait.make(f,width);photo.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	body.add_child(photo);return photo

## Linha de lutador: foto + texto. Com callback vira botão.
func add_fighter_row(f: Fighter, text: String, callback: Callable = Callable()) -> HBoxContainer:
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",Tokens.SPACE_S)
	row.add_child(FighterPortrait.make(f,72))
	row.add_child(_row_label(text,callback,HORIZONTAL_ALIGNMENT_LEFT))
	body.add_child(row);return row

## Confronto: foto do corner vermelho, texto, foto do corner azul.
func add_face_off(red: Fighter, blue: Fighter, text: String, callback: Callable = Callable()) -> HBoxContainer:
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",Tokens.SPACE_S)
	row.add_child(FighterPortrait.make(red,72,Tokens.FIGHT_RED))
	row.add_child(_row_label(text,callback,HORIZONTAL_ALIGNMENT_CENTER))
	row.add_child(FighterPortrait.make(blue,72,Tokens.STEEL))
	body.add_child(row);return row

func _row_label(text: String, callback: Callable, align: HorizontalAlignment) -> Control:
	if callback.is_valid():
		var button:=Button.new();button.text=text;button.custom_minimum_size.y=Tokens.TOUCH_MIN
		button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		button.alignment=align;button.pressed.connect(callback);return button
	var l:=Label.new();l.text=text;l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal=Control.SIZE_EXPAND_FILL;l.horizontal_alignment=align;l.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	return l

## Rótulo de campo em azul e caixa alta, como as colunas das tabelas de 2012.
func add_label(text: String) -> Label:
	var l:=add_text(text.to_upper(),Tokens.TABLE_BLUE)
	l.add_theme_font_override("font",Tokens.DISPLAY_FONT);l.add_theme_font_size_override("font_size",18)
	return l

func add_input(label: String, value: String="") -> LineEdit:
	add_label(label)
	var input:=LineEdit.new();input.text=value
	input.custom_minimum_size.y=Tokens.TOUCH_MIN;body.add_child(input)
	return input

func add_number(label: String, value: float, minimum: float, maximum: float) -> SpinBox:
	add_label(label)
	var input:=SpinBox.new();input.min_value=minimum;input.max_value=maximum;input.value=value
	input.custom_minimum_size.y=Tokens.TOUCH_MIN;body.add_child(input)
	return input

func add_select(label: String, options: Array, selected: String="") -> OptionButton:
	add_label(label)
	var input:=OptionButton.new();input.custom_minimum_size.y=Tokens.TOUCH_MIN
	input.fit_to_longest_item=false;input.clip_text=true
	for option: Dictionary in options:
		input.add_item(str(option.label));input.set_item_metadata(input.item_count-1,option.id)
		if str(option.id)==selected:input.select(input.item_count-1)
	body.add_child(input);return input

func run_action(action: String, params: Dictionary={}) -> Dictionary:
	if _working:return {}
	_working=true;feedback="Atualizando a carreira…"
	for node in body.get_children():
		if node is BaseButton:node.disabled=true
	await get_tree().process_frame
	var result:=Game.perform_action(action,params)
	feedback=CareerText.result(result);_working=false
	return result
