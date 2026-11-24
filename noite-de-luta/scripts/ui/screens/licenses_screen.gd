extends BaseScreen
## Licenças. Sem parâmetro, a lista dos componentes que a Godot traz dentro dela (vem da própria
## engine: `Engine.get_copyright_info`). Com `component`, os avisos de um deles. Com `license`,
## o texto de uma licença. Com `doc`, o texto da licença da Godot ("godot") ou da fonte ("saira").

const SAIRA := "res://assets/fonts/OFL-Saira.txt"


func setup(p: Dictionary) -> void:
	super.setup(p)
	show_nav = false
	max_content_width = 820.0
	if p.has("doc"):
		screen_title = "Godot Engine" if String(p["doc"]) == "godot" else "Saira"
	elif p.has("license"):
		screen_title = String(p["license"])
	elif p.has("component"):
		screen_title = "Avisos"
	else:
		screen_title = "Componentes"


func refresh() -> void:
	var c := reset()
	if params.has("doc"):
		_doc(c, String(params["doc"]))
	elif params.has("license"):
		_text(c, String(Engine.get_license_info().get(String(params["license"]), "")))
	elif params.has("component"):
		_component(c, int(params["component"]))
	else:
		_list(c)


func _doc(c: VBoxContainer, which: String) -> void:
	if which == "godot":
		c.add_child(UIKit.label("Este jogo usa a Godot Engine, distribuída sob a licença MIT. O texto da licença, como ela pede, segue abaixo.", "Muted", true))
		_text(c, Engine.get_license_text())
		return
	c.add_child(UIKit.label("O jogo usa a fonte Saira, de Omnibus-Type, distribuída sob a SIL Open Font License 1.1. O texto da licença segue abaixo.", "Muted", true))
	var f := FileAccess.open(SAIRA, FileAccess.READ)
	_text(c, f.get_as_text() if f != null else "SIL Open Font License 1.1: https://openfontlicense.org")


## Texto longo de licença num cartão. Vai como veio (em inglês, sem tradução automática).
func _text(c: VBoxContainer, text: String) -> void:
	var card := UIKit.card()
	var l := UIKit.label(_reflow(text), "Small", true)
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	card.add_child(l)
	c.add_child(UIKit.card_panel(card))


## Os textos vêm quebrados a cada 80 letras; aqui as linhas de um parágrafo se juntam de novo e
## a tela quebra onde couber. Continuam em linha própria os itens de lista, o que vem depois
## de uma linha curta (títulos) e some o tracejado que separa as partes.
static func _reflow(text: String) -> String:
	var item := RegEx.create_from_string("^(\\d+[.)]|[-*•]|\\([a-z0-9]+\\))\\s")
	var out: Array = []
	for para: String in text.replace("\r", "").split("\n\n", false):
		var lines: Array = []
		var prev_len := 0
		for raw: String in para.split("\n", false):
			var line := raw.strip_edges()
			if line == "" or line.lstrip("-=_ ") == "":
				prev_len = 0
				continue
			if lines.is_empty() or prev_len < 45 or item.search(line) != null:
				lines.append(line)
			else:
				lines[lines.size() - 1] = String(lines[lines.size() - 1]) + " " + line
			prev_len = line.length()
		if not lines.is_empty():
			out.append("\n".join(lines))
	return "\n\n".join(out)


func _list(c: VBoxContainer) -> void:
	c.add_child(UIKit.label("A Godot Engine inclui os componentes abaixo. Toque em um deles para ver os avisos de direitos autorais e a licença.", "Muted", true))
	var info := Engine.get_copyright_info()
	var rows := UIKit.vbox(UITokens.S1)
	c.add_child(rows)
	UIKit.fill_rows(rows, info.size(), func(i: int) -> Control:
		var comp: Dictionary = info[i]
		var row := UIKit.menu_row("", String(comp["name"]), ", ".join(_licenses(comp)), func(): UIManager.push("licenses", {"component": i}))
		for l in row.find_children("*", "Label", true, false):
			(l as Label).auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		return row, 14, 12)


## As licenças citadas num componente, sem repetir ("Expat and Zlib" vira as duas).
static func _licenses(comp: Dictionary) -> Array:
	var out: Array = []
	for p: Dictionary in comp.get("parts", []):
		for name: String in String(p.get("license", "")).replace(" and ", "|").replace(" or ", "|").split("|", false):
			var n := name.strip_edges()
			if n != "" and n not in out:
				out.append(n)
	return out


func _component(c: VBoxContainer, index: int) -> void:
	var info := Engine.get_copyright_info()
	if index < 0 or index >= info.size():
		return
	var comp: Dictionary = info[index]
	var head := UIKit.label(String(comp["name"]), "H2", true)
	head.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	c.add_child(head)
	for p: Dictionary in comp.get("parts", []):
		var card := UIKit.card()
		var lines: Array = []
		for cr: String in p.get("copyright", []):
			lines.append("© " + cr)
		var l := UIKit.label("\n".join(lines), "Small", true)
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		card.add_child(l)
		card.add_child(UIKit.kv("Licença", String(p.get("license", ""))))
		c.add_child(UIKit.card_panel(card))
	var known := Engine.get_license_info()
	var rows: Array = []
	for name: String in _licenses(comp):
		if known.has(name):
			rows.append(UIKit.menu_row("book", name, "Ler o texto da licença", func(): UIManager.push("licenses", {"license": name})))
	if not rows.is_empty():
		c.add_child(UIKit.menu_group(rows))
