extends SceneTree
## Auxiliar no comando (Autopilot) numa temporada inteira, sem interface: escala, plano de cada
## jogo, decisões, propostas e conversas. Confere que nada fica pendurado e mostra o diário.
## godot --headless --path . --script res://tools/autopilot_smoke.gd -- [--mode=1|2] [--rounds=N]

func _initialize() -> void:
	var mode := Autopilot.MODE_ALL
	var rounds := 60
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mode="):
			mode = int(a.substr(7))
		elif a.begins_with("--rounds="):
			rounds = int(a.substr(9))
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	w.user_club_id = w.clubs_in_league("BRA1")[3].id
	w.manager_name = "Teste"
	w.season = SeasonManager.build_season(w)
	SeasonManager.compute_goals(w)
	People.ensure(w)
	Autopilot.mode = mode
	var club := w.user_club()
	var stops := 0
	var guard := 0
	var played := 0
	while guard < rounds and w.season != null and not w.season.finished:
		guard += 1
		club = w.user_club()
		if club.sheet != null:
			club.sheet = ClubAI.auto_sheet(w, club, club.sheet.formation)
		Autopilot.prepare_match(w, club)
		SeasonManager.play_matchday_instant(w)
		played += 1
		var why := Autopilot.handle(w)
		if why != "":
			stops += 1
			if mode == Autopilot.MODE_KEY:
				# No modo "Só o importante" o treinador resolveria aqui; o teste responde pelo padrão.
				for ev in EventManager.pending(w).duplicate():
					EventManager.resolve(w, ev, int(EventManager.describe(w, ev).get("def", 0)))
				for o: TransferOffer in TransferManager.pending_offers(w).duplicate():
					TransferManager.respond_offer(w, o, "reject")
				for q in People.requests(w):
					People.clear_request(w, String(q["k"]), int(q.get("t", -1)))
	var lg: Array = w.stats.get("auto_log", [])
	print("modo %s · datas %d · paradas %d · decisões do auxiliar %d · eventos pendentes %d · propostas pendentes %d" % [
		Autopilot.MODE_NAMES[mode], played, stops, int(w.stats.get("auto_n", 0)), EventManager.pending(w).size(), TransferManager.pending_offers(w).size()])
	for e: Dictionary in lg.slice(maxi(0, lg.size() - 12)):
		print("  %s · %s → %s" % [e["d"], e["w"], String(e["r"]).left(110)])
	var league := w.league_of(w.user_club_id)
	if league != null:
		print("%s: %dº lugar" % [w.user_club().short_name, CompetitionManager.position_of(league, w.user_club_id)])
	var ok := int(w.stats.get("auto_n", 0)) > 0 and (mode != Autopilot.MODE_ALL or EventManager.pending(w).size() == 0)
	print("AUTOPILOT_OK" if ok else "AUTOPILOT_FALHOU")
	quit(0 if ok else 1)
