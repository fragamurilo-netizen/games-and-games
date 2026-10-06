extends SceneTree
## Corpo ao longo dos anos (BodyGrowth): altura e peso dos garotos e sobrepeso no mundo.
## godot --headless --path . --script res://tools/body_report.gd -- [--years=N]

func _initialize() -> void:
	var years := 4
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--years="):
			years = int(a.substr(8))
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	var kids: Array = []
	for p: Player in w.players.values():
		if p.age(w.year) <= 17 and p.club_id >= 0:
			kids.append(p)
		if kids.size() >= 6:
			break
	for y in years + 1:
		var over := 0
		var heavy := 0
		var n := 0
		for p: Player in w.players.values():
			if p.club_id < 0:
				continue
			n += 1
			var ov := BodyGrowth.overweight(p, w.year)
			if ov >= 3:
				over += 1
			if ov >= 6:
				heavy += 1
		var line: Array = []
		for p: Player in kids:
			line.append("%d anos %dcm/%dkg (final %d)" % [p.age(w.year), p.height, p.weight, p.adult_h])
		print("%d · acima do peso %.1f%% (muito: %.1f%%) · %s" % [w.year, 100.0 * over / n, 100.0 * heavy / n, " | ".join(line.slice(0, 3))])
		w.year += 1
		BodyGrowth.yearly(w)
		for _wk in 38:
			w.stats["tick_parity"] = 1 - int(w.stats.get("tick_parity", 0))
			BodyGrowth.weekly(w)
	quit()
