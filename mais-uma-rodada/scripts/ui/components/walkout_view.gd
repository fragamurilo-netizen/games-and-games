class_name WalkoutView
extends Control
## Entrada dos times: as duas filas saem do túnel, sobem até o meio-campo e se perfilam, com o
## árbitro na frente. A arquibancada faz o ritual de cada lugar:
##   ucl        — bandeirão estrelado no círculo central (noite de Champions)
##   libertad   — papel picado e sinalizadores (Libertadores/Sul-Americana)
##   samba      — bandeirões do clube tremulando e fogos (Brasil)
##   hinchada   — papelitos, fumaça nas cores e o "banderazo" (Argentina e vizinhos)
##   terrace    — cachecóis erguidos (Inglaterra, Escócia...)
##   ultras     — mosaico (tifo) na curva e sinalizadores vermelhos (Itália, Turquia, Grécia...)
##   wall       — a muralha amarela (Dortmund) / arquibancada toda numa cor

var home_c1 := Color.WHITE
var home_c2 := Color.BLACK
var away_c1 := Color.RED
var away_c2 := Color.WHITE
var ritual := "terrace"
var night := false
var caption := ""
var _t := 0.0
var _seed := 1


static func make(h1: Color, h2: Color, a1: Color, a2: Color, rit: String, is_night: bool, cap: String, seed_value: int) -> WalkoutView:
	var v := WalkoutView.new()
	v.home_c1 = h1
	v.home_c2 = h2
	v.away_c1 = a1
	v.away_c2 = a2
	v.ritual = rit
	v.night = is_night
	v.caption = cap
	v._seed = seed_value
	v.custom_minimum_size = Vector2(0, 560)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v


## Ritual pela competição e pela torcida da casa.
static func ritual_for(w: GameWorld, comp: String, home: Club) -> String:
	if comp in ["UCL", "UEL", "UECL"]:
		return comp.to_lower()
	if comp in ["LIB", "SUD"]:
		return "libertad"
	if home.key == "GER_DOR":
		return "wall"
	var st := String(CrowdProfile.NATION_STYLE.get(home.nation, "terrace"))
	match st:
		"samba":
			return "samba"
		"hinchada":
			return "hinchada"
		"ultras":
			return "ultras"
	return "terrace"


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _ready() -> void:
	set_process(true)


func _draw() -> void:
	var w := size.x
	var h := size.y
	var stand_h := h * 0.34
	# Arquibancada
	var sky := Color("#0A0E18") if night else Color("#6E8FB3")
	draw_rect(Rect2(0, 0, w, stand_h), sky)
	_stands(Rect2(0, stand_h * 0.25, w, stand_h * 0.75))
	# Gramado em perspectiva
	var top := stand_h
	var tw := w * 0.8
	draw_colored_polygon(PackedVector2Array([Vector2((w - tw) * 0.5, top), Vector2((w + tw) * 0.5, top), Vector2(w, h), Vector2(0, h)]), Color("#1E6E3A") if not night else Color("#1A6134"))
	for k in 7:
		if k % 2 == 0:
			var y0 := lerpf(top, h, k / 7.0)
			var y1 := lerpf(top, h, (k + 1) / 7.0)
			var s0 := lerpf(tw, w, k / 7.0)
			var s1 := lerpf(tw, w, (k + 1) / 7.0)
			draw_colored_polygon(PackedVector2Array([Vector2((w - s0) * 0.5, y0), Vector2((w + s0) * 0.5, y0), Vector2((w + s1) * 0.5, y1), Vector2((w - s1) * 0.5, y1)]), Color(1, 1, 1, 0.04))
	var mid_y := lerpf(top, h, 0.42)
	draw_line(Vector2((w - lerpf(tw, w, 0.42)) * 0.5, mid_y), Vector2((w + lerpf(tw, w, 0.42)) * 0.5, mid_y), Color(1, 1, 1, 0.55), 2.0)
	_ellipse(Vector2(w * 0.5, mid_y), w * 0.16, h * 0.05, Color(1, 1, 1, 0.5))
	if ritual == "ucl":
		_starball(Vector2(w * 0.5, mid_y), w * 0.15, h * 0.045)
	elif ritual in ["uel", "uecl"]:
		var accent: Color = ScoreboardTheme.for_competition(null, ritual.to_upper())["accent"]
		var center := Vector2(w * 0.5, mid_y)
		_ellipse(center, w * 0.15, h * 0.045, UIColors.SURFACE)
		for side in [-1, 1]:
			var x: float = center.x + side * w * 0.05
			draw_colored_polygon(PackedVector2Array([Vector2(x, mid_y - h * 0.025), Vector2(x + side * w * 0.06, mid_y), Vector2(x, mid_y + h * 0.025), Vector2(x - side * w * 0.02, mid_y)]), accent)
	# Túnel
	var tun := Vector2(w * 0.5, h - 6.0)
	draw_rect(Rect2(tun.x - 46, tun.y - 34, 92, 40), Color(0.05, 0.05, 0.06))
	# Jogadores: 11 de cada lado, saem do túnel e se perfilam no meio-campo
	var line_y := lerpf(top, h, 0.52)
	for side in 2:
		for i in 11:
			var delay := i * 0.28
			var k := clampf((_t - delay) / 3.2, 0.0, 1.0)
			var e := k * k * (3.0 - 2.0 * k)
			var start := tun + Vector2((-14.0 if side == 0 else 14.0), -10.0)
			var file := Vector2(tun.x + (-30.0 if side == 0 else 30.0), line_y + 40.0)
			var target := Vector2(w * 0.5 + (-1.0 if side == 0 else 1.0) * (26.0 + (10 - i) * w * 0.036), line_y)
			var p: Vector2
			if e < 0.6:
				p = start.lerp(file, e / 0.6)
			else:
				p = file.lerp(target, (e - 0.6) / 0.4)
			if _t < delay:
				continue
			var sc := lerpf(0.75, 1.1, clampf((p.y - top) / (h - top), 0.0, 1.0))
			_figure(p, sc, home_c1 if side == 0 else away_c1, home_c2 if side == 0 else away_c2, i == 0)
	# Árbitro e bola na frente das filas
	var rk := clampf((_t - 0.1) / 3.0, 0.0, 1.0)
	var rp := (tun + Vector2(0, -16)).lerp(Vector2(w * 0.5, line_y + 26.0), rk * rk * (3.0 - 2.0 * rk))
	_figure(rp, 1.0, Color("#111111"), Color("#F5D547"), false)
	# Efeitos da torcida por cima
	_effects(Rect2(0, 0, w, h), stand_h)
	if caption != "":
		var f := get_theme_default_font()
		var fs := 20
		draw_rect(Rect2(UITokens.S3, h - 84, w - UITokens.S3 * 2, 66), Color(0, 0, 0, 0.6))
		draw_multiline_string(f, Vector2(UITokens.S4, h - 60), caption, HORIZONTAL_ALIGNMENT_CENTER, w - UITokens.S4 * 2, fs, 2, Color.WHITE)


func _stands(r: Rect2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	# Fileiras de torcedores nas cores do mandante
	var rows := 9
	for row in rows:
		var y := r.position.y + r.size.y * row / rows
		var n := 60
		for i in n:
			var x := r.size.x * (i + (row % 2) * 0.5) / n
			var c := home_c1 if rng.randf() < 0.55 else (home_c2 if rng.randf() < 0.5 else Color(0.25, 0.25, 0.3))
			if ritual == "wall":
				c = Color("#FDE100") if rng.randf() < 0.85 else Color("#111111")
			var bob := sin(_t * 6.0 + i * 0.7 + row) * (1.5 if ritual in ["samba", "hinchada", "ultras"] else 0.6)
			draw_rect(Rect2(x, y + bob, r.size.x / n - 1.5, r.size.y / rows - 2.0), c.darkened(0.2 if night else 0.0))
	if ritual == "ultras":
		# Mosaico: faixas diagonais nas cores do clube cobrindo a curva
		var mos := Rect2(r.position.x + r.size.x * 0.2, r.position.y, r.size.x * 0.6, r.size.y)
		for k in 8:
			var col := home_c1 if k % 2 == 0 else home_c2
			draw_rect(Rect2(mos.position.x + mos.size.x * k / 8.0, mos.position.y, mos.size.x / 8.0 + 1, mos.size.y), Color(col, 0.92))
		draw_circle(mos.get_center(), mos.size.y * 0.32, Color(home_c2, 0.95))
		draw_circle(mos.get_center(), mos.size.y * 0.22, Color(home_c1, 0.95))
	if ritual == "terrace":
		# Cachecóis erguidos: faixinhas balançando
		for i in 30:
			var x := r.size.x * (i + 0.5) / 30.0
			var y := r.position.y + r.size.y * 0.3 + sin(i * 1.3) * 8.0
			var sw := sin(_t * 3.0 + i) * 4.0
			draw_line(Vector2(x - 8, y + sw), Vector2(x + 8, y - sw), home_c1, 4.0)
			draw_line(Vector2(x - 2, y + sw * 0.3), Vector2(x + 2, y - sw * 0.3), home_c2, 4.0)
	if ritual in ["samba", "hinchada"]:
		# Bandeirões tremulando
		for k in 4:
			var cx := r.size.x * (0.15 + k * 0.23)
			var pts := PackedVector2Array()
			for j in 9:
				var fx := cx - 50.0 + j * 12.5
				pts.append(Vector2(fx, r.position.y + 6.0 + sin(_t * 4.0 + j * 0.8 + k) * 6.0))
			for j in range(8, -1, -1):
				var fx2 := cx - 50.0 + j * 12.5
				pts.append(Vector2(fx2, r.position.y + 62.0 + sin(_t * 4.0 + j * 0.8 + k + 0.6) * 6.0))
			draw_colored_polygon(pts, home_c1 if k % 2 == 0 else home_c2)


func _effects(r: Rect2, stand_h: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed * 7
	match ritual:
		"libertad", "hinchada":
			# Papel picado caindo e fumaça colorida
			for i in 160:
				var x := fposmod(rng.randf() * r.size.x + sin(_t + i) * 18.0, r.size.x)
				var y := fposmod(rng.randf() * r.size.y + _t * (40.0 + rng.randf() * 40.0), r.size.y)
				draw_rect(Rect2(x, y, 4, 3), Color(1, 1, 1, 0.85) if i % 3 != 0 else Color(home_c1, 0.9))
			for k in 5:
				var c := Vector2(r.size.x * (0.1 + k * 0.2), stand_h * 0.9)
				for j in 5:
					draw_circle(c + Vector2(sin(_t * 0.7 + j) * 20.0, -j * 16.0 - fposmod(_t * 12.0, 30.0)), 26.0 + j * 6.0, Color(home_c1 if k % 2 == 0 else home_c2, 0.1))
		"samba":
			# Fogos no céu
			for k in 3:
				var ph := fposmod(_t * 0.6 + k * 0.33, 1.0)
				var c := Vector2(r.size.x * (0.2 + k * 0.3), stand_h * 0.2)
				for j in 12:
					var a := TAU * j / 12.0
					draw_circle(c + Vector2(cos(a), sin(a)) * ph * 46.0, 2.5, Color(home_c1.lerp(Color.WHITE, 0.4), 1.0 - ph))
		"ultras":
			# Sinalizadores vermelhos na curva
			for k in 7:
				var c := Vector2(r.size.x * (0.08 + k * 0.14), stand_h * 0.55)
				var fl := 0.7 + sin(_t * 12.0 + k * 3.0) * 0.3
				draw_circle(c, 14.0 * fl, Color(1.0, 0.25, 0.1, 0.5))
				draw_circle(c, 6.0 * fl, Color(1.0, 0.85, 0.5, 0.9))
		"ucl":
			# Noite de gala: flashes de câmera na arquibancada
			for i in 20:
				if fposmod(_t * 2.3 + i * 0.61, 1.0) < 0.06:
					draw_circle(Vector2(fposmod(i * 97.0, r.size.x), stand_h * (0.3 + fposmod(i * 0.37, 0.6))), 3.0, Color(1, 1, 1, 0.9))


func _figure(p: Vector2, sc: float, c1: Color, c2: Color, captain: bool) -> void:
	var s := 9.0 * sc
	draw_rect(Rect2(p + Vector2(-s * 0.35, -s * 0.2), Vector2(s * 0.7, s * 1.1)), c2.darkened(0.2)) # calção/pernas
	draw_rect(Rect2(p + Vector2(-s * 0.55, -s * 1.3), Vector2(s * 1.1, s * 1.2)), c1) # camisa
	draw_circle(p + Vector2(0, -s * 1.75), s * 0.45, Color("#C99C7A")) # cabeça
	if captain:
		draw_rect(Rect2(p + Vector2(-s * 0.58, -s * 1.1), Vector2(s * 0.2, s * 0.3)), Color("#FFC940"))


func _ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 41:
		var a := TAU * i / 40.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_polyline(pts, col, 2.0)


func _starball(c: Vector2, rx: float, ry: float) -> void:
	var pts := PackedVector2Array()
	for i in 40:
		var a := TAU * i / 40.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, Color("#0B1E5B"))
	for i in 8:
		var a := TAU * i / 8.0
		var sp := c + Vector2(cos(a) * rx * 0.6, sin(a) * ry * 0.6)
		draw_circle(sp, 4.0, Color.WHITE)
