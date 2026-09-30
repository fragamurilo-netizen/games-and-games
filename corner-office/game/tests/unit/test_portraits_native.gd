extends TestCase
## Retratos nativos (Game Design Bible §5): o rosto do jogo é o mesmo do
## Fight Studio. A referência vem do próprio identity.js
## (tools/build_face_catalog.js → tests/fixtures/genface_reference.json).


func _same(a: Variant, b: Variant) -> bool:
	if (a is float or a is int) and (b is float or b is int):
		return absf(float(a) - float(b)) < 1e-6
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size():
			return false
		for k in a:
			if not b.has(k) or not _same(a[k], b[k]):
				return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not _same(a[i], b[i]):
				return false
		return true
	return a == b


func test_gen_face_matches_face_lab() -> void:
	var text := FileAccess.get_file_as_string("res://tests/fixtures/genface_reference.json")
	var samples: Array = JSON.parse_string(text)
	check(samples.size() >= 6, "referências carregadas")
	for s: Dictionary in samples:
		var face := FaceResolver.gen_face(int(s.seed), str(s.pop), str(s.sex))
		check(_same(face, s.face), "genFace(%s, %s, %s) igual ao face-lab" % [s.seed, s.pop, s.sex])


func test_every_hair_and_beard_draws() -> void:
	var cat := FaceResolver.catalog()
	var base := FaceResolver.gen_face(7, "caucaso", "m")
	for style: String in cat.hair_styles:
		var face := base.duplicate(true)
		face.hair.style = style
		var ops := PortraitPainter.build(face, 128, 160)
		check(ops.size() > 20, "cabelo %s desenhado" % style)
	for style: String in cat.beards:
		var face := base.duplicate(true)
		face.beard.style = style
		check(PortraitPainter.build(face, 128, 160, {"avatar": true}).size() > 20, "barba %s desenhada" % style)


func test_every_fighter_has_a_face() -> void:
	var w := WorldGenerator.generate(41, "regional_promoter")
	var faces := {}
	var n := 0
	for f: Fighter in w.fighters.values():
		var face := FaceView.face_of(f)
		check(face.has("head") and face.has("skin"), "rosto completo para %s" % f.id)
		check_eq(face.sex, "f" if f.sex == Fighter.Sex.FEMALE else "m", "sexo do rosto segue o atleta")
		faces[JSON.stringify(face)] = true
		n += 1
		if n >= 60:
			break
	check(n >= 60, "amostra de atletas")
	check(faces.size() >= 55, "rostos variados (%d/%d)" % [faces.size(), n])
	var carter := FaceView.face_of(w.fighters.ftr_carter)
	check_eq(carter.skin, FaceResolver.catalog().canon[0].skin, "canônico usa o retrato autoral")
