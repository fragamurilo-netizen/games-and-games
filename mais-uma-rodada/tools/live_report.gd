extends SceneTree
## Relatório do motor posicional (LiveEngine): roda partidas completas e mostra médias por time
## (gols, chutes, no gol, xG, posse, passes e acerto, faltas, escanteios, impedimentos, cartões),
## resultados e o tempo de processamento. Serve para calibrar contra o futebol real.
## Uso: godot --headless --path . --script res://tools/live_report.gd -- --n=40 --league=BRA1


func _initialize() -> void:
	var n := 30
	var league := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--n="):
			n = int(a.substr(4))
		elif a.begins_with("--league="):
			league = a.substr(9)
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var ids := ["ENG1", "ESP1", "ITA1", "BRA1", "GER1", "FRA1", "BRA2", "POR1"] if league == "" else [league]
	var tot := {"g": 0.0, "sh": 0.0, "on": 0.0, "xg": 0.0, "pas": 0.0, "pok": 0.0, "fo": 0.0, "co": 0.0, "off": 0.0, "yc": 0.0, "rc": 0.0, "tk": 0.0}
	var hw := 0
	var dr := 0
	var fav_w := 0
	var fav_n := 0
	var poss_min := 1.0
	var poss_max := 0.0
	var rat := 0.0
	var rat_n := 0
	var ms := 0.0
	var scores := {}
	var by_ct := {}
	var fi := 0
	var fo := 0
	for i in n:
		var cl := w.clubs_in_league(ids[i % ids.size()])
		var a: Club = cl[rng.randi_range(0, cl.size() - 1)]
		var b: Club = cl[rng.randi_range(0, cl.size() - 1)]
		if a == b:
			continue
		var hs := ClubAI.prepare_ai_sheet(w, a, b, true)
		var as_ := ClubAI.prepare_ai_sheet(w, b, a, false)
		var sim := MatchSimulation.new()
		sim.setup(w, a, b, hs, as_, {"derby": false, "importance": 0.3, "attendance": int(a.capacity * 0.7), "competition": a.league_id}, rng.randi(), true)
		sim.enable_live(rng.randi())
		var t0 := Time.get_ticks_msec()
		sim.run_to_end()
		ms += Time.get_ticks_msec() - t0
		var r := sim.to_result()
		var hg := int(r["hg"])
		var ag := int(r["ag"])
		scores["%d-%d" % [hg, ag]] = int(scores.get("%d-%d" % [hg, ag], 0)) + 1
		if hg > ag:
			hw += 1
		elif hg == ag:
			dr += 1
		var sa := ClubAI.team_strength(w, a)
		var sb := ClubAI.team_strength(w, b)
		if absf(sa - sb) >= 3.0:
			fav_n += 1
			if (sa > sb and hg > ag) or (sb > sa and ag > hg):
				fav_w += 1
		for t: MatchTeam in sim.teams:
			tot["g"] += sim.score[t.side]
			tot["sh"] += t.shots
			tot["on"] += t.on_target
			tot["xg"] += t.xg
			tot["fo"] += t.fouls
			tot["co"] += t.corners
			tot["off"] += t.offsides
			tot["yc"] += t.yellows
			tot["rc"] += t.reds
			tot["pas"] += sim.live.passes[t.side]
			tot["pok"] += sim.live.passes_ok[t.side]
			tot["tk"] += sim.live.tackles[t.side]
			for mp: MatchPlayer in t.all:
				if mp.used and mp.minutes_played(90) >= 45:
					rat += mp.final_rating
					rat_n += 1
		for ev in sim.events:
			if int(ev["t"]) in [MatchSimulation.EV_GOAL, MatchSimulation.EV_SAVE, MatchSimulation.EV_MISS, MatchSimulation.EV_POST, MatchSimulation.EV_BLOCK]:
				var ct := int(ev.get("x", {}).get("ct", -1))
				by_ct[ct] = int(by_ct.get(ct, 0)) + 1
		fi += sim.live.fail_int[0] + sim.live.fail_int[1]
		fo += sim.live.fail_out[0] + sim.live.fail_out[1]
		var p0 := sim.possession_pct(0)
		poss_min = minf(poss_min, p0)
		poss_max = maxf(poss_max, p0)
	var teams := float(n * 2)
	print("jogos %d | %.0f ms/jogo" % [n, ms / n])
	print("por time: gols %.2f · chutes %.1f · no gol %.1f · xG %.2f · passes %.0f (%.0f%% certos) · desarmes %.0f" % [tot["g"] / teams, tot["sh"] / teams, tot["on"] / teams, tot["xg"] / teams, tot["pas"] / teams, 100.0 * tot["pok"] / maxf(1.0, tot["pas"]), tot["tk"] / teams])
	print("faltas %.1f · escanteios %.1f · impedimentos %.1f · amarelos %.1f · vermelhos %.2f" % [tot["fo"] / teams, tot["co"] / teams, tot["off"] / teams, tot["yc"] / teams, tot["rc"] / teams])
	print("mandante %.0f%% · empates %.0f%% · favorito (gap>=3) vence %.0f%% de %d · posse %.0f–%.0f%% · nota média %.2f" % [100.0 * hw / n, 100.0 * dr / n, 100.0 * fav_w / maxf(1, fav_n), fav_n, poss_min * 100, poss_max * 100, rat / maxf(1, rat_n)])
	var keys := scores.keys()
	keys.sort_custom(func(x, y): return scores[x] > scores[y])
	var top: Array = []
	for k in keys.slice(0, 8):
		top.append("%s×%d" % [k, scores[k]])
	print("placares: ", ", ".join(top))
	print("passes errados por time: interceptados %.0f · para fora %.0f" % [fi / teams, fo / teams])
	print("chutes por tipo (0 enfiada,1 cruz,2 longe,3 drible,4 contra,5 sobra,6 esc,7 falta): ", by_ct)
	quit()
