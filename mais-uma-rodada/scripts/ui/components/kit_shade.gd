class_name KitShade
extends RefCounted
## Luz e sombra dos uniformes, pintadas por vértice numa malha que cobre cada peça (KitGeom).
## A luz vem do alto à esquerda, um pouco de frente. Cada peça tem a sua forma de corpo:
## - tronco: um cilindro achatado com peito, ombros que viram para cima e a barra que entra;
## - manga, perna, meião: cilindros ao longo do eixo do membro;
## mais oclusão onde as peças se encostam (axila, gancho, sob a camisa) e dobras de tecido
## (uma crista que pega luz ao lado de um vale na sombra). O resultado são duas camadas por peça,
## uma escura e uma clara, desenhadas por cima do tecido, da estampa e das marcas: tudo fica
## no mesmo pano. Calculado uma vez por peça e por classe de cor do tecido (cache estático).

const LIGHT := Vector3(-0.42, -0.5, 0.757)

## Força da sombra e da luz por classe de tecido (muito escuro, escuro, médio, claro).
const SHADOW := [0.62, 0.66, 0.68, 0.5]
const HILITE := [0.30, 0.24, 0.17, 0.08]

static var _cache: Dictionary = {}


## Classe de cor do tecido: 0 muito escuro, 1 escuro, 2 médio, 3 claro.
static func lum_class(c: Color) -> int:
	var l := c.get_luminance()
	if l < 0.1:
		return 0
	if l < 0.3:
		return 1
	if l < 0.62:
		return 2
	return 3


## [malha, cores da sombra, cores da luz] de uma peça. `key` identifica a peça (e a classe de
## cor), `poly` é o contorno em coordenadas unitárias, `kind` o modelo de luz e `prm` os dados dele.
static func layers(key: String, poly: Array, kind: String, prm: Dictionary, cls: int, step: float = 0.018) -> Array:
	var ck := "%s|%d" % [key, cls]
	if _cache.has(ck):
		return _cache[ck]
	# Malha e valor da luz em cada vértice: uma vez por peça (a classe de cor só muda a força).
	var vk := "v|" + key
	if not _cache.has(vk):
		var mesh := KitGeom.grid_mesh(PackedVector2Array(poly), step)
		var pts: PackedVector2Array = mesh[0]
		var vals := PackedFloat32Array()
		vals.resize(pts.size())
		var seen := {}
		for i in pts.size():
			var p := pts[i]
			if seen.has(p):
				vals[i] = seen[p]
			else:
				var v := value(kind, p, prm)
				seen[p] = v
				vals[i] = v
		_cache[vk] = [mesh, vals]
	var base: Array = _cache[vk]
	var vals2: PackedFloat32Array = base[1]
	var dark := PackedColorArray()
	var lit := PackedColorArray()
	dark.resize(vals2.size())
	lit.resize(vals2.size())
	var sk: float = SHADOW[cls]
	var hk: float = HILITE[cls]
	# Branco e tecidos claros: a sombra puxa para um cinza frio, como numa camisa branca de verdade.
	var sc := Color(0.06, 0.08, 0.14) if cls == 3 else Color(0, 0, 0)
	for i in vals2.size():
		var v := vals2[i]
		dark[i] = Color(sc, clampf(-v, 0.0, 1.0) * sk)
		lit[i] = Color(1, 1, 1, clampf(v, 0.0, 1.0) * hk)
	var out := [base[0], dark, lit]
	_cache[ck] = out
	return out


static func draw(ci: CanvasItem, lay: Array) -> void:
	KitGeom.draw_mesh(ci, lay[0], lay[1])
	KitGeom.draw_mesh(ci, lay[0], lay[2])


static func value(kind: String, p: Vector2, prm: Dictionary) -> float:
	match kind:
		"torso":
			return _torso(p, prm)
		"sleeve":
			return _limb(p, prm)
		"limb":
			return _limb(p, prm)
		"shorts":
			return _shorts(p, prm)
	return 0.0


static func _gauss(x: float, m: float, s: float) -> float:
	var d := (x - m) / s
	return exp(-0.5 * d * d)


static func _lambert(n: Vector3) -> float:
	return n.normalized().dot(LIGHT.normalized())


## Dobra de tecido ao longo de um caminho: crista clara de um lado, vale escuro do outro, sumindo
## nas pontas. [caminho (PackedVector2Array), largura, intensidade].
static func _folds(p: Vector2, folds: Array) -> float:
	var v := 0.0
	for f: Array in folds:
		var path: PackedVector2Array = f[0]
		var w: float = f[1]
		var bb: Rect2 = f[3]
		if not bb.grow(w * 2.5).has_point(p):
			continue
		var r := KitGeom.sd_path(p, path)
		var d := r.x / w
		if absf(d) > 3.0:
			continue
		var fade := pow(sin(PI * clampf(r.y, 0.0, 1.0)), 0.7)
		v += float(f[2]) * d * exp(0.5 - 0.5 * d * d) * fade
	return v


## Dobras prontas para _folds: suaviza o caminho e guarda a caixa dele.
static func folds(defs: Array, mirror: bool = false) -> Array:
	var out: Array = []
	for f: Array in defs:
		for m in ([false, true] if mirror else [false]):
			var pts: Array = []
			for q: Vector2 in f[0]:
				pts.append(Vector2(1.0 - q.x, q.y) if m else q)
			var path := KitGeom.smooth(pts, 6)
			out.append([path, f[1], float(f[2]) * (-1.0 if m else 1.0), KitGeom.bounds(path)])
	return out


## Tronco da camisa. prm: hw (meia largura por altura, array de 101), folds.
static func _torso(p: Vector2, prm: Dictionary) -> float:
	var hws: Array = prm["hw"]
	var hw: float = maxf(0.05, float(hws[clampi(int(p.y * 100.0), 0, 100)]))
	var u := clampf((p.x - 0.5) / hw, -1.0, 1.0)
	var nx := u * 0.86
	var ny := 0.0
	# Ombros e alto do peito viram para cima (pegam a luz de cima)
	ny -= 0.42 * (1.0 - smoothstep(0.06, 0.24, p.y)) * (0.35 + 0.65 * absf(u))
	# Peitoral: luz em cima, sombra embaixo dele; barriga reta; barra entrando
	ny -= 0.08 * _gauss(p.y, 0.29, 0.045) * (1.0 - absf(u) * 0.6)
	ny += 0.1 * _gauss(p.y, 0.405, 0.03) * (1.0 - absf(u) * 0.7) * smoothstep(0.05, 0.22, absf(p.x - 0.5))
	ny += 0.16 * smoothstep(0.84, 0.95, p.y)
	var nz := sqrt(maxf(0.04, 1.0 - nx * nx - ny * ny))
	var v := (_lambert(Vector3(nx, ny, nz)) - 0.76) * 1.7
	# Brilho largo do poliéster no peito do lado da luz
	v += 0.22 * exp(-((p - Vector2(0.415, 0.25)).length_squared()) / 0.012)
	# Laterais girando para longe (oclusão do cilindro)
	v -= 0.3 * smoothstep(0.72, 1.0, absf(u))
	# Axilas e cava: o braço tapa a luz
	for ap: Vector2 in prm.get("pits", []):
		v -= 0.55 * exp(-(p - ap).length_squared() / 0.0022)
	# Sombra da gola no peito, logo abaixo do decote
	var nd := absf(p.x - 0.5)
	if nd < 0.16:
		v -= 0.22 * _gauss(p.y, 0.1 + 0.07 * (1.0 - nd / 0.16), 0.022) * (1.0 - nd / 0.16)
	v += _folds(p, prm["folds"])
	return v


## Membro ou manga: cilindro ao longo do eixo a→b, com meia largura de ha (em a) a hb (em b).
## prm: a, b, ha, hb, folds, e opcionais: cap (ombro virando para cima até essa altura),
## inner (lado do corpo: 1 ou -1; escurece por oclusão), sx (escala do x, para o uniforme completo).
static func _limb(p: Vector2, prm: Dictionary) -> float:
	var a: Vector2 = prm["a"]
	var b: Vector2 = prm["b"]
	var sx: float = prm.get("sx", 1.0)
	var pa := Vector2((p.x - a.x) * sx, p.y - a.y)
	var ab := Vector2((b.x - a.x) * sx, b.y - a.y)
	var l2 := ab.length_squared()
	var t := clampf(pa.dot(ab) / l2, 0.0, 1.0)
	var dir := ab.normalized()
	var nrm := Vector2(-dir.y, dir.x)
	var hw := lerpf(float(prm["ha"]), float(prm["hb"]), t) * sx
	var u := clampf(pa.dot(nrm) / maxf(0.005, hw), -1.0, 1.0)
	var n2 := nrm * u * 0.9
	var ny := n2.y
	var cap: float = prm.get("cap", 0.0)
	if cap > 0.0:
		ny -= 0.38 * (1.0 - smoothstep(float(prm.get("cap0", 0.08)), cap, p.y))
	var nz := sqrt(maxf(0.04, 1.0 - n2.x * n2.x - ny * ny))
	var v := (_lambert(Vector3(n2.x, ny, nz)) - 0.76) * 1.7
	v -= 0.28 * smoothstep(0.7, 1.0, absf(u))
	var inner: float = prm.get("inner", 0.0)
	if inner != 0.0:
		v -= 0.22 * smoothstep(0.2, 1.0, u * inner)
	# Volume extra (panturrilha, joelho, caneleira...): [centro, raio, intensidade]
	for bump: Array in prm.get("bumps", []):
		var c: Vector2 = bump[0]
		var r: Vector2 = bump[1]
		var dd := Vector2((p.x - c.x) / r.x, (p.y - c.y) / r.y)
		var q := dd.length_squared()
		if q < 4.0:
			# Saliência: luz no alto e à esquerda dela, sombra embaixo e à direita
			v += float(bump[2]) * (-dd.x * 0.6 - dd.y) * exp(-q)
	# Faixas horizontais de sombra ou luz: [y, largura, intensidade]
	for ln: Array in prm.get("lines", []):
		v += float(ln[2]) * _gauss(p.y, float(ln[0]), float(ln[1]))
	v += _folds(p, prm.get("folds", []))
	return v


## Calção: duas pernas (cilindros), oclusão no gancho e embaixo da camisa, barra virando.
## prm: legs [[a, b, ha, hb] x2], hem_y, folds, sx.
static func _shorts(p: Vector2, prm: Dictionary) -> float:
	var sx: float = prm.get("sx", 1.0)
	var legs: Array = prm["legs"]
	var leg: Array = legs[0] if p.x < 0.5 else legs[1]
	var v := _limb(p, {"a": leg[0], "b": leg[1], "ha": leg[2], "hb": leg[3], "sx": sx})
	# A camisa por cima faz sombra na cintura
	v -= 0.9 * (1.0 - smoothstep(float(prm["top"]), float(prm["top"]) + 0.05, p.y))
	# Gancho: as pernas se encostam
	var cr: Vector2 = prm["crotch"]
	v -= 0.5 * exp(-(pow((p.x - cr.x) * sx / 0.03, 2.0) + pow((p.y - cr.y) / 0.05, 2.0)))
	v -= 0.18 * exp(-pow((p.x - 0.5) * sx / 0.02, 2.0)) * smoothstep(0.5, 0.58, p.y)
	# Barra virada: um filete de luz logo acima da costura
	v += 0.16 * _gauss(p.y, float(prm["hem_y"]) - 0.012, 0.005)
	v += _folds(p, prm["folds"])
	return v
