class_name Screen
extends MarginContainer
## Base das telas de aba. Subclasses sobrescrevem `title()` e `build()`.
## `refresh()` é chamado sempre que a aba fica visível.

## Pede à casca para abrir outra aba (ex.: tocar num atleta na Início).
signal navigate(tab: String, payload: Dictionary)

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


## Cabeçalho de seção em faixa inclinada com entalhe vermelho (Undisputed 3).
func add_heading(text: String) -> Label:
	var bar := PanelContainer.new()
	var box := Tokens.slanted_box(Tokens.SURFACE, 60)
	box.border_width_left = 10
	box.border_color = Tokens.FIGHT_RED
	box.content_margin_left += Tokens.SPACE_S
	bar.add_theme_stylebox_override("panel", box)
	var l := Label.new()
	l.text = text.to_upper()
	l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 34)
	l.add_theme_font_override("font",Tokens.italic_font())
	bar.add_child(l)
	body.add_child(bar)
	return l


## Cabeçalho que recolhe/expande a seção. Retorna false se a seção está fechada.
func add_section(text: String, open_by_default: bool=true) -> bool:
	var key:=text
	var is_open: bool=not collapsed.get(key,not open_by_default)
	var button:=Button.new();button.text=("▾  " if is_open else "▸  ")+text.to_upper()
	button.alignment=HORIZONTAL_ALIGNMENT_LEFT;button.custom_minimum_size.y=64
	button.add_theme_font_size_override("font_size",30)
	var box:=Tokens.slanted_box(Tokens.SURFACE,64);box.border_width_left=10;box.border_color=Tokens.FIGHT_RED
	for state in ["normal","hover","pressed","hover_pressed","focus"]:button.add_theme_stylebox_override(state,box)
	button.add_theme_color_override("font_hover_color",Tokens.INK)
	button.pressed.connect(func():collapsed[key]=is_open;refresh())
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
		var box:=Tokens.slanted_box(Color(Tokens.SURFACE,.94));box.border_width_left=6;box.border_color=side[2]
		b.add_theme_stylebox_override("normal",box)
		b.pressed.connect(side[1]);row.add_child(b)
	body.add_child(row)


func add_text(text: String, color: Color = Tokens.INK) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", color)
	body.add_child(l)
	return l


func add_todo(text: String) -> void:
	add_text("TODO — " + text, Tokens.MUTED)


func add_button(text: String, callback: Callable) -> Button:
	var button:=Button.new()
	# Itens de menu em caixa alta, alinhados à esquerda como em Undisputed 3.
	button.text=text.to_upper();button.alignment=HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size.y=Tokens.TOUCH_MIN
	button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	button.pressed.connect(callback);body.add_child(button)
	return button

func add_input(label: String, value: String="") -> LineEdit:
	add_text(label,Tokens.MUTED)
	var input:=LineEdit.new();input.text=value
	input.custom_minimum_size.y=Tokens.TOUCH_MIN;body.add_child(input)
	return input

func add_number(label: String, value: float, minimum: float, maximum: float) -> SpinBox:
	add_text(label,Tokens.MUTED)
	var input:=SpinBox.new();input.min_value=minimum;input.max_value=maximum;input.value=value
	input.custom_minimum_size.y=Tokens.TOUCH_MIN;body.add_child(input)
	return input

func add_select(label: String, options: Array, selected: String="") -> OptionButton:
	add_text(label,Tokens.MUTED)
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
