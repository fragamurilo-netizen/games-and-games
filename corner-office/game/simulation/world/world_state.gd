class_name WorldState
extends RefCounted
## Estado completo do mundo. Tudo que precisa persistir fica aqui.
## Coleções são indexadas por id estável.

const SCHEMA_VERSION := 4

var schema_version := SCHEMA_VERSION
var seed_value := 0
var rng := SimRandom.new()
## Fluxo próprio da sede (Office): staff e dilemas não deslocam o sorteio das
## lutas, mas continuam determinísticos e salvos com o mundo.
var office_rng := SimRandom.new()
var date := GameDate.START.duplicate()
var player_org_id := ""
var next_ids := {}             # prefixo -> contador (ids nunca reutilizados)

var fighters := {}
var organizations := {}
var contracts := {}
var fights := {}
var events := {}
var gyms := {}
var agents := {}
var rankings := {}             # "org:division" -> Array[Ranking] (histórico)
var news := {}
var staff := {}
var dilemmas := {}

## Coleção -> classe da entidade. (Função, não const: classes globais não
## são expressões constantes em GDScript.)
static func collections() -> Dictionary:
	return {
		"fighters": Fighter,
		"organizations": Organization,
		"contracts": Contract,
		"fights": Fight,
		"events": FightEvent,
		"gyms": Gym,
		"agents": Agent,
		"news": NewsItem,
		"staff": StaffMember,
		"dilemmas": Dilemma,
	}


func new_id(prefix: String) -> String:
	var n: int = next_ids.get(prefix, 0) + 1
	next_ids[prefix] = n
	return "%s_%06d" % [prefix, n]


func add(collection: String, entity: Entity) -> Entity:
	var coll: Dictionary = get(collection)
	assert(not coll.has(entity.id), "id duplicado: %s" % entity.id)
	coll[entity.id] = entity
	return entity


func player_org() -> Organization:
	return organizations.get(player_org_id)


func to_dict() -> Dictionary:
	var d := {
		"schema_version": schema_version,
		"seed_value": seed_value,
		"rng_state": str(rng.get_state()),
		"office_rng_state": str(office_rng.get_state()),
		"date": date,
		"player_org_id": player_org_id,
		"next_ids": next_ids,
		"rankings": {},
	}
	for c in collections():
		var out := {}
		var coll: Dictionary = get(c)
		for id in coll:
			out[id] = coll[id].to_dict()
		d[c] = out
	for key in rankings:
		d.rankings[key] = rankings[key].map(func(r: Ranking): return r.to_dict())
	return d


static func from_dict(d: Dictionary) -> WorldState:
	var w := WorldState.new()
	w.schema_version = int(d.schema_version)
	w.seed_value = int(d.seed_value)
	w.rng.set_state(int(d.rng_state))
	if d.has("office_rng_state"):w.office_rng.set_state(int(d.office_rng_state))
	else:w.office_rng=SimRandom.new(int(d.seed_value)*7919+17)
	w.date = d.date
	w.player_org_id = d.player_org_id
	w.next_ids = d.next_ids
	var classes := collections()
	for c in classes:
		var coll: Dictionary = w.get(c)
		for id in d.get(c, {}):
			coll[id] = classes[c].new().load_dict(d[c][id])
	for key in d.get("rankings", {}):
		w.rankings[key] = d.rankings[key].map(func(r): return Ranking.new().load_dict(r))
	return w
