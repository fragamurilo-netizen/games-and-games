extends SceneTree
## Simula N temporadas e mostra como o DNA dos clubes mudou: eras, filosofias, mercados e as
## linhas do tempo mais movimentadas.
## Uso: godot --headless --path . --script res://tests/dna_report.gd -- --seasons=20 --seed=123


func _initialize() -> void:
	var seasons := 10
	var seed_value := WorldGenerator.DEFAULT_SEED
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seasons="):
			seasons = int(a.substr(10))
		elif a.begins_with("--seed="):
			seed_value = int(a.substr(7))
	var w := WorldGenerator.generate(seed_value, "padrao")
	var start := {}
	for c: Club in w.clubs:
		var d := ClubDNA.of(c)
		start[c.id] = [String(d["rec"]), String(d["mkt"]), String(d["tac"])]
	print("Início %d: %s" % [w.year, _dist(w)])
	for s in seasons:
		while not w.season.finished:
			SeasonManager.play_matchday_instant(w)
		SeasonManager.end_season(w)
		print("%d: %s" % [w.year - 1, _dist(w)])
	var changed := [0, 0, 0]
	for c: Club in w.clubs:
		var d := ClubDNA.of(c)
		var s0: Array = start[c.id]
		for i in 3:
			if String(s0[i]) != String(d[["rec", "mkt", "tac"][i]]):
				changed[i] += 1
	print("Mudaram de filosofia de elenco: %d · de mercado: %d · de escola: %d (de %d clubes)" % [changed[0], changed[1], changed[2], w.clubs.size()])
	var busy: Array = w.clubs.duplicate()
	busy.sort_custom(func(a, b): return ClubDNA.log_of(a).size() > ClubDNA.log_of(b).size())
	for c: Club in busy.slice(0, 6):
		print("\n%s (%s) · %s · %s · %s" % [c.name, c.league_id, ClubDNA.name_of("eras", ClubDNA.era(c)), ClubDNA.name_of("rec", ClubDNA.rec(c)), ClubDNA.name_of("mkt", ClubDNA.mkt(c))])
		for e in ClubDNA.log_of(c):
			print("  %d  %s" % [int(e["y"]), String(e["t"])])
	quit(0)


func _dist(w: GameWorld) -> String:
	var eras := {}
	var recs := {}
	for c: Club in w.clubs:
		eras[ClubDNA.era(c)] = int(eras.get(ClubDNA.era(c), 0)) + 1
		recs[ClubDNA.rec(c)] = int(recs.get(ClubDNA.rec(c), 0)) + 1
	return "eras %s | elenco %s" % [str(eras), str(recs)]
