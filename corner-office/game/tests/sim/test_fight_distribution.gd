extends TestCase
## Integration + balance smoke test; broad checks, not fitted real-world percentages.
func test_varied_fights_finish_and_have_valid_replays() -> void:
	var engine := FightEngine.new()
	var player := FightReplayPlayer.new()
	var methods := {}
	var submissions := {}
	var pairs := [["ftr_carter","ftr_moreira"],["ftr_reyes","ftr_holloway"],["ftr_arsanov","ftr_sato"],["ftr_costa","ftr_markovic"],["ftr_monroe","ftr_costa"]]
	var orgs := ["org_crown","org_ascend","org_vale","org_shinsei","org_frontline","org_iron","org_pfl"]
	var observed := {}
	for seed_value in 160:
		var world := WorldGenerator.generate(seed_value,"regional_promoter")
		var pair: Array = pairs[seed_value % pairs.size()]
		var event := FightEvent.new()
		event.id = "event_test"
		event.organization_id = orgs[seed_value % orgs.size()]
		world.add("events",event)
		var fight := Fight.new()
		fight.id = "fight_%d" % seed_value
		fight.event_id = event.id
		fight.fighter_a_id = pair[0]
		fight.fighter_b_id = pair[1]
		fight.rounds = 3 if event.organization_id == "org_shinsei" or seed_value%2==0 else 5
		fight.status = "booked"
		engine.simulate(world,fight)
		check_eq(fight.status,"completed","Fight completes seed %d" % seed_value)
		var replay := FightReplayBuilder.build(world,fight)
		if replay.is_empty():
			check(false,"No replay: %d" % seed_value)
			continue
		check(player.load_replay(replay),"Seed %d: %s" % [seed_value,player.errors.slice(0,3)])
		check(fight.end_round >= 1 and fight.end_round <= fight.rounds,"Legal finish round")
		check(fight.end_time_s >= 0 and fight.end_time_s <= 300,"Legal official clock")
		methods[fight.method] = int(methods.get(fight.method,0))+1
		if fight.method == "submission": submissions[fight.method_detail] = true
		for e: Dictionary in replay.events:
			observed[e.outcome] = true
			if e.outcome == "tapped":
				check(float(e.after.submission.progress) >= .9,"Submission must develop before a tap")
			if event.organization_id == "org_shinsei":
				check("cage" not in e.technique_id and e.technique_id != "wall_walk","Ring cannot use cage mechanics")
		if fight.method in ["decision","draw"]:
			check_eq(fight.scorecards.size(),3,"Three scorecards")
			for card: Dictionary in fight.scorecards:
				check_eq(card.scoring,"whole_fight" if event.organization_id == "org_shinsei" else "round_based_10_point_must","Organization judging rules")
	check(methods.has("submission"),"Submissions occur naturally")
	check(methods.has("ko_tko"),"KO/TKO occur naturally")
	check(methods.has("decision"),"Full-distance fights occur naturally")
	check(submissions.size() >= 3,"Different submissions can finish")
	check(observed.has("defended") and observed.has("escaped") and observed.has("blocked"),"Defense succeeds too")
	print("  Combat sample: %s; %d submission finishes; outcomes %s" % [methods,submissions.size(),observed.keys()])
