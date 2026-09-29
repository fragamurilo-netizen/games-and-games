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


func _init(w: WorldState) -> void:
	world = w


func advance_day() -> void:
	world.date = GameDate.add_days(world.date, 1)
	_expire_contracts()
	_run_scheduled_events()
	# TODO(M2): lesões, camps, negociações e IA das organizações rivais.
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
		EventBus.fight_resolved.emit(fight_id)
	for fight_id: String in ev.fight_ids:
		if world.fights[fight_id].status!="completed":return
	economy.settle_event(world, ev)
	ev.status = "completed"
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
	for pair: Array in changed.values():rankings.update(world,pair[0],pair[1])
