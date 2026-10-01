class_name Tokens
extends RefCounted
## Tokens de design (Game Design Bible §16 e §24). Toda cor da UI vem daqui;
## nunca use Color literais nas telas.
## Regras: vermelho = confronto/ação (não preenchimento constante);
## dourado = só campeão, legado e Hall da Fama.

const DISPLAY_FONT = preload("res://ui/theme/fonts/ChakraPetch-Bold.ttf")
const BODY_FONT = preload("res://ui/theme/fonts/ChakraPetch-Medium.ttf")
## Linguagem dos menus de UFC Undisputed 3 (2012): faixas vermelhas de título
## e de dicas, painéis claros sobre foto dessaturada, cabeçalhos cinza-escuros,
## colunas em azul e o item selecionado aceso em vermelho com a ponta cortada.
const SLANT := 0.16
static var _italic: FontVariation

const CANVAS := Color("#111417")
const SURFACE := Color("#1B2025")
const PAPER := Color("#F1EEE6")
const INK := Color("#F4F1E8")
const MUTED := Color("#8A939C")
const FIGHT_RED := Color("#C83B3B")
const STEEL := Color("#46535E")
const CHAMP_GOLD := Color("#B88B46")
## Corner azul do fight card; só aparece ao lado do vermelho (tale of the tape).
const CORNER_BLUE := Color("#3E6FA8")

## Semânticas de estado (barras, badges, toasts). Vermelho segue sendo ação/perigo.
const GOOD := Color("#4E9A6B")
const WARN := Color("#D08A2E")
const INFO := Color("#3E6FA8")

## Sede 2D (ui/office). Paleta própria, fosca, sem neon: piso, paredes, móveis.
const OFFICE_WALL := Color("#232A31")
const OFFICE_WALL_TOP := Color("#39434D")
const OFFICE_CARPET := Color("#2B3138")
const OFFICE_CARPET_LINE := Color("#323941")
const OFFICE_WOOD := Color("#4A3A2C")
const OFFICE_WOOD_LINE := Color("#54423233")
const OFFICE_TILE := Color("#3A4148")
const OFFICE_TILE_LINE := Color("#434B53")
const OFFICE_DESK := Color("#5E4B3A")
const OFFICE_DESK_TOP := Color("#7A624B")
const OFFICE_METAL := Color("#8C969F")
const OFFICE_SCREEN := Color("#9EC3D9")
const OFFICE_PLANT := Color("#3F7A4E")
const OFFICE_SHADOW := Color(0, 0, 0, 0.28)
const OFFICE_LOCKED := Color("#15191D")
const OFFICE_GLASS := Color("#9EC3D922")

# Painéis claros (conteúdo) e peças dos menus de 2012.
const PANEL := Color("#E4E6E9")
const PANEL_ROW := Color("#D5D8DC")
const PANEL_LINE := Color("#BEC3C9")
const PANEL_INK := Color("#1C2025")
const PANEL_MUTED := Color("#59616B")
const HEADER_BAR := Color("#4A4F56")
const HEADER_TEXT := Color("#DADDE0")
const TABLE_BLUE := Color("#2B55C4")
const HINT_TEXT := Color("#E2D2A6")
const TITLE_RED := Color("#B51D22")

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


## Display dos títulos e itens de menu: bold reto e levemente encorpado, como
## os letreiros de 2012. (Nome mantido: outras telas já chamam italic_font().)
static func italic_font() -> FontVariation:
	if _italic==null:
		_italic=FontVariation.new();_italic.base_font=DISPLAY_FONT
		_italic.variation_embolden=0.25
	return _italic


## Barra com as pontas cortadas na diagonal (paralelogramo discreto).
static func slanted_box(color: Color, height: float=TOUCH_MIN) -> StyleBoxFlat:
	var box:=StyleBoxFlat.new();box.bg_color=color
	box.skew=Vector2(SLANT,0);box.anti_aliasing=true
	var inset:=SPACE_M+ceilf(height*SLANT*.5)
	box.content_margin_left=inset;box.content_margin_right=inset
	box.content_margin_top=SPACE_S;box.content_margin_bottom=SPACE_S
	return box


## Caixa reta (painéis, campos, linhas de tabela).
static func flat_box(color: Color, border: Color=Color.TRANSPARENT, width: int=0, pad: int=SPACE_M) -> StyleBoxFlat:
	var box:=StyleBoxFlat.new();box.bg_color=color
	if width>0:box.border_color=border;box.set_border_width_all(width)
	box.content_margin_left=pad;box.content_margin_right=pad
	box.content_margin_top=SPACE_S;box.content_margin_bottom=SPACE_S
	return box


## Painel de conteúdo claro com borda fina, como os quadros de 2012.
static func panel_box() -> StyleBoxFlat:
	var box:=flat_box(Color(PANEL,.95),Color.WHITE,2,SPACE_M)
	box.content_margin_top=SPACE_M;box.content_margin_bottom=SPACE_M
	box.shadow_color=Color(0,0,0,.35);box.shadow_size=6
	return box


static func build_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = FONT_BODY
	t.default_font = BODY_FONT
	t.set_font("font", "Button", italic_font())
	t.set_font("font", "OptionButton", DISPLAY_FONT)
	t.set_color("font_color", "Label", PANEL_INK)
	t.set_color("font_color", "Button", PANEL_INK)
	# Seleção: a linha inteira acende em vermelho e o texto fica branco.
	for state in ["font_pressed_color","font_hover_color","font_focus_color","font_hover_pressed_color"]:
		t.set_color(state, "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", PANEL_MUTED)

	t.set_stylebox("panel", "PanelContainer", panel_box())

	var row:=flat_box(Color(PANEL_ROW,.9),PANEL_LINE,0)
	row.border_width_bottom=1;row.border_color=PANEL_LINE
	var lit:=slanted_box(FIGHT_RED)
	var off:=flat_box(Color(PANEL_ROW,.45))
	t.set_stylebox("normal","Button",row)
	t.set_stylebox("disabled","Button",off)
	for state in ["hover","pressed","hover_pressed","focus"]:
		t.set_stylebox(state,"Button",lit)
	for kind in ["LineEdit","OptionButton","SpinBox"]:
		t.set_stylebox("normal",kind,flat_box(Color.WHITE,PANEL_LINE,2))
		t.set_color("font_color",kind,PANEL_INK)
	t.set_stylebox("focus","LineEdit",flat_box(Color.WHITE,TABLE_BLUE,2))
	t.set_stylebox("hover","OptionButton",flat_box(Color.WHITE,FIGHT_RED,2))
	t.set_stylebox("pressed","OptionButton",flat_box(Color.WHITE,FIGHT_RED,2))
	t.set_stylebox("focus","OptionButton",flat_box(Color.WHITE,FIGHT_RED,2))
	for state in ["font_hover_color","font_pressed_color","font_focus_color","font_hover_pressed_color"]:
		t.set_color(state,"OptionButton",PANEL_INK)
	t.set_stylebox("panel","PopupMenu",flat_box(PANEL,PANEL_LINE,2))
	t.set_stylebox("hover","PopupMenu",flat_box(FIGHT_RED))
	t.set_color("font_color","PopupMenu",PANEL_INK)
	t.set_color("font_hover_color","PopupMenu",Color.WHITE)
	t.set_font_size("font_size","PopupMenu",FONT_SMALL+2)
	t.set_color("caret_color","LineEdit",PANEL_INK)
	t.set_stylebox("panel","AcceptDialog",panel_box())
	t.set_stylebox("panel","ConfirmationDialog",panel_box())
	return t
