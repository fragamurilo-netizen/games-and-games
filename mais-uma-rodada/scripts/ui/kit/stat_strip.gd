class_name StatStrip
extends RefCounted
## Faixa de números como no grafismo de transmissão: valor em cima (condensada), rótulo
## embaixo, separados por um filete vertical. Não é um card por métrica (DESIGN.md): é uma
## linha só, que cabe dentro de um objeto (cabeçalho de jogador, bloco de jogo).
## items: [[rótulo, valor, cor do valor], ...]


static func make(items: Array) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override(&"separation", 0)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in items.size():
		var it: Array = items[i]
		if i > 0:
			var sep := ColorRect.new()
			sep.color = UIColors.LINE
			sep.custom_minimum_size = Vector2(1, 44)
			sep.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
			h.add_child(sep)
		var v := VBoxContainer.new()
		v.add_theme_constant_override(&"separation", -4)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var val := UIKit.label(String(it[1]), "Section")
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		val.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		if it.size() > 2:
			val.add_theme_color_override(&"font_color", it[2])
		v.add_child(val)
		var cap := UIKit.label(String(it[0]), "Caps")
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		v.add_child(cap)
		h.add_child(v)
	return h
