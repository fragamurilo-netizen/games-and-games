extends SceneTree
## Conversão de pênaltis (PenaltyKick) no jogo e em disputas, contra a referência real
## (~76% no jogo, ~72% em disputas; ~17% defendidos, ~7% para fora).


func _initialize() -> void:
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	var takers: Array = []
	var gks: Array = []
	for p: Player in w.players.values():
		if p.club_id < 0 or p.overall < 68:
			continue
		if p.position == Pos.GK:
			gks.append(p)
		elif p.position in [Pos.ST, Pos.AM, Pos.CM, Pos.LW, Pos.RW]:
			takers.append(p)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for pr in [0.3, 0.75]:
		var c := {}
		for i in 20000:
			var t: Player = takers[rng.randi_range(0, takers.size() - 1)]
			var g: Player = gks[rng.randi_range(0, gks.size() - 1)]
			var r := PenaltyKick.kick(rng, t, g, {"pressure": pr, "cond": 80.0})
			c[r["res"]] = int(c.get(r["res"], 0)) + 1
		var s := []
		for k in ["goal", "save", "post", "wide", "over"]:
			s.append("%s %.1f%%" % [k, 100.0 * int(c.get(k, 0)) / 20000.0])
		print("pressão %.2f: %s" % [pr, ", ".join(s)])
	quit()
