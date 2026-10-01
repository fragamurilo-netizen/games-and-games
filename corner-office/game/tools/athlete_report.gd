extends SceneTree
## Relatório de realismo da população de atletas (Game Design Bible §0, §21).
## Uso: godot --headless --path game -s res://tools/athlete_report.gd -- [seed]

func _initialize() -> void:
	var generator: GDScript = load("res://simulation/world/world_generator.gd")
	var args := OS.get_cmdline_user_args()
	var seed_value := int(args[0]) if args.size() > 0 else 2027
	var started := Time.get_ticks_msec()
	var world: WorldState = generator.generate(seed_value, "flagship")
	print("Mundo gerado em %d ms: %d atletas" % [Time.get_ticks_msec() - started, world.fighters.size()])
	var report: Dictionary = load("res://tools/athlete_stats.gd").summarize(world)
	print(JSON.stringify(report, "  "))
	var player: Organization = world.player_org()
	print("\nCampeões:")
	for d: String in player.titles:
		var f: Fighter = world.fighters[player.titles[d].champion_id]
		print("  %s: %s (%s, %d anos) %s · rating %d · defesas %d" % [d, f.first_name + " " + f.last_name, f.country, int(CareerModel.age_on(f, world.date)), _rec(f), f.rating, player.titles[d].defenses])
	print("\nAmostra da liga principal:")
	var ids: Array = player.roster.duplicate()
	for i in 14:
		var f: Fighter = world.fighters[ids[(i * 37) % ids.size()]]
		print("  " + _line(world, f))
	print("\nAmostra do circuito (prospects ≤ 24 anos):")
	var n := 0
	for f: Fighter in world.fighters.values():
		if f.organization_id.is_empty() and CareerModel.age_on(f, world.date) <= 24.0 and n < 10:
			print("  " + _line(world, f) + (" ★ blue chip" if f.hidden.get("blue_chip", false) else ""))
			n += 1
	quit()


func _rec(f: Fighter) -> String:
	var r := f.record
	return "%d-%d-%d (KO %d · SUB %d · DEC %d)" % [r.wins, r.losses, r.draws, r.get("ko_wins", 0), r.get("sub_wins", 0), r.get("dec_wins", 0)]


func _line(world: WorldState, f: Fighter) -> String:
	var last: Array = f.history.get("results", []).slice(0, 5).map(func(x): return x.result)
	return "%s %s | %s %s | %d anos | %s | %d/%d cm, %.1f kg %s | %s | %s | pico %.0f hoje %.0f | últimas %s | %s" % [f.first_name, f.last_name, f.country, f.appearance.get("pop", ""), int(CareerModel.age_on(f, world.date)), f.division, f.height_cm, f.reach_cm, f.natural_weight_kg, f.body_type, f.martial_base, _rec(f), f.hidden.ability_peak, CareerModel.ability_at(f, CareerModel.age_on(f, world.date)), "".join(last), f.history.get("background", "")]
