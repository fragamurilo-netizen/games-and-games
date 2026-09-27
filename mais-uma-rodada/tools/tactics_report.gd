extends SceneTree
## Relatório das táticas, do estudo de adversários e da evolução dos times numa temporada real
## (todas as ligas, modo rápido): gols por tipo de jogada, variedade de planos da IA, trabalho
## do técnico e fase, e a comparação modo rápido × minuto a minuto.
## Uso: godot --headless --path . --script res://tools/tactics_report.gd -- --days=30


func _process(_d: float) -> bool:
	var days := 30
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--days="):
			days = int(a.substr(7))
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	var t0 := Time.get_ticks_msec()
	var n := 0
	while not w.season.finished and n < days:
		SeasonManager.play_matchday_instant(w)
		n += 1
	var ms := Time.get_ticks_msec() - t0
	print("datas %d | %.0f ms por data" % [n, float(ms) / maxf(1, n)])
	var cats := [0, 0, 0, 0, 0, 0]
	var total := 0
	var styles := {}
	var press := [0, 0, 0]
	var line := [0, 0, 0]
	var width := [0, 0, 0]
	var entries := 0
	var changed := 0
	var goals := 0
	var games := 0
	var hw := 0
	var dr := 0
	for c: Club in w.clubs:
		var prev := -1
		for e: Dictionary in c.tac_log:
			for k in e.get("gt", []):
				cats[int(k)] += 1
				total += 1
			if e.has("st"):
				styles[int(e["st"])] = int(styles.get(int(e["st"]), 0)) + 1
				press[int(e["p"])] += 1
				line[int(e["l"])] += 1
				width[int(e.get("w", 1))] += 1
				entries += 1
				if prev >= 0 and prev != int(e["st"]):
					changed += 1
				prev = int(e["st"])
			if int(e.get("h", 0)) == 1:
				games += 1
				goals += int(e["gf"]) + int(e["ga"])
				if int(e["gf"]) > int(e["ga"]):
					hw += 1
				elif int(e["gf"]) == int(e["ga"]):
					dr += 1
	var cs: Array = []
	for i in cats.size():
		cs.append("%s %.1f%%" % [TacticalScout.CATS[i], 100.0 * cats[i] / maxf(1, total)])
	print("gols por tipo: ", ", ".join(cs))
	print("jogos (diário) %d | gols/jogo %.2f | mandante %.1f%% | empates %.1f%%" % [games, float(goals) / maxf(1, games), 100.0 * hw / maxf(1, games), 100.0 * dr / maxf(1, games)])
	var ss: Array = []
	for k in styles:
		ss.append("%s %.0f%%" % [TacticsManager._style_name(int(k)), 100.0 * styles[k] / maxf(1, entries)])
	print("estilos usados: ", ", ".join(ss), " | troca de estilo entre jogos %.0f%%" % (100.0 * changed / maxf(1, entries)))
	print("pressão %s | linha %s | largura %s" % [str(press), str(line), str(width)])
	var wmin := 999.0
	var wmax := -1.0
	var wsum := 0.0
	var mmin := 9.0
	var mmax := -9.0
	var fmin := 9.0
	var fmax := 0.0
	for c: Club in w.clubs:
		if c.evo.is_empty():
			continue
		var wv := float(c.evo["w"])
		var mv := float(c.evo["mo"])
		wmin = minf(wmin, wv)
		wmax = maxf(wmax, wv)
		wsum += wv
		mmin = minf(mmin, mv)
		mmax = maxf(mmax, mv)
		var f := TeamEvolution.factor(w, c)
		fmin = minf(fmin, f)
		fmax = maxf(fmax, f)
	print("trabalho %.0f–%.0f (média %.1f) | fase %.2f–%.2f | fator %.3f–%.3f" % [wmin, wmax, wsum / w.clubs.size(), mmin, mmax, fmin, fmax])
	# Leitura de um clube qualquer (o que o auxiliar diria)
	var sample: Club = w.clubs_in_league("BRA1")[0]
	var prof := TacticalScout.profile(w, sample)
	print("%s: %s" % [sample.short_name, str(TacticalScout.weaknesses(prof))])
	var opp: Club = w.clubs_in_league("BRA1")[1]
	var plan := TacticalScout.counter_plan(w, opp, sample, true)
	print("plano do %s contra o %s: %s" % [opp.short_name, sample.short_name, str(plan["reasons"])])
	# Modo rápido × minuto a minuto
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var ids := DatabaseManager.league_ids()
	var acc := {true: [0.0, 0.0, 0, 0, 0], false: [0.0, 0.0, 0, 0, 0]}
	for i in 400:
		var cl := w.clubs_in_league(ids[i % ids.size()])
		var a: Club = cl[rng.randi_range(0, cl.size() - 1)]
		var b: Club = cl[rng.randi_range(0, cl.size() - 1)]
		if a == b:
			continue
		for quick in [true, false]:
			var res := MatchEngine.test_match(w, a, b, i * 3 + 1, quick)
			var v: Array = acc[quick]
			v[0] += res["hg"]
			v[1] += res["ag"]
			v[2] += 1
			if res["hg"] > res["ag"]:
				v[3] += 1
			elif res["hg"] == res["ag"]:
				v[4] += 1
	for quick in [true, false]:
		var v: Array = acc[quick]
		print("%s: gols %.2f | mandante %.1f%% | empates %.1f%%" % ["rápido  " if quick else "completo", (v[0] + v[1]) / v[2], 100.0 * v[3] / v[2], 100.0 * v[4] / v[2]])
	quit()
	return true
