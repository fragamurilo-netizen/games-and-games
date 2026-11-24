extends Node
## Carreira em andamento: o mundo, começar, salvar e carregar (um save só).
##
## Salvar monta o mundo inteiro em texto, e isso pesa em celular fraco. Por isso as telas só
## avisam que há o que salvar (`save_now`); o arquivo é escrito de fato quando o jogador fica
## alguns segundos sem tocar na tela, na virada da semana e quando o app sai de cena.

signal world_changed

const SAVE_PATH := "user://carreira.json"
## Cópia do save como ele estava antes de ser aberto por uma versão diferente do jogo.
const BACKUP_PATH := "user://carreira_anterior.json"
## Tempo sem toque para escrever o que está pendente.
const SAVE_IDLE_MS := 2500

var world: GameWorld = null
var _dirty := false
var _last_touch := 0
## Semanas viradas que ainda não foram para o arquivo (no máximo uma fica esperando).
var _weeks_pending := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)


func _input(event: InputEvent) -> void:
	if _dirty and (event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventMouseButton or event is InputEventKey):
		_last_touch = Time.get_ticks_msec()


func _process(_delta: float) -> void:
	if not _dirty:
		set_process(false)
	elif Time.get_ticks_msec() - _last_touch >= SAVE_IDLE_MS:
		flush()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE:
		flush()


static func app_version() -> String:
	return String(ProjectSettings.get_setting("application/config/version", ""))


func has_career() -> bool:
	return world != null


func user_team() -> Team:
	return world.user_team() if world != null else null


func start_career(w: GameWorld) -> void:
	world = w
	_write()
	world_changed.emit()


func close_career() -> void:
	if world != null:
		_write()
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


## Marca que há o que salvar. Não escreve na hora (ver o topo do arquivo).
func save_now() -> void:
	if world == null:
		return
	_dirty = true
	_last_touch = Time.get_ticks_msec()
	set_process(true)


## Escreve agora o que estiver pendente.
func flush() -> void:
	if _dirty:
		_write()


func _write() -> void:
	_dirty = false
	_weeks_pending = 0
	if world == null:
		return
	var t := world.user_team()
	var meta := {"team": t.name if t != null else "", "week": world.week, "balance": t.balance if t != null else 0.0,
		"date": GameWorld.week_text(world.week), "app": app_version()}
	var tmp := SAVE_PATH + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("não salvou: %s" % error_string(FileAccess.get_open_error()))
		return
	f.store_line(JSON.stringify(meta))
	# Sem ordenar as chaves: o arquivo é o mesmo para o jogo e sai mais rápido.
	f.store_string(JSON.stringify(world.to_dict(), "", false))
	f.close()
	DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(SAVE_PATH))


func load_save() -> bool:
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	# A primeira linha é o resumo para o menu; o mundo vem depois dela. (`get_as_text` devolve o
	# arquivo inteiro, sem olhar onde a leitura parou: por isso o resto é lido como bytes.)
	var meta: Variant = JSON.parse_string(f.get_line())
	var d: Variant = JSON.parse_string(f.get_buffer(f.get_length() - f.get_position()).get_string_from_utf8())
	f.close()
	if not (d is Dictionary):
		return false
	# Save de outra versão do jogo: guarda uma cópia do arquivo como estava antes de mexer nele.
	if not (meta is Dictionary) or String((meta as Dictionary).get("app", "")) != app_version():
		DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE_PATH), ProjectSettings.globalize_path(BACKUP_PATH))
	_dirty = false
	world = GameWorld.from_dict(d)
	world_changed.emit()
	return true


func delete_save() -> void:
	_dirty = false
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


## Fecha a semana (as lutas do jogador já jogadas) e salva.
func advance_week() -> void:
	Career.advance_week(world)
	# A semana virada vai para o arquivo quando o jogador parar para ler a tela. Quem vira
	# semana atrás de semana sem parar salva na hora a cada duas.
	_weeks_pending += 1
	if _weeks_pending >= 2:
		_write()
	else:
		save_now()
	world_changed.emit()
