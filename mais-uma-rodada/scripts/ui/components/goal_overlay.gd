class_name GoalOverlay
extends Control
## Comemoração de gol proporcional ao momento: um gol aos 90+4 que vale a vitória explode a tela;
## o quinto gol de uma goleada é só uma faixa rápida; gol sofrido é sóbrio (e doído quando é no fim).
## Tudo desenhado em _draw (sem cenas extras). Toque para pular.

signal finished

## Níveis: 3 épico, 2 grande, 1 simples, -1 sofrido, -2 sofrido no momento decisivo.
const DURATION := {3: 3.6, 2: 2.5, 1: 1.5, -1: 1.5, -2: 2.3}

var _t := 0.0
var _dur := 0.0
var _level := 0
var _c1 := Color.WHITE
var _c2 := Color.BLACK
var _title := ""
var _scorer := ""
var _tag := ""
var _info := ""
var _confetti: Array = [] # [pos, vel, rot, vrot, color, size]
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	set_process(false)


func is_playing() -> bool:
	return visible


## Mostra a comemoração e retorna a duração (s). speed_scale < 1 encurta (modo turbo).
func play(level: int, title: String, scorer: String, tag: String, info: String, c1: Color, c2: Color, speed_scale: float = 1.0) -> float:
	_level = level
	_title = title
	_scorer = scorer
	_tag = tag
	_info = info
	_c1 = c1
	_c2 = c2
	_t = 0.0
	_dur = float(DURATION.get(level, 1.5)) * clampf(speed_scale, 0.45, 1.0)
	if AppSettings.reduce_motion:
		# Animações reduzidas: faixa curta, sem chuva de papel picado.
		_dur = minf(_dur, 1.2)
		level = mini(level, 1)
	_rng.seed = hash(scorer + info)
	_confetti.clear()
	if level >= 2:
		var n := 110 if level == 3 else 55
		var palette := [c1, c2, UIColors.ACCENT, Color.WHITE]
		for i in n:
			var pos := Vector2(_rng.randf() * size.x, -_rng.randf() * size.y * 0.5)
			var vel := Vector2(_rng.randf_range(-60, 60), _rng.randf_range(260, 520))
			_confetti.append([pos, vel, _rng.randf() * TAU, _rng.randf_range(-7, 7), palette[i % palette.size()], Vector2(_rng.randf_range(8, 16), _rng.randf_range(12, 24))])
	visible = true
	modulate.a = 1.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)
	queue_redraw()
	return _dur


func skip() -> void:
	if visible:
		_t = _dur


func _process(delta: float) -> void:
	_t += delta
	for c in _confetti:
		var vel: Vector2 = c[1]
		vel.x += sin(_t * 3.0 + float(c[3])) * 40.0 * delta
		c[1] = vel
		c[0] = (c[0] as Vector2) + vel * delta
		c[2] = float(c[2]) + float(c[3]) * delta
	var fade := 0.3
	modulate.a = clampf((_dur - _t) / fade, 0.0, 1.0)
	queue_redraw()
	if _t >= _dur:
		visible = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(false)
		finished.emit()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		accept_event()
		skip()


func _pop(t: float) -> float:
	# Escala com "estouro": cresce além de 1 e assenta.
	if t < 0.18:
		return lerpf(0.3, 1.18, t / 0.18)
	if t < 0.32:
		return lerpf(1.18, 1.0, (t - 0.18) / 0.14)
	return 1.0 + sin(t * 9.0) * 0.012 * (1.0 if _level == 3 else 0.0)


func _draw() -> void:
	var ours := _level > 0
	var center := size * 0.5 + Vector2(0, -size.y * 0.06)
	# Fundo
	var dim := 0.62 if ours else (0.55 if _level == -2 else 0.42)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.05, dim))
	if _level >= 2:
		var rays := 18
		var rot := _t * (0.5 if _level == 3 else 0.3)
		var rlen := size.length()
		for i in rays:
			var a0 := rot + TAU * i / rays
			var a1 := a0 + TAU / rays * 0.5
			var pts := PackedVector2Array([center, center + Vector2(cos(a0), sin(a0)) * rlen, center + Vector2(cos(a1), sin(a1)) * rlen])
			draw_colored_polygon(pts, Color(_c1.r, _c1.g, _c1.b, 0.22 if _level == 3 else 0.14))
	elif not ours:
		# Faixa sóbria nas cores do adversário
		var band := Rect2(0, center.y - 150, size.x, 300)
		draw_rect(band, Color(_c1.r * 0.5, _c1.g * 0.5, _c1.b * 0.5, 0.85))
		draw_rect(Rect2(0, band.position.y, size.x, 6), _c1)
		draw_rect(Rect2(0, band.end.y - 6, size.x, 6), _c1)
	else:
		var band2 := Rect2(0, center.y - 130, size.x, 260)
		draw_rect(band2, Color(_c1.r * 0.6, _c1.g * 0.6, _c1.b * 0.6, 0.9))
		draw_rect(Rect2(0, band2.position.y, size.x, 8), UIColors.ACCENT)
		draw_rect(Rect2(0, band2.end.y - 8, size.x, 8), UIColors.ACCENT)
	# Clarão inicial
	if _level == 3 and _t < 0.35:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, (0.35 - _t) * 1.6))
	elif _level == -2 and _t < 0.3:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.9, 0.1, 0.1, (0.3 - _t) * 1.2))
	# Confete
	for c in _confetti:
		draw_set_transform(c[0], c[2], Vector2.ONE)
		var s: Vector2 = c[5]
		draw_rect(Rect2(-s * 0.5, s), c[4])
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Textos
	var f_big := get_theme_font(&"font", &"Huge")
	var f_title := get_theme_font(&"font", &"Title")
	var f_semi := get_theme_font(&"font", &"H3")
	var big_size := 118 if _level == 3 else (100 if _level == 2 else 80)
	if not ours:
		big_size = 64
	var shake := Vector2.ZERO
	if _level == 3 and _t < 1.0:
		shake = Vector2(sin(_t * 61.0), cos(_t * 53.0)) * 7.0 * (1.0 - _t)
	elif _level == -2 and _t < 0.6:
		shake = Vector2(sin(_t * 47.0), 0) * 6.0 * (0.6 - _t)
	var sc := _pop(_t)
	var title_col := UIColors.ACCENT if ours else Color.WHITE
	_text_centered(f_big, _title, center + Vector2(0, -34) + shake, big_size, title_col, sc)
	var y := center.y + 52.0
	if _scorer != "":
		_text_centered(f_title, _scorer, Vector2(center.x, y), 44, Color.WHITE, 1.0)
		y += 54.0
	if _tag != "":
		_text_centered(f_semi, _tag, Vector2(center.x, y), 30, UIColors.ACCENT if ours else Color(1, 0.8, 0.8), 1.0)
		y += 42.0
	if _info != "":
		_text_centered(f_semi, _info, Vector2(center.x, y), 24, Color(1, 1, 1, 0.8), 1.0)


func _text_centered(font: Font, text: String, pos: Vector2, fs: int, color: Color, scale_f: float) -> void:
	if font == null or text == "":
		return
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var max_w := size.x - 40.0
	var k := scale_f
	if w * k > max_w:
		k = max_w / w
	draw_set_transform(pos, 0.0, Vector2(k, k))
	var p := Vector2(-w * 0.5, fs * 0.35)
	draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(4, fs / 12), Color(0, 0, 0, 0.75))
	draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Texto de contexto do gol a partir das etiquetas do motor.
static func tag_text(tags: Array) -> String:
	if tags.has("own_goal"):
		return "GOL CONTRA"
	var main := ""
	if tags.has("virada"):
		main = "DE VIRADA"
	elif tags.has("equalizer"):
		main = "EMPATE"
	elif tags.has("winner"):
		main = "GOL DA VITÓRIA"
	if tags.has("stoppage"):
		main = (main + " NOS ACRÉSCIMOS") if main != "" else "NOS ACRÉSCIMOS"
	elif tags.has("late") and main != "":
		main += " NO FIM"
	var extra := ""
	if tags.has("hattrick"):
		extra = "HAT-TRICK"
	elif tags.has("golaco"):
		extra = "GOLAÇO"
	elif tags.has("penalty"):
		extra = "DE PÊNALTI"
	elif main == "" and tags.has("blowout"):
		extra = "GOLEADA"
	elif main == "" and tags.has("counter"):
		extra = "NO CONTRA-ATAQUE"
	elif main == "" and tags.has("header"):
		extra = "DE CABEÇA"
	if main != "" and extra != "":
		return main + " · " + extra
	return main if main != "" else extra


## Nível da comemoração a partir da importância (0..1) e das etiquetas.
static func level_for(importance: float, tags: Array, ours: bool) -> int:
	var decisive := tags.has("stoppage") or (tags.has("late") and (tags.has("equalizer") or tags.has("winner") or tags.has("virada")))
	if ours:
		if decisive or importance >= 0.75:
			return 3
		if importance >= 0.42:
			return 2
		return 1
	return -2 if decisive or importance >= 0.7 else -1
