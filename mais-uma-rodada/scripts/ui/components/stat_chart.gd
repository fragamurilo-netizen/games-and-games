class_name StatChart
extends Control
## Gráfico de números da carreira e das temporadas (linhas ou barras), feito para o dedo: tocar
## escolhe uma coluna, que fica marcada com o valor de cada série; `selected` avisa
## quem usa o gráfico (a tela mostra o detalhe daquela temporada).
## Séries: [{"name", "values": Array (float ou null = sem dado), "color", "bar": bool}].
## `invert` põe o 1 em cima (posição na tabela). Cores só da paleta (UIColors / escala de notas).

signal selected(index: int)

var labels: Array = []
var series: Array = []
var invert := false
var y_min := NAN
var y_max := NAN
## Formato dos valores ("%d", "%.1f", "%dº"...) para o eixo e o destaque.
var value_fmt := "%d"
## Coluna destacada (-1 = nenhuma). Muda ao tocar.
var sel := -1:
	set(v):
		sel = v
		queue_redraw()
## Linhas de referência horizontais: [[valor, rótulo]] (ex.: zona de rebaixamento).
var guides: Array = []

const PAD_L := 46.0
const PAD_R := 14.0
const PAD_T := 30.0
const PAD_B := 30.0


static func make(labels_: Array, series_: Array, h: float = 220.0) -> StatChart:
	var c := StatChart.new()
	c.labels = labels_
	c.series = series_
	c.custom_minimum_size = Vector2(0, h)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_PASS # o toque escolhe a coluna; arrastar continua rolando a tela
	return c


func _range() -> Vector2:
	var lo := INF
	var hi := -INF
	for s: Dictionary in series:
		for v in s.get("values", []):
			if v == null:
				continue
			lo = minf(lo, float(v))
			hi = maxf(hi, float(v))
	for g in guides:
		lo = minf(lo, float(g[0]))
		hi = maxf(hi, float(g[0]))
	if not is_nan(y_min):
		lo = y_min
	if not is_nan(y_max):
		hi = y_max
	if lo == INF:
		return Vector2(0, 1)
	if is_equal_approx(lo, hi):
		hi = lo + 1.0
	return Vector2(lo, hi)


func _x_of(i: int) -> float:
	var n := maxi(1, labels.size())
	var w := size.x - PAD_L - PAD_R
	return PAD_L + w * (float(i) + 0.5) / float(n)


func _y_of(v: float, r: Vector2) -> float:
	var t := (v - r.x) / (r.y - r.x)
	if invert:
		t = 1.0 - t
	return size.y - PAD_B - t * (size.y - PAD_T - PAD_B)


func _fmt(v: float) -> String:
	if value_fmt.contains("d"):
		return value_fmt % int(round(v))
	return value_fmt % v


func _draw() -> void:
	if labels.is_empty() or size.x < 80.0:
		return
	var font := get_theme_default_font()
	var tf: Font = DataTable.tabular_font()
	var fs := 18
	var r := _range()
	var base_y := size.y - PAD_B
	# Grade: três linhas finas e os valores das pontas
	for k in 3:
		var v := lerpf(r.x, r.y, float(k) / 2.0)
		var y := _y_of(v, r)
		draw_line(Vector2(PAD_L, y), Vector2(size.x - PAD_R, y), UIColors.LINE, 1.0)
		draw_string(tf, Vector2(0, y + 6), _fmt(v), HORIZONTAL_ALIGNMENT_RIGHT, PAD_L - 8, fs, UIColors.DIM)
	for g in guides:
		var gy := _y_of(float(g[0]), r)
		_dashed(Vector2(PAD_L, gy), Vector2(size.x - PAD_R, gy), UIColors.ORANGE)
		if g.size() > 1:
			draw_string(font, Vector2(size.x - PAD_R - 220, gy - 6), String(g[1]), HORIZONTAL_ALIGNMENT_RIGHT, 220, 16, UIColors.ORANGE)
	# Rótulos do eixo x (pula quando não cabem)
	var n := labels.size()
	var step := maxi(1, int(ceil(float(n) * 56.0 / maxf(1.0, size.x - PAD_L - PAD_R))))
	for i in n:
		if i % step != 0 and i != n - 1 and i != sel:
			continue
		var col := UIColors.TEXT if i == sel else UIColors.DIM
		draw_string(tf, Vector2(_x_of(i) - 40, size.y - 6), str(labels[i]), HORIZONTAL_ALIGNMENT_CENTER, 80, fs, col)
	# Coluna escolhida
	if sel >= 0 and sel < n:
		var sx := _x_of(sel)
		draw_rect(Rect2(sx - _col_w() * 0.5, PAD_T - 6, _col_w(), base_y - PAD_T + 6), Color(UIColors.TEXT, 0.06))
	# Barras primeiro, linhas por cima
	var bars: Array = series.filter(func(s): return bool(s.get("bar", false)))
	var nb := bars.size()
	for bi in nb:
		var s: Dictionary = bars[bi]
		var vals: Array = s.get("values", [])
		var col: Color = s.get("color", UIColors.MUTED)
		var bw := _col_w() * 0.7 / float(nb)
		for i in mini(n, vals.size()):
			if vals[i] == null:
				continue
			var x := _x_of(i) - _col_w() * 0.35 + bw * bi
			var y := _y_of(float(vals[i]), r)
			var y0 := _y_of(maxf(r.x, 0.0) if not invert else r.y, r)
			var c := col if (sel < 0 or i == sel) else Color(col, 0.55)
			draw_rect(Rect2(x, minf(y, y0), bw - 2.0, absf(y0 - y)), c)
	for s: Dictionary in series:
		if bool(s.get("bar", false)):
			continue
		var vals: Array = s.get("values", [])
		var col: Color = s.get("color", UIColors.TEXT)
		var prev := Vector2.INF
		for i in mini(n, vals.size()):
			if vals[i] == null:
				prev = Vector2.INF
				continue
			var p := Vector2(_x_of(i), _y_of(float(vals[i]), r))
			if prev != Vector2.INF:
				draw_line(prev, p, col, 3.0, true)
			prev = p
		for i in mini(n, vals.size()):
			if vals[i] == null:
				continue
			var p := Vector2(_x_of(i), _y_of(float(vals[i]), r))
			draw_circle(p, 6.0 if i == sel else 4.0, col)
			if i == sel:
				draw_circle(p, 3.0, UIColors.SURFACE)
	# Valores da coluna escolhida, no alto
	if sel >= 0 and sel < n:
		var parts: Array = []
		for s: Dictionary in series:
			var vals: Array = s.get("values", [])
			if sel < vals.size() and vals[sel] != null:
				parts.append([String(s.get("name", "")), _fmt(float(vals[sel])), s.get("color", UIColors.TEXT)])
		var x := clampf(_x_of(sel) - 110.0, 0.0, size.x - 220.0)
		var tx := x
		for pt in parts:
			var txt := ("%s %s" % [pt[0], pt[1]]).strip_edges()
			draw_string(tf, Vector2(tx, 20), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, pt[2])
			tx += tf.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 14.0


func _col_w() -> float:
	return (size.x - PAD_L - PAD_R) / float(maxi(1, labels.size()))


func _dashed(a: Vector2, b: Vector2, col: Color) -> void:
	var d := b - a
	var ln := d.length()
	var k := 0.0
	while k < ln:
		draw_line(a + d * (k / ln), a + d * (minf(k + 8.0, ln) / ln), col, 1.5)
		k += 14.0


func _gui_input(e: InputEvent) -> void:
	var pos := Vector2.INF
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		pos = e.position
	elif e is InputEventScreenTouch and e.pressed:
		pos = e.position
	if pos == Vector2.INF or labels.is_empty():
		return
	var i := clampi(int((pos.x - PAD_L) / _col_w()), 0, labels.size() - 1)
	if i != sel:
		sel = i
		selected.emit(i)
