extends BaseScreen
## Opções do aparelho: aparência (claro/escuro, tamanho), idioma, música e som, vibração,
## velocidade padrão das partidas, dicas e créditos.


func _init() -> void:
	show_nav = false
	screen_title = "Opções"


func refresh() -> void:
	screen_subtitle = "Valem para todas as carreiras"
	UIManager.refresh_chrome()
	var c := content()
	UIKit.clear(c)
	var cl := UIKit.card("Card", 12)
	cl.add_child(UIKit.section("Aparência"))
	cl.add_child(UIKit.label("Tema", "Muted"))
	cl.add_child(_chips(AppSettings.THEME_NAMES, AppSettings.theme_mode, func(i: int):
		AppSettings.theme_mode = i
		AppSettings.save_settings()
		UIManager.apply_look()))
	cl.add_child(UIKit.label("Claro e escuro têm contraste alto para ler no sol ou à noite. \"Do aparelho\" segue o modo do celular.", "Small", true))
	cl.add_child(_toggle("Interface nas cores do meu clube", AppSettings.team_colors, func(v: bool):
		AppSettings.team_colors = v
		AppSettings.save_settings()
		UIManager.refresh_chrome()
		refresh()))
	cl.add_child(UIKit.label("Tamanho da interface", "Muted"))
	cl.add_child(_chips(AppSettings.UI_SCALE_NAMES, AppSettings.ui_scale, func(i: int):
		AppSettings.ui_scale = i
		AppSettings.save_settings()
		UIManager.apply_look()))
	cl.add_child(_toggle("Animações reduzidas", AppSettings.reduce_motion, func(v: bool):
		AppSettings.reduce_motion = v
		AppSettings.save_settings()))
	cl.add_child(UIKit.label("Telas sem deslizar e comemorações de gol curtas.", "Small", true))
	c.add_child(UIKit.card_panel(cl))
	var card0 := UIKit.card("Card", 12)
	card0.add_child(UIKit.section("Idioma"))
	var lg := ButtonGroup.new()
	var lrow := UIKit.hbox(8)
	for i in I18n.LANGS.size():
		var code := I18n.LANGS[i]
		var lchip := UIKit.chip(I18n.LANG_NAMES[i], code == AppSettings.language, lg, func():
			if code == AppSettings.language:
				return
			AppSettings.language = code
			AppSettings.save_settings()
			I18n.apply(code)
			refresh.call_deferred())
		# O nome de cada idioma aparece sempre na própria língua.
		lchip.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		UIKit.shrink_button(lchip)
		lrow.add_child(lchip)
	card0.add_child(lrow)
	c.add_child(UIKit.card_panel(card0))
	var card_ed := UIKit.card("Card", 12)
	card_ed.add_child(UIKit.section("Editor"))
	card_ed.add_child(_toggle("Editar jogadores e clubes durante a carreira", AppSettings.career_edit, func(v: bool):
		AppSettings.career_edit = v
		AppSettings.save_settings()
		refresh()))
	card_ed.add_child(UIKit.label("Desligado, a carreira fica sem atalhos: o botão Editar some dos perfis e o editor dentro da carreira só mexe no visual do seu clube. O Editor do menu inicial sempre edita o mundo padrão das novas carreiras.", "Small", true))
	c.add_child(UIKit.card_panel(card_ed))
	var cm := UIKit.card("Card", 12)
	cm.add_child(UIKit.section("Música"))
	cm.add_child(_toggle("Música de fundo", AppSettings.music, func(v: bool):
		AppSettings.music = v
		AppSettings.save_settings()
		AudioManager.start_music()
		refresh()))
	if AppSettings.music:
		cm.add_child(UIKit.label("Faixa", "Muted"))
		cm.add_child(_chips(MusicSynth.TRACKS, AppSettings.music_track, func(i: int):
			AppSettings.music_track = i
			AppSettings.save_settings()
			if not AudioManager.music_ready(i):
				UIManager.toast("Compondo a faixa… começa em instantes.")
			AudioManager.start_music()))
		cm.add_child(_slider("Volume da música", AppSettings.music_volume, func(v: int):
			AppSettings.music_volume = v
			AudioManager.apply_volumes()
			AudioManager.start_music(), func(): AppSettings.save_settings()))
		cm.add_child(_toggle("Tocar também durante as partidas", AppSettings.music_in_match, func(v: bool):
			AppSettings.music_in_match = v
			AppSettings.save_settings()))
	cm.add_child(UIKit.label("As músicas são compostas e tocadas pelo próprio jogo, sem arquivos de terceiros.", "Small", true))
	c.add_child(UIKit.card_panel(cm))
	var card := UIKit.card("Card", 12)
	card.add_child(UIKit.section("Som e vibração"))
	card.add_child(_toggle("Efeitos sonoros e torcida", AppSettings.sound, func(v: bool):
		AppSettings.sound = v
		AppSettings.save_settings()
		if v:
			AudioManager.play("whistle", -6.0)
		refresh()))
	if AppSettings.sound:
		card.add_child(_slider("Volume dos efeitos", AppSettings.sfx_volume, func(v: int):
			AppSettings.sfx_volume = v
			AudioManager.apply_volumes(), func():
			AppSettings.save_settings()
			AudioManager.play("whistle", -6.0)))
	card.add_child(_toggle("Vibrar nos gols e cartões", AppSettings.vibration, func(v: bool):
		AppSettings.vibration = v
		AppSettings.save_settings()
		AudioManager.vibrate(60)))
	c.add_child(UIKit.card_panel(card))
	var card2 := UIKit.card("Card", 12)
	card2.add_child(UIKit.section("Partidas"))
	card2.add_child(UIKit.label("Velocidade padrão ao iniciar um jogo", "Muted"))
	var g := ButtonGroup.new()
	var row := UIKit.hbox(8)
	for i in 3:
		var idx := i
		var chip := UIKit.chip(AppSettings.SPEED_NAMES[i], i == AppSettings.match_speed, g, func():
			AppSettings.match_speed = idx
			AppSettings.save_settings())
		UIKit.shrink_button(chip)
		row.add_child(chip)
	card2.add_child(row)
	card2.add_child(UIKit.label("Dá para trocar durante a partida.", "Small", true))
	c.add_child(UIKit.card_panel(card2))
	var cs := UIKit.card("Card", 12)
	cs.add_child(UIKit.section("Compras"))
	if Store.owned or not Store.enforced():
		cs.add_child(UIKit.colored("Carreira Completa liberada. Obrigado!", UIColors.GREEN, "H3", true))
	else:
		cs.add_child(UIKit.label("Primeira temporada grátis. A Carreira Completa libera as temporadas seguintes e os mods, com pagamento único de %s." % Store.price(), "Small", true))
		cs.add_child(UIKit.button("Ver a Carreira Completa", "GhostButton", func(): UIManager.push("paywall", {"reason": "settings"}), "star"))
	cs.add_child(UIKit.button("Restaurar compras", "GhostButton", func(): Store.restore(), "save"))
	cs.add_child(UIKit.button("Pagar um café pro desenvolvedor · %s" % Store.price(Store.TIP), "GhostButton", func(): Store.buy(Store.TIP), "star"))
	c.add_child(UIKit.card_panel(cs))
	var card3 := UIKit.card("Card", 12)
	card3.add_child(UIKit.section("Ajuda"))
	card3.add_child(UIKit.button("Mostrar as dicas iniciais novamente", "GhostButton", func():
		AppSettings.tutorial_done = false
		AppSettings.save_settings()
		UIManager.toast("As dicas voltam a aparecer no início da carreira."), "info"))
	card3.add_child(UIKit.button("Como jogar", "GhostButton", func(): Tutorial.show_all(), "list"))
	card3.add_child(UIKit.button("Créditos", "GhostButton", func(): MainMenuScreen.show_credits(), "star"))
	c.add_child(UIKit.card_panel(card3))
	var card4 := UIKit.card("Card", 8)
	card4.add_child(UIKit.section("Sobre"))
	card4.add_child(UIKit.label("Mais Uma Rodada · versão %s" % ProjectSettings.get_setting("application/config/version", "0.1.0"), "H3"))
	card4.add_child(UIKit.label("Clubes, estádios e ligas usam os nomes reais apenas como referência, sem vínculo oficial. Todos os jogadores são fictícios.", "Small", true))
	card4.add_child(UIKit.label("Feito com Godot Engine (licença MIT). Fontes Barlow e Barlow Condensed, de Jeremy Tribby, sob a SIL Open Font License 1.1. Escudos, uniformes, rostos e sons são gerados pelo próprio jogo.", "Small", true))
	card4.add_child(UIKit.label("Tudo roda offline e o jogo não coleta dados. As compras são processadas pela Google Play.", "Small", true))
	c.add_child(UIKit.card_panel(card4))


## Fileira de opções exclusivas (chips); `cb` recebe o índice escolhido.
func _chips(names: Array, selected: int, cb: Callable) -> HBoxContainer:
	var g := ButtonGroup.new()
	var row := UIKit.hbox(8)
	for i in names.size():
		var idx := i
		var chip := UIKit.chip(String(names[i]), i == selected, g, func(): cb.call(idx))
		UIKit.shrink_button(chip)
		row.add_child(chip)
	return row


## Controle deslizante de 0 a 100 com o valor ao lado. `on_change` roda enquanto arrasta;
## `on_done` quando solta (salvar).
func _slider(text: String, value: int, on_change: Callable, on_done: Callable) -> VBoxContainer:
	var box := VBoxContainer.new()
	var head := UIKit.hbox(8)
	var l := UIKit.label(text, "Muted")
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(l)
	var val := UIKit.label("%d%%" % value, "H3")
	head.add_child(val)
	box.add_child(head)
	var sl := HSlider.new()
	sl.min_value = 0
	sl.max_value = 100
	sl.step = 5
	sl.value = value
	sl.custom_minimum_size.y = 48
	sl.focus_mode = Control.FOCUS_NONE
	sl.value_changed.connect(func(v: float):
		val.text = "%d%%" % int(v)
		on_change.call(int(v)))
	sl.drag_ended.connect(func(_c: bool): on_done.call())
	box.add_child(sl)
	return box


func _toggle(text: String, value: bool, cb: Callable) -> CheckButton:
	var t := CheckButton.new()
	t.text = text
	t.button_pressed = value
	t.focus_mode = Control.FOCUS_NONE
	t.custom_minimum_size.y = 64
	t.toggled.connect(func(v: bool):
		AudioManager.click()
		cb.call(v))
	return t
