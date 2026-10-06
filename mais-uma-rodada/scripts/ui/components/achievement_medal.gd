class_name AchievementMedal
extends Control
## Medalha de conquista: disco metálico na cor do nível (bronze, prata, ouro, platina) com aro
## serrilhado, brilho e o ícone no centro. Bloqueada, fica cinza e com cadeado.

var id := ""
var got := false
var shine := -1.0 # 0..2 = brilho passando (aviso); < 0 = parado
var _icon: TextureRect


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(ach_id: String, is_unlocked: bool) -> void:
	id = ach_id
	got = is_unlocked
	if _icon == null:
		_icon = TextureRect.new()
		_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_icon)
		resized.connect(_place)
	var a: Dictionary = Achievements.CATALOG.get(id, {})
	_icon.texture = UIKit.icon(String(a.get("icon", "star")) if got else "close")
	_icon.modulate = Achievements.tier_color(id).darkened(0.65) if got else Color(0.55, 0.57, 0.6)
	_place()
	queue_redraw()


func _place() -> void:
	if _icon == null:
		return
	var s := minf(size.x, size.y)
	var k := s * 0.42
	_icon.size = Vector2(k, k)
	_icon.position = size * 0.5 - Vector2(k, k) * 0.5


func _draw() -> void:
	var s := minf(size.x, size.y)
	if s < 4.0:
		return
	var c := size * 0.5
	var r := s * 0.5 - 1.0
	var base := Achievements.tier_color(id) if got else Color("#3A3D44")
	# Aro serrilhado.
	var pts := PackedVector2Array()
	var n := 28
	for i in n * 2:
		var a := TAU * float(i) / float(n * 2)
		var rr := r if i % 2 == 0 else r * 0.92
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, base.darkened(0.35))
	# Disco com degradê (luz do alto à esquerda).
	for i in 8:
		var t := float(i) / 8.0
		draw_circle(c + Vector2(-1, -1) * s * 0.03 * t, r * (0.86 - t * 0.1), base.lerp(base.lightened(0.45), t), true, -1.0, true)
	draw_arc(c, r * 0.7, 0.0, TAU, 48, base.darkened(0.25), maxf(1.0, s * 0.025), true)
	draw_arc(c, r * 0.86, PI * 1.05, PI * 1.6, 24, Color(1, 1, 1, 0.45 if got else 0.12), maxf(1.0, s * 0.03), true)
	if shine >= 0.0 and shine < 1.0 and got:
		var x := lerpf(-r * 0.7, r * 0.7, shine)
		var hy := sqrt(maxf(0.0, r * r * 0.7 - x * x))
		var band := PackedVector2Array([c + Vector2(x, -hy), c + Vector2(x + s * 0.07, -hy), c + Vector2(x + s * 0.02, hy), c + Vector2(x - s * 0.05, hy)])
		draw_colored_polygon(band, Color(1, 1, 1, 0.25))
