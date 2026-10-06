extends RefCounted
## Gera assets/theme/main_theme.tres a partir do código (fonte da verdade do visual).
## Uso: godot --headless --path . --script res://tools/build_theme.gd (que carrega este arquivo
## depois do primeiro quadro, quando as classes que usam os autoloads já compilam).

const OUT := "res://assets/theme/main_theme.tres"

var f_reg: Font
var f_semi: Font
var f_cond: Font
var f_bold: Font


func build() -> void:
	f_reg = _saira(400,100)
	f_semi = _saira(600,100)
	f_cond = _saira(600,87.5)
	f_bold = _saira(750,87.5)
	var th := Theme.new()
	th.default_font = f_reg
	th.default_font_size = 24
	_labels(th)
	_buttons(th)
	_panels(th)
	_inputs(th)
	_scroll(th)
	_misc(th)
	var err := ResourceSaver.save(th, OUT)
	print("tema salvo: ", OUT, " (", error_string(err), ")")


func _saira(weight: float, width: float) -> FontVariation:
	var font := FontVariation.new()
	font.base_font = load("res://assets/fonts/Saira-Variable.ttf")
	font.variation_opentype = {"weight":weight,"width":width}
	# Saira includes generous vertical metrics; keep compact UI leading.
	font.spacing_top = -2
	font.spacing_bottom = -3
	return font


static func sb(bg: Color, radius: int = 14, border: Color = Color(0, 0, 0, 0), bw: int = 0, mx: int = 18, my: int = 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	if bw > 0:
		s.border_color = border
		s.set_border_width_all(bw)
	s.content_margin_left = mx
	s.content_margin_right = mx
	s.content_margin_top = my
	s.content_margin_bottom = my
	s.anti_aliasing = true
	s.corner_detail = 6
	return s


func _label_var(th: Theme, name: String, font: Font, size: int, color: Color) -> void:
	th.add_type(name)
	th.set_type_variation(name, "Label")
	th.set_font(&"font", name, font)
	th.set_font_size(&"font_size", name, size)
	th.set_color(&"font_color", name, color)


## Fonte com espaço extra entre as letras (rótulos em caixa alta, como nas transmissões).
func _spaced(base: Font, px: int) -> FontVariation:
	var fv := FontVariation.new()
	fv.base_font = base
	fv.spacing_glyph = px
	return fv


## Escala de DESIGN.md › Typography. Saira semicomprimida nos títulos; largura normal para leitura.
func _labels(th: Theme) -> void:
	th.set_color(&"font_color", "Label", UIColors.TEXT)
	th.set_font_size(&"font_size", "Label", UITokens.F_BODY)
	_label_var(th, "Score", f_bold, UITokens.F_SCORE, UIColors.TEXT)
	_label_var(th, "Display", f_bold, UITokens.F_SCORE, UIColors.TEXT)
	_label_var(th, "Title", f_bold, UITokens.F_ENTITY, UIColors.TEXT)
	_label_var(th, "Screen", f_cond, UITokens.F_SCREEN, UIColors.TEXT)
	_label_var(th, "Section", f_cond, UITokens.F_SECTION, UIColors.TEXT)
	_label_var(th, "H2", f_cond, UITokens.F_SECTION, UIColors.TEXT)
	_label_var(th, "H3", f_semi, UITokens.F_BODY, UIColors.TEXT)
	_label_var(th, "Big", f_bold, 58, UIColors.TEXT)
	_label_var(th, "Huge", f_bold, 92, UIColors.TEXT)
	_label_var(th, "Muted", f_reg, UITokens.F_BODY_SMALL, UIColors.MUTED)
	_label_var(th, "Small", f_reg, UITokens.F_BODY_SMALL, UIColors.MUTED)
	_label_var(th, "Meta", f_reg, UITokens.F_META, UIColors.DIM)
	_label_var(th, "Caps", f_semi, UITokens.F_CAPTION, UIColors.DIM)
	_label_var(th, "Eyebrow", f_cond, UITokens.F_SECTION, UIColors.TEXT)
	_label_var(th, "Accent", f_semi, UITokens.F_BODY, UIColors.ACCENT)
	_label_var(th, "Stat", f_cond, 32, UIColors.TEXT)
	_label_var(th, "StatBig", f_bold, UITokens.F_ENTITY, UIColors.TEXT)
	_label_var(th, "Mono", f_reg, UITokens.F_BODY, UIColors.TEXT)
	_label_var(th, "Logo", f_bold, 76, UIColors.ACCENT)


func _button_states(th: Theme, name: String, normal: StyleBox, hover: StyleBox, pressed: StyleBox, disabled: StyleBox) -> void:
	th.set_stylebox(&"normal", name, normal)
	th.set_stylebox(&"hover", name, hover)
	th.set_stylebox(&"pressed", name, pressed)
	th.set_stylebox(&"hover_pressed", name, pressed)
	th.set_stylebox(&"disabled", name, disabled)
	th.set_stylebox(&"focus", name, _focus_ring())


## Contorno de foco (teclado/controle): filete azul (info) de 3 px, afastado do botão; giz
## sumiria no botão principal, que é de giz. O toque não deixa foco
## em botão (main.gd solta o foco depois do clique), então isto só aparece navegando por teclas.
func _focus_ring() -> StyleBoxFlat:
	var f := StyleBoxFlat.new()
	f.draw_center = false
	f.border_color = UIColors.BLUE
	f.set_border_width_all(3)
	f.set_corner_radius_all(UITokens.R_SM)
	f.set_expand_margin_all(4)
	return f


func _button_colors(th: Theme, name: String, fg: Color, pressed_fg: Color) -> void:
	th.set_color(&"font_color", name, fg)
	th.set_color(&"font_hover_color", name, fg)
	th.set_color(&"font_pressed_color", name, pressed_fg)
	th.set_color(&"font_hover_pressed_color", name, pressed_fg)
	th.set_color(&"font_focus_color", name, fg)
	th.set_color(&"font_disabled_color", name, UIColors.DIM)
	th.set_color(&"icon_normal_color", name, fg)
	th.set_color(&"icon_hover_color", name, fg)
	th.set_color(&"icon_pressed_color", name, pressed_fg)
	th.set_color(&"icon_hover_pressed_color", name, pressed_fg)
	th.set_color(&"icon_focus_color", name, fg)
	th.set_color(&"icon_disabled_color", name, UIColors.DIM)


func _buttons(th: Theme) -> void:
	var clear := Color(0, 0, 0, 0)
	var r := UITokens.R_MD
	# Botão padrão: superfície chapada; passar o mouse clareia, tocar escurece (sem borda acesa).
	_button_states(th, "Button",
		sb(UIColors.SURFACE_2, r, clear, 0, 20, 14),
		sb(UIColors.SURFACE_3, r, clear, 0, 20, 14),
		sb(UIColors.SURFACE, r, UIColors.LINE, 1, 20, 14),
		sb(UIColors.SURFACE, r, clear, 0, 20, 14))
	_button_colors(th, "Button", UIColors.TEXT, UIColors.TEXT)
	th.set_font(&"font", "Button", f_semi)
	th.set_font_size(&"font_size", "Button", UITokens.F_BODY)
	th.set_constant(&"h_separation", "Button", 12)
	th.set_constant(&"icon_max_width", "Button", 34)
	# Primário: giz sobre a ardósia (DESIGN.md). Uma ação principal por tela, nunca na cor do clube.
	th.add_type("PrimaryButton")
	th.set_type_variation("PrimaryButton", "Button")
	var pn := sb(UIColors.TEXT, r, clear, 0, 24, 14)
	var ph := sb(UIColors.TEXT, r, clear, 0, 24, 14)
	var pp := sb(UIColors.MUTED, r, clear, 0, 24, 14)
	_button_states(th, "PrimaryButton", pn, ph, pp, sb(UIColors.SURFACE_2, r, clear, 0, 24, 14))
	_button_colors(th, "PrimaryButton", UIColors.BG, UIColors.BG)
	th.set_color(&"font_disabled_color", "PrimaryButton", UIColors.DIM)
	th.set_color(&"icon_disabled_color", "PrimaryButton", UIColors.DIM)
	th.set_font(&"font", "PrimaryButton", f_cond)
	th.set_font_size(&"font_size", "PrimaryButton", UITokens.F_SECTION)
	# Secundário: superfície acima, sem contorno.
	th.add_type("GhostButton")
	th.set_type_variation("GhostButton", "Button")
	_button_states(th, "GhostButton",
		sb(UIColors.SURFACE_2, r, clear, 0, 18, 12),
		sb(UIColors.SURFACE_3, r, clear, 0, 18, 12),
		sb(UIColors.SURFACE_3, r, clear, 0, 18, 12),
		sb(UIColors.SURFACE, r, clear, 0, 18, 12))
	_button_colors(th, "GhostButton", UIColors.TEXT, UIColors.TEXT)
	th.set_font(&"font", "GhostButton", f_semi)
	th.set_font_size(&"font_size", "GhostButton", UITokens.F_BODY)
	# Texto (links "ver tudo" nos cabeçalhos de seção)
	th.add_type("TextButton")
	th.set_type_variation("TextButton", "Button")
	var empty := StyleBoxEmpty.new()
	_button_states(th, "TextButton", sb(clear, UITokens.R_SM, clear, 0, 8, 4), sb(Color(1, 1, 1, 0.04), UITokens.R_SM, clear, 0, 8, 4),
		sb(Color(1, 1, 1, 0.08), UITokens.R_SM, clear, 0, 8, 4), sb(clear, UITokens.R_SM, clear, 0, 8, 4))
	_button_colors(th, "TextButton", UIColors.TEXT, UIColors.TEXT)
	th.set_font(&"font", "TextButton", f_semi)
	th.set_font_size(&"font_size", "TextButton", UITokens.F_BODY_SMALL)
	# Perigo
	th.add_type("DangerButton")
	th.set_type_variation("DangerButton", "Button")
	_button_states(th, "DangerButton",
		sb(Color("#3A1C1E"), r, UIColors.RED, 1, 18, 12),
		sb(Color("#4A2224"), r, UIColors.RED, 1, 18, 12),
		sb(UIColors.RED, r, UIColors.RED, 1, 18, 12),
		sb(UIColors.SURFACE, r, UIColors.LINE, 1, 18, 12))
	_button_colors(th, "DangerButton", Color("#FFB3B5"), Color.WHITE)
	th.set_font(&"font", "DangerButton", f_semi)
	# Chip (filtros e seleções em grupo): compacto, cantos retos; selecionado = cor do clube.
	th.add_type("ChipButton")
	th.set_type_variation("ChipButton", "Button")
	_button_states(th, "ChipButton",
		sb(UIColors.SURFACE, UITokens.R_SM, clear, 0, 14, 6),
		sb(UIColors.SURFACE_3, UITokens.R_SM, clear, 0, 14, 6),
		sb(UIColors.SURFACE_3, UITokens.R_SM, UIColors.LINE, 1, 14, 6),
		sb(UIColors.SURFACE, UITokens.R_SM, UITokens.HAIRLINE, 1, 14, 6))
	_button_colors(th, "ChipButton", UIColors.MUTED, UIColors.TEXT)
	th.set_font(&"font", "ChipButton", f_semi)
	th.set_font_size(&"font_size", "ChipButton", UITokens.F_BODY_SMALL)
	# Abas (seções de uma tela): texto em caixa alta com sublinhado na cor do clube.
	th.add_type("TabButton")
	th.set_type_variation("TabButton", "Button")
	var tn := sb(clear, 0, clear, 0, 10, 10)
	tn.border_color = UITokens.HAIRLINE
	tn.border_width_bottom = 2
	var th_ := sb(Color(1, 1, 1, 0.03), 0, clear, 0, 10, 10)
	th_.border_color = UIColors.LINE
	th_.border_width_bottom = 2
	var tp := sb(clear, 0, clear, 0, 10, 10)
	tp.border_color = UIColors.ACCENT
	tp.border_width_bottom = 4
	_button_states(th, "TabButton", tn, th_, tp, tn)
	_button_colors(th, "TabButton", UIColors.DIM, UIColors.TEXT)
	th.set_font(&"font", "TabButton", f_cond)
	th.set_font_size(&"font_size", "TabButton", 26)
	# Segmento (seletor compacto dentro de uma cápsula "Segment")
	th.add_type("SegmentButton")
	th.set_type_variation("SegmentButton", "Button")
	# Selecionado: um tom acima, texto cheio. A cor do clube fica para o que é ação.
	_button_states(th, "SegmentButton", sb(clear, UITokens.R_XS, clear, 0, 10, 6), sb(Color(1, 1, 1, 0.04), UITokens.R_XS, clear, 0, 10, 6),
		sb(UIColors.SURFACE_3, UITokens.R_XS, clear, 0, 10, 6), sb(clear, UITokens.R_XS, clear, 0, 10, 6))
	_button_colors(th, "SegmentButton", UIColors.DIM, UIColors.TEXT)
	th.set_font(&"font", "SegmentButton", f_semi)
	th.set_font_size(&"font_size", "SegmentButton", UITokens.F_BODY_SMALL)
	# Navegação inferior (o indicador da aba ativa é desenhado pela BottomNav)
	th.add_type("NavButton")
	th.set_type_variation("NavButton", "Button")
	# Ícone e rótulo centrados no botão: o ícone fica preso no topo (vertical_icon_alignment), então
	# a margem de cima é maior. Os quatro estados com a mesma margem (o vazio não tinha nenhuma e
	# o ícone encostava na borda da barra).
	var nav_states: Array = []
	for bg in [clear, Color(1, 1, 1, 0.03), clear, clear]:
		var nb := sb(bg, UITokens.R_MD, clear, 0, 4, 6)
		nb.content_margin_top = UITokens.S3
		nb.content_margin_bottom = UITokens.S1
		nav_states.append(nb)
	_button_states(th, "NavButton", nav_states[0], nav_states[1], nav_states[2], nav_states[3])
	_button_colors(th, "NavButton", UIColors.DIM, UIColors.TEXT)
	th.set_font(&"font", "NavButton", f_semi)
	th.set_font_size(&"font_size", "NavButton", 19)
	th.set_constant(&"icon_max_width", "NavButton", 30)
	# Cabeçalho de tabela (DataTable): texto pequeno, sem fundo; a coluna ordenada acende.
	th.add_type("TableHead")
	th.set_type_variation("TableHead", "Button")
	var thd := sb(clear, 0, clear, 0, 2, 4)
	thd.border_color = UIColors.LINE
	thd.border_width_bottom = 1
	_button_states(th, "TableHead", thd, thd, thd, thd)
	_button_colors(th, "TableHead", UIColors.DIM, UIColors.TEXT)
	th.set_font(&"font", "TableHead", f_semi)
	th.set_font_size(&"font_size", "TableHead", 18)
	# Linha clicável (listas)
	th.add_type("RowButton")
	th.set_type_variation("RowButton", "Button")
	_button_states(th, "RowButton",
		sb(UIColors.SURFACE, r, clear, 0, 14, 10),
		sb(UIColors.SURFACE_2, r, clear, 0, 14, 10),
		sb(UIColors.SURFACE_3, r, clear, 0, 14, 10),
		sb(UIColors.SURFACE, r, clear, 0, 14, 10))
	_button_colors(th, "RowButton", UIColors.TEXT, UIColors.TEXT)
	# Camada clicável transparente sobre linhas (ver UIKit.tap_row)
	th.add_type("RowOverlay")
	th.set_type_variation("RowOverlay", "Button")
	# Selecionado/pressionado: filete na cor do clube só à esquerda (como uma lista de verdade).
	var ov_p := sb(UIColors.SURFACE_3, 0, clear, 0, 0, 0)
	_button_states(th, "RowOverlay", empty, sb(Color(UIColors.LINE, 0.45), 0, clear, 0, 0, 0), ov_p, empty)
	_button_colors(th, "RowOverlay", UIColors.TEXT, UIColors.TEXT)
	# Ícone (barra superior)
	th.add_type("IconButton")
	th.set_type_variation("IconButton", "Button")
	_button_states(th, "IconButton", empty, sb(Color(1, 1, 1, 0.05), r, clear, 0, 8, 8), sb(Color(1, 1, 1, 0.1), r, clear, 0, 8, 8), empty)
	_button_colors(th, "IconButton", UIColors.TEXT, UIColors.TEXT)
	th.set_constant(&"icon_max_width", "IconButton", 36)


func _panel_var(th: Theme, name: String, box: StyleBox) -> void:
	th.add_type(name)
	th.set_type_variation(name, "PanelContainer")
	th.set_stylebox(&"panel", name, box)


func _panels(th: Theme) -> void:
	var clear := Color(0, 0, 0, 0)
	var hair := UITokens.HAIRLINE
	th.set_stylebox(&"panel", "PanelContainer", StyleBoxEmpty.new())
	th.set_stylebox(&"panel", "Panel", sb(UIColors.SURFACE, UITokens.R_LG))
	# Painel: um objeto do jogo (o jogo, o jogador, o clube, a notícia, a lista de pendências).
	# Um tom acima do fundo, canto quase reto, sem borda nem sombra. Dentro dele, linhas finas.
	_panel_var(th, "Card", sb(UIColors.SURFACE, UITokens.R_SM, clear, 0, 18, 16))
	_panel_var(th, "CardFlat", sb(UIColors.SURFACE_2, UITokens.R_XS, clear, 0, 14, 10))
	# Destaque: o mesmo painel com a faixa do clube em cima.
	var hl := sb(UIColors.SURFACE, UITokens.R_SM, clear, 0, 18, 16)
	hl.border_color = UIColors.ACCENT
	hl.border_width_top = 4
	_panel_var(th, "CardHighlight", hl)
	_panel_var(th, "CardInset", sb(UIColors.BG, UITokens.R_XS, clear, 0, 14, 10))
	# Linha de lista: sem fundo, um filete fino embaixo separa da próxima.
	var row := sb(clear, 0, clear, 0, 4, 10)
	row.border_color = UITokens.HAIRLINE
	row.border_width_bottom = 1
	_panel_var(th, "RowPanel", row)
	_panel_var(th, "Pill", sb(UIColors.SURFACE_3, UITokens.R_XS, clear, 0, 10, 3))
	# Cápsula que agrupa SegmentButtons
	_panel_var(th, "Segment", sb(UIColors.SURFACE, UITokens.R_SM, clear, 0, 4, 4))
	# Ladrilho do ícone nas linhas de menu
	_panel_var(th, "IconTile", sb(clear, UITokens.R_SM, clear, 0, 4, 4))
	var top := sb(UITokens.BAR, 0, clear, 0, UITokens.GUTTER, 8)
	_panel_var(th, "TopBar", top)
	var nav := sb(UITokens.BAR, 0, clear, 0, 8, 4)
	nav.border_color = hair
	nav.border_width_top = 1
	_panel_var(th, "BottomBar", nav)
	var sheet := sb(UIColors.SURFACE, 0, clear, 0, 24, 22)
	sheet.corner_radius_top_left = UITokens.R_LG
	sheet.corner_radius_top_right = UITokens.R_LG
	_panel_var(th, "Sheet", sheet)
	_panel_var(th, "Dialog", sb(UIColors.SURFACE, UITokens.R_LG, UIColors.LINE, 1, 22, 20))
	_panel_var(th, "Popover", sb(UIColors.SURFACE_2, UITokens.R_SM, UIColors.LINE, 1, 18, 14))
	_panel_var(th, "Toast", sb(UIColors.SURFACE_2, UITokens.R_SM, clear, 0, 18, 12))


func _inputs(th: Theme) -> void:
	th.set_stylebox(&"normal", "LineEdit", sb(UIColors.SURFACE_2, UITokens.R_MD, UIColors.LINE, 1, 16, 12))
	th.set_stylebox(&"focus", "LineEdit", sb(UIColors.SURFACE_2, UITokens.R_MD, UIColors.ACCENT, 2, 16, 12))
	th.set_stylebox(&"read_only", "LineEdit", sb(UIColors.SURFACE, 12, UIColors.LINE, 1, 16, 12))
	th.set_color(&"font_color", "LineEdit", UIColors.TEXT)
	th.set_color(&"font_placeholder_color", "LineEdit", UIColors.DIM)
	th.set_color(&"caret_color", "LineEdit", UIColors.ACCENT)
	th.set_color(&"selection_color", "LineEdit", Color(1, 0.79, 0.25, 0.35))
	th.set_font_size(&"font_size", "LineEdit", 26)
	# CheckButton / CheckBox
	th.set_color(&"font_color", "CheckButton", UIColors.TEXT)
	th.set_color(&"font_pressed_color", "CheckButton", UIColors.TEXT)
	th.set_color(&"font_hover_color", "CheckButton", UIColors.TEXT)
	th.set_color(&"font_hover_pressed_color", "CheckButton", UIColors.TEXT)
	th.set_color(&"font_focus_color", "CheckButton", UIColors.TEXT)
	for st in [&"normal", &"hover", &"pressed", &"hover_pressed"]:
		th.set_stylebox(st, "CheckButton", sb(Color(0, 0, 0, 0), 12, Color(0, 0, 0, 0), 0, 6, 10))
	th.set_stylebox(&"focus", "CheckButton", _focus_ring())
	# Slider
	var track := sb(UIColors.SURFACE_3, 6, Color(0, 0, 0, 0), 0, 0, 5)
	th.set_stylebox(&"slider", "HSlider", track)
	var fill := sb(UIColors.ACCENT, 6, Color(0, 0, 0, 0), 0, 0, 5)
	th.set_stylebox(&"grabber_area", "HSlider", fill)
	th.set_stylebox(&"grabber_area_highlight", "HSlider", fill)
	th.set_stylebox(&"focus", "HSlider", StyleBoxEmpty.new())
	th.set_stylebox(&"focus", "OptionButton", _focus_ring())
	# Barra de progresso
	th.set_stylebox(&"background", "ProgressBar", sb(UIColors.SURFACE_3, 6, Color(0, 0, 0, 0), 0, 0, 0))
	th.set_stylebox(&"fill", "ProgressBar", sb(UIColors.GREEN, 6, Color(0, 0, 0, 0), 0, 0, 0))
	th.set_color(&"font_color", "ProgressBar", UIColors.TEXT)


func _scroll(th: Theme) -> void:
	var grab := sb(Color(1, 1, 1, 0.22), 4, Color(0, 0, 0, 0), 0, 3, 3)
	var grab_hi := sb(Color(1, 1, 1, 0.36), 4, Color(0, 0, 0, 0), 0, 3, 3)
	var track := StyleBoxEmpty.new()
	for n in ["VScrollBar", "HScrollBar"]:
		th.set_stylebox(&"scroll", n, track)
		th.set_stylebox(&"scroll_focus", n, track)
		th.set_stylebox(&"grabber", n, grab)
		th.set_stylebox(&"grabber_highlight", n, grab_hi)
		th.set_stylebox(&"grabber_pressed", n, grab_hi)


func _misc(th: Theme) -> void:
	th.set_color(&"font_color", "RichTextLabel", UIColors.TEXT)
	th.set_color(&"default_color", "RichTextLabel", UIColors.TEXT)
	th.set_font(&"normal_font", "RichTextLabel", f_reg)
	th.set_font(&"bold_font", "RichTextLabel", f_semi)
	th.set_font_size(&"normal_font_size", "RichTextLabel", 23)
	th.set_font_size(&"bold_font_size", "RichTextLabel", 23)
	th.set_stylebox(&"panel", "PopupMenu", sb(UIColors.SURFACE_2, 14, UIColors.LINE, 1, 10, 10))
	th.set_color(&"font_color", "PopupMenu", UIColors.TEXT)
	th.set_color(&"font_hover_color", "PopupMenu", UIColors.ACCENT)
	th.set_stylebox(&"hover", "PopupMenu", sb(UIColors.SURFACE_3, 10, Color(0, 0, 0, 0), 0, 8, 6))
	th.set_font_size(&"font_size", "PopupMenu", 24)
	th.set_constant(&"v_separation", "PopupMenu", 18)
	th.set_constant(&"separation", "VBoxContainer", 12)
	th.set_constant(&"separation", "HBoxContainer", 12)
	th.set_constant(&"h_separation", "GridContainer", 12)
	th.set_constant(&"v_separation", "GridContainer", 12)
	th.set_stylebox(&"separator", "HSeparator", sb(UIColors.LINE, 0, Color(0, 0, 0, 0), 0, 0, 0))
	th.set_constant(&"separation", "HSeparator", 2)
	th.set_color(&"font_color", "TooltipLabel", UIColors.TEXT)
	th.set_stylebox(&"panel", "TooltipPanel", sb(UIColors.SURFACE_3, 10, UIColors.LINE, 1, 12, 8))
