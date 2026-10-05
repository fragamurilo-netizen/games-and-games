extends SceneTree
## Mercado numa carreira sul-americana (calendário de ano civil): negócios por data, quem a Europa
## leva da América do Sul (idade e valor), para onde vão os sul-americanos e as maiores vendas da região.
## godot --headless --path . --script res://tools/market_sa_report.gd -- [--days=N] [--cal=ano|eu] [--seasons=N]

const SA := ["BRA", "ARG", "URU", "COL", "CHI", "ECU", "PER", "PAR", "BOL", "VEN"]
const EU := ["ENG", "ESP", "ITA", "GER", "FRA", "POR", "NED", "BEL", "TUR", "SCO", "GRE", "AUT", "SUI", "UKR", "CRO", "SRB", "CZE", "DEN"]

var opt_days := 0
var opt_cal := "ano"
var opt_seasons := 1


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--days="):
			opt_days = int(a.substr(7))
		elif a.begins_with("--cal="):
			opt_cal = a.substr(6)
		elif a.begins_with("--seasons="):
			opt_seasons = int(a.substr(10))
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	w.user_club_id = w.clubs_in_league("BRA1")[0].id
	w.stats["cal"] = "ano" if opt_cal == "ano" else ""
	w.season = SeasonManager.build_season(w)
	SeasonManager.compute_goals(w)
	var t0 := Time.get_ticks_msec()
	var per_slot := {}
	var guard := 0
	var seasons := 0
	while seasons < opt_seasons:
		while not w.season.finished and guard < 400 * opt_seasons and (opt_days == 0 or guard < opt_days):
			var slot := w.season.day
			var code := String(w.season.calendar[slot]["t"])
			var before := w.transfer_log.size()
			SeasonManager.play_matchday_instant(w)
			var k := "%d %s%s" % [slot, code, " (janela)" if w.window_open_at(slot) else ""]
			per_slot[k] = w.transfer_log.size() - before
			guard += 1
		seasons += 1
		if seasons < opt_seasons and w.season.finished:
			SeasonManager.end_season(w)
	print("datas: %d · %.1fs · transferências no log: %d" % [guard, (Time.get_ticks_msec() - t0) / 1000.0, w.transfer_log.size()])
	var line := []
	for k in per_slot:
		if int(per_slot[k]) > 0:
			line.append("%s=%d" % [k, per_slot[k]])
	print("por data: " + ", ".join(line))
	var to_eu := []
	var sa_dest := {}
	var sa_buy_src := {}
	var big_sa := []
	var dom_sa := 0
	var tot_sa := 0
	var fee_sa_out := 0
	for t: Transfer in w.transfer_log:
		var to := w.club(t.to_id)
		var from := w.club(t.from_id)
		if to == null:
			continue
		if from != null and SA.has(from.nation):
			tot_sa += 1
			sa_dest[to.nation] = int(sa_dest.get(to.nation, 0)) + 1
			if to.nation == from.nation:
				dom_sa += 1
			else:
				fee_sa_out += t.fee
			if EU.has(to.nation):
				to_eu.append(t)
			big_sa.append(t)
		if SA.has(to.nation):
			var src := from.nation if from != null else "livre"
			sa_buy_src[src] = int(sa_buy_src.get(src, 0)) + 1
	print("saídas de clubes sul-americanos: %d (no próprio país %d) · arrecadado fora: %s" % [tot_sa, dom_sa, Fmt.money(fee_sa_out)])
	print("destinos: %s" % _top(sa_dest, 10))
	print("sul-americanos compram de: %s" % _top(sa_buy_src, 10))
	var ages := {}
	for t: Transfer in to_eu:
		var band := "≤20" if t.age <= 20 else ("21-23" if t.age <= 23 else ("24-27" if t.age <= 27 else "28+"))
		ages[band] = int(ages.get(band, 0)) + 1
	print("para a Europa: %d · idades %s" % [to_eu.size(), _top(ages, 4)])
	big_sa.sort_custom(func(a: Transfer, b: Transfer): return a.fee > b.fee)
	print("maiores vendas sul-americanas:")
	for t: Transfer in big_sa.slice(0, 15):
		print("  %s %s (%d anos, %d): %s → %s" % [Fmt.money(t.fee), t.player_name, t.age, t.overall, w.club(t.from_id).short_name, w.club(t.to_id).short_name])
	for k in ["solidarity", "rights_cut", "medical_fail", "loans", "auctions", "swaps", "talks"]:
		if w.stats.has(k):
			print("%s: %s" % [k, w.stats[k]])
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
