extends SceneTree
## Relatório de realismo do motor minuto a minuto (médias, placares, viradas, zebras).
## Uso: godot --headless --path . --script res://tools/engine_report.gd


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
	for i in 1500:
		var cl := w.clubs_in_league(ids[i % ids.size()])
		var a: Club = cl[rng.randi_range(0, cl.size() - 1)]
		var b: Club = cl[rng.randi_range(0, cl.size() - 1)]
		if a == b:
			continue
		var sim := MatchEngine.quick_match(w, a, b, rng.randi())
		n += 1
		var hg := sim.score[0]
		var ag := sim.score[1]
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
		for ev in sim.events:
			if ev["t"] == MatchSimulation.EV_GOAL or ev["t"] == MatchSimulation.EV_OWN_GOAL:
				if first < 0:
					first = int(ev["s"])
				if int(ev["h"]) == 2:
					second_half += 1
					if int(ev["m"]) >= 76:
						late += 1
			if ev["t"] == MatchSimulation.EV_TACTIC and ev.has("x") and ev["x"].has("formation"):
				formation_changes += 1
		if first >= 0:
			first_scored += 1
			var fw := sim.score[first] > sim.score[1 - first]
			if not fw and sim.score[first] != sim.score[1 - first]:
				comeback += 1
		var sa := ClubAI._compute_strength(w, a)
		var sb := ClubAI._compute_strength(w, b)
		if absf(sa - sb) >= 6.0:
			gaps += 1
			var weak_home := sa < sb
			if (weak_home and hg > ag) or (not weak_home and ag > hg):
				upsets += 1
	print("jogos %d | gols/jogo %.2f | mandante %.1f%% | empates %.1f%% | 0x0 %.1f%% | 5+ gols %.1f%%" % [n, float(goals) / n, 100.0 * hw / n, 100.0 * dr / n, 100.0 * nil / n, 100.0 * big / n])
	print("gols no 2º tempo %.1f%% | a partir dos 76' %.1f%% | viradas (quem sofreu o 1º venceu) %.1f%% | zebras (gap>=6) %.1f%% de %d | trocas de formação/jogo %.2f" % [100.0 * second_half / goals, 100.0 * late / goals, 100.0 * comeback / maxf(1, first_scored), 100.0 * upsets / maxf(1, gaps), gaps, float(formation_changes) / n])
	quit()
