@tool
class_name PortraitView
extends Control
## Retrato procedural: rosto, pele, cabelo, barba, olhos, sobrancelhas e acessórios,
## tudo derivado do face_seed do jogador (mesmo jogador = mesmo rosto, sempre).

const SKIN: Array[Color] = [Color("#F3CDB0"), Color("#E6B48E"), Color("#CC9368"), Color("#A9714A"), Color("#7E5033"), Color("#5B3822")]
const HAIR: Array[Color] = [Color("#16110E"), Color("#3B2618"), Color("#6A4428"), Color("#B78A4C"), Color("#E0C27A"), Color("#8E3B1E")]
## Pesos de tom de pele por etnia (índices de nations.json → ethnicities: nor, eur, med, arb, lat, and, mix, afr, eas).
const ETH_SKIN: Array = [
	[2.0, 1.2, 0.2, 0.0, 0.0, 0.0],
	[1.4, 1.6, 0.6, 0.05, 0.0, 0.0],
	[0.6, 1.6, 1.4, 0.4, 0.05, 0.0],
	[0.2, 1.0, 1.6, 1.0, 0.3, 0.05],
	[0.2, 1.0, 1.6, 1.2, 0.4, 0.1],
	[0.0, 0.3, 1.2, 1.6, 0.8, 0.2],
	[0.05, 0.3, 0.9, 1.6, 1.4, 0.8],
	[0.0, 0.05, 0.3, 1.0, 1.6, 1.8],
	[1.6, 1.6, 0.8, 0.1, 0.0, 0.0],
]

@export var face_seed: int = 12345:
	set(v):
		face_seed = v
		queue_redraw()
@export var eth: int = 1:
	set(v):
		eth = v
		queue_redraw()
@export var age: int = 25:
	set(v):
		age = v
		queue_redraw()
@export var shirt_color: Color = Color("#1B3A8C"):
	set(v):
		shirt_color = v
		queue_redraw()
@export var bg_color: Color = Color("#1D2B3C"):
	set(v):
		bg_color = v
		queue_redraw()


func set_player(p: Player, club: Club, year: int) -> void:
	face_seed = p.face_seed
	eth = p.eth
	age = p.age(year)
	if club != null:
		shirt_color = club.primary_color()
		bg_color = club.primary_color().darkened(0.55)
	queue_redraw()


func _draw() -> void:
	var s := minf(size.x, size.y)
	if s <= 4.0:
		return
	var o := Vector2((size.x - s) * 0.5, (size.y - s) * 0.5)
	var rng := RandomNumberGenerator.new()
	rng.seed = face_seed
	var c := o + Vector2(s * 0.5, s * 0.5)
	# Fundo circular
	draw_circle(c, s * 0.5, bg_color)
	var weights: Array = ETH_SKIN[clampi(eth, 0, ETH_SKIN.size() - 1)]
	var skin: Color = SKIN[RngUtil.weighted_index(rng, weights)]
	var hair_i := rng.randi_range(0, 2) if weights[4] + weights[5] > 1.0 else RngUtil.weighted_index(rng, [3.0, 3.0, 2.0, 1.2, 0.8, 0.5])
	var hair: Color = HAIR[hair_i]
	if age >= 34 and rng.randf() < 0.6:
		hair = hair.lerp(Color("#B8B8B8"), clampf((age - 32) * 0.12, 0.2, 0.8))
	var face_w := s * rng.randf_range(0.2, 0.25)
	var face_h := s * rng.randf_range(0.26, 0.31)
	var head := c + Vector2(0, -s * 0.04)
	# Ombros / camisa
	var shoulders := PackedVector2Array()
	for i in 21:
		var a := PI + PI * i / 20.0
		shoulders.append(c + Vector2(cos(a) * s * 0.42, s * 0.52 + sin(a) * s * 0.2))
	var clipped := Geometry2D.intersect_polygons(shoulders, _circle(c, s * 0.5, 40))
	for piece in clipped:
		draw_colored_polygon(piece, shirt_color)
	# Pescoço
	draw_rect(Rect2(head.x - face_w * 0.45, head.y + face_h * 0.6, face_w * 0.9, s * 0.14), skin.darkened(0.12))
	# Orelhas
	draw_circle(head + Vector2(-face_w * 0.98, 0.0), face_w * 0.22, skin.darkened(0.06))
	draw_circle(head + Vector2(face_w * 0.98, 0.0), face_w * 0.22, skin.darkened(0.06))
	# Cabelo de trás (longo/afro)
	var style := rng.randi_range(0, 8)
	if style == 6:
		draw_circle(head + Vector2(0, -face_h * 0.25), face_w * 1.35, hair)
	elif style == 7:
		draw_colored_polygon(_ellipse(head + Vector2(0, face_h * 0.1), face_w * 1.15, face_h * 1.15, 32), hair)
	# Rosto
	draw_colored_polygon(_ellipse(head, face_w, face_h, 36), skin)
	# Cabelo
	match style:
		0, 1:
			draw_colored_polygon(_cap(head, face_w * 1.04, face_h, 0.35), hair)
		2:
			draw_colored_polygon(_cap(head, face_w * 1.02, face_h, 0.18), hair.lerp(skin, 0.35))
		3:
			for i in 9:
				var a := PI + PI * i / 8.0
				draw_circle(head + Vector2(cos(a) * face_w * 0.9, sin(a) * face_h * 0.75), face_w * 0.3, hair)
		4:
			draw_colored_polygon(_cap(head, face_w * 1.04, face_h, 0.42), hair)
			draw_colored_polygon(PackedVector2Array([head + Vector2(-face_w * 0.9, -face_h * 0.55), head + Vector2(face_w * 0.2, -face_h * 0.55), head + Vector2(-face_w * 0.7, -face_h * 0.2)]), hair)
		5:
			draw_rect(Rect2(head.x - face_w * 0.18, head.y - face_h * 1.1, face_w * 0.36, face_h * 0.6), hair)
		6:
			draw_colored_polygon(_cap(head, face_w * 1.1, face_h, 0.4), hair)
		7:
			draw_colored_polygon(_cap(head, face_w * 1.05, face_h, 0.4), hair)
		_:
			pass # careca
	# Sobrancelhas
	var brow_y := head.y - face_h * 0.18
	var brow_w := face_w * rng.randf_range(0.32, 0.42)
	var brow_t := maxf(1.2, s * rng.randf_range(0.012, 0.022))
	var tilt := rng.randf_range(-0.06, 0.08) * s
	var brow_col := hair.darkened(0.2) if hair_i != 4 else hair.darkened(0.45)
	draw_line(Vector2(head.x - face_w * 0.62, brow_y + tilt * 0.3), Vector2(head.x - face_w * 0.62 + brow_w, brow_y - tilt * 0.3), brow_col, brow_t, true)
	draw_line(Vector2(head.x + face_w * 0.62, brow_y + tilt * 0.3), Vector2(head.x + face_w * 0.62 - brow_w, brow_y - tilt * 0.3), brow_col, brow_t, true)
	# Olhos
	var eye_y := head.y - face_h * 0.02
	var eye_dx := face_w * rng.randf_range(0.4, 0.48)
	var eye_r := maxf(1.2, s * rng.randf_range(0.018, 0.024))
	for sx in [-1.0, 1.0]:
		var ec := Vector2(head.x + sx * eye_dx, eye_y)
		draw_colored_polygon(_ellipse(ec, eye_r * 1.6, eye_r * 1.0, 16), Color(0.98, 0.98, 0.96))
		draw_circle(ec, eye_r * 0.85, Color("#2A1E16"))
	# Nariz
	var nose_col := skin.darkened(0.22)
	draw_line(Vector2(head.x, eye_y + face_h * 0.08), Vector2(head.x - face_w * 0.08, eye_y + face_h * 0.36), nose_col, maxf(1.0, s * 0.012), true)
	draw_line(Vector2(head.x - face_w * 0.08, eye_y + face_h * 0.36), Vector2(head.x + face_w * 0.1, eye_y + face_h * 0.38), nose_col, maxf(1.0, s * 0.012), true)
	# Barba
	var beard := rng.randi_range(0, 5)
	if age < 20:
		beard = 0 if rng.randf() < 0.8 else 1
	var beard_col := hair.darkened(0.1)
	match beard:
		1:
			var stub := _ellipse(head + Vector2(0, face_h * 0.35), face_w * 0.95, face_h * 0.6, 28)
			for piece in Geometry2D.intersect_polygons(stub, _ellipse(head, face_w, face_h, 36)):
				draw_colored_polygon(piece, Color(beard_col.r, beard_col.g, beard_col.b, 0.35))
		2:
			var full := PackedVector2Array()
			for i in 17:
				var a := PI * i / 16.0
				full.append(head + Vector2(cos(a) * face_w * 1.02, face_h * 0.2 + sin(a) * face_h * 0.95))
			for piece in Geometry2D.intersect_polygons(full, _ellipse(head + Vector2(0, face_h * 0.05), face_w * 1.03, face_h * 1.05, 36)):
				draw_colored_polygon(piece, beard_col)
		3:
			draw_colored_polygon(_ellipse(head + Vector2(0, face_h * 0.82), face_w * 0.28, face_h * 0.2, 16), beard_col)
			draw_line(Vector2(head.x - face_w * 0.3, head.y + face_h * 0.5), Vector2(head.x + face_w * 0.3, head.y + face_h * 0.5), beard_col, maxf(1.5, s * 0.02), true)
	# Boca
	var mouth_y := head.y + face_h * 0.55
	var smile := rng.randf_range(-0.2, 0.6)
	draw_arc(Vector2(head.x, mouth_y - face_h * 0.12 * smile), face_w * 0.3, PI * 0.2, PI * 0.8, 10, Color("#5A2F28"), maxf(1.2, s * 0.014), true)
	# Faixa de cabelo (raro)
	if rng.randf() < 0.07 and style != 8:
		draw_line(Vector2(head.x - face_w, head.y - face_h * 0.5), Vector2(head.x + face_w, head.y - face_h * 0.5), Color.WHITE, maxf(1.5, s * 0.03), true)


static func _ellipse(c: Vector2, rx: float, ry: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


static func _circle(c: Vector2, r: float, n: int) -> PackedVector2Array:
	return _ellipse(c, r, r, n)


## Calota de cabelo: parte superior do rosto até `depth` (0..1) abaixo do topo.
static func _cap(c: Vector2, rx: float, ry: float, depth: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var cut := -ry + ry * 2.0 * depth
	for i in 25:
		var a := PI + PI * i / 24.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry * 1.08))
	pts.append(c + Vector2(rx * 0.95, cut))
	pts.append(c + Vector2(-rx * 0.95, cut))
	return pts
