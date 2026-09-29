class_name Tokens
extends RefCounted
## Tokens de design (Game Design Bible §16 e §24). Toda cor da UI vem daqui;
## nunca use Color literais nas telas.
## Regras: vermelho = confronto/ação (não preenchimento constante);
## dourado = só campeão, legado e Hall da Fama.

const DISPLAY_FONT = preload("res://ui/theme/fonts/ChakraPetch-Bold.ttf")
const BODY_FONT = preload("res://ui/theme/fonts/ChakraPetch-Medium.ttf")

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


static func build_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = FONT_BODY
	t.default_font = BODY_FONT
	t.set_font("font", "Button", DISPLAY_FONT)
	t.set_font("font", "OptionButton", DISPLAY_FONT)
	t.set_color("font_color", "Label", INK)
	t.set_color("font_color", "Button", INK)
	t.set_color("font_pressed_color", "Button", FIGHT_RED)
	t.set_color("font_hover_color", "Button", INK)

	var panel := StyleBoxFlat.new()
	panel.bg_color = SURFACE
	t.set_stylebox("panel", "PanelContainer", panel)

	var btn := StyleBoxFlat.new()
	btn.bg_color = SURFACE
	btn.border_width_bottom = 2
	btn.border_color = STEEL
	btn.content_margin_left = SPACE_M
	btn.content_margin_right = SPACE_M
	btn.content_margin_top = SPACE_S
	btn.content_margin_bottom = SPACE_S
	var btn_pressed := btn.duplicate() as StyleBoxFlat
	btn_pressed.border_width_left = 6
	btn_pressed.border_color = FIGHT_RED
	for state in ["normal", "hover", "disabled"]:
		t.set_stylebox(state, "Button", btn)
	t.set_stylebox("pressed", "Button", btn_pressed)
	t.set_stylebox("focus", "Button", btn_pressed)
	for kind in ["LineEdit", "OptionButton", "PopupMenu"]:
		t.set_stylebox("normal",kind,btn)
		t.set_color("font_color",kind,INK)
	return t
