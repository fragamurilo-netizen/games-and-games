class_name FaceResolver
extends RefCounted
## Transforma Fighter.appearance ({seed, pop, sex, age, body}) no rosto completo,
## igual ao que o Fight Studio desenha (Game Design Bible §5). Porte fiel de
## `genFace` e `FightAppearance.resolve` (prototypes/face-lab/identity.js e
## prototypes/fight-lab/appearance.js), inclusive o gerador pseudoaleatório,
## para que o retrato do jogo e o boneco da transmissão sejam a mesma pessoa.
## Tabelas em content/face_catalog.json (tools/build_face_catalog.js).

const MASK := 0xFFFFFFFF
static var _catalog: Dictionary = {}


static func catalog() -> Dictionary:
	if _catalog.is_empty():
		_catalog = ContentDB.load_json("face_catalog.json")
	return _catalog


## Rosto completo para um atleta. canon_index: índice do retrato autoral
## (combat_profiles.json → appearance_index) quando o atleta for canônico.
static func resolve(appearance: Dictionary, sex: String, canon_index: Variant = null) -> Dictionary:
	var cat := catalog()
	var face: Dictionary
	if appearance.has("head"):
		face = appearance.duplicate(true)
	elif canon_index != null and int(canon_index) >= 0 and int(canon_index) < cat.canon.size() and not appearance.has("pop"):
		face = cat.canon[int(canon_index)].duplicate(true)
	else:
		face = {}
	if face.is_empty() or face.get("sex", sex) != sex:
		if appearance.has("seed"):
			face = gen_face(int(appearance.seed), str(appearance.get("pop", "misto")), sex)
		else:
			for c: Dictionary in cat.canon:
				if c.sex == sex:
					face = c.duplicate(true)
					break
	face.sex = sex
	var body: Dictionary = face.get("body", {}).duplicate()
	body.merge(appearance.get("body", {}), true)
	face.body = body
	if appearance.has("age"):
		face.age = int(appearance.age)
	if sex == "f":
		var fem := {"shoulders": 0.35, "hips": 0.65, "waist": 0.35}
		fem.merge(face.body, true)
		face.body = fem
	return face


## mulberry32, idêntico ao rngOf do JS.
class Rng:
	var a: int

	func _init(seed_value: int) -> void:
		a = seed_value & MASK

	func next() -> float:
		a = (a + 0x6D2B79F5) & MASK
		var t := FaceResolver.imul(a ^ (a >> 15), 1 | a)
		t = ((t + FaceResolver.imul(t ^ (t >> 7), 61 | t)) & MASK) ^ t
		return float((t ^ (t >> 14)) & MASK) / 4294967296.0


static func imul(x: int, y: int) -> int:
	x &= MASK
	y &= MASK
	var lo := x * (y & 0xFFFF)
	var hi := ((x * (y >> 16)) & 0xFFFF) << 16
	return (lo + hi) & MASK


static func pick_w(r: Rng, table: Dictionary) -> String:
	var total := 0.0
	for k in table:
		total += float(table[k])
	var x := r.next() * total
	for k in table:
		x -= float(table[k])
		if x <= 0.0:
			return str(k)
	return str(table.keys()[0])


static func _pick(r: Rng, items: Array) -> Variant:
	return items[int(floor(r.next() * items.size()))]


static func _fixed1(v: float) -> float:
	return snappedf(v, 0.1)


static func gen_face(seed_value: int, pop_id: String, sex: String) -> Dictionary:
	var cat := catalog()
	var r := Rng.new(seed_value)
	var pid := pop_id
	var pops: Dictionary = cat.populations
	if pid.is_empty() or pid == "misto" or not pops.has(pid):
		pid = str(_pick(r, pops.keys()))
	var pp: Dictionary = pops[pid]
	var fem := sex == "f"
	var skin := pick_w(r, pp.skin)
	var hair_color := pick_w(r, pp.hairC)
	var style := pick_w(r, pp.f if fem else pp.m)
	var beard := "nenhuma"
	if not fem:
		beard = pick_w(r, pp.beard) if r.next() < float(pp.beardP) else "nenhuma"
	var marks: Array = []
	if pp.has("freck") and r.next() < float(pp.freck):
		marks.append("sardas_leves" if r.next() < 0.5 else "sardas")
	if r.next() < 0.12:
		marks.append(_pick(r, ["pinta_bochecha", "pinta_queixo", "pinta_labio"]))
	if r.next() < 0.3:
		marks.append(_pick(r, ["brow_l", "brow_r", "cheek_l", "cheek_r", "lip", "nose", "chin"]))
	if r.next() < float(pp.get("tattoo", 0.12)):
		marks.append(_pick(r, ["neck", "shoulders", "chest"]))
	if r.next() < 0.12:
		marks.append("argola" if r.next() < 0.5 else "brinco")
	var face := {"v": 1}
	face.seed = int(floor(r.next() * 1e6))
	face.pop = pid
	face.sex = "f" if fem else "m"
	face.age = 19 + int(floor(r.next() * 14))
	face.build = clampf(float(pp.build) + (r.next() - 0.5) * 0.5, 0.0, 1.0) if pp.has("build") else r.next()
	face.skin = skin
	var head := {}
	head.shape = pick_w(r, pp.heads)
	head.width = _fixed1(r.next() * 1.2 - 0.6)
	head.jaw = _fixed1(r.next() * 1.2 - 0.6)
	head.chin = _fixed1(r.next() * 1.2 - 0.6)
	face.head = head
	var eyes := {}
	eyes.shape = pick_w(r, pp.eyes)
	eyes.iris = pick_w(r, pp.iris)
	face.eyes = eyes
	face.brows = {"shape": pick_w(r, pp.brows)}
	var nose := {}
	nose.shape = pick_w(r, pp.nose)
	nose.broken = _fixed1(r.next() * 0.8) if r.next() < 0.3 else 0.0
	face.nose = nose
	face.mouth = {"shape": pick_w(r, pp.mouth)}
	var ears := {}
	ears.shape = pick_w(r, {"normal": 6, "pequena": 2, "abano": 1, "grande": 1})
	ears.cauli = 1 + int(floor(r.next() * 3)) if r.next() < 0.35 else 0
	face.ears = ears
	face.hair = {"style": style, "color": hair_color}
	face.beard = {"style": beard, "color": null}
	face.marks = marks
	face.recede = 0.0 if fem else _fixed1(r.next() * 0.7)
	var body := {}
	body.muscle = snappedf(0.45 + r.next() * 0.45, 0.01)
	body.fat = snappedf(0.05 + r.next() * 0.3, 0.01)
	var hair_body := 0.0
	if not fem:
		hair_body = r.next() if r.next() < float(pp.get("beardP", 0.5)) * 0.6 else 0.0
	body.hair = snappedf(hair_body, 0.01)
	body.height = snappedf(r.next(), 0.01)
	face.body = body
	face.kit = {
		"shorts": pick_w(r, {"preto": 4, "vermelho": 2, "azul": 2, "branco": 1, "verde": 1, "dourado": 0.5, "roxo": 0.5, "camuflado": 0.5}),
		"gloves": pick_w(r, {"preto": 6, "vermelho": 1, "azul": 1, "branco": 0.5}),
	}
	return face
