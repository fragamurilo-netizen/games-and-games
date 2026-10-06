class_name AchievementBanner
extends CanvasLayer
## Aviso de conquista desbloqueada: faixa compacta abaixo da barra superior com a medalha, o
## nome e o nível; aparece por 3,5 s. Mostra as pendentes uma por vez; tocar abre a
## tela de conquistas.

const SHOW := 3.5

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
	# Desbloqueio vindo da thread do "Simular": a árvore de nós só pode ser mexida na principal.
	if OS.get_thread_caller_id() != OS.get_main_thread_id():
		notify.call_deferred(w)
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
	# Aviso compacto (DESIGN.md › Toast): ~108 px, abaixo da barra superior, sem sombra nem
	# brilho. A cor do nível da conquista aparece só no filete da esquerda e na medalha.
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = UIColors.SURFACE_2
	sb.set_corner_radius_all(UITokens.R_SM)
	sb.border_width_left = 4
	sb.border_color = UIColors.GOLD
	sb.content_margin_left = 14
	sb.content_margin_right = 18
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	_panel.add_theme_stylebox_override(&"panel", sb)
	_panel.custom_minimum_size.y = 96
	var row := UIKit.hbox(14)
	_medal = AchievementMedal.new()
	_medal.custom_minimum_size = Vector2(60, 60)
	_medal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_medal)
	var v := UIKit.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	_name = UIKit.label("", "H3")
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title = UIKit.label("", "Small")
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_desc = UIKit.label("", "Small")
	_desc.visible = false
	v.add_child(_name)
	v.add_child(_title)
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
	_title.text = I18n.t("Conquista desbloqueada") + ", " + I18n.t(String(Achievements.TIERS[a["tier"]]["name"])).to_lower()
	(_panel.get_theme_stylebox(&"panel") as StyleBoxFlat).border_color = col
	_panel.tooltip_text = String(a["desc"])
	_name.text = String(a["name"])
	_desc.text = String(a["desc"])
	_t = 0.0
	_busy = true
	_panel.visible = true
	Sfx.play("title", -8.0)
	Sfx.vibrate(60)
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
	var w := minf(vp.x - UITokens.GUTTER * 2.0, 620.0)
	_panel.size = Vector2(w, 0)
	_panel.reset_size()
	_panel.size.x = w
	# Logo abaixo da barra superior (e da área segura), sem cobrir título e abas por muito tempo.
	var top := 24.0
	if UIManager.main != null:
		var bar: Control = UIManager.main.top_bar
		top = (bar.get_global_rect().end.y if bar.visible else UIManager.main.safe_margins().position.y) + 12.0
	var enter := clampf(_t / 0.2, 0.0, 1.0)
	var leave := clampf((_t - SHOW) / 0.25, 0.0, 1.0)
	_panel.modulate.a = enter * (1.0 - leave)
	var slide := 0.0 if AppSettings.reduce_motion else (1.0 - enter) * -12.0
	_panel.position = Vector2(vp.x * 0.5 - w * 0.5, top + slide)
	if _t >= SHOW + 0.35:
		_busy = false
		_panel.visible = false
		if world == null or world.pending_achievements.is_empty():
			name = "AchievementBannerDone"
			queue_free()
