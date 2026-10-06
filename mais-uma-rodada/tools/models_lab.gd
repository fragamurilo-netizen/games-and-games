extends SceneTree
## Formações e modelos de jogo no motor: um clube do meio da tabela, fora de casa, contra um rival
## parecido. Primeiro cada formação com o mesmo plano neutro (nenhuma pode ser muito melhor que as
## outras), depois cada modelo de jogo pronto (GameModels). Entrosamento igual para todos.
## godot --headless --path . --script res://tools/models_lab.gd -- [--n=200] [--league=ENG1] [--only=formations|models]

func _initialize() -> void:
	var n := 200
	var lid := "ENG1"
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--n="):
			n = int(a.substr(4))
		elif a.begins_with("--league="):
			lid = a.substr(9)
		elif a.begins_with("--only="):
			only = a.substr(7)
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	var cl := w.clubs_in_league(lid)
	cl.sort_custom(func(x, y): return ClubAI.team_strength(w, x) > ClubAI.team_strength(w, y))
	var me: Club = cl[cl.size() / 2]
	var opp: Club = cl[cl.size() / 2 + 1]
	w.user_club_id = me.id
	print("%s (força %.1f) fora contra %s (%.1f), %d jogos" % [me.short_name, ClubAI.team_strength(w, me), opp.short_name, ClubAI.team_strength(w, opp), n])
	if only != "models":
		print("--- formações (plano neutro: equilibrado, posse, tudo normal)")
		for fname in DatabaseManager.formation_names():
			var m := {"f": fname, "m": 2, "st": 0}
			_run(w, me, opp, m, String(fname), n)
	if only != "formations":
		print("--- modelos de jogo")
		for m: Dictionary in GameModels.all():
			_run(w, me, opp, m, "%s (%s)" % [m["name"], m["f"]], n)
	quit()


func _run(w: GameWorld, me: Club, opp: Club, model: Dictionary, label: String, n: int) -> void:
	var pts := 0
	var gf := 0
	var ga := 0
	var xf := 0.0
	var xa := 0.0
	for i in n:
		var hs := ClubAI.prepare_ai_sheet(w, opp, me, true)
		var ms := TeamSheet.new()
		ms.formation = DatabaseManager.formation_names()[0]
		me.tactic_fam = {} # entrosamento igual (padrão) para todas as formações e estilos
		GameModels.apply(w, me, ms, model)
		if ms.starters.is_empty():
			GameModels.reshape(w, me, ms, ms.formation)
		ms.auto_subs = true
		var sim := MatchSimulation.new()
		sim.setup(w, opp, me, hs, ms, {"derby": false, "importance": 0.3, "attendance": int(opp.capacity * 0.8), "competition": w.club(opp.id).league_id}, 9000 + i, false)
		sim.run_to_end()
		var g0: int = sim.score[1]
		var g1: int = sim.score[0]
		gf += g0
		ga += g1
		xf += sim.teams[1].xg
		xa += sim.teams[0].xg
		pts += 3 if g0 > g1 else (1 if g0 == g1 else 0)
	print("  %-36s pts/jogo %.2f | gols %.2f x %.2f | xG %.2f x %.2f" % [label, float(pts) / n, float(gf) / n, float(ga) / n, xf / n, xa / n])
