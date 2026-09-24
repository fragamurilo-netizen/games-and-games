@tool
class_name KitView
extends Control
## Uniforme procedural. Por padrão desenha só a camisa; com `full` desenha camisa, calção e meiões.
## Chaves do dicionário do uniforme (todas opcionais, com padrão sensato):
##   pattern, c1 (principal), c2 (secundária), c3 (detalhes: gola, punhos, frisos),
##   collar, sleeve, shorts / shorts2 / shorts_style, socks / socks2 / socks_style,
##   sp = {n, c, t} (patrocinador master no peito), sp_m (manga), sp_c (costas), sp_s (calção),
##   sup = {n, c, t} (fornecedor de material esportivo, logo pequeno no peito).

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
## Vista de costas: patrocinador das costas, nome e número grande.
@export var back: bool = false:
	set(v):
		back = v
		queue_redraw()
@export var back_name: String = "":
	set(v):
		back_name = v
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

const BODY := [Vector2(0.31, 0.07), Vector2(0.4, 0.1), Vector2(0.5, 0.12), Vector2(0.6, 0.1), Vector2(0.69, 0.07),
	Vector2(0.75, 0.28), Vector2(0.74, 0.95), Vector2(0.26, 0.95), Vector2(0.25, 0.28)]
const SLEEVE_R := [Vector2(0.69, 0.07), Vector2(0.9, 0.2), Vector2(0.845, 0.37), Vector2(0.75, 0.33), Vector2(0.75, 0.28)]
const SLEEVE_L := [Vector2(0.31, 0.07), Vector2(0.25, 0.28), Vector2(0.25, 0.33), Vector2(0.155, 0.37), Vector2(0.1, 0.2)]
## Proporção largura/altura do uniforme completo e altura da camisa nele.
const FULL_ASPECT := 0.55
const FULL_SHIRT := 0.5


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
		var s := h * FULL_SHIRT
		_draw_shirt(s, r.position + Vector2((w - s) * 0.5, 0.0))
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
			draw_line(off + Vector2(0.887, 0.235) * s, off + Vector2(0.843, 0.36) * s, c3, maxf(1.5, s * 0.035))
			draw_line(off + Vector2(0.113, 0.235) * s, off + Vector2(0.157, 0.36) * s, c3, maxf(1.5, s * 0.035))
		"stripes":
			for i in 3:
				var d := (i - 1) * 0.02
				draw_line(off + Vector2(0.7, 0.085 + d) * s, off + Vector2(0.88 + d * 0.3, 0.215 + d) * s, c3, maxf(1.0, s * 0.011))
				draw_line(off + Vector2(0.3, 0.085 + d) * s, off + Vector2(0.12 - d * 0.3, 0.215 + d) * s, c3, maxf(1.0, s * 0.011))
		"raglan":
			draw_line(off + Vector2(0.4, 0.1) * s, off + Vector2(0.25, 0.3) * s, c3, maxf(1.0, s * 0.014))
			draw_line(off + Vector2(0.6, 0.1) * s, off + Vector2(0.75, 0.3) * s, c3, maxf(1.0, s * 0.014))
	var show_logos := s >= 56.0
	if back:
		# Costas: só a gola arredondada por trás, patrocinador, nome e número.
		draw_polyline(_xf([Vector2(0.38, 0.07), Vector2(0.5, 0.1), Vector2(0.62, 0.07)], s, off), c3 if c3 != c1 else c1.darkened(0.4), maxf(1.5, s * 0.03), true)
		var bo := body.duplicate()
		bo.append(body[0])
		draw_polyline(bo, Color(0, 0, 0, 0.35), maxf(1.0, s * 0.012), true)
		var fg := UIColors.on_color(c1)
		if show_logos:
			var spc: Dictionary = kit.get("sp_c", {})
			if not spc.is_empty():
				_draw_patch(Rect2(off + Vector2(0.33, 0.13) * s, Vector2(0.34, 0.08) * s), spc, c1)
			if back_name != "":
				_draw_text_centered(back_name.to_upper(), off + Vector2(0.5, 0.3) * s, s * 0.44, int(s * 0.075), fg, &"Caps")
		if number > 0:
			_draw_text_centered(str(number), off + Vector2(0.5, 0.62) * s, s * 0.44, int(s * 0.34), fg, &"Big")
		return
	_draw_collar(s, off, c1, c3)
	# Contorno sutil
	var outline := body.duplicate()
	outline.append(body[0])
	draw_polyline(outline, Color(0, 0, 0, 0.35), maxf(1.0, s * 0.012), true)
	var sp: Dictionary = kit.get("sp", {})
	var has_master := not sp.is_empty() and show_logos
	if show_logos:
		if has_master:
			_draw_patch(Rect2(off + Vector2(0.29, 0.34) * s, Vector2(0.42, 0.13) * s), sp, c1, true)
		var sup: Dictionary = kit.get("sup", {})
		if not sup.is_empty():
			# Fornecedor no peito direito do jogador (esquerda de quem olha).
			_draw_supplier(off + Vector2(0.36, 0.22) * s, s * 0.06, sup, c1)
		var spm: Dictionary = kit.get("sp_m", {})
		if not spm.is_empty():
			_draw_patch(Rect2(off + Vector2(0.77, 0.17) * s, Vector2(0.11, 0.06) * s), spm, c2 if sleeve == "contrast" or sleeve == "raglan" else c1)
	if number > 0:
		var fg := UIColors.on_color(c1)
		if has_master:
			_draw_text_centered(str(number), off + Vector2(0.5, 0.68) * s, s * 0.3, int(s * 0.2), fg, &"Big")
		else:
			_draw_text_centered(str(number), off + Vector2(0.5, 0.52) * s, s * 0.4, int(s * 0.3), fg, &"Big")


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


## Patrocinador estampado no tecido: sem caixa, na cor da marca que contrasta com o fundo.
## O master ganha um pequeno emblema da marca ao lado do nome.
func _draw_patch(r: Rect2, sp: Dictionary, bg: Color, emblem: bool = false) -> void:
	var fg := _ink(sp, bg)
	var name := String(sp.get("n", "")).to_upper()
	var center := r.get_center()
	var max_w := r.size.x
	if emblem:
		var e := r.size.y * 0.32
		var ec := Vector2(r.position.x + e, center.y)
		draw_circle(ec, e, fg)
		draw_circle(ec, e * 0.55, bg)
		draw_circle(ec, e * 0.25, fg)
		center.x += e
		max_w -= e * 2.4
	if not _draw_text_centered(name, center, max_w, int(r.size.y * 0.75), fg, &"Big"):
		# Espaço pequeno (manga, calção): só as iniciais da marca.
		var ini := ""
		for word in name.split(" ", false):
			ini += word.substr(0, 1)
		_draw_text_centered(ini, center, max_w, int(r.size.y * 0.8), fg, &"Big")


## Cor de "tinta" da marca que aparece sobre o tecido.
static func _ink(sp: Dictionary, bg: Color) -> Color:
	for key in ["t", "c"]:
		var c := Color(String(sp.get(key, "#FFFFFF")))
		if absf(c.get_luminance() - bg.get_luminance()) > 0.35:
			return c
	return UIColors.on_color(bg)


## Logos genéricos de material esportivo (formas simples, sem marcas reais).
func _draw_supplier(c: Vector2, u: float, sp: Dictionary, bg: Color) -> void:
	var col := _ink(sp, bg)
	var P := func(x: float, y: float) -> Vector2: return c + Vector2(x, y) * u
	match String(sp.get("logo", "")):
		"curva":
			draw_colored_polygon(PackedVector2Array([P.call(-1.0, 0.1), P.call(-0.6, 0.6), P.call(0.2, 0.4), P.call(1.1, -0.5), P.call(0.1, 0.1), P.call(-0.55, 0.3)]), col)
		"barras":
			for i in 3:
				var x := -0.8 + i * 0.6
				var hh := 0.5 + i * 0.35
				draw_colored_polygon(PackedVector2Array([P.call(x, 0.6), P.call(x + 0.35, 0.6), P.call(x + 0.35 + hh * 0.5, 0.6 - hh), P.call(x + hh * 0.5, 0.6 - hh)]), col)
		"triangulo":
			for i in 3:
				var y := 0.6 - i * 0.45
				var hw := 1.0 - i * 0.33
				draw_colored_polygon(PackedVector2Array([P.call(-hw, y), P.call(hw, y), P.call(hw * 0.8, y - 0.3), P.call(-hw * 0.8, y - 0.3)]), col)
		"raio":
			draw_colored_polygon(PackedVector2Array([P.call(0.3, -0.9), P.call(-0.6, 0.15), P.call(-0.05, 0.15), P.call(-0.3, 0.9), P.call(0.6, -0.2), P.call(0.05, -0.2)]), col)
		"asas":
			draw_colored_polygon(PackedVector2Array([P.call(-1.0, -0.5), P.call(0.0, 0.1), P.call(1.0, -0.5), P.call(0.0, 0.6)]), col)
		"diamante":
			draw_polyline(PackedVector2Array([P.call(0, -0.8), P.call(0.7, 0), P.call(0, 0.8), P.call(-0.7, 0), P.call(0, -0.8)]), col, maxf(1.0, u * 0.25), true)
		"trevo":
			for a in [-PI / 2.0, PI / 6.0, PI * 5.0 / 6.0]:
				draw_circle(c + Vector2(cos(a), sin(a)) * u * 0.42, u * 0.38, col)
		"estrela":
			var pts := PackedVector2Array()
			for i in 10:
				var rr := 0.9 if i % 2 == 0 else 0.38
				var a := -PI / 2.0 + i * PI / 5.0
				pts.append(c + Vector2(cos(a), sin(a)) * u * rr)
			draw_colored_polygon(pts, col)
		"chevron":
			for i in 2:
				var y := -0.3 + i * 0.55
				draw_polyline(PackedVector2Array([P.call(-0.8, y), P.call(0, y + 0.45), P.call(0.8, y)]), col, maxf(1.0, u * 0.28), true)
		_:
			_draw_text_centered(String(sp.get("n", "")).substr(0, 1).to_upper(), c, u * 2.0, int(u * 1.6), col, &"Big")


## Texto centrado em `center`, encolhido até caber em `max_w`.
func _draw_text_centered(txt: String, center: Vector2, max_w: float, size_px: int, color: Color, variation: StringName) -> bool:
	var font := get_theme_font(&"font", variation)
	var fs := maxi(4, size_px)
	var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var min_fs := 6
	while tw > max_w and fs > min_fs:
		fs -= 1
		tw = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if tw > max_w or fs < 5:
		return false
	var asc := font.get_ascent(fs)
	var desc := font.get_descent(fs)
	draw_string(font, Vector2(center.x - tw * 0.5, center.y + (asc - desc) * 0.5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
	return true


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
	for x0 in [0.3, 0.56]:
		draw_rect(_fr(r, x0 + 0.02, 0.6, 0.1, 0.13), skin)
	# Calção (a camisa cobre a cintura)
	var shorts := _fx(r, [Vector2(0.27, 0.44), Vector2(0.73, 0.44), Vector2(0.78, 0.64), Vector2(0.53, 0.655), Vector2(0.5, 0.57), Vector2(0.47, 0.655), Vector2(0.22, 0.64)])
	draw_colored_polygon(shorts, sh)
	var st: String = kit.get("shorts_style", "plain")
	var bands: Array = []
	match st:
		"side_stripe":
			bands = [[Vector2(0.24, 0.44), Vector2(0.3, 0.44), Vector2(0.28, 0.66), Vector2(0.21, 0.66)], [Vector2(0.7, 0.44), Vector2(0.76, 0.44), Vector2(0.79, 0.66), Vector2(0.72, 0.66)]]
		"hem":
			bands = [[Vector2(0, 0.615), Vector2(1, 0.615), Vector2(1, 0.67), Vector2(0, 0.67)]]
		"two_tone":
			bands = [[Vector2(0.5, 0.4), Vector2(1, 0.4), Vector2(1, 0.7), Vector2(0.5, 0.7)]]
		"stripes3":
			for i in 3:
				var d := i * 0.018
				bands.append([Vector2(0.275 - d, 0.44), Vector2(0.283 - d, 0.44), Vector2(0.24 - d, 0.66), Vector2(0.232 - d, 0.66)])
				bands.append([Vector2(0.717 + d, 0.44), Vector2(0.725 + d, 0.44), Vector2(0.768 + d, 0.66), Vector2(0.76 + d, 0.66)])
	for b in bands:
		for piece in Geometry2D.intersect_polygons(_fx(r, b), shorts):
			draw_colored_polygon(piece, sh2)
	var sps: Dictionary = kit.get("sp_s", {})
	if not sps.is_empty() and r.size.y >= 120.0 and not back:
		_draw_patch(_fr(r, 0.54, 0.52, 0.2, 0.05), sps, sh)
	var so_line := shorts.duplicate()
	so_line.append(shorts[0])
	draw_polyline(so_line, outline, lw, true)
	# Meiões e chuteiras
	var ss: String = kit.get("socks_style", "plain")
	for x0 in [0.3, 0.56]:
		var sock := _fx(r, [Vector2(x0, 0.71), Vector2(x0 + 0.14, 0.71), Vector2(x0 + 0.125, 0.93), Vector2(x0 + 0.015, 0.93)])
		draw_colored_polygon(sock, so)
		var sb: Array = []
		match ss:
			"hoops":
				for i in 3:
					sb.append(_fr(r, x0, 0.73 + i * 0.05, 0.14, 0.022))
			"top_band":
				sb.append(_fr(r, x0, 0.71, 0.14, 0.04))
			"two_tone":
				sb.append(_fr(r, x0, 0.82, 0.14, 0.11))
			"stripes3":
				for i in 3:
					sb.append(_fr(r, x0, 0.72 + i * 0.016, 0.14, 0.008))
		for rr: Rect2 in sb:
			var poly := PackedVector2Array([rr.position, rr.position + Vector2(rr.size.x, 0), rr.end, rr.position + Vector2(0, rr.size.y)])
			for piece in Geometry2D.intersect_polygons(poly, sock):
				draw_colored_polygon(piece, so2)
		var sk := sock.duplicate()
		sk.append(sock[0])
		draw_polyline(sk, outline, lw, true)
		var toe := 0.05 if x0 > 0.5 else -0.05
		var bt := _fx(r, [Vector2(x0 + 0.01, 0.925), Vector2(x0 + 0.13, 0.925), Vector2(x0 + 0.13 + maxf(0.0, toe), 0.975), Vector2(x0 + 0.01 + minf(0.0, toe), 0.975)])
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
