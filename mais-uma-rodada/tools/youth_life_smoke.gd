extends SceneTree
## Vida na base (YouthLife) em duas temporadas com o auxiliar no comando: empresários, contrato
## profissional, saudade, pai cobrando minutos, desistências e a maturação enganando a avaliação.
## godot --headless --path . --script res://tools/youth_life_smoke.gd -- [--seasons=N]

func _initialize() -> void:
	var seasons := 2
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seasons="):
			seasons = int(a.substr(10))
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	w.user_club_id = w.clubs_in_league("BRA1")[2].id
	w.manager_name = "Teste"
	w.season = SeasonManager.build_season(w)
	SeasonManager.compute_goals(w)
	People.ensure(w)
	YouthManager.ensure_academy(w)
	YouthManager.build_league(w)
	Autopilot.mode = Autopilot.MODE_ALL
	var kinds := {}
	var quit_total := 0
	for s in seasons:
		var guard := 0
		while guard < 90 and w.season != null and not w.season.finished:
			guard += 1
			var club := w.user_club()
			if club.sheet != null:
				club.sheet = ClubAI.auto_sheet(w, club, club.sheet.formation)
			Autopilot.prepare_match(w, club)
			SeasonManager.play_matchday_instant(w)
			for ev in EventManager.pending(w):
				if YouthLife.handles(String(ev["k"])):
					kinds[ev["k"]] = int(kinds.get(ev["k"], 0)) + 1
			Autopilot.handle(w)
		_report(w, "fim da temporada %d" % w.year)
		var summary := SeasonManager.end_season(w)
		quit_total += Array(summary.get("youth_quit", [])).size()
		for q in summary.get("youth_quit", []):
			print("  desistiu: %s" % q)
		w.season = SeasonManager.build_season(w)
		SeasonManager.compute_goals(w)
	print("dilemas da base: %s · desistências: %d" % [kinds, quit_total])
	var lg: Array = w.stats.get("auto_log", [])
	for e: Dictionary in lg:
		if String(e["w"]).contains("mpresário") or String(e["w"]).contains("casa") or String(e["w"]).contains("Pai de"):
			print("  %s · %s → %s" % [e["d"], e["w"], String(e["r"]).left(110)])
	print("YOUTH_LIFE_OK")
	quit(0)


func _report(w: GameWorld, title: String) -> void:
	var pro := 0
	var hs := 0
	var ag := 0
	var early := 0
	var late := 0
	var err_early := 0.0
	var err_late := 0.0
	for p: Player in w.academy.values():
		var e := YouthLife.of(w, p)
		if YouthLife.has_pro(w, p):
			pro += 1
		if float(e["hs"]) >= 35.0:
			hs += 1
		if float(e["ag"]) >= 40.0:
			ag += 1
		var edge := YouthLife.maturity_edge(w, p)
		var err := float(YouthManager.estimate(w, p) - p.potential)
		if edge >= 1.0:
			early += 1
			err_early += err
		elif edge <= -1.0:
			late += 1
			err_late += err
	print("%s: base %d · contrato profissional %d · saudade %d · empresários rondando %d · precoces %d (erro médio %+.1f) · tardios %d (erro médio %+.1f)" % [
		title, w.academy.size(), pro, hs, ag, early, err_early / maxf(1.0, early), late, err_late / maxf(1.0, late)])
