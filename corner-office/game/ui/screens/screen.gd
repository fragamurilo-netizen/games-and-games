class_name Screen
extends MarginContainer
## Base das telas de aba. Subclasses sobrescrevem `title()` e `build()`.
## `refresh()` é chamado sempre que a aba fica visível.

var body: VBoxContainer


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
		c.queue_free()
	add_heading(title())
	build()


func add_heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", Tokens.FONT_TITLE)
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
