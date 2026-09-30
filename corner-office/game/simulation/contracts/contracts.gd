class_name Contracts
extends RefCounted
## Initial contracts and negotiation. Game Bible §9; MMA Bible §§13,25.
static var _config: Dictionary = {}

static func market_price(_world: WorldState, fighter: Fighter) -> int:
	if _config.is_empty(): _config=ContentDB.load_json("career_tuning.json").contracts
	var fame := 0.0
	for value in fighter.popularity_by_region.values(): fame=maxf(fame,float(value))
	var technical := (float(fighter.striking.get("accuracy",50))+float(fighter.grappling.get("takedown_offense",50))+float(fighter.jiu_jitsu.get("submission_offense",50)))/3.0
	return int(_config.minimum_show+technical*_config.skill_multiplier+fame*_config.popularity_multiplier)

func evaluate_offer(world: WorldState, offer: Contract) -> Dictionary:
	var fighter: Fighter=world.fighters.get(offer.fighter_id)
	var org: Organization=world.organizations.get(offer.organization_id)
	var reasons: Array=[]
	if fighter==null or org==null: return {"eligible":false,"accept_probability":0.0,"reasons":[Reason.make("INVALID_CONTRACT")]}
	var current: Contract=world.contracts.get(fighter.contract_id)
	if fighter.retired: reasons.append(Reason.make("RETIRED"))
	if current and current.active and current.exclusive and current.organization_id!=org.id and current.bouts_remaining>0 and GameDate.days_between(world.date,current.expires_on)>0:
		reasons.append(Reason.make("EXCLUSIVE_CONTRACT"))
	if offer.show_money<=0 or offer.win_bonus<0 or offer.signing_bonus<0 or offer.bouts_total<1 or offer.bouts_total>8 or offer.bouts_remaining!=offer.bouts_total or offer.expires_on.is_empty() or GameDate.days_between(world.date,offer.expires_on)<=0:
		reasons.append(Reason.make("INVALID_CONTRACT"))
	if org.cash<offer.signing_bonus: reasons.append(Reason.make("INSUFFICIENT_CASH"))
	var fair:=market_price(world,fighter)
	var rival_bid:=best_rival_bid(world,fighter,org.id)
	if rival_bid>fair: fair=rival_bid
	var probability:=clampf(.65+(float(offer.show_money)/fair-1.0)*.65+(org.reputation-30)*.002,.08,.98)
	return {"eligible":reasons.is_empty(),"accept_probability":probability if reasons.is_empty() else 0.0,"fair_show":fair,"counter_show":int(fair*1.1),"rival_bid":rival_bid,"reasons":reasons if not reasons.is_empty() else [Reason.make("CONTRACT_MARKET_VALUE",probability,{"fair_show":fair,"rival_bid":rival_bid})]}

## Maior proposta rival ainda válida, sem contar a da própria organização.
static func best_rival_bid(world: WorldState, fighter: Fighter, excluding_org: String="") -> int:
	var best:=0
	for org_id: String in fighter.rival_interest:
		var bid: Dictionary=fighter.rival_interest[org_id]
		if org_id==excluding_org or GameDate.days_between(world.date,bid.until)<0: continue
		best=maxi(best,int(bid.show))
	return best

func sign(world: WorldState, offer: Contract) -> void:
	if world.contracts.has(offer.id): return
	if not evaluate_offer(world,offer).eligible: return
	var fighter: Fighter=world.fighters[offer.fighter_id]
	var previous: Contract=world.contracts.get(fighter.contract_id)
	if previous: previous.active=false
	if not fighter.organization_id.is_empty() and fighter.organization_id!=offer.organization_id:
		world.organizations[fighter.organization_id].roster.erase(fighter.id)
	if offer.id.is_empty(): offer.id=world.new_id("ctr")
	offer.signed_on=world.date.duplicate()
	offer.active=true
	world.add("contracts",offer)
	fighter.contract_id=offer.id
	fighter.organization_id=offer.organization_id
	fighter.rival_interest={}
	var org: Organization=world.organizations[offer.organization_id]
	org.cash-=offer.signing_bonus
	if not org.roster.has(fighter.id): org.roster.append(fighter.id)
	EventBus.contract_signed.emit(offer.id)
