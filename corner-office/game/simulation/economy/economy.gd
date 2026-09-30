class_name Economy
extends RefCounted
## Event projection/settlement. Game Bible §12; MMA Bible §§16–17.

func _purses(world: WorldState, fight: Fight) -> Dictionary:
	for r: Dictionary in fight.reasons:
		if r.code=="PURSE_AGREEMENT": return r.data.purses.duplicate(true)
	var result: Dictionary={}
	for id: String in [fight.fighter_a_id,fight.fighter_b_id]:
		var f: Fighter=world.fighters[id]
		var c: Contract=world.contracts.get(f.contract_id)
		result[id]={"show":c.show_money if c else Contracts.market_price(world,f),"win":c.win_bonus if c else 0}
	return result

## Patamar da promoção (regional/nacional/global) escala arena, mídia e
## patrocínio (content/world_tuning.json → tier_economy).
static func tier_factors(org: Organization) -> Dictionary:
	return ContentDB.load_json("world_tuning.json").tier_economy.get(org.tier,{})

static func capacity(org: Organization) -> int:
	return int(ContentDB.load_json("career_tuning.json").event.capacity*float(tier_factors(org).get("capacity",1.0)))

func project_event(world: WorldState, ev: FightEvent) -> Dictionary:
	var cfg: Dictionary=ContentDB.load_json("career_tuning.json").event
	var org: Organization=world.organizations[ev.organization_id]
	var tier:=tier_factors(org)
	var cap:=capacity(org)
	var market:=float(org.market_popularity.get(ev.region,0.0))*float(ContentDB.load_json("world_tuning.json").standing.market_attendance_weight)
	var fame:=0.0
	var purses:=0
	var athletes:=0
	for id: String in ev.fight_ids:
		var fight: Fight=world.fights[id]
		for fighter_id: String in [fight.fighter_a_id,fight.fighter_b_id]:
			var f: Fighter=world.fighters[fighter_id]
			fame+=float(f.popularity_by_region.get(ev.region,0))+f.charisma*.12
			athletes+=1
		for offer: Dictionary in _purses(world,fight).values(): purses+=int(offer.show+offer.win)
	var attendance:=clampi(int(cap*(.24+org.reputation*.006+fame*.0009+market)),0,cap)
	var revenues: Dictionary={"gate":attendance*int(cfg.ticket_price),"media":int(cfg.media_guarantee*float(tier.get("media",1.0))),"sponsors":int((cfg.sponsor_base+fame*42)*float(tier.get("sponsors",1.0)))}
	var costs: Dictionary={"purses":purses,"production":int(cfg.production*float(tier.get("production",1.0))),"venue":int(cfg.venue_cost*float(tier.get("venue_cost",1.0))),"travel":athletes*int(cfg.travel_per_fighter),"officials":int(cfg.officials),"marketing":int(cfg.marketing)}
	var revenue:=0;var total_cost:=0
	for value in revenues.values():revenue+=int(value)
	for value in costs.values():total_cost+=int(value)
	return {"revenue":revenue,"costs":total_cost,"margin":revenue-total_cost,"attendance":attendance,"audience":attendance*18+int(fame*40),"lines":{"revenue":revenues,"costs":costs},"reasons":[Reason.make("EVENT_PROJECTION",revenue-total_cost)]}

func settle_event(world: WorldState, ev: FightEvent) -> Dictionary:
	if not ev.actual.is_empty():return ev.actual
	for id: String in ev.fight_ids:
		if world.fights[id].status!="completed":return {}
	var actual:=project_event(world,ev)
	var paid:=0
	for id: String in ev.fight_ids:
		var fight: Fight=world.fights[id]
		var purses:=_purses(world,fight)
		for fighter_id: String in [fight.fighter_a_id,fight.fighter_b_id]:
			paid+=int(purses[fighter_id].show)
			if fight.winner_id==fighter_id:paid+=int(purses[fighter_id].win)
			var f: Fighter=world.fighters[fighter_id]
			var contract: Contract=world.contracts.get(f.contract_id)
			if contract and contract.active:contract.bouts_remaining=maxi(0,contract.bouts_remaining-1)
			var rest: Dictionary=ContentDB.load_json("career_tuning.json").medical_rest
			var rest_days:=int(rest.ko_loser_days if fight.method=="ko_tko" and fight.winner_id!=fighter_id else rest.standard_days)
			f.medical_suspension_until=GameDate.add_days(ev.date,rest_days)
	var attendance:=clampi(int(actual.attendance*world.rng.range_f(.82,1.12)),0,capacity(world.organizations[ev.organization_id]))
	actual.lines.revenue.gate=attendance*int(ContentDB.load_json("career_tuning.json").event.ticket_price)
	actual.lines.costs.purses=paid
	actual.audience+=18*(attendance-int(actual.attendance))
	actual.attendance=attendance
	actual.revenue=0;actual.costs=0
	for amount in actual.lines.revenue.values():actual.revenue+=int(amount)
	for amount in actual.lines.costs.values():actual.costs+=int(amount)
	actual.margin=actual.revenue-actual.costs
	actual.reasons=[Reason.make("EVENT_SETTLED",actual.margin,{"paid_purses":paid})]
	ev.actual=actual
	world.organizations[ev.organization_id].cash+=int(actual.margin)
	return actual
