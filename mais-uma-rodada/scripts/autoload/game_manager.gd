extends Node
## Orquestra a carreira ativa: criação, carregamento, rodadas, fim de temporada e autosave.
## A lógica de jogo vive nos sistemas estáticos (SeasonManager, TransferManager...);
## aqui só existe o fluxo e a ponte com a interface.

signal world_changed
signal matchday_finished(report: Dictionary)
signal season_finished(summary: Dictionary)

var world: GameWorld = null
var slot: int = -1
var matchday: Dictionary = {} # dia de jogo em andamento (begin_match → finish_match)
var last_report: Dictionary = {}
var last_summary: Dictionary = {}
var _ai_queue: Array = []
var _gen_task: int = -1
var _gen_result: GameWorld = null
var _gen_callback: Callable


func _ready() -> void:
	DatabaseManager.load_all()
	AppSettings.load_settings()
	get_tree().set_auto_accept_quit(false)


func has_career() -> bool:
	return world != null and world.has_user()


func user_club() -> Club:
	return world.user_club() if world != null else null


# ---------------------------------------------------------------------------
# Geração do mundo em thread (a UI continua respondendo)
# ---------------------------------------------------------------------------

func generate_world_async(seed_value: int, world_type: String, callback: Callable) -> void:
	if _gen_task >= 0:
		return
	_gen_result = null
	_gen_callback = callback
	_gen_task = WorkerThreadPool.add_task(func(): _gen_result = WorldGenerator.generate(seed_value, world_type), true, "gerar_mundo")


func _process(_delta: float) -> void:
	if _gen_task >= 0 and WorkerThreadPool.is_task_completed(_gen_task):
		WorkerThreadPool.wait_for_task_completion(_gen_task)
		_gen_task = -1
		if _gen_callback.is_valid():
			_gen_callback.call(_gen_result)


func is_generating() -> bool:
	return _gen_task >= 0


# ---------------------------------------------------------------------------
# Carreira
# ---------------------------------------------------------------------------

func start_career(w: GameWorld, club_id: int, manager_name: String, difficulty: int, save_slot: int) -> void:
	world = w
	world.user_club_id = club_id
	world.manager_name = manager_name.strip_edges() if manager_name.strip_edges() != "" else "Treinador"
	world.difficulty = difficulty
	var c := world.user_club()
	FinanceManager.set_budgets(world, c)
	c.sheet = ClubAI.auto_sheet(world, c, "")
	for p in world.squad(c):
		p.scout_noise = int(p.scout_noise * 0.3) # você conhece melhor o próprio elenco
	slot = save_slot if save_slot > 0 else SaveManager.first_free_slot()
	if slot <= 0:
		slot = 1
	var goal := SeasonManager.goal_of(world, c.id)
	NewsManager.post(world, "temporada", {"year": world.year, "club": c.short_name, "goal": String(goal[0]).to_lower()}, c.id, -1, NewsEvent.IMP_HEADLINE)
	if world.transfer_window_open():
		NewsManager.on_window(world, true)
	save_now()
	world_changed.emit()


func load_career(save_slot: int) -> bool:
	var w := SaveManager.load_world(save_slot)
	if w == null:
		return false
	world = w
	slot = save_slot
	matchday = {}
	Valuation.refresh_shift(world)
	world_changed.emit()
	return true


func save_now() -> bool:
	if world == null or slot <= 0 or not matchday.is_empty():
		return false
	return SaveManager.save_world(world, slot) == OK


func save_copy(to_slot: int) -> bool:
	if world == null:
		return false
	var ok := SaveManager.save_world(world, to_slot) == OK
	return ok


func close_career() -> void:
	save_now()
	world = null
	slot = -1
	matchday = {}


# ---------------------------------------------------------------------------
# Rodada
# ---------------------------------------------------------------------------

## Monta o dia de jogo; a partida do usuário volta viva. As demais rodam em segundo plano.
func begin_match() -> Dictionary:
	if world == null or world.season == null or world.season.finished:
		return {}
	if not matchday.is_empty():
		return matchday
	matchday = SeasonManager.begin_matchday(world)
	_ai_queue.clear()
	for e in matchday["entries"]:
		if e != matchday["user"]:
			_ai_queue.append(e["sim"])
	return matchday


## Simula partidas IA×IA aos poucos (chamado a cada frame pela tela da partida).
func pump_ai(budget_ms: float) -> void:
	var t0 := Time.get_ticks_usec()
	while not _ai_queue.is_empty() and (Time.get_ticks_usec() - t0) < budget_ms * 1000.0:
		var sim: MatchSimulation = _ai_queue.pop_back()
		sim.run_to_end()


func user_sim() -> MatchSimulation:
	if matchday.is_empty() or matchday["user"].is_empty():
		return null
	return matchday["user"]["sim"]


func user_fixture() -> Fixture:
	if matchday.is_empty() or matchday["user"].is_empty():
		return null
	return matchday["user"]["f"]


## Placar parcial de outro jogo da rodada até o minuto atual da partida do usuário.
func live_score(entry: Dictionary, minute: int, half: int) -> Array:
	var hs := 0
	var as_ := 0
	var sim: MatchSimulation = entry["sim"]
	if not ai_ready() or not sim.finished:
		return [0, 0]
	for ev in sim.events:
		var h: int = ev["h"]
		var m: int = ev["m"]
		if h > half or (h == half and m > minute):
			break
		if ev["t"] == MatchSimulation.EV_GOAL or ev["t"] == MatchSimulation.EV_OWN_GOAL:
			hs = ev["hs"]
			as_ = ev["as"]
	return [hs, as_]


func _wait_ai() -> void:
	pump_ai(1e9)


func ai_ready() -> bool:
	return _ai_queue.is_empty()


func finish_match() -> Dictionary:
	if matchday.is_empty():
		return {}
	_wait_ai()
	var md := matchday
	var report := SeasonManager.finish_matchday(world, md)
	report["entries"] = md["entries"]
	matchday = {}
	last_report = report
	save_now()
	matchday_finished.emit(report)
	world_changed.emit()
	return report


## Joga a rodada inteira sem assistir (modo instantâneo).
func play_instant() -> Dictionary:
	begin_match()
	var sim := user_sim()
	if sim != null:
		sim.run_to_end()
	return finish_match()


func season_over() -> bool:
	return world != null and world.season != null and world.season.finished


func end_season() -> Dictionary:
	if not season_over():
		return {}
	last_summary = SeasonManager.end_season(world)
	var c := world.user_club()
	c.sheet = ClubAI.auto_sheet(world, c, c.sheet.formation if c.sheet != null else "")
	save_now()
	season_finished.emit(last_summary)
	world_changed.emit()
	return last_summary


# ---------------------------------------------------------------------------
# Ciclo de vida do app: autosave ao pausar/fechar
# ---------------------------------------------------------------------------

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			if matchday.is_empty():
				save_now()
		NOTIFICATION_WM_CLOSE_REQUEST:
			if matchday.is_empty():
				save_now()
			get_tree().quit()
