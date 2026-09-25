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
		UIKit.shrink_button(lchip)
		lrow.add_child(lchip)
	card0.add_child(lrow)
	card0.add_child(_toggle("Interface nas cores do meu clube", AppSettings.team_colors, func(v: bool):
		AppSettings.team_colors = v
		AppSettings.save_settings()
		UIManager.refresh_chrome()
		refresh()))
	c.add_child(UIKit.card_panel(card0))
	var card_ed := UIKit.card("Card", 12)
	card_ed.add_child(UIKit.section("Editor"))
	card_ed.add_child(_toggle("Editar jogadores e clubes durante a carreira", AppSettings.career_edit, func(v: bool):
		AppSettings.career_edit = v
		AppSettings.save_settings()
		refresh()))
	card_ed.add_child(UIKit.label("Desligado, a carreira fica sem atalhos: o botão Editar some dos perfis e o editor dentro da carreira só mexe no visual do seu clube. O Editor do menu inicial sempre edita o mundo padrão das novas carreiras.", "Small", true))
	c.add_child(UIKit.card_panel(card_ed))
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
		UIKit.shrink_button(chip)
		row.add_child(chip)
	card2.add_child(row)
	card2.add_child(UIKit.label("Instantâneo mostra só o resultado. Rápido leva cerca de meio minuto; Normal, uns dois minutos, com narração completa. Durante a partida dá para trocar a qualquer momento.", "Small", true))
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
