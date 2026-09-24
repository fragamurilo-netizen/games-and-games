extends SceneTree
## Testes automáticos do núcleo do jogo (sem interface).
## Uso: godot --headless --path . --script res://tests/run_tests.gd
## Sai com código 1 se algum teste falhar. O teste de fumaça da interface fica em
## tools/screenshot_tour.gd e a simulação longa em tests/season_simulator.gd.

const TEST_SLOT := 99 # fora dos 5 espaços visíveis: nunca toca nos saves do jogador

var failures := 0
var passed := 0
var current := ""


func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	_run("geração do mundo padrão", _test_generation)
	_run("mundo aleatório e determinismo", _test_determinism)
	_run("calendário de 38 rodadas", _test_fixtures)
	_run("calibração do motor de partidas", _test_engine)
	_run("partida ao vivo = partida instantânea", _test_live_equals_instant)
	_run("temporada completa e virada de ano", _test_season_cycle)
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


func _fingerprint(w: GameWorld) -> String:
	return var_to_str(w.to_dict()).md5_text()


func _with_user(w: GameWorld, club_id: int, difficulty: int = GameWorld.DIFF_NORMAL) -> Club:
	w.user_club_id = club_id
	w.manager_name = "Teste"
	w.difficulty = difficulty
	var c := w.user_club()
	FinanceManager.set_budgets(w, c)
	c.sheet = ClubAI.auto_sheet(w, c, "")
	return c


# ---------------------------------------------------------------------------

func _test_generation() -> void:
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	check(w.clubs.size() == 80, "80 clubes (veio %d)" % w.clubs.size())
	var abbrs := {}
	for d in 4:
		check(w.season.leagues[d].club_ids.size() == 20, "divisão %d com 20 clubes" % d)
	for c: Club in w.clubs:
		abbrs[c.abbr] = true
		var n := c.player_ids.size()
		check(n >= 20 and n <= 28, "%s com %d jogadores" % [c.short_name, n])
		var sheet := ClubAI.auto_sheet(w, c, "")
		check(sheet.starters.size() == 11 and not sheet.starters.has(-1), "%s não consegue escalar 11" % c.short_name)
		for pid in c.player_ids:
			var p := w.player(pid)
			check(p != null and p.club_id == c.id, "jogador %d fora do clube %s" % [pid, c.short_name])
	check(abbrs.size() == 80, "siglas únicas (%d)" % abbrs.size())
	check(w.players.size() >= 1850 and w.players.size() <= 2200, "total de jogadores plausível (%d)" % w.players.size())
	var names := {}
	var dups := 0
	var bad_attr := 0
	var bad_pot := 0
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
	check(dups == 0, "nomes completos repetidos: %d" % dups)
	check(bad_attr == 0, "atributos fora de 1..100: %d" % bad_attr)
	check(bad_pot == 0, "potencial abaixo do overall: %d" % bad_pot)


func _test_determinism() -> void:
	var a := WorldGenerator.generate(12345, "aleatorio")
	var b := WorldGenerator.generate(12345, "aleatorio")
	check(_fingerprint(a) == _fingerprint(b), "mesmo seed gera o mesmo mundo")
	var std := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	var same_names := 0
	for c: Club in a.clubs:
		for s: Club in std.clubs:
			if c.name == s.name:
				same_names += 1
	check(same_names < 8, "mundo aleatório deveria ter clubes novos (%d nomes iguais ao padrão)" % same_names)
	for i in 3:
		SeasonManager.play_matchday_instant(a)
		SeasonManager.play_matchday_instant(b)
	check(_fingerprint(a) == _fingerprint(b), "mesmas rodadas com o mesmo seed dão os mesmos resultados")
	var c2 := WorldGenerator.generate(54321, "aleatorio")
	check(_fingerprint(c2) != _fingerprint(WorldGenerator.generate(12345, "aleatorio")), "seeds diferentes geram mundos diferentes")


func _test_fixtures() -> void:
	var w := WorldGenerator.generate(777, "padrao")
	for league: League in w.season.leagues:
		check(league.rounds.size() == 38, "%s com %d rodadas" % [league.name, league.rounds.size()])
		var pairs := {}
		var home := {}
		for r in league.rounds.size():
			var seen := {}
			for f: Fixture in league.rounds[r]:
				check(not seen.has(f.home) and not seen.has(f.away), "clube repetido na rodada %d" % (r + 1))
				seen[f.home] = true
				seen[f.away] = true
				var key := "%d-%d" % [f.home, f.away]
				check(not pairs.has(key), "confronto %s repetido com o mesmo mando" % key)
				pairs[key] = true
				home[f.home] = int(home.get(f.home, 0)) + 1
			check(seen.size() == 20, "rodada %d não tem os 20 clubes" % (r + 1))
		check(pairs.size() == 380, "%s: 380 jogos (veio %d)" % [league.name, pairs.size()])
		for cid in league.club_ids:
			check(int(home.get(cid, 0)) == 19, "%s com %d jogos em casa" % [w.club(cid).short_name, int(home.get(cid, 0))])


func _test_engine() -> void:
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var n := 0
	var goals := 0
	var hw := 0
	var dr := 0
	var reds := 0
	for i in 800:
		var l: League = w.season.leagues[i % 4]
		var a: int = l.club_ids[rng.randi_range(0, 19)]
		var b: int = l.club_ids[rng.randi_range(0, 19)]
		if a == b:
			continue
		var sim := MatchEngine.quick_match(w, w.club(a), w.club(b), rng.randi())
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
	# Zebra existe, mas é rara: time da 4ª em casa contra o da 1ª.
	var d4 := 0
	var d1 := 0
	for i in 300:
		var sim := MatchEngine.quick_match(w, w.club(w.season.leagues[3].club_ids[i % 20]), w.club(w.season.leagues[0].club_ids[i % 20]), rng.randi())
		if sim.score[0] > sim.score[1]:
			d4 += 1
		elif sim.score[1] > sim.score[0]:
			d1 += 1
	check(d4 > 0, "a zebra nunca acontece (0 vitórias da 4ª divisão em 300)")
	check(d4 < 60, "zebras demais: %d vitórias da 4ª divisão em 300" % d4)
	check(d1 > 180, "a 1ª divisão deveria vencer a maioria (%d de 300)" % d1)


## A partida assistida usa exatamente a mesma simulação da instantânea: com o mesmo seed,
## passo a passo ou de uma vez, o resultado é idêntico.
func _test_live_equals_instant() -> void:
	var w := WorldGenerator.generate(4242, "padrao")
	var h := w.club(w.season.leagues[1].club_ids[0])
	var a := w.club(w.season.leagues[1].club_ids[1])
	for s in 20:
		var hs := ClubAI.prepare_ai_sheet(w, h, a, true)
		var as_ := ClubAI.prepare_ai_sheet(w, a, h, false)
		var ctx := {"derby": false, "importance": 0.3, "attendance": 10000, "competition": "F"}
		var s1 := MatchSimulation.new()
		s1.setup(w, h, a, hs, as_, ctx, 1000 + s, true)
		var steps := 0
		while not s1.finished and steps < 400:
			s1.step()
			steps += 1
		var s2 := MatchSimulation.new()
		s2.setup(w, h, a, hs, as_, ctx, 1000 + s, false)
		s2.run_to_end()
		var same := s1.score == s2.score and s1.teams[0].shots == s2.teams[0].shots and s1.teams[1].shots == s2.teams[1].shots
		same = same and _goal_log(s1) == _goal_log(s2) and s1.teams[0].yellows == s2.teams[0].yellows
		check(same, "seed %d: ao vivo %s × instantâneo %s" % [1000 + s, str(s1.score), str(s2.score)])


func _goal_log(sim: MatchSimulation) -> String:
	var out := ""
	for ev in sim.events:
		if ev["t"] == MatchSimulation.EV_GOAL or ev["t"] == MatchSimulation.EV_OWN_GOAL:
			out += "%d:%d:%d;" % [ev["m"], ev["s"], ev["p"]]
	return out


func _test_season_cycle() -> void:
	var w := WorldGenerator.generate(777, "padrao")
	var user := _with_user(w, w.season.leagues[2].club_ids[5])
	var year := w.year
	var days := 0
	while not w.season.finished and days < 60:
		SeasonManager.play_matchday_instant(w)
		days += 1
	check(w.season.finished and days == 38, "temporada deveria ter 38 rodadas (%d)" % days)
	for league: League in w.season.leagues:
		var pts := 0
		var expect := 0
		for r in league.rounds:
			for f: Fixture in r:
				check(f.played, "jogo não disputado")
				expect += 2 if f.hg == f.ag else 3
		for cid in league.club_ids:
			pts += int(league.table[cid]["pts"])
		check(pts == expect, "%s: pontos na tabela (%d) não batem com os jogos (%d)" % [league.name, pts, expect])
	var old_div := {}
	for c: Club in w.clubs:
		old_div[c.id] = c.division
	var summary := SeasonManager.end_season(w)
	check(w.year == year + 1, "ano não avançou")
	check(not w.season.finished and w.season.day == 0, "nova temporada não foi montada")
	for d in 4:
		check(w.season.leagues[d].club_ids.size() == 20, "divisão %d ficou com %d clubes" % [d, w.season.leagues[d].club_ids.size()])
	for dv in summary["divisions"]:
		for cid in dv["promoted"]:
			check(w.club(cid).division == int(old_div[cid]) - 1, "%s não subiu" % w.club(cid).short_name)
		for cid in dv["relegated"]:
			check(w.club(cid).division == int(old_div[cid]) + 1, "%s não caiu" % w.club(cid).short_name)
		check((dv["promoted"] as Array).size() == (4 if int(dv["div"]) > 0 else 0), "acessos na divisão %d" % int(dv["div"]))
		check((dv["relegated"] as Array).size() == (4 if int(dv["div"]) < 3 else 0), "quedas na divisão %d" % int(dv["div"]))
	check(not summary["user"].is_empty(), "resumo do usuário vazio")
	check(float(w.stats.get("youth_generated", 0.0)) > 60, "base não gerou jovens suficientes")
	var rules := DatabaseManager.squad_rules()
	var owner := {}
	for c: Club in w.clubs:
		check(c.player_ids.size() >= int(rules["min_players"]) and c.player_ids.size() <= int(rules["max_players"]), "%s com %d jogadores" % [c.short_name, c.player_ids.size()])
		for pid in c.player_ids:
			check(not owner.has(pid), "jogador %d em dois clubes" % pid)
			owner[pid] = c.id
			var p := w.player(pid)
			check(p != null and p.club_id == c.id, "vínculo inconsistente do jogador %d" % pid)
	check(user.id == w.user_club_id, "usuário perdeu o clube sem demissão")


func _test_save_load() -> void:
	var w := WorldGenerator.generate(2024, "aleatorio")
	_with_user(w, w.season.leagues[3].club_ids[0])
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
	check(_fingerprint(l) == _fingerprint(w), "depois de carregar, as rodadas seguintes divergem")
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
	var user := _with_user(w, w.season.leagues[1].club_ids[3])
	check(w.transfer_window_open(), "a janela deveria estar aberta na rodada 1")
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
	w.season.day = 10
	var closed := TransferManager.user_bid(w, w.player(seller.player_ids[0]), 1)
	check(closed["result"] == "rejected", "proposta com a janela fechada deveria ser recusada")


func _test_board() -> void:
	var w := WorldGenerator.generate(99, "padrao")
	var user := _with_user(w, w.season.leagues[0].club_ids[10], GameWorld.DIFF_HARD)
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
	var u2 := _with_user(w2, w2.season.leagues[0].club_ids[10], GameWorld.DIFF_EASY)
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
		if p.club_id >= 0 and p.age(w.year) >= 23 and p.age(w.year) <= 26 and p.overall >= 60:
			young = p
			break
	if young != null:
		var v_now := Valuation.market_value(young, w.year)
		var v_old := Valuation.market_value(young, w.year + 9) # mesmo nível, 9 anos mais velho
		check(v_old < v_now, "jogador mais velho com o mesmo nível deveria valer menos")


func _test_news() -> void:
	var w := WorldGenerator.generate(8080, "padrao")
	_with_user(w, w.season.leagues[0].club_ids[0])
	for i in 6:
		SeasonManager.play_matchday_instant(w)
	check(w.news.size() >= 5, "poucas notícias em 6 rodadas (%d)" % w.news.size())
	var broken := 0
	for n: NewsEvent in w.news:
		if n.title.contains("{") or n.body.contains("{") or n.title.strip_edges() == "":
			broken += 1
	check(broken == 0, "%d notícias com texto não preenchido" % broken)
