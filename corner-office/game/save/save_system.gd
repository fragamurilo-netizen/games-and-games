class_name SaveSystem
extends RefCounted
## Saves versionados com migração (Game Design Bible §17–18).
## Ao mudar o formato de WorldState:
##  1. Incremente WorldState.SCHEMA_VERSION.
##  2. Adicione _migrate_vN_to_vN+1 abaixo e registre em MIGRATIONS.
##  3. Adicione um fixture de save antigo em tests/ e um teste de migração.
## Saves longos não podem quebrar a cada atualização.

const SAVE_DIR := "user://saves"

## versão de origem -> nome do método que migra para a versão seguinte.
const MIGRATIONS := {
	1: "_migrate_v1_to_v2",
	2: "_migrate_v2_to_v3",
	3: "_migrate_v3_to_v4",
}


## v4: sede da promotora (staff, decisões, livro-caixa, nível do escritório).
## Coleções novas começam vazias; Office.ensure monta a equipe inicial ao abrir
## o save (WorldSim._init), com o fluxo próprio office_rng.
static func _migrate_v3_to_v4(data: Dictionary) -> Dictionary:
	for key: String in ["staff", "dilemmas"]:
		if not data.has(key):
			data[key] = {}
	if not data.has("office_rng_state"):
		data["office_rng_state"] = str(SimRandom.new(int(data.get("seed_value", 0)) * 7919 + 17).get_state())
	return data


## v3: rating público, última luta e resumo de carreira (CareerHistory).
## Saves antigos recebem um rating estimado pelo cartel, sem inventar lutas.
static func _migrate_v2_to_v3(data: Dictionary) -> Dictionary:
	for id: String in data.get("fighters", {}):
		var f: Dictionary = data.fighters[id]
		var rec: Dictionary = f.get("record", {})
		if not f.has("rating"):
			f["rating"] = 1000.0 + clampf((int(rec.get("wins", 0)) - int(rec.get("losses", 0))) * 8.0, -200.0, 300.0)
		if not f.has("history"):
			f["history"] = {"results": [], "streak": 0}
		if not f.has("last_fight_on"):
			f["last_fight_on"] = {}
	return _backfill_progression(data)


## v2: todo atleta passa a ter agência (Game Bible §9). Mesma regra pública de
## Agencies.assign_all; confiança começa neutra e a memória vazia.
static func _migrate_v1_to_v2(data: Dictionary) -> Dictionary:
	# Carga em tempo de execução: scripts de CLI parseiam SaveSystem antes dos
	# autoloads, e Agencies depende de Contracts → EventBus.
	var agencies: GDScript = load("res://simulation/contracts/agencies.gd")
	var agents: Dictionary = data.get("agents", {})
	var ids: Array = data.get("fighters", {}).keys()
	ids.sort()
	for id: String in ids:
		var f: Dictionary = data.fighters[id]
		if not str(f.get("agent_id", "")).is_empty():
			continue
		var agent_id: String = agencies.agency_for(str(f.get("country", "")), f.get("popularity_by_region", {}), f.get("record", {}))
		if not agents.has(agent_id):
			continue
		f.agent_id = agent_id
		var clients: Array = agents[agent_id].get("client_ids", [])
		if not clients.has(id):
			clients.append(id)
		agents[agent_id].client_ids = clients
	return _backfill_progression(data)


static func slot_path(slot: String) -> String:
	return "%s/%s.json" % [SAVE_DIR, slot]


static func save_world(world: WorldState, slot: String) -> Error:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var tmp := slot_path(slot) + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(encode(world))
	f.close()
	# Escrita atômica: só substitui o save antigo depois de gravar tudo.
	return DirAccess.rename_absolute(tmp, slot_path(slot))


static func load_world(slot: String) -> WorldState:
	var f := FileAccess.open(slot_path(slot), FileAccess.READ)
	if f == null:
		return null
	return decode(f.get_as_text())


## from_native/to_native preservam int vs float, Vector etc. no JSON.
static func encode(world: WorldState) -> String:
	return JSON.stringify(JSON.from_native(world.to_dict()))


static func decode(text: String) -> WorldState:
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		return null
	var data: Variant = JSON.to_native(parsed)
	if typeof(data) != TYPE_DICTIONARY:
		return null
	data = migrate(data)
	if data == null:
		return null
	return WorldState.from_dict(data)


static func migrate(data: Dictionary) -> Variant:
	var version := int(data.get("schema_version", 0))
	if version > WorldState.SCHEMA_VERSION:
		push_error("Save de versão futura (%d)" % version)
		return null
	while version < WorldState.SCHEMA_VERSION:
		if not MIGRATIONS.has(version):
			push_error("Sem migração a partir da versão %d" % version)
			return null
		data = Callable(SaveSystem, MIGRATIONS[version]).call(data)
		version += 1
		data.schema_version = version
	return data


## Passagem do tempo e progressão (idade, propostas rivais, reputação
## fracionária, metas de temporada). Campos novos entram com o valor padrão;
## idempotente: roda na v1→v2 e na v2→v3 (saves v2 de ramos paralelos).
## a reputação exata parte da inteira e as metas nascem no próximo dia.
static func _backfill_progression(data: Dictionary) -> Dictionary:
	for f: Dictionary in data.get("fighters", {}).values():
		for key: String in ["retired_on", "rival_interest"]:
			if not f.has(key): f[key] = {}
	for o: Dictionary in data.get("organizations", {}).values():
		if not o.has("reputation_exact"): o.reputation_exact = float(o.get("reputation", 0))
		for key: String in ["standing_history", "objectives", "season_reviews"]:
			if not o.has(key): o[key] = []
	return data
