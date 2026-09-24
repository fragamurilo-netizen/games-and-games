extends SceneTree

func _initialize() -> void:
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var n := 0
	var goals := 0
	var hw := 0
	var dr := 0
	var aw := 0
	var shots := 0
	var sot := 0
	var yel := 0
	var red := 0
	var fouls := 0
	var corners := 0
	var pens := 0
	var inj := 0
	var subs := 0
	var t0 := Time.get_ticks_msec()
	for i in 1500:
		var div := i % 4
		var l: League = w.season.leagues[div]
		var a: int = l.club_ids[rng.randi_range(0, 19)]
		var b: int = l.club_ids[rng.randi_range(0, 19)]
		if a == b: continue
		var sim := MatchEngine.quick_match(w, w.clubs[a], w.clubs[b], rng.randi())
		n += 1
		goals += sim.score[0] + sim.score[1]
		if sim.score[0] > sim.score[1]: hw += 1
		elif sim.score[0] == sim.score[1]: dr += 1
		else: aw += 1
		for t in sim.teams:
			shots += t.shots; sot += t.on_target; yel += t.yellows; red += t.reds; fouls += t.fouls; corners += t.corners
		for e in sim.events:
			if e["t"] == MatchSimulation.EV_PENALTY_AWARDED: pens += 1
			if e["t"] == MatchSimulation.EV_INJURY: inj += 1
			if e["t"] == MatchSimulation.EV_SUB: subs += 1
	var ms := Time.get_ticks_msec() - t0
	print("matches=%d ms/match=%.2f goals/m=%.2f H/D/A=%.1f/%.1f/%.1f shots/team=%.1f sot/team=%.1f fouls/m=%.1f Y/m=%.2f R/m=%.2f corners/m=%.1f pens/m=%.2f inj/m=%.2f subs/m=%.1f" % [n, float(ms)/n, float(goals)/n, 100.0*hw/n, 100.0*dr/n, 100.0*aw/n, shots/(2.0*n), sot/(2.0*n), float(fouls)/n, float(yel)/n, float(red)/n, float(corners)/n, float(pens)/n, float(inj)/n, float(subs)/n])
	# Mismatch: best D1 vs D4 teams
	var wins := 0; var draws := 0; var loss := 0
	for i in 400:
		var sim := MatchEngine.quick_match(w, w.clubs[70 + i % 10], w.clubs[i % 10], rng.randi())
		if sim.score[0] > sim.score[1]: wins += 1
		elif sim.score[0] == sim.score[1]: draws += 1
		else: loss += 1
	print("D4 home vs D1 away: W/D/L = %d/%d/%d of 400" % [wins, draws, loss])
	# strength gap within D1: top 3 vs bottom 3 at home
	wins = 0; draws = 0; loss = 0
	var l0: League = w.season.leagues[0]
	for i in 600:
		var sim := MatchEngine.quick_match(w, w.clubs[i % 3], w.clubs[17 + i % 3], rng.randi())
		if sim.score[0] > sim.score[1]: wins += 1
		elif sim.score[0] == sim.score[1]: draws += 1
		else: loss += 1
	print("D1 top3 home vs D1 bottom3: W/D/L = %d/%d/%d of 600" % [wins, draws, loss])
	quit()
