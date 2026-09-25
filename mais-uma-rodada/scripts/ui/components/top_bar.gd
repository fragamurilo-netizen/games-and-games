class_name TopBar
extends PanelContainer
## Barra superior: voltar, escudo do clube, título/subtítulo e saldo.

signal back_pressed

@onready var back_btn: Button = $Row/Back
@onready var crest: CrestView = $Row/Crest
@onready var title_lbl: Label = $Row/Titles/Title
@onready var subtitle_lbl: Label = $Row/Titles/Subtitle
@onready var money_lbl: Label = $Row/Money


func _ready() -> void:
	back_btn.icon = UIKit.icon("back")
	back_btn.pressed.connect(func():
		AudioManager.click()
		back_pressed.emit())


## Faixa fina nas cores do clube embaixo da barra.
func _draw() -> void:
	if UIColors.TEAM_1.a <= 0.0:
		return
	var h := 4.0
	var y := size.y - h
	draw_rect(Rect2(0, y, size.x * 0.68, h), UIColors.TEAM_1)
	draw_rect(Rect2(size.x * 0.68, y, size.x * 0.32, h), UIColors.TEAM_2)


func set_state(title: String, subtitle: String, show_back: bool, club: Club) -> void:
	queue_redraw()
	back_btn.visible = show_back
	title_lbl.text = title
	subtitle_lbl.text = subtitle
	subtitle_lbl.visible = subtitle != ""
	crest.visible = club != null and not show_back
	money_lbl.visible = club != null
	if club != null:
		crest.set_club(club)
		money_lbl.text = Fmt.money(club.balance)
		money_lbl.add_theme_color_override(&"font_color", UIColors.GREEN if club.balance >= 0 else UIColors.RED)
