class_name XRayPitch
extends Control
## Campinho do Raio-X tático (vertical: o seu gol embaixo, o do adversário em cima).
##   modo "map": setas por corredor com o volume de ataques (seus para cima, deles para baixo).
##   modo "clip": um lance — o caminho da jogada, quem finalizou, quem deu o passe e o que
##               aconteceu no seu setor (lateral no ataque, ponta que não voltou, 2 contra 1).

var mode := "map"
var rep: Dictionary = {}
var chance: Dictionary = {}
const MINE := Color("#F5C542")
const THEIRS := Color("#FF5A5F")
var my_color := MINE
var their_color := THEIRS
var _font: Font = null

const LANE_X := [0.2, 0.5, 0.8]


static func map(report: Dictionary, h: int = 460) -> XRayPitch:
	var v := XRayPitch.new()
	v.mode = "map"
	v.rep = report
	v.custom_minimum_size = Vector2(0, h)
	return v


static func clip(report: Dictionary, c: Dictionary, h: int = 380) -> XRayPitch:
	var v := XRayPitch.new()
	v.mode = "clip"
	v.rep = report
	v.chance = c
	v.custom_minimum_size = Vector2(0, h)
	return v


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_font = get_theme_default_font()
	resized.connect(queue_redraw)


func _p(x: float, y: float) -> Vector2:
	var m := 14.0
	return Vector2(m + x * (size.x - m * 2), m + y * (size.y - m * 2))


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UIColors.PITCH_A)
	for i in 6:
		if i % 2 == 1:
			draw_rect(Rect2(0, size.y * i / 6.0, size.x, size.y / 6.0), UIColors.PITCH_B)
	var lc := UIColors.PITCH_LINE
	lc.a = 0.45
	draw_rect(Rect2(_p(0, 0), _p(1, 1) - _p(0, 0)), lc, false, 2.0)
	draw_line(_p(0, 0.5), _p(1, 0.5), lc, 2.0)
	draw_arc(_p(0.5, 0.5), size.x * 0.12, 0, TAU, 32, lc, 2.0)
	for top in [true, false]:
		var y0 := 0.0 if top else 0.84
		draw_rect(Rect2(_p(0.22, y0), _p(0.78, y0 + 0.16) - _p(0.22, y0)), lc, false, 2.0)
	# Corredores
	var dash := Color(1, 1, 1, 0.08)
	for x in [0.34, 0.66]:
		draw_line(_p(x, 0.0), _p(x, 1.0), dash, 2.0)
	if mode == "map":
		_draw_map()
	else:
		_draw_clip()


func _draw_map() -> void:
	var fo: Dictionary = rep.get("for", {})
	var ag: Dictionary = rep.get("against", {})
	var lf: Array = fo.get("lanes", [0, 0, 0])
	var la: Array = ag.get("lanes", [0, 0, 0])
	var mx := 1
	for l in 3:
		mx = maxi(mx, maxi(int(lf[l]), int(la[l])))
	for l in 3:
		var x := float(LANE_X[l])
		# Deles: de cima para o seu gol
		if int(la[l]) > 0:
			var w := 4.0 + 18.0 * float(la[l]) / mx
			_arrow(_p(x + 0.05, 0.12), _p(x + 0.05, 0.86), w, Color(their_color, 0.85))
			_label("%d" % int(la[l]), _p(x + 0.05, 0.5) + Vector2(12, 0), their_color, 26)
		# Seus: de baixo para o gol deles
		if int(lf[l]) > 0:
			var w2 := 4.0 + 18.0 * float(lf[l]) / mx
			_arrow(_p(x - 0.05, 0.88), _p(x - 0.05, 0.14), w2, Color(my_color, 0.85))
			_label("%d" % int(lf[l]), _p(x - 0.05, 0.5) - Vector2(34, 0), my_color, 26)


func _draw_clip() -> void:
	var c := chance
	var mine := bool(c.get("mine", false))
	var ul := int(c.get("ul", 1))
	if ul < 0:
		ul = 1
	var x := float(LANE_X[ul])
	var col := my_color if mine else their_color
	var y_goal := 0.06 if mine else 0.94
	var y_start := 0.62 if mine else 0.38
	if int(c.get("ct", 0)) == MatchSimulation.CH_COUNTER:
		y_start = 0.85 if mine else 0.15
	var names: Dictionary = rep.get("names", {})
	var shot_pt := _p(0.5 + (x - 0.5) * 0.35, 0.2 if mine else 0.8)
	if int(c.get("ct", 0)) == MatchSimulation.CH_CROSS:
		var cross_pt := _p(x, 0.18 if mine else 0.82)
		_arrow(_p(x, y_start), cross_pt, 7.0, Color(col, 0.9))
		_arrow(cross_pt, shot_pt, 4.0, Color(col, 0.6))
	else:
		_arrow(_p(x, y_start), shot_pt, 7.0, Color(col, 0.9))
	_arrow(shot_pt, _p(0.5, y_goal), 3.0, Color(1, 1, 1, 0.8))
	# Quem deu o passe e quem finalizou
	if int(c.get("as", -1)) >= 0:
		var ap := _p(x, y_start)
		_dot(ap, col)
		_label(String(names.get(int(c["as"]), "")), ap + Vector2(14, -10), Color.WHITE, 20)
	_dot(shot_pt, col)
	_label(String(names.get(int(c["sh"]), "")), shot_pt + Vector2(14, 6), Color.WHITE, 20)
	if bool(c.get("x2", false)):
		_dot(_p(x + (0.08 if x < 0.5 else -0.08), y_start + (0.12 if not mine else -0.12)), col)
		_label("2 contra 1", _p(x, 0.5) + Vector2(-40, 0), UIColors.ORANGE, 22)
	# O seu setor quando o lance foi contra você
	if not mine:
		if int(c.get("fb", -1)) >= 0:
			var up := bool(c.get("fb_up", false))
			var fpos := _p(x, 0.34 if up else 0.78)
			_dot(fpos, my_color)
			_label(("%s (no ataque)" if up else "%s") % String(names.get(int(c["fb"]), "lateral")), fpos + Vector2(14, -8), my_color, 20)
			if up:
				_dashed(fpos, _p(x, 0.78), my_color)
		if int(c.get("wg", -1)) >= 0 and bool(c.get("wg_off", false)):
			var wpos := _p(x, 0.22)
			_dot(wpos, my_color)
			_label("%s (não voltou)" % String(names.get(int(c["wg"]), "ponta")), wpos + Vector2(14, -8), my_color, 20)
	var res := String(c.get("r", ""))
	_label("%d' · %s · xG %s" % [int(c.get("m", 0)), res.to_upper(), TacticalXRay.dec(float(c.get("xg", 0.0)))], _p(0.03, 0.5) + Vector2(0, -4), Color(1, 1, 1, 0.9), 22)


func _arrow(a: Vector2, b: Vector2, w: float, col: Color) -> void:
	draw_line(a, b, col, w, true)
	var d := (b - a).normalized()
	var n := Vector2(-d.y, d.x)
	var head := w * 2.2 + 8.0
	draw_colored_polygon(PackedVector2Array([b + d * 2.0, b - d * head + n * head * 0.6, b - d * head - n * head * 0.6]), col)


func _dashed(a: Vector2, b: Vector2, col: Color) -> void:
	var n := int(a.distance_to(b) / 14.0)
	for i in n:
		if i % 2 == 0:
			draw_line(a.lerp(b, float(i) / n), a.lerp(b, float(i + 1) / n), Color(col, 0.7), 2.0)


func _dot(p: Vector2, col: Color) -> void:
	draw_circle(p, 11.0, Color(0, 0, 0, 0.5))
	draw_circle(p, 9.0, col)


func _label(t: String, p: Vector2, col: Color, fs: int) -> void:
	if _font == null or t == "":
		return
	draw_string_outline(_font, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.7))
	draw_string(_font, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
