class_name MainMenuScreen
extends BaseScreen
## Menu inicial: continuar a última carreira em um toque, ou começar outra.


const DEVELOPER := "Murilo Rodrigues"


func _init() -> void:
	show_top = false
	show_nav = false


func refresh() -> void:
	StadiumBackdrop.attach(self)
	var c := content()
	UIKit.clear(c)
	var wide := UILayout.is_wide()
	max_content_width = 1500.0 if wide else 720.0
	var logo := _logo(wide)
	var menu := _menu()
	if wide:
		# Paisagem/tablet: a marca à esquerda, o menu à direita.
		var row := UIKit.hbox(UITokens.S8)
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		logo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		logo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		menu.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(logo)
		row.add_child(menu)
		c.add_child(UIKit.gap(40))
		c.add_child(row)
	else:
		c.add_child(UIKit.gap(36))
		c.add_child(logo)
		c.add_child(UIKit.gap(28))
		c.add_child(menu)
	c.add_child(UIKit.gap(24))
	var credit := UIKit.label("Desenvolvido por %s · versão %s" % [DEVELOPER, ProjectSettings.get_setting("application/config/version", "0.1.0")], "Small")
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(UIKit.tap_row(credit, show_credits, "PanelContainer"))


func _logo(wide: bool) -> VBoxContainer:
	var logo := UIKit.vbox(0)
	logo.alignment = BoxContainer.ALIGNMENT_CENTER
	var icon := TextureRect.new()
	icon.texture = load("res://icon.svg")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(150, 150) if not wide else Vector2(200, 200)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo.add_child(icon)
	logo.add_child(UIKit.gap(8))
	var l1 := UIKit.label("MAIS UMA", "Logo")
	l1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l1.add_theme_color_override(&"font_color", UIColors.TEXT)
	logo.add_child(l1)
	var l2 := UIKit.label("RODADA", "Logo")
	l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.add_child(l2)
	var tag := UIKit.eyebrow("Gestão de futebol. Só mais uma rodada.", UIColors.MUTED)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.add_child(tag)
	return logo


## Continuar (a última carreira em destaque) e as outras ações em ladrilhos.
func _menu() -> VBoxContainer:
	var v := UIKit.vbox(UITokens.S3)
	var latest := SaveManager.latest_slot()
	if latest > 0:
		var meta := SaveManager.read_meta(latest)
		var card := UIKit.card("CardHighlight", 12)
		var row := UIKit.hbox(16)
		var crest := CrestView.new()
		crest.custom_minimum_size = Vector2(92, 92)
		crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cd: Variant = meta.get("crest", {})
		if cd is Dictionary and not cd.is_empty():
			crest.crest = cd
		row.add_child(crest)
		var col := UIKit.vbox(2)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		col.add_child(UIKit.eyebrow("Continuar carreira"))
		var nm := UIKit.label(String(meta.get("club", meta.get("short", ""))), "Title")
		nm.uppercase = true
		nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		col.add_child(nm)
		col.add_child(UIKit.label("%s · temporada %d · rodada %d" % [meta.get("division", meta.get("short", "")), int(meta.get("year", 0)), int(meta.get("round", 0))], "Small", true))
		if String(meta.get("manager", "")) != "":
			col.add_child(UIKit.label("Técnico: %s" % meta.get("manager", ""), "Small"))
		row.add_child(col)
		card.add_child(row)
		var cont := UIKit.button("CONTINUAR", "PrimaryButton", func(): _load(latest), "play")
		cont.custom_minimum_size.y = 96
		card.add_child(cont)
		v.add_child(UIKit.card_panel(card))
	var tiles: Array = [
		UIKit.action_tile("plus", "Nova carreira", "Escolha o país, o clube e comece", func(): UIManager.push("new_career"), latest <= 0),
		UIKit.action_tile("save", "Carregar jogo", "%d espaços de save" % SaveManager.SLOTS, func(): UIManager.push("load")),
		UIKit.action_tile("shield", "Editor e mods", "Escudos, nomes, ligas e fotos", func(): UIManager.push("editor")),
		UIKit.action_tile("gear", "Opções", "Idioma, tema, som e interface", func(): UIManager.push("settings")),
	]
	v.add_child(UIKit.tile_grid(tiles, 2))
	return v


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
