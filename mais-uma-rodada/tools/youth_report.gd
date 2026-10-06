extends SceneTree
## Realismo da base (calibração com o FC/Transfermarkt): quantos jovens bons existem no mundo por
## idade, overall e potencial dos garotos da base, e como isso fica depois de N temporadas.
## godot --headless --path . --script res://tools/youth_report.gd -- [--seasons=N]

func _initialize() -> void:
	var seasons := 0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seasons="):
			seasons = int(a.substr(10))
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	w.user_club_id = -1
	_report(w, "começo")
	for s in seasons:
		var guard := 0
		while not w.season.finished and guard < 400:
			SeasonManager.play_matchday_instant(w)
			guard += 1
		SeasonManager.end_season(w)
		_report(w, "começo da temporada %d" % (s + 2))
	quit()


func _report(w: GameWorld, title: String) -> void:
	print("\n=== %s ===" % title)
	var by_age := {}
	for p: Player in w.players.values():
		if p.club_id < 0:
			continue
		var age := p.age(w.year)
		if age > 23:
			continue
		if not by_age.has(age):
			by_age[age] = []
		by_age[age].append(p)
	print("idade |   n  | ovr médio | pot médio | ovr≥70 ≥75 ≥80 ≥85 | pot≥85 ≥90 | melhor ovr/pot")
	var ages := by_age.keys()
	ages.sort()
	for age in ages:
		var arr: Array = by_age[age]
		var so := 0.0
		var sp := 0.0
		var c70 := 0
		var c75 := 0
		var c80 := 0
		var c85 := 0
		var p85 := 0
		var p90 := 0
		var best: Player = null
		for p: Player in arr:
			so += p.overall
			sp += p.potential
			c70 += 1 if p.overall >= 70 else 0
			c75 += 1 if p.overall >= 75 else 0
			c80 += 1 if p.overall >= 80 else 0
			c85 += 1 if p.overall >= 85 else 0
			p85 += 1 if p.potential >= 85 else 0
			p90 += 1 if p.potential >= 90 else 0
			if best == null or p.overall > best.overall:
				best = p
		print("%5d | %4d | %9.1f | %9.1f | %4d %3d %3d %3d | %6d %3d | %d/%d" % [age, arr.size(), so / arr.size(), sp / arr.size(), c70, c75, c80, c85, p85, p90, best.overall, best.potential])
	# Academia do clube do usuário não existe neste relatório (IA); os jovens acima já incluem a base promovida.
