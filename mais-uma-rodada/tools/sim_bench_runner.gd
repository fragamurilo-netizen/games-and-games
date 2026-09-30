extends Node
## Lógica de tools/sim_bench.gd (carregada depois dos autoloads).

var opt_games := "20"
var opt_league := "BRA1"


func _ready() -> void:
	var t := Time.get_ticks_msec()
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	print("mundo: %d ms" % (Time.get_ticks_msec() - t))
	AppSettings.tutorial_done = true
	GameManager.slot = -1
	GameManager.start_career(w, w.clubs_in_league(opt_league)[3].id, "Teste", GameWorld.DIFF_NORMAL, 9)
	GameManager.slot = -1 # sem gravar: mede só a simulação
	SeasonManager.timings.clear()
	var n := int(opt_games)
	var times: Array = []
	var t_all := Time.get_ticks_usec()
	for i in n:
		if GameManager.season_over():
			break
		var t0 := Time.get_ticks_usec()
		var c := w.user_club()
		c.sheet = ClubAI.auto_sheet(w, c, c.sheet.formation)
		var t1 := Time.get_ticks_usec()
		GameManager.begin_match()
		var t2 := Time.get_ticks_usec()
		var sim := GameManager.user_sim()
		if sim != null:
			sim.run_to_end()
		var t3 := Time.get_ticks_usec()
		var ta := Time.get_ticks_usec()
		if OS.get_environment("SIM_SEQ") == "":
			# Mesmo caminho do jogo: escalações em sequência, partidas em paralelo.
			SeasonManager.run_entries(w, GameManager._ai_queue)
		for e in GameManager._ai_queue if OS.get_environment("SIM_SEQ") != "" else []:
			var f: Fixture = e["f"]
			var hc := w.club(f.home)
			var ac := w.club(f.away)
			var tq := Time.get_ticks_usec()
			var hs := ClubAI.prepare_ai_sheet(w, hc, ac, true)
			var as_ := ClubAI.prepare_ai_sheet(w, ac, hc, false)
			var tq2 := Time.get_ticks_usec()
			e["res"] = QuickMatch.play(w, hc, ac, hs, as_, e["ctx"], e["seed"])
			var tq3 := Time.get_ticks_usec()
			SeasonManager.timings["ai_sheet"] = int(SeasonManager.timings.get("ai_sheet", 0)) + tq2 - tq
			SeasonManager.timings["ai_quick"] = int(SeasonManager.timings.get("ai_quick", 0)) + tq3 - tq2
			SeasonManager.timings["ai_n"] = int(SeasonManager.timings.get("ai_n", 0)) + 1000
		GameManager._ai_queue.clear()
		SeasonManager.timings["pump_ai"] = int(SeasonManager.timings.get("pump_ai", 0)) + Time.get_ticks_usec() - ta
		GameManager.finish_match()
		var t4 := Time.get_ticks_usec()
		times.append(t4 - t0)
		if t4 - t0 > 1000000:
			var d0: Dictionary = get_meta("prev", {})
			for k in SeasonManager.timings:
				var dv := int(SeasonManager.timings[k]) - int(d0.get(k, 0))
				if dv > 50000:
					print("    pico: %s %.0f ms" % [k, dv / 1000.0])
		set_meta("prev", SeasonManager.timings.duplicate())
		print("jogo %2d: %6.1f ms (escalar %.1f · montar %.1f · partida %.1f · data+avanço %.1f)" % [i + 1, (t4 - t0) / 1000.0, (t1 - t0) / 1000.0, (t2 - t1) / 1000.0, (t3 - t2) / 1000.0, (t4 - t3) / 1000.0])
	var total := (Time.get_ticks_usec() - t_all) / 1000.0
	print("TOTAL: %.0f ms para %d jogos (%.1f ms/jogo)" % [total, times.size(), total / maxf(1, times.size())])
	var keys := SeasonManager.timings.keys()
	keys.sort_custom(func(a, b): return SeasonManager.timings[a] > SeasonManager.timings[b])
	for k in keys:
		print("  %-16s %8.1f ms" % [k, SeasonManager.timings[k] / 1000.0])
	get_tree().quit()
