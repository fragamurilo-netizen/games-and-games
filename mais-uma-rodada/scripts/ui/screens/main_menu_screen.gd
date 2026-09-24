extends BaseScreen
## Menu inicial: continuar a última carreira em um toque, ou começar outra.


func _init() -> void:
	show_top = false
	show_nav = false


func refresh() -> void:
	var c := content()
	UIKit.clear(c)
	c.add_child(UIKit.gap(90))
	var logo := UIKit.vbox(0)
	logo.alignment = BoxContainer.ALIGNMENT_CENTER
	var icon := UIKit.icon_rect("ball", 96, UIColors.ACCENT)
	logo.add_child(icon)
	var l1 := UIKit.label("MAIS UMA", "Logo")
	l1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l1.add_theme_color_override(&"font_color", UIColors.TEXT)
	logo.add_child(l1)
	var l2 := UIKit.label("RODADA", "Logo")
	l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.add_child(l2)
	var tag := UIKit.label("Gestão de futebol. Só mais uma rodada.", "Muted")
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.add_child(tag)
	c.add_child(logo)
	c.add_child(UIKit.gap(70))
	var latest := SaveManager.latest_slot()
	if latest > 0:
		var meta := SaveManager.read_meta(latest)
		var cont := UIKit.button("CONTINUAR", "PrimaryButton", func(): _load(latest), "play")
		cont.custom_minimum_size.y = 104
		c.add_child(cont)
		var info := UIKit.label("%s · temporada %d · rodada %d" % [meta.get("short", meta.get("club", "")), int(meta.get("year", 0)), int(meta.get("round", 0))], "Muted")
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c.add_child(info)
		c.add_child(UIKit.gap(10))
	var new_btn := UIKit.button("NOVA CARREIRA", "PrimaryButton" if latest <= 0 else "", func(): UIManager.push("new_career"), "plus")
	new_btn.custom_minimum_size.y = 96 if latest <= 0 else 84
	c.add_child(new_btn)
	c.add_child(UIKit.button("Carregar jogo", "", func(): UIManager.push("load"), "save"))
	c.add_child(UIKit.button("Editor", "", func(): UIManager.push("editor"), "shield"))
	c.add_child(UIKit.button("Opções", "GhostButton", func(): UIManager.push("settings"), "gear"))
	c.add_child(UIKit.gap(40))
	var ver := UIKit.label("versão %s" % ProjectSettings.get_setting("application/config/version", "0.1.0"), "Small")
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(ver)


func _load(slot: int) -> void:
	if GameManager.load_career(slot):
		AudioManager.play("whistle", -6.0)
		UIManager.goto("hub")
	else:
		UIManager.info("Não foi possível carregar", "O arquivo do slot %d parece corrompido." % slot)
