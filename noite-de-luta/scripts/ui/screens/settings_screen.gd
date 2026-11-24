extends BaseScreen
## Opções do aparelho (som, vibração, luta ao vivo, movimento). Com uma carreira aberta, as
## dicas das telas; no menu, o que fazer com a carreira salva. No fim, a versão e os créditos.

const VOLUMES := [[30, "Baixo"], [60, "Médio"], [100, "Alto"]]


func setup(p: Dictionary) -> void:
	super.setup(p)
	screen_title = "Opções"
	show_nav = false
	max_content_width = 820.0


func refresh() -> void:
	var c := reset()
	c.add_child(UIKit.section_header("Som"))
	var sound := UIKit.card()
	sound.add_child(_toggle("Efeitos sonoros", AppSettings.sound, func(on: bool):
		AppSettings.sound = on
		refresh.call_deferred()))
	if AppSettings.sound:
		sound.add_child(UIKit.label("Volume", "Muted"))
		var items: Array = []
		for v: Array in VOLUMES:
			items.append([str(v[0]), String(v[1])])
		sound.add_child(UIKit.segment(items, str(_volume_step()), func(k: String):
			AppSettings.sfx_volume = int(k)
			AppSettings.save_settings()
			Sfx.play("score")))
	sound.add_child(_toggle("Vibração", AppSettings.vibration, func(on: bool):
		AppSettings.vibration = on
		if on:
			Sfx.vibrate(30)))
	c.add_child(UIKit.card_panel(sound))

	c.add_child(UIKit.section_header("Luta ao vivo"))
	var fight := UIKit.card()
	fight.add_child(UIKit.label("Velocidade", "Muted"))
	var speeds: Array = []
	for i in AppSettings.FIGHT_SPEED_NAMES.size():
		speeds.append([str(i), AppSettings.FIGHT_SPEED_NAMES[i]])
	fight.add_child(UIKit.segment(speeds, str(AppSettings.fight_speed), func(k: String):
		AppSettings.fight_speed = int(k)
		AppSettings.save_settings()))
	fight.add_child(UIKit.label("Como assistir", "Muted"))
	var views: Array = []
	for i in AppSettings.FIGHT_VIEWS.size():
		views.append([AppSettings.FIGHT_VIEWS[i], AppSettings.FIGHT_VIEW_NAMES[i]])
	fight.add_child(UIKit.segment(views, AppSettings.fight_view, func(k: String):
		AppSettings.fight_view = k
		AppSettings.save_settings()))
	fight.add_child(UIKit.label("As duas escolhas também podem ser trocadas durante a luta.", "Meta", true))
	c.add_child(UIKit.card_panel(fight))

	c.add_child(UIKit.section_header("Tela"))
	var screen := UIKit.card()
	screen.add_child(_toggle("Menos animação", AppSettings.reduce_motion, func(on: bool): AppSettings.reduce_motion = on))
	screen.add_child(UIKit.label("Encurta as transições entre as telas e pula a abertura do jogo.", "Meta", true))
	c.add_child(UIKit.card_panel(screen))

	var w := world()
	if w != null:
		_career_help(c, w)
	else:
		_saved_career(c)

	c.add_child(UIKit.section_header("Sobre"))
	c.add_child(UIKit.menu_group([
		UIKit.menu_row("book", "Créditos e licenças", "Noite de Luta, versão %s" % GameManager.app_version(), func(): UIManager.push("credits")),
	]))


## O degrau de volume mais perto do valor guardado (saves de opções antigos tinham 90).
static func _volume_step() -> int:
	var best := int(VOLUMES[0][0])
	for v: Array in VOLUMES:
		if absi(int(v[0]) - AppSettings.sfx_volume) < absi(best - AppSettings.sfx_volume):
			best = int(v[0])
	return best


## Da carreira aberta: as dicas de primeira vez das telas e a saída para o menu.
func _career_help(c: VBoxContainer, w: GameWorld) -> void:
	c.add_child(UIKit.section_header("Ajuda nesta carreira"))
	var card := UIKit.card()
	var tips := CheckButton.new()
	tips.text = "Dicas na primeira visita a cada tela"
	tips.button_pressed = bool(w.tut.get("tips_on", false))
	tips.custom_minimum_size.y = UITokens.H_BUTTON
	tips.toggled.connect(func(v: bool):
		w.tut["tips_on"] = v
		GameManager.save_now())
	card.add_child(tips)
	card.add_child(UIKit.button("Mostrar todas as dicas de novo", "GhostButton", func():
		w.tut["tips"] = {}
		w.tut["tips_on"] = true
		GameManager.save_now()
		UIManager.toast("As dicas voltam a aparecer na próxima visita a cada tela.")
		refresh()))
	c.add_child(UIKit.card_panel(card))
	c.add_child(UIKit.section_header("Carreira"))
	c.add_child(UIKit.menu_group([
		UIKit.menu_row("home", "Sair para o menu", "O progresso é salvo sozinho.", func():
			GameManager.close_career()
			UIManager.goto("menu")),
	]))


## No menu: apagar a carreira salva e, se o jogo foi atualizado, voltar à cópia de antes.
func _saved_career(c: VBoxContainer) -> void:
	var rows: Array = []
	if GameManager.has_backup():
		var meta := GameManager.save_summary(GameManager.BACKUP_PATH)
		var what := "%s, semana de %s" % [String(meta.get("team", "")), String(meta.get("date", ""))] if not meta.is_empty() else "Guardada quando o jogo foi atualizado"
		rows.append(UIKit.menu_row("archive", "Voltar à cópia de antes da atualização", what, func():
			UIManager.confirm("Voltar à cópia guardada?", "A carreira salva hoje será trocada pela cópia de quando o jogo foi atualizado (%s). O que foi jogado depois se perde." % what, "Voltar à cópia", func():
				if GameManager.restore_backup():
					UIManager.toast("Cópia restaurada. Use Continuar no menu.", UIColors.GREEN)
				else:
					UIManager.toast("Não foi possível restaurar a cópia.", UIColors.RED)
				refresh())))
	if GameManager.has_save():
		var meta := GameManager.save_summary()
		var what := "%s, semana de %s" % [String(meta.get("team", "")), String(meta.get("date", ""))] if not meta.is_empty() else "A carreira salva neste aparelho"
		rows.append(UIKit.menu_row("close", "Apagar a carreira salva", what, func():
			UIManager.confirm("Apagar a carreira?", "%s será apagada deste aparelho. Não dá para desfazer." % what, "Apagar", func():
				GameManager.delete_save()
				UIManager.toast("Carreira apagada.")
				refresh())))
	if rows.is_empty():
		return
	c.add_child(UIKit.section_header("Carreira salva"))
	c.add_child(UIKit.menu_group(rows))


func _toggle(text: String, on: bool, cb: Callable) -> Control:
	var b := CheckButton.new()
	b.text = text
	b.button_pressed = on
	b.custom_minimum_size.y = UITokens.H_BUTTON
	b.toggled.connect(func(v: bool):
		cb.call(v)
		AppSettings.save_settings())
	return b
