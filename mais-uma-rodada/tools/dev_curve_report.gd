extends SceneTree
## Curva de carreira sem jogar partidas: N temporadas só de evolução (treino semanal com minutos
## sintéticos — titulares jogam, reservas pouco —, revisão anual, aposentadorias e base).
## Mostra a variação média de overall por idade, a elite do mundo a cada ano e exemplos de carreiras.
## godot --headless --path . --script res://tools/dev_curve_report.gd -- --years=6

var opt_years := 6


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--years="):
			opt_years = int(a.substr(8))
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	w.user_club_id = -1
	_elite(w)
	var delta := {} # idade -> [soma, n]
	var gk_delta := {}
	var follow: Array = []
	for p: Player in w.players.values():
		if p.club_id >= 0 and p.age(w.year) <= 18 and p.potential >= 84 and follow.size() < 6:
			follow.append([p, [p.overall]])
	for p: Player in w.players.values():
		if p.club_id >= 0 and p.age(w.year) == 27 and p.overall >= 84 and follow.size() < 10:
			follow.append([p, [p.overall]])
	for y in opt_years:
		var before := {}
		for p: Player in w.players.values():
			before[p.id] = [p.ovr_f, p.age(w.year)]
		var minutes := {}
		var played := {}
		for c: Club in w.clubs:
			played[c.id] = true
			for p: Player in w.squad(c):
				minutes[p.id] = 90 if p.squad_status <= Player.STATUS_STARTER else (25 if p.squad_status == Player.STATUS_ROTATION else 0)
		for p: Player in w.players.values():
			var m: int = minutes.get(p.id, 0)
			p.minutes_season = m * 38.0 * 0.9
		for _wk in 38:
			PlayerDevelopment.weekly_tick(w, minutes, played)
		PlayerDevelopment.yearly_review(w)
		for p: Player in w.players.values():
			if not before.has(p.id):
				continue
			var b: Array = before[p.id]
			var age: int = b[1]
			var d := p.ovr_f - float(b[0])
			var tab: Dictionary = gk_delta if p.position == Pos.GK else delta
			if not tab.has(age):
				tab[age] = [0.0, 0, 0.0]
			tab[age][0] += d
			tab[age][1] += 1
			if p.club_id >= 0 and p.overall >= 75:
				tab[age][2] += d
		PlayerDevelopment.announce_retirements(w)
		PlayerDevelopment.process_retirements(w)
		w.year += 1
		PlayerDevelopment.youth_intake(w)
		TransferManager.balance_squads(w)
		PlayerDevelopment.update_talent_drift(w)
		Valuation.refresh_shift(w)
		for f in follow:
			f[1].append(f[0].overall)
		_elite(w)
	print("Δ overall por temporada (linha: todos · entre parênteses: goleiros)")
	var line := ""
	for age in range(16, 38):
		if not delta.has(age):
			continue
		var d: Array = delta[age]
		var g: Array = gk_delta.get(age, [0.0, 1])
		line += "%d: %+.1f (%+.1f)  " % [age, d[0] / maxf(1, d[1]), g[0] / maxf(1, g[1])]
		if age % 5 == 0:
			print(line)
			line = ""
	print(line)
	print("carreiras (ano a ano):")
	for f in follow:
		var p: Player = f[0]
		print("  %s (pot %d, curva %d): %s" % [p.display_name(), p.potential, p.dev_curve, " → ".join(PackedStringArray(f[1].map(func(x): return str(x))))])
	quit()


func _elite(w: GameWorld) -> void:
	var n85 := 0
	var n80 := 0
	var n75 := 0
	var top := 0
	var ages := 0.0
	for p: Player in w.players.values():
		if p.club_id < 0 or p.retiring:
			continue
		top = maxi(top, p.overall)
		if p.overall >= 85:
			n85 += 1
			ages += p.age(w.year)
		if p.overall >= 80:
			n80 += 1
		if p.overall >= 75:
			n75 += 1
	print("%d: melhor %d · 85+ %d (idade média %.1f) · 80+ %d · 75+ %d · jogadores %d" % [w.year, top, n85, ages / maxf(1, n85), n80, n75, w.players.size()])
