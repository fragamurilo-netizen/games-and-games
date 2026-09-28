extends SceneTree
## Raio-x das finanças e dos ratings: receita, folha, verbas, caixa e dívida de clubes de várias
## ligas no começo e depois de N temporadas, e a distribuição de overall por liga.
## godot --headless --path . --script res://tools/finance_report.gd -- --seasons=2

const LEAGUES := ["ENG1", "ESP1", "ITA1", "GER1", "FRA1", "POR1", "NED1", "BRA1", "BRA2", "ARG1", "USA1", "MEX1", "KSA1", "ENG2", "BRA4"]


func _initialize() -> void:
	var seasons := 1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seasons="):
			seasons = int(a.substr(10))
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	w.user_club_id = -1
	_report(w, "início")
	_ratings(w)
	for s in seasons:
		var guard := 0
		while not w.season.finished and guard < 400:
			SeasonManager.play_matchday_instant(w)
			guard += 1
		_report(w, "fim da temporada %d (antes da virada)" % (s + 1))
		SeasonManager.end_season(w)
		_report(w, "início da temporada %d" % (s + 2))
	_ratings(w)
	quit()


func _pick(w: GameWorld, lid: String) -> Array:
	var cl: Array = w.clubs_in_league(lid)
	if cl.is_empty():
		return []
	cl.sort_custom(func(a: Club, b: Club): return a.reputation > b.reputation)
	return [cl[0], cl[cl.size() / 2], cl[cl.size() - 1]]


func _report(w: GameWorld, title: String) -> void:
	print("\n=== %s ===" % title)
	print("clube | liga | rep | receita/ano | folha/mês | teto folha | verba | caixa | dívida | saúde | folha/receita")
	var crisis := 0
	var total := 0
	for c: Club in w.clubs:
		total += 1
		if FinanceManager.health_label(w, c) in ["Crise", "Endividado"]:
			crisis += 1
	for lid in LEAGUES:
		for c: Club in _pick(w, lid):
			var rev := FinanceManager.expected_revenue(c) + c.income_tv - FinanceManager.tv_income(c)
			var bill := FinanceManager.wage_bill(w, c)
			print("%s | %s | %d | %s | %s | %s | %s | %s | %s | %s | %d%%" % [c.short_name, lid, int(c.reputation), Fmt.money(rev), Fmt.money(bill), Fmt.money(c.wage_budget),
				Fmt.money(c.transfer_budget), Fmt.money(c.balance), Fmt.money(c.debt), FinanceManager.health_label(w, c), int(100.0 * bill * 12.0 / maxf(1.0, rev))])
	print("clubes em crise/endividados: %d de %d" % [crisis, total])


func _ratings(w: GameWorld) -> void:
	print("\n=== overall por liga (média do XI dos 3 mais fortes / médio / mais fraco; melhor jogador) ===")
	for lid in LEAGUES:
		var parts: Array = []
		var best := 0
		for c: Club in _pick(w, lid):
			var sq: Array = w.squad(c)
			var ovr: Array = sq.map(func(p: Player) -> int: return p.overall)
			ovr.sort()
			ovr.reverse()
			var xi := 0.0
			for i in mini(11, ovr.size()):
				xi += ovr[i]
			parts.append(str(int(round(xi / maxf(1.0, mini(11, ovr.size()))))))
			if not ovr.is_empty():
				best = maxi(best, int(ovr[0]))
		print("%s: %s · melhor %d" % [lid, " / ".join(parts), best])
	var all: Array = []
	for p: Player in w.players.values():
		if p.club_id >= 0:
			all.append(p.overall)
	all.sort()
	all.reverse()
	print("top 1/10/50/200/1000 do mundo: %d %d %d %d %d · total %d" % [all[0], all[9], all[49], all[199], all[mini(999, all.size() - 1)], all.size()])
