extends Node
## Ponto de entrada da aplicação: mantém o WorldState atual e os serviços de
## simulação. A UI lê daqui (via view models) e nunca implementa regras.

var world: WorldState
var sim: WorldSim


func new_game(seed_value: int = 0, start_mode: String = "regional_promoter") -> void:
	world = WorldGenerator.generate(seed_value, start_mode)
	sim = WorldSim.new(world)
	EventBus.world_loaded.emit()


func load_game(slot: String) -> Error:
	var loaded := SaveSystem.load_world(slot)
	if loaded == null:
		return ERR_FILE_CORRUPT
	world = loaded
	sim = WorldSim.new(world)
	EventBus.world_loaded.emit()
	return OK


func save_game(slot: String) -> Error:
	if world == null:
		return ERR_UNCONFIGURED
	return SaveSystem.save_world(world, slot)


func has_world() -> bool:
	return world != null
