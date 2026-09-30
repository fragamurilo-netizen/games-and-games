class_name Screen
extends MarginContainer
## Base das telas de aba. Subclasses sobrescrevem `title()` e `build()`.
## `refresh()` é chamado sempre que a aba fica visível.

var body: VBoxContainer
## Nome da aba, já exibido na placa do cabeçalho.
var tab_label:=""
var feedback:=""
var _working:=false


func _init() -> void:
	for side in ["left", "right", "top", "bottom"]:
		add_theme_constant_override("margin_" + side, Tokens.SPACE_M)
	var scroll := ScrollContainer.new()
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


func refresh() -> void:
	for c in body.get_children():
		body.remove_child(c)
		c.queue_free()
	if title().to_upper()!=tab_label.to_upper():add_heading(title())
	if not feedback.is_empty():add_text(feedback,Tokens.MUTED)
	build()


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
