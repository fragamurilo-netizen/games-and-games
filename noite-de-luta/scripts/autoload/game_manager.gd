extends Node
## Carreira em andamento: o mundo, salvar e carregar. (Preenchido com a carreira de verdade.)

signal world_changed

var world: GameWorld = null


func has_career() -> bool:
	return world != null


func user_team() -> Team:
	return world.user_team() if world != null else null


func close_career() -> void:
	world = null
