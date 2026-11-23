class_name Body3D
extends RefCounted
## Corpo 3D de malha contínua com esqueleto (pele presa aos ossos), montado por código a partir
## do físico do Rig2D: tronco com peitoral, costelas, cintura, glúteo e pescoço; braços com
## deltoide, bíceps e antebraço; pernas com quadríceps, joelho e panturrilha; pés, calção e cabeça
## com mandíbula. Cada parte é uma sequência de anéis (perfil anatômico) ligados em malha lisa.
##
## Pose de descanso: de pé, olhando para +X, braços e pernas para baixo, +Z é o lado esquerdo
## do corpo. Os ossos não têm pai: a vista 3D dá a cada um a posição e a orientação no mundo
## (`pose_bone`), e a dobra do cotovelo, do joelho, da cintura e do pescoço sai da mistura de
## pesos entre dois ossos.

const SEG := 14
const SEG_T := 24
const B_PELVIS := 0
const B_CHEST := 1
const B_HEAD := 2
## Por lado (0 = esquerdo, +Z; 1 = direito, -Z): osso = B_SIDE + lado * 5 + parte.
const B_SIDE := 3
const P_UARM := 0
const P_FARM := 1
const P_THIGH := 2
const P_SHIN := 3
const P_FOOT := 4
const NAMES := ["pelvis", "chest", "head", "uarm_l", "farm_l", "thigh_l", "shin_l", "foot_l", "uarm_r", "farm_r", "thigh_r", "shin_r", "foot_r"]
## Base de descanso dos membros (eixo Y do osso aponta para baixo, X para a frente) e do pé (Y
## para a frente, X para cima).
const LIMB := Basis(Vector3(1, 0, 0), Vector3(0, -1, 0), Vector3(0, 0, -1))
const FOOT := Basis(Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1))

## Perfis anatômicos (em U = tamanho da cabeça), usados também pelo boneco 2D de lado.
## Tronco: [altura a partir do quadril, meia largura, frente, trás]
const TORSO_TAB := [
	[-0.36, 0.30, 0.20, 0.22],
	[-0.22, 0.55, 0.30, 0.36],
	[-0.05, 0.68, 0.36, 0.44],
	[0.15, 0.70, 0.38, 0.44],
	[0.38, 0.66, 0.38, 0.38],
	[0.48, 0.63, 0.375, 0.36],
	[0.70, 0.575, 0.37, 0.34],
	[0.90, 0.57, 0.375, 0.34],
	[1.10, 0.60, 0.385, 0.355],
	[1.30, 0.65, 0.40, 0.38],
	[1.50, 0.72, 0.42, 0.42],
	[1.64, 0.76, 0.43, 0.44],
	[1.80, 0.80, 0.53, 0.46],
	[2.00, 0.82, 0.54, 0.48],
	[2.18, 0.82, 0.48, 0.48],
	[2.32, 0.78, 0.38, 0.46],
	[2.44, 0.56, 0.29, 0.40],
	[2.56, 0.33, 0.25, 0.32],
	[2.75, 0.27, 0.245, 0.28],
	[2.98, 0.26, 0.24, 0.27],
]
## Braço: [distância do ombro, frente (bíceps), trás (tríceps), fora, dentro]
const ARM_TAB := [
	[-0.1, 0.2, 0.2, 0.22, 0.18],
	[0.0, 0.29, 0.28, 0.32, 0.24],
	[0.14, 0.32, 0.31, 0.36, 0.25],
	[0.3, 0.3, 0.29, 0.33, 0.24],
	[0.46, 0.265, 0.27, 0.27, 0.23],
	[0.62, 0.29, 0.28, 0.24, 0.23],
	[0.85, 0.27, 0.26, 0.23, 0.22],
	[1.08, 0.22, 0.22, 0.21, 0.20],
	[1.25, 0.20, 0.21, 0.20, 0.19],
	[1.35, 0.19, 0.21, 0.20, 0.19],
	[1.46, 0.21, 0.20, 0.22, 0.20],
	[1.62, 0.22, 0.20, 0.23, 0.20],
	[1.90, 0.19, 0.18, 0.19, 0.18],
	[2.20, 0.15, 0.14, 0.155, 0.15],
	[2.45, 0.125, 0.115, 0.135, 0.13],
	[2.60, 0.115, 0.105, 0.13, 0.125],
]
## Perna: [distância do quadril, frente (quadríceps, canela), trás (posterior, panturrilha), fora, dentro]
const LEG_TAB := [
	[-0.08, 0.30, 0.32, 0.31, 0.28],
	[0.12, 0.37, 0.39, 0.38, 0.34],
	[0.45, 0.39, 0.375, 0.365, 0.34],
	[0.80, 0.365, 0.345, 0.335, 0.325],
	[1.15, 0.32, 0.30, 0.29, 0.29],
	[1.45, 0.26, 0.25, 0.24, 0.255],
	[1.68, 0.225, 0.22, 0.215, 0.225],
	[1.85, 0.215, 0.20, 0.21, 0.21],
	[2.02, 0.20, 0.205, 0.20, 0.20],
	[2.25, 0.19, 0.26, 0.225, 0.215],
	[2.50, 0.185, 0.285, 0.235, 0.22],
	[2.85, 0.165, 0.22, 0.18, 0.175],
	[3.20, 0.14, 0.155, 0.14, 0.14],
	[3.48, 0.12, 0.125, 0.125, 0.12],
	[3.62, 0.115, 0.12, 0.13, 0.125],
	[3.70, 0.11, 0.12, 0.12, 0.115],
]

var skel: Skeleton3D
var mesh_i: MeshInstance3D
var mat: StandardMaterial3D
## Posição de descanso de cada osso e comprimento de descanso (para esticar no eixo).
var rest_pos: Array = []
var rest_len: Array = []
## Meia largura dos ombros e do quadril (onde nascem braços e pernas), já na escala do lutador.
var sw := 0.66
var hw := 0.36
var H := 1.0

var _vs := PackedVector3Array()
var _cs := PackedColorArray()
var _bs := PackedInt32Array()
var _ws := PackedFloat32Array()
var _idx := PackedInt32Array()
var _uv := PackedVector2Array()
var _centers := {}
var _seams: Array = []

## Faixas da textura de músculos (ver `muscle_texture`): tronco, braço, perna e o branco.
const V_TORSO := [0.02, 0.50]
const V_ARM := [0.54, 0.72]
const V_LEG := [0.76, 0.94]
const V_WHITE := 0.98
static var _tex_cache := {}


## Pele na luz do ginásio: o tom claro perde um pouco de brilho e ganha cor, senão estoura e o
## lutador fica com cara de manequim; o tom escuro quase não muda.
static func skin_tone(c: Color) -> Color:
	return Color.from_hsv(c.h, minf(1.0, c.s * 1.2 + 0.04), c.v * lerpf(0.92, 0.78, clampf((c.v - 0.45) / 0.5, 0.0, 1.0)), c.a)


static func side_bone(side: int, part: int) -> int:
	return B_SIDE + side * 5 + part


## Monta o corpo do lutador (ou do árbitro) e põe na cena `parent`.
static func build(r: Rig2D, parent: Node) -> Body3D:
	var b := Body3D.new()
	b._make(r, parent)
	return b


func _make(r: Rig2D, parent: Node) -> void:
	H = r.height_k
	var is_ref := r.outfit == "ref"
	sw = 0.66 * r.chest_k * H
	hw = 0.36 * H
	var y_sh := (Rig2D.L_TORSO - 0.25) * H
	var y_neck := Rig2D.L_TORSO * H
	var y_head := (Rig2D.L_TORSO + Rig2D.L_NECK + Rig2D.R_HEAD) * H
	rest_pos.resize(NAMES.size())
	rest_len.resize(NAMES.size())
	rest_pos[B_PELVIS] = Vector3.ZERO
	rest_pos[B_CHEST] = Vector3(0, y_neck, 0)
	rest_pos[B_HEAD] = Vector3(0, y_head, 0)
	rest_len[B_PELVIS] = 1.0
	rest_len[B_CHEST] = 1.0
	rest_len[B_HEAD] = 1.0
	for s in 2:
		var z := 1.0 if s == 0 else -1.0
		var sh := Vector3(0, y_sh, z * sw)
		var hip := Vector3(0, 0, z * hw)
		rest_pos[side_bone(s, P_UARM)] = sh
		rest_pos[side_bone(s, P_FARM)] = sh + Vector3(0, -Rig2D.L_UARM * H, 0)
		rest_pos[side_bone(s, P_THIGH)] = hip
		rest_pos[side_bone(s, P_SHIN)] = hip + Vector3(0, -Rig2D.L_THIGH * H, 0)
		rest_pos[side_bone(s, P_FOOT)] = hip + Vector3(0, -(Rig2D.L_THIGH + Rig2D.L_SHIN) * H, 0)
		rest_len[side_bone(s, P_UARM)] = Rig2D.L_UARM * H
		rest_len[side_bone(s, P_FARM)] = Rig2D.L_FARM * H
		rest_len[side_bone(s, P_THIGH)] = Rig2D.L_THIGH * H
		rest_len[side_bone(s, P_SHIN)] = Rig2D.L_SHIN * H
		rest_len[side_bone(s, P_FOOT)] = 0.55 * H
	_torso(r, is_ref)
	_head(r)
	for s in 2:
		_arm(r, s, is_ref)
		_leg(r, s, is_ref)
		_foot(r, s, is_ref)
	# Esqueleto
	skel = Skeleton3D.new()
	for i in NAMES.size():
		skel.add_bone(NAMES[i])
		var basis := Basis.IDENTITY
		if i >= B_SIDE:
			basis = FOOT if (i - B_SIDE) % 5 == P_FOOT else LIMB
		skel.set_bone_rest(i, Transform3D(basis, rest_pos[i]))
	skel.reset_bone_poses()
	parent.add_child(skel)
	# Malha
	var ns := _normals()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = _vs
	arr[Mesh.ARRAY_NORMAL] = ns
	arr[Mesh.ARRAY_COLOR] = _cs
	arr[Mesh.ARRAY_TEX_UV] = _uv
	arr[Mesh.ARRAY_BONES] = _bs
	arr[Mesh.ARRAY_WEIGHTS] = _ws
	arr[Mesh.ARRAY_INDEX] = _idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.custom_aabb = AABB(Vector3(-8, -8, -8), Vector3(16, 16, 16))
	mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = muscle_texture(r.belly >= 0.25 or r.fem)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mat.roughness = 0.5
	mat.metallic_specular = 0.4
	mat.rim_enabled = true
	mat.rim = 0.16
	mat.rim_tint = 0.6
	mesh_i = MeshInstance3D.new()
	mesh_i.mesh = m
	mesh_i.material_override = mat
	mesh_i.extra_cull_margin = 40.0
	skel.add_child(mesh_i)
	mesh_i.skin = skel.create_skin_from_rest_transforms()
	mesh_i.skeleton = mesh_i.get_path_to(skel)
	_vs = PackedVector3Array()
	_cs = PackedColorArray()
	_bs = PackedInt32Array()
	_ws = PackedFloat32Array()
	_idx = PackedInt32Array()
	_uv = PackedVector2Array()
	_centers = {}
	_seams = []


## Põe o osso no mundo: origem, eixo do osso (`y`, de `a` para `b`), e para onde aponta a frente.
## `thick` engrossa (músculo contraído, respiração).
func pose_limb(bone: int, a: Vector3, b: Vector3, front: Vector3, thick: float = 1.0) -> void:
	var d := b - a
	var l := d.length()
	if l < 0.0001:
		return
	var y := d / l
	var x := front - y * front.dot(y)
	if x.length() < 0.001:
		x = y.cross(Vector3.BACK)
		if x.length() < 0.001:
			x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	var z := x.cross(y)
	skel.set_bone_pose_position(bone, a)
	skel.set_bone_pose_rotation(bone, Basis(x, y, z).get_rotation_quaternion())
	skel.set_bone_pose_scale(bone, Vector3(thick, l / float(rest_len[bone]), thick))


## Osso do tronco ou da cabeça: origem e base (frente, cima, lado) já ortonormal.
func pose_block(bone: int, origin: Vector3, basis: Basis, scale: Vector3 = Vector3.ONE) -> void:
	skel.set_bone_pose_position(bone, origin)
	skel.set_bone_pose_rotation(bone, basis.get_rotation_quaternion())
	skel.set_bone_pose_scale(bone, scale)


func set_visible(v: bool) -> void:
	skel.visible = v


# --- Construção da malha -----------------------------------------------------------------

## Anel de `n` + 1 vértices em volta de `c` (o último repete o primeiro, para a textura fechar): o
## ângulo 0 aponta para `ax` (frente) e 90° para `az`. rad = [frente, trás, +az, -az]; `e` < 1
## deixa o corte mais quadrado. mods = [[ângulo, largura, ganho de raio, escurecimento], ...]
## (sulcos e volumes). `v` é a linha da textura de músculos.
func _ring(n: int, c: Vector3, ax: Vector3, az: Vector3, rad: Array, e: float, col: Color, b0: int, b1: int, w1: float, mods: Array = [], v: float = V_WHITE) -> int:
	var start := _vs.size()
	for k in n + 1:
		var th := TAU * float(k % n) / float(n)
		var cx := cos(th)
		var sz := sin(th)
		var rx := float(rad[0] if cx >= 0.0 else rad[1]) * signf(cx) * pow(absf(cx), e)
		var rz := float(rad[2] if sz >= 0.0 else rad[3]) * signf(sz) * pow(absf(sz), e)
		var gain := 1.0
		var dark := 0.0
		for m: Array in mods:
			var d := angle_difference(th, float(m[0]))
			var g := exp(-(d * d) / (float(m[1]) * float(m[1])))
			gain += float(m[2]) * g
			dark += float(m[3]) * g
		_vs.append(c + (ax * rx + az * rz) * gain)
		_cs.append(col.darkened(clampf(dark, 0.0, 0.6)) if dark >= 0.0 else col.lightened(clampf(-dark, 0.0, 0.5)))
		_uv.append(Vector2(0.5 + float(k) / float(n), v))
		_bs.append_array(PackedInt32Array([b0, b1, 0, 0]))
		_ws.append_array(PackedFloat32Array([1.0 - w1, w1, 0.0, 0.0]))
	_centers[start] = c
	_seams.append([start, start + n])
	return start


func _tri(a: int, b: int, c: int, out: Vector3) -> void:
	var n := (_vs[a] - _vs[c]).cross(_vs[a] - _vs[b])
	if n.dot(out) >= 0.0:
		_idx.append_array(PackedInt32Array([a, b, c]))
	else:
		_idx.append_array(PackedInt32Array([a, c, b]))


func _bridge(a: int, b: int, n: int) -> void:
	var ca: Vector3 = _centers[a]
	var cb: Vector3 = _centers[b]
	var mid := (ca + cb) * 0.5
	for k in n:
		var i0 := a + k
		var i1 := a + k + 1
		var j0 := b + k
		var j1 := b + k + 1
		var out := (_vs[i0] + _vs[i1] + _vs[j0] + _vs[j1]) * 0.25 - mid
		_tri(i0, i1, j1, out)
		_tri(i0, j1, j0, out)


## Fecha a ponta de um tubo num vértice.
func _cap(a: int, n: int, tip: Vector3, col: Color, b0: int, b1: int = 0, w1: float = 0.0) -> void:
	var t := _vs.size()
	_vs.append(tip)
	_cs.append(col)
	_uv.append(Vector2(0.5, _uv[a].y))
	_bs.append_array(PackedInt32Array([b0, b1, 0, 0]))
	_ws.append_array(PackedFloat32Array([1.0 - w1, w1, 0.0, 0.0]))
	var c: Vector3 = _centers[a]
	var out := tip - c
	if out.length() < 0.0001:
		out = Vector3.UP
	for k in n:
		_tri(t, a + k, a + k + 1, out)


## Esfera presa a um osso (enche a dobra do cotovelo e do joelho).
func _ball(c: Vector3, rad: float, col: Color, bone: int) -> void:
	var prev := -1
	var rings := 5
	for i in range(1, rings):
		var a := PI * float(i) / float(rings)
		var st := _ring(10, c + Vector3(0, cos(a) * rad, 0), Vector3.RIGHT, Vector3.BACK, [sin(a) * rad, sin(a) * rad, sin(a) * rad, sin(a) * rad], 1.0, col, bone, bone, 0.0)
		_centers[st] = c
		if prev < 0:
			_cap(st, 10, c + Vector3(0, rad, 0), col, bone)
		else:
			_bridge(prev, st, 10)
		prev = st
	_cap(prev, 10, c - Vector3(0, rad, 0), col, bone)


## Liga uma sequência de anéis numa pele só. Cada anel é {k, c, ax, az, rad, e, b0, b1, w1, mods, v};
## `look_at` recebe o meio entre dois anéis e devolve [cor] daquele trecho (quando a cor muda de
## um trecho para o outro o anel é repetido, e a divisa da roupa fica nítida).
## Devolve [primeiro anel, último anel].
func _loft(rings: Array, n: int, look_at: Callable) -> Array:
	var prev := -1
	var first := -1
	for i in rings.size():
		var g: Dictionary = rings[i]
		var below: Array = look_at.call((float(rings[i - 1]["k"]) + float(g["k"])) * 0.5) if i > 0 else []
		var above: Array = look_at.call((float(g["k"]) + float(rings[i + 1]["k"])) * 0.5) if i < rings.size() - 1 else below
		if i > 0:
			var st := _ring(n, g["c"], g["ax"], g["az"], g["rad"], float(g["e"]), below[0], int(g["b0"]), int(g["b1"]), float(g["w1"]), g["mods"], float(g.get("v", V_WHITE)))
			_bridge(prev, st, n)
			prev = st
		if i < rings.size() - 1 and (i == 0 or not (above[0] as Color).is_equal_approx(below[0])):
			prev = _ring(n, g["c"], g["ax"], g["az"], g["rad"], float(g["e"]), above[0], int(g["b0"]), int(g["b1"]), float(g["w1"]), g["mods"], float(g.get("v", V_WHITE)))
		if first < 0:
			first = prev
	return [first, prev]


func _normals() -> PackedVector3Array:
	var ns := PackedVector3Array()
	ns.resize(_vs.size())
	for i in range(0, _idx.size(), 3):
		var a := _idx[i]
		var b := _idx[i + 1]
		var c := _idx[i + 2]
		var n := (_vs[a] - _vs[c]).cross(_vs[a] - _vs[b])
		ns[a] += n
		ns[b] += n
		ns[c] += n
	for sm: Array in _seams:
		var sum := ns[int(sm[0])] + ns[int(sm[1])]
		ns[int(sm[0])] = sum
		ns[int(sm[1])] = sum
	for i in ns.size():
		ns[i] = ns[i].normalized() if ns[i].length() > 0.000001 else Vector3.UP
	return ns


static func _lerp_row(a: Array, b: Array, t: float) -> Array:
	var o: Array = []
	for i in a.size():
		o.append(lerpf(float(a[i]), float(b[i]), t))
	return o


## Linha da tabela na altura `y` (interpola entre as duas vizinhas).
static func _row_at(tab: Array, y: float) -> Array:
	for i in range(tab.size() - 1):
		if y <= float(tab[i + 1][0]):
			var t := clampf((y - float(tab[i][0])) / maxf(0.0001, float(tab[i + 1][0]) - float(tab[i][0])), 0.0, 1.0)
			return _lerp_row(tab[i], tab[i + 1], t)
	return tab[tab.size() - 1]


func _torso(r: Rig2D, is_ref: bool) -> void:
	var ck := r.chest_k
	var dk := 0.88 + 0.12 * ck
	var bel := clampf(r.belly, 0.0, 1.2)
	var mus := clampf((r.arm_k - 0.85) / 0.5, 0.0, 1.0)
	var hipk := (0.94 + 0.06 * r.leg_k) * (1.05 if r.fem else 1.0)
	var tab := TORSO_TAB
	# Alturas dos anéis: as da tabela, mais os sulcos do abdômen e a gola do árbitro.
	var ys: Array = []
	for row: Array in tab:
		ys.append(float(row[0]))
	var lean := bel < 0.25 and not is_ref
	if lean:
		ys.append_array([0.80, 1.00, 1.20, 1.40])
	if is_ref:
		ys.append(2.5)
	ys.sort()
	var skin := skin_tone(r.skin)
	var rings: Array = []
	for y: float in ys:
		var row := torso_row(r, y)
		var w := float(row[0])
		var f := float(row[1])
		var bk := float(row[2])
		var mods: Array = []
		if y >= 0.55 and y <= 2.25 and bel < 0.5:
			mods.append([0.0, 0.15, -0.035 if y < 1.55 else -0.05, 0.09]) # linha do meio
		if y >= 0.4 and y <= 2.3:
			mods.append([PI, 0.2, -0.05, 0.09]) # espinha
		if y >= -0.3 and y <= 0.2:
			mods.append([PI, 0.16, -0.07, 0.1]) # entre os glúteos
		if y >= 1.72 and y <= 2.1:
			mods.append([0.6, 0.4, 0.07 * (0.6 + mus) + (0.06 if r.fem else 0.0), -0.04])
			mods.append([-0.6, 0.4, 0.07 * (0.6 + mus) + (0.06 if r.fem else 0.0), -0.04])
		if is_equal_approx(y, 1.64):
			mods.append([0.0, 1.05, -0.03, 0.14]) # dobra debaixo do peitoral
		if lean and (is_equal_approx(y, 0.80) or is_equal_approx(y, 1.00) or is_equal_approx(y, 1.20) or is_equal_approx(y, 1.40)):
			mods.append([0.0, 0.62, -0.034, 0.13]) # gomos
		if y >= 1.3 and y <= 2.0:
			mods.append([PI * 0.5 + 0.5, 0.35, 0.03 * mus, 0.0]) # dorsal aparecendo de frente
			mods.append([-PI * 0.5 - 0.5, 0.35, 0.03 * mus, 0.0])
		var b0 := B_PELVIS
		var b1 := B_CHEST
		var w1 := smoothstep(0.35, 1.45, y)
		if y > 2.5:
			b0 = B_CHEST
			b1 = B_HEAD
			w1 = smoothstep(2.6, 2.95, y)
		rings.append({"k": y, "c": Vector3(0, y * H, 0), "ax": Vector3.RIGHT, "az": Vector3.BACK, "rad": [f * H, bk * H, w * H, w * H],
			"e": 0.86, "b0": b0, "b1": b1, "w1": w1, "mods": mods,
			"v": V_WHITE if is_ref or y > 2.6 else lerpf(V_TORSO[0], V_TORSO[1], (y + 0.47) / 3.47)})
	# Roupa por faixa de altura: calção, cós, camisa do árbitro, top das mulheres.
	var cos_col := r.shirt.lightened(0.1) if is_ref else r.trim
	var top_col := r.shorts.darkened(0.15)
	var look := func(y: float) -> Array:
		if y <= 0.38:
			return [r.shorts]
		if y <= 0.48:
			return [cos_col]
		if is_ref and y <= 2.5:
			return [r.shirt]
		if r.fem and not is_ref and y >= 1.5 and y <= 2.18:
			return [top_col]
		return [skin]
	var ends := _loft(rings, SEG_T, look)
	_cap(ends[0], SEG_T, Vector3(0, -0.47 * H, 0), r.shorts, B_PELVIS)
	_cap(ends[1], SEG_T, Vector3(0, 3.02 * H, 0), skin, B_HEAD)


## Meia largura, frente e trás do tronco na altura `y` (em U), já com o físico do lutador:
## peito e ombros pelo tórax, cintura pela barriga, quadril pelas pernas.
static func torso_row(r: Rig2D, y: float) -> Array:
	var row := _row_at(TORSO_TAB, y)
	var ck := r.chest_k
	var dk := 0.88 + 0.12 * ck
	var bel := clampf(r.belly, 0.0, 1.2)
	var hipk := (0.94 + 0.06 * r.leg_k) * (1.05 if r.fem else 1.0)
	var w := float(row[1])
	var f := float(row[2])
	var bk := float(row[3])
	var chest_t := smoothstep(0.9, 1.6, y) * (1.0 - smoothstep(2.4, 2.6, y))
	var waist_t := smoothstep(0.2, 0.7, y) * (1.0 - smoothstep(1.0, 1.6, y))
	var hip_t := 1.0 - smoothstep(0.3, 0.7, y)
	w *= lerpf(1.0, ck, chest_t) * lerpf(1.0, hipk, hip_t) * (1.0 + 0.16 * bel * waist_t)
	f *= lerpf(1.0, dk, chest_t) * (1.0 + 0.55 * bel * waist_t) * (1.0 + 0.2 * bel * smoothstep(1.0, 1.4, y) * (1.0 - smoothstep(1.4, 1.8, y)))
	bk *= lerpf(1.0, dk, chest_t) * (1.0 + 0.1 * bel * waist_t)
	if y > 2.5:
		w *= 0.86 + 0.14 * ck
		bk *= 0.86 + 0.14 * ck
	return [w, f, bk]


## Escala de grossura do braço e da perna pelo físico (a mesma no 2D e no 3D).
static func arm_scale(r: Rig2D) -> float:
	return 1.1 + 0.5 * (r.arm_k - 0.85)


static func leg_scale(r: Rig2D) -> float:
	return 0.97 + 0.5 * (r.leg_k - 0.9)


func _head(r: Rig2D) -> void:
	var c := Vector3(0, (Rig2D.L_TORSO + Rig2D.L_NECK + Rig2D.R_HEAD) * H, 0)
	var jaw := 0.36 if not r.fem else 0.32
	# [altura, lado, frente, trás]
	var tab := [
		[0.52, 0.20, 0.20, 0.22],
		[0.42, 0.33, 0.33, 0.37],
		[0.28, 0.41, 0.42, 0.46],
		[0.12, 0.44, 0.455, 0.49],
		[-0.02, 0.445, 0.46, 0.49],
		[-0.15, 0.44, 0.455, 0.46],
		[-0.28, 0.40, 0.45, 0.40],
		[-0.40, jaw, 0.43, 0.31],
		[-0.50, jaw - 0.09, 0.39, 0.20],
		[-0.56, 0.15, 0.32, 0.10],
	]
	var prev := -1
	for row: Array in tab:
		var y := float(row[0])
		var st := _ring(16, c + Vector3(0, y * H, 0), Vector3.RIGHT, Vector3.BACK, [float(row[2]) * H, float(row[3]) * H, float(row[1]) * H, float(row[1]) * H], 0.92, skin_tone(r.skin), B_HEAD, B_HEAD, 0.0)
		if prev < 0:
			_cap(st, 16, c + Vector3(0, 0.57 * H, 0), skin_tone(r.skin), B_HEAD)
		else:
			_bridge(prev, st, 16)
		prev = st
	_cap(prev, 16, c + Vector3(0.1 * H, -0.6 * H, 0), skin_tone(r.skin), B_HEAD)


func _arm(r: Rig2D, s: int, is_ref: bool) -> void:
	var z := 1.0 if s == 0 else -1.0
	var sh: Vector3 = rest_pos[side_bone(s, P_UARM)]
	var ak := arm_scale(r) * H
	var mus := clampf((r.arm_k - 0.85) / 0.5, 0.0, 1.0)
	var bu := side_bone(s, P_UARM)
	var bf := side_bone(s, P_FARM)
	var le := Rig2D.L_UARM
	var tab: Array = ARM_TAB.duplicate(true)
	tab[5][1] = float(tab[5][1]) + 0.02 * mus
	tab[5][2] = float(tab[5][2]) + 0.02 * mus
	if is_ref:
		tab.append_array([[2.72, 0.075, 0.075, 0.115, 0.1], [2.9, 0.07, 0.07, 0.11, 0.095], [3.02, 0.045, 0.045, 0.075, 0.065]])
	var latex := Color("#8DB6DA")
	var rings: Array = []
	for row: Array in tab:
		var t := float(row[0])
		var mods: Array = []
		if t > 0.3 and t < 1.1 and not is_ref:
			mods.append([PI * 0.5, 0.22, -0.03, 0.07]) # divisa bíceps/tríceps por fora
		rings.append({"k": t, "c": sh + Vector3(0, -t * H, 0), "ax": Vector3.RIGHT, "az": Vector3(0, 0, z),
			"rad": [float(row[1]) * ak, float(row[2]) * ak, float(row[3]) * ak, float(row[4]) * ak], "e": 1.0,
			"b0": bu, "b1": bf, "w1": smoothstep(le - 0.22, le + 0.18, t), "mods": mods,
			"v": V_WHITE if is_ref else lerpf(V_ARM[0], V_ARM[1], (t + 0.1) / 2.76)})
	var skin := skin_tone(r.skin)
	var shirt := r.shirt
	var look := func(t: float) -> Array:
		if is_ref and t <= 0.75:
			return [shirt]
		if is_ref and t > 2.6:
			return [latex]
		return [skin]
	var ends := _loft(rings, SEG, look)
	_cap(ends[0], SEG, sh + Vector3(0, 0.15 * H, 0), shirt if is_ref else skin, bu)
	_cap(ends[1], SEG, sh + Vector3(0, -(float(tab[tab.size() - 1][0]) + 0.06) * H, 0), latex if is_ref else skin, bf)
	_ball(sh + Vector3(0, -le * H, 0), 0.185 * ak, skin, bf)


func _leg(r: Rig2D, s: int, is_ref: bool) -> void:
	var z := 1.0 if s == 0 else -1.0
	var hip: Vector3 = rest_pos[side_bone(s, P_THIGH)]
	var lk := leg_scale(r) * H
	var bt := side_bone(s, P_THIGH)
	var bs := side_bone(s, P_SHIN)
	var lt := Rig2D.L_THIGH
	var cloth := 1.07 if is_ref else 1.0
	var tab := LEG_TAB
	var col := r.shorts if is_ref else skin_tone(r.skin)
	var prev := -1
	for row: Array in tab:
		var t := float(row[0])
		var w1 := smoothstep(lt - 0.25, lt + 0.2, t)
		var c := hip + Vector3(0, -t * H, 0)
		var rad := [float(row[1]) * lk * cloth, float(row[2]) * lk * cloth, float(row[3]) * lk * cloth, float(row[4]) * lk * cloth]
		var mods: Array = []
		if t > 1.6 and t < 2.0 and not is_ref:
			mods.append([0.0, 0.55, 0.06, -0.04]) # rótula
		if t > 0.3 and t < 1.5 and not is_ref:
			mods.append([PI * 0.5 * 0.55, 0.18, -0.02, 0.05]) # divisa do quadríceps
		var st := _ring(SEG, c, Vector3.RIGHT, Vector3(0, 0, z), rad, 1.0, col, bt, bs, w1, mods, V_WHITE if is_ref else lerpf(V_LEG[0], V_LEG[1], (t + 0.1) / 3.84))
		if prev < 0:
			_cap(st, SEG, hip + Vector3(0, 0.2 * H, 0), col, bt)
		else:
			_bridge(prev, st, SEG)
		prev = st
	_cap(prev, SEG, hip + Vector3(0, -3.74 * H, 0), col, bs)
	_ball(hip + Vector3(0, -lt * H, 0), 0.2 * lk * cloth, col, bs)
	if is_ref:
		return
	# Perna do calção: mais larga que a coxa, com barra e faixa lateral.
	var sh_tab := [[-0.12, 1.06], [0.15, 1.1], [0.5, 1.14], [0.8, 1.2], [0.96, 1.24]]
	prev = -1
	var last := Vector3.ZERO
	for row2: Array in sh_tab:
		var t2 := float(row2[0])
		var base := _row_at(tab, t2)
		var k := float(row2[1]) * lk
		var hem := t2 >= 0.9
		var c2 := hip + Vector3(0, -t2 * H, 0)
		var rad2 := [float(base[1]) * k + 0.02 * H, float(base[2]) * k + 0.02 * H, float(base[3]) * k + 0.02 * H, float(base[4]) * k]
		var st2 := _ring(SEG, c2, Vector3.RIGHT, Vector3(0, 0, z), rad2, 1.0, r.trim if hem else r.shorts, bt, bt, 0.0)
		if prev < 0:
			_cap(st2, SEG, hip + Vector3(0, 0.22 * H, 0), r.shorts, bt)
		else:
			_bridge(prev, st2, SEG)
		prev = st2
		last = c2
	# Fecha a barra por dentro (sombra da boca do calção).
	_cap(prev, SEG, last + Vector3(0, 0.12 * H, 0), r.shorts.darkened(0.55), bt)


func _foot(r: Rig2D, s: int, is_ref: bool) -> void:
	var z := 1.0 if s == 0 else -1.0
	var an: Vector3 = rest_pos[side_bone(s, P_FOOT)]
	var b := side_bone(s, P_FOOT)
	var col := Color(0.07, 0.07, 0.08) if is_ref else skin_tone(r.skin)
	var k := (1.12 if is_ref else 1.0) * H * (0.95 + 0.1 * r.leg_k)
	# [para a frente, altura do centro, cima, baixo, fora, dentro]
	var tab := [
		[-0.14, 0.10, 0.10, 0.09, 0.09, 0.09],
		[0.0, 0.115, 0.17, 0.10, 0.115, 0.11],
		[0.18, 0.10, 0.13, 0.09, 0.125, 0.115],
		[0.38, 0.078, 0.08, 0.068, 0.15, 0.12],
		[0.55, 0.058, 0.055, 0.05, 0.155, 0.125],
		[0.70, 0.048, 0.04, 0.04, 0.13, 0.10],
	]
	var prev := -1
	for row: Array in tab:
		var c := an + Vector3(float(row[0]) * k, float(row[1]) * k + 0.012, 0)
		var st := _ring(12, c, Vector3.UP, Vector3(0, 0, z), [float(row[2]) * k, float(row[3]) * k, float(row[4]) * k, float(row[5]) * k], 0.8, col, b, b, 0.0)
		if prev < 0:
			_cap(st, 12, an + Vector3(-0.2 * k, 0.09 * k, 0), col, b)
		else:
			_bridge(prev, st, 12)
		prev = st
	_cap(prev, 12, an + Vector3(0.79 * k, 0.045 * k, 0), col, b)


# --- Textura de músculos -----------------------------------------------------------------

## Mapa de sombras dos músculos (cinza: branco = pele lisa, escuro = sulco), pintado uma vez e
## dividido em faixas: tronco (peitoral, linha do meio, gomos, oblíquos, serrátil, umbigo; nas
## costas espinha, escápulas e dorsais), braço (deltoide, bíceps/tríceps, antebraço) e perna
## (quadríceps, rótula, panturrilha). `soft`: definição leve (mulheres e quem tem barriga).
static func muscle_texture(soft: bool) -> ImageTexture:
	if _tex_cache.has(soft):
		return _tex_cache[soft]
	var W := 256
	var Hh := 256
	var d := PackedFloat32Array()
	d.resize(W * Hh)
	var k := 0.36 if soft else 0.8
	# Tronco: (graus a partir da frente, altura em U)
	var tor := func(deg: float, y: float) -> Vector2:
		return Vector2((0.5 + deg / 360.0) * W, lerpf(V_TORSO[0], V_TORSO[1], (y + 0.47) / 3.47) * Hh)
	var T := [
		# frente
		[[[0, 0.6], [0, 1.6]], 2.0, 0.34, false], # linha alba
		[[[0, 1.62], [0, 2.2]], 2.4, 0.42, false], # esterno
		[[[3, 1.68], [16, 1.6], [34, 1.6], [50, 1.7], [64, 1.9]], 2.6, 0.5, true], # peitoral por baixo
		[[[8, 2.34], [30, 2.4], [52, 2.36]], 1.8, 0.22, true], # clavícula
		[[[-21, 1.42], [0, 1.4], [21, 1.42]], 1.7, 0.3, false], # gomos
		[[[-22, 1.18], [0, 1.16], [22, 1.18]], 1.7, 0.3, false],
		[[[-22, 0.94], [0, 0.92], [22, 0.94]], 1.7, 0.28, false],
		[[[24, 0.56], [25, 1.2], [22, 1.58]], 1.8, 0.24, true], # borda do reto
		[[[52, 0.8], [36, 0.6], [18, 0.44]], 2.2, 0.3, true], # oblíquo / linha do V
		[[[46, 1.5], [58, 1.42]], 1.5, 0.2, true], # serrátil
		[[[45, 1.36], [57, 1.28]], 1.5, 0.2, true],
		[[[44, 1.22], [55, 1.14]], 1.5, 0.18, true],
		[[[0, 0.72], [0, 0.74]], 1.6, 0.6, false], # umbigo
		[[[27, 1.75], [27, 1.76]], 1.5, 0.45, true], # mamilo
		[[[88, 1.75], [90, 2.2]], 5.0, 0.3, true], # axila
		# costas
		[[[180, 0.4], [180, 2.4]], 2.4, 0.36, false], # espinha
		[[[150, 1.7], [143, 1.95], [150, 2.15]], 2.2, 0.22, true], # escápula
		[[[118, 1.5], [150, 1.05], [166, 0.75]], 2.2, 0.22, true], # dorsal
		[[[168, 0.45], [167, 1.1]], 2.0, 0.2, true], # eretores
		[[[172, 2.5], [150, 2.36], [122, 2.3]], 1.8, 0.16, true], # trapézio
	]
	for st: Array in T:
		_polyline(d, W, Hh, st[0], tor, float(st[1]), float(st[2]) * k, bool(st[3]))
	# Braço: (graus a partir do bíceps, + = por fora; distância do ombro em U)
	var arm := func(deg: float, t: float) -> Vector2:
		return Vector2((0.5 + deg / 360.0) * W, lerpf(V_ARM[0], V_ARM[1], (t + 0.1) / 2.76) * Hh)
	var A := [
		[[[40, 0.2], [90, 0.52], [140, 0.2]], 1.8, 0.32], # ponta do deltoide
		[[[84, 0.52], [86, 1.15]], 1.6, 0.26], # bíceps/tríceps por fora
		[[[-82, 0.4], [-82, 1.15]], 1.8, 0.24], # por dentro
		[[[-30, 1.06], [0, 1.1], [30, 1.06]], 1.5, 0.16], # fim do bíceps
		[[[150, 0.45], [180, 0.92], [210, 0.45]], 1.6, 0.22], # ferradura do tríceps
		[[[-40, 1.35], [0, 1.37], [40, 1.35]], 1.4, 0.24], # dobra do cotovelo
		[[[48, 1.45], [22, 2.3]], 1.5, 0.2], # braquiorradial
		[[[180, 1.5], [180, 2.5]], 1.4, 0.16], # ulna
	]
	for st: Array in A:
		_polyline(d, W, Hh, st[0], arm, float(st[1]), float(st[2]) * k, false)
	# Perna: (graus a partir da frente, + = por fora; distância do quadril em U)
	var leg := func(deg: float, t: float) -> Vector2:
		return Vector2((0.5 + deg / 360.0) * W, lerpf(V_LEG[0], V_LEG[1], (t + 0.1) / 3.84) * Hh)
	var L := [
		[[[28, 0.35], [14, 1.5]], 1.7, 0.26], # reto femoral / vasto lateral
		[[[-38, 1.15], [-30, 1.5], [-16, 1.66]], 1.9, 0.3], # gota do vasto medial
		[[[20, 1.55], [26, 1.72]], 1.6, 0.2],
		[[[-20, 1.78], [-12, 1.95], [12, 1.95], [20, 1.78]], 1.5, 0.3], # rótula
		[[[180, 0.5], [180, 1.6]], 1.8, 0.2], # posterior da coxa
		[[[180, 2.15], [180, 2.9]], 1.7, 0.3], # divisão da panturrilha
		[[[140, 2.78], [165, 2.95], [180, 2.9], [195, 2.95], [220, 2.78]], 1.6, 0.22], # fim da panturrilha
		[[[-12, 2.1], [-8, 3.4]], 1.3, 0.12], # canela
		[[[120, 0.1], [180, 0.16], [240, 0.1]], 2.0, 0.3], # dobra do glúteo
	]
	for st: Array in L:
		_polyline(d, W, Hh, st[0], leg, float(st[1]), float(st[2]) * k, false)
	var bytes := PackedByteArray()
	bytes.resize(W * Hh)
	for i in W * Hh:
		bytes[i] = int(clampf(1.0 - d[i], 0.0, 1.0) * 255.0)
	var img := Image.create_from_data(W, Hh, false, Image.FORMAT_L8, bytes)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_tex_cache[soft] = tex
	return tex


## Traço macio (escurecimento gaussiano) por uma sequência de pontos; `mirror` repete do outro lado.
static func _polyline(d: PackedFloat32Array, W: int, Hh: int, pts: Array, conv: Callable, rad: float, k: float, mirror: bool) -> void:
	for side in (2 if mirror else 1):
		var sg := 1.0 if side == 0 else -1.0
		for i in range(pts.size() - 1):
			var a: Vector2 = conv.call(float(pts[i][0]) * sg, float(pts[i][1]))
			var b: Vector2 = conv.call(float(pts[i + 1][0]) * sg, float(pts[i + 1][1]))
			_stroke(d, W, Hh, a, b, rad * 1.5, k)


static func _stroke(d: PackedFloat32Array, W: int, Hh: int, a: Vector2, b: Vector2, rad: float, k: float) -> void:
	var m := rad * 2.2
	var x0 := int(floor(minf(a.x, b.x) - m))
	var x1 := int(ceil(maxf(a.x, b.x) + m))
	var y0 := clampi(int(floor(minf(a.y, b.y) - m)), 0, Hh - 1)
	var y1 := clampi(int(ceil(maxf(a.y, b.y) + m)), 0, Hh - 1)
	var ab := b - a
	var l2 := maxf(0.0001, ab.length_squared())
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var p := Vector2(x + 0.5, y + 0.5)
			var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
			var dist := p.distance_to(a + ab * t)
			var g := k * exp(-(dist * dist) / (rad * rad))
			var i := y * W + posmod(x, W)
			if g > d[i]:
				d[i] = g
