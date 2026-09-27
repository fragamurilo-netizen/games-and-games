extends SceneTree
## Mercado de uma temporada (ou N datas): de onde cada país contrata, nacionalidade dos reforços,
## idas entre rivais, joias da base vendidas a concorrentes e as maiores transferências.
## godot --headless --path . --script res://tools/market_report.gd -- --days=12

var opt_days := 0 # 0 = temporada inteira


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--days="):
			opt_days = int(a.substr(7))
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	w.user_club_id = w.clubs_in_league("BRA1")[0].id
	var t0 := Time.get_ticks_msec()
	var guard := 0
	while not w.season.finished and guard < 400 and (opt_days == 0 or guard < opt_days):
		SeasonManager.play_matchday_instant(w)
		guard += 1
	print("datas: %d · %.1fs" % [guard, (Time.get_ticks_msec() - t0) / 1000.0])
	var by_buyer := {} # nação compradora -> {origem (liga do vendedor): n}
	var by_nat := {} # nação compradora -> {nacionalidade: n}
	var rivals: Array = []
	var fees: Array = []
	var n := 0
	var free := 0
	for t: Transfer in w.transfer_log:
		var to := w.club(t.to_id)
		if to == null:
			continue
		var from := w.club(t.from_id)
		var p := w.player(t.player_id)
		n += 1
		if t.kind != Transfer.KIND_BUY:
			free += 1
		var src := from.nation if from != null else "livre"
		if not by_buyer.has(to.nation):
			by_buyer[to.nation] = {}
			by_nat[to.nation] = {}
		by_buyer[to.nation][src] = int(by_buyer[to.nation].get(src, 0)) + 1
		if p != null:
			by_nat[to.nation][p.nationality] = int(by_nat[to.nation].get(p.nationality, 0)) + 1
		if from != null and (from.is_rival(to.id) or to.is_rival(from.id)):
			rivals.append("%s → %s: %s (%d anos, %d) %s" % [from.short_name, to.short_name, t.player_name, t.age, t.overall, Fmt.money(t.fee)])
		fees.append(t)
	fees.sort_custom(func(a: Transfer, b: Transfer): return a.fee > b.fee)
	print("transferências: %d (sem custo %d)" % [n, free])
	for nat in ["BRA", "ARG", "ENG", "ESP", "ITA", "GER", "FRA", "POR", "NED", "KSA", "USA", "MEX", "TUR"]:
		if not by_buyer.has(nat):
			continue
		print("%s compra de: %s" % [nat, _top(by_buyer[nat], 7)])
		print("     nacionalidades: %s" % _top(by_nat[nat], 7))
	print("rivais (%d):" % rivals.size())
	for r in rivals.slice(0, 12):
		print("  " + r)
	print("maiores:")
	for t: Transfer in fees.slice(0, 20):
		var from := w.club(t.from_id)
		print("  %s %s (%d anos, %d): %s → %s" % [Fmt.money(t.fee), t.player_name, t.age, t.overall, from.short_name if from != null else "livre", w.club(t.to_id).short_name])
	quit()


func _top(d: Dictionary, k: int) -> String:
	var keys := d.keys()
	var tot := 0
	for x in keys:
		tot += int(d[x])
	keys.sort_custom(func(a, b): return int(d[a]) > int(d[b]))
	var parts: Array = []
	for x in keys.slice(0, k):
		parts.append("%s %d%%" % [x, int(round(100.0 * d[x] / maxf(1.0, tot)))])
	return "%s (n=%d)" % [", ".join(parts), tot]
