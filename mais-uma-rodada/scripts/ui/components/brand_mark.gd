class_name BrandMark
extends RefCounted
## Símbolos das marcas do mundo do jogo (BrandCatalog): patrocinadores, fornecedoras de material
## esportivo e anunciantes. Cada marca tem o seu, sempre o mesmo (semente do nome), desenhado com
## regras de logo de verdade:
##   - monograma: a inicial da marca vazada num selo (círculo, quadrado arredondado, hexágono,
##     escudo, losango, octógono), cheia dentro de um anel, ou cortada em estêncil;
##   - pictograma do setor ("m" da marca: espiga, sol, escudo, anel, colunas, folha, seta, sinal,
##     raio, onda, telhado, coroa, gota, chama, asa, estrela, diamante...), cada um com três
##     desenhos, e montado cheio, vazado num selo, dentro de um anel ou em duas cores;
##   - marca geométrica com simetria de rotação (lâminas, pétalas, diafragma, órbitas, pontos).
## As fornecedoras têm desenho próprio, feito à mão (SUPPLIERS).
## Tudo em cache como camadas [forma (LogoGeom), tom (0 cor principal, 1 cor de destaque)] no
## quadrado de -1 a 1; desenhar só transforma os pontos.

const KEYS := ["curva", "barras", "triangulo", "raio", "asas", "asa", "diamante", "trevo", "estrela", "chevron", "alvo",
	"escudo", "colunas", "anel", "hexagono", "seta", "coroa", "espiga", "gota", "onda", "sinal", "sol", "chama", "guarda",
	"sacola", "pixel", "telhado", "folha", "cruz", "livro", "play", "montanha", "circulo"]

## Palavras genéricas que não viram inicial do monograma (o nome próprio da marca vem depois delas).
const GENERIC := ["banco", "bank", "banca", "banque", "seguros", "seguradora", "assurances", "assicurazioni", "insurance",
	"versicherung", "supermercados", "supermercado", "construtora", "construcciones", "constructora", "materiais", "auto",
	"motors", "motor", "garage", "taller", "telecom", "telefonía", "telefonia", "mobile", "energia", "energy", "energía",
	"énergie", "energi", "foods", "alimentos", "cerveja", "cervejaria", "brewery", "cervecería", "airways", "airlines",
	"linhas", "hospital", "faculdade", "university", "universidad", "imobiliária", "inmobiliaria", "rádio", "radio", "taxis",
	"glass", "carpets", "the", "de", "do", "da", "del", "la", "el", "le", "les", "di", "der", "die", "das", "y", "e", "&",
	"frigorífico", "pollería", "pasticceria", "salumificio", "boulangerie", "pekarnia", "elektro", "cooperativa", "grupo",
	"group", "sport", "sports", "deportes", "kit", "trikot"]

static var _cache: Dictionary = {}


static func has(mark: String) -> bool:
	return mark in KEYS


## Compatível com o desenho antigo: só a forma ("m"/"logo"), na construção básica.
static func draw(ci: CanvasItem, mark: String, c: Vector2, u: float, col: Color, _bg: Color = Color(0, 0, 0, 0)) -> bool:
	if not has(mark):
		return false
	return draw_brand(ci, {"n": "§" + mark, "m": mark}, c, u, col)


## Símbolo da marca centrado em `c`, cabendo num quadrado de lado 2u. `col2` pinta as partes de
## destaque (vazio = a mesma cor).
static func draw_brand(ci: CanvasItem, brand: Dictionary, c: Vector2, u: float, col: Color, col2: Color = Color(0, 0, 0, 0)) -> bool:
	var lay := layers(brand)
	if lay.is_empty():
		return false
	var key := _key(brand)
	for i in lay.size():
		var l: Array = lay[i]
		var cc := col if int(l[1]) == 0 or col2.a <= 0.0 else col2
		LogoGeom.draw(ci, l[0], c, u, cc, "%s|%d" % [key, i])
	return true


static func _key(brand: Dictionary) -> String:
	return "%s|%s" % [String(brand.get("n", "")), _mark_of(brand)]


static func _mark_of(brand: Dictionary) -> String:
	var m := String(brand.get("m", ""))
	if m == "":
		m = String(brand.get("logo", ""))
	return m


static func layers(brand: Dictionary) -> Array:
	var key := _key(brand)
	if _cache.has(key):
		return _cache[key]
	var name := String(brand.get("n", ""))
	var lay: Array
	if SUPPLIERS.has(name):
		lay = _supplier(name)
	else:
		var sector := String(brand.get("s", ""))
		if sector == "" and not name.begins_with("§"):
			sector = String(BrandCatalog.find(name).get("s", ""))
		lay = _generate(name, _mark_of(brand), sector)
	lay = _fit_layers(lay)
	_cache[key] = lay
	return lay


static func _fit_layers(lay: Array) -> Array:
	var all: Array = []
	for l: Array in lay:
		all.append_array(l[0])
	var b := LogoGeom.bounds_all(all)
	if b.size.x <= 0.0 or b.size.y <= 0.0:
		return lay
	var k := 1.84 / maxf(b.size.x, b.size.y)
	var out: Array = []
	for l: Array in lay:
		out.append([LogoGeom.xf_all(l[0], -b.get_center() * k, 0.0, Vector2(k, k)), l[1]])
	return out


# =================================================================================================
# Gerador
# =================================================================================================

const MONO := {"banco": 0.42, "seguro": 0.38, "montadora": 0.36, "telecom": 0.26, "fintech": 0.34, "aerea": 0.3, "midia": 0.34,
	"logistica": 0.3, "imobiliaria": 0.3, "construcao": 0.26, "educacao": 0.36, "saude": 0.26, "tecnologia": 0.3, "cripto": 0.22,
	"luxo": 0.48, "petroleo": 0.22, "energia": 0.14, "mineracao": 0.28, "varejo": 0.26, "turismo": 0.18}
const ABSTRACT := {"tecnologia": 0.34, "fintech": 0.3, "cripto": 0.42, "telecom": 0.24, "energia": 0.18, "aposta": 0.24,
	"midia": 0.2, "logistica": 0.16, "seguro": 0.1, "banco": 0.12}


static func _generate(name: String, mark: String, sector: String) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%s|%s" % [name, mark, sector])
	var pm: float = MONO.get(sector, 0.16)
	var pa: float = ABSTRACT.get(sector, 0.08)
	if name.begins_with("§"):
		pm = 0.0
		pa = 0.0
	var roll := rng.randf()
	var initials := _initials(name)
	if roll < pm and initials != "":
		return _monogram(rng, initials)
	if roll < pm + pa or not has(mark):
		return _abstract(rng)
	var pic := _pic(mark, rng)
	return _construct(rng, pic, name.begins_with("§"))


static func _ray_circle(p: Vector2, d: Vector2, r: float) -> Vector2:
	# p + t d, |.| = r, t > 0
	var b := p.dot(d)
	var c := p.length_squared() - r * r
	var t := -b + sqrt(maxf(0.0, b * b - c))
	return p + d * t


static func _initials(name: String) -> String:
	var words: Array = []
	for w in name.replace("-", " ").split(" ", false):
		if not (w.to_lower() in GENERIC) and w.length() > 1 and w.left(1) != "{":
			words.append(w)
	if words.is_empty():
		for w in name.split(" ", false):
			words.append(w)
	if words.is_empty():
		return ""
	var a := String(words[0]).left(1).to_upper()
	if a.unicode_at(0) < 65:
		return ""
	return a


## Monta o pictograma: cheio, vazado num selo, dentro de um anel ou em duas cores.
## pic = {"s": sólidos, "h": furos (vazados dentro dos sólidos), "a": sólidos de destaque}
static func _construct(rng: RandomNumberGenerator, pic: Dictionary, basic: bool) -> Array:
	var solids: Array = LogoGeom.merge(pic.get("s", []))
	var holes: Array = pic.get("h", [])
	var acc: Array = LogoGeom.merge(pic.get("a", []))
	var r := rng.randf()
	if basic or r < 0.5:
		var out: Array = [[solids + holes, 0]]
		if not acc.is_empty():
			out.append([acc, 1])
		return out
	if r < 0.72:
		# Vazado num selo: o pictograma recortado de dentro de um círculo, squircle ou hexágono
		var enc := _enclosure(rng)
		var inner: Array = LogoGeom.fit(LogoGeom.merge(solids + acc) + holes, 0.56)
		return [[[enc] + inner, 0]]
	if r < 0.88:
		# Dentro de um anel fino
		var ring := LogoGeom.arc_band(Vector2.ZERO, 0.84, 0.97, 0.0, TAU * 0.5, 40)
		var ring2 := LogoGeom.arc_band(Vector2.ZERO, 0.84, 0.97, TAU * 0.5, TAU, 40)
		var inner2: Array = LogoGeom.fit(solids + holes, 0.58)
		var out2: Array = [[[ring, ring2] + inner2, 0]]
		if not acc.is_empty():
			out2.append([LogoGeom.fit(acc, 0.58), 1])
		return out2
	# Duas cores: a metade de cima no destaque
	var top := PackedVector2Array([Vector2(-2, -2), Vector2(2, -2), Vector2(2, -0.02), Vector2(-2, 0.1)])
	var bot := PackedVector2Array([Vector2(-2, 0.1), Vector2(2, -0.02), Vector2(2, 2), Vector2(-2, 2)])
	var all: Array = LogoGeom.merge(solids + acc)
	var a0 := LogoGeom.intersect(all, bot)
	var a1 := LogoGeom.intersect(all, top)
	return [[a0 + _holes_in(holes, a0), 0], [a1 + _holes_in(holes, a1), 1]]


static func _holes_in(holes: Array, solids: Array) -> Array:
	var out: Array = []
	for h: PackedVector2Array in holes:
		for s: PackedVector2Array in solids:
			if Geometry2D.is_point_in_polygon(h[0], s):
				out.append(h)
				break
	return out


static func _enclosure(rng: RandomNumberGenerator) -> PackedVector2Array:
	match rng.randi() % 6:
		0:
			return LogoGeom.circle(Vector2.ZERO, 0.96, 64)
		1:
			return LogoGeom.squircle(Vector2.ZERO, 0.94, 4.5, 72)
		2:
			return LogoGeom.ngon(Vector2.ZERO, 0.98, 6, -PI / 2.0)
		3:
			return _shield_shape(rng.randi() % 3)
		4:
			return LogoGeom.rrect(Rect2(-0.92, -0.92, 1.84, 1.84), 0.3, 8)
		_:
			return LogoGeom.ngon(Vector2.ZERO, 0.98, 8, PI / 8.0)


# --- Monograma ---------------------------------------------------------------------------------

static func _monogram(rng: RandomNumberGenerator, initials: String) -> Array:
	var weight := rng.randf_range(640.0, 900.0)
	var width := rng.randf_range(62.0, 112.0)
	var slant := 0.16 if rng.randf() < 0.18 else 0.0
	var ts := LogoGeom.text_shape(initials, weight, width, 0.0, slant)
	var letter: Array = ts[0]
	if letter.is_empty():
		return _abstract(rng)
	var style := rng.randi() % 4
	match style:
		0, 1:
			# Inicial vazada no selo
			var enc := _enclosure(rng)
			var inner := LogoGeom.fit(letter, 0.5 if style == 0 else 0.56)
			return [[[enc] + inner, 0]]
		2:
			# Inicial cheia dentro de um anel (anel em duas metades: sem furo)
			var th := rng.randf_range(0.09, 0.14)
			var ring := LogoGeom.arc_band(Vector2.ZERO, 0.97 - th, 0.97, -PI / 2.0, PI / 2.0, 40)
			var ring2 := LogoGeom.arc_band(Vector2.ZERO, 0.97 - th, 0.97, PI / 2.0, PI * 1.5, 40)
			return [[[ring, ring2] + LogoGeom.fit(letter, 0.52), 0]]
	# Estêncil: a inicial grande cortada por uma fenda diagonal, com um ponto de destaque
	var big := LogoGeom.fit(letter, 0.9)
	var a := rng.randf_range(-0.9, -0.5)
	var slit := LogoGeom.stroke(PackedVector2Array([Vector2(-1.5, 0.0).rotated(a), Vector2(1.5, 0.0).rotated(a)]), 0.11)
	var pieces := _cut_letter(big, slit)
	var dot := LogoGeom.circle(Vector2(0.86, 0.78), 0.13, 24)
	return [[pieces, 0], [[dot], 1]]


## Corta a letra (externos e contra-formas) por uma fenda: cada externo é recortado e as
## contra-formas continuam como furos onde caem dentro de um pedaço.
static func _cut_letter(letter: Array, slit: PackedVector2Array) -> Array:
	var outers: Array = []
	var counters: Array = []
	for p: PackedVector2Array in letter:
		var inside := false
		for q: PackedVector2Array in letter:
			if q != p and Geometry2D.is_point_in_polygon(p[0], q):
				inside = true
				break
		if inside:
			counters.append(p)
		else:
			outers.append(p)
	var pieces := LogoGeom.cut(outers, [slit])
	var out: Array = pieces.duplicate()
	for h: PackedVector2Array in counters:
		var hh := LogoGeom.cut([h], [slit])
		for piece: PackedVector2Array in hh:
			for s: PackedVector2Array in pieces:
				if Geometry2D.is_point_in_polygon(piece[0], s):
					out.append(piece)
					break
	return out


# --- Marcas geométricas ------------------------------------------------------------------------

static func _abstract(rng: RandomNumberGenerator) -> Array:
	var kind := rng.randi() % 7
	var n: int = [3, 4, 5, 6, 8][rng.randi() % 5]
	match kind:
		0:
			# Lâminas: faixas de anel giradas (hélice)
			var span := rng.randf_range(0.55, 0.9) * TAU / n
			var r0 := rng.randf_range(0.18, 0.36)
			var blade := LogoGeom.arc_band(Vector2.ZERO, r0, 0.95, 0.0, span, 18)
			var bl := LogoGeom.rotate_copies([blade], n, rng.randf() * TAU)
			return [[bl, 0]]
		1:
			# Pétalas a partir do centro
			var w := rng.randf_range(0.14, 0.24)
			var off := rng.randf_range(0.06, 0.16)
			var pet := LogoGeom.lens(Vector2(0, -off), Vector2(0, -0.95), w, rng.randf_range(-0.6, 0.6), 12)
			var ps := LogoGeom.rotate_copies([pet], n, 0.0)
			var out: Array = [[ps, 0]]
			if rng.randf() < 0.5:
				out.append([[LogoGeom.circle(Vector2.ZERO, off * 0.8 + 0.04, 24)], 1])
			return out
		2:
			# Diafragma de câmera: lâminas que se encaixam em volta de um furo poligonal
			var ri := rng.randf_range(0.26, 0.38)
			var ro := 0.97
			var rot := rng.randf() * TAU
			var nb := maxi(5, n)
			var blades: Array = []
			for k in nb:
				var a0 := rot + TAU * k / nb
				var a1 := a0 + TAU / nb
				var p0 := Vector2(cos(a0), sin(a0)) * ri
				var p1 := Vector2(cos(a1), sin(a1)) * ri
				var d0 := (p1 - p0).normalized()
				var q0 := _ray_circle(p0, -d0, ro)
				var p2 := Vector2(cos(a1 + TAU / nb), sin(a1 + TAU / nb)) * ri
				var d1 := (p2 - p1).normalized()
				var q1 := _ray_circle(p1, -d1, ro)
				var blade := PackedVector2Array([p0, q0])
				var aq0 := atan2(q0.y, q0.x)
				var aq1 := atan2(q1.y, q1.x)
				while aq1 < aq0:
					aq1 += TAU
				for i in range(1, 9):
					var a := lerpf(aq0, aq1, i / 9.0)
					blade.append(Vector2(cos(a), sin(a)) * ro)
				blade.append(q1)
				blade.append(p1)
				var sh := Geometry2D.offset_polygon(blade, -0.03)
				if not sh.is_empty():
					blades.append(sh[0])
			return [[blades, 0]]
		3:
			# Pontos em grade com tamanhos em degradê
			var dots: Array = []
			var g := 3 if rng.randf() < 0.6 else 4
			for iy in g:
				for ix in g:
					var t := float(ix + iy) / (2.0 * (g - 1))
					var rr := lerpf(0.26, 0.1, t) * (3.0 / g)
					dots.append(LogoGeom.circle(Vector2(-0.7 + 1.4 * ix / (g - 1), -0.7 + 1.4 * iy / (g - 1)), rr, 20))
			return [[dots, 0]]
		4:
			# Círculo dividido por uma curva em S (dois tons)
			var cut_line := LogoGeom.cubic(Vector2(-1.2, 0.35), Vector2(-0.3, -0.6), Vector2(0.3, 0.6), Vector2(1.2, -0.35), 24)
			var upper := PackedVector2Array(cut_line)
			upper.append(Vector2(1.2, -1.2))
			upper.append(Vector2(-1.2, -1.2))
			var lower := PackedVector2Array(cut_line)
			lower.append(Vector2(1.2, 1.2))
			lower.append(Vector2(-1.2, 1.2))
			var circ := LogoGeom.circle(Vector2.ZERO, 0.96, 64)
			var gap := LogoGeom.stroke(cut_line, 0.08)
			var u0 := LogoGeom.cut(LogoGeom.intersect([circ], upper), [gap])
			var l0 := LogoGeom.cut(LogoGeom.intersect([circ], lower), [gap])
			return [[l0, 0], [u0, 1]]
		5:
			# Três barras arredondadas em degraus
			var bars: Array = []
			for i in 3:
				var x0 := -0.9 + i * 0.22 * rng.randf_range(0.6, 1.4)
				bars.append(LogoGeom.rrect(Rect2(x0, -0.75 + i * 0.55, 1.5 - absf(i - 1) * 0.3, 0.38), 0.19, 6))
			return [[LogoGeom.merge(bars), 0]]
	# Facetas: hexágono em triângulos alternando os tons
	var hexn := 6
	var t0: Array = []
	var t1: Array = []
	for i in hexn:
		var a0 := -PI / 2.0 + TAU * i / hexn
		var a1 := a0 + TAU / hexn
		var tri := PackedVector2Array([Vector2.ZERO, Vector2(cos(a0), sin(a0)) * 0.97, Vector2(cos(a1), sin(a1)) * 0.97])
		tri = LogoGeom.xf(tri, Vector2(cos(a0 + PI / hexn), sin(a0 + PI / hexn)) * 0.03)
		if i % 2 == 0:
			t0.append(tri)
		else:
			t1.append(tri)
	return [[t0, 0], [t1, 1]]


# --- Pictogramas -------------------------------------------------------------------------------

static func _pic(key: String, rng: RandomNumberGenerator) -> Dictionary:
	var v := rng.randi() % 3
	match key:
		"espiga":
			return _wheat(rng, v)
		"sol":
			return _sun(rng, v)
		"escudo":
			return _shield(rng, v)
		"anel", "circulo":
			return _ring(rng, v)
		"colunas":
			return _columns(rng, v)
		"folha":
			return _leaf(rng, v)
		"seta":
			return _arrow(rng, v)
		"sinal":
			return _signal(rng, v)
		"raio":
			return _bolt(rng, v)
		"onda":
			return _wave(rng, v)
		"telhado":
			return _roof(rng, v)
		"coroa":
			return _crown(rng, v)
		"chevron":
			return _chevron(rng, v)
		"gota":
			return _drop(rng, v)
		"guarda":
			return _umbrella(rng, v)
		"chama":
			return _flame(rng, v)
		"asa", "asas":
			return _wing(rng, v, key == "asas")
		"estrela":
			return _star(rng, v)
		"diamante":
			return _gem(rng, v)
		"sacola":
			return _bag(rng, v)
		"hexagono":
			return _hexa(rng, v)
		"cruz":
			return _cross(rng, v)
		"alvo":
			return _target(rng, v)
		"montanha":
			return _mountain(rng, v)
		"play":
			return _play(rng, v)
		"livro":
			return _book(rng, v)
		"pixel":
			return _pixels(rng, v)
		"barras":
			return _bars(rng, v)
		"triangulo":
			return _triangle(rng, v)
		"trevo":
			return _clover(rng, v)
		"curva":
			return _curve(rng, v)
	return {"s": [LogoGeom.circle(Vector2.ZERO, 0.9)]}


static func _wheat(rng: RandomNumberGenerator, v: int) -> Dictionary:
	var k := rng.randi_range(3, 5)
	var ang := deg_to_rad(rng.randf_range(24.0, 38.0))
	var bend := rng.randf_range(-0.14, 0.14)
	var gl := rng.randf_range(0.3, 0.38)
	var gw := rng.randf_range(0.19, 0.25)
	var solids: Array = []
	var holes: Array = []
	var stem := LogoGeom.quad(Vector2(0, 0.98), Vector2(bend, 0.3), Vector2(0, -0.5), 12)
	solids.append(LogoGeom.stroke(stem, 0.07, true))
	var top := LogoGeom.lens(Vector2(0, -0.48), Vector2(0, -0.98), gw, 0.0, 10)
	var grains: Array = [top]
	var sp := 0.82 / k
	for i in k:
		var y := -0.46 + i * sp
		for sx in [-1.0, 1.0]:
			var base := Vector2(0.03 * sx, y)
			var tip := base + Vector2(sin(ang) * sx, -cos(ang)) * gl
			grains.append(LogoGeom.lens(base, tip, gw, 0.0, 10))
	if v == 1:
		# Grãos vazados (só o contorno)
		for g: PackedVector2Array in grains:
			var o := Geometry2D.offset_polygon(g, -0.035, Geometry2D.JOIN_ROUND)
			solids.append(g)
			for q in o:
				holes.append(q)
		return {"s": LogoGeom.merge(solids), "h": holes}
	solids.append_array(grains)
	var merged := LogoGeom.merge(solids)
	if v == 2:
		# Três hastes em leque
		var side: Array = []
		for sx in [-1.0, 1.0]:
			side.append_array(LogoGeom.xf_all(merged, Vector2(0.42 * sx, 0.12), deg_to_rad(22.0) * sx, Vector2(0.78, 0.78)))
		return {"s": merged + side}
	return {"s": merged}


static func _sun(rng: RandomNumberGenerator, v: int) -> Dictionary:
	var core := rng.randf_range(0.32, 0.42)
	var n: int = [8, 10, 12, 16][rng.randi() % 4]
	var gap := rng.randf_range(0.08, 0.13)
	var rays: Array = []
	if v == 1:
		# Sol nascendo atrás do horizonte
		var half := LogoGeom.arc_band(Vector2(0, 0.25), 0.0, core + 0.1, PI, TAU, 32)
		var rn := rng.randi_range(5, 7)
		for i in rn:
			var a := PI + PI * (i + 0.5) / rn
			var r0 := core + 0.1 + gap
			var p0 := Vector2(0, 0.25) + Vector2(cos(a), sin(a)) * r0
			var p1 := Vector2(0, 0.25) + Vector2(cos(a), sin(a)) * (r0 + 0.38)
			rays.append(LogoGeom.stroke(PackedVector2Array([p0, p1]), 0.09, true))
		var hz := LogoGeom.rrect(Rect2(-0.95, 0.36, 1.9, 0.12), 0.06)
		var hz2 := LogoGeom.rrect(Rect2(-0.6, 0.56, 1.2, 0.1), 0.05)
		return {"s": [half] + rays + [hz, hz2]}
	if v == 2:
		# Mostrador: núcleo e um anel em segmentos
		var segs: Array = []
		for i in n:
			var a0 := TAU * i / n
			segs.append(LogoGeom.arc_band(Vector2.ZERO, core + gap, 0.95, a0 + 0.06, a0 + TAU / n - 0.06, 6))
		return {"s": segs, "a": [LogoGeom.circle(Vector2.ZERO, core, 40)]}
	var tri := rng.randf() < 0.55
	for i in n:
		var a := TAU * i / n - PI / 2.0
		var r0 := core + gap
		var r1 := 0.96 if i % 2 == 0 or n < 12 else 0.8
		var d := Vector2(cos(a), sin(a))
		var nrm := Vector2(-d.y, d.x)
		if tri:
			var hw := sin(PI / n) * r0 * 0.75
			rays.append(PackedVector2Array([d * r0 + nrm * hw, d * r1, d * r0 - nrm * hw]))
		else:
			rays.append(LogoGeom.stroke(PackedVector2Array([d * r0, d * r1]), 0.1, true))
	return {"s": rays, "a": [LogoGeom.circle(Vector2.ZERO, core, 40)]}


static func _shield_shape(kind: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	match kind:
		0:
			# Clássico: topo reto, laterais que curvam até a ponta
			out.append(Vector2(-0.82, -0.92))
			out.append(Vector2(0.82, -0.92))
			var right := LogoGeom.cubic(Vector2(0.82, -0.92), Vector2(0.84, 0.15), Vector2(0.55, 0.62), Vector2(0.0, 0.98), 16)
			for i in range(1, right.size()):
				out.append(right[i])
			var left := LogoGeom.cubic(Vector2(0.0, 0.98), Vector2(-0.55, 0.62), Vector2(-0.84, 0.15), Vector2(-0.82, -0.92), 16)
			for i in range(1, left.size() - 1):
				out.append(left[i])
		1:
			# Moderno: cantos de cima arredondados e ponta suave
			var tl := LogoGeom.quad(Vector2(-0.8, -0.6), Vector2(-0.8, -0.92), Vector2(-0.48, -0.92), 6)
			out.append_array(tl)
			var tr := LogoGeom.quad(Vector2(0.48, -0.92), Vector2(0.8, -0.92), Vector2(0.8, -0.6), 6)
			out.append_array(tr)
			var rs := LogoGeom.quad(Vector2(0.8, -0.6), Vector2(0.8, 0.55), Vector2(0.0, 0.98), 14)
			for i in range(1, rs.size()):
				out.append(rs[i])
			var ls := LogoGeom.quad(Vector2(0.0, 0.98), Vector2(-0.8, 0.55), Vector2(-0.8, -0.6), 14)
			for i in range(1, ls.size() - 1):
				out.append(ls[i])
		_:
			# Suíço: topo com entalhe no meio, base redonda
			out.append_array(PackedVector2Array([Vector2(-0.84, -0.94), Vector2(-0.2, -0.94), Vector2(0.0, -0.82), Vector2(0.2, -0.94), Vector2(0.84, -0.94)]))
			var rb := LogoGeom.cubic(Vector2(0.84, -0.94), Vector2(0.84, 0.4), Vector2(0.4, 0.96), Vector2(0.0, 0.98), 14)
			for i in range(1, rb.size()):
				out.append(rb[i])
			var lb := LogoGeom.cubic(Vector2(0.0, 0.98), Vector2(-0.4, 0.96), Vector2(-0.84, 0.4), Vector2(-0.84, -0.94), 14)
			for i in range(1, lb.size() - 1):
				out.append(lb[i])
	return out


static func _shield(rng: RandomNumberGenerator, v: int) -> Dictionary:
	var sh := _shield_shape(rng.randi() % 3)
	match v:
		0:
			# Chevron atravessando: o escudo vira três peças
			var y := rng.randf_range(-0.15, 0.15)
			var chev := LogoGeom.stroke(PackedVector2Array([Vector2(-1.2, y + 0.5), Vector2(0, y - 0.25), Vector2(1.2, y + 0.5)]), 0.13)
			return {"s": LogoGeom.cut([sh], [chev])}
		1:
			# Partido ao meio: metade em destaque
			var gap := LogoGeom.stroke(PackedVector2Array([Vector2(0, -1.2), Vector2(0, 1.2)]), 0.09)
			var pieces := LogoGeom.cut([sh], [gap])
			var l: Array = []
			var r: Array = []
			for p: PackedVector2Array in pieces:
				if KitGeom.bounds(p).get_center().x < 0.0:
					l.append(p)
				else:
					r.append(p)
			return {"s": l, "a": r}
	# Estrela vazada no escudo
	var st := LogoGeom.star(Vector2(0, -0.05), 5, 0.42, 0.18)
	return {"s": [sh], "h": [st]}


static func _ring(rng: RandomNumberGenerator, v: int) -> Dictionary:
	match v:
		0:
			# Órbita: anel grosso aberto e um ponto na abertura
			var a0 := rng.randf_range(-1.2, -0.3)
			var gap := rng.randf_range(0.7, 1.1)
			var ring := LogoGeom.arc_band(Vector2.ZERO, 0.6, 0.95, a0 + gap, a0 + TAU, 56)
			var dot_a := a0 + gap * 0.5
			var dot := LogoGeom.circle(Vector2(cos(dot_a), sin(dot_a)) * 0.775, 0.15, 24)
			return {"s": [ring], "a": [dot]}
		1:
			# Dois anéis entrelaçados (por cima / por baixo)
			var r0 := 0.42
			var r1 := 0.6
			var ca := Vector2(-0.32, 0)
			var cb := Vector2(0.32, 0)
			var a := [LogoGeom.arc_band(ca, r0, r1, 0.0, PI, 28), LogoGeom.arc_band(ca, r0, r1, PI, TAU, 28)]
			var b := [LogoGeom.arc_band(cb, r0, r1, 0.0, PI, 28), LogoGeom.arc_band(cb, r0, r1, PI, TAU, 28)]
			# B passa por baixo de A no alto e por cima embaixo
			var a_wide_top := LogoGeom.arc_band(ca, r0 - 0.05, r1 + 0.05, PI, TAU, 28)
			var b_wide_bot := LogoGeom.arc_band(cb, r0 - 0.05, r1 + 0.05, 0.0, PI, 28)
			var bb := LogoGeom.cut([b[1]], [a_wide_top]) + [b[0]]
			var aa := LogoGeom.cut([a[0]], [b_wide_bot]) + [a[1]]
			return {"s": aa, "a": bb}
	# Anel em segmentos e o centro
	var n := rng.randi_range(3, 4)
	var segs: Array = []
	var rot := rng.randf() * TAU
	for i in n:
		var a0 := rot + TAU * i / n
		segs.append(LogoGeom.arc_band(Vector2.ZERO, 0.66, 0.95, a0 + 0.12, a0 + TAU / n - 0.12, 16))
	return {"s": segs, "a": [LogoGeom.circle(Vector2.ZERO, 0.36, 32)]}


static func _columns(rng: RandomNumberGenerator, v: int) -> Dictionary:
	match v:
		0:
			var n := rng.randi_range(3, 4)
			var out: Array = []
			out.append(PackedVector2Array([Vector2(-0.96, -0.46), Vector2(0, -0.96), Vector2(0.96, -0.46)]))
			out.append(LogoGeom.rrect(Rect2(-0.9, -0.38, 1.8, 0.12), 0.02))
			var cw := 1.5 / (n * 1.9)
			for i in n:
				var x := -0.72 + (1.44 - cw) * i / (n - 1)
				out.append(LogoGeom.rrect(Rect2(x, -0.2, cw, 0.8), 0.02))
			out.append(LogoGeom.rrect(Rect2(-0.92, 0.66, 1.84, 0.12), 0.02))
			out.append(LogoGeom.rrect(Rect2(-1.0, 0.84, 2.0, 0.12), 0.02))
			return {"s": out}
		1:
			# Colunas que sobem (crescimento) sob um arco
			var out2: Array = []
			for i in 3:
				var h := 0.75 + i * 0.35
				out2.append(LogoGeom.rrect(Rect2(-0.78 + i * 0.58, 0.95 - h, 0.4, h), 0.06))
			out2.append(LogoGeom.arc_band(Vector2(0, 0.25), 0.98, 1.1, PI * 1.12, PI * 1.88, 24))
			return {"s": out2}
	# Arco sobre duas colunas
	var arch := LogoGeom.arc_band(Vector2(0, -0.1), 0.52, 0.8, PI, TAU, 28)
	var c1 := LogoGeom.rrect(Rect2(-0.8, -0.1, 0.28, 0.9), 0.02)
	var c2 := LogoGeom.rrect(Rect2(0.52, -0.1, 0.28, 0.9), 0.02)
	var base := LogoGeom.rrect(Rect2(-0.95, 0.82, 1.9, 0.14), 0.03)
	var key := LogoGeom.ngon(Vector2(0, -0.82), 0.12, 4, 0.0)
	return {"s": LogoGeom.merge([arch, c1, c2, base]), "a": [key]}


static func _leaf_shape(a: Vector2, b: Vector2, w: float, skew: float) -> Array:
	var lf := LogoGeom.lens(a, b, w, skew, 16)
	var rib := LogoGeom.stroke(LogoGeom.quad(a.lerp(b, 0.06), a.lerp(b, 0.5) + (b - a).orthogonal() * 0.06, a.lerp(b, 0.86), 10), 0.06)
	return LogoGeom.cut([lf], [rib])


static func _leaf(rng: RandomNumberGenerator, v: int) -> Dictionary:
	var w := rng.randf_range(0.26, 0.36)
	match v:
		0:
			var lf := _leaf_shape(Vector2(-0.62, 0.72), Vector2(0.66, -0.76), w, rng.randf_range(-0.4, 0.4))
			var stem := LogoGeom.stroke(LogoGeom.quad(Vector2(-0.62, 0.72), Vector2(-0.78, 0.86), Vector2(-0.92, 0.84), 6), 0.07, true)
			return {"s": lf + [stem]}
		1:
			# Broto: duas folhas e o caule
			var l := _leaf_shape(Vector2(-0.05, 0.25), Vector2(-0.88, -0.45), w, 0.3)
			var r := _leaf_shape(Vector2(0.05, 0.05), Vector2(0.86, -0.8), w, -0.3)
			var stem2 := LogoGeom.stroke(LogoGeom.quad(Vector2(0, 0.95), Vector2(0.04, 0.4), Vector2(0.0, -0.05), 8), 0.08, true)
			return {"s": l + [stem2], "a": r}
	# Três folhas em leque
	var out: Array = []
	for k in 3:
		var ang := -0.7 + k * 0.7
		var tip := Vector2(sin(ang), -cos(ang)) * 0.95 + Vector2(0, 0.35)
		out.append_array(_leaf_shape(Vector2(0, 0.85), tip, w * 0.8, 0.0))
	return {"s": out}


static func _arrow(rng: RandomNumberGenerator, v: int) -> Dictionary:
	match v:
		0:
			var rot := 0.0 if rng.randf() < 0.5 else -PI / 4.0
			var shaft := LogoGeom.rrect(Rect2(-0.95, -0.17, 1.15, 0.34), 0.05)
			var head := PackedVector2Array([Vector2(0.05, -0.62), Vector2(0.96, 0.0), Vector2(0.05, 0.62)])
			return {"s": [LogoGeom.xf(LogoGeom.merge([shaft, head])[0], Vector2.ZERO, rot)]}
		1:
			var out: Array = []
			for i in 2:
				var x := -0.55 + i * 0.62
				out.append(LogoGeom.stroke(PackedVector2Array([Vector2(x - 0.3, -0.75), Vector2(x + 0.35, 0.0), Vector2(x - 0.3, 0.75)]), 0.26))
			return {"s": [out[0]], "a": [out[1]]}
	# Seta circular
	var a0 := -PI * 0.35
	var a1 := a0 + PI * 1.55
	var band := LogoGeom.arc_band(Vector2.ZERO, 0.52, 0.8, a0, a1, 40)
	var d := Vector2(cos(a1), sin(a1))
	var t := Vector2(-d.y, d.x)
	var head2 := PackedVector2Array([d * 0.36, d * 0.98, d * 0.66 + t * 0.4])
	return {"s": LogoGeom.merge([band, head2])}


static func _signal(rng: RandomNumberGenerator, v: int) -> Dictionary:
	match v:
		0:
			var o := Vector2(-0.78, 0.78)
			var out: Array = [LogoGeom.circle(o, 0.2, 24)]
			for i in 3:
				var r0 := 0.42 + i * 0.4
				out.append(LogoGeom.arc_band(o, r0, r0 + 0.2, -PI / 2.0, 0.0, 18))
			return {"s": out}
		1:
			var bars: Array = []
			for i in 4:
				var h := 0.45 + i * 0.47
				bars.append(LogoGeom.rrect(Rect2(-0.9 + i * 0.48, 0.95 - h, 0.34, h), 0.09))
			return {"s": bars}
	var out2: Array = [LogoGeom.circle(Vector2.ZERO, 0.2, 24)]
	for i in 2:
		var r0 := 0.42 + i * 0.32
		for side in [0.0, PI]:
			out2.append(LogoGeom.arc_band(Vector2.ZERO, r0, r0 + 0.17, side - 0.75, side + 0.75, 14))
	return {"s": out2}


static func _bolt_shape(kind: int) -> PackedVector2Array:
	if kind == 0:
		return PackedVector2Array([Vector2(0.24, -0.98), Vector2(-0.62, 0.14), Vector2(-0.04, 0.14), Vector2(-0.3, 0.98), Vector2(0.62, -0.2), Vector2(0.06, -0.2)])
	return PackedVector2Array([Vector2(-0.1, -0.98), Vector2(0.5, -0.98), Vector2(0.12, -0.2), Vector2(0.52, -0.2), Vector2(-0.34, 0.98), Vector2(-0.08, 0.06), Vector2(-0.46, 0.06)])


static func _bolt(rng: RandomNumberGenerator, v: int) -> Dictionary:
	var b := _bolt_shape(rng.randi() % 2)
	match v:
		0:
			return {"s": [b]}
		1:
			return {"s": [LogoGeom.circle(Vector2.ZERO, 0.97, 56)], "h": [LogoGeom.xf(b, Vector2.ZERO, 0.0, Vector2(0.6, 0.6))]}
	# Raio e o rastro de velocidade
	var trail: Array = []
	for i in 3:
		var y := -0.32 + i * 0.3
		trail.append(LogoGeom.rrect(Rect2(-1.0 + i * 0.08, y, 0.42 - i * 0.08, 0.1), 0.05))
	return {"s": [LogoGeom.xf(b, Vector2(0.22, 0), 0.0, Vector2(0.8, 0.8))], "a": trail}


static func _wave_path(y: float, amp: float, ph: float, x0: float = -0.95, x1: float = 0.95) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in 25:
		var x := lerpf(x0, x1, i / 24.0)
		out.append(Vector2(x, y + sin(x * PI * 1.1 + ph) * amp))
	return out


static func _wave(rng: RandomNumberGenerator, v: int) -> Dictionary:
	var amp := rng.randf_range(0.12, 0.2)
	match v:
		0:
			var n := rng.randi_range(2, 3)
			var out: Array = []
			for i in n:
				var y := -0.4 + i * (0.8 / maxf(1.0, n - 1.0)) if n > 1 else 0.0
				out.append(LogoGeom.taper(_wave_path(y, amp, 0.4), 0.1, 0.2))
			return {"s": [out[0]] + (out.slice(2) if out.size() > 2 else []), "a": [out[1]]}
		1:
			# Círculo com o mar embaixo
			var circ := LogoGeom.circle(Vector2.ZERO, 0.96, 64)
			var sea := _wave_path(0.12, amp * 0.7, 0.0, -1.2, 1.2)
			sea.append(Vector2(1.2, 1.2))
			sea.append(Vector2(-1.2, 1.2))
			var top := _wave_path(0.12, amp * 0.7, 0.0, -1.2, 1.2)
			top.append(Vector2(1.2, -1.2))
			top.append(Vector2(-1.2, -1.2))
			var gap := LogoGeom.stroke(_wave_path(0.12, amp * 0.7, 0.0, -1.2, 1.2), 0.1)
			return {"s": LogoGeom.cut(LogoGeom.intersect([circ], sea), [gap]), "a": LogoGeom.cut(LogoGeom.intersect([circ], top), [gap, LogoGeom.circle(Vector2(0.2, -0.3), 0.3, 32)])}
	# Crista: onda que quebra
	var crest := PackedVector2Array()
	crest.append_array(LogoGeom.cubic(Vector2(-0.98, 0.7), Vector2(-0.5, 0.5), Vector2(-0.4, -0.9), Vector2(0.45, -0.75), 18))
	var curl := LogoGeom.cubic(Vector2(0.45, -0.75), Vector2(0.95, -0.65), Vector2(0.85, 0.05), Vector2(0.35, -0.1), 14)
	for i in range(1, curl.size()):
		crest.append(curl[i])
	var back := LogoGeom.cubic(Vector2(0.35, -0.1), Vector2(0.15, 0.2), Vector2(0.55, 0.55), Vector2(0.98, 0.7), 12)
	for i in range(1, back.size()):
		crest.append(back[i])
	var eye := LogoGeom.circle(Vector2(0.48, -0.42), 0.13, 20)
	return {"s": [crest], "h": [eye]}


static func _roof(rng: RandomNumberGenerator, v: int) -> Dictionary:
	match v:
		0:
			var roof := LogoGeom.stroke(PackedVector2Array([Vector2(-0.98, 0.0), Vector2(0, -0.86), Vector2(0.98, 0.0)]), 0.2)
			var body := LogoGeom.rrect(Rect2(-0.62, 0.02, 1.24, 0.94), 0.04)
			var door := LogoGeom.rrect(Rect2(-0.16, 0.42, 0.32, 0.54), 0.04)
			return {"s": [roof], "a": LogoGeom.cut([body], [door])}
		1:
			var out: Array = []
			for i in 2:
				var y := -0.25 + i * 0.6
				out.append(LogoGeom.stroke(PackedVector2Array([Vector2(-0.95, y + 0.55), Vector2(0, y - 0.32), Vector2(0.95, y + 0.55)]), 0.17))
			out.append(LogoGeom.rrect(Rect2(0.42, -0.86, 0.2, 0.4), 0.02))
			return {"s": LogoGeom.merge(out)}
	var house := PackedVector2Array([Vector2(-0.86, -0.1), Vector2(0, -0.94), Vector2(0.86, -0.1), Vector2(0.86, 0.96), Vector2(-0.86, 0.96)])
	var holes: Array = []
	for iy in 2:
		for ix in 2:
			holes.append(LogoGeom.rrect(Rect2(-0.42 + ix * 0.48, 0.0 + iy * 0.44, 0.36, 0.34), 0.03))
	return {"s": [house], "h": holes}


static func _crown(rng: RandomNumberGenerator, v: int) -> Dictionary:
	var n := 5 if v != 1 else 3
	var body := PackedVector2Array()
	body.append(Vector2(-0.9, 0.5))
	for i in n * 2 - 1:
		var x := lerpf(-0.9, 0.9, float(i) / (n * 2 - 2))
		var tip := i % 2 == 0
		body.append(Vector2(x, -0.62 if tip else -0.05 + (0.1 if (i / 2) % 2 == 0 else 0.0)))
	body.append(Vector2(0.9, 0.5))
	var band := LogoGeom.rrect(Rect2(-0.92, 0.62, 1.84, 0.26), 0.05)
	var jewels: Array = []
	if v != 1:
		for i in n:
			var x := lerpf(-0.9, 0.9, float(i) / (n - 1))
			jewels.append(LogoGeom.circle(Vector2(x, -0.74), 0.12, 18))
	var out := {"s": LogoGeom.merge([body] + jewels) + [band]}
	if v == 2:
		out["h"] = [LogoGeom.ngon(Vector2(0, 0.2), 0.14, 4, 0.0)]
	return out


static func _chevron(rng: RandomNumberGenerator, v: int) -> Dictionary:
	var n := 2 if v != 1 else 3
	var out: Array = []
	for i in n:
		var y := -0.5 + i * (1.0 / maxf(1.0, n - 1.0)) * 0.95
		out.append(LogoGeom.stroke(PackedVector2Array([Vector2(-0.92, y + 0.45), Vector2(0, y - 0.25), Vector2(0.92, y + 0.45)]), 0.26 if n == 2 else 0.2))
	if v == 2:
		return {"s": [LogoGeom.squircle(Vector2.ZERO, 0.95, 4.0)], "h": LogoGeom.xf_all(out, Vector2(0, 0.08), 0.0, Vector2(0.55, 0.55))}
	return {"s": out.slice(0, 1) + out.slice(2), "a": [out[1]]}


static func _drop_shape(c: Vector2, s: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var r := LogoGeom.cubic(Vector2(0, -1), Vector2(0.18, -0.55), Vector2(0.66, -0.18), Vector2(0.66, 0.3), 14)
	out.append_array(r)
	var bot := LogoGeom.arc_band(Vector2(0, 0.3), 0.0, 0.66, 0.0, PI, 20)
	for i in range(1, 21):
		out.append(bot[i])
	var l := LogoGeom.cubic(Vector2(-0.66, 0.3), Vector2(-0.66, -0.18), Vector2(-0.18, -0.55), Vector2(0, -1), 14)
	for i in range(1, l.size() - 1):
		out.append(l[i])
	return LogoGeom.xf(out, c, 0.0, Vector2(s, s))


static func _drop(rng: RandomNumberGenerator, v: int) -> Dictionary:
	var d := _drop_shape(Vector2.ZERO, 0.96)
	match v:
		0:
			var hl := LogoGeom.stroke(LogoGeom.quad(Vector2(-0.38, 0.1), Vector2(-0.4, 0.5), Vector2(-0.05, 0.62), 10), 0.1, true)
			return {"s": [d], "h": [hl]}
		1:
			var sea := _wave_path(0.18, 0.1, 0.5, -1.2, 1.2)
			sea.append(Vector2(1.2, 1.2))
			sea.append(Vector2(-1.2, 1.2))
			var top := _wave_path(0.18, 0.1, 0.5, -1.2, 1.2)
			top.append(Vector2(1.2, -1.2))
			top.append(Vector2(-1.2, -1.2))
			var gap := LogoGeom.stroke(_wave_path(0.18, 0.1, 0.5, -1.2, 1.2), 0.08)
			return {"s": LogoGeom.cut(LogoGeom.intersect([d], top), [gap]), "a": LogoGeom.cut(LogoGeom.intersect([d], sea), [gap])}
	return {"s": [_drop_shape(Vector2(-0.2, 0.05), 0.82)], "a": [_drop_shape(Vector2(0.62, 0.35), 0.38)]}


static func _umbrella(rng: RandomNumberGenerator, v: int) -> Dictionary:
	if v == 1:
		var sh := _shield_shape(rng.randi() % 3)
		var check := LogoGeom.stroke(PackedVector2Array([Vector2(-0.4, 0.0), Vector2(-0.08, 0.32), Vector2(0.45, -0.3)]), 0.17, true)
		return {"s": [sh], "h": [check]}
	var n := rng.randi_range(3, 4)
	var canopy := PackedVector2Array()
	var top := LogoGeom.arc_band(Vector2(0, 0.1), 0.0, 0.95, PI, TAU, 32)
	for i in range(0, 33):
		canopy.append(top[i])
	# Borda de baixo em gomos
	for k in n:
		var x0 := 0.95 - 1.9 * k / n
		var x1 := 0.95 - 1.9 * (k + 1) / n
		var arc := LogoGeom.quad(Vector2(x0, 0.1), Vector2((x0 + x1) * 0.5, -0.12), Vector2(x1, 0.1), 6)
		for i in range(1, arc.size()):
			canopy.append(arc[i])
	var handle := LogoGeom.stroke(PackedVector2Array([Vector2(0, -0.1), Vector2(0, 0.66)]), 0.11)
	var hook := LogoGeom.arc_band(Vector2(-0.18, 0.66), 0.12, 0.235, 0.0, PI, 12)
	if v == 2:
		return {"s": [LogoGeom.circle(Vector2.ZERO, 0.97, 56)], "h": LogoGeom.xf_all([canopy], Vector2(0, 0.05), 0.0, Vector2(0.62, 0.62))}
	return {"s": [canopy], "a": LogoGeom.merge([handle, hook])}


static func _flame_shape(c: Vector2, s: float, lean: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.append_array(LogoGeom.cubic(Vector2(lean, -1), Vector2(0.5, -0.45), Vector2(0.72, -0.05), Vector2(0.62, 0.42), 14))
	var b := LogoGeom.cubic(Vector2(0.62, 0.42), Vector2(0.5, 0.95), Vector2(-0.5, 0.95), Vector2(-0.62, 0.42), 14)
	for i in range(1, b.size()):
		out.append(b[i])
	var l := LogoGeom.cubic(Vector2(-0.62, 0.42), Vector2(-0.72, 0.0), Vector2(-0.3, -0.3), Vector2(lean, -1), 14)
	for i in range(1, l.size() - 1):
		out.append(l[i])
	return LogoGeom.xf(out, c, 0.0, Vector2(s, s))


static func _flame(rng: RandomNumberGenerator, v: int) -> Dictionary:
	var lean := rng.randf_range(-0.2, 0.25)
	match v:
		0:
			return {"s": [_flame_shape(Vector2.ZERO, 0.96, lean)], "h": [_flame_shape(Vector2(0, 0.32), 0.42, lean * 0.5)]}
		1:
			return {"s": [_flame_shape(Vector2(-0.22, 0.05), 0.9, lean)], "a": [_flame_shape(Vector2(0.5, 0.35), 0.55, -lean)]}
	return {"s": [_drop_shape(Vector2.ZERO, 0.96)], "h": [_flame_shape(Vector2(0, 0.22), 0.5, lean)]}


static func _wing(rng: RandomNumberGenerator, v: int, pair: bool) -> Dictionary:
	var n := rng.randi_range(3, 5)
	var feathers: Array = []
	for i in n:
		var t := float(i) / maxf(1.0, n - 1.0)
		var a := Vector2(-0.85, 0.15 + t * 0.35)
		var b := Vector2(0.95 - t * 0.55, -0.85 + t * 0.95)
		var path := LogoGeom.quad(a, a.lerp(b, 0.5) + Vector2(0, -0.22), b, 12)
		feathers.append(LogoGeom.taper(path, 0.24 - t * 0.06, 0.04))
	var w := LogoGeom.merge(feathers)
	if v == 1:
		# Andorinha
		var bird := PackedVector2Array()
		bird.append_array(LogoGeom.cubic(Vector2(-0.98, -0.3), Vector2(-0.5, -0.05), Vector2(-0.2, 0.0), Vector2(0.0, 0.2), 10))
		var r2 := LogoGeom.cubic(Vector2(0.0, 0.2), Vector2(0.25, -0.1), Vector2(0.6, -0.55), Vector2(0.98, -0.6), 10)
		for i in range(1, r2.size()):
			bird.append(r2[i])
		var r3 := LogoGeom.cubic(Vector2(0.98, -0.6), Vector2(0.6, -0.3), Vector2(0.35, 0.1), Vector2(0.25, 0.45), 10)
		for i in range(1, r3.size()):
			bird.append(r3[i])
		bird.append_array(PackedVector2Array([Vector2(0.1, 0.92), Vector2(0.02, 0.5), Vector2(-0.18, 0.86), Vector2(-0.12, 0.35)]))
		var r4 := LogoGeom.cubic(Vector2(-0.12, 0.35), Vector2(-0.4, 0.15), Vector2(-0.7, -0.05), Vector2(-0.98, -0.3), 10)
		for i in range(1, r4.size() - 1):
			bird.append(r4[i])
		return {"s": [bird]}
	if pair or v == 2:
		var right := LogoGeom.xf_all(w, Vector2(0.48, 0), 0.0, Vector2(0.52, 0.8))
		var left: Array = []
		for p: PackedVector2Array in right:
			left.append(LogoGeom.mirror_x(p))
		return {"s": left, "a": right}
	return {"s": w}


static func _star(rng: RandomNumberGenerator, v: int) -> Dictionary:
	var ri := rng.randf_range(0.38, 0.5)
	match v:
		0:
			var n: int = [5, 5, 6, 8][rng.randi() % 4]
			return {"s": [LogoGeom.star(Vector2.ZERO, n, 0.97, 0.97 * (ri if n == 5 else ri * 0.85))]}
		1:
			var ring := LogoGeom.arc_band(Vector2.ZERO, 0.8, 0.97, 0.0, PI, 30)
			var ring2 := LogoGeom.arc_band(Vector2.ZERO, 0.8, 0.97, PI, TAU, 30)
			return {"s": [ring, ring2], "a": [LogoGeom.star(Vector2.ZERO, 5, 0.62, 0.62 * ri)]}
	var st := LogoGeom.star(Vector2(0.35, -0.3), 5, 0.62, 0.62 * ri, -PI / 2.0 + 0.2)
	var trail: Array = []
	for i in 3:
		var y := -0.08 + i * 0.22
		var path := PackedVector2Array([Vector2(-0.95 + i * 0.12, y + 0.55), Vector2(0.0, y - 0.05)])
		trail.append(LogoGeom.taper(path, 0.02, 0.14 - i * 0.02))
	return {"s": [st], "a": trail}


static func _gem(rng: RandomNumberGenerator, v: int) -> Dictionary:
	match v:
		0:
			var crown_pts := PackedVector2Array([Vector2(-0.95, -0.25), Vector2(-0.55, -0.82), Vector2(0.55, -0.82), Vector2(0.95, -0.25)])
			var pav := PackedVector2Array([Vector2(-0.95, -0.12), Vector2(0.95, -0.12), Vector2(0, 0.98)])
			var cuts: Array = [LogoGeom.stroke(PackedVector2Array([Vector2(-0.22, -0.9), Vector2(-0.38, -0.2)]), 0.06),
				LogoGeom.stroke(PackedVector2Array([Vector2(0.22, -0.9), Vector2(0.38, -0.2)]), 0.06)]
			var c2 := LogoGeom.cut([crown_pts], cuts)
			return {"s": [pav] + [c2[0]] + (c2.slice(2) if c2.size() > 2 else []), "a": c2.slice(1, 2)}
		1:
			var rh := LogoGeom.ngon(Vector2.ZERO, 0.97, 4)
			var out := LogoGeom.outline(rh, 0.2)
			return {"s": out.slice(0, 1), "h": out.slice(1), "a": [LogoGeom.ngon(Vector2.ZERO, 0.34, 4)]}
	var rh2 := LogoGeom.ngon(Vector2.ZERO, 0.97, 4)
	var gap := LogoGeom.stroke(PackedVector2Array([Vector2(-1.1, -1.1), Vector2(1.1, 1.1)]), 0.08)
	var pieces := LogoGeom.cut([rh2], [gap])
	return {"s": pieces.slice(0, 1), "a": pieces.slice(1)}


static func _bag(rng: RandomNumberGenerator, v: int) -> Dictionary:
	var body := PackedVector2Array([Vector2(-0.82, -0.32), Vector2(0.82, -0.32), Vector2(0.92, 0.96), Vector2(-0.92, 0.96)])
	var handle := LogoGeom.arc_band(Vector2(0, -0.32), 0.3, 0.44, PI, TAU, 18)
	match v:
		0:
			return {"s": [body], "a": [handle]}
		1:
			var check := LogoGeom.stroke(PackedVector2Array([Vector2(-0.32, 0.32), Vector2(-0.06, 0.58), Vector2(0.38, 0.06)]), 0.15, true)
			return {"s": [body, handle], "h": [check]}
	var heart := LogoGeom.merge([LogoGeom.circle(Vector2(-0.14, 0.24), 0.16, 20), LogoGeom.circle(Vector2(0.14, 0.24), 0.16, 20),
		PackedVector2Array([Vector2(-0.29, 0.3), Vector2(0.29, 0.3), Vector2(0, 0.66)])])
	return {"s": [body, handle], "h": heart}


static func _hexa(rng: RandomNumberGenerator, v: int) -> Dictionary:
	match v:
		0:
			# Cubo: três faces com fendas
			var c := Vector2.ZERO
			var top := PackedVector2Array([Vector2(0, -0.96), Vector2(0.83, -0.48), Vector2(0, 0.0), Vector2(-0.83, -0.48)])
			var lf := PackedVector2Array([Vector2(-0.83, -0.42), Vector2(-0.03, 0.05), Vector2(-0.03, 0.97), Vector2(-0.83, 0.5)])
			var rf := PackedVector2Array([Vector2(0.83, -0.42), Vector2(0.03, 0.05), Vector2(0.03, 0.97), Vector2(0.83, 0.5)])
			return {"s": [lf, rf], "a": [LogoGeom.xf(top, Vector2(0, -0.03))]}
		1:
			var hx := LogoGeom.ngon(Vector2.ZERO, 0.97, 6, 0.0)
			var o := LogoGeom.outline(hx, 0.2)
			return {"s": o.slice(0, 1), "h": o.slice(1), "a": [LogoGeom.circle(Vector2.ZERO, 0.26, 24)]}
	var out: Array = []
	for p: Vector2 in [Vector2(-0.48, 0.3), Vector2(0.48, 0.3), Vector2(0, -0.5)]:
		out.append(LogoGeom.ngon(p, 0.46, 6, 0.0))
	return {"s": out.slice(0, 2), "a": out.slice(2)}


static func _cross(rng: RandomNumberGenerator, v: int) -> Dictionary:
	var arm := rng.randf_range(0.3, 0.38)
	var plus := LogoGeom.merge([LogoGeom.rrect(Rect2(-arm, -0.96, arm * 2.0, 1.92), arm * 0.4), LogoGeom.rrect(Rect2(-0.96, -arm, 1.92, arm * 2.0), arm * 0.4)])
	match v:
		0:
			return {"s": plus}
		1:
			return {"s": [LogoGeom.circle(Vector2.ZERO, 0.97, 56)], "h": LogoGeom.xf_all(plus, Vector2.ZERO, 0.0, Vector2(0.55, 0.55))}
	return {"s": [LogoGeom.squircle(Vector2.ZERO, 0.95, 4.0)], "h": LogoGeom.xf_all(plus, Vector2.ZERO, 0.0, Vector2(0.55, 0.55))}


static func _target(rng: RandomNumberGenerator, v: int) -> Dictionary:
	# Anéis em duas metades (sem contornos um dentro do outro) e o centro
	var out: Array = []
	var rings := [[0.74, 0.97], [0.4, 0.58]] if v != 1 else [[0.78, 0.97]]
	for rr: Array in rings:
		out.append(LogoGeom.arc_band(Vector2.ZERO, rr[0], rr[1], 0.0, PI, 30))
		out.append(LogoGeom.arc_band(Vector2.ZERO, rr[0], rr[1], PI, TAU, 30))
	var center := LogoGeom.circle(Vector2.ZERO, 0.24 if v != 1 else 0.5, 32)
	return {"s": out, "a": [center]}


static func _mountain(rng: RandomNumberGenerator, v: int) -> Dictionary:
	var peaks := PackedVector2Array([Vector2(-0.98, 0.8), Vector2(-0.35, -0.55), Vector2(-0.05, -0.05), Vector2(0.3, -0.85), Vector2(0.98, 0.8)])
	var snow_line := PackedVector2Array([Vector2(-1.2, -0.25), Vector2(-0.5, -0.05), Vector2(-0.2, -0.25), Vector2(0.1, -0.35), Vector2(0.35, -0.25), Vector2(0.6, -0.4), Vector2(1.2, -0.3)])
	var gap := LogoGeom.stroke(snow_line, 0.08)
	var pieces := LogoGeom.cut([peaks], [gap])
	var low: Array = []
	var high: Array = []
	for p: PackedVector2Array in pieces:
		if KitGeom.bounds(p).get_center().y > -0.1:
			low.append(p)
		else:
			high.append(p)
	if v == 1:
		return {"s": [LogoGeom.circle(Vector2.ZERO, 0.97, 56)], "h": LogoGeom.xf_all([peaks], Vector2(0, 0.08), 0.0, Vector2(0.6, 0.6))}
	var out := {"s": low, "a": high}
	if v == 2:
		out["s"] = low + [LogoGeom.circle(Vector2(0.7, -0.75), 0.18, 20)]
	return out


static func _play(rng: RandomNumberGenerator, v: int) -> Dictionary:
	var tri := LogoGeom.ngon(Vector2(0.12, 0), 0.8, 3, 0.0)
	var rt: PackedVector2Array = Geometry2D.offset_polygon(Geometry2D.offset_polygon(tri, -0.12)[0], 0.12, Geometry2D.JOIN_ROUND)[0]
	match v:
		0:
			return {"s": [rt]}
		1:
			return {"s": [LogoGeom.circle(Vector2.ZERO, 0.97, 56)], "h": [LogoGeom.xf(rt, Vector2(0.03, 0), 0.0, Vector2(0.55, 0.55))]}
	var waves: Array = []
	for i in 2:
		waves.append(LogoGeom.arc_band(Vector2(-0.1, 0), 0.62 + i * 0.26, 0.74 + i * 0.26, -0.7, 0.7, 12))
	return {"s": [LogoGeom.xf(rt, Vector2(-0.45, 0), 0.0, Vector2(0.6, 0.6))], "a": waves}


static func _book(rng: RandomNumberGenerator, v: int) -> Dictionary:
	var lp := PackedVector2Array()
	lp.append_array(LogoGeom.quad(Vector2(-0.96, -0.6), Vector2(-0.5, -0.8), Vector2(-0.05, -0.55), 10))
	lp.append(Vector2(-0.05, 0.86))
	var lb := LogoGeom.quad(Vector2(-0.05, 0.86), Vector2(-0.5, 0.62), Vector2(-0.96, 0.78), 10)
	for i in range(1, lb.size()):
		lp.append(lb[i])
	var rp := LogoGeom.mirror_x(lp)
	var out := {"s": [lp], "a": [rp]}
	if v == 1:
		out["s"] = [lp, rp]
		out["a"] = [PackedVector2Array([Vector2(0.35, -0.62), Vector2(0.55, -0.62), Vector2(0.55, 0.0), Vector2(0.45, -0.12), Vector2(0.35, 0.0)])]
	return out


static func _pixels(rng: RandomNumberGenerator, v: int) -> Dictionary:
	var s: Array = []
	var a: Array = []
	for iy in 3:
		for ix in 3:
			if rng.randf() < 0.2 and not (ix == 1 and iy == 1):
				continue
			var cell := LogoGeom.rrect(Rect2(-0.95 + ix * 0.66, -0.95 + iy * 0.66, 0.56, 0.56), 0.1)
			if (ix + iy) % 3 == 0:
				a.append(cell)
			else:
				s.append(cell)
	return {"s": s, "a": a}


static func _bars(rng: RandomNumberGenerator, v: int) -> Dictionary:
	var out: Array = []
	for i in 3:
		var y := -0.7 + i * 0.55
		var len := 1.9 - i * 0.35 * (1.0 if v != 1 else -0.5)
		out.append(PackedVector2Array([Vector2(-0.95, y), Vector2(-0.95 + len, y), Vector2(-0.95 + len - 0.25, y + 0.36), Vector2(-1.2, y + 0.36)]))
	return {"s": out}


static func _triangle(rng: RandomNumberGenerator, v: int) -> Dictionary:
	var t := LogoGeom.ngon(Vector2(0, 0.12), 0.98, 3)
	match v:
		0:
			var o := LogoGeom.outline(t, 0.22)
			return {"s": o.slice(0, 1), "h": o.slice(1), "a": [LogoGeom.ngon(Vector2(0, 0.25), 0.3, 3)]}
		1:
			var out: Array = []
			for i in 3:
				out.append(LogoGeom.ngon(Vector2(-0.45 + i * 0.45, 0.35 - (0.45 if i == 1 else 0.0)), 0.5, 3))
			return {"s": out.slice(0, 1) + out.slice(2), "a": out.slice(1, 2)}
	var gap := LogoGeom.stroke(PackedVector2Array([Vector2(0, -1.2), Vector2(0, 1.2)]), 0.09)
	var pieces := LogoGeom.cut([t], [gap])
	return {"s": pieces.slice(0, 1), "a": pieces.slice(1)}


static func _clover(rng: RandomNumberGenerator, v: int) -> Dictionary:
	var leaves: Array = []
	for k in 4:
		var a := PI / 4.0 + k * PI / 2.0
		var c := Vector2(cos(a), sin(a)) * 0.42
		leaves.append(LogoGeom.merge([LogoGeom.circle(c + Vector2(cos(a + 0.8), sin(a + 0.8)) * 0.16, 0.3, 24),
			LogoGeom.circle(c + Vector2(cos(a - 0.8), sin(a - 0.8)) * 0.16, 0.3, 24)])[0])
	var gap := LogoGeom.merge([LogoGeom.stroke(PackedVector2Array([Vector2(-1.2, 0), Vector2(1.2, 0)]), 0.08), LogoGeom.stroke(PackedVector2Array([Vector2(0, -1.2), Vector2(0, 1.2)]), 0.08)])
	return {"s": LogoGeom.cut(leaves, gap)}


static func _curve(rng: RandomNumberGenerator, v: int) -> Dictionary:
	var big := LogoGeom.circle(Vector2.ZERO, 0.95, 64)
	var small := LogoGeom.circle(Vector2(0.36, -0.28), 0.78, 64)
	var cres := LogoGeom.cut([big], [small])
	return {"s": cres, "a": [LogoGeom.circle(Vector2(0.62, -0.62), 0.16, 24)]}


# =================================================================================================
# Fornecedoras (desenho próprio)
# =================================================================================================

const SUPPLIERS := ["Kora", "Veloce", "Striker", "Tenkai", "Albion Kit", "Olimpo", "Tessuto", "Ataque", "Nordvik", "Alouette",
	"Pampa Sport", "Rinha", "Gol Norte", "Tramela", "Tango Deportes", "Gauchito", "Cóndor Sport", "Xolo Sport", "Hamle",
	"Hanse Trikot", "Alpina Sport", "Lusitano", "Delta Sport", "Tartan Kit", "Ferrier", "Vardar Sport", "Hwarang", "Longwei",
	"Sahel Sport", "Rimal Sport", "Southern Kit"]


static func _supplier(name: String) -> Array:
	match name:
		"Kora":
			# Órbita: lua crescente inclinada e o planeta
			var big := LogoGeom.circle(Vector2.ZERO, 0.95, 72)
			var small := LogoGeom.circle(Vector2(0.4, -0.3), 0.8, 72)
			return [[LogoGeom.cut([big], [small]), 0], [[LogoGeom.circle(Vector2(0.66, -0.64), 0.17, 28)], 0]]
		"Veloce":
			# V de velocidade: braço direito inteiro, o esquerdo em três lâminas da mesma espessura
			var right := PackedVector2Array([Vector2(0.34, -0.95), Vector2(0.98, -0.95), Vector2(0.18, 0.95), Vector2(-0.22, 0.95)])
			var lines: Array = []
			for i in 3:
				var x0 := -0.98 + i * 0.22
				var w := 0.15
				lines.append(PackedVector2Array([Vector2(x0, -0.95), Vector2(x0 + w, -0.95), Vector2(x0 + w + 0.64 - i * 0.05, 0.6 - i * 0.16), Vector2(x0 + 0.64 - i * 0.05, 0.6 - i * 0.16)]))
			return [[[right] + lines, 0]]
		"Striker":
			var a := PackedVector2Array([Vector2(-0.2, -0.98), Vector2(0.62, -0.98), Vector2(0.1, -0.08), Vector2(-0.62, -0.08)])
			var b := PackedVector2Array([Vector2(0.62, 0.08), Vector2(-0.1, 0.98), Vector2(-0.62, 0.98), Vector2(-0.1, 0.08)])
			return [[[a, b], 0]]
		"Tenkai":
			# Sol nascente atravessado por faixas
			var sun := LogoGeom.circle(Vector2.ZERO, 0.95, 72)
			var cuts: Array = []
			for i in 3:
				var y := 0.1 + i * 0.28
				cuts.append(PackedVector2Array([Vector2(-1.2, y), Vector2(1.2, y), Vector2(1.2, y + 0.1 - i * 0.015), Vector2(-1.2, y + 0.1 - i * 0.015)]))
			return [[LogoGeom.cut([sun], cuts), 0]]
		"Albion Kit":
			var band := LogoGeom.rrect(Rect2(-0.9, 0.55, 1.8, 0.24), 0.04)
			var body := PackedVector2Array([Vector2(-0.9, 0.42), Vector2(-0.98, -0.42), Vector2(-0.45, 0.02), Vector2(0, -0.62), Vector2(0.45, 0.02), Vector2(0.98, -0.42), Vector2(0.9, 0.42)])
			var gems: Array = [LogoGeom.circle(Vector2(-0.98, -0.56), 0.13, 20), LogoGeom.circle(Vector2(0, -0.78), 0.15, 20), LogoGeom.circle(Vector2(0.98, -0.56), 0.13, 20)]
			return [[[band, body] + gems, 0]]
		"Olimpo":
			# Asas abertas: três penas largas de cada lado, da raiz para cima
			var right: Array = []
			var tips := [[0.98, -0.82, 0.22], [0.92, -0.38, 0.2], [0.78, 0.02, 0.18]]
			for t: Array in tips:
				right.append(LogoGeom.lens(Vector2(0.1, 0.62), Vector2(float(t[0]), float(t[1])), float(t[2]), 0.35, 12))
			var rr := LogoGeom.merge(right)
			var left: Array = []
			for p: PackedVector2Array in rr:
				left.append(LogoGeom.mirror_x(p))
			return [[left + rr, 0]]
		"Tessuto":
			var out: Array = []
			for i in 3:
				out.append(LogoGeom.taper(_wave_path(-0.6 + i * 0.6, 0.18, i * 0.9), 0.06, 0.2))
			return [[out, 0]]
		"Ataque":
			var d := LogoGeom.ngon(Vector2.ZERO, 0.97, 4)
			var arrow := LogoGeom.stroke(PackedVector2Array([Vector2(-0.35, -0.42), Vector2(0.12, 0.0), Vector2(-0.35, 0.42)]), 0.2)
			return [[LogoGeom.cut([d], [arrow]), 0]]
		"Nordvik":
			var c1 := LogoGeom.stroke(PackedVector2Array([Vector2(-0.95, 0.1), Vector2(0, -0.78), Vector2(0.95, 0.1)]), 0.28)
			var c2 := LogoGeom.stroke(PackedVector2Array([Vector2(-0.95, 0.85), Vector2(0, -0.03), Vector2(0.95, 0.85)]), 0.28)
			var notch := LogoGeom.stroke(PackedVector2Array([Vector2(0, -1.2), Vector2(0, 1.2)]), 0.07)
			return [[LogoGeom.cut([c1, c2], [notch]), 0]]
		"Alouette":
			return [[_wing(_rng_of(name), 1, false)["s"], 0]]
		"Pampa Sport":
			return [[_clover(_rng_of(name), 0)["s"], 0], [[LogoGeom.stroke(LogoGeom.quad(Vector2(0.05, 0.05), Vector2(0.4, 0.6), Vector2(0.2, 0.98), 8), 0.08, true)], 0]]
		"Rinha":
			var st := LogoGeom.star(Vector2(0.3, -0.25), 5, 0.66, 0.28, -PI / 2.0 + 0.25)
			var trail: Array = []
			for i in 3:
				trail.append(LogoGeom.taper(PackedVector2Array([Vector2(-0.98 + i * 0.1, 0.45 + i * 0.22), Vector2(-0.12, -0.05 + i * 0.2)]), 0.02, 0.15 - i * 0.03))
			return [[[st] + trail, 0]]
		"Gol Norte":
			var ring := LogoGeom.arc_band(Vector2.ZERO, 0.8, 0.97, 0.0, PI, 32)
			var ring2 := LogoGeom.arc_band(Vector2.ZERO, 0.8, 0.97, PI, TAU, 32)
			var needle_n := PackedVector2Array([Vector2(0, -0.66), Vector2(0.24, 0.0), Vector2(-0.24, 0.0)])
			var needle_s := PackedVector2Array([Vector2(0.24, 0.06), Vector2(0, 0.66), Vector2(-0.24, 0.06)])
			return [[[ring, ring2, needle_n], 0], [[needle_s], 1]]
		"Tramela":
			# Três traços que formam um triângulo, abertos nos cantos (tramados)
			var c := [Vector2(0, -0.92), Vector2(0.95, 0.72), Vector2(-0.95, 0.72)]
			var out: Array = []
			for i in 3:
				var a: Vector2 = c[i]
				var b: Vector2 = c[(i + 1) % 3]
				out.append(LogoGeom.stroke(PackedVector2Array([a.lerp(b, 0.14), b.lerp(a, -0.02)]), 0.22))
			return [[LogoGeom.cut(out.slice(0, 1), [Geometry2D.offset_polygon(out[2], 0.06)[0]]) + LogoGeom.cut(out.slice(1, 2), [Geometry2D.offset_polygon(out[0], 0.06)[0]]) + LogoGeom.cut(out.slice(2, 3), [Geometry2D.offset_polygon(out[1], 0.06)[0]]), 0]]
		"Tango Deportes":
			var core := LogoGeom.circle(Vector2.ZERO, 0.38, 40)
			var rays: Array = []
			for i in 16:
				var a := TAU * i / 16.0
				var d := Vector2(cos(a), sin(a))
				if i % 2 == 0:
					rays.append(LogoGeom.taper(PackedVector2Array([d * 0.48, d * 0.97]), 0.14, 0.02))
				else:
					var wpath := PackedVector2Array()
					for k in 7:
						var t := k / 6.0
						wpath.append(d * lerpf(0.48, 0.86, t) + Vector2(-d.y, d.x) * sin(t * TAU) * 0.05)
					rays.append(LogoGeom.taper(wpath, 0.08, 0.02))
			return [[rays, 0], [[core], 0]]
		"Gauchito":
			var ring := LogoGeom.arc_band(Vector2.ZERO, 0.82, 0.97, 0.0, PI, 32)
			var ring2 := LogoGeom.arc_band(Vector2.ZERO, 0.82, 0.97, PI, TAU, 32)
			return [[[ring, ring2, LogoGeom.star(Vector2.ZERO, 8, 0.68, 0.3)], 0]]
		"Cóndor Sport":
			# Condor de asas abertas: asa larga com as penas-dedo na ponta, cabeça e colar
			var wing := PackedVector2Array([Vector2(0.06, -0.12), Vector2(0.45, -0.3), Vector2(0.98, -0.42), Vector2(0.9, -0.24), Vector2(0.98, -0.18),
				Vector2(0.86, -0.06), Vector2(0.94, 0.02), Vector2(0.8, 0.1), Vector2(0.84, 0.2), Vector2(0.62, 0.2), Vector2(0.4, 0.26), Vector2(0.06, 0.24)])
			var left := LogoGeom.mirror_x(wing)
			var body := LogoGeom.ellipse(Vector2(0, 0.12), 0.16, 0.3, 24)
			var tail := PackedVector2Array([Vector2(-0.14, 0.36), Vector2(0.14, 0.36), Vector2(0.2, 0.62), Vector2(0, 0.52), Vector2(-0.2, 0.62)])
			var all := LogoGeom.merge([wing, left, body, tail])
			var collar := LogoGeom.circle(Vector2(0, -0.2), 0.17, 24)
			var head := LogoGeom.circle(Vector2(0, -0.42), 0.12, 20)
			return [[all, 0], [[collar], 1], [[head], 0]]
		"Xolo Sport":
			var z := PackedVector2Array([Vector2(-0.9, -0.95), Vector2(0.3, -0.95), Vector2(0.3, -0.55), Vector2(-0.1, -0.55), Vector2(-0.1, -0.15),
				Vector2(0.55, -0.15), Vector2(-0.35, 0.98), Vector2(-0.18, 0.25), Vector2(-0.55, 0.25), Vector2(-0.55, -0.55), Vector2(-0.9, -0.55)])
			return [[[z], 0]]
		"Hamle":
			var out: Array = []
			for i in 2:
				var x := -0.6 + i * 0.7
				out.append(PackedVector2Array([Vector2(x - 0.38, -0.95), Vector2(x + 0.02, -0.95), Vector2(x + 0.55, 0.0), Vector2(x + 0.02, 0.95), Vector2(x - 0.38, 0.95), Vector2(x + 0.14, 0.0)]))
			return [[out.slice(0, 1), 0], [out.slice(1), 0]]
		"Hanse Trikot":
			var sh := _shield_shape(0)
			var h_cut: Array = [LogoGeom.rrect(Rect2(-0.42, -0.6, 0.16, 1.05), 0.02), LogoGeom.rrect(Rect2(0.26, -0.6, 0.16, 1.05), 0.02), LogoGeom.rrect(Rect2(-0.42, -0.12, 0.84, 0.16), 0.02)]
			return [[[sh] + LogoGeom.merge(h_cut), 0]]
		"Alpina Sport":
			# Dois picos com neve: a neve separada da rocha por uma fenda
			var a := PackedVector2Array([Vector2(-0.98, 0.78), Vector2(-0.3, -0.42), Vector2(0.3, 0.78)])
			var b := PackedVector2Array([Vector2(-0.2, 0.78), Vector2(0.36, -0.9), Vector2(0.98, 0.78)])
			var mts := LogoGeom.merge([a, b])
			var snow_b := PackedVector2Array([Vector2(0.36, -0.9), Vector2(0.58, -0.25), Vector2(0.46, -0.32), Vector2(0.36, -0.2), Vector2(0.26, -0.32), Vector2(0.16, -0.25)])
			var snow_a := PackedVector2Array([Vector2(-0.3, -0.42), Vector2(-0.14, -0.13), Vector2(-0.24, -0.18), Vector2(-0.32, -0.08), Vector2(-0.42, -0.18), Vector2(-0.47, -0.12)])
			var gap_b := Geometry2D.offset_polygon(snow_b, 0.05)[0]
			var gap_a := Geometry2D.offset_polygon(snow_a, 0.05)[0]
			var rock := LogoGeom.cut(mts, [gap_a, gap_b])
			return [[rock, 0], [[snow_a, snow_b], 1]]
		"Lusitano":
			# Cruz pátea: quatro braços que abrem nas pontas
			var arms: Array = []
			for k in 4:
				var q := LogoGeom.cubic(Vector2(0.42, -0.97), Vector2(0.15, -0.88), Vector2(-0.15, -0.88), Vector2(-0.42, -0.97), 8)
				var arm := PackedVector2Array([Vector2(-0.1, -0.12), Vector2(0.1, -0.12)])
				arm.append_array(PackedVector2Array([Vector2(0.42, -0.97)]))
				for i in range(1, q.size()):
					arm.append(q[i])
				arms.append(LogoGeom.xf(arm, Vector2.ZERO, k * PI / 2.0))
			return [[LogoGeom.merge(arms + [LogoGeom.circle(Vector2.ZERO, 0.18, 20)]), 0]]
		"Delta Sport":
			var t := LogoGeom.ngon(Vector2(0, 0.12), 0.98, 3)
			var o := LogoGeom.outline(t, 0.24)
			var inner := LogoGeom.ngon(Vector2(0, 0.28), 0.34, 3, PI / 2.0)
			return [[o, 0], [[inner], 1]]
		"Tartan Kit":
			var cells: Array = []
			for iy in 3:
				for ix in 3:
					var big := (ix == 1) != (iy == 1)
					var r := Rect2(-0.95 + ix * 0.66, -0.95 + iy * 0.66, 0.56, 0.56)
					if big or (ix == 1 and iy == 1):
						cells.append(LogoGeom.rrect(r, 0.04))
					else:
						cells.append(LogoGeom.rrect(r.grow(-0.12), 0.03))
			return [[cells, 0]]
		"Ferrier":
			# Ferradura com os furos dos cravos
			var shoe := LogoGeom.arc_band(Vector2(0, -0.08), 0.5, 0.92, PI * 0.82, PI * 2.18, 40)
			var holes: Array = []
			for i in 6:
				var a := PI * 0.95 + i * PI * 1.1 / 5.0
				holes.append(LogoGeom.circle(Vector2(0, -0.08) + Vector2(cos(a), sin(a)) * 0.71, 0.06, 12))
			return [[[shoe] + holes, 0]]
		"Vardar Sport":
			return [[_gem(_rng_of(name), 0)["s"] + _gem(_rng_of(name), 0)["a"], 0]]
		"Hwarang":
			# Pincelada em círculo, aberta no alto
			var path := PackedVector2Array()
			for i in 41:
				var a := -PI * 0.35 + TAU * 0.86 * i / 40.0
				path.append(Vector2(cos(a), sin(a)) * 0.78)
			return [[[LogoGeom.taper(path, 0.06, 0.32)], 0]]
		"Longwei":
			# Cauda de dragão: três ondas em S que afinam, uma dentro da outra
			var out: Array = []
			for i in 3:
				var path := PackedVector2Array()
				var amp := 0.5 - i * 0.12
				for k in 25:
					var t := k / 24.0
					path.append(Vector2(lerpf(-0.95 + i * 0.12, 0.95 - i * 0.2, t), -0.25 + i * 0.32 + sin(t * TAU + 0.6) * amp * (1.0 - t * 0.35)))
				out.append(LogoGeom.taper(path, 0.28 - i * 0.06, 0.02))
			return [[[out[0], out[2]], 0], [[out[1]], 1]]
		"Sahel Sport":
			var half := LogoGeom.arc_band(Vector2(0, 0.2), 0.0, 0.5, PI, TAU, 28)
			var rays: Array = []
			for i in 7:
				var a := PI + PI * (i + 0.5) / 7.0
				var d := Vector2(cos(a), sin(a))
				rays.append(PackedVector2Array([Vector2(0, 0.2) + d * 0.6 + Vector2(-d.y, d.x) * 0.07, Vector2(0, 0.2) + d * 0.96, Vector2(0, 0.2) + d * 0.6 - Vector2(-d.y, d.x) * 0.07]))
			var dune := LogoGeom.taper(_wave_path(0.55, 0.1, 0.0), 0.12, 0.12)
			return [[[half] + rays, 0], [[dune], 1]]
		"Rimal Sport":
			# Folha de palmeira: nervura curva e folíolos largos que afinam para a ponta
			var rib := LogoGeom.quad(Vector2(-0.82, 0.92), Vector2(-0.05, -0.05), Vector2(0.92, -0.86), 18)
			var out: Array = [LogoGeom.taper(rib, 0.12, 0.04)]
			for i in range(2, 17, 2):
				var p := rib[i]
				var d := (rib[i + 1] - rib[i - 1]).normalized()
				var n := Vector2(-d.y, d.x)
				var l := 0.5 * (1.0 - i / 20.0)
				for sx in [-1.0, 1.0]:
					var tip: Vector2 = p + (n * sx * 0.8 + d * 0.6).normalized() * l
					out.append(LogoGeom.lens(p, tip, 0.18, 0.3 * sx, 8))
			return [[LogoGeom.merge(out), 0]]
		"Southern Kit":
			var stars: Array = [LogoGeom.star(Vector2(0, -0.62), 5, 0.3, 0.13), LogoGeom.star(Vector2(0, 0.66), 5, 0.32, 0.14),
				LogoGeom.star(Vector2(-0.6, 0.0), 5, 0.26, 0.11), LogoGeom.star(Vector2(0.62, -0.12), 5, 0.24, 0.1)]
			return [[stars, 0], [[LogoGeom.star(Vector2(0.3, 0.22), 5, 0.14, 0.06)], 1]]
	return [[[LogoGeom.circle(Vector2.ZERO, 0.9)], 0]]


static func _rng_of(name: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash(name)
	return r
