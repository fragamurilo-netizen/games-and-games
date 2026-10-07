extends SceneTree
## Relatório de realismo do motor minuto a minuto (médias, placares, viradas, zebras).
## Uso: godot --headless --path . --script res://tools/engine_report.gd [-- --quick --n=1500] [-- --quick] [-- --n=1500]
## --quick: mede o modo rápido (QuickMatch, os jogos da IA) em vez do minuto a minuto.
## --detail: minuto a minuto com a narração ligada (o jogo assistido); deve dar os mesmos números.


func _initialize() -> void:
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var ids := DatabaseManager.league_ids()
	var n := 0
	var goals := 0
	var hw := 0
	var dr := 0
	var nil := 0
	var big := 0
	var first_scored := 0
	var comeback := 0
	var late := 0
	var second_half := 0
	var upsets := 0
	var gaps := 0
	var formation_changes := 0
	var quick := false
	var detail := false
	var total := 1500
	for arg in OS.get_cmdline_user_args():
		if arg == "--quick":
			quick = true
		elif arg == "--detail":
			detail = true
		elif arg.begins_with("--n="):
			total = int(arg.substr(4))
	var t0 := Time.get_ticks_msec()
	var fs_w := 0
	var fs_d := 0
	var dist := [0, 0, 0, 0, 0, 0, 0]
	var yc := 0
	var rc := 0
	var shots := 0
	var xg := 0.0
	var pens := 0
	var pos_g := [0, 0, 0, 0]
	var st_g := 0
	var gap_n := [0, 0, 0]
	var gap_w := [0, 0, 0]
	var gap_d := [0, 0, 0]
	var gap_g := [0, 0, 0]
	var gap_big := [0, 0, 0]
	for i in total:
		var cl := w.clubs_in_league(ids[i % ids.size()])
		var a: Club = cl[rng.randi_range(0, cl.size() - 1)]
		var b: Club = cl[rng.randi_range(0, cl.size() - 1)]
		if a == b:
			continue
		var res: Dictionary
		if quick:
			res = MatchEngine.test_match(w, a, b, rng.randi(), true)
			_ratings(res)
			_team_stats(res)
		else:
			var sim := _detail_sim(w, a, b, rng.randi()) if detail else MatchEngine.quick_match(w, a, b, rng.randi())
			res = sim.to_result()
			_collect(sim)
		n += 1
		var hg := int(res["hg"])
		var ag := int(res["ag"])
		var sc: Array = [hg, ag]
		goals += hg + ag
		if hg > ag:
			hw += 1
		elif hg == ag:
			dr += 1
		if hg + ag == 0:
			nil += 1
		if hg + ag >= 5:
			big += 1
		dist[mini(6, hg + ag)] += 1
		yc += int(res["yc"][0]) + int(res["yc"][1])
		rc += int(res["rc"][0]) + int(res["rc"][1])
		shots += int(res.get("sh", [0, 0])[0]) + int(res.get("sh", [0, 0])[1])
		xg += float(res["tac"]["xg"][0]) + float(res["tac"]["xg"][1])
		for g in res["goals"]:
			if int(g[3]) == Fixture.GOAL_PENALTY:
				pens += 1
			if int(g[3]) != Fixture.GOAL_OWN:
				var gp: Player = w.players.get(int(g[2]), null)
				if gp != null:
					pos_g[Pos.GROUP[gp.position]] += 1
					if gp.position == Pos.ST:
						st_g += 1
		var ga_ := ClubAI._compute_strength(w, a) + 1.5
		var gb_ := ClubAI._compute_strength(w, b)
		var gi := 0 if absf(ga_ - gb_) < 3.0 else (1 if absf(ga_ - gb_) < 7.0 else 2)
		gap_n[gi] += 1
		gap_g[gi] += hg + ag
		if hg + ag >= 5:
			gap_big[gi] += 1
		var fav_home := ga_ >= gb_
		if (fav_home and hg > ag) or (not fav_home and ag > hg):
			gap_w[gi] += 1
		elif hg == ag:
			gap_d[gi] += 1
		var first := -1
		for g in res["goals"]:
			if first < 0:
				first = int(g[1])
			if int(g[4]) == 2:
				second_half += 1
				if int(g[0]) >= 76:
					late += 1
		if first >= 0:
			first_scored += 1
			if sc[first] > sc[1 - first]:
				fs_w += 1
			elif sc[first] == sc[1 - first]:
				fs_d += 1
			else:
				comeback += 1
		var sa := ClubAI._compute_strength(w, a)
		var sb := ClubAI._compute_strength(w, b)
		if absf(sa - sb) >= 6.0:
			gaps += 1
			var weak_home := sa < sb
			if (weak_home and hg > ag) or (not weak_home and ag > hg):
				upsets += 1
	print("%s · %.1f ms/jogo" % ["RÁPIDO (QuickMatch)" if quick else "MINUTO A MINUTO", float(Time.get_ticks_msec() - t0) / n])
	print("quem marca primeiro: vence %.1f%% · empata %.1f%% · perde %.1f%%" % [100.0 * fs_w / maxf(1, first_scored), 100.0 * fs_d / maxf(1, first_scored), 100.0 * comeback / maxf(1, first_scored)])
	print("jogos %d | gols/jogo %.2f | mandante %.1f%% | empates %.1f%% | 0x0 %.1f%% | 5+ gols %.1f%%" % [n, float(goals) / n, 100.0 * hw / n, 100.0 * dr / n, 100.0 * nil / n, 100.0 * big / n])
	print("gols no 2º tempo %.1f%% | a partir dos 76' %.1f%% | viradas (quem sofreu o 1º venceu) %.1f%% | zebras (gap>=6) %.1f%% de %d" % [100.0 * second_half / goals, 100.0 * late / goals, 100.0 * comeback / maxf(1, first_scored), 100.0 * upsets / maxf(1, gaps), gaps])
	var ds: Array = []
	for k in dist.size():
		ds.append("%s:%.1f%%" % [str(k) if k < 6 else "6+", 100.0 * dist[k] / n])
	print("total de gols: ", " ".join(ds))
	var tg := maxf(1, pos_g[1] + pos_g[2] + pos_g[3])
	print("amarelos %.2f | vermelhos %.3f | finalizações/time %.1f | xG/time %.2f | pênaltis %.1f%% dos gols | DEF %.1f%% MEI %.1f%% ATA %.1f%% (centroavante %.1f%%)" % [float(yc) / n, float(rc) / n, shots / (2.0 * n), xg / (2.0 * n), 100.0 * pens / maxf(1, goals), 100.0 * pos_g[1] / tg, 100.0 * pos_g[2] / tg, 100.0 * pos_g[3] / tg, 100.0 * st_g / tg])
	var rs0 := []
	for g in 4:
		var nn0: float = maxf(1.0, ex["rn"][g])
		var mean0: float = ex["rs"][g] / nn0
		rs0.append("%s %.2f±%.2f" % [["GOL", "DEF", "MEI", "ATA"][g], mean0, sqrt(maxf(0.0, ex["rq"][g] / nn0 - mean0 * mean0))])
	print("notas (titulares 60+ min): " + " | ".join(rs0))
	if ex_n > 0:
		var tn := 2.0 * ex_n
		var sh_all := maxf(1.0, float(ex["shots"]))
		print("POR TIME: escanteios %.1f (real ~5) | faltas %.1f (~11-12) | impedimentos %.1f (~2) | no alvo %.1f = %.0f%% das finalizações (~33%%) | travadas %.0f%% (~27%%) | defesas %.1f (~3) | grandes chances %.1f (~1,8) | rebotes %.2f" % [
			ex["corners"] / tn, ex["fouls"] / tn, ex["offs"] / tn, ex["on"] / tn, 100.0 * ex["on"] / sh_all, 100.0 * ex["blocked"] / sh_all, ex["saves"] / tn, ex["big"] / tn, ex["reb"] / tn])
	if not quick and ex_n > 0:
		var tn := 2.0 * ex_n
		print("DUELOS POR TIME: desarmes %.1f (~16) | interceptações %.1f (~10) | dribles %.1f (~9) | aéreas ganhas %.1f (~16) | passes %.0f (~450) a %.0f%% (~80%%)" % [
			ex["tk"] / tn, ex["it"] / tn, ex["dr"] / tn, ex["ad"] / tn, ex["pa"] / tn, 100.0 * ex["pc"] / maxf(1.0, ex["pa"])])
		var pm: float = ex["poss_sq"] / ex_n - pow(ex["poss_sum"] / ex_n, 2)
		print("posse: mandante %.1f%%, desvio %.1f pontos (real ~9) | amarelos 1º tempo %.0f%% (real ~35%%) | lesões/jogo %.2f | trocas/time %.1f, minuto médio %.0f, 1ª troca %.0f (real ~58)" % [
			100.0 * ex["poss_sum"] / ex_n, 100.0 * sqrt(maxf(0.0, pm)), 100.0 * ex["y1"] / maxf(1.0, ex["y1"] + ex["y2"]), ex["inj"] / ex_n, ex["subs"] / tn, ex["sub_min"] / maxf(1.0, ex["subs"]), ex["first_sub"] / maxf(1.0, ex["first_n"])])
	var gs: Array = []
	for k in 3:
		gs.append("%s: favorito vence %.0f%% empata %.0f%% perde %.0f%% gols %.2f 5+ %.0f%% (%d)" % [["gap<3", "3-7", "7+"][k], 100.0 * gap_w[k] / maxf(1, gap_n[k]), 100.0 * gap_d[k] / maxf(1, gap_n[k]), 100.0 * (gap_n[k] - gap_w[k] - gap_d[k]) / maxf(1, gap_n[k]), float(gap_g[k]) / maxf(1, gap_n[k]), 100.0 * gap_big[k] / maxf(1, gap_n[k]), gap_n[k]])
	print(" | ".join(gs))
	quit()


var ex := {"poss_sum": 0.0, "corners": 0.0, "fouls": 0.0, "offs": 0.0, "on": 0.0, "shots": 0.0, "blocked": 0.0, "saves": 0.0, "big": 0.0, "reb": 0.0,
	"tk": 0.0, "it": 0.0, "dr": 0.0, "ad": 0.0, "pa": 0.0, "pc": 0.0, "poss_sq": 0.0, "y1": 0.0, "y2": 0.0, "inj": 0.0, "subs": 0.0,
	"sub_min": 0.0, "first_sub": 0.0, "first_n": 0.0, "rs": [0.0, 0.0, 0.0, 0.0], "rq": [0.0, 0.0, 0.0, 0.0], "rn": [0.0, 0.0, 0.0, 0.0]}
var ex_n := 0


## Números do minuto a minuto que o resultado comum não traz (escanteios, duelos, notas...).
func _collect(sim: MatchSimulation) -> void:
	ex_n += 1
	var res := sim.to_result()
	for t: MatchTeam in sim.teams:
		ex["corners"] += t.corners
		ex["fouls"] += t.fouls
		ex["offs"] += t.offsides
		ex["on"] += t.on_target
		ex["shots"] += t.shots
		ex["blocked"] += t.blocked
		ex["saves"] += t.saves
		ex["big"] += t.big
		ex["reb"] += t.rebounds
		var first := 999
		for mp: MatchPlayer in t.all:
			if not mp.used:
				continue
			ex["tk"] += mp.tackles
			ex["it"] += mp.interceptions
			ex["dr"] += mp.dribbles
			ex["ad"] += mp.aerials
			var ps: Array = res["pstats"][mp.p.id]
			ex["pa"] += int(ps[13])
			ex["pc"] += int(ps[14])
			if mp.start_min > 0:
				ex["subs"] += 1
				ex["sub_min"] += mp.start_min
				first = mini(first, mp.start_min)
		if first < 999:
			ex["first_sub"] += first
			ex["first_n"] += 1
	_ratings(res)
	var p0 := sim.possession_pct(0)
	ex["poss_sq"] += p0 * p0
	ex["poss_sum"] += p0
	for ev in sim.events:
		var t: int = ev["t"]
		if t == MatchSimulation.EV_YELLOW:
			if int(ev["h"]) == 1:
				ex["y1"] += 1
			else:
				ex["y2"] += 1
		elif t == MatchSimulation.EV_INJURY:
			ex["inj"] += 1


## Números por time que os dois modos exportam em res["team"] (o modo rápido não tem rebotes).
func _team_stats(res: Dictionary) -> void:
	ex_n += 1
	for t: Dictionary in res.get("team", []):
		ex["corners"] += int(t["corners"])
		ex["fouls"] += int(t["fouls"])
		ex["offs"] += int(t["offsides"])
		ex["on"] += int(t["on"])
		ex["shots"] += int(t["shots"])
		ex["blocked"] += int(t["blocked"])
		ex["saves"] += int(t["saves"])
		ex["big"] += int(t["big"])
		ex["reb"] += int(t.get("rebounds", 0))


## Notas dos titulares que jogaram 60+ minutos, pelo formato comum das linhas (os dois modos).
func _ratings(res: Dictionary) -> void:
	for side in 2:
		for ln: Array in res["lines"][side]:
			if int(ln[QuickMatch.L_START]) == 0 and int(ln[19]) >= 60:
				var g: int = Pos.GROUP[int(ln[1])]
				var r := float(ln[20])
				ex["rs"][g] += r
				ex["rq"][g] += r * r
				ex["rn"][g] += 1


static func _detail_sim(world: GameWorld, home: Club, away: Club, seed_value: int) -> MatchSimulation:
	var hs := ClubAI.prepare_ai_sheet(world, home, away, true)
	var as_ := ClubAI.prepare_ai_sheet(world, away, home, false)
	var sim := MatchSimulation.new()
	sim.setup(world, home, away, hs, as_, MatchEngine._test_ctx(home), seed_value, true)
	sim.run_to_end()
	return sim


## Mesmo jogo de teste do MatchEngine.quick_match, mas com detail = true (eventos de apresentação).
static func _detail_match(world: GameWorld, home: Club, away: Club, seed_value: int) -> Dictionary:
	var hs := ClubAI.prepare_ai_sheet(world, home, away, true)
	var as_ := ClubAI.prepare_ai_sheet(world, away, home, false)
	var sim := MatchSimulation.new()
	sim.setup(world, home, away, hs, as_, MatchEngine._test_ctx(home), seed_value, true)
	sim.run_to_end()
	return sim.to_result()
