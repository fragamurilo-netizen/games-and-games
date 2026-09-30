class_name Tokens
extends RefCounted
## Tokens de design (Game Design Bible §16 e §24). Toda cor da UI vem daqui;
## nunca use Color literais nas telas.
## Regras: vermelho = confronto/ação (não preenchimento constante);
## dourado = só campeão, legado e Hall da Fama.

const DISPLAY_FONT = preload("res://ui/theme/fonts/ChakraPetch-Bold.ttf")
const BODY_FONT = preload("res://ui/theme/fonts/ChakraPetch-Medium.ttf")
## Inclinação dos menus inspirados em UFC Undisputed 3: títulos em itálico
## e barras em paralelogramo. Um único valor para texto e formas.
const SLANT := 0.22
static var _italic: FontVariation

const CANVAS := Color("#111417")
const SURFACE := Color("#1B2025")
const PAPER := Color("#F1EEE6")
const INK := Color("#F4F1E8")
const MUTED := Color("#8A939C")
const FIGHT_RED := Color("#C83B3B")
const STEEL := Color("#46535E")
const CHAMP_GOLD := Color("#B88B46")

const SPACE_XS := 4
const SPACE_S := 8
const SPACE_M := 16
const SPACE_L := 24
const SPACE_XL := 32

const FONT_BODY := 26
const FONT_SMALL := 20
const FONT_TITLE := 40
const FONT_SCORE := 64

## Alvo de toque mínimo (px no viewport de 720 de largura).
const TOUCH_MIN := 88


## Display em itálico sintético (Chakra Petch não tem itálico próprio).
static func italic_font() -> FontVariation:
	if _italic==null:
		_italic=FontVariation.new();_italic.base_font=DISPLAY_FONT
		_italic.variation_transform=Transform2D(Vector2(1,SLANT),Vector2(0,1),Vector2.ZERO)
	return _italic


## Barra em paralelogramo; o recuo lateral acompanha a inclinação.
static func slanted_box(color: Color, height: float=TOUCH_MIN) -> StyleBoxFlat:
	var box:=StyleBoxFlat.new();box.bg_color=color
	box.skew=Vector2(SLANT,0);box.anti_aliasing=true
	var inset:=SPACE_M+ceilf(height*SLANT*.5)
	box.content_margin_left=inset;box.content_margin_right=inset
	box.content_margin_top=SPACE_S;box.content_margin_bottom=SPACE_S
	return box


static func build_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = FONT_BODY
	t.default_font = BODY_FONT
	t.set_font("font", "Button", italic_font())
	t.set_font("font", "OptionButton", DISPLAY_FONT)
	t.set_color("font_color", "Label", INK)
	t.set_color("font_color", "Button", INK)
	# Seleção estilo Undisputed 3: a barra inteira acende em vermelho.
	for state in ["font_pressed_color","font_hover_color","font_focus_color","font_hover_pressed_color"]:
		t.set_color(state, "Button", INK)
	t.set_color("font_disabled_color", "Button", MUTED)

	var panel := StyleBoxFlat.new()
	panel.bg_color = SURFACE
	t.set_stylebox("panel", "PanelContainer", panel)

	var btn:=slanted_box(Color(SURFACE,.94))
	btn.border_width_bottom=2;btn.border_color=STEEL
	var lit:=slanted_box(FIGHT_RED)
	var off:=slanted_box(Color(SURFACE,.5))
	t.set_stylebox("normal","Button",btn)
	t.set_stylebox("disabled","Button",off)
	for state in ["hover","pressed","hover_pressed"]:
		t.set_stylebox(state,"Button",lit)
	var focus:=StyleBoxFlat.new();focus.draw_center=false
	focus.skew=Vector2(SLANT,0);focus.border_color=INK
	focus.set_border_width_all(2)
	t.set_stylebox("focus","Button",focus)
	for kind in ["LineEdit", "OptionButton", "PopupMenu"]:
		t.set_stylebox("normal",kind,slanted_box(SURFACE))
		t.set_color("font_color",kind,INK)
	return t
