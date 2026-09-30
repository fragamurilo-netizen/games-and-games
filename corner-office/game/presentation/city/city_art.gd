class_name CityArt
extends RefCounted
## Ilustração própria de cada cidade do universo (Game Design Bible §16).
## Pintada em código a partir de `art` em content/universe/geography.json:
## céu, sol/lua, montanhas, skyline, marco característico e água. Nada de foto;
## cada cidade tem a mesma imagem em todo aparelho (seed fixa).
## Uso: `CityArt.texture(city_id)` (cache em memória e em user://city_art).

const VERSION := 1
const DEFAULT_SIZE := Vector2i(640, 360)
const SUPERSAMPLE := 2

static var _textures := {}


static func texture(city_id: String, size: Vector2i = DEFAULT_SIZE) -> Texture2D:
	var key := "%s_%dx%d_v%d" % [city_id, size.x, size.y, VERSION]
	if _textures.has(key):
		return _textures[key]
	var path := "user://city_art/%s.png" % key
	var img: Image = null
	if FileAccess.file_exists(path):
		img = Image.load_from_file(path)
	if img == null or img.is_empty():
		var city := Universe.city(city_id)
		if city.is_empty():
			return null
		img = render(city, size)
		DirAccess.make_dir_recursive_absolute("user://city_art")
		img.save_png(path)
	var tex := ImageTexture.create_from_image(img)
	_textures[key] = tex
	return tex


static func render(city: Dictionary, size: Vector2i = DEFAULT_SIZE) -> Image:
	var art: Dictionary = city.get("art", {})
	var palettes: Dictionary = Universe.data("geography").get("art_palettes", {})
	var pal := {}
	for k: String in palettes.get(art.get("sky", "dusk"), {}):
		pal[k] = Color(palettes[art.get("sky", "dusk")][k])
	var p := _Painter.new(size * SUPERSAMPLE, int(art.get("seed", 1)), pal)
	p.paint(art)
	p.img.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
	return p.img


class _Painter:
	var img: Image
	var w: int
	var h: int
	var rng := RandomNumberGenerator.new()
	var pal: Dictionary
	var horizon: float
	var sky := ""

	func _init(size: Vector2i, seed_value: int, palette: Dictionary) -> void:
		w = size.x
		h = size.y
		rng.seed = seed_value
		pal = palette
		img = Image.create(w, h, false, Image.FORMAT_RGB8)

	# --- primitivas ----------------------------------------------------------
	func rect(x: float, y: float, rw: float, rh: float, c: Color) -> void:
		var r := Rect2i(int(x), int(y), maxi(1, int(rw)), maxi(1, int(rh))).intersection(Rect2i(0, 0, w, h))
		if r.size.x > 0 and r.size.y > 0:
			img.fill_rect(r, c)

	func poly(pts: PackedVector2Array, c: Color) -> void:
		var miny := h
		var maxy := 0
		for v in pts:
			miny = mini(miny, int(v.y))
			maxy = maxi(maxy, int(ceil(v.y)))
		miny = maxi(0, miny)
		maxy = mini(h, maxy)
		var n := pts.size()
		for y in range(miny, maxy):
			var yc := y + .5
			var xs: Array[float] = []
			for i in n:
				var a := pts[i]
				var b := pts[(i + 1) % n]
				if (a.y <= yc and b.y > yc) or (b.y <= yc and a.y > yc):
					xs.append(a.x + (yc - a.y) / (b.y - a.y) * (b.x - a.x))
			xs.sort()
			for k in range(0, xs.size() - 1, 2):
				rect(xs[k], y, xs[k + 1] - xs[k] + 1, 1, c)

	func circle(cx: float, cy: float, r: float, c: Color) -> void:
		for y in range(int(cy - r), int(cy + r) + 1):
			var dy := y + .5 - cy
			if absf(dy) > r:
				continue
			var dx := sqrt(r * r - dy * dy)
			rect(cx - dx, y, dx * 2, 1, c)

	func tri(ax: float, ay: float, bx: float, by: float, cx: float, cy: float, c: Color) -> void:
		poly(PackedVector2Array([Vector2(ax, ay), Vector2(bx, by), Vector2(cx, cy)]), c)

	func mix(a: String, b: String, t: float) -> Color:
		return (pal[a] as Color).lerp(pal[b], t)

	# --- cena ----------------------------------------------------------------
	func paint(art: Dictionary) -> void:
		sky = str(art.get("sky", "dusk"))
		var water: bool = art.get("water", false)
		horizon = h * (0.70 if water else 0.80)
		_sky()
		_sun()
		if art.get("mountains", false):
			_mountains(bool(art.get("snow", false)))
		if art.get("desert", false):
			_dunes()
		var density := float(art.get("density", .6))
		var height := float(art.get("height", .6))
		_skyline(mix("far", "horizon", .25), density * .8, height * .55, false)
		var lx := w * rng.randf_range(.30, .62)
		_landmark(str(art.get("landmark", "towers")), lx)
		_skyline(pal.near, density, height * .8, true, lx)
		if water:
			_water()
		else:
			rect(0, horizon, w, h - horizon, pal.ground)
		_arena()

	func _sky() -> void:
		var top: Color = pal.top
		var mid: Color = pal.mid
		var hor: Color = pal.horizon
		for y in int(horizon) + 2:
			var t := y / horizon
			var c := top.lerp(mid, t / .6) if t < .6 else mid.lerp(hor, (t - .6) / .4)
			rect(0, y, w, 1, c)
		if sky == "night":
			for i in 160:
				var s := rng.randf_range(1, 2.6)
				rect(rng.randf() * w, rng.randf() * horizon * .7, s, s, mix("sun", "top", rng.randf_range(.1, .6)))

	func _sun() -> void:
		var x := w * rng.randf_range(.12, .88)
		match sky:
			"night":
				var r := h * .05
				circle(x, h * .16, r, pal.sun)
				circle(x + r * .45, h * .16 - r * .2, r * .9, pal.top)
			"day":
				circle(x, h * .14, h * .05, pal.sun)
			_:
				var r2 := h * .11
				circle(x, horizon - r2 * .35, r2 * 1.35, mix("horizon", "sun", .35))
				circle(x, horizon - r2 * .35, r2, pal.sun)

	func _ridge(base: float, amp: float, step: float, c: Color) -> PackedVector2Array:
		var pts := PackedVector2Array([Vector2(0, horizon + 2)])
		var x := 0.0
		while x <= w + step:
			pts.append(Vector2(x, base - rng.randf_range(.2, 1.0) * amp))
			x += rng.randf_range(step * .6, step * 1.4)
		pts.append(Vector2(w, horizon + 2))
		poly(pts, c)
		return pts

	func _mountains(snow: bool) -> void:
		var far := _ridge(horizon, h * .34, w * .09, mix("far", "horizon", .55))
		if snow:
			for i in range(1, far.size() - 2):
				var v := far[i]
				if v.y < horizon - h * .22:
					tri(v.x - w * .025, v.y + h * .05, v.x, v.y, v.x + w * .025, v.y + h * .05, mix("sun", "horizon", .3))
		_ridge(horizon, h * .2, w * .07, mix("far", "near", .25))

	func _dunes() -> void:
		var sand := mix("horizon", "far", .45)
		for i in 3:
			var cx := w * rng.randf_range(0, 1)
			var rw := w * rng.randf_range(.3, .6)
			var pts := PackedVector2Array()
			for k in 17:
				var t := k / 16.0
				pts.append(Vector2(cx - rw / 2 + rw * t, horizon - sin(t * PI) * h * rng.randf_range(.05, .09)))
			pts.append(Vector2(cx + rw / 2, horizon + 2))
			pts.append(Vector2(cx - rw / 2, horizon + 2))
			poly(pts, sand)

	func _skyline(c: Color, density: float, height: float, lit: bool, gap_at: float = -1) -> void:
		var x := -rng.randf() * 30
		while x < w:
			var bw := w * rng.randf_range(.025, .07)
			var tall := rng.randf() < density * .35
			var bh := h * height * (rng.randf_range(.45, 1.0) if tall else rng.randf_range(.12, .4)) * rng.randf_range(.7, 1.0)
			if gap_at >= 0 and absf(x + bw / 2 - gap_at) < w * .15:
				bh *= .22  # abre espaço para o marco
			if rng.randf() < 1.0 - density * .4 and not tall:
				bh *= .6
			var top := horizon - bh
			rect(x, top, bw, bh + 2, c)
			if tall and rng.randf() < .35:
				rect(x + bw * .45, top - h * .04, maxf(2, bw * .08), h * .04, c)  # antena
			if tall and rng.randf() < .25:
				tri(x, top, x + bw / 2, top - bw * .5, x + bw, top, c)
			if lit:
				_windows(x, top, bw, bh)
			x += bw + rng.randf_range(0, w * .012)

	func _windows(x: float, top: float, bw: float, bh: float) -> void:
		var on: float = {"night": .55, "dusk": .35, "dawn": .25, "day": .0}.get(sky, .3)
		if on <= 0:
			for yy in range(int(top + 6), int(horizon - 4), 14):  # faixas de vidro de dia
				rect(x + 3, yy, bw - 6, 2, mix("near", "window", .35))
			return
		var cw := maxf(3, w * .004)
		var ch := maxf(4, h * .01)
		var yy := top + ch
		while yy < horizon - ch:
			var xx := x + cw
			while xx < x + bw - cw * 1.5:
				if rng.randf() < on:
					rect(xx, yy, cw, ch, mix("window", "near", rng.randf_range(0, .45)))
				xx += cw * 2.2
			yy += ch * 2
			if rng.randf() < .15:
				yy += ch * 2

	func _water() -> void:
		var top: Color = pal.water
		for y in range(int(horizon), h):
			var t := (y - horizon) / (h - horizon)
			rect(0, y, w, 1, top.lerp(pal.ground, t * .7))
		var glow := mix("sun", "water", .35)
		for i in 90:  # reflexos
			var y := rng.randf_range(horizon + 4, h)
			var seg := rng.randf_range(10, 60) * (1 - (y - horizon) / (h - horizon) * .5)
			rect(rng.randf() * w, y, seg, 2, glow if rng.randf() < .4 else mix("window", "water", .5))

	func _arena() -> void:
		# A arena da noite de luta, em primeiro plano: domo baixo e faixa de luz.
		var cx := w * (.14 if rng.randf() < .5 else .86)
		var aw := w * .2
		var base := horizon + (h - horizon) * .12
		var pts := PackedVector2Array()
		for k in 21:
			var t := k / 20.0
			pts.append(Vector2(cx - aw / 2 + aw * t, base - sin(t * PI) * h * .075))
		pts.append(Vector2(cx + aw / 2, base + h * .03))
		pts.append(Vector2(cx - aw / 2, base + h * .03))
		var body := mix("near", "far", .3)
		poly(pts, body)
		rect(cx - aw * .44, base - h * .014, aw * .88, h * .012, mix("window", "near", .1))
		for k in 9:  # portões iluminados
			rect(cx - aw * .4 + k * aw * .1, base + h * .006, aw * .04, h * .018, mix("window", "near", .3))
		rect(cx - aw * .6, base + h * .03, aw * 1.2, h * .012, pal.ground)
		for k in 3:  # canhões de luz da noite de luta
			var bx := cx + (k - 1) * aw * .25
			tri(bx - 2, base - h * .07, bx + 2, base - h * .07, bx + (k - 1) * w * .05, 0, mix("top", "sun", .12))

	# --- marcos --------------------------------------------------------------
	func _landmark(kind: String, x: float) -> void:
		var c := mix("near", "far", .6 if sky == "night" else .35)
		var s := h * .01
		match kind:
			"towers":
				for i in 3:
					var bw := w * rng.randf_range(.035, .05)
					var bh := h * rng.randf_range(.42, .58)
					var bx := x + (i - 1) * bw * 1.3
					rect(bx, horizon - bh, bw, bh, c)
					tri(bx, horizon - bh, bx + bw / 2, horizon - bh - bw * .8, bx + bw, horizon - bh, c)
					rect(bx + bw * .47, horizon - bh - bw * 1.6, 2, bw, c)
			"needle":
				rect(x - s * 1.2, horizon - h * .56, s * 2.4, h * .56, c)
				circle(x, horizon - h * .44, s * 4.5, c)
				rect(x - s * 3, horizon - h * .47, s * 6, s * 2, mix("window", "near", .3))
				rect(x - 1, horizon - h * .66, 3, h * .1, c)
				tri(x - s * 6, horizon, x, horizon - h * .15, x + s * 6, horizon, c)
			"clock":
				rect(x - s * 3, horizon - h * .45, s * 6, h * .45, c)
				tri(x - s * 3.6, horizon - h * .45, x, horizon - h * .56, x + s * 3.6, horizon - h * .45, c)
				circle(x, horizon - h * .39, s * 2.2, mix("window", "near", .15))
				rect(x - w * .12, horizon - h * .16, w * .24, h * .16, c)
			"lattice":
				poly(PackedVector2Array([Vector2(x - s * 9, horizon), Vector2(x - s, horizon - h * .55), Vector2(x + s, horizon - h * .55), Vector2(x + s * 9, horizon)]), c)
				tri(x - s * 4, horizon, x, horizon - h * .14, x + s * 4, horizon, pal.horizon.lerp(pal.near, .1))
				rect(x - s * 5, horizon - h * .2, s * 10, s, c)
				rect(x - s * 3, horizon - h * .36, s * 6, s, c)
				rect(x - 1, horizon - h * .63, 3, h * .08, c)
			"neon":
				for i in 4:
					var bw := w * .045
					var bh := h * (.3 + .08 * (i % 2))
					rect(x + (i - 2) * bw * 1.2, horizon - bh, bw, bh, c)
					rect(x + (i - 2) * bw * 1.2 + 3, horizon - bh + 6, bw - 6, 5, mix("sun", "window", .5))
				tri(x - w * .06, horizon, x, horizon - h * .28, x + w * .06, horizon, mix("near", "far", .5))
				rect(x - 1, 0, 3, horizon - h * .28, mix("sun", "top", .55))  # feixe
			"hills":
				for i in 3:
					var r := h * rng.randf_range(.16, .28)
					var hx := x + (i - 1) * r * 1.6
					poly(_hump(hx, r * 1.1, r * 1.3), mix("far", "near", .45))
					for k in 30:
						rect(hx + rng.randf_range(-r, r), horizon - rng.randf_range(0, r * .9), 3, 3, mix("window", "near", .2))
			"pyramid":
				for k in 6:
					var pw := w * .2 * (1 - k * .15)
					rect(x - pw / 2, horizon - h * .045 * (k + 1), pw, h * .045, c)
				rect(x - w * .015, horizon - h * .32, w * .03, h * .05, c)
			"cathedral":
				rect(x - w * .07, horizon - h * .2, w * .14, h * .2, c)
				for dx in [-1, 1]:
					var tx: float = x + dx * w * .055
					rect(tx - s * 2.2, horizon - h * .38, s * 4.4, h * .38, c)
					tri(tx - s * 2.6, horizon - h * .38, tx, horizon - h * .47, tx + s * 2.6, horizon - h * .38, c)
				tri(x - w * .07, horizon - h * .2, x, horizon - h * .28, x + w * .07, horizon - h * .2, c)
				circle(x, horizon - h * .15, s * 2, mix("window", "near", .2))
			"onion":
				for dx in [-2, -1, 0, 1, 2]:
					var tx: float = x + dx * w * .03
					var th := h * (.3 if dx == 0 else .22)
					rect(tx - s * 1.8, horizon - th, s * 3.6, th, c)
					circle(tx, horizon - th - s * 2, s * 2.8, c)
					tri(tx - s * 1.5, horizon - th - s * 3.5, tx, horizon - th - s * 8, tx + s * 1.5, horizon - th - s * 3.5, c)
			"dome", "minaret":
				rect(x - w * .08, horizon - h * .14, w * .16, h * .14, c)
				circle(x, horizon - h * .14, w * .06, c)
				rect(x - 1, horizon - h * .14 - w * .06 - s * 3, 3, s * 3, c)
				var n := 2 if kind == "minaret" else 1
				for i in n:
					for dx in [-1, 1]:
						var mx: float = x + dx * w * (.11 + .04 * i)
						rect(mx - s, horizon - h * .4, s * 2, h * .4, c)
						tri(mx - s * 1.3, horizon - h * .4, mx, horizon - h * .46, mx + s * 1.3, horizon - h * .4, c)
			"pagoda":
				for k in 5:
					var pw := w * .1 * (1 - k * .14)
					var py := horizon - h * .07 * (k + 1)
					rect(x - pw * .35, py, pw * .7, h * .07, c)
					poly(PackedVector2Array([Vector2(x - pw * .65, py + s), Vector2(x - pw * .4, py - s), Vector2(x + pw * .4, py - s), Vector2(x + pw * .65, py + s)]), c)
				rect(x - 1, horizon - h * .43, 3, h * .08, c)
			"sails":
				for i in 4:
					var sx := x + (i - 1.5) * w * .045
					var sh := h * (.16 + .03 * (i % 2))
					poly(PackedVector2Array([Vector2(sx - w * .04, horizon - h * .03), Vector2(sx + w * .015, horizon - sh), Vector2(sx + w * .03, horizon - h * .03)]), mix("horizon", "near", .25))
				rect(x - w * .12, horizon - h * .035, w * .24, h * .035, c)
			"flame":
				for i in 3:
					var fx := x + (i - 1) * w * .05
					var fh := h * (.42 if i == 1 else .34)
					var pts := PackedVector2Array()
					for k in 13:
						var t := k / 12.0
						pts.append(Vector2(fx - w * .022 * sin(t * PI * .9 + .2), horizon - fh * t))
					for k in range(12, -1, -1):
						var t := k / 12.0
						pts.append(Vector2(fx + w * .022 * sin(t * PI * .9 + .2), horizon - fh * t))
					poly(pts, c)
			"coliseum":
				rect(x - w * .13, horizon - h * .17, w * .26, h * .17, c)
				for row in 3:
					for k in 12:
						rect(x - w * .12 + k * w * .02, horizon - h * .16 + row * h * .052, w * .009, h * .03, mix("horizon", "near", .35))
			"temple":
				tri(x - w * .11, horizon - h * .2, x, horizon - h * .27, x + w * .11, horizon - h * .2, c)
				rect(x - w * .11, horizon - h * .21, w * .22, h * .02, c)
				for k in 8:
					rect(x - w * .1 + k * w * .028, horizon - h * .19, w * .012, h * .17, c)
				rect(x - w * .12, horizon - h * .02, w * .24, h * .02, c)
			"gables":
				for k in 7:
					var gx := x - w * .14 + k * w * .04
					var gh := h * rng.randf_range(.14, .22)
					rect(gx, horizon - gh, w * .038, gh, c)
					for st in 3:
						rect(gx + st * w * .006, horizon - gh - (st + 1) * s * 1.4, w * .038 - st * w * .012, s * 1.4, c)
			"bridge":
				var span := w * .5
				for dx in [-1, 1]:
					rect(x + dx * span / 4 - s, horizon - h * .3, s * 2, h * .3, c)
				for k in 41:
					var t := k / 40.0
					var bx := x - span / 2 + span * t
					var sag := absf(sin(t * 2 * PI)) * h * .22 if t > .25 and t < .75 else (absf(t - .25) if t <= .25 else absf(t - .75)) * h * .9
					rect(bx, horizon - h * .3 + (h * .22 - sag if t > .25 and t < .75 else sag), 2, 2, c)
				rect(x - span / 2, horizon - h * .06, span, s * .8, c)
			"palms":
				for i in 5:
					var px := x + (i - 2) * w * .05
					var ph := h * rng.randf_range(.16, .26)
					rect(px, horizon - ph, s * .9, ph, c)
					for a in 6:
						var ang := PI * (.1 + a * .16)
						tri(px, horizon - ph, px + cos(ang) * s * 7, horizon - ph + sin(-ang) * s * 2 + s * 3, px + cos(ang) * s * 6, horizon - ph + s * 4, c)
				rect(x - w * .16, horizon - h * .08, w * .32, h * .08, c)
			"bowl":
				rect(x - s * 1.6, horizon - h * .35, s * 3.2, h * .35, c)
				rect(x + s * 2.4, horizon - h * .35, s * 3.2, h * .35, c)
				poly(_hump(x - w * .1, w * .04, -h * .05), c)
				poly(_hump(x + w * .12, w * .04, h * .05), c)
				rect(x - w * .16, horizon - h * .06, w * .32, h * .06, c)

	func _hump(cx: float, rx: float, ry: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for k in 17:
			var t := k / 16.0
			pts.append(Vector2(cx - rx + 2 * rx * t, horizon - h * .1 - sin(t * PI) * ry))
		pts.append(Vector2(cx + rx, horizon))
		pts.append(Vector2(cx - rx, horizon))
		return pts
