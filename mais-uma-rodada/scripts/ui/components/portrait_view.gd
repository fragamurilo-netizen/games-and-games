@tool
class_name PortraitView
extends Control
## Retrato 2D procedural em camadas: fundo, cabelo de trás, camisa, pescoço, orelhas, rosto com
## sombra e luz, barba, olhos, sobrancelhas, nariz, boca, rugas, cabelo e acessórios.
## Os traços vêm de FaceGen (semente + etnia + idade); uma foto importada no editor substitui tudo.

@export var face_seed: int = 12345:
	set(v):
		face_seed = v
		_dirty = true
		queue_redraw()
@export var eth: int = 1:
	set(v):
		eth = v
		_dirty = true
		queue_redraw()
@export var age: int = 25:
	set(v):
		age = v
		_dirty = true
		queue_redraw()
@export var shirt_color: Color = Color("#1B3A8C"):
	set(v):
		shirt_color = v
		queue_redraw()
@export var trim_color: Color = Color("#FFFFFF"):
	set(v):
		trim_color = v
		queue_redraw()
@export var bg_color: Color = Color("#1D2B3C"):
	set(v):
		bg_color = v
		queue_redraw()
## Roupa de treinador/dirigente (terno) em vez da camisa do clube.
@export var suit: bool = false:
	set(v):
		suit = v
		queue_redraw()

var look: Dictionary = {}:
	set(v):
		look = v
		_dirty = true
		queue_redraw()
var photo: Texture2D = null:
	set(v):
		photo = v
		queue_redraw()

var _f: Dictionary = {}
var _dirty := true


func set_player(p: Player, club: Club, year: int) -> void:
	face_seed = p.face_seed
	eth = p.eth
	age = p.age(year)
	look = p.look
	photo = CustomAssets.texture(String(p.look.get("photo", "")))
	if club != null:
		shirt_color = club.primary_color()
		trim_color = club.secondary_color()
		bg_color = club.primary_color().darkened(0.6)
	queue_redraw()


func set_person(seed_value: int, eth_: int, age_: int, club: Club) -> void:
	face_seed = seed_value
	eth = eth_
	age = age_
	suit = true
	if club != null:
		trim_color = club.primary_color()
		bg_color = club.primary_color().darkened(0.6)


func _draw() -> void:
	var s := minf(size.x, size.y)
	if s <= 4.0:
		return
	var o := Vector2((size.x - s) * 0.5, (size.y - s) * 0.5)
	var c := o + Vector2(s * 0.5, s * 0.5)
	if photo != null:
		_draw_photo(c, s)
		return
	if _dirty or _f.is_empty():
		_f = FaceGen.features(face_seed, eth, age, look)
		_dirty = false
	var f := _f
	var skin: Color = f["skin"]
	var hair: Color = f["hair"]
	var fw: float = float(f["fw"]) * s
	var fh: float = float(f["fh"]) * s
	var hc := c + Vector2(0, -s * 0.045)
	var bg_poly := _ellipse(c, s * 0.5, s * 0.5, 48)
	var trng := RandomNumberGenerator.new()
	trng.seed = int(f["texture_seed"])
	# Fundo com leve gradiente
	_fill(bg_poly, bg_color)
	for piece in Geometry2D.intersect_polygons(_ellipse(c + Vector2(-s * 0.12, -s * 0.2), s * 0.42, s * 0.36, 32), bg_poly):
		_fill(piece, Color(1, 1, 1, 0.05))
	var face := _head(hc, fw, fh, float(f["jaw"]), float(f["sq"]))
	var style: int = f["style"]
	# Cabelo de trás (volume atrás da cabeça)
	_back_hair(hc, fw, fh, style, hair, trng, bg_poly, f)
	# Camisa / terno
	_body(c, s, hc, fw, fh, skin, bg_poly, f)
	# Orelhas
	var ear_r := float(f["ear"])
	for sx: float in [-1.0, 1.0]:
		var ec := hc + Vector2(sx * fw * 0.97, fh * 0.04)
		_fill(_ellipse(ec, fw * 0.15 * ear_r, fh * 0.2 * ear_r, 16), skin.darkened(0.05))
		var a0 := -PI * 0.5 if sx > 0 else PI * 0.5
		draw_arc(ec + Vector2(sx * fw * 0.02, 0), fw * 0.08 * ear_r, a0, a0 + PI, 8, skin.darkened(0.22), maxf(1.0, s * 0.008), true)
		if bool(f["earring"]) and sx < 0:
			draw_circle(ec + Vector2(0, fh * 0.17 * ear_r), maxf(1.2, s * 0.012), Color("#F2D16B"))
	# Rosto
	_fill(face, skin)
	# Luz e sombra (luz vindo da esquerda)
	for k in 3:
		for piece in Geometry2D.intersect_polygons(face, _ellipse(hc + Vector2(fw * (1.25 - k * 0.12), fh * 0.1), fw * (0.6 + k * 0.1), fh * 1.3, 28)):
			_fill(piece, Color(0, 0, 0, 0.045))
	for piece in Geometry2D.intersect_polygons(face, _ellipse(hc + Vector2(0, fh * 1.15), fw * 1.1, fh * 0.42, 28)):
		_fill(piece, Color(0, 0, 0, 0.06))
	_fill(_ellipse(hc + Vector2(-fw * 0.25, -fh * 0.5), fw * 0.45, fh * 0.22, 20), Color(1, 1, 1, 0.07))
	_fill(_ellipse(hc + Vector2(-fw * 0.5, fh * 0.22), fw * 0.2, fh * 0.1, 16), Color(0.9, 0.35, 0.3, 0.07))
	_fill(_ellipse(hc + Vector2(fw * 0.5, fh * 0.22), fw * 0.2, fh * 0.1, 16), Color(0.9, 0.35, 0.3, 0.05))
	# Posições dos traços
	var eye_y := hc.y - fh * 0.02
	var nose_y := hc.y + fh * float(f["nose_len"])
	var mouth_y := hc.y + fh * 0.56
	var mw := fw * float(f["mouth_w"])
	var nw := fw * float(f["nose_w"])
	var line_w := maxf(1.0, s * 0.009)
	# Rugas
	var wr: float = f["wrinkles"]
	if wr > 0.0:
		var wc := Color(skin.darkened(0.35), 0.18 + wr * 0.25)
		draw_arc(hc + Vector2(0, -fh * 0.1), fw * 0.55, PI * 1.3, PI * 1.7, 12, wc, line_w, true)
		if wr > 0.35:
			draw_arc(hc + Vector2(0, -fh * 0.02), fw * 0.5, PI * 1.32, PI * 1.68, 12, wc, line_w, true)
			for sx: float in [-1.0, 1.0]:
				draw_polyline(PackedVector2Array([Vector2(hc.x + sx * nw * 1.15, nose_y - fh * 0.04), Vector2(hc.x + sx * (nw * 1.35 + mw * 0.2), nose_y + fh * 0.1), Vector2(hc.x + sx * mw * 1.12, mouth_y + fh * 0.03)]), wc, line_w, true)
		if wr > 0.6:
			for sx: float in [-1.0, 1.0]:
				var ox: float = hc.x + sx * fw * (float(f["eye_dx"]) + float(f["eye_w"]) + 0.06)
				for k in 3:
					draw_line(Vector2(ox, eye_y + (k - 1) * fh * 0.035), Vector2(ox + sx * fw * 0.1, eye_y + (k - 1) * fh * 0.06), wc, line_w * 0.8, true)
	if bool(f["freckles"]):
		for i in 16:
			var sx := -1.0 if i % 2 == 0 else 1.0
			var p := hc + Vector2(sx * trng.randf_range(0.15, 0.62) * fw, trng.randf_range(0.08, 0.3) * fh)
			draw_circle(p, maxf(0.7, s * 0.004), Color(skin.darkened(0.3), 0.55))
	if bool(f["mole"]):
		var mp: Vector2 = f["mole_pos"]
		draw_circle(hc + Vector2(mp.x * fw, mp.y * fh), maxf(0.8, s * 0.0055), skin.darkened(0.45))
	# Barba (antes da boca: os lábios ficam por cima)
	var beard: int = f["beard"]
	var beard_col: Color = f["beard_col"]
	_beard(hc, fw, fh, face, beard, beard_col, nose_y, mouth_y, mw, trng, s)
	# Olhos
	_eyes(hc, fw, fh, eye_y, f, s, skin)
	# Sobrancelhas
	var brow_col: Color = (f["beard_col"] as Color).darkened(0.15)
	if int(f["hair_i"]) >= 5:
		brow_col = (FaceGen.HAIR_COLORS[3] as Color)
	_brows(hc, fw, fh, eye_y, f, brow_col)
	# Nariz
	_nose(hc, fw, fh, eye_y, nose_y, nw, skin, line_w)
	# Boca
	_mouth(hc, fw, fh, mouth_y, mw, f, skin, line_w)
	if beard == FaceGen.B_MUSTACHE or beard == FaceGen.B_VANDYKE or beard == FaceGen.B_FULL or beard == FaceGen.B_SHORT:
		_mustache(hc, fh, nose_y, mouth_y, mw, beard_col, float(f["lip_u"]) * fh * 4.0, trng, s)
	# Cabelo da frente
	_front_hair(hc, fw, fh, style, hair, skin, trng, f, s)
	if bool(f["headband"]):
		var hy := hc.y - fh * 0.62
		var band := PackedVector2Array([Vector2(hc.x - fw * 1.02, hy + fh * 0.05), Vector2(hc.x + fw * 1.02, hy + fh * 0.05), Vector2(hc.x + fw * 1.0, hy - fh * 0.07), Vector2(hc.x - fw * 1.0, hy - fh * 0.07)])
		for piece in Geometry2D.intersect_polygons(band, _ellipse(hc, fw * 1.08, fh * 1.25, 36)):
			_fill(piece, trim_color)
	# Borda
	draw_arc(c, s * 0.5 - 1.0, 0.0, TAU, 48, Color(bg_color.lightened(0.25), 0.6), maxf(1.0, s * 0.012), true)


## Preenche um polígono; se ele se cruzar (traços extremos), limpa o contorno antes.
func _fill(pts: PackedVector2Array, col: Color, uvs: PackedVector2Array = PackedVector2Array(), tex: Texture2D = null) -> void:
	if pts.size() < 3:
		return
	if not Geometry2D.triangulate_polygon(pts).is_empty():
		draw_colored_polygon(pts, col, uvs, tex)
		return
	for piece in Geometry2D.offset_polygon(pts, 0.05):
		if not Geometry2D.triangulate_polygon(piece).is_empty():
			draw_colored_polygon(piece, col)


func _draw_photo(c: Vector2, s: float) -> void:
	var pts := _ellipse(c, s * 0.5, s * 0.5, 48)
	var ts := photo.get_size()
	var side := minf(ts.x, ts.y)
	var uvs := PackedVector2Array()
	for p in pts:
		var rel := (p - c) / s # -0.5..0.5
		var px := ts * 0.5 + rel * side
		uvs.append(Vector2(px.x / ts.x, px.y / ts.y))
	_fill(pts, Color.WHITE, uvs, photo)
	draw_arc(c, s * 0.5 - 1.0, 0.0, TAU, 48, Color(bg_color.lightened(0.25), 0.6), maxf(1.0, s * 0.012), true)


# ---------------------------------------------------------------------------
# Partes
# ---------------------------------------------------------------------------

func _body(c: Vector2, s: float, hc: Vector2, fw: float, fh: float, skin: Color, bg_poly: PackedVector2Array, f: Dictionary) -> void:
	var neck_top := hc.y + fh * 0.55
	var neck_bot := c.y + s * 0.36
	var neck := PackedVector2Array([
		Vector2(hc.x - fw * 0.5, neck_top), Vector2(hc.x + fw * 0.5, neck_top),
		Vector2(hc.x + fw * 0.58, neck_bot), Vector2(hc.x - fw * 0.58, neck_bot)])
	var shoulders := _ellipse(Vector2(c.x, c.y + s * 0.56), s * 0.45, s * 0.25, 40)
	var body_col := Color("#2B2F36") if suit else shirt_color
	for piece in Geometry2D.intersect_polygons(shoulders, bg_poly):
		_fill(piece, body_col)
		for sh in Geometry2D.intersect_polygons(piece, _ellipse(Vector2(c.x + s * 0.3, c.y + s * 0.6), s * 0.3, s * 0.3, 24)):
			_fill(sh, Color(0, 0, 0, 0.15))
	_fill(neck, skin.darkened(0.07))
	# Sombra do queixo no pescoço
	var jaw_shadow := _ellipse(Vector2(hc.x, neck_top + fh * 0.05), fw * 0.62, fh * 0.14, 20)
	for piece in Geometry2D.intersect_polygons(jaw_shadow, neck):
		_fill(piece, Color(0, 0, 0, 0.18))
	var col_y := c.y + s * 0.33
	var lw := maxf(1.5, s * 0.022)
	if suit:
		# Camisa branca, gravata e lapelas
		var shirt := PackedVector2Array([Vector2(hc.x - fw * 0.55, col_y - s * 0.01), Vector2(hc.x + fw * 0.55, col_y - s * 0.01), Vector2(hc.x, col_y + s * 0.16)])
		_fill(shirt, Color("#ECEFF3"))
		var tie := PackedVector2Array([Vector2(hc.x - s * 0.018, col_y + s * 0.02), Vector2(hc.x + s * 0.018, col_y + s * 0.02), Vector2(hc.x + s * 0.025, col_y + s * 0.15), Vector2(hc.x, col_y + s * 0.18), Vector2(hc.x - s * 0.025, col_y + s * 0.15)])
		for piece in Geometry2D.intersect_polygons(tie, bg_poly):
			_fill(piece, trim_color)
		for sx: float in [-1.0, 1.0]:
			var lap := PackedVector2Array([Vector2(hc.x + sx * fw * 0.6, col_y - s * 0.02), Vector2(hc.x + sx * fw * 0.95, col_y + s * 0.05), Vector2(hc.x + sx * s * 0.03, col_y + s * 0.2)])
			for piece in Geometry2D.intersect_polygons(lap, bg_poly):
				_fill(piece, Color("#1E2127"))
		return
	match int(f["collar"]):
		0: # gola V
			var v := PackedVector2Array([Vector2(hc.x - fw * 0.55, col_y), Vector2(hc.x, col_y + s * 0.09), Vector2(hc.x + fw * 0.55, col_y)])
			_fill(v, skin.darkened(0.1))
			draw_polyline(v, trim_color, lw, true)
		1: # gola redonda
			draw_arc(Vector2(hc.x, col_y - s * 0.015), fw * 0.6, PI * 0.12, PI * 0.88, 16, trim_color, lw, true)
		_: # gola polo
			for sx: float in [-1.0, 1.0]:
				var tri := PackedVector2Array([Vector2(hc.x + sx * fw * 0.62, col_y - s * 0.03), Vector2(hc.x + sx * fw * 0.05, col_y + s * 0.06), Vector2(hc.x + sx * fw * 0.8, col_y + s * 0.05)])
				_fill(tri, trim_color)


func _back_hair(hc: Vector2, fw: float, fh: float, style: int, hair: Color, rng: RandomNumberGenerator, bg_poly: PackedVector2Array, f: Dictionary) -> void:
	match style:
		FaceGen.H_AFRO:
			var r := fw * (1.45 + float(f["vol"]) * 0.2)
			var afro := _ellipse(hc + Vector2(0, -fh * 0.3), r, r * 0.95, 40)
			for piece in Geometry2D.intersect_polygons(afro, bg_poly):
				_fill(piece, hair)
			for i in 40:
				var a := TAU * i / 40.0
				draw_circle(hc + Vector2(0, -fh * 0.3) + Vector2(cos(a), sin(a) * 0.95) * r * 0.97, r * 0.09, hair)
			_texture_dots(afro, hair.lightened(0.12), 60, fw * 0.035, rng)
		FaceGen.H_LONG:
			var back := PackedVector2Array([
				Vector2(hc.x - fw * 1.18, hc.y - fh * 0.3), Vector2(hc.x - fw * 1.25, hc.y + fh * 1.1),
				Vector2(hc.x - fw * 0.7, hc.y + fh * 1.25), Vector2(hc.x + fw * 0.7, hc.y + fh * 1.25),
				Vector2(hc.x + fw * 1.25, hc.y + fh * 1.1), Vector2(hc.x + fw * 1.18, hc.y - fh * 0.3)])
			for piece in Geometry2D.intersect_polygons(back, bg_poly):
				_fill(piece, hair.darkened(0.12))
		FaceGen.H_DREADS:
			for i in 14:
				var t := float(i) / 13.0
				var x := lerpf(-fw * 1.12, fw * 1.12, t)
				var top := hc + Vector2(x * 0.85, -fh * 0.55)
				var bottom := hc + Vector2(x * 1.08, fh * rng.randf_range(0.7, 1.15))
				draw_line(top, bottom, hair.darkened(0.1), fw * 0.16, true)
				draw_circle(bottom, fw * 0.08, hair.darkened(0.1))
		FaceGen.H_BUN:
			draw_circle(hc + Vector2(0, -fh * 1.12), fw * 0.34, hair)
			draw_arc(hc + Vector2(0, -fh * 1.12), fw * 0.22, PI * 0.9, PI * 1.9, 10, hair.lightened(0.15), maxf(1.0, fw * 0.03), true)


func _front_hair(hc: Vector2, fw: float, fh: float, style: int, hair: Color, skin: Color, rng: RandomNumberGenerator, f: Dictionary, s: float) -> void:
	if style == FaceGen.H_BALD:
		_shine(hc, fw, fh)
		return
	var rec: float = f["recession"]
	var vol: float = f["vol"]
	var hairline := -fh * (0.6 - rec * 0.28)
	var temple := rec * 0.25
	var cap: PackedVector2Array
	match style:
		FaceGen.H_BUZZ:
			cap = _cap(hc, fw, fh, 1.02, hairline, temple, 0.02)
			_fill(cap, Color(hair, 0.55))
			_texture_dots(cap, Color(hair.darkened(0.2), 0.6), 70, fw * 0.018, rng)
		FaceGen.H_FADE:
			cap = _cap(hc, fw, fh, 1.06 + vol * 0.04, hairline, temple, 0.05)
			_fill(cap, Color(hair, 0.45))
			var top_rect := PackedVector2Array([Vector2(hc.x - fw * 1.3, hc.y - fh * 2.0), Vector2(hc.x + fw * 1.3, hc.y - fh * 2.0), Vector2(hc.x + fw * 1.3, hc.y - fh * 0.62), Vector2(hc.x - fw * 1.3, hc.y - fh * 0.62)])
			for piece in Geometry2D.intersect_polygons(cap, top_rect):
				_fill(piece, hair)
				_strands(piece, hair.lightened(0.14), 22, Vector2(0.2, -1.0), fh * 0.08, rng, s)
		FaceGen.H_MOHAWK:
			cap = _cap(hc, fw, fh, 1.02, hairline, temple, 0.0)
			_fill(cap, Color(hair, 0.3))
			var strip := PackedVector2Array([Vector2(hc.x - fw * 0.22, hc.y + hairline), Vector2(hc.x - fw * 0.28, hc.y - fh * 1.05), Vector2(hc.x - fw * 0.1, hc.y - fh * 1.32), Vector2(hc.x + fw * 0.12, hc.y - fh * 1.3), Vector2(hc.x + fw * 0.28, hc.y - fh * 1.05), Vector2(hc.x + fw * 0.22, hc.y + hairline)])
			_fill(strip, hair)
			_strands(strip, hair.lightened(0.18), 14, Vector2(0.0, -1.0), fh * 0.12, rng, s)
		FaceGen.H_CORNROWS:
			cap = _cap(hc, fw, fh, 1.03, hairline, temple * 0.5, 0.03)
			_fill(cap, Color(hair, 0.5))
			for i in 7:
				var x := lerpf(-fw * 0.8, fw * 0.8, float(i) / 6.0)
				var pts := PackedVector2Array()
				for k in 9:
					var t := float(k) / 8.0
					pts.append(hc + Vector2(x * (1.0 - t * 0.15), lerpf(hairline, -fh * 1.02, t) * (1.0 - absf(x) / fw * 0.1 * t)))
				draw_polyline(pts, hair, fw * 0.1, true)
				draw_polyline(pts, hair.lightened(0.15), fw * 0.025, true)
		_:
			var v := 1.06
			var depth_hl := hairline
			match style:
				FaceGen.H_SHORT:
					v = 1.07 + vol * 0.05
				FaceGen.H_PART:
					v = 1.12 + vol * 0.05
				FaceGen.H_QUIFF:
					v = 1.1
				FaceGen.H_CURLY:
					v = 1.18 + vol * 0.08
				FaceGen.H_AFRO:
					v = 1.25
				FaceGen.H_DREADS:
					v = 1.14
				FaceGen.H_LONG:
					v = 1.12
					depth_hl = hairline + fh * 0.05
				FaceGen.H_BUN:
					v = 1.06
				FaceGen.H_SLICK:
					v = 1.1
				FaceGen.H_SPIKY:
					v = 1.12
				FaceGen.H_FRINGE:
					v = 1.1
					depth_hl = -fh * 0.3 - rec * fh * 0.05
			cap = _cap(hc, fw, fh, v, depth_hl, temple, 0.12 if style == FaceGen.H_LONG else 0.05)
			if bool(f["balding"]):
				var top := _ellipse(hc + Vector2(0, -fh * 0.5), fw * 0.86, fh * 0.72, 28)
				for piece in Geometry2D.clip_polygons(cap, top):
					if not Geometry2D.is_polygon_clockwise(piece):
						_fill(piece, hair)
				_shine(hc, fw, fh)
				return
			# Sombra do cabelo na testa
			var shadow := PackedVector2Array()
			for pt in cap:
				shadow.append(pt + Vector2(0, fh * 0.035))
			_fill(shadow, Color(0, 0, 0, 0.14))
			_fill(cap, hair)
			# Textura e detalhes de cada penteado
			match style:
				FaceGen.H_PART:
					var px := float(f["part_side"]) * fw * 0.38
					draw_line(hc + Vector2(px, hairline - fh * 0.02), hc + Vector2(px * 0.8, -fh * v * 0.95), hair.lightened(0.25), maxf(1.0, s * 0.008), true)
					_strands(cap, hair.lightened(0.15), 30, Vector2(-float(f["part_side"]), -0.3), fh * 0.14, rng, s)
				FaceGen.H_QUIFF:
					var q := _ellipse(hc + Vector2(-fw * 0.05, -fh * 0.98), fw * 0.72, fh * 0.28, 24)
					_fill(q, hair)
					_strands(q, hair.lightened(0.18), 16, Vector2(0.3, -1.0), fh * 0.12, rng, s)
				FaceGen.H_CURLY, FaceGen.H_AFRO:
					for i in 18:
						var a := PI + PI * i / 17.0
						draw_circle(hc + Vector2(cos(a) * fw * 1.02, sin(a) * fh * v), fw * 0.14, hair)
					_texture_curls(cap, hair.lightened(0.16), 34, fw * 0.05, rng, s)
				FaceGen.H_SPIKY:
					for i in 9:
						var a := PI * 1.12 + PI * 0.76 * i / 8.0
						var base := hc + Vector2(cos(a) * fw * 0.95, sin(a) * fh * v * 0.95)
						var tip := hc + Vector2(cos(a) * fw * 1.2, sin(a) * fh * v * 1.18) + Vector2(rng.randf_range(-1, 1), 0) * fw * 0.05
						_fill(PackedVector2Array([base + Vector2(-fw * 0.12, 0), tip, base + Vector2(fw * 0.12, 0)]), hair)
					_strands(cap, hair.lightened(0.15), 24, Vector2(0.0, -1.0), fh * 0.1, rng, s)
				FaceGen.H_SLICK:
					_strands(cap, hair.lightened(0.22), 30, Vector2(0.1, -1.0), fh * 0.18, rng, s)
				FaceGen.H_FRINGE:
					for i in 7:
						var x := lerpf(-fw * 0.75, fw * 0.75, float(i) / 6.0)
						_fill(PackedVector2Array([hc + Vector2(x - fw * 0.13, depth_hl - fh * 0.05), hc + Vector2(x + fw * 0.02, depth_hl + fh * 0.07), hc + Vector2(x + fw * 0.13, depth_hl - fh * 0.05)]), hair)
					_strands(cap, hair.lightened(0.15), 24, Vector2(0.1, 1.0), fh * 0.12, rng, s)
				FaceGen.H_DREADS:
					for i in 9:
						var x := lerpf(-fw * 0.8, fw * 0.8, float(i) / 8.0)
						draw_line(hc + Vector2(x * 0.7, -fh * v * 0.95), hc + Vector2(x, depth_hl + fh * 0.03), hair.lightened(0.12), fw * 0.05, true)
				_:
					_strands(cap, hair.lightened(0.14), 26, Vector2(0.15, -1.0), fh * 0.1, rng, s)
	# Brilho
	for piece in Geometry2D.intersect_polygons(cap, _ellipse(hc + Vector2(-fw * 0.35, -fh * 0.85), fw * 0.4, fh * 0.2, 20)):
		_fill(piece, Color(1, 1, 1, 0.1))


func _shine(hc: Vector2, fw: float, fh: float) -> void:
	_fill(_ellipse(hc + Vector2(-fw * 0.25, -fh * 0.78), fw * 0.3, fh * 0.12, 18), Color(1, 1, 1, 0.12))


func _eyes(hc: Vector2, fw: float, fh: float, eye_y: float, f: Dictionary, s: float, skin: Color) -> void:
	var ew := fw * float(f["eye_w"])
	var eh := fw * float(f["eye_h"])
	var dx := fw * float(f["eye_dx"])
	var tilt := fw * float(f["eye_tilt"])
	var iris_col: Color = f["eye"]
	var gaze := float(f["gaze"]) * ew * 0.25
	var lid := Color("#1C1410")
	var lw := maxf(1.0, s * 0.011)
	for sx: float in [-1.0, 1.0]:
		var cx := hc.x + sx * dx
		var inner := Vector2(cx - sx * ew, eye_y + tilt * 0.3)
		var outer := Vector2(cx + sx * ew, eye_y - tilt)
		var upper := PackedVector2Array()
		var lower := PackedVector2Array()
		for i in 13:
			var t := float(i) / 12.0
			var base := inner.lerp(outer, t)
			upper.append(base + Vector2(0, -sin(PI * pow(t, 0.85)) * eh))
			lower.append(base + Vector2(0, sin(PI * t) * eh * 0.55))
		var sclera := PackedVector2Array(upper)
		for i in range(lower.size() - 2, 0, -1):
			sclera.append(lower[i])
		# Sombra da órbita
		_fill(_ellipse(Vector2(cx, eye_y - eh * 0.4), ew * 1.25, eh * 1.6, 18), Color(skin.darkened(0.25), 0.18))
		_fill(sclera, Color("#F4F1EA"))
		var ic := Vector2(cx + gaze, eye_y + eh * 0.05)
		for piece in Geometry2D.intersect_polygons(_ellipse(ic, eh * 1.0, eh * 1.0, 18), sclera):
			_fill(piece, iris_col)
		for piece in Geometry2D.intersect_polygons(_ellipse(ic, eh * 0.45, eh * 0.45, 12), sclera):
			_fill(piece, Color("#0B0806"))
		draw_circle(ic + Vector2(-eh * 0.35, -eh * 0.35), maxf(0.7, eh * 0.22), Color(1, 1, 1, 0.9))
		draw_polyline(upper, lid, lw * 1.3, true)
		draw_line(outer, outer + Vector2(sx * ew * 0.18, -eh * 0.25), lid, lw, true)
		draw_polyline(lower, Color(lid, 0.25), lw * 0.7, true)
		if not bool(f["monolid"]):
			var crease := PackedVector2Array()
			for p in upper:
				crease.append(p + Vector2(0, -eh * 0.55))
			draw_polyline(crease.slice(2, 11), Color(skin.darkened(0.35), 0.35), lw * 0.8, true)
		if float(f["wrinkles"]) > 0.3:
			var bag := PackedVector2Array()
			for p in lower.slice(3, 11):
				bag.append(p + Vector2(0, eh * 0.55))
			draw_polyline(bag, Color(skin.darkened(0.3), 0.3 * float(f["wrinkles"])), lw * 0.8, true)


func _brows(hc: Vector2, fw: float, fh: float, eye_y: float, f: Dictionary, col: Color) -> void:
	var by := eye_y - fh * 0.2
	var th := fw * float(f["brow_t"])
	var arch := fw * float(f["brow_arch"])
	var tilt := fw * float(f["brow_tilt"])
	var dx := fw * float(f["eye_dx"])
	var blen := fw * float(f["brow_len"])
	for sx: float in [-1.0, 1.0]:
		var x0 := hc.x + sx * (dx - blen * 0.55)
		var top := PackedVector2Array()
		var bot := PackedVector2Array()
		for i in 11:
			var t := float(i) / 10.0
			var x := x0 + sx * blen * t
			var y := by - arch * sin(PI * t * 0.9) - tilt * t
			var thick := lerpf(th * 1.15, th * 0.35, pow(t, 1.3))
			top.append(Vector2(x, y - thick * 0.5))
			bot.append(Vector2(x, y + thick * 0.5))
		bot.reverse()
		var poly := PackedVector2Array(top)
		poly.append_array(bot)
		_fill(poly, col)


func _nose(hc: Vector2, fw: float, fh: float, eye_y: float, nose_y: float, nw: float, skin: Color, lw: float) -> void:
	var shade := Color(skin.darkened(0.4), 0.35)
	# Lateral do nariz (sombra do lado direito)
	draw_polyline(PackedVector2Array([Vector2(hc.x + nw * 0.25, eye_y + fh * 0.06), Vector2(hc.x + nw * 0.4, nose_y - fh * 0.12), Vector2(hc.x + nw * 0.75, nose_y - fh * 0.01)]), shade, lw, true)
	for piece in Geometry2D.intersect_polygons(_ellipse(Vector2(hc.x + nw * 0.35, (eye_y + nose_y) * 0.5 + fh * 0.04), nw * 0.35, fh * 0.16, 14), _ellipse(hc, fw, fh, 24)):
		_fill(piece, Color(0, 0, 0, 0.05))
	# Ponta e asas
	var tip := PackedVector2Array()
	for i in 11:
		var t := float(i) / 10.0
		tip.append(Vector2(hc.x + lerpf(-nw, nw, t), nose_y + sin(PI * t) * fh * 0.035))
	draw_polyline(tip, Color(skin.darkened(0.35), 0.55), lw, true)
	for sx: float in [-1.0, 1.0]:
		_fill(_ellipse(Vector2(hc.x + sx * nw * 0.42, nose_y + fh * 0.012), nw * 0.2, fh * 0.017, 10), Color(skin.darkened(0.55), 0.6))
		draw_arc(Vector2(hc.x + sx * nw * 0.82, nose_y - fh * 0.02), nw * 0.25, PI * 0.5 - sx * 0.9, PI * 0.5 + sx * 1.6, 8, Color(skin.darkened(0.35), 0.45), lw, true)
	_fill(_ellipse(Vector2(hc.x - nw * 0.1, nose_y - fh * 0.04), nw * 0.22, fh * 0.03, 10), Color(1, 1, 1, 0.12))


func _mouth(hc: Vector2, fw: float, fh: float, mouth_y: float, mw: float, f: Dictionary, skin: Color, lw: float) -> void:
	var smile := float(f["smile"])
	var ul := fh * float(f["lip_u"]) * 2.0
	var ll := fh * float(f["lip_l"]) * 2.0
	var lip := skin.lerp(Color("#A8494F"), 0.3).darkened(0.1)
	var corner_y := mouth_y - smile * fh * 0.03
	var line := PackedVector2Array()
	for i in 13:
		var t := float(i) / 12.0
		var x := hc.x + lerpf(-mw, mw, t)
		line.append(Vector2(x, lerpf(corner_y, mouth_y + smile * fh * 0.01, sin(PI * t))))
	var up := PackedVector2Array()
	for i in 13:
		var t := float(i) / 12.0
		var x := hc.x + lerpf(-mw, mw, t)
		var bow := sin(PI * t) * ul - (ul * 0.28 if absf(t - 0.5) < 0.09 else 0.0)
		up.append(Vector2(x, lerpf(corner_y, mouth_y, sin(PI * t)) - bow))
	var upper := PackedVector2Array(up)
	var rl := line.duplicate()
	rl.reverse()
	upper.append_array(rl)
	_fill(upper, lip.darkened(0.12))
	var lo := PackedVector2Array()
	for i in 13:
		var t := float(i) / 12.0
		var x := hc.x + lerpf(-mw * 0.92, mw * 0.92, t)
		lo.append(Vector2(x, lerpf(corner_y, mouth_y, sin(PI * t)) + sin(PI * t) * ll))
	var lower := PackedVector2Array(line)
	lo.reverse()
	lower.append_array(lo)
	_fill(lower, lip)
	_fill(_ellipse(Vector2(hc.x - mw * 0.15, mouth_y + ll * 0.45), mw * 0.3, ll * 0.2, 10), Color(1, 1, 1, 0.12))
	draw_polyline(line, Color("#3A1D1B"), lw, true)
	# Sombra sob o lábio inferior
	_fill(_ellipse(Vector2(hc.x, mouth_y + ll * 1.5), mw * 0.45, ll * 0.4, 12), Color(0, 0, 0, 0.06))


func _beard(hc: Vector2, fw: float, fh: float, face: PackedVector2Array, beard: int, col: Color, nose_y: float, mouth_y: float, mw: float, rng: RandomNumberGenerator, s: float) -> void:
	if beard == FaceGen.B_NONE or beard == FaceGen.B_MUSTACHE:
		return
	var region := PackedVector2Array([
		Vector2(hc.x - fw * 1.3, hc.y + fh * 0.02), Vector2(hc.x - fw * 0.8, hc.y + fh * 0.22),
		Vector2(hc.x - mw * 1.2, nose_y + fh * 0.08), Vector2(hc.x, nose_y + fh * 0.1),
		Vector2(hc.x + mw * 1.2, nose_y + fh * 0.08), Vector2(hc.x + fw * 0.8, hc.y + fh * 0.22),
		Vector2(hc.x + fw * 1.3, hc.y + fh * 0.02), Vector2(hc.x + fw * 1.3, hc.y + fh * 1.6),
		Vector2(hc.x - fw * 1.3, hc.y + fh * 1.6)])
	match beard:
		FaceGen.B_STUBBLE:
			for piece in Geometry2D.intersect_polygons(face, region):
				_fill(piece, Color(col, 0.26))
				_texture_dots(piece, Color(col, 0.35), 60, fw * 0.012, rng)
		FaceGen.B_SHORT, FaceGen.B_FULL:
			var grown := face
			if beard == FaceGen.B_FULL:
				var off := Geometry2D.offset_polygon(face, fw * 0.07)
				if not off.is_empty():
					grown = off[0]
			for piece in Geometry2D.intersect_polygons(grown, region):
				_fill(piece, Color(col, 0.82 if beard == FaceGen.B_SHORT else 0.95))
				_strands(piece, col.lightened(0.14), 40, Vector2(0.0, 1.0), fh * 0.06, rng, s)
		FaceGen.B_GOATEE, FaceGen.B_VANDYKE:
			var g := _ellipse(Vector2(hc.x, hc.y + fh * 0.82), mw * 0.72, fh * 0.24, 20)
			for piece in Geometry2D.intersect_polygons(g, face):
				_fill(piece, Color(col, 0.9))
				_strands(piece, col.lightened(0.14), 12, Vector2(0.0, 1.0), fh * 0.05, rng, s)
		FaceGen.B_CHINSTRAP:
			var inner := Geometry2D.offset_polygon(face, -fw * 0.1)
			var band: Array = Geometry2D.clip_polygons(face, inner[0]) if not inner.is_empty() else []
			for b in band:
				for piece in Geometry2D.intersect_polygons(b, region):
					_fill(piece, Color(col, 0.9))
			var chin := _ellipse(Vector2(hc.x, hc.y + fh * 0.9), mw * 0.5, fh * 0.12, 16)
			for piece in Geometry2D.intersect_polygons(chin, face):
				_fill(piece, Color(col, 0.9))


func _mustache(hc: Vector2, fh: float, nose_y: float, mouth_y: float, mw: float, col: Color, ul: float, rng: RandomNumberGenerator, s: float) -> void:
	var m := PackedVector2Array([
		Vector2(hc.x - mw * 1.08, mouth_y + fh * 0.02), Vector2(hc.x - mw * 0.75, nose_y + fh * 0.06),
		Vector2(hc.x - mw * 0.15, nose_y + fh * 0.05), Vector2(hc.x, nose_y + fh * 0.07),
		Vector2(hc.x + mw * 0.15, nose_y + fh * 0.05), Vector2(hc.x + mw * 0.75, nose_y + fh * 0.06),
		Vector2(hc.x + mw * 1.08, mouth_y + fh * 0.02), Vector2(hc.x + mw * 0.55, mouth_y - ul * 0.35),
		Vector2(hc.x, mouth_y - ul * 0.5), Vector2(hc.x - mw * 0.55, mouth_y - ul * 0.35)])
	_fill(m, Color(col, 0.95))
	_strands(m, col.lightened(0.16), 12, Vector2(0.0, 1.0), fh * 0.04, rng, s)


# ---------------------------------------------------------------------------
# Geometria e texturas
# ---------------------------------------------------------------------------

## Contorno da cabeça: calota elíptica em cima e mandíbula (mais ou menos quadrada) embaixo.
static func _head(c: Vector2, fw: float, fh: float, jaw: float, sq: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 48:
		var a := TAU * i / 48.0
		var ca := cos(a)
		var sa := sin(a)
		if sa <= 0.0:
			pts.append(c + Vector2(ca * fw, sa * fh * 1.02))
		else:
			var x := signf(ca) * pow(absf(ca), 1.0 / sq) * fw * lerpf(1.0, jaw, pow(sa, 1.4))
			pts.append(c + Vector2(x, sa * fh))
	return pts


## Calota de cabelo: por cima da cabeça, costeletas até `side` e linha do cabelo em `hairline`
## (relativa ao centro), com entradas (`temple`) nas têmporas.
static func _cap(c: Vector2, fw: float, fh: float, vol: float, hairline: float, temple: float, side: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(c + Vector2(-fw * 1.04, fh * side))
	for i in 25:
		var a := PI + PI * i / 24.0
		var up := sin(a) # -1 no topo
		pts.append(c + Vector2(cos(a) * fw * (1.04 + (vol - 1.0) * 0.4), up * fh * vol))
	pts.append(c + Vector2(fw * 1.04, fh * side))
	pts.append(c + Vector2(fw * 0.88, fh * side))
	pts.append(c + Vector2(fw * 0.86, -fh * 0.18))
	pts.append(c + Vector2(fw * 0.66, hairline + fh * temple))
	for i in 9:
		var t := float(i) / 8.0
		var x := lerpf(fw * 0.5, -fw * 0.5, t)
		pts.append(c + Vector2(x, hairline - sin(PI * t) * fh * 0.04 + fh * temple * 0.3 * absf(x) / fw))
	pts.append(c + Vector2(-fw * 0.66, hairline + fh * temple))
	pts.append(c + Vector2(-fw * 0.86, -fh * 0.18))
	pts.append(c + Vector2(-fw * 0.88, fh * side))
	return pts


func _strands(poly: PackedVector2Array, col: Color, n: int, dir: Vector2, length: float, rng: RandomNumberGenerator, s: float) -> void:
	var r := _bounds(poly)
	var d := dir.normalized()
	var w := maxf(0.8, s * 0.006)
	var tries := 0
	var drawn := 0
	while drawn < n and tries < n * 4:
		tries += 1
		var p := Vector2(rng.randf_range(r.position.x, r.end.x), rng.randf_range(r.position.y, r.end.y))
		if not Geometry2D.is_point_in_polygon(p, poly):
			continue
		var q := p + (d + Vector2(rng.randf_range(-0.25, 0.25), 0.0)) * length * rng.randf_range(0.6, 1.2)
		if not Geometry2D.is_point_in_polygon(q, poly):
			continue
		draw_line(p, q, col, w, true)
		drawn += 1


func _texture_dots(poly: PackedVector2Array, col: Color, n: int, r: float, rng: RandomNumberGenerator) -> void:
	var b := _bounds(poly)
	var tries := 0
	var drawn := 0
	while drawn < n and tries < n * 3:
		tries += 1
		var p := Vector2(rng.randf_range(b.position.x, b.end.x), rng.randf_range(b.position.y, b.end.y))
		if Geometry2D.is_point_in_polygon(p, poly):
			draw_circle(p, maxf(0.5, r), col)
			drawn += 1


func _texture_curls(poly: PackedVector2Array, col: Color, n: int, r: float, rng: RandomNumberGenerator, s: float) -> void:
	var b := _bounds(poly)
	var tries := 0
	var drawn := 0
	while drawn < n and tries < n * 3:
		tries += 1
		var p := Vector2(rng.randf_range(b.position.x, b.end.x), rng.randf_range(b.position.y, b.end.y))
		if Geometry2D.is_point_in_polygon(p, poly):
			var a0 := rng.randf() * TAU
			draw_arc(p, r, a0, a0 + PI * 1.3, 6, col, maxf(0.8, s * 0.006), true)
			drawn += 1


static func _bounds(poly: PackedVector2Array) -> Rect2:
	var r := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		r = r.expand(p)
	return r


static func _ellipse(c: Vector2, rx: float, ry: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts
