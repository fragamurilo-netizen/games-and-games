class_name MainMenuScreen
extends BaseScreen
## Menu inicial: continuar a última carreira em um toque, ou começar outra.


const DEVELOPER := "Murilo Rodrigues"


func _init() -> void:
	show_top = false
	show_nav = false


func refresh() -> void:
	var c := content()
	UIKit.clear(c)
	c.add_child(UIKit.gap(60))
	var logo := UIKit.vbox(0)
	logo.alignment = BoxContainer.ALIGNMENT_CENTER
	var icon := TextureRect.new()
	icon.texture = load("res://icon.svg")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(176, 176)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo.add_child(icon)
	logo.add_child(UIKit.gap(10))
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
	c.add_child(UIKit.button("Editor e mods", "", func(): UIManager.push("editor"), "shield"))
	c.add_child(UIKit.button("Opções", "GhostButton", func(): UIManager.push("settings"), "gear"))
	c.add_child(UIKit.gap(40))
	var credit := UIKit.label("Desenvolvido por %s" % DEVELOPER, "Small")
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var credit_row := UIKit.tap_row(credit, show_credits, "CardFlat")
	c.add_child(credit_row)
	var ver := UIKit.label("versão %s" % ProjectSettings.get_setting("application/config/version", "0.1.0"), "Small")
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ver.add_theme_color_override(&"font_color", UIColors.DIM)
	c.add_child(ver)


## Créditos do jogo (também abertos pelas Opções).
static func show_credits() -> void:
	var v := UIKit.vbox(12)
	v.custom_minimum_size.x = 600
	var icon := TextureRect.new()
	icon.texture = load("res://icon.svg")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(120, 120)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(icon)
	var t := UIKit.label("Mais Uma Rodada", "Title")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	v.add_child(UIKit.section("Criação e desenvolvimento"))
	v.add_child(UIKit.label(DEVELOPER, "H2"))
	v.add_child(UIKit.label("Design de jogo, programação, simulação, interface e dados.", "Muted", true))
	v.add_child(UIKit.section("Tecnologia"))
	v.add_child(UIKit.label("Feito com Godot Engine (licença MIT). Fontes Barlow e Barlow Condensed, de Jeremy Tribby (SIL Open Font License 1.1).", "Small", true))
	v.add_child(UIKit.section("Aviso"))
	v.add_child(UIKit.label("Clubes, estádios e competições usam os nomes reais só como referência, sem vínculo oficial. Todos os jogadores são fictícios.", "Small", true))
	v.add_child(UIKit.label("versão %s" % ProjectSettings.get_setting("application/config/version", "0.1.0"), "Small"))
	v.add_child(UIKit.button("Fechar", "GhostButton", func(): UIManager.close_modal()))
	UIManager.show_modal(v, true)


func _load(slot: int) -> void:
	if GameManager.load_career(slot):
		AudioManager.play("whistle", -6.0)
		UIManager.goto("hub")
	else:
		UIManager.info("Não foi possível carregar", "O arquivo do slot %d parece corrompido." % slot)
