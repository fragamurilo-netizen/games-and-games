extends SceneTree
## Relatório de realismo do motor minuto a minuto (médias, placares, viradas, zebras).
## Uso: godot --headless --path . --script res://tools/engine_report.gd [-- --quick --n=1500] [-- --quick] [-- --n=1500]
## --quick: mede o modo rápido (QuickMatch, os jogos da IA) em vez do minuto a minuto.
## --detail: minuto a minuto com a narração ligada (o jogo assistido); deve dar os mesmos números.


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
	var detail := false
	var total := 1500
	for arg in OS.get_cmdline_user_args():
		if arg == "--quick":
			quick = true
		elif arg == "--detail":
			detail = true
		elif arg.begins_with("--n="):
			total = int(arg.substr(4))
	var t0 := Time.get_ticks_msec()
	var fs_w := 0
	var fs_d := 0
	var dist := [0, 0, 0, 0, 0, 0, 0]
	var yc := 0
	var rc := 0
	var shots := 0
	var xg := 0.0
	var pens := 0
	var pos_g := [0, 0, 0, 0]
	var st_g := 0
	var gap_n := [0, 0, 0]
	var gap_w := [0, 0, 0]
	var gap_d := [0, 0, 0]
	var gap_g := [0, 0, 0]
	var gap_big := [0, 0, 0]
	for i in total:
		var cl := w.clubs_in_league(ids[i % ids.size()])
		var a: Club = cl[rng.randi_range(0, cl.size() - 1)]
		var b: Club = cl[rng.randi_range(0, cl.size() - 1)]
		if a == b:
			continue
		var res := _detail_match(w, a, b, rng.randi()) if detail else MatchEngine.test_match(w, a, b, rng.randi(), quick)
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
		dist[mini(6, hg + ag)] += 1
		yc += int(res["yc"][0]) + int(res["yc"][1])
		rc += int(res["rc"][0]) + int(res["rc"][1])
		shots += int(res.get("sh", [0, 0])[0]) + int(res.get("sh", [0, 0])[1])
		xg += float(res["tac"]["xg"][0]) + float(res["tac"]["xg"][1])
		for g in res["goals"]:
			if int(g[3]) == Fixture.GOAL_PENALTY:
				pens += 1
			if int(g[3]) != Fixture.GOAL_OWN:
				var gp: Player = w.players.get(int(g[2]), null)
				if gp != null:
					pos_g[Pos.GROUP[gp.position]] += 1
					if gp.position == Pos.ST:
						st_g += 1
		var ga_ := ClubAI._compute_strength(w, a) + 1.5
		var gb_ := ClubAI._compute_strength(w, b)
		var gi := 0 if absf(ga_ - gb_) < 3.0 else (1 if absf(ga_ - gb_) < 7.0 else 2)
		gap_n[gi] += 1
		gap_g[gi] += hg + ag
		if hg + ag >= 5:
			gap_big[gi] += 1
		var fav_home := ga_ >= gb_
		if (fav_home and hg > ag) or (not fav_home and ag > hg):
			gap_w[gi] += 1
		elif hg == ag:
			gap_d[gi] += 1
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
	var ds: Array = []
	for k in dist.size():
		ds.append("%s:%.1f%%" % [str(k) if k < 6 else "6+", 100.0 * dist[k] / n])
	print("total de gols: ", " ".join(ds))
	var tg := maxf(1, pos_g[1] + pos_g[2] + pos_g[3])
	print("amarelos %.2f | vermelhos %.3f | finalizações/time %.1f | xG/time %.2f | pênaltis %.1f%% dos gols | DEF %.1f%% MEI %.1f%% ATA %.1f%% (centroavante %.1f%%)" % [float(yc) / n, float(rc) / n, shots / (2.0 * n), xg / (2.0 * n), 100.0 * pens / maxf(1, goals), 100.0 * pos_g[1] / tg, 100.0 * pos_g[2] / tg, 100.0 * pos_g[3] / tg, 100.0 * st_g / tg])
	var gs: Array = []
	for k in 3:
		gs.append("%s: favorito vence %.0f%% empata %.0f%% perde %.0f%% gols %.2f 5+ %.0f%% (%d)" % [["gap<3", "3-7", "7+"][k], 100.0 * gap_w[k] / maxf(1, gap_n[k]), 100.0 * gap_d[k] / maxf(1, gap_n[k]), 100.0 * (gap_n[k] - gap_w[k] - gap_d[k]) / maxf(1, gap_n[k]), float(gap_g[k]) / maxf(1, gap_n[k]), 100.0 * gap_big[k] / maxf(1, gap_n[k]), gap_n[k]])
	print(" | ".join(gs))
	quit()


## Mesmo jogo de teste do MatchEngine.quick_match, mas com detail = true (eventos de apresentação).
static func _detail_match(world: GameWorld, home: Club, away: Club, seed_value: int) -> Dictionary:
	var hs := ClubAI.prepare_ai_sheet(world, home, away, true)
	var as_ := ClubAI.prepare_ai_sheet(world, away, home, false)
	var sim := MatchSimulation.new()
	sim.setup(world, home, away, hs, as_, MatchEngine._test_ctx(home), seed_value, true)
	sim.run_to_end()
	return sim.to_result()
