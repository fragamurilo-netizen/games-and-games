extends BaseScreen
## Créditos: a marca, a versão, quem assina (data/credits.json), do que o jogo é feito (com as
## licenças, que a Godot e a fonte pedem que acompanhem o jogo), o aviso de universo fictício e
## a nota de privacidade.

const DATA := "res://data/credits.json"


func setup(p: Dictionary) -> void:
	super.setup(p)
	screen_title = "Créditos"
	show_nav = false
	max_content_width = 820.0


static func signature() -> Array:
	var out: Array = []
	var f := FileAccess.open(DATA, FileAccess.READ)
	if f == null:
		return out
	var d: Variant = JSON.parse_string(f.get_as_text())
	if not (d is Dictionary):
		return out
	for line: Variant in (d as Dictionary).get("assinatura", []):
		if line is Array and (line as Array).size() >= 2 and String(line[1]).strip_edges() != "":
			out.append([String(line[0]), String(line[1]).strip_edges()])
	return out


func refresh() -> void:
	var c := reset()
	c.add_child(UIKit.gap(UITokens.S2))
	c.add_child(BrandLogo.new(150.0, 96))
	var ver := UIKit.label("Versão %s" % GameManager.app_version(), "Muted")
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(ver)

	var game := UIKit.card()
	game.add_child(UIKit.section("O jogo"))
	game.add_child(UIKit.label("Noite de Luta é um jogo de gestão de MMA. Como empresário, você monta uma equipe e leva seus lutadores até o cinturão. Como presidente, você comanda a liga: monta os eventos, negocia a TV e responde aos sócios.", "Muted", true))
	for line: Array in signature():
		game.add_child(UIKit.kv(String(line[0]), String(line[1])))
	c.add_child(UIKit.card_panel(game))

	c.add_child(UIKit.section_header("Feito com"))
	c.add_child(UIKit.menu_group([
		UIKit.menu_row("gear", "Godot Engine %s" % _engine_version(), "Motor do jogo. Licença MIT.", func(): UIManager.push("licenses", {"doc": "godot"})),
		UIKit.menu_row("book", "Saira", "Fonte de Omnibus-Type. SIL Open Font License 1.1.", func(): UIManager.push("licenses", {"doc": "saira"})),
		UIKit.menu_row("archive", "Componentes da Godot", "Avisos de direitos autorais e licenças de terceiros.", func(): UIManager.push("licenses")),
	]))

	var fic := UIKit.card()
	fic.add_child(UIKit.section("Universo fictício"))
	fic.add_child(UIKit.label("Todos os lutadores, equipes, ligas e eventos são inventados. Qualquer semelhança com pessoas ou organizações reais é coincidência.", "Muted", true))
	c.add_child(UIKit.card_panel(fic))

	var priv := UIKit.card()
	priv.add_child(UIKit.section("Privacidade"))
	priv.add_child(UIKit.label("O jogo funciona sem internet, não tem anúncios e não coleta nenhum dado. A carreira fica guardada no seu aparelho.", "Muted", true))
	c.add_child(UIKit.card_panel(priv))

	var bye := UIKit.label("Obrigado por jogar.", "Muted")
	bye.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(bye)


static func _engine_version() -> String:
	var v := Engine.get_version_info()
	return "%d.%d.%d" % [int(v["major"]), int(v["minor"]), int(v["patch"])]
