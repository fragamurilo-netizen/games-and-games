@tool
class_name PitchView
extends Control
## Campo 2D em coordenadas canônicas (a, b):
##   a = comprimento, 0 = gol do mandante → 1 = gol do visitante (o mandante ataca para a=1)
##   b = largura, 0 = lado esquerdo do mandante → 1 = lado direito
## Orientação vertical (escalação: ataque para cima) ou horizontal (partida: ataque para a direita).
## Modos: "lineup" (fichas tocáveis de um time → slot_tapped) e "match" (22 jogadores + bola).
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
var home_slots: Array = [] # [{x, y, number, on}]
var away_slots: Array = []
var home_color: Color = Color("#1B3A8C")
var home_color2: Color = Color.WHITE
var away_color: Color = Color("#B3122E")
var away_color2: Color = Color.WHITE
var ball := Vector2(0.5, 0.5) # canônico (a, b)
var ball_target := Vector2(0.5, 0.5)
var ball_speed := 1.4
var possession_side := 0
var push_home := 0.0
var push_away := 0.0
var _push_home_t := 0.0
var _push_away_t := 0.0
var highlight_side := -1
var highlight_slot := -1
var flash := 0.0
var flash_color := Color(1, 0.85, 0.3)
var net_shake := 0.0
var net_side := 1
## Times trocados de lado (2º tempo e 2º tempo da prorrogação). Tudo continua em coordenadas
## canônicas; só a conversão para a tela espelha.
var swapped: bool = false:
	set(v):
		swapped = v
		queue_redraw()
## Siglas mostradas no fundo de cada campo de defesa (quem defende aquele gol).
var home_label: String = ""
var away_label: String = ""
var _t := 0.0


func _ready() -> void:
	if mode == "lineup":
		mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(mode == "match" and not Engine.is_editor_hint())


func _process(delta: float) -> void:
	_t += delta
	ball = ball.move_toward(ball_target, ball_speed * delta)
	push_home = lerpf(push_home, _push_home_t, clampf(delta * 2.5, 0.0, 1.0))
	push_away = lerpf(push_away, _push_away_t, clampf(delta * 2.5, 0.0, 1.0))
	flash = maxf(0.0, flash - delta * 1.2)
	net_shake = maxf(0.0, net_shake - delta * 1.5)
	queue_redraw()


## Fase de jogo: lado com a bola, profundidade (0 próprio gol → 1 gol adversário) e posição lateral.
func set_phase(side: int, depth: float, lateral: float) -> void:
	possession_side = side
	var a := depth if side == 0 else 1.0 - depth
	var b := lateral if side == 0 else 1.0 - lateral
	ball_target = Vector2(clampf(a, -0.03, 1.03), clampf(b, 0.04, 0.96))
	var att_push := clampf((depth - 0.4) * 0.45, -0.08, 0.26)
	var def_push := clampf(-(depth - 0.35) * 0.3, -0.16, 0.06)
	if side == 0:
		_push_home_t = att_push
		_push_away_t = def_push
	else:
		_push_away_t = att_push
		_push_home_t = def_push


func goal_effect(side: int, color: Color) -> void:
	flash = 1.0
	flash_color = color
	net_shake = 1.0
	net_side = 1 if side == 0 else 0
	ball_target = Vector2(1.04 if side == 0 else -0.04, 0.5)


func reset_kickoff() -> void:
	ball = Vector2(0.5, 0.5)
	ball_target = ball
	_push_home_t = 0.0
	_push_away_t = 0.0


# ---------------------------------------------------------------------------
# Geometria
# ---------------------------------------------------------------------------

func pitch_rect() -> Rect2:
	var aspect := 1.55 if horizontal else 0.74 # largura/altura na tela
	var h := size.y
	var w := h * aspect
	if w > size.x:
		w = size.x
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
	_draw_pitch(r)
	if mode == "lineup":
		_draw_chips(r)
	else:
		_draw_match(r)
	if flash > 0.0:
		draw_rect(r, Color(flash_color.r, flash_color.g, flash_color.b, flash * 0.25))


func _rect_ab(a0: float, b0: float, a1: float, b1: float, r: Rect2) -> Rect2:
	var p0 := P(a0, b0, r)
	var p1 := P(a1, b1, r)
	return Rect2(Vector2(minf(p0.x, p1.x), minf(p0.y, p1.y)), (p1 - p0).abs())


func _draw_pitch(r: Rect2) -> void:
	var stripes := 12
	for i in stripes:
		var a0 := float(i) / stripes
		var a1 := float(i + 1) / stripes
		draw_rect(_rect_ab(a0, 0.0, a1, 1.0, r).grow(0.5), UIColors.PITCH_A if i % 2 == 0 else UIColors.PITCH_B)
	var lc := UIColors.PITCH_LINE
	var lw := maxf(1.5, minf(r.size.x, r.size.y) * 0.006)
	draw_rect(r.grow(-lw * 0.5), lc, false, lw)
	draw_line(P(0.5, 0.0, r), P(0.5, 1.0, r), lc, lw)
	var center := P(0.5, 0.5, r)
	draw_arc(center, _wid_px(r) * 0.14, 0.0, TAU, 40, lc, lw, true)
	draw_circle(center, lw * 1.3, lc)
	for home_end in [true, false]:
		var a_goal := 0.0 if home_end else 1.0
		var dir := 1.0 if home_end else -1.0
		var box_d := 0.15
		var small_d := 0.055
		draw_rect(_rect_ab(a_goal, 0.21, a_goal + dir * box_d, 0.79, r), lc, false, lw)
		draw_rect(_rect_ab(a_goal, 0.36, a_goal + dir * small_d, 0.64, r), lc, false, lw)
		var spot := P(a_goal + dir * 0.105, 0.5, r)
		draw_circle(spot, lw * 1.2, lc)
		# Meia-lua
		var arc_r := _wid_px(r) * 0.12
		var base_angle := 0.0
		var near_end: bool = home_end != (swapped and mode == "match") # gol do lado esquerdo/de baixo da tela
		if horizontal:
			base_angle = 0.0 if near_end else PI
		else:
			base_angle = -PI / 2 if near_end else PI / 2
		draw_arc(spot, arc_r, base_angle - 0.95, base_angle + 0.95, 16, lc, lw, true)
		# Gol (com a rede tremendo após gol)
		var depth := 0.022
		var shake := sin(_t * 70.0) * net_shake * 0.006 if (home_end and net_side == 0) or (not home_end and net_side == 1) else 0.0
		var g := _rect_ab(a_goal - dir * depth + shake, 0.42, a_goal + shake, 0.58, r)
		draw_rect(g, Color(1, 1, 1, 0.12 + net_shake * 0.3))
		draw_rect(g, Color(1, 1, 1, 0.9), false, lw)


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
			draw_rect(rb, Color(0.05, 0.08, 0.12, 0.9))
			var rs := str(rating)
			var rfs := int(rad * 0.6)
			var rw := font.get_string_size(rs, HORIZONTAL_ALIGNMENT_LEFT, -1, rfs).x
			draw_string(font, rb.position + Vector2((rb.size.x - rw) * 0.5, rb.size.y * 0.78), rs, HORIZONTAL_ALIGNMENT_LEFT, -1, rfs, Fmt.rating_color(rating))
		var nm: String = ch.get("name", "")
		var nfs := int(maxf(13.0, rad * 0.62))
		var tw := small.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs).x
		var bg := Rect2(p + Vector2(-tw * 0.5 - 6, rad + 3), Vector2(tw + 12, nfs * 1.25))
		draw_rect(bg, Color(0.05, 0.08, 0.12, 0.78))
		draw_string(small, p + Vector2(-tw * 0.5, rad + 3 + nfs * 0.98), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs, Color.WHITE if not ch.get("warn", false) else UIColors.ORANGE)


func _slot_ab(slot: Dictionary, side: int, idx: int) -> Vector2:
	var x := float(slot["x"])
	var y := float(slot["y"])
	var push := push_home if side == 0 else push_away
	y = clampf(y + push * (0.55 + 0.45 * y), 0.02, 0.97)
	var ball_lat := ball.y if side == 0 else 1.0 - ball.y
	x = clampf(x + (ball_lat - 0.5) * 0.18 * (1.0 - absf(x - 0.5)), 0.03, 0.97)
	var j := Vector2(sin(_t * 1.3 + idx * 1.7 + side), cos(_t * 1.1 + idx * 2.3)) * 0.008
	if side == 0:
		return Vector2(y, x) + j
	return Vector2(1.0 - y, 1.0 - x) + j


func _draw_match(r: Rect2) -> void:
	var rad := _wid_px(r) * 0.042
	var font := get_theme_font(&"font", &"Stat")
	var fs := int(rad * 1.05)
	_draw_end_labels(r, font, int(rad * 0.85))
	for side in 2:
		var slots: Array = home_slots if side == 0 else away_slots
		var c1 := home_color if side == 0 else away_color
		var c2 := home_color2 if side == 0 else away_color2
		for i in slots.size():
			var s: Dictionary = slots[i]
			if not s.get("on", true):
				continue
			var ab := _slot_ab(s, side, i)
			var p := P(ab.x, ab.y, r)
			var k1: Color = s.get("c1", c1) # goleiro com a camisa dele
			var k2: Color = s.get("c2", c2)
			draw_circle(p + Vector2(0, 2), rad, Color(0, 0, 0, 0.3))
			draw_circle(p, rad, k1)
			draw_arc(p, rad, 0.0, TAU, 20, k2, maxf(1.5, rad * 0.22), true)
			if side == highlight_side and i == highlight_slot:
				draw_arc(p, rad * 1.6, 0.0, TAU, 24, UIColors.ACCENT, 2.5, true)
			var num := str(s.get("number", ""))
			var nw := font.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(font, p + Vector2(-nw * 0.5, fs * 0.36), num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UIColors.on_color(k1))
	var bp := P(ball.x, ball.y, r)
	draw_circle(bp + Vector2(1.5, 2.5), rad * 0.5, Color(0, 0, 0, 0.35))
	draw_circle(bp, rad * 0.5, Color.WHITE)
	draw_circle(bp, rad * 0.2, Color(0.15, 0.15, 0.15))


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
		draw_string(font, p + Vector2(-tw * 0.5, fs * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col.r, col.g, col.b, 0.55))


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
