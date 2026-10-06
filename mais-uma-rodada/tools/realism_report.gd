extends SceneTree
## Realismo de uma temporada inteira (todas as ligas): gols/jogo, mando, placares, empates,
## artilheiros e garçons por liga, gols por posição, concentração dos gols, jogos sem sofrer gol,
## finalizações/xG por jogo e cartões.
## Uso: godot --headless --path . --script res://tools/realism_report.gd [-- --full] [-- --seasons=2] [-- --days=N]
## --full: todos os jogos no minuto a minuto (o motor do jogo do usuário e do "Simular") em vez do
## modo rápido da IA; é mais lento, mas mostra se os dois modelos dão os mesmos números.


func _process(_d: float) -> bool:
	var full := false
	var seasons := 1
	var days := 9999
	for a in OS.get_cmdline_user_args():
		if a == "--full":
			full = true
		elif a.begins_with("--seasons="):
			seasons = int(a.substr(10))
		elif a.begins_with("--days="):
			days = int(a.substr(7))
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	for s_i in seasons:
		if s_i > 0:
			SeasonManager.end_season(w)
		_run_season(w, full, days)
	quit()
	return true


func _run_season(w: GameWorld, full: bool, days: int) -> void:
	var t0 := Time.get_ticks_msec()
	var n_days := 0
	var yc := 0
	var rc := 0
	var xg := 0.0
	var ncard := 0
	while not w.season.finished and n_days < days:
		var md := SeasonManager.begin_matchday(w)
		for e: Dictionary in md["entries"]:
			var f: Fixture = e["f"]
			if full and e["sim"] == null:
				var home := w.club(f.home)
				var away := w.club(f.away)
				var sim := MatchSimulation.new()
				sim.setup(w, home, away, ClubAI.prepare_ai_sheet(w, home, away, true), ClubAI.prepare_ai_sheet(w, away, home, false), e["ctx"], e["seed"], false)
				e["sim"] = sim
			SeasonManager.run_entry(w, e)
			if f.is_league():
				var r: Dictionary = e["res"]
				yc += int(r["yc"][0]) + int(r["yc"][1])
				rc += int(r["rc"][0]) + int(r["rc"][1])
				var tx: Dictionary = r.get("tac", {})
				if tx.has("xg"):
					xg += float(tx["xg"][0]) + float(tx["xg"][1])
				ncard += 1
		SeasonManager.finish_matchday(w, md)
		n_days += 1
	print("=== temporada %d · %s · %d datas · %.1f s ===" % [w.season.year, "MINUTO A MINUTO" if full else "RÁPIDO", n_days, float(Time.get_ticks_msec() - t0) / 1000.0])
	# Resultados de liga
	var n := 0
	var goals := 0
	var hg_t := 0
	var ag_t := 0
	var hw := 0
	var dr := 0
	var nil := 0
	var big := 0
	var cs := 0
	var scores := {}
	var pos_goals := [0, 0, 0, 0]
	var fine := {} # posição exata
	var pens := 0
	var ogs := 0
	var all_f: Array = []
	for lid in w.season.league_order:
		for rd in w.season.leagues[lid].rounds:
			all_f.append_array(rd)
	for f: Fixture in all_f:
		if not f.played or not f.is_league():
			continue
		n += 1
		goals += f.hg + f.ag
		hg_t += f.hg
		ag_t += f.ag
		if f.hg > f.ag:
			hw += 1
		elif f.hg == f.ag:
			dr += 1
		if f.hg + f.ag == 0:
			nil += 1
		if f.hg + f.ag >= 5:
			big += 1
		if f.hg == 0:
			cs += 1
		if f.ag == 0:
			cs += 1
		var key := "%d-%d" % [maxi(f.hg, f.ag), mini(f.hg, f.ag)]
		scores[key] = int(scores.get(key, 0)) + 1
		for g in f.goals:
			if int(g[3]) == Fixture.GOAL_OWN:
				ogs += 1
				continue
			if int(g[3]) == Fixture.GOAL_PENALTY:
				pens += 1
			var p: Player = w.players.get(int(g[2]), null)
			if p == null:
				continue
			pos_goals[Pos.GROUP[p.position]] += 1
			fine[p.position] = int(fine.get(p.position, 0)) + 1
	if n == 0:
		print("nenhum jogo de liga")
		return
	print("jogos %d | gols/jogo %.2f (mandante %.2f × visitante %.2f) | mandante vence %.1f%% | empates %.1f%% | visitante %.1f%%" % [n, float(goals) / n, float(hg_t) / n, float(ag_t) / n, 100.0 * hw / n, 100.0 * dr / n, 100.0 * (n - hw - dr) / n])
	print("0x0 %.1f%% | 5+ gols %.1f%% | sem sofrer gol %.1f%% dos times-jogo | pênaltis %.1f%% dos gols | contra %.1f%%" % [100.0 * nil / n, 100.0 * big / n, 50.0 * cs / n, 100.0 * pens / maxf(1, goals), 100.0 * ogs / maxf(1, goals)])
	var keys := scores.keys()
	keys.sort_custom(func(a, b): return int(scores[a]) > int(scores[b]))
	var ss: Array = []
	for k in keys.slice(0, 12):
		ss.append("%s %.1f%%" % [k, 100.0 * int(scores[k]) / n])
	print("placares: ", ", ".join(ss))
	var tg := maxf(1, pos_goals[0] + pos_goals[1] + pos_goals[2] + pos_goals[3])
	print("gols por grupo (sem contra): GOL %.1f%% | DEF %.1f%% | MEI %.1f%% | ATA %.1f%%" % [100.0 * pos_goals[0] / tg, 100.0 * pos_goals[1] / tg, 100.0 * pos_goals[2] / tg, 100.0 * pos_goals[3] / tg])
	var fs: Array = []
	for pz in Pos.DISPLAY_ORDER:
		fs.append("%s %.1f%%" % [Pos.CODES[pz], 100.0 * int(fine.get(pz, 0)) / tg])
	print("   por posição: ", ", ".join(fs))
	print("cartões/jogo: amarelos %.2f | vermelhos %.3f | xG/jogo (motor) %.2f" % [float(yc) / maxf(1, ncard), float(rc) / maxf(1, ncard), xg / maxf(1, ncard)])
	# Estatísticas dos jogadores (liga)
	var shots := 0
	var sxg := 0
	for p: Player in w.players.values():
		shots += p.stats[Player.S_SHOTS]
		sxg += p.stats[Player.S_XG]
	print("finalizações/time-jogo %.1f | xG/time-jogo (súmula) %.2f" % [float(shots) / (2.0 * n), float(sxg) / 100.0 / (2.0 * n)])
	# Artilharia por liga
	var tops: Array = []
	var atops: Array = []
	var scorers_share := [0.0, 0.0, 0.0] # % dos jogadores com minutos que marcaram; % dos gols do top-3 do time; jogadores 10+
	var cnt_leagues := 0
	var ten_plus := 0
	var players_with_mins := 0
	var players_scored := 0
	var top3_share := 0.0
	var clubs_n := 0
	for lid in DatabaseManager.league_ids():
		var lg := w.league(lid)
		if lg == null:
			continue
		var games := lg.rounds.size()
		var best: Player = null
		var besta: Player = null
		var top5: Array = []
		for cid in lg.club_ids:
			var c := w.club(cid)
			var cg: Array = []
			for pid in c.player_ids:
				var p: Player = w.players.get(pid, null)
				if p == null:
					continue
				if p.stats[Player.S_MINUTES] > 0:
					players_with_mins += 1
					if p.stats[Player.S_GOALS] > 0:
						players_scored += 1
				if p.stats[Player.S_GOALS] >= 10:
					ten_plus += 1
				cg.append(p.stats[Player.S_GOALS])
				if best == null or p.stats[Player.S_GOALS] > best.stats[Player.S_GOALS]:
					best = p
				if besta == null or p.stats[Player.S_ASSISTS] > besta.stats[Player.S_ASSISTS]:
					besta = p
				top5.append(p.stats[Player.S_GOALS])
			cg.sort()
			cg.reverse()
			var tot := 0
			for x in cg:
				tot += int(x)
			if tot > 0:
				top3_share += float(int(cg[0]) + (int(cg[1]) if cg.size() > 1 else 0) + (int(cg[2]) if cg.size() > 2 else 0)) / tot
				clubs_n += 1
		top5.sort()
		top5.reverse()
		var gf_max := 0
		var ga_min := 999
		for cid in lg.club_ids:
			var row: Dictionary = lg.table[cid]
			gf_max = maxi(gf_max, int(row.get("gf", 0)))
			ga_min = mini(ga_min, int(row.get("ga", 0)))
		if best != null:
			tops.append("%s(%dj) %d [%s] ataque %d defesa %d" % [lid, games, best.stats[Player.S_GOALS], ",".join(top5.slice(1, 5).map(func(x): return str(x))), gf_max, ga_min])
			atops.append("%s %d" % [lid, besta.stats[Player.S_ASSISTS]])
		cnt_leagues += 1
	print("artilheiros (liga, jogos por time, gols do 1º [2º..5º]):")
	for i in range(0, tops.size(), 3):
		print("   ", " | ".join(tops.slice(i, i + 3)))
	print("garçons: ", ", ".join(atops))
	print("jogadores com minutos que marcaram %.0f%% | 10+ gols: %d | top-3 do time = %.0f%% dos gols do time" % [100.0 * players_scored / maxf(1, players_with_mins), ten_plus, 100.0 * top3_share / maxf(1, clubs_n)])
