@tool
class_name KitView
extends Control
## Uniforme procedural. Por padrão desenha só a camisa; com `full` desenha camisa, calção e meiões.
## Chaves do dicionário do uniforme (todas opcionais, com padrão sensato):
##   pattern, c1 (principal), c2 (secundária), c3 (detalhes: gola, punhos, frisos),
##   collar, sleeve, shorts / shorts2 / shorts_style, socks / socks2 / socks_style,
##   sp = {n, c, t} (patrocinador master no peito).

@export var kit: Dictionary = {"pattern": "stripes_v", "c1": "#B3122E", "c2": "#F2C14E", "collar": "round", "sleeve": "same"}:
	set(v):
		kit = v
		queue_redraw()
@export var number: int = 0:
	set(v):
		number = v
		queue_redraw()
@export var full: bool = false:
	set(v):
		full = v
		queue_redraw()

## [chave, nome] — a ordem é a do editor.
const PATTERNS: Array = [
	["plain", "Lisa"], ["stripes_v", "Listras"], ["pinstripes", "Listras finas"], ["wide_stripes", "Listras largas"],
	["center_stripe", "Listra central"], ["stripes_h", "Faixas horizontais"], ["hoops_thin", "Faixas finas"],
	["faixa", "Faixa no peito"], ["double_band", "Faixa dupla"], ["diagonal", "Faixa diagonal"],
	["diagonal_rev", "Diagonal invertida"], ["halves", "Metades"], ["bottom_half", "Duas cores (h)"],
	["quarters", "Quartos"], ["chevron", "Chevron"], ["side_panels", "Laterais"], ["yoke", "Ombros"],
	["cross", "Cruz"], ["checkers", "Xadrez"], ["pixels", "Grade"],
]
const COLLARS: Array = [["round", "Redonda"], ["v", "Em V"], ["polo", "Polo"], ["wide", "Careca larga"], ["henley", "Botões"], ["mandarin", "Padre"]]
const SLEEVES: Array = [["same", "Iguais"], ["contrast", "Contraste"], ["cuff", "Punho"], ["stripes", "Três listras"], ["raglan", "Raglan"]]
const SHORTS_STYLES: Array = [["plain", "Liso"], ["side_stripe", "Faixa lateral"], ["hem", "Barra"], ["two_tone", "Duas cores"], ["stripes3", "Três listras"]]
const SOCKS_STYLES: Array = [["plain", "Liso"], ["hoops", "Listrado"], ["top_band", "Punho"], ["two_tone", "Duas cores"], ["stripes3", "Frisos"]]

const BODY := [Vector2(0.3, 0.06), Vector2(0.4, 0.1), Vector2(0.5, 0.12), Vector2(0.6, 0.1), Vector2(0.7, 0.06),
	Vector2(0.77, 0.3), Vector2(0.77, 0.95), Vector2(0.23, 0.95), Vector2(0.23, 0.3)]
const SLEEVE_R := [Vector2(0.7, 0.06), Vector2(0.96, 0.2), Vector2(0.88, 0.4), Vector2(0.77, 0.34), Vector2(0.77, 0.3)]
const SLEEVE_L := [Vector2(0.3, 0.06), Vector2(0.23, 0.3), Vector2(0.23, 0.34), Vector2(0.12, 0.4), Vector2(0.04, 0.2)]
## Proporção largura/altura do uniforme completo.
const FULL_ASPECT := 0.62


## Número de combinações de estilo (sem contar cores).
static func style_combinations() -> int:
	return PATTERNS.size() * COLLARS.size() * SLEEVES.size() * SHORTS_STYLES.size() * SOCKS_STYLES.size()


func _draw() -> void:
	if full:
		var h := minf(size.y, size.x / FULL_ASPECT)
		var w := h * FULL_ASPECT
		if h <= 8.0:
			return
		var r := Rect2((size.x - w) * 0.5, (size.y - h) * 0.5, w, h)
		_draw_legs(r)
		_draw_shirt(w, r.position)
	else:
		var s := minf(size.x, size.y)
		if s <= 2.0:
			return
		_draw_shirt(s, Vector2((size.x - s) * 0.5, (size.y - s) * 0.5))


func _col(key: String, fallback: String) -> Color:
	return Color(String(kit.get(key, fallback)))


func _draw_shirt(s: float, off: Vector2) -> void:
	var c1 := _col("c1", "#FFFFFF")
	var c2 := _col("c2", "#000000")
	var c3 := Color(String(kit.get("c3", kit.get("c2", "#000000"))))
	var body := _xf(BODY, s, off)
	var sr := _xf(SLEEVE_R, s, off)
	var sl := _xf(SLEEVE_L, s, off)
	var sleeve: String = kit.get("sleeve", "same")
	var sleeve_col := c2 if sleeve == "contrast" or sleeve == "raglan" else c1
	draw_colored_polygon(sr, sleeve_col)
	draw_colored_polygon(sl, sleeve_col)
	draw_colored_polygon(body, c1)
	for band in pattern_bands(kit.get("pattern", "plain")):
		for piece in Geometry2D.intersect_polygons(_xf(band, s, off), body):
			draw_colored_polygon(piece, c2)
	match sleeve:
		"cuff":
			draw_line(off + Vector2(0.925, 0.26) * s, off + Vector2(0.875, 0.39) * s, c3, maxf(1.5, s * 0.04))
			draw_line(off + Vector2(0.075, 0.26) * s, off + Vector2(0.125, 0.39) * s, c3, maxf(1.5, s * 0.04))
		"stripes":
			for i in 3:
				var d := (i - 1) * 0.022
				draw_line(off + Vector2(0.7 + d * 0.3, 0.07 + d) * s, off + Vector2(0.93 + d * 0.3, 0.26 + d) * s, c3, maxf(1.0, s * 0.012))
				draw_line(off + Vector2(0.3 - d * 0.3, 0.07 + d) * s, off + Vector2(0.07 - d * 0.3, 0.26 + d) * s, c3, maxf(1.0, s * 0.012))
		"raglan":
			draw_line(off + Vector2(0.4, 0.1) * s, off + Vector2(0.23, 0.32) * s, c3, maxf(1.0, s * 0.014))
			draw_line(off + Vector2(0.6, 0.1) * s, off + Vector2(0.77, 0.32) * s, c3, maxf(1.0, s * 0.014))
	_draw_collar(s, off, c1, c3)
	# Contorno sutil
	var outline := body.duplicate()
	outline.append(body[0])
	draw_polyline(outline, Color(0, 0, 0, 0.35), maxf(1.0, s * 0.012), true)
	var sp: Dictionary = kit.get("sp", {})
	if not sp.is_empty() and s >= 56.0:
		_draw_sponsor(s, off, sp)
	if number > 0:
		var font := get_theme_font(&"font", &"Big")
		var fs := int(s * (0.22 if not sp.is_empty() and s >= 56.0 else 0.3))
		var txt := str(number)
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var fg := UIColors.on_color(c1)
		var y := 0.84 if not sp.is_empty() and s >= 56.0 else 0.62
		draw_string(font, off + Vector2(0.5 * s - w * 0.5, y * s), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, fg)


func _draw_collar(s: float, off: Vector2, c1: Color, c3: Color) -> void:
	var collar: String = kit.get("collar", "round")
	var col := c3 if c3 != c1 else c1.darkened(0.4)
	var width := maxf(1.5, s * 0.04)
	var neck: PackedVector2Array
	match collar:
		"v":
			neck = _xf([Vector2(0.38, 0.08), Vector2(0.5, 0.22), Vector2(0.62, 0.08)], s, off)
		"polo":
			neck = _xf([Vector2(0.36, 0.07), Vector2(0.44, 0.15), Vector2(0.5, 0.13), Vector2(0.56, 0.15), Vector2(0.64, 0.07)], s, off)
			draw_line(off + Vector2(0.5, 0.13) * s, off + Vector2(0.5, 0.25) * s, col, maxf(1.0, s * 0.015))
		"wide":
			neck = _xf([Vector2(0.35, 0.07), Vector2(0.42, 0.14), Vector2(0.5, 0.16), Vector2(0.58, 0.14), Vector2(0.65, 0.07)], s, off)
			width *= 1.5
		"henley":
			neck = _xf([Vector2(0.38, 0.07), Vector2(0.44, 0.12), Vector2(0.5, 0.13), Vector2(0.56, 0.12), Vector2(0.62, 0.07)], s, off)
			draw_line(off + Vector2(0.5, 0.13) * s, off + Vector2(0.5, 0.24) * s, col, maxf(1.0, s * 0.012))
			for i in 2:
				draw_circle(off + Vector2(0.5, 0.17 + i * 0.05) * s, maxf(1.0, s * 0.012), col)
		"mandarin":
			draw_colored_polygon(_xf([Vector2(0.37, 0.04), Vector2(0.63, 0.04), Vector2(0.62, 0.09), Vector2(0.5, 0.12), Vector2(0.38, 0.09)], s, off), col)
			return
		_:
			neck = _xf([Vector2(0.38, 0.07), Vector2(0.44, 0.12), Vector2(0.5, 0.13), Vector2(0.56, 0.12), Vector2(0.62, 0.07)], s, off)
	draw_polyline(neck, col, width, true)


func _draw_sponsor(s: float, off: Vector2, sp: Dictionary) -> void:
	var r := Rect2(off + Vector2(0.3, 0.36) * s, Vector2(0.4, 0.14) * s)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(String(sp.get("c", "#FFFFFF")))
	sb.set_corner_radius_all(int(maxf(2.0, s * 0.02)))
	draw_style_box(sb, r)
	var font := get_theme_font(&"font", &"Caps")
	var txt := String(sp.get("n", "")).to_upper()
	var fs := int(s * 0.1)
	var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	while tw > r.size.x * 0.92 and fs > 6:
		fs -= 1
		tw = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var asc := font.get_ascent(fs)
	var desc := font.get_descent(fs)
	draw_string(font, Vector2(r.get_center().x - tw * 0.5, r.get_center().y + (asc - desc) * 0.5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(String(sp.get("t", "#111111"))))


## Calção, pernas e meiões (modo completo). Desenhado antes da camisa, que cobre a cintura.
func _draw_legs(r: Rect2) -> void:
	var sh := Color(String(kit.get("shorts", kit.get("c2", "#111111"))))
	var sh2 := Color(String(kit.get("shorts2", kit.get("c1", "#FFFFFF"))))
	var so := Color(String(kit.get("socks", kit.get("c1", "#FFFFFF"))))
	var so2 := Color(String(kit.get("socks2", kit.get("c2", "#000000"))))
	var skin := Color("#C68E5D")
	var boot := Color("#1A1A1A")
	var outline := Color(0, 0, 0, 0.35)
	var lw := maxf(1.0, r.size.x * 0.012)
	# Pernas (pele entre o calção e os meiões)
	for x0 in [0.29, 0.57]:
		draw_rect(_fr(r, x0 + 0.02, 0.74, 0.1, 0.08), skin)
	# Calção
	var shorts := _fx(r, [Vector2(0.25, 0.54), Vector2(0.75, 0.54), Vector2(0.79, 0.77), Vector2(0.53, 0.79), Vector2(0.5, 0.69), Vector2(0.47, 0.79), Vector2(0.21, 0.77)])
	draw_colored_polygon(shorts, sh)
	var st: String = kit.get("shorts_style", "plain")
	var bands: Array = []
	match st:
		"side_stripe":
			bands = [[Vector2(0.23, 0.54), Vector2(0.28, 0.54), Vector2(0.27, 0.78), Vector2(0.21, 0.78)], [Vector2(0.72, 0.54), Vector2(0.77, 0.54), Vector2(0.79, 0.78), Vector2(0.73, 0.78)]]
		"hem":
			bands = [[Vector2(0, 0.74), Vector2(1, 0.74), Vector2(1, 0.8), Vector2(0, 0.8)]]
		"two_tone":
			bands = [[Vector2(0.5, 0.5), Vector2(1, 0.5), Vector2(1, 0.8), Vector2(0.5, 0.8)]]
		"stripes3":
			for i in 3:
				var d := i * 0.018
				bands.append([Vector2(0.25 - d + 0.005, 0.54), Vector2(0.25 - d + 0.013, 0.54), Vector2(0.23 - d + 0.013, 0.78), Vector2(0.23 - d + 0.005, 0.78)])
				bands.append([Vector2(0.735 + d, 0.54), Vector2(0.743 + d, 0.54), Vector2(0.763 + d, 0.78), Vector2(0.755 + d, 0.78)])
	for b in bands:
		for piece in Geometry2D.intersect_polygons(_fx(r, b), shorts):
			draw_colored_polygon(piece, sh2)
	var so_line := shorts.duplicate()
	so_line.append(shorts[0])
	draw_polyline(so_line, outline, lw, true)
	# Meiões e chuteiras
	var ss: String = kit.get("socks_style", "plain")
	for x0 in [0.29, 0.57]:
		var sock := _fx(r, [Vector2(x0, 0.8), Vector2(x0 + 0.14, 0.8), Vector2(x0 + 0.13, 0.95), Vector2(x0 + 0.01, 0.95)])
		draw_colored_polygon(sock, so)
		var sb: Array = []
		match ss:
			"hoops":
				for i in 3:
					sb.append(_fr(r, x0, 0.815 + i * 0.04, 0.14, 0.018))
			"top_band":
				sb.append(_fr(r, x0, 0.8, 0.14, 0.035))
			"two_tone":
				sb.append(_fr(r, x0, 0.875, 0.14, 0.08))
			"stripes3":
				for i in 3:
					sb.append(_fr(r, x0, 0.81 + i * 0.014, 0.14, 0.007))
		for rr: Rect2 in sb:
			var poly := PackedVector2Array([rr.position, rr.position + Vector2(rr.size.x, 0), rr.end, rr.position + Vector2(0, rr.size.y)])
			for piece in Geometry2D.intersect_polygons(poly, sock):
				draw_colored_polygon(piece, so2)
		var sk := sock.duplicate()
		sk.append(sock[0])
		draw_polyline(sk, outline, lw, true)
		var bt := _fx(r, [Vector2(x0 + 0.005, 0.945), Vector2(x0 + 0.135, 0.945), Vector2(x0 + 0.17, 0.985), Vector2(x0 + 0.005, 0.985)])
		draw_colored_polygon(bt, boot)


## Faixas do padrão em coordenadas unitárias (serão recortadas pelo corpo da camisa).
static func pattern_bands(pattern: String) -> Array:
	var out: Array = []
	match pattern:
		"stripes_v":
			for i in 3:
				var x := 0.3 + i * 0.16
				out.append(_rect(x, 0, 0.08, 1))
		"pinstripes":
			for i in 8:
				out.append(_rect(0.25 + i * 0.07, 0, 0.018, 1))
		"wide_stripes":
			out.append(_rect(0.2, 0, 0.14, 1))
			out.append(_rect(0.43, 0, 0.14, 1))
			out.append(_rect(0.66, 0, 0.14, 1))
		"center_stripe":
			out.append(_rect(0.44, 0, 0.12, 1))
		"stripes_h":
			for i in 4:
				out.append(_rect(0, 0.22 + i * 0.19, 1, 0.09))
		"hoops_thin":
			for i in 8:
				out.append(_rect(0, 0.18 + i * 0.1, 1, 0.035))
		"faixa":
			out.append(_rect(0, 0.36, 1, 0.14))
		"double_band":
			out.append(_rect(0, 0.3, 1, 0.07))
			out.append(_rect(0, 0.43, 1, 0.07))
		"diagonal":
			out.append(PackedVector2Array([Vector2(0.15, 0.05), Vector2(0.33, 0.05), Vector2(0.9, 0.95), Vector2(0.72, 0.95)]))
		"diagonal_rev":
			out.append(PackedVector2Array([Vector2(0.85, 0.05), Vector2(0.67, 0.05), Vector2(0.1, 0.95), Vector2(0.28, 0.95)]))
		"halves":
			out.append(_rect(0.5, 0, 0.5, 1))
		"bottom_half":
			out.append(_rect(0, 0.55, 1, 0.5))
		"quarters":
			out.append(_rect(0, 0, 0.5, 0.5))
			out.append(_rect(0.5, 0.5, 0.5, 0.5))
		"chevron":
			out.append(PackedVector2Array([Vector2(0.2, 0.2), Vector2(0.5, 0.42), Vector2(0.8, 0.2), Vector2(0.8, 0.32), Vector2(0.5, 0.54), Vector2(0.2, 0.32)]))
		"side_panels":
			out.append(_rect(0.2, 0.25, 0.1, 0.8))
			out.append(_rect(0.7, 0.25, 0.1, 0.8))
		"yoke":
			out.append(PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 0.24), Vector2(0.5, 0.3), Vector2(0, 0.24)]))
		"cross":
			out.append(_rect(0.44, 0, 0.12, 1))
			out.append(_rect(0, 0.36, 1, 0.12))
		"checkers":
			for iy in 10:
				for ix in 7:
					if (ix + iy) % 2 == 0:
						out.append(_rect(0.2 + ix * 0.086, iy * 0.1, 0.086, 0.1))
		"pixels":
			for iy in 20:
				for ix in 14:
					if (ix * 7 + iy * 3) % 5 == 0:
						out.append(_rect(0.2 + ix * 0.043, iy * 0.05, 0.043, 0.05))
	return out


static func _rect(x: float, y: float, w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)])


static func _xf(pts: Array, s: float, off: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(off + p * s)
	return out


static func _fx(r: Rect2, pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(r.position + Vector2(p.x * r.size.x, p.y * r.size.y))
	return out


static func _fr(r: Rect2, x: float, y: float, w: float, h: float) -> Rect2:
	return Rect2(r.position + Vector2(x * r.size.x, y * r.size.y), Vector2(w * r.size.x, h * r.size.y))
