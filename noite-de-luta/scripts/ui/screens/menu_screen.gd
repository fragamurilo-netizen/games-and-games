extends BaseScreen
## Tela inicial: a marca sob a luz da arena, continuar a carreira salva, começar outra, opções e
## créditos. Na primeira vez que aparece depois de o app abrir, a abertura passa por cima.

## A abertura só toca uma vez por vez que o app abre.
static var opened := false

var _back: BrandBackdrop
var _logo: BrandLogo


func setup(p: Dictionary) -> void:
	super.setup(p)
	show_top = false
	show_nav = false
	_back = BrandBackdrop.new()
	_back.strength = 0.6
	add_child(_back)
	move_child(_back, 0)
	scroll().resized.connect(_fit_height)


func on_show() -> void:
	super.on_show()
	if opened:
		return
	opened = true
	if not AppSettings.intro or not Anim.on() or UIManager.main == null:
		return
	var intro := IntroOverlay.new()
	UIManager.main.modal_host.add_child(intro)
	# Os cartões do menu entram de novo quando a abertura começa a sair.
	intro.leaving.connect(func():
		intro_pending = true
		play_intro())


func refresh() -> void:
	var c := reset()
	c.add_theme_constant_override(&"separation", UITokens.S4)
	var view := UILayout.viewport
	var wide := UILayout.is_landscape()
	var actions := _actions()
	if wide:
		# Deitado: a marca de um lado, os botões do outro.
		var short := UILayout.is_short()
		_logo = BrandLogo.new(170.0 if short else 300.0, 88 if short else 150)
		var left := UIKit.vbox(UITokens.S6)
		left.alignment = BoxContainer.ALIGNMENT_CENTER
		left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left.add_child(_logo)
		if not short:
			left.add_child(_faces(190))
		actions.custom_minimum_size.x = 460.0 if short else 600.0
		actions.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var row := UIKit.hbox(UITokens.S8)
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		row.add_child(left)
		row.add_child(actions)
		c.add_child(row)
	else:
		# Em pé: a marca em cima, os rostos no meio e os botões embaixo. Em tela curta o
		# emblema encolhe para tudo caber sem rolar.
		var tall := view.y >= 1200.0
		var big := view.x >= 900.0
		_logo = BrandLogo.new(320.0 if big else (236.0 if tall else 150.0), 160 if big else (128 if tall else 96))
		if not tall:
			c.add_theme_constant_override(&"separation", UITokens.S2)
		c.add_child(UIKit.gap(UITokens.S6 if tall else UITokens.S1))
		c.add_child(_logo)
		c.add_child(_stretch())
		c.add_child(_faces(230 if big else (176 if tall else 148)))
		c.add_child(_stretch())
		c.add_child(actions)
	_logo.resized.connect(_aim, CONNECT_DEFERRED)
	_fit_height.call_deferred()
	_aim.call_deferred()


func _stretch() -> Control:
	var s := Control.new()
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return s


## O conteúdo ocupa pelo menos a altura da tela, para os botões assentarem embaixo.
func _fit_height() -> void:
	var sc := scroll()
	var c := content()
	if sc == null or c == null or _margin_node == null:
		return
	var pad := _margin_node.get_theme_constant(&"margin_top") + _margin_node.get_theme_constant(&"margin_bottom")
	c.custom_minimum_size.y = maxf(0.0, sc.size.y - pad)


## A luz de fundo mira no emblema.
func _aim() -> void:
	if not is_instance_valid(_logo) or not is_instance_valid(_back) or size.x < 1.0 or size.y < 1.0:
		return
	var p := _logo.emblem.get_global_rect().get_center() - get_global_rect().position
	_back.focus = p / size


## Três lutadores sob a luz do octógono: a cara do jogo antes de qualquer menu.
func _faces(px: int) -> Control:
	var row := UIKit.hbox(UITokens.S2)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var seeds := [[90210, 7, 27, {"wt": 0.55}], [4471, 1, 31, {"wt": 0.85}], [31337, 4, 25, {"wt": 0.3, "fem": 1}]]
	for sd: Array in seeds:
		var v := PortraitView.new()
		v.custom_minimum_size = Vector2(px, px)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.set_face(int(sd[0]), int(sd[1]), int(sd[2]), sd[3])
		row.add_child(v)
	return row


func _actions() -> VBoxContainer:
	var box := UIKit.vbox(UITokens.S2)
	if GameManager.has_save():
		var meta := GameManager.save_summary()
		box.add_child(UIKit.button("Continuar", "PrimaryButton", func():
			# Carreira longa leva um instante para abrir em celular fraco: o aviso aparece antes.
			await UIManager.busy("Abrindo a carreira…")
			if GameManager.load_save():
				UIManager.goto("hub")
				UIManager.busy_done()
			else:
				UIManager.busy_done()
				UIManager.toast("Não foi possível abrir o save.", UIColors.RED)))
		if not meta.is_empty():
			var info := UIKit.label("%s · semana de %s · caixa %s" % [String(meta.get("team", "")), String(meta.get("date", "")), Fmt.money(float(meta.get("balance", 0.0)))], "Small", true)
			info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			box.add_child(info)
	box.add_child(UIKit.button("Nova carreira", "GhostButton" if GameManager.has_save() else "PrimaryButton", func():
		if GameManager.has_save():
			UIManager.confirm("Começar do zero?", "A carreira salva será apagada quando a nova carreira começar.", "Começar nova", func(): UIManager.push("new_career"))
		else:
			UIManager.push("new_career")))
	var row := UIKit.hbox(UITokens.S2)
	for item: Array in [["Opções", "settings"], ["Créditos", "credits"]]:
		var b := UIKit.button(String(item[0]), "GhostButton", func(): UIManager.push(String(item[1])))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	box.add_child(row)
	box.add_child(UIKit.gap(UITokens.S1))
	var foot := UIKit.label("Universo fictício. Nenhum lutador, equipe ou organização real.", "Meta", true)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(foot)
	var ver := UIKit.label("Versão %s" % GameManager.app_version(), "Meta")
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(ver)
	return box
