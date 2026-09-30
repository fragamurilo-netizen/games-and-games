class_name WorldSim
extends RefCounted
## Relógio do mundo (Game Design Bible §13, §17). O mundo simula sem o
## jogador: cada tick roda todos os sistemas, inclusive as organizações rivais.

var world: WorldState
var matchmaking := Matchmaking.new()
var fight_engine := FightEngine.new()
var rankings := Rankings.new()
var contracts := Contracts.new()
var economy := Economy.new()
var popularity := Popularity.new()
var media := Media.new()
var org_ai := OrgAI.new()
var life_cycle := LifeCycle.new()
var standing := OrgStanding.new()


func _init(w: WorldState) -> void:
	world = w


func advance_day() -> void:
	world.date = GameDate.add_days(world.date, 1)
	_expire_contracts()
	_run_scheduled_events()
	# Passagem do tempo (Game Design Bible §13): lesões diárias; no dia 1º,
	# chegada de prospectos e aposentadoria de agentes livres (FighterGenerator),
	# evolução e aposentadoria de contratados (LifeCycle), reputação e temporada.
	if int(world.date.day) == 1:
		FighterGenerator.monthly_intake(world)
	life_cycle.daily(world)
	if int(world.date.day) == 1:
		standing.monthly(world)
		EventBus.month_advanced.emit(world.date)
	standing.ensure_objectives(world)
	org_ai.tick(world)
	# TODO(M2): camps e negociações com memória de agentes.
	EventBus.day_advanced.emit(world.date)


func advance_week() -> void:
	for i in 7:
		advance_day()
	# Rankings/news update from factual event completion; inactive weeks stay quiet.
	EventBus.week_advanced.emit(world.date)


## Roda um evento inteiro: pesagem → lutas → rankings → economia → mídia.
func run_event(event_id: String) -> void:
	var ev: FightEvent = world.events.get(event_id)
	if ev==null or ev.status!="announced" or GameDate.days_between(ev.date,world.date)<0:return
	# Eligibility can change after announcement (e.g. a KO in an earlier event).
	for id: String in ev.fight_ids:
		var bout: Fight=world.fights[id]
		if bout.status!="booked":continue
		var validation:=matchmaking.evaluate(world,bout.fighter_a_id,bout.fighter_b_id,ev.id,1.0,bout.id,false)
		if not validation.eligible:
			ev.status="postponed"
			var cfg: Dictionary=ContentDB.load_json("career_tuning.json").story
			var item:=media.publish(world,"event_postponed",[ev.id],validation.reasons)
			item.headline=str(cfg.event_postponed).replace("{event}",ev.name);item.body=cfg.postponed_body
			return
	for fight_id in ev.fight_ids:
		var fight: Fight = world.fights[fight_id]
		if fight.status != "booked":
			continue
		fight_engine.simulate(world, fight)
		if fight.status == "completed":
			popularity.apply_fight_result(world, fight, ev.region)
			life_cycle.after_fight(world, fight)
		EventBus.fight_resolved.emit(fight_id)
	for fight_id: String in ev.fight_ids:
		if world.fights[fight_id].status!="completed":return
	economy.settle_event(world, ev)
	ev.status = "completed"
	standing.after_event(world, ev)
	for division: Dictionary in ContentDB.load_json("weight_classes.json"):
		rankings.update(world,ev.organization_id,division.id)
		rankings.update(world,"wci",division.id)
	media.event_report(world,ev)
	EventBus.event_completed.emit(event_id)


func _run_scheduled_events() -> void:
	for ev in world.events.values():
		if ev.status == "announced" and ev.date == world.date:
			run_event(ev.id)


func _expire_contracts() -> void:
	var changed: Dictionary={}
	for c: Contract in world.contracts.values():
		if not c.active:continue
		if c.bouts_remaining>0 and GameDate.days_between(world.date,c.expires_on)>=0:continue
		c.active=false
		var f: Fighter=world.fighters[c.fighter_id]
		if f.contract_id==c.id:
			world.organizations[c.organization_id].roster.erase(f.id)
			f.organization_id=""
			changed[c.organization_id+":"+f.division]=[c.organization_id,f.division]
			var destination:=_accept_rival_bid(f,c.organization_id)
			if not destination.is_empty():changed[destination+":"+f.division]=[destination,f.division]
	for pair: Array in changed.values():rankings.update(world,pair[0],pair[1])


## Fim de contrato com proposta rival na mesa: o atleta assina com quem
## ofereceu mais e ainda tem caixa (Game Design Bible §9).
func _accept_rival_bid(f: Fighter, previous_org: String) -> String:
	var bids: Array=[]
	for org_id: String in f.rival_interest:
		var bid: Dictionary=f.rival_interest[org_id]
		if GameDate.days_between(world.date,bid.until)>=0 and world.organizations.has(org_id):bids.append([org_id,int(bid.show)])
	bids.sort_custom(func(a,b):return a[1]>b[1] if a[1]!=b[1] else a[0]<b[0])
	var cfg: Dictionary=ContentDB.load_json("career_tuning.json").contracts
	for pair: Array in bids:
		var org: Organization=world.organizations[pair[0]]
		if org.cash<0:continue
		var offer:=Contract.new()
		offer.fighter_id=f.id;offer.organization_id=org.id;offer.show_money=pair[1]
		offer.win_bonus=int(offer.show_money*float(cfg.win_bonus_ratio));offer.bouts_total=int(cfg.bouts);offer.bouts_remaining=offer.bouts_total
		offer.expires_on=GameDate.add_days(world.date,int(cfg.term_days))
		if not contracts.evaluate_offer(world,offer).eligible:continue
		contracts.sign(world,offer)
		LifeCycle.story(world,"fighter_departed","departed",{"fighter":f.display_name(),"previous":world.organizations[previous_org].name,"organization":org.name,"show":"US$ %d"%offer.show_money},[f.id,org.id,previous_org])
		return org.id
	f.rival_interest={}
	return ""
