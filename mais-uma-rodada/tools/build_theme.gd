extends SceneTree
## Gera assets/theme/main_theme.tres a partir do código (fonte da verdade do visual).
## Uso: godot --headless --path . --script res://tools/build_theme.gd

const OUT := "res://assets/theme/main_theme.tres"

var f_reg: Font
var f_semi: Font
var f_cond: Font
var f_bold: Font


func _initialize() -> void:
	f_reg = load("res://assets/fonts/Barlow-Regular.woff2")
	f_semi = load("res://assets/fonts/Barlow-SemiBold.woff2")
	f_cond = load("res://assets/fonts/BarlowCondensed-SemiBold.woff2")
	f_bold = load("res://assets/fonts/BarlowCondensed-ExtraBold.woff2")
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
	quit()


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


func _labels(th: Theme) -> void:
	th.set_color(&"font_color", "Label", UIColors.TEXT)
	th.set_font_size(&"font_size", "Label", 24)
	_label_var(th, "Title", f_cond, 38, UIColors.TEXT)
	_label_var(th, "H2", f_cond, 30, UIColors.TEXT)
	_label_var(th, "H3", f_semi, 24, UIColors.TEXT)
	_label_var(th, "Big", f_bold, 58, UIColors.TEXT)
	_label_var(th, "Huge", f_bold, 92, UIColors.TEXT)
	_label_var(th, "Score", f_bold, 72, UIColors.TEXT)
	_label_var(th, "Muted", f_reg, 21, UIColors.MUTED)
	_label_var(th, "Small", f_reg, 18, UIColors.MUTED)
	_label_var(th, "Caps", f_semi, 17, UIColors.DIM)
	_label_var(th, "Accent", f_semi, 24, UIColors.ACCENT)
	_label_var(th, "Stat", f_cond, 32, UIColors.TEXT)
	_label_var(th, "Mono", f_cond, 24, UIColors.TEXT)
	_label_var(th, "Logo", f_bold, 76, UIColors.ACCENT)


func _button_states(th: Theme, name: String, normal: StyleBox, hover: StyleBox, pressed: StyleBox, disabled: StyleBox) -> void:
	th.set_stylebox(&"normal", name, normal)
	th.set_stylebox(&"hover", name, hover)
	th.set_stylebox(&"pressed", name, pressed)
	th.set_stylebox(&"hover_pressed", name, pressed)
	th.set_stylebox(&"disabled", name, disabled)
	th.set_stylebox(&"focus", name, StyleBoxEmpty.new())


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
	# Botão padrão
	_button_states(th, "Button",
		sb(UIColors.SURFACE_2, 14, UIColors.LINE, 1, 20, 14),
		sb(UIColors.SURFACE_3, 14, UIColors.LINE, 1, 20, 14),
		sb(UIColors.SURFACE_3, 14, UIColors.ACCENT, 2, 20, 14),
		sb(UIColors.SURFACE, 14, UIColors.LINE, 1, 20, 14))
	_button_colors(th, "Button", UIColors.TEXT, UIColors.ACCENT)
	th.set_font(&"font", "Button", f_semi)
	th.set_font_size(&"font_size", "Button", 24)
	th.set_constant(&"h_separation", "Button", 10)
	th.set_constant(&"icon_max_width", "Button", 40)
	# Primário (JOGAR, confirmar)
	th.add_type("PrimaryButton")
	th.set_type_variation("PrimaryButton", "Button")
	_button_states(th, "PrimaryButton",
		sb(UIColors.ACCENT, 16, Color(0, 0, 0, 0), 0, 24, 16),
		sb(Color("#FFD466"), 16, Color(0, 0, 0, 0), 0, 24, 16),
		sb(UIColors.ACCENT_DARK, 16, Color(0, 0, 0, 0), 0, 24, 16),
		sb(UIColors.SURFACE_2, 16, Color(0, 0, 0, 0), 0, 24, 16))
	_button_colors(th, "PrimaryButton", UIColors.ON_ACCENT, UIColors.ON_ACCENT)
	th.set_font(&"font", "PrimaryButton", f_bold)
	th.set_font_size(&"font_size", "PrimaryButton", 34)
	# Fantasma (ações secundárias)
	th.add_type("GhostButton")
	th.set_type_variation("GhostButton", "Button")
	_button_states(th, "GhostButton",
		sb(Color(0, 0, 0, 0), 14, UIColors.LINE, 2, 18, 12),
		sb(UIColors.SURFACE_2, 14, UIColors.LINE, 2, 18, 12),
		sb(UIColors.SURFACE_3, 14, UIColors.ACCENT, 2, 18, 12),
		sb(Color(0, 0, 0, 0), 14, UIColors.SURFACE_2, 2, 18, 12))
	_button_colors(th, "GhostButton", UIColors.TEXT, UIColors.ACCENT)
	th.set_font(&"font", "GhostButton", f_semi)
	th.set_font_size(&"font_size", "GhostButton", 22)
	# Perigo
	th.add_type("DangerButton")
	th.set_type_variation("DangerButton", "Button")
	_button_states(th, "DangerButton",
		sb(Color("#3A1C22"), 14, UIColors.RED, 2, 18, 12),
		sb(Color("#4A2229"), 14, UIColors.RED, 2, 18, 12),
		sb(UIColors.RED, 14, UIColors.RED, 2, 18, 12),
		sb(UIColors.SURFACE, 14, UIColors.LINE, 1, 18, 12))
	_button_colors(th, "DangerButton", Color("#FFB3B5"), Color.WHITE)
	th.set_font(&"font", "DangerButton", f_semi)
	# Chip (seleção em grupo: formações, mentalidade, filtros)
	th.add_type("ChipButton")
	th.set_type_variation("ChipButton", "Button")
	_button_states(th, "ChipButton",
		sb(UIColors.SURFACE_2, 22, UIColors.LINE, 1, 16, 8),
		sb(UIColors.SURFACE_3, 22, UIColors.LINE, 1, 16, 8),
		sb(UIColors.ACCENT, 22, UIColors.ACCENT, 1, 16, 8),
		sb(UIColors.SURFACE, 22, UIColors.LINE, 1, 16, 8))
	_button_colors(th, "ChipButton", UIColors.MUTED, UIColors.ON_ACCENT)
	th.set_font(&"font", "ChipButton", f_semi)
	th.set_font_size(&"font_size", "ChipButton", 20)
	# Navegação inferior
	th.add_type("NavButton")
	th.set_type_variation("NavButton", "Button")
	var empty := StyleBoxEmpty.new()
	_button_states(th, "NavButton", empty, sb(Color(1, 1, 1, 0.03), 12, Color(0, 0, 0, 0), 0, 4, 6), sb(Color(1, 1, 1, 0.05), 12, Color(0, 0, 0, 0), 0, 4, 6), empty)
	_button_colors(th, "NavButton", UIColors.MUTED, UIColors.ACCENT)
	th.set_font(&"font", "NavButton", f_semi)
	th.set_font_size(&"font_size", "NavButton", 16)
	th.set_constant(&"icon_max_width", "NavButton", 36)
	# Linha clicável (listas)
	th.add_type("RowButton")
	th.set_type_variation("RowButton", "Button")
	_button_states(th, "RowButton",
		sb(UIColors.SURFACE, 12, Color(0, 0, 0, 0), 0, 14, 10),
		sb(UIColors.SURFACE_2, 12, Color(0, 0, 0, 0), 0, 14, 10),
		sb(UIColors.SURFACE_3, 12, UIColors.ACCENT, 1, 14, 10),
		sb(UIColors.SURFACE, 12, Color(0, 0, 0, 0), 0, 14, 10))
	_button_colors(th, "RowButton", UIColors.TEXT, UIColors.TEXT)
	# Camada clicável transparente sobre linhas (ver UIKit.tap_row)
	th.add_type("RowOverlay")
	th.set_type_variation("RowOverlay", "Button")
	_button_states(th, "RowOverlay", empty, sb(Color(1, 1, 1, 0.035), 12, Color(0, 0, 0, 0), 0, 0, 0),
		sb(Color(1, 0.79, 0.25, 0.08), 12, UIColors.ACCENT, 2, 0, 0), empty)
	_button_colors(th, "RowOverlay", UIColors.TEXT, UIColors.TEXT)
	# Ícone (barra superior)
	th.add_type("IconButton")
	th.set_type_variation("IconButton", "Button")
	_button_states(th, "IconButton", empty, sb(Color(1, 1, 1, 0.05), 14, Color(0, 0, 0, 0), 0, 8, 8), sb(Color(1, 1, 1, 0.1), 14, Color(0, 0, 0, 0), 0, 8, 8), empty)
	_button_colors(th, "IconButton", UIColors.TEXT, UIColors.ACCENT)
	th.set_constant(&"icon_max_width", "IconButton", 40)


func _panel_var(th: Theme, name: String, box: StyleBox) -> void:
	th.add_type(name)
	th.set_type_variation(name, "PanelContainer")
	th.set_stylebox(&"panel", name, box)


func _panels(th: Theme) -> void:
	th.set_stylebox(&"panel", "PanelContainer", StyleBoxEmpty.new())
	th.set_stylebox(&"panel", "Panel", sb(UIColors.SURFACE, 18))
	_panel_var(th, "Card", sb(UIColors.SURFACE, 18, Color(0, 0, 0, 0), 0, 22, 18))
	_panel_var(th, "CardFlat", sb(UIColors.SURFACE, 14, Color(0, 0, 0, 0), 0, 14, 10))
	_panel_var(th, "CardHighlight", sb(UIColors.SURFACE_2, 18, UIColors.ACCENT, 2, 22, 18))
	_panel_var(th, "CardInset", sb(UIColors.BG, 14, UIColors.LINE, 1, 16, 12))
	_panel_var(th, "RowPanel", sb(UIColors.SURFACE_2, 12, Color(0, 0, 0, 0), 0, 14, 10))
	_panel_var(th, "Pill", sb(UIColors.SURFACE_3, 20, Color(0, 0, 0, 0), 0, 12, 4))
	var top := sb(Color("#111B28"), 0, Color(0, 0, 0, 0), 0, 16, 10)
	_panel_var(th, "TopBar", top)
	var nav := sb(Color("#111B28"), 0, Color(0, 0, 0, 0), 0, 8, 6)
	nav.border_color = UIColors.LINE
	nav.border_width_top = 1
	_panel_var(th, "BottomBar", nav)
	var sheet := sb(UIColors.SURFACE, 0, Color(0, 0, 0, 0), 0, 24, 22)
	sheet.corner_radius_top_left = 26
	sheet.corner_radius_top_right = 26
	_panel_var(th, "Sheet", sheet)
	_panel_var(th, "Dialog", sb(UIColors.SURFACE, 22, UIColors.LINE, 1, 26, 24))
	_panel_var(th, "Toast", sb(Color("#22344A"), 16, UIColors.LINE, 1, 22, 14))


func _inputs(th: Theme) -> void:
	th.set_stylebox(&"normal", "LineEdit", sb(UIColors.SURFACE_2, 12, UIColors.LINE, 1, 16, 12))
	th.set_stylebox(&"focus", "LineEdit", sb(UIColors.SURFACE_2, 12, UIColors.ACCENT, 2, 16, 12))
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
	th.set_stylebox(&"focus", "CheckButton", StyleBoxEmpty.new())
	# Slider
	var track := sb(UIColors.SURFACE_3, 6, Color(0, 0, 0, 0), 0, 0, 5)
	th.set_stylebox(&"slider", "HSlider", track)
	var fill := sb(UIColors.ACCENT, 6, Color(0, 0, 0, 0), 0, 0, 5)
	th.set_stylebox(&"grabber_area", "HSlider", fill)
	th.set_stylebox(&"grabber_area_highlight", "HSlider", fill)
	# Barra de progresso
	th.set_stylebox(&"background", "ProgressBar", sb(UIColors.SURFACE_3, 6, Color(0, 0, 0, 0), 0, 0, 0))
	th.set_stylebox(&"fill", "ProgressBar", sb(UIColors.GREEN, 6, Color(0, 0, 0, 0), 0, 0, 0))
	th.set_color(&"font_color", "ProgressBar", UIColors.TEXT)


func _scroll(th: Theme) -> void:
	var grab := sb(Color(1, 1, 1, 0.14), 4, Color(0, 0, 0, 0), 0, 3, 3)
	var grab_hi := sb(Color(1, 1, 1, 0.24), 4, Color(0, 0, 0, 0), 0, 3, 3)
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
