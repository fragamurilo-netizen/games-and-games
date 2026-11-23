extends SceneTree
## Lances estruturados de uma luta (o que a luta animada desenha).
## godot --headless --path . --script res://tools/beat_dump.gd -- --seed=3 [--div=leve]


func _initialize() -> void:
	var seed_v := 3
	var div := "leve"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			seed_v = int(a.substr(7))
		elif a.begins_with("--div="):
			div = a.substr(6)
	var w := GameWorld.new()
	w.rng.seed = seed_v
	var fa := FighterGenerator.make(w, div, 70.0)
	var fb := FighterGenerator.make(w, div, 70.0)
	print("%s (%s) x %s (%s)" % [fa.short_name(), fa.base, fb.short_name(), fb.base])
	var e := FightEngine.new()
	e.setup(fa, fb, 3, false, w.rng, {"narrate": true})
	e.run_all()
	var per := {}
	for b: Dictionary in e.beats:
		per[int(b["r"])] = int(per.get(int(b["r"]), 0)) + 1
		print("R%d %6.1f %-12s %2d %s" % [int(b["r"]), float(b["t"]), b["type"], int(b["side"]), b])
	print(per)
	quit()
