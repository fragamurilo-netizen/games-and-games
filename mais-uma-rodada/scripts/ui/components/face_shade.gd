class_name FaceShade
extends RefCounted
## Luz de estúdio do retrato inteiro, pintada por malha (a mesma técnica da luz dos uniformes, mas
## com um modelo próprio do boneco). O busto vira um volume numa grade só:
## - cabeça: crânio, testa, arco das sobrancelhas, órbitas, globo ocular, nariz (dorso, ponta e
##   asas), maçãs, sulco nasolabial, boca, lábios e queixo;
## - cabelo: uma casca em volta do crânio (e o cabelo de trás, mais atrás); orelhas;
## - pescoço: um cilindro atrás do queixo; ombros e peito: o tronco com os ombros virando para cima.
## Do volume saem a luz direta (com a pele "enrolando" a luz), a sombra projetada de uma parte na
## outra (cabeça e queixo no pescoço, cabelo na testa, nariz na bochecha, sobrancelha no olho), a
## oclusão nos encontros e vincos, a luz de recorte fria do lado da sombra e o brilho da pele. As
## camadas são desenhadas no fim, por cima de pele, olhos, boca, barba, cabelo, pescoço e camisa,
## com a cor de sombra de cada material. Teste: liga com PortraitView.mesh_light.

const LIGHT := Vector3(-0.4, -0.5, 0.77)
## Profundidade da cabeça (em meias larguras do rosto) e expoente do perfil: a frente do rosto é
## mais plana que uma esfera e vira rápido nas laterais.
const DEPTH := 1.1
const PROFILE := 2.4
const SKULL_N := 2.35
## Quanto a luz "enrola" além do terminador (espalhamento sob a pele).
const WRAP := 0.38
## Penumbra da sombra projetada (fonte de luz grande, como um softbox).
const PENUMBRA := 0.4
## Partes do busto na grade
const R_NONE := 0
const R_FACE := 1
const R_HAIR := 2
const R_EAR := 3
const R_NECK := 4
const R_CLOTH := 5
const R_BACK := 6
## Quanto da forma (luz direta) cada parte recebe por cima do sombreado que já tem desenhado.
const FORM := [0.0, 0.5, 1.0, 0.55, 0.85, 0.85, 0.8]
## Ferramentas: 1 mostra só a luz em cinza (opaca), 2 mostra as partes do busto em cores.
static var debug := 0
## Ferramentas: soma o tempo de cada etapa (ms) para medir o custo.
static var profile: Dictionary = {}


static func _tick(key: String, t0: int) -> int:
	var t1 := Time.get_ticks_usec()
	profile[key] = float(profile.get(key, 0.0)) + (t1 - t0) / 1000.0
	return t1
## Luz de recorte (fria, do lado da sombra) por parte.
const RIM := [0.0, 0.08, 0.12, 0.12, 0.12, 0.16, 0.12]

var _pv: PortraitView
var _a := 1.4
var _E := 0.0
var _X := 0.0
var _N := 0.0
var _M := 0.0
var _NW := 0.0
var _BW := 0.0
var _MW := 0.0
var _ND := 0.0
var _k := PackedFloat32Array()
var _ul := 0.0
var _ll := 0.0
var _mw := 0.0
var _tipw := 1.0
var _chin_len := 0.0
var _hw_tab := PackedFloat32Array()
var _rx_tab := PackedFloat32Array()
# Grade em pixels sobre o quadro do retrato
var _o := Vector2.ZERO
var _st := 3.0
var _nx := 0
var _ny := 0
var _h := PackedFloat32Array()
var _reg := PackedByteArray()
# Luz por ponto da grade: direta (sem sombra projetada nem oclusão), final, recorte e brilho
var _lit := PackedFloat32Array()
var _lum := PackedFloat32Array()
var _rim := PackedFloat32Array()
var _spc := PackedFloat32Array()
var _front := 0.0
var _spec_k := 0.2
# Cores da sombra e da luz por parte
var _deep: Array = []
var _warm: Array = []
var _lift: Array = []


func _setup(pv: PortraitView) -> void:
	_pv = pv
	var f: Dictionary = pv._f
	_a = pv._fh / pv._fw
	_E = pv._E
	_X = pv._X
	_N = pv._N
	_M = pv._M
	_NW = pv._NW
	_BW = pv._BW
	_MW = pv._MW
	_ND = pv._ND
	_k = pv._k
	_ul = float(f["lip_u"]) * 2.0
	_ll = float(f["lip_l"]) * 2.0
	_mw = _MW * (1.0 + maxf(0.0, float(f["smile"]) - 0.6) * 0.18)
	_tipw = float(f.get("nose_tip_width", 1.0))
	_chin_len = float(f.get("chin_len", 0.0))
	_hw_tab.resize(257)
	_rx_tab.resize(257)
	for i in 257:
		_hw_tab[i] = pv._hw(float(i) / 256.0)
		_rx_tab[i] = pv._skull_rx(float(i) / 256.0)


static func _g2(x: float, y: float, sx: float, sy: float) -> float:
	return exp(-(x * x) / (sx * sx) - (y * y) / (sy * sy))


static func _tab(t: PackedFloat32Array, x: float) -> float:
	var fx := clampf(x, 0.0, 1.0) * 256.0
	var i := mini(int(fx), 255)
	return lerpf(t[i], t[i + 1], fx - i)


# ---------------------------------------------------------------------------
# Relevo
# ---------------------------------------------------------------------------

## Perfil da cabeça: 1 na frente do rosto, 0 no contorno (a borda vira para longe da câmera) e
## negativo fora dele, continuando a curva: a borda é uma parede suave, sem degrau para o fundo.
static func _prof(th: float, p: float) -> float:
	var q := 1.0 - pow(th, p)
	return pow(q, 1.0 / p) if q >= 0.0 else -pow(-q, 1.0 / p)


func _dome(u: float, v: float) -> float:
	var au := absf(u)
	var top := 0.0
	var low := 0.0
	if v < 0.06:
		var up := maxf(0.0, -v) / 1.02
		var rx := _tab(_rx_tab, up)
		var th := pow(pow(au / rx, SKULL_N) + pow(up, SKULL_N), 1.0 / SKULL_N)
		top = _prof(th, PROFILE)
	if v > -0.12:
		var vv := maxf(v, 0.0) / (1.0 + _chin_len * smoothstep(0.7, 1.0, v))
		var x := au / maxf(_tab(_hw_tab, minf(vv, 1.0)), 0.02)
		# Na vertical o rosto é quase reto da testa à boca e o queixo vira para baixo
		var cx := _prof(x, PROFILE)
		var cy := _prof(vv, 4.0)
		low = cx * cy if cx > 0.0 or cy > 0.0 else -absf(cx * cy)
		if cx < 0.0 and cy < 0.0:
			low = minf(cx, cy)
	if v <= -0.12:
		return top
	if v >= 0.06:
		return low
	return lerpf(top, low, smoothstep(-0.12, 0.06, v))


## Altura do rosto em (u, v), em meias larguras do rosto (negativa fora da cabeça).
func _height(u: float, v: float) -> float:
	var d := _dome(u, v)
	if d <= 0.0:
		return DEPTH * d
	return DEPTH * d + _relief(u, v) * smoothstep(0.0, 0.4, d)


## Volumes do rosto por cima do perfil da cabeça.
func _relief(u: float, v: float) -> float:
	var k := _k
	var au := absf(u)
	var E := _E
	var X := _X
	var N := _N
	var M := _M
	var h := 0.0
	# Testa: bossas frontais; têmporas fundas
	h += 0.025 * _g2(au - 0.3, v + 0.55, 0.24, 0.2)
	h -= (0.04 + 0.07 * k[18] + 0.04 * k[15]) * _g2(au - 0.9, v + 0.28, 0.14, 0.22)
	# Arco das sobrancelhas e glabela (entre elas); logo acima, um leve afundamento
	h += 0.06 * k[1] * _g2(au - 0.36, v - (E - 0.165), 0.27, 0.06)
	h += 0.035 * k[1] * _g2(u, v - (E - 0.13), 0.12, 0.07)
	h -= 0.015 * _g2(au - 0.3, v - (E - 0.3), 0.25, 0.06)
	# Órbitas: fundas no canto de dentro e embaixo do arco; o globo ocular estufa as pálpebras
	h -= (0.06 + 0.07 * k[0]) * _g2(au - (X - 0.03), v - (E - 0.02), 0.25, 0.12)
	h -= 0.05 * k[0] * _g2(au - (X - 0.22), v - E, 0.07, 0.06)
	h += 0.075 * _g2(au - X, v - (E + 0.01), 0.17, 0.075)
	# Olheira funda, bolsas
	if k[28] > 0.0:
		h -= 0.03 * k[28] * _g2(au - X * 0.8, v - (E + 0.16), 0.14, 0.03)
	if k[17] > 0.01:
		h += 0.025 * k[17] * _g2(au - X, v - (E + 0.12), 0.13, 0.03)
	# Maçãs (osso e a gordura logo à frente) e bochecha funda embaixo
	h += 0.065 * k[6] * _g2(au - 0.55, v - 0.12, 0.26, 0.14)
	h += 0.03 * _g2(au - 0.38, v - 0.25, 0.18, 0.12)
	h -= 0.55 * k[7] * _g2(au - 0.62, v - 0.44, 0.16, 0.14)
	if k[19] > 0.01:
		h += 0.035 * k[19] * _g2(au - 0.45, v - 0.2, 0.15, 0.09)
	if k[20] > 0.01:
		h += 0.05 * k[20] * _g2(au - 0.55, v - 0.45, 0.22, 0.16)
	if k[16] > 0.01:
		h += 0.035 * k[16] * _g2(au - _MW * 1.7, v - 0.8, 0.1, 0.08)
	# Arco dos dentes: a região da boca vem para a frente; queixo
	h += 0.075 * _g2(u, v - (M - 0.04), 0.42, 0.21)
	h += 0.07 * _g2(u, v - 0.86, 0.22, 0.1)
	if k[9] > 0.0:
		h -= 0.022 * k[9] * _g2(u, v - 0.9, 0.03, 0.06)
	h += _nose(u, v)
	h += _lips(u, v)
	h += _nasolabial(au, v)
	return h


func _nose(u: float, v: float) -> float:
	var E := _E
	var N := _N
	if v < E - 0.22 or v > N + 0.14:
		return 0.0
	var k := _k
	var nu := u - _ND * smoothstep(E - 0.05, N, v)
	var anu := absf(nu)
	# Dorso: a projeção cresce da raiz (entre os olhos) até a ponta e cai embaixo dela
	var t := clampf((v - (E - 0.08)) / ((N - 0.05) - (E - 0.08)), 0.0, 1.0)
	var proj := (0.09 + 0.17 * k[3]) * pow(t, 0.85)
	proj *= 1.0 - 0.45 * k[25] * (1.0 - t)
	proj += (0.03 * k[2] + 0.045 * k[26]) * exp(-pow((t - 0.5) / 0.17, 2.0))
	var w := lerpf(_BW * 1.7, _NW * 0.62 * _tipw, smoothstep(0.3, 1.0, t))
	var under := 1.0 - smoothstep(N - 0.07, N + 0.045, v)
	var h := proj * exp(-pow(nu / w, 2.0)) * under
	# Ponta (lóbulo), maior na ponta bulbosa e menor na afilada
	h += (0.05 * k[4] + 0.04 * k[22]) * _g2(nu + 0.005, v - (N - 0.055), _NW * (0.42 + 0.12 * k[22] - 0.08 * k[23]) * _tipw, 0.055)
	# Asas e o sulco que as separa da bochecha
	var wing := _NW * (0.8 + 0.16 * k[24])
	h += (0.1 + 0.03 * k[24]) * _g2(anu - wing, v - (N - 0.035), _NW * 0.3, 0.045)
	h -= 0.035 * _g2(anu - wing * 1.38, v - (N - 0.03), _NW * 0.13, 0.06)
	# Narinas e a base do nariz
	h -= 0.04 * _g2(anu - _NW * 0.42, v - (N + 0.006), _NW * 0.2, 0.02)
	return h


func _lips(u: float, v: float) -> float:
	var M := _M
	if v < M - 0.16 or v > M + 0.3:
		return 0.0
	var au := absf(u)
	var mw := _mw
	var taper := clampf(1.0 - pow(au / (mw * 1.05), 2.0), 0.0, 1.0)
	var tp := sqrt(taper)
	var h := 0.0
	var pout := float(_k[29])
	# Lábio de cima: o ponto mais à frente é a borda de cima; dali a boca entra até a linha
	var s := (v - (M - _ul * tp)) / maxf(_ul, 0.01)
	h += 0.04 * tp * exp(-pow((s - 0.2) / 0.5, 2.0))
	# Lábio de baixo: cheio no meio, voltando para a linha da boca e para o sulco embaixo
	var s2 := (v - M) / maxf(_ll, 0.01)
	h += (0.05 + 0.03 * pout) * tp * exp(-pow((s2 - 0.45) / 0.45, 2.0))
	# Linha da boca, cantos e sulco mentolabial
	h -= 0.02 * tp * exp(-pow((v - M) / 0.018, 2.0))
	h -= 0.025 * _g2(au - mw * 1.02, v - M, 0.045, 0.04)
	h -= 0.04 * _g2(u, v - (M + _ll + 0.05), mw * 0.85, 0.035)
	# Filtro: duas colunas e o sulco entre o nariz e o lábio
	var pk := 0.4 + float(_k[27])
	if v > _N and v < M:
		var wv := exp(-pow((v - (_N + M) * 0.5) / 0.05, 2.0))
		h += 0.01 * pk * (exp(-pow((au - 0.055) / 0.025, 2.0))) * wv
		h -= 0.008 * pk * exp(-pow(u / 0.025, 2.0)) * wv
	return h


## Sulco nasolabial: a gordura da bochecha faz uma crista do lado de fora e um vale do de dentro,
## sumindo nas pontas (a mesma dobra das camisas).
func _nasolabial(au: float, v: float) -> float:
	var k5 := _k[5]
	if k5 <= 0.0 or v < _N - 0.12 or v > _M + 0.16:
		return 0.0
	var a := Vector2(_NW * 1.25, _N - 0.02)
	var b := Vector2(_mw * 1.12, _M + 0.05)
	# Em unidades iguais nos dois eixos
	var p := Vector2(au, v * _a)
	var pa := Vector2(a.x, a.y * _a)
	var pb := Vector2(b.x, b.y * _a)
	var ab := pb - pa
	var t := clampf((p - pa).dot(ab) / ab.length_squared(), 0.0, 1.0)
	var q := pa + ab * t
	var d := p.distance_to(q)
	# Lado de fora (bochecha) positivo
	if ab.x * (p.y - pa.y) - ab.y * (p.x - pa.x) > 0.0:
		d = -d
	var w := 0.06
	var x := d / w
	var fade := pow(sin(PI * t), 0.6)
	return 0.3 * k5 * x * exp(0.5 - 0.5 * x * x) * fade


## Pele oleosa: onde o brilho aparece (zona T, maçãs, queixo, lábio de baixo).
func _oil(u: float, v: float) -> float:
	var nu := u - _ND * smoothstep(_E - 0.05, _N, v)
	var o := 0.0
	o += 0.85 * _g2(u + 0.12, v + 0.5, 0.36, 0.22)
	o += 1.0 * _g2(nu + 0.02, v - (_E + _N) * 0.55, _BW * 1.5, (_N - _E) * 0.45)
	o += 1.0 * _g2(nu + 0.01, v - (_N - 0.065), _NW * 0.45, 0.05)
	o += 0.7 * _g2(absf(u) - 0.46, v - 0.1, 0.17, 0.09)
	o += 0.55 * _g2(u, v - 0.86, 0.16, 0.07)
	o += 0.4 * _g2(u, v - (_M + _ll * 0.45), _mw * 0.55, _ll * 0.4) # brilho forte no lábio deixava a boca cinzenta
	return minf(o, 1.0)



# ---------------------------------------------------------------------------
# Grade, luz e desenho
# ---------------------------------------------------------------------------

func _at(arr: PackedFloat32Array, q: Vector2) -> float:
	var x := (q.x - _o.x) / _st
	var y := (q.y - _o.y) / _st
	var i := clampi(int(floor(x)), 0, _nx - 2)
	var j := clampi(int(floor(y)), 0, _ny - 2)
	var fx := clampf(x - i, 0.0, 1.0)
	var fy := clampf(y - j, 0.0, 1.0)
	var b := j * _nx + i
	return lerpf(lerpf(arr[b], arr[b + 1], fx), lerpf(arr[b + _nx], arr[b + _nx + 1], fx), fy)


## Média móvel (duas passadas de caixa em cada eixo): a altura "em volta" de cada ponto.
func _blur(src: PackedFloat32Array, r: int) -> PackedFloat32Array:
	var cur := src
	var inv := 1.0 / float(2 * r + 1)
	for it in 2:
		var tmp := PackedFloat32Array()
		tmp.resize(cur.size())
		for j in _ny:
			var row := j * _nx
			var acc := 0.0
			for i in range(-r, r + 1):
				acc += cur[row + clampi(i, 0, _nx - 1)]
			for i in _nx:
				tmp[row + i] = acc * inv
				acc += cur[row + mini(i + r + 1, _nx - 1)] - cur[row + maxi(i - r, 0)]
		var out := PackedFloat32Array()
		out.resize(cur.size())
		for i in _nx:
			var acc := 0.0
			for j in range(-r, r + 1):
				acc += tmp[clampi(j, 0, _ny - 1) * _nx + i]
			for j in _ny:
				out[j * _nx + i] = acc * inv
				acc += tmp[mini(j + r + 1, _ny - 1) * _nx + i] - tmp[maxi(j - r, 0) * _nx + i]
		cur = out
	return cur




## Pinta a luz do retrato `pv` (com _setup e _body_setup feitos), por cima de tudo o que já foi
## desenhado. `masks`: contornos (em pixels) de olhos e lábios, que recebem a forma inteira do
## rosto; `beard`: a malha da barba ([índices, pontos, cores]), idem; `back`: silhuetas do cabelo
## de trás.
static func paint(pv: PortraitView, masks: Array, beard: Array, back: Array) -> void:
	var fs := FaceShade.new()
	fs._setup(pv)
	fs._run(masks, beard, back)


## Partes do busto: contornos em pixels e o que é preciso para a altura de cada uma.
var _head := PackedVector2Array()
var _cap := PackedVector2Array()
var _band := PackedVector2Array()
var _cap_r := PackedFloat32Array()
var _ears: Array = []
var _body := PackedVector2Array()
var _top_r := PackedVector2Array()
var _back: Array = []
var _last_d := 0.0
var _last_soft := 0.0
var _edge := PackedFloat32Array()
## Peso das normais suavizadas (cabelo, barba, corpo): o pelo e o tecido não têm quina.
var _soft := PackedFloat32Array()
## Raio do volume do cabelo (calota e cabelo de trás juntos) por ângulo, a partir do centro da cabeça
var _hair_r := PackedFloat32Array()
var _beard_on := false
var _beard_ln := 0.0


func _parts(back: Array) -> Array:
	var pv := _pv
	_head = pv._head_contour(pv._contour_k())
	var polys: Array = [_head]
	if int(pv._f["style"]) != FaceGen.H_BALD and pv._cap_out.size() > 2:
		_cap = pv._cap_out
		_band = PackedVector2Array(pv._cap_out)
		var rin := pv._cap_in.duplicate()
		rin.reverse()
		_band.append_array(rin)
		_cap_r = pv._angle_radius_table(pv._hc, _cap, 128)
		polys.append(_cap)
	var f: Dictionary = pv._f
	var er: float = f["ear"]
	var out: float = f["ear_out"]
	for sx: float in [-1.0, 1.0]:
		var ec := pv._px(sx * (float(f["cheek_w"]) * 0.97 + out * 0.07), 0.04)
		var ew := pv._fw * (0.15 + out * 0.04) * er * float(f.get("ear_width", 1.0))
		var eh := pv._fh * 0.2 * er * float(f.get("ear_height", 1.0))
		_ears.append([ec, Vector2(ew, eh)])
		polys.append(PortraitView._ellipse(ec, ew * 1.02, eh * 1.02, 20))
	var right := pv._torso_side(0.0, true)
	_body = PortraitView._mirror(right, pv._hc.x)
	_body.append_array(right)
	_top_r = pv._torso_side(0.0, false)
	polys.append(_body)
	for b: PackedVector2Array in back:
		if b.size() > 2:
			_back.append(b)
			polys.append(b)
	# Cabelo de cima e de trás formam um volume só (antes eram dois, com emenda entre eles)
	var hp: Array = []
	if not _cap.is_empty():
		hp.append(_cap)
	hp.append_array(_back)
	_hair_r = _radius_table(pv._hc, hp, 128)
	_beard_on = int(f["beard"]) != FaceGen.B_NONE
	if _beard_on:
		_beard_ln = float(pv._beard_p.get("ln", 0.0))
	# União das partes, recortada no quadro do retrato (buracos ficam de fora)
	var shapes: Array = []
	for p: PackedVector2Array in polys:
		var piece := p
		var i := 0
		while i < shapes.size():
			var outer := _outers(Geometry2D.merge_polygons(shapes[i], piece))
			if outer.size() == 1:
				piece = outer[0]
				shapes.remove_at(i)
				i = 0
				continue
			i += 1
		shapes.append(piece)
	var clip := pv._clip_poly()
	var res: Array = []
	for sh: PackedVector2Array in shapes:
		res.append_array(_outers(Geometry2D.intersect_polygons(sh, clip)))
	return res


## Contornos de fora de um resultado de Geometry2D (os buracos giram ao contrário).
static func _outers(polys: Array) -> Array:
	var best := -1.0
	var cw := false
	for q: PackedVector2Array in polys:
		var a := 0.0
		for i in q.size():
			a += q[i].cross(q[(i + 1) % q.size()])
		if absf(a) > best:
			best = absf(a)
			cw = Geometry2D.is_polygon_clockwise(q)
	var out: Array = []
	for q: PackedVector2Array in polys:
		if q.size() >= 3 and Geometry2D.is_polygon_clockwise(q) == cw:
			out.append(q)
	return out


## Altura do tronco na linha de cima (ombros) em x: interpola o lado direito do tronco.
func _top_y(adx: float) -> float:
	var x := _pv._hc.x + adx
	var t := _top_r
	if x <= t[0].x:
		return t[0].y
	for i in t.size() - 1:
		if x <= t[i + 1].x:
			return lerpf(t[i].y, t[i + 1].y, (x - t[i].x) / maxf(0.001, t[i + 1].x - t[i].x))
	return t[t.size() - 1].y


## Maior raio de cada ângulo (a partir de c) entre os contornos; ângulos sem nenhum ponto pegam
## o vizinho.
static func _radius_table(c: Vector2, polys: Array, bins: int) -> PackedFloat32Array:
	var tab := PackedFloat32Array()
	tab.resize(bins)
	tab.fill(0.0)
	for poly: PackedVector2Array in polys:
		var n := poly.size()
		for i in n:
			var a := poly[i] - c
			var b := poly[(i + 1) % n] - c
			for k in 9:
				var d := a.lerp(b, k / 8.0)
				var bi := int(floor(fposmod(d.angle(), TAU) / TAU * bins)) % bins
				tab[bi] = maxf(tab[bi], d.length())
	for pass_i in 4:
		for i in bins:
			if tab[i] <= 0.0:
				tab[i] = maxf(tab[(i + bins - 1) % bins], tab[(i + 1) % bins])
	return tab


static func _star(c: Vector2, tab: PackedFloat32Array, p: Vector2) -> float:
	var d := p - c
	var bins := tab.size()
	var x := fposmod(d.angle(), TAU) / TAU * bins
	var i := int(floor(x)) % bins
	var r := lerpf(tab[i], tab[(i + 1) % bins], x - floor(x))
	return d.length() / maxf(r, 0.001)


## Altura (em pixels, para a câmera) e parte do busto no ponto p.
func _sample(p: Vector2) -> Vector2:
	var pv := _pv
	var F := pv._fw
	var zh := 1.3 * F
	var u := (p.x - pv._hc.x) / F
	var v := (p.y - pv._hc.y) / pv._fh
	var d := _dome(u, v)
	_last_d = d
	_last_soft = 0.0
	# Barba: camada de pelo por cima da pele (e, fora do rosto, um volume próprio sobre o pescoço)
	var cov := 0.0
	if _beard_on and v > _N - 0.25:
		cov = _beard_cov(u, v)
	var hair := _in_hair(p)
	if d > 0.0:
		var zf := zh + F * (DEPTH * d + _relief(u, v) * smoothstep(0.0, 0.4, d))
		if hair and Geometry2D.is_point_in_polygon(p, _band):
			# Cabelo sobre a cabeça: nasce colado na pele (sem degrau na linha do cabelo) e vai
			# ganhando o volume do cabelo para cima e para os lados. Onde ainda está colado, a luz
			# é a da pele (senão a linha do cabelo vira uma faixa cinza)
			var hz := _hair_z(p)
			# Máximo suave: o cabelo encontra a testa sem quina
			var zz := _smax(zf + 0.01 * F, hz, 0.08 * F)
			if hz > zf + 0.03 * F:
				_last_soft = 1.0
				return Vector2(zz, R_HAIR)
			_last_soft = 0.6
			return Vector2(zz, R_FACE)
		if cov > 0.0:
			# Barba: uma camada que segue o rosto; a comprida forma uma cortina na frente da
			# mandíbula (o contorno do queixo não aparece através dela)
			_last_soft = cov
			zf = maxf(zf + F * (0.04 + 0.1 * _beard_ln) * cov, _beard_plane(cov, v))
		return Vector2(zf, R_FACE)
	if hair:
		_last_soft = 1.0
		return Vector2(_hair_z(p), R_HAIR)
	var under := _sample_body(p)
	if cov > 0.05:
		# Barba sobre o pescoço: sai da altura do que está embaixo aos poucos (sem degrau na borda)
		_last_soft = 1.0
		var top := maxf(_beard_plane(cov, v), 1.3 * F) if _beard_ln >= 0.3 else under.x + F * 0.06 * cov
		var zb := lerpf(under.x, top, smoothstep(0.05, 0.6, cov))
		return Vector2(zb, R_HAIR if cov > 0.3 or under.y == R_NONE else under.y)
	return under


func _sample_body(p: Vector2) -> Vector2:
	var pv := _pv
	var F := pv._fw
	var zh := 1.3 * F
	for e: Array in _ears:
		var q: Vector2 = (p - (e[0] as Vector2)) / (e[1] as Vector2)
		if q.length_squared() < 1.04:
			_last_soft = 0.5
			return Vector2(zh + F * 0.28 * maxf(0.0, _prof(minf(q.length(), 1.0), 2.0)), R_EAR)
	if Geometry2D.is_point_in_polygon(p, _body):
		_last_soft = 1.0
		var dx := absf(p.x - pv._hc.x)
		var zn := -1.0
		var nw := pv._nwt
		if dx < nw:
			zn = zh - 0.3 * F + 0.9 * sqrt(nw * nw - dx * dx)
		var top := _top_y(dx) if dx > nw else pv._ynotch - pv._s * 0.01
		var zt := -1.0
		if p.y >= top:
			var sw := pv._sw * 1.12
			var across := maxf(0.0, _prof(minf(dx / sw, 1.0), 2.4))
			var roll := sqrt(maxf(0.0, 1.0 - pow(1.0 - minf((p.y - top) / (pv._s * 0.07), 1.0), 2.0)))
			zt = zh - 0.75 * F + 1.05 * F * across * lerpf(0.55, 1.0, roll)
		if zn >= zt:
			return Vector2(maxf(zn, 0.0), R_NECK)
		return Vector2(zt, R_CLOTH)
	return Vector2(0.0, R_NONE)


## Cobertura da barba em (u, v), lida da malha da barba que o retrato já desenhou.
func _beard_cov(u: float, v: float) -> float:
	var g := _pv._beard_grid
	var bd: Array = _pv._beard_data
	if g.size() < 6 or bd.size() < 3:
		return 0.0
	var nu := int(g[4])
	var nv := int(g[5])
	var x := (u - g[0]) / (g[1] - g[0]) * nu
	var y := (v - g[2]) / (g[3] - g[2]) * nv
	if x < 0.0 or y < 0.0 or x > nu or y > nv:
		return 0.0
	var i := mini(int(x), nu - 1)
	var j := mini(int(y), nv - 1)
	var fx := x - i
	var fy := y - j
	var cols: PackedColorArray = bd[2]
	var row := nu + 1
	var a := lerpf(lerpf(cols[j * row + i].a, cols[j * row + i + 1].a, fx), lerpf(cols[(j + 1) * row + i].a, cols[(j + 1) * row + i + 1].a, fx), fy)
	return clampf(a * 1.6, 0.0, 1.0)


## Frente da barba: nasce na frente do queixo e da mandíbula (a barba comprida não fica na sombra
## do queixo) e recua aos poucos para baixo, sobre o pescoço.
func _beard_plane(cov: float, v: float) -> float:
	var F := _pv._fw
	var front := 0.12 + 3.0 * _beard_ln
	var drop := 0.5 * smoothstep(0.9, 1.45 + _beard_ln, v)
	return 1.3 * F + F * maxf(0.1, front - drop) * cov


static func _smax(a: float, b: float, k: float) -> float:
	var h := maxf(k - absf(a - b), 0.0) / k
	return maxf(a, b) + h * h * k * 0.25


func _in_hair(p: Vector2) -> bool:
	if not _cap.is_empty() and Geometry2D.is_point_in_polygon(p, _cap):
		return true
	for b: PackedVector2Array in _back:
		if Geometry2D.is_point_in_polygon(p, b):
			return true
	return false


## Altura do volume do cabelo: uma cúpula só sobre o contorno de todo o cabelo. Da linha dos
## olhos para baixo o cabelo que cai ao lado do rosto fica atrás dele (no plano das laterais da
## cabeça), não na frente: senão o rosto parece afundado dentro do cabelo.
func _hair_z(p: Vector2) -> float:
	var F := _pv._fw
	var rr := _star(_pv._hc, _hair_r, p)
	var v := (p.y - _pv._hc.y) / _pv._fh
	var dome := (DEPTH + 0.1) * maxf(0.0, _prof(minf(rr, 1.0), 2.0))
	var side := 0.25 * maxf(0.0, _prof(minf(rr, 1.0), 2.0))
	return 1.3 * F + F * lerpf(dome, side, smoothstep(_E - 0.15, _E + 0.25, v))


func _run(masks: Array, beard: Array, back: Array) -> void:
	var pv := _pv
	var tk := Time.get_ticks_usec()
	var shapes := _parts(back)
	tk = _tick("partes", tk)
	if shapes.is_empty():
		return
	var F := pv._fw
	# Uns 60 pontos por lado no retrato grande e 42 no médio: a luz é suave, e o custo cresce com
	# o quadrado disso
	var r := pv._rect if pv._fm else Rect2(pv._c - Vector2(pv._R, pv._R), Vector2(pv._R, pv._R) * 2.0)
	_st = maxf(r.size.x / (60.0 if pv._s >= 300.0 else 42.0), 2.2)
	var m := 3
	_o = r.position - Vector2(m, m) * _st
	_nx = ceili(r.size.x / _st) + 2 * m + 2
	_ny = ceili(r.size.y / _st) + 2 * m + 2
	var n := _nx * _ny
	_h.resize(n)
	_reg.resize(n)
	_edge.resize(n)
	_soft.resize(n)
	for j in _ny:
		for i in _nx:
			var s := _sample(_o + Vector2(i, j) * _st)
			_h[j * _nx + i] = s.x
			_reg[j * _nx + i] = int(s.y)
			_edge[j * _nx + i] = _last_d
			_soft[j * _nx + i] = _last_soft
	tk = _tick("alturas", tk)
	var hb := _blur(_h, maxi(1, int(round(0.1 * F / _st))))
	# Oclusão do rosto só com o relevo do próprio rosto: o cabelo em volta não cava um sulco na
	# borda da testa e das bochechas
	var hface := PackedFloat32Array(_h)
	for k in n:
		if _reg[k] != R_FACE:
			hface[k] = 1.3 * F + F * DEPTH * _edge[k]
	var hbf := _blur(hface, maxi(1, int(round(0.1 * F / _st))))
	# Altura suavizada: cabelo, barba e corpo são macios, e as emendas entre as partes somem
	var hs := _blur(_h, maxi(1, int(round(0.06 * F / _st))))
	tk = _tick("desfoques", tk)
	_lit.resize(n)
	_lum.resize(n)
	_rim.resize(n)
	_spc.resize(n)
	_lit.fill(1.0)
	_lum.fill(1.0)
	_rim.fill(0.0)
	_spc.fill(0.0)
	var L := LIGHT.normalized()
	var Hv := (L + Vector3(0, 0, 1)).normalized()
	var dir := Vector2(L.x, L.y).normalized()
	var rise := L.z / Vector2(L.x, L.y).length()
	_front = 0.5 + 0.55 * clampf((L.z + WRAP) / (1.0 + WRAP), 0.0, 1.0)
	var steps := 10 if pv._s >= 200.0 else 7
	var hairm := PackedFloat32Array()
	hairm.resize(n)
	for k in n:
		hairm[k] = 1.0 if _reg[k] == R_HAIR else 0.0
	var reach := 1.6 * F
	for j in range(1, _ny - 1):
		for i in range(1, _nx - 1):
			var id := j * _nx + i
			var rg := _reg[id]
			if rg == R_NONE:
				continue
			# Normal só com vizinhos da mesma parte (entre partes a altura dá um degrau)
			var hx := 0.0
			var hy := 0.0
			var l := _reg[id - 1] == rg
			var rr := _reg[id + 1] == rg
			if l and rr:
				hx = (_h[id + 1] - _h[id - 1]) / (2.0 * _st)
			elif rr:
				hx = (_h[id + 1] - _h[id]) / _st
			elif l:
				hx = (_h[id] - _h[id - 1]) / _st
			var up := _reg[id - _nx] == rg
			var dn := _reg[id + _nx] == rg
			if up and dn:
				hy = (_h[id + _nx] - _h[id - _nx]) / (2.0 * _st)
			elif dn:
				hy = (_h[id + _nx] - _h[id]) / _st
			elif up:
				hy = (_h[id] - _h[id - _nx]) / _st
			var g := Vector2(hx, hy)
			var wsoft := _soft[id]
			if wsoft > 0.0:
				var gs := Vector2(hs[id + 1] - hs[id - 1], hs[id + _nx] - hs[id - _nx]) / (2.0 * _st)
				g = g.lerp(gs, wsoft)
			if g.length_squared() > 9.0:
				g = g.normalized() * 3.0
			var nrm := Vector3(-g.x, -g.y, 1.0).normalized()
			var ndl := nrm.dot(L)
			var diff := clampf((ndl + WRAP) / (1.0 + WRAP), 0.0, 1.0)
			var h0 := _h[id]
			var p := _o + Vector2(i, j) * _st
			var sh := 0.0
			if ndl > -WRAP:
				var lit := 1.0
				for s in steps:
					var t := reach * (0.02 + 0.98 * pow(float(s + 1) / steps, 1.6))
					var q := p + dir * t
					var hq := _at(_h, q)
					var occ := 1.0 - clampf((h0 + rise * t + 0.01 * F - hq) / (PENUMBRA * t) + 0.5, 0.0, 1.0)
					# Cabelo e barba deixam passar parte da luz entre os fios
					if rg != R_HAIR and occ > 0.0:
						occ *= 1.0 - 0.65 * _at(hairm, q)
					lit = minf(lit, 1.0 - occ)
					if lit <= 0.0:
						break
				sh = 1.0 - clampf(lit, 0.0, 1.0)
			var ao := clampf(((hbf[id] if rg == R_FACE else hb[id]) - h0) / F * 4.0, 0.0, 0.4)
			# Rebatedor embaixo: a camisa devolve luz para o queixo e a base do nariz
			var fill := (0.12 if rg == R_FACE else (0.1 if rg == R_HAIR else 0.05)) * maxf(0.0, nrm.y)
			_lit[id] = 0.5 + 0.55 * diff + fill
			_lum[id] = (0.5 + 0.55 * diff * (1.0 - 0.8 * sh)) * (1.0 - ao) + fill
			# Recorte: luz fria de trás à direita na borda que vira para longe
			_rim[id] = float(RIM[rg]) * pow(1.0 - nrm.z, 1.5) * clampf(nrm.x * 0.9 - nrm.y * 0.3, 0.0, 1.0) * (1.0 - ao)
			if rg == R_FACE:
				var u := (p.x - pv._hc.x) / F
				var v := (p.y - pv._hc.y) / pv._fh
				_spc[id] = pow(maxf(0.0, nrm.dot(Hv)), 24.0) * (1.0 - sh) * (1.0 - ao) * _oil(u, v)
	tk = _tick("luz", tk)
	_smooth_mult()
	_colors()
	tk = _tick("suavizar", tk)
	_draw_layers(shapes)
	tk = _tick("camadas", tk)
	if debug == 0:
		_draw_features(masks, beard)
	tk = _tick("peças", tk)


func _colors() -> void:
	var pv := _pv
	var skin: Color = pv._skin
	var dark_k := clampf(float(pv._f["skin_i"]) / 9.0, 0.0, 1.0)
	_spec_k = 0.14 + 0.14 * dark_k
	# Pele: sombra quente (perto do terminador puxa para o vermelho, no fundo é um marrom do
	# próprio tom). Cabelo: quase preto. Roupa: escuro frio, que serve para qualquer cor de camisa.
	# Pele escura: a sombra não vai ao preto (os traços sumiam no rosto todo escuro)
	var s_deep := PortraitView._shade(skin, lerpf(0.1, 0.32, dark_k))
	var s_warm := PortraitView._shade(skin, lerpf(0.55, 0.7, dark_k)).lerp(Color(0.62, 0.14, 0.1), 0.3 - 0.12 * dark_k)
	var s_lift := PortraitView._shade(skin, 1.3).lerp(Color(1.0, 0.95, 0.88), 0.2)
	var hc0: Color = pv._f["hair"]
	# Sombra do cabelo no tom do próprio cabelo (o preto neutro deixava a borda cinzenta)
	var h_deep := Color(hc0.r * 0.28, hc0.g * 0.26, hc0.b * 0.24)
	var hc: Color = pv._f["hair"]
	var h_lift := Color(minf(1.0, hc.r * 1.7 + 0.08), minf(1.0, hc.g * 1.7 + 0.06), minf(1.0, hc.b * 1.7 + 0.04))
	var c_deep := Color(0.02, 0.03, 0.06)
	_deep = [s_deep, s_deep, h_deep, s_deep, s_deep, c_deep, h_deep]
	_warm = [s_warm, s_warm, h_deep, s_warm, s_warm, c_deep, h_deep]
	_lift = [s_lift, s_lift, h_lift, s_lift, s_lift, Color(1, 1, 1), h_lift]


func _region_at(q: Vector2) -> int:
	var i := clampi(int(round((q.x - _o.x) / _st)), 0, _nx - 1)
	var j := clampi(int(round((q.y - _o.y) / _st)), 0, _ny - 1)
	var rg := _reg[j * _nx + i]
	if rg == R_NONE:
		# Borda: a parte do vizinho que estiver dentro
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var k := clampi(j + d.y, 0, _ny - 1) * _nx + clampi(i + d.x, 0, _nx - 1)
			if _reg[k] != R_NONE:
				return _reg[k]
	return rg


var _mul := PackedFloat32Array()


## Quanto a luz muda a cor já desenhada em cada ponto da grade (< 1 escurece, > 1 clareia),
## suavizado dentro da silhueta: entre duas partes (rosto e cabelo, queixo e pescoço) a luz muda
## aos poucos, sem a escadinha da grade.
func _smooth_mult() -> void:
	var n := _nx * _ny
	var mul := PackedFloat32Array()
	var w := PackedFloat32Array()
	mul.resize(n)
	w.resize(n)
	for id in n:
		var rg := _reg[id]
		if rg == R_NONE:
			mul[id] = 0.0
			w[id] = 0.0
			continue
		var lit := maxf(_lit[id], 0.05)
		var fk := float(FORM[rg])
		if rg == R_FACE:
			# Na borda do rosto a pele já vira para a sombra no desenho: sem dobrar a conta
			fk *= lerpf(0.25, 1.0, smoothstep(0.0, 0.35, _edge[id]))
		mul[id] = (1.0 + fk * (lit / _front - 1.0)) * _lum[id] / lit
		w[id] = 1.0
	var r := maxi(1, int(round(0.03 * _pv._fw / _st)))
	var bm := _blur(mul, r)
	var bw := _blur(w, r)
	_mul.resize(n)
	for id in n:
		_mul[id] = bm[id] / bw[id] if bw[id] > 0.001 else 1.0


func _mult(q: Vector2, _rg: int) -> float:
	return _at(_mul, q)


func _dark(rg: int, a: float) -> Color:
	var c: Color = (_warm[rg] as Color).lerp(_deep[rg], smoothstep(0.2, 0.8, a))
	return Color(c, a)


## Cores das camadas em cada ponto da grade (sombra, luz e recorte + brilho), uma vez só.
func _node_colors() -> Array:
	var n := _nx * _ny
	var cd := PackedColorArray()
	var cl := PackedColorArray()
	var cr := PackedColorArray()
	cd.resize(n)
	cl.resize(n)
	cr.resize(n)
	var rim_c := Color(0.8, 0.88, 1.0)
	var spec_c := Color(1.0, 0.98, 0.95)
	for j in _ny:
		for i in _nx:
			var id := j * _nx + i
			var rg := _reg[id]
			if rg == R_NONE:
				# Fora do busto: a cor da parte vizinha (para a borda interpolar sem clarear)
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var k := clampi(j + d.y, 0, _ny - 1) * _nx + clampi(i + d.x, 0, _nx - 1)
					if _reg[k] != R_NONE:
						rg = _reg[k]
						break
				rg = maxi(rg, R_FACE)
			var mm := _mul[id]
			if debug == 1:
				var gv := clampf(mm * 0.6, 0.0, 1.0)
				cd[id] = Color(gv, gv, gv, 1.0)
				continue
			if debug == 2:
				cd[id] = [Color.BLACK, Color(0.9, 0.6, 0.5), Color(0.3, 0.2, 0.1), Color(0.9, 0.3, 0.6), Color(0.6, 0.4, 0.3), Color(0.2, 0.4, 0.9), Color(0.5, 0.5, 0.1)][rg]
				continue
			cd[id] = _dark(rg, clampf((1.0 - mm) * 1.25, 0.0, 0.85))
			cl[id] = Color(_lift[rg], clampf((mm - 1.0) * 1.6, 0.0, 0.15 if rg == R_HAIR or rg == R_BACK else 0.3))
			var sp := clampf(_spc[id] * _spec_k, 0.0, 0.5) if rg == R_FACE else 0.0
			var rm := clampf(_rim[id], 0.0, 0.5)
			cr[id] = Color(spec_c.lerp(rim_c, rm / maxf(rm + sp, 0.001)), rm + sp)
	return [cd, cl, cr]


func _col_at(arr: PackedColorArray, q: Vector2) -> Color:
	var x := (q.x - _o.x) / _st
	var y := (q.y - _o.y) / _st
	var i := clampi(int(floor(x)), 0, _nx - 2)
	var j := clampi(int(floor(y)), 0, _ny - 2)
	var fx := clampf(x - i, 0.0, 1.0)
	var fy := clampf(y - j, 0.0, 1.0)
	var b := j * _nx + i
	return arr[b].lerp(arr[b + 1], fx).lerp(arr[b + _nx].lerp(arr[b + _nx + 1], fx), fy)


## Malha das camadas direto da grade: as células inteiras dentro do busto usam os pontos da
## grade (vértices compartilhados, cores já prontas); só as da borda são recortadas no contorno.
func _draw_layers(shapes: Array) -> void:
	var pv := _pv
	var nc := _node_colors()
	var ncd: PackedColorArray = nc[0]
	var ncl: PackedColorArray = nc[1]
	var ncr: PackedColorArray = nc[2]
	var n := _nx * _ny
	var inside := PackedByteArray()
	inside.resize(n)
	for j in _ny:
		for i in _nx:
			var p := _o + Vector2(i, j) * _st
			var k := 0
			for sh: PackedVector2Array in shapes:
				if Geometry2D.is_point_in_polygon(p, sh):
					k = 1
					break
			inside[j * _nx + i] = k
	var vid := PackedInt32Array()
	vid.resize(n)
	vid.fill(-1)
	var pts := PackedVector2Array()
	var cd := PackedColorArray()
	var cl := PackedColorArray()
	var cr := PackedColorArray()
	var idx := PackedInt32Array()
	for j in _ny - 1:
		for i in _nx - 1:
			var a := j * _nx + i
			var c4 := [a, a + 1, a + _nx + 1, a + _nx]
			var cnt := inside[a] + inside[a + 1] + inside[a + _nx] + inside[a + _nx + 1]
			if cnt == 0:
				continue
			if cnt == 4:
				for k in c4:
					if vid[k] < 0:
						vid[k] = pts.size()
						pts.append(_o + Vector2(k % _nx, k / _nx) * _st)
						cd.append(ncd[k])
						cl.append(ncl[k])
						cr.append(ncr[k])
				idx.append_array([vid[c4[0]], vid[c4[1]], vid[c4[2]], vid[c4[0]], vid[c4[2]], vid[c4[3]]])
				continue
			# Borda: recorta a célula no contorno do busto
			var x0 := _o.x + i * _st
			var y0 := _o.y + j * _st
			var cell := PackedVector2Array([Vector2(x0, y0), Vector2(x0 + _st, y0), Vector2(x0 + _st, y0 + _st), Vector2(x0, y0 + _st)])
			for sh: PackedVector2Array in shapes:
				for piece: PackedVector2Array in Geometry2D.intersect_polygons(cell, sh):
					if piece.size() < 3:
						continue
					var tri := Geometry2D.triangulate_polygon(piece)
					var base := pts.size()
					for q in piece:
						pts.append(q)
						cd.append(_col_at(ncd, q))
						cl.append(_col_at(ncl, q))
						cr.append(_col_at(ncr, q))
					for t in tri:
						idx.append(base + t)
	if idx.is_empty():
		return
	for k in pts.size():
		pts[k] = pv._cl(pts[k])
	pv._r_tri(idx, pts, cd)
	if debug == 0:
		pv._r_tri(idx, pts, cl)
		pv._r_tri(idx, pts, cr)
	# Borda antisserrilhada da sombra (o GLES3 não faz MSAA em 2D)
	for sh: PackedVector2Array in shapes:
		var line := PackedVector2Array(sh)
		line.append(sh[0])
		var lc := PackedColorArray()
		for q in line:
			var c := _col_at(ncd, q)
			lc.append(Color(c, c.a * 0.8))
		pv._r_polyline_colors(line, lc, maxf(1.0, pv._s * 0.003), true)


## Olhos, lábios e barba ganham a forma inteira do rosto (a pele já tem a dela desenhada).
func _draw_features(masks: Array, beard: Array) -> void:
	var pv := _pv
	var k := 1.0 - float(FORM[R_FACE])
	for poly: PackedVector2Array in masks:
		if poly.size() < 3:
			continue
		var mm := KitGeom.grid_mesh(poly, _st * 0.7)
		var mp: PackedVector2Array = mm[0]
		if mp.is_empty():
			continue
		var md := PackedColorArray()
		var ml := PackedColorArray()
		for q in mp:
			var v := k * (_at(_lit, q) / _front - 1.0)
			md.append(_dark(R_FACE, clampf(-v * 1.1, 0.0, 0.45)))
			ml.append(Color(_lift[R_FACE], clampf(v, 0.0, 0.15)))
		pv._r_tri(mm[1], mp, md)
		pv._r_tri(mm[1], mp, ml)
	if beard.size() >= 3 and not (beard[0] as PackedInt32Array).is_empty():
		var bp: PackedVector2Array = beard[1]
		var bc: PackedColorArray = beard[2]
		var bd := PackedColorArray()
		bd.resize(bp.size())
		for i in bp.size():
			var cov := clampf(bc[i].a * 1.4, 0.0, 1.0)
			var v := k * (_at(_lit, bp[i]) / _front - 1.0)
			var d := _dark(R_HAIR, clampf(-v * 1.1, 0.0, 0.5))
			bd[i] = Color(d, d.a * cov)
		pv._r_tri(beard[0], bp, bd)
