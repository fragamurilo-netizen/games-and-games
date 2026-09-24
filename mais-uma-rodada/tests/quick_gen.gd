extends SceneTree

func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	var t1 := Time.get_ticks_msec()
	print("gen ms: ", t1 - t0, " clubs=", w.clubs.size(), " players=", w.players.size(), " free=", w.free_agents().size())
	for div in 4:
		var l: League = w.season.leagues[div]
		var ovrs := []
		for cid in l.club_ids:
			var c: Club = w.clubs[cid]
			var sq := w.squad(c)
			sq.sort_custom(func(a, b): return a.overall > b.overall)
			var top11 := 0.0
			for i in 11: top11 += sq[i].overall
			ovrs.append("%s %d(%d)" % [c.abbr, int(top11 / 11.0), sq.size()])
		print("D", div + 1, ": ", ", ".join(ovrs))
	var c0: Club = w.clubs[0]
	print(c0.name, " bal=", c0.balance, " fans=", c0.fan_base, " cap=", c0.capacity, " rev=", FinanceManager.expected_revenue(c0), " wages/m=", FinanceManager.wage_bill(w, c0), " wb=", c0.wage_budget, " tb=", c0.transfer_budget)
	for p in w.squad(c0):
		print("  #%d %s (%s) %s %d anos ovr %d pot %d val %s sal %s %s %s" % [p.shirt, p.known_as, p.full_name(), Pos.code(p.position), p.age(w.year), p.overall, p.potential, Fmt.money(p.value), Fmt.money(p.wage), p.traits, p.playstyle()])
	quit()
