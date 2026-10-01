extends TestCase
## Full M1 service flow, no UI implementation of game rules. Bible §20.

func _book_six(world: WorldState, event_id: String) -> void:
	var groups: Dictionary={}
	for id: String in world.player_org().roster:
		var f: Fighter=world.fighters[id]
		if not groups.has(f.division):groups[f.division]=[]
		groups[f.division].append(id)
	for i in range(0,12,2):
		for ids: Array in groups.values():
			if i+1>=ids.size():continue
			if world.events[event_id].fight_ids.size()>=6:return
			for premium in [1.0,1.5,2.0]:
				var r:=CareerActions.perform(world,"propose",{"event_id":event_id,"red":ids[i],"blue":ids[i+1],"premium":premium})
				if r.get("proposal",{}).get("outcome")=="accepted":break

func test_generated_world_and_six_bout_career_loop() -> void:
	var world:=WorldGenerator.generate(44,"regional_promoter")
	check(world.fighters.size()>=100,"100+ coherent fighters")
	check(world.player_org().roster.size()>=20,"Playable starting roster")
	var names: Dictionary={}
	for f: Fighter in world.fighters.values():
		check(not names.has(f.first_name+" "+f.last_name),"Unique generated full name")
		names[f.first_name+" "+f.last_name]=true
		check(f.sex==Fighter.Sex.FEMALE if f.division.begins_with("w_") else f.sex==Fighter.Sex.MALE,"Sex matches division")
	var created:=CareerActions.perform(world,"create_event",{"name":"Teste de carreira","days":42})
	check(created.ok,"Create event")
	var id: String=created.event_id
	check(not CareerActions.perform(world,"announce",{"event_id":id}).ok,"Cannot announce empty card")
	_book_six(world,id)
	var ev: FightEvent=world.events[id]
	check_eq(ev.fight_ids.size(),6,"Six accepted bouts")
	check(CareerActions.perform(world,"announce",{"event_id":id}).ok,"Announce complete card")
	var cash:=world.player_org().cash
	var office_before:=world.player_org().ledger.size()
	check(CareerActions.perform(world,"advance_event",{"event_id":id}).ok,"Advance to fight night")
	check_eq(ev.status,"completed","Night finishes")
	check_eq(world.player_org().cash,cash+int(ev.actual.margin)+_office_moves(world,office_before),"Exactly one settlement (além da folha da sede)")
	check_eq(world.news.values().filter(func(n: NewsItem): return n.topic=="event_completed" and ev.id in n.entity_ids).size(),1,"One factual event report")
	for fight_id: String in ev.fight_ids:
		var f: Fight=world.fights[fight_id]
		check_eq(f.status,"completed","Real combat engine used")
		check(not f.round_log.is_empty(),"Complete replay events")
		var replay:=FightReplayBuilder.build(world,f)
		check(FightReplayPlayer.new().load_replay(replay),"Player promotion arena validates")
		for athlete: String in [f.fighter_a_id,f.fighter_b_id]:
			check_eq(world.contracts[world.fighters[athlete].contract_id].bouts_remaining,3,"Contract fight consumed once")
	var settled:=world.to_dict().duplicate(true)
	WorldSim.new(world).run_event(id)
	check_eq(world.to_dict(),settled,"Running a completed event is idempotent")
	var saved:=SaveSystem.decode(SaveSystem.encode(world))
	check_eq(saved.player_org().cash,world.player_org().cash,"Cash survives save")
	check_eq(saved.events[id].fight_ids,ev.fight_ids,"Card survives save")
	check_eq(saved.rng.range_i(0,999999),world.rng.range_i(0,999999),"RNG continuation after full career loop")

func test_eligibility_and_separate_scores() -> void:
	var world:=WorldGenerator.generate(12,"regional_promoter")
	var event_id: String=CareerActions.perform(world,"create_event",{}).event_id
	var ids: Array=world.player_org().roster
	var mm:=Matchmaking.new()
	var quote:=mm.evaluate(world,ids[0],ids[4],event_id)
	check(quote.eligible,"Same division and valid contracts")
	check(quote.sporting_fit>0 and quote.commercial_fit>0,"Distinct sporting and commercial scores")
	check_eq(quote.acceptance.size(),2,"Each athlete has own acceptance")
	check(not mm.evaluate(world,ids[0],ids[2],event_id).eligible,"No male/female mismatch")
	check(not mm.evaluate(world,ids[0],ids[1],event_id).eligible,"No division mismatch")
	world.fighters[ids[0]].medical_suspension_until=GameDate.add_days(world.date,90)
	check(not mm.evaluate(world,ids[0],ids[4],event_id).eligible,"Medical suspension blocks booking")
	var before:=world.rng.get_state()
	var r:=CareerActions.perform(world,"propose",{"event_id":event_id,"red":ids[0],"blue":ids[4]})
	check_eq(r.proposal.outcome,"refused","Unavailable bout refused")
	check_eq(world.rng.get_state(),before,"Invalid proposals consume no RNG")

func test_contracts_and_market_change_roster() -> void:
	var world:=WorldGenerator.generate(7,"regional_promoter")
	var free: Fighter=null
	for f: Fighter in world.fighters.values():
		if f.organization_id.is_empty():free=f;break
	check(free!=null,"Free agency exists")
	var low:=CareerActions.perform(world,"negotiate",{"fighter_id":free.id,"show_money":1})
	check(low.has("counter_show"),"Under-market offer generates counter")
	check(free.organization_id.is_empty(),"Counter does not sign silently")
	var response:=CareerActions.perform(world,"negotiate",{"fighter_id":free.id,"show_money":int(low.counter_show)})
	check(response.ok and not response.has("counter_show"),"Agent's counter closes the deal")
	check(world.player_org().roster.has(free.id),"New athlete in roster")
	var old_id:=free.contract_id
	var renewal:=CareerActions.perform(world,"negotiate",{"fighter_id":free.id,"show_money":world.contracts[old_id].show_money})
	if renewal.has("counter_show"):CareerActions.perform(world,"negotiate",{"fighter_id":free.id,"show_money":int(renewal.counter_show)})
	check(not world.contracts[old_id].active,"Renewal retains inactive historical contract")
	check_eq(world.player_org().roster.count(free.id),1,"No duplicate roster entry")


func test_late_medical_change_postpones_without_paying_and_can_reschedule() -> void:
	var world:=WorldGenerator.generate(42,"regional_promoter")
	var id: String=CareerActions.perform(world,"create_event",{}).event_id
	_book_six(world,id)
	check(CareerActions.perform(world,"announce",{"event_id":id}).ok,"Card announced")
	var ev: FightEvent=world.events[id]
	var f: Fight=world.fights[ev.fight_ids[0]]
	world.fighters[f.fighter_a_id].medical_suspension_until=GameDate.add_days(ev.date,50)
	var cash:=world.player_org().cash
	var office_before:=world.player_org().ledger.size()
	CareerActions.perform(world,"advance_event",{"event_id":id})
	check_eq(ev.status,"postponed","A later medical change stops the event")
	check_eq(world.player_org().cash,cash+_office_moves(world,office_before),"No settlement for an unavailable card")
	check_eq(f.status,"booked","No partial fight night")
	check(CareerActions.perform(world,"reschedule",{"event_id":id,"days":60}).ok,"Reschedule after recovery")
	check(CareerActions.perform(world,"announce",{"event_id":id}).ok,"Revalidate before new announcement")
	CareerActions.perform(world,"advance_event",{"event_id":id})
	check_eq(ev.status,"completed","Recovered card can run")


## Folha e decisões da sede entram no caixa pelo livro-caixa da organização.
func _office_moves(world: WorldState, from: int) -> int:
	var total:=0
	for entry: Dictionary in world.player_org().ledger.slice(from):total+=int(entry.amount)
	return total
