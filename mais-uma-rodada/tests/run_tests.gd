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
	for i in 300:
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
		check(w.club(cup.champion).title_count("C:" + cid) == 1, "%s: título não registrado" % cid)
	check(w.season.cups.has("CWC"), "Mundial de Clubes não foi montado")
	if w.season.cups.has("CWC"):
		var cwc: Cup = w.season.cups["CWC"]
		check(cwc.club_ids.size() == 8 and cwc.finished and cwc.champion >= 0, "Mundial incompleto")
		check(cwc.club_ids.has(w.season.cups["UCL"].champion) and cwc.club_ids.has(w.season.cups["LIB"].champion), "campeões continentais fora do Mundial")
		check(w.club(cwc.champion).title_count("W:CWC") == 1, "título mundial não registrado")
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
	var summary := SeasonManager.end_season(w)
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
	check(float(w.stats.get("youth_generated", 0.0)) > 600, "base não gerou jovens suficientes")
	var rules := DatabaseManager.squad_rules()
	var owner := {}
	for c: Club in w.clubs:
		check(c.player_ids.size() >= int(rules["min_players"]) and c.player_ids.size() <= int(rules["max_players"]), "%s com %d jogadores" % [c.short_name, c.player_ids.size()])
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
