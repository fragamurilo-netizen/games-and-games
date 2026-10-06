extends SceneTree
## Lesões numa temporada (InjuryModel): por clube da 1ª divisão das grandes ligas, duração média,
## lesões longas, partes do corpo e recidivas. Referência real: ~40 a 65 lesões por clube de elite
## por temporada, ~3 semanas em média, musculares perto da metade.
## godot --headless --path . --script res://tools/injury_report.gd

func _initialize() -> void:
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	w.user_club_id = -1
	var guard := 0
	while not w.season.finished and guard < 400:
		SeasonManager.play_matchday_instant(w)
		guard += 1
	var parts := {}
	var long := 0
	var n := 0
	var weeks := 0
	var by_league := {}
	for p: Player in w.players.values():
		for e in p.inj_log:
			if int(e[0]) != w.year:
				continue
			n += 1
			weeks += int(e[3])
			parts[String(e[2])] = int(parts.get(String(e[2]), 0)) + 1
			if int(e[3]) >= 13:
				long += 1
			if p.club_id >= 0:
				var lid := w.club(p.club_id).league_id
				by_league[lid] = int(by_league.get(lid, 0)) + 1
	print("lesões na temporada: %d (contador %d, no treino %d) · média %.1f semanas · longas (13+): %d" % [n, int(w.stats.get("inj_n", 0)), int(w.stats.get("inj_t", 0)), float(weeks) / maxf(1.0, n), long])
	for lid in ["ENG1", "ESP1", "ITA1", "GER1", "BRA1", "ARG1"]:
		print("  %s: %.1f lesões por clube" % [lid, float(by_league.get(lid, 0)) / maxf(1.0, w.clubs_in_league(lid).size())])
	var keys := parts.keys()
	keys.sort_custom(func(a, b): return int(parts[a]) > int(parts[b]))
	var txt: Array = []
	for k in keys:
		txt.append("%s %d%%" % [k, int(round(100.0 * int(parts[k]) / maxf(1.0, n)))])
	print("  partes: " + ", ".join(txt))
	quit()
