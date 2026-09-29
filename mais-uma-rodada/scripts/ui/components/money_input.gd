class_name MoneyInput
extends VBoxContainer
## Integers in the selected display currency; the economy remains euro-based.
signal amount_changed(value: int)
signal committed
var amount := 0
var valid := true
var minimum := 0
var edit: LineEdit
var error: Label
var _rate := 1.0


static func parse(text: String, rate: float, min_value: int = 0) -> int:
	var raw := text.strip_edges().replace(" ", "").replace("\u00a0", "")
	# Whole amounts only. Separators must form complete groups of three digits.
	var pattern := RegEx.new()
	pattern.compile("^(?:[0-9]+|[0-9]{1,3}(?:\\.[0-9]{3})+|[0-9]{1,3}(?:,[0-9]{3})+)$")
	if rate <= 0.0 or raw.length() > 18 or pattern.search(raw) == null:
		return -1
	var shown := raw.replace(".", "").replace(",", "").to_float()
	if shown > 100_000_000_000.0 * rate:
		return -1
	var result := int(round(shown / rate))
	return result if result >= min_value else -1


static func create(value: int, caption: String, step: int, min_value: int = 0) -> MoneyInput:
	var input := MoneyInput.new()
	input.amount = value
	input.minimum = min_value
	input._rate = Fmt.currency_rate()
	input.add_theme_constant_override(&"separation", UITokens.S1)
	var row := UIKit.hbox(UITokens.S1)
	input.add_child(row)
	row.add_child(UIKit.label(Fmt.currency_symbol(), "H3"))
	input.edit = LineEdit.new()
	input.edit.text = str(int(round(value * input._rate)))
	input.edit.placeholder_text = caption
	input.edit.tooltip_text = caption + " (" + Fmt.currency_symbol() + ")"
	input.edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	input.edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.edit.custom_minimum_size = Vector2(0, UITokens.H_BUTTON)
	input.edit.expand_to_text_length = false
	input.edit.max_length = 18
	input.edit.select_all_on_focus = true
	row.add_child(input.edit)
	for sign_value in [-1, 1]:
		var delta: int = sign_value * step
		row.add_child(UIKit.icon_button("minus" if sign_value < 0 else "plus", func():
			input.set_amount(maxi(input.minimum, input.amount + delta))
			input.committed.emit(), "Diminuir " + caption if sign_value < 0 else "Aumentar " + caption))
	input.error = UIKit.colored("Digite um valor inteiro, sem centavos.", UIColors.RED, "Small", true)
	input.error.visible = false
	input.add_child(input.error)
	input.edit.text_changed.connect(func(txt: String):
		var result := parse(txt, input._rate, input.minimum)
		input.valid = result >= 0
		input.error.visible = not input.valid
		if input.valid:
			input.amount = result
			input.amount_changed.emit(result))
	input.edit.text_submitted.connect(func(_txt: String):
		if input.valid:
			input.edit.release_focus()
			input.committed.emit())
	return input


func set_amount(value: int) -> void:
	amount = value
	valid = true
	edit.text = str(int(round(value * _rate)))
	error.visible = false
	amount_changed.emit(amount)
