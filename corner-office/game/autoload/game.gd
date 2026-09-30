extends Node
## Ponto de entrada da aplicação: mantém o WorldState atual e os serviços de
## simulação. A UI lê daqui (via view models) e nunca implementa regras.

var world: WorldState
var sim: WorldSim


func new_game(seed_value: int = 0, start_mode: String = "flagship") -> void:
	world = WorldGenerator.generate(seed_value, start_mode)
	sim = WorldSim.new(world)
	EventBus.world_loaded.emit()


func load_game(slot: String) -> Error:
	var loaded := SaveSystem.load_world(slot)
	if loaded == null:
		return ERR_FILE_CORRUPT
	world = loaded
	Universe.apply_titles(world, true)  # saves anteriores ao universo ganham seus campeões
	sim = WorldSim.new(world)
	EventBus.world_loaded.emit()
	return OK


func save_game(slot: String) -> Error:
	if world == null:
		return ERR_UNCONFIGURED
	return SaveSystem.save_world(world, slot)


func has_world() -> bool:
	return world != null


func perform_action(action: String, params: Dictionary={}) -> Dictionary:
	if world==null:return {"ok":false,"message":"Nenhuma carreira aberta."}
	var result:=CareerActions.perform(world,action,params)
	if result.get("ok") and action not in ["state","evaluate","fighter_options"]:
		var error:=save_game("autosave")
		if error!=OK:result.message="Decisão aplicada, mas o save falhou. Não feche o jogo."
	return result

## Ações do presidente na sede (OfficeActions): aplica, salva e avisa a UI.
func office_action(action: String, params: Dictionary = {}) -> Dictionary:
	if world == null:
		return {"ok": false, "message": "Nenhuma carreira aberta.", "tone": "bad"}
	var result := OfficeActions.perform(world, action, params)
	_after_decision(result)
	return result


## Resposta a uma decisão da caixa de entrada (Dilemmas).
func decide(dilemma_id: String, option_id: String) -> Dictionary:
	if world == null:
		return {"ok": false, "message": "Nenhuma carreira aberta.", "tone": "bad"}
	var result := Dilemmas.resolve(world, world.dilemmas.get(dilemma_id), option_id)
	_after_decision(result)
	return result


func _after_decision(result: Dictionary) -> void:
	if result.get("ok", false) and save_game("autosave") != OK:
		result.message = str(result.message) + " (o save falhou; não feche o jogo)"
	EventBus.office_changed.emit()
	EventBus.toast.emit(str(result.get("message", "")), str(result.get("tone", "neutral")))


func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_PAUSED and has_world():save_game("autosave")
