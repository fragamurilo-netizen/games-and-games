class_name StatStrip
extends RefCounted
## Faixa de números como no grafismo de transmissão: valor em cima (condensada), rótulo
## embaixo, separados por um filete vertical. Não é um card por métrica (DESIGN.md): é uma
## linha só, que cabe dentro de um objeto (cabeçalho de jogador, bloco de jogo).
## items: [[rótulo, valor, cor do valor, proporção, cor da barra], ...]. Com a proporção (0 a 1,
## opcional), uma barra fina embaixo do rótulo mostra o quanto do limite está usado (folha,
## vagas, elenco): o número diz quanto, a barra diz se está perto do teto.


static func make(items: Array) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override(&"separation", 0)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in items.size():
		var it: Array = items[i]
		if i > 0:
			var sep := ColorRect.new()
			sep.color = UIColors.LINE
			# 2 px: com a tela reduzida (canvas 600 num aparelho de 390 dp), 1 px some em alguns pontos.
			sep.custom_minimum_size = Vector2(2, 44)
			sep.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
			h.add_child(sep)
		var v := VBoxContainer.new()
		v.add_theme_constant_override(&"separation", -4)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Cinco ou mais valores numa linha de celular: fonte menor para "Excelente" caber.
		var val := UIKit.label(String(it[1]), "Section" if items.size() <= 4 else "H3")
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		val.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		if it.size() > 2:
			val.add_theme_color_override(&"font_color", it[2])
		v.add_child(val)
		var cap := UIKit.label(String(it[0]), "Caps")
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		v.add_child(cap)
		if it.size() > 3 and float(it[3]) >= 0.0:
			var gap := Control.new()
			gap.custom_minimum_size.y = 10
			gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			v.add_child(gap)
			var bar := UIKit.bar(clampf(float(it[3]), 0.0, 1.0), 1.0, it[4] if it.size() > 4 else UIColors.TEXT, 6)
			bar.custom_minimum_size.x = 72
			bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			v.add_child(bar)
		h.add_child(v)
	return h


## Cor da barra de um limite: tranquila, perto do teto, estourada.
static func load_color(ratio: float) -> Color:
	if ratio > 1.0:
		return UIColors.RED
	return UIColors.ORANGE if ratio > 0.9 else UIColors.GREEN
