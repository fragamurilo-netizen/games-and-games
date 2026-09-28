class_name AchievementBanner
extends CanvasLayer
## Aviso de conquista desbloqueada: desce do alto da tela com a medalha na cor do nível, o nome
## e a descrição, fica alguns segundos e sobe. Mostra as pendentes uma por vez; tocar abre a
## tela de conquistas.

const SHOW := 3.2

var world: GameWorld = null
var _panel: PanelContainer
var _medal: AchievementMedal
var _title: Label
var _name: Label
var _desc: Label
var _t := 0.0
var _busy := false


## Chamado quando algo é desbloqueado: cria o aviso (se ainda não existe) na próxima quadro.
static func notify(w: GameWorld) -> void:
	if DisplayServer.get_name() == "headless" or UIManager.main == null:
		w.pending_achievements.clear()
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var b := tree.root.get_node_or_null("AchievementBanner") as AchievementBanner
	if b == null:
		b = AchievementBanner.new()
		b.name = "AchievementBanner"
		b.world = w
		tree.root.add_child.call_deferred(b)
	else:
		b.world = w


func _ready() -> void:
	layer = 95
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.1, 0.97)
	sb.set_corner_radius_all(18)
	sb.set_border_width_all(2)
	sb.border_color = Color("#FFC940")
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 18
	sb.content_margin_left = 16
	sb.content_margin_right = 18
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	sb.anti_aliasing = true
	_panel.add_theme_stylebox_override(&"panel", sb)
	var row := UIKit.hbox(14)
	_medal = AchievementMedal.new()
	_medal.custom_minimum_size = Vector2(76, 76)
	_medal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_medal)
	var v := UIKit.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	_title = UIKit.label("CONQUISTA DESBLOQUEADA", "Caps")
	_name = UIKit.label("", "H2")
	_name.add_theme_color_override(&"font_color", UIColors.D_TEXT)
	_desc = UIKit.label("", "Small", true)
	_desc.add_theme_color_override(&"font_color", UIColors.D_TEXT.darkened(0.3))
	v.add_child(_title)
	v.add_child(_name)
	v.add_child(_desc)
	row.add_child(v)
	_panel.add_child(row)
	var tap := Button.new()
	tap.flat = true
	tap.focus_mode = Control.FOCUS_NONE
	tap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tap.pressed.connect(func():
		_t = SHOW
		UIManager.push("achievements"))
	_panel.add_child(tap)
	add_child(_panel)
	_panel.visible = false
	_next()


func _next() -> bool:
	if GameManager.is_simulating(): # a thread do "Simular" está mexendo no mundo
		return false
	if world == null or world.pending_achievements.is_empty():
		return false
	var id := String(world.pending_achievements.pop_front())
	var a: Dictionary = Achievements.CATALOG.get(id, {})
	if a.is_empty():
		return _next()
	var col := Achievements.tier_color(id)
	_medal.setup(id, true)
	_title.text = (I18n.t("Conquista desbloqueada") + " · " + I18n.t(String(Achievements.TIERS[a["tier"]]["name"]))).to_upper()
	_title.add_theme_color_override(&"font_color", col)
	(_panel.get_theme_stylebox(&"panel") as StyleBoxFlat).border_color = col
	_name.text = String(a["name"])
	_desc.text = String(a["desc"])
	_t = 0.0
	_busy = true
	_panel.visible = true
	AudioManager.play("title", -8.0)
	AudioManager.vibrate(60)
	return true


func _process(delta: float) -> void:
	if not _busy:
		# Espera a apresentação de reforço terminar para não cobrir a foto.
		if get_tree().root.get_node_or_null("SigningCeremony") != null:
			return
		if not _next():
			return
	_t += delta
	var vp := get_viewport().get_visible_rect().size
	var w := minf(vp.x - 32.0, 640.0)
	_panel.size = Vector2(w, 0)
	_panel.reset_size()
	_panel.size.x = w
	var enter := clampf(_t / 0.35, 0.0, 1.0)
	var leave := clampf((_t - SHOW) / 0.35, 0.0, 1.0)
	var k := (1.0 - pow(1.0 - enter, 3.0)) * (1.0 - leave * leave)
	_panel.position = Vector2(vp.x * 0.5 - w * 0.5, lerpf(-_panel.size.y - 30.0, 48.0, k))
	_medal.shine = fmod(_t, 2.0)
	_medal.queue_redraw()
	if _t >= SHOW + 0.35:
		_busy = false
		_panel.visible = false
		if world == null or world.pending_achievements.is_empty():
			name = "AchievementBannerDone"
			queue_free()
