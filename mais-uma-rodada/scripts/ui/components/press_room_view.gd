class_name PressRoomView
extends Control
## Sala de imprensa do clube, desenhada na hora: painel de patrocínio ao fundo (escudo do clube
## alternado com as marcas dos patrocinadores, como os backdrops de verdade), o treinador atrás
## da mesa com a toalha nas cores do clube, microfones das rádios e TVs, garrafinha e placa, e
## os repórteres e cinegrafistas em primeiro plano. Os flashes das câmeras piscam de vez em quando.
## `compact` desliga a animação (miniatura no feed das redes).

var compact := false
var club_name := ""
var coach_name := ""
var c1 := Color("#1B3A8C")
var c2 := Color("#FFFFFF")
var brands: Array = [] # [{n, c, t, m, logo}] (BrandCatalog)
var outlets: Array = [] # nomes dos veículos (cubos dos microfones)
var crest_spec: Dictionary = {}

var _crests: Array = [] # CrestView do painel
var _skirt_crest: CrestView
var _front: Control
var _fx: Control
var _flashes: Array = [] # [pos, idade]
var _t := 0.0
var _next_flash := 0.6
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func setup(w: GameWorld, c: Club) -> void:
	club_name = c.short_name
	coach_name = w.manager_name if w.is_user_club(c.id) else People.coach_name(w, c.id)
	c1 = Color(c.color1)
	c2 = Color(c.color2)
	crest_spec = c.crest
	brands = brands_for(c)
	outlets.clear()
	for j: Dictionary in People.journalists(w):
		outlets.append(String(j.get("o", "")))
	if outlets.is_empty():
		outlets = Array(People.OUTLETS_PT).slice(0, 5)
	_rng.seed = hash([c.key, "sala"])


## Marcas do painel: patrocinadores do clube (camisa, fornecedora) e, se faltar, parceiros da liga.
static func brands_for(c: Club) -> Array:
	# Patrocinadores do clube (master primeiro) e, se faltarem marcas no painel, anunciantes do
	# país do clube — tudo do BrandCatalog, a mesma fonte das camisas e das placas.
	var out: Array = []
	var seen: Dictionary = {}
	for b: Dictionary in BrandCatalog.for_club(null, c):
		var n := String(b.get("n", ""))
		if n != "" and not seen.has(n):
			seen[n] = true
			out.append({"n": n, "c": String(b.get("c", "#1B1B1B")), "t": String(b.get("t", "#FFFFFF")), "m": String(b.get("m", "")), "logo": String(b.get("logo", ""))})
	if out.size() < 4:
		var r := RandomNumberGenerator.new()
		r.seed = hash([c.key, "painel"])
		var pool: Array = BrandCatalog.brands_for(c.nation, BrandCatalog.club_tier(c), "placa", c.tier, c.city)
		RngUtil.shuffle(r, pool)
		for b: Dictionary in pool:
			if out.size() >= 4:
				break
			if not seen.has(String(b["n"])):
				seen[String(b["n"])] = true
				out.append({"n": String(b["n"]), "c": String(b.get("c", "#1B1B1B")), "t": String(b.get("t", "#FFFFFF")), "m": String(b.get("m", "")), "logo": ""})
	return out


func _ready() -> void:
	_front = Control.new()
	_front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_front.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_front.draw.connect(_draw_front)
	add_child(_front)
	_skirt_crest = CrestView.new()
	_skirt_crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skirt_crest.crest = crest_spec
	add_child(_skirt_crest)
	_fx = Control.new()
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fx.draw.connect(_draw_fx)
	add_child(_fx)
	resized.connect(_layout)
	_layout()
	set_process(not compact)


func _process(delta: float) -> void:
	_t += delta
	_next_flash -= delta
	if _next_flash <= 0.0:
		_next_flash = _rng.randf_range(0.5, 2.2)
		var n := 1 if _rng.randf() < 0.7 else 2
		for i in n:
			_flashes.append([Vector2(_rng.randf_range(0.08, 0.92) * size.x, size.y * _rng.randf_range(0.8, 0.95)), 0.0])
	for f in _flashes:
		f[1] += delta
	_flashes = _flashes.filter(func(f): return f[1] < 0.35)
	_fx.queue_redraw()


# ---------------------------------------------------------------------------
# Geometria
# ---------------------------------------------------------------------------

func _tile() -> Vector2:
	var tw := maxf(70.0, size.x / (5.5 if compact else 6.5))
	return Vector2(tw, tw * 0.46)


func _table_rect() -> Rect2:
	var w := size.x
	var h := size.y
	return Rect2(w * 0.2, h * 0.6, w * 0.6, h * 0.24)


## Posições das peças do painel: [Rect2, índice (−1 = escudo, senão marca)].
func _tiles() -> Array:
	var out: Array = []
	var t := _tile()
	var back_h := size.y * 0.72
	var rows := int(ceil(back_h / t.y)) + 1
	var k := 0
	for row in rows:
		var off := -t.x * 0.5 if row % 2 == 1 else 0.0
		var x := off - t.x * 0.25
		var col := 0
		while x < size.x + t.x:
			var r := Rect2(Vector2(x, row * t.y), t).grow(-5.0)
			var crest := (col + row * 2) % 3 == 0
			out.append([r, -1 if crest else k])
			if not crest:
				k += 1
			x += t.x
			col += 1
	return out


func _layout() -> void:
	if _front == null:
		return
	for cv in _crests:
		cv.queue_free()
	_crests.clear()
	var i := 0
	for tl in _tiles():
		if int(tl[1]) != -1:
			continue
		var r: Rect2 = tl[0]
		var cv := CrestView.new()
		cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cv.crest = crest_spec
		var s := r.size.y * 0.92
		cv.position = r.get_center() - Vector2(s, s) * 0.5
		cv.size = Vector2(s, s)
		add_child(cv)
		move_child(cv, i)
		_crests.append(cv)
		i += 1
	var tb := _table_rect()
	var cs := tb.size.y * 0.62
	_skirt_crest.position = Vector2(tb.position.x + tb.size.x * 0.5 - cs * 0.5, tb.position.y + tb.size.y * 0.3)
	_skirt_crest.size = Vector2(cs, cs)
	queue_redraw()
	_front.queue_redraw()


# ---------------------------------------------------------------------------
# Desenho
# ---------------------------------------------------------------------------

## Fundo: parede do painel, luz dos refletores e as marcas.
func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), Color("#15161A"))
	var back := Rect2(0, 0, w, h * 0.72)
	var wall := Color("#EEF0F2")
	var steps := 12
	for i in steps:
		var t := float(i) / float(steps)
		draw_rect(Rect2(0, back.size.y * t, w, back.size.y / steps + 1.0), wall.darkened(0.04 + absf(t - 0.3) * 0.12))
	var font := get_theme_font(&"font", &"Stat")
	for tl in _tiles():
		var idx := int(tl[1])
		if idx == -1 or brands.is_empty():
			continue
		var r: Rect2 = tl[0]
		if r.position.y > back.end.y:
			continue
		var b: Dictionary = brands[idx % brands.size()]
		var bg := Color(String(b.get("c", "#1B1B1B")))
		var tx := Color(String(b.get("t", "#FFFFFF")))
		var logo := r.grow_individual(-r.size.x * 0.06, -r.size.y * 0.16, -r.size.x * 0.06, -r.size.y * 0.16)
		var sb := StyleBoxFlat.new()
		sb.bg_color = bg
		sb.set_corner_radius_all(int(logo.size.y * 0.22))
		sb.anti_aliasing = true
		draw_style_box(sb, logo)
		var txt := String(b.get("n", "")).to_upper()
		var mark := String(b.get("m", ""))
		if mark == "":
			mark = String(b.get("logo", ""))
		var mu := logo.size.y * 0.24
		var mark_w := mu * 2.6 if BrandMark.has(mark) and mu >= 2.5 else 0.0
		var fs := int(logo.size.y * 0.5)
		var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		if tw > logo.size.x - 8.0 - mark_w:
			fs = maxi(7, int(fs * (logo.size.x - 8.0 - mark_w) / tw))
			tw = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var x0 := logo.get_center().x - (tw + mark_w) * 0.5
		if mark_w > 0.0:
			BrandMark.draw(self, mark, Vector2(x0 + mu, logo.get_center().y), mu, tx, bg)
		draw_string(font, Vector2(x0 + mark_w, logo.get_center().y + fs * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, tx)
	# Rodapé do painel e piso.
	draw_rect(Rect2(0, back.end.y, w, 4), c1)
	for i in 6:
		var t2 := float(i) / 6.0
		draw_rect(Rect2(0, back.end.y + 4 + (h - back.end.y) * t2, w, (h - back.end.y) / 6.0 + 1.0), Color("#23252B").darkened(t2 * 0.5))


## Frente: treinador, mesa, microfones e a plateia de repórteres.
func _draw_front() -> void:
	var cv := _front
	var w := size.x
	var h := size.y
	var tb := _table_rect()
	var font := get_theme_font(&"font", &"Stat")
	# Luz dos refletores sobre o painel (por cima dos escudos também).
	for i in 6:
		cv.draw_circle(Vector2(w * 0.5, h * 0.1), h * (0.55 - i * 0.07), Color(1, 1, 1, 0.035), true, -1.0, true)
	cv.draw_rect(Rect2(0, 0, w, h * 0.72), Color(0, 0, 0, 0.05))
	# Treinador (silhueta de terno) atrás da mesa.
	var cx := w * 0.5
	var head_r := h * 0.078
	var neck_y := tb.position.y - h * 0.15
	var sw := h * 0.3 # meia largura dos ombros
	var suit := Color("#1E2229")
	var sh := PackedVector2Array([
		Vector2(cx - sw * 1.05, tb.position.y + 2), Vector2(cx - sw, neck_y + head_r * 0.9),
		Vector2(cx - sw * 0.8, neck_y + head_r * 0.35), Vector2(cx - head_r * 0.9, neck_y + head_r * 0.15), Vector2(cx + head_r * 0.9, neck_y + head_r * 0.15),
		Vector2(cx + sw * 0.8, neck_y + head_r * 0.35), Vector2(cx + sw, neck_y + head_r * 0.9), Vector2(cx + sw * 1.05, tb.position.y + 2)])
	cv.draw_colored_polygon(sh, suit)
	cv.draw_colored_polygon(PackedVector2Array([Vector2(cx - head_r * 0.6, neck_y + head_r * 0.2), Vector2(cx + head_r * 0.6, neck_y + head_r * 0.2), Vector2(cx, tb.position.y)]), Color("#F4F4F4"))
	cv.draw_colored_polygon(PackedVector2Array([Vector2(cx - head_r * 0.16, neck_y + head_r * 0.35), Vector2(cx + head_r * 0.16, neck_y + head_r * 0.35), Vector2(cx + head_r * 0.22, tb.position.y), Vector2(cx - head_r * 0.22, tb.position.y)]), c1)
	var skin := Color("#B98563")
	var hc := Vector2(cx, neck_y - head_r * 0.85)
	cv.draw_rect(Rect2(cx - head_r * 0.4, hc.y, head_r * 0.8, neck_y + head_r * 0.25 - hc.y), skin.darkened(0.15))
	cv.draw_circle(hc - Vector2(0, head_r * 0.14), head_r * 1.02, Color("#231C17"), true, -1.0, true)
	cv.draw_circle(hc + Vector2(-head_r * 0.9, head_r * 0.1), head_r * 0.2, skin.darkened(0.1), true, -1.0, true)
	cv.draw_circle(hc + Vector2(head_r * 0.9, head_r * 0.1), head_r * 0.2, skin.darkened(0.1), true, -1.0, true)
	cv.draw_set_transform(hc + Vector2(0, head_r * 0.08), 0.0, Vector2(0.88, 1.0))
	cv.draw_circle(Vector2.ZERO, head_r * 0.92, skin, true, -1.0, true)
	cv.draw_set_transform_matrix(Transform2D.IDENTITY)
	cv.draw_colored_polygon(PackedVector2Array([hc + Vector2(-head_r * 0.85, -head_r * 0.25), hc + Vector2(-head_r * 0.6, -head_r * 0.85), hc + Vector2(head_r * 0.6, -head_r * 0.85), hc + Vector2(head_r * 0.85, -head_r * 0.25), hc + Vector2(0, -head_r * 0.5)]), Color("#231C17"))
	cv.draw_circle(hc + Vector2(-head_r * 0.32, head_r * 0.05), head_r * 0.08, Color("#1A1411"), true, -1.0, true)
	cv.draw_circle(hc + Vector2(head_r * 0.32, head_r * 0.05), head_r * 0.08, Color("#1A1411"), true, -1.0, true)
	cv.draw_line(hc + Vector2(-head_r * 0.22, head_r * 0.5), hc + Vector2(head_r * 0.22, head_r * 0.5), skin.darkened(0.35), 2.0, true)
	# Mesa: tampo e toalha na cor do clube.
	cv.draw_rect(Rect2(tb.position.x - 6, tb.position.y - 6, tb.size.x + 12, 8), Color("#D9DCE0"))
	cv.draw_rect(tb, c1.darkened(0.15))
	cv.draw_rect(Rect2(tb.position.x, tb.position.y, tb.size.x, 3), c2.lerp(c1, 0.3))
	cv.draw_rect(Rect2(tb.position.x, tb.end.y - 4, tb.size.x, 4), Color(0, 0, 0, 0.35))
	var tc := c2 if absf(c2.get_luminance() - c1.get_luminance()) > 0.25 else Color.WHITE
	var fs := int(clampf(tb.size.y * 0.2, 9.0, 22.0))
	var name_txt := club_name.to_upper()
	var tw := font.get_string_size(name_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var side_w := tb.size.x * 0.5 - tb.size.y * 0.45
	if tw > side_w - 10.0:
		fs = maxi(7, int(fs * (side_w - 10.0) / tw))
		tw = font.get_string_size(name_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	cv.draw_string(font, Vector2(tb.position.x + side_w * 0.5 - tw * 0.5, tb.get_center().y + fs * 0.36), name_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, tc)
	if not brands.is_empty():
		var main: Dictionary = brands[0]
		var bt := String(main.get("n", "")).to_upper()
		var bw := font.get_string_size(bt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var box := Rect2(tb.end.x - side_w * 0.5 - bw * 0.5 - 8, tb.get_center().y - fs * 0.75, bw + 16, fs * 1.5)
		cv.draw_rect(box, Color(String(main.get("c", "#1B1B1B"))))
		cv.draw_string(font, Vector2(box.position.x + 8, tb.get_center().y + fs * 0.36), bt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(String(main.get("t", "#FFFFFF"))))
	# Garrafinha e placa com o nome.
	var bx := tb.position.x + tb.size.x * 0.14
	cv.draw_rect(Rect2(bx, tb.position.y - tb.size.y * 0.55, tb.size.y * 0.16, tb.size.y * 0.5), Color(0.75, 0.88, 1.0, 0.75))
	cv.draw_rect(Rect2(bx, tb.position.y - tb.size.y * 0.42, tb.size.y * 0.16, tb.size.y * 0.12), c1.lightened(0.2))
	var plate := Rect2(tb.end.x - tb.size.x * 0.3, tb.position.y - tb.size.y * 0.3, tb.size.x * 0.2, tb.size.y * 0.26)
	cv.draw_rect(plate, Color("#F5F5F5"))
	var pn := coach_name.to_upper()
	var pfs := int(plate.size.y * 0.5)
	var pw := font.get_string_size(pn, HORIZONTAL_ALIGNMENT_LEFT, -1, pfs).x
	if pw > plate.size.x - 6.0:
		pfs = maxi(6, int(pfs * (plate.size.x - 6.0) / pw))
		pw = font.get_string_size(pn, HORIZONTAL_ALIGNMENT_LEFT, -1, pfs).x
	cv.draw_string(font, plate.get_center() + Vector2(-pw * 0.5, pfs * 0.36), pn, HORIZONTAL_ALIGNMENT_LEFT, -1, pfs, Color("#222222"))
	# Microfones com os cubos dos veículos.
	var mics := mini(6, maxi(3, outlets.size()))
	var cols := [Color("#E5484D"), Color("#4EA8DE"), Color("#FFC940"), Color("#3DBE7A"), Color("#C77DFF"), Color("#F0A35E")]
	for i in mics:
		var t := (float(i) + 0.5) / float(mics)
		var base := Vector2(cx + (t - 0.5) * sw * 2.4, tb.position.y - 4)
		var tip := Vector2(cx + (t - 0.5) * head_r * 2.2, neck_y + head_r * 0.7)
		cv.draw_line(base, tip, Color("#111111"), 2.0, true)
		var dir := (tip - base).normalized()
		var cube_c := base.lerp(tip, 0.72)
		var cs := h * 0.055
		cv.draw_set_transform(cube_c, dir.angle() + PI / 2.0, Vector2.ONE)
		cv.draw_rect(Rect2(-cs * 0.5, -cs * 0.5, cs, cs), cols[i % cols.size()])
		var on := String(outlets[i % outlets.size()]) if not outlets.is_empty() else ""
		var ini := ""
		for part in on.split(" ", false):
			if part.length() > 2:
				ini += part.substr(0, 1).to_upper()
		ini = ini.substr(0, 2)
		var ifs := int(cs * 0.5)
		var iw := font.get_string_size(ini, HORIZONTAL_ALIGNMENT_LEFT, -1, ifs).x
		cv.draw_string(font, Vector2(-iw * 0.5, ifs * 0.36), ini, HORIZONTAL_ALIGNMENT_LEFT, -1, ifs, Color.WHITE)
		cv.draw_set_transform_matrix(Transform2D.IDENTITY)
		cv.draw_circle(tip, h * 0.022, Color("#2B2B2B"), true, -1.0, true)
		cv.draw_circle(tip - Vector2(1, 1), h * 0.012, Color("#555555"), true, -1.0, true)
	# Repórteres e câmeras em primeiro plano (contraluz).
	var crowd := Color("#0B0C0F")
	var r := RandomNumberGenerator.new()
	r.seed = hash([club_name, "plateia"])
	var hx := -10.0
	while hx < w + 20.0:
		var hr := h * r.randf_range(0.075, 0.1)
		var hy := h - hr * r.randf_range(0.6, 1.1)
		cv.draw_circle(Vector2(hx, hy), hr, crowd, true, -1.0, true)
		cv.draw_rect(Rect2(hx - hr * 1.6, hy + hr * 0.7, hr * 3.2, h), crowd)
		if r.randf() < 0.35:
			var cam := Rect2(hx - hr * 1.1, hy - hr * 1.9, hr * 2.2, hr * 1.3)
			cv.draw_rect(cam, Color("#15171B"))
			cv.draw_circle(cam.get_center() + Vector2(0, hr * 0.05), hr * 0.42, Color("#2B3038"), true, -1.0, true)
			cv.draw_circle(cam.get_center() + Vector2(0, hr * 0.05), hr * 0.22, Color("#4E5A6A"), true, -1.0, true)
		hx += hr * r.randf_range(2.1, 2.9)


func _draw_fx() -> void:
	for f in _flashes:
		var p: Vector2 = f[0]
		var a := 1.0 - float(f[1]) / 0.35
		for i in 5:
			_fx.draw_circle(p, size.y * (0.05 + i * 0.05), Color(1, 1, 1, 0.16 * a), true, -1.0, true)
		_fx.draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.05 * a))
