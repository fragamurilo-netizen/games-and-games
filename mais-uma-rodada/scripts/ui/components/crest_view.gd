@tool
class_name CrestView
extends Control
## Escudo procedural no estilo dos escudos de futebol de verdade: formato heráldico, campo
## (listras, faixas, partido, esquartelado, banda, chevron, cruz, chefe, losangos, xadrez...),
## símbolo central (animais, objetos, iniciais), anel com o nome do clube, faixa com o ano,
## estrelas de títulos, coroa e louros. Aceita o formato antigo (shape/symbol/stripes/border).
##
## Chaves (todas opcionais):
##   shape  shield|heater|iberian|french|swiss|tall|notched|scallop|modern|round|ring|oval|
##          oval_ring|octagon|diamond|hexagon|square|pennant
##   field  plain|stripes:N|hoops:N|halves|halves_h|tierce|quarters|sash|sash_r|diag|chevron|
##          cross|saltire|chief|base|pale|lozenges|checky|bordure|pile|vee|tricolor_h|tricolor_v|
##          stripes_tri:N (listras c1/fc/c3)
##   c1 c2 c3  cores (c3 = detalhe/dourado)     symbol  nome do CrestArt, letter, stars:N, tiger, none
##   fc     cor do desenho do campo (padrão c2) cc  cor do chefe (padrão c2)
##   sc     cor do símbolo                      initials  letras do monograma
##   text / text2  texto do anel (em cima / embaixo)    year  ano de fundação
##   chief_text  texto na faixa de cima          ribbon  texto da faixa de baixo
##   stars  estrelas acima do escudo            crown  1 coroa real, 2 coroa mural
##   laurel  louros em volta                    border  none|thin|thick|double|gold

@export var crest: Dictionary = {"shape": "shield", "symbol": "star", "c1": "#1B3A8C", "c2": "#FFFFFF", "border": "thin", "initials": "RA"}:
	set(v):
		crest = v
		queue_redraw()

const GOLD := Color("#E2B84A")
## Símbolos antigos → desenho do CrestArt.
const LEGACY := {"sun": "sunrise", "wave": "waves", "cross": "cross_plain", "diamond": "diamond_plain", "chevron": "chevron_plain"}

static var _cache: Dictionary = {}
static var _cache_order: Array = []
const CACHE_MAX := 300

var _rec: Array = []
var _recording := false


func set_club(c: Club) -> void:
	if c == null:
		return
	crest = c.crest
	tooltip_text = c.name


func _draw() -> void:
	var s := minf(size.x, size.y)
	if s <= 2.0:
		return
	var off := Vector2((size.x - s) * 0.5, (size.y - s) * 0.5)
	var img := CustomAssets.texture(String(crest.get("img", "")))
	if img != null:
		draw_texture_rect(img, Rect2(off, Vector2(s, s)), false)
		return
	var key := hash([crest, s])
	if _cache.has(key):
		_replay(_cache[key], off)
		return
	_rec = []
	_recording = true
	_render(s)
	_recording = false
	_cache[key] = _rec
	_cache_order.append(key)
	if _cache_order.size() > CACHE_MAX:
		_cache.erase(_cache_order.pop_front())
	_replay(_rec, off)
	_rec = []


# ---------------------------------------------------------------------------
# Especificação
# ---------------------------------------------------------------------------

## Especificação completa (valores padrão + compatibilidade com o formato antigo).
static func spec(cr: Dictionary) -> Dictionary:
	var sp := {}
	sp["shape"] = String(cr.get("shape", "shield"))
	var field := String(cr.get("field", ""))
	if field == "":
		field = "stripes:3" if bool(cr.get("stripes", false)) else "plain"
	sp["field"] = field
	sp["c1"] = Color(String(cr.get("c1", "#1B3A8C")))
	sp["c2"] = Color(String(cr.get("c2", "#FFFFFF")))
	sp["c3"] = Color(String(cr.get("c3", "#E2B84A")))
	sp["fc"] = Color(String(cr.get("fc", ""))) if String(cr.get("fc", "")) != "" else sp["c2"]
	sp["cc"] = Color(String(cr.get("cc", ""))) if String(cr.get("cc", "")) != "" else sp["c2"]
	var sym := String(cr.get("symbol", "star"))
	sp["symbol"] = String(LEGACY.get(sym, sym))
	sp["sc"] = Color(String(cr.get("sc", ""))) if String(cr.get("sc", "")) != "" else null
	sp["initials"] = String(cr.get("initials", "FC"))
	sp["text"] = String(cr.get("text", ""))
	sp["text2"] = String(cr.get("text2", ""))
	sp["year"] = String(cr.get("year", ""))
	sp["chief_text"] = String(cr.get("chief_text", ""))
	sp["ribbon"] = String(cr.get("ribbon", ""))
	sp["stars"] = int(cr.get("stars", 0))
	sp["crown"] = int(cr.get("crown", 0))
	sp["laurel"] = bool(cr.get("laurel", false))
	sp["border"] = String(cr.get("border", "thin"))
	return sp


## Cor que contrasta com `bg` escolhida entre as do escudo.
static func contrast(bg: Color, a: Color, b: Color) -> Color:
	if absf(a.get_luminance() - bg.get_luminance()) > 0.28:
		return a
	if absf(b.get_luminance() - bg.get_luminance()) > 0.28:
		return b
	return Color.WHITE if bg.get_luminance() < 0.55 else Color("#15171B")


# ---------------------------------------------------------------------------
# Desenho
# ---------------------------------------------------------------------------

func _render(s: float) -> void:
	var sp := spec(crest)
	var shape: String = sp["shape"]
	var c1: Color = sp["c1"]
	var c2: Color = sp["c2"]
	var c3: Color = sp["c3"]
	var small := s < 40.0
	# Espaço fora do escudo: coroa e estrelas em cima, faixa embaixo, louros em volta
	var top := 0.0
	if int(sp["crown"]) > 0:
		top += 0.2
	if int(sp["stars"]) > 0:
		top += 0.12 if not small else 0.1
	var bottom := 0.1 if String(sp["ribbon"]) != "" and not small else 0.0
	var side := 0.14 if bool(sp["laurel"]) else 0.0
	var box_s := s * minf(1.0 - top - bottom, 1.0 - side * 2.0)
	var box := Rect2(Vector2((s - box_s) * 0.5, s * top + (s * (1.0 - top - bottom) - box_s) * 0.5), Vector2(box_s, box_s))
	var unit := unit_shape(shape)
	var poly := _xf(unit, box)
	# Sombra e base
	var shadow := PackedVector2Array()
	for p in poly:
		shadow.append(p + Vector2(0, s * 0.03))
	_poly(shadow, Color(0, 0, 0, 0.28))
	var ring := shape == "ring" or shape == "oval_ring"
	var inner := poly
	if ring:
		# Anel externo com o nome; o campo fica no disco de dentro
		var band_col := c2 if absf(c2.get_luminance() - c1.get_luminance()) > 0.15 else c1.darkened(0.35)
		_poly(poly, band_col)
		inner = _xf(_shrink(unit, 0.27 if not small else 0.2), box)
	_poly(inner, c1)
	_field(inner, box, sp, s)
	# Chefe com texto
	var charge_box := _inner_box(box, shape)
	if String(sp["chief_text"]) != "" or String(sp["field"]) == "chief":
		var chief_h := 0.24
		var band := _xf(PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, chief_h), Vector2(0, chief_h)]), box)
		var cc: Color = sp["cc"]
		for piece in Geometry2D.intersect_polygons(band, inner):
			_poly(piece, cc)
		if String(sp["chief_text"]) != "" and not small:
			var ink := contrast(cc, c1, c3)
			var narrow := shape in ["round", "oval", "ring", "oval_ring", "octagon", "hexagon", "diamond"]
			_text_center(String(sp["chief_text"]), box.position + Vector2(box.size.x * 0.5, box.size.y * chief_h * 0.56), box.size.x * (0.46 if narrow else 0.62), box.size.y * 0.15, ink)
		charge_box = Rect2(charge_box.position + Vector2(0, box.size.y * 0.12), charge_box.size * Vector2(1.0, 0.86))
	# Símbolo
	_charge(sp, charge_box, inner, s)
	# Borda
	_border(poly, inner, ring, sp, s)
	# Texto do anel
	if ring and not small:
		var cc := box.get_center()
		var rr := box.size.x * 0.5 * (0.87 if shape == "ring" else 0.87)
		var band_col := c2 if absf(c2.get_luminance() - c1.get_luminance()) > 0.15 else c1.darkened(0.35)
		var ink := contrast(band_col, c1, c3)
		var fs := box.size.x * 0.105
		if String(sp["text"]) != "":
			_arc_text(String(sp["text"]), cc, rr - fs * 0.35, fs, ink, true)
		var bottom_text := String(sp["text2"]) if String(sp["text2"]) != "" else String(sp["year"])
		if bottom_text != "":
			_arc_text(bottom_text, cc, rr - fs * 0.35, fs * 0.9, ink, false)
		# Pontinhos separando os textos
		for sx: float in [-1.0, 1.0]:
			var a := PI * (0.5 - 0.42 * sx) + PI
			_circle(cc + Vector2(cos(a), sin(a)) * (rr - fs * 0.3), fs * 0.12, ink)
	# Faixa embaixo
	if bottom > 0.0:
		_ribbon(String(sp["ribbon"]), Rect2(Vector2(s * 0.12, s * (1.0 - bottom - 0.03)), Vector2(s * 0.76, s * bottom)), c3, c1)
	# Estrelas acima
	var y_cursor := box.position.y
	if int(sp["crown"]) > 0:
		var ch := s * 0.18
		var cr_box := Rect2(Vector2(s * 0.5 - box_s * 0.3, y_cursor - ch * 1.02), Vector2(box_s * 0.6, ch))
		_crown(cr_box, int(sp["crown"]), c3, s)
		y_cursor = cr_box.position.y
	if int(sp["stars"]) > 0:
		var n: int = mini(int(sp["stars"]), 7)
		var r := s * (0.045 if not small else 0.05)
		var sy := y_cursor - r * 1.25
		var sc: Color = c3 if int(sp["stars"]) > 0 else c2
		for i in n:
			var x := s * 0.5 + (i - (n - 1) * 0.5) * r * 2.3
			var dy := -absf(i - (n - 1) * 0.5) * r * 0.25 * -1.0
			_poly(_star(Vector2(x, sy + dy), r, r * 0.42, 5), sc)
	if bool(sp["laurel"]):
		_laurel(box, c3, s)


## Área útil para o símbolo dentro de cada formato (evita a ponta e o anel).
static func _inner_box(box: Rect2, shape: String) -> Rect2:
	var m := Rect2(0.2, 0.18, 0.6, 0.6)
	match shape:
		"ring", "oval_ring":
			m = Rect2(0.3, 0.3, 0.4, 0.4)
		"round", "oval", "octagon", "hexagon", "square":
			m = Rect2(0.2, 0.2, 0.6, 0.6)
		"diamond":
			m = Rect2(0.28, 0.28, 0.44, 0.44)
		"pennant":
			m = Rect2(0.26, 0.12, 0.48, 0.48)
		"tall":
			m = Rect2(0.26, 0.16, 0.48, 0.56)
		_:
			m = Rect2(0.2, 0.16, 0.6, 0.58)
	return Rect2(box.position + m.position * box.size, m.size * box.size)


func _field(poly: PackedVector2Array, box: Rect2, sp: Dictionary, s: float) -> void:
	var f := String(sp["field"])
	var c1: Color = sp["c1"]
	var c2: Color = sp["fc"]
	var c3: Color = sp["c3"]
	var kind := f.get_slice(":", 0)
	var n := int(f.get_slice(":", 1)) if f.contains(":") else 0
	var parts: Array = [] # [polígono unitário, cor]
	match kind:
		"stripes":
			n = maxi(n, 3)
			var w := 1.0 / (n * 2 - 1)
			for i in n - 1:
				var x := w * (1 + i * 2)
				parts.append([_rect(x, -0.1, w, 1.2), c2])
		"hoops":
			n = maxi(n, 3)
			var h := 1.0 / (n * 2 - 1)
			for i in n - 1:
				var y := h * (1 + i * 2)
				parts.append([_rect(-0.1, y, 1.2, h), c2])
		"halves":
			parts.append([_rect(0.5, -0.1, 0.6, 1.2), c2])
		"halves_h":
			parts.append([_rect(-0.1, 0.5, 1.2, 0.6), c2])
		"tierce":
			parts.append([_rect(0.333, -0.1, 0.334, 1.2), c2])
		"quarters":
			parts.append([_rect(0.5, -0.1, 0.6, 0.6), c2])
			parts.append([_rect(-0.1, 0.5, 0.6, 0.6), c2])
		"sash":
			parts.append([PackedVector2Array([Vector2(-0.1, 0.05), Vector2(0.2, -0.1), Vector2(1.1, 0.8), Vector2(0.8, 1.1)]), c2])
		"sash_r":
			parts.append([PackedVector2Array([Vector2(1.1, 0.05), Vector2(0.8, -0.1), Vector2(-0.1, 0.8), Vector2(0.2, 1.1)]), c2])
		"diag":
			parts.append([PackedVector2Array([Vector2(1.1, -0.1), Vector2(1.1, 1.1), Vector2(-0.1, 1.1)]), c2])
		"chevron":
			parts.append([PackedVector2Array([Vector2(-0.1, 0.72), Vector2(0.5, 0.3), Vector2(1.1, 0.72), Vector2(1.1, 0.94), Vector2(0.5, 0.52), Vector2(-0.1, 0.94)]), c2])
		"cross":
			parts.append([_rect(0.4, -0.1, 0.2, 1.2), c2])
			parts.append([_rect(-0.1, 0.36, 1.2, 0.2), c2])
		"saltire":
			parts.append([PackedVector2Array([Vector2(-0.1, 0.02), Vector2(0.02, -0.1), Vector2(1.1, 0.98), Vector2(0.98, 1.1)]), c2])
			parts.append([PackedVector2Array([Vector2(1.1, 0.02), Vector2(0.98, -0.1), Vector2(-0.1, 0.98), Vector2(0.02, 1.1)]), c2])
		"base":
			parts.append([_rect(-0.1, 0.7, 1.2, 0.5), c2])
		"pale":
			parts.append([_rect(0.36, -0.1, 0.28, 1.2), c2])
		"pile":
			parts.append([PackedVector2Array([Vector2(0.1, -0.1), Vector2(0.9, -0.1), Vector2(0.5, 0.85)]), c2])
		"lozenges":
			var k := 6
			for iy in range(-1, k + 1):
				for ix in range(-1, k + 1):
					if (ix + iy) % 2 != 0:
						continue
					var cx := (ix + 0.5 * (iy % 2)) / k
					var cy := iy * 0.5 / k * 2.0
					var hw := 0.5 / k
					parts.append([PackedVector2Array([Vector2(cx, cy - hw * 1.3), Vector2(cx + hw, cy), Vector2(cx, cy + hw * 1.3), Vector2(cx - hw, cy)]), c2])
		"checky":
			var k2 := 6
			for iy in k2:
				for ix in k2:
					if (ix + iy) % 2 == 0:
						parts.append([_rect(float(ix) / k2, float(iy) / k2, 1.0 / k2, 1.0 / k2), c2])
		"vee":
			parts.append([PackedVector2Array([Vector2(-0.1, -0.1), Vector2(0.14, -0.1), Vector2(0.5, 0.66), Vector2(0.86, -0.1), Vector2(1.1, -0.1), Vector2(0.5, 1.02)]), c2])
		"tricolor_h":
			# Com chefe, as três faixas dividem o que sobra embaixo dele
			var y0 := 0.24 if String(sp["chief_text"]) != "" else 0.0
			var bh := (1.0 - y0) / 3.0
			parts.append([_rect(-0.1, y0 + bh, 1.2, bh), c2])
			parts.append([_rect(-0.1, y0 + bh * 2.0, 1.2, 0.5), c3])
		"tricolor_v":
			parts.append([_rect(0.333, -0.1, 0.334, 1.2), c2])
			parts.append([_rect(0.667, -0.1, 0.5, 1.2), c3])
		"stripes_tri":
			n = maxi(n, 3)
			var w3 := 1.0 / n
			for i in n:
				if i % 3 != 0:
					parts.append([_rect(w3 * i, -0.1, w3 + 0.001, 1.2), c2 if i % 3 == 1 else c3])
		"bordure":
			pass
	for part: Array in parts:
		for piece in Geometry2D.intersect_polygons(_xf(part[0], box), poly):
			_poly(piece, part[1])
	if kind == "bordure":
		var inner := Geometry2D.offset_polygon(poly, -box.size.x * 0.07)
		for piece in inner:
			_polyline_closed(piece, c2, maxf(1.0, box.size.x * 0.08))


func _charge(sp: Dictionary, cb: Rect2, field_poly: PackedVector2Array, s: float) -> void:
	var sym := String(sp["symbol"])
	if sym == "none" or sym == "":
		return
	var c1: Color = sp["c1"]
	var c2: Color = sp["fc"]
	var c3: Color = sp["c3"]
	var field := String(sp["field"])
	# Cor do símbolo: a pedida, ou a que contrasta com o fundo (em campo dividido, dourado ou branco com contorno)
	var col: Color
	if sp["sc"] != null:
		col = sp["sc"]
	elif field == "plain" or field == "chief" or field == "bordure" or field == "base":
		col = contrast(c1, c2, c3)
	else:
		col = c3 if absf(c3.get_luminance() - c1.get_luminance()) > 0.2 and absf(c3.get_luminance() - c2.get_luminance()) > 0.2 else contrast(c1, Color.WHITE, c2)
	var outline := field != "plain" and field != "chief" and field != "bordure"
	var cen := cb.get_center()
	var r := minf(cb.size.x, cb.size.y) * 0.5
	if sym == "letter" or sym == "letters":
		var txt := String(sp["initials"])
		var fs := r * (1.25 if txt.length() <= 2 else (1.0 if txt.length() == 3 else 0.8))
		_text_center(txt, cen + Vector2(0, r * 0.05), cb.size.x * 1.05, fs, col, outline, Color("#15171B") if col.get_luminance() > 0.5 else Color.WHITE)
		return
	if sym.begins_with("stars:"):
		var n := clampi(int(sym.get_slice(":", 1)), 1, 5)
		var sr := r * (0.5 if n <= 2 else 0.36)
		for i in n:
			var x := cen.x + (i - (n - 1) * 0.5) * sr * 2.2
			_poly(_star(Vector2(x, cen.y), sr, sr * 0.42, 5), col)
		return
	if sym == "cross_plain":
		_poly(_xf_c(PackedVector2Array([Vector2(-0.22, -1), Vector2(0.22, -1), Vector2(0.22, -0.22), Vector2(1, -0.22), Vector2(1, 0.22), Vector2(0.22, 0.22), Vector2(0.22, 1), Vector2(-0.22, 1), Vector2(-0.22, 0.22), Vector2(-1, 0.22), Vector2(-1, -0.22), Vector2(-0.22, -0.22)]), cen, r), col)
		return
	if sym == "diamond_plain":
		_poly(_xf_c(PackedVector2Array([Vector2(0, -1), Vector2(0.75, 0), Vector2(0, 1), Vector2(-0.75, 0)]), cen, r), col)
		return
	if sym == "chevron_plain":
		for k in 2:
			var y := -0.35 + k * 0.6
			_polyline(PackedVector2Array([cen + Vector2(-r, (y - 0.4) * r), cen + Vector2(0, (y + 0.2) * r), cen + Vector2(r, (y - 0.4) * r)]), col, maxf(2.0, r * 0.26))
		return
	var det := sym + "_d"
	if sym == "tiger":
		sym = "cat"
		det = "tiger_d"
	if not CrestArt.has(sym):
		sym = "star"
		det = "star_d"
	var polys: Array = CrestArt.polys(sym)
	var shade := col.darkened(0.45) if col.get_luminance() > 0.35 else col.lightened(0.35)
	# Contorno fino para destacar sobre campo dividido
	if outline and s >= 36.0:
		for p: PackedVector2Array in polys:
			var pts := _xf_c(p, cen, r)
			_polyline_closed(pts, c1.darkened(0.3) if c1.get_luminance() < 0.6 else Color(0, 0, 0, 0.6), maxf(1.0, r * 0.07))
	for p: PackedVector2Array in polys:
		_poly(_xf_c(p, cen, r), col)
	if CrestArt.has(det) and s >= 28.0:
		for p: PackedVector2Array in CrestArt.polys(det):
			_poly(_xf_c(p, cen, r), shade if sym != "ball" else Color("#15171B"))


func _border(poly: PackedVector2Array, inner: PackedVector2Array, ring: bool, sp: Dictionary, s: float) -> void:
	var b := String(sp["border"])
	var c2: Color = sp["c2"]
	var c3: Color = sp["c3"]
	var c1: Color = sp["c1"]
	var edge := c2 if absf(c2.get_luminance() - c1.get_luminance()) > 0.15 else c1.lightened(0.3)
	match b:
		"none":
			pass
		"thick":
			_polyline_closed(poly, edge, maxf(2.0, s * 0.06))
		"double":
			_polyline_closed(poly, edge, maxf(1.0, s * 0.03))
			for piece in Geometry2D.offset_polygon(poly, -s * 0.06):
				_polyline_closed(piece, edge, maxf(1.0, s * 0.018))
		"gold":
			_polyline_closed(poly, c3, maxf(1.5, s * 0.045))
			_polyline_closed(poly, c3.darkened(0.35), maxf(1.0, s * 0.012))
		_:
			_polyline_closed(poly, edge, maxf(1.0, s * 0.03))
	if ring:
		_polyline_closed(inner, c3 if b == "gold" else edge, maxf(1.0, s * 0.02))


func _crown(r: Rect2, kind: int, col: Color, s: float) -> void:
	var cen := r.get_center()
	var rad := r.size.x * 0.5
	if kind == 2:
		# Coroa mural: muralha com ameias
		var pts := PackedVector2Array()
		var n := 5
		var y0 := r.end.y
		var y1 := r.position.y + r.size.y * 0.3
		pts.append(Vector2(r.position.x, y0))
		for i in n:
			var x0 := r.position.x + r.size.x * float(i) / n
			var x1 := r.position.x + r.size.x * (i + 0.5) / n
			var x2 := r.position.x + r.size.x * float(i + 1) / n
			pts.append(Vector2(x0, y1))
			pts.append(Vector2(x1 - r.size.x * 0.02, y1))
			pts.append(Vector2(x1 - r.size.x * 0.02, y1 + r.size.y * 0.25))
			pts.append(Vector2(x1 + r.size.x * 0.1, y1 + r.size.y * 0.25))
			pts.append(Vector2(x1 + r.size.x * 0.1, y1))
			pts.append(Vector2(x2, y1))
		pts.append(Vector2(r.end.x, y0))
		_poly(pts, col)
		_polyline_closed(pts, col.darkened(0.4), maxf(1.0, s * 0.01))
		return
	for p: PackedVector2Array in CrestArt.polys("crown"):
		var pts := PackedVector2Array()
		for q in p:
			pts.append(cen + Vector2(q.x * rad, q.y * r.size.y * 0.55))
		_poly(pts, col)
		_polyline_closed(pts, col.darkened(0.4), maxf(1.0, s * 0.008))
	for p: PackedVector2Array in CrestArt.polys("crown_d"):
		var pts := PackedVector2Array()
		for q in p:
			pts.append(cen + Vector2(q.x * rad, q.y * r.size.y * 0.55))
		_poly(pts, Color("#B3122E"))


func _laurel(box: Rect2, col: Color, s: float) -> void:
	var cen := box.get_center() + Vector2(0, box.size.y * 0.06)
	var rad := box.size.x * 0.6
	var dark := col.darkened(0.3)
	for sx: float in [-1.0, 1.0]:
		# Ramo: arco do pé até a altura do topo do escudo
		var stem := PackedVector2Array()
		for i in 9:
			var a := PI * 0.5 + sx * (0.25 + i * 0.26)
			stem.append(cen + Vector2(cos(a), sin(a)) * rad)
		_polyline(stem, dark, maxf(1.0, s * 0.012))
		for i in 8:
			var a := PI * 0.5 + sx * (0.32 + i * 0.26)
			var p := cen + Vector2(cos(a), sin(a)) * rad
			var dir := Vector2(-sin(a), cos(a)) * -sx
			for side: float in [-1.0, 1.0]:
				var l := s * (0.085 - i * 0.004)
				var w := l * 0.32
				var tip := p + dir.rotated(side * 0.75 * sx).normalized() * l
				var nrm := (tip - p).orthogonal().normalized() * w
				var leaf := PackedVector2Array([p, p.lerp(tip, 0.45) + nrm, tip, p.lerp(tip, 0.45) - nrm])
				_poly(leaf, col if side > 0 else col.darkened(0.12))


func _ribbon(text: String, r: Rect2, col: Color, ink_bg: Color) -> void:
	var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), Vector2(r.end.x - r.size.x * 0.06, r.position.y + r.size.y * 0.5), r.end, Vector2(r.position.x, r.end.y), Vector2(r.position.x + r.size.x * 0.06, r.position.y + r.size.y * 0.5)])
	_poly(pts, col)
	_polyline_closed(pts, col.darkened(0.35), maxf(1.0, r.size.y * 0.06))
	var ink := contrast(col, ink_bg, Color("#15171B"))
	_text_center(text, r.get_center(), r.size.x * 0.8, r.size.y * 0.7, ink)


# ---------------------------------------------------------------------------
# Formatos
# ---------------------------------------------------------------------------

static func unit_shape(shape: String) -> PackedVector2Array:
	var pts := PackedVector2Array()
	match shape:
		"round", "ring":
			for i in 56:
				var a := TAU * i / 56.0
				pts.append(Vector2(0.5 + cos(a) * 0.47, 0.5 + sin(a) * 0.47))
		"oval", "oval_ring":
			for i in 56:
				var a := TAU * i / 56.0
				pts.append(Vector2(0.5 + cos(a) * 0.38, 0.5 + sin(a) * 0.48))
		"pennant":
			pts = PackedVector2Array([Vector2(0.06, 0.06), Vector2(0.94, 0.06), Vector2(0.94, 0.2), Vector2(0.5, 0.97), Vector2(0.06, 0.2)])
		"modern":
			pts = PackedVector2Array([Vector2(0.5, 0.02), Vector2(0.93, 0.26), Vector2(0.93, 0.74), Vector2(0.5, 0.98), Vector2(0.07, 0.74), Vector2(0.07, 0.26)])
		"hexagon":
			for i in 6:
				var a := TAU * i / 6.0
				pts.append(Vector2(0.5 + cos(a) * 0.48, 0.5 + sin(a) * 0.46))
		"octagon":
			for i in 8:
				var a := TAU * (i + 0.5) / 8.0
				pts.append(Vector2(0.5 + cos(a) * 0.49, 0.5 + sin(a) * 0.49))
		"diamond":
			pts = PackedVector2Array([Vector2(0.5, 0.02), Vector2(0.96, 0.5), Vector2(0.5, 0.98), Vector2(0.04, 0.5)])
		"square":
			var r := 0.14
			for corner in [Vector2(0.9 - r, 0.1 + r), Vector2(0.9 - r, 0.9 - r), Vector2(0.1 + r, 0.9 - r), Vector2(0.1 + r, 0.1 + r)]:
				var start := 0.0
				if corner.x > 0.5 and corner.y < 0.5:
					start = -PI / 2
				elif corner.x > 0.5:
					start = 0.0
				elif corner.y > 0.5:
					start = PI / 2
				else:
					start = PI
				for k in 7:
					var a: float = start + (PI / 2) * k / 6.0
					pts.append(corner + Vector2(cos(a), sin(a)) * r)
		"iberian":
			# Topo reto, laterais retas e fundo em semicírculo (escudo português/espanhol)
			pts.append(Vector2(0.1, 0.04))
			pts.append(Vector2(0.9, 0.04))
			pts.append(Vector2(0.9, 0.56))
			for i in range(1, 16):
				var a := PI * float(i) / 16.0
				pts.append(Vector2(0.5 + cos(a) * 0.4, 0.56 + sin(a) * 0.42))
			pts.append(Vector2(0.1, 0.56))
		"french":
			# Topo reto, laterais retas, base em duas curvas que se encontram numa ponta
			pts.append(Vector2(0.1, 0.04))
			pts.append(Vector2(0.9, 0.04))
			pts.append(Vector2(0.9, 0.62))
			for i in range(1, 9):
				pts.append(_bezier(Vector2(0.9, 0.62), Vector2(0.9, 0.86), Vector2(0.5, 0.98), float(i) / 8.0))
			for i in range(1, 8):
				pts.append(_bezier(Vector2(0.5, 0.98), Vector2(0.1, 0.86), Vector2(0.1, 0.62), float(i) / 8.0))
		"tall":
			pts.append(Vector2(0.18, 0.03))
			pts.append(Vector2(0.82, 0.03))
			for i in range(1, 13):
				pts.append(_bezier(Vector2(0.82, 0.03), Vector2(0.86, 0.74), Vector2(0.5, 0.98), float(i) / 12.0))
			for i in range(1, 12):
				pts.append(_bezier(Vector2(0.5, 0.98), Vector2(0.14, 0.74), Vector2(0.18, 0.03), float(i) / 12.0))
		"notched":
			pts = PackedVector2Array([Vector2(0.2, 0.04), Vector2(0.8, 0.04), Vector2(0.9, 0.14), Vector2(0.9, 0.6)])
			for i in range(1, 13):
				pts.append(_bezier(Vector2(0.9, 0.6), Vector2(0.9, 0.88), Vector2(0.5, 0.98), float(i) / 12.0))
			for i in range(1, 12):
				pts.append(_bezier(Vector2(0.5, 0.98), Vector2(0.1, 0.88), Vector2(0.1, 0.6), float(i) / 12.0))
			pts.append(Vector2(0.1, 0.14))
		"scallop":
			# Topo com três arcos (escudos clássicos)
			for k in 3:
				var x0 := 0.1 + k * 0.2667
				for i in 7:
					var a := PI + PI * float(i) / 6.0
					pts.append(Vector2(x0 + 0.1333 + cos(a) * 0.1333, 0.14 + sin(a) * 0.1))
			pts.append(Vector2(0.9, 0.56))
			for i in range(1, 16):
				var a := PI * float(i) / 16.0
				pts.append(Vector2(0.5 + cos(a) * 0.4, 0.56 + sin(a) * 0.42))
			pts.append(Vector2(0.1, 0.56))
		"swiss":
			pts.append(Vector2(0.08, 0.05))
			pts.append(Vector2(0.5, 0.1))
			pts.append(Vector2(0.92, 0.05))
			for i in 13:
				pts.append(_bezier(Vector2(0.92, 0.05), Vector2(0.95, 0.72), Vector2(0.5, 0.98), i / 12.0))
			for i in range(1, 12):
				pts.append(_bezier(Vector2(0.5, 0.98), Vector2(0.05, 0.72), Vector2(0.08, 0.05), i / 12.0))
		_:
			# Escudo clássico ("shield"/"heater"): topo reto e ponta arredondada
			pts.append(Vector2(0.08, 0.05))
			pts.append(Vector2(0.92, 0.05))
			for i in range(1, 14):
				pts.append(_bezier(Vector2(0.92, 0.05), Vector2(0.96, 0.7), Vector2(0.5, 0.98), float(i) / 13.0))
			for i in range(1, 13):
				pts.append(_bezier(Vector2(0.5, 0.98), Vector2(0.04, 0.7), Vector2(0.08, 0.05), float(i) / 13.0))
	return pts


static func _bezier(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
	return a.lerp(b, t).lerp(b.lerp(c, t), t)


static func _shrink(pts: PackedVector2Array, amount: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(Vector2(0.5, 0.5) + (p - Vector2(0.5, 0.5)) * (1.0 - amount))
	return out


static func _rect(x: float, y: float, w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)])


static func _xf(pts: PackedVector2Array, box: Rect2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(box.position + p * box.size)
	return out


static func _xf_c(pts: PackedVector2Array, c: Vector2, r: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(c + p * r)
	return out


static func _star(c: Vector2, r1: float, r2: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n * 2:
		var a := -PI / 2 + PI * i / n
		var r := r1 if i % 2 == 0 else r2
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


static func _ngon(c: Vector2, r: float, n: int, rot: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := rot + TAU * i / n
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


# ---------------------------------------------------------------------------
# Texto
# ---------------------------------------------------------------------------

func _font() -> Font:
	var f := get_theme_font(&"font", &"Big")
	return f if f != null else ThemeDB.fallback_font


func _text_center(txt: String, center: Vector2, max_w: float, size_px: float, col: Color, outline: bool = false, out_col: Color = Color.BLACK) -> void:
	var font := _font()
	var fs := maxi(4, int(size_px))
	var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	while tw > max_w and fs > 5:
		fs -= 1
		tw = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if fs < 5:
		return
	var pos := center + Vector2(-tw * 0.5, fs * 0.36)
	if outline:
		_string_outline(font, pos, txt, fs, maxi(1, int(fs * 0.12)), out_col)
	_string(font, pos, txt, fs, col)


## Texto em arco: em cima lê no sentido horário, embaixo lê da esquerda para a direita (de pé).
func _arc_text(txt: String, c: Vector2, r: float, size_px: float, col: Color, top: bool) -> void:
	var font := _font()
	var fs := maxi(5, int(size_px))
	var widths: Array = []
	var total := 0.0
	for ch in txt:
		var w := font.get_char_size(ch.unicode_at(0), fs).x
		widths.append(w)
		total += w
	var max_arc := PI * 0.82 * r
	if total > max_arc:
		fs = maxi(5, int(fs * max_arc / total))
		total = 0.0
		widths.clear()
		for ch in txt:
			var w := font.get_char_size(ch.unicode_at(0), fs).x
			widths.append(w)
			total += w
	var span := total / r
	var a := (-PI * 0.5 - span * 0.5) if top else (PI * 0.5 + span * 0.5)
	for i in txt.length():
		var w: float = widths[i]
		var mid := a + (w * 0.5 / r) * (1.0 if top else -1.0)
		var pos := c + Vector2(cos(mid), sin(mid)) * r
		var rot := mid + PI * 0.5 if top else mid - PI * 0.5
		_char_at(font, pos, rot, txt.substr(i, 1), fs, col, w)
		a += (w / r) * (1.0 if top else -1.0)


# ---------------------------------------------------------------------------
# Comandos gravados (cache)
# ---------------------------------------------------------------------------

func _poly(pts: PackedVector2Array, col: Color) -> void:
	if pts.size() < 3:
		return
	if Geometry2D.triangulate_polygon(pts).is_empty():
		return
	_rec.append([0, pts, col])


func _polyline(pts: PackedVector2Array, col: Color, w: float) -> void:
	_rec.append([1, pts, col, w])


func _polyline_closed(pts: PackedVector2Array, col: Color, w: float) -> void:
	if pts.size() < 2:
		return
	var c := PackedVector2Array(pts)
	c.append(pts[0])
	_rec.append([1, c, col, w])


func _circle(p: Vector2, r: float, col: Color) -> void:
	_rec.append([2, p, r, col])


func _string(font: Font, pos: Vector2, txt: String, fs: int, col: Color) -> void:
	_rec.append([3, font, pos, txt, fs, col])


func _string_outline(font: Font, pos: Vector2, txt: String, fs: int, size_px: int, col: Color) -> void:
	_rec.append([4, font, pos, txt, fs, size_px, col])


func _char_at(font: Font, pos: Vector2, rot: float, ch: String, fs: int, col: Color, w: float) -> void:
	_rec.append([5, font, pos, rot, ch, fs, col, w])


func _replay(cmds: Array, off: Vector2) -> void:
	draw_set_transform(off, 0.0, Vector2.ONE)
	for c: Array in cmds:
		match int(c[0]):
			0:
				draw_colored_polygon(c[1], c[2])
			1:
				draw_polyline(c[1], c[2], c[3], true)
			2:
				draw_circle(c[1], c[2], c[3])
			3:
				draw_string(c[1], c[2], c[3], HORIZONTAL_ALIGNMENT_LEFT, -1, c[4], c[5])
			4:
				draw_string_outline(c[1], c[2], c[3], HORIZONTAL_ALIGNMENT_LEFT, -1, c[4], c[5], c[6])
			5:
				var p: Vector2 = c[2]
				draw_set_transform(off + p, c[3], Vector2.ONE)
				draw_string(c[1], Vector2(-float(c[7]) * 0.5, float(c[5]) * 0.36), c[4], HORIZONTAL_ALIGNMENT_LEFT, -1, c[5], c[6])
				draw_set_transform(off, 0.0, Vector2.ONE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
