class_name TopBar
extends PanelContainer
## Barra superior: voltar, selo da equipe, título e saldo. Montada em código.

signal back_pressed
signal mail_pressed

var back_btn: Button
var badge: TeamBadge
var title_lbl: Label
var subtitle_lbl: Label
var money_lbl: Label
var mail_btn: Button
var _mail_badge: CountBadge

const TITLE_MAX := 31
const TITLE_MIN := 24


func _ready() -> void:
	var row := UIKit.hbox(12)
	add_child(row)
	back_btn = Button.new()
	back_btn.theme_type_variation = "IconButton"
	back_btn.custom_minimum_size = Vector2(72, 72)
	back_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back_btn.tooltip_text = "Voltar"
	back_btn.expand_icon = true
	back_btn.icon = UIKit.icon("back")
	back_btn.pressed.connect(func():
		Sfx.play("back", -6.0)
		back_pressed.emit())
	row.add_child(back_btn)
	badge = TeamBadge.new()
	badge.custom_minimum_size = Vector2(52, 52)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(badge)
	var titles := UIKit.vbox(-4)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(titles)
	title_lbl = UIKit.label("Noite de Luta", "H2")
	title_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_lbl.add_theme_font_size_override(&"font_size", TITLE_MAX)
	title_lbl.resized.connect(_fit_title)
	titles.add_child(title_lbl)
	subtitle_lbl = UIKit.label("", "Small")
	subtitle_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	titles.add_child(subtitle_lbl)
	mail_btn = Button.new()
	mail_btn.theme_type_variation = "IconButton"
	mail_btn.custom_minimum_size = Vector2(64, 64)
	mail_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mail_btn.tooltip_text = "Caixa de entrada"
	mail_btn.expand_icon = true
	mail_btn.icon = UIKit.icon("mail")
	mail_btn.visible = false
	mail_btn.pressed.connect(func():
		Sfx.click()
		mail_pressed.emit())
	_mail_badge = CountBadge.new()
	mail_btn.add_child(_mail_badge)
	row.add_child(mail_btn)
	money_lbl = UIKit.label("", "Stat")
	money_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	money_lbl.add_theme_font_size_override(&"font_size", 24)
	row.add_child(money_lbl)
	row.add_child(UIKit.gap(6))


## Faixa nas duas cores da equipe na base da barra (a identidade do save, sempre à vista).
func _draw() -> void:
	if UIColors.TEAM_1.a > 0.0:
		var h := 4.0
		draw_rect(Rect2(0, size.y - h, size.x * 0.72, h), UIColors.TEAM_1)
		draw_rect(Rect2(size.x * 0.72, size.y - h, size.x * 0.28, h), UIColors.TEAM_2)
	else:
		draw_rect(Rect2(0, size.y - 1.0, size.x, 1.0), UITokens.HAIRLINE)


func set_state(title: String, subtitle: String, show_back: bool, team: Team) -> void:
	queue_redraw()
	back_btn.visible = show_back
	title_lbl.text = title
	_fit_title.call_deferred()
	subtitle_lbl.text = subtitle
	subtitle_lbl.visible = subtitle != ""
	badge.visible = team != null and not show_back
	money_lbl.visible = team != null
	if team != null:
		badge.team = team
		money_lbl.text = Fmt.money(team.balance)
		money_lbl.add_theme_color_override(&"font_color", UIColors.TEXT if team.balance >= 0 else UIColors.RED)


## Título longo no celular: a letra encolhe até 24 px antes de cortar com reticências.
func _fit_title() -> void:
	if title_lbl == null or title_lbl.size.x <= 8.0:
		return
	var font := title_lbl.get_theme_font(&"font")
	var fs := TITLE_MAX
	while fs > TITLE_MIN and font.get_string_size(title_lbl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > title_lbl.size.x:
		fs -= 1
	if title_lbl.get_theme_font_size(&"font_size") != fs:
		title_lbl.add_theme_font_size_override(&"font_size", fs)


## Envelope da caixa de entrada, com o número de mensagens não lidas.
func set_mail(shown: bool, count: int) -> void:
	mail_btn.visible = shown
	_mail_badge.count = count


## Bolinha com número no canto de um botão.
class CountBadge extends Control:
	var count := 0:
		set(v):
			if v != count:
				count = v
				queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		if count <= 0:
			return
		var txt := str(count) if count < 100 else "99"
		var font := get_theme_default_font()
		var fs := 17
		var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var w := maxf(24.0, tw + 12.0)
		var r := Rect2(size.x - w - 2.0, 4.0, w, 24.0)
		var sb := StyleBoxFlat.new()
		sb.bg_color = UIColors.ACCENT
		sb.set_corner_radius_all(12)
		draw_style_box(sb, r)
		draw_string(font, Vector2(r.position.x + (w - tw) * 0.5, r.position.y + 18.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UIColors.ON_ACCENT)
