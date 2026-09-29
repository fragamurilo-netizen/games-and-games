extends SceneTree
## Laboratório tático: o quanto cada plano muda o jogo (minuto a minuto, o motor do usuário).
## Um clube "usuário" (sem o técnico da IA mexendo nele) enfrenta, fora de casa, um rival mais forte,
## um parecido e um mais fraco da mesma liga, com vários planos. Compara com o plano que a IA
## escolheria (ClubAI.prepare_ai_sheet) no mesmo jogo.
## Uso: godot --headless --path . --script res://tools/tactic_lab.gd [-- --n=300 --league=ENG1]

const PLANS := [
	# [nome, mentalidade, estilo, pressão, linha, largura]
	["IA (plano próprio)", -1, -1, -1, -1, -1],
	["retranca + contra", 0, TeamSheet.STYLE_CONTRA, 0, 0, 1],
	["defensivo + contra", 1, TeamSheet.STYLE_CONTRA, 1, 0, 1],
	["equilibrado posse", 2, TeamSheet.STYLE_POSSE, 1, 1, 1],
	["ofensivo pressão", 3, TeamSheet.STYLE_PRESSAO, 2, 2, 1],
	["tudo ou nada", 4, TeamSheet.STYLE_DIRETO, 2, 2, 2],
]


func _initialize() -> void:
	var n := 300
	var lid := "ENG1"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--n="):
			n = int(a.substr(4))
		elif a.begins_with("--league="):
			lid = a.substr(9)
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	var cl := w.clubs_in_league(lid)
	cl.sort_custom(func(x, y): return ClubAI.team_strength(w, x) > ClubAI.team_strength(w, y))
	var me: Club = cl[cl.size() / 2]
	var opps := {"mais forte": cl[0], "parecido": cl[cl.size() / 2 + 1], "mais fraco": cl[cl.size() - 1]}
	w.user_club_id = me.id
	print("%s (força %.1f) fora de casa, %d jogos por plano" % [me.short_name, ClubAI.team_strength(w, me), n])
	for key in opps:
		var opp: Club = opps[key]
		print("--- contra o %s: %s (força %.1f)" % [key, opp.short_name, ClubAI.team_strength(w, opp)])
		for plan in PLANS:
			var pts := 0
			var gf := 0
			var ga := 0
			var xf := 0.0
			var xa := 0.0
			var wins := 0
			var draws := 0
			for i in n:
				var hs := ClubAI.prepare_ai_sheet(w, opp, me, true)
				w.user_club_id = -1
				var ms := ClubAI.prepare_ai_sheet(w, me, opp, false).duplicate_sheet()
				w.user_club_id = me.id
				if int(plan[1]) >= 0:
					ms.mentality = plan[1]
					ms.style = plan[2]
					ms.pressing = plan[3]
					ms.line = plan[4]
					ms.width = plan[5]
				ms.auto_subs = true
				var sim := MatchSimulation.new()
				sim.setup(w, opp, me, hs, ms, {"derby": false, "importance": 0.3, "attendance": int(opp.capacity * 0.8), "competition": lid}, 7000 + i, false)
				sim.run_to_end()
				var g0 := sim.score[1]
				var g1 := sim.score[0]
				gf += g0
				ga += g1
				xf += sim.teams[1].xg
				xa += sim.teams[0].xg
				if g0 > g1:
					pts += 3
					wins += 1
				elif g0 == g1:
					pts += 1
					draws += 1
			var label: String = plan[0]
			if int(plan[1]) < 0:
				w.user_club_id = -1
				var ai := ClubAI.prepare_ai_sheet(w, me, opp, false)
				label += " [ment %d, %s, pressão %d, linha %d]" % [ai.mentality, TacticsManager._style_name(ai.style), ai.pressing, ai.line]
				w.user_club_id = me.id
			print("  %-60s pts/jogo %.2f | V %.0f%% E %.0f%% | gols %.2f x %.2f | xG %.2f x %.2f" % [label, float(pts) / n, 100.0 * wins / n, 100.0 * draws / n, float(gf) / n, float(ga) / n, xf / n, xa / n])
	quit()
