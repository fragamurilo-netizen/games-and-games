class_name Matchmaking
extends RefCounted
## Separate sporting fit, each athlete's acceptance and commercial fit. Bible §7; MMA §22.

func evaluate(world: WorldState, fighter_a_id: String, fighter_b_id: String, event_id: String, premium: float=1.0, ignore_fight: String="", check_timing: bool=true) -> Dictionary:
	var a: Fighter=world.fighters.get(fighter_a_id)
	var b: Fighter=world.fighters.get(fighter_b_id)
	var ev: FightEvent=world.events.get(event_id)
	var result: Dictionary={"eligible":false,"sporting_fit":0.0,"acceptance":{},"commercial_fit":0.0,"projected_cost":0,"purses":{},"reasons":[]}
	if a==null or b==null or ev==null or a==b:
		result.reasons.append(Reason.make("INVALID_MATCHUP"));return result
	var notice:=GameDate.days_between(world.date,ev.date)
	if check_timing and (ev.status!="planned" or notice<1): result.reasons.append(Reason.make("EVENT_CLOSED"))
	if a.sex!=b.sex: result.reasons.append(Reason.make("SEX_MISMATCH"))
	if a.division!=b.division: result.reasons.append(Reason.make("DIVISION_MISMATCH"))
	for f: Fighter in [a,b]:
		if f.retired: result.reasons.append(Reason.make("RETIRED",0,{"fighter_id":f.id}))
		if not f.injuries.is_empty(): result.reasons.append(Reason.make("INJURED",0,{"fighter_id":f.id}))
		if not f.medical_suspension_until.is_empty() and GameDate.days_between(ev.date,f.medical_suspension_until)>0:
			result.reasons.append(Reason.make("MEDICAL_SUSPENSION",0,{"fighter_id":f.id}))
		var contract: Contract=world.contracts.get(f.contract_id)
		if f.organization_id!=ev.organization_id or contract==null or not contract.active or contract.bouts_remaining<1 or GameDate.days_between(ev.date,contract.expires_on)<0:
			result.reasons.append(Reason.make("NO_VALID_CONTRACT",0,{"fighter_id":f.id}))
		var reserved_bouts:=0
		for other: Fight in world.fights.values():
			if other.id==ignore_fight or other.status!="booked" or f.id not in [other.fighter_a_id,other.fighter_b_id]: continue
			reserved_bouts+=1
			var other_event: FightEvent=world.events.get(other.event_id)
			if other_event and abs(GameDate.days_between(ev.date,other_event.date))<28:
				result.reasons.append(Reason.make("ALREADY_BOOKED",0,{"fighter_id":f.id}))
		if contract and reserved_bouts>=contract.bouts_remaining:result.reasons.append(Reason.make("NO_VALID_CONTRACT",0,{"fighter_id":f.id}))
		var show:=int((contract.show_money if contract else Contracts.market_price(world,f))*clampf(premium,1.0,2.0))
		var bonus:=int((contract.win_bonus if contract else show/2.0)*clampf(premium,1.0,2.0))
		result.purses[f.id]={"show":show,"win":bonus}
		result.projected_cost+=show+bonus
		var acceptance:=clampf(.76+minf(56,notice)*.002+(premium-1)*.45-float(f.mental.get("discipline",50))*.001,.15,.98)
		if notice<21: acceptance-=.18
		result.acceptance[f.id]=acceptance
	var record_gap:=absf(float(a.record.wins-b.record.wins))
	result.sporting_fit=clampf(88-record_gap*2.5+(8 if a.martial_base!=b.martial_base else 0),10,98)
	var fame_a:=0.0;var fame_b:=0.0
	for value in a.popularity_by_region.values(): fame_a=maxf(fame_a,value)
	for value in b.popularity_by_region.values(): fame_b=maxf(fame_b,value)
	result.commercial_fit=clampf((fame_a+fame_b)*.8+(a.charisma+b.charisma)*.15,0,100)
	result.eligible=result.reasons.is_empty()
	if result.eligible:
		result.reasons=[Reason.make("SPORTING_FIT",result.sporting_fit),Reason.make("CAMP_NOTICE",notice),Reason.make("COMMERCIAL_APPEAL",result.commercial_fit)]
	return result

func propose(world: WorldState, fight: Fight) -> Dictionary:
	var premium:=1.0
	for r: Dictionary in fight.reasons:
		if r.code=="PURSE_OFFER": premium=float(r.weight)
	var quote:=evaluate(world,fight.fighter_a_id,fight.fighter_b_id,fight.event_id,premium)
	if not quote.eligible: return {"outcome":"refused","reasons":quote.reasons}
	# A declined offer cannot be rerolled by clicking again at the same terms.
	for prior: Fight in world.fights.values():
		if prior.event_id!=fight.event_id or prior.status!="proposed":continue
		if prior.fighter_a_id not in [fight.fighter_a_id,fight.fighter_b_id] or prior.fighter_b_id not in [fight.fighter_a_id,fight.fighter_b_id]:continue
		for r: Dictionary in prior.reasons:
			if r.code=="PROPOSAL_RESPONSE" and float(r.data.get("premium",1.0))>=premium:
				return {"outcome":r.data.outcome,"reasons":[Reason.make("OFFER_UNCHANGED")],"fight_id":prior.id}
	var refused: Array=[]
	for id: String in [fight.fighter_a_id,fight.fighter_b_id]:
		if not world.rng.chance(quote.acceptance[id]):refused.append(id)
	var outcome: String="accepted" if refused.is_empty() else "counter"
	fight.id=world.new_id("fight")
	fight.status="booked" if refused.is_empty() else "proposed"
	fight.reasons.append_array(quote.reasons)
	fight.reasons.append(Reason.make("PROPOSAL_RESPONSE",0,{"outcome":outcome,"premium":premium,"refused_ids":refused}))
	fight.reasons.append(Reason.make("PURSE_AGREEMENT",quote.projected_cost,{"purses":quote.purses}))
	world.add("fights",fight)
	if outcome=="accepted":world.events[fight.event_id].fight_ids.append(fight.id)
	return {"outcome":outcome,"fight_id":fight.id,"reasons":[Reason.make("BOTH_ACCEPTED" if refused.is_empty() else "COUNTER_PURSE",0,{"fighter_ids":refused})]}
