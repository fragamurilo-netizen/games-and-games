extends Control
## Prova visual real do Godot. Não é mockup: esta cena monta Controls, carrega os SVGs
## de res://assets/visual_proof e salva o próprio Viewport quando executada com --render-proof.

@export_enum("dashboard", "crests") var mode := "dashboard"

const W := 900.0
const H := 1600.0
const BG := Color("#07111F")
const SURFACE := Color("#0E1B2B")
const CARD := Color("#F5F7FA")
const CARD_2 := Color("#E9EEF3")
const TEXT := Color("#101827")
const MUTED := Color("#657286")
const WHITE := Color("#F7FAFC")
const GREEN := Color("#20C878")
const GOLD := Color("#E3B54B")
const RED := Color("#EA5B5B")
const BLUE := Color("#3CB6F0")

const CRESTS := [
	["Aurora FC", "res://assets/visual_proof/aurora_fc.svg", Color("#F4B942")],
	["Vale Unido", "res://assets/visual_proof/vale_unido.svg", Color("#2F7A4D")],
	["Ferro Azul", "res://assets/visual_proof/ferro_azul.svg", Color("#45B9F4")],
	["Estrela do Sul", "res://assets/visual_proof/estrela_sul.svg", Color("#D9A441")],
	["Monte Verde", "res://assets/visual_proof/monte_verde.svg", Color("#2D7A46")],
]

func _ready() -> void:
	get_window().size = Vector2i(int(W), int(H))
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if mode == "crests":
		_build_crest_gallery()
	else:
		_build_dashboard()
	if OS.get_cmdline_user_args().has("--render-proof"):
		_capture.call_deferred()

func _capture() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var out_dir := ProjectSettings.globalize_path("res://build")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var img := get_viewport().get_texture().get_image()
	var file := "visual-proof-crests.png" if mode == "crests" else "visual-proof-ui.png"
	var err := img.save_png(out_dir.path_join(file))
	print("VISUAL_PROOF_SAVED ", file, " err=", err)
	get_tree().quit(0 if err == OK else 1)

func _panel(rect: Rect2, color: Color, radius := 24.0, border_color := Color.TRANSPARENT, border := 0) -> Panel:
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	var st := StyleBoxFlat.new()
	st.bg_color = color
	st.corner_radius_top_left = int(radius)
	st.corner_radius_top_right = int(radius)
	st.corner_radius_bottom_left = int(radius)
	st.corner_radius_bottom_right = int(radius)
	if border > 0:
		st.border_color = border_color
		st.border_width_left = border
		st.border_width_top = border
		st.border_width_right = border
		st.border_width_bottom = border
	p.add_theme_stylebox_override("panel", st)
	add_child(p)
	return p

func _label(parent: Node, text: String, rect: Rect2, size_px: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.position = rect.position
	l.size = rect.size
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.clip_text = true
	parent.add_child(l)
	return l

func _crest(parent: Node, path: String, rect: Rect2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load(path)
	t.position = rect.position
	t.size = rect.size
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(t)
	return t

func _button(parent: Node, text: String, rect: Rect2, color: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.position = rect.position
	b.size = rect.size
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.focus_mode = Control.FOCUS_NONE
	var normal := StyleBoxFlat.new()
	normal.bg_color = color
	normal.corner_radius_top_left = 18
	normal.corner_radius_top_right = 18
	normal.corner_radius_bottom_left = 18
	normal.corner_radius_bottom_right = 18
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", normal)
	b.add_theme_stylebox_override("pressed", normal)
	parent.add_child(b)
	return b

func _build_dashboard() -> void:
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Header
	var header := _panel(Rect2(0, 0, W, 176), Color("#0A1625"), 0)
	_crest(header, CRESTS[0][1], Rect2(34, 28, 112, 112))
	_label(header, "AURORA FC", Rect2(164, 35, 430, 48), 34, WHITE)
	_label(header, "MAIS UMA RODADA", Rect2(164, 80, 430, 32), 18, Color("#9AA7B8"))
	_label(header, "TEMPORADA 2026  •  BRASIL", Rect2(164, 116, 430, 28), 17, Color("#7F8A9C"))
	var pill := _panel(Rect2(694, 45, 165, 70), Color("#14283D"), 18, GREEN, 2)
	_label(pill, "5º LUGAR", Rect2(0, 0, 165, 70), 20, WHITE, HORIZONTAL_ALIGNMENT_CENTER)

	# Próximo jogo
	var game := _panel(Rect2(30, 202, 840, 282), CARD, 28)
	_label(game, "PRÓXIMO JOGO", Rect2(28, 18, 300, 42), 25, TEXT)
	_label(game, "SÉRIE A  •  RODADA 19", Rect2(490, 18, 320, 42), 17, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	_crest(game, CRESTS[0][1], Rect2(42, 72, 132, 132))
	_crest(game, CRESTS[1][1], Rect2(666, 72, 132, 132))
	_label(game, "Aurora FC", Rect2(25, 194, 165, 32), 20, TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_label(game, "Vale Unido", Rect2(650, 194, 165, 32), 20, TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_label(game, "SÁBADO", Rect2(318, 78, 205, 28), 16, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_label(game, "19:00", Rect2(310, 104, 220, 66), 48, TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_label(game, "Estádio Aurora", Rect2(300, 166, 240, 28), 17, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_button(game, "IR PARA O JOGO", Rect2(286, 210, 268, 54), Color("#14985F"))

	# Classificação
	var table := _panel(Rect2(30, 510, 406, 478), CARD, 26)
	_label(table, "CLASSIFICAÇÃO", Rect2(24, 16, 245, 42), 24, TEXT)
	_label(table, "P", Rect2(344, 16, 40, 42), 18, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	var points := [38, 35, 33, 31, 29]
	for i in 5:
		var y := 78.0 + i * 72.0
		if i == 4:
			var hi := Panel.new()
			hi.position = Vector2(14, y - 6)
			hi.size = Vector2(378, 64)
			var hs := StyleBoxFlat.new()
			hs.bg_color = Color("#E2E9F0")
			hs.corner_radius_top_left = 14
			hs.corner_radius_top_right = 14
			hs.corner_radius_bottom_left = 14
			hs.corner_radius_bottom_right = 14
			hi.add_theme_stylebox_override("panel", hs)
			table.add_child(hi)
		_label(table, str(i + 1), Rect2(18, y, 32, 50), 18, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		_crest(table, CRESTS[i][1], Rect2(55, y, 44, 44))
		_label(table, CRESTS[i][0], Rect2(110, y, 190, 48), 18, TEXT)
		_label(table, str(points[i]), Rect2(334, y, 52, 48), 19, TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_button(table, "VER TABELA COMPLETA", Rect2(22, 415, 362, 46), Color("#182B40"))

	# Notícias
	var news := _panel(Rect2(464, 510, 406, 478), CARD, 26)
	_label(news, "NOTÍCIAS", Rect2(24, 16, 210, 42), 24, TEXT)
	_label(news, "AGORA", Rect2(300, 16, 82, 42), 16, GREEN, HORIZONTAL_ALIGNMENT_RIGHT)
	var news_data := [
		["Aurora chega a cinco jogos sem perder", "A equipe ganhou confiança e encosta no G4."],
		["Joia da base chama atenção no treino", "Comissão planeja integrar o jovem ao profissional."],
		["Diretoria revisa verba para a janela", "Mercado e caixa entram na conta antes das propostas."],
	]
	for i in 3:
		var y := 76.0 + i * 112.0
		var dot := ColorRect.new()
		dot.color = [GOLD, BLUE, GREEN][i]
		dot.position = Vector2(24, y + 7)
		dot.size = Vector2(6, 78)
		news.add_child(dot)
		_label(news, news_data[i][0], Rect2(46, y, 330, 48), 18, TEXT)
		var body := _label(news, news_data[i][1], Rect2(46, y + 47, 330, 52), 15, MUTED)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_button(news, "ABRIR CENTRAL DE NOTÍCIAS", Rect2(22, 415, 362, 46), Color("#182B40"))

	# Finanças
	var finance := _panel(Rect2(30, 1014, 406, 330), CARD, 26)
	_label(finance, "FINANÇAS", Rect2(24, 16, 230, 42), 24, TEXT)
	_label(finance, "Saldo em caixa", Rect2(24, 76, 210, 28), 16, MUTED)
	_label(finance, "R$ 42,8 mi", Rect2(24, 104, 270, 46), 31, Color("#12835A"))
	_label(finance, "Orçamento de transferências", Rect2(24, 164, 300, 28), 16, MUTED)
	_label(finance, "R$ 86,4 mi", Rect2(24, 192, 270, 42), 26, TEXT)
	var bar_bg := _panel(Rect2(54, 1264, 352, 14), Color("#D9E1E8"), 7)
	var bar := _panel(Rect2(54, 1264, 226, 14), GREEN, 7)
	_label(finance, "64% disponível", Rect2(24, 252, 350, 30), 15, MUTED)

	# Elenco
	var squad := _panel(Rect2(464, 1014, 406, 330), CARD, 26)
	_label(squad, "ELENCO", Rect2(24, 16, 230, 42), 24, TEXT)
	_label(squad, "Força do XI inicial", Rect2(24, 72, 240, 30), 16, MUTED)
	_label(squad, "74,2", Rect2(286, 65, 90, 44), 28, TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	_label(squad, "Idade média", Rect2(24, 122, 240, 30), 16, MUTED)
	_label(squad, "25,8", Rect2(286, 115, 90, 44), 26, TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	_label(squad, "Moral do grupo", Rect2(24, 172, 240, 30), 16, MUTED)
	_label(squad, "Boa", Rect2(286, 165, 90, 44), 24, GREEN, HORIZONTAL_ALIGNMENT_RIGHT)
	_label(squad, "Próxima prioridade", Rect2(24, 225, 220, 26), 15, MUTED)
	_label(squad, "LD titular", Rect2(24, 252, 220, 34), 20, TEXT)
	_button(squad, "ABRIR ELENCO", Rect2(232, 244, 150, 48), Color("#182B40"))

	# Nav real de app
	var nav := _panel(Rect2(0, 1380, W, 220), Color("#091724"), 0)
	var items := [["INÍCIO", "●"], ["ELENCO", "◉"], ["TÁTICAS", "▦"], ["MERCADO", "⇄"], ["CLUBE", "◆"]]
	for i in 5:
		var x := 18.0 + i * 176.0
		var active := i == 0
		_label(nav, items[i][1], Rect2(x, 34, 150, 48), 30, GREEN if active else Color("#AAB5C3"), HORIZONTAL_ALIGNMENT_CENTER)
		_label(nav, items[i][0], Rect2(x, 84, 150, 42), 16, WHITE if active else Color("#AAB5C3"), HORIZONTAL_ALIGNMENT_CENTER)
		if active:
			var line := ColorRect.new()
			line.color = GREEN
			line.position = Vector2(x + 28, 132)
			line.size = Vector2(94, 5)
			nav.add_child(line)
	_label(nav, "PROVA VISUAL REAL • GODOT 4", Rect2(30, 166, 840, 30), 14, Color("#627187"), HORIZONTAL_ALIGNMENT_CENTER)

func _build_crest_gallery() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#F4F6F8")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_label(self, "ESCUDOS • PROVA REAL NO GODOT", Rect2(42, 42, 816, 56), 30, TEXT)
	_label(self, "5 SVGs vetoriais originais carregados como Texture2D", Rect2(42, 98, 816, 34), 17, MUTED)
	for i in 5:
		var col := i % 2
		var row := i / 2
		var x := 42.0 + col * 414.0
		var y := 170.0 + row * 400.0
		if i == 4:
			x = 249.0
		var card := _panel(Rect2(x, y, 360, 350), Color.WHITE, 28, Color("#D9E0E7"), 2)
		_crest(card, CRESTS[i][1], Rect2(80, 34, 200, 200))
		_label(card, CRESTS[i][0], Rect2(30, 244, 300, 40), 24, TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		_label(card, "SVG • 512 × 512 • TRANSPARENTE", Rect2(25, 286, 310, 30), 14, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		var strip := ColorRect.new()
		strip.color = CRESTS[i][2]
		strip.position = Vector2(90, 326)
		strip.size = Vector2(180, 6)
		card.add_child(strip)
	_label(self, "Arquivo real no projeto: res://assets/visual_proof/", Rect2(42, 1420, 816, 36), 16, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_label(self, "Sem PNG pré-renderizado • o Godot rasteriza o SVG", Rect2(42, 1460, 816, 36), 16, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
