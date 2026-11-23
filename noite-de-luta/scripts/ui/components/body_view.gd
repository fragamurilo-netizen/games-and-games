@tool
class_name BodyView
extends Control
## Corpo inteiro do lutador, de frente, como na pesagem: shorts nas cores da equipe, luvas de MMA,
## pés descalços. O físico vem do mesmo FaceGen do retrato (categoria, músculo, gordura, trapézio,
## tatuagens) e a altura em cm define o tamanho no quadro (dois BodyView lado a lado com a mesma
## `ref_cm` comparam a altura de verdade). A cabeça é um PortraitView só de cabeça por cima.
##
## Luz igual à do retrato: refletor em cima, um pouco à esquerda. Cada parte é uma malha em faixas
## com a normal de um cilindro, então braço, perna e tronco ganham volume sem textura.

var face_seed: int = 1
var eth: int = 1
var age: int = 26
var look: Dictionary = {}
var height_cm: int = 178
## Altura que ocupa o quadro inteiro (a mesma nos dois lados de uma comparação).
var ref_cm: int = 200
var shorts: Color = Color("#16161A")
var trim: Color = Color("#C8102E")
var glove: Color = Color("#141416")

var _f: Dictionary = {}
var _head: PortraitView = null
var _skin := Color.WHITE
var _key := 0


func set_fighter(w: GameWorld, f: Fighter) -> void:
	face_seed = f.face_seed
	eth = f.eth
	age = w.age_of(f)
	look = f.look
	height_cm = f.height_cm
	var t := w.team(f.team_id)
	if t != null:
		shorts = t.color1
		trim = t.color2 if not t.color2.is_equal_approx(t.color1) else t.color1.lightened(0.4)
	queue_redraw()


func _ready() -> void:
	clip_contents = false
	resized.connect(queue_redraw)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	if size.y < 40.0:
		return
	var k := hash([face_seed, eth, age, look])
	if k != _key or _f.is_empty():
		_f = FaceGen.features(face_seed, eth, age, look)
		_key = k
	_skin = _f["skin"]
	var f := _f
	var fem: bool = bool(f.get("fem", false))
	var build: float = float(f.get("build", 0.5))
	var mus: float = float(f.get("muscle", 0.6))
	var bf: float = float(f.get("body_fat", 0.15))
	var trap: float = float(f.get("trap", 0.0))
	# Escala: a figura inteira (cabeça aos pés) tem 7,5 cabeças.
	var fig_h := size.y * 0.97 * clampf(float(height_cm) / float(maxi(ref_cm, 140)), 0.5, 1.0)
	var U := fig_h / 7.5
	var feet := size.y * 0.985
	var top := feet - fig_h
	var cx := size.x * 0.5
	var fh_px := U / 1.78
	var s := fh_px / (float(f["fh"]) * PortraitView.HEAD_SCALE)
	var fw_px := float(f["fw"]) * s * PortraitView.HEAD_SCALE * PortraitView.HEAD_W
	var hc := Vector2(cx, top + fh_px * 0.95)
	var chin := hc.y + fh_px * (1.0 + float(f.get("chin_len", 0.0)))
	var nw := fw_px * float(f.get("neck_w", 0.68)) * (1.0 + 0.1 * float(f.get("fat", 0.0)))
	nw = minf(maxf(nw, fw_px * 0.6), fw_px * float(f["jaw"]) * 0.95 * (0.92 + 0.16 * trap))
	# Medidas do tronco (meia largura).
	var sw := U * ((0.74 + 0.16 * build + 0.04 * trap) if fem else (0.86 + 0.3 * build + 0.1 * mus + 0.08 * trap))
	var ys := chin + U * (0.36 - 0.08 * trap)
	var y_chest := chin + U * 1.05
	var y_waist := chin + U * 2.25
	var y_hip := chin + U * 2.5
	var chest_w := sw * (0.8 if fem else 0.84)
	var waist_w := U * ((0.5 + 0.14 * build) if fem else (0.58 + 0.24 * build)) + U * 0.75 * maxf(0.0, bf - 0.14)
	var hip_w := waist_w * (1.22 if fem else 1.04) + U * 0.04
	var y_crotch := chin + U * 3.05
	var y_short := chin + U * (3.4 if fem else 3.55)
	var y_knee := chin + U * 4.65
	var y_ankle := chin + U * 6.2
	var leg_x := hip_w * 0.5
	var thigh := hip_w * 0.5 + U * 0.02 * mus
	# Pernas (atrás dos shorts).
	for sx: float in [-1.0, 1.0]:
		var cl := PackedVector2Array([Vector2(cx + sx * leg_x, y_crotch - U * 0.3), Vector2(cx + sx * (leg_x + U * 0.02), y_knee),
			Vector2(cx + sx * (leg_x + U * 0.03), y_ankle)])
		var wd := PackedFloat32Array([thigh, U * (0.2 + 0.03 * mus), U * 0.12])
		_limb(cl, wd, U * (0.27 + 0.05 * mus), y_knee + U * 0.5, _skin, sx)
		# Pé
		var ft := Vector2(cx + sx * (leg_x + U * 0.05), feet - U * 0.08)
		_blob(ft + Vector2(sx * U * 0.08, -U * 0.02), U * 0.17, U * 0.11, _skin, 0.75)
	# Braços (atrás do tronco: o ombro do tronco cobre o encontro)
	var arm_w := U * (0.2 + 0.08 * mus + 0.05 * build) * (0.82 if fem else 1.0)
	for sx: float in [-1.0, 1.0]:
		var sh := Vector2(cx + sx * (sw - arm_w * 0.55), ys + U * 0.32)
		var el := Vector2(cx + sx * (sw + U * 0.08 + U * 0.1 * bf), chin + U * 2.05)
		var wr := Vector2(cx + sx * (sw + U * 0.14 + U * 0.12 * bf), chin + U * 3.0)
		var cl2 := PackedVector2Array([sh + Vector2(-sx * arm_w * 0.3, -U * 0.02), sh + (el - sh) * 0.45, el, wr])
		var wd2 := PackedFloat32Array([arm_w * 1.12, arm_w, arm_w * 0.82, arm_w * 0.62])
		_limb(cl2, wd2, arm_w * 1.08, (sh.y + el.y) * 0.5, _skin, sx)
		_glove(wr + Vector2(sx * U * 0.02, U * 0.22), U, sx)
	# Tronco
	var col_t := _skin
	var rows := [
		[chin - U * 0.25, nw], [ys - U * 0.02, nw * 1.05], [ys + U * 0.03, lerpf(nw, sw, 0.55)], [ys + U * 0.1, sw * 0.86], [ys + U * 0.3, sw * 1.08],
		[ys + U * 0.55, sw * 1.0], [y_chest, chest_w], [chin + U * 1.6, lerpf(chest_w, waist_w, 0.55)], [y_waist, waist_w], [y_hip, hip_w], [y_crotch, hip_w * 1.02]]
	_torso(cx, rows, col_t, mus, bf, fem)
	# Shorts
	_shorts(cx, y_hip - U * 0.12, y_crotch, y_short, hip_w, leg_x, thigh, U)
	if fem:
		_top(cx, ys, y_chest, chest_w, sw, U)
	_tattoos(cx, sw, ys, y_chest, arm_w, chin, U)
	# Pescoço por cima dos ombros, até o queixo
	var neck := PackedVector2Array()
	var ncols := PackedColorArray()
	for i in 9:
		var t := float(i) / 8.0
		var x := lerpf(-1.0, 1.0, t)
		neck.append(Vector2(cx + x * nw, chin - U * 0.35))
		ncols.append(_lit(_skin, x, -0.1))
	for i in 9:
		var t := 1.0 - float(i) / 8.0
		var x := lerpf(-1.0, 1.0, t)
		neck.append(Vector2(cx + x * nw * (1.08 + 0.1 * trap), ys + U * 0.04))
		ncols.append(_lit(_skin, x, 0.05).darkened(0.12 * (1.0 - absf(x))))
	draw_polygon(neck, ncols)
	# Sombra do queixo no pescoço
	_soft(Vector2(cx, chin + U * 0.06), nw * 0.95, U * 0.1, Color(_skin.darkened(0.55), 0.35))
	# Cabeça
	if _head == null:
		_head = PortraitView.new()
		_head.head_only = true
		_head.cutout = true
		_head.stage = false
		_head.framing = PortraitView.FRAME_CLASSIC
		_head.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_head)
	_head.size = Vector2(s, s)
	_head.position = hc - Vector2(s * 0.5, s * 0.4)
	if _head.face_seed != face_seed or _head.eth != eth or _head.age != age or _head.look != look:
		_head.set_face(face_seed, eth, age, look)
	_head.queue_redraw()


## Luz de cilindro: `x` de -1 (lado esquerdo, aceso) a 1, `y` desce a luz (0 em cima).
func _lit(base: Color, x: float, y: float) -> Color:
	var nrm := Vector3(x * 0.85, -0.25, sqrt(maxf(0.05, 1.0 - x * x * 0.72))).normalized()
	var l := PortraitView.LIGHT.normalized()
	var diff := clampf((nrm.dot(l) + 0.25) / 1.25, 0.0, 1.0)
	var lum := PortraitView.AMBIENT + PortraitView.KEY * diff - 0.22 * clampf(y, 0.0, 1.2)
	return PortraitView._shade(base, lum * 0.95)


## Membro como uma faixa ao longo da linha central (`cl`) com meias larguras `wd`; `bulge` engrossa
## no ponto `bulge_y` (bíceps, panturrilha).
func _limb(cl: PackedVector2Array, wd: PackedFloat32Array, bulge: float, bulge_y: float, base: Color, sx: float) -> void:
	var n := 14
	var cols := 6
	var pts: Array = []
	var y0 := cl[0].y
	var y1 := cl[cl.size() - 1].y
	for i in n + 1:
		var t := float(i) / n
		var fp := t * (cl.size() - 1)
		var j := mini(int(fp), cl.size() - 2)
		var lt := fp - j
		var c := cl[j].lerp(cl[j + 1], lt)
		var w := lerpf(wd[j], wd[j + 1], lt)
		w = maxf(w, lerpf(w, bulge, exp(-pow((c.y - bulge_y) / ((y1 - y0) * 0.18), 2.0))))
		var dir := (cl[j + 1] - cl[j]).normalized()
		var nrm := Vector2(-dir.y, dir.x)
		if nrm.x < 0.0:
			nrm = -nrm
		var row: Array = []
		for k in cols + 1:
			var u := lerpf(-1.0, 1.0, float(k) / cols)
			row.append([c + nrm * w * u, _lit(base, u, (c.y - y0) / maxf(1.0, size.y) * 2.5)])
		pts.append(row)
	_grid(pts)
	# Contorno do lado da sombra
	var edge := PackedVector2Array()
	for row: Array in pts:
		edge.append((row[cols] as Array)[0])
	draw_polyline(edge, Color(base.darkened(0.6), 0.35), 1.0, true)


func _grid(pts: Array) -> void:
	for i in pts.size() - 1:
		var a: Array = pts[i]
		var b: Array = pts[i + 1]
		for k in a.size() - 1:
			var q := PackedVector2Array([a[k][0], a[k + 1][0], b[k + 1][0], b[k][0]])
			var qc := PackedColorArray([a[k][1], a[k + 1][1], b[k + 1][1], b[k][1]])
			draw_polygon(q, qc)


## Tronco: linhas [y, meia largura] de cima para baixo, com peitoral, abdômen e umbigo pela
## definição (músculo menos gordura).
func _torso(cx: float, rows: Array, base: Color, mus: float, bf: float, fem: bool) -> void:
	var cols := 10
	var pts: Array = []
	var y_top: float = rows[0][0]
	var y_bot: float = rows[rows.size() - 1][0]
	var n := 22
	for i in n + 1:
		var y := lerpf(y_top, y_bot, float(i) / n)
		var w := _row_w(rows, y)
		var row: Array = []
		for k in cols + 1:
			var u := lerpf(-1.0, 1.0, float(k) / cols)
			row.append([Vector2(cx + u * w, y), _lit(base, u * 0.8, (y - y_top) / (y_bot - y_top) * 0.7)])
		pts.append(row)
	_grid(pts)
	var U := (y_bot - y_top) / 3.3
	var defn := clampf(mus * (1.0 - bf * 1.8), 0.1, 1.0) * (0.5 if fem else 1.0)
	var shade := Color(base.darkened(0.55), 0.0)
	var y_chest: float = rows[6][0]
	var cw: float = rows[6][1]
	# Deltoide: a curva que separa o ombro do peitoral e a dobra da axila
	var y_sh: float = rows[4][0]
	var swd: float = float(rows[4][1]) / 1.08
	for sx: float in [-1.0, 1.0]:
		var dl := PackedVector2Array()
		for i in 9:
			var t := float(i) / 8.0
			dl.append(Vector2(cx + sx * swd * lerpf(0.62, 0.86, t), y_sh - U * 0.12 + t * U * 0.62 - sin(t * PI) * U * 0.05))
		draw_polyline(dl, Color(shade, 0.18 + 0.2 * defn), maxf(1.0, U * 0.03), true)
		_soft(Vector2(cx + sx * swd * 0.93, y_sh + U * 0.55), U * 0.08, U * 0.16, Color(shade, 0.35))
	if not fem:
		# Dobra de baixo do peitoral e sulco do esterno
		for sx: float in [-1.0, 1.0]:
			var arc := PackedVector2Array()
			for i in 9:
				var t := float(i) / 8.0
				arc.append(Vector2(cx + sx * lerpf(U * 0.04, cw * 0.78, t), y_chest + U * 0.12 + sin(t * PI * 0.85) * U * 0.12 - t * U * 0.12))
			draw_polyline(arc, Color(shade, 0.35 * defn + 0.08), maxf(1.0, U * 0.035), true)
		draw_line(Vector2(cx, y_chest - U * 0.35), Vector2(cx, y_chest + U * 0.15), Color(shade, 0.25 * defn), maxf(1.0, U * 0.025), true)
		# Mamilos
		for sx: float in [-1.0, 1.0]:
			_soft(Vector2(cx + sx * cw * 0.5, y_chest + U * 0.12), U * 0.05, U * 0.04, Color(base.darkened(0.4), 0.6))
		# Abdômen: linha alba e três linhas de gomos (só quem é seco)
		if defn > 0.35:
			var a := (defn - 0.35) / 0.65
			var y_abs0 := y_chest + U * 0.35
			draw_line(Vector2(cx, y_abs0), Vector2(cx, y_abs0 + U * 1.1), Color(shade, 0.3 * a), maxf(1.0, U * 0.022), true)
			for r in 3:
				var yy := y_abs0 + U * (0.25 + r * 0.3)
				for sx: float in [-1.0, 1.0]:
					draw_line(Vector2(cx + sx * U * 0.04, yy), Vector2(cx + sx * U * 0.26, yy - U * 0.03), Color(shade, 0.22 * a), maxf(1.0, U * 0.02), true)
			# Oblíquos (o "V")
			for sx: float in [-1.0, 1.0]:
				draw_line(Vector2(cx + sx * U * 0.42, y_abs0 + U * 0.75), Vector2(cx + sx * U * 0.18, y_abs0 + U * 1.3), Color(shade, 0.25 * a), maxf(1.0, U * 0.025), true)
	# Barriga: brilho redondo e a sombra embaixo (pesado macio)
	if bf > 0.22:
		var b := clampf((bf - 0.22) / 0.3, 0.0, 1.0)
		var yb := y_chest + U * 1.1
		_soft(Vector2(cx - U * 0.08, yb - U * 0.1), U * 0.55, U * 0.4, Color(base.lightened(0.18), 0.25 * b))
		draw_arc(Vector2(cx, yb - U * 0.2), U * 0.62, PI * 0.15, PI * 0.85, 16, Color(shade, 0.3 * b), maxf(1.0, U * 0.03), true)
	# Umbigo
	_soft(Vector2(cx, y_chest + U * 1.25), U * 0.035, U * 0.05, Color(base.darkened(0.5), 0.7))
	# Clavículas
	var yc: float = rows[1][0] + U * 0.16
	for sx: float in [-1.0, 1.0]:
		draw_line(Vector2(cx + sx * U * 0.06, yc), Vector2(cx + sx * float(rows[3][1]) * 0.62, yc - U * 0.04), Color(base.lightened(0.2), 0.3), maxf(1.0, U * 0.03), true)


static func _row_w(rows: Array, y: float) -> float:
	if y <= float(rows[0][0]):
		return rows[0][1]
	for i in rows.size() - 1:
		var a: Array = rows[i]
		var b: Array = rows[i + 1]
		if y <= float(b[0]):
			var t := (y - float(a[0])) / maxf(0.001, float(b[0]) - float(a[0]))
			t = t * t * (3.0 - 2.0 * t)
			return lerpf(float(a[1]), float(b[1]), t)
	return rows[rows.size() - 1][1]


## Shorts de luta: cós, faixa lateral na cor de destaque e a abertura nas coxas.
func _shorts(cx: float, y0: float, y_crotch: float, y1: float, hip_w: float, leg_x: float, thigh: float, U: float) -> void:
	var cols := 10
	for sx: float in [-1.0, 1.0]:
		var pts: Array = []
		var n := 8
		for i in n + 1:
			var t := float(i) / n
			var y := lerpf(y0, y1, t)
			var outer := hip_w * 1.04 + U * 0.06 * t
			var inner := 0.0 if y < y_crotch else (leg_x - thigh * 1.05) * smoothstep(y_crotch, y_crotch + U * 0.2, y)
			var row: Array = []
			for k in cols / 2 + 1:
				var u := float(k) / (cols / 2)
				var x := lerpf(inner, outer, u)
				var xn := sx * x / (hip_w * 1.1)
				row.append([Vector2(cx + sx * x, y), _lit(shorts, xn, t * 0.6)])
			if sx < 0.0:
				row.reverse()
			pts.append(row)
		_grid(pts)
		# Faixa lateral
		draw_line(Vector2(cx + sx * hip_w * 0.98, y0 + U * 0.1), Vector2(cx + sx * (hip_w * 1.04 + U * 0.05), y1), Color(trim, 0.9), maxf(1.5, U * 0.07), true)
	# Cós
	var band := PackedVector2Array([Vector2(cx - hip_w * 1.03, y0), Vector2(cx + hip_w * 1.03, y0), Vector2(cx + hip_w * 1.03, y0 + U * 0.13), Vector2(cx - hip_w * 1.03, y0 + U * 0.13)])
	draw_polygon(band, PackedColorArray([_lit(trim, -0.9, 0.0), _lit(trim, 0.9, 0.0), _lit(trim, 0.9, 0.1), _lit(trim, -0.9, 0.1)]))
	# Dobra entre as pernas
	draw_line(Vector2(cx, y_crotch - U * 0.25), Vector2(cx, y1 - U * 0.1), Color(shorts.darkened(0.6), 0.5), maxf(1.0, U * 0.03), true)


## Top esportivo das lutadoras.
func _top(cx: float, ys: float, y_chest: float, cw: float, sw: float, U: float) -> void:
	var y0 := ys + U * 0.42
	var y1 := y_chest + U * 0.35
	var pts: Array = []
	for i in 7:
		var t := float(i) / 6.0
		var y := lerpf(y0, y1, t)
		var w := lerpf(cw * 0.98, cw * 0.9, t)
		var row: Array = []
		for k in 11:
			var u := lerpf(-1.0, 1.0, float(k) / 10.0)
			var bump := 0.0 if t > 0.75 else 0.08 * sin(PI * clampf(t / 0.75, 0.0, 1.0))
			row.append([Vector2(cx + u * w, y), _lit(glove, u, t * 0.5 - bump).lightened(0.05)])
		pts.append(row)
	_grid(pts)
	for sx: float in [-1.0, 1.0]:
		draw_line(Vector2(cx + sx * cw * 0.55, y0 + U * 0.02), Vector2(cx + sx * sw * 0.45, ys + U * 0.05), _lit(glove, sx * 0.5, 0.0), maxf(2.0, U * 0.12), true)
	draw_line(Vector2(cx - cw * 0.9, y1), Vector2(cx + cw * 0.9, y1), trim, maxf(1.5, U * 0.06), true)


## Luva de MMA: punho fechado e a faixa do velcro na cor de destaque.
func _glove(c: Vector2, U: float, sx: float) -> void:
	_blob(c, U * 0.25, U * 0.3, glove, 1.0)
	var band := c + Vector2(0, -U * 0.26)
	draw_line(band + Vector2(-U * 0.2, 0), band + Vector2(U * 0.2, 0), trim, maxf(1.5, U * 0.1), true)
	# Dedos de fora (luva aberta): a pele aparece embaixo do punho
	_blob(c + Vector2(0, U * 0.2), U * 0.17, U * 0.07, _skin.darkened(0.1), 0.6)
	_blob(c + Vector2(0, -U * 0.02), U * 0.2, U * 0.2, glove, 1.0)
	draw_arc(c, U * 0.2, PI * 0.1 if sx > 0 else PI * 0.6, PI * 0.4 if sx > 0 else PI * 0.9, 6, Color(1, 1, 1, 0.12), maxf(1.0, U * 0.03), true)


## Elipse com luz de cilindro.
func _blob(c: Vector2, rx: float, ry: float, base: Color, lum: float) -> void:
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	pts.append(c + Vector2(-rx * 0.3, -ry * 0.3))
	cols.append(_lit(base, -0.4, 0.0).lightened(0.05 * lum))
	for i in 25:
		var a := float(i) / 24.0 * TAU
		var p := Vector2(cos(a), sin(a))
		pts.append(c + Vector2(p.x * rx, p.y * ry))
		cols.append(_lit(base, p.x, 0.3 + 0.3 * p.y))
	var idx := PackedInt32Array()
	for i in 24:
		idx.append_array([0, i + 1, i + 2])
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), idx, pts, cols)


func _soft(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array([c])
	var cols := PackedColorArray([col])
	for i in 17:
		var a := float(i) / 16.0 * TAU
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
		cols.append(Color(col, 0.0))
	var idx := PackedInt32Array()
	for i in 16:
		idx.append_array([0, i + 1, i + 2])
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), idx, pts, cols)


## Tatuagens (`body_tat`): 1 ombro; 2 os dois ombros e escrita no peito; 3 manga fechada num braço.
func _tattoos(cx: float, sw: float, ys: float, y_chest: float, arm_w: float, chin: float, U: float) -> void:
	var n := int(_f.get("body_tat", 0))
	if n <= 0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([face_seed, "tatuagem"])
	var dark := clampf(float(_f["skin_i"]) / 9.0, 0.0, 1.0)
	var ink := Color(0.1, 0.12, 0.17, lerpf(0.6, 0.4, dark))
	var lw := maxf(1.0, U * 0.03)
	var first := -1.0 if rng.randf() < 0.5 else 1.0
	var sides: Array = [first] if n == 1 else [first, -first]
	for sx: float in sides:
		var c := Vector2(cx + sx * (sw - arm_w * 0.5), ys + U * 0.45)
		var r := arm_w * 0.85
		for k in 5:
			var a := -PI * 0.5 + (k - 2) * 0.5
			var p0 := c + Vector2(cos(a), sin(a)) * r * 0.35
			var p1 := c + Vector2(cos(a + sx * 0.55), sin(a + sx * 0.55)) * r * 1.2
			var p2 := c + Vector2(cos(a + sx * 0.15), sin(a + sx * 0.15)) * r * 0.9
			draw_colored_polygon(PackedVector2Array([p0, p1, p2]), ink)
	if n >= 2:
		var sx2 := -first
		var y0 := y_chest - U * 0.48
		for k in 2:
			var x0 := cx + sx2 * U * 0.16
			var pts := PackedVector2Array()
			var letters := rng.randi_range(5, 8)
			for i in letters * 6 + 1:
				var t := float(i) / 6.0
				var x := x0 + sx2 * t * U * 0.07
				var loop := sin(t * TAU) * U * 0.03
				pts.append(Vector2(x + cos(t * TAU) * U * 0.015 * sx2, y0 + k * U * 0.12 - loop))
			draw_polyline(pts, Color(ink, ink.a * 0.85), maxf(1.0, lw * 0.6), true)
	if n >= 3:
		var sh := Vector2(cx + first * (sw - arm_w * 0.4), ys + U * 0.5)
		for k in 10:
			var y := sh.y + U * 0.15 * k
			draw_line(Vector2(sh.x - arm_w * 0.7 + first * U * 0.02 * k, y), Vector2(sh.x + arm_w * 0.7 + first * U * 0.02 * k, y + U * 0.05), Color(ink, ink.a * 0.7), lw * 1.3, true)
			_soft(Vector2(sh.x + first * U * 0.02 * k + rng.randf_range(-0.4, 0.4) * arm_w, y + U * 0.07), arm_w * 0.35, U * 0.05, Color(ink, ink.a * 0.6))
