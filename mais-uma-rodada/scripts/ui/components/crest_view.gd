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
##   plate  auto|band|disc|none — placa atrás do monograma (auto: só em campo listrado/dividido)
##   pc     cor da placa                         finish  false tira o filete interno
##   tc     cor do texto do anel
##   canton cor do cantão (quadrado no alto à esquerda)   canton_sym  símbolo dentro dele
##   field pale_cross:L|R  metade com cruz (lado L/R) e metade listrada (Milan, Bologna)
## Logos de competição (mesmo formato, chaves a mais):
##   logo  true: desenho chapado de marca (sem filete nem sombra), formatos tile|badge|disc
##   ring_c  cor do aro fino por fora (padrão: sem aro)    accent  cor de detalhe (faixa, numeral)
##   num  numeral grande no canto (divisões de acesso: "2", "3")
##   wordmark  nome embaixo do desenho, dentro do formato (só em tamanho grande)

@export var crest: Dictionary = {"shape": "shield", "symbol": "star", "c1": "#1B3A8C", "c2": "#FFFFFF", "border": "thin", "initials": "RA"}:
	set(v):
		crest = v
		queue_redraw()

const GOLD := Color("#E2B84A")
## Campos em que o monograma ganha placa (listras, faixas, divididos).
const BUSY_FIELDS := ["stripes", "hoops", "halves", "halves_h", "tierce", "quarters", "sash", "sash_r", "diag", "saltire", "cross", "lozenges", "checky", "vee", "tricolor_h", "tricolor_v", "stripes_tri", "pile", "chevron", "bends"]
const ROUNDISH := ["round", "ring", "oval", "oval_ring", "octagon", "hexagon", "disc"]
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
		# Escudos em imagem de qualquer proporção cabem no quadrado sem deformar.
		var ts := img.get_size()
		var k := s / maxf(ts.x, ts.y)
		var sz := ts * k
		draw_texture_rect(img, Rect2(off + (Vector2(s, s) - sz) * 0.5, sz), false)
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
	# Onde fica o símbolo ("" centro, "tl" canto de cima à esquerda, "low" metade de baixo), escala,
	# letras entrelaçadas (monograma) e um texto curto embaixo das letras ("09")
	sp["sym_pos"] = String(cr.get("sym_pos", ""))
	sp["sym_scale"] = float(cr.get("sym_scale", 1.0))
	sp["mono"] = bool(cr.get("mono", false))
	sp["sub"] = String(cr.get("sub", ""))
	sp["line_art"] = bool(cr.get("line_art", false))
	sp["ribbon_top"] = String(cr.get("ribbon_top", "")) # faixa acima do escudo (MANCHESTER)
	sp["top_style"] = String(cr.get("top_style", "")) # "gates": portão em arco atrás da faixa de cima (Liverpool)
	sp["flames"] = bool(cr.get("flames", false)) # chamas dos dois lados (Liverpool)
	sp["chief_sym"] = String(cr.get("chief_sym", ""))
	sp["chief_text2"] = String(cr.get("chief_text2", "")) # segunda linha menor no chefe
	sp["chief_h"] = float(cr.get("chief_h", 0.24)) # símbolo no chefe (navio do United)
	sp["chief_sc"] = Color(String(cr.get("chief_sc", "#C8102E")))
	sp["staff"] = bool(cr.get("staff", false)) # cajado atrás do leão (Chelsea)
	sp["ring_deco"] = String(cr.get("ring_deco", "")) # "roses": rosas e bolas embaixo do anel # símbolo em traço (Ajax), sem preenchimento
	sp["star_c"] = Color(String(cr.get("star_c", ""))) if String(cr.get("star_c", "")) != "" else sp["c3"]
	sp["plate"] = String(cr.get("plate", "auto"))
	sp["pc"] = _col_or_null(cr, "pc")
	sp["finish"] = bool(cr.get("finish", true))
	sp["tc"] = _col_or_null(cr, "tc")
	sp["canton"] = _col_or_null(cr, "canton")
	sp["canton_sym"] = String(cr.get("canton_sym", ""))
	sp["logo"] = bool(cr.get("logo", false))
	sp["ring_c"] = _col_or_null(cr, "ring_c")
	sp["accent"] = _col_or_null(cr, "accent")
	sp["num"] = String(cr.get("num", ""))
	sp["wordmark"] = String(cr.get("wordmark", ""))
	sp["flag"] = Array(cr.get("flag", [])) if cr.get("flag", null) is Array else []
	sp["sym_top"] = String(cr.get("sym_top", ""))
	return sp


static func _col_or_null(cr: Dictionary, key: String) -> Variant:
	var v := String(cr.get(key, ""))
	return Color(v) if v != "" else null


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
	var logo := bool(sp["logo"])
	# Espaço fora do escudo: coroa e estrelas em cima, faixa embaixo, louros em volta
	var top := 0.0
	if int(sp["crown"]) > 0:
		top += 0.2
	if int(sp["stars"]) > 0:
		top += 0.12 if not small else 0.1
	if String(sp["ribbon_top"]) != "" and not small:
		top += 0.2 if String(sp["top_style"]) == "gates" else 0.13
	var bottom := 0.1 if String(sp["ribbon"]) != "" and not small else 0.0
	var side := 0.14 if bool(sp["laurel"]) else (0.13 if bool(sp["flames"]) else 0.0)
	var box_s := s * minf(1.0 - top - bottom, 1.0 - side * 2.0)
	var box := Rect2(Vector2((s - box_s) * 0.5, s * top + (s * (1.0 - top - bottom) - box_s) * 0.5), Vector2(box_s, box_s))
	var unit := unit_shape(shape)
	var poly := _xf(unit, box)
	# Sombra curta embaixo (o logo de competição fica chapado, como marca impressa)
	if not logo:
		var shadow := PackedVector2Array()
		for p in poly:
			shadow.append(p + Vector2(0, s * 0.026))
		_poly(shadow, Color(0, 0, 0, 0.24))
	var ring := shape == "ring" or shape == "oval_ring"
	var inner := poly
	if ring:
		# Anel externo com o nome; o campo fica no disco de dentro
		var band_col := c2 if absf(c2.get_luminance() - c1.get_luminance()) > 0.15 else c1.darkened(0.35)
		_poly(poly, band_col)
		inner = _xf(_shrink(unit, 0.27 if not small else 0.2), box)
	_poly(inner, c1)
	_field(inner, box, sp, s)
	if sp["canton"] != null:
		_canton(sp, box, inner, s)
	var charge_box := _inner_box(box, shape)
	# Faixa com as cores da bandeira no alto (logos de liga)
	var flag: Array = sp["flag"]
	if flag.size() >= 2 and not ring:
		var fh := 0.15
		for i in flag.size():
			var part := _xf(_rect(-0.1 + 1.2 * i / flag.size(), -0.1, 1.2 / flag.size() + 0.002, fh + 0.1), box)
			for piece in Geometry2D.intersect_polygons(part, inner):
				_poly(piece, Color(String(flag[i])))
		charge_box = Rect2(charge_box.position + Vector2(0, box.size.y * 0.06), charge_box.size)
	# Chefe com texto
	if String(sp["chief_text"]) != "" or String(sp["field"]) == "chief" or String(sp["chief_sym"]) != "":
		var chief_h := float(sp["chief_h"])
		var band := _xf(PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, chief_h), Vector2(0, chief_h)]), box)
		var cc: Color = sp["cc"]
		for piece in Geometry2D.intersect_polygons(band, inner):
			_poly(piece, cc)
		if String(sp["chief_text"]) != "" and not small:
			var ink := contrast(cc, c1, c3)
			var narrow := shape in ["round", "oval", "ring", "oval_ring", "octagon", "hexagon", "diamond"]
			var t2 := String(sp["chief_text2"])
			var ty := chief_h * (0.42 if t2 != "" else 0.56)
			_text_center(String(sp["chief_text"]), box.position + Vector2(box.size.x * 0.5, box.size.y * ty), box.size.x * (0.46 if narrow else 0.66), box.size.y * (0.14 if t2 != "" else 0.15), ink)
			if t2 != "":
				_text_center(t2, box.position + Vector2(box.size.x * 0.5, box.size.y * chief_h * 0.8), box.size.x * 0.7, box.size.y * 0.06, ink)
		if String(sp["chief_sym"]) != "" and CrestArt.has(String(sp["chief_sym"])):
			var ccen := box.position + Vector2(box.size.x * 0.5, box.size.y * chief_h * 0.55)
			for pp: PackedVector2Array in CrestArt.polys(String(sp["chief_sym"])):
				_poly(_xf_c(pp, ccen, box.size.y * chief_h * 0.42), sp["chief_sc"])
		charge_box = Rect2(charge_box.position + Vector2(0, box.size.y * 0.12), charge_box.size * Vector2(1.0, 0.86))
	# Filete interno fino (estilo chapado, bordado)
	if bool(sp["finish"]) and not logo and s >= 30.0 and not ring and String(sp["border"]) in ["thin", "thick", "none"]:
		_rim(inner, sp, s)
	# Placa atrás do monograma (faixa ou disco), para as letras não se perderem nas listras
	var plate := plate_mode(sp)
	if plate != "" and not small:
		_plate(plate, sp, charge_box, box, inner, s)
	# Símbolo
	match String(sp["sym_pos"]):
		"tl":
			charge_box = Rect2(box.position + box.size * Vector2(0.13, 0.1), box.size * 0.4)
		"low":
			charge_box = Rect2(box.position + box.size * Vector2(0.3, 0.55), box.size * 0.4)
	var wordmark := String(sp["wordmark"]) if s >= 72.0 and not ring else ""
	if logo and not ring:
		charge_box = _logo_box(box, shape, flag.size() >= 2, String(sp["sym_top"]) != "", wordmark != "")
	if float(sp["sym_scale"]) != 1.0:
		var cc0 := charge_box.get_center()
		charge_box = Rect2(cc0 - charge_box.size * 0.5 * float(sp["sym_scale"]), charge_box.size * float(sp["sym_scale"]))
	_charge(sp, charge_box, inner, s, box)
	if String(sp["sym_top"]) != "" and CrestArt.has(String(sp["sym_top"])):
		# Símbolo pequeno acima do principal (coroa sobre o leão, estrela sobre a bola)
		var tc0 := Vector2(charge_box.get_center().x, charge_box.position.y - box.size.y * 0.09)
		var tcol: Color = sp["accent"] if sp["accent"] != null else (sp["sc"] if sp["sc"] != null else contrast(c1, c2, c3))
		for pp: PackedVector2Array in CrestArt.polys(String(sp["sym_top"])):
			_poly(_xf_c(pp, tc0, box.size.x * 0.115), tcol)
	if wordmark != "":
		var wy := 0.79 if shape != "badge" else 0.74
		var ink: Color = sp["sc"] if sp["sc"] != null else contrast(c1, c2, c3)
		_text_center(wordmark, box.position + box.size * Vector2(0.5, wy), box.size.x * (0.64 if shape in ROUNDISH or shape == "badge" else 0.8), box.size.y * 0.13, ink)
	# Borda
	_border(poly, inner, ring, sp, s)
	# Texto do anel
	if ring and not small:
		var cc := box.get_center()
		var rr := box.size.x * 0.5 * (0.87 if shape == "ring" else 0.87)
		var band_col := c2 if absf(c2.get_luminance() - c1.get_luminance()) > 0.15 else c1.darkened(0.35)
		var ink: Color = sp["tc"] if sp["tc"] != null else contrast(band_col, c1, c3)
		var fs := box.size.x * 0.105
		if String(sp["text"]) != "":
			_arc_text(String(sp["text"]), cc, rr - fs * 0.35, fs, ink, true)
		var bottom_text := String(sp["text2"]) if String(sp["text2"]) != "" else String(sp["year"])
		if bottom_text != "":
			_arc_text(bottom_text, cc, rr - fs * 0.35, fs * 0.9, ink, false)
		if String(sp["ring_deco"]) == "roses":
			# Rosas vermelhas e bolas de futebol na parte de baixo do anel
			for k in 5:
				var a := PI * 0.5 + (k - 2) * 0.32
				var pc := cc + Vector2(cos(a), sin(a)) * (rr - fs * 0.35)
				if k % 2 == 0:
					for j in 5:
						var aa := TAU * j / 5.0
						_circle(pc + Vector2(cos(aa), sin(aa)) * fs * 0.22, fs * 0.2, Color("#D0202E"))
					_circle(pc, fs * 0.14, Color("#F2C14E"))
				else:
					_circle(pc, fs * 0.34, Color.WHITE)
					_circle(pc, fs * 0.12, Color("#15171B"))
		elif String(sp["text"]) != "" and bottom_text != "":
			# Pontinhos separando os textos
			for sx: float in [-1.0, 1.0]:
				var a := PI * (0.5 - 0.42 * sx) + PI
				_circle(cc + Vector2(cos(a), sin(a)) * (rr - fs * 0.3), fs * 0.12, ink)
	# Numeral da divisão num selo no canto (Série B, 2. Bundesliga)
	if String(sp["num"]) != "":
		var nc := box.position + box.size * (Vector2(0.8, 0.2) if shape != "badge" else Vector2(0.8, 0.24))
		var nr := box.size.x * (0.17 if not small else 0.2)
		var nbg: Color = sp["accent"] if sp["accent"] != null else c2
		_circle(nc, nr + maxf(1.0, s * 0.02), c1 if absf(c1.get_luminance() - nbg.get_luminance()) > 0.2 else Color("#15171B"))
		_circle(nc, nr, nbg)
		_text_center(String(sp["num"]), nc + Vector2(0, nr * 0.04), nr * 1.5, nr * 1.45, contrast(nbg, c1, Color("#15171B")))
	# Louros por baixo da faixa (a faixa fica legível por cima das folhas)
	if bool(sp["laurel"]):
		_laurel(box, c3, s)
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
		var sc: Color = sp["star_c"]
		for i in n:
			var x := s * 0.5 + (i - (n - 1) * 0.5) * r * 2.3
			var dy := -absf(i - (n - 1) * 0.5) * r * 0.25 * -1.0
			_poly(_star(Vector2(x, sy + dy), r, r * 0.42, 5), sc)
	if bool(sp["flames"]) and not small:
		# Chamas eternas dos dois lados do escudo
		for sx: float in [-1.0, 1.0]:
			var base := Vector2(box.get_center().x + sx * box.size.x * 0.56, box.position.y + box.size.y * 0.78)
			var fh := box.size.y * 0.38
			var fw := box.size.x * 0.1
			_poly(PackedVector2Array([base + Vector2(-fw, 0), base + Vector2(-fw * 0.8, -fh * 0.45), base + Vector2(-fw * 0.2, -fh * 0.7), base + Vector2(0, -fh), base + Vector2(fw * 0.35, -fh * 0.62), base + Vector2(fw * 0.9, -fh * 0.4), base + Vector2(fw, 0)]), Color("#E0301E"))
			_poly(PackedVector2Array([base + Vector2(-fw * 0.55, 0), base + Vector2(-fw * 0.3, -fh * 0.45), base + Vector2(0, -fh * 0.62), base + Vector2(fw * 0.3, -fh * 0.4), base + Vector2(fw * 0.55, 0)]), Color("#F9A12E"))
			_poly(PackedVector2Array([base + Vector2(-fw * 1.2, 0), base + Vector2(fw * 1.2, 0), base + Vector2(fw * 0.8, fh * 0.12), base + Vector2(-fw * 0.8, fh * 0.12)]), c3)
	if String(sp["ribbon_top"]) != "" and not small:
		var rt_h := s * 0.1
		var rt := Rect2(Vector2(s * 0.14, y_cursor - rt_h - s * 0.015), Vector2(s * 0.72, rt_h))
		if String(sp["top_style"]) == "gates":
			# Portão em arco (grade vertical) atrás da faixa
			var gc := Color("#1F8A7A")
			var arc_c := Vector2(s * 0.5, rt.end.y)
			var ar := s * 0.3
			var pts := PackedVector2Array()
			for i in 17:
				var a := PI + PI * i / 16.0
				pts.append(arc_c + Vector2(cos(a) * ar, sin(a) * ar * 0.6))
			_polyline(pts, gc, maxf(1.5, s * 0.02))
			for i in 9:
				var x := arc_c.x - ar + ar * 2.0 * (i + 0.5) / 9.0
				var dy := sqrt(maxf(0.0, 1.0 - pow((x - arc_c.x) / ar, 2.0))) * ar * 0.6
				_polyline(PackedVector2Array([Vector2(x, arc_c.y), Vector2(x, arc_c.y - dy)]), gc, maxf(1.0, s * 0.01))
			rt = Rect2(Vector2(s * 0.12, arc_c.y - ar * 0.6 - rt_h * 0.4), Vector2(s * 0.76, rt_h))
			_ribbon(String(sp["ribbon_top"]), rt, gc, Color.WHITE)
		else:
			_ribbon(String(sp["ribbon_top"]), rt, c3, c1)


## Área do desenho num logo de competição: maior que no escudo, sobe quando há nome embaixo,
## desce quando há faixa da bandeira ou símbolo pequeno em cima.
static func _logo_box(box: Rect2, shape: String, has_flag: bool, has_top: bool, has_word: bool) -> Rect2:
	var cy := 0.5 if shape != "badge" else 0.44
	var sz := 0.62 if shape != "badge" else 0.54
	if shape in ["square", "tile"]:
		sz = 0.66
	if has_flag:
		cy += 0.05
		sz *= 0.9
	if has_top:
		cy += 0.1
		sz *= 0.82
	if has_word:
		cy -= 0.1
		sz *= 0.8
	return Rect2(box.position + box.size * Vector2(0.5 - sz * 0.5, cy - sz * 0.5), box.size * sz)


## Área útil para o símbolo dentro de cada formato (evita a ponta e o anel).
static func _inner_box(box: Rect2, shape: String) -> Rect2:
	var m := Rect2(0.2, 0.18, 0.6, 0.6)
	match shape:
		"ring", "oval_ring":
			m = Rect2(0.3, 0.3, 0.4, 0.4)
		"round", "oval", "octagon", "hexagon", "square", "disc", "tile":
			m = Rect2(0.2, 0.2, 0.6, 0.6)
		"badge":
			m = Rect2(0.22, 0.16, 0.56, 0.56)
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
			# hoops:2 = uma faixa só atravessando o meio (Boca, Olimpia, Platense)
			n = maxi(n, 2)
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
		"pale_cross":
			# Metade listrada (c1/fc) e metade branca (c2) com cruz (c3)
			var cross_left := f.get_slice(":", 1) == "L"
			var x0 := 0.0 if cross_left else 0.5
			var sx := 0.5 if cross_left else 0.0
			parts.append([_rect(x0 - (0.1 if cross_left else 0.0), -0.1, 0.6, 1.2), sp["c2"]])
			parts.append([_rect(x0 + 0.2, -0.1, 0.1, 1.2), c3])
			parts.append([_rect(x0 - (0.1 if cross_left else 0.0), 0.36, 0.6, 0.1), c3])
			for i in 2:
				parts.append([_rect(sx + 0.125 + i * 0.25, -0.1, 0.125, 1.2), c2])
		"bends":
			# Faixas diagonais (Athletico): n faixas da segunda cor
			n = maxi(n, 3)
			var bw := 1.0 / (n * 2)
			for i in n:
				var o := -0.5 + i * bw * 2.0 + bw
				parts.append([PackedVector2Array([Vector2(o, 1.1), Vector2(o + bw, 1.1), Vector2(o + bw + 1.2, -0.1), Vector2(o + 1.2, -0.1)]), c2])
		"barca":
			# Blaugrana embaixo; em cima a cruz de São Jorge e as barras catalãs; faixa FCB no meio
			var gold := Color("#E4B43A")
			for i in 7:
				if i % 2 == 1:
					parts.append([_rect(i / 7.0, 0.47, 1.0 / 7.0 + 0.001, 0.6), c2])
			parts.append([_rect(-0.1, -0.1, 0.6, 0.43), Color("#F7F4EC")])
			parts.append([_rect(0.215, -0.1, 0.07, 0.43), Color("#D21F26")])
			parts.append([_rect(-0.1, 0.11, 0.6, 0.07), Color("#D21F26")])
			parts.append([_rect(0.5, -0.1, 0.6, 0.43), Color("#FCD116")])
			for i in 4:
				parts.append([_rect(0.5 + (1 + i * 2) * 0.5 / 9.0, -0.1, 0.5 / 9.0, 0.43), Color("#D21F26")])
			parts.append([_rect(-0.1, 0.33, 1.2, 0.14), Color("#F4EEDC")])
			# Frisos dourados entre as partes, como o esmalte do escudo
			parts.append([_rect(-0.1, 0.322, 1.2, 0.016), gold])
			parts.append([_rect(-0.1, 0.462, 1.2, 0.016), gold])
			parts.append([_rect(0.492, -0.1, 0.016, 0.43), gold])
		"bordure":
			pass
	for part: Array in parts:
		for piece in Geometry2D.intersect_polygons(_xf(part[0], box), poly):
			_poly(piece, part[1])
	if kind == "barca" and s >= 36.0:
		_text_center(String(sp["text"]) if String(sp["text"]) != "" else "FCB", box.position + box.size * Vector2(0.5, 0.405), box.size.x * 0.46, box.size.y * 0.115, Color("#1A1A1A"))
	if kind == "bordure":
		var inner := Geometry2D.offset_polygon(poly, -box.size.x * 0.07)
		for piece in inner:
			_polyline_closed(piece, c2, maxf(1.0, box.size.x * 0.08))


func _charge(sp: Dictionary, cb: Rect2, field_poly: PackedVector2Array, s: float, box: Rect2 = Rect2()) -> void:
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
		var ink_out := Color("#15171B") if col.get_luminance() > 0.5 else Color.WHITE
		var sub := String(sp["sub"])
		if sub != "":
			cen.y -= r * 0.2
		if bool(sp["mono"]) and txt.length() >= 2:
			# Monograma: letras grandes entrelaçadas, cada uma um pouco deslocada, contorno na cor do fundo
			var n := txt.length()
			var fsm := r * (1.5 if n <= 3 else 1.2)
			var step := fsm * 0.36
			for i in n:
				var dx := (i - (n - 1) * 0.5) * step
				var dy := (r * 0.14) * (1.0 if i % 2 == 1 else -1.0) if n >= 3 else 0.0
				_text_center(txt[i], cen + Vector2(dx, r * 0.05 + dy), cb.size.x, fsm, col, true, c1)
		else:
			var max_w := cb.size.x * 1.05
			var plate := plate_mode(sp)
			if plate != "":
				# Letras na placa: cor que contrasta com ela, sem contorno
				var pcol := plate_color(sp)
				col = contrast(pcol, plate_line(sp), c3)
				if sp["sc"] != null and absf((sp["sc"] as Color).get_luminance() - pcol.get_luminance()) > 0.28:
					col = sp["sc"]
				if plate == "band":
					fs = minf(fs, cb.size.y * 0.5 * 0.8)
				else:
					max_w = r * 1.7
				outline = false
			elif (field == "hoops:2" or field == "tricolor_h") and String(sp["chief_text"]) == "" and String(sp["sym_pos"]) == "" and box.size.x > 0.0:
				# Letras em cima da faixa do meio, do tamanho dela
				cen.y = box.position.y + box.size.y * 0.5
				fs = minf(fs, box.size.y * 0.333 * 0.72)
				var band_c: Color = c2
				if absf(col.get_luminance() - band_c.get_luminance()) < 0.28:
					col = contrast(band_c, c1, c3)
				outline = false
			ink_out = Color("#15171B") if col.get_luminance() > 0.5 else Color.WHITE
			_text_center(txt, cen + Vector2(0, r * 0.05), max_w, fs, col, outline, ink_out, s >= 36.0 and col.get_luminance() > 0.5 and not bool(sp["logo"]))
		if sub != "":
			_text_center(sub, cen + Vector2(0, r * 0.95), cb.size.x * 0.6, fs * 0.55, col)
		return
	if sym.begins_with("stars:"):
		var n := clampi(int(sym.get_slice(":", 1)), 1, 5)
		var sr := r * (0.5 if n <= 2 else 0.36)
		for i in n:
			var x := cen.x + (i - (n - 1) * 0.5) * sr * 2.2
			_poly(_star(Vector2(x, cen.y), sr, sr * 0.42, 5), col)
		return
	if sym == "starball":
		# Bola feita de estrelas: uma no centro e um anel de sete em volta
		_poly(_star(cen, r * 0.34, r * 0.14, 5), col)
		for k in 7:
			var a := -PI * 0.5 + TAU * (k + 0.5) / 7.0
			_poly(_star(cen + Vector2(cos(a), sin(a)) * r * 0.66, r * 0.25, r * 0.1, 5), col)
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
	# Bola antiga de couro, com os gomos costurados (Barça)
	if sym == "ball_old":
		var bc := cen
		var br := r * 0.62
		_circle(bc + Vector2(br * 0.06, br * 0.08), br, Color(0, 0, 0, 0.3))
		_circle(bc, br, Color("#7A4A12"))
		_circle(bc, br * 0.92, Color("#E9A93B"))
		_circle(bc + Vector2(-br * 0.28, -br * 0.3), br * 0.35, Color(1, 0.9, 0.6, 0.35))
		var seam := Color("#6B3F0E")
		var lw := maxf(1.0, br * 0.07)
		_polyline(PackedVector2Array([bc + Vector2(-br * 0.88, -br * 0.2), bc + Vector2(-br * 0.3, -br * 0.05), bc + Vector2(br * 0.3, -br * 0.05), bc + Vector2(br * 0.88, -br * 0.2)]), seam, lw)
		_polyline(PackedVector2Array([bc + Vector2(-br * 0.7, br * 0.55), bc + Vector2(-br * 0.2, br * 0.35), bc + Vector2(br * 0.2, br * 0.35), bc + Vector2(br * 0.7, br * 0.55)]), seam, lw)
		_polyline(PackedVector2Array([bc + Vector2(0, -br * 0.9), bc + Vector2(-br * 0.08, -br * 0.05), bc + Vector2(0, br * 0.35), bc + Vector2(br * 0.05, br * 0.9)]), seam, lw)
		return
	# Galo em cima da bola (Tottenham)
	if sym == "rooster_ball":
		var rc := cen + Vector2(0, -r * 0.18)
		for p: PackedVector2Array in CrestArt.polys("rooster"):
			_poly(_xf_c(p, rc, r * 0.8), col)
		var bc := cen + Vector2(r * 0.02, r * 0.72)
		_circle(bc, r * 0.26, col)
		_circle(bc, r * 0.2, c1)
		_circle(bc, r * 0.07, col)
		for k in 5:
			var a := TAU * k / 5.0 - PI * 0.5
			_polyline(PackedVector2Array([bc + Vector2(cos(a), sin(a)) * r * 0.07, bc + Vector2(cos(a), sin(a)) * r * 0.2]), col, maxf(1.0, r * 0.03))
		return
	var det := sym + "_d"
	if bool(sp["line_art"]) and CrestArt.has(sym):
		# Desenho só em traços: contorno e detalhes na cor do símbolo
		var lw := maxf(1.2, r * 0.075)
		for p: PackedVector2Array in CrestArt.polys(sym):
			_polyline_closed(_xf_c(p, cen, r), col, lw)
		if CrestArt.has(det) and s >= 28.0:
			for p: PackedVector2Array in CrestArt.polys(det):
				_poly(_xf_c(p, cen, r), col)
		return
	if sym == "tiger":
		sym = "cat"
		det = "tiger_d"
	if not CrestArt.has(sym):
		sym = "star"
		det = "star_d"
	if bool(sp["staff"]):
		# Cajado com ponteira, na diagonal, atrás do leão
		var a0 := cen + Vector2(r * 0.78, -r * 0.95)
		var a1 := cen + Vector2(-r * 0.45, r * 0.95)
		_polyline(PackedVector2Array([a0, a1]), col, maxf(1.2, r * 0.08))
		_poly(_xf_c(PackedVector2Array([Vector2(0, -1), Vector2(0.5, 0), Vector2(0, 1), Vector2(-0.5, 0)]), a0, r * 0.14), col)
	var polys: Array = CrestArt.polys(sym)
	var shade := col.darkened(0.45) if col.get_luminance() > 0.35 else col.lightened(0.35)
	# Contorno fino para destacar sobre campo dividido
	if outline and s >= 36.0:
		for p: PackedVector2Array in polys:
			var pts := _xf_c(p, cen, r)
			_polyline_closed(pts, c1.darkened(0.3) if c1.get_luminance() < 0.6 else Color(0, 0, 0, 0.6), maxf(1.0, r * 0.07))
	for p: PackedVector2Array in polys:
		_poly(_xf_c(p, cen, r), col)
	# Recortes ("_c"): partes vazadas, na cor do fundo (costuras da bola dos logos)
	if CrestArt.has(sym + "_c") and s >= 20.0:
		for p: PackedVector2Array in CrestArt.polys(sym + "_c"):
			_poly(_xf_c(p, cen, r), c1)
	# Recortes do liver bird usam o campo; em ícones pequenos vale a silhueta limpa.
	var detail_min := 48.0 if sym == "liverbird" else 28.0
	if sym == "liverbird":
		shade = c1
	var metal := sym.begins_with("trophy")
	if metal:
		# Taça: sombra metálica mais suave e um reflexo claro
		shade = col.darkened(0.28) if col.get_luminance() > 0.35 else col.lightened(0.3)
	if CrestArt.has(det) and s >= detail_min:
		for p: PackedVector2Array in CrestArt.polys(det):
			_poly(_xf_c(p, cen, r), shade if sym != "ball" else Color("#15171B"))
	if CrestArt.has(sym + "_h") and s >= 28.0:
		for p: PackedVector2Array in CrestArt.polys(sym + "_h"):
			_poly(_xf_c(p, cen, r), Color(col.lightened(0.6), 0.85))


## Placa do monograma: "band" (faixa atravessada) ou "disc" (disco central). "" = sem placa.
static func plate_mode(sp: Dictionary) -> String:
	var sym := String(sp["symbol"])
	if sym != "letter" and sym != "letters":
		return ""
	var p := String(sp.get("plate", "auto"))
	if p == "none":
		return ""
	if p == "band" or p == "disc":
		return p
	var field := String(sp["field"])
	# Uma faixa só no meio (hoops:2, tricolor_h) já faz o papel de placa; monograma entrelaçado e
	# letras fora do centro também não ganham placa
	if String(sp["chief_text"]) != "" or field == "hoops:2" or field == "tricolor_h" or not field.get_slice(":", 0) in BUSY_FIELDS:
		return ""
	if bool(sp["mono"]) or String(sp["sym_pos"]) != "" or bool(sp["logo"]):
		return ""
	# No anel o disco de dentro já é pequeno: letras com contorno, sem placa
	if String(sp["shape"]) in ["ring", "oval_ring"]:
		return ""
	return "disc" if String(sp["shape"]) in ROUNDISH else "band"


## Cor da placa: a pedida ou a mais escura entre o fundo e o desenho do campo.
static func plate_color(sp: Dictionary) -> Color:
	if sp.get("pc") != null:
		return sp["pc"]
	var c1: Color = sp["c1"]
	var fc: Color = sp["fc"]
	return c1 if c1.get_luminance() <= fc.get_luminance() + 0.05 else fc


## Cor dos filetes da placa: a outra cor do campo, ou o dourado se as duas forem parecidas.
static func plate_line(sp: Dictionary) -> Color:
	var pcol := plate_color(sp)
	var c1: Color = sp["c1"]
	var fc: Color = sp["fc"]
	var other := fc if pcol == c1 else c1
	if absf(other.get_luminance() - pcol.get_luminance()) < 0.25:
		other = sp["c3"]
	if absf(other.get_luminance() - pcol.get_luminance()) < 0.25:
		other = Color.WHITE if pcol.get_luminance() < 0.5 else Color("#15171B")
	return other


func _plate(kind: String, sp: Dictionary, cb: Rect2, box: Rect2, inner: PackedVector2Array, s: float) -> void:
	var pcol := plate_color(sp)
	var line := plate_line(sp)
	var cen := cb.get_center() + Vector2(0, minf(cb.size.x, cb.size.y) * 0.025)
	var t := maxf(1.0, s * 0.018)
	if kind == "disc":
		var r := minf(cb.size.x, cb.size.y) * 0.56
		_poly(_ngon(cen, r + t * 1.6, 48, 0.0), line)
		_poly(_ngon(cen, r, 48, 0.0), pcol)
		return
	var h := cb.size.y * 0.5
	var band := _xf(_rect(-0.1, 0, 1.2, 1), Rect2(Vector2(box.position.x, cen.y - h * 0.5), Vector2(box.size.x, h)))
	var outer := _xf(_rect(-0.1, 0, 1.2, 1), Rect2(Vector2(box.position.x, cen.y - h * 0.5 - t * 1.6), Vector2(box.size.x, h + t * 3.2)))
	for piece in Geometry2D.intersect_polygons(outer, inner):
		_poly(piece, line)
	for piece in Geometry2D.intersect_polygons(band, inner):
		_poly(piece, pcol)


## Cantão: quadrado no alto à esquerda com um símbolo pequeno (Atlético de Madrid).
func _canton(sp: Dictionary, box: Rect2, inner: PackedVector2Array, s: float) -> void:
	var col: Color = sp["canton"]
	for piece in Geometry2D.intersect_polygons(_xf(_rect(-0.1, -0.1, 0.6, 0.56), box), inner):
		_poly(piece, col)
	var sym := String(sp["canton_sym"])
	if sym == "" or not CrestArt.has(sym) or s < 28.0:
		return
	var cen := box.position + Vector2(0.3, 0.26) * box.size
	var ink := contrast(col, Color.WHITE, sp["c3"])
	for p: PackedVector2Array in CrestArt.polys(sym):
		_poly(_xf_c(p, cen, box.size.x * 0.15), ink)


## Filete fino por dentro da borda, como nos escudos bordados/esmaltados.
func _rim(inner: PackedVector2Array, sp: Dictionary, s: float) -> void:
	var c1: Color = sp["c1"]
	var c2: Color = sp["c2"]
	var col := c2 if absf(c2.get_luminance() - c1.get_luminance()) > 0.15 else c1.lightened(0.35)
	col.a = 0.7
	for piece in Geometry2D.offset_polygon(inner, -s * 0.052):
		_polyline_closed(piece, col, maxf(1.0, s * 0.011))


static func _outer_edge(sp: Dictionary) -> Color:
	var c1: Color = sp["c1"]
	var c2: Color = sp["c2"]
	var d := c1 if c1.get_luminance() < c2.get_luminance() else c2
	return d.darkened(0.55)


func _border(poly: PackedVector2Array, inner: PackedVector2Array, ring: bool, sp: Dictionary, s: float) -> void:
	var b := String(sp["border"])
	var c2: Color = sp["c2"]
	var c3: Color = sp["c3"]
	var c1: Color = sp["c1"]
	var edge := c2 if absf(c2.get_luminance() - c1.get_luminance()) > 0.15 else c1.lightened(0.3)
	var logo := bool(sp["logo"])
	# Contorno escuro por fora: recorta o escudo de qualquer fundo (tema claro ou escuro)
	if b != "none" and s >= 20.0 and not logo:
		var lw := {"thick": 0.06, "gold": 0.045, "double": 0.03}.get(b, 0.03) as float
		_polyline_closed(poly, _outer_edge(sp), maxf(1.5, s * lw) + maxf(1.0, s * 0.012))
	if logo:
		# Logo: aro fino de destaque, ou um fio escuro discreto que separa do fundo
		if sp["ring_c"] != null:
			_polyline_closed(poly, sp["ring_c"], maxf(1.2, s * 0.032))
		elif b == "none":
			_polyline_closed(poly, Color(0, 0, 0, 0.3), maxf(0.8, s * 0.01))
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
		"round", "ring", "disc":
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
		"square", "tile":
			# Quadrado de cantos redondos ("tile" ocupa o quadro todo, como ícone de liga)
			var r := 0.14 if shape == "square" else 0.2
			var e := 0.1 if shape == "square" else 0.04
			for corner in [Vector2(1.0 - e - r, e + r), Vector2(1.0 - e - r, 1.0 - e - r), Vector2(e + r, 1.0 - e - r), Vector2(e + r, e + r)]:
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
		"barca":
			# Ânfora: pontas do alto abertas para fora, topo côncavo, cintura na faixa FCB e fundo bojudo em ponta
			for i in 13:
				pts.append(_bezier(Vector2(0.02, 0.0), Vector2(0.5, 0.16), Vector2(0.98, 0.0), i / 12.0))
			for i in range(1, 9):
				pts.append(_bezier(Vector2(0.98, 0.0), Vector2(0.86, 0.2), Vector2(0.87, 0.42), i / 8.0))
			for i in range(1, 14):
				pts.append(_bezier(Vector2(0.87, 0.42), Vector2(0.97, 0.78), Vector2(0.5, 0.99), i / 13.0))
			for i in range(1, 14):
				pts.append(_bezier(Vector2(0.5, 0.99), Vector2(0.03, 0.78), Vector2(0.13, 0.42), i / 13.0))
			for i in range(1, 8):
				pts.append(_bezier(Vector2(0.13, 0.42), Vector2(0.14, 0.2), Vector2(0.02, 0.0), i / 8.0))
		"badge":
			# Escudo moderno de competição: cantos de cima arredondados, laterais retas e ponta suave
			var rr := 0.12
			for k in 7:
				var a := PI + (PI / 2) * k / 6.0
				pts.append(Vector2(0.1 + rr, 0.04 + rr) + Vector2(cos(a), sin(a)) * rr)
			for k in 7:
				var a := -PI / 2 + (PI / 2) * k / 6.0
				pts.append(Vector2(0.9 - rr, 0.04 + rr) + Vector2(cos(a), sin(a)) * rr)
			pts.append(Vector2(0.9, 0.56))
			for i in range(1, 13):
				pts.append(_bezier(Vector2(0.9, 0.56), Vector2(0.9, 0.8), Vector2(0.5, 0.98), float(i) / 12.0))
			for i in range(1, 12):
				pts.append(_bezier(Vector2(0.5, 0.98), Vector2(0.1, 0.8), Vector2(0.1, 0.56), float(i) / 12.0))
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


func _text_center(txt: String, center: Vector2, max_w: float, size_px: float, col: Color, outline: bool = false, out_col: Color = Color.BLACK, shadow: bool = false) -> void:
	var font := _font()
	var fs := maxi(4, int(size_px))
	var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	while tw > max_w and fs > 5:
		fs -= 1
		tw = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if fs < 5:
		return
	var pos := center + Vector2(-tw * 0.5, fs * 0.36)
	if shadow:
		_string(font, pos + Vector2(fs * 0.03, fs * 0.07), txt, fs, Color(0, 0, 0, 0.2))
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


## Polígono com degradê vertical (cor de cima para a de baixo, por vértice).
func _poly_grad(pts: PackedVector2Array, top: Color, bot: Color) -> void:
	if pts.size() < 3 or Geometry2D.triangulate_polygon(pts).is_empty():
		return
	var y0 := INF
	var y1 := -INF
	for p in pts:
		y0 = minf(y0, p.y)
		y1 = maxf(y1, p.y)
	var cols := PackedColorArray()
	for p in pts:
		cols.append(top.lerp(bot, clampf((p.y - y0) / maxf(1.0, y1 - y0), 0.0, 1.0)))
	_rec.append([6, pts, cols])


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
			6:
				draw_polygon(c[1], c[2])
			5:
				var p: Vector2 = c[2]
				draw_set_transform(off + p, c[3], Vector2.ONE)
				draw_string(c[1], Vector2(-float(c[7]) * 0.5, float(c[5]) * 0.36), c[4], HORIZONTAL_ALIGNMENT_LEFT, -1, c[5], c[6])
				draw_set_transform(off, 0.0, Vector2.ONE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
