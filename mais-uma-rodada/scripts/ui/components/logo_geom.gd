class_name LogoGeom
extends RefCounted
## Geometria dos logos (BrandMark, BrandLogo): formas básicas em coordenadas unitárias (o símbolo
## cabe no quadrado de -1 a 1), operações de recorte (Godot Geometry2D), contornos de letras da fonte
## e o desenho de formas com furos (sem antialiasing nativo no polígono: a borda ganha um filete
## suavizado).
##
## Uma "forma" é uma lista de contornos (PackedVector2Array). Contornos dentro de outros contam como
## furos (par/ímpar), não importa o sentido deles.


static func circle(c: Vector2, r: float, n: int = 48) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		out.append(c + Vector2(cos(a), sin(a)) * r)
	return out


static func ellipse(c: Vector2, rx: float, ry: float, n: int = 48, rot: float = 0.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		out.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	return out


## Polígono regular de `n` lados (raio até o vértice).
static func ngon(c: Vector2, r: float, n: int, rot: float = -PI / 2.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		var a := rot + TAU * i / n
		out.append(c + Vector2(cos(a), sin(a)) * r)
	return out


## Estrela de `n` pontas, raio externo e interno.
static func star(c: Vector2, n: int, ro: float, ri: float, rot: float = -PI / 2.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n * 2:
		var a := rot + PI * i / n
		out.append(c + Vector2(cos(a), sin(a)) * (ro if i % 2 == 0 else ri))
	return out


## Retângulo de cantos arredondados.
static func rrect(r: Rect2, rad: float, seg: int = 6) -> PackedVector2Array:
	rad = minf(rad, minf(r.size.x, r.size.y) * 0.5)
	var out := PackedVector2Array()
	var cs := [Vector2(r.end.x - rad, r.position.y + rad), Vector2(r.end.x - rad, r.end.y - rad),
		Vector2(r.position.x + rad, r.end.y - rad), Vector2(r.position.x + rad, r.position.y + rad)]
	var a0s := [-PI / 2.0, 0.0, PI / 2.0, PI]
	for k in 4:
		for i in seg + 1:
			var a: float = a0s[k] + (PI / 2.0) * i / seg
			out.append(cs[k] + Vector2(cos(a), sin(a)) * rad)
	return out


## "Squircle" (superelipse): o quadrado arredondado dos ícones modernos.
static func squircle(c: Vector2, r: float, e: float = 4.0, n: int = 64) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		var ca := cos(a)
		var sa := sin(a)
		out.append(c + Vector2(signf(ca) * pow(absf(ca), 2.0 / e), signf(sa) * pow(absf(sa), 2.0 / e)) * r)
	return out


## Faixa de anel entre os raios r0 e r1, do ângulo a0 ao a1.
static func arc_band(c: Vector2, r0: float, r1: float, a0: float, a1: float, n: int = 0) -> PackedVector2Array:
	if n <= 0:
		n = maxi(6, int(absf(a1 - a0) / TAU * 64.0))
	var out := PackedVector2Array()
	for i in n + 1:
		var a := lerpf(a0, a1, float(i) / n)
		out.append(c + Vector2(cos(a), sin(a)) * r1)
	for i in range(n, -1, -1):
		var a := lerpf(a0, a1, float(i) / n)
		out.append(c + Vector2(cos(a), sin(a)) * r0)
	return out


static func quad(p0: Vector2, p1: Vector2, p2: Vector2, n: int = 10) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n + 1:
		var t := float(i) / n
		out.append(p0.lerp(p1, t).lerp(p1.lerp(p2, t), t))
	return out


static func cubic(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, n: int = 14) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n + 1:
		var t := float(i) / n
		var u := 1.0 - t
		out.append(p0 * u * u * u + p1 * 3.0 * u * u * t + p2 * 3.0 * u * t * t + p3 * t * t * t)
	return out


## Folha / lente entre a e b, com largura `w` (fração do comprimento) e assimetria `skew` (-1..1).
static func lens(a: Vector2, b: Vector2, w: float, skew: float = 0.0, n: int = 12) -> PackedVector2Array:
	var d := b - a
	var nrm := Vector2(-d.y, d.x)
	var c1 := a + d * (0.3 + 0.12 * skew) + nrm * w
	var c2 := a + d * (0.7 + 0.12 * skew) + nrm * w
	var c3 := a + d * (0.7 - 0.12 * skew) - nrm * w
	var c4 := a + d * (0.3 - 0.12 * skew) - nrm * w
	var out := cubic(a, c1, c2, b, n)
	var back := cubic(b, c3, c4, a, n)
	for i in range(1, back.size() - 1):
		out.append(back[i])
	return out


## Traço de largura constante ao longo do caminho, com pontas retas ou redondas.
static func stroke(path: PackedVector2Array, w: float, round_caps: bool = false) -> PackedVector2Array:
	var poly := KitGeom.band(path, -w * 0.5, w * 0.5)
	if not round_caps or path.size() < 2:
		return poly
	for e in [path[0], path[path.size() - 1]]:
		var r := Geometry2D.merge_polygons(poly, circle(e, w * 0.5, 20))
		if not r.is_empty():
			var best: PackedVector2Array = r[0]
			for q: PackedVector2Array in r:
				if KitGeom.bounds(q).get_area() > KitGeom.bounds(best).get_area():
					best = q
			poly = best
	return poly


## Une polígonos sólidos que se sobrepõem (sem furos): devolve só os contornos externos.
static func merge(polys: Array) -> Array:
	var acc: Array = []
	for p: PackedVector2Array in polys:
		if p.size() < 3:
			continue
		var cur := p
		var i := 0
		while i < acc.size():
			var q: PackedVector2Array = acc[i]
			if KitGeom.bounds(q).intersects(KitGeom.bounds(cur)):
				var r := Geometry2D.merge_polygons(q, cur)
				var outs := _outers(r)
				if outs.size() == 1:
					cur = outs[0]
					acc.remove_at(i)
					continue
			i += 1
		acc.append(cur)
	return acc


## Traço com a largura variando de w0 (começo) a w1 (fim): pinceladas e penas.
static func taper(path: PackedVector2Array, w0: float, w1: float) -> PackedVector2Array:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var n := path.size()
	for i in n:
		var t := float(i) / maxf(1.0, n - 1.0)
		var w := lerpf(w0, w1, t) * 0.5
		var din := (path[i] - path[i - 1]).normalized() if i > 0 else (path[1] - path[0]).normalized()
		var dout := (path[i + 1] - path[i]).normalized() if i < n - 1 else din
		var m := (Vector2(-din.y, din.x) + Vector2(-dout.y, dout.x)).normalized()
		left.append(path[i] + m * w)
		right.append(path[i] - m * w)
	right.reverse()
	left.append_array(right)
	return left


static func xf(poly: PackedVector2Array, pos: Vector2 = Vector2.ZERO, rot: float = 0.0, scale: Vector2 = Vector2.ONE) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(poly.size())
	for i in poly.size():
		out[i] = (poly[i] * scale).rotated(rot) + pos
	return out


static func xf_all(shape: Array, pos: Vector2 = Vector2.ZERO, rot: float = 0.0, scale: Vector2 = Vector2.ONE) -> Array:
	var out: Array = []
	for p: PackedVector2Array in shape:
		out.append(xf(p, pos, rot, scale))
	return out


static func mirror_x(poly: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(poly.size() - 1, -1, -1):
		out.append(Vector2(-poly[i].x, poly[i].y))
	return out


## Cópias giradas em volta do centro (simetria de rotação).
static func rotate_copies(shape: Array, n: int, rot0: float = 0.0) -> Array:
	var out: Array = []
	for k in n:
		for p: PackedVector2Array in shape:
			out.append(xf(p, Vector2.ZERO, rot0 + TAU * k / n))
	return out


# --- Operações (formas como listas de contornos; furos por par/ímpar) -------------------------

static func _outers(polys: Array) -> Array:
	var out: Array = []
	for p: PackedVector2Array in polys:
		var inside := false
		for q: PackedVector2Array in polys:
			if q != p and Geometry2D.is_point_in_polygon(p[0], q):
				inside = true
				break
		if not inside:
			out.append(p)
	return out


## Forma menos as tesouras: o que sobra de cada contorno (furos totalmente dentro viram contornos
## de furo, desenhados por par/ímpar).
static func cut(shape: Array, cutters: Array) -> Array:
	var cur: Array = shape.duplicate()
	for k: PackedVector2Array in cutters:
		if k.size() < 3:
			continue
		var nxt: Array = []
		for p: PackedVector2Array in cur:
			var bb := KitGeom.bounds(p)
			if not bb.intersects(KitGeom.bounds(k)):
				nxt.append(p)
				continue
			for r in Geometry2D.clip_polygons(p, k):
				if r.size() >= 3:
					nxt.append(r)
		cur = nxt
	return cur


static func intersect(shape: Array, mask: PackedVector2Array) -> Array:
	var out: Array = []
	for p: PackedVector2Array in shape:
		for r in Geometry2D.intersect_polygons(p, mask):
			if r.size() >= 3:
				out.append(r)
	return out


## Contorno de uma forma: a borda com espessura `w` (por fora e por dentro), para versões vazadas.
static func outline(poly: PackedVector2Array, w: float) -> Array:
	var outer := Geometry2D.offset_polygon(poly, w * 0.5, Geometry2D.JOIN_ROUND)
	var inner := Geometry2D.offset_polygon(poly, -w * 0.5, Geometry2D.JOIN_ROUND)
	var out: Array = []
	for o in outer:
		out.append(o)
	for i in inner:
		out.append(i)
	return out


static func bounds_all(shape: Array) -> Rect2:
	var r := Rect2()
	var first := true
	for p: PackedVector2Array in shape:
		if p.is_empty():
			continue
		var b := KitGeom.bounds(p)
		r = b if first else r.merge(b)
		first = false
	return r


## Reescala a forma para caber no quadrado [-m, m] (centrada).
static func fit(shape: Array, m: float = 0.92) -> Array:
	var b := bounds_all(shape)
	if b.size.x <= 0.0 or b.size.y <= 0.0:
		return shape
	var k := (2.0 * m) / maxf(b.size.x, b.size.y)
	return xf_all(shape, -b.get_center() * k, 0.0, Vector2(k, k))


# --- Letras da fonte ----------------------------------------------------------------------------

static var _fonts: Dictionary = {}


static func font_var(weight: float, width: float, slant: float = 0.0) -> FontVariation:
	var key := "%d|%d|%.2f" % [int(weight), int(width), slant]
	if _fonts.has(key):
		return _fonts[key]
	var fv := FontVariation.new()
	fv.base_font = load("res://assets/fonts/Saira-Variable.ttf")
	fv.variation_opentype = {"weight": weight, "width": width}
	if slant != 0.0:
		fv.variation_transform = Transform2D(Vector2(1, 0), Vector2(slant, 1), Vector2.ZERO)
	_fonts[key] = fv
	return fv


## Contornos de um texto (uma linha) como forma, com a altura das maiúsculas = 1, a linha de base em
## y = 0 e o começo em x = 0. Usa o kerning da fonte; letras que se encostam viram um contorno só
## (as contra-formas continuam como furos). Devolve [forma, largura].
static var _text_cache: Dictionary = {}


static func text_shape(txt: String, weight: float, width: float, track: float = 0.0, slant: float = 0.0) -> Array:
	var ck := "%s|%d|%d|%.3f|%.3f" % [txt, int(weight), int(width), track, slant]
	if _text_cache.has(ck):
		return _text_cache[ck]
	var fv := font_var(weight, width)
	var ts := TextServerManager.get_primary_interface()
	var rid: RID = fv.get_rids()[0]
	var size := 100
	var cap := 70.0 # altura de maiúscula da Saira em 100 px (aprox.)
	var outers: Array = []
	var counters: Array = []
	var x := 0.0
	var prev := -1
	for ch in txt:
		var code := ch.unicode_at(0)
		var gi := ts.font_get_glyph_index(rid, size, code, 0)
		if prev >= 0:
			x += ts.font_get_kerning(rid, size, Vector2i(prev, gi)).x
		var adv := ts.font_get_glyph_advance(rid, size, gi).x
		if ch != " ":
			var c: Dictionary = ts.font_get_glyph_contours(rid, size, gi)
			var polys: Array = []
			for poly: PackedVector2Array in _flatten(c):
				var p2 := PackedVector2Array()
				for q in poly:
					var y := q.y / cap
					p2.append(Vector2((q.x + x) / cap - y * slant, y))
				if p2.size() >= 3:
					polys.append(p2)
			# Contra-forma é o contorno no sentido contrário ao do maior contorno da letra (regra
			# da própria fonte): a cedilha encostada no C não engana.
			var big := 0.0
			var sign_big := 1.0
			for p: PackedVector2Array in polys:
				var ar := _area(p)
				if absf(ar) > big:
					big = absf(ar)
					sign_big = signf(ar)
			for p: PackedVector2Array in polys:
				if signf(_area(p)) == sign_big:
					outers.append(p)
				else:
					counters.append(p)
		x += adv + track * cap
		prev = gi
	var shape: Array = merge(outers) + counters
	var out := [shape, (x - track * cap) / cap]
	_text_cache[ck] = out
	return out


## Curvas quadráticas (TrueType) e cúbicas dos contornos do glifo em polígonos.
static func _flatten(c: Dictionary) -> Array:
	var pts: PackedVector3Array = c.get("points", PackedVector3Array())
	var ends: PackedInt32Array = c.get("contours", PackedInt32Array())
	var out: Array = []
	var start := 0
	for e in ends:
		var raw: Array = []
		for i in range(start, e + 1):
			raw.append(pts[i])
		start = e + 1
		if raw.size() < 2:
			continue
		var poly := PackedVector2Array()
		var n := raw.size()
		# começa num ponto da curva
		var first := 0
		for i in n:
			if int((raw[i] as Vector3).z) == 1:
				first = i
				break
		var i := 0
		var prev: Vector2 = Vector2((raw[first] as Vector3).x, (raw[first] as Vector3).y)
		poly.append(prev)
		while i < n:
			var cur: Vector3 = raw[(first + i + 1) % n]
			var cp := Vector2(cur.x, cur.y)
			var kind := int(cur.z)
			if kind == 1:
				poly.append(cp)
				prev = cp
				i += 1
			elif kind == 0:
				var nx: Vector3 = raw[(first + i + 2) % n]
				var np := Vector2(nx.x, nx.y)
				var end := np if int(nx.z) == 1 else cp.lerp(np, 0.5)
				var q := quad(prev, cp, end, 6)
				for k in range(1, q.size()):
					poly.append(q[k])
				prev = end
				i += 2 if int(nx.z) == 1 else 1
			else:
				var c2: Vector3 = raw[(first + i + 2) % n]
				var e3: Vector3 = raw[(first + i + 3) % n]
				var cb := cubic(prev, cp, Vector2(c2.x, c2.y), Vector2(e3.x, e3.y), 8)
				for k in range(1, cb.size()):
					poly.append(cb[k])
				prev = Vector2(e3.x, e3.y)
				i += 3
		if poly.size() > 2 and poly[0].distance_to(poly[poly.size() - 1]) < 0.01:
			poly.remove_at(poly.size() - 1)
		out.append(poly)
	return out


# --- Desenho ------------------------------------------------------------------------------------

static var _tris: Dictionary = {}


## Desenha a forma (contornos unitários) centrada em `c` com escala `u`. Furos por par/ímpar:
## cada contorno externo é emendado aos furos dele por uma "fenda" de largura zero e triangulado.
static func draw(ci: CanvasItem, shape: Array, c: Vector2, u: float, col: Color, cache_key: String = "") -> void:
	if shape.is_empty() or col.a <= 0.0:
		return
	var mesh: Array
	if cache_key != "" and _tris.has(cache_key):
		mesh = _tris[cache_key]
	else:
		mesh = _mesh(shape)
		if cache_key != "":
			_tris[cache_key] = mesh
	var pts: PackedVector2Array = mesh[0]
	var idx: PackedInt32Array = mesh[1]
	if not idx.is_empty():
		var tp := PackedVector2Array()
		tp.resize(pts.size())
		for i in pts.size():
			tp[i] = c + pts[i] * u
		var cols := PackedColorArray()
		cols.resize(pts.size())
		cols.fill(col)
		RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, tp, cols)
	# Borda suavizada (o triângulo do Godot não tem antialiasing)
	var lw := 1.0 if u >= 6.0 else 0.75
	for p: PackedVector2Array in shape:
		if p.size() < 3:
			continue
		var e := PackedVector2Array()
		e.resize(p.size() + 1)
		for i in p.size():
			e[i] = c + p[i] * u
		e[p.size()] = e[0]
		ci.draw_polyline(e, col, lw, true)


## [pontos, índices] da forma: externos com os furos emendados, triangulados. Se a emenda não
## triangular, cai numa triangulação de Delaunay filtrada por par/ímpar (sempre funciona).
static func _mesh(shape: Array) -> Array:
	var valid: Array = []
	for p: PackedVector2Array in shape:
		if p.size() >= 3:
			valid.append(p)
	var depth: Array = []
	for i in valid.size():
		var d := 0
		var p: PackedVector2Array = valid[i]
		for j in valid.size():
			if i != j and Geometry2D.is_point_in_polygon(p[0], valid[j]):
				d += 1
		depth.append(d)
	var pts := PackedVector2Array()
	var idx := PackedInt32Array()
	for i in valid.size():
		if int(depth[i]) % 2 == 1:
			continue
		var outer: PackedVector2Array = valid[i]
		var holes: Array = []
		for j in valid.size():
			if int(depth[j]) == int(depth[i]) + 1 and Geometry2D.is_point_in_polygon((valid[j] as PackedVector2Array)[0], outer):
				holes.append(valid[j])
		var merged := _bridge(outer, holes)
		var tri := Geometry2D.triangulate_polygon(merged)
		if tri.is_empty():
			var r := _delaunay([outer] + holes)
			var base0 := pts.size()
			pts.append_array(r[0])
			for t in r[1]:
				idx.append(base0 + t)
			continue
		var base := pts.size()
		pts.append_array(merged)
		for t in tri:
			idx.append(base + t)
	return [pts, idx]


## Triangulação de reserva: Delaunay de todos os pontos, mantendo os triângulos cujo centro cai
## dentro de um número ímpar de contornos.
static func _delaunay(contours: Array) -> Array:
	var pts := PackedVector2Array()
	for c: PackedVector2Array in contours:
		pts.append_array(KitGeom.densify(c, 0.04))
	var tri := Geometry2D.triangulate_delaunay(pts)
	var keep := PackedInt32Array()
	for i in range(0, tri.size(), 3):
		var cen := (pts[tri[i]] + pts[tri[i + 1]] + pts[tri[i + 2]]) / 3.0
		var n := 0
		for c: PackedVector2Array in contours:
			if Geometry2D.is_point_in_polygon(cen, c):
				n += 1
		if n % 2 == 1:
			keep.append(tri[i])
			keep.append(tri[i + 1])
			keep.append(tri[i + 2])
	return [pts, keep]


static func _area(p: PackedVector2Array) -> float:
	var a := 0.0
	for i in p.size():
		var q := p[(i + 1) % p.size()]
		a += p[i].x * q.y - q.x * p[i].y
	return a * 0.5


## Emenda os furos ao contorno externo por fendas de largura zero (o furo mais à direita primeiro),
## ligando cada furo a um vértice visível (a fenda não cruza nenhuma borda).
static func _bridge(outer: PackedVector2Array, holes: Array) -> PackedVector2Array:
	var poly := PackedVector2Array(outer)
	var so := signf(_area(poly))
	var hs: Array = []
	for h: PackedVector2Array in holes:
		var hh := PackedVector2Array(h)
		if signf(_area(hh)) == so:
			hh.reverse()
		hs.append(hh)
	hs.sort_custom(func(a: PackedVector2Array, b: PackedVector2Array) -> bool:
		return KitGeom.bounds(a).end.x > KitGeom.bounds(b).end.x)
	for k in hs.size():
		var h: PackedVector2Array = hs[k]
		var hi := 0
		for q in h.size():
			if h[q].x > h[hi].x:
				hi = q
		var m := h[hi]
		# Bordas que a fenda não pode cruzar: o polígono atual e os furos que ainda faltam
		var edges: Array = []
		for q in poly.size():
			edges.append([poly[q], poly[(q + 1) % poly.size()]])
		for j in range(k, hs.size()):
			var o: PackedVector2Array = hs[j]
			for q in o.size():
				edges.append([o[q], o[(q + 1) % o.size()]])
		var order: Array = []
		for q in poly.size():
			order.append([poly[q].distance_squared_to(m), q])
		order.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
		var oi := int(order[0][1])
		for cand: Array in order.slice(0, mini(order.size(), 60)):
			var v := poly[int(cand[1])]
			var ok := true
			for e: Array in edges:
				var a: Vector2 = e[0]
				var b: Vector2 = e[1]
				if a.is_equal_approx(v) or b.is_equal_approx(v) or a.is_equal_approx(m) or b.is_equal_approx(m):
					continue
				if Geometry2D.segment_intersects_segment(m, v, a, b) != null:
					ok = false
					break
			if ok:
				oi = int(cand[1])
				break
		var out := PackedVector2Array()
		for q in oi + 1:
			out.append(poly[q])
		for q in h.size() + 1:
			out.append(h[(hi + q) % h.size()])
		for q in range(oi, poly.size()):
			out.append(poly[q])
		poly = out
	return poly
