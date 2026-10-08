extends Node
## Carreira em andamento: o mundo, começar, salvar e carregar (um save, salvo toda semana).

signal world_changed

const SAVE_PATH := "user://carreira.json"

var world: GameWorld = null


func has_career() -> bool:
	return world != null


func user_team() -> Team:
	return world.user_team() if world != null else null


func start_career(w: GameWorld) -> void:
	world = w
	save_now()
	world_changed.emit()


func close_career() -> void:
	if world != null:
		save_now()
	world = null


static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Resumo do save para o menu: {team, week, balance}.
static func save_summary() -> Dictionary:
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return {}
	var meta: Variant = JSON.parse_string(f.get_line())
	return meta if meta is Dictionary else {}


func save_now() -> void:
	if world == null:
		return
	var t := world.user_team()
	var meta := {"team": t.name if t != null else "", "week": world.week, "balance": t.balance if t != null else 0.0,
		"date": GameWorld.week_text(world.week)}
	var tmp := SAVE_PATH + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("não salvou: %s" % error_string(FileAccess.get_open_error()))
		return
	f.store_line(JSON.stringify(meta))
	f.store_string(JSON.stringify(world.to_dict()))
	f.close()
	DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(SAVE_PATH))


func load_save() -> bool:
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	f.get_line()
	var d: Variant = JSON.parse_string(f.get_as_text())
	if not (d is Dictionary):
		return false
	world = GameWorld.from_dict(d)
	world_changed.emit()
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


## Fecha a semana (as lutas do jogador já jogadas) e salva.
func advance_week() -> void:
	Career.advance_week(world)
	save_now()
	world_changed.emit()
