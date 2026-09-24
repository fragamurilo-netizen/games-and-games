extends SceneTree

func _initialize() -> void:
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	var t0 := Time.get_ticks_usec()
	var sheets := {}
	for c in w.clubs:
		sheets[c.id] = ClubAI.prepare_ai_sheet(w, c, null, true)
	var t1 := Time.get_ticks_usec()
	print("prepare_ai_sheet avg us: ", (t1 - t0) / 80)
	for pair in [[0, 19], [0, 70], [10, 11], [40, 41]]:
		var h: Club = w.clubs[pair[0]]
		var a: Club = w.clubs[pair[1]]
		var sim := MatchSimulation.new()
		sim.setup(w, h, a, sheets[h.id], sheets[a.id], {"attendance": int(h.capacity * 0.6)}, 7, false)
		for t in sim.teams:
			print("%s str=%.1f att=%.1f def=%.1f mid=%.1f gk=%.1f aer=%.1f/%.1f width=%.1f ment=%d style=%d form=%s" % [t.club.abbr, ClubAI.team_strength(w, t.club), t.u_att, t.u_def, t.u_mid, t.u_gk, t.aerial_att, t.aerial_def, t.width, t.mentality, t.style, t.sheet.formation])
		var t2 := Time.get_ticks_usec()
		sim.run_to_end()
		print("   sim us: ", Time.get_ticks_usec() - t2, " score ", sim.score)
	quit()
