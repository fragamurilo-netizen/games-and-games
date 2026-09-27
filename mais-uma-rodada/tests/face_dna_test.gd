extends SceneTree
## Teste do gerador de rostos (sem tela): milhares de DNAs faciais conferidos um a um.
## Uso: godot --headless --path . --script res://tests/face_dna_test.gd -- --n=5000
##
## Para cada DNA (todas as etnias, idades de 16 a 45):
##   - validação anatômica (FaceDNA.validate): olhos sobrepostos ou fora do rosto, nariz fora do
##     lugar, boca encostando no nariz, orelhas e cabelo fora do retrato, escalas negativas, cores
##     inválidas e sombra do nariz acima do limite;
##   - determinismo: a mesma semente gera o mesmo dicionário;
##   - saves antigos: o DNA sai só de face_seed/etnia/idade (nada novo no save).
## Depois mede a diversidade (distância ao vizinho mais parecido na mesma etnia, só estrutura do
## rosto: sem cabelo nem barba) e o tempo médio de geração. Sai com código 1 se algo falhar.

var _fail := 0


func _initialize() -> void:
	var n := 5000
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--n="):
			n = int(a.substr(4))
	var t0 := Time.get_ticks_usec()
	var issues := {}
	var bad_faces := 0
	var by_eth := {}
	var dna: Array = []
	for i in n:
		var seed_value := 1000003 + i * 7919
		var eth := i % FaceGen.ETH_COUNT
		var age := 16 + (i * 7) % 30
		var f := FaceDNA.from_seed(seed_value, eth, age)
		dna.append(f)
		var probs := FaceDNA.validate(f)
		if not probs.is_empty():
			bad_faces += 1
			for p in probs:
				var kind := p.split(" (")[0]
				issues[kind] = int(issues.get(kind, 0)) + 1
				if int(issues[kind]) <= 3:
					print("  semente %d etnia %d idade %d: %s" % [seed_value, eth, age, p])
		if not by_eth.has(eth):
			by_eth[eth] = []
		(by_eth[eth] as Array).append(FaceDNA.vector(f))
	var gen_ms := (Time.get_ticks_usec() - t0) / 1000.0
	print("FACE_DNA %d rostos gerados em %.0f ms (%.3f ms por DNA)" % [n, gen_ms, gen_ms / maxf(1.0, n)])

	# Validação anatômica
	_check(bad_faces == 0, "%d de %d rostos com problemas de anatomia" % [bad_faces, n])
	for k in issues:
		print("  %5d × %s" % [issues[k], k])

	# Determinismo: repetir uma amostra e comparar tudo
	var diff := 0
	for i in range(0, n, 37):
		var f := FaceDNA.from_seed(1000003 + i * 7919, i % FaceGen.ETH_COUNT, 16 + (i * 7) % 30)
		if var_to_str(f) != var_to_str(dna[i]):
			diff += 1
	_check(diff == 0, "DNA não determinístico em %d amostras" % diff)

	# Save antigo: jogador sem nenhum dado de rosto além da semente, etnia e nascimento
	var p := Player.new()
	p.face_seed = 424242
	p.eth = 7
	p.birth_year = 2001
	var a1 := FaceDNA.from_player(p, 2026)
	var a2 := FaceDNA.from_seed(424242, 7, p.age(2026))
	_check(var_to_str(a1) == var_to_str(a2), "save antigo não deriva o DNA do jogador")

	# Envelhecer não troca a pessoa: a estrutura do rosto aos 20 e aos 34 é quase a mesma
	var drift := 0.0
	for i in 200:
		var young := FaceDNA.vector(FaceDNA.from_seed(77 + i * 104729, i % FaceGen.ETH_COUNT, 20))
		var older := FaceDNA.vector(FaceDNA.from_seed(77 + i * 104729, i % FaceGen.ETH_COUNT, 34))
		drift += _dist(young, older)
	drift /= 200.0

	# Diversidade: vizinho mais parecido dentro da mesma etnia (até 400 por etnia)
	var nn_sum := 0.0
	var nn_n := 0
	var twins := 0
	var rand_sum := 0.0
	var rand_n := 0
	for eth in by_eth:
		var vs: Array = by_eth[eth]
		var m := mini(vs.size(), 400)
		for i in m:
			var best := 1e9
			for j in m:
				if i != j:
					best = minf(best, _dist(vs[i], vs[j]))
			nn_sum += best
			nn_n += 1
			if best < 1.2:
				twins += 1
			rand_sum += _dist(vs[i], vs[(i * 13 + 7) % m])
			rand_n += 1
	var nn := nn_sum / maxf(1.0, nn_n)
	var typical := rand_sum / maxf(1.0, rand_n)
	print("FACE_DNA diversidade: vizinho mais parecido %.2f · par qualquer %.2f · quase gêmeos %d de %d · mudança da idade 20→34 %.2f" % [nn, typical, twins, nn_n, drift])
	_check(nn > 1.8, "rostos parecidos demais (vizinho médio %.2f)" % nn)
	_check(twins * 100 <= nn_n, "quase gêmeos demais (%d de %d)" % [twins, nn_n])
	_check(drift < typical * 0.5, "a idade muda a estrutura do rosto demais (%.2f)" % drift)

	# Traços com alguma variação de verdade (desvio de cada componente do vetor)
	var comps := (FaceDNA.vector(dna[0]) as PackedFloat32Array).size()
	var flat := []
	for c in comps:
		var s := 0.0
		var s2 := 0.0
		for f in dna:
			var x: float = FaceDNA.vector(f)[c]
			s += x
			s2 += x * x
		var mean := s / n
		var sd := sqrt(maxf(0.0, s2 / n - mean * mean))
		if sd < 0.3:
			flat.append("%d (%.2f)" % [c, sd])
	_check(flat.is_empty(), "traços quase sem variação: %s" % ", ".join(flat))

	if _fail == 0:
		print("FACE_DNA_TEST OK")
	quit(1 if _fail > 0 else 0)


func _dist(a: PackedFloat32Array, b: PackedFloat32Array) -> float:
	var s := 0.0
	for k in a.size():
		var d := a[k] - b[k]
		s += d * d
	return sqrt(s)


func _check(ok: bool, msg: String) -> void:
	if not ok:
		_fail += 1
		print("FALHA: ", msg)
