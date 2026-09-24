@tool
class_name PortraitView
extends Control
## Retrato 2D procedural com sombreamento suave. Cada parte grande (fundo, pele, orelhas, pescoço,
## camisa, cabelo, barba, olhos) é uma malha com cor por vértice calculada por uma função de luz:
## luz principal vindo de cima à esquerda, sombras quentes, brilho especular, órbitas, dorso do
## nariz, maçãs, sombra sob o lábio e o queixo. Cabelo, sobrancelhas e barba ganham fios por cima.
## Os traços vêm de FaceGen (semente + etnia + idade); uma foto importada no editor substitui tudo.
## O retrato pronto (malhas e traços) fica num cache global de comandos de desenho.

@export var face_seed: int = 12345:
	set(v):
		face_seed = v
		_dirty = true
		_invalidate()
@export var eth: int = 1:
	set(v):
		eth = v
		_dirty = true
		_invalidate()
@export var age: int = 25:
	set(v):
		age = v
		_dirty = true
		_invalidate()
@export var shirt_color: Color = Color("#1B3A8C"):
	set(v):
		shirt_color = v
		_invalidate()
@export var trim_color: Color = Color("#FFFFFF"):
	set(v):
		trim_color = v
		_invalidate()
@export var bg_color: Color = Color("#1D2B3C"):
	set(v):
		bg_color = v
		_invalidate()
## Roupa de treinador/dirigente (terno) em vez da camisa do clube.
@export var suit: bool = false:
	set(v):
		suit = v
		_invalidate()

var look: Dictionary = {}:
	set(v):
		look = v
		_dirty = true
		_invalidate()
var photo: Texture2D = null:
	set(v):
		photo = v
		queue_redraw()

## Parâmetros de cada penteado: tp/sd = volume no alto/nas laterais, hl = franja (desce a linha do
## cabelo), sb = até onde descem as laterais, fd = degradê (1 leve, 2 alto, 3 lateral raspada),
## tx = textura forçada, sp = silhueta (1 reto no alto, 2 espetado, 3 cacheado, 4 crista),
## bk = parte de trás, fr = peça da frente, fl = direção dos fios (0 para trás, 1 de lado, 2 para
## baixo, 3 repartido ao meio), op = opacidade, gl = brilho extra, lk = comprimento das mechas.
const STYLE_P: Array = [
	{"tp": 0.02, "sd": 0.0, "tx": "dots", "op": 0.6}, # raspado
	{"tp": 0.09, "sd": 0.05, "fd": 1, "fl": 1}, # curto
	{"tp": 0.13, "sd": 0.06, "fl": 1, "fr": "part"}, # repartido
	{"tp": 0.1, "sd": 0.04, "fd": 1, "fr": "quiff"}, # topete
	{"tp": 0.1, "sd": 0.0, "fd": 2}, # degradê
	{"tp": 0.24, "sd": 0.16, "sp": 3, "tx": "curl", "sb": 0.05}, # cacheado
	{"tp": 0.5, "sd": 0.42, "sp": 3, "tx": "coil", "bk": "afro"}, # black power
	{"tp": 0.12, "sd": 0.1, "tx": "locs", "bk": "dreads", "sb": 0.1}, # dreads
	{"tp": 0.1, "sd": 0.1, "sb": 0.25, "bk": "long", "fr": "locks", "lk": 1.3, "fl": 1}, # longo
	{"tp": 0.05, "sd": 0.03, "bk": "bun", "gl": 0.15}, # coque
	{"tp": 0.0, "sd": 0.0, "fd": 3, "sp": 4}, # moicano
	{}, # careca
	{"tp": 0.1, "sd": 0.04, "fd": 1, "gl": 0.3}, # para trás
	{"tp": 0.03, "sd": 0.02, "tx": "braid", "op": 0.75}, # nagô
	{"tp": 0.14, "sd": 0.05, "sp": 2, "fd": 1}, # arrepiado
	{"tp": 0.12, "sd": 0.08, "hl": 0.27, "fr": "fringe", "fl": 2, "sb": 0.05}, # franja
	{"tp": 0.15, "sd": 0.0, "fd": 3, "fl": 1, "gl": 0.15}, # undercut
	{"tp": 0.05, "sd": 0.02, "fd": 1, "op": 0.85}, # militar
	{"tp": 0.12, "sd": 0.0, "fd": 2, "fr": "pomp", "gl": 0.3}, # pompadour
	{"tp": 0.17, "sd": 0.15, "sb": 0.2, "tx": "wavy", "fr": "locks", "lk": 0.45, "fl": 1}, # ondulado médio
	{"tp": 0.12, "sd": 0.1, "sb": 0.22, "fl": 3, "fr": "locks", "lk": 0.4}, # repartido ao meio
	{"tp": 0.1, "sd": 0.05, "fd": 1, "bk": "mullet"}, # mullet
	{"tp": 0.03, "sd": 0.02, "bk": "pony", "gl": 0.25}, # rabo de cavalo
	{"tp": 0.2, "sd": 0.0, "fd": 2, "tx": "coil", "fr": "twists"}, # twists
	{"tp": 0.55, "sd": 0.02, "fd": 2, "sp": 1, "tx": "coil"}, # high top
	{"tp": 0.03, "sd": 0.02, "tx": "waves", "op": 0.9}, # waves
	{"tp": 0.08, "sd": 0.0, "hl": 0.14, "fd": 2, "fr": "crop", "fl": 2}, # crop
	{"tp": 0.14, "sd": 0.14, "sb": 0.3, "tx": "wavy", "bk": "long_short", "fr": "locks", "lk": 0.8, "fl": 1}, # surfista
	{"tp": 0.12, "sd": 0.11, "hl": 0.3, "fr": "fringe", "fl": 2, "sb": 0.08}, # tigela
	{"tp": 0.05, "sd": 0.03, "tx": "braid", "bk": "braids", "fr": "braid_locks", "lk": 1.3}, # box braids
	{"tp": 0.2, "sd": 0.15, "sp": 3, "tx": "coil"}, # afro curto
	{"tp": 0.03, "sd": 0.0, "fd": 3, "bk": "knot", "gl": 0.2}, # samurai
	{"tp": 0.3, "sd": 0.3, "sp": 3, "tx": "curl", "sb": 0.3, "bk": "curly_long"}, # cacheado longo
	{"tp": 0.08, "sd": 0.0, "fd": 2, "fr": "shaved_part"}, # degradê com risco
	{"tp": 0.14, "sd": 0.06, "tx": "wavy", "gl": 0.2}, # ondulado para trás
	{"tp": 0.2, "sd": 0.05, "fd": 1, "tx": "coil", "fr": "locs_top"}, # locs curtos
	{"tp": 0.16, "sd": 0.0, "fd": 4}, # burst fade
	{"tp": 0.36, "sd": 0.0, "fd": 2, "sp": 3, "tx": "coil"}, # afro com degradê
	{"tp": 0.16, "sd": 0.12, "sb": 0.18, "gl": 0.25, "tx": "wavy", "fr": "locks", "lk": 0.32}, # flow para trás
	{"tp": 0.16, "sd": 0.03, "fd": 1, "sp": 5, "fl": 1}, # topete bagunçado
	{"tp": 0.02, "sd": 0.0, "tx": "dots", "op": 0.62, "fr": "design"}, # máquina com desenho
	{"tp": 0.04, "sd": 0.0, "fd": 2, "tx": "braid", "op": 0.8}, # nagô com degradê
	{"tp": 0.0, "sd": 0.0, "fd": 3, "sp": 4, "tx": "curl"}, # moicano cacheado
	{"tp": 0.14, "sd": 0.1, "hl": 0.2, "fd": 1, "fr": "fringe", "fl": 2, "sb": 0.05}, # liso médio
	{"tp": 0.14, "sd": 0.05, "hl": 0.1, "fd": 2, "fr": "side_fringe", "fl": 1}, # franja lateral
	{"tp": 0.2, "sd": 0.1, "tx": "locs", "fr": "locs_top", "sb": 0.05}, # freeform
	{"tp": 0.07, "sd": 0.02, "fd": 1, "fl": 1, "fr": "part", "op": 0.95}, # degradê social
]

const LIGHT := Vector3(-0.45, -0.52, 0.72)

var _f: Dictionary = {}
var _dirty := true
# Geometria do retrato atual (em pixels)
var _s := 0.0
var _c := Vector2.ZERO
var _hc := Vector2.ZERO
var _fw := 0.0
var _fh := 0.0
var _R := 0.0
var _det := 1.0
var _light := Vector3.ZERO
# Traços em coordenadas normalizadas do rosto (u = x/fw, v = y/fh a partir do centro da cabeça)
var _E := 0.0
var _X := 0.0
var _N := 0.0
var _M := 0.0
var _NW := 0.0
var _BW := 0.0
var _MW := 0.0
var _ND := 0.0
var _skin := Color.WHITE
var _beard_p: Dictionary = {}
var _shadow_p: Dictionary = {}
var _blotches: Array = []
var _k := PackedFloat32Array()
var _half := Vector3.ZERO
var _shadow_col := Color.BLACK
var _beard_data: Array = []
# Gravação dos comandos de desenho: o retrato pronto fica num cache global e é só reproduzido
# quando a tela o recria (listas de elenco, mercado, etc.).
var _rec: Array = []
var _recording := false
static var _cmd_cache: Dictionary = {}
static var _cmd_cache_order: Array = []
const CMD_CACHE_MAX := 240
# Contexto da malha que está sendo gerada
var _mesh_c := Vector2.ZERO
var _mesh_b := PackedVector2Array()
var _blob_c := Vector2.ZERO
var _blob_r := 1.0
var _hair_style: Dictionary = {}
var _cap_in := PackedVector2Array()
var _cap_out := PackedVector2Array()


func set_player(p: Player, club: Club, year: int) -> void:
	face_seed = p.face_seed
	eth = p.eth
	age = p.age(year)
	look = p.look
	photo = CustomAssets.texture(String(p.look.get("photo", "")))
	if club != null:
		shirt_color = club.primary_color()
		trim_color = club.secondary_color()
		bg_color = club.primary_color().darkened(0.6)
	queue_redraw()


func set_person(seed_value: int, eth_: int, age_: int, club: Club) -> void:
	face_seed = seed_value
	eth = eth_
	age = age_
	suit = true
	if club != null:
		trim_color = club.primary_color()
		bg_color = club.primary_color().darkened(0.6)


func _invalidate() -> void:
	queue_redraw()


# ---------------------------------------------------------------------------
# Desenho
# ---------------------------------------------------------------------------

func _draw() -> void:
	var s := minf(size.x, size.y)
	if s <= 4.0:
		return
	var o := Vector2((size.x - s) * 0.5, (size.y - s) * 0.5)
	var c := o + Vector2(s * 0.5, s * 0.5)
	if photo != null:
		_draw_photo(c, s)
		return
	if _dirty or _f.is_empty():
		_f = FaceGen.features(face_seed, eth, age, look)
		_dirty = false
	var key := hash([face_seed, eth, age, look, size, shirt_color, trim_color, bg_color, suit])
	if _cmd_cache.has(key):
		_replay(_cmd_cache[key])
		return
	_rec = []
	_recording = true
	_setup(c, s)
	var f := _f
	var rng := RandomNumberGenerator.new()
	rng.seed = int(f["texture_seed"])
	var style: int = f["style"]
	var hair: Color = f["hair"]

	_background()
	_back_hair(rng)
	_body()
	_ears()
	# Rosto
	var head := _head_contour(_contour_k())
	_radial(_hc, head, _rings(11), _skin_px)
	_aa_outline(head, _skin.darkened(0.3), 0.8)
	_age_lines()
	_marks(rng)
	# Barba (malha com densidade suave), depois os traços por cima
	if int(f["beard"]) != FaceGen.B_NONE:
		_beard_mesh()
	_eyes()
	_brows(rng)
	_nose()
	_mouth()
	if int(f["beard"]) != FaceGen.B_NONE:
		_beard_hairs(rng)
	# Cabelo da frente
	if style != FaceGen.H_BALD:
		_front_hair(rng, hair)
	else:
		_scalp_shine()
	_accessories()
	# Borda
	_r_arc(_c, _R - 1.0, 0.0, TAU, 64, Color(bg_color.lightened(0.25), 0.6), maxf(1.0, s * 0.012), true)
	_recording = false
	_cmd_cache[key] = _rec
	_cmd_cache_order.append(key)
	if _cmd_cache_order.size() > CMD_CACHE_MAX:
		_cmd_cache.erase(_cmd_cache_order.pop_front())
	_rec = []


func _setup(c: Vector2, s: float) -> void:
	var f := _f
	_s = s
	_c = c
	_R = s * 0.5
	_fw = float(f["fw"]) * s
	_fh = float(f["fh"]) * s
	_hc = c + Vector2(0, -s * 0.04)
	_det = clampf(s / 140.0, 0.3, 2.0)
	_light = LIGHT.normalized()
	_E = float(f["eye_y"])
	_X = float(f["eye_dx"])
	_N = float(f["nose_len"])
	_M = float(f["mouth_y"])
	_NW = float(f["nose_w"]) * 1.1
	_BW = float(f["bridge_w"])
	_MW = float(f["mouth_w"]) * 1.15
	_skin = f["skin"]
	_beard_p = FaceGen.BEARD_PARTS[int(f["beard"])]
	_shadow_p = FaceGen.BEARD_PARTS[FaceGen.B_STUBBLE]
	_hair_style = STYLE_P[int(f["style"])]
	_half = (_light + Vector3(0, 0, 1)).normalized()
	_shadow_col = Color(0.2, 0.22, 0.28).lerp(_skin.darkened(0.5), 0.5)
	var ag: float = f["aging"]
	var shadow: float = f["shadow"] if int(f["beard"]) != FaceGen.B_STUBBLE else 0.0
	_k = PackedFloat32Array([
		float(f["deep"]), float(f["ridge"]), 1.0 if bool(f["aquiline"]) else 0.0, float(f["bridge"]),
		float(f["nose_tip"]), 0.025 + 0.09 * ag + 0.04 * maxf(0.0, float(f["smile"])), float(f["cheekbone"]),
		0.07 * float(f["cheekbone"]) * (1.0 - float(f["fat"])), float(f["lip_l"]), 1.0 if bool(f["chin_cleft"]) else 0.0,
		ag, float(f["rosy"]), shadow, 0.05 + clampf(float(f["skin_i"]) / 9.0, 0.0, 1.0) * 0.1,
		float(f.get("dark_circles", 0.0))])
	_ND = float(f.get("nose_dx", 0.0))
	_blotches.clear()
	var br := RandomNumberGenerator.new()
	br.seed = int(f["blotch_seed"])
	for i in 5:
		_blotches.append([br.randf_range(-0.8, 0.8), br.randf_range(-0.8, 0.9), br.randf_range(0.15, 0.35), br.randf_range(-0.035, 0.03)])


func _contour_k() -> int:
	return clampi(int(24 * _det), 10, 30)


func _rings(n: int) -> int:
	return maxi(3, int(round(n * clampf(_det, 0.4, 1.2))))


func _draw_photo(c: Vector2, s: float) -> void:
	var pts := _ellipse(c, s * 0.5, s * 0.5, 48)
	var ts := photo.get_size()
	var side := minf(ts.x, ts.y)
	var uvs := PackedVector2Array()
	for p in pts:
		var rel := (p - c) / s # -0.5..0.5
		var px := ts * 0.5 + rel * side
		uvs.append(Vector2(px.x / ts.x, px.y / ts.y))
	_fill(pts, Color.WHITE, uvs, photo)
	_r_arc(c, s * 0.5 - 1.0, 0.0, TAU, 48, Color(bg_color.lightened(0.25), 0.6), maxf(1.0, s * 0.012), true)


# ---------------------------------------------------------------------------
# Malhas com cor por vértice
# ---------------------------------------------------------------------------

## Malha radial de `center` até o contorno `boundary` (precisa ser "estrelado" a partir do centro).
## `shader(p, t, i)` recebe o ponto, a fração do raio (0 centro … 1 borda) e o índice no contorno.
func _radial(center: Vector2, boundary: PackedVector2Array, rings: int, shader: Callable) -> Array:
	var n := boundary.size()
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	if n < 3:
		return [idx, pts, cols]
	_mesh_c = center
	_mesh_b = boundary
	pts.append(_cl(center))
	cols.append(shader.call(center, 0.0, 0))
	for r in range(1, rings + 1):
		var t := float(r) / rings
		for i in n:
			var p := center + (boundary[i] - center) * t
			pts.append(_cl(p))
			cols.append(shader.call(p, t, i))
	for i in n:
		idx.append_array([0, 1 + i, 1 + (i + 1) % n])
	for r in range(1, rings):
		var b0 := 1 + (r - 1) * n
		var b1 := 1 + r * n
		for i in n:
			var j := (i + 1) % n
			idx.append_array([b0 + i, b1 + i, b1 + j, b0 + i, b1 + j, b0 + j])
	var m := [idx, pts, cols]
	_emit(m)
	return m


## Faixa entre duas linhas com o mesmo número de pontos; `shader(p, t, w)` recebe a posição ao
## longo da faixa (t) e a fração entre a linha de dentro (w = 0) e a de fora (w = 1).
func _strip(inner: PackedVector2Array, outer: PackedVector2Array, layers: int, shader: Callable) -> void:
	var n := mini(inner.size(), outer.size())
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for l in layers + 1:
		var w := float(l) / layers
		for i in n:
			var p := inner[i].lerp(outer[i], w)
			pts.append(_cl(p))
			cols.append(shader.call(p, float(i) / maxf(1.0, n - 1.0), w))
	for l in layers:
		var b0 := l * n
		var b1 := (l + 1) * n
		for i in n - 1:
			idx.append_array([b0 + i, b1 + i, b1 + i + 1, b0 + i, b1 + i + 1, b0 + i + 1])
	_emit([idx, pts, cols])


func _emit(m: Array) -> void:
	var idx: PackedInt32Array = m[0]
	if idx.is_empty():
		return
	_r_tri(idx, m[1], m[2])


## Mantém os pontos dentro do círculo do retrato (recorte barato das malhas).
func _cl(p: Vector2) -> Vector2:
	var d := p - _c
	var r := _R - 0.5
	if d.length_squared() > r * r:
		return _c + d.normalized() * r
	return p


func _aa_outline(poly: PackedVector2Array, col: Color, alpha: float) -> void:
	var pts := PackedVector2Array(poly)
	pts.append(poly[0])
	for i in pts.size():
		pts[i] = _cl(pts[i])
	_r_polyline(pts, Color(col, alpha * 0.55), maxf(0.8, _s * 0.006), true)


static func _g(x: float, sd: float) -> float:
	return exp(-(x * x) / (sd * sd))


static func _g2(x: float, y: float, sx: float, sy: float) -> float:
	return exp(-(x * x) / (sx * sx) - (y * y) / (sy * sy))


func _uv(p: Vector2) -> Vector2:
	return Vector2((p.x - _hc.x) / _fw, (p.y - _hc.y) / _fh)


func _px(u: float, v: float) -> Vector2:
	return _hc + Vector2(u * _fw, v * _fh)


## Ponto do nariz (acompanha o desvio de um nariz torto).
func _pxn(u: float, v: float) -> Vector2:
	return _px(u + _ND * smoothstep(_E - 0.05, _N, v), v)


## Aplica luminância com sombras mais quentes (o vermelho some por último).
static func _shade(base: Color, lum: float) -> Color:
	var l := maxf(lum, 0.0)
	return Color(minf(base.r * pow(l, 0.82), 1.0), minf(base.g * l, 1.0), minf(base.b * pow(l, 1.12), 1.0), base.a)


# ---------------------------------------------------------------------------
# Formato da cabeça
# ---------------------------------------------------------------------------

## Meia largura do rosto (em fw) na altura v (0 = centro da cabeça, 1 = queixo).
func _hw(v: float) -> float:
	var f := _f
	var cw: float = f["cheek_w"]
	var jaw: float = f["jaw"]
	var jv: float = f["jaw_v"]
	var sq: float = f["chin_sq"]
	var w: float
	if v <= jv:
		w = lerpf(cw, jaw, smoothstep(0.0, jv, v))
	else:
		var q := clampf((v - jv) / (1.0 - jv), 0.0, 1.0)
		w = jaw * pow(maxf(0.0, 1.0 - pow(q, sq)), 1.0 / sq)
	w += 0.03 * float(f["cheekbone"]) * _g(v - 0.08, 0.16)
	w *= 1.0 + float(f["fat"]) * 0.07 * _g(v - 0.55, 0.25)
	return w


## Contorno da cabeça (sentido horário a partir do alto).
func _head_contour(k: int) -> PackedVector2Array:
	var f := _f
	var cw: float = f["cheek_w"]
	var fore: float = f["forehead"]
	var right := PackedVector2Array()
	for i in k:
		var a := -PI * 0.5 + PI * 0.5 * float(i) / k
		var up := -sin(a)
		right.append(Vector2(cos(a) * lerpf(cw, fore, up), sin(a) * 1.02))
	for i in k + 1:
		var q := float(i) / k
		var v := sin(q * PI * 0.5)
		right.append(Vector2(_hw(v), v))
	var pts := PackedVector2Array()
	for p in right:
		pts.append(_px(p.x, p.y))
	for i in range(right.size() - 2, 0, -1):
		pts.append(_px(-right[i].x, right[i].y))
	return pts


## "Distância" normalizada até o contorno do rosto: < 1 dentro, 1 na borda, > 1 fora.
func _th(u: float, v: float) -> float:
	if v >= 0.0:
		var hw := maxf(_hw(minf(v, 1.0)), 0.001)
		return maxf(absf(u) / hw, v)
	var rx := lerpf(float(_f["cheek_w"]), float(_f["forehead"]), clampf(-v / 1.02, 0.0, 1.0))
	return sqrt(pow(u / rx, 2.0) + pow(v / 1.02, 2.0))


# ---------------------------------------------------------------------------
# Pele
# ---------------------------------------------------------------------------

func _skin_px(p: Vector2, t: float, i: int) -> Color:
	var u := (p.x - _hc.x) / _fw
	var v := (p.y - _hc.y) / _fh
	var au := absf(u)
	# Normal de uma "cúpula" com o formato do rosto
	var dx := 0.0
	var dy := 0.0
	if t > 0.0 and i < _mesh_b.size():
		var d := (_mesh_b[i] - _mesh_c).normalized()
		dx = d.x
		dy = d.y
	var tilt := pow(t, 2.3)
	var nx := dx * tilt
	var ny := dy * tilt
	var nz := sqrt(maxf(0.0, 1.0 - tilt * tilt))
	var diff := maxf(0.0, nx * _light.x + ny * _light.y + nz * _light.z)
	var lum := 0.56 + 0.54 * diff
	var E := _E
	var X := _X
	var N := _N
	var M := _M
	var BW := _BW
	var NW := _NW
	var MW := _MW
	var k := _k
	var a := 0.0
	var b := 0.0
	# Órbitas e arco superciliar
	var ey := v - E + 0.01
	a = (u - X) / 0.27
	b = (u + X) / 0.27
	var ey2 := ey * ey / 0.0121
	lum -= 0.13 * k[0] * (exp(-a * a - ey2) + exp(-b * b - ey2))
	a = (au - 0.2) / 0.08
	b = (v - E) / 0.08
	lum -= 0.05 * exp(-a * a - b * b)
	b = (v - E + 0.19) / 0.05
	var bb := b * b
	a = (u + X * 0.95) / 0.26
	var a2 := (u - X * 0.95) / 0.26
	lum += 0.07 * k[1] * (exp(-a * a - bb) * 1.2 + exp(-a2 * a2 - bb) * 0.6)
	# Testa e têmporas
	a = (u + 0.2) / 0.38
	b = (v + 0.55) / 0.2
	var fore := exp(-a * a - b * b)
	lum += 0.07 * fore
	a = (au - 0.92) / 0.14
	b = (v + 0.28) / 0.22
	lum -= 0.05 * exp(-a * a - b * b)
	# Nariz: dorso claro, lateral direita na sombra, ponta, asas e sombra embaixo
	var un := u - _ND * smoothstep(E - 0.05, N, v)
	var wv := smoothstep(E - 0.06, E + 0.1, v) * (1.0 - smoothstep(N - 0.1, N - 0.01, v))
	var ridge_hl := 0.0
	if wv > 0.0:
		a = (un + 0.03) / BW
		ridge_hl = exp(-a * a) * wv
		var hump := 0.0
		if k[2] > 0.0:
			b = (v - (E + N) * 0.5) / 0.06
			hump = 0.05 * exp(-b * b)
		lum += (0.1 * k[3] + hump) * ridge_hl
		a = (un - BW * 1.7) / (BW * 0.9)
		lum -= 0.2 * k[3] * exp(-a * a) * wv
		a = (un + BW * 1.9) / (BW * 0.9)
		lum -= 0.05 * k[3] * exp(-a * a) * wv
	if v > N - 0.25 and v < N + 0.12:
		a = (un + 0.02) / (NW * 0.45 * k[4])
		b = (v - (N - 0.07)) / 0.05
		lum += 0.09 * exp(-a * a - b * b)
		b = (v - (N - 0.035)) / 0.055
		bb = b * b
		a = (un - NW * 0.85) / (NW * 0.3)
		a2 = (un + NW * 0.85) / (NW * 0.3)
		lum -= 0.14 * (exp(-a * a - bb) + exp(-a2 * a2 - bb) * 0.6)
		a = (un - 0.02) / (NW * 0.8)
		b = (v - (N + 0.035)) / 0.034
		lum -= 0.28 * exp(-a * a - b * b)
	# Sulco nasolabial (mais marcado com a idade e o sorriso)
	if v > N - 0.1 and v < M + 0.15:
		var nl_d := _seg_dist(Vector2(au, v), Vector2(NW * 1.25, N - 0.02), Vector2(MW * 1.12, M + 0.04)) / 0.045
		lum -= k[5] * (1.0 if u > 0.0 else 0.55) * exp(-nl_d * nl_d)
	# Maçãs do rosto e bochechas
	b = (v - 0.1) / 0.1
	a = (u + 0.5) / 0.25
	a2 = (u - 0.5) / 0.25
	lum += k[6] * (0.07 * exp(-a * a - b * b) + 0.03 * exp(-a2 * a2 - b * b))
	a = (au - 0.64) / 0.17
	b = (v - 0.4) / 0.13
	lum -= k[7] * exp(-a * a - b * b)
	# Boca e queixo
	if v > M - 0.15:
		a = u / (MW * 0.55)
		b = (v - (M + k[8] * 2.0 + 0.06)) / 0.035
		lum -= 0.11 * exp(-a * a - b * b)
		a = (au - MW * 1.05) / 0.05
		b = (v - M) / 0.04
		lum -= 0.08 * exp(-a * a - b * b)
		a = (u + 0.06) / 0.2
		b = (v - 0.86) / 0.07
		lum += 0.07 * exp(-a * a - b * b)
		if k[9] > 0.0:
			a = u / 0.025
			b = (v - 0.9) / 0.06
			lum -= 0.08 * exp(-a * a - b * b)
	a = (u + 0.04) / 0.04
	b = (v - (N + M) * 0.5) / 0.05
	lum += 0.03 * exp(-a * a - b * b)
	# Olheiras e flacidez com a idade
	if k[10] > 0.0:
		a = (au - X) / 0.18
		b = (v - (E + 0.13)) / 0.035
		lum -= 0.07 * k[10] * exp(-a * a - b * b)
		a = (au - MW * 1.3) / 0.12
		b = (v - 0.8) / 0.1
		lum -= 0.05 * k[10] * exp(-a * a - b * b)
	if k[14] > 0.05:
		a = (au - X * 0.9) / 0.2
		b = (v - (E + 0.11)) / 0.045
		lum -= 0.09 * k[14] * exp(-a * a - b * b)
	# Manchas de tom (pele não é uniforme)
	for bl: Array in _blotches:
		a = (u - float(bl[0])) / float(bl[2])
		b = (v - float(bl[1])) / float(bl[2])
		lum += float(bl[3]) * exp(-a * a - b * b)
	var col := _shade(_skin, lum)
	# Rubor nas bochechas, nariz e queixo
	a = (au - 0.52) / 0.22
	b = (v - 0.25) / 0.13
	var blush := 0.55 * exp(-a * a - b * b)
	a = u / NW
	b = (v - (N - 0.05)) / 0.06
	blush += 0.35 * exp(-a * a - b * b)
	a = u / 0.2
	b = (v - 0.9) / 0.08
	blush += 0.2 * exp(-a * a - b * b)
	col = col.lerp(Color(0.85, 0.32, 0.3), clampf(blush * k[11] * 0.18, 0.0, 0.3))
	# Sombra da barba feita (zona da barba, bem suave)
	if k[12] > 0.02 and v > N - 0.05:
		var line := lerpf(N + 0.02, 0.2, smoothstep(MW * 0.8, MW * 1.5, au)) - 0.16 * smoothstep(0.55, 1.0, au)
		var dens := smoothstep(line - 0.08, line + 0.08, v)
		a = u / MW
		b = (v - M) / (k[8] * 2.2 + 0.03)
		dens *= smoothstep(0.8, 1.1, sqrt(a * a + b * b))
		col = col.lerp(_shadow_col, dens * k[12] * 0.32)
	# Brilho especular (mais visível em pele escura)
	var hx := _half.x
	var hy := _half.y
	var hz := _half.z
	var spec := pow(maxf(0.0, nx * hx + ny * hy + nz * hz), 26.0)
	a = (u + 0.5) / 0.2
	b = (v - 0.08) / 0.1
	spec *= k[13] * (0.6 + 0.8 * (fore * 0.9 + ridge_hl + exp(-a * a - b * b)))
	return Color(minf(col.r + spec, 1.0), minf(col.g + spec * 0.97, 1.0), minf(col.b + spec * 0.93, 1.0))


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _age_lines() -> void:
	var f := _f
	var wr: float = f["wrinkles"]
	if wr <= 0.0:
		return
	var lw := maxf(0.7, _s * 0.005)
	var dark := Color(_skin.darkened(0.45), 0.12 + wr * 0.2)
	var light := Color(_skin.lightened(0.25), 0.06 + wr * 0.08)
	var lines := 1 + int(wr * 2.5)
	for k in lines:
		var y := -0.66 - k * 0.075 + _E
		var pts := PackedVector2Array()
		for i in 11:
			var t := float(i) / 10.0
			var u := lerpf(-0.5, 0.5, t)
			pts.append(_px(u, y - 0.03 * sin(PI * t) + 0.01 * sin(t * 13.0 + k)))
		_r_polyline(pts, dark, lw, true)
		var hl := PackedVector2Array()
		for p in pts:
			hl.append(p + Vector2(0, lw * 1.2))
		_r_polyline(hl, light, lw, true)
	if wr > 0.4:
		# Pés de galinha
		for sx: float in [-1.0, 1.0]:
			var ox := sx * (_X + float(f["eye_w"]) + 0.05)
			for k in 3:
				var a := _px(ox, _E + (k - 1) * 0.035)
				var b := _px(ox + sx * 0.1, _E + (k - 1) * 0.07)
				_r_line(a, b, Color(dark, dark.a * 0.8), lw * 0.8, true)
	if wr > 0.25:
		for sx: float in [-1.0, 1.0]:
			var pts := PackedVector2Array([_px(sx * _NW * 1.25, _N - 0.03), _px(sx * (_NW * 1.4 + _MW * 0.25), _N + 0.1), _px(sx * _MW * 1.12, _M + 0.05)])
			_r_polyline(pts, Color(dark, dark.a * (0.8 if sx > 0 else 0.5)), lw, true)
	if wr > 0.75:
		for sx: float in [-1.0, 1.0]:
			_r_line(_px(sx * _MW * 1.05, _M + 0.06), _px(sx * _MW * 1.2, _M + 0.2), Color(dark, dark.a * 0.6), lw, true)


func _marks(rng: RandomNumberGenerator) -> void:
	var f := _f
	if bool(f["freckles"]):
		var n := int(40 * clampf(_det, 0.5, 1.5))
		for i in n:
			var sx := -1.0 if i % 2 == 0 else 1.0
			var u := sx * rng.randf_range(0.0, 0.62)
			var v := rng.randf_range(-0.05, 0.3) - (0.12 if absf(u) < 0.2 else 0.0)
			_r_circle(_px(u, v), maxf(0.5, _s * rng.randf_range(0.0025, 0.0045)), Color(_skin.darkened(0.3).lerp(Color("#8A4A2A"), 0.3), rng.randf_range(0.25, 0.55)))
	# Marcas de acne e poros abertos
	var bl: float = float(f.get("blemish", 0.0))
	if bl > 0.05:
		for i in int(30 * bl * clampf(_det, 0.4, 1.5)):
			var u := rng.randf_range(-0.75, 0.75)
			var v := rng.randf_range(-0.6, 0.75)
			if absf(u) < 0.45 and v > -0.1 and v < 0.25:
				u = signf(u) * rng.randf_range(0.45, 0.75)
			var p := _px(u, v)
			var r := maxf(0.5, _s * rng.randf_range(0.003, 0.006))
			if rng.randf() < 0.5:
				_r_circle(p, r, Color(0.7, 0.25, 0.2, rng.randf_range(0.12, 0.25)))
			else:
				_r_circle(p, r, Color(_skin.darkened(0.25), 0.25))
				_r_circle(p + Vector2(-r * 0.3, -r * 0.3), r * 0.5, Color(_skin.lightened(0.2), 0.2))
	# Papada
	var fat: float = f["fat"]
	if fat > 0.62:
		var amt := (fat - 0.62) / 0.38
		var pts := PackedVector2Array()
		for i in 11:
			var t := float(i) / 10.0
			pts.append(_px(lerpf(-0.5, 0.5, t), 1.02 + 0.07 * sin(PI * t)))
		_r_polyline(pts, Color(_skin.darkened(0.4), 0.3 * amt), maxf(0.8, _s * 0.007), true)
	if bool(f["mole"]):
		var mp: Vector2 = f["mole_pos"]
		_r_circle(_px(mp.x, mp.y), maxf(0.7, _s * 0.005), _skin.darkened(0.5))
	if bool(f["scar"]):
		var sp: Vector2 = f["scar_pos"]
		var a := _px(sp.x, sp.y)
		var b := a + Vector2(_fw * 0.12, _fh * 0.07)
		_r_line(a, b, Color(_skin.lightened(0.2), 0.6), maxf(0.8, _s * 0.006), true)
		_r_line(a + Vector2(0, 1), b + Vector2(0, 1), Color(_skin.darkened(0.3), 0.3), maxf(0.6, _s * 0.004), true)


# ---------------------------------------------------------------------------
# Fundo, corpo, orelhas
# ---------------------------------------------------------------------------

func _background() -> void:
	var circle := _ellipse(_c, _R, _R, 24 if _s < 90.0 else 40)
	_radial(_c, circle, 3 if _s < 90.0 else 5, func(p: Vector2, t: float, _i: int) -> Color:
		var d := (p - _c) / _R
		var lum := 1.12 - 0.3 * t * t + 0.1 * (-d.x * 0.5 - d.y * 0.8)
		return Color(minf(bg_color.r * lum, 1.0), minf(bg_color.g * lum, 1.0), minf(bg_color.b * lum, 1.0)))


func _body() -> void:
	var f := _f
	var s := _s
	var neck_top := _hc.y + _fh * 0.4
	var neck_bot := _c.y + s * 0.37
	var nw_top := _fw * 0.5
	var nw_bot := _fw * 0.6
	# Ombros / camisa
	var shoulders := _ellipse(Vector2(_c.x, _c.y + s * 0.585), s * 0.47, s * 0.25, 40)
	var body_col := Color("#262A31") if suit else shirt_color
	var pieces := Geometry2D.intersect_polygons(shoulders, _ellipse(_c, _R, _R, 48))
	for piece in pieces:
		var cen := _centroid(piece)
		_radial(cen, piece, _rings(6), func(p: Vector2, _t: float, _i: int) -> Color:
			var d := (p - Vector2(_c.x, _c.y + s * 0.5)) / (s * 0.5)
			var lum := 1.0 - 0.28 * d.x - 0.12 * d.y
			lum -= 0.22 * _g2((p.x - _c.x) / (s * 0.18), (p.y - neck_bot) / (s * 0.06), 1.0, 1.0)
			lum -= 0.1 * clampf(absf(d.x) - 0.6, 0.0, 1.0)
			return _shade(body_col, lum * 0.95))
	# Pescoço (com trapézio)
	var neck := PackedVector2Array([
		Vector2(_hc.x - nw_top, neck_top), Vector2(_hc.x + nw_top, neck_top),
		Vector2(_hc.x + nw_bot, neck_bot - s * 0.02), Vector2(_hc.x + _fw * 1.05, neck_bot + s * 0.03),
		Vector2(_hc.x - _fw * 1.05, neck_bot + s * 0.03), Vector2(_hc.x - nw_bot, neck_bot - s * 0.02)])
	var ncen := Vector2(_hc.x, (neck_top + neck_bot) * 0.5)
	var jaw_y := _hc.y + _fh * 0.95
	_radial(ncen, neck, _rings(5), func(p: Vector2, _t: float, _i: int) -> Color:
		var dx := (p.x - _hc.x) / _fw
		var lum := 0.8 - 0.14 * dx
		lum -= 0.32 * (1.0 - smoothstep(jaw_y - _fh * 0.05, jaw_y + _fh * 0.28, p.y))
		lum += 0.05 * _g2(dx + 0.05, (p.y - (jaw_y + _fh * 0.25)) / _fh, 0.12, 0.1) * (1.0 - float(f["fat"]))
		return _shade(_skin, lum))
	var col_y := _c.y + s * 0.335
	var lw := maxf(1.5, s * 0.022)
	if suit:
		var shirt := PackedVector2Array([Vector2(_hc.x - _fw * 0.55, col_y - s * 0.01), Vector2(_hc.x + _fw * 0.55, col_y - s * 0.01), Vector2(_hc.x, col_y + s * 0.16)])
		_r_polygon(shirt, PackedColorArray([Color("#E4E8EE"), Color("#C9CED6"), Color("#DDE1E7")]))
		var tie := PackedVector2Array([Vector2(_hc.x - s * 0.018, col_y + s * 0.02), Vector2(_hc.x + s * 0.018, col_y + s * 0.02), Vector2(_hc.x + s * 0.026, col_y + s * 0.15), Vector2(_hc.x, col_y + s * 0.18), Vector2(_hc.x - s * 0.026, col_y + s * 0.15)])
		for piece in Geometry2D.intersect_polygons(tie, _ellipse(_c, _R, _R, 48)):
			_fill(piece, trim_color.darkened(0.1))
		_r_line(Vector2(_hc.x - s * 0.01, col_y + s * 0.03), Vector2(_hc.x + s * 0.004, col_y + s * 0.14), Color(1, 1, 1, 0.15), maxf(1.0, s * 0.008), true)
		for sx: float in [-1.0, 1.0]:
			var lap := PackedVector2Array([Vector2(_hc.x + sx * _fw * 0.6, col_y - s * 0.02), Vector2(_hc.x + sx * _fw * 0.98, col_y + s * 0.05), Vector2(_hc.x + sx * s * 0.03, col_y + s * 0.2)])
			for piece in Geometry2D.intersect_polygons(lap, _ellipse(_c, _R, _R, 48)):
				_fill(piece, Color("#1B1E23") if sx < 0 else Color("#15171B"))
		return
	match int(f["collar"]):
		0: # gola V
			var v := PackedVector2Array([Vector2(_hc.x - _fw * 0.55, col_y), Vector2(_hc.x, col_y + s * 0.09), Vector2(_hc.x + _fw * 0.55, col_y)])
			_r_polygon(v, PackedColorArray([_skin.darkened(0.22), _skin.darkened(0.15), _skin.darkened(0.3)]))
			_r_polyline(v, trim_color, lw, true)
			_r_polyline(PackedVector2Array([v[0] + Vector2(0, lw * 0.6), v[1] + Vector2(0, lw * 0.6), v[2] + Vector2(0, lw * 0.6)]), Color(0, 0, 0, 0.2), lw * 0.5, true)
		1: # gola redonda
			_r_arc(Vector2(_hc.x, col_y - s * 0.015), _fw * 0.6, PI * 0.12, PI * 0.88, 20, trim_color, lw, true)
			_r_arc(Vector2(_hc.x, col_y - s * 0.015 + lw * 0.6), _fw * 0.6, PI * 0.15, PI * 0.85, 20, Color(0, 0, 0, 0.18), lw * 0.4, true)
		_: # gola polo
			for sx: float in [-1.0, 1.0]:
				var tri := PackedVector2Array([Vector2(_hc.x + sx * _fw * 0.62, col_y - s * 0.03), Vector2(_hc.x + sx * _fw * 0.05, col_y + s * 0.06), Vector2(_hc.x + sx * _fw * 0.82, col_y + s * 0.05)])
				_r_polygon(tri, PackedColorArray([trim_color, trim_color.darkened(0.2 if sx > 0 else 0.05), trim_color.darkened(0.25 if sx > 0 else 0.1)]))


func _ears() -> void:
	var f := _f
	var er: float = f["ear"]
	var out: float = f["ear_out"]
	for sx: float in [-1.0, 1.0]:
		var ec := _px(sx * (float(f["cheek_w"]) * 0.97 + out * 0.07), 0.04)
		var ew := _fw * (0.15 + out * 0.04) * er
		var eh := _fh * 0.2 * er
		var pts := PackedVector2Array()
		var en := 12 if _s < 90.0 else 20
		for i in en:
			var a := TAU * i / en
			var y := sin(a)
			var x := cos(a) * (0.8 if y > 0.2 else 1.0) * lerpf(1.0, 0.7, clampf(y, 0.0, 1.0))
			pts.append(ec + Vector2(x * ew, y * eh))
		var lit := -sx
		_radial(ec, pts, _rings(3), func(p: Vector2, t: float, _i: int) -> Color:
			var d := (p - ec) / Vector2(ew, eh)
			var lum := 0.8 + 0.1 * lit
			lum -= 0.22 * _g2(d.x + sx * 0.15, d.y + 0.05, 0.4, 0.45)
			lum += 0.1 * smoothstep(0.6, 0.95, t) * (1.0 if d.y < 0.3 else 0.3)
			var c := _shade(_skin, lum)
			return c.lerp(Color(0.85, 0.35, 0.3), 0.08 + 0.05 * float(f["rosy"])))
		_aa_outline(pts, _skin.darkened(0.3), 0.8)
		var lw := maxf(0.8, _s * 0.006)
		var a0 := -PI * 0.5 if sx > 0 else PI * 0.5
		_r_arc(ec + Vector2(sx * ew * 0.1, -eh * 0.05), ew * 0.55, a0, a0 + PI, 10, Color(_skin.darkened(0.35), 0.55), lw, true)
		if bool(f["earring"]) and sx < 0:
			var er_col := Color("#F2D16B") if int(f["texture_seed"]) % 2 == 0 else Color("#E6E9EE")
			_r_circle(ec + Vector2(0, eh * 0.78), maxf(1.2, _s * 0.012), er_col)
			_r_circle(ec + Vector2(-_s * 0.004, eh * 0.75), maxf(0.5, _s * 0.004), Color(1, 1, 1, 0.8))


# ---------------------------------------------------------------------------
# Olhos, sobrancelhas, nariz, boca
# ---------------------------------------------------------------------------

func _eyes() -> void:
	var f := _f
	var ew := _fw * float(f["eye_w"])
	var eh := _fw * float(f["eye_h"])
	var tilt := _fw * float(f["eye_tilt"])
	var iris_col: Color = f["eye"]
	var lw := maxf(0.9, _s * 0.009)
	var mono: bool = f["monolid"]
	var hooded: bool = f["hooded"]
	var asym: float = f["asym"]
	for sx: float in [-1.0, 1.0]:
		var cx := _hc.x + sx * _X * _fw
		var cy := _hc.y + _E * _fh + sx * asym * _fh * 0.012
		var inner := Vector2(cx - sx * ew, cy + tilt * 0.35 + (eh * 0.12 if mono else 0.0))
		var outer := Vector2(cx + sx * ew, cy - tilt)
		var upper := PackedVector2Array()
		var lower := PackedVector2Array()
		for i in 15:
			var t := float(i) / 14.0
			var base := inner.lerp(outer, t)
			var peak := pow(t, 0.78) if not mono else pow(t, 1.0)
			upper.append(base + Vector2(0, -sin(PI * peak) * eh * (0.85 if mono else 1.0)))
			lower.append(base + Vector2(0, sin(PI * pow(t, 1.15)) * eh * 0.52))
		var sclera := PackedVector2Array(upper)
		for i in range(lower.size() - 2, 0, -1):
			sclera.append(lower[i])
		var ecen := Vector2(cx, cy)
		var sc_base := Color("#E4DED4").lerp(_skin, 0.12)
		_radial(ecen, sclera, 2 if _s < 90.0 else 3, func(p: Vector2, t: float, _i: int) -> Color:
			var lum := 1.0 - 0.32 * t * t - (0.28 if p.y < cy else 0.0) * t
			return _shade(sc_base, lum))
		# Íris com anel escuro, centro claro e sombra da pálpebra
		var ic := Vector2(cx + float(f["gaze"]) * ew * 0.3, cy + eh * 0.12)
		var ir := minf(eh * 1.3, ew * 0.47)
		for piece in Geometry2D.intersect_polygons(_ellipse(ic, ir, ir, 12 if _s < 90.0 else 20), sclera):
			if not Geometry2D.is_point_in_polygon(ic, piece):
				_fill(piece, iris_col.darkened(0.3))
				continue
			_radial(ic, piece, 2 if _s < 90.0 else 4, func(p: Vector2, _t: float, _i: int) -> Color:
				var d := p - ic
				var r := d.length() / ir
				var lum := 1.0 + 0.28 * (1.0 - smoothstep(0.3, 0.7, r)) - 0.55 * smoothstep(0.72, 1.0, r)
				lum -= 0.4 * (1.0 - smoothstep(-ir * 0.9, -ir * 0.1, d.y))
				lum += 0.08 * sin(atan2(d.y, d.x) * 17.0 + sx * 3.0) * (1.0 - r)
				return _shade(iris_col, lum))
		for piece in Geometry2D.intersect_polygons(_ellipse(ic, ir * 0.4, ir * 0.4, 14), sclera):
			_fill(piece, Color("#070505"))
		_r_circle(ic + Vector2(-ir * 0.34, -ir * 0.36), maxf(0.7, ir * 0.2), Color(1, 1, 1, 0.9))
		_r_circle(ic + Vector2(ir * 0.3, ir * 0.25), maxf(0.4, ir * 0.09), Color(1, 1, 1, 0.35))
		# Carúncula
		_r_circle(inner + Vector2(sx * ew * 0.1, eh * 0.05), maxf(0.6, eh * 0.18), Color(0.85, 0.5, 0.5, 0.55))
		# Linha dos cílios (mais grossa por fora) e cílios
		var lash := Color("#2B1D15").lerp(_skin.darkened(0.7), 0.25)
		_r_polyline(upper, Color(lash, 0.8), lw * 0.9, true)
		_r_polyline(upper.slice(7), Color(lash, 0.7), lw * 1.3, true)
		var ln := float(f["lashes"]) * 0.7
		for k in (3 if _s > 110.0 else 0):
			var t := 0.62 + k * 0.08
			var i := int(t * 14.0)
			var p0: Vector2 = upper[mini(i, 14)]
			_r_line(p0, p0 + Vector2(sx * 0.6, -1.0).normalized() * eh * 0.45 * ln, Color(lash, 0.75), lw * 0.7, true)
		_r_line(outer, outer + Vector2(sx * ew * 0.12, -eh * 0.18), lash, lw, true)
		_r_polyline(lower, Color(lash, 0.22), lw * 0.7, true)
		var wl := PackedVector2Array()
		for p in lower.slice(2, 13):
			wl.append(p + Vector2(0, lw * 0.6))
		_r_polyline(wl, Color(_skin.lightened(0.25), 0.25), lw * 0.6, true)
		# Dobra da pálpebra
		if not mono:
			var crease := PackedVector2Array()
			var off := eh * (0.38 if hooded else 0.62)
			for p in upper.slice(2, 13):
				crease.append(p + Vector2(0, -off))
			_r_polyline(crease, Color(_skin.darkened(0.4), 0.38), lw * 0.8, true)
			var hl := PackedVector2Array()
			for p in crease.slice(2, 9):
				hl.append(p + Vector2(0, -lw * 1.2))
			_r_polyline(hl, Color(_skin.lightened(0.3), 0.12), lw, true)
		else:
			var fold := PackedVector2Array()
			for p in upper.slice(0, 7):
				fold.append(p + Vector2(0, -eh * 0.12))
			_r_polyline(fold, Color(_skin.darkened(0.3), 0.3), lw * 0.8, true)


func _brows(rng: RandomNumberGenerator) -> void:
	var f := _f
	var col: Color = (f["beard_col"] as Color).darkened(0.12)
	if int(f["hair_i"]) in [5, 7, 9] or int(f["hair_i"]) == 4:
		col = (f["hair"] as Color).darkened(0.35)
	col = col.lerp(_skin, 0.12)
	var ew := _fw * float(f["eye_w"])
	var th := _fw * float(f["brow_t"])
	var arch := _fw * float(f["brow_arch"])
	var tilt := _fw * float(f["brow_tilt"])
	var blen := ew * 2.3 * (float(f["brow_len"]) / 0.45)
	var dens: float = f["brow_dens"]
	var wline := maxf(0.6, _s * 0.0034)
	var asym: float = f["asym"]
	for sx: float in [-1.0, 1.0]:
		var cx := _hc.x + sx * _X * _fw
		var by := _hc.y + (_E - float(f["brow_gap"])) * _fh - sx * asym * _fh * 0.018
		var x0 := cx - sx * ew * 1.05
		var path := PackedVector2Array()
		var thick := PackedFloat32Array()
		for i in 12:
			var t := float(i) / 11.0
			var x := x0 + sx * blen * t
			var y := by - arch * sin(PI * minf(t / 0.7, 1.0) * 0.5) * (1.0 if t < 0.7 else 1.0 - (t - 0.7) * 1.8) - tilt * t
			path.append(Vector2(x, y))
			thick.append(th * lerpf(1.15, 0.35, pow(t, 1.4)))
		var top := PackedVector2Array()
		var bot := PackedVector2Array()
		for i in path.size():
			top.append(path[i] + Vector2(0, -thick[i] * 0.5))
			bot.append(path[i] + Vector2(0, thick[i] * 0.5))
		bot.reverse()
		var poly := PackedVector2Array(top)
		poly.append_array(bot)
		var base_a := 0.42 + (0.3 if _s < 90.0 else 0.0)
		_fill(poly, Color(col, base_a * dens + 0.1))
		var n := int(75 * dens * clampf(_det, 0.4, 1.6))
		for k in n:
			var t := pow(rng.randf(), 0.85)
			var i := mini(int(t * 11.0), 10)
			var lt := t * 11.0 - i
			var p := path[i].lerp(path[i + 1], lt)
			var tk := lerpf(thick[i], thick[i + 1], lt)
			p.y += rng.randf_range(-0.45, 0.45) * tk
			var dir: Vector2
			if t < 0.18:
				dir = Vector2(-sx * 0.2, -1.0)
			else:
				var a := lerpf(-0.9, 0.3, clampf((t - 0.18) / 0.8, 0.0, 1.0))
				dir = Vector2(sx * cos(a), sin(a))
			var ln := tk * rng.randf_range(0.6, 1.05) + _s * 0.002
			_r_line(p, p + dir.normalized() * ln, Color(col.darkened(rng.randf_range(0.0, 0.2)), rng.randf_range(0.35, 0.7)), wline, true)
	if bool(f["unibrow"]):
		for k in int(10 * clampf(_det, 0.5, 1.5)):
			var p := _px(rng.randf_range(-0.15, 0.15), _E - float(f["brow_gap"]) + rng.randf_range(-0.02, 0.02))
			_r_line(p, p + Vector2(0, -_s * 0.008), Color(col, 0.4), wline, true)


func _nose() -> void:
	var f := _f
	var lw := maxf(0.8, _s * 0.007)
	var dark := _skin.darkened(0.62)
	for sx: float in [-1.0, 1.0]:
		var nc := _pxn(sx * _NW * 0.45, _N + 0.004)
		var rx := _NW * _fw * 0.2
		var ry := _fh * 0.02
		_fill(_ellipse(nc, rx * 1.6, ry * 1.6, 12), Color(dark, 0.14))
		_fill(_ellipse(nc + Vector2(sx * rx * 0.1, 0), rx, ry, 12), Color(dark, 0.62))
		# Asa do nariz
		var wc := _pxn(sx * _NW * 0.82, _N - 0.03)
		var a0 := PI * 0.5 - sx * 0.6
		_r_arc(wc, _NW * _fw * 0.28, a0 - sx * PI * 0.9, a0 + sx * 0.2, 10, Color(_skin.darkened(0.4), 0.28 if sx < 0 else 0.4), lw, true)
	var side := PackedVector2Array([_pxn(_BW * 1.1, _E + 0.1), _pxn(_BW * 1.3, (_E + _N) * 0.5), _pxn(_NW * 0.75, _N - 0.07)])
	_r_polyline(side, Color(_skin.darkened(0.45), 0.14), lw * 1.2, true)
	var tip := PackedVector2Array()
	for i in 9:
		var t := float(i) / 8.0
		tip.append(_pxn(lerpf(-_NW * 0.35, _NW * 0.35, t), _N + 0.018 + sin(PI * t) * 0.012))
	_r_polyline(tip, Color(_skin.darkened(0.4), 0.25), lw, true)


func _mouth() -> void:
	var f := _f
	var smile: float = f["smile"]
	var mw := _MW * _fw
	var mouth_y := _hc.y + _M * _fh
	var ul := _fh * float(f["lip_u"]) * 2.0
	var ll := _fh * float(f["lip_l"]) * 2.0
	var darkness := clampf(float(f["skin_i"]) / 9.0, 0.0, 1.0)
	var lip := _skin.lerp(Color("#A8585A"), 0.2 - darkness * 0.08).darkened(0.1 + darkness * 0.1)
	var lip_up := lip.darkened(0.12 + darkness * 0.15)
	var lip_lo := lip.lerp(Color("#9A5A5E"), darkness * 0.25)
	var corner_y := mouth_y - smile * _fh * 0.03
	var bow: float = f["bow"]
	var line := PackedVector2Array()
	var up := PackedVector2Array()
	var lo := PackedVector2Array()
	for i in 15:
		var t := float(i) / 14.0
		var x := _hc.x + lerpf(-mw, mw, t)
		var yb := lerpf(corner_y, mouth_y + smile * _fh * 0.008, sin(PI * t))
		line.append(Vector2(x, yb))
		var cupid := ul * 0.3 * bow * _g(t - 0.5, 0.06)
		up.append(Vector2(x, lerpf(corner_y, mouth_y, sin(PI * t)) - sin(PI * t) * ul + cupid))
	for i in 15:
		var t := float(i) / 14.0
		var x := _hc.x + lerpf(-mw * 0.9, mw * 0.9, t)
		lo.append(Vector2(x, lerpf(corner_y, mouth_y, sin(PI * t)) + sin(PI * t) * ll))
	# Lábio superior (cor por vértice: mais escuro junto à linha da boca)
	var upper := PackedVector2Array(up)
	var ucol := PackedColorArray()
	for i in up.size():
		ucol.append(lip_up.lightened(0.05))
	for i in range(line.size() - 1, -1, -1):
		upper.append(line[i])
		ucol.append(lip_up.darkened(0.15))
	_poly_colors(upper, ucol)
	# Lábio inferior (claro no meio, com brilho)
	var lower := PackedVector2Array(line)
	var lcol := PackedColorArray()
	for i in line.size():
		lcol.append(lip_lo.darkened(0.12))
	var lo_r := lo.duplicate()
	lo_r.reverse()
	for i in lo_r.size():
		var t := float(i) / 14.0
		lcol.append(lip_lo.lightened(0.05 * sin(PI * t)).darkened(0.08 * (1.0 - sin(PI * t))))
	lower.append_array(lo_r)
	_poly_colors(lower, lcol)
	_fill(_ellipse(Vector2(_hc.x - mw * 0.12, mouth_y + ll * 0.5), mw * 0.28, ll * 0.18, 12), Color(1, 1, 1, 0.1 + darkness * 0.06))
	# Contornos suaves
	var lw := maxf(0.8, _s * 0.007)
	var ol := PackedVector2Array(up)
	_r_polyline(ol, Color(lip_up.darkened(0.1), 0.35), lw * 0.8, true)
	var olo := PackedVector2Array(lo)
	_r_polyline(olo, Color(lip_lo, 0.35), lw * 0.8, true)
	var lc := PackedColorArray()
	for i in line.size():
		var t := float(i) / 14.0
		lc.append(Color("#3A1C1B", 0.3 + 0.35 * sin(PI * t)))
	_r_polyline_colors(line, lc, lw, true)
	for sx: float in [-1.0, 1.0]:
		_r_circle(Vector2(_hc.x + sx * mw, corner_y), lw * 0.9, Color(0.1, 0.05, 0.05, 0.25))


func _poly_colors(pts: PackedVector2Array, cols: PackedColorArray) -> void:
	if pts.size() < 3:
		return
	if not Geometry2D.triangulate_polygon(pts).is_empty():
		_r_polygon(pts, cols)
	else:
		_fill(pts, cols[0])


# ---------------------------------------------------------------------------
# Barba
# ---------------------------------------------------------------------------

## Densidade (0..1) de pelos da barba `P` no ponto (u, v) do rosto.
func _beard_dens(u: float, v: float, P: Dictionary) -> float:
	if P.is_empty():
		return 0.0
	var f := _f
	var au := absf(u)
	var th := _th(u, v)
	var sharp: float = P["sh"]
	var soft := lerpf(0.09, 0.025, sharp)
	var ln: float = P["ln"]
	var lip_u: float = f["lip_u"] * 2.0
	var lip_l: float = f["lip_l"] * 2.0
	var d := 0.0
	# Bochechas
	var ch: float = P["ch"]
	var cn: float = P["cn"]
	if ch > 0.0:
		var line := lerpf(_N + 0.02, -0.02 + ch * 0.75, smoothstep(_MW * 0.8, _MW * 1.5, au)) - 0.16 * smoothstep(0.55, 1.0, au)
		var dc := smoothstep(line - soft, line + soft, v)
		if cn <= 0.0:
			dc *= smoothstep(_MW * 1.15, _MW * 1.5, au)
		d = maxf(d, dc)
	# Costeletas
	var sd: float = P["sd"]
	if sd > 0.0:
		d = maxf(d, sd * smoothstep(0.78, 0.9, th) * smoothstep(-0.34, -0.2, v) * (1.0 - smoothstep(0.3, 0.45, v) * (1.0 if ch <= 0.0 and float(P["jw"]) <= 0.0 else 0.0)))
	# Contorno da mandíbula
	var jw: float = P["jw"]
	if jw > 0.0:
		var band := smoothstep(0.82 - soft, 0.86, th) * smoothstep(-0.1, 0.1, v)
		if jw < 0.8:
			band *= 1.0 - smoothstep(jw * 1.3, jw * 1.3 + 0.12, au)
		d = maxf(d, band)
	# Queixo
	if cn > 0.0:
		var top := _M + lip_l + 0.05
		var bottom := 1.02 + ln * 0.9
		var cy := (top + bottom) * 0.5
		var ry := (bottom - top) * 0.5 + 0.02
		var rx := _MW * (0.45 + cn * 0.6) * (1.0 + float(P.get("rd", 0.0)) * 0.45)
		var e := sqrt(pow(u / rx, 2.0) + pow((v - cy) / ry, 2.0))
		d = maxf(d, 1.0 - smoothstep(1.0 - soft * 3.0, 1.0 + soft, e))
	# Bigode
	var mu: int = int(P["mu"])
	if mu > 0:
		var top_y := _N + 0.045
		var bot_y := _M - lip_u * 0.55
		if mu == 2:
			top_y = _M - lip_u - 0.045
			bot_y = _M - lip_u * 0.6
		elif mu == 4:
			top_y = _N + 0.025
			bot_y = _M - lip_u * 0.15
		var wx := _MW * (0.95 if mu == 2 else (1.16 if mu == 4 else 1.08))
		var yr := smoothstep(top_y - soft, top_y + soft, v) * (1.0 - smoothstep(bot_y - soft * 0.5, bot_y + soft * 0.5, v + au * 0.1))
		var xr := 1.0 - smoothstep(wx - soft, wx + soft, au)
		var dm := yr * xr
		if mu == 2:
			dm *= smoothstep(0.02, 0.06, au)
		# Pontas do bigode descendo nos cantos
		dm = maxf(dm, (1.0 - smoothstep(0.05, 0.05 + soft, absf(au - _MW * 1.02))) * smoothstep(_N + 0.06, _N + 0.1, v) * (1.0 - smoothstep(_M + 0.02, _M + 0.06, v)) * (0.0 if mu == 2 else 1.0))
		if mu == 3:
			var bar := (1.0 - smoothstep(0.07, 0.07 + soft, absf(au - _MW * 1.12))) * smoothstep(_N + 0.06, _N + 0.1, v) * (1.0 - smoothstep(0.93, 1.0, th))
			dm = maxf(dm, bar)
		d = maxf(d, dm)
	# Cavanhaque fechado: ligação dos cantos da boca ao queixo
	if float(P.get("ci", 0.0)) > 0.0:
		var ring := (1.0 - smoothstep(0.05, 0.05 + soft, absf(au - _MW * 1.04))) * smoothstep(_M - 0.06, _M - 0.02, v) * (1.0 - smoothstep(_M + lip_l + 0.1, _M + lip_l + 0.16, v))
		d = maxf(d, ring)
	# Mosca
	var so: float = P["so"]
	if so > 0.0:
		var sy := _M + lip_l + 0.06
		d = maxf(d, so * (1.0 - smoothstep(0.7, 1.1, sqrt(pow(u / 0.07, 2.0) + pow((v - sy) / 0.05, 2.0)))))
	# Pescoço
	var nk: float = P["nk"]
	if nk > 0.0 and v > 0.6:
		d = maxf(d, nk * smoothstep(0.98, 1.04, th) * (1.0 - smoothstep(1.1 + ln, 1.3 + ln, v)))
	# Fora do rosto só existe volume se a barba for comprida
	if th > 1.0:
		var reach := 0.035 + ln * 0.9
		d *= 1.0 - smoothstep(reach * 0.5, reach, (th - 1.0) * (0.6 if v > 0.6 else 2.5))
	# Barba degradê: afina em direção às costeletas
	var fdb: float = float(P.get("fd", 0.0))
	if fdb > 0.0:
		d *= lerpf(1.0, 0.2, fdb * (1.0 - smoothstep(0.05, 0.4, v)) * smoothstep(0.55, 0.85, au))
	# Nunca sobre os lábios
	var lip_c := _M + (lip_l - lip_u) * 0.5
	var le := sqrt(pow(u / (_MW * 1.0), 2.0) + pow((v - lip_c) / ((lip_u + lip_l) * 0.62), 2.0))
	d *= smoothstep(0.85, 1.05, le)
	# Nunca acima da linha das maçãs
	d *= smoothstep(_E + 0.08, _E + 0.2, v) if au < 0.8 else 1.0
	# Falhas
	var pt: float = maxf(float(P["pt"]), float(f["beard_patch"]) if P != _shadow_p else 0.0)
	if pt > 0.01:
		var sd2 := float(int(f["beard_seed"]) % 1000)
		var nz := 0.5 + 0.28 * sin(u * 19.0 + sd2) * sin(v * 15.0 + sd2 * 0.7) + 0.22 * sin((u - v) * 31.0 + sd2 * 1.3)
		var on_cheek := smoothstep(0.15, 0.45, au) * (1.0 - smoothstep(0.8, 1.0, v))
		d *= lerpf(1.0, smoothstep(pt - 0.12, pt + 0.1, nz), on_cheek * minf(1.0, pt * 1.6))
	return clampf(d, 0.0, 1.0)


func _beard_mesh() -> void:
	var f := _f
	var P := _beard_p
	var ln: float = P["ln"]
	var op: float = P["op"]
	var col: Color = f["beard_col"]
	var head := _head_contour(_contour_k())
	var grown := PackedVector2Array()
	for p in head:
		var q := _uv(p)
		var ext := 0.0
		if q.y > 0.0:
			ext = (0.05 + ln * 1.05 * pow(q.y, 1.5)) * smoothstep(0.0, 0.4, q.y)
		var dir := (p - _hc).normalized()
		grown.append(p + Vector2(dir.x * _fw, dir.y * _fh) * ext + Vector2(0, _fh * ext * 0.6 * float(q.y > 0.5)))
	_beard_data = _radial(_hc, grown, _rings(13), func(p: Vector2, _t: float, _i: int) -> Color:
		var q := _uv(p)
		var dens := _beard_dens(q.x, q.y, P)
		if dens <= 0.0:
			return Color(col, 0.0)
		var lum := 0.95 - 0.22 * clampf(q.x, -1.0, 1.0) - 0.2 * smoothstep(0.6, 1.3, q.y) + 0.12 * _g2(q.x + 0.3, q.y - 0.5, 0.3, 0.2)
		lum += 0.05 * sin(q.x * 23.0 + q.y * 7.0) * sin(q.y * 19.0 - q.x * 5.0)
		var c := col.lerp(Color.BLACK, (1.0 - lum) * 0.6) if lum < 1.0 else col.lerp(col.lightened(0.3), lum - 1.0)
		# Pontas mais claras e mais quentes no queixo e nas bochechas
		c = c.lerp(col.lightened(0.18).lerp(Color("#8A5A3A"), 0.15), 0.25 * smoothstep(0.7, 1.2, q.y) + 0.1 * smoothstep(0.4, 0.8, absf(q.x)))
		return Color(c, dens * op))


func _beard_hairs(rng: RandomNumberGenerator) -> void:
	if _beard_data.size() < 3:
		return
	var f := _f
	var P := _beard_p
	var col: Color = f["beard_col"]
	var ln: float = P["ln"]
	var op: float = P["op"]
	var tx: int = int(P["tx"])
	# Os fios nascem nos vértices da malha da barba (a densidade já está no alfa)
	var pts: PackedVector2Array = _beard_data[1]
	var cols: PackedColorArray = _beard_data[2]
	var cand := PackedInt32Array()
	for i in cols.size():
		if cols[i].a > 0.12 * op:
			cand.append(i)
	if cand.is_empty():
		return
	var n := int((420 if tx == 0 else 220 + ln * 300.0) * clampf(_det, 0.35, 1.8) * (0.6 + op * 0.6))
	var w := maxf(0.6, _s * 0.0036)
	var jit := _fw * 0.05
	for k in n:
		var i := cand[rng.randi() % cand.size()]
		var dens := cols[i].a / maxf(op, 0.01)
		if rng.randf() > dens:
			continue
		var p := pts[i] + Vector2(rng.randf_range(-jit, jit), rng.randf_range(-jit, jit))
		if (p - _c).length() > _R - 1.0:
			continue
		if tx == 0:
			# Pelos curtos: tracinhos finos e claros, não pontos grossos
			var dd := Vector2(rng.randf_range(-0.3, 0.3), 1.0).normalized() * _s * rng.randf_range(0.003, 0.006)
			_r_line(p, p + dd, Color(col.darkened(0.1), rng.randf_range(0.18, 0.38) * (0.5 + op)), maxf(0.5, _s * 0.0022), true)
			continue
		var u := (p.x - _hc.x) / _fw
		var v := (p.y - _hc.y) / _fh
		var dir := Vector2(u * 0.35, 1.0).normalized()
		if absf(v - (_N + _M) * 0.5) < 0.08 and absf(u) < _MW * 1.1:
			dir = Vector2(u * 1.4, 1.0).normalized()
		var length := _s * (0.012 + ln * 0.04) * rng.randf_range(0.6, 1.3)
		var light := rng.randf() < 0.45
		var c := col.lightened(rng.randf_range(0.1, 0.3)) if light else col.darkened(rng.randf_range(0.1, 0.35))
		_r_line(p, p + dir * length, Color(c, rng.randf_range(0.35, 0.7) * op), w, true)


# ---------------------------------------------------------------------------
# Cabelo
# ---------------------------------------------------------------------------

func _hs(key: String, def: Variant) -> Variant:
	return _hair_style.get(key, def)


## Cor do cabelo em um ponto: luz de cima à esquerda, raiz mais escura, faixa de brilho.
func _hair_col(p: Vector2, w: float, t: float, gloss: float) -> Color:
	var f := _f
	var hair: Color = f["hair"]
	var q := _uv(p)
	var dn := Vector2(q.x, q.y * 0.9).normalized() if q.length() > 0.001 else Vector2(0, -1)
	var lum := 0.66 + 0.36 * dn.dot(Vector2(-0.55, -0.83))
	lum *= 0.78 + 0.22 * smoothstep(0.0, 0.45, w)
	lum *= 1.0 - 0.12 * smoothstep(0.85, 1.0, w)
	var c := hair.lerp(Color.BLACK, clampf((1.0 - lum) * 0.75, 0.0, 0.9))
	var tex: int = int(f["texture"])
	var gl: float = float([0.5, 0.36, 0.2, 0.1][tex]) + gloss
	var ang := atan2(q.y, q.x)
	var sheen := _g(ang + PI * 0.62, 0.5) * _g(w - 0.6, 0.3)
	sheen *= 0.62 + 0.38 * sin(t * 97.0 + float(int(f["hair_seed"]) % 100)) * sin(t * 41.0 + 1.3)
	c = c.lerp(hair.lightened(0.55).lerp(Color(0.8, 0.8, 0.85), 0.15 if hair.v < 0.2 else 0.0), clampf(sheen * gl, 0.0, 0.7))
	if bool(f["tips"]):
		c = c.lerp(Color("#E2C98C"), smoothstep(0.35, 0.95, w) * 0.85)
	return c


## Opacidade do cabelo da calota (degradê, linha do cabelo suave, coroa rala).
func _cap_alpha(p: Vector2, w: float) -> float:
	var f := _f
	var q := _uv(p)
	var h := -q.y
	var a: float = float(_hs("op", 1.0))
	match int(_hs("fd", 0)):
		1:
			a *= lerpf(0.5, 1.0, smoothstep(-0.05, 0.3, h))
		2:
			a *= lerpf(0.1, 1.0, smoothstep(0.35, 0.72, h))
		3:
			a *= lerpf(0.16, 1.0, smoothstep(0.62, 0.7, h))
		4: # burst: raspado em volta da orelha, cheio no alto e na nuca
			a *= lerpf(0.1, 1.0, maxf(smoothstep(0.3, 0.55, h), 1.0 - smoothstep(0.55, 0.8, absf(q.x))))
	if int(_hs("sp", 0)) == 4:
		a *= lerpf(0.14, 1.0, 1.0 - smoothstep(0.22, 0.3, absf(q.x)))
	var crown: float = f["crown"]
	if crown > 0.0:
		a *= 1.0 - minf(1.0, crown * 1.3) * _g(q.x, 0.7) * smoothstep(0.35, 0.8, h) * smoothstep(0.05, 0.4, w)
	var sharp: bool = bool(f["lineup"]) or _hs("tx", "") == "braid" or _hs("tx", "") == "waves"
	a *= lerpf(0.9 if sharp else 0.4, 1.0, smoothstep(0.0, 0.08 if sharp else 0.25, w))
	return a


## Monta a calota: linha de fora (silhueta) e de dentro (linha do cabelo), da esquerda para a direita.
func _build_cap() -> void:
	var f := _f
	var vol: float = f["vol"]
	var thin: bool = _hs("tx", "") in ["dots", "braid", "waves"] or int(_hs("fd", 0)) == 3
	var tp: float = (float(_hs("tp", 0.08)) + (0.0 if thin else 0.07)) * (0.85 + vol * 0.3)
	var sd: float = (float(_hs("sd", 0.04)) + (0.0 if thin else 0.035)) * (0.85 + vol * 0.3)
	var sb: float = float(_hs("sb", 0.0))
	var sp: int = int(_hs("sp", 0))
	var cw: float = f["cheek_w"]
	var fore: float = f["forehead"]
	var seed := float(int(f["hair_seed"]) % 1000)
	var n := clampi(int(40 * _det), 18, 48)
	var outer := PackedVector2Array()
	var d0 := asin(clampf(sb, 0.0, 0.9))
	for i in n:
		var a := PI - d0 + (PI + 2.0 * d0) * float(i) / (n - 1)
		var up := maxf(0.0, -sin(a))
		var rx := lerpf(cw, fore, up) * 1.035
		var ext := sd * (1.0 - up * up) + tp * up * up
		if sp == 3:
			ext += 0.035 * sin(a * 11.0 + seed) + 0.025 * sin(a * 17.0 + seed * 1.7)
		var x := cos(a) * (rx + ext * 0.9)
		var y := sin(a) * (1.03 + ext)
		if sp == 1:
			y = -pow(up, 0.22) * (1.03 + tp) if sin(a) < 0.0 else y
			x = cos(a) * (rx + 0.04)
		outer.append(Vector2(x, y))
	# Linha do cabelo
	var rec: float = f["recession"]
	var hl: float = float(f["hairline"]) + float(_hs("hl", 0.0))
	var fringe := float(_hs("hl", 0.0)) > 0.1
	var inner_raw := PackedVector2Array()
	inner_raw.append(Vector2(-cw * 0.9, sb))
	inner_raw.append(Vector2(-cw * 0.89, -0.12))
	inner_raw.append(Vector2(-0.8, hl * 0.62 - rec * 0.25))
	for i in 13:
		var t := float(i) / 12.0
		var u := lerpf(-0.66, 0.66, t)
		var y := hl - 0.045 * sin(PI * t)
		if not fringe:
			y -= rec * 0.12 + rec * 0.3 * smoothstep(0.15, 0.66, absf(u))
			if bool(f["widow"]):
				y += 0.05 * _g(u, 0.09)
		if int(_hs("fl", 0)) == 3:
			# Repartido ao meio: o cabelo cai para os lados e deixa um "V" de testa no centro
			y = hl + 0.2 - 0.1 * absf(u) / 0.66 - 0.2 * _g(u, 0.16) + 0.08 * smoothstep(0.3, 0.66, absf(u))
		inner_raw.append(Vector2(u, y))
	inner_raw.append(Vector2(0.8, hl * 0.62 - rec * 0.25))
	inner_raw.append(Vector2(cw * 0.89, -0.12))
	inner_raw.append(Vector2(cw * 0.9, sb))
	var inner := _resample(inner_raw, n)
	_cap_in = PackedVector2Array()
	_cap_out = PackedVector2Array()
	for i in n:
		_cap_in.append(_px(inner[i].x, inner[i].y))
		_cap_out.append(_px(outer[i].x, outer[i].y))


static func _resample(pts: PackedVector2Array, n: int) -> PackedVector2Array:
	var lens := PackedFloat32Array([0.0])
	for i in range(1, pts.size()):
		lens.append(lens[i - 1] + pts[i].distance_to(pts[i - 1]))
	var total := lens[lens.size() - 1]
	var out := PackedVector2Array()
	var j := 0
	for k in n:
		var target := total * float(k) / (n - 1)
		while j < pts.size() - 2 and lens[j + 1] < target:
			j += 1
		var seg := maxf(lens[j + 1] - lens[j], 1e-6)
		out.append(pts[j].lerp(pts[j + 1], clampf((target - lens[j]) / seg, 0.0, 1.0)))
	return out


func _cap_pt(t: float, w: float) -> Vector2:
	var n := _cap_in.size()
	var x := clampf(t, 0.0, 1.0) * (n - 1)
	var i := mini(int(x), n - 2)
	var lt := x - i
	var a := _cap_in[i].lerp(_cap_in[i + 1], lt)
	var b := _cap_out[i].lerp(_cap_out[i + 1], lt)
	return a.lerp(b, w)


func _front_hair(rng: RandomNumberGenerator, hair: Color) -> void:
	var f := _f
	_build_cap()
	var gloss: float = float(_hs("gl", 0.0))
	_strip(_cap_in, _cap_out, _rings(7), func(p: Vector2, t: float, w: float) -> Color:
		var c := _hair_col(p, w, t, gloss)
		return Color(c, _cap_alpha(p, w)))
	var tex := String(_hs("tx", ["str", "wavy", "curl", "coil"][int(f["texture"])]))
	_cap_texture(rng, tex, hair)
	_front_piece(rng, String(_hs("fr", "")), hair, gloss)
	# Silhueta espetada / crista
	match int(_hs("sp", 0)):
		5:
			for i in 16:
				var t := 0.1 + 0.8 * i / 15.0
				var base := _cap_pt(t, 0.75)
				var tip := _cap_pt(t + rng.randf_range(-0.04, 0.04), 1.0)
				tip += (tip - _hc).normalized().rotated(rng.randf_range(-0.5, 0.5)) * _fw * rng.randf_range(0.05, 0.13)
				var side := (tip - base).orthogonal().normalized() * _fw * rng.randf_range(0.06, 0.1)
				var tc := _hair_col(tip, 0.95, t, 0.1)
				_r_polygon(PackedVector2Array([_cl(base - side), _cl(tip), _cl(base + side)]), PackedColorArray([tc.darkened(0.25), tc.lightened(0.08), tc.darkened(0.15)]))
		2:
			for i in 11:
				var t := 0.12 + 0.76 * i / 10.0
				var base := _cap_pt(t, 0.8)
				var tip := _cap_pt(t + rng.randf_range(-0.02, 0.02), 1.0)
				tip += (tip - _hc).normalized() * _fw * rng.randf_range(0.12, 0.22)
				var side := (tip - base).orthogonal().normalized() * _fw * 0.09
				_r_polygon(PackedVector2Array([_cl(base - side), _cl(tip), _cl(base + side)]), PackedColorArray([hair.darkened(0.2), hair.lightened(0.15), hair.darkened(0.1)]))
		4:
			var hl0: float = float(f["hairline"])
			var h := 0.16 + float(f["vol"]) * 0.12
			var shape := [Vector2(-0.2, hl0 + 0.02), Vector2(-0.25, -0.75), Vector2(-0.22, -1.05 - h * 0.6), Vector2(-0.1, -1.05 - h), Vector2(0.1, -1.05 - h), Vector2(0.22, -1.05 - h * 0.6), Vector2(0.25, -0.75), Vector2(0.2, hl0 + 0.02)]
			var crest := PackedVector2Array()
			var ccol := PackedColorArray()
			for i in shape.size():
				var q: Vector2 = shape[i]
				crest.append(_cl(_px(q.x, q.y)))
				ccol.append(_hair_col(crest[i], 0.3 + 0.6 * clampf(-(q.y + 0.6) / 0.8, 0.0, 1.0), float(i) / 7.0, 0.2).darkened(0.12 if q.x > 0.0 else 0.0))
			_poly_colors(crest, ccol)
			_strands_in_poly(rng, crest, hair, Vector2(0, -1), 24)
	if bool(f["balding"]) or float(f["recession"]) > 0.5:
		_scalp_shine()


## Textura do cabelo sobre a calota.
func _cap_texture(rng: RandomNumberGenerator, tex: String, hair: Color) -> void:
	var f := _f
	var w := maxf(0.6, _s * 0.0036)
	var k := clampf(_det * _det, 0.1, 2.0)
	var flow := int(_hs("fl", 0))
	var part := 0.5 + float(f["part_side"]) * 0.19
	match tex:
		"str", "wavy":
			var n := int(110 * k)
			for i in n:
				var t0 := rng.randf()
				var w0 := rng.randf_range(0.0, 0.25)
				var w1 := rng.randf_range(0.65, 1.0)
				var pts := PackedVector2Array()
				var ok := true
				for j in 7:
					var ww := lerpf(w0, w1, float(j) / 6.0)
					var tt := t0
					if flow == 1:
						tt += (t0 - part) * 0.08 * ww
					elif flow == 3:
						tt += (t0 - 0.5) * 0.12 * ww
					if tex == "wavy":
						tt += 0.012 * sin(ww * 11.0 + t0 * 30.0)
					var p := _cap_pt(tt, ww)
					if _cap_alpha(p, ww) < 0.5:
						ok = false
						break
					pts.append(_cl(p))
				if not ok:
					continue
				var light := rng.randf() < 0.5
				var c := _hair_col(pts[3], 0.6, t0, 0.3).lerp(hair.lightened(0.5), 0.15) if light else hair.darkened(rng.randf_range(0.2, 0.45))
				_r_polyline(pts, Color(c, rng.randf_range(0.2, 0.45)), w, true)
			if int(f["hair_i"]) != FaceGen.HC_PLATINUM and float(f["gray"]) > 0.15:
				for i in int(40 * k * float(f["gray"])):
					var t0 := rng.randf()
					var a := _cap_pt(t0, rng.randf_range(0.1, 0.4))
					var b := _cap_pt(t0 + rng.randf_range(-0.01, 0.01), rng.randf_range(0.6, 0.95))
					if _cap_alpha(a, 0.3) < 0.5 or _cap_alpha(b, 0.8) < 0.5:
						continue
					_r_line(_cl(a), _cl(b), Color(0.85, 0.85, 0.83, 0.35), w, true)
		"curl":
			for i in int(60 * k):
				var p := _cap_pt(rng.randf(), rng.randf_range(0.15, 0.95))
				if _cap_alpha(p, 0.5) < 0.5:
					continue
				var r := _fw * rng.randf_range(0.04, 0.075)
				var a0 := rng.randf() * TAU
				_r_arc(_cl(p), r, a0, a0 + PI * 1.3, 8, Color(hair.lightened(0.28), 0.5), w * 1.2, true)
				_r_arc(_cl(p + Vector2(r * 0.3, r * 0.4)), r, a0 + PI, a0 + PI * 2.1, 8, Color(hair.darkened(0.4), 0.45), w * 1.2, true)
			_outline_bumps(rng, hair, 0.075, 26)
		"coil":
			for i in int(420 * k):
				var ww := rng.randf_range(0.05, 1.0)
				var tt := rng.randf()
				var p := _cap_pt(tt, ww)
				if _cap_alpha(p, ww) < 0.3:
					continue
				var base := _hair_col(p, ww, tt, 0.0)
				var light := rng.randf() < 0.45
				var c := base.lerp(hair.lightened(0.35), 0.35) if light else base.darkened(0.3)
				_r_circle(_cl(p), maxf(0.45, _s * rng.randf_range(0.0022, 0.0042)), Color(c, rng.randf_range(0.25, 0.5)))
			_outline_bumps(rng, hair, 0.028, 56)
		"dots":
			for i in int(170 * k):
				var ww := rng.randf_range(0.0, 1.0)
				var p := _cap_pt(rng.randf(), ww)
				_r_circle(_cl(p), maxf(0.4, _s * 0.0028), Color(hair.darkened(0.2), rng.randf_range(0.25, 0.5)))
		"braid":
			var rows := 8
			for r in rows:
				var t0 := lerpf(0.14, 0.86, float(r) / (rows - 1))
				var pts := PackedVector2Array()
				for j in 12:
					pts.append(_cl(_cap_pt(t0 + (t0 - 0.5) * 0.05 * j / 11.0, lerpf(0.0, 0.98, float(j) / 11.0))))
				_r_polyline(pts, Color(hair.darkened(0.1), 0.95), _fw * 0.09, true)
				for j in 11:
					var a := pts[j]
					var b := pts[j + 1]
					var side := (b - a).orthogonal().normalized() * _fw * 0.035
					_r_line(a - side, b + side, Color(hair.lightened(0.25), 0.55), w * 1.3, true)
		"waves":
			var crown := _px(0.0, -1.35)
			for r in 9:
				var rad := _fh * (0.45 + r * 0.1)
				_r_arc(crown, rad, PI * 0.22, PI * 0.78, 18, Color(hair.lightened(0.3), 0.3), w * 1.4, true)
			for i in int(120 * k):
				var ww := rng.randf_range(0.0, 1.0)
				var p := _cap_pt(rng.randf(), ww)
				_r_circle(_cl(p), maxf(0.4, _s * 0.0028), Color(hair.darkened(0.3), 0.35))
		"locs":
			for i in 12:
				var t0 := 0.08 + 0.84 * i / 11.0
				var pts := PackedVector2Array()
				for j in 6:
					pts.append(_cl(_cap_pt(t0, 0.1 + 0.88 * j / 5.0)))
				_r_polyline(pts, Color(hair.darkened(0.25), 0.6), _fw * 0.08, true)
				_r_polyline(pts, Color(hair.lightened(0.2), 0.35), _fw * 0.025, true)


## Bolinhas na silhueta (cachos e crespos).
func _outline_bumps(rng: RandomNumberGenerator, hair: Color, r: float, n: int) -> void:
	for i in n:
		var t := float(i) / (n - 1)
		var p := _cap_pt(t, 0.97)
		if _cap_alpha(p, 0.9) < 0.5:
			continue
		var rr := _fw * r * rng.randf_range(0.7, 1.2)
		_r_circle(_cl(p), rr, _hair_col(p, 0.9, t, 0.0))


func _strands_in_poly(rng: RandomNumberGenerator, poly: PackedVector2Array, hair: Color, dir: Vector2, n: int) -> void:
	var r := _bounds(poly)
	var w := maxf(0.6, _s * 0.0036)
	var drawn := 0
	var tries := 0
	var cnt := int(n * clampf(_det, 0.4, 1.6))
	while drawn < cnt and tries < cnt * 5:
		tries += 1
		var p := Vector2(rng.randf_range(r.position.x, r.end.x), rng.randf_range(r.position.y, r.end.y))
		if not Geometry2D.is_point_in_polygon(p, poly):
			continue
		var q := p + (dir.normalized() + Vector2(rng.randf_range(-0.2, 0.2), 0)) * _fh * rng.randf_range(0.08, 0.16)
		if not Geometry2D.is_point_in_polygon(q, poly):
			continue
		var light := rng.randf() < 0.5
		_r_line(p, q, Color(hair.lightened(0.25) if light else hair.darkened(0.3), 0.4), w, true)
		drawn += 1


func _blob(center: Vector2, rx: float, ry: float, gloss: float, lumpy: float, seed: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 36:
		var a := TAU * i / 36.0
		var k := 1.0 + lumpy * (0.06 * sin(a * 9.0 + seed) + 0.04 * sin(a * 14.0 + seed * 2.0))
		pts.append(_cl(center + Vector2(cos(a) * rx, sin(a) * ry) * k))
	_blob_c = center
	_blob_r = maxf(rx, ry)
	_radial(center, pts, _rings(6), func(p: Vector2, t: float, _i: int) -> Color:
		return _hair_col(p, clampf(0.35 + t * 0.55, 0.0, 1.0), float(_i) / 36.0, gloss))
	return pts


func _front_piece(rng: RandomNumberGenerator, kind: String, hair: Color, gloss: float) -> void:
	var f := _f
	var hl: float = float(f["hairline"]) + float(_hs("hl", 0.0))
	var w := maxf(0.6, _s * 0.0036)
	match kind:
		"quiff", "pomp":
			var big := kind == "pomp"
			var q := _blob(_px(-0.08, -0.98 - (0.08 if big else 0.0)), _fw * (0.72 if big else 0.62), _fh * (0.3 if big else 0.22), gloss + 0.2, 0.2, 3.0)
			_strands_in_poly(rng, q, hair, Vector2(0.35, -1.0), 22 if big else 16)
		"fringe", "crop":
			var crop := kind == "crop"
			var locks := 11 if not crop else 14
			var top_y := hl - (0.3 if not crop else 0.18)
			for i in locks:
				var t := float(i) / (locks - 1)
				var u := lerpf(-0.78, 0.78, t)
				var lw := 0.1 + rng.randf_range(0.0, 0.05)
				var tip_y := hl + rng.randf_range(-0.03, 0.05) + (0.0 if crop else 0.03 * sin(PI * t))
				var skew := rng.randf_range(-0.05, 0.05) + float(f["part_side"]) * 0.03
				var poly := PackedVector2Array([_px(u - lw, top_y), _px(u + skew, tip_y + 0.02), _px(u + lw, top_y)])
				var tc := _hair_col(_px(u, top_y), 0.8, t, gloss)
				_r_polygon(poly, PackedColorArray([tc, tc.darkened(0.3), tc.darkened(0.05)]))
				_r_line(_px(u, top_y), _px(u + skew * 0.8, tip_y), Color(hair.lightened(0.25), 0.35), w, true)
			# Sombra da franja na testa
			var sh := PackedVector2Array()
			for i in 12:
				var t := float(i) / 11.0
				sh.append(_px(lerpf(-0.7, 0.7, t), hl + 0.05 + 0.03 * sin(PI * t)))
			_r_polyline(sh, Color(0, 0, 0, 0.1), _fh * 0.05, true)
		"locks", "braid_locks":
			var ln := float(_hs("lk", 1.0))
			var braid := kind == "braid_locks"
			for sx: float in [-1.0, 1.0]:
				var inner := PackedVector2Array()
				var outer := PackedVector2Array()
				for i in 10:
					var t := float(i) / 9.0
					var v := lerpf(-0.55, -0.1 + ln, t)
					var hw := _hw(clampf(v, 0.0, 1.0)) if v > 0.0 else float(f["cheek_w"]) * sqrt(maxf(0.0, 1.0 - pow(v / 1.02, 2.0)))
					var ix := hw * lerpf(0.8, 0.95, smoothstep(0.0, 0.35, t))
					if v > 0.75:
						ix = maxf(ix, 0.62 + (v - 0.75) * 0.35)
					var thick := lerpf(0.3, 0.06, pow(t, 1.4)) * (0.8 if braid else 1.0)
					inner.append(_px(sx * ix, v))
					outer.append(_px(sx * (ix + thick + 0.06 * sin(PI * t)), v + 0.03 * t))
				_strip(inner, outer, 3, func(p: Vector2, t: float, ww: float) -> Color:
					var c := _hair_col(p, 0.55 + ww * 0.3, t, gloss)
					return Color(c.darkened(0.08 * t), 1.0 - smoothstep(0.92, 1.0, t) * 0.6))
				var n := int(18 * clampf(_det, 0.4, 1.6))
				for j in n:
					var ww := rng.randf()
					var pts := PackedVector2Array()
					for k in 8:
						var t := float(k) / 7.0
						var i0 := mini(int(t * 8.0), 8)
						var lt := t * 8.0 - i0
						var a := inner[i0].lerp(inner[i0 + 1], lt)
						var b := outer[i0].lerp(outer[i0 + 1], lt)
						var p := a.lerp(b, ww)
						if _hs("tx", "") == "wavy":
							p.x += sin(t * 9.0 + j) * _fw * 0.02
						pts.append(_cl(p))
					var light := rng.randf() < 0.5
					if braid:
						_r_polyline(pts, Color(hair.darkened(0.3), 0.5), _fw * 0.05, true)
						for k in 7:
							_r_line(pts[k], pts[k + 1], Color(hair.lightened(0.25), 0.4), w, true)
					else:
						_r_polyline(pts, Color(hair.lightened(0.25) if light else hair.darkened(0.35), 0.35), w, true)
		"part":
			var px := float(f["part_side"]) * 0.36
			_r_line(_px(px, hl - 0.03), _px(px * 0.75, -1.0), Color(hair.lightened(0.3).lerp(_skin, 0.4), 0.55), maxf(0.8, _s * 0.006), true)
		"design":
			var sx := float(f["part_side"])
			var lw := maxf(0.8, _s * 0.006)
			for k in 2:
				var pts := PackedVector2Array()
				for i in 9:
					var t := float(i) / 8.0
					pts.append(_cl(_px(sx * (0.62 + 0.12 * t + k * 0.1), -0.55 - 0.3 * t + 0.08 * sin(PI * t * 2.0) + k * 0.06)))
				_r_polyline(pts, Color(_skin.lightened(0.05), 0.85), lw, true)
		"side_fringe":
			var sx := float(f["part_side"])
			var lower := PackedVector2Array()
			var upper := PackedVector2Array()
			for i in 12:
				var t := float(i) / 11.0
				var u := sx * lerpf(0.55, -0.95, t)
				var vl := hl - 0.14 + 0.24 * t + 0.05 * sin(PI * t)
				lower.append(_px(u, vl))
				upper.append(_px(u * 0.98, vl - lerpf(0.34, 0.14, t)))
			_strip(lower, upper, 3, func(p: Vector2, t: float, ww: float) -> Color:
				return _hair_col(p, 0.5 + ww * 0.45, t, gloss))
			for j in int(14 * clampf(_det, 0.3, 1.6)):
				var ww := rng.randf_range(0.1, 0.9)
				var pts := PackedVector2Array()
				for k in 12:
					pts.append(_cl(lower[k].lerp(upper[k], ww)))
				_r_polyline(pts, Color(hair.lightened(0.22) if j % 2 == 0 else hair.darkened(0.3), 0.35), w, true)
		"shaved_part":
			var px := float(f["part_side"]) * 0.52
			_r_line(_px(px, hl - 0.02), _px(px * 0.85, -0.95), Color(_skin.lightened(0.05), 0.85), maxf(0.8, _s * 0.007), true)
		"twists", "locs_top":
			# Mechas curtas torcidas, caindo a partir do alto da cabeça
			var n := int(22 * clampf(_det, 0.5, 1.4))
			var th := _fw * (0.12 if kind == "twists" else 0.1)
			for i in n:
				var t := rng.randf_range(0.08, 0.92)
				var ww := rng.randf_range(0.45, 0.95)
				var base := _cap_pt(t, ww)
				var out := (base - _px(0.0, -0.3)).normalized()
				var tip := base + (out * 0.6 + Vector2(0, 0.5)).normalized() * _fw * rng.randf_range(0.1, 0.2)
				var bc := _hair_col(base, ww, t, 0.05)
				_r_line(_cl(base), _cl(tip), bc.darkened(0.15), th, true)
				_r_circle(_cl(tip), th * 0.5, bc.darkened(0.15))
				for k in 3:
					var a := base.lerp(tip, float(k) / 3.0)
					var b2 := base.lerp(tip, float(k + 1) / 3.0)
					var side := (b2 - a).orthogonal().normalized() * th * 0.35
					_r_line(_cl(a - side), _cl(b2 + side), Color(bc.lightened(0.18), 0.35), w * 1.1, true)


func _back_hair(rng: RandomNumberGenerator) -> void:
	var f := _f
	if int(f["style"]) == FaceGen.H_BALD:
		return
	var hair: Color = f["hair"]
	var gloss: float = float(_hs("gl", 0.0))
	var back_dark := hair.darkened(0.25)
	match String(_hs("bk", "")):
		"long", "long_short", "curly_long", "mullet":
			var kind := String(_hs("bk", ""))
			var bottom := 1.3 if kind == "long" else (0.85 if kind == "long_short" else (1.35 if kind == "curly_long" else 1.1))
			var width := 1.28 if kind != "curly_long" else 1.55
			if kind == "mullet":
				width = 1.05
			var pts := PackedVector2Array()
			for i in 30:
				var a := PI + PI * i / 29.0
				pts.append(_px(cos(a) * width, sin(a) * 1.12 - 0.3))
			var lumpy := 1.0 if kind == "curly_long" else 0.0
			var xb := width * 0.78
			for i in 12:
				var t := float(i + 1) / 12.0
				var v := lerpf(-0.3, bottom, t)
				var wd := width * (1.0 + 0.07 * sin(PI * t)) - (width - xb) * t * t + lumpy * 0.06 * sin(t * 12.0)
				pts.append(_px(wd, v))
			for i in 9:
				var t := float(i + 1) / 10.0
				pts.append(_px(lerpf(xb, -xb, t), bottom + 0.07 * sin(PI * t) + rng.randf_range(-0.03, 0.03)))
			for i in 12:
				var t := 1.0 - float(i) / 12.0
				var v := lerpf(-0.3, bottom, t)
				var wd := width * (1.0 + 0.07 * sin(PI * t)) - (width - xb) * t * t + lumpy * 0.06 * sin(t * 12.0 + 1.0)
				pts.append(_px(-wd, v))
			var clean := PackedVector2Array()
			for p in pts:
				clean.append(_cl(p))
			_radial(_hc + Vector2(0, _fh * 0.4), clean, _rings(6), func(p: Vector2, t: float, i: int) -> Color:
				var c := _hair_col(p, 0.6, float(i) / 60.0, gloss).darkened(0.25)
				return c.darkened(0.15 * t))
			if kind == "curly_long":
				for i in int(70 * clampf(_det, 0.4, 1.6)):
					var p := _px(rng.randf_range(-width, width), rng.randf_range(-0.2, bottom))
					var r := _fw * rng.randf_range(0.05, 0.08)
					var a0 := rng.randf() * TAU
					_r_arc(_cl(p), r, a0, a0 + PI * 1.3, 8, Color(hair.lightened(0.2), 0.45), maxf(0.7, _s * 0.004), true)
			else:
				for i in int(50 * clampf(_det, 0.4, 1.6)):
					var x := rng.randf_range(-width, width)
					var a := _px(x, rng.randf_range(-0.1, 0.4))
					var b := _px(x * 1.05 + rng.randf_range(-0.05, 0.05), bottom - rng.randf_range(0.0, 0.2))
					_r_line(_cl(a), _cl(b), Color(hair.lightened(0.15) if rng.randf() < 0.5 else back_dark.darkened(0.2), 0.3), maxf(0.6, _s * 0.0035), true)
		"afro":
			var r := 1.5 + float(f["vol"]) * 0.2
			var cen := _px(0.0, -0.32)
			var pts := _blob(cen, _fw * r, _fw * r * 0.95, 0.0, 1.0, float(int(f["hair_seed"]) % 100))
			for i in int(300 * clampf(_det, 0.4, 1.6)):
				var a := rng.randf() * TAU
				var rr := sqrt(rng.randf()) * _fw * r
				var p := cen + Vector2(cos(a), sin(a) * 0.95) * rr
				_r_circle(_cl(p), maxf(0.5, _s * rng.randf_range(0.003, 0.006)), Color(hair.lightened(0.2) if rng.randf() < 0.4 else hair.darkened(0.35), rng.randf_range(0.3, 0.6)))
			for i in 48:
				var a := TAU * i / 48.0
				var p := cen + Vector2(cos(a), sin(a) * 0.95) * _fw * r * 0.98
				_r_circle(_cl(p), _fw * r * 0.07, _hair_col(p, 0.9, float(i) / 48.0, 0.0))
		"dreads", "braids":
			var braids := String(_hs("bk", "")) == "braids"
			var n := 18 if braids else 15
			for i in n:
				var t := float(i) / (n - 1)
				var x := lerpf(-1.15, 1.15, t)
				var top := _px(x * 0.8, -0.6)
				var bottom := _px(x * 1.12 + rng.randf_range(-0.05, 0.05), rng.randf_range(0.8, 1.3))
				var th := _fw * (0.1 if braids else 0.16)
				var c := back_dark.darkened(rng.randf_range(0.0, 0.2))
				_r_line(_cl(top), _cl(bottom), c, th, true)
				_r_circle(_cl(bottom), th * 0.5, c)
				_r_line(_cl(top + Vector2(-th * 0.2, 0)), _cl(bottom + Vector2(-th * 0.2, 0)), Color(hair.lightened(0.15), 0.3), th * 0.25, true)
		"bun", "knot":
			var knot := String(_hs("bk", "")) == "knot"
			var bc := _px(0.0, -1.12 if not knot else -1.18)
			var br := _fw * (0.34 if not knot else 0.26)
			var bp := _blob(bc, br, br * 0.9, 0.2, 0.2, 5.0)
			_strands_in_poly(rng, bp, hair, Vector2(0.5, -1), 10)
		"pony":
			var pts := PackedVector2Array([_px(0.55, 0.2), _px(0.95, 0.15), _px(1.2, 0.8), _px(1.05, 1.35), _px(0.8, 1.3), _px(0.85, 0.7)])
			var cols := PackedColorArray()
			for p in pts:
				cols.append(_hair_col(p, 0.6, 0.5, gloss).darkened(0.2))
			for i in pts.size():
				pts[i] = _cl(pts[i])
			_poly_colors(pts, cols)
			_strands_in_poly(rng, pts, hair, Vector2(0.2, 1.0), 14)


func _scalp_shine() -> void:
	var p := _px(-0.25, -0.8)
	_fill(_ellipse(p, _fw * 0.32, _fh * 0.11, 18), Color(1, 1, 1, 0.08))
	_fill(_ellipse(p + Vector2(-_fw * 0.04, -_fh * 0.01), _fw * 0.15, _fh * 0.05, 14), Color(1, 1, 1, 0.08))


func _accessories() -> void:
	var f := _f
	if bool(f["headband"]):
		var hy := float(f["hairline"]) - 0.02
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		for i in 13:
			var t := float(i) / 12.0
			var u := lerpf(-1.08, 1.08, t)
			pts.append(_cl(_px(u, hy - 0.05 - 0.05 * sin(PI * t))))
			cols.append(trim_color.lightened(0.1 * (1.0 - t)))
		for i in range(12, -1, -1):
			var t := float(i) / 12.0
			var u := lerpf(-1.08, 1.08, t)
			pts.append(_cl(_px(u, hy + 0.07 - 0.05 * sin(PI * t))))
			cols.append(trim_color.darkened(0.15 + 0.15 * t))
		_poly_colors(pts, cols)


# ---------------------------------------------------------------------------
# Desenho gravado
# ---------------------------------------------------------------------------

func _r_line(a: Vector2, b: Vector2, col: Color, w: float = -1.0, aa: bool = false) -> void:
	draw_line(a, b, col, w, aa)
	if _recording:
		_rec.append([0, a, b, col, w, aa])


func _r_polyline(pts: PackedVector2Array, col: Color, w: float = -1.0, aa: bool = false) -> void:
	draw_polyline(pts, col, w, aa)
	if _recording:
		_rec.append([1, pts, col, w, aa])


func _r_polyline_colors(pts: PackedVector2Array, cols: PackedColorArray, w: float = -1.0, aa: bool = false) -> void:
	draw_polyline_colors(pts, cols, w, aa)
	if _recording:
		_rec.append([2, pts, cols, w, aa])


func _r_circle(p: Vector2, r: float, col: Color) -> void:
	draw_circle(p, r, col)
	if _recording:
		_rec.append([3, p, r, col])


func _r_arc(c: Vector2, r: float, a0: float, a1: float, n: int, col: Color, w: float = -1.0, aa: bool = false) -> void:
	draw_arc(c, r, a0, a1, n, col, w, aa)
	if _recording:
		_rec.append([4, c, r, a0, a1, n, col, w, aa])


func _r_polygon(pts: PackedVector2Array, cols: PackedColorArray) -> void:
	draw_polygon(pts, cols)
	if _recording:
		_rec.append([5, pts, cols])


func _r_colored_polygon(pts: PackedVector2Array, col: Color, uvs: PackedVector2Array = PackedVector2Array(), tex: Texture2D = null) -> void:
	draw_colored_polygon(pts, col, uvs, tex)
	if _recording:
		_rec.append([6, pts, col, uvs, tex])


func _r_tri(idx: PackedInt32Array, pts: PackedVector2Array, cols: PackedColorArray) -> void:
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), idx, pts, cols)
	if _recording:
		_rec.append([7, idx, pts, cols])


func _replay(cmds: Array) -> void:
	var ci := get_canvas_item()
	for c: Array in cmds:
		match int(c[0]):
			0:
				draw_line(c[1], c[2], c[3], c[4], c[5])
			1:
				draw_polyline(c[1], c[2], c[3], c[4])
			2:
				draw_polyline_colors(c[1], c[2], c[3], c[4])
			3:
				draw_circle(c[1], c[2], c[3])
			4:
				draw_arc(c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8])
			5:
				draw_polygon(c[1], c[2])
			6:
				draw_colored_polygon(c[1], c[2], c[3], c[4])
			7:
				RenderingServer.canvas_item_add_triangle_array(ci, c[1], c[2], c[3])


# ---------------------------------------------------------------------------
# Geometria auxiliar
# ---------------------------------------------------------------------------

## Preenche um polígono; se ele se cruzar (traços extremos), limpa o contorno antes.
func _fill(pts: PackedVector2Array, col: Color, uvs: PackedVector2Array = PackedVector2Array(), tex: Texture2D = null) -> void:
	if pts.size() < 3:
		return
	if not Geometry2D.triangulate_polygon(pts).is_empty():
		_r_colored_polygon(pts, col, uvs, tex)
		return
	for piece in Geometry2D.offset_polygon(pts, 0.05):
		if not Geometry2D.triangulate_polygon(piece).is_empty():
			_r_colored_polygon(piece, col)


static func _centroid(poly: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	for p in poly:
		c += p
	return c / maxf(1.0, poly.size())


static func _bounds(poly: PackedVector2Array) -> Rect2:
	var r := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		r = r.expand(p)
	return r


static func _ellipse(c: Vector2, rx: float, ry: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts
