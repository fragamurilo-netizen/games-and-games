extends SceneTree
## Testes automáticos do núcleo do jogo (sem interface).
## Uso: godot --headless --path . --script res://tests/run_tests.gd
## Só alguns: ... run_tests.gd -- --only=calend,mercado (trechos do nome do teste, separados por vírgula)
## Sai com código 1 se algum teste falhar. O teste de fumaça da interface fica em
## tools/screenshot_tour.gd e a simulação longa em tests/season_simulator.gd.

const TEST_SLOT := 99 # fora dos 5 espaços visíveis: nunca toca nos saves do jogador

var failures := 0
var passed := 0
var current := ""
var _season_world: GameWorld = null # mundo com uma temporada inteira jogada (reaproveitado)


func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	_run("geração do mundo padrão", _test_generation)
	_run("mundo aleatório e determinismo", _test_determinism)
	_run("calendários das ligas", _test_fixtures)
	_run("calibração do motor de partidas", _test_engine)
	_run("modo rápido = motor completo (médias)", _test_quick_calibration)
	_run("partida ao vivo = partida instantânea", _test_live_equals_instant)
	_run("mata-mata: prorrogação e pênaltis", _test_knockout)
	_run("troca de formação durante a partida", _test_formation_change)
	_run("temporada completa, copas e Mundial", _test_season_cycle)
	_run("virada de ano: acessos, quedas e vagas", _test_end_season)
	_run("Football Memory: confrontos, recordes e linha do tempo", _test_football_memory)
	_run("ranking de clubes, finanças e eventos do mundo", _test_ranking_economy)
	_run("dívida de longo prazo, cheque especial e refinanciamento", _test_debt)
	_run("avanço até o próximo jogo do usuário", _test_advance)
	_run("save/load (ida e volta, backup e determinismo)", _test_save_load)
	_run("negociações do usuário", _test_transfers)
	_run("diretoria: ultimato, demissão e novo clube", _test_board)
	_run("valores e salários", _test_valuation)
	_run("notícias com dados reais", _test_news)
	_run("eventos com escolhas e promessas", _test_events)
	_run("treino, base e liga sub-20", _test_training_youth)
	_run("empréstimos, parcelas e cláusulas", _test_deals)
	_run("mercado da IA (negociação, rotas reais, empréstimos)", _test_market_ai)
	_run("rostos e personalização", _test_faces)
	_run("trocas, oferecer jogador e contrapropostas", _test_trades)
	_run("patrocínios e uniformes da pré-temporada", _test_sponsors)
	_run("personalidade, lesões graves e troféus", _test_persona_trophies)
	_run("táticas: entrosamento, plano de jogo e filosofias", _test_tactics)
	_run("elenco: papéis, profundidade e rodízio", _test_squad_mgmt)
	_run("pré-temporada e balanço da temporada", _test_preseason)
	_run("copas continentais de 2º e 3º nível", _test_second_cups)
	_run("seleções: eliminatórias, torneios e ranking", _test_national_teams)
	_run("técnicos, comissão, presidente e relações", _test_people)
	_run("conversas e coletiva de imprensa", _test_talks)
	_run("imprensa: palpites, termômetro, rumores e cobrança", _test_press_room)
	_run("demissão no meio da temporada e troca de técnicos", _test_mid_season_firing)
	_run("mods e jogadores personalizados", _test_mods)
	_run("loja: temporada de demonstração e Carreira Completa", _test_store)
	_run("times de coração, treinador e revelados", _test_hearts_manager)
	_run("formação personalizada, instruções e regra de estrangeiros", _test_tactical_freedom)
	_run("raio-x tático: corredores, causas e correção", _test_xray)
	_run("gritos da beira do campo", _test_shouts)
	_run("rivalidade emergente: clássicos que nascem no save", _test_rivalry)
	_run("caixa de entrada do treinador", _test_inbox)
	_run("reputação do treinador aprendida com as decisões", _test_coach_identity)
	_run("DNA dos clubes: identidade, mercado e mudanças", _test_club_dna)
	print("")
	print("%d testes ok, %d falha(s) — %.1f s" % [passed, failures, (Time.get_ticks_msec() - t0) / 1000.0])
	quit(1 if failures > 0 else 0)


func _run(name: String, fn: Callable) -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			var parts := a.substr(7).split(",")
			if not Array(parts).any(func(x): return name.to_lower().contains(String(x).to_lower())):
				return
	current = name
	var before := failures
	var t := Time.get_ticks_msec()
	fn.call()
	if failures == before:
		passed += 1
		print("OK     %s (%d ms)" % [name, Time.get_ticks_msec() - t])
	else:
		print("FALHOU %s" % name)


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		print("   x %s" % msg)


## Impressão digital compacta do mundo (estado que importa para o determinismo).


func _fingerprint(w: GameWorld) -> String:
	var parts: Array = [w.rng.state, w.year, w.season.day if w.season != null else -1, w.next_player_id]
	for c: Club in w.clubs:
		parts.append([c.balance, snappedf(c.reputation, 0.001), c.player_ids.size(), c.league_id])
	var ids := w.players.keys()
	ids.sort()
	for pid in ids:
		var p: Player = w.players[pid]
		parts.append([pid, p.club_id, snappedf(p.ovr_f, 0.01), p.value, p.potential, p.injury_weeks, p.stats[Player.S_GOALS]])
	if w.season != null:
		for id in w.season.league_order:
			var l: League = w.season.leagues[id]
			for cid in l.club_ids:
				parts.append(l.table[cid]["pts"])
		for cid in w.season.cups:
			parts.append(w.season.cups[cid].fixtures.size())
	return var_to_str(parts).md5_text()


func _with_user(w: GameWorld, club_id: int, difficulty: int = GameWorld.DIFF_NORMAL) -> Club:
	w.user_club_id = club_id
	w.manager_name = "Teste"
	w.difficulty = difficulty
	var c := w.user_club()
	FinanceManager.set_budgets(w, c)
	c.sheet = ClubAI.auto_sheet(w, c, "")
	return c


func _club(w: GameWorld, key: String) -> Club:
	return w.club_by_key(key)


# ---------------------------------------------------------------------------

func _test_generation() -> void:
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	var slots := 0
	for id in DatabaseManager.league_ids():
		var cfg := DatabaseManager.league_cfg(id)
		slots += int(cfg["teams"])
		check(w.league(id).club_ids.size() == int(cfg["teams"]), "%s com %d clubes" % [id, w.league(id).club_ids.size()])
	check(w.clubs.size() == slots, "%d clubes para %d vagas" % [w.clubs.size(), slots])
	var keys := {}
	var abbrs := {}
	for c: Club in w.clubs:
		check(not keys.has(c.key), "chave repetida %s" % c.key)
		check(not (c.key.substr(4, 1) == "P" and c.key.substr(5).is_valid_int()), "clube fictício %s (%s): toda liga deve ter só clubes reais" % [c.key, c.league_id])
		keys[c.key] = true
		var ak := c.nation + c.abbr
		check(not abbrs.has(ak), "sigla repetida %s em %s" % [c.abbr, c.nation])
		abbrs[ak] = true
		check(c.id == w.clubs.find(c), "id de %s não bate com a posição" % c.key)
		var n := c.player_ids.size()
		check(n >= 20 and n <= int(DatabaseManager.squad_rules()["max_players"]) - 3, "%s com %d jogadores" % [c.short_name, n])
		var sheet := ClubAI.auto_sheet(w, c, "")
		check(sheet.starters.size() == 11 and not sheet.starters.has(-1), "%s não consegue escalar 11" % c.short_name)
		for pid in c.player_ids:
			var p := w.player(pid)
			check(p != null and p.club_id == c.id, "jogador %d fora do clube %s" % [pid, c.short_name])
		for rid in c.rivals:
			check(w.club(rid).is_rival(c.id), "rivalidade não é mútua: %s" % c.key)
	# ~27 por clube (grandes com 29–32, pequenos com 23–26) + agentes livres
	check(w.players.size() >= w.clubs.size() * 24 and w.players.size() <= w.clubs.size() * 30, "total de jogadores plausível (%d)" % w.players.size())
	var names := {}
	var dups := 0
	var bad_attr := 0
	var bad_pot := 0
	var bad_nat := 0
	for p: Player in w.players.values():
		var full := p.first_name + " " + p.last_name
		if names.has(full):
			dups += 1
		names[full] = true
		for a in p.attrs:
			if a < 1 or a > 100:
				bad_attr += 1
		if p.potential < p.overall:
			bad_pot += 1
		if not DatabaseManager.has_nation(p.nationality):
			bad_nat += 1
	check(dups == 0, "nomes completos repetidos: %d" % dups)
	check(bad_attr == 0, "atributos fora de 1..100: %d" % bad_attr)
	check(bad_pot == 0, "potencial abaixo do overall: %d" % bad_pot)
	check(bad_nat == 0, "nacionalidades desconhecidas: %d" % bad_nat)
	# Os grandes são grandes: gigante inglês bem acima de um clube da Série D.
	var big := _club(w, "ENG_MSK")
	var small: Club = w.clubs_in_league("BRA4")[19]
	check(ClubAI._compute_strength(w, big) > ClubAI._compute_strength(w, small) + 25.0, "escala de níveis entre ligas")
	# Copas da primeira temporada montadas
	check(w.season.cups.has("UCL") and w.season.cups["UCL"].club_ids.size() == 32, "Liga dos Campeões com 32 clubes")
	check(w.season.cups.has("LIB") and w.season.cups["LIB"].club_ids.size() == 32, "Libertadores com 32 clubes")
	_season_world = null


func _test_determinism() -> void:
	var a := WorldGenerator.generate(12345, "aleatorio")
	var b := WorldGenerator.generate(12345, "aleatorio")
	check(_fingerprint(a) == _fingerprint(b), "mesmo seed gera o mesmo mundo")
	for i in 4:
		SeasonManager.play_matchday_instant(a)
		SeasonManager.play_matchday_instant(b)
	check(_fingerprint(a) == _fingerprint(b), "mesmas datas com o mesmo seed dão os mesmos resultados")
	var c2 := WorldGenerator.generate(54321, "aleatorio")
	check(_fingerprint(c2) != _fingerprint(WorldGenerator.generate(12345, "aleatorio")), "seeds diferentes geram mundos diferentes")


func _test_fixtures() -> void:
	var w := WorldGenerator.generate(777, "padrao")
	for id in w.season.league_order:
		var league: League = w.season.leagues[id]
		var cfg := league.cfg()
		var teams := int(cfg["teams"])
		var expect_rounds := (teams - 1) * int(cfg["rr"])
		check(league.rounds.size() == expect_rounds, "%s com %d rodadas (esperado %d)" % [id, league.rounds.size(), expect_rounds])
		var home := {}
		var last_slot := -1
		for r in league.rounds.size():
			var seen := {}
			var slot: int = league.round_slots[r]
			check(slot > last_slot and w.season.is_weekend(slot), "%s: rodada %d em data inválida" % [id, r + 1])
			last_slot = slot
			for f: Fixture in league.rounds[r]:
				check(not seen.has(f.home) and not seen.has(f.away), "%s: clube repetido na rodada %d" % [id, r + 1])
				seen[f.home] = true
				seen[f.away] = true
				home[f.home] = int(home.get(f.home, 0)) + 1
				check(f.slot == slot and f.comp == id, "%s: jogo com data/competição errada" % id)
			check(seen.size() == teams, "%s: rodada %d não tem todos os clubes" % [id, r + 1])
		for cid in league.club_ids:
			var hg := int(home.get(cid, 0))
			check(absi(hg * 2 - expect_rounds) <= int(cfg["rr"]), "%s: %s com %d jogos em casa" % [id, w.club(cid).short_name, hg])


func _test_engine() -> void:
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var n := 0
	var goals := 0
	var hw := 0
	var dr := 0
	var reds := 0
	var ids := DatabaseManager.league_ids()
	for i in 500:
		var cl := w.clubs_in_league(ids[i % ids.size()])
		var a: Club = cl[rng.randi_range(0, cl.size() - 1)]
		var b: Club = cl[rng.randi_range(0, cl.size() - 1)]
		if a == b:
			continue
		var sim := MatchEngine.quick_match(w, a, b, rng.randi())
		n += 1
		goals += sim.score[0] + sim.score[1]
		if sim.score[0] > sim.score[1]:
			hw += 1
		elif sim.score[0] == sim.score[1]:
			dr += 1
		reds += sim.teams[0].reds + sim.teams[1].reds
		check(sim.finished, "partida não terminou")
	var gpm := float(goals) / n
	check(gpm >= 2.3 and gpm <= 3.2, "média de gols %.2f fora de 2,3–3,2" % gpm)
	var hp := 100.0 * hw / n
	check(hp >= 36.0 and hp <= 55.0, "vitórias do mandante %.1f%% fora de 36–55%%" % hp)
	var dp := 100.0 * dr / n
	check(dp >= 17.0 and dp <= 34.0, "empates %.1f%% fora de 17–34%%" % dp)
	check(float(reds) / n < 0.4, "expulsões demais: %.2f por jogo" % (float(reds) / n))
	# Zebra existe, mas é rara: time da Série D em casa contra um grande europeu.
	var weak := w.clubs_in_league("BRA4")
	var strong := w.clubs_in_league("ENG1")
	var wins_weak := 0
	var wins_strong := 0
	for i in 200:
		var sim := MatchEngine.quick_match(w, weak[i % weak.size()], strong[i % strong.size()], rng.randi())
		if sim.score[0] > sim.score[1]:
			wins_weak += 1
		elif sim.score[1] > sim.score[0]:
			wins_strong += 1
	check(wins_weak < 20, "zebras demais: %d vitórias da Série D em 200" % wins_weak)
	check(wins_strong > 150, "o gigante deveria vencer quase sempre (%d de 200)" % wins_strong)


## O modo rápido (resto do mundo) precisa produzir as mesmas médias do minuto a minuto
## (usado nos jogos do usuário), senão o usuário jogaria outro esporte.


func _test_quick_calibration() -> void:
	var w := WorldGenerator.generate(606, "padrao")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var ids := DatabaseManager.league_ids()
	var acc := {true: [0.0, 0.0, 0, 0], false: [0.0, 0.0, 0, 0]}
	for i in 600:
		var cl := w.clubs_in_league(ids[i % ids.size()])
		var a: Club = cl[rng.randi_range(0, cl.size() - 1)]
		var b: Club = cl[rng.randi_range(0, cl.size() - 1)]
		if a == b:
			continue
		for quick in [true, false]:
			var res := MatchEngine.test_match(w, a, b, i * 3 + 1, quick)
			var v: Array = acc[quick]
			v[0] += res["hg"]
			v[1] += res["ag"]
			v[2] += 1
			if res["hg"] > res["ag"]:
				v[3] += 1
	var q: Array = acc[true]
	var f: Array = acc[false]
	var qg: float = (q[0] + q[1]) / q[2]
	var fg: float = (f[0] + f[1]) / f[2]
	check(absf(qg - fg) / fg < 0.12, "gols por jogo: rápido %.2f × completo %.2f" % [qg, fg])
	var qh: float = q[3] * 100.0 / q[2]
	var fh: float = f[3] * 100.0 / f[2]
	check(absf(qh - fh) < 9.0, "vitórias do mandante: rápido %.0f%% × completo %.0f%%" % [qh, fh])


## A partida assistida usa exatamente a mesma simulação da instantânea.


func _test_live_equals_instant() -> void:
	var w := WorldGenerator.generate(4242, "padrao")
	var cl := w.clubs_in_league("ENG2")
	var h: Club = cl[0]
	var a: Club = cl[1]
	for s in 15:
		var hs := ClubAI.prepare_ai_sheet(w, h, a, true)
		var as_ := ClubAI.prepare_ai_sheet(w, a, h, false)
		var ctx := {"derby": false, "importance": 0.3, "attendance": 10000, "competition": "F", "ko": s % 3 == 0, "agg": [0, 0]}
		var s1 := MatchSimulation.new()
		s1.setup(w, h, a, hs, as_, ctx, 1000 + s, true)
		var steps := 0
		while not s1.finished and steps < 600:
			s1.step()
			steps += 1
		var s2 := MatchSimulation.new()
		s2.setup(w, h, a, hs, as_, ctx, 1000 + s, false)
		s2.run_to_end()
		var same := s1.score == s2.score and s1.teams[0].shots == s2.teams[0].shots and s1.teams[1].shots == s2.teams[1].shots
		same = same and _goal_log(s1) == _goal_log(s2) and s1.teams[0].yellows == s2.teams[0].yellows and s1.pen_score == s2.pen_score
		check(same, "seed %d: ao vivo %s × instantâneo %s" % [1000 + s, str(s1.score), str(s2.score)])


func _goal_log(sim: MatchSimulation) -> String:
	var out := ""
	for ev in sim.events:
		if ev["t"] == MatchSimulation.EV_GOAL or ev["t"] == MatchSimulation.EV_OWN_GOAL:
			out += "%d:%d:%d;" % [ev["m"], ev["s"], ev["p"]]
	return out


## Mudar o desenho no meio do jogo mantém os mesmos 11 em campo, o goleiro no gol e não gasta troca.
func _test_formation_change() -> void:
	var w := WorldGenerator.generate(4242, "padrao")
	var cl := w.clubs_in_league("ENG2")
	var h: Club = cl[2]
	var a: Club = cl[3]
	var hs := ClubAI.prepare_ai_sheet(w, h, a, true)
	var as_ := ClubAI.prepare_ai_sheet(w, a, h, false)
	var ctx := {"derby": false, "importance": 0.3, "attendance": 10000, "competition": "F"}
	var sim := MatchSimulation.new()
	sim.setup(w, h, a, hs, as_, ctx, 77, true)
	while sim.minute < 30:
		sim.step()
	var t: MatchTeam = sim.teams[0]
	var before: Array = []
	for mp: MatchPlayer in t.slots:
		if mp != null:
			before.append(mp.p.id)
	var gk := t.goalkeeper()
	var target := "3-4-3" if t.formation_name != "3-4-3" else "4-4-2"
	check(sim.set_formation(0, target), "troca de formação recusada")
	check(t.formation_name == target, "formação não mudou")
	check(t.goalkeeper() == gk, "goleiro saiu do gol")
	check(t.subs_used == 0, "troca de formação gastou substituição")
	var after: Array = []
	for i in t.slots.size():
		var mp: MatchPlayer = t.slots[i]
		if mp != null:
			after.append(mp.p.id)
			check(mp.slot == i and mp.pos == int(t.formation["slots"][i]["pos"]), "vaga desencontrada: %s" % mp.p.display_name())
	before.sort()
	after.sort()
	check(before == after, "jogadores em campo mudaram")
	check(not sim.set_formation(0, target), "mesma formação deveria ser ignorada")
	sim.run_to_end()
	check(sim.finished and not sim.pressure.is_empty(), "partida não terminou ou sem gráfico de pressão")


## Jogo que decide confronto nunca termina empatado no agregado.


func _test_knockout() -> void:
	var w := WorldGenerator.generate(1313, "padrao")
	var cl := w.clubs_in_league("ESP1")
	var ets := 0
	var pens := 0
	for s in 60:
		var h: Club = cl[s % cl.size()]
		var a: Club = cl[(s + 7) % cl.size()]
		var agg: Array = [s % 3, (s + 1) % 3]
		var ctx := {"derby": false, "importance": 0.8, "attendance": 30000, "competition": "UCL", "ko": true, "agg": agg}
		var hs := ClubAI.prepare_ai_sheet(w, h, a, true)
		var as_ := ClubAI.prepare_ai_sheet(w, a, h, false)
		var sim := MatchSimulation.new()
		sim.setup(w, h, a, hs, as_, ctx, 500 + s, false)
		sim.run_to_end()
		check(sim.decided_winner() >= 0, "mata-mata sem vencedor (seed %d)" % (500 + s))
		if sim.half >= 3:
			ets += 1
		if sim.pen_taken[0] > 0:
			pens += 1
		var q := QuickMatch.play(w, h, a, hs, as_, ctx, 900 + s)
		var tot_h: int = int(q["hg"]) + int(agg[0])
		var tot_a: int = int(q["ag"]) + int(agg[1])
		var p: Array = q["pens"]
		check(tot_h != tot_a or (p.size() == 2 and p[0] != p[1]), "modo rápido: mata-mata sem vencedor (%s)" % str(q["pens"]))
	check(ets > 0 and pens > 0, "prorrogação (%d) e pênaltis (%d) deveriam acontecer" % [ets, pens])


var _cup_champs := {}


func _season(w: GameWorld) -> void:
	var guard := 0
	while not w.season.finished and guard < 120:
		SeasonManager.play_matchday_instant(w)
		guard += 1


func _test_season_cycle() -> void:
	var w := WorldGenerator.generate(777, "padrao")
	_with_user(w, w.clubs_in_league("BRA1")[3].id)
	var titles_before := {}
	for c: Club in w.clubs:
		titles_before[c.id] = c.titles.duplicate()
	_season(w)
	_season_world = w
	check(w.season.finished and w.season.day == w.season.calendar.size(), "temporada não terminou (%d)" % w.season.day)
	for id in w.season.league_order:
		var league: League = w.season.leagues[id]
		var pts := 0
		var expect := 0
		for r in league.rounds:
			for f: Fixture in r:
				check(f.played, "%s: jogo não disputado" % id)
				if f.stage == Fixture.STAGE_LEAGUE:
					expect += 2 if f.hg == f.ag else 3
		for cid in league.club_ids:
			pts += int(league.table[cid]["pts"])
		if not bool(LeagueFormat.cfg(league).get("halve", false)): # pontos pela metade no split
			check(pts == expect, "%s: pontos na tabela (%d) não batem com os jogos (%d)" % [id, pts, expect])
	# Estatísticas detalhadas com médias reais por time e por jogo (Premier League)
	var eng: League = w.season.leagues["ENG1"]
	var team_games := 0
	for r in eng.rounds:
		team_games += r.size() * 2
	var tot := {"sh": 0, "so": 0, "tk": 0, "pp": 0, "apps": 0, "xg": 0, "g": 0}
	for cid in eng.club_ids:
		for pid in w.club(cid).player_ids:
			var q: Player = w.player(pid)
			if q == null:
				continue
			tot["sh"] += q.stats[Player.S_SHOTS]
			tot["so"] += q.stats[Player.S_SHOTS_ON]
			tot["tk"] += q.stats[Player.S_TACKLES]
			tot["pp"] += q.stats[Player.S_PASS_PCT]
			tot["apps"] += q.stats[Player.S_APPS]
			tot["xg"] += q.stats[Player.S_XG]
			tot["g"] += q.stats[Player.S_GOALS]
	var shots_pg := float(tot["sh"]) / team_games
	var on_pg := float(tot["so"]) / team_games
	check(shots_pg > 9.5 and shots_pg < 16.0, "finalizações por jogo irreais: %.1f" % shots_pg)
	check(on_pg > 3.0 and on_pg < 6.0, "chutes no alvo por jogo irreais: %.1f" % on_pg)
	check(float(tot["tk"]) / team_games > 10.0, "desarmes por jogo irreais")
	var ppct := float(tot["pp"]) / maxf(1.0, tot["apps"])
	check(ppct > 70.0 and ppct < 88.0, "passes certos irreais: %.0f%%" % ppct)
	check(absf(tot["xg"] / 100.0 - float(tot["g"])) / maxf(1.0, float(tot["g"])) < 0.3, "xG longe dos gols (%.0f × %d)" % [tot["xg"] / 100.0, tot["g"]])
	# Formatos reais: split na Escócia (6 + 6, grupo de cima à frente) e playoffs no México e na MLS
	var sco: League = w.season.leagues["SCO1"]
	check(sco.phase_groups.size() == 2 and Array(sco.phase_groups[0]).size() == 6, "Escócia sem o split 6 + 6")
	if sco.phase_groups.size() == 2:
		var order := CompetitionManager.sorted_ids(sco)
		for cid in sco.phase_groups[0]:
			check(order.find(cid) < 6, "clube do grupo de cima terminou abaixo do 6º na Escócia")
		check(sco.rounds.size() == 38, "Escócia com %d rodadas (38 na vida real)" % sco.rounds.size())
	for lid in ["MEX1", "USA1", "AUS1"]:
		var pl: League = w.season.leagues[lid]
		var champ := int(pl.po.get("champ", -1))
		check(champ >= 0 and Array(pl.po.get("seeds", [])).has(champ), "%s sem campeão dos playoffs" % lid)
		check(LeagueFormat.champion(pl, CompetitionManager.sorted_ids(pl)) == champ or champ < 0, "%s: campeão da temporada não é o dos playoffs" % lid)
	# Copas continentais
	for cid in ["UCL", "LIB", "AFC"]:
		var cup: Cup = w.season.cups[cid]
		check(cup.finished and cup.champion >= 0, "%s sem campeão" % cid)
		var same_nation := 0
		for g in cup.groups:
			var seen := {}
			for c in g["clubs"]:
				var n := w.club(c).nation
				if seen.has(n):
					same_nation += 1
				seen[n] = true
		check(same_nation <= 2, "%s: %d grupos com clubes do mesmo país" % [cid, same_nation])
		for f in cup.fixtures:
			check(f.played, "%s: jogo não disputado" % cid)
		var last := cup.ties_of_round(cup.round_names.size() - 1)
		check(last.size() == 1 and int(last[0]["w"]) == cup.champion, "%s: final inconsistente" % cid)
		check(w.club(cup.champion).title_count("C:" + cid) == int(titles_before[cup.champion].get("C:" + cid, 0)) + 1, "%s: título não registrado" % cid)
	# Estaduais: todos os 80 clubes brasileiros em exatamente um, com campeão e sem choque de datas.
	var in_state := {}
	for cid in CupManager.state_ids():
		check(w.season.cups.has(cid), "%s não foi montado" % cid)
		if not w.season.cups.has(cid):
			continue
		var st: Cup = w.season.cups[cid]
		check(st.finished and st.champion >= 0, "%s sem campeão" % cid)
		check(w.club(st.champion).title_count("S:" + cid) == int(titles_before[st.champion].get("S:" + cid, 0)) + 1, "%s: título não registrado" % cid)
		for c in st.club_ids:
			check(not in_state.has(c), "%s em dois estaduais" % w.club(c).short_name)
			in_state[c] = true
		for f in st.fixtures:
			check(f.played and w.season.slot_type(f.slot).begins_with("E"), "%s: jogo fora das datas do estadual" % cid)
	# Formatos reais: Paulistão com 16 (o 17º paulista joga a Série A2), Carioca com 8 na Taça Guanabara...
	check(in_state.size() >= 75, "%d clubes brasileiros nos estaduais" % in_state.size())
	check(w.season.cups.has("SPE") and w.season.cups["SPE"].club_ids.size() == 16 and w.season.cups["SPE"].groups.size() == 4, "Paulistão fora do formato (16 clubes em 4 grupos)")
	check(w.season.cups.has("VER") and w.season.cups["VER"].groups.is_empty(), "Copa Verde deveria ser só mata-mata")
	if w.season.cups.has("SPE"):
		check(w.season.cups["SPE"].ties_of_round(0).size() == 4, "Paulistão sem quartas de final")
	check(w.season.cups.has("CWC"), "Mundial de Clubes não foi montado")
	if w.season.cups.has("CWC"):
		var cwc: Cup = w.season.cups["CWC"]
		check(cwc.club_ids.size() == 8 and cwc.finished and cwc.champion >= 0, "Mundial incompleto")
		check(cwc.club_ids.has(w.season.cups["UCL"].champion) and cwc.club_ids.has(w.season.cups["LIB"].champion), "campeões continentais fora do Mundial")
		check(w.club(cwc.champion).title_count("W:CWC") == int(titles_before[cwc.champion].get("W:CWC", 0)) + 1, "título mundial não registrado")
	# Copas nacionais, copas da liga e supercopas
	var clash := 0
	for slot in w.season.calendar.size():
		var seen := {}
		for f in w.season.fixtures_at(slot):
			for cl in [f.home, f.away]:
				if seen.has(cl):
					clash += 1
				seen[cl] = true
	check(clash == 0, "%d clubes com dois jogos na mesma data" % clash)
	for cid in ["FAC", "CDB", "CDR", "CIT", "DFB", "CDF", "EFL", "USO", "EMP", "CSH", "SCB", "USC", "REC"]:
		check(w.season.cups.has(cid), "%s não foi montada" % cid)
		if not w.season.cups.has(cid):
			continue
		var dc: Cup = w.season.cups[cid]
		check(dc.finished and dc.champion >= 0, "%s sem campeão" % cid)
		for f in dc.fixtures:
			check(f.played, "%s: jogo não disputado" % cid)
		check(w.club(dc.champion).title_count(CupManager.title_key(cid)) == int(titles_before[dc.champion].get(CupManager.title_key(cid), 0)) + 1, "%s: título não registrado" % cid)
	var cdb: Cup = w.season.cups["CDB"]
	check(cdb.club_ids.size() == 80 and cdb.plan == ["pre", "r64", "r32", "r16", "qf", "sf", "f"] and cdb.byes.size() == 48, "Copa do Brasil com fases erradas: %s" % [cdb.plan])
	check(Array(cdb.plan_slots[6]).size() == 2 and Array(cdb.plan_slots[0]).size() == 1, "Copa do Brasil: final deveria ser em ida e volta")
	var fac: Cup = w.season.cups["FAC"]
	check(fac.club_ids.size() == 40 and fac.plan[0] == "pre" and fac.plan.size() == 6, "FA Cup com fases erradas: %s" % [fac.plan])
	for f in fac.fixtures:
		check(w.season.slot_type(f.slot).begins_with("N"), "FA Cup fora das datas de copa nacional")
		if f.round == fac.plan.size() - 1:
			check(f.neutral, "final da FA Cup deveria ser em campo neutro")
	for f in w.season.cups["EFL"].fixtures:
		check(w.season.slot_type(f.slot).begins_with("E"), "Copa da Liga inglesa fora das datas E")
	for f in w.season.cups["CSH"].fixtures:
		check(w.season.slot_type(f.slot) == "U1", "Community Shield fora da data das supercopas")
	var nations_with_cup := {}
	for cid in CupManager.domestic_ids():
		if w.season.cups.has(cid):
			nations_with_cup[String(CupManager.cfg(cid).get("nation", ""))] = true
	for n in DatabaseManager.league_nations():
		if n != "MEX":
			check(nations_with_cup.has(n), "%s sem copa nacional" % n)
	_cup_champs = {"CDB": cdb.champion, "FAC": fac.champion}
	# Estatísticas de copa separadas das de liga
	var top := CupManager.scorers(w, "UCL", 1)
	check(not top.is_empty() and top[0].cup_stats["UCL"][Player.C_GOALS] > 0, "artilharia da Liga dos Campeões vazia")


func _test_football_memory() -> void:
	var w := _season_world
	if w == null:
		check(false, "sem mundo da temporada")
		return
	var m := FootballMemory.data(w)
	check(m["h2h"].size() > 3000, "poucos confrontos registrados (%d)" % m["h2h"].size())
	# Retrospecto simétrico entre dois clubes da mesma liga (turno e returno)
	var bra: Array = w.clubs_in_league("BRA1")
	var a: Club = bra[0]
	var b: Club = bra[1]
	var ab := FootballMemory.head_to_head(w, a.id, b.id)
	var ba := FootballMemory.head_to_head(w, b.id, a.id)
	check(int(ab["games"]) >= 2 and int(ab["games"]) == int(ba["games"]), "retrospecto incompleto: %d jogos" % int(ab["games"]))
	check(int(ab["wins"]) == int(ba["losses"]) and int(ab["gf"]) == int(ba["ga"]) and int(ab["draws"]) == int(ba["draws"]), "retrospecto assimétrico")
	check(int(ab["wins"]) + int(ab["draws"]) + int(ab["losses"]) == int(ab["games"]), "V+E+D diferente do total de jogos")
	check((ab["recent"] as Array).size() == mini(FootballMemory.LAST_N, int(ab["games"])), "últimos encontros não guardados")
	check(not FootballMemory.opponents_of(w, a.id).is_empty(), "sem adversários para o clube")
	# Finais, títulos decididos, zebras e mercado
	check((m["fin"] as Array).size() >= 20, "poucas finais registradas (%d)" % (m["fin"] as Array).size())
	check((m["tit"] as Array).size() >= 10, "poucos títulos decididos (%d)" % (m["tit"] as Array).size())
	var ups_year := 0
	for u in m["ups"]:
		if int(u[0]) == w.year - 1:
			ups_year += 1
	check(ups_year <= FootballMemory.UPS_PER_YEAR, "zebras do ano não foram podadas")
	var fees: Array = m["wr"]["fee"]
	check(not fees.is_empty(), "sem transferências no recorde mundial")
	for i in range(1, fees.size()):
		check(int(fees[i - 1][0]) >= int(fees[i][0]), "recorde de transferências fora de ordem")
	# Braçadeira e linha do tempo
	check(m["cap"].size() >= 300, "poucos capitães registrados (%d)" % m["cap"].size())
	var with_moves := 0
	for p: Player in w.players.values():
		if p.spells.size() < 2 or p.career_apps < 50:
			continue
		var tl := FootballMemory.timeline(w, p)
		var ev: Array = tl["events"]
		check(not ev.is_empty() and String(ev[0]["k"]) == "debut", "linha do tempo sem estreia")
		for i in range(1, ev.size()):
			check(int(ev[i - 1]["y"]) <= int(ev[i]["y"]), "linha do tempo fora de ordem")
		with_moves += 1
		if with_moves >= 50:
			break
	check(with_moves >= 50, "poucos jogadores com carreira para a linha do tempo")
	# Técnicos: a galeria do clube registra quem saiu
	var club: Club = w.clubs[5]
	var old := People.coach_of(w, club.id)
	People.replace_coach(w, club, "resultados")
	var gallery: Array = FootballMemory.club_records(w, club.id)["coaches"]
	check(not gallery.is_empty() and String(gallery[-1][0]) == String(old["n"]), "técnico que saiu não entrou na galeria")
	# Ídolo aposentado que vira técnico enfrenta o ex-clube
	var legend := {}
	for r in w.retired:
		if int(r.get("apps", 0)) >= 150 and not Array(r.get("spells", [])).is_empty():
			legend = r
			break
	if not legend.is_empty():
		var home_id := int(legend["spells"][0]["c"])
		var coach := People.coach_of(w, club.id)
		coach["pid"] = int(legend["id"])
		var f := Fixture.new()
		f.home = club.id
		f.away = home_id
		f.comp = club.league_id
		f.played = true
		f.hg = 1
		f.ag = 0
		if club.id != home_id and FootballMemory.coach_bond(w, coach, home_id) >= 40:
			FootballMemory.on_match(w, f)
			var got := FootballMemory.moments(w, int(legend["id"])).any(func(e): return String(e[1]) == "face")
			check(got, "reencontro do ídolo com o ex-clube não registrado")
		coach.erase("pid")
	# Save: a memória vai e volta
	var back := GameWorld.from_dict(w.to_dict())
	check(FootballMemory.data(back)["h2h"].size() == m["h2h"].size(), "memória perdida no save")
	var ab2 := FootballMemory.head_to_head(back, a.id, b.id)
	check(int(ab2["games"]) == int(ab["games"]) and int(ab2["gf"]) == int(ab["gf"]), "retrospecto mudou depois do save")


func _test_end_season() -> void:
	var w := _season_world
	if w == null:
		check(false, "sem mundo da temporada")
		return
	var year := w.year
	var old_league := {}
	for c: Club in w.clubs:
		old_league[c.id] = c.league_id
	# Seleção da rodada e do mês foram montadas durante a temporada
	check(not Dictionary(w.stats.get("totw", {})).is_empty() and Array(w.stats["totw"]["ids"]).size() == 11, "seleção da rodada não montada")
	check(Array(w.stats.get("totm_list", [])).size() >= 5, "poucas seleções do mês (%d)" % Array(w.stats.get("totm_list", [])).size())
	var summary := SeasonManager.end_season(w)
	# Prêmios, Bola de Ouro, arquivo da temporada
	var aw: Dictionary = summary["awards"]
	for k in ["mvp", "scorer", "assist", "young", "gk", "def", "mid", "att"]:
		check(aw.has(k), "prêmio %s ausente na liga do usuário" % k)
	check((summary["team"] as Array).size() == 11, "seleção do campeonato incompleta")
	var bo: Array = summary["ballon_rank"]
	check(bo.size() == 10 and int(bo[0]["pts"]) >= int(bo[1]["pts"]) and int(bo[0]["votes"]) == AwardVoting.jury_nations().size(), "votação da Bola de Ouro inválida")
	check(int(bo[0]["pts"]) <= int(bo[0]["votes"]) * 15 and int(bo[0]["first"]) > 0, "pontos da Bola de Ouro fora da escala")
	check(int(Dictionary(w.stats.get("aw_nom", {})).get("y", 0)) == year and Array(w.stats["aw_nom"]["bo"]).size() == AwardVoting.BALLON_NOMINEES, "indicados não anunciados na reta final")
	check(not Dictionary(summary["coach"]).is_empty() and not Dictionary(summary["gk_world"]).is_empty(), "treinador da temporada / melhor goleiro ausentes")
	check(Array(summary["world_xi"]).size() == 11, "seleção do ano incompleta")
	check(String(aw["mvp"].get("v", "")).find("votos") >= 0 and Array(aw["mvp"].get("fin", [])).size() >= 2, "craque sem votação dos técnicos")
	check(not Dictionary(summary["boot"]).is_empty() and not Dictionary(summary["world_young"]).is_empty(), "Chuteira de Ouro / revelação mundial ausentes")
	var hist: Dictionary = w.history[w.history.size() - 1]
	var arch: Dictionary = hist.get("arch", {})
	check(arch.has("BRA1") and (arch["BRA1"]["tb"] as Array).size() == 20 and (arch["BRA1"]["sc"] as Array).size() == 10, "arquivo da temporada incompleto")
	check(not (hist.get("sq", []) as Array).is_empty() and not (hist.get("months", []) as Array).is_empty(), "elenco/meses não arquivados")
	# Registro dos prêmios para a enciclopédia
	var bw := AwardVoting.winners(w, "ballon")
	check(bw.size() >= 1 and int(bw.back()["y"]) == year and int(bw.back()["id"]) == int(bo[0]["id"]), "Bola de Ouro fora do registro")
	check(AwardVoting.records(w, {"k": "coach", "y": year}).size() >= 20, "treinadores da temporada fora do registro")
	check(AwardVoting.records(w, {"id": int(aw["mvp"]["id"]), "k": "mvp", "pos": 1}).size() >= 1, "consulta por jogador falhou")
	check(AwardVoting.records(w, {"k": "ballon", "y": year}).size() == 10, "ranking da Bola de Ouro fora do registro")
	check(w.stats.get("totw", {}).is_empty(), "seleção da rodada não foi limpa na virada")
	var mvp := w.player(int(aw["mvp"]["id"]))
	check(mvp == null or mvp.awards_in(year).has("mvp"), "craque sem o prêmio no currículo")
	var with_hist := 0
	for p: Player in w.players.values():
		if not p.history.is_empty() and p.history[p.history.size() - 1].has("o"):
			with_hist += 1
		check(p.ovr_start == p.overall, "overall inicial da temporada não registrado")
	check(with_hist > 1000, "histórico anual sem overall (%d)" % with_hist)
	check(w.year == year + 1, "ano não avançou")
	check(not w.season.finished and w.season.day == 0, "nova temporada não foi montada")
	for id in DatabaseManager.league_ids():
		check(w.league(id).club_ids.size() == int(DatabaseManager.league_cfg(id)["teams"]), "%s ficou com %d clubes" % [id, w.league(id).club_ids.size()])
	for d in summary["leagues"]:
		var up := int(DatabaseManager.league_cfg(d["id"]).get("up", 0))
		var down := int(DatabaseManager.league_cfg(d["id"]).get("down", 0))
		check((d["promoted"] as Array).size() == up, "%s: %d acessos (esperado %d)" % [d["id"], (d["promoted"] as Array).size(), up])
		check((d["relegated"] as Array).size() == down, "%s: %d quedas (esperado %d)" % [d["id"], (d["relegated"] as Array).size(), down])
		for cid in d["promoted"]:
			var c := w.club(cid)
			check(c.tier == int(DatabaseManager.league_cfg(old_league[cid])["tier"]) - 1 and c.nation == d["nation"], "%s não subiu" % c.short_name)
		for cid in d["relegated"]:
			var c := w.club(cid)
			check(c.tier == int(DatabaseManager.league_cfg(old_league[cid])["tier"]) + 1, "%s não caiu" % c.short_name)
	# Classificados: campeão da Série A está na Libertadores do ano seguinte.
	var bra: Dictionary = {}
	for d in summary["leagues"]:
		if d["id"] == "BRA1":
			bra = d
	check(w.season.cups["LIB"].has_club(int(bra["champion"])), "campeão brasileiro fora da Libertadores")
	check(w.season.cups["UCL"].club_ids.size() == 32 and w.season.cups["LIB"].club_ids.size() == 32, "copas do ano seguinte incompletas")
	# Campeão da Copa do Brasil garante a Libertadores; supercopa com o campeão da liga e o da copa.
	check(w.season.cups["LIB"].has_club(int(_cup_champs.get("CDB", -1))), "campeão da Copa do Brasil fora da Libertadores")
	check(w.season.cups.has("SCB") and w.season.cups["SCB"].has_club(int(bra["champion"])), "Supercopa do Brasil sem o campeão brasileiro")
	if int(_cup_champs.get("CDB", -1)) != int(bra["champion"]):
		check(w.season.cups["SCB"].has_club(int(_cup_champs["CDB"])), "Supercopa do Brasil sem o campeão da copa")
	var fac_champ := int(_cup_champs.get("FAC", -1))
	var in_eu := false
	for eu in ["UCL", "UEL"]:
		if w.season.cups[eu].has_club(fac_champ):
			in_eu = true
	check(in_eu, "campeão da FA Cup sem vaga europeia")
	check(not summary["user"].is_empty(), "resumo do usuário vazio")
	var rv: Dictionary = summary.get("review", {})
	check(not rv.is_empty() and String(rv.get("grade", "")) != "", "balanço da temporada sem nota")
	check(int(rv.get("record", {}).get("pl", 0)) > 0, "balanço sem a campanha na liga")
	check((rv.get("achievements", []) as Array).has("primeira"), "conquista da primeira temporada não desbloqueada")
	check(float(w.stats.get("youth_generated", 0.0)) > 600, "base não gerou jovens suficientes")
	var rules := DatabaseManager.squad_rules()
	var owner := {}
	for c: Club in w.clubs:
		# A IA completa os elencos na virada (TransferManager.balance_squads); o clube do usuário não é
		# mexido e pode ficar abaixo do mínimo (o painel avisa "Elenco curto"), mas sempre dá para escalar.
		var min_n := 11 if w.is_user_club(c.id) else int(rules["min_players"])
		check(c.player_ids.size() >= min_n and c.player_ids.size() <= int(rules["max_players"]), "%s com %d jogadores" % [c.short_name, c.player_ids.size()])
		for pid in c.player_ids:
			check(not owner.has(pid), "jogador %d em dois clubes" % pid)
			owner[pid] = c.id
			var p := w.player(pid)
			check(p != null and p.club_id == c.id, "vínculo inconsistente do jogador %d" % pid)


func _test_debt() -> void:
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	# Gigantes endividados começam devendo mais de um ano de receita, mas com caixa para operar;
	# a maioria dos clubes deve pouco, e os de dono rico não devem nada.
	var giants := 0
	var small_debt := 0
	var total := 0
	for c: Club in w.clubs:
		check(c.balance >= 0, "%s começou com caixa negativo" % c.name)
		var dr := FinanceManager.debt_ratio(c)
		if c.archetype == "gigante_endividado":
			giants += 1
			check(dr >= 0.95, "%s: gigante endividado com dívida de %.2f" % [c.name, dr])
		elif c.archetype == "rico_promovido":
			check(c.debt == 0, "%s: clube de dono rico começou devendo" % c.name)
		if dr < 0.5:
			small_debt += 1
		total += 1
	check(giants >= 5 and small_debt > total * 0.7, "distribuição de dívidas estranha (%d gigantes, %d/%d com pouca dívida)" % [giants, small_debt, total])
	# Brasileirão com receita na faixa dos grandes de Portugal/Turquia (antes: um oitavo do Real Madrid)
	var fla := w.club_by_key("BRA_RNC")
	var rm := w.club_by_key("ESP_MBL")
	if fla != null and rm != null:
		var ratio := float(FinanceManager.expected_revenue(fla)) / float(FinanceManager.expected_revenue(rm))
		check(ratio > 0.16 and ratio < 0.35, "receita do Flamengo fora da escala real (%.2f do Real Madrid)" % ratio)
	# Semana a semana: juros e amortização saem do caixa e a dívida encolhe
	var c: Club = w.clubs_in_league("ESP1")[2]
	c.debt = FinanceManager.expected_revenue(c)
	c.balance = 50_000_000
	c.ledger = {}
	var d0 := c.debt
	var b0 := c.balance
	FinanceManager.process_week(w, c)
	check(c.debt < d0 and int(c.ledger.get("amortizacao", 0)) < 0 and int(c.ledger.get("juros", 0)) < 0, "dívida não cobrou juros nem amortização")
	check(c.balance < b0, "parcela da dívida não saiu do caixa")
	# Dívida pesada com caixa positivo: folha contida e metade da verba de contratações
	c.debt = 0
	FinanceManager.set_budgets(w, c)
	var wb0 := c.wage_budget
	var tb0 := c.transfer_budget
	c.debt = int(FinanceManager.expected_revenue(c) * 1.4)
	FinanceManager.set_budgets(w, c)
	check(c.wage_budget < wb0 and c.transfer_budget < tb0, "dívida grande não aperta o orçamento (%d/%d, %d/%d)" % [c.wage_budget, wb0, c.transfer_budget, tb0])
	check(FinanceManager.in_trouble(c) and FinanceManager.health_label(w, c) != "Saudável", "dívida grande não aparece na saúde financeira")
	# Virada do ano: o rombo do caixa vira empréstimo, até o limite dos bancos
	var r: Club = w.clubs_in_league("ITA1")[5]
	r.debt = 0
	r.balance = -10_000_000
	r.ledger = {}
	var lent := FinanceManager.refinance(w, r)
	check(lent == 10_000_000 and r.balance == 0 and r.debt == 10_000_000 and int(r.ledger.get("emprestimo", 0)) == lent, "refinanciamento do rombo falhou")
	var rev := FinanceManager.expected_revenue(r)
	r.debt = int(rev * 2.0)
	r.balance = -5_000_000
	check(FinanceManager.refinance(w, r) == 0 and r.balance < 0, "banco emprestou além do limite")
	# Empréstimo e amortização não são lucro nem prejuízo
	r.ledger = {"emprestimo": 100_000_000, "amortizacao": -5_000_000, "tv": 1_000_000}
	var taxes := FinanceManager.season_taxes(w)
	check(int(taxes.get(r.id, 0)) == int(1_000_000 * FinanceManager.PROFIT_TAX), "empréstimo entrou no imposto (%d)" % int(taxes.get(r.id, 0)))
	# Comprador quita a dívida; dono que sai deixa dívida de longo prazo
	var t: Club = w.clubs_in_league("FRA1")[6]
	t.debt = 30_000_000
	WorldEvents.takeover(w, t, "Grupo Teste")
	check(t.debt == 0 and t.balance > 0, "novo dono não quitou a dívida")
	# Recuperação judicial corta parte da dívida e zera o rombo do caixa
	var j: Club = w.clubs_in_league("TUR1")[3]
	j.debt = int(FinanceManager.expected_revenue(j) * 2.5)
	j.balance = -3_000_000
	var before := j.debt + 3_000_000
	WorldEvents._judicial_recovery(w, j, float(FinanceManager.expected_revenue(j)))
	check(j.balance >= 0 and j.debt < before * 0.6, "recuperação judicial não renegociou a dívida")
	# Save guarda a dívida
	var w2 := GameWorld.from_dict(JSON.parse_string(JSON.stringify(w.to_dict())))
	check(w2.club(j.id).debt == j.debt, "save perdeu a dívida")


func _test_ranking_economy() -> void:
	# Ranking: depois da virada, todo clube arquivou a temporada e tem posição
	var w := _season_world
	if w == null:
		check(false, "sem mundo da temporada")
		return
	var table := ClubRanking.table(w)
	check(table.size() == w.clubs.size(), "ranking sem todos os clubes")
	for i in table.size() - 1:
		check(float(table[i]["pts"]) >= float(table[i + 1]["pts"]), "ranking fora de ordem")
		if float(table[i]["pts"]) < float(table[i + 1]["pts"]):
			break
	var top := w.club(int(table[0]["id"]))
	check(top.tier == 1 and int(DatabaseManager.nation(top.nation).get("coef", 0)) >= 80, "líder do ranking improvável: %s" % top.short_name)
	var positions := {}
	for c: Club in w.clubs:
		check(c.rank_hist.size() == 1 and c.rank_prev > 0, "%s sem temporada arquivada no ranking" % c.short_name)
		positions[c.rank_prev] = true
	check(positions.size() == w.clubs.size(), "posições repetidas no ranking")
	var bra := ClubRanking.table(w, "N:BRA")
	check(not bra.is_empty() and bra.all(func(e): return w.club(int(e["id"])).nation == "BRA"), "filtro por país do ranking")
	var back := Club.from_dict(top.to_dict())
	check(back.rank_hist == top.rank_hist and back.rank_prev == top.rank_prev, "ranking não sobrevive ao save")
	# TV: a divisão por mérito e audiência mantém a média da liga
	var cw := _career_world()
	for lid in ["ENG1", "BRA1", "BRA3"]:
		var sum := 0.0
		var clubs := cw.clubs_in_league(lid)
		for c: Club in clubs:
			sum += FinanceManager.tv_factor(c)
		check(absf(sum / clubs.size() - 1.0) < 0.15, "%s: cota média de TV %.2f" % [lid, sum / clubs.size()])
	# Loja rende mais com a torcida feliz
	var u := cw.user_club()
	u.fan_mood = 90.0
	var happy := FinanceManager.merch_mood(u)
	u.fan_mood = 20.0
	check(FinanceManager.merch_mood(u) < happy, "loja ignora o humor da torcida")
	# Clube endividado: orçamento de contratações zerado e folha mais curta
	var debtor: Club = cw.clubs_in_league("ENG1")[4]
	FinanceManager.set_budgets(cw, debtor)
	var healthy_wb := debtor.wage_budget
	debtor.balance = -FinanceManager.expected_revenue(debtor)
	FinanceManager.set_budgets(cw, debtor)
	check(debtor.transfer_budget == 0 and debtor.wage_budget < healthy_wb, "dívida não aperta o orçamento")
	check(FinanceManager.projected_balance(cw, u) != 0, "projeção de caixa vazia")
	# Compra do clube: dívida quitada, dono registrado, perfil de novo rico
	var paid := WorldEvents.takeover(cw, debtor, "Grupo Teste")
	check(paid > 0 and debtor.balance > 0, "compra não quitou a dívida")
	check(debtor.archetype == "rico_promovido" and String(WorldEvents.owner_of(cw, debtor.id).get("who", "")) == "Grupo Teste", "novo dono não registrado")
	check(not WorldEvents._can_be_bought(cw, debtor), "clube recém-comprado já pode ser vendido de novo")
	# Proposta de compra do clube do usuário (dilema): apoiar → vendido
	var ev := {"id": 900, "k": "takeover", "p": -1, "p2": -1, "d": {"who": "Fundo Teste", "money": 1000000}}
	cw.events.append(ev)
	var bal := u.balance
	EventManager.resolve(cw, ev, 0)
	check(u.balance > bal and not WorldEvents.owner_of(cw, u.id).is_empty(), "venda do clube do usuário não aconteceu")
	# Virada: contratos de TV renegociados dentro dos limites e imposto sobre lucro
	for i in FinanceManager.TV_DEAL_YEARS:
		cw.year += 1
		FinanceManager.renegotiate_tv(cw)
	var deals: Dictionary = cw.stats.get("tv_deals", {})
	check(deals.size() == DatabaseManager.league_ids().size(), "nem toda liga renegociou a TV em %d anos" % FinanceManager.TV_DEAL_YEARS)
	for id in deals:
		check(float(deals[id]) >= FinanceManager.TV_DEAL_RANGE[0] and float(deals[id]) <= FinanceManager.TV_DEAL_RANGE[1], "contrato de TV fora dos limites")
	u.ledger = {"bilheteria": 1000000, "salarios": -400000}
	check(int(FinanceManager.season_taxes(cw).get(u.id, 0)) == int(600000 * FinanceManager.PROFIT_TAX), "imposto sobre lucro errado")
	# Semanas do mundo rodam sem quebrar
	for i in 200:
		WorldEvents.weekly(cw)
	WorldEvents.season_start(cw)


## Depois do jogo do usuário, o mundo anda sozinho até o próximo compromisso dele — sem pular nenhum.


func _test_advance() -> void:
	var w := WorldGenerator.generate(2468, "padrao")
	var user := _with_user(w, w.clubs_in_league("POR1")[0].id)
	var played := 0
	var guard := 0
	SeasonManager.advance_to_user(w)
	while not w.season.finished and guard < 80:
		guard += 1
		check(SeasonManager.user_plays_now(w), "data %d sem jogo do usuário" % w.season.day)
		var md := SeasonManager.begin_matchday(w)
		check(not md["user"].is_empty(), "jogo do usuário não montado")
		for e in md["entries"]:
			SeasonManager.run_entry(w, e)
		SeasonManager.finish_matchday(w, md)
		played += 1
		SeasonManager.advance_to_user(w)
	var expect := 0
	for f in FixtureManager.season_fixtures(w, user.id):
		expect += 1
		check(f.played, "jogo do usuário ficou para trás")
	check(played == expect, "usuário jogou %d de %d jogos" % [played, expect])


func _test_save_load() -> void:
	var w := WorldGenerator.generate(2024, "aleatorio")
	_with_user(w, w.clubs_in_league("ARG1")[0].id)
	for i in 5:
		SeasonManager.play_matchday_instant(w)
	check(SaveManager.save_world(w, TEST_SLOT) == OK, "falha ao salvar")
	var l := SaveManager.load_world(TEST_SLOT)
	check(l != null, "falha ao carregar")
	if l == null:
		return
	check(_fingerprint(l) == _fingerprint(w), "o mundo carregado difere do salvo")
	for i in 3:
		SeasonManager.play_matchday_instant(w)
		SeasonManager.play_matchday_instant(l)
	check(_fingerprint(l) == _fingerprint(w), "depois de carregar, as datas seguintes divergem")
	# Save corrompido: o backup do save anterior assume.
	check(SaveManager.save_world(w, TEST_SLOT) == OK, "falha ao salvar de novo")
	var f := FileAccess.open(SaveManager.slot_path(TEST_SLOT), FileAccess.WRITE)
	f.store_string("lixo")
	f.close()
	var r := SaveManager.load_world(TEST_SLOT)
	check(r != null, "o backup deveria salvar um save corrompido")
	var meta := SaveManager.read_meta(TEST_SLOT)
	check(int(meta.get("year", 0)) == w.year and meta.get("short", "") == w.user_club().short_name, "metadados do espaço incorretos")
	SaveManager.delete_slot(TEST_SLOT)
	check(not SaveManager.has_save(TEST_SLOT), "espaço não foi apagado")


func _test_transfers() -> void:
	var w := WorldGenerator.generate(31337, "padrao")
	var user := _with_user(w, w.clubs_in_league("ENG2")[3].id)
	check(w.transfer_window_open(), "a janela deveria estar aberta no começo da temporada")
	var target: Player = null
	for p: Player in w.players.values():
		if p.club_id < 0 or p.club_id == user.id or w.club(p.club_id).is_rival(user.id):
			continue
		if p.age(w.year) <= 29 and p.squad_status >= Player.STATUS_ROTATION and TransferManager.interest(w, p, user) >= 0.55:
			target = p
			break
	check(target != null, "nenhum alvo de teste encontrado")
	if target == null:
		return
	var ask := TransferManager.asking_price(w, target)
	user.transfer_budget = ask * 4
	var low := TransferManager.user_bid(w, target, int(ask * 0.4))
	check(low["result"] == "rejected", "proposta de 40%% deveria ser recusada (%s)" % low["result"])
	var ok := TransferManager.user_bid(w, target, int(ask * 2.0))
	check(ok["result"] == "accepted", "proposta de 200%% deveria ser aceita (%s)" % ok["result"])
	var seller := w.club(target.club_id)
	var seller_before := seller.balance
	var budget_before := user.transfer_budget
	var wage := int(TransferManager.wage_ask(w, target, user) * 1.1)
	user.wage_budget = FinanceManager.wage_bill(w, user) + wage * 2
	var r := TransferManager.user_sign(w, target, int(ask * 2.0), wage, 3)
	check(r.get("ok", false), "contratação falhou: %s" % r.get("msg", ""))
	check(target.club_id == user.id and user.player_ids.has(target.id), "jogador não chegou ao clube")
	check(not seller.player_ids.has(target.id), "jogador continua no clube vendedor")
	check(seller.balance > seller_before, "vendedor não recebeu")
	check(user.transfer_budget < budget_before, "orçamento do comprador não caiu")
	check(target.contract_end == w.year + 3 and target.wage == wage, "contrato não registrado")
	# Janela fechada: só livres.
	w.season.day = 12
	check(not w.transfer_window_open(), "a janela deveria estar fechada na data 12")
	var closed := TransferManager.user_bid(w, w.player(seller.player_ids[0]), 1)
	check(closed["result"] == "rejected", "proposta com a janela fechada deveria ser recusada")


func _test_board() -> void:
	var w := WorldGenerator.generate(99, "padrao")
	var user := _with_user(w, w.clubs_in_league("GER1")[10].id, GameWorld.DIFF_HARD)
	user.board_confidence = 20.0
	var rev := BoardManager.season_review(w, user, {"goal_met": false, "relegated": true})
	check(rev["fired"], "diretoria deveria demitir após meta perdida e queda no difícil")
	var offers: Array = rev["offers"]
	check(offers.size() == 3, "deveria haver 3 propostas de emprego (%d)" % offers.size())
	check(not BoardManager.pending_job_offers(w).is_empty(), "propostas pendentes não registradas")
	if offers.is_empty():
		return
	BoardManager.take_job(w, int(offers[0]))
	check(w.user_club_id == int(offers[0]), "não assumiu o novo clube")
	check(BoardManager.pending_job_offers(w).is_empty(), "propostas continuam pendentes")
	# No fácil a diretoria nunca demite.
	var w2 := WorldGenerator.generate(99, "padrao")
	var u2 := _with_user(w2, w2.clubs_in_league("GER1")[10].id, GameWorld.DIFF_EASY)
	u2.board_confidence = 1.0
	var rev2 := BoardManager.season_review(w2, u2, {"goal_met": false, "relegated": true})
	check(not rev2["fired"], "no fácil ninguém é demitido")
	check(u2.board_confidence >= BoardManager.ULTIMATUM, "temporada nova não deveria começar em ultimato")


func _test_valuation() -> void:
	var w := WorldGenerator.generate(5150, "padrao")
	var zero := 0
	for p: Player in w.players.values():
		if p.value <= 0:
			zero += 1
		if p.club_id >= 0 and p.wage <= 0:
			zero += 1
	check(zero == 0, "%d jogadores sem valor ou salário" % zero)
	var young: Player = null
	for p: Player in w.players.values():
		if p.club_id >= 0 and p.age(w.year) >= 23 and p.age(w.year) <= 26 and p.overall >= 70:
			young = p
			break
	if young != null:
		var v_now := Valuation.market_value(young, w.year)
		var v_old := Valuation.market_value(young, w.year + 9) # mesmo nível, 9 anos mais velho
		check(v_old < v_now, "jogador mais velho com o mesmo nível deveria valer menos")
	# Salário acompanha a liga: o mesmo jogador pede mais na Inglaterra que no Brasil.
	var p0: Player = young if young != null else w.players.values()[0]
	check(Valuation.wage_demand(p0, _club(w, "ENG_MSK"), w.year) > Valuation.wage_demand(p0, w.clubs_in_league("BRA2")[0], w.year), "escala salarial por liga")


func _test_news() -> void:
	var w := WorldGenerator.generate(8080, "padrao")
	_with_user(w, w.clubs_in_league("BRA1")[0].id)
	for i in 8:
		SeasonManager.play_matchday_instant(w)
	check(w.news.size() >= 5, "poucas notícias em 8 datas (%d)" % w.news.size())
	var broken := 0
	for n: NewsEvent in w.news:
		if n.title.contains("{") or n.body.contains("{") or n.title.strip_edges() == "":
			broken += 1
	check(broken == 0, "%d notícias com texto não preenchido" % broken)


# ---------------------------------------------------------------------------
# Sistemas da carreira (eventos, treino, base, negócios, rostos)
# ---------------------------------------------------------------------------

func _career_world() -> GameWorld:
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	_with_user(w, w.clubs_in_league("BRA1")[5].id)
	YouthManager.ensure_academy(w)
	YouthManager.build_league(w)
	return w


func _test_events() -> void:
	var w := _career_world()
	var c := w.user_club()
	c.streak_winless = 5
	w.season.turn = 10
	var squad := w.squad(c)
	squad[3].injury_weeks = 4
	squad[4].injury_weeks = 3
	var built := 0
	for k in EventManager.KINDS:
		var ev := EventManager._build(w, k)
		if ev.is_empty():
			continue
		built += 1
		var d := EventManager.describe(w, ev)
		check(String(d["title"]) != "" and String(d["body"]) != "", "evento %s sem texto" % k)
		check(Array(d["options"]).size() >= 2, "evento %s com menos de 2 opções" % k)
		for i in Array(d["options"]).size():
			var e2 := ev.duplicate(true)
			e2["id"] = 100 + i
			w.events.append(e2)
			var msg := EventManager.resolve(w, e2, i)
			check(msg != "", "evento %s opção %d sem resposta" % [k, i])
			check(not w.events.has(e2), "evento %s não saiu da lista" % k)
	check(built >= 10, "poucos tipos de evento disponíveis (%d)" % built)
	# Promessa de minutos quebrada derruba a moral
	var p: Player = squad[10]
	p.morale = 70.0
	w.promises.clear()
	w.promises.append({"k": "minutes", "p": p.id, "until": w.current_turn(), "need": 2, "s0": p.stat(Player.S_STARTS)})
	EventManager._check_promises(w, w.current_turn(), "V")
	check(p.morale < 60.0 and w.promises.is_empty(), "promessa quebrada sem consequência")
	# Expiração aplica a opção padrão
	var ev := EventManager._build(w, "sponsor")
	ev["id"] = 555
	ev["exp"] = w.current_turn()
	w.events.append(ev)
	EventManager._expire(w, w.current_turn())
	check(not w.events.has(ev), "evento expirado continua pendente")


func _test_training_youth() -> void:
	var w := _career_world()
	var c := w.user_club()
	c.training = {"focus": "fisico", "int": 2}
	var p: Player = w.squad(c)[8]
	p.train = {"f": "finalizacao"}
	var bias := TrainingManager.bias_for(w, p)
	check(bias.size() == TrainingManager.focus_of(c)["attrs"].size() + TrainingManager.PLAYER_FOCUS["finalizacao"]["attrs"].size(), "foco do time + individual com pesos errados (%d)" % bias.size())
	check(TrainingManager.injury_mult(w, c.id) > 1.3, "treino intenso sem risco maior")
	var other: Club = w.clubs_in_league("BRA1")[0]
	check(TrainingManager.bias_for(w, w.squad(other)[0]).is_empty(), "IA não deveria usar o treino do usuário")
	var target := Pos.DM if p.position != Pos.DM else Pos.CM
	p.secondary.erase(target)
	p.train["pos"] = target
	for i in 40:
		TrainingManager.weekly(w)
	check(p.secondary.has(target), "posição não aprendida em 40 semanas")
	# Base e sub-20
	check(w.academy.size() >= 8, "base com poucos garotos (%d)" % w.academy.size())
	var kid: Player = YouthManager.academy(w)[0]
	check(w.player(kid.id) == kid, "garoto da base não encontrado por id")
	var n_before := c.player_ids.size()
	var msg := YouthManager.promote(w, kid)
	check(c.player_ids.size() == n_before + 1 and not w.academy.has(kid.id) and w.players.has(kid.id), "promoção falhou: %s" % msg)
	var ovr0 := 0.0
	for q: Player in w.academy.values():
		ovr0 += q.ovr_f
	for slot in w.season.calendar.size():
		if w.season.is_weekend(slot):
			w.season.day = slot
			YouthManager.play_slot(w, slot)
			YouthManager.weekly(w)
	var ovr1 := 0.0
	for q: Player in w.academy.values():
		ovr1 += q.ovr_f
	check(ovr1 > ovr0, "a base não evoluiu")
	var yl := w.youth_league
	var n: int = yl["clubs"].size()
	for cid in yl["clubs"]:
		check(int(yl["table"][cid]["pl"]) == n - 1, "sub-20: %s com %d jogos" % [w.club(cid).short_name, int(yl["table"][cid]["pl"])])
	check(not YouthManager.top_scorers(w, 3).is_empty(), "sub-20 sem artilheiros")
	var fin := YouthManager.finish_league(w)
	check(int(fin.get("champion", -1)) >= 0, "sub-20 sem campeão")
	w.year += 1
	var turn := YouthManager.season_turnover(w)
	check(not Array(turn["new"]).is_empty(), "nenhum garoto novo na virada")
	for q: Player in w.academy.values():
		check(q.age(w.year) <= YouthManager.MAX_AGE, "garoto acima da idade ficou na base")
	_test_academy_depth()


## Base aprofundada: categorias, escalação, sub-17, faixa de potencial, captação, peneira,
## propostas, revelados e save.
func _test_academy_depth() -> void:
	var w := _career_world()
	var c := w.user_club()
	check(YouthManager.has_league(w, "u20") and YouthManager.has_league(w, "u17"), "ligas sub-20 e sub-17 não montadas")
	# Categorias
	for q: Player in w.academy.values():
		var a := q.age(w.year)
		var cat := YouthManager.category(q, w.year)
		check((a >= 18) == (cat == YouthManager.CAT_U20) and (a <= 15) == (cat == YouthManager.CAT_U15), "categoria errada: %d anos em %s" % [a, cat])
	# Estimativa de potencial: perto do real, mas com erro que nunca some de todo
	var exact := 0
	for q: Player in w.academy.values():
		var est := YouthManager.estimate(w, q)
		check(absi(est - q.potential) <= 6 or est == q.overall, "estimativa %d longe do potencial %d" % [est, q.potential])
		if est == q.potential:
			exact += 1
	check(exact < w.academy.size(), "estimativa sempre exata: o potencial ficou exposto")
	# Escalação: um goleiro no gol, sem repetir ninguém, e sub-17 só com garotos até 17 anos
	var t := YouthManager.pick_team(w, "u20")
	var gks := 0
	var seen := {}
	for e in t["xi"]:
		if int(e[1]) == Pos.GK:
			gks += 1
		check(not seen.has(e[0].id), "garoto escalado duas vezes")
		seen[e[0].id] = true
	check(gks <= 1 and t["xi"].size() >= 5, "escalação do sub-20 estranha (%d jogadores, %d goleiros)" % [t["xi"].size(), gks])
	var t17 := YouthManager.pick_team(w, "u17", seen)
	for e in t17["xi"]:
		check(e[0].age(w.year) <= 17 and not seen.has(e[0].id), "sub-17 com garoto de %d anos ou repetido" % e[0].age(w.year))
	# Temporada das duas ligas: todo mundo joga tudo; quem joga soma minutos e notas
	for slot in w.season.calendar.size():
		if w.season.is_weekend(slot):
			w.season.day = slot
			YouthManager.play_slot(w, slot)
			YouthManager.weekly(w)
	for key in ["u20", "u17"]:
		var yl := YouthManager.league(w, key)
		var n: int = yl["clubs"].size()
		for cid in yl["clubs"]:
			check(int(yl["table"][cid]["pl"]) == n - 1, "%s: %s com %d jogos" % [key, w.club(cid).short_name, int(yl["table"][cid]["pl"])])
	var played := 0
	var gk_goals := 0
	for q: Player in w.academy.values():
		if q.stats[Player.S_APPS] > 0:
			played += 1
			check(q.avg_rating() >= 4.0 and q.avg_rating() <= 10.0, "nota fora da escala: %.2f" % q.avg_rating())
		if q.position == Pos.GK:
			gk_goals += q.stats[Player.S_GOALS]
	check(played >= 18, "poucos garotos jogaram (%d)" % played)
	check(gk_goals <= 1, "goleiros da base marcaram %d gols" % gk_goals)
	var games_u: Array = []
	for g in YouthManager.league(w, "u20")["rounds"][0] + YouthManager.league(w, "u20")["rounds"][1]:
		if w.is_user_club(int(g[0])) or w.is_user_club(int(g[1])):
			games_u.append(g)
	check(not games_u.is_empty() and games_u[0].size() == 5, "jogo do usuário sem resumo (autores/melhor em campo)")
	var fin := YouthManager.finish_league(w)
	check(int(fin.get("champion", -1)) >= 0 and int(fin.get("u17", {}).get("champion", -1)) >= 0, "ligas da base sem campeão")
	# Captação e peneira
	YouthManager.set_region(w, "internacional")
	YouthManager.set_focus(w, "gol")
	check(YouthManager.scouting_cost(w) > YouthManager.scouting_cost(w, "nacional") and YouthManager.scouting_cost(w, "local") == 0, "custos da captação fora de ordem")
	var bal := c.balance
	check(YouthManager.can_trial(w), "peneira indisponível no começo")
	var cands := YouthManager.run_trial(w)
	check(cands.size() >= 3 and c.balance < bal and not YouthManager.can_trial(w), "peneira não gerou candidatos ou não cobrou")
	for q: Player in cands:
		check(not w.academy.has(q.id), "candidato entrou na base sem ser aprovado")
	var n0 := w.academy.size()
	YouthManager.accept_candidate(w, cands[0].id)
	check(w.academy.size() == n0 + 1 and w.academy.has(cands[0].id) and YouthManager.candidates(w).size() == cands.size() - 1, "aprovação na peneira falhou")
	# Regra da FIFA: garoto de 15 anos não vai para o exterior
	check(YouthManager.min_foreign_age("BRA", "ESP") == 18 and YouthManager.min_foreign_age("POR", "ESP") == 16 and YouthManager.min_foreign_age("BRA", "BRA") == 0, "regra de transferência de menores errada")
	# Proposta por um garoto: evento, venda com % de revenda e revelado registrado
	var kid: Player = YouthManager.academy(w)[0]
	kid.potential = maxi(kid.potential, 80)
	var buyer := YouthManager.bid_buyer(w, kid)
	if buyer != null:
		check(kid.age(w.year) >= YouthManager.min_foreign_age(c.nation, buyer.nation), "comprador estrangeiro para garoto novo demais")
		var ev := {"id": 999, "k": "youth_bid", "turn": w.current_turn(), "exp": w.current_turn() + 3, "p": kid.id, "d": {"club": buyer.id, "fee": YouthManager.bid_fee(w, kid, buyer)}}
		check(EventManager.describe(w, ev)["options"].size() == 3, "evento de proposta sem as 3 opções")
		w.events.append(ev)
		var bal2 := c.balance
		EventManager.resolve(w, ev, 0)
		check(not w.academy.has(kid.id) and kid.club_id == buyer.id and c.balance > bal2 and int(kid.clauses.get("so", -1)) == c.id, "venda do garoto da base falhou")
		check(YouthManager.graduates(w).size() >= 1 and YouthManager.sales_total(w) > 0, "venda não entrou nos revelados")
	# Save guarda a base inteira
	var w2 := GameWorld.from_dict(w.to_dict())
	check(String(YouthManager.state(w2)["region"]) == "internacional" and YouthManager.has_league(w2, "u17") and YouthManager.graduates(w2).size() == YouthManager.graduates(w).size(), "save perdeu captação/sub-17/revelados")
	# Virada: balanço do ano (estirão/estagnação), cobrança da captação e novos garotos
	var bal3 := c.balance
	w.year += 1
	var turn := YouthManager.season_turnover(w)
	check(int(turn["cost"]) > 0 and c.balance < bal3, "captação internacional não foi cobrada")
	check(YouthManager.candidates(w).is_empty(), "candidatos da peneira sobraram para o ano seguinte")
	for q: Player in turn["new"]:
		check(q.age(w.year) >= YouthManager.MIN_AGE and q.age(w.year) <= 16, "garoto novo com %d anos" % q.age(w.year))
	check(float(YouthManager._pos_weights(w)[Pos.GK]) >= float(YouthManager.POS_WEIGHTS[Pos.GK]) * 3.0, "foco em goleiros não mudou a captação")
	# Estirão e estagnação acontecem num grupo grande ao longo de alguns anos
	var ups := 0
	var downs := 0
	for i in 6:
		for ch in YouthManager.yearly_review(w):
			if ch["up"]:
				ups += 1
			else:
				downs += 1
	check(ups > 0 and downs > 0, "balanço da base sem estirão (%d) ou estagnação (%d)" % [ups, downs])


func _test_hearts_manager() -> void:
	var w := _career_world()
	var c := w.user_club()
	# Times de coração: todo mundo sorteado, ~60% torcem para alguém, quase todos escondidos
	var fans := 0
	var total := 0
	var known := 0
	var local := 0
	for p: Player in w.players.values():
		total += 1
		check(p.heart != -2, "jogador sem sorteio de time de coração")
		if p.heart >= 0:
			fans += 1
			var hc := w.club(p.heart)
			check(hc != null and hc.nation == p.nationality, "time de coração de outro país")
			if hc != null and hc.city == p.hometown:
				local += 1
		if p.heart_known:
			known += 1
	var share := float(fans) / float(total)
	check(share > 0.4 and share < 0.75, "fração de torcedores estranha: %.2f" % share)
	check(known == 0, "time de coração revelado sem motivo (%d)" % known)
	check(local > fans * 0.2, "poucos torcem para o clube da cidade (%d de %d)" % [local, fans])
	# Save guarda o segredo
	var any: Player = null
	for p: Player in w.players.values():
		if p.heart >= 0:
			any = p
			break
	var w2 := GameWorld.from_dict(w.to_dict())
	check(w2.player(any.id).heart == any.heart and not w2.player(any.id).heart_known, "save perdeu o time de coração")
	# Efeito: topa ir para o clube do coração com mais vontade e pedindo menos
	var heart_club := w.club(any.heart)
	var before := any.heart
	any.heart = -1
	var i0 := TransferManager.interest(w, any, heart_club)
	var wage0 := TransferManager.wage_ask(w, any, heart_club)
	any.heart = before
	check(TransferManager.interest(w, any, heart_club) >= i0 and TransferManager.wage_ask(w, any, heart_club) <= wage0, "clube do coração não pesou na negociação")
	# Pergunta na conversa revela (ou ele desconversa se torce para o rival)
	var sp: Player = w.squad(c)[0]
	HeartClubs.ask(w, sp)
	var hc2 := HeartClubs.club_of(w, sp)
	check(sp.heart_known or (hc2 != null and (hc2.is_rival(c.id) or c.is_rival(hc2.id))), "pergunta sobre o time de coração não revelou")
	# Treinador personalizado: salvo e com efeito do estilo
	var m := ManagerProfile.data(w)
	m["style"] = "formador"
	m["nat"] = "ARG"
	check(ManagerProfile.youth_mult(w) > 1.0 and ManagerProfile.cohesion_mult(w) == 1.0, "estilo formador sem efeito")
	var w3 := GameWorld.from_dict(w.to_dict())
	check(ManagerProfile.style(w3) == "formador" and String(ManagerProfile.data(w3)["nat"]) == "ARG", "save perdeu o treinador")
	# Save antigo: 15 atributos viram 21, estatísticas antigas ganham as novas colunas zeradas
	var old_d := sp.to_dict()
	var at: PackedByteArray = old_d["at"]
	old_d["at"] = at.slice(0, Attr.OLD_COUNT)
	var st0: PackedInt32Array = old_d["stats"]
	old_d["stats"] = st0.slice(0, 10)
	var mig := Player.from_dict(old_d)
	check(mig.attrs.size() == Attr.COUNT and mig.attrs[Attr.DRI] > 0 and mig.attrs[Attr.ACE] > 0 and mig.stats.size() == Player.S_COUNT, "migração de save antigo falhou")
	check(absi(mig.overall - sp.overall) <= 6, "overall mudou demais na migração (%d → %d)" % [sp.overall, mig.overall])
	# Revelados: clubes formadores reconhecidos pela primeira passagem
	var any_grads := 0
	for cl: Club in w.clubs_in_league("BRA1"):
		any_grads += Graduates.count(w, cl.id)
	check(any_grads > 20, "quase nenhum revelado nos clubes da Série A (%d)" % any_grads)


func _test_tactical_freedom() -> void:
	var w := _career_world()
	var c := w.user_club()
	# Formação personalizada: o 4-3-3 com um meia central virando meia-armador
	var name := DatabaseManager.custom_formation_name("4-3-3", {6: "AM"})
	check(DatabaseManager.has_formation(name) and DatabaseManager.formation_base(name) == "4-3-3", "formação personalizada não reconhecida")
	var f := DatabaseManager.formation(name)
	check(int(f["slots"][6]["pos"]) == Pos.AM and String(f["slots"][6]["role"]) == "AM" and f["slots"].size() == 11, "vaga personalizada não virou meia-armador")
	check(int(f["slots"][0]["pos"]) == Pos.GK, "goleiro saiu do gol")
	c.sheet = ClubAI.auto_sheet(w, c, name)
	check(c.sheet.starters.size() == 11, "escalação na formação personalizada incompleta")
	check(TacticsManager.formation_fam(c, name) <= TacticsManager.formation_fam(c, "4-3-3"), "variação personalizada sem custo de entrosamento")
	# Instruções individuais mudam os pesos do jogador no motor
	var pid: int = c.sheet.starters[9]
	c.sheet.instr[pid] = "avancar"
	var opp: Club = w.clubs_in_league("BRA1")[0]
	var hs := c.sheet.duplicate_sheet()
	var as_ := ClubAI.prepare_ai_sheet(w, opp, c, false)
	var sim := MatchSimulation.new()
	sim.setup(w, c, opp, hs, as_, {"competition": "BRA1", "attendance": 20000}, 5, false)
	var mp: MatchPlayer = sim.teams[0].by_id[pid]
	var base_att := float(f["slots"][9]["att"])
	check(mp.w_att > base_att, "instrução de apoiar o ataque não subiu o peso ofensivo")
	sim.run_to_end()
	check(sim.finished, "partida com formação personalizada não terminou")
	var r := QuickMatch.play(w, c, opp, hs, as_, {"competition": "BRA1", "attendance": 20000}, 9)
	check(int(r["hg"]) >= 0, "modo rápido falhou com formação personalizada")
	# Save guarda formação, instruções e largura
	hs.width = 2
	var back := TeamSheet.from_dict(hs.to_dict())
	check(back.formation == name and String(back.instr.get(pid, "")) == "avancar" and back.width == 2, "escalação perdeu ajustes táticos no save")
	# Regra de estrangeiros (Brasil: até 9 entre os relacionados)
	var lim := int(SquadRules.limit(c)["max"])
	check(lim == 9, "Brasil deveria permitir 9 estrangeiros (%d)" % lim)
	var foreign_n := 0
	for q: Player in w.squad(c):
		if q.nationality != c.nation:
			foreign_n += 1
	# Força a regra: todo mundo do elenco vira estrangeiro, menos o necessário
	var changed: Array = []
	for q: Player in w.squad(c):
		if q.nationality == c.nation and changed.size() < 14:
			q.nationality = "ARG"
			changed.append(q)
	c.sheet = ClubAI.auto_sheet(w, c, "4-3-3")
	check(SquadRules.count(w, c, c.sheet.starters + c.sheet.bench) <= lim, "escalação acima do limite de estrangeiros (%d)" % SquadRules.count(w, c, c.sheet.starters + c.sheet.bench))
	for q: Player in changed:
		q.nationality = c.nation
	# Espanha: só extracomunitários contam
	var esp: Club = w.clubs_in_league("ESP1")[0]
	var probe := Player.new()
	probe.nationality = "FRA"
	check(not SquadRules.is_foreign(probe, esp, "non_eu"), "francês contou como extracomunitário na Espanha")
	probe.nationality = "BRA"
	check(SquadRules.is_foreign(probe, esp, "non_eu"), "brasileiro deveria ser extracomunitário na Espanha")


func _test_shouts() -> void:
	var w := _career_world()
	var c := w.user_club()
	var foe: Club = w.clubs_in_league("BRA1")[0]
	if foe.id == c.id:
		foe = w.clubs_in_league("BRA1")[1]
	# Mesmo jogo (mesma semente) com e sem "Pra frente!" a cada janela: o time finaliza mais.
	var shots := [0, 0]
	var fouls := [0, 0]
	for mode in 2:
		for k in 40:
			var sim := MatchSimulation.new()
			sim.setup(w, c, foe, ClubAI.prepare_ai_sheet(w, c, foe, true), ClubAI.prepare_ai_sheet(w, foe, c, false), {"competition": "BRA1", "attendance": 20000}, 500 + k, false)
			sim.teams[0].is_user = true
			while not sim.finished:
				sim.step()
				if mode == 1 and sim.started and sim.shout_wait(0) == 0 and sim.minute >= 5 and sim.minute < 88:
					sim.shout(0, "frente" if sim.minute < 60 else "pressao")
			shots[mode] += sim.teams[0].shots
			fouls[mode] += sim.teams[0].fouls
	check(shots[1] > shots[0] * 1.03, "gritos de ataque não aumentaram as finalizações (%d × %d)" % [shots[1], shots[0]])
	check(fouls[1] > fouls[0], "pressão não aumentou as faltas (%d × %d)" % [fouls[1], fouls[0]])
	# Repetir perde efeito, intervalo entre gritos, reação conforme a personalidade
	var sim2 := MatchSimulation.new()
	sim2.setup(w, c, foe, ClubAI.prepare_ai_sheet(w, c, foe, true), ClubAI.prepare_ai_sheet(w, foe, c, false), {"competition": "BRA1", "attendance": 20000}, 77, false)
	while sim2.minute < 10:
		sim2.step()
	check(sim2.shout(0, "frente")["ok"], "grito recusado")
	var a1 := sim2.teams[0].sh_att
	check(not sim2.shout(0, "frente")["ok"], "gritou de novo sem intervalo")
	while sim2.shout_wait(0) > 0:
		sim2.step()
	sim2.shout(0, "frente")
	check(sim2.teams[0].sh_att < a1, "repetir o grito não perdeu efeito")
	var mp: MatchPlayer = sim2.teams[0].slots[5]
	mp.p.traits = ["inseguro"]
	check(sim2._shout_reaction(mp, "cob", 0) < 0.0, "inseguro não sentiu a cobrança")
	mp.p.traits = ["lider"]
	check(sim2._shout_reaction(mp, "cob", 0) > 0.0, "líder não respondeu à cobrança")
	while sim2.minute < sim2.teams[0].sh_until + 1 and not sim2.finished:
		sim2.step()
	check(sim2.teams[0].sh_key == "" and is_equal_approx(sim2.teams[0].sh_att, 1.0), "efeito do grito não acabou")


func _test_xray() -> void:
	var w := _career_world()
	var c := w.user_club()
	var opp: Club = w.clubs_in_league("BRA1")[0]
	c.sheet = ClubAI.auto_sheet(w, c, "4-3-3")
	# Lado direito aberto: o lateral direito só apoia e o ponta direito não volta
	var slots: Array = DatabaseManager.formation("4-3-3")["slots"]
	var rb := -1
	var rw := -1
	for i in slots.size():
		if int(slots[i]["pos"]) == Pos.RB:
			rb = int(c.sheet.starters[i])
		if int(slots[i]["pos"]) == Pos.RW:
			rw = int(c.sheet.starters[i])
	# Referência: os mesmos jogos sem a instrução
	var right0 := 0
	for k in 60:
		var foe0: Club = w.clubs_in_league("BRA1")[k % 3]
		if foe0.id == c.id:
			foe0 = w.clubs_in_league("BRA1")[3]
		var sim0 := MatchSimulation.new()
		sim0.setup(w, c, foe0, c.sheet.duplicate_sheet(), ClubAI.prepare_ai_sheet(w, foe0, c, false), {"competition": "BRA1", "attendance": 20000}, 100 + k, false)
		sim0.run_to_end()
		right0 += int(TacticalXRay.analyze(w, sim0)["against"]["lanes"][2])
	c.sheet.instr[rb] = "avancar"
	var right := 0
	var right60 := 0
	var left := 0
	var reports := 0
	var fb_flagged := 0
	# Três adversários diferentes: o efeito é do lateral que sobe, não do jeito de jogar de um rival só
	for k in 120:
		var foe: Club = w.clubs_in_league("BRA1")[k % 3]
		if foe.id == c.id:
			foe = w.clubs_in_league("BRA1")[3]
		var sim := MatchSimulation.new()
		sim.setup(w, c, foe, c.sheet.duplicate_sheet(), ClubAI.prepare_ai_sheet(w, foe, c, false), {"competition": "BRA1", "attendance": 20000}, 100 + k, false)
		sim.run_to_end()
		var rep := TacticalXRay.analyze(w, sim)
		if rep.is_empty():
			continue
		reports += 1
		var la: Array = rep["against"]["lanes"]
		left += int(la[0])
		right += int(la[2])
		if k < 60:
			right60 += int(la[2])
		var total := 0
		for ch in rep["chances"]:
			if not bool(ch["mine"]) and int(ch["ul"]) >= 0:
				total += 1
				if int(ch["ul"]) == 2 and int(ch.get("fb", -1)) == rb and bool(ch.get("fb_up", false)):
					fb_flagged += 1
		check(total == int(la[0]) + int(la[1]) + int(la[2]), "corredores não somam as chances do adversário")
		check(not Array(rep["segments"]).is_empty(), "raio-x sem trechos")
	check(reports == 120, "raio-x não gerado em todas as partidas (%d)" % reports)
	check(right60 > right0 * 1.07, "lateral no ataque não abriu o corredor (dir %d com × %d sem)" % [right60, right0])
	check(fb_flagged > 0, "raio-x não apontou o lateral no ataque")
	# Correção: aplicar a sugestão muda a escalação
	var fix := {"type": "instr", "pid": rb, "instr": "segurar", "label": "segurar"}
	TacticalXRay.apply_fix(w, fix)
	check(String(c.sheet.instr.get(rb, "")) == "segurar", "correção do raio-x não aplicada")
	var fix2 := {"type": "formation", "slot_pos": "AM", "label": "meia"}
	TacticalXRay.apply_fix(w, fix2)
	check(c.sheet.formation.begins_with("C:") and DatabaseManager.formation(c.sheet.formation)["slots"].any(func(sl): return int(sl["pos"]) == Pos.AM), "correção de formação não aplicada")
	# Mudança no meio do jogo cria um trecho novo
	var sim2 := MatchSimulation.new()
	sim2.setup(w, c, opp, c.sheet.duplicate_sheet(), ClubAI.prepare_ai_sheet(w, opp, c, false), {"competition": "BRA1", "attendance": 20000}, 7, false)
	while sim2.minute < 55 and not sim2.finished:
		sim2.step()
	sim2.set_formation(0, "4-2-3-1")
	sim2.run_to_end()
	var rep2 := TacticalXRay.analyze(w, sim2)
	check(Array(rep2["segments"]).size() >= 2, "mudança de formação não abriu um trecho novo")
	var has_change := false
	for ins in rep2["insights"]:
		if String(ins["k"]) == "change":
			has_change = true
	check(has_change, "raio-x sem o antes e depois da mudança")


func _test_trades() -> void:
	var w := _career_world()
	var c := w.user_club()
	c.transfer_budget = 80_000_000
	c.wage_budget = maxi(c.wage_budget, 50_000_000) # o teste é da troca, não do teto salarial
	w.season.day = 0 # janela aberta no início
	check(w.transfer_window_open(), "janela deveria estar aberta")
	var seller: Club = w.clubs_in_league("BRA1")[10]
	var target: Player = w.squad(seller)[3]
	var mine: Array = w.squad(c).duplicate()
	mine.sort_custom(func(a, b): return a.value > b.value)
	var sp: Player = mine[2]
	var deal := {"inst": 1, "sell_on": 0.0, "swap": [sp.id]}
	var cash_only := TransferManager.user_bid(w, target, Valuation.round_value(target.value * 0.5), {"inst": 1})
	w.stats.erase("neg")
	var with_swap := TransferManager.user_bid(w, target, Valuation.round_value(target.value * 0.5), deal)
	check(TransferManager.swap_worth(w, sp, seller) > 0, "jogador da troca sem valor")
	check(cash_only["result"] != "accepted" or with_swap["result"] == "accepted", "troca não melhorou a proposta")
	# Fecha com troca: o jogador oferecido vai para o vendedor
	var n0 := c.player_ids.size()
	var r := TransferManager.user_sign(w, target, target.value, TransferManager.wage_ask(w, target, c) * 2, 3, deal)
	check(r["ok"], "contratação com troca falhou: %s" % r.get("msg", ""))
	if r["ok"]:
		check(target.club_id == c.id and sp.club_id == seller.id, "troca não moveu os dois jogadores")
		check(c.player_ids.size() == n0, "elenco deveria ficar do mesmo tamanho")
	# Oferecer jogador aos clubes
	var off: Player = mine[5]
	var sh := TransferManager.shop_player(w, off)
	check(sh["ok"], "oferecer falhou: %s" % sh["msg"])
	var again := TransferManager.shop_player(w, off)
	check(not again["ok"], "oferecer duas vezes na mesma rodada deveria ser bloqueado")
	# Contraproposta em rodadas: comprador sobe sem passar do teto
	var o := TransferOffer.new()
	o.id = 999
	o.player_id = mine[6].id
	o.buyer_id = w.clubs_in_league("ENG1")[0].id
	o.seller_id = c.id
	o.fee = 1_000_000
	o.max_fee = 1_500_000
	o.expires_day = w.current_turn() + 2
	w.offers.append(o)
	var msg := TransferManager.respond_offer(w, o, "counter", 2_000_000)
	check(o.is_pending() and o.fee > 1_000_000 and o.fee <= o.max_fee, "comprador deveria subir a oferta (%s)" % msg)
	TransferManager.respond_offer(w, o, "counter", 1_400_000)
	check(o.is_pending() and o.raised and o.fee == 1_400_000, "pedido dentro do teto deveria ser aceito")
	var d := o.to_dict()
	check(TransferOffer.from_dict(d).rounds == 2, "rodadas não salvas")


func _test_sponsors() -> void:
	var w := _career_world()
	var c := w.user_club()
	c.sponsors.clear()
	SponsorManager.open_preseason(w)
	check(SponsorManager.is_preseason(w), "pré-temporada não abriu")
	check(c.sponsors.size() == SponsorManager.SLOTS.size(), "diretoria não fechou todos os espaços (%d)" % c.sponsors.size())
	for key in ["sp", "sup", "sp_m", "sp_c", "sp_s"]:
		check(c.kit_home.has(key) and c.kit_away.has(key), "logo %s fora do uniforme" % key)
	check(String(c.kit_home.get("sp", {}).get("n", "")) == String(c.sponsors["master"]["n"]), "logo do master fora da camisa")
	var typical := FinanceManager.sponsor_income(c)
	check(c.income_sponsor > typical * 0.75 and c.income_sponsor < typical * 1.25, "receita de patrocínio desbalanceada (%d vs %d)" % [c.income_sponsor, typical])
	check(SponsorManager.breakdown(c).size() == 6, "detalhamento de patrocínio incompleto")
	var c2 := Club.from_dict(c.to_dict())
	check(c2.sponsors.size() == 5 and is_equal_approx(c2.commercial, c.commercial), "patrocínios não salvos")
	SponsorManager.close_preseason(w)
	check(not SponsorManager.is_preseason(w), "pré-temporada não fechou")
	# Momento comercial: clube em alta recebe propostas maiores e a diretoria trava por mais tempo
	c.commercial = 1.3
	c.sponsors.clear()
	SponsorManager.open_preseason(w)
	var hi := c.income_sponsor
	var hi_yrs := int(c.sponsors["master"]["yrs"])
	c.commercial = 0.8
	c.sponsors.clear()
	SponsorManager.open_preseason(w)
	check(c.income_sponsor < hi * 0.8, "momento comercial não mexeu no valor (%d vs %d)" % [c.income_sponsor, hi])
	check(int(c.sponsors["master"]["yrs"]) < hi_yrs, "diretoria deveria fechar curto em baixa e longo em alta")
	# Cláusulas: título paga bônus; rebaixamento corta contratos em vigor
	for slot in c.sponsors:
		c.sponsors[slot]["y"] = w.year + 1
	var b0 := c.balance
	var v0 := int(c.sponsors["master"]["v"])
	SponsorManager._clauses(w, c, 1, true, false)
	check(c.balance > b0 and int(c.ledger.get("bonus_patrocinio", 0)) > 0, "bônus por título não pago")
	SponsorManager._clauses(w, c, 0, false, true)
	check(int(c.sponsors["master"]["v"]) < v0, "rebaixamento não cortou o contrato")
	# Fim de temporada mexe no momento de todos os clubes
	var before := {}
	for cl: Club in w.clubs:
		before[cl.id] = cl.commercial
	SponsorManager.season_close(w, {})
	var moved := 0
	for cl: Club in w.clubs:
		if not is_equal_approx(before[cl.id], cl.commercial):
			moved += 1
	check(moved > w.clubs.size() / 2, "momento comercial parado no fim da temporada")
	check(KitView.style_combinations() >= 100, "poucas combinações de uniforme")


func _test_deals() -> void:
	var w := _career_world()
	var c := w.user_club()
	var demand := 100000
	check(TransferManager.adjust_demand(demand, 3, {"bonus": 1200000, "clause": 3}) < demand, "luvas não reduziram o salário pedido")
	check(TransferManager.adjust_demand(demand, 3, {"clause": 2}) < TransferManager.adjust_demand(demand, 3, {"clause": 5}), "multa baixa deveria baratear o salário")
	check(TransferManager.deal_value(1000000, {"inst": 3}) < TransferManager.deal_value(1000000, {}), "parcelas deveriam valer menos")
	check(TransferManager.deal_value(1000000, {"sell_on": 0.2}) > TransferManager.deal_value(1000000, {}), "revenda deveria valer mais")
	check(TransferManager.upfront_cost(900000, {"inst": 3}) < 900000, "primeira parcela deveria ser menor que o total")
	# Compra parcelada com revenda e multa
	var seller: Club = w.clubs_in_league("BRA1")[12]
	var p: Player = w.squad(seller)[15]
	c.transfer_budget = 50_000_000
	var bal0 := c.balance
	var fee := p.value
	TransferManager.complete_transfer(w, p, c, fee, p.wage, 3)
	TransferManager.apply_deal(w, p, c, seller.id, fee, {"inst": 3, "sell_on": 0.1, "clause": 2})
	check(Array(w.stats.get("installments", [])).size() == 2, "parcelas não agendadas")
	check(int(p.clauses.get("so", -1)) == seller.id, "cláusula de revenda não registrada")
	check(p.release_clause > 0, "multa rescisória não registrada")
	check(bal0 - c.balance < fee, "compra parcelada cobrou tudo de uma vez")
	w.year += 2
	TransferManager.pay_installments(w)
	check(Array(w.stats.get("installments", [])).is_empty(), "parcelas não pagas")
	w.year -= 2
	# Revenda: o clube antigo recebe sua parte
	var buyer: Club = w.clubs_in_league("ENG1")[0]
	var sbal := seller.balance
	TransferManager.complete_transfer(w, p, buyer, 2_000_000, p.wage, 3)
	check(seller.balance - sbal == 200000, "revenda de 10%% não paga (%d)" % (seller.balance - sbal))
	# Empréstimo de ida e volta
	var mine: Player = w.squad(c)[18]
	var r := TransferManager.loan_out(w, mine)
	check(r["ok"], "empréstimo recusado: %s" % r["msg"])
	if r["ok"]:
		check(not c.player_ids.has(mine.id) and mine.club_id != c.id, "emprestado continua no elenco")
		check(TransferManager.loaned_out(w).has(mine), "emprestado fora da lista")
		var back := TransferManager.return_loans(w)
		check(back.has(mine) and c.player_ids.has(mine.id) and mine.loan.is_empty(), "emprestado não voltou")
	# Save guarda os campos novos
	w.events.append({"id": 1, "k": "sponsor", "turn": 0, "exp": 3, "p": -1, "p2": -1, "d": {"lump": 1, "bonus": 2, "brand": "X"}})
	mine.look = {"hs": 3, "bd": 2}
	mine.train = {"f": "fisico"}
	var w2 := GameWorld.from_dict(w.to_dict())
	check(w2.events.size() == 1 and w2.academy.size() == w.academy.size() and not w2.youth_league.is_empty(), "save perdeu eventos/base/sub-20")
	var m2: Player = w2.player(mine.id)
	check(int(m2.look.get("hs", -1)) == 3 and String(m2.train.get("f", "")) == "fisico", "save perdeu aparência/treino")
	check(w2.player(p.id).release_clause == p.release_clause, "save perdeu a multa")


func _test_market_ai() -> void:
	var w := _season_world
	if w == null:
		w = WorldGenerator.generate(777, "padrao")
		_season(w)
	# Ninguém é revendido na mesma temporada em que chegou.
	var buys := {}
	var export_routes := 0
	for t: Transfer in w.transfer_log:
		if t.year != w.year or t.kind != Transfer.KIND_BUY:
			continue
		buys[t.player_id] = int(buys.get(t.player_id, 0)) + 1
		var from := w.club(t.from_id)
		var to := w.club(t.to_id)
		if ["BRA", "ARG", "URU", "COL"].has(from.nation) and ["ENG", "ESP", "GER", "ITA", "FRA", "POR", "NED"].has(to.nation):
			export_routes += 1
	var repeated := 0
	for pid in buys:
		if int(buys[pid]) > 1:
			repeated += 1
	check(repeated == 0, "%d jogador(es) vendido(s) mais de uma vez na temporada" % repeated)
	check(export_routes >= 3, "quase ninguém saiu da América do Sul para a Europa (%d)" % export_routes)
	check(float(w.stats.get("loans", 0.0)) > 20.0, "a IA quase não emprestou jovens")
	var max_players := int(DatabaseManager.squad_rules()["max_players"])
	for c: Club in w.clubs:
		if not w.is_user_club(c.id):
			check(c.player_ids.size() <= max_players + 1, "%s com elenco inchado (%d)" % [c.short_name, c.player_ids.size()])
	# Clube grande não vende a estrela para um clube pequeno, nem com o cofre cheio.
	var big: Club = w.clubs_in_league("ENG1")[0]
	var star: Player = null
	for q: Player in w.squad(big):
		if q.squad_status == Player.STATUS_STAR and q.loan.is_empty():
			star = q
	var small: Club = w.clubs_in_league("BRA2")[5]
	small.transfer_budget = 900_000_000
	if star != null:
		check(not MarketAI.negotiate(w, small, star, 1.0, false).has("fee"), "estrela vendida para clube pequeno")
	# Rico inglês paga ágio por uma promessa brasileira.
	var seller: Club = w.clubs_in_league("BRA1")[8]
	var prospect: Player = null
	for q: Player in w.squad(seller):
		if q.age(w.year) <= 22 and q.loan.is_empty() and (prospect == null or q.potential > prospect.potential):
			prospect = q
	big.transfer_budget = 900_000_000
	if prospect != null:
		# Pode virar novela (o comprador sobe a oferta nas semanas seguintes), como no jogo.
		var deal := {}
		for push in 4:
			deal = MarketAI.negotiate(w, big, prospect, 1.0, false, false, push)
			if deal.has("fee"):
				break
		check(deal.has("fee") and int(deal["fee"]) * (1.0 + float(deal.get("sell_on", 0.0)) * 0.5) >= prospect.value, "clube inglês não pagou ágio pela promessa (%s)" % str(deal))
		var bids := MarketAI.bids_for_user_player(w, big, prospect)
		check(int(bids[0]) <= int(bids[1]) and int(bids[0]) > 0, "proposta acima do teto do comprador")
	check(MarketAI.power(big) > MarketAI.power(seller) * 2.0, "liga inglesa deveria ter muito mais poder de compra")
	if star != null:
		check(float(MarketAI.negotiate(w, small, star, 1.0, false).get("gap", -1.0)) >= 0.0, "negociação travada sem informar a distância")
	# Empréstimo com opção de compra: quem se firmou é comprado no fim da temporada.
	var owner: Club = w.clubs_in_league("ESP1")[2]
	var borrower: Club = w.clubs_in_league("ESP1")[15]
	var loanee: Player = null
	for q: Player in w.squad(owner):
		if q.loan.is_empty() and q.age(w.year) >= 22 and q.age(w.year) <= 29:
			loanee = q
	if loanee != null:
		TransferManager._move_loan(w, loanee, owner, borrower)
		loanee.loan["opt"] = loanee.value
		loanee.squad_status = Player.STATUS_STARTER
		borrower.transfer_budget = loanee.value * 3
		var ok := false
		for _k in 10:
			MarketAI.exercise_loan_options(w)
			if loanee.loan.is_empty():
				ok = true
				break
		check(ok and loanee.club_id == borrower.id and not owner.player_ids.has(loanee.id), "opção de compra não exercida")


func _test_faces() -> void:
	var a := FaceGen.features(1234, 7, 25)
	var b := FaceGen.features(1234, 7, 25)
	check(var_to_str(a) == var_to_str(b), "rosto não é determinístico")
	var old := FaceGen.features(1234, 7, 38)
	check(float(old["gray"]) >= float(a["gray"]) and float(old["wrinkles"]) > float(a["wrinkles"]), "rosto não envelhece")
	var styles := {}
	var beards := {}
	var eths := {}
	var eyes := {}
	var shapes := {}
	for i in 2000:
		var f := FaceGen.features(i * 7919, i % FaceGen.ETH_COUNT, 16 + i % 30)
		styles[int(f["style"])] = true
		beards[int(f["beard"])] = true
		eths[int(f["eth"])] = true
		eyes[int(f["eye_i"])] = true
		shapes[int(f["face_shape"])] = true
	check(styles.size() >= 60, "pouca variedade de penteados (%d)" % styles.size())
	check(beards.size() >= 32, "pouca variedade de barbas (%d)" % beards.size())
	check(shapes.size() == FaceGen.FACE_SHAPES.size(), "formatos de rosto que nunca aparecem (%d)" % shapes.size())
	check(eyes.size() == FaceGen.EYE_COLORS.size(), "cores de olho que nunca aparecem (%d)" % eyes.size())
	check(FaceGen.EYE_NAMES.size() == FaceGen.EYE_COLORS.size(), "nomes e cores de olho não batem")
	check(FaceGen.STYLE_TEX_W.size() == FaceGen.HAIR_STYLES.size() and PortraitView.STYLE_P.size() == FaceGen.HAIR_STYLES.size(), "penteado sem parâmetros")
	check(FaceGen.BEARD_PARTS.size() == FaceGen.BEARDS.size() and FaceGen.BEARD_MIN_CAP.size() == FaceGen.BEARDS.size() and FaceGen.BEARD_POP.size() == FaceGen.BEARDS.size(), "barba sem parâmetros")
	for e in FaceGen.ETH_COUNT:
		check((FaceGen.ETH_EYES[e] as Array).size() == FaceGen.EYE_COLORS.size(), "pesos de olho da etnia %d incompletos" % e)
	check(eths.size() == FaceGen.ETH_COUNT, "etnias sem rosto (%d)" % eths.size())
	check(FaceGen.ETH_COUNT == DatabaseManager.ethnicities().size(), "FaceGen e nations.json com etnias diferentes")
	# Barba só depois da puberdade, e nem todo adulto tem
	var teen_beards := 0
	var adult_none := 0
	var adult_full := 0
	for i in 300:
		var teen := FaceGen.features(i * 104729, i % FaceGen.ETH_COUNT, 15)
		if int(teen["beard"]) not in [FaceGen.B_NONE, FaceGen.B_WISPY]:
			teen_beards += 1
		var adult := FaceGen.features(i * 104729, i % FaceGen.ETH_COUNT, 31)
		if int(adult["beard"]) == FaceGen.B_NONE:
			adult_none += 1
		if int(adult["beard"]) in [FaceGen.B_FULL, FaceGen.B_SHORT, FaceGen.B_BOXED, FaceGen.B_LONG]:
			adult_full += 1
	check(teen_beards <= 6, "barba demais aos 15 anos (%d)" % teen_beards)
	check(adult_none >= 40 and adult_full >= 25, "barbas adultas sem variedade (sem %d, cheias %d)" % [adult_none, adult_full])
	# O mesmo jogador envelhece com a mesma genética: a barba possível só cresce
	var young := FaceGen.features(4242, 3, 17)
	var grown := FaceGen.features(4242, 3, 30)
	check(float(grown["beard_cap"]) >= float(young["beard_cap"]), "barba regrediu com a idade")
	var lk := FaceGen.features(99, 1, 30, {"hs": FaceGen.H_MOHAWK, "bd": FaceGen.B_FULL, "hc": 6})
	check(int(lk["style"]) == FaceGen.H_MOHAWK and int(lk["beard"]) == FaceGen.B_FULL and int(lk["hair_i"]) == 6, "editor não fixa a aparência")
	# Overrides de clube aplicados na geração
	var c := Club.new()
	c.key = "__teste__"
	c.name = "Original"
	c.crest = {"shape": "round"}
	Overrides.data()["clubs"]["__teste__"] = {"name": "Editado", "c1": "#112233", "c2": "#FFFFFF"}
	Overrides.apply_club(c)
	Overrides.data()["clubs"].erase("__teste__")
	check(c.name == "Editado" and c.color1 == "#112233" and String(c.crest.get("c1", "")) == "#112233", "personalização de clube não aplicada")
	# Escudos: todos os clubes reais com escudo completo; saves antigos ganham o escudo novo
	var cw := WorldGenerator.generate(4242, "padrao")
	var real := 0
	var fla: Club = null
	for cl: Club in cw.clubs:
		check(cl.crest.has("field") and cl.crest.has("symbol") and cl.crest.has("c1"), "escudo incompleto: %s" % cl.name)
		if not cl.key.contains("_P"):
			real += 1
		if cl.key == "BRA_RNC":
			fla = cl
	check(real >= 600, "poucos clubes reais (%d)" % real)
	check(fla != null and String(fla.crest["field"]).begins_with("hoops") and String(fla.crest["initials"]) == "CRF", "escudo do Flamengo não veio do banco")
	fla.crest = {"shape": "round", "symbol": "star", "c1": fla.color1, "c2": fla.color2}
	ClubGenerator.upgrade_crests(cw)
	check(String(fla.crest.get("initials", "")) == "CRF" and fla.crest.has("field"), "save antigo não ganhou o escudo novo")


func _test_persona_trophies() -> void:
	var w := WorldGenerator.generate(4242, "padrao")
	# Veterano rodado vira cascudo com o tempo
	var vet: Player = null
	for p: Player in w.players.values():
		if p.age(w.year) >= 31 and p.traits.size() == 1 and not p.has_trait("inseguro") and not p.has_trait("timido") \
				and not p.has_trait("cascudo") and not p.has_trait("mentor") and not p.has_trait("lider") and not p.has_trait("idolo"):
			vet = p
			break
	check(vet != null, "sem veterano para testar")
	if vet != null:
		vet.career_apps = 400
		var got := false
		for _i in 40:
			PlayerDevelopment.personality_review(w)
			if vet.has_trait("cascudo") or vet.has_trait("mentor") or vet.has_trait("lider") or vet.has_trait("idolo"):
				got = true
				break
		check(got and not vet.persona_log.is_empty(), "veterano não ganhou traço de experiência")
		check(vet.traits.size() <= PlayerDevelopment.MAX_TRAITS, "traços demais")
		var d := Player.from_dict(vet.to_dict())
		check(d.persona_log.size() == vet.persona_log.size() and d.traits == vet.traits, "personalidade não sobreviveu ao save")
	# Lesão grave custa físico; lesão leve não
	var p2: Player = w.players.values()[10]
	var phys := 0
	for a in Attr.PHYSICAL:
		phys += p2.attrs[a]
	check(PlayerDevelopment.injury_setback(w.rng, p2, 3, 30) == 0, "lesão leve tirou físico")
	var lost := 0
	for _i in 5:
		lost += PlayerDevelopment.injury_setback(w.rng, p2, 20, 32)
	var phys2 := 0
	for a in Attr.PHYSICAL:
		phys2 += p2.attrs[a]
	check(lost > 0 and phys2 == phys - lost, "lesão grave sem efeito físico")
	# Troféus: cada liga resolve para um desenho e um nome
	var styles := {}
	for id in DatabaseManager.league_ids():
		var tv := TrophyView.make("L:" + id, 64, w)
		styles[tv._style] = true
		check(TrophyView.trophy_name("L:" + id, w).begins_with("Taça "), "troféu sem nome: %s" % id)
		tv.free()
	check(styles.size() >= 4, "troféus pouco variados (%d formatos)" % styles.size())
	# Passado real: campeões e títulos de antes do jogo
	var pre := 0
	for h in w.history:
		if h.get("pre", false):
			pre += 1
	check(pre >= 20, "passado anterior ao jogo curto (%d temporadas)" % pre)
	var liv := w.club_by_key("ENG_MSR")
	var rma := w.club_by_key("ESP_MBL")
	check(liv != null and liv.title_count("L:ENG1") == 20, "Liverpool sem os 20 títulos ingleses")
	check(rma != null and rma.title_count("C:UCL") == 15, "Real Madrid sem as 15 Champions")
	var h24: Dictionary = {}
	for h in w.history:
		if int(h["y"]) == 2024:
			h24 = h
	check(not h24.is_empty() and int(h24["leagues"]["ENG1"]["champion"]) == liv.id, "campeão inglês de 2024/25 errado")
	check(not h24.is_empty() and h24["leagues"].has("JPN1"), "liga sem dados reais sem passado gerado")
	var r1 := WorldGenerator.generate(4242, "padrao")
	check(_fingerprint(r1) == _fingerprint(WorldGenerator.generate(4242, "padrao")) and str(r1.history) == str(WorldGenerator.generate(4242, "padrao").history), "passado não determinístico")
	var cwc := TrophyView.make("W:CWC", 64, w)
	check(cwc._style == TrophyView.STYLE_GLOBE, "Mundial sem o troféu do globo")
	cwc.free()


func _test_tactics() -> void:
	var w := WorldGenerator.generate(777, "padrao")
	# Filosofias: estáveis, válidas e variadas.
	var seen := {}
	for c: Club in w.clubs:
		var id := ClubPhilosophy.id_of(c)
		seen[id] = int(seen.get(id, 0)) + 1
		check(ClubPhilosophy.ids().has(id), "filosofia inválida: %s" % id)
		check(ClubPhilosophy.pick_for(c) == id, "filosofia não é estável para %s" % c.short_name)
	check(seen.size() >= 8, "filosofias pouco variadas: %s" % str(seen))
	var top := 0
	for k in seen:
		top = maxi(top, seen[k])
	check(top < w.clubs.size() * 0.35, "uma filosofia domina o mundo: %s" % str(seen))
	for code in ["ESP", "ITA", "GER", "BRA"]:
		var by := {}
		for c: Club in w.clubs:
			if c.nation == code:
				by[c.philosophy] = int(by.get(c.philosophy, 0)) + 1
		check(by.size() >= 3, "%s com filosofias pouco variadas: %s" % [code, str(by)])
	# Tática da IA varia conforme o adversário (favorito × azarão).
	var cl := w.clubs_in_league("ENG1")
	cl.sort_custom(func(a, b): return ClubAI.team_strength(w, a) > ClubAI.team_strength(w, b))
	var strong: Club = cl[0]
	var weak: Club = cl[cl.size() - 1]
	var s1 := ClubAI.prepare_ai_sheet(w, weak, strong, false).duplicate_sheet()
	check(s1.mentality <= int(ClubPhilosophy.of(weak)["mentality"]), "azarão não se protegeu")
	var s2 := ClubAI.prepare_ai_sheet(w, strong, weak, true)
	check(s2.mentality >= 3, "favorito em casa não foi para cima (%d)" % s2.mentality)
	var styles := {}
	var forms := {}
	for c: Club in w.clubs:
		var opp: Club = w.clubs[(c.id + 7) % w.clubs.size()]
		var sh := ClubAI.prepare_ai_sheet(w, c, opp, true)
		styles[sh.style] = true
		forms[sh.formation] = true
	check(styles.size() == 6, "a IA não usa todos os estilos: %s" % str(styles.keys()))
	check(forms.size() >= 7, "a IA usa poucas formações: %s" % str(forms.keys()))
	# Entrosamento: aprende o que usa, esquece o resto, e pesa no jogo.
	var c := strong
	c.tactic_fam = {}
	TacticsManager.ensure(c)
	var f0 := c.sheet.formation
	var other := "3-5-2" if f0 != "3-5-2" else "4-4-2"
	check(TacticsManager.formation_fam(c, other) == TacticsManager.FAM_FLOOR, "formação nova deveria começar do zero")
	var sh2 := c.sheet.duplicate_sheet()
	sh2.formation = other
	var low := TacticsManager.fam_factor(c, sh2)
	for i in 12:
		TacticsManager.after_match(c, sh2)
	check(TacticsManager.formation_fam(c, other) > 70.0, "formação não aprendida em 12 jogos (%.1f)" % TacticsManager.formation_fam(c, other))
	check(TacticsManager.formation_fam(c, f0) < TacticsManager.FAM_START, "formação antiga não foi esquecida")
	check(TacticsManager.fam_factor(c, sh2) > low, "entrosamento não melhora o time")
	var d := Club.from_dict(c.to_dict())
	check(d.tactic_fam == c.tactic_fam and d.philosophy == c.philosophy, "entrosamento/filosofia não sobrevivem ao save")
	# Plano de jogo do usuário muda a mentalidade sozinho e o ao vivo segue igual ao instantâneo.
	var h: Club = cl[3]
	var a: Club = cl[4]
	w.user_club_id = h.id
	var changed := 0
	for s in 12:
		var hs := ClubAI.prepare_ai_sheet(w, h, a, true).duplicate_sheet()
		hs.mentality = TeamSheet.MENT_EQUILIBRADA
		hs.plan_losing = TeamSheet.MENT_TUDO
		hs.plan_winning = TeamSheet.MENT_RETRANCA
		hs.plan_minute = 60
		var as_ := ClubAI.prepare_ai_sheet(w, a, h, false)
		var ctx := {"derby": false, "importance": 0.3, "attendance": 10000, "competition": "F", "ko": false, "agg": [0, 0]}
		var m1 := MatchSimulation.new()
		m1.setup(w, h, a, hs, as_, ctx, 500 + s, true)
		var steps := 0
		while not m1.finished and steps < 600:
			m1.step()
			steps += 1
		var m2 := MatchSimulation.new()
		m2.setup(w, h, a, hs, as_, ctx, 500 + s, false)
		m2.run_to_end()
		check(m1.score == m2.score and _goal_log(m1) == _goal_log(m2), "plano: ao vivo ≠ instantâneo (seed %d)" % (500 + s))
		var t: MatchTeam = m2.teams[0]
		var diff: int = m2.score[0] - m2.score[1]
		# Gol no último lance: o plano ainda não teve minuto para reagir ao placar final.
		if diff < 0 and t.plan_state == 0:
			check(t.mentality == TeamSheet.MENT_TUDO, "perdendo e o plano não foi para o tudo ou nada")
			changed += 1
		elif diff > 0 and t.plan_state == 2:
			check(t.mentality == TeamSheet.MENT_RETRANCA, "vencendo e o plano não fechou o time")
			changed += 1
	check(changed > 0, "plano de jogo nunca agiu")
	w.user_club_id = -1
	# Leitura do auxiliar e estilos de jogadores.
	var sug := TacticsManager.suggest(w, weak, strong, false)
	check(int(sug["mentality"]) <= TeamSheet.MENT_EQUILIBRADA and not Array(sug["reasons"]).is_empty(), "auxiliar sugeriu atacar como azarão")
	var ps := {}
	for p: Player in w.players.values():
		ps[PlayStyle.of(p)] = true
	check(ps.size() >= 25, "poucos estilos de jogador (%d)" % ps.size())


func _test_squad_mgmt() -> void:
	var w := _career_world()
	var c := w.user_club()
	var squad := w.squad(c)
	squad.sort_custom(func(a, b): return a.ovr_f < b.ovr_f)
	var p: Player = squad[squad.size() - 1]
	# Rebaixar um titular derruba a moral; promover anima.
	p.squad_status = Player.STATUS_STARTER
	p.morale = 70.0
	check(SquadManager.set_status(w, c, p, Player.STATUS_BACKUP) == "", "rebaixamento recusado")
	check(p.morale < 60.0 and p.squad_status == Player.STATUS_BACKUP, "rebaixar não mexeu na moral (%.1f)" % p.morale)
	var m0 := p.morale
	SquadManager.set_status(w, c, p, Player.STATUS_STARTER)
	check(p.morale > m0, "promover não animou")
	# Limite de estrelas e promessas só para jovens.
	for q: Player in squad:
		q.squad_status = Player.STATUS_STAR if q != squad[0] and squad.find(q) >= squad.size() - SquadManager.MAX_STARS else q.squad_status
	check(SquadManager.set_status(w, c, squad[0], Player.STATUS_STAR) != "", "passou do limite de estrelas")
	var old: Player = null
	for q: Player in squad:
		if q.age(w.year) > 25:
			old = q
			break
	if old != null:
		check(SquadManager.set_status(w, c, old, Player.STATUS_PROSPECT) != "", "veterano virou promessa")
	# Profundidade cobre todas as linhas.
	var dep := SquadManager.depth(w, c)
	check(dep.size() == SquadManager.DEPTH_ROWS.size(), "profundidade incompleta")
	check(not Array(dep[0]["best"]).is_empty(), "sem goleiro na profundidade")
	# Poupar cansados troca só quem está esgotado.
	c.sheet = ClubAI.auto_sheet(w, c, "")
	var tired: Player = w.player(c.sheet.starters[5])
	tired.condition = 55.0
	var msgs := SquadManager.rest_tired(w, c, c.sheet, 80.0, 30.0)
	check(not c.sheet.starters.has(tired.id) and msgs.size() >= 1, "cansado não foi poupado")
	var ids := {}
	for pid in c.sheet.starters:
		check(not ids.has(pid), "jogador repetido na escalação depois do rodízio")
		ids[pid] = true


func _test_preseason() -> void:
	var w := _season_world
	if w == null:
		w = WorldGenerator.generate(4242, "padrao")
		_with_user(w, w.clubs_in_league("BRA1")[5].id)
	var club := w.user_club()
	check(not PreseasonManager.is_active(w) or w.season.turn == 0, "pré-temporada ativa com jogos disputados")
	PreseasonManager.open(w)
	check(PreseasonManager.is_active(w), "pré-temporada não abriu")
	var pre := PreseasonManager.state(w)
	check((pre["opponents"] as Array).size() == 3, "pré-temporada sem 3 adversários (%d)" % (pre["opponents"] as Array).size())
	for oid in pre["opponents"]:
		check(int(oid) != club.id and w.club(int(oid)).league_id != club.league_id, "amistoso contra time da mesma liga")
	var plan := PreseasonManager.squad_plan(w)
	check(plan.size() == 4, "raio-x deveria ter 4 setores")
	for g in plan:
		check(float(g["quality"]) > 20.0 and float(g["league"]) > 20.0, "raio-x com qualidade inválida no setor %d" % int(g["group"]))
	var notes := PreseasonManager.squad_notes(w)
	check(notes.has("expiring") and notes.has("prospects"), "pendências do elenco incompletas")
	var coh := club.cohesion
	var out := PreseasonManager.choose_camp(w, "tatica")
	check(not out.is_empty() and club.cohesion > coh, "intertemporada tática não subiu o entrosamento")
	check(PreseasonManager.choose_camp(w, "fisica").is_empty(), "segunda intertemporada no mesmo ano")
	var goals := {}
	for p in w.squad(club):
		goals[p.id] = p.stats[Player.S_GOALS]
	var res := PreseasonManager.play_friendlies(w)
	check(res.size() == 3, "amistosos: %d resultados" % res.size())
	check(PreseasonManager.play_friendlies(w).is_empty(), "amistosos jogados duas vezes")
	for p in w.squad(club):
		check(p.stats[Player.S_GOALS] == int(goals[p.id]), "amistoso contou gols na liga")
	check(PreseasonManager.steps(w) == [false, true, true], "passos da pré-temporada")
	# Sobrevive ao save
	var d := w.to_dict()
	var w2 := GameWorld.from_dict(d)
	check(PreseasonManager.is_active(w2) and String(PreseasonManager.state(w2)["camp"]) == "tatica", "pré-temporada perdida no save")
	PreseasonManager.finish(w)
	check(not PreseasonManager.is_active(w), "pré-temporada não encerrou")


func _test_second_cups() -> void:
	var w := WorldGenerator.generate(4242, "padrao")
	for cid in ["UEL", "UECL", "SUD"]:
		check(w.season.cups.has(cid) and w.season.cups[cid].club_ids.size() == 32, "%s sem 32 clubes" % cid)
	var seen := {}
	for cid in w.season.cups:
		if not CupManager.is_international(cid):
			continue
		for club in w.season.cups[cid].club_ids:
			check(not seen.has(club), "clube em duas copas continentais")
			seen[club] = true
	# O melhor brasileiro vai para a Libertadores; o 8º (depois das 7 vagas) para a Sul-Americana.
	var bra := w.league("BRA1")
	var bands := CupManager.qualification_bands(bra)
	check(bands.size() == 2 and bands[0]["cup"] == "LIB" and int(bands[1]["from"]) == 8 and int(bands[1]["to"]) == 13, "faixas do Brasileirão erradas")
	check(CupManager.cup_for_position(w.league("ENG1"), 6) == "UEL" and CupManager.cup_for_position(w.league("ENG1"), 7) == "UECL", "faixas da Premier League erradas")
	# Campeão da Europa League sobe para a Liga dos Campeões no ano seguinte.
	var uel: Cup = w.season.cups["UEL"]
	uel.champion = uel.club_ids[0]
	var q := CupManager.compute_qualified(w)
	check(q["UCL"].has(uel.champion) and not q["UEL"].has(uel.champion), "campeão da Europa League fora da Liga dos Campeões")
	var all := {}
	for cid in q:
		for club in q[cid]:
			check(not all.has(club), "classificado em duas copas")
			all[club] = true


func _test_national_teams() -> void:
	var w := WorldGenerator.generate(9090, "padrao")
	_with_user(w, w.clubs_in_league("BRA1")[0].id)
	var dates: Array = DatabaseManager.international_cfg()["fifa_dates"]
	var elo_before := NationalTeamManager.elo_of(w, "BRA")
	var tours := {}
	for y in range(2026, 2030):
		w.year = y
		NationalTeamManager.start_season(w)
		for d in dates:
			NationalTeamManager.after_weekend(w, int(d))
		for camp in NationalTeamManager.data(w)["camps"]:
			if int(camp["end"]) == y:
				check(bool(camp["done"]), "%s não terminou na temporada" % camp["name"])
				check((camp["q"] as Array).size() == int(camp["spots"]), "%s: %d classificados (esperado %d)" % [camp["name"], (camp["q"] as Array).size(), int(camp["spots"])])
		for rec in NationalTeamManager.play_summer(w):
			tours[String(rec["t"]) + str(rec["y"])] = rec
	for key in ["AFCON2027", "ASIAN2027", "GOLD2027", "EURO2028", "CA2028", "AFCON2029", "GOLD2029", "WC2030"]:
		check(tours.has(key), "torneio %s não foi disputado" % key)
	if tours.has("WC2030"):
		var wc: Dictionary = tours["WC2030"]
		check((wc["teams"] as Array).size() == 48 and wc["teams"].has("ESP"), "Copa do Mundo sem 48 seleções ou sem a sede")
		check((wc["ko"] as Array).size() == 5 and String(wc["champion"]) != "" and String(wc["runner_up"]) != "", "mata-mata da Copa incompleto")
		var uefa := 0
		for t in wc["teams"]:
			if DatabaseManager.nation(t).get("confed", "") == "UEFA":
				uefa += 1
		check(uefa == 16, "Europa com %d vagas na Copa" % uefa)
		check(not (wc["scorer"] as Dictionary).is_empty(), "Copa sem artilheiro")
	if tours.has("EURO2028"):
		var eu: Dictionary = tours["EURO2028"]
		check((eu["teams"] as Array).size() == 24 and eu["teams"].has("ENG"), "Eurocopa sem 24 seleções ou sem a sede")
	if tours.has("CA2028"):
		check((tours["CA2028"]["teams"] as Array).size() == 16, "Copa América sem 16 seleções")
	check(NationalTeamManager.elo_of(w, "BRA") != elo_before, "ranking não se mexeu")
	var r := NationalTeamManager.ranking(w)
	check(r.size() == DatabaseManager.nations().size() and float(r[0][1]) >= float(r[r.size() - 1][1]), "ranking incompleto")
	var capped := 0
	for p: Player in w.players.values():
		if NationalTeamManager.caps_of(w, p.id)[0] > 0:
			capped += 1
	check(capped > 500, "poucos jogadores com jogos pela seleção (%d)" % capped)
	# Save/load preserva o futebol de seleções.
	var w2 := GameWorld.from_dict(w.to_dict())
	check(NationalTeamManager.data(w2)["tours"].size() == NationalTeamManager.data(w)["tours"].size(), "save perdeu os torneios")


func _test_people() -> void:
	var w := _career_world()
	var c := w.user_club()
	People.ensure(w)
	var missing := 0
	for cl: Club in w.clubs:
		if w.is_user_club(cl.id):
			continue
		if People.coach_of(w, cl.id).is_empty():
			missing += 1
	check(missing == 0, "%d clube(s) sem técnico" % missing)
	check(People.coach_of(w, c.id).is_empty(), "o clube do usuário não deveria ter outro técnico")
	check(not People.president(w, c.id).is_empty(), "clube sem presidente")
	check(People.staff(w).size() == People.STAFF_ORDER.size(), "comissão incompleta (%d)" % People.staff(w).size())
	check(People.journalists(w).size() == 5, "deveria haver 5 jornalistas")
	for p: Player in w.squad(c):
		var t := People.trust_of(w, p)
		check(t >= 0.0 and t <= 100.0, "confiança fora da faixa")
	check(People.staff_wage_bill(w) <= People.staff_budget(w) * 1.5, "comissão inicial cara demais")
	# Contratar da lista de candidatos
	var cand: Dictionary = People.candidates(w, "medico")[2]
	var err := People.hire_staff(w, "medico", int(cand["id"]))
	check(err == "" and int(People.staff(w)["medico"]["id"]) == int(cand["id"]), "contratação da comissão falhou: %s" % err)
	# Troca de técnico na IA
	var ai: Club = w.clubs_in_league("BRA1")[0]
	if w.is_user_club(ai.id):
		ai = w.clubs_in_league("BRA1")[1]
	var old := People.coach_of(w, ai.id)
	var nc := People.replace_coach(w, ai, "resultados")
	check(int(nc["c"]) == ai.id and int(nc["id"]) != int(old["id"]), "troca de técnico não aconteceu")
	var in_free := false
	for f: Dictionary in People.data(w)["free"]:
		if int(f["id"]) == int(old["id"]):
			in_free = true
	check(in_free, "técnico demitido deveria ir para a lista de livres")
	# Sai um amigo, o outro sente
	var sq := w.squad(c)
	var a: Player = sq[0]
	var b: Player = sq[1]
	People.data(w)["bonds"].append({"a": a.id, "b": b.id, "k": People.BOND_FRIEND, "v": 60.0})
	var tb := People.trust_of(w, b)
	People.data(w)["squad"] = c.player_ids.duplicate()
	c.player_ids.erase(a.id)
	People._squad_changes(w, People.rng(w))
	c.player_ids.append(a.id)
	check(People.trust_of(w, b) < tb, "saída do amigo não afetou a confiança")
	# Save/load preserva as pessoas
	var w2 := GameWorld.from_dict(w.to_dict())
	check(var_to_str(w2.people) == var_to_str(w.people), "pessoas não sobrevivem ao save")
	# Ligar o sistema não muda os sorteios do mundo
	var st := w.rng.state
	People.after_matchday(w, [])
	Talks.start(w, "press")
	check(w.rng.state == st, "People/Talks consumiram o sorteio do mundo")


func _test_press_room() -> void:
	var w := _career_world()
	var c := w.user_club()
	w.season.turn = 10
	People.ensure(w)
	var js := People.journalists(w)
	var pred := PressRoom.ensure_predictions(w)
	check(Array(pred.get("list", [])).size() == js.size(), "palpites incompletos")
	var cons := PressRoom.consensus(w)
	check(cons >= 1 and cons <= 20, "consenso fora da tabela (%d)" % cons)
	var h := PressRoom.heat(w)
	check(h >= 0.0 and h <= 100.0, "termômetro fora da escala")
	var race := PressRoom.sack_race(w, 3)
	check(race.size() == 3 and float(race[0][2]) <= float(race[2][2]), "bolsa de apostas inválida")
	# Rumores e placar de acertos
	var r := People.rng(w, 1)
	var made := 0
	for i in 40:
		if not PressRoom.make_rumor(w, r).is_empty():
			made += 1
	check(made >= 5, "poucos rumores (%d)" % made)
	var x: Dictionary = People.data(w)["press"]["rum"][0]
	var j := People.journalist(w, int(x["j"]))
	var acc0 := PressRoom.accuracy(w, j)
	var t := Transfer.new()
	t.player_id = int(x["p"])
	t.to_id = int(x["to"])
	t.from_id = int(x["from"])
	PressRoom.on_transfer(w, t)
	check(String(x["st"]) == "hit" and PressRoom.accuracy(w, j) > acc0, "rumor confirmado não contou")
	PressRoom.on_window_close(w)
	w.season.turn += 3
	PressRoom.on_window_close(w)
	check(Array(People.data(w)["press"]["rum"]).filter(func(q): return String(q["st"]) == "open").is_empty(), "rumores abertos depois da janela")
	# Coletiva depois de goleada sofrida, com frase cobrada depois
	var opp: Club = w.clubs_in_league(c.league_id)[0] if w.clubs_in_league(c.league_id)[0].id != c.id else w.clubs_in_league(c.league_id)[1]
	People.data(w)["press"]["match"] = {"t": w.current_turn(), "res": "D", "gd": -4, "score": "0 x 4", "opp": opp.id, "derby": false,
		"hero": -1, "hr": 0.0, "red": c.player_ids[0], "asked": false}
	var conv := Talks.start(w, "press")
	check(bool(conv["d"].get("post", false)), "coletiva pós-jogo não reconhecida")
	var qtext := String(conv["lines"].back()[1])
	check(qtext.find("0 x 4") >= 0, "primeira pergunta não fala do jogo: %s" % qtext)
	Talks.choose(w, conv, "1") # "Tem jogador que precisa se olhar no espelho" (frase guardada)
	var guard := 0
	while not conv["done"] and guard < 5:
		Talks.choose(w, conv, "0")
		guard += 1
	check(conv["done"], "coletiva pós-jogo não terminou")
	var quotes: Array = People.data(w)["press"]["quotes"]
	check(quotes.size() >= 1 and String(quotes[0]["k"]) == "blame", "frase não guardada")
	check(w.news.back().category == "imprensa" and w.news.back().body.find("depois do jogo") >= 0, "manchete da coletiva ausente")
	quotes[0]["t"] = w.current_turn() - 5
	c.streak_wins = 3
	var qs := PressRoom.questions(w, func(_tone): return int(js[0]["id"]))
	check(qs.size() == 1 and String(qs[0]["q"]).find("cobrança") >= 0, "frase antiga não voltou na coletiva")
	check(PressRoom.questions(w, func(_tone): return int(js[0]["id"])).is_empty(), "cobrança repetida")
	# Fim de temporada: palpites conferidos
	var n0 := w.news.size()
	PressRoom.on_season_end(w, {"user": {"league": c.league_id, "pos": 3}})
	check(w.news.size() == n0 + 1 and w.news.back().title.find(c.short_name) >= 0, "balanço dos palpites ausente")


func _test_talks() -> void:
	var w := _career_world()
	var c := w.user_club()
	w.season.turn = 10
	People.ensure(w)
	var sq := w.squad(c)
	var n := 0
	for p: Player in sq.slice(0, 6):
		var conv := Talks.start(w, "player", p.id)
		for o in conv["opts"]:
			var topic := String(o["id"])
			if topic == "bye":
				continue
			People.data(w)["talk"].clear()
			var cv := Talks.start(w, "player", p.id)
			Talks.choose(w, cv, topic)
			check(not cv["done"] and Array(cv["opts"]).size() >= 2, "tópico %s sem opções" % topic)
			for tone in cv["opts"]:
				var cv2 := cv.duplicate(true)
				Talks.choose(w, cv2, String(tone["id"]))
				check(cv2["done"] and String(cv2["lines"].back()[1]) != "", "conversa %s/%s sem desfecho" % [topic, tone["id"]])
				n += 1
	check(n >= 40, "poucas combinações de conversa (%d)" % n)
	for topic in ["verba", "folha", "facilities", "youth", "staff", "cargo"]:
		for tone in ["a", "b", "c"]:
			People.data(w)["talk"].clear()
			var cv := Talks.start(w, "board")
			Talks.choose(w, cv, topic)
			if not cv["done"]:
				Talks.choose(w, cv, tone)
			check(cv["done"], "reunião %s não terminou" % topic)
	c.board_confidence = 25.0
	People.data(w)["reqs"] = [{"k": "board", "t": -1, "until": 99, "summon": true}]
	var sm := Talks.start(w, "board")
	check(sm["d"]["summon"], "convocação do presidente não reconhecida")
	Talks.choose(w, sm, "a")
	check(sm["done"], "convocação não terminou")
	for i in People.STAFF_ORDER.size():
		var cv := Talks.start(w, "staff", i)
		check(Array(cv["lines"]).size() >= 1, "relatório vazio da comissão")
		Talks.choose(w, cv, "a")
	var fans := Talks.start(w, "fans")
	Talks.choose(w, fans, "b")
	check(fans["done"], "conversa com a torcida não terminou")
	var rival: Club = w.club(c.main_rival()) if c.main_rival() >= 0 else w.clubs_in_league(c.league_id)[0]
	var co := Talks.start(w, "coach", rival.id)
	Talks.choose(w, co, "b")
	check(People.coach_rel(w, int(People.coach_of(w, rival.id)["id"])) < 0.0, "provocação não esfriou a relação")
	c.streak_losses = 3
	var press := Talks.start(w, "press")
	var guard := 0
	while not press["done"] and guard < 5:
		Talks.choose(w, press, "0")
		guard += 1
	check(press["done"] and guard >= 1, "coletiva não terminou")


func _test_mid_season_firing() -> void:
	var w := _career_world()
	var c := w.user_club()
	w.difficulty = GameWorld.DIFF_HARD
	People.ensure(w)
	w.season.turn = 12
	c.board_confidence = 4.0
	People.data(w)["ult"] = 5
	People.data(w)["fans"]["support"] = 30.0
	for i in 30:
		if w.stats.has("fired"):
			break
		People._check_job(w, People.rng(w))
	check(w.stats.has("fired") and bool(w.stats["fired"].get("mid", false)), "diretoria deveria demitir no meio da temporada")
	var offers := BoardManager.pending_job_offers(w)
	check(not offers.is_empty(), "sem propostas após a demissão")
	if offers.is_empty():
		return
	var old_id := c.id
	BoardManager.take_job(w, int(offers[0]))
	check(w.user_club_id == int(offers[0]), "não assumiu o clube novo")
	check(int(People.data(w)["uc"]) == w.user_club_id, "relações não migraram para o clube novo")
	check(not People.coach_of(w, old_id).is_empty(), "clube antigo ficou sem técnico")
	check(People.coach_of(w, w.user_club_id).is_empty(), "clube novo continua com o técnico antigo")
	# Com carência (pedido de tempo aceito) não há demissão
	var w2 := _career_world()
	w2.difficulty = GameWorld.DIFF_HARD
	var c2 := w2.user_club()
	w2.season.turn = 12
	c2.board_confidence = 4.0
	People.data(w2)["ult"] = 5
	People.data(w2)["grace"] = 20
	for i in 30:
		People._check_job(w2, People.rng(w2))
	check(not w2.stats.has("fired"), "demitiu durante a carência")
	# No fácil nunca
	var w3 := _career_world()
	w3.difficulty = GameWorld.DIFF_EASY
	w3.season.turn = 12
	w3.user_club().board_confidence = 1.0
	People.data(w3)["ult"] = 1
	for i in 30:
		People._check_job(w3, People.rng(w3))
	check(not w3.stats.has("fired"), "no fácil ninguém é demitido")
	# Temporada inteira: técnicos da IA caem e presidentes seguem no lugar
	var w4 := _career_world()
	People.ensure(w4)
	var before := {}
	for cl: Club in w4.clubs:
		before[cl.id] = int(People.coach_of(w4, cl.id).get("id", -1))
	_season(w4)
	var changes := 0
	for cl: Club in w4.clubs:
		if int(People.coach_of(w4, cl.id).get("id", -1)) != int(before[cl.id]):
			changes += 1
	print("   técnicos trocados na temporada: %d de %d clubes" % [changes, w4.clubs.size()])
	check(changes > 0 and changes < w4.clubs.size() / 3, "trocas de técnico fora do esperado (%d)" % changes)


func _test_mods() -> void:
	# Mesclagem de patches: objeto chave a chave, lista pelo campo _by, remoção.
	var base := {"cups": {"CDB": {"name": "Copa do Brasil", "two_legs": ["f"]}}, "list": [{"key": "A", "v": 1}, {"key": "B", "v": 2}]}
	var patch := {"cups": {"CDB": {"two_legs": ["sf", "f"]}}, "list": {"_by": "key", "items": [{"key": "A", "v": 9}, {"key": "C", "v": 3}], "remove": ["B"]}}
	var m: Dictionary = Mods.merge(base.duplicate(true), patch)
	check(m["cups"]["CDB"]["name"] == "Copa do Brasil" and m["cups"]["CDB"]["two_legs"] == ["sf", "f"], "patch de objeto mal mesclado")
	var keys: Array = m["list"].map(func(e): return e["key"])
	check(keys == ["A", "C"] and int(m["list"][0]["v"]) == 9, "patch de lista mal mesclado: %s" % [m["list"]])
	# Jogadores: novo, editado e removido, sem mexer no sorteio do mundo.
	var w := WorldGenerator.generate(555, "padrao")
	var fla := _club(w, "BRA_RNC")
	var n0 := fla.player_ids.size()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var marks := {}
	var used := WorldGenerator.used_names_of(w)
	PlayerMods._apply_one(w, rng, {"club": "BRA_RNC", "first": "Giorgian", "last": "de Arrascaeta", "known": "Arrascaeta",
		"nat": "URU", "pos": "MEI", "sec": ["MC"], "birth": 1994, "foot": "R", "ovr": 84, "shirt": 10}, used, marks)
	var arr := PlayerMods.find(w, fla, "Giorgian de Arrascaeta")
	check(arr != null and fla.player_ids.size() == n0 + 1, "jogador novo não entrou no elenco")
	if arr != null:
		check(arr.position == Pos.AM and arr.secondary == [Pos.CM] and arr.nationality == "URU" and arr.shirt == 10, "campos do jogador novo errados")
		check(absi(arr.overall - 84) <= 1 and arr.potential >= arr.overall and arr.value > 0, "overall do jogador novo %d (esperado 84)" % arr.overall)
	var victim: Player = w.squad(fla)[3]
	var vname := victim.first_name + " " + victim.last_name
	PlayerMods._apply_one(w, rng, {"club": "BRA_RNC", "match": vname, "known": "Editado", "attrs": {"FIN": 97}}, used, marks)
	check(victim.known_as == "Editado" and victim.attrs[Attr.FIN] == 97, "edição do jogador não aplicada")
	check(marks.has(str(victim.id)) and String(marks[str(victim.id)]) == "BRA_RNC/" + vname, "edição sem marca de origem")
	PlayerMods._apply_one(w, rng, {"club": "BRA_RNC", "match": vname, "remove": true}, used, marks)
	check(w.player(victim.id) == null and not fla.player_ids.has(victim.id), "jogador removido continua no mundo")
	check(PlayerMods.pos_from("ST") == Pos.ST and PlayerMods.pos_from("ZAG") == Pos.CB, "códigos de posição")


func _test_store() -> void:
	var st: Node = load("res://scripts/autoload/store.gd").new()
	var w := GameWorld.new()
	st.enforce_override = 0
	w.season_number = 3
	check(not st.locked(w), "fora da loja a carreira não pode travar")
	st.enforce_override = 1
	st.owned = false
	w.season_number = 1
	check(not st.locked(w), "a primeira temporada tem que ser grátis")
	w.season_number = 2
	check(st.locked(w), "a segunda temporada sem compra deveria travar")
	check(not st.locked(null), "sem carreira não há trava")
	st._handle({"purchase_state": 2, "product_ids": ["carreira_completa"], "purchase_token": "t"}, false)
	check(st.locked(w) and st.pending, "compra pendente não pode liberar")
	st._client = _FakeBilling.new()
	st._handle({"purchase_state": 1, "product_ids": ["carreira_completa"], "purchase_token": "t", "is_acknowledged": false}, false)
	check(not st.locked(w), "compra confirmada tem que liberar")
	check(st._client.acked == ["t"], "a compra precisa ser confirmada (acknowledge) na Play")
	st._handle({"purchase_state": 1, "product_ids": ["cafe"], "purchase_token": "c"}, false)
	check(st._client.consumed == ["c"], "o café precisa ser consumido para poder comprar de novo")
	st._on_purchases_query({"response_code": 0, "purchases": []})
	check(st.locked(w), "compra reembolsada tem que voltar a travar")
	st._on_purchases_query({"response_code": 2})
	check(st.locked(w), "sem conexão mantém o estado salvo")
	st.owned = true
	st._on_purchases_query({"response_code": 6})
	check(not st.locked(w), "erro da Play não pode tirar uma compra salva")
	st.free()


class _FakeBilling:
	extends RefCounted
	var acked: Array = []
	var consumed: Array = []

	func acknowledge_purchase(t: String) -> void:
		acked.append(t)

	func consume_purchase(t: String) -> void:
		consumed.append(t)


func _test_rivalry() -> void:
	var w := _career_world()
	var user := w.user_club()
	# Um adversário da mesma liga que não é rival de origem
	var opp: Club = null
	for cid in w.clubs_in_league(user.league_id):
		var c: Club = cid if cid is Club else w.club(int(cid))
		if c.id != user.id and not c.is_rival(user.id) and not user.is_rival(c.id):
			opp = c
			break
	check(opp != null, "sem adversário para o teste")
	if opp == null:
		return
	check(not MatchEngine.is_derby(w, user.id, opp.id), "par sem história já nasce clássico")
	var att0 := Rivalry.attendance_factor(w, user.id, opp.id, false)
	# Eliminado três vezes, perde o capitão para eles e depois perde a final
	Rivalry.add(w, user.id, opp.id, 10.0, "%s elimina o %s" % [opp.short_name, user.short_name], "elim", opp.id)
	check(Rivalry.level_of(Rivalry.heat(w, user.id, opp.id)) == 0, "uma eliminação já virou rixa")
	Rivalry.add(w, user.id, opp.id, 16.0, "%s elimina o %s de novo" % [opp.short_name, user.short_name], "elim", opp.id)
	check(Rivalry.heat(w, user.id, opp.id) >= Rivalry.RIXA_AT, "duas eliminações não criaram rixa")
	var cap := w.squad(user)[0] as Player
	user.sheet.captain = cap.id
	var news0 := w.news.size()
	TransferManager.complete_transfer(w, cap, opp, 1000000, cap.wage, 3)
	var rng0 := w.rng.state
	Rivalry.add(w, user.id, opp.id, 17.0, "%s vence o %s na final" % [opp.short_name, user.short_name], "final", opp.id)
	var h := Rivalry.heat(w, user.id, opp.id)
	check(h >= Rivalry.DERBY_AT, "história não virou clássico (%.1f)" % h)
	check(MatchEngine.is_derby(w, user.id, opp.id) and MatchEngine.is_derby(w, opp.id, user.id), "clássico emergente não conta como clássico")
	check(Rivalry.is_emergent_derby(w, user.id, opp.id), "clássico emergente não reconhecido")
	var found := false
	for i in range(news0, w.news.size()):
		var n: NewsEvent = w.news[i]
		if n.category == "rivalidade" and n.title.contains("clássico"):
			found = true
	check(found, "imprensa não noticiou o novo clássico")
	var ev: Array = Rivalry.get_rec(w, user.id, opp.id)["ev"]
	var has_transfer := false
	for e: Dictionary in ev:
		if String(e["k"]) == "transferencia":
			has_transfer = true
	check(has_transfer, "ida do capitão para o rival não entrou na história")
	check(Rivalry.attendance_factor(w, user.id, opp.id, true) >= 1.0 and Rivalry.attendance_factor(w, user.id, opp.id, false) > att0, "rivalidade não mexeu no público")
	check(Rivalry.memory_line(w, user.id, opp.id).begins_with("Revanche"), "prévia não lembra a revanche")
	check(Rivalry.of_club(w, user.id).any(func(e): return int(e["club"]) == opp.id), "rivalidade fora da lista do clube")
	check(w.rng.state == rng0, "rivalidade consumiu o RNG do mundo")
	# Save guarda a rivalidade
	var w2 := GameWorld.from_dict(JSON.parse_string(JSON.stringify(w.to_dict())))
	check(absf(Rivalry.heat(w2, user.id, opp.id) - h) < 0.01 and MatchEngine.is_derby(w2, user.id, opp.id), "save perdeu a rivalidade")
	# O tempo esfria; rivais de origem nunca caem abaixo do piso
	for i in 8:
		Rivalry.season_close(w)
	check(Rivalry.heat(w, user.id, opp.id) < Rivalry.DERBY_AT, "rivalidade não esfriou com o tempo")
	var orig := user.main_rival()
	if orig >= 0:
		check(Rivalry.heat(w, user.id, orig) >= Rivalry.STATIC_FLOOR, "rival de origem esfriou abaixo do piso")
	# Uma temporada inteira: o mundo cria rivalidades sozinho (copas, títulos, goleadas)
	var sw := _season_world
	if sw == null:
		sw = WorldGenerator.generate(777, "padrao")
		_with_user(sw, sw.clubs_in_league("BRA1")[3].id)
		_season(sw)
	check(not sw.rivalries.is_empty(), "nenhuma rivalidade registrada na temporada")
	var kinds := {}
	var hot := 0
	for k in sw.rivalries:
		var r: Dictionary = sw.rivalries[k]
		if float(r["s"]) >= Rivalry.RIXA_AT and not Rivalry._is_static(sw, int(r["a"]), int(r["b"])):
			hot += 1
		for e: Dictionary in r["ev"]:
			kinds[String(e["k"])] = true
	check(kinds.has("elim") and kinds.has("final"), "copas não alimentaram rivalidades: %s" % str(kinds.keys()))
	var n0 := sw.rivalries.size()
	var rv2: Dictionary = JSON.parse_string(JSON.stringify(sw.rivalries))
	var sw2 := GameWorld.new()
	sw2.clubs = sw.clubs
	sw2.rivalries = rv2
	Rivalry.season_close(sw2)
	var bytes := JSON.stringify(sw2.rivalries).length()
	check(sw2.rivalries.size() < n0, "virada de ano não esqueceu rixas pequenas")
	check(bytes < 400000, "rivalidades pesam demais no save (%d bytes)" % bytes)
	print("   depois da virada: %d (%d KB)" % [sw2.rivalries.size(), bytes / 1024])
	print("   rivalidades: %d registradas, %d rixas novas, tipos %s" % [sw.rivalries.size(), hot, str(kinds.keys())])
func _test_inbox() -> void:
	var w := _career_world()
	InboxManager.on_new_job(w)
	check(w.inbox.size() >= 2, "sem boas-vindas na caixa de entrada (%d)" % w.inbox.size())
	check(String(w.inbox[0]["f"]) == "presidente", "a primeira mensagem não é do presidente")
	# Joga até o 13º jogo do usuário: relatórios, olheiro e diretoria.
	var guard := 0
	while w.current_turn() < 13 and guard < 80:
		SeasonManager.play_matchday_instant(w)
		guard += 1
	var from := {}
	var broken := 0
	for m: Dictionary in w.inbox:
		from[String(m["f"])] = true
		var txt := String(m["s"]) + String(m["b"])
		if txt.contains("{") or txt.contains("%d") or txt.contains("%s") or String(m["s"]).strip_edges() == "" or String(m["n"]).strip_edges() == "":
			broken += 1
	check(broken == 0, "%d mensagens com texto quebrado" % broken)
	check(from.has("auxiliar"), "sem relatório do auxiliar")
	check(from.has("olheiro"), "sem relatório do olheiro")
	check(from.has("presidente"), "sem carta do presidente")
	check(InboxManager.unread_count(w) == w.inbox.size(), "mensagens novas deveriam estar não lidas")
	# Decisões da carreira viram mensagens com resposta pendente enquanto o evento existir.
	var ev := EventManager._build(w, "raise")
	if not ev.is_empty():
		ev["id"] = 9999
		ev["turn"] = w.current_turn()
		ev["exp"] = w.current_turn() + 3
		w.events.append(ev)
		InboxManager.on_event(w, ev)
		var m: Dictionary = w.inbox.back()
		check(InboxManager.action_open(w, m), "decisão pendente não aparece como aberta")
		EventManager.resolve(w, ev, 0)
		check(not InboxManager.action_open(w, m), "decisão resolvida continua aberta")
	# Não mexe no sorteio da simulação.
	var st := w.rng.state
	InboxManager.scout_report(w)
	InboxManager.after_user_turn(w, {}, {})
	check(w.rng.state == st, "a caixa de entrada consumiu o rng do mundo")
	# Save e load preservam as mensagens.
	var n := w.inbox.size()
	InboxManager.mark_read(w.inbox[0])
	var l := GameWorld.from_dict(w.to_dict())
	check(l.inbox.size() == n, "save perdeu mensagens (%d de %d)" % [l.inbox.size(), n])
	check(bool(l.inbox[0]["r"]), "save perdeu o estado de lida")
	InboxManager.mark_all_read(w)
	check(InboxManager.unread_count(w) == 0, "marcar todas como lidas falhou")
	InboxManager.delete_read(w)
	for m: Dictionary in w.inbox:
		check(InboxManager.action_open(w, m), "limpar lidas apagou mensagem que pede resposta")
func _test_coach_identity() -> void:
	var w := WorldGenerator.generate(4242, "padrao")
	var user := _with_user(w, w.clubs_in_league("BRA1")[8].id)
	check(CoachIdentity.titles(w).is_empty(), "carreira nova não deveria ter reputação")
	check(CoachIdentity.headline(w) == "", "sem título principal no começo")
	check((CoachIdentity.mem(w)["jobs"] as Array).size() == 1, "o primeiro emprego deveria ser registrado")
	# 20 jogos no 4-3-3 com pressão alta
	user.sheet.formation = "4-3-3"
	user.sheet.pressing = 2
	for i in 20:
		CoachIdentity.on_match(w, user)
	var ids := {}
	for t in CoachIdentity.titles(w):
		ids[t["id"]] = true
	check(ids.has("pressao"), "20 jogos pressionando deveriam render 'Técnico de pressão alta'")
	check(ids.has("fiel"), "20 jogos no 4-3-3 deveriam render 'Fiel ao 4-3-3'")
	# 6 reforços de até 21 anos
	var kids: Array = []
	for p: Player in w.players.values():
		if p.club_id >= 0 and p.club_id != user.id and p.age(w.year) <= 21 and p.loan.is_empty():
			kids.append(p)
		if kids.size() >= 7:
			break
	for i in 6:
		TransferManager.complete_transfer(w, kids[i], user, 0, kids[i].wage, 3)
	var probe: Player = kids[6]
	var jovens := false
	for t in CoachIdentity.titles(w):
		jovens = jovens or t["id"] == "jovens"
	check(jovens, "6 reforços garotos deveriam render 'Especialista em jovens'")
	check(CoachIdentity.interest_delta(w, probe, user) > 0.0, "garotos deveriam gostar mais de assinar com o especialista em jovens")
	check(CoachIdentity.interest_delta(w, probe, w.clubs[0] if w.clubs[0].id != user.id else w.clubs[1]) == 0.0, "reputação do usuário não muda o interesse por outros clubes")
	# Venda registrada com idade
	var seller_p := world_player_of(w, user)
	TransferManager.complete_transfer(w, seller_p, w.clubs_in_league("BRA1")[0], 3_000_000, seller_p.wage, 3)
	check(int(CoachIdentity.mem(w)["sell_paid"]) == 1, "venda do usuário não registrada")
	check(not CoachIdentity.habits(w).is_empty(), "hábitos deveriam aparecer")
	# Fim de temporada: a imprensa anuncia uma vez só
	var news0 := w.news.size()
	var fresh := CoachIdentity.on_season_end(w, {"pos": 5, "champion": false, "cups": []}, user.reputation)
	check(fresh.size() >= 3, "títulos novos deveriam ser anunciados (%d)" % fresh.size())
	check(w.news.size() > news0, "a imprensa deveria noticiar a reputação nova")
	check(CoachIdentity.on_season_end(w, {"pos": 5, "champion": false, "cups": []}, user.reputation).is_empty(), "título já conhecido não vira notícia de novo")
	# Emprego novo: clubes que combinam com o perfil lembram de você
	var formador: Club = null
	var other: Club = null
	for c: Club in w.clubs:
		if c.nation != user.nation and c.archetype == "formador" and formador == null:
			formador = c
		if c.nation != user.nation and c.archetype == "gigante_endividado" and other == null:
			other = c
	var ctx := CoachIdentity.job_context(w)
	if formador != null and other != null:
		check(CoachIdentity.job_score(ctx, formador) > CoachIdentity.job_score(ctx, other), "clube formador deveria preferir o especialista em jovens")
	BoardManager.take_job(w, w.clubs_in_league("BRA1")[15].id)
	var jobs: Array = CoachIdentity.mem(w)["jobs"]
	check(jobs.size() == 2 and int(jobs[0]["to"]) > 0, "troca de clube deveria fechar o emprego antigo e abrir o novo")
	# Save/load
	var w2 := GameWorld.from_dict(w.to_dict())
	check(CoachIdentity.headline(w2) == CoachIdentity.headline(w), "a reputação deveria sobreviver ao save")


func world_player_of(w: GameWorld, c: Club) -> Player:
	for p in w.squad(c):
		if p.loan.is_empty():
			return p
	return null


func _test_club_dna() -> void:
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	var st := w.rng.state
	var recs := {}
	var bad := 0
	for c: Club in w.clubs:
		var d := ClubDNA.of(c)
		recs[String(d["rec"])] = int(recs.get(String(d["rec"]), 0)) + 1
		if ClubDNA.info("rec", String(d["rec"])).is_empty() or ClubDNA.info("mkt", String(d["mkt"])).is_empty() or ClubDNA.info("tac", String(d["tac"])).is_empty():
			bad += 1
		for k in ClubDNA.PARAMS:
			if float(d[k]) < 0.0 or float(d[k]) > 100.0:
				bad += 1
	check(bad == 0, "%d DNA(s) inválido(s)" % bad)
	check(recs.size() >= 5, "pouca variedade de filosofias de elenco: %s" % str(recs))
	check(w.rng.state == st, "gerar o DNA consumiu o sorteio do mundo")
	# Mesmo mundo, mesmo DNA.
	var w2 := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	var same := true
	for i in 40:
		var a: Club = w.clubs[i * 7 % w.clubs.size()]
		if var_to_str(ClubDNA.of(a)) != var_to_str(ClubDNA.of(w2.club(a.id))):
			same = false
	check(same, "DNA não é determinístico")
	# Gigantes olham o mundo; clubes de divisões baixas, o próprio país.
	var big: Club = w.clubs_in_league("ENG1")[0]
	var wide := 0
	var top_n := 0
	for c: Club in w.clubs_in_league("ENG1"):
		top_n += 1
		if ["global", "continental"].has(ClubDNA.mkt(c)):
			wide += 1
	check(wide * 2 > top_n, "clubes ingleses deveriam ter mercado amplo (%d/%d)" % [wide, top_n])
	var low_home := 0
	var low_n := 0
	for c: Club in w.clubs:
		if c.tier >= 3:
			low_n += 1
			if ["domestico", "regional"].has(ClubDNA.mkt(c)):
				low_home += 1
	check(low_n == 0 or low_home * 10 >= low_n * 7, "clubes pequenos com mercado amplo demais (%d/%d)" % [low_home, low_n])
	# Filosofia de elenco muda o mercado: quem vende jovens cede mais barato; quem é ambicioso segura.
	var kid: Player = null
	for q: Player in w.squad(big):
		if q.age(w.year) <= 21:
			kid = q
	if kid != null:
		big.dna["sell"] = 90.0
		big.dna["amb"] = 50.0
		var easy := ClubDNA.sell_mult(w, big, kid)
		big.dna["sell"] = 10.0
		check(ClubDNA.sell_mult(w, big, kid) > easy * 1.3, "venda de jovens não muda o preço")
	var spender: Club = w.clubs_in_league("ESP1")[3]
	spender.dna["fin"] = 95.0
	var sm := ClubDNA.spend_mult(spender)
	spender.dna["fin"] = 5.0
	check(sm > ClubDNA.spend_mult(spender) * 1.5, "apetite financeiro não muda o orçamento")
	# Dono rico compra o clube: novo rico, estrelas, cofre aberto e mercado mais amplo.
	var target: Club = w.clubs_in_league("POR1")[10]
	var mk0 := ClubDNA.MKT_ORDER.find(ClubDNA.mkt(target))
	WorldEvents.takeover(w, target, "Grupo Teste")
	check(ClubDNA.era(target) == "novo_rico" and ClubDNA.rec(target) == "estrelas" and ClubDNA.val(target, "fin") >= 85.0, "compra do clube não mudou o DNA: %s" % str(target.dna))
	check(ClubDNA.MKT_ORDER.find(ClubDNA.mkt(target)) >= mk0 and not ClubDNA.log_of(target).is_empty(), "compra do clube fora da linha do tempo")
	# Presidente da austeridade fecha o cofre.
	var pc: Club = w.clubs_in_league("ITA1")[6]
	var fin0 := ClubDNA.val(pc, "fin")
	ClubDNA.on_president(w, pc, "promete austeridade")
	check(ClubDNA.val(pc, "fin") < fin0, "presidente não mudou o apetite financeiro")
	# Técnico novo: a escola do clube costuma prevalecer.
	var school := 0
	var sc: Club = w.clubs_in_league("GER1")[4]
	var fam: Array = ClubDNA.info("tac", ClubDNA.tac(sc)).get("ph", [])
	for _k in 30:
		People.replace_coach(w, sc, "resultados")
		if fam.has(sc.philosophy):
			school += 1
	check(school >= 15, "a escola do clube não sobrevive aos técnicos (%d/30)" % school)
	check(int(sc.dna.get("cc", 0)) >= 30, "trocas de técnico não contadas no DNA")
	# Temporada inteira: o DNA registra o ano, e a dívida alta leva à crise.
	_season(w)
	var broke: Club = w.clubs_in_league("ARG1")[2]
	broke.balance = -FinanceManager.expected_revenue(broke) * 2
	broke.dna["since"] = w.year - 5
	ClubDNA.season_end(w, {})
	check(ClubDNA.era(broke) == "crise", "clube afundado em dívida não entrou em crise (%s)" % ClubDNA.era(broke))
	check(ClubDNA.of(big)["h"].size() == 1, "temporada não registrada no DNA")
	# Save/load preserva o DNA.
	var w3 := GameWorld.from_dict(w.to_dict())
	check(var_to_str(w3.club(broke.id).dna) == var_to_str(broke.dna), "DNA não sobrevive ao save")
