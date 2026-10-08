extends BaseScreen
## Menu inicial: continuar a carreira salva, fundar uma academia nova, opções.


func setup(p: Dictionary) -> void:
	super.setup(p)
	show_top = false
	show_nav = false


func refresh() -> void:
	var c := reset()
	c.add_theme_constant_override(&"separation", UITokens.S4)
	c.add_child(UIKit.gap(UITokens.S6))
	# Três lutadores sob a luz do octógono: a cara do jogo antes de qualquer menu.
	var row := UIKit.hbox(UITokens.S2)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var seeds := [[90210, 7, 27, {"wt": 0.55}], [4471, 1, 31, {"wt": 0.85}], [31337, 4, 25, {"wt": 0.3, "fem": 1}]]
	for sd: Array in seeds:
		var v := PortraitView.new()
		v.custom_minimum_size = Vector2(164, 164)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.set_face(int(sd[0]), int(sd[1]), int(sd[2]), sd[3])
		row.add_child(v)
	c.add_child(row)
	var title := UIKit.label("Noite de Luta", "Display")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(title)
	var sub := UIKit.label("Você é o empresário. Monte a equipe, escolha as lutas, trace o plano e leve alguém até o cinturão.", "Muted", true)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(sub)
	c.add_child(UIKit.gap(UITokens.S4))
	var box := UIKit.vbox(UITokens.S2)
	if GameManager.has_save():
		var meta := GameManager.save_summary()
		var cont := UIKit.button("Continuar", "PrimaryButton", func():
			if GameManager.load_save():
				UIManager.goto("hub")
			else:
				UIManager.toast("Não foi possível abrir o save.", UIColors.RED))
		box.add_child(cont)
		if not meta.is_empty():
			var info := UIKit.label("%s · semana de %s · caixa %s" % [String(meta.get("team", "")), String(meta.get("date", "")), Fmt.money(float(meta.get("balance", 0.0)))], "Small", true)
			info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			box.add_child(info)
	box.add_child(UIKit.button("Nova carreira", "GhostButton" if GameManager.has_save() else "PrimaryButton", func():
		if GameManager.has_save():
			UIManager.confirm("Começar do zero?", "A carreira salva será apagada quando a nova academia for fundada.", "Começar nova", func(): UIManager.push("new_career"))
		else:
			UIManager.push("new_career")))
	box.add_child(UIKit.button("Opções", "GhostButton", func(): UIManager.push("settings")))
	c.add_child(box)
	var foot := UIKit.label("Universo fictício. Nenhum lutador, equipe ou organização real.", "Meta", true)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(UIKit.gap(UITokens.S4))
	c.add_child(foot)
