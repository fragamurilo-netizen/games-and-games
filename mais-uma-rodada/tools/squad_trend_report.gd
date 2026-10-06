extends SceneTree
## Os grandes ao longo das temporadas: força do time titular, valor do elenco, idade média,
## contratações e vendas e caixa. Mostra se os ricos reinvestem ou deixam o elenco envelhecer.
## godot --headless --path . --script res://tools/squad_trend_report.gd -- [--seasons=N]

const CLUBS := ["Real Madrid", "Man City", "Barcelona", "Bayern", "Flamengo", "Palmeiras", "Corinthians", "Boca Juniors", "Benfica", "Arsenal"]


func _initialize() -> void:
	var seasons := 3
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seasons="):
			seasons = int(a.substr(10))
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	w.user_club_id = -1
	_report(w)
	for s in seasons:
		var guard := 0
		while not w.season.finished and guard < 400:
			SeasonManager.play_matchday_instant(w)
			guard += 1
		var buys := {}
		var sells := {}
		var spent := {}
		for t: Transfer in w.transfer_log:
			if t.year != w.year:
				continue
			buys[t.to_id] = int(buys.get(t.to_id, 0)) + 1
			spent[t.to_id] = int(spent.get(t.to_id, 0)) + t.fee
			sells[t.from_id] = int(sells.get(t.from_id, 0)) + 1
		print("-- mercado da temporada %d: clube compras(€M gastos)/vendas" % w.year)
		for c: Club in _clubs(w):
			print("   %-14s %2d (%4.0f) / %2d" % [c.short_name, int(buys.get(c.id, 0)), float(spent.get(c.id, 0)) / 1e6, int(sells.get(c.id, 0))])
		SeasonManager.end_season(w)
		_report(w)
	quit()


func _clubs(w: GameWorld) -> Array:
	var out: Array = []
	for nm in CLUBS:
		for c: Club in w.clubs:
			if c.short_name == nm and c.tier <= 2 and c.nation != "URU":
				out.append(c)
				break
	return out


func _report(w: GameWorld) -> void:
	print("== %d: clube | XI | elenco € mi | idade XI | caixa | verba | folha/ano" % w.year)
	for c: Club in _clubs(w):
		var sq: Array = w.squad(c)
		sq.sort_custom(func(a: Player, b: Player): return a.ovr_f > b.ovr_f)
		var xi := 0.0
		var age := 0.0
		var val := 0.0
		for i in mini(11, sq.size()):
			xi += sq[i].ovr_f
			age += sq[i].age(w.year)
		for p: Player in sq:
			val += p.value
		var n := float(mini(11, sq.size()))
		print("   %-14s %5.1f | %5.0f | %4.1f | %5.0f | %4.0f | %4.0f" % [c.short_name, xi / n, val / 1e6, age / n, c.balance / 1e6, c.transfer_budget / 1e6, FinanceManager.wage_bill(w, c) * 12.0 / 1e6])
