extends SceneTree
## Relatório de realismo do motor minuto a minuto (médias, placares, viradas, zebras).
## Uso: godot --headless --path . --script res://tools/engine_report.gd [-- --quick --n=1500] [-- --quick] [-- --n=1500]
## --quick: mede o modo rápido (QuickMatch, os jogos da IA) em vez do minuto a minuto.


func _initialize() -> void:
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var ids := DatabaseManager.league_ids()
	var n := 0
	var goals := 0
	var hw := 0
	var dr := 0
	var nil := 0
	var big := 0
	var first_scored := 0
	var comeback := 0
	var late := 0
	var second_half := 0
	var upsets := 0
	var gaps := 0
	var formation_changes := 0
	var quick := false
	var total := 1500
	for arg in OS.get_cmdline_user_args():
		if arg == "--quick":
			quick = true
		elif arg.begins_with("--n="):
			total = int(arg.substr(4))
	var t0 := Time.get_ticks_msec()
	var fs_w := 0
	var fs_d := 0
	for i in total:
		var cl := w.clubs_in_league(ids[i % ids.size()])
		var a: Club = cl[rng.randi_range(0, cl.size() - 1)]
		var b: Club = cl[rng.randi_range(0, cl.size() - 1)]
		if a == b:
			continue
		var res := MatchEngine.test_match(w, a, b, rng.randi(), quick)
		n += 1
		var hg := int(res["hg"])
		var ag := int(res["ag"])
		var sc: Array = [hg, ag]
		goals += hg + ag
		if hg > ag:
			hw += 1
		elif hg == ag:
			dr += 1
		if hg + ag == 0:
			nil += 1
		if hg + ag >= 5:
			big += 1
		var first := -1
		for g in res["goals"]:
			if first < 0:
				first = int(g[1])
			if int(g[4]) == 2:
				second_half += 1
				if int(g[0]) >= 76:
					late += 1
		if first >= 0:
			first_scored += 1
			if sc[first] > sc[1 - first]:
				fs_w += 1
			elif sc[first] == sc[1 - first]:
				fs_d += 1
			else:
				comeback += 1
		var sa := ClubAI._compute_strength(w, a)
		var sb := ClubAI._compute_strength(w, b)
		if absf(sa - sb) >= 6.0:
			gaps += 1
			var weak_home := sa < sb
			if (weak_home and hg > ag) or (not weak_home and ag > hg):
				upsets += 1
	print("%s · %.1f ms/jogo" % ["RÁPIDO (QuickMatch)" if quick else "MINUTO A MINUTO", float(Time.get_ticks_msec() - t0) / n])
	print("quem marca primeiro: vence %.1f%% · empata %.1f%% · perde %.1f%%" % [100.0 * fs_w / maxf(1, first_scored), 100.0 * fs_d / maxf(1, first_scored), 100.0 * comeback / maxf(1, first_scored)])
	print("jogos %d | gols/jogo %.2f | mandante %.1f%% | empates %.1f%% | 0x0 %.1f%% | 5+ gols %.1f%%" % [n, float(goals) / n, 100.0 * hw / n, 100.0 * dr / n, 100.0 * nil / n, 100.0 * big / n])
	print("gols no 2º tempo %.1f%% | a partir dos 76' %.1f%% | viradas (quem sofreu o 1º venceu) %.1f%% | zebras (gap>=6) %.1f%% de %d" % [100.0 * second_half / goals, 100.0 * late / goals, 100.0 * comeback / maxf(1, first_scored), 100.0 * upsets / maxf(1, gaps), gaps])
	quit()
