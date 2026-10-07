class_name KitPattern
extends RefCounted
## Faixas dos padrões de camisa (coordenadas do uniforme, 0..1), usadas pela roupa do retrato
## (camisetas da equipe, cornermen). Copiado do KitView do Mais Uma Rodada.


static func tone_of(c: Color) -> Color:
	return c.lightened(0.16) if c.get_luminance() < 0.45 else c.darkened(0.14)


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
		"center_stripe_edged":
			out.append(_rect(0.415, 0, 0.03, 1))
			out.append(_rect(0.555, 0, 0.03, 1))
		"stripes_tri":
			for i in 3:
				out.append(_rect(0.225 + i * 0.19, 0, 0.075, 1))
		"twin_stripes":
			out.append(_rect(0.405, 0, 0.055, 1))
			out.append(_rect(0.54, 0, 0.055, 1))
		"tricolor_v":
			out.append(_rect(0.4167, 0, 0.1667, 1))
		"stripes_h":
			for i in 4:
				out.append(_rect(0, 0.22 + i * 0.19, 1, 0.09))
		"hoops_thin":
			for i in 8:
				out.append(_rect(0, 0.18 + i * 0.1, 1, 0.035))
		"hoops_pin":
			for i in 17:
				out.append(_rect(0, 0.1 + i * 0.05, 1, 0.012))
		"hoop_fade":
			for i in 8:
				out.append(_rect(0, 0.14 + i * 0.1, 1, 0.07 - i * 0.0075))
		"faixa":
			out.append(_rect(0, 0.36, 1, 0.14))
		"faixa_duo":
			out.append(_rect(0, 0.33, 1, 0.075))
		"double_band":
			out.append(_rect(0, 0.3, 1, 0.07))
			out.append(_rect(0, 0.43, 1, 0.07))
		"band_low":
			out.append(_rect(0, 0.62, 1, 0.12))
		"tricolor_h":
			out.append(_rect(0, 0.37, 1, 0.28))
		"diagonal":
			out.append(PackedVector2Array([Vector2(0.15, 0.05), Vector2(0.33, 0.05), Vector2(0.9, 0.95), Vector2(0.72, 0.95)]))
		"diagonal_rev":
			out.append(PackedVector2Array([Vector2(0.85, 0.05), Vector2(0.67, 0.05), Vector2(0.1, 0.95), Vector2(0.28, 0.95)]))
		"sash_thin":
			out.append(PackedVector2Array([Vector2(0.2, 0.05), Vector2(0.27, 0.05), Vector2(0.86, 0.95), Vector2(0.79, 0.95)]))
		"sash_double":
			out.append(PackedVector2Array([Vector2(0.14, 0.05), Vector2(0.2, 0.05), Vector2(0.79, 0.95), Vector2(0.73, 0.95)]))
			out.append(PackedVector2Array([Vector2(0.25, 0.05), Vector2(0.31, 0.05), Vector2(0.9, 0.95), Vector2(0.84, 0.95)]))
		"diagonal_split":
			out.append(PackedVector2Array([Vector2(0.9, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.2, 1.0)]))
		"halves":
			out.append(_rect(0.5, 0, 0.5, 1))
		"bottom_half":
			out.append(_rect(0, 0.55, 1, 0.5))
		"quarters":
			out.append(_rect(0, 0, 0.5, 0.5))
			out.append(_rect(0.5, 0.5, 0.5, 0.5))
		"chevron":
			out.append(PackedVector2Array([Vector2(0.2, 0.2), Vector2(0.5, 0.42), Vector2(0.8, 0.2), Vector2(0.8, 0.32), Vector2(0.5, 0.54), Vector2(0.2, 0.32)]))
		"v_big":
			out.append(PackedVector2Array([Vector2(0.24, 0.0), Vector2(0.36, 0.0), Vector2(0.5, 0.3), Vector2(0.64, 0.0), Vector2(0.76, 0.0), Vector2(0.5, 0.48)]))
		"side_panels":
			out.append(_rect(0.2, 0.25, 0.1, 0.8))
			out.append(_rect(0.7, 0.25, 0.1, 0.8))
		"center_panel":
			out.append(_rect(0.37, 0, 0.26, 1))
		"yoke":
			out.append(PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 0.24), Vector2(0.5, 0.3), Vector2(0, 0.24)]))
		"shoulder_band":
			out.append(_rect(0, 0.15, 1, 0.075))
		"cross":
			out.append(_rect(0.44, 0, 0.12, 1))
			out.append(_rect(0, 0.36, 1, 0.12))
		"saltire":
			out.append(PackedVector2Array([Vector2(0.18, 0.05), Vector2(0.27, 0.05), Vector2(0.82, 0.95), Vector2(0.73, 0.95)]))
			out.append(PackedVector2Array([Vector2(0.82, 0.05), Vector2(0.73, 0.05), Vector2(0.18, 0.95), Vector2(0.27, 0.95)]))
		"checkers":
			for iy in 10:
				for ix in 7:
					if (ix + iy) % 2 == 0:
						out.append(_rect(0.2 + ix * 0.086, iy * 0.1, 0.086, 0.1))
		"tartan":
			for i in 6:
				out.append(_rect(0.25 + i * 0.1, 0, 0.035, 1))
			for i in 9:
				out.append(_rect(0, 0.08 + i * 0.1, 1, 0.035))
		"harlequin":
			for j in 11:
				for i in 7:
					if (i + j) % 2 == 0:
						out.append(_diamond(Vector2(0.25 + i * 0.0833, 0.04 + j * 0.1), 0.0833, 0.1))
		"argyle":
			for j in 6:
				for i in 4:
					out.append(_diamond(Vector2(0.25 + i * 0.1667 + (0.0833 if j % 2 == 1 else 0.0), 0.08 + j * 0.18), 0.07, 0.09))
		"pixels":
			for iy in 20:
				for ix in 14:
					if (ix * 7 + iy * 3) % 5 == 0:
						out.append(_rect(0.2 + ix * 0.043, iy * 0.05, 0.043, 0.05))
		"triangles":
			for j in 9:
				var y0 := 0.06 + j * 0.1
				for i in 5:
					var x := 0.22 + i * 0.125 + (0.0625 if j % 2 == 1 else 0.0)
					out.append(PackedVector2Array([Vector2(x, y0 + 0.1), Vector2(x + 0.0625, y0), Vector2(x + 0.125, y0 + 0.1)]))
		"zigzag":
			for j in 5:
				out.append(_wave_band(0.2 + j * 0.16, 0.05, 0.03, false))
		"waves":
			for j in 5:
				out.append(_wave_band(0.2 + j * 0.16, 0.05, 0.03, true))
		"dots":
			for j in 13:
				for i in 8:
					out.append(_circle(Vector2(0.25 + i * 0.07 + (0.035 if j % 2 == 1 else 0.0), 0.1 + j * 0.068), 0.016, 8))
		"halftone":
			for j in 12:
				var rr := 0.003 + j * 0.0024
				for i in 12:
					out.append(_circle(Vector2(0.245 + i * 0.046 + (0.023 if j % 2 == 1 else 0.0), 0.4 + j * 0.046), rr, 6))
		"gradient":
			out.append(_rect(0, 0.62, 1, 0.4))
		"fade_up":
			out.append(_rect(0, 0.78, 1, 0.3))
		"brush":
			for j in 4:
				out.append(_brush_stroke(0.24 + j * 0.2, 0.06, j))
		"sunburst":
			var c := Vector2(0.5, 1.15)
			for i in 9:
				var a0 := -PI * 0.5 + (i - 4) * 0.16 - 0.04
				var a1 := a0 + 0.08
				out.append(PackedVector2Array([c, c + Vector2(cos(a0), sin(a0)) * 1.3, c + Vector2(cos(a1), sin(a1)) * 1.3]))
		"shatter":
			var rng := RandomNumberGenerator.new()
			rng.seed = 91
			for i in 16:
				var p := Vector2(rng.randf_range(0.25, 0.75), rng.randf_range(0.45, 0.95))
				var a := rng.randf() * TAU
				var l := rng.randf_range(0.05, 0.11)
				out.append(PackedVector2Array([p, p + Vector2(cos(a), sin(a)) * l, p + Vector2(cos(a + 0.5), sin(a + 0.5)) * l * 0.7]))
		"camo":
			var rng := RandomNumberGenerator.new()
			rng.seed = 37
			for i in 16:
				var cc := Vector2(rng.randf_range(0.22, 0.78), rng.randf_range(0.08, 0.95))
				var pts := PackedVector2Array()
				var base := rng.randf_range(0.035, 0.06)
				var ph := rng.randf() * TAU
				for k in 12:
					var a := k * TAU / 12.0
					var rr := base * (1.0 + 0.35 * sin(a * 3.0 + ph) + 0.2 * cos(a * 2.0 + ph * 1.7))
					pts.append(cc + Vector2(cos(a) * rr * 1.3, sin(a) * rr))
				out.append(pts)
		"topo":
			var cc := Vector2(0.62, 0.62)
			for k in 7:
				var rr := 0.05 + k * 0.065
				for seg in 28:
					var a0 := seg * TAU / 28.0
					var a1 := (seg + 1) * TAU / 28.0
					var w0 := rr * (1.0 + 0.08 * sin(a0 * 3.0 + k))
					var w1 := rr * (1.0 + 0.08 * sin(a1 * 3.0 + k))
					out.append(PackedVector2Array([cc + Vector2(cos(a0), sin(a0)) * w0, cc + Vector2(cos(a1), sin(a1)) * w1,
						cc + Vector2(cos(a1), sin(a1)) * (w1 + 0.012), cc + Vector2(cos(a0), sin(a0)) * (w0 + 0.012)]))
	return out


## Faixas da terceira cor (c3) das estampas tricolores.
static func pattern_bands3(pattern: String) -> Array:
	match pattern:
		"tricolor_v":
			return [_rect(0.5834, 0, 0.3, 1)]
		"tricolor_h":
			return [_rect(0, 0.65, 1, 0.4)]
		"stripes_tri":
			return [_rect(0.32, 0, 0.075, 1), _rect(0.51, 0, 0.075, 1), _rect(0.7, 0, 0.075, 1)]
		"faixa_duo":
			return [_rect(0, 0.425, 1, 0.075)]
		"center_stripe_edged":
			return [_rect(0.445, 0, 0.11, 1)]
	return []


static func _rect(x: float, y: float, w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)])


static func _diamond(c: Vector2, hw: float, hh: float) -> PackedVector2Array:
	return PackedVector2Array([c + Vector2(0, -hh), c + Vector2(hw, 0), c + Vector2(0, hh), c + Vector2(-hw, 0)])


static func _circle(c: Vector2, r: float, n: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		var a := i * TAU / n
		out.append(c + Vector2(cos(a), sin(a)) * r)
	return out


## Faixa horizontal ondulada (senoide) ou em zigue-zague.
static func _wave_band(y: float, h: float, amp: float, smooth: bool) -> PackedVector2Array:
	var top := PackedVector2Array()
	var n := 24 if smooth else 12
	for i in n + 1:
		var x := 0.2 + i * 0.6 / n
		var d: float
		if smooth:
			d = sin(i * TAU / 8.0) * amp
		else:
			d = amp if i % 2 == 0 else -amp
		top.append(Vector2(x, y + d))
	var out := top.duplicate()
	for i in range(n, -1, -1):
		out.append(top[i] + Vector2(0, h))
	return out


## Pincelada: faixa com bordas irregulares.
static func _brush_stroke(y: float, h: float, seed_i: int) -> PackedVector2Array:
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	for i in 21:
		var x := 0.18 + i * 0.032
		var n1 := sin(i * 1.7 + seed_i * 2.3) * 0.012 + sin(i * 4.1 + seed_i) * 0.006
		var n2 := sin(i * 2.3 + seed_i * 1.1) * 0.012 + cos(i * 3.7 + seed_i) * 0.006
		var taper := 1.0 - pow(absf(i - 10) / 10.0, 3.0) * 0.6
		top.append(Vector2(x, y + n1 - h * 0.5 * taper))
		bot.append(Vector2(x, y + n2 + h * 0.5 * taper))
	var out := top.duplicate()
	for i in range(bot.size() - 1, -1, -1):
		out.append(bot[i])
	return out


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
