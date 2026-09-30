class_name PortraitPainter
extends RefCounted
## Retrato nativo dos lutadores (Game Design Bible §5, estilo "Broadcast" do
## face-lab). Porte de `drawFace` (prototypes/face-lab/identity.js) no estilo
## flat: mesma geometria em unidades normalizadas (cabeça ≈ 2 de altura, origem
## no centro do rosto), mesmas tabelas (content/face_catalog.json).
##
## Em vez de pintar num canvas, gera uma lista de operações (polígonos já
## recortados e linhas) que FighterPortrait desenha e reaproveita. Cabelos e
## barbas novos do catálogo que ainda não têm desenho próprio caem no corte
## padrão, sem quebrar.

const INK := "#1B2025"


## Operações de desenho para um rosto resolvido (FaceResolver.resolve).
## opts: avatar (bool) = enquadramento de lista; post (bool) = marcas de luta.
static func build(face: Dictionary, w: float, h: float, opts: Dictionary = {}) -> Array:
	var p := _Painter.new(face, w, h, opts)
	p.draw_background()
	p.draw_face()
	return p.ops


## Desenha as operações de build() num CanvasItem (dentro de _draw), com a
## escala k = largura na tela / largura usada no build.
static func draw(ci: CanvasItem, ops: Array, k: float = 1.0) -> void:
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2(k, k))
	for op: Dictionary in ops:
		if op.has("polys"):
			for poly: PackedVector2Array in op.polys:
				ci.draw_colored_polygon(poly, op.color)
		else:
			for pl: PackedVector2Array in op.lines:
				ci.draw_polyline(pl, op.color, op.width, true)
	ci.draw_set_transform(Vector2.ZERO)


class _Pen:
	var S: float
	var ox: float
	var oy: float
	var paths: Array = []
	var cur := PackedVector2Array()
	var cx := 0.0
	var cy := 0.0

	func _init(s: float, x: float, y: float) -> void:
		S = s
		ox = x
		oy = y

	func begin() -> void:
		paths = []
		cur = PackedVector2Array()

	func _pt(x: float, y: float) -> Vector2:
		return Vector2(ox + x * S, oy + y * S)

	func _flush() -> void:
		if cur.size() > 1:
			paths.append(cur)
		cur = PackedVector2Array()

	func m(x: float, y: float) -> void:
		_flush()
		cur.append(_pt(x, y))
		cx = x
		cy = y

	func l(x: float, y: float) -> void:
		cur.append(_pt(x, y))
		cx = x
		cy = y

	func q(qx: float, qy: float, x: float, y: float) -> void:
		for i in range(1, 9):
			var t := i / 8.0
			var u := 1.0 - t
			cur.append(_pt(u * u * cx + 2 * u * t * qx + t * t * x, u * u * cy + 2 * u * t * qy + t * t * y))
		cx = x
		cy = y

	func c(ax: float, ay: float, bx: float, by: float, x: float, y: float) -> void:
		for i in range(1, 13):
			var t := i / 12.0
			var u := 1.0 - t
			cur.append(_pt(u * u * u * cx + 3 * u * u * t * ax + 3 * u * t * t * bx + t * t * t * x,
				u * u * u * cy + 3 * u * u * t * ay + 3 * u * t * t * by + t * t * t * y))
		cx = x
		cy = y

	func e(ex: float, ey: float, rx: float, ry: float, a0: float = 0.0, a1: float = TAU, new_sub: bool = true) -> void:
		var n := maxi(6, int(ceil(40.0 * absf(a1 - a0) / TAU)))
		if new_sub:
			_flush()
		for i in n + 1:
			var a := a0 + (a1 - a0) * i / n
			cur.append(_pt(ex + cos(a) * rx, ey + sin(a) * ry))
		cx = ex + cos(a1) * rx
		cy = ey + sin(a1) * ry

	func close() -> void:
		_flush()

	func done() -> Array:
		_flush()
		return paths


class _Painter:
	var f: Dictionary
	var cat: Dictionary
	var W: float
	var H: float
	var opts: Dictionary
	var S: float
	var ox: float
	var oy: float
	var P: _Pen
	var ops: Array = []
	var clips: Array = []  # pilha de listas de polígonos (união)

	func _init(face: Dictionary, w: float, h: float, o: Dictionary) -> void:
		f = face
		cat = FaceResolver.catalog()
		W = w
		H = h
		opts = o
		var zoom: float = o.get("zoom", 1.0)
		S = W * 0.3 * zoom
		ox = W / 2.0
		oy = H * (0.56 if o.get("avatar", false) else 0.44)
		P = _Pen.new(S, ox, oy)

	# ---------- cores ----------
	static func hx(s: String) -> Color:
		return Color(s)

	static func mix(a: Color, b: Color, t: float) -> Color:
		return a.lerp(b, t)

	static func darken(c: Color, t: float) -> Color:
		return c.lerp(Color("#26120c"), t)

	static func lighten(c: Color, t: float) -> Color:
		return c.lerp(Color("#fff4ea"), t)

	static func lum(c: Color) -> float:
		return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b

	# ---------- primitivas ----------
	func _path(fn: Callable) -> Array:
		P.begin()
		fn.call()
		return P.done()

	func _clean(poly: PackedVector2Array) -> Array:
		if poly.size() < 3:
			return []
		var big := PackedVector2Array([Vector2(-W, -H), Vector2(W * 2, -H), Vector2(W * 2, H * 2), Vector2(-W, H * 2)])
		return Geometry2D.intersect_polygons(poly, big)

	func _apply_clips(polys: Array) -> Array:
		var out: Array = polys
		for level: Array in clips:
			var next: Array = []
			for a: PackedVector2Array in out:
				for c: PackedVector2Array in level:
					next.append_array(Geometry2D.intersect_polygons(a, c))
			out = next
		return out

	func _fill(paths: Array, color: Color, alpha: float) -> void:
		var polys: Array = []
		for sub: PackedVector2Array in paths:
			polys.append_array(_clean(sub))
		polys = _apply_clips(polys)
		var outer: Array = []
		for poly: PackedVector2Array in polys:
			if poly.size() >= 3 and not Geometry2D.is_polygon_clockwise(poly):
				outer.append(poly)
		if outer.is_empty():
			return
		ops.append({"polys": outer, "color": Color(color, clampf(alpha, 0.0, 1.0))})

	func _stroke(paths: Array, color: Color, width: float, alpha: float, closed: bool) -> void:
		var lines: Array = []
		for sub: PackedVector2Array in paths:
			var pts := sub
			if closed and sub.size() > 2:
				pts = sub.duplicate()
				pts.append(sub[0])
			lines.append(pts)
		for level: Array in clips:
			var next: Array = []
			for pl: PackedVector2Array in lines:
				for c: PackedVector2Array in level:
					next.append_array(Geometry2D.intersect_polyline_with_polygon(pl, c))
			lines = next
		var kept: Array = lines.filter(func(pl): return pl.size() >= 2)
		if kept.is_empty():
			return
		ops.append({"lines": kept, "color": Color(color, clampf(alpha, 0.0, 1.0)), "width": width})

	func push_clip(fn: Callable) -> void:
		var polys: Array = []
		for sub: PackedVector2Array in _path(fn):
			polys.append_array(_clean(sub))
		clips.append(polys)

	func pop_clip() -> void:
		clips.pop_back()

	func paint(fn: Callable, color: Color, o: Dictionary = {}) -> void:
		var paths := _path(fn)
		_fill(paths, color, float(o.get("alpha", 1.0)))
		if o.get("stroke", true):
			var ink: Color = o.get("ink", darken(color, 0.62))
			_stroke(paths, ink, S * 0.026 * float(o.get("lw", 1.0)), 1.0, true)

	func shade_in(clip_fn: Callable, fn: Callable, color: Color, alpha: float) -> void:
		push_clip(clip_fn)
		_fill(_path(fn), color, alpha)
		pop_clip()

	func line(fn: Callable, color: Color, lw: float, alpha: float = 1.0) -> void:
		_stroke(_path(fn), color, S * lw, alpha, false)

	func dot(x: float, y: float, r: float, color: Color, alpha: float) -> void:
		P.begin()
		P.e(x, y, r / S, r / S)
		_fill(P.done(), color, alpha)

	# ---------- fundo ----------
	func draw_background() -> void:
		var pal: Dictionary = cat.palette
		ops.append({"polys": [PackedVector2Array([Vector2(0, 0), Vector2(W, 0), Vector2(W, H), Vector2(0, H)])], "color": hx(pal.surface2)})
		if not opts.get("avatar", false):
			P.begin()
			P.e((W * 0.5 - ox) / S, (H * 0.42 - oy) / S, W * 0.44 / S, W * 0.44 / S)
			ops.append({"polys": P.done(), "color": hx("#2A323A")})

	# ---------- rosto ----------
	func draw_face() -> void:
		var heads: Dictionary = cat.heads
		var H0: Dictionary = heads.get(str(f.get("head", {}).get("shape", "oval")), heads.oval)
		var fem: bool = f.get("sex", "m") == "f"
		var head_cfg: Dictionary = f.get("head", {})
		var hw: float = float(H0.hw) + float(head_cfg.get("width", 0)) * 0.05
		var jw: float = float(H0.jw) + float(head_cfg.get("jaw", 0)) * 0.07
		var cw: float = float(H0.cw) + float(head_cfg.get("jaw", 0)) * 0.03
		if fem:
			jw *= 0.88
			cw *= 0.84
		var cl: float = float(H0.cl) + float(head_cfg.get("chin", 0)) * 0.05
		var chinY := 0.86 + cl
		var cb: float = float(H0.cb)
		var cr: float = float(H0.cr)
		var age: float = float(f.get("age", 27))
		var gray := clampf((age - 32.0) / 13.0, 0.0, 0.8) * float(f.get("grayGene", 1.0))
		var recede := float(f.get("recede", 0.0)) * clampf((age - 23.0) / 15.0, 0.0, 1.0)
		var wrinkle := clampf((age - 27.0) / 14.0, 0.0, 1.0)

		var skin: Color = hx(cat.skin.get(str(f.get("skin", "t06")), cat.skin.t06))
		var dk := lum(skin) < 0.42
		var shade := darken(skin, 0.3 if dk else 0.24)
		var deep := darken(skin, 0.5 if dk else 0.45)
		var light := lighten(skin, 0.14 if dk else 0.2)
		var lipC := mix(skin, hx("#4a1d20" if dk else "#7a2c33"), 0.3 if dk else 0.34)
		var hair: Dictionary = f.get("hair", {"style": "curto", "color": "preto"})
		var hair_color := str(hair.get("color", "preto"))
		var hairBase: Color = hx(cat.hair_colors.get(hair_color, "#17110e"))
		var special: bool = hair_color.begins_with("tingido") or hair_color in ["platinado", "multicolor", "bicolor", "pontas_claras", "prata"]
		var hairC := mix(hairBase, hx("#c6c2ba"), 0.0 if special else gray)
		var beard: Dictionary = f.get("beard", {"style": "nenhuma"})
		var beard_key: String = str(beard.color) if beard.get("color") != null else ("castanho_escuro" if special else hair_color)
		var beardBase: Color = hx(cat.hair_colors.get(beard_key, cat.hair_colors.get(hair_color, "#17110e")))
		var beardC := mix(beardBase, hx("#cfcbc3"), minf(0.9, gray * 1.15))
		var build: float = float(f.get("build", 0.5))
		var nw := 0.3 + 0.2 * build
		var marks := {}
		for mk in f.get("marks", []):
			marks[str(mk)] = true
		var hairInk := darken(hairC, 0.5)
		var hpaint := func(fn: Callable, o: Dictionary = {}) -> void:
			var oo := {"ink": hairInk}
			oo.merge(o, true)
			paint(fn, hairC, oo)

		var head := func() -> void:
			P.m(-hw, -0.27)
			P.e(0, -0.27, hw, cr, PI, TAU, false)
			P.c(hw * cb, 0.12, jw + 0.06, 0.42, jw, 0.6)
			P.q(jw - 0.06, chinY - 0.06, cw, chinY)
			P.q(0, chinY + 0.06, -cw, chinY)
			P.q(-jw + 0.06, chinY - 0.06, -jw, 0.6)
			P.c(-jw - 0.06, 0.42, -hw * cb, 0.12, -hw, -0.27)
			P.close()
		var topY := -0.27 - cr
		var hs := str(hair.get("style", "curto"))
		var rope := func(x0: float, y0: float, ln: float, s: float, wd: float = 0.06) -> Callable:
			return func() -> void:
				P.m(x0 - wd, y0)
				P.q(x0 + s * 0.12, y0 + ln * 0.5, x0 + s * 0.02, y0 + ln)
				P.l(x0 + s * 0.02 + s * wd * 1.4, y0 + ln)
				P.q(x0 + s * 0.2, y0 + ln * 0.5, x0 + wd, y0)
				P.close()

		# ---------- cabelo: parte de trás ----------
		if hs == "black_power":
			hpaint.call(func(): P.e(0, -0.5, hw * 1.36, 0.8))
		if hs == "afro_curto":
			hpaint.call(func(): P.e(0, -0.4, hw * 1.14, 0.66))
		if hs == "longo_liso" or hs == "longo_ondulado":
			hpaint.call(func() -> void:
				P.m(-hw * 1.06, -0.45)
				if hs == "longo_ondulado":
					P.q(-hw * 1.35, 0.0, -hw * 1.12, 0.3); P.q(-hw * 0.95, 0.6, -hw * 1.2, 0.9); P.q(-hw * 1.35, 1.2, -hw * 1.05, 1.45)
				else:
					P.q(-hw * 1.22, 0.7, -hw * 1.04, 1.45)
				P.l(hw * 1.04, 1.45)
				if hs == "longo_ondulado":
					P.q(hw * 1.35, 1.2, hw * 1.2, 0.9); P.q(hw * 0.95, 0.6, hw * 1.12, 0.3); P.q(hw * 1.35, 0, hw * 1.06, -0.45)
				else:
					P.q(hw * 1.22, 0.7, hw * 1.06, -0.45)
				P.close())
		if hs == "cacheado_longo":
			hpaint.call(func(): P.e(0, -0.1, hw * 1.35, 1.1))
			for i in 22:
				var a := PI * 0.9 + i / 21.0 * PI * 1.2
				hpaint.call(func(): P.e(cos(a) * hw * 1.33, -0.1 + sin(a) * 1.08, 0.1, 0.1), {"stroke": false})
		if hs == "dreads_longos" or hs == "box_braids":
			var n := 5 if hs == "box_braids" else 4
			for s: float in [-1.0, 1.0]:
				for i in n:
					var x0: float = s * (hw * 0.8 + i * 0.065)
					var ln: float = (1.55 if hs == "box_braids" else 1.3) + i * 0.04
					hpaint.call(rope.call(x0, -0.15, ln, s, 0.045 if hs == "box_braids" else 0.06), {"lw": 0.8})
					if hs == "box_braids":
						for k in 8:
							var yy := k * 0.19
							line(func(): P.m(x0, yy); P.q(x0 + s * 0.05, yy + 0.05, x0 + s * 0.09, yy + 0.02), darken(hairC, 0.5), 0.013, 0.7)
		if hs == "dreads_curtos":
			for s: float in [-1.0, 1.0]:
				for i in 4:
					hpaint.call(rope.call(s * (hw * 0.62 + i * 0.1), -0.5, 0.55 + i * 0.06, s, 0.055), {"lw": 0.8})
		if hs == "coque":
			hpaint.call(func(): P.e(hw * 0.1, topY - 0.05, 0.26, 0.2))
		if hs == "coque_masc":
			hpaint.call(func(): P.e(0, topY - 0.02, 0.2, 0.15))
		if hs == "rabo":
			hpaint.call(func(): P.m(hw * 0.55, -0.85); P.q(hw * 1.35, -0.3, hw * 1.05, 0.6); P.q(hw * 0.95, 1.1, hw * 1.2, 1.4); P.l(hw * 1.0, 1.42); P.q(hw * 0.7, 0.8, hw * 0.8, 0.2); P.q(hw * 0.9, -0.4, hw * 0.3, -0.8); P.close())
		if hs == "meio_coque":
			hpaint.call(func(): P.m(-hw * 1.04, -0.4); P.q(-hw * 1.2, 0.6, -hw * 1.02, 1.25); P.l(hw * 1.02, 1.25); P.q(hw * 1.2, 0.6, hw * 1.04, -0.4); P.close())
		if hs == "mullet_moderno":
			hpaint.call(func(): P.m(-hw * 0.85, 0.05); P.q(-hw * 0.95, 0.7, -nw * 1.2, 1.05); P.l(nw * 1.2, 1.05); P.q(hw * 0.95, 0.7, hw * 0.85, 0.05); P.close())
		if hs == "duas_trancas":
			for s: float in [-1.0, 1.0]:
				var x0: float = s * hw * 0.82
				hpaint.call(rope.call(x0, -0.2, 1.45, s, 0.075), {"lw": 0.8})
				for k in 8:
					var yy := -0.05 + k * 0.17
					line(func(): P.m(x0 - s * 0.04, yy); P.q(x0 + s * 0.04, yy + 0.06, x0 + s * 0.12, yy + 0.01), darken(hairC, 0.5), 0.016, 0.8)
		if hs == "coque_baixo":
			hpaint.call(func(): P.e(hw * 0.86, 0.08, 0.16, 0.17))
		if hs == "dreads_presos":
			for i in range(-3, 4):
				hpaint.call(rope.call(i * 0.09, topY - 0.18, 0.22, -1.0 if i < 0 else 1.0, 0.04), {"lw": 0.6})
		if hs == "ombro":
			hpaint.call(func(): P.m(-hw * 1.05, -0.45); P.q(-hw * 1.22, 0.3, -hw * 1.06, 0.95); P.l(hw * 1.06, 0.95); P.q(hw * 1.22, 0.3, hw * 1.05, -0.45); P.close())
		if hs == "ondulado_medio":
			hpaint.call(func(): P.m(-hw * 1.05, -0.45); P.q(-hw * 1.3, -0.05, -hw * 1.08, 0.2); P.q(-hw * 0.95, 0.45, -hw * 1.12, 0.62); P.l(hw * 1.12, 0.62); P.q(hw * 0.95, 0.45, hw * 1.08, 0.2); P.q(hw * 1.3, -0.05, hw * 1.05, -0.45); P.close())
		if hs == "cachos_volumosos":
			hpaint.call(func(): P.e(0, -0.5, hw * 1.22, 0.72))
			var r := FaceResolver.Rng.new(int(f.get("seed", 1)))
			for i in 26:
				var a := PI * 0.85 + i / 25.0 * PI * 1.3
				var rx := 0.11 + r.next() * 0.04
				var ry := 0.1 + r.next() * 0.04
				hpaint.call(func(): P.e(cos(a) * hw * 1.2, -0.5 + sin(a) * 0.7, rx, ry), {"lw": 0.6})
		if hs == "afro_puff":
			hpaint.call(func(): P.e(0, topY - 0.32, 0.52, 0.42))
			var r := FaceResolver.Rng.new(int(f.get("seed", 1)))
			for i in 18:
				var a := r.next() * TAU
				hpaint.call(func(): P.e(cos(a) * 0.45, topY - 0.32 + sin(a) * 0.36, 0.1, 0.09), {"stroke": false})
		if hs == "rabo_alto":
			hpaint.call(func(): P.m(hw * 0.2, -1.0); P.q(hw * 1.1, -0.9, hw * 1.08, 0.1); P.q(hw * 1.02, 0.7, hw * 1.18, 1.15); P.l(hw * 0.98, 1.18); P.q(hw * 0.82, 0.6, hw * 0.85, 0); P.q(hw * 0.8, -0.75, hw * 0.05, -0.95); P.close())
		if hs == "dreads_soltos":
			for i in 9:
				var a := PI * 0.95 + i / 8.0 * PI * 1.1
				var x0 := cos(a) * hw * 0.9
				var y0 := -0.27 + sin(a) * cr * 0.9
				var dx := cos(a) * 0.75
				var dy := sin(a) * 0.5 + 0.45
				hpaint.call(func(): P.m(x0 - 0.05, y0); P.q(x0 + dx * 0.5, y0 + dy * 0.3 - 0.1, x0 + dx, y0 + dy); P.l(x0 + dx + 0.09, y0 + dy + 0.02); P.q(x0 + dx * 0.5 + 0.1, y0 + dy * 0.3 - 0.05, x0 + 0.05, y0); P.close(), {"lw": 0.6})
		if hs == "mullet":
			hpaint.call(func(): P.m(-hw * 0.95, 0); P.q(-hw * 1.12, 0.8, -nw * 1.45, 1.18); P.l(nw * 1.45, 1.18); P.q(hw * 1.12, 0.8, hw * 0.95, 0); P.close())

		# ---------- pescoço, ombros, tatuagens ----------
		var tr := 1.35 + build * 0.35
		var body := func() -> void:
			P.m(-nw, 0.4); P.l(nw, 0.4); P.q(nw * 0.92, 0.98, nw * 1.35, 1.13); P.q(tr * 0.8, 1.3, tr, 1.5); P.q(tr + 0.35, 1.6, tr + 0.45, 1.95)
			P.l(tr + 0.6, 3); P.l(-tr - 0.6, 3); P.l(-tr - 0.45, 1.95); P.q(-tr - 0.35, 1.6, -tr, 1.5); P.q(-tr * 0.8, 1.3, -nw * 1.35, 1.13); P.q(-nw * 0.92, 0.98, -nw, 0.4); P.close()
		var tc := mix(skin, hx("#1d2b30"), 0.55 if dk else 0.75)
		paint(body, skin)
		shade_in(body, func(): P.e(0, chinY + 0.06, jw * 0.85, 0.2), deep, 0.45)
		shade_in(body, func(): P.m(nw * 0.4, 0.4); P.l(3, 0.4); P.l(3, 1.25); P.l(nw * 0.9, 1.18); P.close(), shade, 0.35)
		for s: float in [-1.0, 1.0]:
			line(func(): P.m(s * 0.22, 1.36); P.q(s * 0.7, 1.28, s * (tr - 0.1), 1.44), shade, 0.03, 0.7)
		if not fem:
			line(func(): P.m(-0.02, 1.75); P.q(-0.5, 1.95, -1.05, 1.82); P.m(0.02, 1.75); P.q(0.5, 1.95, 1.05, 1.82), shade, 0.025, 0.5)
		if marks.has("shoulders"):
			for s: float in [-1.0, 1.0]:
				line(func(): P.m(s * (tr - 0.35), 1.4); P.q(s * (tr - 0.05), 1.35, s * (tr + 0.3), 1.75), tc, 0.05, 0.85)
				line(func(): P.m(s * (tr - 0.25), 1.52); P.q(s * (tr - 0.02), 1.5, s * (tr + 0.22), 1.86), tc, 0.03, 0.85)
				for k in 3:
					line(func(): P.m(s * (tr - 0.15 + k * 0.12), 1.47 + k * 0.03); P.l(s * (tr - 0.08 + k * 0.12), 1.62 + k * 0.04), tc, 0.022, 0.85)
		if marks.has("chest") and not fem:
			line(func(): P.m(-0.45, 1.62); P.q(0, 1.52, 0.45, 1.62), tc, 0.035, 0.85)
			line(func(): P.m(-0.3, 1.7); P.q(-0.05, 1.66, 0.05, 1.71); P.q(0.2, 1.76, 0.3, 1.69), tc, 0.022, 0.8)
		if fem:
			var top := func(): P.m(-tr - 0.6, 2.0); P.l(-1.05, 1.72); P.q(0, 1.9, 1.05, 1.72); P.l(tr + 0.6, 2.0); P.l(tr + 0.6, 3); P.l(-tr - 0.6, 3); P.close()
			paint(top, hx("#2E3942"), {"ink": hx("#141a1f")})
			for s: float in [-1.0, 1.0]:
				line(func(): P.m(s * 0.98, 1.74); P.l(s * 0.78, 1.18), hx("#2E3942"), 0.08, 1.0)
		if hs == "tranca_unica":
			hpaint.call(func(): P.m(hw * 0.55, 0.1); P.q(hw * 1.05, 0.8, hw * 0.95, 1.7); P.l(hw * 0.78, 1.72); P.q(hw * 0.85, 0.8, hw * 0.35, 0.2); P.close(), {"lw": 0.8})
			for k in 9:
				var yy := 0.3 + k * 0.15
				var xx := hw * (0.62 + k * 0.035)
				line(func(): P.m(xx - 0.06, yy); P.q(xx, yy + 0.06, xx + 0.07, yy), darken(hairC, 0.5), 0.016, 0.8)
		if marks.has("neck"):
			line(func(): P.m(-nw * 0.95, 0.7); P.q(-nw * 0.3, 0.8, -nw * 0.7, 1.0); P.q(-nw * 1.1, 1.1, -nw * 0.55, 1.22), tc, 0.028, 0.85)
			line(func(): P.m(-nw * 0.85, 0.86); P.q(-nw * 0.55, 0.9, -nw * 0.62, 0.98), tc, 0.022, 0.85)

		# ---------- orelhas ----------
		var ears: Dictionary = f.get("ears", {"shape": "normal", "cauli": 0})
		var E0: Dictionary = cat.ears.get(str(ears.get("shape", "normal")), cat.ears.normal)
		var cauli := float(ears.get("cauli", 0))
		for s: float in [-1.0, 1.0]:
			var ex0: float = s * (hw + 0.03 + float(E0.get("out", 0.0)))
			paint(func(): P.e(ex0, 0, float(E0.rx) + 0.02 * cauli, float(E0.ry) + 0.015 * cauli), skin)
			if cauli > 0:
				paint(func(): P.e(ex0 + s * 0.05, -0.07, 0.045 * cauli, 0.05 * cauli); P.e(ex0 + s * 0.03, 0.07, 0.035 * cauli, 0.04 * cauli), mix(skin, hx("#6a3a3a" if dk else "#b56a6a"), 0.18), {"lw": 0.6})
			line(func(): P.m(ex0 - s * 0.01, -0.12); P.q(ex0 + s * 0.08, -0.02, ex0 + s * 0.01, 0.1), deep, 0.022, 0.7)
			if marks.has("argola"):
				line(func(): P.e(ex0 + s * 0.01, float(E0.ry) - 0.01, 0.035, 0.04, 0, TAU), hx("#c9c4b8"), 0.014, 1.0)
			if marks.has("brinco"):
				paint(func(): P.e(ex0 + s * 0.01, float(E0.ry) - 0.03, 0.018, 0.018), hx("#e8e3d6"), {"lw": 0.5})

		# ---------- cabeça ----------
		paint(head, skin, {"lw": 1.1})
		shade_in(head, func(): P.m(0.1, -1.2); P.q(0.52, -0.35, 0.2, 0.28); P.q(0.06, 0.7, 0.08, 1.2); P.l(1.3, 1.2); P.l(1.3, -1.2); P.close(), shade, 0.42)
		for s: float in [-1.0, 1.0]:
			shade_in(head, func(): P.e(s * 0.55, 0.3, 0.2, 0.1), shade, 0.35 if s > 0 else 0.18)
		shade_in(head, func(): P.e(-0.22, -0.58, 0.24, 0.12), light, 0.4)

		# ---------- sardas, pintas, idade ----------
		var fr := 1.0 if marks.has("sardas") else 0.4 if marks.has("sardas_leves") else 0.0
		if fr > 0:
			var r := FaceResolver.Rng.new(int(f.get("seed", 1)) * 13)
			for i in int(round(70 * fr)):
				var s := -1.0 if r.next() < 0.5 else 1.0
				var x := s * (0.08 + r.next() * 0.42)
				var y := 0.08 + r.next() * 0.3 + absf(x) * 0.1
				var a := 0.35 + r.next() * 0.35
				dot(x, y, maxf(0.6, S * (0.008 + r.next() * 0.008)), darken(skin, 0.32), a)
		var moleC := darken(skin, 0.45 if dk else 0.55)
		if marks.has("pinta_bochecha"):
			paint(func(): P.e(-0.42, 0.36, 0.018, 0.018), moleC, {"stroke": false})
		if marks.has("pinta_queixo"):
			paint(func(): P.e(0.12, chinY - 0.1, 0.016, 0.016), moleC, {"stroke": false})
		if marks.has("pinta_labio"):
			paint(func(): P.e(0.2, 0.52, 0.014, 0.014), moleC, {"stroke": false})
		var NZ: Dictionary = cat.noses.get(str(f.get("nose", {}).get("shape", "reto")), cat.noses.reto)
		var MO: Dictionary = cat.mouths.get(str(f.get("mouth", {}).get("shape", "neutra")), cat.mouths.neutra)
		if wrinkle > 0:
			var wa := wrinkle * 0.75
			for s: float in [-1.0, 1.0]:
				line(func(): P.m(s * (float(NZ.nw) + 0.06), 0.37); P.q(s * (float(NZ.nw) + 0.16), 0.5, s * (float(MO.w) + 0.06), 0.68), deep, 0.018, wa)
				line(func(): P.m(s * 0.44, 0.04); P.l(s * 0.52, 0); P.m(s * 0.44, 0.08); P.l(s * 0.52, 0.1), deep, 0.012, wa)
				line(func(): P.m(s * 0.2, 0.15); P.q(s * 0.3, 0.2, s * 0.41, 0.14), deep, 0.013, wa * 0.8)
			line(func(): P.m(-0.3, -0.45); P.q(0, -0.49, 0.3, -0.45), deep, 0.013, wa * 0.8)
			if wrinkle > 0.5:
				line(func(): P.m(-0.26, -0.37); P.q(0, -0.41, 0.26, -0.37), deep, 0.012, wa * 0.7)

		# ---------- barba ----------
		var bs := str(beard.get("style", "nenhuma"))
		if bs != "nenhuma" and not fem:
			var bp := func(fn: Callable, o: Dictionary = {}) -> void:
				var oo := {"ink": darken(beardC, 0.5), "lw": 0.8}
				oo.merge(o, true)
				paint(fn, beardC, oo)
			var full := func(ln: float = 0.15, top: float = 0.02) -> Callable:
				return func() -> void:
					P.m(-hw * 0.97, top); P.q(-hw * 1.01, 0.42, -jw - 0.03, 0.6); P.q(-cw - 0.14 - ln * 0.3, chinY + ln, 0, chinY + ln + 0.01); P.q(cw + 0.14 + ln * 0.3, chinY + ln, jw + 0.03, 0.6)
					P.q(hw * 1.01, 0.42, hw * 0.97, top); P.q(0.6, 0.4, 0.3, 0.46); P.l(0.2, 0.49); P.q(0, 0.44, -0.2, 0.49); P.l(-0.3, 0.46); P.q(-0.6, 0.4, -hw * 0.97, top); P.close()
			var must := func(): P.m(-0.26, 0.58); P.q(-0.2, 0.47, 0, 0.49); P.q(0.2, 0.47, 0.26, 0.58); P.q(0.13, 0.53, 0, 0.545); P.q(-0.13, 0.53, -0.26, 0.58); P.close()
			var pencil := func(): P.m(-0.2, 0.555); P.q(0, 0.5, 0.2, 0.555); P.q(0, 0.535, -0.2, 0.555); P.close()
			var chin_patch := func(wd: float = 0.2) -> Callable:
				return func(): P.m(-wd, 0.66); P.q(0, 0.64, wd, 0.66); P.q(wd, chinY + 0.1, 0, chinY + 0.11); P.q(-wd, chinY + 0.1, -wd, 0.66); P.close()
			var no_must := func() -> void:
				P.m(-hw * 0.97, 0.02); P.q(-hw * 1.01, 0.42, -jw - 0.03, 0.6); P.q(-cw - 0.16, chinY + 0.15, 0, chinY + 0.16); P.q(cw + 0.16, chinY + 0.15, jw + 0.03, 0.6); P.q(hw * 1.01, 0.42, hw * 0.97, 0.02)
				P.q(0.55, 0.55, 0.26, 0.7); P.q(0, 0.74, -0.26, 0.7); P.q(-0.55, 0.55, -hw * 0.97, 0.02); P.close()
			var chops := func(s: float) -> Callable:
				return func(): P.m(s * hw * 0.97, 0.0); P.q(s * hw * 1.0, 0.45, s * (jw - 0.02), 0.62); P.q(s * 0.4, 0.66, s * 0.3, 0.62); P.q(s * 0.45, 0.35, s * hw * 0.8, 0.0); P.close()
			var strap := func() -> void:
				P.m(-hw * 0.97, 0.02); P.q(-hw * 1.01, 0.42, -jw - 0.03, 0.6); P.q(-cw - 0.14, chinY + 0.1, 0, chinY + 0.11); P.q(cw + 0.14, chinY + 0.1, jw + 0.03, 0.6); P.q(hw * 1.01, 0.42, hw * 0.97, 0.02)
				P.l(hw * 0.88, 0.02); P.q(hw * 0.9, 0.4, jw - 0.06, 0.58); P.q(cw, chinY, 0, chinY - 0.02); P.q(-cw, chinY, -jw + 0.06, 0.58); P.q(-hw * 0.9, 0.4, -hw * 0.88, 0.02); P.close()
			match bs:
				"sombra": bp.call(full.call(), {"alpha": 0.17, "stroke": false})
				"por_fazer": bp.call(full.call(), {"alpha": 0.32, "stroke": false})
				"cheia_curta": bp.call(full.call(0.15))
				"cheia_longa": bp.call(full.call(0.42))
				"sem_bigode": bp.call(no_must)
				"cavanhaque": bp.call(chin_patch.call(0.17))
				"cavanhaque_bigode": bp.call(func(): P.m(-0.24, 0.52); P.q(0, 0.45, 0.24, 0.52); P.l(0.22, 0.64); P.q(0.2, chinY + 0.1, 0, chinY + 0.11); P.q(-0.2, chinY + 0.1, -0.22, 0.64); P.close())
				"ancora":
					bp.call(must)
					bp.call(func(): P.m(-0.24, 0.7); P.q(0, 0.76, 0.24, 0.7); P.q(0.12, chinY + 0.12, 0, chinY + 0.14); P.q(-0.12, chinY + 0.12, -0.24, 0.7); P.close())
				"bigode": bp.call(must)
				"bigode_fino": bp.call(pencil, {"lw": 0.5})
				"ferradura":
					bp.call(must)
					for s: float in [-1.0, 1.0]:
						bp.call(func(): P.m(s * 0.2, 0.53); P.l(s * 0.27, 0.55); P.l(s * 0.27, chinY - 0.02); P.l(s * 0.19, chinY - 0.02); P.close())
				"costeletas":
					for s: float in [-1.0, 1.0]:
						bp.call(chops.call(s))
				"contorno": bp.call(strap)
				"desenhada": bp.call(func() -> void:
					P.m(-hw * 0.97, 0.0); P.q(-hw * 1.01, 0.42, -jw - 0.03, 0.6); P.q(-cw - 0.14, chinY + 0.12, 0, chinY + 0.13); P.q(cw + 0.14, chinY + 0.12, jw + 0.03, 0.6); P.q(hw * 1.01, 0.42, hw * 0.97, 0)
					P.l(hw * 0.9, 0); P.l(0.34, 0.43); P.l(0.2, 0.49); P.q(0, 0.44, -0.2, 0.49); P.l(-0.34, 0.43); P.l(-hw * 0.9, 0); P.close())
				"longa_sem_bigode": bp.call(func() -> void:
					P.m(-hw * 0.97, 0.02); P.q(-hw * 1.01, 0.42, -jw - 0.03, 0.6); P.q(-cw - 0.25, chinY + 0.5, 0, chinY + 0.55); P.q(cw + 0.25, chinY + 0.5, jw + 0.03, 0.6); P.q(hw * 1.01, 0.42, hw * 0.97, 0.02)
					P.q(0.55, 0.55, 0.26, 0.7); P.q(0, 0.74, -0.26, 0.7); P.q(-0.55, 0.55, -hw * 0.97, 0.02); P.close())
				"bigode_grosso": bp.call(func(): P.m(-0.31, 0.61); P.q(-0.25, 0.43, 0, 0.455); P.q(0.25, 0.43, 0.31, 0.61); P.q(0.15, 0.545, 0, 0.56); P.q(-0.15, 0.545, -0.31, 0.61); P.close())
				"cavanhaque_longo": bp.call(func(): P.m(-0.24, 0.52); P.q(0, 0.45, 0.24, 0.52); P.l(0.22, 0.64); P.q(0.2, chinY + 0.1, 0.05, chinY + 0.35); P.l(-0.05, chinY + 0.35); P.q(-0.2, chinY + 0.1, -0.22, 0.64); P.close())
				"mosca": bp.call(func(): P.m(-0.05, 0.68); P.q(0, 0.66, 0.05, 0.68); P.l(0.035, 0.78); P.q(0, 0.8, -0.035, 0.78); P.close(), {"lw": 0.5})
				_: bp.call(full.call(0.15))  # barba nova do catálogo sem desenho próprio

		# ---------- cabelo: frente ----------
		if hs != "raspado":
			_front_hair(hs, hw, cr, topY, recede, nw, skin, hairC, hpaint, head, light)
		else:
			shade_in(head, func(): P.e(0, -0.75, hw * 0.8, 0.35), light, 0.22)

		# ---------- sobrancelhas e olhos ----------
		var EY: Dictionary = cat.eyes.get(str(f.get("eyes", {}).get("shape", "amendoado")), cat.eyes.amendoado)
		var BR: Dictionary = cat.brows.get(str(f.get("brows", {}).get("shape", "reta")), cat.brows.reta)
		var ey := 0.02
		var ex := 0.3
		var ew: float = float(EY.w)
		var eh: float = float(EY.h)
		var tilt: float = float(EY.tilt)
		var browC := mix(beardBase, hairC, 0.5)
		var mono: bool = EY.has("mono")
		for s: float in [-1.0, 1.0]:
			var by: float = -0.13 + float(BR.get("low", 0.0))
			var t: float = float(BR.t) * (0.8 if fem else 1.0)
			var ar: float = float(BR.arch)
			var scar_gap: bool = (s < 0 and marks.has("brow_l")) or (s > 0 and marks.has("brow_r"))
			var brow := func() -> void:
				P.m(s * (ex - 0.15), by + 0.03)
				if BR.has("angular"):
					P.l(s * (ex + 0.06), by - 0.05 - ar); P.l(s * (ex + 0.17), by + 0.02); P.l(s * (ex + 0.16), by + 0.02 + t * 0.6); P.l(s * (ex + 0.06), by - 0.05 - ar + t); P.l(s * (ex - 0.15), by + 0.03 + t)
				else:
					P.q(s * ex, by - 0.05 - ar, s * (ex + 0.17), by + 0.01); P.l(s * (ex + 0.16), by + 0.01 + t * 0.7); P.q(s * ex, by - 0.02 - ar + t, s * (ex - 0.15), by + 0.03 + t)
				P.close()
			paint(brow, browC, {"stroke": false})
			if BR.has("bushy"):
				for k in 6:
					var x := s * (ex - 0.12 + k * 0.05)
					line(func(): P.m(x, by + 0.03 + t * 0.8); P.l(x + s * 0.03, by - 0.03), browC, 0.012, 0.8)
			if scar_gap:
				line(func(): P.m(s * (ex + 0.07), by - 0.06); P.l(s * (ex + 0.05), by + 0.09), skin, 0.03, 1.0)
			if EY.has("deep"):
				shade_in(head, func(): P.e(s * ex, ey - eh * 1.6, ew * 1.3, eh * 1.5), deep, 0.35)
			var oc := ey - tilt
			var eye := func(): P.m(s * (ex - ew), ey); P.q(s * ex, ey - eh * (0.85 if mono else 1.05), s * (ex + ew), oc); P.q(s * ex, ey + eh * 0.72, s * (ex - ew), ey); P.close()
			paint(eye, mix(hx("#efe8de"), skin, 0.25), {"stroke": false})
			push_clip(eye)
			var ir: Color = hx(cat.iris.get(str(f.get("eyes", {}).get("iris", "escuro")), cat.iris.escuro))
			paint(func(): P.e(s * ex + s * 0.005, ey - tilt * 0.3, 0.047, 0.047), ir, {"stroke": false})
			paint(func(): P.e(s * ex + s * 0.005, ey - tilt * 0.3, 0.022, 0.022), hx("#0e0908"), {"stroke": false})
			paint(func(): P.e(s * ex + s * 0.016, ey - 0.017, 0.011, 0.011), Color.WHITE, {"stroke": false, "alpha": 0.8})
			_fill(_path(func(): P.e(s * ex, ey - eh, ew * 1.2, eh * 0.55)), hx("#1a110c"), 0.18)
			pop_clip()
			line(func(): P.m(s * (ex - ew), ey); P.q(s * ex, ey - eh * (0.85 if mono else 1.05), s * (ex + ew), oc), hx("#1a110c"), 0.025 if fem or mono else 0.02, 1.0)
			if fem:
				line(func(): P.m(s * (ex + ew), oc); P.l(s * (ex + ew + 0.035), oc - 0.028), hx("#1a110c"), 0.02, 1.0)
			if EY.has("crease"):
				line(func(): P.m(s * (ex - ew * 0.7), ey - eh * 1.25); P.q(s * ex, ey - eh * 2.0, s * (ex + ew * 0.95), oc - eh * 1.05), shade, 0.014, 0.55)
			if mono:
				line(func(): P.m(s * (ex - ew), ey + 0.004); P.q(s * (ex - ew * 0.8), ey - eh * 0.6, s * (ex - ew * 0.4), ey - eh * 0.85), shade, 0.012, 0.5)
			if EY.has("hood"):
				paint(func(): P.m(s * (ex - ew * 0.3), ey - eh * 1.35); P.q(s * (ex + ew * 0.6), ey - eh * 1.7, s * (ex + ew * 1.18), oc - eh * 0.05); P.q(s * (ex + ew * 0.45), ey - eh * 0.95, s * (ex - ew * 0.3), ey - eh * 1.35); P.close(), mix(skin, shade, 0.35), {"stroke": false})
			line(func(): P.m(s * (ex - ew * 0.8), ey + eh * 0.55); P.q(s * ex, ey + eh * 0.95, s * (ex + ew * 0.85), oc + eh * 0.4), shade, 0.012, 0.35 + wrinkle * 0.4)

		# ---------- nariz ----------
		var nose_cfg: Dictionary = f.get("nose", {})
		var nwd: float = float(NZ.nw) * (0.9 if fem else 1.0)
		var nby: float = 0.05 + float(NZ.len)
		var bw: float = float(NZ.bw)
		var brk: float = float(nose_cfg.get("broken", 0.0)) * 0.08 + (0.03 if NZ.has("flat") else 0.0)
		var fl: float = float(NZ.get("flare", 0.0))
		var bump: float = float(NZ.get("bump", 0.0))
		var tip: float = float(NZ.get("tip", 0.0))
		shade_in(head, func(): P.m(bw, -0.02); P.l(bw + brk + bump, nby * 0.45); P.l(nwd + fl + 0.02, nby - 0.03); P.l(0.02, nby); P.close(), shade, 0.4)
		line(func(): P.m(bw, -0.02); P.q(bw + bump * 2.2 + brk * 1.2, nby * 0.38, bw + brk + bump * 0.6, nby * 0.5); P.q(nwd * 0.85, nby - 0.1, nwd + fl * 0.5, nby - 0.05), deep, 0.02, 0.75)
		if NZ.has("flat"):
			line(func(): P.m(-bw * 1.1, 0.02); P.q(-bw * 1.4, nby * 0.4, -nwd * 0.8, nby - 0.08), deep, 0.016, 0.4)
		paint(func(): P.m(-nwd - fl, nby - 0.06); P.q(-nwd - fl - 0.05, nby + 0.02, -nwd * 0.45, nby + 0.025); P.q(0, nby + 0.05 + tip, nwd * 0.45, nby + 0.025); P.q(nwd + fl + 0.05, nby + 0.02, nwd + fl, nby - 0.06); P.q(0, nby - 0.04, -nwd - fl, nby - 0.06); P.close(), mix(skin, shade, 0.3), {"lw": 0.7})
		for s: float in [-1.0, 1.0]:
			line(func(): P.m(s * (nwd * 0.55), nby - 0.1); P.q(s * (nwd + fl + 0.04), nby - 0.08, s * (nwd + fl), nby), deep, 0.016, 0.55)
		var up_nose: bool = NZ.has("up")
		for s: float in [-1.0, 1.0]:
			paint(func(): P.e(s * nwd * 0.46, nby + 0.005, 0.04 if up_nose else 0.034, 0.028 if up_nose else 0.017), deep, {"stroke": false, "alpha": 0.85})
		var rnd: float = float(NZ.get("round", 1.0))
		shade_in(head, func(): P.e(0, nby - 0.045, 0.055 * rnd, 0.04 * rnd), light, 0.35)

		# ---------- boca ----------
		var mw: float = float(MO.w) * (0.95 if fem else 1.0)
		var up: float = float(MO.up) * (1.15 if fem else 1.0)
		var lo: float = float(MO.lo) * (1.12 if fem else 1.0)
		var my := 0.6 + float(head_cfg.get("chin", 0)) * 0.01
		var cv: float = float(MO.get("curve", 0.0))
		var sm: float = float(MO.get("smirk", 0.0))
		var bow: float = float(MO.get("bow", 0.01))
		var cyL := my - cv
		var cyR := my - cv - sm
		paint(func(): P.m(-mw, cyL); P.q(-mw * 0.6, my - up * 0.5, -mw * 0.3, my - up); P.q(-mw * 0.12, my - up, 0, my - up + bow); P.q(mw * 0.12, my - up, mw * 0.3, my - up); P.q(mw * 0.6, my - up * 0.5, mw, cyR); P.q(0, my + 0.012, -mw, cyL); P.close(), mix(lipC, shade, 0.25), {"stroke": false, "alpha": 0.92})
		paint(func(): P.m(-mw * 0.8, my + 0.012); P.q(0, my + lo * 1.9, mw * 0.8, my + 0.012 - sm * 0.5); P.q(0, my + 0.022, -mw * 0.8, my + 0.012); P.close(), lipC, {"stroke": false, "alpha": 0.78})
		shade_in(head, func(): P.e(0, my + lo * 0.9, mw * 0.35, lo * 0.35), light, 0.18)
		line(func(): P.m(-mw, cyL); P.q(0, my + 0.022, mw, cyR), darken(lipC, 0.55), 0.022, 1.0)
		line(func(): P.m(-0.08, my + 0.15 + lo * 0.4); P.q(0, my + 0.165 + lo * 0.4, 0.08, my + 0.15 + lo * 0.4), shade, 0.02, 0.5)

		# ---------- cicatrizes e tatuagem de rosto ----------
		var scarC := mix(skin, hx("#b88a7e" if dk else "#f2c7bd"), 0.55)
		var scars := {
			"brow_l": [-0.38, -0.24, -0.29, -0.07], "brow_r": [0.38, -0.24, 0.29, -0.07],
			"cheek_l": [-0.44, 0.18, -0.56, 0.36], "cheek_r": [0.44, 0.18, 0.56, 0.36],
			"lip": [0.08, my - 0.09, 0.11, my + 0.06], "nose": [-0.06, 0.08, 0.07, 0.12]}
		for key: String in scars:
			if marks.has(key):
				var v: Array = scars[key]
				line(func(): P.m(v[0], v[1]); P.l(v[2], v[3]), scarC, 0.022, 0.95)
		if marks.has("chin"):
			line(func(): P.m(-0.08, chinY - 0.05); P.q(0, chinY - 0.02, 0.09, chinY - 0.06), scarC, 0.022, 0.95)
		if marks.has("temple"):
			for k in 3:
				line(func(): P.m(-hw * 0.86 + k * 0.035, -0.4 + k * 0.07); P.l(-hw * 0.72 + k * 0.02, -0.36 + k * 0.07), tc, 0.018, 0.85)

		# ---------- pós-luta ----------
		if opts.get("post", false):
			var pr := FaceResolver.Rng.new(int(f.get("seed", 1)) * 3)
			var side := 1.0 if pr.next() > 0.5 else -1.0
			shade_in(head, func(): P.e(side * 0.32, 0.13, 0.17, 0.09), hx("#6c2f4f"), 0.5 if dk else 0.38)
			shade_in(head, func(): P.e(side * 0.36, 0.1, 0.1, 0.06), hx("#b04257"), 0.3)
			shade_in(head, func(): P.e(-side * 0.5, 0.34, 0.13, 0.09), hx("#6c3a55"), 0.36 if dk else 0.28)
			line(func(): P.m(-side * 0.27, -0.23); P.l(-side * 0.4, -0.19), hx("#9e1f26"), 0.03, 1.0)

	func _front_hair(hs: String, hw: float, cr: float, topY: float, rec: float, nw: float, skin: Color, hairC: Color, hpaint: Callable, head: Callable, light: Color) -> void:
		var hl := -0.56 + rec * 0.28
		var cyc := hl - rec * 0.18 + 0.02
		var vol_by := {"maquina": 0, "degrade_baixo": .02, "degrade_alto": .02, "militar": .03, "curto": .06, "risca": .06, "topete": .05, "para_tras": .03, "franja": .07, "nago": .01, "box_braids": .02, "coque": .02, "coque_masc": .02, "rabo": .02, "longo_liso": .05, "longo_ondulado": .06, "cacheado_longo": .1, "mullet": .05, "afro_curto": .12, "black_power": .2, "twists": .06, "dreads_curtos": .05, "dreads_longos": .05, "cacheado_curto": .05, "moicano": 0, "fauxhawk": .02, "coroa": .02, "quiff": .02, "franja_longa": .04, "cogumelo": .05, "ombro": .05, "ondulado_medio": .06, "cachos_volumosos": .14, "dreads_soltos": .04, "twists_altos": .02, "afro_puff": .01, "rabo_alto": .01, "coque_baguncado": .02, "curto_lateral": .05, "volumoso": .12, "trancas_laterais": .03, "undercut": .02, "mullet_moderno": .03, "crop_frances": .02, "espetado": .04, "degrade_risca": .02, "high_top": .02, "moicano_cacheado": 0, "dreads_presos": .04, "meio_coque": .03, "duas_trancas": .02, "tranca_unica": .02, "coque_baixo": .02, "pixie": .05, "undercut_lateral": .04}
		var vol: float = float(vol_by.get(hs, 0.05))
		var short_sides: bool = hs == "maquina" or hs.begins_with("degrade") or hs in ["undercut", "mullet_moderno", "crop_frances", "high_top", "moicano_cacheado", "espetado", "quiff", "twists_altos"]
		var sb := -0.05 if short_sides else 0.08
		var fringe := hs == "franja"
		var cap := func(hly: float = hl) -> Callable:
			return func() -> void:
				P.m(-hw * 1.3, sb); P.l(-hw * 0.95, sb); P.q(-hw * 0.9, -0.3, -hw * 0.72, -0.38)
				if fringe:
					P.q(-0.5, -0.3, -0.3, -0.28); P.l(-0.18, -0.34); P.l(-0.08, -0.27); P.l(0.05, -0.33); P.l(0.18, -0.27); P.l(0.32, -0.31); P.q(0.5, -0.3, hw * 0.72, -0.38)
				else:
					P.q(-0.5, cyc, -0.34, cyc); P.q(-0.12, hly - 0.03, 0, hly); P.q(0.12, hly - 0.03, 0.34, cyc); P.q(0.5, cyc, hw * 0.72, -0.38)
				P.q(hw * 0.9, -0.3, hw * 0.95, sb); P.l(hw * 1.3, sb); P.l(hw * 1.3, -2.2); P.l(-hw * 1.3, -2.2); P.close()
		var top_only := func(y: float) -> Callable:
			return func(): P.m(-2, y); P.l(2, y); P.l(2, -2.5); P.l(-2, -2.5); P.close()
		push_clip(func(): P.e(0, -0.27, hw + vol, cr + vol))
		var sides := func(a: float) -> void:
			paint(cap.call(), hairC, {"alpha": a, "stroke": false})
		var solid_top := func(y: float) -> void:
			push_clip(top_only.call(y))
			hpaint.call(cap.call(), {"stroke": false})
			pop_clip()
		match hs:
			"maquina": sides.call(0.72)
			"degrade_baixo": sides.call(0.5); solid_top.call(-0.55)
			"degrade_alto": sides.call(0.14); solid_top.call(-0.68)
			"militar": sides.call(0.5); solid_top.call(-0.6)
			"moicano": sides.call(0.1)
			"fauxhawk": sides.call(0.35)
			"undercut": sides.call(0.12)
			"quiff": sides.call(0.35); solid_top.call(-0.6)
			"twists_altos": sides.call(0.12)
			"mullet_moderno": sides.call(0.22); solid_top.call(-0.6)
			"crop_frances": sides.call(0.3); solid_top.call(-0.55)
			"espetado": sides.call(0.45); solid_top.call(-0.55)
			"degrade_risca": sides.call(0.14); solid_top.call(-0.68)
			"high_top": sides.call(0.1)
			"moicano_cacheado": sides.call(0.12)
			"undercut_lateral":
				push_clip(func(): P.m(-hw * 0.42, -3); P.l(3, -3); P.l(3, 3); P.l(-hw * 0.42, 3); P.close())
				hpaint.call(cap.call(), {"stroke": false})
				pop_clip()
				push_clip(func(): P.m(-hw * 0.42, -3); P.l(-3, -3); P.l(-3, 3); P.l(-hw * 0.42, 3); P.close())
				sides.call(0.14)
				pop_clip()
			"coroa":
				push_clip(func(): P.m(-2, -0.55 + rec * 0.1); P.l(-hw * 0.6, -0.55 + rec * 0.1); P.l(-hw * 0.6, 1); P.l(-2, 1); P.close(); P.m(2, -0.55 + rec * 0.1); P.l(hw * 0.6, -0.55 + rec * 0.1); P.l(hw * 0.6, 1); P.l(2, 1); P.close())
				hpaint.call(cap.call(-0.2), {"stroke": false})
				pop_clip()
			_:
				hpaint.call(cap.call())
		pop_clip()
		# detalhes por estilo
		var hl2 := lighten(hairC, 0.2)
		var hl22 := lighten(hairC, 0.22)
		if hs == "nago" or hs == "box_braids":
			for i in range(-3, 4):
				line(func(): P.m(i * 0.14, hl + 0.02); P.q(i * 0.2, -0.85, i * 0.12, topY - 0.02), hl2, 0.02, 0.8)
		if hs == "curto":
			for i in range(-2, 3):
				hpaint.call(func(): P.m(i * 0.14 - 0.07, hl - 0.02); P.l(i * 0.14, hl + 0.07); P.l(i * 0.14 + 0.07, hl - 0.02); P.close(), {"stroke": false})
		if hs == "cacheado_curto":
			var r := FaceResolver.Rng.new(int(f.get("seed", 1)))
			for i in 26:
				var a := PI * 1.08 + r.next() * PI * 0.84
				var rr := 0.85 + r.next() * 0.2
				hpaint.call(func(): P.e(cos(a) * hw * rr, -0.27 + sin(a) * cr * rr, 0.075, 0.075), {"lw": 0.6})
		if hs == "twists":
			for i in range(-4, 5):
				var x := i * 0.13
				var ai := absf(i)
				hpaint.call(func(): P.m(x - 0.045, topY + 0.25); P.l(x - 0.05, topY - 0.08 + ai * 0.03); P.q(x, topY - 0.14 + ai * 0.03, x + 0.05, topY - 0.08 + ai * 0.03); P.l(x + 0.045, topY + 0.25); P.close(), {"lw": 0.6})
		if hs == "risca":
			line(func(): P.m(-0.32, hl + 0.04); P.q(-0.36, -0.8, -0.3, topY + 0.05), lighten(skin, 0.1), 0.02, 0.9)
			hpaint.call(func(): P.m(-0.3, topY + 0.05); P.q(0.3, topY - 0.12, hw * 0.9, -0.62); P.q(0.3, -0.8, -0.3, -0.72); P.close(), {"stroke": false})
		if hs == "topete":
			hpaint.call(func(): P.m(-hw * 0.8, -0.6); P.q(-hw * 0.7, topY - 0.28, 0, topY - 0.3); P.q(hw * 0.75, topY - 0.26, hw * 0.82, -0.6); P.q(0, -0.45, -hw * 0.8, -0.6); P.close())
		if hs == "undercut" or hs == "mullet_moderno":
			hpaint.call(func(): P.m(-hw * 0.7, -0.5); P.q(-hw * 0.78, topY - 0.02, 0, topY - 0.08); P.q(hw * 0.78, topY - 0.02, hw * 0.7, -0.5); P.q(0, hl - 0.04, -hw * 0.7, -0.5); P.close())
		if hs == "undercut":
			for i in range(-2, 3):
				line(func(): P.m(i * 0.14, hl + 0.02); P.q(i * 0.17, -0.9, i * 0.1, topY - 0.04), hl22, 0.014, 0.5)
		if hs == "mullet_moderno" or hs == "espetado":
			for i in range(-3, 4):
				var x := i * 0.12
				var yb := topY + 0.06 + absf(i) * 0.04 if hs == "espetado" else hl - 0.02
				if hs == "espetado":
					hpaint.call(func(): P.m(x - 0.06, yb + 0.12); P.l(x + i * 0.03, yb - 0.16); P.l(x + 0.06, yb + 0.12); P.close(), {"stroke": false})
				else:
					hpaint.call(func(): P.m(x - 0.06, yb); P.l(x + 0.01, yb + 0.09); P.l(x + 0.06, yb); P.close(), {"stroke": false})
		if hs == "crop_frances":
			hpaint.call(func(): P.m(-0.42, -0.6); P.l(0.42, -0.6); P.l(0.4, -0.37); P.l(-0.4, -0.37); P.close(), {"stroke": false})
			for i in range(-3, 4):
				line(func(): P.m(i * 0.11, -0.39); P.l(i * 0.11 + 0.02, -0.46), darken(hairC, 0.35), 0.014, 0.8)
		if hs == "degrade_risca":
			line(func(): P.m(-hw * 0.82, -0.58); P.q(-hw * 0.6, -0.72, -hw * 0.25, -0.8), lighten(skin, 0.1), 0.022, 1.0)
		if hs == "high_top":
			hpaint.call(func(): P.m(-hw * 0.72, -0.55); P.l(-hw * 0.78, topY - 0.34); P.l(hw * 0.78, topY - 0.34); P.l(hw * 0.72, -0.55); P.q(0, hl - 0.02, -hw * 0.72, -0.55); P.close())
		if hs == "moicano_cacheado":
			var r := FaceResolver.Rng.new(int(f.get("seed", 1)))
			for i in 16:
				var t := i / 15.0
				var y := hl - 0.02 + (topY - 0.12 - hl) * t
				var dx := (r.next() - 0.5) * 0.22
				var dy := (r.next() - 0.5) * 0.05
				hpaint.call(func(): P.e(dx, y + dy, 0.085, 0.075), {"lw": 0.6})
		if hs == "dreads_presos":
			hpaint.call(func(): P.e(0, topY - 0.2, 0.3, 0.17))
			for i in range(-2, 3):
				line(func(): P.m(i * 0.16, hl + 0.02); P.q(i * 0.18, -0.85, i * 0.08, topY - 0.05), darken(hairC, 0.4), 0.02, 0.7)
		if hs == "meio_coque":
			hpaint.call(func(): P.e(0, topY - 0.03, 0.17, 0.12))
			line(func(): P.m(0, hl); P.l(0, topY + 0.02), lighten(skin, 0.1), 0.018, 0.8)
		if hs == "duas_trancas":
			for s: float in [-1.0, 1.0]:
				for k in 6:
					var t := k / 5.0
					var x: float = s * (0.14 + t * 0.2)
					var y := hl + 0.02 + (topY + 0.08 - hl) * t
					hpaint.call(func(): P.e(x, y, 0.085, 0.06), {"lw": 0.6})
		if hs == "tranca_unica" or hs == "coque_baixo":
			for i in range(-2, 3):
				line(func(): P.m(i * 0.16, hl + 0.03); P.q(i * 0.2, -0.9, i * 0.1 + 0.1, topY + 0.05), hl2, 0.015, 0.45)
		if hs == "pixie":
			hpaint.call(func(): P.m(-hw * 0.85, -0.28); P.q(-0.3, -0.5, 0.42, -0.42); P.q(0.1, -0.66, -hw * 0.8, -0.62); P.close())
		if hs == "undercut_lateral":
			hpaint.call(func(): P.m(-hw * 0.42, -0.62); P.q(0.1, topY - 0.1, hw * 0.85, -0.4); P.q(0.3, -0.55, -hw * 0.42, -0.62); P.close())
		if hs == "quiff":
			hpaint.call(func(): P.m(-hw * 0.72, -0.5); P.q(-hw * 0.62, topY - 0.16, 0.12, topY - 0.2); P.q(hw * 0.78, topY - 0.1, hw * 0.72, -0.5); P.q(0, hl - 0.08, -hw * 0.72, -0.5); P.close())
			for i in range(-2, 3):
				line(func(): P.m(i * 0.15 - 0.05, hl); P.q(i * 0.15, topY, i * 0.15 + 0.12, topY - 0.12), hl22, 0.015, 0.5)
		if hs == "franja_longa":
			hpaint.call(func() -> void:
				P.m(-hw * 1.0, 0.02); P.l(-hw * 0.97, -0.55); P.q(-hw * 0.82, topY - 0.06, 0, topY - 0.08); P.q(hw * 0.82, topY - 0.06, hw * 0.97, -0.55); P.l(hw * 1.0, 0.02)
				P.l(hw * 0.82, -0.06); P.l(hw * 0.72, -0.26); P.l(0.46, -0.17); P.l(0.31, -0.28); P.l(0.16, -0.18); P.l(0, -0.3); P.l(-0.16, -0.18); P.l(-0.31, -0.27); P.l(-0.46, -0.17); P.l(-hw * 0.72, -0.26); P.l(-hw * 0.82, -0.06); P.close())
		if hs == "cogumelo":
			hpaint.call(func(): P.m(-hw * 1.06, -0.04); P.q(-hw * 1.14, topY - 0.12, 0, topY - 0.12); P.q(hw * 1.14, topY - 0.12, hw * 1.06, -0.04); P.q(hw * 0.92, -0.2, 0.5, -0.25); P.q(0, -0.29, -0.5, -0.25); P.q(-hw * 0.92, -0.2, -hw * 1.06, -0.04); P.close())
		if hs == "ombro" or hs == "ondulado_medio":
			line(func(): P.m(0, hl); P.l(0, topY + 0.02), lighten(skin, 0.1), 0.018, 0.8)
			for s2 in [-1.0, 1.0]:
				hpaint.call(func(): P.m(s2 * 0.02, hl - 0.02); P.q(s2 * hw * 0.85, hl - 0.02, s2 * hw * 1.03, 0.35); P.l(s2 * hw * 0.9, 0.38); P.q(s2 * hw * 0.78, -0.1, s2 * 0.02, hl + 0.06); P.close(), {"stroke": false})
		if hs == "cachos_volumosos" or hs == "volumoso":
			var r := FaceResolver.Rng.new(int(f.get("seed", 1)) + 7)
			for i in 9:
				var x := -0.5 + i * 0.125
				var y := hl + 0.03 + r.next() * 0.05
				if hs == "volumoso":
					var jx := (r.next() - 0.5) * 0.1
					hpaint.call(func(): P.m(x - 0.08, y - 0.14); P.l(x + jx, y + 0.1); P.l(x + 0.08, y - 0.14); P.close(), {"stroke": false})
				else:
					hpaint.call(func(): P.e(x, y, 0.085, 0.075), {"lw": 0.6})
			if hs == "volumoso":
				for i in 9:
					var a := PI * 1.08 + i / 8.0 * PI * 0.84
					hpaint.call(func(): P.m(cos(a - 0.12) * hw * 1.08, -0.27 + sin(a - 0.12) * cr * 1.08); P.l(cos(a) * hw * 1.32, -0.27 + sin(a) * cr * 1.3); P.l(cos(a + 0.12) * hw * 1.08, -0.27 + sin(a + 0.12) * cr * 1.08); P.close(), {"stroke": false})
		if hs == "twists_altos":
			hpaint.call(func(): P.m(-hw * 0.62, -0.55); P.l(-hw * 0.68, topY - 0.3); P.q(0, topY - 0.37, hw * 0.68, topY - 0.3); P.l(hw * 0.62, -0.55); P.q(0, hl - 0.04, -hw * 0.62, -0.55); P.close())
			for i in range(-4, 5):
				line(func(): P.m(i * 0.1, hl); P.l(i * 0.1 + 0.01, topY - 0.3), lighten(hairC, 0.25), 0.018, 0.55)
		if hs == "coque_baguncado":
			hpaint.call(func(): P.e(0, topY - 0.16, 0.3, 0.24))
			var r := FaceResolver.Rng.new(int(f.get("seed", 1)))
			for i in 7:
				var a := PI * (1.1 + r.next() * 0.8)
				hpaint.call(func(): P.e(cos(a) * 0.3, topY - 0.16 + sin(a) * 0.24, 0.08, 0.07), {"lw": 0.5})
			for s2 in [-1.0, 1.0]:
				line(func(): P.m(s2 * hw * 0.7, -0.4); P.q(s2 * hw * 0.95, 0.0, s2 * hw * 0.85, 0.3), hairC, 0.03, 0.9)
		if hs == "rabo_alto":
			hpaint.call(func(): P.e(0, topY - 0.01, 0.2, 0.1))
		if hs == "rabo_alto" or hs == "afro_puff":
			for i in range(-2, 3):
				line(func(): P.m(i * 0.16, hl + 0.03); P.q(i * 0.18, -0.9, i * 0.05, topY + 0.03), hl22, 0.015, 0.45)
		if hs == "curto_lateral":
			hpaint.call(func(): P.m(hw * 0.85, -0.3); P.q(0.2, -0.52, -0.45, -0.4); P.q(-0.1, -0.7, hw * 0.8, -0.62); P.close())
		if hs == "trancas_laterais":
			for s2 in [-1.0, 1.0]:
				for k in 3:
					line(func(): P.m(s2 * (hw * 0.55 + k * 0.1), hl + 0.08 + k * 0.1); P.q(s2 * (hw * 0.62 + k * 0.1), -0.8, s2 * (0.3 + k * 0.08), topY + 0.1), hl22, 0.02, 0.8)
			var r := FaceResolver.Rng.new(int(f.get("seed", 1)))
			for i in 10:
				var x := (r.next() - 0.5) * 0.5
				var y := topY + 0.05 - r.next() * 0.12
				hpaint.call(func(): P.e(x, y, 0.1, 0.09), {"lw": 0.5})
		if hs == "dreads_soltos":
			for i in range(-3, 4):
				var x := i * 0.13
				hpaint.call(func(): P.m(x - 0.05, hl + 0.02); P.q(x + i * 0.05, -0.2, x + i * 0.08, 0.02); P.l(x + i * 0.08 + 0.08, 0.02); P.q(x + i * 0.05 + 0.06, -0.25, x + 0.05, hl + 0.02); P.close(), {"lw": 0.5})
		if hs == "moicano":
			hpaint.call(func(): P.m(-0.16, hl); P.l(-0.2, topY - 0.3); P.q(0, topY - 0.4, 0.2, topY - 0.3); P.l(0.16, hl); P.close())
		if hs == "fauxhawk":
			hpaint.call(func(): P.m(-0.36, hl); P.q(-0.3, topY - 0.1, 0, topY - 0.24); P.q(0.3, topY - 0.1, 0.36, hl); P.close())
		if hs in ["coque_masc", "para_tras", "rabo"]:
			for i in range(-2, 3):
				line(func(): P.m(i * 0.18, hl + 0.03); P.q(i * 0.2, -0.9, i * 0.1, topY + 0.04), hl2, 0.015, 0.45)
		if hs == "longo_liso" or hs == "longo_ondulado":
			line(func(): P.m(0, hl); P.l(0, topY + 0.02), lighten(skin, 0.1), 0.018, 0.8)
		if hs in ["curto", "franja", "afro_curto", "black_power", "longo_liso", "longo_ondulado", "cacheado_longo", "mullet", "topete", "risca", "coque", "coque_masc", "rabo", "para_tras"]:
			line(func(): P.m(-0.1, hl + 0.02); P.q(0.2, -0.82, 0.45, -0.97), lighten(hairC, 0.28), 0.024, 0.4)
