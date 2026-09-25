class_name SeasonManager
extends RefCounted
## Ciclo da temporada no mundo inteiro: montagem (ligas de todos os países, copas e calendário
## unificado), processamento data a data (partida detalhada do usuário, modo rápido para o resto do
## mundo), acesso e rebaixamento por país, classificação continental e a virada de ano.

## Ligas de primeira divisão cujos campeões viram notícia mesmo longe do usuário.
const MAJOR_COEF := 70

## Tempo acumulado (µs) por etapa do processamento das datas — medição de desempenho (simulador).
static var timings: Dictionary = {}


static func _time(key: String, t0: int) -> int:
	var now := Time.get_ticks_usec()
	timings[key] = int(timings.get(key, 0)) + now - t0
	return now


# ---------------------------------------------------------------------------
# Montagem
# ---------------------------------------------------------------------------

static func setup_first_season(world: GameWorld) -> void:
	world.season = build_season(world)
	NationalTeamManager.start_season(world)
	for c in world.clubs:
		c.reset_season_state()
		FinanceManager.set_budgets(world, c)
	for p: Player in world.players.values():
		p.ovr_start = p.overall
	compute_goals(world)


## Datas da temporada a partir do modelo do rules.json (sábados para a liga, quartas para as copas).
## As supercopas (U0, U1) vêm antes da primeira rodada. Cada data leva as marcas "win" (janela de
## transferências aberta) e "ret" (anúncio de aposentadorias), então saves antigos com outro modelo
## de calendário continuam com as suas próprias datas.
static func build_calendar(year: int) -> Array:
	var cc := DatabaseManager.calendar_cfg()
	var jan1 := Time.get_unix_time_from_datetime_dict({"year": year, "month": 1, "day": 1})
	var start := Time.get_unix_time_from_datetime_dict({"year": year, "month": int(cc.get("start_month", 8)), "day": int(cc.get("start_day", 15))})
	var sat := int((start - jan1) / 86400)
	var wd := int(Time.get_datetime_dict_from_unix_time(start)["weekday"])
	sat += (6 - wd + 7) % 7
	var out: Array = []
	var slots: Array = cc["slots"]
	var brk := int(cc.get("winter_break_after", -1))
	var first_w := true
	for i in slots.size():
		var t: String = slots[i]
		if t == "W":
			if not first_w:
				sat += 7
			first_w = false
			out.append({"t": t, "d": sat})
		elif t == "U0":
			out.append({"t": t, "d": sat - 10}) # quarta-feira, dez dias antes da estreia
		elif t == "U1":
			out.append({"t": t, "d": sat - 6}) # domingo anterior à primeira rodada
		elif t.begins_with("C"):
			out.append({"t": t, "d": sat + 4})
		else:
			out.append({"t": t, "d": (int(out[out.size() - 1]["d"]) + 4) if not out.is_empty() else sat})
		if i == brk:
			sat += int(cc.get("winter_break_days", 0))
	for w in cc.get("windows", []):
		for i in range(int(w[0]), mini(int(w[1]) + 1, out.size())):
			out[i]["win"] = true
	var ret := int(cc.get("retire_announce", -1))
	if ret >= 0 and ret < out.size():
		out[ret]["ret"] = true
	return out


## Cria as ligas (clubes pela liga atual de cada um), os jogos, as copas e o calendário de `world.year`.
## Notícias da segunda fase e dos playoffs (só das ligas que interessam ao usuário).
static func _league_format_news(world: GameWorld, league: League, ev: Dictionary) -> void:
	var mine := world.has_user() and (league.nation == world.user_nation() or league.has_club(world.user_club_id))
	if not mine and not _is_major(league):
		return
	match String(ev["t"]):
		"split":
			var names: Array = []
			for g in league.phase_groups:
				names.append(str(g.size()))
			NewsManager.post_raw(world, "%s se divide: começa a fase decisiva" % league.short_name,
				"Terminada a fase regular, a %s se divide em grupos de %s clubes. Quem está no grupo de cima termina à frente, aconteça o que acontecer." % [league.name, " e ".join(PackedStringArray(names))],
				-1, -1, NewsEvent.IMP_HIGH if mine else NewsEvent.IMP_NORMAL, "liga")
		"playoff_start":
			var cl: Array = ev["clubs"]
			NewsManager.post_raw(world, "Playoffs da %s definidos" % league.short_name,
				"%d clubes disputam o título em mata-mata. %s termina a fase regular na liderança." % [cl.size(), world.club(int(cl[0])).short_name],
				int(cl[0]), -1, NewsEvent.IMP_HIGH if mine else NewsEvent.IMP_NORMAL, "liga")
		"playoff_champion":
			var c := world.club(int(ev["club"]))
			NewsManager.post_raw(world, "%s é campeão da %s!" % [c.short_name, league.short_name],
				"O %s venceu os playoffs e levantou a taça da %s." % [c.name, league.name],
				c.id, -1, NewsEvent.IMP_HEADLINE if world.is_user_club(c.id) else NewsEvent.IMP_HIGH, "liga")


static func build_season(world: GameWorld) -> SeasonState:
	var s := SeasonState.new()
	s.year = world.year
	s.calendar = build_calendar(world.year)
	var weekends: Array = []
	for i in s.calendar.size():
		if s.calendar[i]["t"] == "W":
			weekends.append(i)
	var by_league := {}
	for c in world.clubs:
		if not by_league.has(c.league_id):
			by_league[c.league_id] = []
		by_league[c.league_id].append(c.id)
	for id in DatabaseManager.league_ids():
		var cfg := DatabaseManager.league_cfg(id)
		var l := League.new()
		l.id = id
		l.nation = cfg["nation"]
		l.tier = int(cfg["tier"])
		l.name = cfg["name"]
		l.short_name = cfg.get("short", l.name)
		l.club_ids = by_league.get(id, [])
		# Saves de antes das ligas ampliadas têm menos clubes: mais turnos para manter ~30 rodadas
		var rr := int(cfg.get("rr", 2))
		var n_clubs := l.club_ids.size()
		if n_clubs > 1 and n_clubs < int(cfg.get("teams", n_clubs)):
			rr = maxi(rr, int(ceil(30.0 / (n_clubs - 1))))
		# Formato real: os últimos fins de semana ficam para a segunda fase ou os playoffs.
		var extra := LeagueFormat.extra_rounds(cfg, n_clubs)
		var reg_weekends: Array = weekends.slice(0, weekends.size() - extra) if extra > 0 else weekends
		# Cada rodada precisa de um fim de semana próprio: turnos a mais ficariam sem data.
		var per_turn := n_clubs - 1 + n_clubs % 2
		while rr > 1 and per_turn * rr > reg_weekends.size():
			rr -= 1
		FixtureManager.build_league_fixtures(world.rng, l, rr, reg_weekends)
		l.regular_rounds = l.rounds.size()
		if extra > 0:
			l.phase_slots = weekends.slice(weekends.size() - extra)
		CompetitionManager.init_table(l)
		s.leagues[id] = l
		s.league_order.append(id)
	CupManager.setup_season(world, s)
	s.day = 0
	s.finished = false
	return s


## Metas da diretoria conforme a força relativa do elenco dentro da liga.
static func compute_goals(world: GameWorld) -> void:
	var goals := {}
	for id in world.season.league_order:
		var league: League = world.season.leagues[id]
		var ranked: Array = league.club_ids.duplicate()
		var strength := {}
		for cid in ranked:
			strength[cid] = ClubAI._compute_strength(world, world.club(cid))
		ranked.sort_custom(func(a, b): return strength[a] > strength[b] or (strength[a] == strength[b] and a < b))
		var teams := ranked.size()
		var up := league.promoted_count()
		var down := league.relegated_count()
		var cont := CupManager.continental_spots(league)
		var cup_short := CupManager.cup_short(CupManager.cup_of_nation(league.nation))
		for i in teams:
			var rank := i + 1
			var goal: Array
			if league.tier == 1:
				var top := maxi(3, int(round(teams * 0.3)))
				var mid := maxi(top + 1, int(round(teams * 0.6)))
				if rank <= 2:
					goal = ["Ser campeão", 1]
				elif cont > 0 and rank <= cont + 1:
					goal = ["Classificar para a %s" % cup_short, cont]
				elif rank <= top + 1:
					goal = ["Terminar entre os %d primeiros" % top, top]
				elif rank <= mid or down == 0:
					goal = ["Terminar entre os %d primeiros" % mid, mid] if down > 0 or rank <= mid else ["Não terminar entre os últimos", teams - 2]
				else:
					goal = ["Evitar o rebaixamento", teams - down]
			else:
				if rank <= maxi(2, up):
					goal = ["Conquistar o acesso", up]
				elif rank <= up + 5:
					goal = ["Brigar pelo acesso", up + 3]
				elif down == 0 or rank <= teams - down - 3:
					goal = ["Terminar no meio da tabela", teams / 2 + 2]
				else:
					goal = ["Evitar o rebaixamento", teams - down]
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
# Data (slot) do calendário
# ---------------------------------------------------------------------------

## Prepara a data atual: contexto e sementes de todos os jogos. A partida do usuário volta viva
## (MatchSimulation detalhada); as demais ficam na fila do modo rápido (run_entry).
## Retorna {"day", "entries": [{f, seed, ctx, sim}], "user": entrada do usuário ou {}, "notes"}.
static func begin_matchday(world: GameWorld) -> Dictionary:
	var md := {"day": world.season.day, "entries": [], "user": {}, "notes": []}
	for f: Fixture in world.season.fixtures_at(world.season.day):
		if not f.played and (world.is_user_club(f.home) or world.is_user_club(f.away)):
			SponsorManager.close_preseason(world) # primeiro jogo: uniforme e patrocínios travados
			break
	for f: Fixture in world.season.fixtures_at(world.season.day):
		if f.played:
			continue
		var entry := {"f": f, "seed": world.rng.randi(), "ctx": MatchEngine.context_for(world, f), "sim": null, "res": {}}
		if world.is_user_club(f.home) or world.is_user_club(f.away):
			var home := world.club(f.home)
			var away := world.club(f.away)
			var hs := _sheet_for(world, home, away, true, md)
			var as_ := _sheet_for(world, away, home, false, md)
			var sim := MatchSimulation.new()
			sim.setup(world, home, away, hs, as_, entry["ctx"], entry["seed"], true)
			entry["sim"] = sim
			md["user"] = entry
		md["entries"].append(entry)
	return md


static func _sheet_for(world: GameWorld, club: Club, opp: Club, home: bool, md: Dictionary) -> TeamSheet:
	if world.is_user_club(club.id):
		md["notes"] = ClubAI.validate_user_sheet(world, club)
		return club.sheet.duplicate_sheet()
	return ClubAI.prepare_ai_sheet(world, club, opp, home)


## Roda uma entrada ainda não simulada: modo rápido para IA × IA; minuto a minuto para o usuário.
static func run_entry(world: GameWorld, entry: Dictionary) -> void:
	if not entry["res"].is_empty():
		return
	var sim: MatchSimulation = entry["sim"]
	if sim != null:
		if not sim.finished:
			sim.run_to_end()
		entry["res"] = sim.to_result()
		return
	var f: Fixture = entry["f"]
	var home := world.club(f.home)
	var away := world.club(f.away)
	var hs := ClubAI.prepare_ai_sheet(world, home, away, true)
	var as_ := ClubAI.prepare_ai_sheet(world, away, home, false)
	entry["res"] = QuickMatch.play(world, home, away, hs, as_, entry["ctx"], entry["seed"])


static func entry_done(entry: Dictionary) -> bool:
	return not entry["res"].is_empty()


## Aplica tudo o que aconteceu na data e avança o calendário. Retorna um relatório para a UI.
static func finish_matchday(world: GameWorld, md: Dictionary) -> Dictionary:
	var tt := Time.get_ticks_usec()
	for e in md["entries"]:
		run_entry(world, e)
	tt = _time("jogos", tt)
	var s := world.season
	var slot := s.day
	var weekend := s.is_weekend(slot)
	var report := {"day": slot, "user": {}, "transfers": [], "retiring": [], "window_opened": false, "window_closed": false, "cups": []}
	var user_pos_before := 0
	if world.has_user():
		var ul := world.league_of(world.user_club_id)
		if ul != null and int(ul.table[world.user_club_id]["pl"]) > 0:
			user_pos_before = CompetitionManager.position_of(ul, world.user_club_id)
	var was_open := world.transfer_window_open()
	# Lesões antigas avançam uma semana (a cada fim de semana) antes de registrar as novas.
	if weekend:
		for p: Player in world.players.values():
			if p.injury_weeks > 0:
				p.injury_weeks -= 1
				if p.injury_weeks == 0:
					p.injury_name = ""
	var played := {}
	var newly_suspended := {}
	var clubs_played := {}
	for e in md["entries"]:
		var f: Fixture = e["f"]
		var res: Dictionary = e["res"]
		_apply_match(world, f, res, played, newly_suspended)
		clubs_played[f.home] = true
		clubs_played[f.away] = true
		if not f.neutral:
			var home := world.club(f.home)
			var price := FinanceManager.ticket_price(home) * (1.4 if not f.is_league() else 1.0)
			home.add_ledger("bilheteria", int(int(res["att"]) * price))
	WeeklyAwards.after_matchday(world, md, slot)
	tt = _time("aplicar", tt)
	# Suspensões cumpridas por quem ficou de fora de um jogo do seu clube
	var sus := world.suspended()
	for pid in sus.keys():
		var p: Player = world.players.get(pid, null)
		if p == null or p.suspension <= 0:
			sus.erase(pid)
			continue
		if p.club_id >= 0 and clubs_played.has(p.club_id) and not played.has(pid) and not newly_suspended.has(pid):
			p.suspension -= 1
			if p.suspension <= 0:
				sus.erase(pid)
	# Recuperação física (proporcional aos dias até a próxima data); a moral volta ao normal na evolução semanal.
	var days := _days_to_next(s, slot)
	var dayf := days / 7.0
	var rec_set := world.recovering()
	for pid in rec_set.keys():
		var p: Player = world.players.get(pid, null)
		if p == null:
			rec_set.erase(pid)
			continue
		var fac: int = world.clubs[p.club_id].facilities if p.club_id >= 0 else 40
		var rec: float = (16.0 + p.attrs[Attr.RES] * 0.08 + fac * 0.04 - maxf(0.0, p.age(world.year) - 30.0) * 0.8) * dayf
		if p.club_id == world.user_club_id and p.club_id >= 0:
			rec *= TrainingManager.recovery_mult(world, p.club_id)
		p.condition = minf(100.0, p.condition + rec)
		if p.condition >= 100.0:
			rec_set.erase(pid)
	tt = _time("recuperacao", tt)
	if weekend:
		# Evolução, finanças e mercado andam por semana.
		var notable := PlayerDevelopment.weekly_tick(world, played, clubs_played)
		for p in notable:
			if p.age(world.year) <= 21:
				NewsManager.on_explosion(world, p)
		tt = _time("evolucao", tt)
		for c: Club in world.clubs:
			FinanceManager.process_week(world, c)
			c.fan_mood = clampf(c.fan_mood + (60.0 - c.fan_mood) * 0.03, 0.0, 100.0)
		WorldEvents.weekly(world)
		tt = _time("financas", tt)
		TrainingManager.weekly(world)
		YouthManager.weekly(world)
		HeartClubs.weekly(world)
		report["youth"] = YouthManager.play_slot(world, slot)
		report["transfers"] = TransferManager.process_matchday(world)
		tt = _time("mercado", tt)
		report["intl"] = NationalTeamManager.after_weekend(world, _weekend_index(s, slot))
		tt = _time("selecoes", tt)
		if _weekend_index(s, slot) % 4 == 3:
			for p: Player in world.players.values():
				Valuation.update_value(p, world.year)
		tt = _time("valores", tt)
	# Veteranos anunciam aposentadoria
	if s.is_retire_slot(slot):
		var ann := PlayerDevelopment.announce_retirements(world)
		report["retiring"] = ann
		for p in ann:
			NewsManager.on_retirement_announced(world, p)
	# Copas: grupos, confrontos, campeões e o Mundial
	var cup_events := CupManager.after_slot(world, slot)
	report["cups"] = cup_events
	# Formatos reais das ligas: split e playoffs
	for lid in s.league_order:
		for ev in LeagueFormat.after_slot(world, s.leagues[lid]):
			_league_format_news(world, s.leagues[lid], ev)
	NewsManager.on_cup_events(world, cup_events)
	# Notícias da data e pressão sobre os técnicos
	NewsManager.after_matchday(world, md["entries"])
	People.after_matchday(world, md["entries"])
	tt = _time("copas_noticias", tt)
	# Avança o calendário
	s.day += 1
	if s.day >= s.calendar.size():
		s.finished = true
	var now_open := world.transfer_window_open()
	if now_open and not was_open:
		report["window_opened"] = true
		NewsManager.on_window(world, true)
		if s.day > 5:
			for c: Club in world.clubs:
				FinanceManager.mid_season_review(world, c)
	elif was_open and not now_open:
		report["window_closed"] = true
		NewsManager.on_window(world, false)
	# Relatório do usuário
	if world.has_user() and not md["user"].is_empty():
		var f: Fixture = md["user"]["f"]
		s.turn += 1
		var league := world.league_of(world.user_club_id)
		report["user"] = {"fixture": f, "result": f.result_for(world.user_club_id), "pos_before": user_pos_before,
			"pos_after": CompetitionManager.position_of(league, world.user_club_id) if league != null else 0}
		report["events"] = EventManager.after_user_turn(world, String(report["user"]["result"]))
		report["talks"] = People.after_user_turn(world, md["user"], String(report["user"]["result"]))
	return report


static func _days_to_next(s: SeasonState, slot: int) -> int:
	if slot + 1 >= s.calendar.size():
		return 7
	return clampi(int(s.calendar[slot + 1]["d"]) - int(s.calendar[slot]["d"]), 1, 21)


static func _weekend_index(s: SeasonState, slot: int) -> int:
	var n := 0
	for i in slot:
		if s.calendar[i]["t"] == "W":
			n += 1
	return n


static func _apply_match(world: GameWorld, f: Fixture, res: Dictionary, played: Dictionary, newly_suspended: Dictionary) -> void:
	f.played = true
	f.hg = int(res["hg"])
	f.ag = int(res["ag"])
	f.attendance = int(res["att"])
	f.extra_time = bool(res.get("et", false))
	var pens: Array = res.get("pens", [])
	if pens.size() == 2:
		f.pen_h = int(pens[0])
		f.pen_a = int(pens[1])
	f.goals = Array(res["goals"]).duplicate()
	f.motm = int(res["motm"])
	var is_league := f.is_league()
	if is_league:
		var league := world.league(f.comp)
		if league != null:
			CompetitionManager.apply_result(league, f)
			var yc: Array = res["yc"]
			var rc: Array = res["rc"]
			league.table[f.home]["yc"] += int(yc[0])
			league.table[f.home]["rc"] += int(rc[0])
			league.table[f.away]["yc"] += int(yc[1])
			league.table[f.away]["rc"] += int(rc[1])
	elif world.league(f.comp) == null:
		CupManager.apply_result(world, f) # (playoffs de liga: o confronto é resolvido em LeagueFormat)
	var derby := bool(res.get("derby", false))
	var big := derby or float(res.get("importance", 0.3)) >= 0.7
	var yellow_limit := int(DatabaseManager.squad_rules()["yellow_limit"])
	var score: Array = [f.hg, f.ag]
	for side in 2:
		var club := world.club(f.home if side == 0 else f.away)
		var result := f.result_for(club.id)
		club.push_result(result)
		if result == "V" and world.is_user_club(club.id):
			SponsorManager.on_win(world, club)
		club.cohesion = minf(92.0, club.cohesion + 1.2)
		TacticsManager.after_match(club, club.sheet, String(club.training.get("focus", "")) == "tatico")
		# Torcida
		var patience := float(club.arch().get("fan_patience", 50))
		var swing := 1.0 + (50.0 - patience) / 100.0
		var dm := 3.0 if result == "V" else (-0.5 if result == "E" else -3.0 * swing)
		if result == "V" and world.is_user_club(club.id) and ManagerProfile.has_style(world, "ofensivo"):
			dm *= 1.25
		if big:
			dm *= 1.8
		club.fan_mood = clampf(club.fan_mood + dm, 0.0, 100.0)
		# Técnico do usuário
		if world.is_user_club(club.id):
			world.manager_stats["games"] = int(world.manager_stats.get("games", 0)) + 1
			var key := "w" if result == "V" else ("d" if result == "E" else "l")
			world.manager_stats[key] = int(world.manager_stats.get(key, 0)) + 1
			BoardManager.after_match(world, club, result, derby)
		var conceded: int = score[1 - side]
		for ln in res["lines"][side]:
			var p: Player = ln[QuickMatch.L_P]
			var mins: int = ln[QuickMatch.L_MINS]
			var g: int = ln[QuickMatch.L_G]
			var a: int = ln[QuickMatch.L_A]
			var r: float = ln[QuickMatch.L_R]
			var yellows: int = ln[QuickMatch.L_Y]
			var red: bool = ln[QuickMatch.L_RED]
			var inj: int = ln[QuickMatch.L_INJ]
			played[p.id] = int(played.get(p.id, 0)) + mins
			p.minutes_season += mins
			if is_league:
				p.stats[Player.S_APPS] += 1
				if int(ln[QuickMatch.L_START]) == 0:
					p.stats[Player.S_STARTS] += 1
				p.stats[Player.S_MINUTES] += mins
				p.stats[Player.S_GOALS] += g
				p.stats[Player.S_ASSISTS] += a
				p.stats[Player.S_RATING_SUM] += int(round(r * 10.0))
				if red:
					p.stats[Player.S_REDS] += 1
				else:
					p.stats[Player.S_YELLOWS] += yellows
				if f.motm == p.id:
					p.stats[Player.S_MOTM] += 1
				if conceded == 0 and mins >= 60 and ln[QuickMatch.L_DEFN]:
					p.stats[Player.S_CLEAN] += 1
			else:
				p.cup_add(f.comp, mins, g, a, r)
			p.push_rating(r)
			p.condition = float(ln[QuickMatch.L_COND])
			world.mark_tired(p)
			var before := p.career_goals
			p.career_apps += 1
			p.career_goals += g
			p.career_assists += a
			_update_spell(p, club, g, a)
			if g > 0 and before / 50 != p.career_goals / 50 and world.has_user() and (world.is_user_club(club.id) or club.league_id == world.user_league_id()):
				NewsManager.on_goal_milestone(world, p, (p.career_goals / 50) * 50)
			# Disciplina
			if red:
				p.suspension += 1 if world.rng.randf() < 0.7 else 2
				newly_suspended[p.id] = true
				world.mark_suspended(p)
			elif yellows > 0 and is_league:
				p.yellow_acc += yellows
				if p.yellow_acc >= yellow_limit:
					p.yellow_acc -= yellow_limit
					p.suspension += 1
					newly_suspended[p.id] = true
					world.mark_suspended(p)
			# Lesão
			if inj > 0:
				p.injury_weeks = maxi(p.injury_weeks, inj)
				p.injury_name = InjuryTable.name_for(inj, p.id + world.season.day)
				PlayerDevelopment.injury_setback(world.rng, p, inj, p.age(world.year))
				NewsManager.on_injury(world, p)
			# Moral
			var vol := p.trait_mult("morale_volatility")
			var dmor := 4.0 if result == "V" else (0.5 if result == "E" else -4.0)
			if r >= 7.5:
				dmor += 2.0
			elif r <= 5.5:
				dmor -= 2.0
			if big:
				dmor *= 1.5
			p.morale = clampf(p.morale + dmor * vol, 0.0, 100.0)


static func _update_spell(p: Player, club: Club, goals: int, assists: int) -> void:
	var s: Dictionary = p.spells[p.spells.size() - 1] if not p.spells.is_empty() else {}
	if s.is_empty() or int(s["c"]) != club.id:
		s = {"c": club.id, "cn": club.short_name, "from": p.joined_year, "to": 0, "a": 0, "g": 0, "as": 0}
		p.spells.append(s)
	s["a"] += 1
	if goals > 0:
		s["g"] += goals
	if assists > 0:
		s["as"] += assists


## Atalho: joga a data inteira sem interface (simulador, datas sem o usuário e modo instantâneo).
static func play_matchday_instant(world: GameWorld) -> Dictionary:
	var tt := Time.get_ticks_usec()
	var md := begin_matchday(world)
	_time("preparar", tt)
	for e in md["entries"]:
		run_entry(world, e)
	return finish_matchday(world, md)


## O usuário joga na data atual?
static func user_plays_now(world: GameWorld) -> bool:
	if not world.has_user() or world.season == null or world.season.finished:
		return false
	return FixtureManager.next_slot_for(world, world.user_club_id) == world.season.day


## Joga (instantaneamente) todas as datas até a próxima partida do usuário ou o fim da temporada.
## Retorna os relatórios dessas datas.
static func advance_to_user(world: GameWorld) -> Array:
	var reports: Array = []
	var guard := 0
	while world.season != null and not world.season.finished and not user_plays_now(world) and guard < 80:
		reports.append(play_matchday_instant(world))
		guard += 1
	return reports


# ---------------------------------------------------------------------------
# Fim de temporada
# ---------------------------------------------------------------------------

static func _is_major(league: League) -> bool:
	return league.tier == 1 and int(DatabaseManager.nation(league.nation).get("coef", 0)) >= MAJOR_COEF


## Processa a virada de temporada. Retorna um resumo para a tela de fim de temporada.
static func end_season(world: GameWorld) -> Dictionary:
	var s := world.season
	var summary := {"year": world.year, "leagues": [], "cups": [], "user": {}, "retired": [], "youth": [], "left": []}
	var user_nation := world.user_nation()
	var rep0 := world.user_club().reputation if world.has_user() else 0.0
	var fans0 := world.user_club().fan_base if world.has_user() else 0
	# Vagas continentais do ano que vem (antes das mudanças de divisão)
	world.stats["qualified"] = CupManager.compute_qualified(world)
	# Ranking mundial de clubes: arquiva a temporada antes que tabelas e copas sejam desfeitas
	ClubRanking.close_season(world)
	ClubRanking.season_news(world)
	var moves := {} # club_id -> nova liga
	var hist_leagues := {}
	for id in s.league_order:
		var league: League = s.leagues[id]
		var ids := CompetitionManager.sorted_ids(league)
		var teams := ids.size()
		if teams == 0:
			continue
		var up := league.promoted_count()
		var down := league.relegated_count()
		var upper := DatabaseManager.league_at(league.nation, league.tier - 1) if league.tier > 1 else ""
		var lower := DatabaseManager.league_at(league.nation, league.tier + 1)
		var promoted: Array = ids.slice(0, up) if up > 0 and upper != "" else []
		var relegated: Array = ids.slice(teams - down) if down > 0 and lower != "" else []
		var top := CompetitionManager.player_ranking(world, id, Player.S_GOALS, 1)
		var scorer := {}
		if not top.is_empty():
			var sp: Player = top[0]
			scorer = {"id": sp.id, "name": sp.display_name(), "club": world.club(sp.club_id).short_name if sp.club_id >= 0 else "", "goals": sp.stats[Player.S_GOALS]}
		var cfg := league.cfg()
		for i in teams:
			var c := world.club(ids[i])
			var row: Dictionary = league.table[c.id]
			c.add_ledger("premiacao", FinanceManager.prize_for(id, i + 1, teams))
			c.history.append({"y": world.year, "l": id, "p": i + 1, "pts": row["pts"], "w": row["w"], "dr": row["d"], "lo": row["l"], "gf": row["gf"], "ga": row["ga"]})
			if c.history.size() > 80:
				c.history = c.history.slice(c.history.size() - 80)
			_update_reputation(c, cfg, i + 1, teams, promoted.has(c.id), relegated.has(c.id))
		var champ := world.club(LeagueFormat.champion(league, ids))
		champ.add_title("L:" + id)
		for pid in champ.player_ids:
			var p := world.player(pid)
			if p != null and p.stats[Player.S_APPS] >= 5:
				p.win_title(world.year, "L:" + id, champ.id)
		for cid in promoted:
			var c := world.club(cid)
			c.add_title("P:" + id)
			c.add_ledger("premiacao", FinanceManager.promotion_bonus(upper))
			moves[cid] = upper
		for cid in relegated:
			moves[cid] = lower
		summary["leagues"].append({"id": id, "name": league.name, "nation": league.nation, "tier": league.tier, "champion": champ.id,
			"promoted": promoted, "relegated": relegated, "scorer": scorer, "table": ids})
		hist_leagues[id] = {"champion": champ.id, "runner_up": LeagueFormat.runner_up(league, ids), "promoted": promoted, "relegated": relegated, "scorer": scorer}
		var mine := league.nation == user_nation
		if mine or _is_major(league) or world.is_user_club(champ.id):
			NewsManager.post(world, "campeao", {"club": champ.short_name, "division": league.name, "pts": league.table[champ.id]["pts"], "year": world.year},
				champ.id, -1, NewsEvent.IMP_HEADLINE if world.is_user_club(champ.id) else (NewsEvent.IMP_HIGH if mine else NewsEvent.IMP_NORMAL))
		if mine:
			for cid in promoted:
				NewsManager.post(world, "acesso", {"club": world.club(cid).short_name, "division": world.league_name(upper), "pos": ids.find(cid) + 1},
					cid, -1, NewsEvent.IMP_HEADLINE if world.is_user_club(cid) else NewsEvent.IMP_NORMAL)
			for cid in relegated:
				NewsManager.post(world, "rebaixamento", {"club": world.club(cid).short_name, "division": world.league_name(lower), "pos": ids.find(cid) + 1},
					cid, -1, NewsEvent.IMP_HEADLINE if world.is_user_club(cid) else NewsEvent.IMP_NORMAL)
	# Prêmios individuais
	var weekly := WeeklyAwards.season_close(world)
	summary["months"] = weekly["months"]
	summary["totw_most"] = WeeklyAwards.most_selected(weekly["totw_n"])
	var bo_rank := AwardManager.ballon_ranking(world, 10)
	summary["ballon_rank"] = bo_rank
	var awards := AwardManager.league_awards(world)
	var ballon := AwardManager.world_player(world)
	var extra := {"teams": AwardManager.teams_of_season(world), "cups": AwardManager.cup_awards(world),
		"world_young": AwardManager.world_young(world), "boot": AwardManager.golden_boot(world),
		"club": AwardManager.club_player(world, world.user_club_id) if world.has_user() else {}}
	AwardManager.credit(world, awards, ballon, extra)
	for id in hist_leagues:
		hist_leagues[id]["awards"] = awards.get(id, {})
		if extra["teams"].has(id):
			hist_leagues[id]["team"] = extra["teams"][id]
	summary["awards"] = awards.get(world.user_league_id(), {})
	summary["team"] = extra["teams"].get(world.user_league_id(), [])
	summary["ballon"] = ballon
	summary["world_young"] = extra["world_young"]
	summary["boot"] = extra["boot"]
	summary["club_player"] = extra["club"]
	summary["cup_awards"] = extra["cups"]
	if not extra["boot"].is_empty():
		var bt: Dictionary = extra["boot"]
		NewsManager.post_raw(world, "%s leva a Chuteira de Ouro" % bt["name"],
			"Com %d gols pelo %s, %s foi o artilheiro mais valioso do mundo em %d." % [int(bt["goals"]), bt["club"], bt["name"], world.year],
			-1, int(bt["id"]), NewsEvent.IMP_NORMAL, "premio")
	if not ballon.is_empty():
		NewsManager.post_raw(world, "%s ganha a Bola de Ouro" % ballon["name"],
			"%s, do %s, foi eleito o melhor jogador do planeta em %d: %d gols em %d jogos." % [ballon["full"], ballon["club"], world.year, int(ballon["goals"]), int(ballon["apps"])],
			-1, int(ballon["id"]), NewsEvent.IMP_HIGH, "premio")
	var ua: Dictionary = summary["awards"]
	if ua.has("mvp"):
		NewsManager.post_raw(world, "%s é o craque da %s" % [ua["mvp"]["name"], world.league_name(world.user_league_id())],
			"O prêmio de revelação ficou com %s." % (ua["young"]["name"] if ua.has("young") else "ninguém"), -1, int(ua["mvp"]["id"]), NewsEvent.IMP_NORMAL, "premio")
	# Copas
	var hist_cups := {}
	for cid in s.cups:
		var cup: Cup = s.cups[cid]
		var top := CupManager.scorers(world, cid, 1)
		var scorer := {}
		if not top.is_empty():
			var sp: Player = top[0]
			scorer = {"id": sp.id, "name": sp.display_name(), "club": world.club(sp.club_id).short_name if sp.club_id >= 0 else "", "goals": sp.cup_stats[cid][Player.C_GOALS]}
		summary["cups"].append({"id": cid, "name": cup.name, "champion": cup.champion, "runner_up": cup.runner_up, "scorer": scorer})
		hist_cups[cid] = {"champion": cup.champion, "runner_up": cup.runner_up, "scorer": scorer, "mvp": extra["cups"].get(cid, {})}
	# Seleções: torneios de verão (Copa do Mundo, Eurocopa, Copa América...)
	summary["intl"] = NationalTeamManager.play_summer(world)
	# Resumo do usuário
	if world.has_user():
		var u := world.user_club()
		var league := world.league_of(u.id)
		var pos := CompetitionManager.position_of(league, u.id)
		var goal := goal_of(world, u.id)
		var cups_user: Array = []
		for cid in s.cups:
			var cup: Cup = s.cups[cid]
			if cup.has_club(u.id):
				cups_user.append({"id": cid, "name": cup.name, "champion": cup.champion == u.id, "stage": _stage_reached(cup, u.id)})
		summary["user"] = {"league": u.league_id, "league_name": league.name, "pos": pos, "goal": goal[0], "goal_met": pos <= int(goal[1]),
			"promoted": moves.has(u.id) and DatabaseManager.league_cfg(moves[u.id]).get("tier", 1) < u.tier,
			"relegated": moves.has(u.id) and DatabaseManager.league_cfg(moves[u.id]).get("tier", 1) > u.tier,
			"champion": LeagueFormat.champion(league, CompetitionManager.sorted_ids(league)) == u.id, "cups": cups_user}
		world.manager_stats["seasons"] = int(world.manager_stats.get("seasons", 0)) + 1
		if summary["user"]["champion"]:
			world.manager_stats["titles"] = int(world.manager_stats.get("titles", 0)) + 1
		for cu in cups_user:
			if cu["champion"]:
				world.manager_stats["titles"] = int(world.manager_stats.get("titles", 0)) + 1
				world.manager_stats["cup_titles"] = int(world.manager_stats.get("cup_titles", 0)) + 1
		if summary["user"]["promoted"]:
			world.manager_stats["promotions"] = int(world.manager_stats.get("promotions", 0)) + 1
		EventManager.on_season_end(world, bool(summary["user"]["goal_met"]))
		summary["youth_league"] = YouthManager.finish_league(world)
		var review := BoardManager.season_review(world, u, summary["user"])
		summary["user"]["board_delta"] = review["delta"]
		summary["user"]["fired"] = review["fired"]
		summary["user"]["offers"] = review["offers"]
		summary["user"]["board"] = u.board_confidence
		var user_scorer: Dictionary = hist_leagues.get(league.id, {}).get("scorer", {})
		summary["review"] = SeasonReview.build(world, summary["user"], league, rep0, fans0, user_scorer)
	People.on_season_end(world, summary)
	# Elenco do usuário guardado como estava (camisas, jogos, gols) para "Elencos anteriores"
	var uc := world.user_club()
	if uc != null:
		var snap: Array = []
		for p: Player in world.squad(uc):
			var t := p.season_totals()
			snap.append({"id": p.id, "n": p.display_name(), "pos": p.position, "sh": p.shirt, "a": int(t[0]), "g": int(t[1]),
				"as": int(t[2]), "r": snappedf(p.avg_rating(), 0.01), "o": p.overall})
		uc.squad_archive[str(world.year)] = snap
		if uc.squad_archive.size() > 40:
			var ks: Array = uc.squad_archive.keys()
			ks.sort()
			uc.squad_archive.erase(ks[0])
	# Arquivo individual da temporada
	for p: Player in world.players.values():
		var tot := p.season_totals()
		if int(tot[0]) > 0 and p.club_id >= 0:
			p.history.append({"y": world.year, "c": p.club_id, "cn": world.club(p.club_id).short_name, "l": world.club(p.club_id).league_id,
				"a": p.stats[Player.S_APPS], "g": p.stats[Player.S_GOALS], "as": p.stats[Player.S_ASSISTS], "r": snappedf(p.avg_rating(), 0.01),
				"ca": int(tot[0]) - p.stats[Player.S_APPS], "cg": int(tot[1]) - p.stats[Player.S_GOALS],
				"cas": int(tot[2]) - p.stats[Player.S_ASSISTS], "mi": p.minutes_season, "st": p.stats[Player.S_STARTS],
				"mo": p.stats[Player.S_MOTM], "cs": p.stats[Player.S_CLEAN], "yc": p.stats[Player.S_YELLOWS], "rc": p.stats[Player.S_REDS],
				"o": p.overall, "o0": p.ovr_start if p.ovr_start >= 0 else p.overall})
			if p.history.size() > 25:
				p.history = p.history.slice(p.history.size() - 25)
	var yl_sum: Dictionary = summary.get("youth_league", {})
	world.history.append({"y": world.year, "leagues": hist_leagues, "cups": hist_cups, "user": summary["user"], "ballon": ballon,
		"club": world.user_club_id, "yl": yl_sum, "wy": extra["world_young"], "boot": extra["boot"], "cp": extra["club"],
		"arch": SeasonArchive.snapshot_leagues(world), "sq": SeasonArchive.snapshot_squad(world),
		"bo": bo_rank, "months": weekly["months"], "tw": summary["totw_most"]})
	# Evolução do elenco do usuário no ano (quem subiu e quem caiu)
	if world.has_user():
		summary["evolution"] = PlayerDevelopment.squad_evolution(world, world.user_club_id)
	# Personalidade: traços que surgem ou somem com a idade, os prêmios e o momento
	var persona := PlayerDevelopment.personality_review(world)
	summary["persona"] = []
	for ch in persona:
		var cp: Player = ch["p"]
		if cp.club_id >= 0 and world.is_user_club(cp.club_id):
			summary["persona"].append({"id": cp.id, "name": cp.display_name(), "t": ch["t"], "add": ch["add"], "why": ch["why"]})
			NewsManager.post_raw(world, "%s: %s" % [cp.display_name(), PlayerDevelopment.persona_headline(ch)],
				String(ch["why"]), world.user_club_id, cp.id, NewsEvent.IMP_NORMAL, "personalidade")
	# Âncora de talento do mundo (antes da revisão anual e da nova base)
	PlayerDevelopment.update_talent_drift(world)
	# Revisão anual de potencial (explosões / estagnações)
	var review_y := PlayerDevelopment.yearly_review(world)
	for p in review_y["explosions"]:
		NewsManager.on_explosion(world, p)
	# Aposentadorias
	var retired := PlayerDevelopment.process_retirements(world)
	world.stat_add("retirements", retired.size())
	for p in retired:
		if p.club_id >= 0 and world.is_user_club(p.club_id):
			summary["retired"].append(p.display_name())
	# Contratos vencidos
	var loans_back := TransferManager.return_loans(world)
	summary["loans_back"] = loans_back.map(func(q: Player): return q.display_name())
	var left := TransferManager.process_expiring_contracts(world)
	for p in left:
		summary["left"].append(p.display_name())
		NewsManager.post(world, "contrato_fim", {"player": p.display_name(), "club": world.user_club().short_name, "apps": p.career_apps}, world.user_club_id, p.id, NewsEvent.IMP_HIGH)
	# Investimentos em estrutura/base e depreciação
	FinanceManager.yearly_investments(world)
	# Mudança de divisões
	for cid in moves:
		var c := world.club(cid)
		c.league_id = moves[cid]
		c.tier = int(DatabaseManager.league_cfg(c.league_id).get("tier", 1))
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
		var turnover := YouthManager.season_turnover(world)
		summary["youth_left"] = turnover["left"]
		summary["youth_changes"] = turnover["changes"]
		summary["youth_cost"] = turnover["cost"]
		for ch in turnover["changes"]:
			if ch["up"] and int(ch["d"]) >= 4:
				NewsManager.post_raw(world, "%s dá o salto na base" % ch["name"], "%s O coordenador da base está animado com o garoto." % ch["why"],
					world.user_club_id, int(ch["id"]), NewsEvent.IMP_NORMAL, "base")
		var mine: Array = turnover["new"]
		yc += mine.size()
		mine.sort_custom(func(a, b): return a.potential > b.potential)
		for p in mine:
			summary["youth"].append(p.display_name())
		if not mine.is_empty():
			var best: Player = mine[0]
			NewsManager.post(world, "base", {"club": world.user_club().short_name, "n": mine.size(), "player": best.display_name(),
				"pos": Pos.name_of(best.position).to_lower(), "age": best.age(world.year), "potential": Player.potential_label(best.potential_estimate(0.8)).to_lower()},
				world.user_club_id, best.id, NewsEvent.IMP_HIGH)
	TransferManager.pay_installments(world)
	# Agentes livres: mantém o mercado vivo, sem inchar
	_maintain_free_agents(world)
	HeartClubs.ensure_all(world) # garotos e livres novos
	TransferManager.balance_squads(world)
	# Nova temporada
	world.season = build_season(world)
	NationalTeamManager.start_season(world)
	YouthManager.build_league(world)
	world.transfer_log = world.transfer_log.filter(func(t): return t.year >= world.year - 1)
	world.offers.clear()
	world.stats.erase("neg")
	var taxes := FinanceManager.season_taxes(world)
	WorldEvents.season_start(world)
	for c: Club in world.clubs:
		c.reset_season_state()
		if taxes.has(c.id):
			c.add_ledger("impostos", -int(taxes[c.id]))
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
	world.reset_indexes()
	# Mercado das férias: os outros clubes fazem a maior parte dos negócios antes da bola rolar.
	MarketAI.offseason(world)
	compute_goals(world)
	SponsorManager.open_preseason(world)
	if world.has_user():
		var goal := goal_of(world, world.user_club_id)
		NewsManager.post(world, "temporada", {"year": world.year, "club": world.user_club().short_name, "goal": String(goal[0]).to_lower()}, world.user_club_id, -1, NewsEvent.IMP_HIGH)
		for cid in world.season.cups:
			if world.season.cups[cid].has_club(world.user_club_id):
				NewsManager.post(world, CupManager.news_cat(cid, "classificado"), {"club": world.user_club().short_name, "cup": world.season.cups[cid].name}, world.user_club_id, -1, NewsEvent.IMP_HIGH)
	return summary


## Fase mais longe alcançada numa copa ("Campeão", "Final", "Semifinal", ..., "Fase de grupos").
static func _stage_reached(cup: Cup, club_id: int) -> String:
	if cup.champion == club_id:
		return "Campeão"
	var best := -1
	for t in cup.ties:
		if int(t["a"]) == club_id or int(t["b"]) == club_id:
			best = maxi(best, int(t["r"]))
	if best < 0:
		return "Fase de grupos" if not cup.groups.is_empty() else "Primeira fase"
	return cup.round_names[best]


static func _update_reputation(c: Club, cfg: Dictionary, pos: int, teams: int, promoted: bool, relegated: bool) -> void:
	var rr: Array = cfg.get("rep", [40, 70])
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
	c.fan_base = maxi(600, int(c.fan_base * fan_f))


static func _maintain_free_agents(world: GameWorld) -> void:
	var per_club := float(DatabaseManager.rules().get("free_agents_per_club", 0.5))
	var target := int(world.clubs.size() * per_club)
	var cap := target * 2
	var free := world.free_agents().duplicate()
	# Remove os mais fracos se o mercado inchar demais: quem sobra sem clube (velhos e fracos primeiro) para.
	if free.size() > cap:
		var y := world.year
		free.sort_custom(func(a, b): return a.ovr_f - maxf(0.0, a.age(y) - 29.0) * 3.0 < b.ovr_f - maxf(0.0, b.age(y) - 29.0) * 3.0)
		for i in free.size() - cap:
			world.remove_player(free[i])
		world.stat_add("retirements", free.size() - cap)
	var used := WorldGenerator.used_names_of(world)
	var have := world.free_agents().size()
	for i in maxi(0, target - have):
		PlayerGenerator.create_free_agent(world, world.rng, WorldGenerator.random_league_level(world.rng), used)


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
