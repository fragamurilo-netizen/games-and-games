@tool
class_name PitchView
extends Control
## Campo 2D em coordenadas canônicas (a, b):
##   a = comprimento, 0 = gol do mandante → 1 = gol do visitante (o mandante ataca para a=1)
##   b = largura, 0 = lado esquerdo do mandante → 1 = lado direito
## Orientação vertical (escalação: ataque para cima) ou horizontal (partida: ataque para a direita).
## Modos: "lineup" (fichas tocáveis de um time → slot_tapped) e "match" (estádio, 22 jogadores,
## bola, árbitro e bandeirinhas, movidos pelo PitchMotion).
## Na partida, `swapped` espelha o desenho: no segundo tempo o mandante ataca para a esquerda.

signal slot_tapped(index: int)

@export_enum("lineup", "match") var mode: String = "lineup":
	set(v):
		mode = v
		queue_redraw()
@export var horizontal: bool = false:
	set(v):
		horizontal = v
		queue_redraw()

# --- Escalação ---
## [{x, y, number, name, rating, warn}] (x: 0 esq..1 dir, y: 0 próprio gol..1 gol adversário)
var chips: Array = []
var selected: int = -1
var chip_color: Color = Color("#1B3A8C")

# --- Partida ---
var home_slots: Array = [] # [{x, y, number, on, name, role, gk, c1?, c2?}]
var away_slots: Array = []
var home_color: Color = Color("#1B3A8C")
var home_color2: Color = Color.WHITE
var away_color: Color = Color("#B3122E")
var away_color2: Color = Color.WHITE
var motion: PitchMotion = PitchMotion.new()
## StadiumStyle.for_match(): {kind, night, rain, weather, fill, brands, away_share, seed}
var stadium: Dictionary = {}:
	set(v):
		stadium = v
		_crowd_tex = null
		queue_redraw()
## Telão/placar do estádio: {h, a, hs, as, clock}
var board: Dictionary = {}
var comp_accent: Color = Color("#FFC940")
var comp_bg: Color = Color("#0F1012")
var ref_color: Color = Color("#111111")
var ref_color2: Color = Color("#F5D547")
var highlight_side := -1
var highlight_slot := -1
var flash := 0.0
var flash_color := Color(1, 0.85, 0.3)
var net_shake := 0.0
var net_side := 1
var crowd_jump := 0.0
var crowd_side := 0
var smoke: Array = [] # [pos, cor, idade]
## Times trocados de lado (2º tempo e 2º tempo da prorrogação). Tudo continua em coordenadas
## canônicas; só a conversão para a tela espelha.
var swapped: bool = false:
	set(v):
		swapped = v
		_crowd_tex = null
		queue_redraw()
## Siglas mostradas no fundo de cada campo de defesa (quem defende aquele gol).
var home_label: String = ""
var away_label: String = ""
var _t := 0.0
var _crowd_tex: ImageTexture = null
var _crowd_size := Vector2.ZERO
var _fx_rng := RandomNumberGenerator.new()


func _ready() -> void:
	if mode == "lineup":
		mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		clip_contents = true
	set_process(mode == "match" and not Engine.is_editor_hint())
	_fx_rng.seed = 7


func _process(delta: float) -> void:
	_t += delta
	motion.update(delta)
	flash = maxf(0.0, flash - delta * 1.2)
	net_shake = maxf(0.0, net_shake - delta * 1.5)
	if motion.net_t > 0.0 and motion.net_hit >= 0:
		net_shake = maxf(net_shake, motion.net_t)
		net_side = motion.net_hit
	crowd_jump = maxf(0.0, crowd_jump - delta * 0.35)
	for sm in smoke:
		sm[2] += delta
	while not smoke.is_empty() and float(smoke[0][2]) > 4.0:
		smoke.pop_front()
	queue_redraw()


## Compatível com a versão anterior: a posse muda de lado e caminha para a profundidade.
func set_phase(side: int, depth: float, _lateral: float) -> void:
	motion.ambient(side, depth)


func goal_effect(side: int, color: Color) -> void:
	flash = 1.0
	flash_color = color
	net_shake = 1.0
	net_side = 1 if side == 0 else 0
	crowd_jump = 1.0
	crowd_side = side
	var kind := String(stadium.get("kind", ""))
	if kind == "caldeirao" or kind == "nacional" or (kind == "arena" and side == 0):
		var r := pitch_rect()
		for i in 7:
			var a := 0.08 + _fx_rng.randf() * 0.84
			var top := _fx_rng.randf() < 0.5
			var p := P(a, -0.12 if top else 1.12, r)
			smoke.append([p, color, _fx_rng.randf_range(-0.6, 0.0)])


func reset_kickoff() -> void:
	motion.kickoff(motion.poss, false)


# ---------------------------------------------------------------------------
# Geometria
# ---------------------------------------------------------------------------

func _margins() -> Vector2:
	if mode != "match" or stadium.is_empty():
		return Vector2.ZERO
	match String(stadium.get("kind", "arena")):
		"olimpico":
			return Vector2(0.1, 0.2)
		"acanhado":
			return Vector2(0.06, 0.13)
		"caldeirao":
			return Vector2(0.06, 0.14)
	return Vector2(0.055, 0.135)


func pitch_rect() -> Rect2:
	var aspect := 1.55 if horizontal else 0.74 # largura/altura na tela
	var m := _margins()
	var h := size.y / (1.0 + 2.0 * m.y)
	var w := h * aspect
	if w * (1.0 + 2.0 * m.x) > size.x:
		w = size.x / (1.0 + 2.0 * m.x)
		h = w / aspect
	return Rect2((size.x - w) * 0.5, (size.y - h) * 0.5, w, h)


## Canônico (a, b) → tela.
func P(a: float, b: float, r: Rect2) -> Vector2:
	if swapped and mode == "match":
		a = 1.0 - a
		b = 1.0 - b
	if horizontal:
		return r.position + Vector2(a * r.size.x, b * r.size.y)
	return r.position + Vector2(b * r.size.x, (1.0 - a) * r.size.y)


## Metros do motor → tela.
func M(p: Vector2, r: Rect2) -> Vector2:
	return P(p.x / PitchMotion.L, p.y / PitchMotion.W, r)


## Comprimento do campo em pixels (eixo a) e largura (eixo b).
func _len_px(r: Rect2) -> float:
	return r.size.x if horizontal else r.size.y


func _wid_px(r: Rect2) -> float:
	return r.size.y if horizontal else r.size.x


# ---------------------------------------------------------------------------
# Desenho
# ---------------------------------------------------------------------------

func _draw() -> void:
	var r := pitch_rect()
	var in_match := mode == "match" and not stadium.is_empty()
	if in_match:
		_draw_stadium(r)
	_draw_pitch(r)
	if mode == "lineup":
		_draw_chips(r)
	else:
		if in_match:
			_draw_shade(r)
		_draw_match(r)
		if in_match:
			_draw_weather()
	if flash > 0.0:
		draw_rect(r, Color(flash_color.r, flash_color.g, flash_color.b, flash * 0.25))


func _rect_ab(a0: float, b0: float, a1: float, b1: float, r: Rect2) -> Rect2:
	var p0 := P(a0, b0, r)
	var p1 := P(a1, b1, r)
	return Rect2(Vector2(minf(p0.x, p1.x), minf(p0.y, p1.y)), (p1 - p0).abs())


func _grass_colors() -> Array:
	var a := UIColors.PITCH_A
	var b := UIColors.PITCH_B
	if mode == "match" and not stadium.is_empty():
		match String(stadium.get("kind", "")):
			"arena", "nacional":
				a = Color("#2F8C50")
				b = Color("#287D45")
			"olimpico":
				a = Color("#35904F")
				b = Color("#2E8247")
			"caldeirao":
				a = Color("#2D7E4A")
				b = Color("#276F40")
			"acanhado":
				a = Color("#46803F")
				b = Color("#3F7638")
		if stadium.get("rain", false):
			a = a.darkened(0.12)
			b = b.darkened(0.12)
	return [a, b]


func _draw_pitch(r: Rect2) -> void:
	var gc := _grass_colors()
	var kind := String(stadium.get("kind", "")) if mode == "match" else ""
	var stripes := 12
	if kind == "arena" or kind == "nacional":
		stripes = 18
	elif kind == "acanhado":
		stripes = 10
	# Gramado além das linhas (até as placas).
	if kind != "":
		var run := _runoff(r)
		draw_rect(r.grow_individual(run.x, run.y, run.x, run.y), gc[1])
	for i in stripes:
		var a0 := float(i) / stripes
		var a1 := float(i + 1) / stripes
		draw_rect(_rect_ab(a0, 0.0, a1, 1.0, r).grow(0.5), gc[0] if i % 2 == 0 else gc[1])
	if kind == "olimpico":
		# Corte xadrez: faixas cruzadas.
		for j in 8:
			if j % 2 == 0:
				draw_rect(_rect_ab(0.0, float(j) / 8.0, 1.0, float(j + 1) / 8.0, r), Color(1, 1, 1, 0.035))
	elif kind == "acanhado":
		# Gramado gasto: terra na pequena área e no meio-campo.
		var worn := Color("#7A6A42")
		worn.a = 0.35
		for end in [0.03, 0.97]:
			var c := P(end, 0.5, r)
			draw_circle(c, _wid_px(r) * 0.07, worn)
			draw_circle(c + Vector2(0, _wid_px(r) * 0.05), _wid_px(r) * 0.04, worn)
		draw_circle(P(0.5, 0.5, r), _wid_px(r) * 0.06, Color(worn.r, worn.g, worn.b, 0.22))
		for k in 6:
			var h := absi(hash(k * 7919 + int(stadium.get("seed", 1))))
			var pa := P(0.1 + (h % 80) / 100.0, 0.1 + ((h / 100) % 80) / 100.0, r)
			draw_circle(pa, _wid_px(r) * (0.05 + (h % 5) * 0.01), Color(0.4, 0.45, 0.2, 0.12))
	var lc := UIColors.PITCH_LINE
	if kind == "arena" or kind == "nacional":
		lc = Color(0.95, 0.98, 0.95, 0.9)
	elif kind == "acanhado":
		lc = Color(0.9, 0.92, 0.85, 0.6)
	var lw := maxf(1.5, minf(r.size.x, r.size.y) * 0.006)
	draw_rect(r.grow(-lw * 0.5), lc, false, lw)
	draw_line(P(0.5, 0.0, r), P(0.5, 1.0, r), lc, lw)
	var center := P(0.5, 0.5, r)
	draw_arc(center, _wid_px(r) * 0.134, 0.0, TAU, 40, lc, lw, true)
	draw_circle(center, lw * 1.3, lc)
	for home_end in [true, false]:
		var a_goal := 0.0 if home_end else 1.0
		var dir := 1.0 if home_end else -1.0
		var box_d := 16.5 / 105.0
		var small_d := 5.5 / 105.0
		draw_rect(_rect_ab(a_goal, 0.203, a_goal + dir * box_d, 0.797, r), lc, false, lw)
		draw_rect(_rect_ab(a_goal, 0.365, a_goal + dir * small_d, 0.635, r), lc, false, lw)
		var spot := P(a_goal + dir * 11.0 / 105.0, 0.5, r)
		draw_circle(spot, lw * 1.2, lc)
		# Meia-lua
		var arc_r := _wid_px(r) * 0.134
		var base_angle := 0.0
		var near_end: bool = home_end != (swapped and mode == "match") # gol do lado esquerdo/de baixo da tela
		if horizontal:
			base_angle = 0.0 if near_end else PI
		else:
			base_angle = -PI / 2 if near_end else PI / 2
		draw_arc(spot, arc_r, base_angle - 0.93, base_angle + 0.93, 16, lc, lw, true)
		# Gol (com a rede tremendo após gol)
		var depth := 0.022
		var mine: bool = (home_end and net_side == 0) or (not home_end and net_side == 1)
		var shake := sin(_t * 70.0) * net_shake * 0.006 if mine else 0.0
		var g := _rect_ab(a_goal - dir * depth + shake, 0.446, a_goal + shake, 0.554, r)
		draw_rect(g, Color(1, 1, 1, 0.12 + (net_shake * 0.3 if mine else 0.0)))
		if mode == "match":
			# Malha da rede.
			var steps := 5
			for k in steps:
				var bb := 0.446 + (0.108 * (k + 0.5) / steps)
				draw_line(P(a_goal - dir * depth + shake, bb, r), P(a_goal, bb, r), Color(1, 1, 1, 0.22), 1.0)
		draw_rect(g, Color(1, 1, 1, 0.9), false, lw)
	if mode == "match" and kind != "":
		# Bandeirinhas de escanteio.
		for a in [0.0, 1.0]:
			for b in [0.0, 1.0]:
				var fp := P(a, b, r)
				draw_line(fp, fp + Vector2(0, -lw * 5), Color(0.95, 0.95, 0.95), 1.5)
				draw_colored_polygon(PackedVector2Array([fp + Vector2(0, -lw * 5), fp + Vector2(lw * 3.5, -lw * 4.2), fp + Vector2(0, -lw * 3.4)]), comp_accent)


# ---------------------------------------------------------------------------
# Estádio
# ---------------------------------------------------------------------------

## Faixa de grama além das linhas (px em x e y).
func _runoff(r: Rect2) -> Vector2:
	var kind := String(stadium.get("kind", "arena"))
	if kind == "olimpico":
		return Vector2(r.size.x * 0.022, r.size.y * 0.035)
	return Vector2(r.size.x * 0.03, r.size.y * 0.05)


## Retângulos concêntricos: gramado, pista, placas, alambrado e início das arquibancadas.
func _rings(r: Rect2) -> Dictionary:
	var run := _runoff(r)
	var grass := r.grow_individual(run.x, run.y, run.x, run.y)
	var kind := String(stadium.get("kind", "arena"))
	var track := grass
	if kind == "olimpico":
		var t := r.size.y * 0.1
		track = grass.grow(t)
	var bt := r.size.y * 0.032
	var boards := track.grow(bt)
	var fence := boards
	if kind == "caldeirao" or kind == "acanhado":
		fence = boards.grow(r.size.y * 0.022)
	var stands := fence.grow(r.size.y * 0.012)
	return {"grass": grass, "track": track, "boards": boards, "fence": fence, "stands": stands, "bt": bt}


func _draw_stadium(r: Rect2) -> void:
	var kind := String(stadium.get("kind", "arena"))
	var rings := _rings(r)
	var stands: Rect2 = rings["stands"]
	# Arquibancadas com a torcida (textura gerada uma vez por tamanho).
	if _crowd_tex == null or _crowd_size != size:
		_build_crowd(r, rings)
	draw_rect(Rect2(Vector2.ZERO, size), Color("#15171B"))
	if _crowd_tex != null:
		var jump := Vector2(0, -absf(sin(_t * 14.0)) * crowd_jump * 2.5)
		draw_texture_rect(_crowd_tex, Rect2(jump, size), false)
	# Bandeirões e sinalizadores (caldeirão e final).
	if kind == "caldeirao" or kind == "nacional":
		_draw_flags(r, stands)
	for sm in smoke:
		var age := float(sm[2])
		if age < 0.0:
			continue
		var c: Color = sm[1]
		var p: Vector2 = sm[0]
		var rad := r.size.y * (0.03 + age * 0.03)
		draw_circle(p + Vector2(age * 6.0, -age * 10.0), rad, Color(c.r, c.g, c.b, 0.35 * (1.0 - age / 4.0)))
		draw_circle(p, r.size.y * 0.012, Color(1.0, 0.45, 0.2, 0.9 * (1.0 - age / 4.0)))
	# Concreto entre a arquibancada e o campo.
	var fence: Rect2 = rings["fence"]
	var boards: Rect2 = rings["boards"]
	var track: Rect2 = rings["track"]
	draw_rect(stands, Color("#2A2C31") if kind != "acanhado" else Color("#5A5A55"))
	if kind == "caldeirao" or kind == "acanhado":
		_draw_fence(fence, boards)
	draw_rect(boards, Color("#101114"))
	if kind == "olimpico":
		_draw_track(track, rings["grass"])
	else:
		draw_rect(track, _grass_colors()[1])
	_draw_boards(boards, track, float(rings["bt"]), kind)
	if kind == "arena" or kind == "nacional":
		_draw_carpets(r, rings["grass"])
	_draw_dugouts(r, rings["grass"])
	_draw_big_screen(r, stands, kind)
	if kind != "arena":
		_draw_floodlights(stands, kind)


func _draw_track(track: Rect2, grass: Rect2) -> void:
	var tc := Color("#A8503A")
	draw_rect(track, tc)
	draw_rect(grass, _grass_colors()[1])
	var lanes := 6
	for i in range(1, lanes):
		var k := float(i) / lanes
		var rr := Rect2(grass.position.lerp(track.position, k), grass.size.lerp(track.size, k))
		draw_rect(rr, Color(1, 1, 1, 0.35), false, 1.0)


func _draw_fence(fence: Rect2, boards: Rect2) -> void:
	# Alambrado: tela de arame entre o campo e a torcida, com o poste e o cano de cima.
	var col := Color(0.82, 0.85, 0.88, 0.28)
	var step := 5.0
	var bands := [
		Rect2(fence.position, Vector2(fence.size.x, boards.position.y - fence.position.y)),
		Rect2(Vector2(fence.position.x, boards.end.y), Vector2(fence.size.x, fence.end.y - boards.end.y)),
		Rect2(fence.position, Vector2(boards.position.x - fence.position.x, fence.size.y)),
		Rect2(Vector2(boards.end.x, fence.position.y), Vector2(fence.end.x - boards.end.x, fence.size.y)),
	]
	for band: Rect2 in bands:
		if band.size.x <= 0.0 or band.size.y <= 0.0:
			continue
		draw_rect(band, Color(0.05, 0.06, 0.07, 0.55))
		var n := int((band.size.x + band.size.y) / step)
		for i in n:
			var o := i * step
			# Losangos da tela: duas famílias de diagonais recortadas na faixa.
			var a0 := Vector2(band.position.x + o, band.position.y)
			var a1 := a0 + Vector2(-band.size.y, band.size.y)
			_clip_line(a0, a1, band, col)
			var b0 := Vector2(band.position.x + o - band.size.y, band.position.y)
			var b1 := b0 + Vector2(band.size.y, band.size.y)
			_clip_line(b0, b1, band, col)
	draw_rect(fence, Color(0.75, 0.78, 0.8, 0.8), false, 1.5)
	# Postes.
	var posts := 14
	for i in posts + 1:
		var x := lerpf(fence.position.x, fence.end.x, float(i) / posts)
		draw_line(Vector2(x, fence.position.y), Vector2(x, boards.position.y), Color(0.7, 0.72, 0.75, 0.7), 1.5)
		draw_line(Vector2(x, boards.end.y), Vector2(x, fence.end.y), Color(0.7, 0.72, 0.75, 0.7), 1.5)


func _clip_line(a: Vector2, b: Vector2, box: Rect2, col: Color) -> void:
	# Recorte simples de segmento em retângulo (Liang–Barsky).
	var d := b - a
	var t0 := 0.0
	var t1 := 1.0
	var ps := [-d.x, d.x, -d.y, d.y]
	var qs := [a.x - box.position.x, box.end.x - a.x, a.y - box.position.y, box.end.y - a.y]
	for i in 4:
		var p: float = ps[i]
		var q: float = qs[i]
		if absf(p) < 0.0001:
			if q < 0.0:
				return
			continue
		var t := q / p
		if p < 0.0:
			t0 = maxf(t0, t)
		else:
			t1 = minf(t1, t)
	if t0 < t1:
		draw_line(a + d * t0, a + d * t1, col, 1.0)


func _draw_boards(boards: Rect2, inner: Rect2, bt: float, kind: String) -> void:
	var brands: Array = stadium.get("brands", [])
	if brands.is_empty():
		return
	var font := get_theme_font(&"font", &"Stat")
	var fs := int(clampf(bt * 0.62, 8.0, 22.0))
	var led := kind != "acanhado"
	var cycle := 7.0
	var shift := int(_t / cycle) if led else 0
	var fade := 1.0
	if led:
		var ph := fmod(_t, cycle)
		fade = clampf(minf(ph / 0.35, (cycle - ph) / 0.35), 0.0, 1.0)
	# Lados longos (cima e baixo) e fundos (esquerda e direita).
	var sides := [
		[Rect2(Vector2(inner.position.x, boards.position.y), Vector2(inner.size.x, inner.position.y - boards.position.y)), false, 0],
		[Rect2(Vector2(inner.position.x, inner.end.y), Vector2(inner.size.x, boards.end.y - inner.end.y)), false, 3],
		[Rect2(Vector2(boards.position.x, inner.position.y), Vector2(inner.position.x - boards.position.x, inner.size.y)), true, 5],
		[Rect2(Vector2(inner.end.x, inner.position.y), Vector2(boards.end.x - inner.end.x, inner.size.y)), true, 7],
	]
	for sd in sides:
		var band: Rect2 = sd[0]
		var vertical: bool = sd[1]
		var off: int = sd[2]
		var length := band.size.y if vertical else band.size.x
		var n := maxi(2, int(round(length / (bt * 7.5))))
		for i in n:
			var b: Dictionary = brands[(i + off + shift) % brands.size()]
			var seg: Rect2
			if vertical:
				seg = Rect2(band.position + Vector2(0, length * i / n), Vector2(band.size.x, length / n))
			else:
				seg = Rect2(band.position + Vector2(length * i / n, 0), Vector2(length / n, band.size.y))
			seg = seg.grow(-0.8)
			var bg := Color(String(b.get("c", "#1B1B1B")))
			var tx := Color(String(b.get("t", "#FFFFFF")))
			if not led:
				bg = bg.lerp(Color("#8C8C84"), 0.35)
				tx = tx.lerp(Color("#8C8C84"), 0.25)
			if stadium.get("night", false) and led:
				bg = bg.lightened(0.08)
			draw_rect(seg, bg.darkened(0.25 * (1.0 - fade)))
			if led:
				draw_line(seg.position, seg.position + Vector2(seg.size.x, 0) if not vertical else seg.position + Vector2(0, seg.size.y), Color(1, 1, 1, 0.18), 1.0)
			var txt := String(b.get("n", "")).to_upper()
			var tcol := Color(tx.r, tx.g, tx.b, fade)
			if vertical:
				var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				var maxw := seg.size.y - 4.0
				var f2 := fs if tw <= maxw else maxi(6, int(fs * maxw / tw))
				tw = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, f2).x
				var c := seg.get_center()
				draw_set_transform(c, -PI / 2.0 if seg.position.x < size.x * 0.5 else PI / 2.0, Vector2.ONE)
				draw_string(font, Vector2(-tw * 0.5, f2 * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, f2, tcol)
				draw_set_transform_matrix(Transform2D.IDENTITY)
			else:
				var tw2 := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				var maxw2 := seg.size.x - 4.0
				var f3 := fs if tw2 <= maxw2 else maxi(6, int(fs * maxw2 / tw2))
				tw2 = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, f3).x
				var c2 := seg.get_center()
				draw_string(font, c2 + Vector2(-tw2 * 0.5, f3 * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, f3, tcol)


## Tapetes de publicidade deitados na grama ao lado dos gols (estádios modernos).
func _draw_carpets(r: Rect2, grass: Rect2) -> void:
	var brands: Array = stadium.get("brands", [])
	if brands.is_empty():
		return
	var font := get_theme_font(&"font", &"Stat")
	var gap := r.position.x - grass.position.x
	if gap < 6.0:
		return
	var idx := 0
	for left in [true, false]:
		for top in [true, false]:
			var b: Dictionary = brands[idx % brands.size()]
			idx += 1
			var x := grass.position.x + 1.0 if left else r.end.x + 1.0
			var y0 := r.position.y + r.size.y * (0.2 if top else 0.62)
			var rr := Rect2(Vector2(x, y0), Vector2(gap - 2.0, r.size.y * 0.18))
			var bg := Color(String(b.get("c", "#1B1B1B")))
			draw_rect(rr, Color(bg.r, bg.g, bg.b, 0.85))
			var txt := String(b.get("n", "")).to_upper()
			var fs := int(clampf(gap * 0.55, 6.0, 16.0))
			var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			if tw > rr.size.y - 2.0:
				fs = maxi(5, int(fs * (rr.size.y - 2.0) / tw))
				tw = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_set_transform(rr.get_center(), -PI / 2.0 if left else PI / 2.0, Vector2.ONE)
			draw_string(font, Vector2(-tw * 0.5, fs * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(String(b.get("t", "#FFFFFF"))))
			draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_dugouts(r: Rect2, grass: Rect2) -> void:
	var y := grass.end.y - (grass.end.y - r.end.y) * 0.1
	var h := (grass.end.y - r.end.y) * 0.75
	if h < 3.0:
		return
	var w := r.size.x * 0.1
	for i in 2:
		var home_bench := i == 0
		var cx := r.position.x + r.size.x * (0.37 if (home_bench != swapped) else 0.63)
		var box := Rect2(Vector2(cx - w * 0.5, y - h), Vector2(w, h))
		var col := home_color if home_bench else away_color
		draw_rect(box, Color(0.08, 0.09, 0.1, 0.85))
		draw_rect(Rect2(box.position, Vector2(box.size.x, h * 0.35)), Color(col.r, col.g, col.b, 0.85))
		# Área técnica tracejada.
		var ta := Rect2(Vector2(cx - w * 0.7, r.end.y + 2.0), Vector2(w * 1.4, (y - h) - r.end.y - 3.0))
		if ta.size.y > 2.0:
			for k in 8:
				var x0 := ta.position.x + ta.size.x * k / 8.0
				draw_line(Vector2(x0, ta.position.y), Vector2(x0 + ta.size.x / 16.0, ta.position.y), Color(1, 1, 1, 0.45), 1.0)
	# Quarto árbitro entre os bancos.
	draw_rect(Rect2(Vector2(r.position.x + r.size.x * 0.5 - 3.0, y - h * 0.6), Vector2(6.0, h * 0.5)), ref_color2)


## Telão (estádios grandes) ou placar manual (estádio pequeno) com o placar do jogo.
func _draw_big_screen(r: Rect2, stands: Rect2, kind: String) -> void:
	if board.is_empty():
		return
	var font := get_theme_font(&"font", &"Stat")
	var left_room := stands.position.x
	var txt := "%s %d x %d %s" % [String(board.get("h", "")), int(board.get("hs", 0)), int(board.get("as", 0)), String(board.get("a", ""))]
	var clock := String(board.get("clock", ""))
	var fs := int(clampf(r.size.y * 0.045, 9.0, 18.0))
	var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var box: Rect2
	if left_room > tw * 0.6 + 16.0:
		var bw := minf(left_room - 10.0, tw + 14.0)
		box = Rect2(Vector2((left_room - bw) * 0.5, size.y * 0.5 - fs * 1.7), Vector2(bw, fs * 3.2))
	else:
		var top_room := stands.position.y
		if top_room < fs * 1.6:
			return
		var bh := minf(top_room - 4.0, fs * 1.5)
		box = Rect2(Vector2(r.position.x + r.size.x * 0.12, (top_room - bh) * 0.5), Vector2(tw + 14.0, bh))
	if kind == "acanhado":
		draw_rect(box, Color("#1F4D2B"))
		draw_rect(box, Color("#D9D2B4"), false, 2.0)
	else:
		draw_rect(box.grow(2.0), Color("#050505"))
		draw_rect(box, Color("#0B0D12"))
		draw_rect(Rect2(box.position, Vector2(box.size.x, 3.0)), comp_accent)
	var f2 := fs
	if tw > box.size.x - 6.0:
		f2 = maxi(7, int(fs * (box.size.x - 6.0) / tw))
		tw = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, f2).x
	var tcol := Color("#FFE9A8") if kind != "acanhado" else Color.WHITE
	var ty := box.position.y + box.size.y * (0.45 if box.size.y > f2 * 2.4 else 0.72)
	draw_string(font, Vector2(box.get_center().x - tw * 0.5, ty), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, f2, tcol)
	if box.size.y > f2 * 2.4 and clock != "":
		var cw := font.get_string_size(clock, HORIZONTAL_ALIGNMENT_LEFT, -1, f2).x
		draw_string(font, Vector2(box.get_center().x - cw * 0.5, ty + f2 * 1.2), clock, HORIZONTAL_ALIGNMENT_LEFT, -1, f2, comp_accent)


func _draw_floodlights(stands: Rect2, kind: String) -> void:
	var night: bool = stadium.get("night", false)
	var pts := [Vector2(6, 6), Vector2(size.x - 6, 6), Vector2(6, size.y - 6), Vector2(size.x - 6, size.y - 6)]
	for p: Vector2 in pts:
		var towards := (stands.get_center() - p).normalized()
		var head := p + towards * 10.0
		draw_line(p, head, Color(0.6, 0.62, 0.66), 3.0)
		draw_rect(Rect2(head - Vector2(6, 4), Vector2(12, 8)), Color(0.85, 0.87, 0.9) if night else Color(0.45, 0.47, 0.5))
		if night:
			for k in 3:
				draw_circle(head, 14.0 + k * 10.0, Color(1, 0.98, 0.85, 0.07))
	if kind == "acanhado":
		# Árvores e muro atrás de onde não há arquibancada já vêm na textura.
		pass


func _draw_flags(r: Rect2, stands: Rect2) -> void:
	# Bandeirões do mandante atrás dos gols (onde a arquibancada é maior) e nas laterais.
	var ends := [Rect2(Vector2(0, stands.position.y), Vector2(stands.position.x, stands.size.y)),
		Rect2(Vector2(stands.end.x, stands.position.y), Vector2(size.x - stands.end.x, stands.size.y))]
	var home_right := swapped # no 1º tempo a torcida do mandante fica atrás do gol da esquerda
	for i in 2:
		var e: Rect2 = ends[i]
		if e.size.x < 24.0:
			continue
		var mine := (i == 1) == home_right
		if not mine and String(stadium.get("kind", "")) != "nacional":
			continue
		var c1 := home_color if mine else away_color
		var c2 := home_color2 if mine else away_color2
		var w := e.size.x * 0.55
		var h := e.size.y * 0.3
		var fl := Rect2(Vector2(e.get_center().x - w * 0.5, e.position.y + e.size.y * 0.12), Vector2(w, h))
		var stripes := 5
		for k in stripes:
			var sy := fl.position.y + fl.size.y * k / stripes
			var wave := sin(_t * 2.6 + k * 0.9 + i) * 2.5
			var col := c1 if k % 2 == 0 else c2
			draw_rect(Rect2(Vector2(fl.position.x + wave, sy), Vector2(fl.size.x, fl.size.y / stripes + 0.5)), Color(col.r, col.g, col.b, 0.85))
	var h2 := stands.position.y
	if h2 < 8.0:
		return
	for i in 3:
		var x0 := r.position.x + r.size.x * (0.18 + i * 0.28)
		var fw := r.size.x * 0.12
		var top := i % 2 == 0
		var y0 := 2.0 if top else stands.end.y + 2.0
		var hh := (h2 - 4.0) if top else (size.y - stands.end.y - 4.0)
		if hh < 6.0:
			continue
		for k in 4:
			var col2 := home_color if k % 2 == 0 else home_color2
			var sx := x0 + fw * k / 4
			var wave2 := sin(_t * 3.0 + i + k * 0.7) * 2.0
			draw_rect(Rect2(Vector2(sx, y0 + wave2), Vector2(fw / 4 + 0.5, hh)), Color(col2.r, col2.g, col2.b, 0.9))


## Sombra da cobertura sobre parte do gramado (jogo de dia) ou brilho dos refletores (noite).
func _draw_shade(r: Rect2) -> void:
	var kind := String(stadium.get("kind", ""))
	if stadium.get("night", false):
		# Refletores: gramado um pouco mais claro no meio, cantos mais escuros.
		draw_rect(r.grow(-r.size.y * 0.12), Color(1, 1, 0.92, 0.035))
		return
	if kind == "arena" or kind == "caldeirao" or kind == "nacional":
		var sh := r.size.y * (0.3 if kind == "arena" else 0.2)
		draw_rect(Rect2(r.position, Vector2(r.size.x, sh)), Color(0, 0.02, 0.04, 0.16))


func _draw_weather() -> void:
	if not stadium.get("rain", false):
		return
	var n := 90
	for i in n:
		var x := fposmod(i * 97.31 + _t * 60.0, size.x)
		var y := fposmod(i * 57.17 + _t * 520.0 + i * i * 0.37, size.y)
		draw_line(Vector2(x, y), Vector2(x - 3.0, y + 11.0), Color(0.8, 0.88, 1.0, 0.22), 1.0)


## Textura da torcida: fileiras, setores, lugares vazios conforme o público, torcida visitante
## num canto e a cor do mandante predominando. Gerada em meia resolução.
func _build_crowd(r: Rect2, rings: Dictionary) -> void:
	_crowd_size = size
	var sc := 3
	var iw := maxi(8, int(size.x / sc))
	var ih := maxi(8, int(size.y / sc))
	var kind := String(stadium.get("kind", "arena"))
	var fill := float(stadium.get("fill", 0.8))
	var away_share := float(stadium.get("away_share", 0.1))
	var night: bool = stadium.get("night", false)
	var stands: Rect2 = rings["stands"]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(stadium.get("seed", 1)) * 13 + 5
	var inner := Rect2(stands.position / sc, stands.size / sc)
	var h1 := home_color
	var h2 := home_color2
	var a1 := away_color
	var a2 := away_color2
	var generic: Array[Color] = [Color("#1C1C1C"), Color("#E8E8E8"), Color("#3A3F4A"), Color("#C9A27E"), Color("#8A5A3C"), Color("#5B3A29"), Color("#D9C3A5")]
	var seat := Color("#2C3038")
	if kind == "arena":
		seat = h1.darkened(0.45) if h1.get_luminance() > 0.08 else Color("#3A3F48")
	elif kind == "olimpico":
		seat = Color("#3C4452")
	elif kind == "nacional":
		seat = comp_bg.lightened(0.1)
	var bytes := PackedByteArray()
	bytes.resize(iw * ih * 3)
	# Lado da torcida visitante: atrás do gol à direita da tela (vira no 2º tempo).
	var away_right := not swapped
	var cx := inner.get_center().x
	for y in ih:
		for x in iw:
			var col := Color("#15171B")
			var inside := inner.has_point(Vector2(x, y))
			if not inside:
				# Distância até o campo: fileiras e profundidade da arquibancada.
				var dx := maxf(inner.position.x - x, x - inner.end.x)
				var dy := maxf(inner.position.y - y, y - inner.end.y)
				var dist := maxf(dx, dy)
				var end_stand := dx > dy
				var has_stand := true
				if kind == "acanhado":
					# Só a arquibancada principal (embaixo) e um lance pequeno em cima.
					has_stand = (y > inner.end.y) or (y < inner.position.y and absf(x - cx) < inner.size.x * 0.3)
				if not has_stand:
					var tree := (hash(Vector2i(x / 6, y / 6)) % 5) == 0
					col = Color("#1E3A22") if tree else Color("#2B4A2C")
					if dist < 3.0:
						col = Color("#7A7468") # muro
				else:
					var row := int(dist) % 3 == 0
					var aisle := (int(x if not end_stand else y) % 23) == 0
					if aisle:
						col = Color("#3B3E44")
					elif row:
						col = seat.darkened(0.35)
					else:
						col = seat
						var p_fill := fill * (1.05 if kind == "caldeirao" else 1.0)
						if rng.randf() < p_fill:
							var away_zone := end_stand and ((x > cx) == away_right) and absf(y - inner.get_center().y) < inner.size.y * (away_share * 4.0)
							if kind == "nacional":
								away_zone = (x > cx) == away_right
							var k := rng.randf()
							if away_zone:
								col = a1 if k < 0.55 else (a2 if k < 0.8 else generic[rng.randi_range(0, generic.size() - 1)])
							else:
								var home_w := 0.55 if kind == "caldeirao" else 0.4
								col = h1 if k < home_w else (h2 if k < home_w + 0.18 else generic[rng.randi_range(0, generic.size() - 1)])
							# Gente vista de longe: cores apagadas, com fileiras mais escuras ao fundo.
							col = col.lerp(Color(0.08, 0.08, 0.1), rng.randf_range(0.25, 0.55) + minf(0.2, dist * 0.01))
					# Cobertura: a parte de trás fica na sombra.
					if (kind == "arena" or kind == "nacional") and dist > 10.0:
						col = col.darkened(0.35)
					if night:
						col = col.darkened(0.25)
			var i := (y * iw + x) * 3
			bytes[i] = int(clampf(col.r, 0.0, 1.0) * 255.0)
			bytes[i + 1] = int(clampf(col.g, 0.0, 1.0) * 255.0)
			bytes[i + 2] = int(clampf(col.b, 0.0, 1.0) * 255.0)
	var img := Image.create_from_data(iw, ih, false, Image.FORMAT_RGB8, bytes)
	_crowd_tex = ImageTexture.create_from_image(img)


# ---------------------------------------------------------------------------
# Escalação
# ---------------------------------------------------------------------------

func _draw_chips(r: Rect2) -> void:
	var font := get_theme_font(&"font", &"Stat")
	var small := get_theme_font(&"font", &"H3")
	var rad := _wid_px(r) * 0.058
	for i in chips.size():
		var ch: Dictionary = chips[i]
		var p := P(float(ch["y"]), float(ch["x"]), r)
		var col: Color = ch.get("color", chip_color)
		if i == selected:
			draw_circle(p, rad * 1.35, Color(1, 0.79, 0.25, 0.45))
		draw_circle(p + Vector2(0, 2), rad, Color(0, 0, 0, 0.35))
		draw_circle(p, rad, col)
		draw_arc(p, rad, 0.0, TAU, 32, Color(1, 1, 1, 0.85) if i != selected else UIColors.ACCENT, maxf(2.0, rad * 0.12), true)
		var num := str(ch.get("number", ""))
		var fs := int(rad * 0.95)
		var nw := font.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, p + Vector2(-nw * 0.5, fs * 0.36), num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UIColors.on_color(col))
		var rating: int = int(ch.get("rating", 0))
		if rating > 0:
			var rb := Rect2(p + Vector2(rad * 0.45, -rad * 1.25), Vector2(rad * 1.25, rad * 0.8))
			draw_rect(rb, Color(0.04, 0.045, 0.05, 0.9))
			var rs := str(rating)
			var rfs := int(rad * 0.6)
			var rw := font.get_string_size(rs, HORIZONTAL_ALIGNMENT_LEFT, -1, rfs).x
			draw_string(font, rb.position + Vector2((rb.size.x - rw) * 0.5, rb.size.y * 0.78), rs, HORIZONTAL_ALIGNMENT_LEFT, -1, rfs, Fmt.rating_color(rating))
		var nm: String = ch.get("name", "")
		var nfs := int(maxf(13.0, rad * 0.62))
		var tw := small.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs).x
		var bg := Rect2(p + Vector2(-tw * 0.5 - 6, rad + 3), Vector2(tw + 12, nfs * 1.25))
		draw_rect(bg, Color(0.04, 0.045, 0.05, 0.78))
		draw_string(small, p + Vector2(-tw * 0.5, rad + 3 + nfs * 0.98), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs, Color.WHITE if not ch.get("warn", false) else UIColors.ORANGE)


# ---------------------------------------------------------------------------
# Partida
# ---------------------------------------------------------------------------

func _draw_match(r: Rect2) -> void:
	var mm := motion
	var ppm := r.size.y / PitchMotion.W # pixels por metro
	var rad := clampf(ppm * 2.3, 7.0, 17.0)
	var font := get_theme_font(&"font", &"Stat")
	var small := get_theme_font(&"font", &"H3")
	var fs := int(rad * 1.0)
	var night: bool = stadium.get("night", false)
	_draw_end_labels(r, font, int(rad * 1.1))
	# Sombras primeiro (ficam por baixo de todos).
	for side in 2:
		for a: PitchMotion.Ag in mm.agents[side]:
			if a.on:
				_draw_shadow(M(a.pos, r), rad, night)
	_draw_shadow(M(mm.ref_pos, r), rad * 0.85, night)
	# Jogadores (quem está mais embaixo na tela por cima).
	var order: Array = []
	for side in 2:
		for a: PitchMotion.Ag in mm.agents[side]:
			if a.on:
				order.append(a)
	order.sort_custom(func(x: PitchMotion.Ag, y: PitchMotion.Ag): return M(x.pos, r).y < M(y.pos, r).y)
	for a: PitchMotion.Ag in order:
		var slots: Array = home_slots if a.side == 0 else away_slots
		var s: Dictionary = slots[a.idx] if a.idx < slots.size() else {}
		var c1: Color = s.get("c1", home_color if a.side == 0 else away_color)
		var c2: Color = s.get("c2", home_color2 if a.side == 0 else away_color2)
		_draw_player(a, M(a.pos, r), rad, c1, c2, font, fs)
	# Árbitro e bandeirinhas.
	_draw_official(M(mm.ref_pos, r), mm.ref_face, mm.ref_run, rad * 0.85, true)
	for i in 2:
		var ap: Vector2 = mm.ar_pos[i]
		var sp := M(ap, r)
		_draw_official(sp, Vector2(1, 0), 0.0, rad * 0.75, false)
		var up := float(mm.ar_flag[i]) > 0.0
		var fl := sp + (Vector2(0, -rad * 1.6) if up else Vector2(rad * 0.7, rad * 0.2))
		draw_line(sp, fl, Color(0.9, 0.9, 0.9), 1.5)
		draw_rect(Rect2(fl - Vector2(0, rad * 0.35), Vector2(rad * 0.7, rad * 0.5)), Color("#F5D547") if not up else Color("#E5484D"))
	if mm.whistle > 0.0:
		var rp := M(mm.ref_pos, r)
		draw_arc(rp, rad * (1.2 + (0.6 - mm.whistle) * 4.0), 0.0, TAU, 20, Color(1, 1, 1, mm.whistle), 1.5, true)
	if mm.ref_card > 0:
		var rp2 := M(mm.ref_pos, r)
		draw_rect(Rect2(rp2 + Vector2(rad * 0.4, -rad * 2.2), Vector2(rad * 0.7, rad)), Color("#F5D547") if mm.ref_card == 1 else Color("#E5484D"))
	if mm.ref_var > 0.0:
		var rp3 := M(mm.ref_pos, r)
		draw_rect(Rect2(rp3 + Vector2(-rad, -rad * 2.4), Vector2(rad * 2.0, rad * 1.3)), Color(1, 1, 1, 0.9), false, 1.5)
		var vw := font.get_string_size("VAR", HORIZONTAL_ALIGNMENT_LEFT, -1, int(rad * 0.8)).x
		draw_string(font, rp3 + Vector2(-vw * 0.5, -rad * 1.45), "VAR", HORIZONTAL_ALIGNMENT_LEFT, -1, int(rad * 0.8), Color.WHITE)
	# Rastro do chute e a bola (com altura: a sombra fica no chão).
	for tr in mm.trail:
		var tp := M(tr[0], r) - Vector2(0, float(tr[1]) * ppm * 0.8)
		draw_circle(tp, rad * 0.3 * (1.0 - float(tr[2]) / 0.35), Color(1, 1, 1, 0.35 * (1.0 - float(tr[2]) / 0.35)))
	var bp := M(mm.ball, r)
	var br := rad * 0.48 * (1.0 + mm.ball_h * 0.07)
	draw_circle(bp + Vector2(1.5, 2.0), rad * 0.45, Color(0, 0, 0, 0.35))
	var lift := Vector2(0, -mm.ball_h * ppm * 0.8)
	draw_circle(bp + lift, br, Color.WHITE)
	var ang := _t * mm.ball_spin * 0.6
	for k in 3:
		var o := Vector2(cos(ang + k * TAU / 3.0), sin(ang + k * TAU / 3.0)) * br * 0.5
		draw_circle(bp + lift + o, br * 0.26, Color(0.12, 0.12, 0.14))
	# Nome de quem está com a bola (como na transmissão).
	if mm.owner != null and mm.owner.on and mm.owner.name != "":
		var op := M(mm.owner.pos, r)
		var nfs := int(clampf(rad * 1.05, 11.0, 17.0))
		var tw := small.get_string_size(mm.owner.name, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs).x
		var bgr := Rect2(op + Vector2(-tw * 0.5 - 5, rad * 1.35), Vector2(tw + 10, nfs * 1.3))
		bgr.position.x = clampf(bgr.position.x, 2.0, size.x - bgr.size.x - 2.0)
		draw_rect(bgr, Color(0.03, 0.035, 0.04, 0.82))
		var tc := home_color if mm.owner.side == 0 else away_color
		if tc.get_luminance() < 0.15:
			tc = home_color2 if mm.owner.side == 0 else away_color2
		draw_rect(Rect2(bgr.position, Vector2(3, bgr.size.y)), tc)
		draw_string(small, bgr.position + Vector2(6, nfs * 1.02), mm.owner.name, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs, Color.WHITE)


func _draw_shadow(p: Vector2, rad: float, night: bool) -> void:
	if night:
		for o in [Vector2(-0.6, -0.5), Vector2(0.6, -0.5), Vector2(-0.6, 0.5), Vector2(0.6, 0.5)]:
			draw_circle(p + o * rad, rad * 0.85, Color(0, 0, 0, 0.1))
	else:
		draw_circle(p + Vector2(rad * 0.45, rad * 0.35), rad * 0.95, Color(0, 0, 0, 0.28))


func _draw_player(a: PitchMotion.Ag, p: Vector2, rad: float, c1: Color, c2: Color, font: Font, fs: int) -> void:
	var face := a.face
	if swapped:
		face = -face
	var perp := face.orthogonal()
	var spd := a.vel.length()
	var shorts := c2.darkened(0.35)
	if a.down > 0.0:
		# Caído no gramado: corpo deitado.
		var tip := p + perp * rad * 1.3
		draw_line(p - perp * rad * 0.9, tip, c1, rad * 1.1)
		draw_circle(tip, rad * 0.45, Color("#C9A27E"))
		if a.hurt > 0.0:
			var cp := p + Vector2(0, -rad * 2.0)
			draw_rect(Rect2(cp - Vector2(rad * 0.5, rad * 0.15), Vector2(rad, rad * 0.3)), Color.WHITE)
			draw_rect(Rect2(cp - Vector2(rad * 0.15, rad * 0.5), Vector2(rad * 0.3, rad)), Color("#E5484D"))
		return
	if a.dive > 0.0 and spd > 2.0:
		# Goleiro voando: corpo esticado na direção do salto.
		var dv := a.vel.normalized()
		if swapped:
			dv = -dv
		draw_line(p - dv * rad * 0.6, p + dv * rad * 1.6, c1, rad * 1.2)
		draw_circle(p + dv * rad * 1.7, rad * 0.45, c2)
		return
	# Pernas: passada alternada conforme a velocidade.
	var stride := sin(a.run * 3.2) * clampf(spd / 6.0, 0.0, 1.0) * rad * 0.75
	draw_circle(p + perp * rad * 0.38 + face * stride, rad * 0.36, shorts)
	draw_circle(p - perp * rad * 0.38 - face * stride, rad * 0.36, shorts)
	if a.arms > 0.0:
		var up := absf(sin(_t * 8.0 + a.idx)) * rad * 0.3
		draw_circle(p + perp * rad * 1.05 + face * up, rad * 0.3, c1)
		draw_circle(p - perp * rad * 1.05 + face * up, rad * 0.3, c1)
	draw_circle(p, rad, c1)
	draw_arc(p, rad, 0.0, TAU, 20, c2, maxf(1.5, rad * 0.2), true)
	# Cabeça (indica para onde está virado).
	draw_circle(p + face * rad * 0.62, rad * 0.3, c2.lerp(Color.BLACK, 0.2))
	if a.side == highlight_side and a.idx == highlight_slot:
		draw_arc(p, rad * 1.6, 0.0, TAU, 24, UIColors.ACCENT, 2.5, true)
	var num := str(a.number)
	var nw := font.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, p + Vector2(-nw * 0.5, fs * 0.36), num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UIColors.on_color(c1))
	if a.card > 0:
		draw_rect(Rect2(p + Vector2(rad * 0.6, -rad * 2.0), Vector2(rad * 0.65, rad * 0.9)), Color("#F5D547") if a.card == 1 else Color("#E5484D"))


func _draw_official(p: Vector2, face: Vector2, run: float, rad: float, main: bool) -> void:
	if swapped:
		face = -face
	var perp := face.orthogonal()
	if main:
		var stride := sin(run * 3.2) * rad * 0.5
		draw_circle(p + perp * rad * 0.38 + face * stride, rad * 0.34, Color("#111111"))
		draw_circle(p - perp * rad * 0.38 - face * stride, rad * 0.34, Color("#111111"))
	draw_circle(p, rad, ref_color)
	draw_arc(p, rad, 0.0, TAU, 16, ref_color2, maxf(1.2, rad * 0.22), true)


## Sigla de cada time junto ao gol que defende, com a cor do uniforme (mostra a troca de lado).
func _draw_end_labels(r: Rect2, font: Font, fs: int) -> void:
	for side in 2:
		var txt := home_label if side == 0 else away_label
		if txt == "":
			continue
		var col := home_color if side == 0 else away_color
		if col.get_luminance() < 0.12:
			col = home_color2 if side == 0 else away_color2
		var a_goal := 0.07 if side == 0 else 0.93
		var p := P(a_goal, 0.07, r)
		var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, p + Vector2(-tw * 0.5, fs * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col.r, col.g, col.b, 0.45))


func _gui_input(event: InputEvent) -> void:
	if mode != "lineup":
		return
	# Toques chegam como clique emulado (emulate_mouse_from_touch): tratamos só o mouse.
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return
	var r := pitch_rect()
	var best := -1
	var best_d := _wid_px(r) * 0.12
	for i in chips.size():
		var ch: Dictionary = chips[i]
		var d := P(float(ch["y"]), float(ch["x"]), r).distance_to(event.position)
		if d < best_d:
			best_d = d
			best = i
	if best >= 0:
		accept_event()
		slot_tapped.emit(best)
