extends SceneTree
## Mercado de técnicos de ponta a ponta, sem interface: joga algumas rodadas, lista vagas e
## cargos por um fio, manda candidatura, faz a entrevista, pede demissão e assina com outro clube.
## godot --headless --path . --script res://tools/job_market_smoke.gd -- [--rounds=N]

var opt_rounds := 12


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--rounds="):
			opt_rounds = int(a.substr(9))
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	var bra: Array = w.clubs_in_league("BRA1")
	w.user_club_id = bra[bra.size() - 1].id
	w.manager_name = "Teste"
	w.season = SeasonManager.build_season(w)
	SeasonManager.compute_goals(w)
	People.ensure(w)
	var fails := 0
	var approaches := 0
	for i in opt_rounds:
		if w.season != null and not w.season.finished:
			SeasonManager.play_matchday_instant(w)
		if not People.job_offer(w).is_empty():
			approaches += 1
	print("rodadas: %d · turno %d · reputação %.1f · sondagens vistas: %d" % [opt_rounds, w.current_turn(), People.manager_rep(w), approaches])
	var vac := JobMarket.vacancies(w)
	print("vagas abertas: %d" % vac.size())
	for c: Club in vac.slice(0, 8):
		print("  %s (%s, rep %.0f) · cotação %s %.2f" % [c.short_name, w.league_short(c.league_id), c.reputation, JobMarket.fit_label(JobMarket.fit(w, c)), JobMarket.fit(w, c)])
	var hot := JobMarket.hot_seats(w)
	print("cargos por um fio: %d" % hot.size())
	# Candidatura até conseguir uma entrevista.
	var target: Club = null
	vac.sort_custom(func(a: Club, b: Club): return JobMarket.fit(w, a) > JobMarket.fit(w, b))
	for c: Club in vac:
		JobMarket.data(w)["last"] = -99 # o teste não espera o intervalo entre candidaturas
		var res := JobMarket.apply(w, c.id)
		print("candidatura ao %s: %s" % [c.short_name, res["text"]])
		if res["ok"]:
			target = c
			break
	if target != null:
		var conv := Talks.start(w, "interview", target.id)
		var guard := 0
		while not conv["done"] and guard < 10:
			guard += 1
			Talks.choose(w, conv, "0")
		for ln in conv["lines"]:
			print("  [%s] %s" % [ln[0], ln[1]])
		print("proposta: %s" % str(conv["d"].get("offer", false)))
		if (conv["lines"] as Array).size() < 6:
			fails += 1
			print("FALHA: entrevista curta demais")
	# Demissão e nova casa.
	var old := w.user_club()
	JobMarket.resign(w)
	if not JobMarket.unemployed(w):
		fails += 1
		print("FALHA: demissão não deixou o técnico sem clube")
	var offers := BoardManager.pending_job_offers(w)
	print("sem clube · propostas: %d · vagas: %d" % [offers.size(), JobMarket.vacancies(w).size()])
	if offers.is_empty():
		fails += 1
		print("FALHA: sem propostas depois da demissão")
	else:
		JobMarket.accept(w, int(offers[0]))
		print("novo clube: %s (antes %s)" % [w.user_club().short_name, old.short_name])
		if w.user_club_id == old.id or JobMarket.unemployed(w):
			fails += 1
			print("FALHA: não assumiu o clube novo")
		var co: Dictionary = People.data(w)["coaches"].get(old.id, {})
		print("o %s agora tem técnico: %s" % [old.short_name, String(co.get("n", "-"))])
	# O jogo segue no clube novo.
	for _k in 3:
		if w.season != null and not w.season.finished:
			SeasonManager.play_matchday_instant(w)
	print("JOB_MARKET_OK" if fails == 0 else "JOB_MARKET_FALHOU (%d)" % fails)
	quit(0 if fails == 0 else 1)
