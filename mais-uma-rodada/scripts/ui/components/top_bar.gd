class_name TopBar
extends PanelContainer
## Barra superior: voltar, escudo do clube, título, saldo, sino (mensagens e notícias) e menu.

signal back_pressed
signal menu_pressed
signal bell_pressed

@onready var back_btn: Button = $Row/Back
@onready var crest: CrestView = $Row/Crest
@onready var title_lbl: Label = $Row/Titles/Title
@onready var subtitle_lbl: Label = $Row/Titles/Subtitle
@onready var money_lbl: Label = $Row/Money
@onready var bell_btn: Button = $Row/Bell
@onready var menu_btn: Button = $Row/Menu

var _unread := 0
## Quanto a grama da barra escurece: o título, o saldo e os ícones de cal precisam ler por cima.
const GRASS_DARK := 0.2


func _ready() -> void:
	back_btn.icon = UIKit.icon("back")
	# Sobre a grama tudo é de cal, no modo escuro e no claro.
	title_lbl.add_theme_color_override(&"font_color", Grass.CHALK)
	subtitle_lbl.add_theme_color_override(&"font_color", Grass.chalk(0.78))
	for b: Button in [back_btn, bell_btn, menu_btn]:
		for nm in [&"icon_normal_color", &"icon_hover_color", &"icon_pressed_color", &"icon_hover_pressed_color", &"icon_focus_color"]:
			b.add_theme_color_override(nm, Grass.CHALK)
	title_lbl.add_theme_font_override(&"font", get_theme_font(&"font", &"H2"))
	title_lbl.add_theme_font_size_override(&"font_size", 31)
	money_lbl.add_theme_font_size_override(&"font_size", 24)
	title_lbl.resized.connect(_fit_title)
	bell_btn.icon = UIKit.icon("bell")
	bell_btn.draw.connect(_draw_badge)
	back_btn.pressed.connect(func():
		Sfx.play("back", -6.0)
		back_pressed.emit())
	bell_btn.pressed.connect(func():
		Sfx.click()
		bell_pressed.emit())
	menu_btn.icon = UIKit.icon("menu")
	menu_btn.pressed.connect(func():
		Sfx.click()
		menu_pressed.emit())


## A barra é um pedaço do gramado: faixas de corte, o círculo central em volta do escudo (com a
## linha do meio passando por ele) e, na base, a faixa nas duas cores do clube. A grama sobe até a
## borda da tela, por trás do entalhe e da barra de status.
func _draw() -> void:
	var safe := Rect2()
	if is_instance_valid(UIManager.main) and UIManager.main.has_method("safe_margins"):
		safe = UIManager.main.safe_margins()
	var r := Rect2(-safe.position.x, -safe.position.y, size.x + safe.position.x + safe.size.x, size.y + safe.position.y)
	Grass.stripes(self, r, 75.0, GRASS_DARK)
	if crest.visible:
		var c := ($Row as Control).position + crest.position + crest.size * 0.5
		Grass.center_mark(self, c, minf(size.y * 0.5 - 5.0, crest.size.x * 0.5 + 9.0), r, 0.42)
	var h := 5.0
	if UIColors.TEAM_1.a > 0.0:
		draw_rect(Rect2(r.position.x, size.y - h, r.size.x * 0.72, h), UIColors.TEAM_1)
		draw_rect(Rect2(r.position.x + r.size.x * 0.72, size.y - h, r.size.x * 0.28, h), UIColors.TEAM_2)
	else:
		draw_rect(Rect2(r.position.x, size.y - 3.0, r.size.x, 3.0), Grass.chalk(0.85))


## Contador de não lidos: número pequeno no canto do sino, sem cápsula.
func _draw_badge() -> void:
	if _unread <= 0:
		return
	var txt := str(_unread) if _unread < 100 else "99+"
	var font := get_theme_font(&"font", &"Caps")
	var fs := 17
	var w := maxf(22.0, font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 10.0)
	var r := Rect2(bell_btn.size.x - w - 2.0, 4.0, w, 22.0)
	bell_btn.draw_rect(r, UIColors.RED)
	bell_btn.draw_string(font, Vector2(r.position.x + (w - font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x) * 0.5, r.position.y + 17.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


func set_state(title: String, subtitle: String, show_back: bool, club: Club, show_menu: bool = false, unread: int = 0) -> void:
	queue_redraw()
	back_btn.visible = show_back
	menu_btn.visible = show_menu
	bell_btn.visible = show_menu
	_unread = unread
	bell_btn.queue_redraw()
	title_lbl.text = title
	_fit_title.call_deferred()
	subtitle_lbl.text = subtitle
	subtitle_lbl.visible = subtitle != ""
	crest.visible = club != null and not show_back
	money_lbl.visible = club != null
	if club != null:
		crest.set_club(club)
		money_lbl.text = Fmt.money(club.balance)
		money_lbl.add_theme_color_override(&"font_color", Grass.CHALK if club.balance >= 0 else Color("#FFB3B5"))


const TITLE_MAX := 31
const TITLE_MIN := 24


## Título longo no celular ("Caixa de entrada", "Revelados pela base"): a letra encolhe até 24 px
## antes de cortar com reticências.
func _fit_title() -> void:
	if title_lbl == null or title_lbl.size.x <= 8.0:
		return
	var font := title_lbl.get_theme_font(&"font")
	var fs := TITLE_MAX
	var txt := I18n.t(title_lbl.text)
	while fs > TITLE_MIN and font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > title_lbl.size.x:
		fs -= 1
	if title_lbl.get_theme_font_size(&"font_size") != fs:
		title_lbl.add_theme_font_size_override(&"font_size", fs)
