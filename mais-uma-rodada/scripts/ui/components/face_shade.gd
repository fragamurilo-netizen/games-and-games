class_name FaceShade
extends RefCounted
## Luz do rosto por malha, a mesma ideia da luz dos uniformes (KitShade). O rosto vira um relevo
## (uma altura em cada ponto: crânio, testa, arco das sobrancelhas, órbitas, globo ocular, nariz
## com dorso, ponta e asas, maçãs, sulco nasolabial, boca, lábios e queixo) em vez de manchas de
## luz pintadas. Do relevo saem:
## - a luz direta pela normal, com a pele "enrolando" a luz na passagem para a sombra;
## - a sombra projetada: o nariz na bochecha e no lábio, o arco da sobrancelha no olho, o lábio
##   de baixo no queixo;
## - a oclusão dos vincos (cantos dos olhos, asas do nariz, sulco nasolabial, cantos da boca);
## - o brilho da pele oleosa (testa, dorso e ponta do nariz, maçãs, queixo, lábio de baixo).
## Tudo é pintado numa grade uniforme recortada no contorno da cabeça. As camadas (sombra, luz e
## brilho) são desenhadas por cima da pele, dos olhos, da boca e da barba, e essas peças passam a
## fazer parte do mesmo volume. Por enquanto é um teste: liga com PortraitView.mesh_light.

const LIGHT := Vector3(-0.4, -0.5, 0.77)
## Luminância da pele chapada que fica embaixo da luz (a do rosto de frente no modelo antigo).
const BASE := 0.97
## Profundidade da cabeça (em meias larguras do rosto) e expoente do perfil: a frente do rosto é
## mais plana que uma esfera e vira rápido nas laterais.
const DEPTH := 1.1
const PROFILE := 2.4
const SKULL_N := 2.35
## Quanto a luz "enrola" além do terminador (espalhamento sob a pele).
const WRAP := 0.38
## Penumbra da sombra projetada (fonte de luz grande, como um softbox).
const PENUMBRA := 0.4
## Modo de depuração das ferramentas: 0 normal, 1 só a luz em cinza (modo relevo).
static var debug := 0
## Integrado: a pele de sempre, mais sombra projetada, oclusão, brilho e as peças (olhos, lábios,
## sobrancelhas, barba) no volume do rosto. Relevo: a pele vira um tom chapado e toda a luz vem
## do relevo.
const INTEGRATED := 1
const RELIEF := 2

var mode := INTEGRATED

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
# Grade em unidades do rosto (x = u, y = v * fh / fw: a mesma escala nos dois eixos)
var _o := Vector2.ZERO
var _st := 0.03
var _nx := 0
var _ny := 0
var _h := PackedFloat32Array()
var _in := PackedByteArray()
var _poly := PackedVector2Array()
# Luz por ponto da grade: direta (sem sombra projetada nem oclusão), final e brilho
var _lit := PackedFloat32Array()
var _lum := PackedFloat32Array()
var _spc := PackedFloat32Array()
var _front := 0.0
var _deep := Color.BLACK
var _warm := Color.BLACK
var _lift := Color.WHITE
var _spec_k := 0.2


## Prepara a luz por malha do retrato `pv` (com _setup feito) no modo `mode`.
static func make(pv: PortraitView, mode_: int) -> FaceShade:
	var fs := FaceShade.new()
	fs.mode = mode_
	fs._setup(pv)
	fs._prepare()
	return fs


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
	o += 0.9 * _g2(u, v - (_M + _ll * 0.45), _mw * 0.55, _ll * 0.4)
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


## Monta a grade e a luz de cada ponto (antes de desenhar o rosto: o modo relevo precisa da luz
## já na borda da pele).
func _prepare() -> void:
	var pv := _pv
	var head: PackedVector2Array = pv._head_contour(pv._contour_k())
	_poly = PackedVector2Array()
	for p in head:
		_poly.append((p - pv._hc) / pv._fw)
	# Células de ~2,4 px no retrato grande; nas miniaturas a grade fica mais grossa
	_st = clampf(2.4 / pv._fw, 0.022, 0.09)
	var bb := KitGeom.bounds(_poly)
	var m := 10
	_o = bb.position - Vector2(m, m) * _st
	_nx = ceili(bb.size.x / _st) + 2 * m + 2
	_ny = ceili(bb.size.y / _st) + 2 * m + 2
	var n := _nx * _ny
	_h.resize(n)
	_in.resize(n)
	for j in _ny:
		var v := (_o.y + j * _st) / _a
		for i in _nx:
			var u := _o.x + i * _st
			var id := j * _nx + i
			_h[id] = _height(u, v)
			_in[id] = 1 if _dome(u, v) > 0.0 else 0
	var hb := _blur(_h, maxi(1, int(round(0.07 / _st))))
	_lit.resize(n)
	_lum.resize(n)
	_spc.resize(n)
	_lit.fill(BASE)
	_lum.fill(BASE)
	_spc.fill(0.0)
	var L := LIGHT.normalized()
	var Hv := (L + Vector3(0, 0, 1)).normalized()
	var dir := Vector2(L.x, L.y).normalized()
	var rise := L.z / Vector2(L.x, L.y).length()
	_front = 0.5 + 0.55 * clampf((L.z + WRAP) / (1.0 + WRAP), 0.0, 1.0)
	var steps := 14 if pv._s >= 140.0 else 8
	var inv2 := 1.0 / (2.0 * _st)
	for j in range(1, _ny - 1):
		for i in range(1, _nx - 1):
			var id := j * _nx + i
			var hx := (_h[id + 1] - _h[id - 1]) * inv2
			var hy := (_h[id + _nx] - _h[id - _nx]) * inv2
			var g := Vector2(hx, hy)
			if g.length_squared() > 6.25:
				g = g.normalized() * 2.5
			var nrm := Vector3(-g.x, -g.y, 1.0).normalized()
			var ndl := nrm.dot(L)
			var diff := clampf((ndl + WRAP) / (1.0 + WRAP), 0.0, 1.0)
			var sh := 0.0
			var ao := 0.0
			var h0 := _h[id]
			var p := Vector2(_o.x + i * _st, _o.y + j * _st)
			if _in[id] == 1:
				if ndl > -WRAP:
					var lit := 1.0
					for s in steps:
						var t := 0.015 + 0.5 * pow(float(s + 1) / steps, 1.6)
						var hq := _at(_h, p + dir * t)
						lit = minf(lit, (h0 + rise * t + 0.004 - hq) / (PENUMBRA * t) + 0.5)
						if lit <= 0.0:
							break
					sh = 1.0 - clampf(lit, 0.0, 1.0)
				ao = clampf((hb[id] - h0) * 5.0, 0.0, 0.35)
				_spc[id] = pow(maxf(0.0, nrm.dot(Hv)), 24.0) * (1.0 - sh) * (1.0 - ao) * _oil(p.x, p.y / _a)
			# Rebatedor embaixo (a camisa e o peito devolvem luz para o queixo e a base do nariz) e
			# rebote frio na borda do lado da sombra, que separa o rosto do fundo
			var fill := 0.06 * maxf(0.0, nrm.y) + 0.05 * pow(1.0 - nrm.z, 2.0) * maxf(0.0, nrm.x)
			_lit[id] = 0.5 + 0.55 * diff + fill
			_lum[id] = (0.5 + 0.55 * diff * (1.0 - 0.6 * sh)) * (1.0 - ao) + fill
	var dark_k := clampf(float(pv._f["skin_i"]) / 9.0, 0.0, 1.0)
	var skin: Color = pv._skin
	# Sombra quente: perto do terminador puxa para o vermelho (sangue sob a pele), no fundo é um
	# marrom profundo do próprio tom
	_deep = PortraitView._shade(skin, 0.1)
	_warm = PortraitView._shade(skin, 0.55).lerp(Color(0.62, 0.14, 0.1), 0.3)
	_lift = PortraitView._shade(skin, 1.3).lerp(Color(1.0, 0.95, 0.88), 0.2)
	_spec_k = 0.14 + 0.14 * dark_k


func _dark(a: float) -> Color:
	return Color(_warm.lerp(_deep, smoothstep(0.2, 0.8, a)), a)


## Modo relevo: cor final de um ponto da borda (pele chapada `base` mais as camadas de luz), para a
## borda antisserrilhada do rosto.
func composite(base: Color, p: Vector2) -> Color:
	var q := (p - _pv._hc) / _pv._fw
	var v := _at(_lum, q) - BASE
	var c := base
	var ad := clampf(-v / (BASE - 0.1), 0.0, 0.95)
	var dk := _dark(ad)
	c = c.lerp(Color(dk, 1.0), dk.a)
	c = c.lerp(_lift, clampf(v / 0.4, 0.0, 0.7))
	return Color(c, base.a)


## Desenha as camadas. `masks`: contornos (em pixels) de olhos, lábios e sobrancelhas; `beard`: a
## malha da barba ([índices, pontos, cores]), que no modo integrado recebem o volume do rosto.
func paint(masks: Array, beard: Array) -> void:
	var pv := _pv
	var mesh := KitGeom.grid_mesh(_poly, _st)
	var pts: PackedVector2Array = mesh[0]
	var idx: PackedInt32Array = mesh[1]
	var px := PackedVector2Array()
	var c_dark := PackedColorArray()
	var c_lift := PackedColorArray()
	var c_spec := PackedColorArray()
	px.resize(pts.size())
	c_dark.resize(pts.size())
	c_lift.resize(pts.size())
	c_spec.resize(pts.size())
	var spec_c := Color(1.0, 0.98, 0.95)
	for i in pts.size():
		var q := pts[i]
		px[i] = pv._cl(pv._hc + q * pv._fw)
		var lum := _at(_lum, q)
		var sp := clampf(_at(_spc, q) * _spec_k, 0.0, 0.6)
		if mode == RELIEF:
			var v := lum - BASE
			if debug == 1:
				var g := clampf(lum, 0.0, 1.2) * 0.8
				c_dark[i] = Color(g, g, g, 1.0)
				c_lift[i] = Color(0, 0, 0, 0)
			else:
				c_dark[i] = _dark(clampf(-v / (BASE - 0.1), 0.0, 0.95))
				c_lift[i] = Color(_lift, clampf(v / 0.4, 0.0, 0.7))
			c_spec[i] = Color(spec_c, sp)
		else:
			# Integrado: a pele já tem a luz direta; aqui entram só a sombra projetada e a oclusão
			var r := lum / maxf(_at(_lit, q), 0.05)
			c_dark[i] = _dark(clampf((1.0 - r) * 1.12, 0.0, 0.85))
			c_lift[i] = Color(0, 0, 0, 0)
			c_spec[i] = Color(spec_c, sp)
	pv._r_tri(idx, px, c_dark)
	if mode == RELIEF:
		pv._r_tri(idx, px, c_lift)
	pv._r_tri(idx, px, c_spec)
	if mode == RELIEF:
		return
	# Integrado: olhos, lábios, sobrancelhas e barba ganham o volume que a pele já tem
	for poly: PackedVector2Array in masks:
		if poly.size() < 3:
			continue
		var pf := PackedVector2Array()
		for p in poly:
			pf.append((p - pv._hc) / pv._fw)
		var mm := KitGeom.grid_mesh(pf, _st * 0.7)
		var mp: PackedVector2Array = mm[0]
		if mp.is_empty():
			continue
		var mpx := PackedVector2Array()
		var md := PackedColorArray()
		var ml := PackedColorArray()
		for q in mp:
			mpx.append(pv._cl(pv._hc + q * pv._fw))
			var v := _at(_lit, q) / _front - 1.0
			md.append(_dark(clampf(-v * 1.1, 0.0, 0.45)))
			ml.append(Color(_lift, clampf(v * 0.8, 0.0, 0.15)))
		pv._r_tri(mm[1], mpx, md)
		pv._r_tri(mm[1], mpx, ml)
	if beard.size() >= 3 and not (beard[0] as PackedInt32Array).is_empty():
		var bp: PackedVector2Array = beard[1]
		var bc: PackedColorArray = beard[2]
		var bd := PackedColorArray()
		var bl := PackedColorArray()
		bd.resize(bp.size())
		bl.resize(bp.size())
		for i in bp.size():
			var q := (bp[i] - pv._hc) / pv._fw
			var cov := clampf(bc[i].a * 1.4, 0.0, 1.0)
			var v := _at(_lit, q) / _front - 1.0
			var d := _dark(clampf(-v * 1.2, 0.0, 0.6))
			bd[i] = Color(d, d.a * cov)
			bl[i] = Color(_lift, clampf(v, 0.0, 0.25) * cov)
		pv._r_tri(beard[0], bp, bd)
		pv._r_tri(beard[0], bp, bl)
