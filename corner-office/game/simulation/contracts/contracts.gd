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
	# O pedido vem do agente: mercado, perfil da agência, confiança e BATNA (Agencies).
	var q:=Agencies.quote(world,fighter,org.id)
	var value:=Agencies.offer_value(offer,fighter.agent_id)
	var probability:=clampf(.65+(value/float(q.ask_show)-1.0)*.65,.08,.98)
	var explained: Array=q.reasons.duplicate()
	explained.push_front(Reason.make("CONTRACT_MARKET_VALUE",probability,{"fair_show":q.fair_show,"ask_show":q.ask_show}))
	return {"eligible":reasons.is_empty(),"accept_probability":probability if reasons.is_empty() else 0.0,"fair_show":q.fair_show,"ask_show":q.ask_show,"counter_show":q.ask_show,"meets_ask":value>=float(q.ask_show),"batna_show":q.batna_show,"rival_ids":q.rival_ids,"agent_id":q.agent_id,"trust":q.trust,"reasons":reasons if not reasons.is_empty() else explained}

## Oferta não fechada: fica na memória do agente (Game Bible §9).
func reject(world: WorldState, offer: Contract, response: Dictionary, outcome: String="countered") -> Dictionary:
	if not response.get("eligible",false): return {}
	return Agencies.record(world,offer,int(response.ask_show),outcome)

func sign(world: WorldState, offer: Contract) -> void:
	if world.contracts.has(offer.id): return
	var response:=evaluate_offer(world,offer)
	if not response.eligible: return
	Agencies.record(world,offer,int(response.ask_show),"signed")
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
	var org: Organization=world.organizations[offer.organization_id]
	org.cash-=offer.signing_bonus
	if not org.roster.has(fighter.id): org.roster.append(fighter.id)
	EventBus.contract_signed.emit(offer.id)
