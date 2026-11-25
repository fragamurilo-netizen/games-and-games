extends Node
## A/B measurement with the same world and exact ordering equivalence.
func _ready() -> void:
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	GameManager.start_career(w, w.clubs_in_league("BRA1")[2].id, "Teste", GameWorld.DIFF_NORMAL, -1)
	var market: Node = load("res://scripts/ui/screens/market_screen.gd").new()
	var baseline := w.free_agents()
	var improved := baseline.duplicate()
	var begin := Time.get_ticks_usec()
	baseline.sort_custom(func(a: Player, b: Player): return PlayerAssessment.score(w, a) > PlayerAssessment.score(w, b))
	var old_ms := (Time.get_ticks_usec() - begin) / 1000.0
	begin = Time.get_ticks_usec()
	market.call("_sort_free", w, improved)
	var new_ms := (Time.get_ticks_usec() - begin) / 1000.0
	var equivalent := baseline == improved
	print("MARKET_FREE_PERF candidates=%d old_ms=%.2f new_ms=%.2f identical=%s" % [baseline.size(), old_ms, new_ms, equivalent])
	# Reordering after an assessment change must not reuse stale scores.
	if not baseline.is_empty():
		var p: Player = baseline[-1]
		for ai in p.attrs.size():
			p.attrs[ai] = 99
		baseline.sort_custom(func(a: Player, b: Player): return PlayerAssessment.score(w, a) > PlayerAssessment.score(w, b))
		market.call("_sort_free", w, improved)
		equivalent = equivalent and baseline == improved
	market.free()
	print("MARKET_PERFORMANCE_RESULT failures=", 0 if equivalent else 1)
	get_tree().quit(0 if equivalent else 1)
