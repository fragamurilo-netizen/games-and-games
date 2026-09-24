extends SceneTree
## Simula N temporadas sem interface e gera um relatório de balanceamento.
## Uso:
##   godot --headless --path . --script res://tests/season_simulator.gd -- --seasons=100 --seed=123 --type=padrao --out=user://relatorio.md
## Métricas: média de gols, mando, transferências, idade média, equilíbrio financeiro, campeões,
## rebaixamentos, distribuição de overall, inflação de valores, jovens gerados e aposentadorias.

var rows: Array = []
var champions: Dictionary = {} # por liga/copa: {club_id: títulos}
var lines: Array = []
const TOP := ["ENG1", "ESP1", "GER1", "ITA1", "FRA1", "POR1", "BRA1", "ARG1", "USA1", "MEX1"]


func _initialize() -> void:
	var args := _args()
	var seasons := int(args.get("seasons", "10"))
	var seed_value := int(args.get("seed", str(WorldGenerator.DEFAULT_SEED)))
	var wtype: String = args.get("type", "padrao")
	var out_path: String = args.get("out", "user://relatorio_simulacao.md")
	var t0 := Time.get_ticks_msec()
	var w := WorldGenerator.generate(seed_value, wtype)
	_log("Mundo gerado em %d ms (seed %d, %s): %d clubes, %d jogadores" % [Time.get_ticks_msec() - t0, seed_value, wtype, w.clubs.size(), w.players.size()])
	var first_value := _avg_value(w)
	var first_wage := _avg_wage(w)
	for s in seasons:
		var ts := Time.get_ticks_msec()
		var trans_before := float(w.stats.get("transfers", 0.0))
		var fees_before := float(w.stats.get("transfer_fees", 0.0))
		var ret_before := float(w.stats.get("retirements", 0.0))
		var youth_before := float(w.stats.get("youth_generated", 0.0))
		while not w.season.finished:
			SeasonManager.play_matchday_instant(w)
		var row := _season_metrics(w)
		row["transfers"] = int(float(w.stats.get("transfers", 0.0)) - trans_before)
		row["fees"] = float(w.stats.get("transfer_fees", 0.0)) - fees_before
		var year := w.year
		var summary := SeasonManager.end_season(w)
		row["retirements"] = int(float(w.stats.get("retirements", 0.0)) - ret_before)
		row["youth"] = int(float(w.stats.get("youth_generated", 0.0)) - youth_before)
		row["year"] = year
		row["ms"] = Time.get_ticks_msec() - ts
		row["players"] = w.players.size()
		row["free"] = w.free_agents().size()
		var champs: Array = []
		for dv in summary["leagues"] + summary["cups"]:
			var cid: int = dv["champion"]
			var key := String(dv["id"])
			if cid < 0:
				continue
			if not champions.has(key):
				champions[key] = {}
			champions[key][cid] = int(champions[key].get(cid, 0)) + 1
			if int(dv.get("tier", 1)) == 1 and (TOP.has(key) or not DatabaseManager.has_league(key)):
				champs.append("%s:%s" % [key, w.club(cid).abbr])
		row["champions"] = champs
		rows.append(row)
		_log("%d | gols %.2f | M/E/V %d/%d/%d%% | transf %d (%s) | idade %.1f | ovr ENG1 %.1f BRA1 %.1f | 80+ %d | caixa %s (%d no vermelho) | valor médio %s | jovens %d | aposent. %d | jogadores %d (livres %d) | campeões %s | %d ms" % [
			year, row["goals"], row["home"], row["draw"], row["away"], row["transfers"], Fmt.money(row["fees"]), row["age"],
			float(row["ovr_div"].get("ENG1", 0.0)), float(row["ovr_div"].get("BRA1", 0.0)), row["elite"], Fmt.money(row["money"]), row["debt_clubs"], Fmt.money(row["value"]),
			row["youth"], row["retirements"], row["players"], row["free"], ", ".join(champs), row["ms"]])
		_log("      idades(n, ovr médio, +potencial): %s | amplitude força ENG1: %.1f | talento (%d/clube): %.1f (desvio %+.2f, correção %+.2f)" % [row["ages"], row["spread"], PlayerDevelopment.TALENT_PER_CLUB, PlayerDevelopment.talent_index(w), float(w.stats.get("talent_raw", 0.0)), PlayerDevelopment.talent_drift(w)])
	var last_value := _avg_value(w)
	var last_wage := _avg_wage(w)
	_log("")
	_log("RESUMO (%d temporadas, %.1f s)" % [seasons, (Time.get_ticks_msec() - t0) / 1000.0])
	var g := 0.0
	for r in rows:
		g += r["goals"]
	_log("Média de gols: %.2f por jogo" % (g / maxf(1.0, rows.size())))
	_log("Inflação de valor médio: %s → %s (x%.2f) · salário médio %s → %s (x%.2f)" % [Fmt.money(first_value), Fmt.money(last_value), last_value / maxf(1.0, first_value), Fmt.money(first_wage), Fmt.money(last_wage), last_wage / maxf(1.0, first_wage)])
	for d in champions:
		if DatabaseManager.has_league(d) and not TOP.has(d):
			continue
		var list: Array = []
		for cid in champions[d]:
			list.append([cid, champions[d][cid]])
		list.sort_custom(func(a, b): return a[1] > b[1])
		var txt: Array = []
		for e in list.slice(0, 6):
			txt.append("%s %d" % [w.club(e[0]).short_name, e[1]])
		_log("Campeões %s: %d clubes diferentes — %s" % [CompText.comp_short(w, d), list.size(), ", ".join(txt)])
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(lines))
		_log("Relatório salvo em " + ProjectSettings.globalize_path(out_path))
	quit()


func _season_metrics(w: GameWorld) -> Dictionary:
	var goals := 0
	var n := 0
	var hw := 0
	var dr := 0
	for l: League in w.season.leagues.values():
		for r in l.rounds:
			for f: Fixture in r:
				if not f.played:
					continue
				n += 1
				goals += f.hg + f.ag
				if f.hg > f.ag:
					hw += 1
				elif f.hg == f.ag:
					dr += 1
	var ages := 0.0
	var cnt := 0
	var elite := 0
	for p: Player in w.players.values():
		if p.club_id < 0:
			continue
		ages += p.age(w.year)
		cnt += 1
		if p.overall >= 80:
			elite += 1
	var ovr_div: Dictionary = {}
	var spread_d1 := 0.0
	for l: League in w.season.leagues.values():
		var s := 0.0
		var vals: Array = []
		for cid in l.club_ids:
			var v := ClubAI._compute_strength(w, w.club(cid))
			vals.append(v)
			s += v
		var mean := s / l.club_ids.size()
		ovr_div[l.id] = mean
		if l.id == "ENG1":
			vals.sort()
			spread_d1 = vals[vals.size() - 1] - vals[0]
	var buckets := [[17, 20], [21, 24], [25, 28], [29, 32], [33, 45]]
	var bsum := [0.0, 0.0, 0.0, 0.0, 0.0]
	var bn := [0, 0, 0, 0, 0]
	var gap_sum := [0.0, 0.0, 0.0, 0.0, 0.0]
	for p: Player in w.players.values():
		if p.club_id < 0:
			continue
		var a := p.age(w.year)
		for bi in buckets.size():
			if a >= buckets[bi][0] and a <= buckets[bi][1]:
				bsum[bi] += p.ovr_f
				gap_sum[bi] += p.potential - p.ovr_f
				bn[bi] += 1
	var age_txt: Array = []
	for bi in buckets.size():
		age_txt.append("%d-%d:%d(%.0f,+%.1f)" % [buckets[bi][0], buckets[bi][1], bn[bi], bsum[bi] / maxf(1, bn[bi]), gap_sum[bi] / maxf(1, bn[bi])])
	var money := 0.0
	var debt := 0
	for c: Club in w.clubs:
		money += c.balance
		if c.balance < 0:
			debt += 1
	return {
		"goals": float(goals) / maxf(1.0, n), "home": int(100.0 * hw / maxf(1.0, n)), "draw": int(100.0 * dr / maxf(1.0, n)),
		"away": int(100.0 * (n - hw - dr) / maxf(1.0, n)), "age": ages / maxf(1.0, cnt), "elite": elite, "ovr_div": ovr_div,
		"money": money, "debt_clubs": debt, "value": _avg_value(w), "ages": " ".join(age_txt), "spread": spread_d1,
	}


func _avg_value(w: GameWorld) -> float:
	var s := 0.0
	var n := 0
	for p: Player in w.players.values():
		if p.club_id >= 0:
			s += p.value
			n += 1
	return s / maxf(1.0, n)


func _avg_wage(w: GameWorld) -> float:
	var s := 0.0
	var n := 0
	for p: Player in w.players.values():
		if p.club_id >= 0:
			s += p.wage
			n += 1
	return s / maxf(1.0, n)


func _log(s: String) -> void:
	print(s)
	lines.append(s)


func _args() -> Dictionary:
	var out := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			var kv := a.substr(2).split("=", true, 1)
			out[kv[0]] = kv[1]
	return out
