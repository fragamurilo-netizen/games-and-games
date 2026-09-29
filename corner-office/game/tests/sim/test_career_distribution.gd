extends TestCase
## Two consecutive mixed-division events across eight seeds. Bible §§12–13,20.
## Broad solvency/accounting assertions, not claimed real-world calibration.
func test_regional_career_repeats_with_mixed_cards_and_valid_accounts() -> void:
	var margins: Array=[]
	var helper: TestCase=load("res://tests/unit/test_career.gd").new()
	for seed_value in range(30,38):
		var world:=WorldGenerator.generate(seed_value,"regional_promoter")
		for night in 2:
			var id: String=CareerActions.perform(world,"create_event",{"days":75}).event_id
			helper._book_six(world,id)
			var ev: FightEvent=world.events[id]
			check_eq(ev.fight_ids.size(),6,"Six accepted bouts, seed %d"%seed_value)
			check(CareerActions.perform(world,"announce",{"event_id":id}).ok,"Announce mixed card")
			var before:=world.player_org().cash
			CareerActions.perform(world,"advance_event",{"event_id":id})
			check_eq(ev.status,"completed","Repeated event resolves")
			if ev.actual.is_empty():continue
			check_eq(world.player_org().cash,before+int(ev.actual.margin),"Ledger reconciles")
			check(int(ev.actual.costs)<=int(ev.projected.costs),"Agreed purse budget covers actual obligations")
			check(int(ev.actual.attendance)<=2800 and int(ev.actual.attendance)>0,"Attendance within venue capacity")
			check(world.player_org().cash>0,"Regional starting capital supports two initial nights")
			var women:=0;var men:=0
			for fight_id: String in ev.fight_ids:
				var f: Fight=world.fights[fight_id]
				if world.fighters[f.fighter_a_id].sex==Fighter.Sex.FEMALE:women+=1
				else:men+=1
				check(FightReplayPlayer.new().load_replay(FightReplayBuilder.build(world,f)),"Generated athletes have valid player-arena replays")
			check(women>0 and men>0,"Both divisions represented")
			margins.append(ev.actual.margin)
	print("  Regional career sample: 16 events, 96 bouts; margins ",margins)
