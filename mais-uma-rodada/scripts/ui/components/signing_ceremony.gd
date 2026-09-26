class_name SigningCeremony
extends Control
## Apresentação animada das contratações importantes do usuário: faixas nas cores do clube
## cruzam a tela, o escudo surge com "É OFICIAL", a foto do jogador aparece no painel de
## patrocínio com os flashes das câmeras, ele ergue a camisa com o nome e o número, e o confete
## sai junto com a ficha (posição, idade, de onde veio, quanto custou, até quando assinou).
## Toque adianta para o fim; "Continuar" fecha. As pendentes ficam em world.pending_signings.

signal finished

const T_CREST := 0.7
const T_PHOTO := 1.9
const T_LIFT := 2.6
const T_BURST := 3.5
const T_END := 4.2

var world: GameWorld = null
var player: Player = null
var club: Club = null
var fee := 0
var from_club: Club = null
var number := 0

var _t := 0.0
var _photo: SigningPhoto
var _crest: CrestView
var _fx: Control
var _buttons: Control
var _confetti: Array = []
var _rng := RandomNumberGenerator.new()
var _c1 := Color("#1B3A8C")
var _c2 := Color("#FFFFFF")


## Toca a próxima apresentação pendente (se houver). Devolve true se começou uma.
static func play_pending(w: GameWorld) -> bool:
	if w == null or w.pending_signings.is_empty():
		return false
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root.get_node_or_null("SigningCeremony") != null:
		return false
	var d: Dictionary = w.pending_signings.pop_front()
	var p := w.player(int(d.get("player", -1)))
	var c := w.club(int(d.get("club", -1)))
	if p == null or c == null or p.club_id != c.id:
		return play_pending(w)
	var layer := CanvasLayer.new()
	layer.name = "SigningCeremony"
	layer.layer = 90
	var cer := SigningCeremony.new()
	cer.world = w
	cer.player = p
	cer.club = c
	cer.fee = int(d.get("fee", 0))
	cer.from_club = w.club(int(d.get("from", -1)))
	cer.number = p.shirt
	tree.root.add_child(layer)
	layer.add_child(cer)
	cer.start()
	cer.finished.connect(func(): play_pending(w), CONNECT_ONE_SHOT | CONNECT_DEFERRED)
	return true


func start() -> void:
	_c1 = Color(club.color1)
	_c2 = Color(club.color2)
	if absf(_c1.get_luminance() - _c2.get_luminance()) < 0.12:
		_c2 = Color.WHITE if _c1.get_luminance() < 0.5 else Color("#111111")
	_rng.seed = hash([player.id, club.id])
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 10
	mouse_filter = Control.MOUSE_FILTER_STOP
	_crest = UIKit.crest(club, 200)
	_crest.custom_minimum_size = Vector2.ZERO
	add_child(_crest)
	_photo = SigningPhoto.new()
	_photo.size_flags_horizontal = Control.SIZE_FILL
	_photo.setup(world, player, club, number, world.year)
	_photo.lift = 0.0
	_photo.modulate.a = 0.0
	add_child(_photo)
	_fx = Control.new()
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fx.draw.connect(_draw_fx)
	add_child(_fx)
	_buttons = UIKit.vbox(10)
	_buttons.modulate.a = 0.0
	var go := UIKit.button("CONTINUAR", "PrimaryButton", func(): _end(), "check")
	_buttons.add_child(go)
	var see := UIKit.button("Ver jogador", "GhostButton", func():
		var pid := player.id
		_end()
		UIManager.push("player", {"id": pid}), "shirt")
	for st in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color"]:
		see.add_theme_color_override(st, UIColors.D_TEXT)
	_buttons.add_child(see)
	add_child(_buttons)
	var skip := UIKit.button("Pular", "GhostButton", func(): _end())
	skip.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	skip.position = Vector2(-150, 40)
	skip.custom_minimum_size = Vector2(120, 56)
	for st in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color"]:
		skip.add_theme_color_override(st, UIColors.D_TEXT)
	add_child(skip)
	AudioManager.play("whistle", -8.0)
	set_process(true)
	_layout()


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		if _t < T_BURST:
			_t = T_BURST - 0.01
		accept_event()


func _end() -> void:
	if is_queued_for_deletion():
		return
	set_process(false)
	finished.emit()
	if get_parent() is CanvasLayer:
		get_parent().name = "SigningCeremonyDone"
		get_parent().queue_free()
	else:
		queue_free()


func _burst() -> void:
	var palette := [_c1, _c2, _c1.lightened(0.3), UIColors.D_GOLD]
	for k in 120:
		var pos := Vector2(size.x * _rng.randf_range(0.2, 0.8), size.y * 0.2)
		var ang := _rng.randf_range(-PI * 0.95, -PI * 0.05)
		var spd := _rng.randf_range(320, 860)
		_confetti.append([pos, Vector2(cos(ang), sin(ang)) * spd, _rng.randf() * TAU, _rng.randf_range(-8, 8), palette[k % palette.size()], Vector2(_rng.randf_range(8, 15), _rng.randf_range(12, 22))])
	AudioManager.play("sign")
	AudioManager.play("title", -6.0)
	AudioManager.vibrate(160)


func _process(delta: float) -> void:
	var before := _t
	_t += delta
	if before < T_BURST and _t >= T_BURST:
		_burst()
	for c in _confetti:
		var vel: Vector2 = c[1]
		vel.y += 700.0 * delta
		vel.x *= 0.99
		c[1] = vel
		c[0] = (c[0] as Vector2) + vel * delta
		c[2] = float(c[2]) + float(c[3]) * delta
	_confetti = _confetti.filter(func(c): return (c[0] as Vector2).y < size.y + 40.0)
	_layout()
	queue_redraw()
	_fx.queue_redraw()


static func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return 1.0 - pow(1.0 - x, 3.0)


static func _back(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	var c1 := 1.70158
	return 1.0 + (c1 + 1.0) * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)


func _photo_rect() -> Rect2:
	var pw := minf(size.x - 48.0, 680.0)
	var ph := pw * 0.7
	return Rect2(size.x * 0.5 - pw * 0.5, size.y * 0.2, pw, ph)


func _layout() -> void:
	if _photo == null:
		return
	var pr := _photo_rect()
	# Escudo: surge no centro e sobe para o alto da foto quando ela aparece.
	var pop := _back((_t - T_CREST) / 0.5)
	var up := _ease((_t - T_PHOTO + 0.3) / 0.6)
	var cs := lerpf(260.0, 96.0, up) * pop
	var cc := Vector2(size.x * 0.5, lerpf(size.y * 0.42, pr.position.y - 58.0, up))
	_crest.size = Vector2(cs, cs)
	_crest.position = cc - Vector2(cs, cs) * 0.5
	_crest.visible = cs > 1.0
	# Foto: entra com zoom leve.
	var ap := _ease((_t - T_PHOTO) / 0.6)
	var zoom := lerpf(1.08, 1.0, ap)
	_photo.size = pr.size
	_photo.pivot_offset = pr.size * 0.5
	_photo.scale = Vector2.ONE * zoom
	_photo.position = pr.position
	_photo.modulate.a = ap
	_photo.lift = _back((_t - T_LIFT) / 0.8)
	# Botões depois da ficha.
	var bw := minf(size.x - 48.0, 520.0)
	_buttons.size = Vector2(bw, 0)
	_buttons.position = Vector2(size.x * 0.5 - bw * 0.5, size.y - 190.0)
	_buttons.modulate.a = _ease((_t - T_END) / 0.4)
	_buttons.visible = _t >= T_END


func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.05, 1.0))
	# Faixas diagonais nas cores do clube cruzando a tela.
	var sweep := _ease(_t / 0.7)
	var fade := 1.0 - 0.75 * _ease((_t - 1.0) / 0.8)
	for k in 3:
		var col := (_c1 if k != 1 else _c2)
		col.a = 0.9 * fade if k != 1 else 0.55 * fade
		var bw := h * (0.22 if k != 1 else 0.06)
		var off := lerpf(-w - h, 0.0, _ease((_t - k * 0.08) / 0.7)) + (k - 1) * h * 0.2
		var x0 := off + w * 0.2
		draw_colored_polygon(PackedVector2Array([Vector2(x0, h), Vector2(x0 + bw, h), Vector2(x0 + bw + h, 0), Vector2(x0 + h, 0)]), col)
	# Raios girando atrás do escudo e da foto.
	var center := Vector2(w * 0.5, h * 0.4)
	var ray_col := _c1.lightened(0.35)
	ray_col.a = 0.08 * sweep
	for k in 16:
		var a0 := _t * 0.2 + TAU * k / 16.0
		var a1 := a0 + TAU / 16.0 * 0.45
		draw_colored_polygon(PackedVector2Array([center, center + Vector2(cos(a0), sin(a0)) * h, center + Vector2(cos(a1), sin(a1)) * h]), ray_col)
	for k in 8:
		draw_circle(center, 80.0 + k * 34.0, Color(1, 1, 1, 0.02 * sweep))


## Textos, moldura da foto, flash e confete (por cima da foto).
func _draw_fx() -> void:
	var cv := _fx
	var w := size.x
	var font := get_theme_font(&"font", &"Title") if has_theme_font(&"font", &"Title") else get_theme_default_font()
	var font_caps := get_theme_font(&"font", &"Stat") if has_theme_font(&"font", &"Stat") else font
	var light := UIColors.D_TEXT
	var muted := UIColors.D_TEXT.darkened(0.3)
	var accent := _c1.lightened(0.45) if _c1.get_luminance() < 0.35 else _c1
	# "É OFICIAL" antes da foto.
	var t1 := clampf((_t - T_CREST - 0.2) / 0.4, 0.0, 1.0) * (1.0 - _ease((_t - T_PHOTO + 0.2) / 0.4))
	if t1 > 0.0:
		var msg := "É OFICIAL"
		var fs := 64
		var tw := font.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		cv.draw_string(font, Vector2(w * 0.5 - tw * 0.5, size.y * 0.42 + 190.0), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(light, t1))
		var sub := club.name.to_upper()
		var sfs := 24
		var sw := font_caps.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs).x
		cv.draw_string(font_caps, Vector2(w * 0.5 - sw * 0.5, size.y * 0.42 + 232.0), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs, Color(accent, t1))
	# Moldura da foto.
	var pr := _photo_rect()
	var ap := _ease((_t - T_PHOTO) / 0.6)
	if ap > 0.0:
		cv.draw_rect(pr.grow(3.0), Color(_c2, 0.85 * ap), false, 3.0)
		cv.draw_rect(Rect2(pr.position.x - 3.0, pr.end.y + 3.0, pr.size.x + 6.0, 6.0), Color(_c1, ap))
	# Flash da foto quando ele ergue a camisa.
	var fl := 1.0 - clampf((_t - T_LIFT - 0.55) / 0.35, 0.0, 1.0)
	if _t > T_LIFT + 0.55 and fl > 0.0:
		cv.draw_rect(pr, Color(1, 1, 1, 0.55 * fl))
	# Ficha do jogador embaixo da foto.
	var ft := _ease((_t - T_BURST + 0.2) / 0.5)
	if ft > 0.0:
		var y := pr.end.y + 64.0 + (1.0 - ft) * 30.0
		var nm := player.display_name().to_upper()
		var nfs := 52
		var nw := font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs).x
		if nw > w - 40.0:
			nfs = int(nfs * (w - 40.0) / nw)
			nw = font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs).x
		cv.draw_string(font, Vector2(w * 0.5 - nw * 0.5, y), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs, Color(light, ft))
		var line1 := "%s · %d anos · %s · camisa %d" % [Pos.name_of(player.position), player.age(world.year), DatabaseManager.nation_name(player.nationality), number]
		_center_text(cv, font_caps, line1, y + 44.0, 22, Color(accent, ft))
		var parts: Array = []
		if from_club != null:
			parts.append("Vem do %s" % from_club.short_name)
		else:
			parts.append("Chega sem custos")
		if fee > 0:
			parts.append(Fmt.money(fee))
		parts.append("contrato até %d" % player.contract_end)
		_center_text(cv, font_caps, " · ".join(parts), y + 80.0, 20, Color(muted, ft))
		var ovr := "OVR %d" % player.overall
		_center_text(cv, font, ovr, y + 126.0, 34, Color(UIColors.D_GOLD, ft))
	# Confete.
	for c in _confetti:
		var pos: Vector2 = c[0]
		var sz: Vector2 = c[5]
		cv.draw_set_transform(pos, float(c[2]), Vector2.ONE)
		cv.draw_rect(Rect2(-sz * 0.5, sz), c[4])
	cv.draw_set_transform_matrix(Transform2D.IDENTITY)


func _center_text(cv: Control, font: Font, txt: String, y: float, fs: int, col: Color) -> void:
	var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if tw > size.x - 40.0:
		fs = maxi(10, int(fs * (size.x - 40.0) / tw))
		tw = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	cv.draw_string(font, Vector2(size.x * 0.5 - tw * 0.5, y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
