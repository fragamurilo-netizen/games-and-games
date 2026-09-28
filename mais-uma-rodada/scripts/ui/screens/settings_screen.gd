extends BaseScreen
## Opções do aparelho: aparência (claro/escuro, tamanho), idioma, música e som, vibração,
## velocidade padrão das partidas, dicas e créditos.


func _init() -> void:
	show_nav = false
	screen_title = "Opções"


func refresh() -> void:
	screen_subtitle = ""
	UIManager.refresh_chrome()
	var c := content()
	UIKit.clear(c)
	max_content_width = 1600.0
	var cards: Array = []
	var cl := UIKit.card("Card", 12)
	cl.add_child(UIKit.section("Aparência"))
	cl.add_child(UIKit.label("Tema", "Muted"))
	cl.add_child(_chips(AppSettings.THEME_NAMES, AppSettings.theme_mode, func(i: int):
		AppSettings.theme_mode = i
		AppSettings.save_settings()
		UIManager.apply_look()))
	cl.add_child(UIKit.label("Cores da interface", "Muted"))
	cl.add_child(_chips(AppSettings.COLOR_SOURCE_NAMES, AppSettings.color_source, func(i: int):
		AppSettings.color_source = i
		AppSettings.team_colors = i != 0
		AppSettings.save_settings()
		UIManager.apply_look()))
	cl.add_child(UIKit.label("Cor no fundo e nos menus", "Muted"))
	cl.add_child(_chips(AppSettings.TINT_NAMES, AppSettings.bg_tint, func(i: int):
		AppSettings.bg_tint = i
		AppSettings.save_settings()
		UIManager.apply_look()))
	cl.add_child(UIKit.label("Tamanho da interface", "Muted"))
	cl.add_child(_chips(AppSettings.UI_SCALE_NAMES, AppSettings.ui_scale, func(i: int):
		AppSettings.ui_scale = i
		AppSettings.save_settings()
		UIManager.apply_look()))
	cl.add_child(_toggle("Animações reduzidas", AppSettings.reduce_motion, func(v: bool):
		AppSettings.reduce_motion = v
		AppSettings.save_settings()))
	cards.append(UIKit.card_panel(cl))
	var card0 := UIKit.card("Card", 12)
	card0.add_child(UIKit.section("Idioma"))
	var lrow := _chips(I18n.LANG_NAMES, I18n.LANGS.find(AppSettings.language), func(i: int):
		var code := I18n.LANGS[i]
		if code == AppSettings.language:
			return
		AppSettings.language = code
		AppSettings.save_settings()
		I18n.apply(code)
		refresh.call_deferred())
	# O nome de cada idioma aparece sempre na própria língua.
	for b in lrow.find_children("*", "Button", true, false):
		(b as Button).auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	card0.add_child(lrow)
	cards.append(UIKit.card_panel(card0))
	var currency_card := UIKit.card("Card", 12)
	currency_card.add_child(UIKit.section("Moeda"))
	currency_card.add_child(UIKit.label("Valores de mercado, salários e finanças", "Muted"))
	currency_card.add_child(_chips(AppSettings.CURRENCY_NAMES, AppSettings.currency, func(i: int):
		AppSettings.currency = i
		AppSettings.save_settings()
		refresh()))
	cards.append(UIKit.card_panel(currency_card))
	var card_ed := UIKit.card("Card", 12)
	card_ed.add_child(UIKit.section("Editor"))
	card_ed.add_child(_toggle("Editar jogadores e clubes durante a carreira", AppSettings.career_edit, func(v: bool):
		AppSettings.career_edit = v
		AppSettings.save_settings()
		refresh()))
	cards.append(UIKit.card_panel(card_ed))
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
	cards.append(UIKit.card_panel(cm))
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
	cards.append(UIKit.card_panel(card))
	var card2 := UIKit.card("Card", 12)
	card2.add_child(UIKit.section("Partidas"))
	card2.add_child(UIKit.label("Velocidade padrão ao iniciar um jogo", "Muted"))
	var row := _chips(AppSettings.SPEED_NAMES, AppSettings.match_speed, func(i: int):
		AppSettings.match_speed = i
		AppSettings.save_settings())
	card2.add_child(row)
	cards.append(UIKit.card_panel(card2))
	var cs := UIKit.card("Card", 12)
	cs.add_child(UIKit.section("Compras"))
	if Store.owned or not Store.enforced():
		cs.add_child(UIKit.colored("Carreira Completa liberada. Obrigado!", UIColors.GREEN, "H3", true))
	else:
		cs.add_child(UIKit.label("Carreira Completa · %s" % Store.price(), "Small", true))
		cs.add_child(UIKit.button("Ver a Carreira Completa", "GhostButton", func(): UIManager.push("paywall", {"reason": "settings"}), "star"))
	cs.add_child(UIKit.menu_group([
		UIKit.menu_row("save", "Restaurar compras", "", func(): Store.restore()),
		UIKit.menu_row("star", "Pagar um café pro desenvolvedor · %s" % Store.price(Store.TIP), "", func(): Store.buy(Store.TIP)),
	]))
	cards.append(UIKit.card_panel(cs))
	var card3 := UIKit.card("Card", 12)
	card3.add_child(UIKit.section("Ajuda"))
	card3.add_child(UIKit.menu_group([
		UIKit.menu_row("info", "Mostrar as dicas iniciais novamente", "", func():
			AppSettings.tutorial_done = false
			AppSettings.save_settings()
			UIManager.toast("As dicas voltam a aparecer no início da carreira.")),
		UIKit.menu_row("list", "Como jogar", "", func(): Tutorial.show_all()),
		UIKit.menu_row("star", "Créditos", "", func(): MainMenuScreen.show_credits()),
	]))
	cards.append(UIKit.card_panel(card3))
	var card4 := UIKit.card("Card", 8)
	card4.add_child(UIKit.section("Sobre"))
	card4.add_child(UIKit.label("Mais Uma Rodada · versão %s" % ProjectSettings.get_setting("application/config/version", "0.1.0"), "H3"))
	card4.add_child(UIKit.label("Clubes, estádios e ligas usam os nomes reais apenas como referência, sem vínculo oficial. Todos os jogadores são fictícios.", "Small", true))
	card4.add_child(UIKit.label("Feito com Godot Engine (licença MIT). Fontes Barlow e Barlow Condensed, de Jeremy Tribby, sob a SIL Open Font License 1.1. Escudos, uniformes, rostos e sons são gerados pelo próprio jogo.", "Small", true))
	card4.add_child(UIKit.label("Tudo roda offline e o jogo não coleta dados. As compras são processadas pela Google Play.", "Small", true))
	cards.append(UIKit.card_panel(card4))
	UIKit.columns(c, cards, content_width())


## Fileira de opções exclusivas (chips); `cb` recebe o índice escolhido.
func _chips(names: Array, selected: int, cb: Callable) -> Control:
	var items: Array = []
	for i in names.size():
		items.append([str(i), String(names[i])])
	return UIKit.segment(items, str(selected), func(k: String): cb.call(int(k)))


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
