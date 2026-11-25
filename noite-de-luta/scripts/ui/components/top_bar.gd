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
var _money_box: PanelContainer
var _cash := 0.0
var _cash_team := -1

const TITLE_MAX := 34
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
	badge.custom_minimum_size = Vector2(56, 56)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(badge)
	var titles := UIKit.vbox(-4)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(titles)
	title_lbl = UIKit.label("Noite de Luta", "Screen")
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
	# O caixa numa cápsula, com a moeda dourada.
	_money_box = PanelContainer.new()
	var mb := StyleBoxFlat.new()
	mb.bg_color = UIColors.SURFACE_3
	mb.set_corner_radius_all(UITokens.CUT_SM + 2)
	mb.corner_detail = 1
	mb.content_margin_left = 12
	mb.content_margin_right = 16
	mb.content_margin_top = 6
	mb.content_margin_bottom = 6
	mb.anti_aliasing = true
	_money_box.add_theme_stylebox_override(&"panel", mb)
	_money_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_money_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mr := UIKit.hbox(6)
	mr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var coin := UIKit.icon_rect("money", 24, UIColors.GOLD)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mr.add_child(coin)
	money_lbl = UIKit.label("", "Stat")
	money_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	money_lbl.add_theme_font_size_override(&"font_size", 23)
	mr.add_child(money_lbl)
	_money_box.add_child(mr)
	row.add_child(_money_box)


func set_state(title: String, subtitle: String, show_back: bool, team: Team) -> void:
	queue_redraw()
	back_btn.visible = show_back
	title_lbl.text = title
	_fit_title.call_deferred()
	subtitle_lbl.text = subtitle
	subtitle_lbl.visible = subtitle != ""
	badge.visible = team != null and not show_back
	_money_box.visible = team != null
	if team != null:
		badge.team = team
		var base := UIColors.TEXT if team.balance >= 0 else UIColors.RED
		money_lbl.add_theme_color_override(&"font_color", base)
		# O saldo mudou com a barra à vista (mesma equipe): o número conta até o valor novo e
		# pisca verde ou vermelho. Entrar dinheiro tem som; sair, não.
		if _cash_team == team.id and absf(team.balance - _cash) >= 1.0 and is_visible_in_tree() and Anim.on():
			var up := team.balance > _cash
			Anim.count(money_lbl, _cash, team.balance, func(v: float) -> String: return Fmt.money(v), 0.6)
			Anim.flash(money_lbl, UIColors.GREEN if up else UIColors.RED, base, 1.0)
			if up:
				DashKit.later(0.25, "cash", -11.0)
		else:
			money_lbl.text = Fmt.money(team.balance)
		_cash = team.balance
		_cash_team = team.id
	else:
		_cash_team = -1


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
	# Chegou pendência nova com o envelope à vista: ele dá um pulso.
	if shown and count > _mail_badge.count and mail_btn.is_visible_in_tree():
		Anim.pulse(mail_btn, 1.18, 0.4)
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
		sb.bg_color = UIColors.RED
		sb.border_color = UIColors.BG
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(6)
		sb.corner_detail = 1
		sb.anti_aliasing = true
		draw_style_box(sb, r)
		draw_string(font, Vector2(r.position.x + (w - tw) * 0.5, r.position.y + 18.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
