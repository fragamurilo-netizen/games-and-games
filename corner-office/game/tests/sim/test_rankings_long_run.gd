extends TestCase
## Rankings em um ano de mundo vivo: listas se movem, sem saltos absurdos e
## com motivo para cada mudança. Game Design Bible §7; MMA Bible §23.8–10.


func test_year_of_rankings_moves_with_reasons_and_capped_jumps() -> void:
	var world := WorldGenerator.generate(21, "regional_promoter")
	var sim := WorldSim.new(world)
	for i in 365:
		sim.advance_day()
	var climb := int(ContentDB.load_json("ranking_tuning.json").max_climb)
	var snapshots := 0; var moves := 0; var explained := 0; var absurd := 0
	for key: String in world.rankings:
		var history: Array = world.rankings[key]
		for s in range(1, history.size()):
			var r: Ranking = history[s]; var prev: Ranking = history[s - 1]
			snapshots += 1
			var kept: Array = prev.entries.filter(func(x): return x in r.entries)
			for id: String in r.changes:
				var c: Dictionary = r.changes[id]
				if int(c.to) < 0 or int(c.from) < 0: continue
				moves += 1
				if str(c.reason.code) != "OTHERS_MOVED": explained += 1
				if key.ends_with(":p4p"): continue
				var jumped := kept.find(id) - int(c.to)
				var reason: Dictionary = c.reason.data.get("cause", c.reason) if c.reason.code == "JUMP_CAPPED" else c.reason
				var exceptional: bool = reason.code == "WIN_OVER" and kept.find(reason.data.opponent_id) >= 0 and kept.find(reason.data.opponent_id) <= int(c.to)
				if jumped > climb and not exceptional:
					absurd += 1; print("  salto: %s %s %d→%d %s" % [key, id, kept.find(id), int(c.to), str(c.reason)])
			check(r.entries.size() == prev.entries.size() or not r.changes.is_empty(), "snapshot novo traz mudanças")
	print("  Rankings em 1 ano: %d snapshots, %d movimentos, %d com motivo direto, %d saltos sem vitória excepcional" % [snapshots, moves, explained, absurd])
	check(snapshots > 50, "listas atualizam ao longo do ano")
	check(explained > 0, "mudanças têm reason codes de luta")
	check_eq(absurd, 0, "nenhum salto acima do limite sem vitória excepcional")
	check(Rankings.new().latest(world, Rankings.WCI_ORG_ID, Rankings.P4P_DIVISION) != null, "P4P existe após um ano")
