class_name KitGeom
extends RefCounted
## Geometria dos uniformes, em coordenadas unitárias (a peça só muda de escala na tela):
## - malhas em grade dentro de cada peça, onde a luz e a sombra são pintadas por vértice;
## - faixas paralelas a um caminho (listras, frisos e golas que seguem o contorno da peça);
## - curvatura da estampa pelo corpo (listras que estreitam nas laterais, faixas que acompanham o peito).
## Tudo o que é caro fica em cache estático: desenhar de novo só reaproveita os arrays.


## Caminho suave (Catmull-Rom) passando pelos pontos, com `per_seg` amostras por trecho.
static func smooth(points: Array, per_seg: int = 6) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := points.size()
	if n < 3:
		for p: Vector2 in points:
			out.append(p)
		return out
	for i in n - 1:
		var p0: Vector2 = points[maxi(0, i - 1)]
		var p1: Vector2 = points[i]
		var p2: Vector2 = points[i + 1]
		var p3: Vector2 = points[mini(n - 1, i + 2)]
		for k in per_seg:
			var t := float(k) / per_seg
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	out.append(points[n - 1])
	return out


## Caminho deslocado `d` para o lado da normal (-dir.y, dir.x) do caminho (na tela, com y para baixo,
## é a direita de quem anda nele; negativo = o outro lado), com juntas em meia-esquadria: a
## distância fica a mesma nas curvas.
static func offset(path: PackedVector2Array, d: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := path.size()
	for i in n:
		var din := (path[i] - path[i - 1]).normalized() if i > 0 else (path[1] - path[0]).normalized()
		var dout := (path[i + 1] - path[i]).normalized() if i < n - 1 else din
		var n1 := Vector2(-din.y, din.x)
		var n2 := Vector2(-dout.y, dout.x)
		var m := (n1 + n2)
		if m.length_squared() < 1e-8:
			m = n1
		m = m.normalized()
		out.append(path[i] + m * d / maxf(0.4, m.dot(n1)))
	return out


## Faixa entre os deslocamentos `d0` e `d1` do caminho, como polígono.
static func band(path: PackedVector2Array, d0: float, d1: float) -> PackedVector2Array:
	var a := offset(path, d0)
	var b := offset(path, d1)
	b.reverse()
	a.append_array(b)
	return a


## Prolonga as pontas do caminho em linha reta (para o recorte deixar a ponta rente à costura).
static func extend(path: PackedVector2Array, before: float, after: float) -> PackedVector2Array:
	var out := PackedVector2Array(path)
	var n := out.size()
	if n < 2:
		return out
	if before > 0.0:
		out.insert(0, out[0] + (out[0] - out[1]).normalized() * before)
	if after > 0.0:
		n = out.size()
		out.append(out[n - 1] + (out[n - 1] - out[n - 2]).normalized() * after)
	return out


## Recorta os polígonos por uma ou mais formas (a parte de cada um que cai dentro delas).
static func clip_all(polys: Array, shapes: Array) -> Array:
	var out: Array = []
	for poly: PackedVector2Array in polys:
		for shape: PackedVector2Array in shapes:
			for piece in Geometry2D.intersect_polygons(poly, shape):
				if piece.size() >= 3:
					out.append(piece)
	return out


## Subdivide as arestas até nenhuma passar de `step` (para a estampa poder curvar sem quinas).
static func densify(poly: PackedVector2Array, step: float, closed: bool = true) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := poly.size()
	var last := n if closed else n - 1
	for i in last:
		var a := poly[i]
		var b := poly[(i + 1) % n]
		var k := maxi(1, ceili(a.distance_to(b) / step))
		for j in k:
			out.append(a.lerp(b, float(j) / k))
	if not closed:
		out.append(poly[n - 1])
	return out


static func bounds(poly: PackedVector2Array) -> Rect2:
	var r := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		r = r.expand(p)
	return r


## Malha em grade dentro do polígono: [pontos, índices]. Células inteiras viram dois triângulos;
## as da borda são recortadas pelo polígono (a malha fica exatamente dentro da peça).
static func grid_mesh(poly: PackedVector2Array, step: float) -> Array:
	var bb := bounds(poly)
	var pts := PackedVector2Array()
	var idx := PackedInt32Array()
	var nx := ceili(bb.size.x / step)
	var ny := ceili(bb.size.y / step)
	for j in ny:
		for i in nx:
			var x0 := bb.position.x + i * step
			var y0 := bb.position.y + j * step
			var cell := PackedVector2Array([Vector2(x0, y0), Vector2(x0 + step, y0), Vector2(x0 + step, y0 + step), Vector2(x0, y0 + step)])
			var inside := 0
			for c in cell:
				if Geometry2D.is_point_in_polygon(c, poly):
					inside += 1
			if inside == 0:
				# Pode haver um pedaço fino da peça cruzando a célula
				var crr := Rect2(x0, y0, step, step)
				var touches := false
				for p in poly:
					if crr.has_point(p):
						touches = true
						break
				if not touches:
					continue
			var pieces: Array
			if inside == 4 and not _has_vertex_inside(poly, Rect2(x0, y0, step, step)):
				pieces = [cell]
			else:
				pieces = Geometry2D.intersect_polygons(cell, poly)
			for piece: PackedVector2Array in pieces:
				if piece.size() < 3:
					continue
				var tri := Geometry2D.triangulate_polygon(piece)
				var base := pts.size()
				pts.append_array(piece)
				for t in tri:
					idx.append(base + t)
	return [pts, idx]


static func _has_vertex_inside(poly: PackedVector2Array, r: Rect2) -> bool:
	for p in poly:
		if r.has_point(p) and p.x > r.position.x and p.y > r.position.y:
			return true
	return false


## Distância com sinal até o caminho (positiva no mesmo lado de `offset` com d > 0) e a posição ao
## longo dele (0 no começo, 1 no fim). Devolve Vector2(distância, t).
static func sd_path(p: Vector2, path: PackedVector2Array) -> Vector2:
	var best := INF
	var best_sd := 0.0
	var best_t := 0.0
	var total := 0.0
	var acc: Array = [0.0]
	for i in path.size() - 1:
		total += path[i].distance_to(path[i + 1])
		acc.append(total)
	for i in path.size() - 1:
		var a := path[i]
		var b := path[i + 1]
		var ab := b - a
		var l2 := ab.length_squared()
		var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0) if l2 > 0.0 else 0.0
		var q := a + ab * t
		var d := p.distance_to(q)
		if d < best:
			best = d
			var cr := ab.x * (p.y - a.y) - ab.y * (p.x - a.x)
			best_sd = d if cr > 0.0 else -d
			best_t = (float(acc[i]) + sqrt(l2) * t) / maxf(total, 1e-6)
	return Vector2(best_sd, best_t)


## Desenha uma malha (pontos e índices em coordenadas unitárias) com uma cor por vértice.
static func draw_mesh(ci: CanvasItem, mesh: Array, colors: PackedColorArray) -> void:
	if (mesh[1] as PackedInt32Array).is_empty():
		return
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), mesh[1], mesh[0], colors)


## Curvatura da estampa pelo tronco (coordenadas da camisa): perto das laterais o tecido vira para
## longe de quem olha e o desenho estreita; as faixas horizontais descem de leve no meio do peito.
static func warp_torso(p: Vector2) -> Vector2:
	var hw := 0.258
	var u := (p.x - 0.5) / hw
	var th := 0.95
	var x := p.x
	if absf(u) <= 1.0:
		x = 0.5 + hw * sin(u * th) / sin(th)
	else:
		# Fora do tronco (só para o recorte): continua com a inclinação da borda
		var e := signf(u)
		x = 0.5 + hw * (e + (u - e) * th * cos(th) / sin(th))
	var uu := clampf(u, -1.0, 1.0)
	var sag := 0.007 * (1.0 - uu * uu) * smoothstep(0.12, 0.3, p.y)
	return Vector2(x, p.y + sag)


static func warp_poly(poly: PackedVector2Array, step: float = 0.02) -> PackedVector2Array:
	var d := densify(poly, step)
	var out := PackedVector2Array()
	out.resize(d.size())
	for i in d.size():
		out[i] = warp_torso(d[i])
	return out
