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
	title_lbl.uppercase = true
	title_lbl.add_theme_font_override(&"font", get_theme_font(&"font", &"Title"))
	title_lbl.add_theme_font_size_override(&"font_size", 32)
	money_lbl.add_theme_font_size_override(&"font_size", 28)
	$Row.resized.connect(queue_redraw)
	money_lbl.item_rect_changed.connect(queue_redraw)
	back_btn.pressed.connect(func():
		AudioManager.click()
		back_pressed.emit())


## Fundo com a identidade do clube: a cor principal nasce atrás do escudo e se dissolve para a
## direita, com riscas diagonais discretas na segunda cor; filete nas duas cores na base e
## o saldo numa cápsula.
func _draw() -> void:
	var has_team := UIColors.TEAM_1.a > 0.0
	if has_team:
		var c1 := UIColors.ACCENT
		var steps := 20
		for i in steps:
			var t := float(i) / steps
			var col := c1
			col.a = (0.5 if not UIColors.light else 0.26) * pow(1.0 - t, 1.6)
			draw_rect(Rect2(size.x * 0.75 * t, 0, size.x * 0.75 / steps + 1.0, size.y), col)
		var band := Color.WHITE if not UIColors.light else Color.BLACK
		band.a = 0.035
		var x := -size.y
		while x < size.x * 0.6:
			draw_colored_polygon(PackedVector2Array([Vector2(x + size.y, 0), Vector2(x + size.y + 10.0, 0), Vector2(x + 10.0, size.y), Vector2(x, size.y)]), band)
			x += 26.0
		var h := 3.0
		var y := size.y - h
		draw_rect(Rect2(0, y, size.x * 0.68, h), UIColors.TEAM_1)
		draw_rect(Rect2(size.x * 0.68, y, size.x * 0.32, h), UIColors.TEAM_2)
	else:
		draw_rect(Rect2(0, size.y - 1.0, size.x, 1.0), UITokens.HAIRLINE if not UIColors.light else UIColors.LINE)
	if money_lbl != null and money_lbl.visible:
		var r := Rect2(money_lbl.position + $Row.position, money_lbl.size).grow_individual(14, 2, 14, 2)
		var pill := StyleBoxFlat.new()
		pill.bg_color = Color(0, 0, 0, 0.35) if not UIColors.light else Color(1, 1, 1, 0.85)
		pill.border_color = UITokens.HAIRLINE if not UIColors.light else UIColors.LINE
		pill.set_border_width_all(1)
		pill.set_corner_radius_all(int(r.size.y * 0.5))
		pill.anti_aliasing = true
		draw_style_box(pill, r)


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
