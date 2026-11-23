class_name Rig2D
extends RefCounted
## Lutador 2D de lado (luta animada): esqueleto de bonecos articulados com cinemática direta.
## A pose é um dicionário de ângulos em graus; 0 aponta para baixo e o positivo gira para a
## frente (para onde o lutador olha). Membros "near" ficam do lado da câmera, "far" do outro.
##
## Chaves da pose: x, y (deslocamento da cintura em U), crouch (0–1, abaixa a cintura), rot (gira o
## corpo inteiro em volta da cintura, para quedas e chão), torso (inclinação, 0 = em pé, + para a
## frente), head (ângulo extra da cabeça), na_s/na_e (ombro e cotovelo do braço near), fa_s/fa_e
## (braço far), nl_h/nl_k (quadril e joelho da perna near), fl_h/fl_k (perna far), sit (> 0.5:
## sentado/deitado, o quadril apoia e os pés podem afundar um pouco). Só no 3D: lz/az abrem pernas
## e braços para os lados (0 = normal), zz tira o corpo todo do plano (para não embolar no chão) e
## tw gira ombros e quadril (graus; + leva o lado de trás para a frente, como na direita e no chute).

const KEYS := ["x", "y", "crouch", "sit", "rot", "torso", "head", "na_s", "na_e", "fa_s", "fa_e", "nl_h", "nl_k", "fl_h", "fl_k", "lz", "az", "zz", "tw"]
## Comprimentos em U (U = tamanho da cabeça).
const L_TORSO := 2.55
const L_NECK := 0.35
const R_HEAD := 0.5
const L_UARM := 1.35
const L_FARM := 1.25
const L_THIGH := 1.85
const L_SHIN := 1.85

var face: Dictionary = {}
var skin := Color("#C8946A")
var hair := Color("#2A1D16")
var beard := Color("#2A1D16")
var has_beard := false
var bald := false
var shorts := Color("#1B1B1F")
var trim := Color("#C8102E")
var glove := Color("#232327")
var corner := Color("#C8102E")
var fem := false
## Curvas das lutadoras (0 a 1, do FaceGen): busto, cintura (0 fina) e quadril.
var bust := 0.5
var waist := 0.4
var hips := 0.5
## Grossura dos membros e do tronco pelo físico.
var arm_k := 1.0
var leg_k := 1.0
var chest_k := 1.0
var belly := 0.0
var tattoo := 0
var height_k := 1.0
## Olha para a direita (+1) ou para a esquerda (-1).
var dir := 1.0
## Base (o pé de trás atrás): o braço/perna da frente é o near quando olha para a direita e é
## ortodoxo; no canhoto ou olhando para a esquerda, inverte.
var southpaw := false
var pose: Dictionary = {}
## Onde está no palco (em U, centro da cintura).
var px := 0.0
## Família do estilo (guarda): boxe, thai, karate, wrestler, mma.
var guard := "mma"
## Pisca vermelho quando apanha.
var flash := 0.0
## "ref" veste o árbitro (camisa e calça escuras, sem luvas).
var outfit := ""
var shirt := Color("#16171B")
## Corte (sangue no rosto, 0–1.5) e inchaço (dano na cabeça, 0–1).
var cut := 0.0
var bruise := 0.0
## Apagado (olhos fechados) e sangue do outro nas luvas.
var ko := false
var glove_blood := 0.0
## Castigo acumulado na luta (0 a 1): coxa da frente (chutes baixos) e costela.
var leg_dmg := 0.0
var body_dmg := 0.0
## Volume do cabelo e tipo de barba na luta (ver HairShape) e grossura do pescoço.
var hair_shape: Dictionary = {}
var beard_kind := 0
var neck_k := 1.0



static func from_fighter(w: GameWorld, f: Fighter, facing: float) -> Rig2D:
	var r := Rig2D.new()
	r.face = FaceGen.features(f.face_seed, f.eth, w.age_of(f), f.look)
	r.skin = r.face["skin"]
	r.hair = r.face.get("hair", Color("#2A1D16"))
	r.beard = r.face.get("beard_col", r.hair)
	r._read_face()
	r.fem = f.is_female()
	if r.fem:
		r.bust = float(r.face.get("bust", 0.5))
		r.waist = float(r.face.get("waist", 0.4))
		r.hips = float(r.face.get("hips", 0.5))
	var ms := float(f.look.get("ms", 0.5))
	var bf := float(f.look.get("bf", 0.15))
	var build := float(r.face.get("build", 0.5))
	r.arm_k = 0.85 + 0.35 * ms + 0.15 * build
	r.leg_k = 0.9 + 0.25 * build + 0.1 * ms
	r.chest_k = 0.9 + 0.3 * build + 0.12 * ms + (0.0 if not r.fem else -0.12)
	r.belly = maxf(0.0, bf - 0.18) * 2.2
	r.tattoo = int(f.look.get("tt", 0))
	r.height_k = clampf(f.height_cm / 178.0, 0.86, 1.14)
	r.dir = facing
	r.southpaw = f.southpaw
	var t := w.team(f.team_id)
	if t != null:
		r.shorts = t.color1
		r.trim = t.color2 if not t.color2.is_equal_approx(t.color1) else t.color1.lightened(0.4)
	var fam := Styles.family(f.base)
	if f.base in ["boxe"]:
		r.guard = "boxe"
	elif f.base in ["muay_thai", "kickboxing", "kick_holandes", "sanda"]:
		r.guard = "thai"
	elif f.base in ["karate", "kyokushin", "taekwondo", "savate", "capoeira"]:
		r.guard = "karate"
	elif fam == "agarrada":
		r.guard = "wrestler"
	r.pose = r.stance()
	return r


## Cabelo, barba e pescoço a partir do rosto gerado.
func _read_face() -> void:
	hair_shape = HairShape.of(int(face.get("style", 1)))
	beard_kind = HairShape.beard(int(face.get("beard", 0)))
	has_beard = beard_kind >= HairShape.BD_GOATEE
	bald = bool(hair_shape["bald"])
	neck_k = clampf(float(face.get("neck_w", 0.7)) / 0.7, 0.88, 1.25)
	if bool(face.get("fem", false)):
		neck_k = clampf(neck_k * 0.92, 0.8, 1.0)


## Árbitro: camisa escura, calça cinza, sem luvas; cabeça de alguém comum.
static func referee(rng: RandomNumberGenerator) -> Rig2D:
	var r := Rig2D.new()
	var eth: int = [FaceGen.E_EUR, FaceGen.E_LAT, FaceGen.E_NOR, FaceGen.E_MED, FaceGen.E_AFR][rng.randi() % 5]
	r.face = FaceGen.features(rng.randi(), eth, rng.randi_range(36, 58), {})
	r.skin = r.face["skin"]
	r.hair = r.face.get("hair", Color("#2A1D16"))
	r.beard = r.face.get("beard_col", r.hair)
	r._read_face()
	r.outfit = "ref"
	r.shorts = Color("#3B3E46")
	r.shirt = Color("#15161A")
	r.arm_k = 0.95
	r.leg_k = 0.85
	r.chest_k = 0.95
	r.belly = 0.15
	r.height_k = 1.0
	r.dir = 1.0
	r.pose = {"x": 0.0, "y": 0.0, "crouch": 0.1, "sit": 0.0, "rot": 0.0, "torso": 6.0, "head": 0.0, "na_s": 40.0, "na_e": 60.0, "fa_s": 30.0, "fa_e": 70.0,
		"nl_h": 8.0, "nl_k": 4.0, "fl_h": -8.0, "fl_k": 6.0}
	return r


## Lado (n = near, f = far) do braço e da perna da frente. Ortodoxo olhando para a direita mostra o
## lado esquerdo para a câmera, então a frente é o near.
func lead() -> String:
	return "n" if (dir > 0.0) != southpaw else "f"


func rear() -> String:
	return "f" if lead() == "n" else "n"


## Guarda de base de cada escola.
func stance() -> Dictionary:
	var p := _stance_raw()
	if lead() == "f":
		p = swap_sides(p)
	return p


## Troca near e far (os ângulos da guarda são escritos com a frente no near).
static func swap_sides(p: Dictionary) -> Dictionary:
	var o := p.duplicate()
	for pair: Array in [["na_s", "fa_s"], ["na_e", "fa_e"], ["nl_h", "fl_h"], ["nl_k", "fl_k"]]:
		o[pair[0]] = p.get(pair[1], 0.0)
		o[pair[1]] = p.get(pair[0], 0.0)
	return o


func _stance_raw() -> Dictionary:
	match guard:
		"boxe":
			return {"x": 0.0, "y": 0.0, "crouch": 0.2, "rot": 0.0, "torso": 12.0, "head": 8.0, "na_s": 55.0, "na_e": 120.0, "fa_s": 35.0, "fa_e": 135.0,
				"nl_h": 18.0, "nl_k": 18.0, "fl_h": -20.0, "fl_k": 22.0}
		"thai":
			return {"x": 0.0, "y": 0.0, "crouch": 0.05, "rot": 0.0, "torso": 2.0, "head": 4.0, "na_s": 70.0, "na_e": 115.0, "fa_s": 50.0, "fa_e": 125.0,
				"nl_h": 12.0, "nl_k": 10.0, "fl_h": -14.0, "fl_k": 8.0}
		"karate":
			return {"x": 0.0, "y": 0.0, "crouch": 0.12, "rot": 0.0, "torso": 4.0, "head": 0.0, "na_s": 55.0, "na_e": 70.0, "fa_s": 30.0, "fa_e": 115.0,
				"nl_h": 26.0, "nl_k": 12.0, "fl_h": -26.0, "fl_k": 14.0}
		"wrestler":
			return {"x": 0.0, "y": 0.0, "crouch": 0.45, "rot": 0.0, "torso": 30.0, "head": -10.0, "na_s": 70.0, "na_e": 60.0, "fa_s": 55.0, "fa_e": 75.0,
				"nl_h": 30.0, "nl_k": 45.0, "fl_h": -18.0, "fl_k": 40.0}
	return {"x": 0.0, "y": 0.0, "crouch": 0.22, "rot": 0.0, "torso": 14.0, "head": 2.0, "na_s": 60.0, "na_e": 110.0, "fa_s": 40.0, "fa_e": 125.0,
		"nl_h": 20.0, "nl_k": 20.0, "fl_h": -20.0, "fl_k": 24.0}


static func blend(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var out := {}
	for k: String in KEYS:
		out[k] = lerpf(float(a.get(k, 0.0)), float(b.get(k, a.get(k, 0.0))), t)
	return out


## Ponto a partir de um ângulo (0 = para baixo, + para a frente).
func _dirv(deg: float) -> Vector2:
	var a := deg_to_rad(deg)
	return Vector2(sin(a) * dir, cos(a))


## Juntas em coordenadas do palco (pixels). `ground_y`: linha do chão; `U`: pixels por U. O ponto
## mais baixo do corpo (pé, quadril ou cabeça, se deitado) encosta no chão; `y` levanta do chão
## (pulo, joelhada voadora, arremesso).
func joints(origin_x: float, ground_y: float, U: float) -> Dictionary:
	var j := _joints_at(Vector2(origin_x + px * U + float(pose.get("x", 0.0)) * U * dir, 0.0), U)
	var low := -INF
	var Uh: float = j["U"]
	# Sentado/deitado: o quadril apoia e a ponta do pé não conta (pé pode ficar abaixo da linha).
	var sit := float(pose.get("sit", 0.0)) > 0.5
	for k: String in ["nl_an", "fl_an", "nl_kn", "fl_kn"]:
		low = maxf(low, (j[k] as Vector2).y - (Uh * 0.2 if sit else 0.0))
	for k: String in ["hip", "neck", "head", "sh"]:
		low = maxf(low, (j[k] as Vector2).y + Uh * 0.35)
	var lift := float(pose.get("y", 0.0)) * U
	var dy := ground_y - low - lift
	j["gy"] = ground_y
	for k: String in j:
		if j[k] is Vector2:
			j[k] = (j[k] as Vector2) + Vector2(0, dy)
	if not sit:
		for side: String in ["nl", "fl"]:
			var hipj: Vector2 = j["hip"]
			var kn: Vector2 = j[side + "_kn"]
			var an: Vector2 = j[side + "_an"]
			var td := ((j[side + "_toe"] as Vector2) - an) / (0.55 * Uh)
			var h := (ground_y - an.y) / Uh
			var fwd := smoothstep(-0.3, 0.3, td.x * dir)
			# Pé que ficou perto do chão (o de trás, na base) desce até a lona: a perna estica o que
			# falta e o calcanhar fica um pouco levantado, apoiado na ponta.
			var reach := (1.0 - smoothstep(0.55, 1.0, h)) * fwd
			if lift <= 0.0 and h > 0.02 and reach > 0.0:
				var dx := clampf(an.x - hipj.x, -1.35 * Uh, 1.35 * Uh)
				var tgt := an.lerp(Vector2(hipj.x + dx, ground_y - minf(0.3 * h, 0.2) * Uh), reach)
				var l1 := L_THIGH * Uh
				var l2 := L_SHIN * Uh
				var v := tgt - hipj
				var d := clampf(v.length(), 0.05 * Uh, (l1 + l2) * 0.999)
				var u := v.normalized()
				var a := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
				var hgt := sqrt(maxf(0.0, l1 * l1 - a * a))
				var perp := Vector2(-u.y, u.x)
				if perp.dot(kn - hipj) < 0.0:
					perp = -perp
				kn = hipj + u * a + perp * hgt
				an = hipj + u * d
				j[side + "_kn"] = kn
				j[side + "_an"] = an
				h = (ground_y - an.y) / Uh
			# De planta inteira na lona, apontando para a frente; com o calcanhar levantado a bola
			# do pé fica na lona. No ar o pé segue a canela.
			var toe := an + td * 0.55 * Uh
			if lift <= 0.0 and h < 0.5 and fwd > 0.0 and (h < 0.1 or toe.y > ground_y - 0.12 * Uh):
				var hh := clampf(h, 0.0, 0.5)
				var flat := Vector2(dir * sqrt(0.55 * 0.55 - hh * hh), hh) / 0.55
				td = td.lerp(flat, fwd).normalized()
				toe = an + td * 0.55 * Uh
			j[side + "_toe"] = toe
	return j


func _joints_at(hip: Vector2, U: float) -> Dictionary:
	var p := pose
	var Uh := U * height_k
	var rot := float(p.get("rot", 0.0))
	var torso_deg := 180.0 - float(p.get("torso", 0.0)) + rot
	var neck := hip + _dirv(torso_deg) * L_TORSO * Uh
	var head_c := neck + _dirv(torso_deg - float(p.get("head", 0.0)) * 0.5) * (L_NECK + R_HEAD) * Uh
	var sh := neck + _dirv(torso_deg) * -0.25 * Uh
	var j := {"hip": hip, "neck": neck, "head": head_c, "sh": sh, "U": Uh, "torso_deg": torso_deg}
	for side: String in ["na", "fa"]:
		var s_deg := float(p.get(side + "_s", 40.0)) + rot
		var e_deg := s_deg + float(p.get(side + "_e", 90.0))
		var el := sh + _dirv(s_deg) * L_UARM * Uh
		var wr := el + _dirv(e_deg) * L_FARM * Uh
		j[side + "_el"] = el
		j[side + "_wr"] = wr
	# Base mais baixa: dobra os joelhos (a perna da frente mais que a de trás).
	var cr := float(p.get("crouch", 0.0))
	for side: String in ["nl", "fl"]:
		var front := float(p.get(side + "_h", 0.0)) >= float(p.get(("fl" if side == "nl" else "nl") + "_h", 0.0))
		var h_deg := float(p.get(side + "_h", 0.0)) + rot + cr * (28.0 if front else 8.0)
		var k_deg := h_deg - float(p.get(side + "_k", 0.0)) - cr * (55.0 if front else 40.0)
		var kn := hip + _dirv(h_deg) * L_THIGH * Uh
		var an := kn + _dirv(k_deg) * L_SHIN * Uh
		j[side + "_kn"] = kn
		j[side + "_an"] = an
		j[side + "_toe"] = an + _dirv(k_deg + 90.0) * 0.55 * Uh
	return j




# --- Desenho ---------------------------------------------------------------------------------
# O corpo é uma malha: cada membro é uma tira que segue o perfil anatômico do Body3D (deltoide,
# bíceps, antebraço; quadríceps, joelho, panturrilha), com sombra de volume em cada vértice. O
# tronco usa o mesmo perfil do 3D, visto um pouco de três quartos, e gira com o golpe: quem está
# com o lado da frente para a câmera mostra as costas, o outro mostra o peito.

const OL_COL := Color(0.05, 0.04, 0.06, 0.92)
## Luz do ginásio: de cima, um pouco de lado e de frente (x e y da tela, z saindo da tela).
const LIGHT := Vector3(-0.2, -0.74, 0.64)
const AMB := 0.56
const DIF := 0.56
## Quanto o lado de lá do corpo fica mais escuro.
const FAR := 0.72
## Pé de lado: [para a frente, altura do centro, cima, baixo]
const FOOT_TAB := [
	[-0.15, 0.10, 0.09, 0.085],
	[-0.02, 0.118, 0.165, 0.105],
	[0.16, 0.105, 0.135, 0.095],
	[0.36, 0.08, 0.085, 0.07],
	[0.54, 0.06, 0.058, 0.052],
	[0.70, 0.05, 0.045, 0.042],
	[0.79, 0.04, 0.016, 0.022],
]
## Cabeça de perfil (x para a frente, y para cima, em raios da cabeça): do alto, descendo pelo
## rosto e voltando pela mandíbula e pela nuca.
const HEAD_PTS := [
	Vector2(0.0, 1.0), Vector2(0.45, 0.93), Vector2(0.78, 0.68), Vector2(0.9, 0.38), Vector2(0.93, 0.2),
	Vector2(0.87, 0.08), Vector2(1.02, -0.1), Vector2(1.15, -0.25), Vector2(0.98, -0.33), Vector2(0.96, -0.42),
	Vector2(0.99, -0.5), Vector2(0.94, -0.6), Vector2(0.9, -0.7), Vector2(0.93, -0.86), Vector2(0.78, -1.0),
	Vector2(0.5, -0.97), Vector2(0.1, -0.8), Vector2(-0.12, -0.62), Vector2(-0.32, -0.52), Vector2(-0.55, -0.45),
	Vector2(-0.88, -0.2), Vector2(-1.0, 0.2), Vector2(-0.9, 0.6), Vector2(-0.6, 0.88), Vector2(-0.3, 0.98),
]

## Largura do contorno na passada de contorno (0 na passada normal).
var _ol := 0.0
# Linhas da tira em construção: centro, normal da frente, raio da frente e de trás, cor e t.
var _cs := PackedVector2Array()
var _ns := PackedVector2Array()
var _fr := PackedFloat32Array()
var _bk := PackedFloat32Array()
var _cl := PackedColorArray()
var _tt := PackedFloat32Array()
# Perfis prontos do físico (em U) e cabeça/cabelo de perfil (em raios da cabeça).
var _ready_k := -1.0
var _arm_p: Array = []
var _leg_p: Array = []
var _tor_p: Array = []
var _hp := PackedVector2Array()
var _hair_main := PackedVector2Array()
var _hair_side := PackedVector2Array()
var _hair_hang := PackedVector2Array()
var _hair_skin := PackedVector2Array()
var _hair_balls: Array = []
var _hair_strands: Array = []
var _beard_p := PackedVector2Array()
var _parts := {}
# Malha única do lutador (ver "Malha única"): pontos, cores e uvs em linhas de dois vértices.
var _mp := PackedVector2Array()
var _mc := PackedColorArray()
var _mu := PackedVector2Array()
# Cabeça pronta para a malha, em raios da cabeça: leque da pele, polígonos já em triângulos e os
# contornos em fita.
var _hp_fan := PackedVector2Array()
var _hp_ring := PackedVector2Array()
var _jaw_tri := PackedVector2Array()
var _main_tri := PackedVector2Array()
var _main_ring := PackedVector2Array()
var _main_hi := PackedVector2Array()
var _side_tri := PackedVector2Array()
var _hang_tri := PackedVector2Array()
var _hang_ring := PackedVector2Array()
var _skin_tri := PackedVector2Array()
var _beard_tri := PackedVector2Array()
static var _strip_idx := PackedInt32Array()
static var _flat_uvs := {}
static var _zig := {}


## Tom da cor pela luz: sombra mais quente e saturada, luz puxando para o branco.
static func _tone(base: Color, b: float) -> Color:
	if b <= 1.0:
		return Color(base.r * 0.4, base.g * 0.33, base.b * 0.37, base.a).lerp(base, clampf((b - 0.3) / 0.7, 0.0, 1.0))
	return base.lerp(Color(minf(1.0, base.r * 1.32 + 0.03), minf(1.0, base.g * 1.3 + 0.03), minf(1.0, base.b * 1.26 + 0.03), base.a), minf(1.0, (b - 1.0) * 8.0))


## Perfil de membro: [t, frente, trás] da tabela, já na grossura do lutador; `cuts` duplica uma
## linha onde a cor muda (manga, barra).
static func _profile(tab: Array, k: float, cuts: Array = []) -> Array:
	var ts := PackedFloat32Array()
	var fr := PackedFloat32Array()
	var bk := PackedFloat32Array()
	var all: Array = []
	for row: Array in tab:
		all.append(float(row[0]))
	for c: float in cuts:
		all.append(c)
		all.append(c + 0.0001)
	all.sort()
	for t: float in all:
		var row := Body3D._row_at(tab, t)
		ts.append(t)
		fr.append(float(row[1]) * k)
		bk.append(float(row[2]) * k)
	return [ts, fr, bk]


func _prep() -> void:
	var key := arm_k * 3.1 + leg_k * 5.3 + chest_k * 7.7 + belly * 11.0 + (100.0 if fem else 0.0) + (1000.0 if outfit == "ref" else 0.0) + float(tattoo) * 10000.0
	if fem:
		key += bust * 13.0 + waist * 17.0 + hips * 19.0
	if is_equal_approx(key, _ready_k):
		return
	_ready_k = key
	var is_ref := outfit == "ref"
	_arm_p = _profile(Body3D.ARM_TAB, Body3D.arm_scale(self), [0.75] if is_ref else ([0.12, 2.25] if tattoo >= 3 else []))
	_leg_p = _profile(Body3D.LEG_TAB, Body3D.leg_scale(self) * (1.07 if is_ref else 1.0))
	if fem and not is_ref:
		# Coxa cheia e tornozelo fino
		var lts: PackedFloat32Array = _leg_p[0]
		var lfr: PackedFloat32Array = _leg_p[1]
		var lbk: PackedFloat32Array = _leg_p[2]
		for i in lts.size():
			var kk := 1.0 + (0.03 + 0.1 * hips) * (1.0 - smoothstep(0.6, 1.5, lts[i])) - 0.05 * smoothstep(2.9, 3.4, lts[i])
			lfr[i] *= kk
			lbk[i] *= kk + 0.05 * hips * (1.0 - smoothstep(0.1, 0.7, lts[i]))
	# Tronco: [y, frente, trás, faixa]. Faixas: 0 calção, 1 cós, 2 pele, 3 top, 4 camisa.
	var ys: Array = []
	for row: Array in Body3D.TORSO_TAB:
		if float(row[0]) <= 2.57:
			ys.append(float(row[0]))
	for c: float in [0.38, 0.48]:
		if not ys.has(c):
			ys.append(c)
	if fem and not is_ref:
		ys.append(2.19)
		for c: float in [1.72, 1.9, 2.09, 1.0, 0.0]:
			if not ys.has(c):
				ys.append(c)
	ys.sort()
	var zone := func(y: float) -> int:
		if y <= 0.38:
			return 0
		if y <= 0.48:
			return 1
		if is_ref:
			return 4
		if fem and y >= 1.5 and y <= 2.19:
			return 3
		return 2
	_tor_p = []
	for y: float in ys:
		var row := Body3D.torso_row(self, y)
		var f := float(row[1]) + 0.22 * float(row[0])
		var b := float(row[2]) * 0.92 + 0.22 * float(row[0])
		var z0: int = zone.call(y - 0.005)
		var z1: int = zone.call(y + 0.005)
		_tor_p.append([y, f, b, z0])
		if z1 != z0 and y < 2.5:
			_tor_p.append([y, f, b, z1])
	_prep_head()


func _begin() -> void:
	_cs = PackedVector2Array()
	_ns = PackedVector2Array()
	_fr = PackedFloat32Array()
	_bk = PackedFloat32Array()
	_cl = PackedColorArray()
	_tt = PackedFloat32Array()


func _row(c: Vector2, n: Vector2, f: float, b: float, col: Color, t: float = 0.0) -> void:
	_cs.append(c)
	_ns.append(n)
	_fr.append(f)
	_bk.append(b)
	_cl.append(col)
	_tt.append(t)


## Ponto da tira em construção: na altura `t`, de -1 (borda de trás) a 1 (borda da frente).
func _at(t: float, u: float) -> Vector2:
	var n := _tt.size()
	var i := 0
	while i < n - 2 and _tt[i + 1] < t:
		i += 1
	var k := clampf((t - _tt[i]) / maxf(0.0001, _tt[i + 1] - _tt[i]), 0.0, 1.0)
	var a := _cs[i] + _ns[i] * (u * (_fr[i] if u > 0.0 else _bk[i]))
	var b := _cs[i + 1] + _ns[i + 1] * (u * (_fr[i + 1] if u > 0.0 else _bk[i + 1]))
	return a.lerp(b, k)


## Volume da tira: uma textura pequena com o sombreado de um cilindro (x: da borda de trás à da
## frente; y: para onde a normal da frente aponta em relação à luz). A placa de vídeo interpola,
## então cada linha da tira só precisa de dois vértices. As quatro linhas de baixo são brancas:
## é onde apontam as peças de cor chapada (UV_FLAT), que assim cabem na mesma malha.
const SHADE_MAX := 1.32
const SHADE_ROWS := 16
const SHADE_H := 20
const SHADE_V0 := 0.5 / 20.0
const SHADE_VK := 15.0 / 20.0
const UV_FLAT := Vector2(0.5, 18.5 / 20.0)
static var _shade_tex: ImageTexture


static func _shading() -> RID:
	if _shade_tex == null:
		var w := 32
		var h := SHADE_ROWS
		var img := Image.create(w, SHADE_H, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		for y in h:
			var d := (float(y) + 0.5) / float(h) * 2.0 - 1.0
			for x in w:
				var u := (float(x) + 0.5) / float(w) * 2.0 - 1.0
				var br := AMB + DIF * maxf(0.0, u * d + sqrt(1.0 - u * u) * LIGHT.z)
				var m := Vector3.ONE
				if br <= 1.0:
					m = Vector3(0.4, 0.33, 0.37).lerp(Vector3.ONE, clampf((br - 0.3) / 0.7, 0.0, 1.0))
				else:
					m = Vector3.ONE.lerp(Vector3(1.32, 1.3, 1.26), minf(1.0, (br - 1.0) * 8.0))
				img.set_pixel(x, y, Color(m.x / SHADE_MAX, m.y / SHADE_MAX, m.z / SHADE_MAX, 1.0))
		_shade_tex = ImageTexture.create_from_image(img)
	return _shade_tex.get_rid()


## Tira já montada na passada de contorno: a passada do desenho reaproveita.
func _load(key: String) -> bool:
	if _ol > 0.0 or not _parts.has(key):
		return false
	var p: Array = _parts[key]
	_cs = p[0]
	_ns = p[1]
	_fr = p[2]
	_bk = p[3]
	_cl = p[4]
	_tt = p[5]
	return true


## Põe a tira montada na malha. `dim` escurece (lado de lá); `edge` põe por baixo um contorno fino
## que some perto da raiz (separa o braço e a perna de cá do tronco).
func _emit(key: String, dim: float, edge: float = 0.0, ew: float = 1.0) -> void:
	var n := _cs.size()
	if n < 2:
		return
	if _ol > 0.0:
		_emit_edge(n, _ol, OL_COL, 0)
		_parts[key] = [_cs, _ns, _fr, _bk, _cl, _tt]
		return
	if edge > 0.0:
		_emit_edge(n, ew, Color(OL_COL, edge), maxi(2, int(n * 0.3)))
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	pts.resize(n * 2)
	cols.resize(n * 2)
	uvs.resize(n * 2)
	var dt := clampf((dim - 0.3) / 0.7, 0.0, 1.0)
	var dr := lerpf(0.4, 1.0, dt) * SHADE_MAX
	var dg := lerpf(0.33, 1.0, dt) * SHADE_MAX
	var db := lerpf(0.37, 1.0, dt) * SHADE_MAX
	var lx := LIGHT.x * 0.5 * SHADE_VK
	var ly := LIGHT.y * 0.5 * SHADE_VK
	var v0 := SHADE_V0 + 0.5 * SHADE_VK
	for i in n:
		var c := _cs[i]
		var nn := _ns[i]
		var base := _cl[i]
		var col := Color(base.r * dr, base.g * dg, base.b * db, base.a)
		var v := v0 + nn.x * lx + nn.y * ly
		var k := i * 2
		pts[k] = c + nn * _fr[i]
		pts[k + 1] = c - nn * _bk[i]
		cols[k] = col
		cols[k + 1] = col
		uvs[k] = Vector2(1.0, v)
		uvs[k + 1] = Vector2(0.0, v)
	_push(pts, cols, uvs)


func _emit_edge(n: int, o: float, col: Color, fade: int) -> void:
	var pts := PackedVector2Array()
	pts.resize(n * 2)
	for i in n:
		var c := _cs[i]
		if i == 0:
			c -= (_cs[1] - _cs[0]).normalized() * o
		elif i == n - 1:
			c += (_cs[n - 1] - _cs[n - 2]).normalized() * o
		pts[i * 2] = c + _ns[i] * (_fr[i] + o)
		pts[i * 2 + 1] = c - _ns[i] * (_bk[i] + o)
	if fade <= 0:
		_push_flat(pts, col)
		return
	var cols := PackedColorArray()
	cols.resize(n * 2)
	cols.fill(col)
	for i in mini(fade, n):
		var cc := Color(col.r, col.g, col.b, col.a * float(i) / float(fade))
		cols[i * 2] = cc
		cols[i * 2 + 1] = cc
	_push(pts, cols, _flat_uv(n * 2))


## Monta as linhas de um membro de dois ossos (a→b→c). O lado da frente do osso é o do bíceps e
## do quadríceps; na junta, um leque arredonda o cotovelo e o joelho.
func _limb_rows(a: Vector2, b: Vector2, c: Vector2, prof: Array, l1: float, l2: float, k: float, col: Color) -> void:
	var d1 := (b - a).normalized()
	var d2 := (c - b).normalized()
	if d1 == Vector2.ZERO:
		d1 = Vector2(0, 1)
	if d2 == Vector2.ZERO:
		d2 = d1
	var n1 := Vector2(d1.y, -d1.x) * dir
	var n2 := Vector2(d2.y, -d2.x) * dir
	var ts: PackedFloat32Array = prof[0]
	var fr: PackedFloat32Array = prof[1]
	var bk: PackedFloat32Array = prof[2]
	_begin()
	for i in ts.size():
		var t := ts[i]
		var f := fr[i] * k
		var bb := bk[i] * k
		if absf(t - l1) < 0.0005:
			var ang := n1.angle_to(n2)
			var steps := 1 + int(absf(ang) / 0.45)
			for s in steps + 1:
				_row(b, n1.rotated(ang * float(s) / float(steps)), f, bb, col, t)
		elif t < l1:
			_row(a + (b - a) * (t / l1), n1, f, bb, col, t)
		else:
			_row(b + (c - b) * ((t - l1) / l2), n2, f, bb, col, t)


static func _oval(c: Vector2, ax: Vector2, ay: Vector2, n: int = 12) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.resize(n)
	for i in n:
		var a := TAU * float(i) / float(n)
		pts[i] = c + ax * cos(a) + ay * sin(a)
	return pts


## `layer`: 0 tudo, 1 tudo menos o braço near, 2 só o braço e a perna near (abraço por trás).
func draw(ci: CanvasItem, origin_x: float, ground_y: float, U: float, layer: int = 0) -> void:
	var j := joints(origin_x, ground_y, U)
	var Uh: float = j["U"]
	_prep()
	_parts.clear()
	_mp = PackedVector2Array()
	_mc = PackedColorArray()
	_mu = PackedVector2Array()
	if layer != 2:
		_shadow(j, ground_y, Uh)
	# Contorno escuro primeiro (separa os dois corpos quando se embolam), depois o desenho.
	_ol = maxf(1.0, Uh * 0.05)
	_pass(j, layer)
	_ol = 0.0
	_pass(j, layer)
	_flush(ci)


## Sombra de contato na lona: acompanha o corpo (mais larga com ele deitado).
func _shadow(j: Dictionary, ground_y: float, Uh: float) -> void:
	var x0 := INF
	var x1 := -INF
	for k: String in ["nl_an", "fl_an", "nl_toe", "fl_toe", "hip", "head"]:
		var p: Vector2 = j[k]
		if p.y > ground_y - Uh * 1.6:
			x0 = minf(x0, p.x)
			x1 = maxf(x1, p.x)
	if x0 > x1:
		x0 = (j["hip"] as Vector2).x
		x1 = x0
	var lift := clampf((ground_y - maxf((j["nl_an"] as Vector2).y, (j["fl_an"] as Vector2).y)) / (Uh * 2.5), 0.0, 1.0)
	var cx := (x0 + x1) * 0.5
	var rx := (x1 - x0) * 0.5 + Uh * (0.75 + 0.5 * lift)
	var c := Vector2(cx, ground_y + Uh * 0.04)
	_ov(c, Vector2(rx * 1.15, 0), Vector2(0, Uh * 0.3), 20, Color(0, 0, 0, 0.14 * (1.0 - 0.5 * lift)))
	_ov(c, Vector2(rx * 0.82, 0), Vector2(0, Uh * 0.19), 18, Color(0, 0, 0, 0.2 * (1.0 - 0.6 * lift)))


func _pass(j: Dictionary, layer: int) -> void:
	var Uh: float = j["U"]
	var sk := skin.lerp(Color(0.8, 0.22, 0.18), flash * 0.35)
	var hip: Vector2 = j["hip"]
	var neck: Vector2 = j["neck"]
	var tdir := (neck - hip).normalized()
	var tn := Vector2(-tdir.y, tdir.x) * dir
	# Giro do tronco: na base o ombro da frente fica adiantado; o golpe de trás (tw) inverte.
	var s_lead := 1.0 if lead() == "n" else -1.0
	var tw := float(pose.get("tw", 0.0))
	var turn := s_lead * sin(deg_to_rad(32.0 - tw))
	var sho := tn * (turn * 0.2 * Uh * chest_k)
	var hpo := tn * (s_lead * sin(deg_to_rad(32.0 - tw * 0.6)) * 0.09 * Uh)
	if layer == 2:
		_leg(j, "nl", hpo, sk, 1.0, Uh)
		_shorts_leg(j, "nl", hpo, 1.0, Uh)
		_arm(j, "na", sho, sk, 1.0, Uh)
		return
	_leg(j, "fl", -hpo, sk, FAR, Uh)
	_shorts_leg(j, "fl", -hpo, FAR, Uh)
	_arm(j, "fa", -sho, sk, FAR, Uh)
	_neck(j, sk, tn, Uh)
	_torso(j, sk, tdir, tn, -turn, Uh)
	_head(j, Uh, sk)
	_leg(j, "nl", hpo, sk, 1.0, Uh)
	_shorts_leg(j, "nl", hpo, 1.0, Uh)
	if layer == 0:
		_arm(j, "na", sho, sk, 1.0, Uh)


func _arm(j: Dictionary, side: String, off: Vector2, sk: Color, dim: float, Uh: float) -> void:
	var sh: Vector2 = (j["sh"] as Vector2) + off
	var el: Vector2 = (j[side + "_el"] as Vector2) + off * 0.45
	var wr: Vector2 = j[side + "_wr"]
	var is_ref := outfit == "ref"
	var near := dim >= 1.0
	if not _load(side):
		_limb_rows(sh, el, wr, _arm_p, L_UARM, L_FARM, Uh, sk)
		# Bíceps contraído com o braço dobrado; manga do árbitro; braço fechado de tatuagem.
		var flex := clampf(1.0 - sh.distance_to(wr) / ((L_UARM + L_FARM) * Uh), 0.0, 1.0)
		var ink := Color(0.1, 0.12, 0.17)
		for i in _tt.size():
			var t := _tt[i]
			if t > 0.35 and t < 1.15:
				_fr[i] += Uh * 0.05 * flex * sin(PI * (t - 0.35) / 0.8)
			if is_ref:
				if t <= 0.75:
					_cl[i] = shirt
					_fr[i] *= 1.12
					_bk[i] *= 1.12
			elif tattoo >= 3 and near and t > 0.12 and t <= 2.25:
				_cl[i] = sk.lerp(ink, 0.4)
	_emit(side, dim, 0.55 if near else 0.0, maxf(1.0, Uh * 0.03))
	var fd := (wr - el).normalized()
	var fn := Vector2(fd.y, -fd.x) * dir
	if _ol <= 0.0 and not is_ref and near:
		# Divisa do deltoide e do bíceps com o tríceps.
		var mc := Color(sk.r * 0.42, sk.g * 0.33, sk.b * 0.36, 0.34 * _def())
		var lw := maxf(1.0, Uh * 0.035)
		_pl(PackedVector2Array([_at(0.34, 0.82), _at(0.5, 0.2), _at(0.44, -0.55)]), mc, lw)
		_pl(PackedVector2Array([_at(0.56, -0.12), _at(0.9, -0.2), _at(1.2, -0.1)]), mc, lw)
		_pl(PackedVector2Array([_at(1.5, 0.25), _at(1.85, 0.05), _at(2.3, 0.0)]), Color(mc, mc.a * 0.7), lw)
	if is_ref:
		# Mão do árbitro com luva de látex azul.
		_cov(wr + fd * Uh * 0.17, fd * Uh * 0.22, fn * Uh * 0.13, 10, _tone(Color("#8DB6DA"), dim))
		return
	# Luva de MMA: faixa do córner no punho, almofada nos nós dos dedos, dedos e polegar de fora.
	var gc := glove.lerp(Color(0.42, 0.03, 0.03), clampf(glove_blood, 0.0, 0.8) * 0.6)
	gc = _tone(gc, dim)
	var cuff := _tone(corner, dim * 0.95)
	_cquad(PackedVector2Array([wr - fd * Uh * 0.2 + fn * Uh * 0.2, wr + fd * Uh * 0.03 + fn * Uh * 0.22, wr + fd * Uh * 0.03 - fn * Uh * 0.21, wr - fd * Uh * 0.2 - fn * Uh * 0.19]), cuff)
	_cov(wr + fd * Uh * 0.3 - fn * Uh * 0.15, fd * Uh * 0.17, fn * Uh * 0.11, 8, _tone(sk, dim * 0.78))
	_cov(wr + fd * Uh * 0.26 + fn * Uh * 0.02, fd * Uh * 0.28, fn * Uh * 0.24, 12, gc)
	if _ol <= 0.0:
		_ov(wr + fd * Uh * 0.34 + fn * Uh * 0.08, fd * Uh * 0.14, fn * Uh * 0.12, 10, gc.lightened(0.16))
		_ov(wr + fd * Uh * 0.1 + fn * Uh * 0.2, fd * Uh * 0.13, fn * Uh * 0.075, 8, _tone(sk, dim * 0.9))


## Definição muscular: some com barriga, é mais leve nas mulheres e cresce com o braço forte.
func _def() -> float:
	return clampf(1.0 - belly * 1.6, 0.0, 1.0) * (0.6 if fem else 1.0) * (0.75 + 0.5 * clampf((arm_k - 0.85) / 0.5, 0.0, 1.0))


func _leg(j: Dictionary, side: String, off: Vector2, sk: Color, dim: float, Uh: float) -> void:
	var hip: Vector2 = (j["hip"] as Vector2) + off
	var kn: Vector2 = (j[side + "_kn"] as Vector2) + off * 0.3
	var an: Vector2 = j[side + "_an"]
	var toe: Vector2 = j[side + "_toe"]
	var is_ref := outfit == "ref"
	var near := dim >= 1.0
	var col := shorts if is_ref else sk
	if not _load(side):
		_limb_rows(hip, kn, an, _leg_p, L_THIGH, L_SHIN, Uh, col)
		# Panturrilha e coxa contraem com o joelho dobrado.
		var flex := clampf(1.0 - hip.distance_to(an) / ((L_THIGH + L_SHIN) * Uh), 0.0, 1.0)
		if not is_ref:
			for i in _tt.size():
				var t := _tt[i]
				if t > 2.0 and t < 3.0:
					_bk[i] += Uh * 0.05 * flex * sin(PI * (t - 2.0))
				elif t > 0.3 and t < 1.6:
					_bk[i] += Uh * 0.04 * flex * sin(PI * (t - 0.3) / 1.3)
	_emit(side, dim, 0.5 if near else 0.0, maxf(1.0, Uh * 0.03))
	if _ol <= 0.0 and not is_ref and near:
		var mc := Color(sk.r * 0.42, sk.g * 0.33, sk.b * 0.36, 0.3 * _def())
		var lw := maxf(1.0, Uh * 0.035)
		# Quadríceps (vasto de fora), rótula e a divisa da panturrilha.
		_pl(PackedVector2Array([_at(1.0, 0.35), _at(1.35, 0.3), _at(1.62, 0.5)]), mc, lw)
		_pl(PackedVector2Array([_at(1.7, 0.75), _at(1.86, 0.35), _at(2.02, 0.7)]), mc, lw)
		_pl(PackedVector2Array([_at(2.15, -0.2), _at(2.6, -0.3), _at(3.0, -0.1)]), Color(mc, mc.a * 0.8), lw)
	if _ol <= 0.0 and not is_ref and leg_dmg > 0.1 and side.begins_with(lead()):
		# Coxa castigada pelos chutes baixos: vermelhão que cresce e escurece.
		var along := (kn - hip).normalized() * Uh
		var across := Vector2(-along.y, along.x)
		var da := clampf((leg_dmg - 0.1) * 0.8, 0.0, 0.6) * (1.0 if near else 0.75)
		_ov(_at(1.05, 0.15), along * (0.36 + 0.2 * leg_dmg), across * (0.2 + 0.08 * leg_dmg), 12, Color(0.78, 0.14, 0.12, da * 0.75))
		if leg_dmg > 0.5:
			_ov(_at(1.15, 0.25), along * 0.22, across * 0.13, 10, Color(0.42, 0.08, 0.2, (leg_dmg - 0.5) * 0.9 * (1.0 if near else 0.75)))
	# Pé: calcanhar, peito do pé e dedos.
	var f := (toe - an).normalized()
	if f == Vector2.ZERO:
		f = Vector2(dir, 0)
	var upv := Vector2(-f.y, f.x)
	if upv.dot(kn - an) < 0.0:
		upv = -upv
	var fk := Uh * (0.95 + 0.1 * leg_k) * (1.12 if is_ref else 1.0)
	var fcol := Color(0.07, 0.07, 0.08) if is_ref else sk
	# Calcanhar levantado com a ponta na lona: o pé dobra na bola e os dedos ficam deitados.
	var gy := float(j.get("gy", an.y))
	var bent := gy - an.y > Uh * 0.1 and gy - toe.y < Uh * 0.08 and f.x * dir > 0.3 and upv.y < 0.0
	if not _load(side + "p"):
		_begin()
		for row: Array in FOOT_TAB:
			var fx := float(row[0])
			if bent and fx > 0.4:
				var ball := an + f * (0.4 * fk)
				_row(Vector2(ball.x + dir * (fx - 0.4) * fk, gy - float(row[1]) * fk * 0.9), Vector2(0, -1), float(row[2]) * fk, float(row[3]) * fk, fcol)
			else:
				_row(an + f * (fx * fk) + upv * (float(row[1]) * fk), upv, float(row[2]) * fk, float(row[3]) * fk, fcol)
	_emit(side + "p", dim, 0.4 if near else 0.0, maxf(1.0, Uh * 0.03))


## Perna do calção: mais larga que a coxa, com barra na cor do detalhe e listra lateral.
func _shorts_leg(j: Dictionary, side: String, off: Vector2, dim: float, Uh: float) -> void:
	if outfit == "ref":
		return
	var hip: Vector2 = (j["hip"] as Vector2) + off
	var kn: Vector2 = (j[side + "_kn"] as Vector2) + off * 0.3
	var d := (kn - hip).normalized()
	if d == Vector2.ZERO:
		d = Vector2(0, 1)
	var n := Vector2(d.y, -d.x) * dir
	var ts: PackedFloat32Array = _leg_p[0]
	var fr: PackedFloat32Array = _leg_p[1]
	var bk: PackedFloat32Array = _leg_p[2]
	var seg := (kn - hip) / L_THIGH
	if not _load(side + "c"):
		_begin()
		var cut: Array = [[-0.14, 1.04, 0], [0.12, 1.1, 0], [0.45, 1.14, 0], [0.8, 1.2, 0], [0.9, 1.23, 0], [0.9, 1.23, 1], [0.98, 1.25, 1]]
		if fem:
			# Shorts justo das lutadoras, até o alto da coxa
			cut = [[-0.14, 1.03, 0], [0.12, 1.04, 0], [0.36, 1.05, 0], [0.52, 1.05, 0], [0.52, 1.06, 1], [0.6, 1.06, 1]]
		for row: Array in cut:
			var t := float(row[0])
			var i := 0
			while i < ts.size() - 2 and ts[i + 1] < t:
				i += 1
			var k := clampf((t - ts[i]) / maxf(0.0001, ts[i + 1] - ts[i]), 0.0, 1.0)
			var g := float(row[1]) * Uh
			var pad := (0.012 if fem else 0.025) * Uh
			_row(hip + seg * t, n, lerpf(fr[i], fr[i + 1], k) * g + pad, lerpf(bk[i], bk[i + 1], k) * g + pad, trim if int(row[2]) == 1 else shorts, t)
	_emit(side + "c", dim, 0.45 if dim >= 1.0 else 0.0, maxf(1.0, Uh * 0.03))
	if _ol <= 0.0 and dim >= 1.0:
		_ln(_at(-0.1, -0.12), _at(0.5 if fem else 0.88, -0.15), Color(trim, 0.85), maxf(1.0, Uh * 0.09))


func _neck(j: Dictionary, sk: Color, tn: Vector2, Uh: float) -> void:
	var neck: Vector2 = j["neck"]
	var c: Vector2 = j["head"]
	var hip: Vector2 = j["hip"]
	var tdir := (neck - hip).normalized()
	var hd := (c - neck).normalized()
	var hn := Vector2(-hd.y, hd.x) * dir
	var k := Uh * neck_k
	if not _load("pesc"):
		_begin()
		_row(neck - tdir * Uh * 0.2, tn, 0.29 * k, 0.33 * k, sk)
		_row(neck + hd * Uh * 0.1, (tn + hn).normalized(), 0.25 * k, 0.29 * k, sk)
		_row(neck + hd * Uh * 0.52, hn, 0.23 * k, 0.27 * k, sk)
	_emit("pesc", 0.88)


## Tronco: perfil do 3D de lado, com as faixas de roupa e a musculatura que aparece conforme o
## giro. `open` > 0: peito virado para a câmera; < 0: costas.
func _torso(j: Dictionary, sk: Color, tdir: Vector2, tn: Vector2, open: float, Uh: float) -> void:
	var hip: Vector2 = j["hip"]
	var is_ref := outfit == "ref"
	var zc := [shorts, shirt.lightened(0.1) if is_ref else trim, sk, shorts.darkened(0.15), shirt]
	if not _load("tronco"):
		_begin()
		for row: Array in _tor_p:
			var y := float(row[0])
			_row(hip + tdir * (y * Uh), tn, float(row[1]) * Uh, float(row[2]) * Uh, zc[int(row[3])], y)
	_emit("tronco", 1.0)
	if _ol > 0.0:
		return
	var lw := maxf(1.0, Uh * 0.04)
	if is_ref:
		# Botões e gola da camisa.
		_ln(_at(2.5, 0.75), _at(0.55, 0.8), Color(shirt.lightened(0.16), 0.7), lw)
		return
	# Listra lateral do calção.
	_ln(_at(0.36, -0.12), _at(-0.3, -0.12), Color(trim, 0.85), maxf(1.0, Uh * 0.09))
	var def := _def()
	var uc := 0.92 - 0.75 * open
	if fem:
		# Alças do top.
		var strap := _tone(shorts.darkened(0.15), 0.9)
		_ln(_at(2.19, 0.4), _at(2.5, 0.15), strap, maxf(1.5, Uh * 0.09))
		_ln(_at(2.19, -0.45), _at(2.5, -0.2), strap, maxf(1.5, Uh * 0.09))
	var mc := Color(sk.r * 0.42, sk.g * 0.33, sk.b * 0.36, 0.42 * def)
	var soft := Color(mc, mc.a * 0.65)
	if not fem:
		# Peitoral de cá (e o de lá, quando o peito está aberto para a câmera).
		_pl(PackedVector2Array([_at(1.75, minf(uc, 0.97)), _at(1.66, clampf(uc - 0.3, -0.9, 0.95)), _at(1.71, clampf(uc - 0.62, -0.9, 0.95)), _at(1.93, clampf(uc - 0.9, -0.92, 0.9))]), mc, lw)
		if uc < 0.9:
			_pl(PackedVector2Array([_at(1.75, uc), _at(1.68, minf(0.97, uc + 0.28)), _at(1.75, minf(1.0, uc + 0.5))]), mc, lw)
		_ov(_at(1.95, clampf(uc - 0.42, -0.6, 0.7)), tn * Uh * 0.2, tdir * Uh * 0.15, 10, Color(1.0, 0.95, 0.88, 0.07 + 0.05 * def))
	if uc < 0.97:
		# Linha do meio, gomos e umbigo.
		_pl(PackedVector2Array([_at(1.74, uc), _at(1.2, uc), _at(0.6, uc * 0.98)]), soft, lw)
		if belly < 0.3:
			var ab := Color(mc, mc.a * 0.5)
			for y: float in [1.42, 1.16, 0.9]:
				_ln(_at(y, maxf(-0.3, uc - 0.27)), _at(y - 0.02, uc - 0.05), ab, lw)
				if uc < 0.88:
					_ln(_at(y - 0.02, uc + 0.05), _at(y, minf(0.96, uc + 0.27)), ab, lw)
		_dot(_at(0.72, uc * 0.98), maxf(1.0, Uh * 0.03), Color(mc, minf(0.6, mc.a * 1.4)))
		_ln(_at(2.38, minf(0.9, uc)), _at(2.44, uc - 0.5), soft, lw)
	# Oblíquo / costela.
	_pl(PackedVector2Array([_at(1.5, clampf(uc - 0.42, -0.85, 0.9)), _at(1.0, clampf(uc - 0.36, -0.85, 0.9)), _at(0.55, clampf(uc - 0.2, -0.8, 0.9))]), soft, lw)
	if body_dmg > 0.12:
		# Costela marcada pelos golpes no corpo.
		var ba := clampf((body_dmg - 0.12) * 0.7, 0.0, 0.5)
		var bu := clampf(uc - 0.4, -0.75, 0.75)
		_ov(_at(1.22, bu), tn * Uh * (0.24 + 0.1 * body_dmg), tdir * Uh * (0.34 + 0.12 * body_dmg), 12, Color(0.78, 0.14, 0.12, ba * 0.75))
		if body_dmg > 0.55:
			_ov(_at(1.3, bu), tn * Uh * 0.14, tdir * Uh * 0.2, 10, Color(0.42, 0.08, 0.2, (body_dmg - 0.55) * 0.8))
	if uc > 1.05:
		# De costas para a câmera: dorsal e escápula.
		_pl(PackedVector2Array([_at(1.98, -0.2), _at(1.45, -0.58), _at(0.95, -0.7)]), mc, lw)
		_pl(PackedVector2Array([_at(2.22, -0.42), _at(1.98, -0.62), _at(1.76, -0.48)]), soft, lw)
		_pl(PackedVector2Array([_at(2.3, -0.9), _at(1.4, -0.93), _at(0.6, -0.9)]), soft, lw)
	if tattoo > 0:
		# Tatuagem no peito (ou na escápula, de costas): desenho em traço.
		var tc := Color(0.07, 0.09, 0.14, 0.55)
		var tu := clampf(uc - 0.45, -0.55, 0.6) if uc <= 1.05 else -0.5
		var tp := _at(2.0, tu)
		var tl := maxf(1.0, Uh * 0.035)
		match int(face.get("tattoo_seed", face.get("hair_seed", 0))) % 3:
			0:
				_arc(tp, Uh * 0.17, 0.5, 3.9, 9, tc, tl)
				_arc(tp, Uh * 0.1, 3.4, 6.6, 7, tc, tl)
				_ln(tp - tdir * Uh * 0.2, tp + tdir * Uh * 0.2, tc, tl)
				_ln(tp - tn * Uh * 0.12 + tdir * Uh * 0.1, tp + tn * Uh * 0.12 + tdir * Uh * 0.1, tc, tl)
			1:
				for q in 3:
					var o := tdir * Uh * (0.14 - 0.12 * float(q))
					_pl(PackedVector2Array([tp + o - tn * Uh * 0.18, tp + o - tdir * Uh * 0.09, tp + o + tn * Uh * 0.18]), tc, tl)
			_:
				_arc(tp, Uh * 0.09, 0.0, TAU, 9, tc, tl)
				for q in 8:
					var rv := Vector2.RIGHT.rotated(TAU * float(q) / 8.0)
					_ln(tp + rv * Uh * 0.13, tp + rv * Uh * 0.21, tc, tl)
		if tattoo >= 2:
			# Escrita nas costelas.
			for q in 4:
				var ty := 1.42 - 0.11 * float(q)
				_ln(_at(ty, clampf(tu - 0.3, -0.8, 0.45)), _at(ty - 0.03, clampf(tu - 0.02 - 0.05 * float(q % 2), -0.8, 0.7)), Color(tc, 0.42), tl)
	if cut > 0.8:
		_ln(_at(2.4, minf(0.8, uc)), _at(1.75, minf(0.9, uc + 0.1)), Color(0.55, 0.03, 0.03, clampf(cut - 0.7, 0.0, 0.7)), maxf(1.0, Uh * 0.1))


static func _skull(deg: float) -> Vector2:
	var a := deg_to_rad(deg)
	return Vector2(0.97 * cos(a) - 0.02, sin(a))


## Sombra embaixo da maçã do rosto e da mandíbula.
const JAW_SHADE := [Vector2(0.72, -0.2), Vector2(0.3, -0.36), Vector2(-0.02, -0.2), Vector2(-0.1, -0.6), Vector2(0.12, -0.78), Vector2(0.5, -0.95), Vector2(0.62, -0.7)]


## Cabeça, cabelo e barba de perfil, uma vez por lutador, já no formato da malha.
func _prep_head() -> void:
	_prep_head_shapes()
	var o := 0.065 / R_HEAD
	_hp_fan = PackedVector2Array()
	for i in _hp.size() + 1:
		_hp_fan.append(Vector2.ZERO)
		_hp_fan.append(_hp[i % _hp.size()])
	_hp_ring = _ring_rows(_hp, o)
	_jaw_tri = _tri_rows(PackedVector2Array(JAW_SHADE))
	_main_tri = _tri_rows(_hair_main)
	_main_ring = _ring_rows(_hair_main, o)
	_main_hi = PackedVector2Array()
	if not _main_tri.is_empty():
		# Brilho no alto do cabelo.
		var hk := 1.0 + float(hair_shape.get("top", 0.1)) * 0.55
		for d: float in [70.0, 88.0, 106.0, 124.0]:
			_main_hi.append(_skull(d) * hk)
	_side_tri = _tri_rows(_hair_side)
	_hang_tri = _tri_rows(_hair_hang)
	_hang_ring = _ring_rows(_hair_hang, o)
	_skin_tri = _tri_rows(_hair_skin)
	_beard_tri = _tri_rows(_beard_p)


func _prep_head_shapes() -> void:
	var p := PackedVector2Array(HEAD_PTS)
	var nl := clampf((float(face.get("nose_len", 0.305)) - 0.305) / 0.045, -1.0, 1.0)
	var br := clampf(float(face.get("bridge", 0.8)) - 0.8, -0.5, 0.5)
	var rd := clampf(float(face.get("ridge", 0.9)) - 0.9, -0.4, 0.5)
	var jw := clampf((float(face.get("jaw", 0.79)) - 0.79) / 0.11, -1.0, 1.0)
	var fat := clampf(float(face.get("fat", 0.2)), 0.0, 1.0)
	var lip := clampf((float(face.get("lip_l", 0.06)) - 0.06) / 0.03, -1.0, 1.5)
	var soft := 1.0 if fem else 0.0
	p[4] += Vector2(0.035 * rd - 0.02 * soft, 0)
	p[6] += Vector2(0.05 * br, 0)
	p[7] += Vector2(0.05 * nl + 0.03 * br - 0.03 * soft, -0.03 * nl)
	p[8] += Vector2(0.02 * nl, 0)
	p[10] += Vector2(0.03 * lip, 0)
	p[11] += Vector2(0.035 * lip, 0)
	p[13] += Vector2(0.03 * jw - 0.03 * soft, 0)
	p[14] += Vector2(0.02 * jw, -0.03 * jw - 0.04 * fat)
	p[15] += Vector2(0, -0.05 * fat - 0.02 * jw)
	p[16] += Vector2(0, -0.07 * fat - 0.03 * jw)
	p[17] += Vector2(-0.05 * jw, -0.06 * jw - 0.03 * fat)
	_hp = p
	# Barba: acompanha a mandíbula; a média e a longa descem do queixo.
	_beard_p = PackedVector2Array()
	if beard_kind == HairShape.BD_GOATEE:
		_beard_p = PackedVector2Array([Vector2(0.74, -0.46), p[9], p[10], p[11], p[12], p[13] + Vector2(0.02, 0), p[14] + Vector2(0.02, -0.08), Vector2(0.52, -0.98), Vector2(0.62, -0.68)])
	elif beard_kind == HairShape.BD_STUBBLE or beard_kind >= HairShape.BD_SHORT:
		var ext := 0.0
		if beard_kind == HairShape.BD_MEDIUM:
			ext = 0.16
		elif beard_kind == HairShape.BD_LONG:
			ext = 0.52
		_beard_p = PackedVector2Array([Vector2(0.26, -0.2), Vector2(0.6, -0.36), Vector2(0.9, -0.43), p[9], p[10], p[11], p[12] + Vector2(0.02 + ext * 0.1, 0),
			p[13] + Vector2(0.02 + ext * 0.08, -ext * 0.5), p[14] + Vector2(-ext * 0.1, -ext), p[15] + Vector2(-ext * 0.15, -ext * 0.8), p[16] + Vector2(0, -ext * 0.3), p[17] + Vector2(-0.02, -0.02), Vector2(-0.06, -0.2)])
	# Cabelo.
	_hair_main = PackedVector2Array()
	_hair_side = PackedVector2Array()
	_hair_hang = PackedVector2Array()
	_hair_skin = PackedVector2Array()
	_hair_balls = []
	_hair_strands = []
	var hs := hair_shape
	if hs.is_empty() or bool(hs["bald"]):
		return
	var top := float(hs["top"])
	var side := float(hs["side"])
	var back := float(hs["back"])
	var front := float(hs["front"])
	var lifted := float(hs["lift"]) > 0.0
	var ridge := bool(hs["ridge"])
	var curly := bool(hs["curly"]) or bool(hs["strands"])
	var rec := clampf(float(face.get("recession", 0.0)), 0.0, 1.0)
	var full := side >= 0.03 and not ridge
	var a0 := 40.0 + 9.0 * rec - 16.0 * front
	var a1 := 206.0 if full else 168.0
	if ridge:
		a0 = 38.0
		a1 = 184.0
	var seed_f := float(int(face.get("hair_seed", 7)) % 100) * 0.1
	var deg := a0
	var outer := PackedVector2Array()
	while true:
		var th := side
		if ridge:
			th = top * pow(sin(PI * clampf((deg - a0) / (a1 - a0), 0.04, 0.96)), 0.6)
		elif deg <= 115.0:
			var ff := clampf((deg - a0) / maxf(1.0, 90.0 - a0), 0.0, 1.0)
			th = top * (lerpf(1.3, 1.0, ff) if lifted else lerpf(0.55, 1.0, ff))
		elif deg <= 150.0:
			th = lerpf(top, side, (deg - 115.0) / 35.0)
		else:
			th = side * lerpf(1.0, 0.5, (deg - 150.0) / maxf(1.0, a1 - 150.0))
		if curly:
			th *= 1.0 + 0.2 * sin(deg * 0.33 + seed_f)
		var sp := _skull(deg)
		outer.append(sp + sp.normalized() * maxf(0.012, th))
		if deg >= a1:
			break
		deg = minf(a1, deg + 8.0)
	_hair_main = outer.duplicate()
	var side_line := [Vector2(-0.5, -0.44), Vector2(-0.3, -0.12), Vector2(-0.15, 0.24), Vector2(0.06, 0.27), Vector2(0.12, 0.0), Vector2(0.24, 0.04), Vector2(0.33, 0.38), Vector2(0.6, 0.5 - 0.2 * front)]
	if ridge:
		var d2 := a1
		while d2 >= a0:
			_hair_main.append(_skull(d2) * 0.97)
			d2 -= 12.0
	elif full:
		_hair_main.append_array(PackedVector2Array(side_line))
	else:
		_hair_main.append_array(PackedVector2Array([Vector2(-0.8, 0.42), Vector2(-0.3, 0.55), Vector2(0.3, 0.58), Vector2(0.62, 0.56)]))
	if not full:
		# Laterais raspadas: só uma sombra de cabelo rente.
		var d3 := 44.0
		while d3 <= 206.0:
			_hair_side.append(_skull(d3) * 0.985)
			d3 += 12.0
		_hair_side.append_array(PackedVector2Array(side_line))
	# Coroa calva (entradas da idade): pele no alto, cabelo só em volta.
	if float(face.get("crown", 0.0)) > 0.5 and not ridge and top < 0.2:
		for d4: float in [150.0, 130.0, 110.0, 90.0, 70.0, 56.0]:
			_hair_skin.append(_skull(d4) * 1.0)
		_hair_skin.append_array(PackedVector2Array([Vector2(0.4, 0.52), Vector2(-0.1, 0.5), Vector2(-0.62, 0.42)]))
	if back >= 0.2 and not bool(hs["strands"]):
		_hair_hang = PackedVector2Array([Vector2(-0.3, 0.35), Vector2(-1.0 - side, 0.2), Vector2(-1.04 - side * 0.6, -0.25 - back * 0.55), Vector2(-0.8, -0.42 - back),
			Vector2(-0.3, -0.4 - back * 0.85), Vector2(-0.1, -0.3)])
	if bool(hs["strands"]):
		var n := 7
		for i in n:
			var sp2 := _skull(96.0 + 104.0 * float(i) / float(n - 1)) * (1.0 + side * 0.5)
			var ln := 0.35 + back * (0.75 + 0.25 * sin(float(i) * 2.3 + seed_f))
			_hair_strands.append([sp2, sp2 + Vector2(-0.1 + 0.05 * sin(float(i) * 1.7), -ln)])
	match int(hs["bun"]):
		HairShape.BUN_TOP:
			_hair_balls.append([_skull(120.0) * (1.24 if not bool(hs["curly"]) else 1.34), 0.25 if not bool(hs["curly"]) else 0.42])
		HairShape.BUN_LOW:
			_hair_balls.append([Vector2(-1.0, -0.22), 0.24])
		HairShape.BUN_PUFFS:
			_hair_balls.append([_skull(72.0) * 1.28, 0.3])
			_hair_balls.append([_skull(128.0) * 1.3, 0.34])
		HairShape.BUN_TAIL:
			_hair_hang = PackedVector2Array([Vector2(-0.8, 0.56), Vector2(-1.2, 0.5), Vector2(-1.38, 0.0), Vector2(-1.3, -0.6), Vector2(-1.12, -0.8), Vector2(-1.08, -0.2), Vector2(-0.9, 0.2)])


func _head(j: Dictionary, Uh: float, sk: Color) -> void:
	var c: Vector2 = j["head"]
	var neck: Vector2 = j["neck"]
	var r := R_HEAD * Uh
	var up := (c - neck).normalized()
	var fw := Vector2(-up.y, up.x) * dir
	var X := fw * r
	var Y := up * r
	var T := Transform2D(X, Y, c)
	var hcol := hair
	var long_hair := not _hair_hang.is_empty() or not _hair_strands.is_empty() or float(hair_shape.get("side", 0.0)) >= 0.2
	if not _hang_tri.is_empty():
		if _ol > 0.0:
			_push_flat(T * _hang_ring, OL_COL)
		else:
			_push_flat(T * _hang_tri, hcol.darkened(0.14))
	if _ol > 0.0:
		_push_flat(T * _hp_ring, OL_COL)
		if not _main_tri.is_empty():
			_push_flat(T * _main_ring, OL_COL)
		for b: Array in _hair_balls:
			_cdot(T * (b[0] as Vector2), float(b[1]) * r, hcol)
		return
	# Pele com a luz de cima: testa clara, embaixo do queixo e nuca mais escuros.
	var fan := T * _hp_fan
	var m := fan.size()
	var cols := PackedColorArray()
	cols.resize(m)
	var mid := _tone(sk, 0.9)
	var i := 0
	while i < m:
		var o := (fan[i + 1] - c) / r
		cols[i] = mid
		cols[i + 1] = _tone(sk, 0.9 - 0.17 * o.y - 0.05 * o.x)
		i += 2
	_push(fan, cols, _flat_uv(m))
	var dk := Color(sk.r * 0.42, sk.g * 0.33, sk.b * 0.36)
	_push_flat(T * _jaw_tri, Color(dk, 0.14))
	if not _side_tri.is_empty():
		_push_flat(T * _side_tri, Color(hcol, 0.34))
	var ear_c := c - X * 0.1 - Y * 0.03
	var ecol := _tone(sk, 0.84)
	if float(face.get("cauli", 0.0)) > 0.5:
		ecol = ecol.lerp(Color(0.62, 0.3, 0.28), 0.35)
	# Barba.
	if not _beard_tri.is_empty():
		_push_flat(T * _beard_tri, Color(beard, 0.3 if beard_kind == HairShape.BD_STUBBLE else 0.92))
	if beard_kind == HairShape.BD_MUSTACHE or beard_kind == HairShape.BD_GOATEE:
		_ln(c + X * 0.99 - Y * 0.4, c + X * 0.72 - Y * 0.45, beard, maxf(1.0, r * 0.11))
	# Cabelo por cima do crânio, com um brilho no alto.
	if not _main_tri.is_empty():
		_push_flat(T * _main_tri, hcol)
		_pl(T * _main_hi, Color(hcol.lightened(0.25), 0.5), maxf(1.0, r * 0.07))
	if not _skin_tri.is_empty():
		_push_flat(T * _skin_tri, _tone(sk, 1.03))
	for b: Array in _hair_balls:
		var bc := T * (b[0] as Vector2)
		var br := float(b[1]) * r
		_dot(bc, br, hcol)
		_dot(bc + Vector2(-0.2, -0.3) * br, br * 0.45, Color(hcol.lightened(0.2), 0.45))
	if not long_hair:
		_ov(ear_c, X * 0.13 - Y * 0.03, Y * 0.24 + X * 0.03, 10, ecol)
		_ln(ear_c + Y * 0.12 + X * 0.03, ear_c - Y * 0.12, Color(dk, 0.5), maxf(1.0, r * 0.05))
	for q in _hair_strands.size():
		var st: Array = _hair_strands[q]
		_ln(T * (st[0] as Vector2), T * (st[1] as Vector2), hcol.darkened(0.12) if q % 2 == 0 else hcol.lightened(0.06), maxf(1.5, r * 0.17))
	if bool(face.get("headband", false)) and not bald:
		_ln(c + X * 0.86 + Y * 0.5, c - X * 0.95 + Y * 0.38, corner, maxf(1.5, r * 0.14))
	# Sobrancelha, olho e boca.
	var e := c + X * 0.6 + Y * 0.1
	if fem:
		# Lutadora: blush, sobrancelha fina e arqueada, cílios e a boca com cor
		_ov(c + X * 0.5 - Y * 0.2, X * 0.2, Y * 0.12, 8, Color(0.92, 0.42, 0.44, 0.1 + 0.16 * float(face.get("blush", 0.4))))
		_pl(PackedVector2Array([c + X * 0.9 + Y * 0.25, c + X * 0.66 + Y * 0.34, c + X * 0.4 + Y * 0.27]), Color(beard.darkened(0.2), 0.95), maxf(1.0, r * 0.065))
	else:
		_ln(c + X * 0.44 + Y * 0.3, c + X * 0.87 + Y * 0.25, Color(beard.darkened(0.2), 0.95), maxf(1.0, r * 0.09))
	if ko:
		_ln(e - X * 0.12, e + X * 0.14, Color(0.08, 0.06, 0.05), maxf(1.0, r * 0.08))
	else:
		if r >= 9.0:
			_ov(e + X * 0.02, X * 0.14, Y * 0.08, 8, Color(0.93, 0.92, 0.9))
		_dot(e + X * 0.07, maxf(1.0, r * 0.075), Color(0.08, 0.06, 0.05))
		if fem:
			# Delineado: da frente do olho até o canto de trás, subindo
			_pl(PackedVector2Array([e + X * 0.17 + Y * 0.06, e + X * 0.02 + Y * 0.1, e - X * 0.14 + Y * 0.07, e - X * 0.25 + Y * 0.15]), Color(0.07, 0.05, 0.05, 0.95), maxf(1.0, r * 0.055))
	if fem:
		var lipc := _tone(sk, 0.9).lerp(Color(0.72, 0.3, 0.33), 0.5).lerp(face.get("lip_tint", Color(0.72, 0.3, 0.33)) as Color, float(face.get("lip_tint_k", 0.3)))
		_ov(T * Vector2(0.9, -0.51), X * 0.1, Y * 0.085, 8, lipc)
	_ln(T * _hp[10] - X * 0.02, c + X * 0.72 - Y * 0.5, Color(dk, 0.85), maxf(1.0, r * (0.045 if fem else 0.06)))
	_ln(T * _hp[8], c + X * 0.86 - Y * 0.3, Color(dk, 0.5), maxf(1.0, r * 0.05))
	# Olho inchado, nariz sangrando e corte.
	if bruise > 0.25:
		_dot(e + X * 0.02, r * (0.22 + 0.12 * bruise), Color(0.38, 0.12, 0.2, clampf((bruise - 0.25) * 0.7, 0.0, 0.5)))
	if bruise > 0.6:
		_ln(c + X * 0.98 - Y * 0.32, c + X * 0.92 - Y * (0.48 + 0.3 * bruise), Color(0.6, 0.03, 0.03, 0.85), maxf(1.0, r * 0.14))
	if cut > 0.2:
		var bl := Color(0.62, 0.04, 0.04, clampf(0.35 + cut * 0.45, 0.0, 0.95))
		var top := c + X * 0.6 + Y * 0.4
		_dot(top, r * 0.12, bl)
		_ln(top, c + X * 0.74 - Y * (0.2 + 0.5 * minf(cut, 1.0)), bl, maxf(1.0, r * (0.12 + 0.1 * cut)))
		if cut > 0.7:
			_ln(top - X * 0.2, c + X * 0.38 - Y * 0.9, Color(bl, bl.a * 0.8), maxf(1.0, r * 0.1))


# --- Malha única ---------------------------------------------------------------------------
# O lutador inteiro vai para uma malha só. Cada peça entra como uma fita de linhas de dois
# vértices (frente e trás) e é emendada na anterior por uma linha sem área, que a placa de vídeo
# descarta. Assim cada lutador é uma única chamada de desenho por quadro, em vez de mais de cem
# pedaços com um buffer cada, o que pesa no celular.

## Meia largura da borda suave das linhas, em pixels da tela do jogo.
const FEATHER := 1.25


static func _flat_uv(n: int) -> PackedVector2Array:
	var got: Variant = _flat_uvs.get(n)
	if got != null:
		return got
	var u := PackedVector2Array()
	u.resize(n)
	u.fill(UV_FLAT)
	_flat_uvs[n] = u
	return u


## Emenda: repete o último vértice e o primeiro da peça nova.
func _join(first: Vector2) -> void:
	var n := _mp.size()
	if n > 0:
		_mp.append(_mp[n - 1])
		_mp.append(first)
		_mc.resize(n + 2)
		_mu.resize(n + 2)


func _push(pts: PackedVector2Array, cols: PackedColorArray, uvs: PackedVector2Array) -> void:
	if pts.is_empty():
		return
	_join(pts[0])
	_mp.append_array(pts)
	_mc.append_array(cols)
	_mu.append_array(uvs)


func _push_flat(pts: PackedVector2Array, col: Color) -> void:
	var m := pts.size()
	if m == 0:
		return
	_join(pts[0])
	_mp.append_array(pts)
	var cc := PackedColorArray()
	cc.resize(m)
	cc.fill(col)
	_mc.append_array(cc)
	_mu.append_array(_flat_uv(m))


func _flush(ci: CanvasItem) -> void:
	var rows := _mp.size() >> 1
	if rows < 2:
		return
	var need := (rows - 1) * 6
	if _strip_idx.size() < need:
		var q0 := _strip_idx.size() / 6
		var q1 := maxi(rows + 512, q0 * 2)
		_strip_idx.resize(q1 * 6)
		for q in range(q0, q1):
			var a := q * 2
			var k := q * 6
			_strip_idx[k] = a
			_strip_idx[k + 1] = a + 1
			_strip_idx[k + 2] = a + 2
			_strip_idx[k + 3] = a + 1
			_strip_idx[k + 4] = a + 3
			_strip_idx[k + 5] = a + 2
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), _strip_idx.slice(0, need), _mp, _mc, _mu, PackedInt32Array(), PackedFloat32Array(), _shading())


## Polígono qualquer (em coordenadas locais) já quebrado em triângulos, no formato de fita.
static func _tri_rows(poly: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	if poly.size() < 3:
		return out
	var tri := Geometry2D.triangulate_polygon(poly)
	if tri.is_empty():
		push_warning("Rig2D: polígono da cabeça não triangulou")
		return out
	var t := 0
	while t + 2 < tri.size():
		var a := poly[tri[t]]
		var c := poly[tri[t + 2]]
		if not out.is_empty():
			out.append(out[out.size() - 1])
			out.append(a)
		out.append(a)
		out.append(poly[tri[t + 1]])
		out.append(c)
		out.append(c)
		t += 3
	return out


## Contorno de um polígono (em coordenadas locais): fita de largura 2·o em cima da borda.
static func _ring_rows(poly: PackedVector2Array, o: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := poly.size()
	if n < 3:
		return out
	for i in n + 1:
		var p := poly[i % n]
		var d := poly[(i + 1) % n] - poly[(i + n - 1) % n]
		var nn := Vector2(-d.y, d.x).normalized() * o
		out.append(p + nn)
		out.append(p - nn)
	return out


## Oval em ziguezague (um lado e o outro), pronto para virar fita.
static func _zigzag(n: int) -> PackedVector2Array:
	var got: Variant = _zig.get(n)
	if got != null:
		return got
	var u := PackedVector2Array()
	for k in n / 2 + 1:
		var a := TAU * float(k) / float(n)
		u.append(Vector2(cos(a), sin(a)))
		u.append(Vector2(cos(a), -sin(a)))
	_zig[n] = u
	return u


func _ov(c: Vector2, ax: Vector2, ay: Vector2, n: int, col: Color) -> void:
	_push_flat(Transform2D(ax, ay, c) * _zigzag(n), col)


func _dot(c: Vector2, r: float, col: Color) -> void:
	_push_flat(Transform2D(Vector2(r, 0), Vector2(0, r), c) * _zigzag(8 if r < 2.5 else (12 if r < 7.0 else 16)), col)


## Linha com borda suave: borda, miolo e borda, numa fita só (vai, volta e vai).
func _ln(a: Vector2, b: Vector2, col: Color, w: float) -> void:
	var d := b - a
	var l := d.length()
	if l < 0.001:
		return
	var nn := Vector2(-d.y, d.x) / l
	var ni := nn * (w * 0.5)
	var no := nn * (w * 0.5 + FEATHER)
	var c0 := Color(col.r, col.g, col.b, 0.0)
	var n := _mp.size()
	if n > 0:
		_mp.append(_mp[n - 1])
		_mp.append(a + no)
		_mc.append(c0)
		_mc.append(c0)
	_mp.append(a + no)
	_mp.append(a + ni)
	_mp.append(b + no)
	_mp.append(b + ni)
	_mp.append(b + ni)
	_mp.append(b - ni)
	_mp.append(a + ni)
	_mp.append(a - ni)
	_mp.append(a - ni)
	_mp.append(a - no)
	_mp.append(b - ni)
	_mp.append(b - no)
	_mc.append(c0)
	_mc.append(col)
	_mc.append(c0)
	_mc.append(col)
	_mc.append(col)
	_mc.append(col)
	_mc.append(col)
	_mc.append(col)
	_mc.append(col)
	_mc.append(c0)
	_mc.append(col)
	_mc.append(c0)
	_mu.append_array(_flat_uv(14 if n > 0 else 12))


## Linha quebrada com borda suave e quina emendada.
func _pl(p: PackedVector2Array, col: Color, w: float) -> void:
	var n := p.size()
	if n < 2:
		return
	if n == 2:
		_ln(p[0], p[1], col, w)
		return
	var hi := w * 0.5
	var ho := hi + FEATHER
	var c0 := Color(col.r, col.g, col.b, 0.0)
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	pts.resize(n * 6)
	cols.resize(n * 6)
	var prev := Vector2.ZERO
	for i in n:
		var q := p[i]
		var sn := prev
		if i < n - 1:
			var d := p[i + 1] - q
			sn = Vector2(-d.y, d.x).normalized()
		var nn := sn
		if i > 0 and i < n - 1:
			nn = (prev + sn).normalized()
			nn /= maxf(0.5, nn.dot(sn))
		prev = sn
		var k := i * 2
		pts[k] = q + nn * ho
		pts[k + 1] = q + nn * hi
		cols[k] = c0
		cols[k + 1] = col
		k = (2 * n - 1 - i) * 2
		pts[k] = q + nn * hi
		pts[k + 1] = q - nn * hi
		cols[k] = col
		cols[k + 1] = col
		k = (2 * n + i) * 2
		pts[k] = q - nn * hi
		pts[k + 1] = q - nn * ho
		cols[k] = col
		cols[k + 1] = c0
	_push(pts, cols, _flat_uv(n * 6))


func _arc(c: Vector2, r: float, a0: float, a1: float, n: int, col: Color, w: float) -> void:
	var pts := PackedVector2Array()
	pts.resize(n)
	for i in n:
		var a := lerpf(a0, a1, float(i) / float(n - 1))
		pts[i] = c + Vector2(cos(a), sin(a)) * r
	_pl(pts, col, w)


# --- Peças com contorno --------------------------------------------------------------------

func _cdot(c: Vector2, r: float, col: Color) -> void:
	if _ol > 0.0:
		if r >= _ol * 2.5 and col.a > 0.8:
			_dot(c, r + _ol * 1.3, OL_COL)
	else:
		_dot(c, r, col)


func _cov(c: Vector2, ax: Vector2, ay: Vector2, n: int, col: Color) -> void:
	if _ol > 0.0:
		if col.a > 0.8:
			var o := _ol * 1.3
			_ov(c, ax + ax.normalized() * o, ay + ay.normalized() * o, n, OL_COL)
	else:
		_ov(c, ax, ay, n, col)


## Quadrilátero dado em volta (p0, p1, p2, p3).
func _cquad(p: PackedVector2Array, col: Color) -> void:
	if _ol > 0.0:
		if col.a > 0.8:
			var mid := (p[0] + p[1] + p[2] + p[3]) * 0.25
			var o := _ol * 1.5
			_push_flat(PackedVector2Array([p[0] + (p[0] - mid).normalized() * o, p[3] + (p[3] - mid).normalized() * o,
				p[1] + (p[1] - mid).normalized() * o, p[2] + (p[2] - mid).normalized() * o]), OL_COL)
	else:
		_push_flat(PackedVector2Array([p[0], p[3], p[1], p[2]]), col)
