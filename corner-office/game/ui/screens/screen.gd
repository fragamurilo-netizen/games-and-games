class_name Screen
extends MarginContainer
## Base das telas de aba. Subclasses sobrescrevem `title()` e `build()`.
## `refresh()` é chamado sempre que a aba fica visível.

var body: VBoxContainer
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
	add_heading(title())
	if not feedback.is_empty():add_text(feedback,Tokens.MUTED)
	build()


func add_heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", Tokens.FONT_TITLE)
	l.add_theme_font_override("font",Tokens.DISPLAY_FONT)
	body.add_child(l)
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
	button.text=text;button.custom_minimum_size.y=Tokens.TOUCH_MIN
	button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	button.pressed.connect(callback);body.add_child(button)
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
