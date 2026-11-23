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
## e braços para os lados (0 = normal) e zz tira o corpo todo do plano (para não embolar no chão).

const KEYS := ["x", "y", "crouch", "sit", "rot", "torso", "head", "na_s", "na_e", "fa_s", "fa_e", "nl_h", "nl_k", "fl_h", "fl_k", "lz", "az", "zz"]
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


static func from_fighter(w: GameWorld, f: Fighter, facing: float) -> Rig2D:
	var r := Rig2D.new()
	r.face = FaceGen.features(f.face_seed, f.eth, w.age_of(f), f.look)
	r.skin = r.face["skin"]
	r.hair = r.face.get("hair", Color("#2A1D16"))
	r.beard = r.face.get("beard_col", r.hair)
	r.has_beard = int(r.face.get("beard", 0)) >= 2
	r.bald = int(r.face.get("style", 0)) == FaceGen.H_BALD
	r.fem = f.is_female()
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


## Árbitro: camisa escura, calça cinza, sem luvas; cabeça de alguém comum.
static func referee(rng: RandomNumberGenerator) -> Rig2D:
	var r := Rig2D.new()
	var eth: int = [FaceGen.E_EUR, FaceGen.E_LAT, FaceGen.E_NOR, FaceGen.E_MED, FaceGen.E_AFR][rng.randi() % 5]
	r.face = FaceGen.features(rng.randi(), eth, rng.randi_range(36, 58), {})
	r.skin = r.face["skin"]
	r.hair = r.face.get("hair", Color("#2A1D16"))
	r.beard = r.face.get("beard_col", r.hair)
	r.has_beard = int(r.face.get("beard", 0)) >= 2
	r.bald = int(r.face.get("style", 0)) == FaceGen.H_BALD
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
	for k: String in (["nl_an", "fl_an", "nl_kn", "fl_kn"] if sit else ["nl_an", "fl_an", "nl_toe", "fl_toe", "nl_kn", "fl_kn"]):
		low = maxf(low, (j[k] as Vector2).y - (Uh * 0.2 if sit else 0.0))
	for k: String in ["hip", "neck", "head", "sh"]:
		low = maxf(low, (j[k] as Vector2).y + Uh * 0.35)
	var dy := ground_y - low - float(pose.get("y", 0.0)) * U
	for k: String in j:
		if j[k] is Vector2:
			j[k] = (j[k] as Vector2) + Vector2(0, dy)
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


func _shade(c: Color, k: float) -> Color:
	return c.darkened(k) if k > 0.0 else c.lightened(-k)


## Membro como cápsula: largura w0 no começo e w1 no fim.
static func _capsule(ci: CanvasItem, a: Vector2, b: Vector2, w0: float, w1: float, col: Color, light: Color) -> void:
	var d := (b - a)
	if d.length() < 0.01:
		return
	var n := Vector2(-d.y, d.x).normalized()
	var pts := PackedVector2Array([a + n * w0, b + n * w1, b - n * w1, a - n * w0])
	var lit := n.y < 0.0
	ci.draw_polygon(pts, PackedColorArray([light if lit else col, light if lit else col, col if lit else light, col if lit else light]))
	ci.draw_circle(a, w0, col if not lit else col.lerp(light, 0.5))
	ci.draw_circle(b, w1, col if not lit else col.lerp(light, 0.5))


## `layer`: 0 tudo, 1 tudo menos o braço near, 2 só o braço near (para abraços por trás).
func draw(ci: CanvasItem, origin_x: float, ground_y: float, U: float, layer: int = 0) -> void:
	var j := joints(origin_x, ground_y, U)
	var Uh: float = j["U"]
	var sk := skin.lerp(Color(0.8, 0.22, 0.18), flash * 0.35)
	var far := sk.darkened(0.28)
	var far_l := sk.darkened(0.12)
	var near := sk
	var near_l := sk.lightened(0.12)
	# Sombra no chão
	if layer != 2:
		ci.draw_set_transform(Vector2(j["hip"].x, ground_y), 0.0, Vector2(1.0, 0.22))
		ci.draw_circle(Vector2.ZERO, Uh * 1.6, Color(0, 0, 0, 0.28))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var aw := Uh * 0.3 * arm_k
	var lw := Uh * 0.43 * leg_k
	if layer == 2:
		_arm(ci, j, "na", aw, sk, sk.lightened(0.12), Uh, false)
		return
	# Membros do lado de lá
	_leg(ci, j, "fl", lw, far, far_l, Uh, true)
	_arm(ci, j, "fa", aw, far, far_l, Uh, true)
	# Tronco
	var hip: Vector2 = j["hip"]
	var neck: Vector2 = j["neck"]
	var tdir := (neck - hip).normalized()
	var tn := Vector2(-tdir.y, tdir.x) * dir
	if tn.dot(Vector2(dir, 0)) < 0.0 and absf(tn.x) > 0.3:
		tn = -tn
	var cw := Uh * 0.78 * chest_k
	var ww := Uh * (0.6 + 0.3 * belly) * chest_k
	var chest := neck - tdir * Uh * 0.75
	var waist := hip + tdir * Uh * 0.55
	var tors := PackedVector2Array([neck + tn * cw * 0.5, chest + tn * cw, waist + tn * ww * (1.0 + 0.35 * belly), hip + tn * ww * 0.95,
		hip - tn * ww * 0.95, waist - tn * ww * 0.95, chest - tn * cw * 0.9, neck - tn * cw * 0.55])
	if outfit == "ref":
		ci.draw_polygon(tors, PackedColorArray([shirt.lightened(0.1), shirt.lightened(0.1), shirt, shirt, shirt.darkened(0.2), shirt.darkened(0.2), shirt, shirt.lightened(0.1)]))
		ci.draw_line(neck + tn * cw * 0.3, neck - tn * cw * 0.3, sk, maxf(1.0, Uh * 0.12), true)
		_shorts_leg(ci, j, "fl", lw, shorts.darkened(0.25))
		_head(ci, j, Uh, sk)
		_leg(ci, j, "nl", lw, near, near_l, Uh, false)
		_shorts_leg(ci, j, "nl", lw, shorts)
		if layer == 0:
			_arm(ci, j, "na", aw, near, near_l, Uh, false)
		return
	ci.draw_polygon(tors, PackedColorArray([near_l, near_l, near, near, far_l, far_l, near, near_l]))
	if cut > 0.8:
		ci.draw_line(neck + tn * cw * 0.6, chest + tn * cw * 0.7 - tdir * Uh * 0.6, Color(0.55, 0.03, 0.03, clampf(cut - 0.7, 0.0, 0.7)), maxf(1.0, Uh * 0.1), true)
	# Peitoral, abdômen e costela
	ci.draw_line(chest + tn * cw * 0.95, chest + tn * cw * 0.15 - tdir * Uh * 0.15, Color(sk.darkened(0.35), 0.45), maxf(1.0, Uh * 0.05), true)
	ci.draw_line(chest - tdir * Uh * 0.35 + tn * cw * 0.7, waist + tn * ww * 0.75, Color(sk.darkened(0.3), 0.25), maxf(1.0, Uh * 0.04), true)
	if fem:
		var top := PackedVector2Array([chest + tn * cw * 1.02 + tdir * Uh * 0.3, chest + tn * cw * 1.02 - tdir * Uh * 0.35,
			chest - tn * cw * 0.92 - tdir * Uh * 0.35, chest - tn * cw * 0.92 + tdir * Uh * 0.3])
		ci.draw_colored_polygon(top, shorts.darkened(0.15))
	if tattoo > 0:
		ci.draw_arc(chest + tn * cw * 0.35, Uh * 0.22, 0.0, TAU, 10, Color(0.1, 0.12, 0.17, 0.45), maxf(1.0, Uh * 0.05), true)
	# Calção: cós e as duas pernas do calção por cima das coxas.
	_shorts_leg(ci, j, "fl", lw, shorts.darkened(0.25))
	var t_hip := hip + tdir * Uh * 0.35
	var band := PackedVector2Array([t_hip + tn * ww * 1.05, t_hip - tn * ww * 1.0, hip - tn * ww * 1.05 - tdir * Uh * 0.15, hip + tn * ww * 1.1 - tdir * Uh * 0.15])
	ci.draw_colored_polygon(band, shorts)
	ci.draw_line(t_hip + tn * ww * 1.05, t_hip - tn * ww * 1.0, trim, maxf(1.5, Uh * 0.16), true)
	# Cabeça
	_head(ci, j, Uh, sk)
	# Membros do lado de cá
	_leg(ci, j, "nl", lw, near, near_l, Uh, false)
	_shorts_leg(ci, j, "nl", lw, shorts)
	if layer == 0:
		_arm(ci, j, "na", aw, near, near_l, Uh, false)


func _arm(ci: CanvasItem, j: Dictionary, side: String, aw: float, col: Color, light: Color, Uh: float, far_side: bool) -> void:
	var sh: Vector2 = j["sh"]
	var el: Vector2 = j[side + "_el"]
	var wr: Vector2 = j[side + "_wr"]
	_capsule(ci, sh, el, aw * 1.15, aw * 0.9, col, light)
	_capsule(ci, el, wr, aw * 0.9, aw * 0.75, col, light)
	if tattoo >= 3 and not far_side:
		ci.draw_line(sh.lerp(el, 0.2), sh.lerp(el, 0.9), Color(0.1, 0.12, 0.17, 0.4), aw * 1.2, true)
	if outfit == "ref":
		_capsule(ci, sh, sh.lerp(el, 0.55), aw * 1.3, aw * 1.15, shirt.darkened(0.25) if far_side else shirt, shirt.lightened(0.1))
		ci.draw_circle(wr + (wr - el).normalized() * Uh * 0.1, Uh * 0.2, col)
		return
	var g := glove.darkened(0.3) if far_side else glove
	var fd := (wr - el).normalized()
	var fn := Vector2(-fd.y, fd.x)
	ci.draw_circle(wr + fd * Uh * 0.16, Uh * 0.36, g)
	ci.draw_circle(wr + fd * Uh * 0.16 - fn * Uh * 0.08 + Vector2(0, -Uh * 0.06), Uh * 0.16, g.lightened(0.12))
	ci.draw_line(wr - fd * Uh * 0.08 + fn * Uh * 0.3, wr - fd * Uh * 0.08 - fn * Uh * 0.3, corner.darkened(0.3) if far_side else corner, maxf(1.5, Uh * 0.16), true)


func _shorts_leg(ci: CanvasItem, j: Dictionary, side: String, lw: float, col: Color) -> void:
	var hip: Vector2 = j["hip"]
	var kn: Vector2 = j[side + "_kn"]
	var end := hip.lerp(kn, 0.5)
	if outfit == "ref":
		var an: Vector2 = j[side + "_an"]
		_capsule(ci, hip, kn, lw * 1.05, lw * 0.85, col, col.lightened(0.08))
		_capsule(ci, kn, an.lerp(kn, 0.1), lw * 0.85, lw * 0.6, col, col.lightened(0.08))
		return
	var d := (end - hip).normalized()
	var n := Vector2(-d.y, d.x)
	var a := hip - d * lw * 0.6
	ci.draw_colored_polygon(PackedVector2Array([a + n * lw * 1.25, end + n * lw * 1.2, end - n * lw * 1.2, a - n * lw * 1.25]), col)
	ci.draw_line(end + n * lw * 1.2, end - n * lw * 1.2, Color(trim, 0.9), maxf(1.0, lw * 0.22), true)


func _leg(ci: CanvasItem, j: Dictionary, side: String, lw: float, col: Color, light: Color, Uh: float, _far_side: bool) -> void:
	var hip: Vector2 = j["hip"]
	var kn: Vector2 = j[side + "_kn"]
	var an: Vector2 = j[side + "_an"]
	var toe: Vector2 = j[side + "_toe"]
	_capsule(ci, hip, kn, lw, lw * 0.72, col, light)
	_capsule(ci, kn, an, lw * 0.72, lw * 0.42, col, light)
	_capsule(ci, an, toe, lw * 0.4, lw * 0.3, col, light)


func _head(ci: CanvasItem, j: Dictionary, Uh: float, sk: Color) -> void:
	var c: Vector2 = j["head"]
	var neck: Vector2 = j["neck"]
	var r := R_HEAD * Uh
	_capsule(ci, neck - (c - neck).normalized() * Uh * 0.1, c, Uh * 0.24 * chest_k, Uh * 0.24, sk.darkened(0.1), sk)
	var up := (c - neck).normalized()
	var fw := Vector2(-up.y, up.x) * dir
	if fw.dot(Vector2(dir, 0)) < 0.0:
		fw = -fw
	# Crânio (oval) e queixo para a frente
	ci.draw_circle(c, r, sk)
	ci.draw_circle(c + fw * r * 0.35 - up * r * 0.35, r * 0.62, sk)
	# Cabelo
	if not bald:
		var cap := PackedVector2Array()
		for i in 13:
			var a := PI * float(i) / 12.0
			var v := up.rotated((a - PI * 0.5) * dir)
			cap.append(c + v * r * 1.04)
		cap.append(c - fw * r * 0.9 - up * r * 0.1)
		ci.draw_colored_polygon(cap, hair)
	# Barba
	if has_beard:
		var bd := PackedVector2Array([c + fw * r * 0.95 - up * r * 0.15, c + fw * r * 0.75 - up * r * 0.95, c - up * r * 0.85, c - fw * r * 0.3 - up * r * 0.3])
		ci.draw_colored_polygon(bd, Color(beard, 0.9))
	# Olho, nariz e orelha
	ci.draw_circle(c + fw * r * 0.62 + up * r * 0.12, maxf(1.0, r * 0.1), Color(0.08, 0.06, 0.05))
	ci.draw_line(c + fw * r * 0.9 + up * r * 0.05, c + fw * r * 1.12 - up * r * 0.15, sk.darkened(0.25), maxf(1.0, r * 0.18), true)
	ci.draw_circle(c - fw * r * 0.1, r * 0.2, sk.darkened(0.15))
	if bruise > 0.25:
		ci.draw_circle(c + fw * r * 0.6 + up * r * 0.1, r * (0.22 + 0.12 * bruise), Color(0.38, 0.12, 0.2, clampf((bruise - 0.25) * 0.7, 0.0, 0.5)))
	if cut > 0.2:
		var bl := Color(0.62, 0.04, 0.04, clampf(0.35 + cut * 0.45, 0.0, 0.95))
		var top := c + fw * r * 0.55 + up * r * 0.5
		ci.draw_circle(top, r * 0.12, bl)
		ci.draw_line(top, c + fw * r * 0.72 - up * r * (0.2 + 0.5 * minf(cut, 1.0)), bl, maxf(1.0, r * (0.12 + 0.1 * cut)), true)
		if cut > 0.7:
			ci.draw_line(top - fw * r * 0.2, c + fw * r * 0.35 - up * r * 0.9, Color(bl, bl.a * 0.8), maxf(1.0, r * 0.1), true)
