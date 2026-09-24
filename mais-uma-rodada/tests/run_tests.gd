extends SceneTree
## Testes automáticos do núcleo do jogo (sem interface).
## Uso: godot --headless --path . --script res://tests/run_tests.gd
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
	_run("temporada completa, copas e Mundial", _test_season_cycle)
	_run("virada de ano: acessos, quedas e vagas", _test_end_season)
	_run("avanço até o próximo jogo do usuário", _test_advance)
	_run("save/load (ida e volta, backup e determinismo)", _test_save_load)
	_run("negociações do usuário", _test_transfers)
	_run("diretoria: ultimato, demissão e novo clube", _test_board)
	_run("valores e salários", _test_valuation)
	_run("notícias com dados reais", _test_news)
	_run("eventos com escolhas e promessas", _test_events)
	_run("treino, base e liga sub-20", _test_training_youth)
	_run("empréstimos, parcelas e cláusulas", _test_deals)
	_run("rostos e personalização", _test_faces)
	_run("trocas, oferecer jogador e contrapropostas", _test_trades)
	_run("patrocínios e uniformes da pré-temporada", _test_sponsors)
	_run("personalidade, lesões graves e troféus", _test_persona_trophies)
	_run("táticas: entrosamento, plano de jogo e filosofias", _test_tactics)
	_run("elenco: papéis, profundidade e rodízio", _test_squad_mgmt)
	_run("pré-temporada e balanço da temporada", _test_preseason)
	_run("copas continentais de 2º e 3º nível", _test_second_cups)
	_run("seleções: eliminatórias, torneios e ranking", _test_national_teams)
	print("")
	print("%d testes ok, %d falha(s) — %.1f s" % [passed, failures, (Time.get_ticks_msec() - t0) / 1000.0])
	quit(1 if failures > 0 else 0)


func _run(name: String, fn: Callable) -> void:
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
		check(n >= 20 and n <= 28, "%s com %d jogadores" % [c.short_name, n])
		var sheet := ClubAI.auto_sheet(w, c, "")
		check(sheet.starters.size() == 11 and not sheet.starters.has(-1), "%s não consegue escalar 11" % c.short_name)
		for pid in c.player_ids:
			var p := w.player(pid)
			check(p != null and p.club_id == c.id, "jogador %d fora do clube %s" % [pid, c.short_name])
		for rid in c.rivals:
			check(w.club(rid).is_rival(c.id), "rivalidade não é mútua: %s" % c.key)
	check(w.players.size() >= 13500 and w.players.size() <= 16500, "total de jogadores plausível (%d)" % w.players.size())
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


func _season(w: GameWorld) -> void:
	var guard := 0
	while not w.season.finished and guard < 80:
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
				expect += 2 if f.hg == f.ag else 3
		for cid in league.club_ids:
			pts += int(league.table[cid]["pts"])
		check(pts == expect, "%s: pontos na tabela (%d) não batem com os jogos (%d)" % [id, pts, expect])
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
	check(in_state.size() == 80, "%d clubes brasileiros nos estaduais" % in_state.size())
	check(w.season.cups.has("SPE") and w.season.cups["SPE"].club_ids.size() == 17, "Paulistão sem os 17 clubes paulistas")
	check(w.season.cups.has("CWC"), "Mundial de Clubes não foi montado")
	if w.season.cups.has("CWC"):
		var cwc: Cup = w.season.cups["CWC"]
		check(cwc.club_ids.size() == 8 and cwc.finished and cwc.champion >= 0, "Mundial incompleto")
		check(cwc.club_ids.has(w.season.cups["UCL"].champion) and cwc.club_ids.has(w.season.cups["LIB"].champion), "campeões continentais fora do Mundial")
		check(w.club(cwc.champion).title_count("W:CWC") == int(titles_before[cwc.champion].get("W:CWC", 0)) + 1, "título mundial não registrado")
	# Estatísticas de copa separadas das de liga
	var top := CupManager.scorers(w, "UCL", 1)
	check(not top.is_empty() and top[0].cup_stats["UCL"][Player.C_GOALS] > 0, "artilharia da Liga dos Campeões vazia")


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
	check((summary["ballon_rank"] as Array).size() == 10 and int(summary["ballon_rank"][0]["pts"]) == 1000, "votação da Bola de Ouro inválida")
	check(not Dictionary(summary["boot"]).is_empty() and not Dictionary(summary["world_young"]).is_empty(), "Chuteira de Ouro / revelação mundial ausentes")
	var hist: Dictionary = w.history[w.history.size() - 1]
	var arch: Dictionary = hist.get("arch", {})
	check(arch.has("BRA1") and (arch["BRA1"]["tb"] as Array).size() == 20 and (arch["BRA1"]["sc"] as Array).size() == 10, "arquivo da temporada incompleto")
	check(not (hist.get("sq", []) as Array).is_empty() and not (hist.get("months", []) as Array).is_empty(), "elenco/meses não arquivados")
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
	check(bias.size() == 5, "foco do time + individual deveria dar 5 pesos (%d)" % bias.size())
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


func _test_trades() -> void:
	var w := _career_world()
	var c := w.user_club()
	c.transfer_budget = 80_000_000
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
	SponsorManager.open_preseason(w)
	check(SponsorManager.is_preseason(w), "pré-temporada não abriu")
	for s in SponsorManager.SLOTS:
		check(SponsorManager.offers_for(w, s[0]).size() == 3, "espaço %s sem 3 propostas" % s[0])
	var base := c.income_sponsor
	var r := SponsorManager.sign(w, "master", 0)
	check(r["ok"], "assinar master falhou")
	check(c.income_sponsor > base, "master não aumentou a receita")
	check(String(c.kit_home.get("sp", {}).get("n", "")) == String(c.sponsors["master"]["n"]), "logo do master fora da camisa")
	check(not SponsorManager.sign(w, "master", 1)["ok"], "espaço ocupado aceitou outro contrato")
	r = SponsorManager.sign(w, "manga", 1) # por vitória
	var b0 := c.balance
	SponsorManager.on_win(w, c)
	check(c.balance - b0 == int(c.sponsors["manga"]["b"]) and int(c.sponsors["manga"]["b"]) > 0, "bônus por vitória não pago")
	check(int(c.ledger.get("bonus_patrocinio", 0)) == int(c.sponsors["manga"]["b"]), "bônus fora das finanças")
	check(SponsorManager.breakdown(c).size() == 3 and int(SponsorManager.breakdown(c)[2]["e"]) > 0, "detalhamento de patrocínio incompleto")
	var signed := SponsorManager.close_preseason(w)
	check(signed.size() == 3 and c.sponsors.size() == 5, "diretoria não fechou os espaços vazios")
	check(not SponsorManager.is_preseason(w), "pré-temporada não fechou")
	for key in ["sp", "sup", "sp_m", "sp_c", "sp_s"]:
		check(c.kit_home.has(key) and c.kit_away.has(key), "logo %s fora do uniforme" % key)
	var c2 := Club.from_dict(c.to_dict())
	check(c2.sponsors.size() == 5, "patrocínios não salvos")
	# Receita total com todos os espaços fica perto da receita típica
	var typical := FinanceManager.sponsor_income(c)
	check(c.income_sponsor > typical * 0.75 and c.income_sponsor < typical * 1.25, "receita de patrocínio desbalanceada (%d vs %d)" % [c.income_sponsor, typical])
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


func _test_persona_trophies() -> void:
	var w := WorldGenerator.generate(4242, "padrao")
	# Veterano rodado vira cascudo com o tempo
	var vet: Player = null
	for p: Player in w.players.values():
		if p.age(w.year) >= 31 and p.traits.size() == 1 and not p.has_trait("inseguro") and not p.has_trait("timido"):
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
	var phys := p2.attrs[Attr.VEL] + p2.attrs[Attr.RES] + p2.attrs[Attr.FOR]
	check(PlayerDevelopment.injury_setback(w.rng, p2, 3, 30) == 0, "lesão leve tirou físico")
	var lost := 0
	for _i in 5:
		lost += PlayerDevelopment.injury_setback(w.rng, p2, 20, 32)
	check(lost > 0 and p2.attrs[Attr.VEL] + p2.attrs[Attr.RES] + p2.attrs[Attr.FOR] == phys - lost, "lesão grave sem efeito físico")
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
		if diff < 0:
			check(t.mentality == TeamSheet.MENT_TUDO, "perdendo e o plano não foi para o tudo ou nada")
			changed += 1
		elif diff > 0 and t.plan_state >= 0:
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
		if CupManager.is_state(cid):
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
