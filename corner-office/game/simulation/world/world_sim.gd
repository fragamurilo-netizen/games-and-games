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
	_run_scheduled_events()
	# TODO(M2): lesões, camps, negociações e IA das organizações rivais.
	EventBus.day_advanced.emit(world.date)


func advance_week() -> void:
	for i in 7:
		advance_day()
	# TODO(M1): atualizar rankings semanais e gerar notícias da semana.
	EventBus.week_advanced.emit(world.date)


## Roda um evento inteiro: pesagem → lutas → rankings → economia → mídia.
func run_event(event_id: String) -> void:
	var ev: FightEvent = world.events[event_id]
	for fight_id in ev.fight_ids:
		var fight: Fight = world.fights[fight_id]
		if fight.status != "booked":
			continue
		fight_engine.simulate(world, fight)
		EventBus.fight_resolved.emit(fight_id)
	economy.settle_event(world, ev)
	ev.status = "completed"
	EventBus.event_completed.emit(event_id)


func _run_scheduled_events() -> void:
	for ev in world.events.values():
		if ev.status == "announced" and ev.date == world.date:
			run_event(ev.id)
