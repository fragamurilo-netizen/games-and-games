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


func _ready() -> void:
	back_btn.icon = UIKit.icon("back")
	title_lbl.add_theme_font_override(&"font", get_theme_font(&"font", &"H2"))
	title_lbl.add_theme_font_size_override(&"font_size", 31)
	money_lbl.add_theme_font_size_override(&"font_size", 24)
	bell_btn.icon = UIKit.icon("bell")
	bell_btn.draw.connect(_draw_badge)
	back_btn.pressed.connect(func():
		Sfx.click()
		back_pressed.emit())
	bell_btn.pressed.connect(func():
		Sfx.click()
		bell_pressed.emit())
	menu_btn.icon = UIKit.icon("menu")
	menu_btn.pressed.connect(func():
		Sfx.click()
		menu_pressed.emit())


## Faixa nas duas cores do clube na base da barra (a identidade do save, sempre à vista).
func _draw() -> void:
	if UIColors.TEAM_1.a > 0.0:
		var h := 4.0
		draw_rect(Rect2(0, size.y - h, size.x * 0.72, h), UIColors.TEAM_1)
		draw_rect(Rect2(size.x * 0.72, size.y - h, size.x * 0.28, h), UIColors.TEAM_2)
	else:
		draw_rect(Rect2(0, size.y - 1.0, size.x, 1.0), UITokens.HAIRLINE if not UIColors.light else UIColors.LINE)


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
	subtitle_lbl.text = subtitle
	subtitle_lbl.visible = subtitle != ""
	crest.visible = club != null and not show_back
	money_lbl.visible = club != null
	if club != null:
		crest.set_club(club)
		money_lbl.text = Fmt.money(club.balance)
		money_lbl.add_theme_color_override(&"font_color", UIColors.TEXT if club.balance >= 0 else UIColors.RED)
