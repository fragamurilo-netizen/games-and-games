extends BaseScreen
## Opções do aparelho: idioma, som, vibração, velocidade padrão das partidas, dicas e créditos.


func _init() -> void:
	show_nav = false
	screen_title = "Opções"


func refresh() -> void:
	screen_subtitle = "Valem para todas as carreiras"
	UIManager.refresh_chrome()
	var c := content()
	UIKit.clear(c)
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
		lchip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lrow.add_child(lchip)
	card0.add_child(lrow)
	c.add_child(UIKit.card_panel(card0))
	var card := UIKit.card("Card", 12)
	card.add_child(UIKit.section("Som e vibração"))
	card.add_child(_toggle("Efeitos sonoros e torcida", AppSettings.sound, func(v: bool):
		AppSettings.sound = v
		AppSettings.save_settings()
		if v:
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
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(chip)
	card2.add_child(row)
	card2.add_child(UIKit.label("Instantâneo mostra só o resultado. Rápido leva cerca de meio minuto; Normal, uns dois minutos, com narração completa. Durante a partida dá para trocar a qualquer momento.", "Small", true))
	c.add_child(UIKit.card_panel(card2))
	var card3 := UIKit.card("Card", 12)
	card3.add_child(UIKit.section("Ajuda"))
	card3.add_child(UIKit.button("Mostrar as dicas iniciais novamente", "GhostButton", func():
		AppSettings.tutorial_done = false
		AppSettings.save_settings()
		UIManager.toast("As dicas voltam a aparecer no início da carreira."), "info"))
	card3.add_child(UIKit.button("Como jogar", "GhostButton", func(): Tutorial.show_all(), "list"))
	c.add_child(UIKit.card_panel(card3))
	var card4 := UIKit.card("Card", 8)
	card4.add_child(UIKit.section("Sobre"))
	card4.add_child(UIKit.label("Mais Uma Rodada · versão %s" % ProjectSettings.get_setting("application/config/version", "0.1.0"), "H3"))
	card4.add_child(UIKit.label("Clubes, estádios e ligas usam os nomes reais apenas como referência, sem vínculo oficial. Todos os jogadores são fictícios.", "Small", true))
	card4.add_child(UIKit.label("Feito com Godot Engine (licença MIT). Fontes Barlow e Barlow Condensed, de Jeremy Tribby, sob a SIL Open Font License 1.1. Escudos, uniformes, rostos e sons são gerados pelo próprio jogo.", "Small", true))
	card4.add_child(UIKit.label("Tudo roda offline; nenhum dado sai do aparelho.", "Small", true))
	c.add_child(UIKit.card_panel(card4))


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
