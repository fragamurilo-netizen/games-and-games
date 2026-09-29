extends TestCase

func _bout(world: WorldState) -> Fight:
	var fight := Fight.new()
	fight.id = "test_fight"
	fight.fighter_a_id = "ftr_carter"
	fight.fighter_b_id = "ftr_moreira"
	fight.status = "booked"
	world.add("fights",fight)
	return fight

func test_seed_replay_and_resolution_are_immutable() -> void:
	var engine := FightEngine.new()
	var w1 := WorldGenerator.generate(2027,"regional_promoter")
	var w2 := WorldGenerator.generate(2027,"regional_promoter")
	var f1 := engine.simulate(w1,_bout(w1))
	var f2 := engine.simulate(w2,_bout(w2))
	check_eq(f1.to_dict(),f2.to_dict(),"Same seed, same entire historical fight")
	var before := w1.to_dict()
	var log := FightReplayBuilder.build(w1,f1)
	var player := FightReplayPlayer.new()
	check(player.load_replay(log),str(player.errors))
	for t in [0.0,10000.0,player.duration_ms,500.0,player.duration_ms]:
		player.seek_ms(t)
	engine.simulate(w1,f1)
	check_eq(w1.to_dict(),before,"Replay and repeated resolution never consume RNG or alter history")
	var restored := SaveSystem.decode(SaveSystem.encode(w1))
	check(_equal_saved(restored.fights[f1.id].round_log,f1.round_log),"Resolved events survive at native JSON save precision")
	var restored_log := FightReplayBuilder.build(restored,restored.fights[f1.id])
	check(_equal_saved(restored_log,log),"Save round trip preserves the replay at JSON precision")
	check(player.load_replay(restored_log),"Restored snapshots remain continuous")
	check_eq(restored.rng.range_i(0,1000000),w1.rng.range_i(0,1000000),"Save preserves the next RNG draw after a fight")
	check_eq(w1.fighters.ftr_carter.fight_ids.count(f1.id),1,"Record settlement only once")
	check_eq(player.seek_ms(player.duration_ms).result,log.result,"Final replay result is authoritative")

func test_judges_prioritize_effect_not_empty_control() -> void:
	var a := FightEngine._empty_stats()
	var b := FightEngine._empty_stats()
	a.striking_impact = .12
	b.control_s = 290
	b.aggression = 100
	var log := {"fighter_ids":["a","b"],"stats":{"a":a,"b":b},"elapsed_s":300}
	var judge := Judge.new()
	var rng := SimRandom.new(44)
	check_eq(judge.score_round(log,rng),[10,9],"Control does not override damage")
	b.grappling_impact = .25
	check_eq(judge.score_round(log,rng),[9,10],"Effective submission offense can outweigh strikes")
	a.striking_impact = .26
	judge.impact_weight = .90
	judge.grappling_result_weight = 1.15
	check_eq(judge.score_round(log,rng),[9,10],"Close round: grappling impact interpretation")
	judge.impact_weight = 1.1
	judge.grappling_result_weight = .85
	check_eq(judge.score_round(log,rng),[10,9],"Close round: striking impact interpretation")
	check_eq(judge.score_round(log,rng),judge.score_round(log,rng),"Judging does not roll a random winner")

func test_invalid_bookings_do_not_mutate_fighters() -> void:
	var world := WorldGenerator.generate(7,"regional_promoter")
	var fight := _bout(world)
	fight.fighter_b_id = fight.fighter_a_id
	var original: Dictionary = world.fighters.ftr_carter.to_dict()
	FightEngine.new().simulate(world,fight)
	check_eq(fight.status,"booked","Invalid input rejected")
	check_eq(world.fighters.ftr_carter.to_dict(),original,"No record changes on rejected input")

## JSON.from_native preserves types, but float text can differ by a few ULPs.
## All structure, ids, outcomes and integer values must stay exact.
func _equal_saved(a: Variant,b: Variant) -> bool:
	if typeof(a) != typeof(b): return false
	if a is float: return absf(a-b) <= 1e-12*maxf(1.0,absf(b))
	if a is Array:
		if a.size()!=b.size(): return false
		for i in a.size():
			if not _equal_saved(a[i],b[i]): return false
		return true
	if a is Dictionary:
		if a.size()!=b.size(): return false
		for key in a:
			if not b.has(key) or not _equal_saved(a[key],b[key]): return false
		return true
	return a == b
