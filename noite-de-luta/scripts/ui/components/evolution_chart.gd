class_name EvolutionChart
extends Control
## Gráfico de evolução do perfil: o nível do lutador pela idade, com as lutas marcadas em cima
## da linha, a idade do auge e a faixa do teto que o olheiro enxerga.
##
## Uma série só (o nível), então não há legenda de cor: o título do cartão diz o que é. A linha
## de antes do jogo (reconstruída pela idade) vem num tom apagado; a do jogo, em giz claro.
## As lutas não dependem só da cor: vitória é ponto cheio, derrota é anel vazado, cinturão é losango.

const PAD_L := 46.0
const PAD_R := 20.0
const PAD_T := 26.0
const PAD_B := 34.0

## [[idade, nível, semana], ...] em ordem.
var points: Array = []
## [{age, res ("V"/"D"/"E"), title}] das lutas no jogo.
var fights: Array = []
## Faixa do teto (nível): x = de, y = até. Negativo = não mostra.
var band := Vector2(-1.0, -1.0)
## Idade do auge como a equipe a enxerga (0 = não mostra).
var peak_age := 0.0

var _x0 := 18.0
var _x1 := 30.0
var _y0 := 40.0
var _y1 := 90.0


func _init() -> void:
	custom_minimum_size = Vector2(0, 250)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(pts: Array, fight_list: Array, ceiling: Vector2, peak: float) -> void:
	points = pts
	fights = fight_list
	band = ceiling
	peak_age = peak
	_ranges()
	queue_redraw()


func _ranges() -> void:
	if points.is_empty():
		return
	_x0 = floorf(float((points[0] as Array)[0]))
	_x1 = ceilf(float((points.back() as Array)[0]) + 0.01)
	if peak_age > 0.0 and peak_age > _x1 and peak_age - _x1 <= 6.0:
		_x1 = ceilf(peak_age) + 1.0
	if _x1 - _x0 < 4.0:
		_x0 = _x1 - 4.0
	var lo := 999.0
	var hi := 0.0
	for p: Array in points:
		lo = minf(lo, float(p[1]))
		hi = maxf(hi, float(p[1]))
	if band.y > 0.0:
		hi = maxf(hi, band.y)
	_y0 = floorf((lo - 3.0) / 5.0) * 5.0
	_y1 = ceilf((hi + 2.0) / 5.0) * 5.0
	if _y1 - _y0 < 15.0:
		_y0 = _y1 - 15.0


func _plot() -> Rect2:
	return Rect2(PAD_L, PAD_T, maxf(10.0, size.x - PAD_L - PAD_R), maxf(10.0, size.y - PAD_T - PAD_B))


func _px(age: float, level: float) -> Vector2:
	var r := _plot()
	return Vector2(r.position.x + (age - _x0) / maxf(0.01, _x1 - _x0) * r.size.x, r.position.y + (1.0 - (level - _y0) / maxf(0.01, _y1 - _y0)) * r.size.y)


## Nível na idade `age`, lido da linha.
func _level_at(age: float) -> float:
	if points.is_empty():
		return 50.0
	var prev: Array = points[0]
	if age <= float(prev[0]):
		return float(prev[1])
	for p: Array in points:
		if float(p[0]) >= age:
			var span := float(p[0]) - float(prev[0])
			var t := 0.0 if span <= 0.0 else (age - float(prev[0])) / span
			return lerpf(float(prev[1]), float(p[1]), t)
		prev = p
	return float((points.back() as Array)[1])


func _draw() -> void:
	if points.size() < 2:
		return
	var r := _plot()
	var font := get_theme_font(&"font", &"Label")
	var fs := UITokens.F_CAPTION
	var grid := UIColors.SURFACE_3
	var ink := UIColors.MUTED
	# Grade horizontal com os níveis (o eixo é discreto: quem fala é a linha).
	var step := 5.0 if _y1 - _y0 <= 30.0 else 10.0
	var v := _y0
	while v <= _y1 + 0.01:
		var y := _px(_x0, v).y
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), grid, 1.0)
		draw_string(font, Vector2(0, y + fs * 0.35), str(int(v)), HORIZONTAL_ALIGNMENT_RIGHT, PAD_L - 10.0, fs, ink)
		v += step
	# Idades no eixo de baixo.
	var span := _x1 - _x0
	var xs := 1.0 if span <= 8.0 else (2.0 if span <= 16.0 else 5.0)
	var a := ceilf(_x0 / xs) * xs
	while a <= _x1 + 0.01:
		var x := _px(a, _y0).x
		draw_line(Vector2(x, r.end.y), Vector2(x, r.end.y + 5.0), grid, 1.0)
		draw_string(font, Vector2(x - 30.0, r.end.y + 8.0 + fs), str(int(a)), HORIZONTAL_ALIGNMENT_CENTER, 60.0, fs, ink)
		a += xs
	# Faixa do teto (o que o olheiro enxerga).
	if band.y > 0.0:
		var top := _px(_x0, band.y).y
		var bot := _px(_x0, maxf(band.x, _y0)).y
		if bot - top < 3.0:
			bot = top + 3.0
		draw_rect(Rect2(r.position.x, top, r.size.x, bot - top), Color(UIColors.GOLD, 0.13))
		draw_line(Vector2(r.position.x, top), Vector2(r.end.x, top), Color(UIColors.GOLD, 0.45), 1.0)
		draw_string(font, Vector2(r.position.x + 8.0, top - 6.0), "teto estimado", HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 2, UIColors.MUTED)
	# Idade do auge.
	if peak_age > _x0 and peak_age < _x1:
		var px := _px(peak_age, _y0).x
		draw_line(Vector2(px, r.position.y), Vector2(px, r.end.y), UIColors.LINE, 1.0)
		draw_string(font, Vector2(px - 60.0, r.position.y - 8.0), "auge", HORIZONTAL_ALIGNMENT_CENTER, 120.0, fs - 2, UIColors.MUTED)
	# A linha: passado reconstruído apagado, o que aconteceu no jogo na cor de destaque.
	var past := PackedVector2Array()
	var live := PackedVector2Array()
	for p: Array in points:
		var q := _px(float(p[0]), float(p[1]))
		if int(p[2]) <= 0:
			past.append(q)
		if int(p[2]) >= 0:
			live.append(q)
	# Giz, não a cor da equipe: vermelho e verde aqui são derrota e vitória.
	var col := UIColors.TEXT
	if live.size() >= 2:
		var area := live.duplicate()
		area.append(Vector2(live[live.size() - 1].x, r.end.y))
		area.append(Vector2(live[0].x, r.end.y))
		if Geometry2D.triangulate_polygon(area).size() >= 3:
			draw_colored_polygon(area, Color(col, 0.1))
	if past.size() >= 2:
		draw_polyline(past, UIColors.DIM, 2.0, true)
	if live.size() >= 2:
		draw_polyline(live, col, 2.5, true)
	# Lutas do jogo em cima da linha.
	for f: Dictionary in fights:
		var fa := float(f["age"])
		if fa < _x0 or fa > _x1:
			continue
		var c := _px(fa, _level_at(fa))
		var res := String(f["res"])
		var mc := UIColors.GREEN if res == "V" else (UIColors.RED if res == "D" else UIColors.MUTED)
		if bool(f.get("title", false)):
			var d := 7.0
			var diamond := PackedVector2Array([c + Vector2(0, -d), c + Vector2(d, 0), c + Vector2(0, d), c + Vector2(-d, 0)])
			var ring := PackedVector2Array([c + Vector2(0, -d - 2.5), c + Vector2(d + 2.5, 0), c + Vector2(0, d + 2.5), c + Vector2(-d - 2.5, 0)])
			draw_colored_polygon(ring, UIColors.SURFACE)
			draw_colored_polygon(diamond, UIColors.GOLD if res == "V" else UIColors.SURFACE)
			if res != "V":
				draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]), mc, 2.0, true)
		elif res == "V":
			draw_circle(c, 7.0, UIColors.SURFACE)
			draw_circle(c, 5.0, mc)
		else:
			draw_circle(c, 7.0, UIColors.SURFACE)
			draw_arc(c, 4.5, 0.0, TAU, 20, mc, 2.0, true)
	# Rótulo direto só na ponta: o nível de hoje.
	var last: Array = points.back()
	var e := _px(float(last[0]), float(last[1]))
	draw_circle(e, 7.0, UIColors.SURFACE)
	draw_circle(e, 5.0, col)
	var txt := str(int(round(float(last[1]))))
	var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs + 4).x
	var tx := clampf(e.x - tw * 0.5, r.position.x, size.x - tw - 2.0)
	draw_string(font, Vector2(tx, e.y - 12.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs + 4, UIColors.TEXT)


## Legenda das marcas de luta (fica embaixo do gráfico): ponto cheio, anel e losango.
static func legend() -> Control:
	var h := UIKit.hbox(UITokens.S3)
	for it: Array in [["V", false, "vitória"], ["D", false, "derrota"], ["V", true, "cinturão"]]:
		var one := UIKit.hbox(6)
		var mk := _Mark.new()
		mk.res = String(it[0])
		mk.title = bool(it[1])
		one.add_child(mk)
		one.add_child(UIKit.label(String(it[2]), "Caps"))
		h.add_child(one)
	return h


class _Mark:
	extends Control
	var res := "V"
	var title := false

	func _init() -> void:
		custom_minimum_size = Vector2(18, 18)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		if title:
			var d := 7.0
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -d), c + Vector2(d, 0), c + Vector2(0, d), c + Vector2(-d, 0)]), UIColors.GOLD)
		elif res == "V":
			draw_circle(c, 5.0, UIColors.GREEN)
		else:
			draw_arc(c, 4.5, 0.0, TAU, 20, UIColors.RED, 2.0, true)
