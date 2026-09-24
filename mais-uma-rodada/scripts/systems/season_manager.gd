class_name SeasonManager
extends RefCounted
## Ciclo da temporada: montagem de ligas/calendário, rodada a rodada e virada de ano.

## Simular em threads é opcional: nesta engine o GDScript sofre contenção em chamadas nativas,
## então o padrão é sequencial (cada partida tem seu próprio RNG → determinístico de qualquer forma).
static var use_threads := false


# ---------------------------------------------------------------------------
# Montagem
# ---------------------------------------------------------------------------

static func setup_first_season(world: GameWorld) -> void:
	world.season = build_season(world)
	for c in world.clubs:
		c.reset_season_state()
		FinanceManager.set_budgets(world, c)
	compute_goals(world)


## Cria as ligas (clubes por divisão), os jogos e o calendário da temporada `world.year`.
static func build_season(world: GameWorld) -> SeasonState:
	var s := SeasonState.new()
	s.year = world.year
	var divs := DatabaseManager.division_count()
	for div in divs:
		var l := League.new()
		l.division = div
		l.name = world.division_name(div)
		for c in world.clubs:
			if c.division == div:
				l.club_ids.append(c.id)
		FixtureManager.build_league_fixtures(world.rng, l)
		CompetitionManager.init_table(l)
		s.leagues.append(l)
	var rounds: int = s.leagues[0].rounds.size()
	for r in rounds:
		s.calendar.append({"t": "L", "r": r})
	s.day = 0
	s.finished = false
	return s


## Metas da diretoria conforme a força relativa do elenco na divisão.
static func compute_goals(world: GameWorld) -> void:
	var goals := {}
	for league: League in world.season.leagues:
		var ranked: Array = league.club_ids.duplicate()
		ranked.sort_custom(func(a, b): return ClubAI._compute_strength(world, world.club(a)) > ClubAI._compute_strength(world, world.club(b)))
		var teams := ranked.size()
		var cfg := DatabaseManager.division_config(league.division)
		for i in teams:
			var rank := i + 1
			var goal: Array
			if league.division == 0:
				if rank <= 2:
					goal = ["Ser campeão", 1]
				elif rank <= 6:
					goal = ["Terminar entre os 6 primeiros", 6]
				elif rank <= 14:
					goal = ["Terminar entre os 12 primeiros", 12]
				else:
					goal = ["Evitar o rebaixamento", teams - int(cfg["relegated"])]
			else:
				var promo := int(cfg["promoted"])
				if rank <= 3:
					goal = ["Conquistar o acesso", promo]
				elif rank <= 8:
					goal = ["Brigar pelo acesso", promo + 3]
				elif rank <= 15 or int(cfg["relegated"]) == 0:
					goal = ["Terminar no meio da tabela", 12 if int(cfg["relegated"]) > 0 else 16]
				else:
					goal = ["Evitar o rebaixamento", teams - int(cfg["relegated"])]
			goals[ranked[i]] = goal
	world.stats["goals"] = goals


static func goal_of(world: GameWorld, club_id: int) -> Array:
	var goals: Dictionary = world.stats.get("goals", {})
	if goals.has(club_id):
		return goals[club_id]
	if goals.has(str(club_id)):
		return goals[str(club_id)]
	return ["Fazer uma boa campanha", 10]


# ---------------------------------------------------------------------------
# Rodada
# ---------------------------------------------------------------------------

## Prepara o dia de jogo: escalações e simulações. A partida do usuário volta "viva" (não simulada).
## Retorna {"day", "entries": [{f, sim}], "user": {f, sim} ou {}}.
static func begin_matchday(world: GameWorld) -> Dictionary:
	var md := {"day": world.season.day, "entries": [], "user": {}, "notes": []}
	var e := world.season.current_entry()
	if e.is_empty():
		return md
	var r := int(e["r"])
	for league: League in world.season.leagues:
		for f: Fixture in league.fixtures_of_round(r):
			if f.played:
				continue
			var home := world.club(f.home)
			var away := world.club(f.away)
			var hs := _sheet_for(world, home, away, true, md)
			var as_ := _sheet_for(world, away, home, false, md)
			var detail := world.is_user_club(f.home) or world.is_user_club(f.away)
			var sim := MatchEngine.create(world, f, hs, as_, detail)
			var entry := {"f": f, "sim": sim}
			md["entries"].append(entry)
			if detail:
				md["user"] = entry
	return md


static func _sheet_for(world: GameWorld, club: Club, opp: Club, home: bool, md: Dictionary) -> TeamSheet:
	if world.is_user_club(club.id):
		md["notes"] = ClubAI.validate_user_sheet(world, club)
		return club.sheet.duplicate_sheet()
	return ClubAI.prepare_ai_sheet(world, club, opp, home)


## Simula todas as partidas sem usuário (em paralelo quando possível).
static func simulate_ai_matches(md: Dictionary) -> void:
	var sims: Array = []
	for e in md["entries"]:
		if e != md["user"] and not e["sim"].finished:
			sims.append(e["sim"])
	if sims.is_empty():
		return
	if use_threads and sims.size() >= 4 and OS.get_processor_count() > 1:
		var task := WorkerThreadPool.add_group_task(func(i: int): sims[i].run_to_end(), sims.size(), -1, true, "sim_rodada")
		WorkerThreadPool.wait_for_group_task_completion(task)
	else:
		for s: MatchSimulation in sims:
			s.run_to_end()


## Aplica tudo o que aconteceu na rodada e avança o calendário. Retorna um relatório para a UI.
static func finish_matchday(world: GameWorld, md: Dictionary) -> Dictionary:
	for e in md["entries"]:
		if not e["sim"].finished:
			e["sim"].run_to_end()
	var report := {"day": md["day"], "user": {}, "transfers": [], "retiring": [], "window_opened": false, "window_closed": false}
	var user_pos_before := 0
	if world.has_user():
		user_pos_before = CompetitionManager.position_of(world.league_of(world.user_club_id), world.user_club_id)
	var was_open := world.transfer_window_open()
	# Lesões antigas avançam uma semana antes de registrar as novas.
	for p: Player in world.players.values():
		if p.injury_weeks > 0:
			p.injury_weeks -= 1
			if p.injury_weeks == 0:
				p.injury_name = ""
	var played := {}
	var newly_suspended := {}
	var clubs_played := {}
	var gates := {}
	for e in md["entries"]:
		_apply_match(world, e["f"], e["sim"], played, newly_suspended)
		clubs_played[e["f"].home] = true
		clubs_played[e["f"].away] = true
		gates[e["f"].home] = e["f"].attendance * FinanceManager.ticket_price(world.club(e["f"].home))
	# Suspensões cumpridas por quem ficou de fora
	for cid in clubs_played:
		for p in world.squad_of(cid):
			if p.suspension > 0 and not played.has(p.id) and not newly_suspended.has(p.id):
				p.suspension -= 1
	# Recuperação física e moral
	for p: Player in world.players.values():
		var fac := world.club(p.club_id).facilities if p.club_id >= 0 else 40
		var rec := 16.0 + p.attrs[Attr.RES] * 0.08 + fac * 0.04 - maxf(0.0, p.age(world.year) - 30.0) * 0.8
		p.condition = minf(100.0, p.condition + rec)
		p.morale = clampf(p.morale + (62.0 - p.morale) * 0.05, 0.0, 100.0)
	# Evolução semanal
	var notable := PlayerDevelopment.weekly_tick(world, played)
	for p in notable:
		if p.age(world.year) <= 21:
			NewsManager.on_explosion(world, p)
	# Finanças
	for c: Club in world.clubs:
		FinanceManager.process_matchday(world, c, int(gates.get(c.id, 0)))
		c.fan_mood = clampf(c.fan_mood + (60.0 - c.fan_mood) * 0.03, 0.0, 100.0)
	# Mercado
	report["transfers"] = TransferManager.process_matchday(world)
	# Veteranos anunciam aposentadoria
	if world.season.day == 27:
		var ann := PlayerDevelopment.announce_retirements(world)
		report["retiring"] = ann
		for p in ann:
			NewsManager.on_retirement_announced(world, p)
	# Notícias
	NewsManager.after_matchday(world, md["entries"])
	# Valores de mercado (a cada 4 rodadas, barato o suficiente)
	if world.season.day % 4 == 0:
		for p: Player in world.players.values():
			Valuation.update_value(p, world.year)
	# Avança o calendário
	world.season.day += 1
	if world.season.day >= world.season.calendar.size():
		world.season.finished = true
	var now_open := world.transfer_window_open()
	if now_open and not was_open:
		report["window_opened"] = true
		NewsManager.on_window(world, true)
	elif was_open and not now_open:
		report["window_closed"] = true
		NewsManager.on_window(world, false)
	# Relatório do usuário
	if world.has_user() and not md["user"].is_empty():
		var f: Fixture = md["user"]["f"]
		report["user"] = {"fixture": f, "result": f.result_for(world.user_club_id), "pos_before": user_pos_before,
			"pos_after": CompetitionManager.position_of(world.league_of(world.user_club_id), world.user_club_id)}
	return report


static func _apply_match(world: GameWorld, f: Fixture, sim: MatchSimulation, played: Dictionary, newly_suspended: Dictionary) -> void:
	f.played = true
	f.hg = sim.score[0]
	f.ag = sim.score[1]
	f.attendance = sim.attendance
	f.goals.clear()
	for ev in sim.events:
		var t: int = ev["t"]
		if t == MatchSimulation.EV_GOAL or t == MatchSimulation.EV_OWN_GOAL:
			var kind := Fixture.GOAL_NORMAL
			if t == MatchSimulation.EV_OWN_GOAL:
				kind = Fixture.GOAL_OWN
			elif ev.has("x") and int(ev["x"].get("ct", -1)) == MatchSimulation.CH_PENALTY:
				kind = Fixture.GOAL_PENALTY
			f.goals.append([int(ev["m"]), int(ev["s"]), int(ev["p"]), kind, int(ev["h"])])
	var motm := sim.man_of_the_match()
	f.motm = motm.p.id if motm != null else -1
	if f.competition == "L":
		var league: League = world.season.leagues[f.division]
		CompetitionManager.apply_result(league, f)
		for side in 2:
			var tm: MatchTeam = sim.teams[side]
			var row: Dictionary = league.table[tm.club.id]
			row["yc"] += tm.yellows
			row["rc"] += tm.reds
	var derby := sim.derby
	var yellow_limit := int(DatabaseManager.squad_rules()["yellow_limit"])
	for side in 2:
		var tm: MatchTeam = sim.teams[side]
		var club := tm.club
		var res := f.result_for(club.id)
		club.push_result(res)
		club.cohesion = minf(92.0, club.cohesion + 1.2)
		# Torcida
		var patience := float(club.arch().get("fan_patience", 50))
		var swing := 1.0 + (50.0 - patience) / 100.0
		var dm := 3.0 if res == "V" else (-0.5 if res == "E" else -3.0 * swing)
		if derby:
			dm *= 1.8
		club.fan_mood = clampf(club.fan_mood + dm, 0.0, 100.0)
		# Técnico do usuário
		if world.is_user_club(club.id):
			world.manager_stats["games"] = int(world.manager_stats.get("games", 0)) + 1
			var key := "w" if res == "V" else ("d" if res == "E" else "l")
			world.manager_stats[key] = int(world.manager_stats.get(key, 0)) + 1
		var conceded: int = sim.score[1 - side]
		for mp: MatchPlayer in tm.all:
			var p := mp.p
			if not mp.used:
				continue
			var mins := mp.minutes_played(sim.minute)
			played[p.id] = mins
			p.stats[Player.S_APPS] += 1
			if mp.start_min == 0:
				p.stats[Player.S_STARTS] += 1
			p.stats[Player.S_MINUTES] += mins
			p.minutes_season += mins
			p.stats[Player.S_GOALS] += mp.goals
			p.stats[Player.S_ASSISTS] += mp.assists
			p.stats[Player.S_RATING_SUM] += int(round(mp.final_rating * 10.0))
			if mp.red:
				p.stats[Player.S_REDS] += 1
			else:
				p.stats[Player.S_YELLOWS] += mp.yellow
			if f.motm == p.id:
				p.stats[Player.S_MOTM] += 1
			if conceded == 0 and mins >= 60 and (mp.pos == Pos.GK or mp.w_def >= 0.8):
				p.stats[Player.S_CLEAN] += 1
			p.push_rating(mp.final_rating)
			p.condition = mp.cond
			var goals_before := _spell_goals(p)
			p.career_apps += 1
			p.career_goals += mp.goals
			p.career_assists += mp.assists
			_update_spell(p, club, mp.goals, mp.assists)
			var goals_after := _spell_goals(p)
			for milestone in [50, 100, 150, 200]:
				if goals_before < milestone and goals_after >= milestone and world.has_user() and (world.is_user_club(club.id) or club.division == world.user_club().division):
					NewsManager.on_goal_milestone(world, p, milestone)
			# Disciplina
			if mp.red:
				p.suspension += 1 if world.rng.randf() < 0.7 else 2
				newly_suspended[p.id] = true
			elif mp.yellow > 0:
				p.yellow_acc += mp.yellow
				if p.yellow_acc >= yellow_limit:
					p.yellow_acc -= yellow_limit
					p.suspension += 1
					newly_suspended[p.id] = true
			# Lesão
			if mp.injured:
				p.injury_weeks = maxi(p.injury_weeks, mp.injury_weeks)
				p.injury_name = InjuryTable.name_for(mp.injury_weeks, p.id + world.season.day)
				NewsManager.on_injury(world, p)
			# Moral
			var vol := p.trait_mult("morale_volatility")
			var dmor := 4.0 if res == "V" else (0.5 if res == "E" else -4.0)
			if mp.final_rating >= 7.5:
				dmor += 2.0
			elif mp.final_rating <= 5.5:
				dmor -= 2.0
			if derby:
				dmor *= 1.5
			p.morale = clampf(p.morale + dmor * vol, 0.0, 100.0)
		# Quem não jogou: estrelas e titulares reclamam do banco
		for pid in club.player_ids:
			if played.has(pid):
				continue
			var q := world.player(pid)
			if q == null or not q.is_available():
				continue
			if q.squad_status <= Player.STATUS_STARTER:
				q.morale = clampf(q.morale - 2.5 * q.trait_mult("morale_volatility"), 0.0, 100.0)
			elif q.squad_status == Player.STATUS_PROSPECT and q.age(world.year) >= 19:
				q.morale = clampf(q.morale - 0.6, 0.0, 100.0)


static func _update_spell(p: Player, club: Club, goals: int, assists: int) -> void:
	if p.spells.is_empty() or int(p.spells[p.spells.size() - 1].get("c", -1)) != club.id:
		p.spells.append({"c": club.id, "cn": club.short_name, "from": p.joined_year, "to": 0, "a": 0, "g": 0, "as": 0})
	var s: Dictionary = p.spells[p.spells.size() - 1]
	s["a"] = int(s.get("a", 0)) + 1
	s["g"] = int(s.get("g", 0)) + goals
	s["as"] = int(s.get("as", 0)) + assists


static func _spell_goals(p: Player) -> int:
	if p.spells.is_empty():
		return 0
	return int(p.spells[p.spells.size() - 1].get("g", 0))


## Atalho: joga a rodada inteira sem interface (simulador e modo instantâneo).
static func play_matchday_instant(world: GameWorld) -> Dictionary:
	var md := begin_matchday(world)
	simulate_ai_matches(md)
	if not md["user"].is_empty():
		md["user"]["sim"].run_to_end()
	return finish_matchday(world, md)


# ---------------------------------------------------------------------------
# Fim de temporada
# ---------------------------------------------------------------------------

## Processa a virada de temporada. Retorna um resumo para a tela de fim de temporada.
static func end_season(world: GameWorld) -> Dictionary:
	var summary := {"year": world.year, "divisions": [], "user": {}, "retired": [], "youth": [], "left": []}
	var moves := {} # club_id -> nova divisão
	var n_div := world.season.leagues.size()
	for league: League in world.season.leagues:
		var div := league.division
		var cfg := DatabaseManager.division_config(div)
		var ids := CompetitionManager.sorted_ids(league)
		var teams := ids.size()
		var promoted: Array = []
		var relegated: Array = []
		if div > 0:
			promoted = ids.slice(0, int(cfg["promoted"]))
		if div < n_div - 1:
			relegated = ids.slice(teams - int(cfg["relegated"]))
		var top := CompetitionManager.player_ranking(world, div, Player.S_GOALS, 1)
		var scorer := {}
		if not top.is_empty():
			var sp: Player = top[0]
			scorer = {"id": sp.id, "name": sp.display_name(), "club": world.club(sp.club_id).short_name, "goals": sp.stats[Player.S_GOALS]}
		for i in teams:
			var c := world.club(ids[i])
			var row: Dictionary = league.table[c.id]
			c.add_ledger("premiacao", FinanceManager.prize_for(div, i + 1, teams))
			c.history.append({"y": world.year, "d": div, "p": i + 1, "pts": row["pts"], "w": row["w"], "dr": row["d"], "l": row["l"], "gf": row["gf"], "ga": row["ga"]})
			if c.history.size() > 80:
				c.history = c.history.slice(c.history.size() - 80)
			_update_reputation(c, div, i + 1, teams, promoted.has(c.id), relegated.has(c.id))
		var champ := world.club(ids[0])
		champ.add_title("L%d" % div)
		for pid in champ.player_ids:
			var p := world.player(pid)
			if p != null and p.stats[Player.S_APPS] >= 5:
				p.titles += 1
		for cid in promoted:
			var c := world.club(cid)
			c.add_title("A%d" % div)
			c.add_ledger("premiacao", int(DatabaseManager.division_config(div - 1)["promotion_bonus"]))
			moves[cid] = div - 1
		for cid in relegated:
			moves[cid] = div + 1
		summary["divisions"].append({"div": div, "name": league.name, "champion": ids[0], "promoted": promoted, "relegated": relegated,
			"scorer": scorer, "table": ids})
		NewsManager.post(world, "campeao", {"club": champ.short_name, "division": league.name, "pts": league.table[champ.id]["pts"], "year": world.year},
			champ.id, -1, NewsEvent.IMP_HEADLINE if world.is_user_club(champ.id) else NewsEvent.IMP_HIGH)
		for cid in promoted:
			NewsManager.post(world, "acesso", {"club": world.club(cid).short_name, "division": world.division_name(div - 1), "pos": ids.find(cid) + 1},
				cid, -1, NewsEvent.IMP_HEADLINE if world.is_user_club(cid) else NewsEvent.IMP_NORMAL)
		for cid in relegated:
			NewsManager.post(world, "rebaixamento", {"club": world.club(cid).short_name, "division": world.division_name(div + 1), "pos": ids.find(cid) + 1},
				cid, -1, NewsEvent.IMP_HEADLINE if world.is_user_club(cid) else NewsEvent.IMP_NORMAL)
	# Resumo do usuário
	if world.has_user():
		var u := world.user_club()
		var league: League = world.season.leagues[u.division]
		var pos := CompetitionManager.position_of(league, u.id)
		var goal := goal_of(world, u.id)
		summary["user"] = {"div": u.division, "pos": pos, "goal": goal[0], "goal_met": pos <= int(goal[1]),
			"promoted": moves.get(u.id, u.division) < u.division, "relegated": moves.get(u.id, u.division) > u.division,
			"champion": pos == 1}
		world.manager_stats["seasons"] = int(world.manager_stats.get("seasons", 0)) + 1
		if pos == 1:
			world.manager_stats["titles"] = int(world.manager_stats.get("titles", 0)) + 1
		if summary["user"]["promoted"]:
			world.manager_stats["promotions"] = int(world.manager_stats.get("promotions", 0)) + 1
	# Arquivo individual da temporada
	for p: Player in world.players.values():
		if p.stats[Player.S_APPS] > 0 and p.club_id >= 0:
			p.history.append({"y": world.year, "c": p.club_id, "cn": world.club(p.club_id).short_name,
				"a": p.stats[Player.S_APPS], "g": p.stats[Player.S_GOALS], "as": p.stats[Player.S_ASSISTS], "r": snappedf(p.avg_rating(), 0.01)})
			if p.history.size() > 25:
				p.history = p.history.slice(p.history.size() - 25)
	world.history.append({"y": world.year, "div": summary["divisions"].map(func(d): return {"champion": d["champion"], "promoted": d["promoted"], "relegated": d["relegated"], "scorer": d["scorer"]}),
		"user": summary["user"]})
	# Revisão anual de potencial (explosões / estagnações)
	var review := PlayerDevelopment.yearly_review(world)
	for p in review["explosions"]:
		NewsManager.on_explosion(world, p)
	# Aposentadorias
	var retired := PlayerDevelopment.process_retirements(world)
	world.stat_add("retirements", retired.size())
	for p in retired:
		if p.club_id >= 0 and world.is_user_club(p.club_id):
			summary["retired"].append(p.display_name())
	# Contratos vencidos
	var left := TransferManager.process_expiring_contracts(world)
	for p in left:
		summary["left"].append(p.display_name())
		NewsManager.post(world, "contrato_fim", {"player": p.display_name(), "club": world.user_club().short_name, "apps": p.career_apps}, world.user_club_id, p.id, NewsEvent.IMP_HIGH)
	# Investimentos em estrutura/base e depreciação
	FinanceManager.yearly_investments(world)
	# Mudança de divisões
	for cid in moves:
		world.club(cid).division = moves[cid]
	# Novo ano
	world.year += 1
	world.season_number += 1
	# Base
	var youth := PlayerDevelopment.youth_intake(world)
	var yc := 0
	for cid in youth:
		yc += youth[cid].size()
	world.stat_add("youth_generated", yc)
	if world.has_user():
		var mine: Array = youth.get(world.user_club_id, [])
		mine.sort_custom(func(a, b): return a.potential > b.potential)
		for p in mine:
			summary["youth"].append(p.display_name())
		if not mine.is_empty():
			var best: Player = mine[0]
			NewsManager.post(world, "base", {"club": world.user_club().short_name, "n": mine.size(), "player": best.display_name(),
				"pos": Pos.name_of(best.position).to_lower(), "age": best.age(world.year), "potential": Player.potential_label(best.potential_estimate(0.8)).to_lower()},
				world.user_club_id, best.id, NewsEvent.IMP_HIGH)
	# Agentes livres: mantém o mercado vivo, sem inchar
	_maintain_free_agents(world)
	TransferManager.balance_squads(world)
	# Nova temporada
	world.season = build_season(world)
	world.transfer_log = world.transfer_log.filter(func(t): return t.year >= world.year - 1)
	world.offers.clear()
	world.stats.erase("neg")
	for c: Club in world.clubs:
		c.reset_season_state()
		c.cohesion = maxf(35.0, c.cohesion - 8.0)
		FinanceManager.set_budgets(world, c)
		if not world.is_user_club(c.id):
			PlayerGenerator.assign_statuses(world, c)
		_assign_missing_shirts(world, c)
	Valuation.refresh_shift(world)
	for p: Player in world.players.values():
		p.reset_season_stats()
		p.yellow_acc = 0
		p.suspension = 0
		p.condition = 100.0
		p.retiring = false
		Valuation.update_value(p, world.year)
	compute_goals(world)
	if world.has_user():
		var goal := goal_of(world, world.user_club_id)
		NewsManager.post(world, "temporada", {"year": world.year, "club": world.user_club().short_name, "goal": goal[0].to_lower()}, world.user_club_id, -1, NewsEvent.IMP_HIGH)
	return summary


static func _update_reputation(c: Club, div: int, pos: int, teams: int, promoted: bool, relegated: bool) -> void:
	var rr: Array = DatabaseManager.division_config(div)["rep_range"]
	var t := float(teams - pos) / maxf(1.0, teams - 1)
	var target := float(rr[0]) + (float(rr[1]) - float(rr[0])) * t
	if promoted:
		target += 6.0
	if relegated:
		target -= 6.0
	c.reputation = clampf(c.reputation + (target - c.reputation) * 0.18, 5.0, 99.0)
	var fan_f := 1.0 + (target - c.reputation) / 400.0
	if pos == 1:
		fan_f += 0.05
	if relegated:
		fan_f -= 0.05
	c.fan_base = maxi(800, int(c.fan_base * fan_f))


static func _maintain_free_agents(world: GameWorld) -> void:
	var free := world.free_agents().duplicate()
	# Remove os mais fracos se o mercado inchar demais.
	if free.size() > 160:
		# Quem sobra no mercado sem clube (velhos e fracos primeiro) abandona o futebol.
		var y := world.year
		free.sort_custom(func(a, b): return a.ovr_f - maxf(0.0, a.age(y) - 29.0) * 3.0 < b.ovr_f - maxf(0.0, b.age(y) - 29.0) * 3.0)
		for i in free.size() - 160:
			world.remove_player(free[i])
		world.stat_add("retirements", free.size() - 160)
	var used := WorldGenerator.used_names_of(world)
	var have := world.free_agents().size()
	for i in maxi(0, 60 - have):
		var div := RngUtil.weighted_index(world.rng, [1.0, 2.0, 3.0, 4.0])
		var lr: Array = DatabaseManager.division_config(div)["level_range"]
		PlayerGenerator.create_free_agent(world, world.rng, (float(lr[0]) + float(lr[1])) * 0.5, used)


static func _assign_missing_shirts(world: GameWorld, c: Club) -> void:
	var used := {}
	for p in world.squad(c):
		if p.shirt > 0 and not used.has(p.shirt):
			used[p.shirt] = true
		else:
			p.shirt = 0
	var next := 12
	for p in world.squad(c):
		if p.shirt == 0:
			while used.has(next):
				next += 1
			p.shirt = next
			used[next] = true
