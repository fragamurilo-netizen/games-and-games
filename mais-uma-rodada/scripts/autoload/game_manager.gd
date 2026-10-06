extends Node
## Orquestra a carreira ativa: criação, carregamento, rodadas, fim de temporada e autosave.
## A lógica de jogo vive nos sistemas estáticos (SeasonManager, TransferManager...);
## aqui só existe o fluxo e a ponte com a interface.

signal world_changed
signal matchday_finished(report: Dictionary)
signal season_finished(summary: Dictionary)

var world: GameWorld = null
var slot: int = -1
var matchday: Dictionary = {} # data em andamento (begin_match → finish_match)
var last_report: Dictionary = {}
var last_summary: Dictionary = {}
var _ai_queue: Array = [] # entradas da data ainda não simuladas (modo rápido, em segundo plano)
## Mundo padrão carregado pelo Editor geral (sem carreira) para editar jogadores.
var preview_world: GameWorld = null
var _gen_task: int = -1
var _gen_result: GameWorld = null
var _gen_callback: Callable
## Save em segundo plano: pedido pendente, job em andamento e a thread que grava o arquivo.
var _save_dirty := false
var _save_busy := false
var _save_writer = null # SaveManager.Writer do save em andamento
var _save_gen := 0 # troca a cada carreira aberta/fechada: um job antigo não grava por cima
var _save_phase := 0 # 0 parado, 1 montando os blocos, 2 gravando na thread
## "Simular" em lote: cada data roda numa thread de trabalho (a tela segue fluida e o "Parar"
## responde) e o save fica para o fim do lote, em vez de um save completo a cada jogo.
var _batch := false
var _batch_save := false
var _end_batch_pending := false
var _sim_has := false # relatório de uma data do "Simular" esperando o SimDialog buscar
var _sim_report: Dictionary = {}
## Trabalho pesado numa thread (fechar a rodada, fim de temporada, carregar, simular): a tela
## principal nunca trava (o Android fecha o app que fica ~5 s sem responder). Enquanto roda, o
## mundo é da thread: a interface não o lê (ver UIManager, que congela a tela atual).
signal busy_changed(on: bool)
var _work_task := -1
var _work_result: Variant = null
var _work_done: Callable
## App foi para o segundo plano com um trabalho no meio: a própria thread grava o save ao acabar
## (a tela principal não espera; o Android fecha o app que demora a pausar).
var _work_mutex := Mutex.new()
var _work_in_fn := false
var _save_on_finish := false
var _resave_after_work := false
## Texto do aviso "processando" (só lido na thread principal).
var work_label := ""


func _ready() -> void:
	DatabaseManager.load_all()
	AppSettings.load_settings()
	I18n.apply(AppSettings.language)
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
	if _work_task >= 0 and WorkerThreadPool.is_task_completed(_work_task):
		_complete_work()


# ---------------------------------------------------------------------------
# Trabalho em thread (a tela segue respondendo)
# ---------------------------------------------------------------------------

## Roda `work` numa thread de trabalho e chama `done(resultado)` na thread principal quando acabar.
## `label` não vazio mostra o aviso "processando" por cima da tela. Um trabalho por vez.
func run_work(work: Callable, done: Callable = Callable(), label: String = "") -> bool:
	if _work_task >= 0:
		return false
	_work_result = null
	_work_done = done
	work_label = label
	SeasonManager.progress = 0
	Warmup.run() # caches preguiçosos prontos antes: a thread e a tela não os montam ao mesmo tempo
	_work_in_fn = true
	_save_on_finish = false
	if _save_busy:
		# Save aos poucos no meio: ele lê o mundo entre um quadro e outro, e a thread vai mudá-lo.
		# Descarta e grava de novo quando o trabalho acabar.
		_cancel_save()
		_resave_after_work = true
	_work_task = WorkerThreadPool.add_task(_work_body.bind(work), true, "trabalho")
	busy_changed.emit(true)
	return true


func _work_body(work: Callable) -> void:
	var r: Variant = work.call()
	_work_mutex.lock()
	_work_in_fn = false
	var save := _save_on_finish
	_save_on_finish = false
	_work_mutex.unlock()
	if save:
		_save_core()
	_work_result = r


## Save completo numa thread de trabalho (a tela fica congelada enquanto ele lê o mundo).
func _save_core() -> bool:
	if world == null or slot <= 0 or not matchday.is_empty():
		return false
	return SaveManager.save_world(world, slot) == OK


## Mundo sendo alterado por uma thread de trabalho: a interface não deve lê-lo agora.
func is_busy() -> bool:
	return _work_task >= 0


func _complete_work() -> void:
	WorkerThreadPool.wait_for_task_completion(_work_task)
	_work_task = -1
	var r: Variant = _work_result
	_work_result = null
	var cb := _work_done
	_work_done = Callable()
	work_label = ""
	if cb.is_valid():
		cb.call(r)
	if _work_task < 0: # (o done pode ter emendado outro trabalho)
		if _end_batch_pending:
			end_batch()
		if _resave_after_work:
			_resave_after_work = false
			save_now()
		busy_changed.emit(false)


## Espera o trabalho em curso terminar agora (app indo para o fundo, fechando a carreira).
func _wait_work() -> void:
	if _work_task >= 0:
		_complete_work()


func is_generating() -> bool:
	return _gen_task >= 0


## Gera (em thread) o mundo padrão para o Editor geral; `done` é chamado quando estiver pronto.
func ensure_preview_world(done: Callable) -> void:
	if preview_world != null:
		done.call()
		return
	if is_generating():
		return
	generate_world_async(WorldGenerator.DEFAULT_SEED, "padrao", func(w: GameWorld):
		preview_world = w
		done.call())


# ---------------------------------------------------------------------------
# Carreira
# ---------------------------------------------------------------------------

func start_career(w: GameWorld, club_id: int, manager_name: String, difficulty: int, save_slot: int) -> void:
	_cancel_save()
	world = w
	_start_core(club_id, manager_name, difficulty, save_slot)
	save_now()
	world_changed.emit()


## Mesmo começo de carreira numa thread (vários segundos no celular: temporada, base, pré-temporada
## e o avanço até o primeiro jogo); `done()` na principal, já com o save pedido.
func start_career_async(w: GameWorld, club_id: int, manager_name: String, difficulty: int, save_slot: int, done: Callable) -> void:
	_cancel_save()
	world = w
	var after := func(_r: Variant) -> void:
		save_now()
		world_changed.emit()
		done.call()
	if not run_work(func() -> bool:
			_start_core(club_id, manager_name, difficulty, save_slot)
			return true, after, "Preparando a carreira..."):
		_start_core(club_id, manager_name, difficulty, save_slot)
		after.call(true)


func _start_core(club_id: int, manager_name: String, difficulty: int, save_slot: int) -> void:
	world.user_club_id = club_id
	world.manager_name = manager_name.strip_edges() if manager_name.strip_edges() != "" else "Treinador"
	world.difficulty = difficulty
	var c := world.user_club()
	# Calendário da carreira pela liga do usuário (ano civil na América do Sul, MLS e Ásia).
	var kind := String(c.league_cfg().get("calendar", ""))
	if kind != SeasonManager.calendar_kind(world) and world.season != null and world.season.day == 0:
		world.stats["cal"] = kind
		world.season = SeasonManager.build_season(world)
		SeasonManager.compute_goals(world)
	FinanceManager.set_budgets(world, c)
	SponsorManager.open_preseason(world)
	c.sheet = ClubAI.auto_sheet(world, c, "")
	for p in world.squad(c):
		p.scout_noise = int(p.scout_noise * 0.3) # você conhece melhor o próprio elenco
	YouthManager.ensure_academy(world)
	YouthManager.build_league(world)
	NationalCoach.season_offers(world) # federações sondam o técnico recém-chegado
	slot = save_slot if save_slot > 0 else SaveManager.first_free_slot()
	if slot <= 0:
		slot = 1
	var goal := SeasonManager.goal_of(world, c.id)
	NewsManager.post(world, "temporada", {"year": world.year, "club": c.short_name, "goal": String(goal[0]).to_lower()}, c.id, -1, NewsEvent.IMP_HEADLINE)
	for cid in world.season.cups:
		if world.season.cups[cid].has_club(c.id):
			NewsManager.post(world, CupManager.news_cat(cid, "classificado"), {"club": c.short_name, "cup": world.season.cups[cid].name}, c.id, -1, NewsEvent.IMP_HIGH)
	if world.transfer_window_open():
		NewsManager.on_window(world, true)
	world.stats.erase(BoardObjectives.KEY)
	BoardObjectives.list(world)
	PreseasonManager.open(world)
	InboxManager.on_new_job(world)
	SeasonManager.advance_to_user(world)


func load_career(save_slot: int) -> bool:
	return _adopt_loaded(_load_core(save_slot), save_slot)


## Carrega numa thread (o save grande leva vários segundos no celular); `done(ok)` na principal.
func load_career_async(save_slot: int, done: Callable) -> void:
	if not run_work(_load_core.bind(save_slot), func(w: Variant) -> void:
			done.call(_adopt_loaded(w, save_slot)), "Carregando a carreira..."):
		done.call(false)


## A parte pesada do carregamento: só mexe no mundo novo (ainda fora do GameManager).
func _load_core(save_slot: int) -> GameWorld:
	var w := SaveManager.load_world(save_slot)
	if w == null:
		return null
	# Entropia nova a cada abertura: reabrir o save não repete os mesmos jogos, gols e minutos.
	var fresh := RandomNumberGenerator.new()
	fresh.randomize()
	w.rng.seed = w.rng.randi() ^ fresh.randi()
	HeartClubs.ensure_all(w) # saves de antes dos times de coração
	SponsorManager.ensure_all(w) # saves de antes dos patrocínios da IA
	Economy.ensure(w) # câmbio salvo e receitas reais (saves de antes da Economia 2026)
	LeagueReputation.ensure(w) # força das ligas, que muda com o tempo
	Valuation.refresh_shift(w)
	var market_migrated := MarketReality.ensure_world(w)
	if market_migrated:
		for c: Club in w.clubs:
			MarketReality.migrate_budget(w, c)
	return w


func _adopt_loaded(w: Variant, save_slot: int) -> bool:
	if not w is GameWorld:
		return false
	_cancel_save()
	world = w
	slot = save_slot
	matchday = {}
	world_changed.emit()
	return true


## Pede um save. Não trava a tela: os pedidos da mesma hora se juntam num só, os jogadores são
## serializados aos poucos (alguns milissegundos por quadro) e a compressão e a escrita rodam em
## outra thread. Sem vídeo (testes) grava na hora.
func save_now() -> bool:
	if world == null or slot <= 0 or not matchday.is_empty():
		return false
	if _batch:
		_batch_save = true
		return true
	if DisplayServer.get_name() == "headless":
		return SaveManager.save_world(world, slot) == OK
	_save_dirty = true
	if not _save_busy:
		_save_busy = true
		_run_save.call_deferred()
	return true


## Termina o que estiver pendente agora mesmo (fechar a carreira, app indo para o fundo).
func save_blocking() -> void:
	_wait_work()
	var need := _save_dirty or _save_phase >= 1
	if _save_writer != null:
		_save_writer.abort() # fecha o arquivo do save em andamento antes de gravar de uma vez
		_save_writer = null
	if need and world != null and slot > 0 and matchday.is_empty():
		SaveManager.save_world(world, slot)
	_save_gen += 1 # o job que estava no meio fica sem efeito
	_save_busy = false
	_save_dirty = false
	_save_phase = 0


## Troca de carreira: espera a gravação em curso e descarta o job (ele é da carreira anterior).
func _cancel_save() -> void:
	if _save_writer != null:
		_save_writer.abort()
		_save_writer = null
	_save_gen += 1
	_save_busy = false
	_save_dirty = false
	_save_phase = 0


func _run_save() -> void:
	var gen := _save_gen
	var w := world
	var s := slot
	_save_dirty = false
	_save_phase = 1
	# Cada clube/jogador é serializado, comprimido e gravado na hora (alguns ms por quadro):
	# nada de juntar o mundo inteiro na memória.
	var wr := SaveManager.Writer.open(s, w.clubs.size(), w.players.size())
	_save_writer = wr
	if wr == null:
		_save_phase = 0
		_save_busy = false
		return
	var items: Array = w.clubs.duplicate()
	items.append_array(w.players.values())
	# Por quadro, um lote que cabe em ~6 ms: serializado e comprimido em todos os núcleos (o
	# mundo não muda enquanto o lote roda, a tela espera só por ele). O lote se ajusta ao aparelho.
	var batch := 64
	var i := 0
	while i < items.size():
		var t0 := Time.get_ticks_usec()
		var j := mini(items.size(), i + batch)
		wr.add_all(SaveManager.encode_all(items.slice(i, j)))
		i = j
		var spent := maxf(0.2, (Time.get_ticks_usec() - t0) / 1000.0)
		batch = clampi(int(batch * 6.0 / spent), 16, 2048)
		await get_tree().process_frame
		if gen != _save_gen:
			wr.abort() # (já cancelado por quem trocou a geração)
			return
	if gen != _save_gen or w != world or not matchday.is_empty() or w.players.size() + w.clubs.size() != items.size():
		# Mudou no meio (carreira trocada, partida começou, jogador novo): grava de novo depois
		wr.abort()
		if _save_writer == wr:
			_save_writer = null
		if gen == _save_gen:
			_save_phase = 0
			_save_busy = false
			if w == world and matchday.is_empty():
				_save_dirty = true
				_run_save.call_deferred()
				_save_busy = true
		return
	_save_phase = 2
	if wr.finish(w) == OK:
		SaveManager.write_meta(w, s)
	if _save_writer == wr:
		_save_writer = null
	_save_phase = 0
	if _save_dirty:
		_run_save.call_deferred()
	else:
		_save_busy = false


func save_copy(to_slot: int) -> bool:
	if world == null:
		return false
	save_blocking()
	var ok := SaveManager.save_world(world, to_slot) == OK
	return ok


## Cópia do save em outro espaço, numa thread (são dois saves completos). `done(ok)` depois.
func save_copy_async(to_slot: int, done: Callable) -> void:
	if world == null:
		done.call(false)
		return
	_wait_work()
	var need := _save_dirty or _save_phase >= 1 or _batch_save
	_cancel_save()
	var work := func() -> bool:
		if need:
			_save_core()
		return SaveManager.save_world(world, to_slot) == OK
	if not run_work(work, done, "Salvando..."):
		done.call(false)


func close_career() -> void:
	end_batch()
	save_now()
	save_blocking()
	_drop_career()


func _drop_career() -> void:
	_save_gen += 1
	world = null
	slot = -1
	matchday = {}


## Sai da carreira gravando numa thread (o save completo leva segundos no celular); `done` depois.
func close_career_async(done: Callable) -> void:
	end_batch()
	_wait_work()
	var need := _save_dirty or _save_phase >= 1 or _batch_save
	_cancel_save()
	if need and world != null and slot > 0 and matchday.is_empty() \
			and run_work(_save_core, func(_r: Variant) -> void:
				_drop_career()
				done.call(), "Salvando..."):
		return
	_drop_career()
	done.call()


## App indo para o segundo plano: grava sem travar a thread principal. Um trabalho em curso grava
## ao acabar (na própria thread); senão, o save pendente roda numa thread, com a tela congelada.
func _save_on_pause() -> void:
	if world == null or slot <= 0:
		return
	_work_mutex.lock()
	var running := _work_task >= 0 and _work_in_fn
	if running:
		_save_on_finish = true
	_work_mutex.unlock()
	if running:
		return
	if _work_task >= 0:
		_complete_work() # a conta já acabou: entrega agora (é rápido)
	if _work_task >= 0:
		return # (o done emendou outro trabalho)
	var need := _save_dirty or _save_phase >= 1 or _batch_save
	if not need or not matchday.is_empty():
		return
	_cancel_save()
	run_work(_save_core, Callable(), "Salvando...")


# ---------------------------------------------------------------------------
# Rodada
# ---------------------------------------------------------------------------

## Monta a data do próximo jogo do usuário; a partida dele volta viva e as demais rodam em
## segundo plano (pump_ai) enquanto ele assiste.
func begin_match() -> Dictionary:
	if is_busy():
		return {}
	return _begin_match_core()


## Called only by the owner of the world (UI thread or the active worker).
func _begin_match_core(with_detail: bool = true) -> Dictionary:
	if world == null or world.season == null or world.season.finished or Store.locked(world):
		return {}
	if not matchday.is_empty():
		return matchday
	SeasonManager.advance_to_user(world)
	if world.season.finished or not SeasonManager.user_plays_now(world):
		return {}
	matchday = SeasonManager.begin_matchday(world, with_detail)
	_ai_queue.clear()
	for e in matchday["entries"]:
		if e != matchday["user"]:
			_ai_queue.append(e)
	return matchday


## Simula as partidas do resto do mundo aos poucos (chamado a cada frame pela tela da partida).
func pump_ai(budget_ms: float) -> void:
	var t0 := Time.get_ticks_usec()
	while not _ai_queue.is_empty() and (Time.get_ticks_usec() - t0) < budget_ms * 1000.0:
		SeasonManager.run_entry(world, _ai_queue.pop_front())


func user_sim() -> MatchSimulation:
	if matchday.is_empty() or matchday["user"].is_empty():
		return null
	return matchday["user"]["sim"]


func user_fixture() -> Fixture:
	if matchday.is_empty() or matchday["user"].is_empty():
		return null
	return matchday["user"]["f"]


## Placar parcial de outro jogo da data até o minuto atual da partida do usuário.
func live_score(entry: Dictionary, minute: int, half: int) -> Array:
	var res: Dictionary = entry["res"]
	if res.is_empty():
		return [0, 0]
	var hs := 0
	var as_ := 0
	for g in res["goals"]:
		var gh: int = g[4]
		var gm: int = g[0]
		if gh > half or (gh == half and gm > minute):
			continue
		if int(g[1]) == 0:
			hs += 1
		else:
			as_ += 1
	return [hs, as_]


## O que sobrou da fila roda de uma vez, com os jogos da IA em paralelo.
func _wait_ai() -> void:
	SeasonManager.run_entries(world, _ai_queue)
	_ai_queue.clear()


func ai_ready() -> bool:
	return _ai_queue.is_empty()


## Encerra a data do usuário e já joga as datas seguintes em que ele não entra em campo
## (o relatório traz também as viradas de janela e os eventos de copa dessas datas).
func finish_match() -> Dictionary:
	var report := _finish_core()
	if report.is_empty():
		return {}
	save_now()
	matchday_finished.emit(report)
	world_changed.emit()
	return report


## finish_match numa thread de trabalho, com o aviso "processando"; `done(relatório)` na principal.
func finish_match_async(done: Callable) -> void:
	# Never fall back to mutating the same world on the UI thread while a worker
	# owns it. A duplicate finish request must not settle a match twice.
	if is_busy():
		return
	if matchday.is_empty():
		if done.is_valid():
			done.call({})
		return
	run_work(_finish_core, _after_report.bind(done), "Fechando a rodada...")


## Joga a rodada inteira sem assistir (modo instantâneo), numa thread de trabalho.
func play_instant_async(done: Callable) -> void:
	if not run_work(_sim_step_work, _after_report.bind(done), "Jogando a rodada..."):
		done.call({})


func _after_report(r: Variant, done: Callable) -> void:
	var report: Dictionary = r if r is Dictionary else {}
	if not report.is_empty():
		save_now()
		matchday_finished.emit(report)
		world_changed.emit()
	if done.is_valid():
		done.call(report)


## A parte pura de finish_match (sem save nem sinais): pode rodar numa thread de trabalho.
func _finish_core() -> Dictionary:
	if matchday.is_empty():
		return {}
	_wait_ai()
	var md := matchday
	var report := SeasonManager.finish_matchday(world, md)
	report["entries"] = md["entries"]
	matchday = {}
	for r in SeasonManager.advance_to_user(world):
		report["window_opened"] = report["window_opened"] or r["window_opened"]
		report["window_closed"] = report["window_closed"] or r["window_closed"]
		report["transfers"].append_array(r["transfers"])
		report["retiring"].append_array(r["retiring"])
		report["cups"].append_array(r["cups"])
	last_report = report
	return report


## Joga a rodada inteira sem assistir (modo instantâneo).
func play_instant() -> Dictionary:
	begin_match()
	var sim := user_sim()
	if sim != null:
		sim.run_to_end()
	return finish_match()


# ---------------------------------------------------------------------------
# Simulação em lote (tela "Simular")
# ---------------------------------------------------------------------------

## Abre um lote: os saves pedidos durante ele viram um só, no end_batch(). Um save que estava
## no meio é descartado (o mundo vai mudar) e refeito no fim.
func begin_batch() -> void:
	if _batch:
		return
	if _save_busy or _save_dirty:
		_cancel_save()
		_batch_save = true
	_batch = true


func end_batch() -> void:
	# A folha pode sair da árvore durante a simulação. Esperar aqui bloqueava a
	# interface até acabar a data inteira; no Android isso pode provocar um ANR.
	if is_busy():
		_end_batch_pending = true
		return
	_end_batch_pending = false
	if not _batch:
		return
	_batch = false
	if _batch_save:
		_batch_save = false
		save_now()
	world_changed.emit()
	busy_changed.emit(false) # a tela congelada durante o lote volta


func in_batch() -> bool:
	return _batch


## Mundo sendo alterado por uma thread de trabalho (nome antigo de is_busy).
func is_simulating() -> bool:
	return is_busy()


## Joga a próxima data do usuário numa thread de trabalho. Acompanhe com sim_step_poll().
func sim_step_start() -> bool:
	if is_busy() or world == null:
		return false
	_sim_has = false
	_sim_report = {}
	return run_work(_sim_step_work, func(r: Variant) -> void:
		_sim_report = r if r is Dictionary else {}
		_sim_has = true
		if not _sim_report.is_empty():
			save_now()
			matchday_finished.emit(_sim_report)
			world_changed.emit())


func _sim_step_work() -> Dictionary:
	var t0 := Time.get_ticks_usec()
	_begin_match_core(false)
	SeasonManager._time("batch_preparar",t0)
	t0 = Time.get_ticks_usec()
	var sim := user_sim()
	if sim != null:
		sim.run_to_end()
	SeasonManager._time("batch_partida",t0)
	t0 = Time.get_ticks_usec()
	var report := _finish_core()
	SeasonManager._time("batch_finalizar",t0)
	return report


## null enquanto a data ainda roda (ou se nenhuma foi pedida); depois, uma vez, o relatório
## (igual ao de play_instant).
func sim_step_poll() -> Variant:
	if not _sim_has:
		return null
	_sim_has = false
	var report := _sim_report
	_sim_report = {}
	return report


func season_over() -> bool:
	return world != null and world.season != null and world.season.finished


## Sem jogos do usuário até o fim da temporada: joga o resto do calendário de uma vez.
func advance_to_end() -> void:
	if world == null or world.season == null or not matchday.is_empty() or Store.locked(world):
		return
	SeasonManager.advance_to_user(world)
	save_now()
	world_changed.emit()


## Avança até o fim numa thread de trabalho (o resto do calendário pode ter muitas datas).
func advance_to_end_async(done: Callable) -> void:
	if is_busy():
		return
	var ok := world != null and world.season != null and matchday.is_empty() and not Store.locked(world)
	if ok and run_work(_advance_core, _after_advance.bind(done), "Avançando o calendário..."):
		return
	advance_to_end()
	if done.is_valid():
		done.call()


func _advance_core() -> bool:
	SeasonManager.advance_to_user(world)
	return true


func _after_advance(_r: Variant, done: Callable) -> void:
	save_now()
	world_changed.emit()
	if done.is_valid():
		done.call()


func end_season() -> Dictionary:
	if not season_over():
		return {}
	return _after_season(_end_season_core())


## Fim de temporada numa thread de trabalho (é a operação mais pesada do jogo).
func end_season_async(done: Callable) -> void:
	if is_busy():
		return
	if not season_over() or not run_work(_end_season_core, func(r: Variant) -> void:
			done.call(_after_season(r)), "Encerrando a temporada..."):
		done.call(end_season() if season_over() else last_summary)


func _end_season_core() -> Dictionary:
	var summary := SeasonManager.end_season(world)
	PreseasonManager.open(world)
	var c := world.user_club()
	c.sheet = ClubAI.auto_sheet(world, c, c.sheet.formation if c.sheet != null else "")
	SeasonManager.advance_to_user(world)
	return summary


func _after_season(r: Variant) -> Dictionary:
	last_summary = r if r is Dictionary else {}
	save_now()
	season_finished.emit(last_summary)
	world_changed.emit()
	return last_summary


# ---------------------------------------------------------------------------
# Ciclo de vida do app: autosave ao pausar/fechar
# ---------------------------------------------------------------------------

func _exit_tree() -> void:
	if _gen_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_gen_task)
		_gen_task = -1
	I18n.release()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			# Só grava se houver algo pendente (os saves normais já rodam em segundo plano), e numa
			# thread: pausar não pode esperar um save inteiro (o Android fecha o app que não pausa).
			_save_on_pause()
		NOTIFICATION_WM_CLOSE_REQUEST:
			_wait_work()
			_batch = false
			if matchday.is_empty():
				save_now()
				save_blocking()
			get_tree().quit()
