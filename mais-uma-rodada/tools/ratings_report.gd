extends SceneTree
## Raio-x de overall, potencial, atributos, idade, valor e salário do mundo gerado; com --years=N
## simula N temporadas só de evolução (como dev_curve_report) e mostra a deriva do mundo.
## godot --headless --path . --script res://tools/ratings_report.gd -- --years=4

const TOP5 := ["ENG1", "ESP1", "GER1", "ITA1", "FRA1"]
var opt_years := 0
var opt_real := 0 # temporadas completas (partidas, mercado, virada)


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--years="):
			opt_years = int(a.substr(8))
		elif a.begins_with("--real="):
			opt_real = int(a.substr(7))
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	w.user_club_id = -1
	print("jogadores: %d · clubes: %d" % [w.players.size(), w.clubs.size()])
	_leagues(w)
	_world_top(w)
	_potential(w)
	_attrs(w)
	_ages(w)
	_values(w)
	_wages(w)
	_styles(w)
	if opt_years > 0:
		_simulate(w)
	if opt_real > 0:
		_real(w)
	quit()


func _real(w: GameWorld) -> void:
	print("\n== %d temporadas completas ==" % opt_real)
	print("ano   méd.clubes  méd.titulares  top5 XI  melhor  90+  85+  80+  75+  jogadores  top valor  ≥100M")
	_year_line(w)
	for s in opt_real:
		var guard := 0
		var t0 := Time.get_ticks_msec()
		while not w.season.finished and guard < 400:
			SeasonManager.play_matchday_instant(w)
			guard += 1
		SeasonManager.end_season(w)
		_year_line(w)
		print("  (%.0fs)" % ((Time.get_ticks_msec() - t0) / 1000.0))
	_leagues(w)
	_world_top(w)
	_potential(w)
	_ages(w)
	_values(w)
	_wages(w)


func _group(c: Club) -> String:
	if c.league_id in TOP5:
		return "top5"
	if c.tier == 1:
		var lr: Array = c.league_cfg().get("level", [55, 65])
		return "1a forte" if int(lr[1]) >= 76 else ("1a media" if int(lr[1]) >= 69 else "1a fraca")
	return "2a div" if c.tier == 2 else "3a+ div"


func _xi(w: GameWorld, c: Club) -> Array:
	var sq := w.squad(c)
	sq.sort_custom(func(a, b): return a.ovr_f > b.ovr_f)
	var out: Array = []
	var gk := false
	for p: Player in sq:
		if p.position == Pos.GK:
			if gk:
				continue
			gk = true
		out.append(p)
		if out.size() >= 11:
			break
	return out


func _leagues(w: GameWorld) -> void:
	print("\n== overall por grupo de liga ==")
	print("grupo       clubes  melhor  top10  90+  85+  80+  titular(méd)  melhor XI  pior XI  elenco")
	var g := {}
	for c: Club in w.clubs:
		var k := _group(c)
		if not g.has(k):
			g[k] = {"clubs": 0, "all": [], "xi": [], "xiavg": []}
		var d: Dictionary = g[k]
		d["clubs"] += 1
		var xi := _xi(w, c)
		var s := 0.0
		for p: Player in xi:
			d["xi"].append(p.ovr_f)
			s += p.ovr_f
		d["xiavg"].append(s / maxf(1, xi.size()))
		for p: Player in w.squad(c):
			d["all"].append(p.ovr_f)
	for k in ["top5", "1a forte", "1a media", "1a fraca", "2a div", "3a+ div"]:
		if not g.has(k):
			continue
		var d: Dictionary = g[k]
		var all: Array = d["all"]
		all.sort()
		all.reverse()
		var t10 := 0.0
		for i in mini(10, all.size()):
			t10 += all[i]
		var xa: Array = d["xiavg"]
		xa.sort()
		print("%-10s  %5d  %6.1f  %5.1f  %3d  %3d  %4d  %11.1f  %9.1f  %7.1f  %6.1f" % [k, d["clubs"], all[0], t10 / 10.0,
			_count(all, 89.5), _count(all, 84.5), _count(all, 79.5), _mean(d["xi"]), xa[xa.size() - 1], xa[0], _mean(all)])
	print("por liga (média XI · melhor jogador · melhor XI):")
	var line := ""
	for lid in ["ENG1", "ESP1", "GER1", "ITA1", "FRA1", "POR1", "NED1", "BRA1", "ARG1", "KSA1", "MEX1", "USA1", "BRA2", "ENG2", "BRA3", "BRA4", "BRA5"]:
		var xs: Array = []
		var best := 0.0
		var bxi := 0.0
		for c: Club in w.clubs_in_league(lid):
			var xi := _xi(w, c)
			var s := 0.0
			for p: Player in xi:
				s += p.ovr_f
				best = maxf(best, p.ovr_f)
			xs.append(s / maxf(1, xi.size()))
			bxi = maxf(bxi, s / maxf(1, xi.size()))
		line += "%s %.1f·%.0f·%.1f  " % [lid, _mean(xs), best, bxi]
		if line.length() > 90:
			print("  " + line)
			line = ""
	if line != "":
		print("  " + line)


func _world_top(w: GameWorld) -> void:
	var arr: Array = []
	for p: Player in w.players.values():
		if p.club_id >= 0:
			arr.append(p)
	arr.sort_custom(func(a, b): return a.ovr_f > b.ovr_f)
	print("\n== elite mundial ==")
	var parts: Array = []
	for p: Player in arr.slice(0, 15):
		parts.append("%d %s %d" % [p.overall, _pos_name(p.position), p.age(w.year)])
	print("top15: " + ", ".join(PackedStringArray(parts)))
	var ovrs: Array = arr.map(func(p): return p.ovr_f)
	print("90+ %d · 88+ %d · 85+ %d · 80+ %d · 75+ %d · 70+ %d (em clubes: %d)" % [_count(ovrs, 89.5), _count(ovrs, 87.5), _count(ovrs, 84.5), _count(ovrs, 79.5), _count(ovrs, 74.5), _count(ovrs, 69.5), arr.size()])


func _potential(w: GameWorld) -> void:
	print("\n== potencial x idade (jogadores em clubes) ==")
	print("idade    n    ovr   pot   gap   pot85+  pot90+  gap>=10")
	var b := {}
	for p: Player in w.players.values():
		if p.club_id < 0:
			continue
		var a := p.age(w.year)
		var k := mini(a, 34)
		if a <= 17:
			k = 17
		if not b.has(k):
			b[k] = [0, 0.0, 0.0, 0, 0, 0]
		var r: Array = b[k]
		r[0] += 1
		r[1] += p.ovr_f
		r[2] += p.potential
		if p.potential >= 85:
			r[3] += 1
		if p.potential >= 90:
			r[4] += 1
		if p.potential - p.overall >= 10:
			r[5] += 1
	var keys := b.keys()
	keys.sort()
	for k in keys:
		var r: Array = b[k]
		print("%s%3d  %5d  %5.1f  %5.1f  %4.1f  %6d  %6d  %7d" % ["<=" if k == 17 else ("  " if k < 34 else ">="), k, r[0], r[1] / r[0], r[2] / r[0], (r[2] - r[1]) / r[0], r[3], r[4], r[5]])


func _attrs(w: GameWorld) -> void:
	print("\n== atributos por posição (jogadores 70–80 em clubes): média [p10–p90] ==")
	var show := {Pos.GK: [Attr.GOL, Attr.REF, Attr.POS, Attr.FIN, Attr.VEL, Attr.PAS], Pos.CB: [Attr.MAR, Attr.DES, Attr.CAB, Attr.VEL, Attr.FIN, Attr.DRI],
		Pos.RB: [Attr.VEL, Attr.CRU, Attr.MAR, Attr.RES, Attr.FIN], Pos.DM: [Attr.MAR, Attr.DES, Attr.PAS, Attr.FIN, Attr.VEL],
		Pos.CM: [Attr.PAS, Attr.VIS, Attr.TEC, Attr.FIN, Attr.MAR], Pos.AM: [Attr.VIS, Attr.PAS, Attr.TEC, Attr.FIN, Attr.MAR],
		Pos.RW: [Attr.VEL, Attr.DRI, Attr.FIN, Attr.CRU, Attr.MAR], Pos.ST: [Attr.FIN, Attr.POS, Attr.CAB, Attr.VEL, Attr.MAR, Attr.PAS]}
	for pos in show:
		var cols: Dictionary = {}
		var n := 0
		for p: Player in w.players.values():
			if p.club_id < 0 or p.position != pos or p.ovr_f < 70.0 or p.ovr_f > 80.0:
				continue
			n += 1
			for ai in show[pos]:
				if not cols.has(ai):
					cols[ai] = []
				cols[ai].append(float(p.attrs[ai]))
		var parts: Array = []
		for ai in show[pos]:
			var a: Array = cols.get(ai, [0.0])
			a.sort()
			parts.append("%s %.0f [%.0f–%.0f]" % [Attr.SHORT[ai], _mean(a), a[int(a.size() * 0.1)], a[int(a.size() * 0.9)]])
		print("%s (n=%d): %s" % [_pos_name(pos), n, ", ".join(PackedStringArray(parts))])
	# Extremos absurdos
	var st_low := 0
	var st_n := 0
	var cb_pace: Array = []
	for p: Player in w.players.values():
		if p.club_id < 0:
			continue
		if p.position == Pos.ST and p.overall >= 70:
			st_n += 1
			if p.attrs[Attr.FIN] < 60:
				st_low += 1
		if p.position == Pos.CB and p.overall >= 70:
			cb_pace.append(float(p.attrs[Attr.VEL]))
	cb_pace.sort()
	print("ST 70+ com FIN<60: %d de %d · CB 70+ VEL p5/p50/p95: %.0f/%.0f/%.0f" % [st_low, st_n, cb_pace[int(cb_pace.size() * 0.05)], cb_pace[cb_pace.size() / 2], cb_pace[int(cb_pace.size() * 0.95)]])


func _ages(w: GameWorld) -> void:
	print("\n== idade: overall médio dos titulares (status<=titular) e nº de 80+ ==")
	var b := {}
	for p: Player in w.players.values():
		if p.club_id < 0:
			continue
		var a := clampi(p.age(w.year), 17, 37)
		var gk := p.position == Pos.GK
		if not b.has(a):
			b[a] = [0, 0.0, 0, 0, 0.0]
		var r: Array = b[a]
		if p.squad_status <= Player.STATUS_STARTER and not gk:
			r[0] += 1
			r[1] += p.ovr_f
		if p.overall >= 80:
			r[2] += 1
		if gk and p.squad_status <= Player.STATUS_STARTER:
			r[3] += 1
			r[4] += p.ovr_f
	var line := ""
	for a in range(17, 38):
		if not b.has(a):
			continue
		var r: Array = b[a]
		line += "%d: %.1f/%d (gk %.1f)  " % [a, r[1] / maxf(1, r[0]), r[2], r[4] / maxf(1, r[3])]
		if a % 4 == 0:
			print(line)
			line = ""
	print(line)


func _values(w: GameWorld) -> void:
	print("\n== valor de mercado ==")
	var arr: Array = []
	for p: Player in w.players.values():
		if p.club_id >= 0:
			arr.append(p)
	arr.sort_custom(func(a, b): return a.value > b.value)
	var parts: Array = []
	for p: Player in arr.slice(0, 12):
		parts.append("%s (%d, %d a, %s)" % [Fmt.money(p.value), p.overall, p.age(w.year), w.club(p.club_id).league_id])
	print("top12: " + ", ".join(PackedStringArray(parts)))
	var n100 := 0
	var n50 := 0
	for p: Player in arr:
		if p.value >= 100_000_000:
			n100 += 1
		if p.value >= 50_000_000:
			n50 += 1
	print("≥100M: %d · ≥50M: %d" % [n100, n50])
	# Mediana por overall (idade 24–28, contrato 2+)
	var by := {}
	for p: Player in arr:
		var a := p.age(w.year)
		if a < 24 or a > 28:
			continue
		var k := int(p.overall / 5) * 5
		if not by.has(k):
			by[k] = {}
		var g := "top5" if w.club(p.club_id).league_id in TOP5 else "outras"
		if not by[k].has(g):
			by[k][g] = []
		by[k][g].append(p.value)
	var ks := by.keys()
	ks.sort()
	var line := "mediana 24–28 anos por overall (top5 | outras): "
	for k in ks:
		line += "%d: %s | %s  " % [k, Fmt.money(_median(by[k].get("top5", [0]))), Fmt.money(_median(by[k].get("outras", [0])))]
	print(line)
	# Idade: mesmo overall 78–82 em ligas top5
	var ag := {}
	for p: Player in arr:
		if p.ovr_f < 77.5 or p.ovr_f >= 82.5 or not w.club(p.club_id).league_id in TOP5:
			continue
		var a := clampi(p.age(w.year) / 3 * 3, 18, 33)
		if not ag.has(a):
			ag[a] = []
		ag[a].append(p.value)
	var ak := ag.keys()
	ak.sort()
	line = "overall 78–82 no top5 por idade: "
	for a in ak:
		line += "%d–%d: %s  " % [a, a + 2, Fmt.money(_median(ag[a]))]
	print(line)


func _wages(w: GameWorld) -> void:
	print("\n== salários (mensais) x receita ==")
	print("liga   receita/ano(méd)  folha/ano(méd)  folha/receita  salário top  salário médio titular")
	for lid in ["ENG1", "ESP1", "GER1", "ITA1", "FRA1", "POR1", "NED1", "TUR1", "KSA1", "USA1", "MEX1", "BRA1", "ARG1", "JPN1", "BRA2", "ENG2", "BRA3", "BRA5"]:
		var rev := 0.0
		var bill := 0.0
		var top := 0
		var xw: Array = []
		var n := 0
		for c: Club in w.clubs_in_league(lid):
			n += 1
			rev += FinanceManager.expected_revenue(c)
			bill += FinanceManager.wage_bill(w, c) * 12.0
			for p: Player in w.squad(c):
				top = maxi(top, p.wage)
			for p: Player in _xi(w, c):
				xw.append(p.wage)
		print("%-5s  %16s  %14s  %12.0f%%  %11s  %s" % [lid, Fmt.money(int(rev / n)), Fmt.money(int(bill / n)), 100.0 * bill / maxf(1.0, rev), Fmt.money(top), Fmt.money(int(_mean(xw)))])


func _styles(w: GameWorld) -> void:
	print("\n== estilos de jogo (principal) por função ==")
	var by := {}
	for p: Player in w.players.values():
		var r := PlayStyle.role_of(p.position)
		if not by.has(r):
			by[r] = {}
		var k := PlayStyle.of(p)
		by[r][k] = int(by[r].get(k, 0)) + 1
	for r in by:
		var d: Dictionary = by[r]
		var tot := 0
		for k in d:
			tot += d[k]
		var ks: Array = d.keys()
		ks.sort_custom(func(a, b): return d[a] > d[b])
		var parts: Array = []
		for k in ks:
			parts.append("%s %d%%" % [k, int(round(100.0 * d[k] / tot))])
		print("%s: %s" % [r, ", ".join(PackedStringArray(parts))])
	var ph := {}
	for c: Club in w.clubs:
		ph[c.philosophy] = int(ph.get(c.philosophy, 0)) + 1
	print("filosofias: %s" % str(ph))


func _simulate(w: GameWorld) -> void:
	print("\n== evolução (%d temporadas, só desenvolvimento) ==" % opt_years)
	print("ano   méd.clubes  méd.titulares  top5 XI  melhor  90+  85+  80+  75+  jogadores  top valor  ≥100M")
	_year_line(w)
	for y in opt_years:
		var minutes := {}
		var played := {}
		for c: Club in w.clubs:
			played[c.id] = true
			for p: Player in w.squad(c):
				minutes[p.id] = 90 if p.squad_status <= Player.STATUS_STARTER else (25 if p.squad_status == Player.STATUS_ROTATION else 0)
		for p: Player in w.players.values():
			p.minutes_season = int(minutes.get(p.id, 0) * 38.0 * 0.9)
		for _wk in 38:
			PlayerDevelopment.weekly_tick(w, minutes, played)
		PlayerDevelopment.yearly_review(w)
		PlayerDevelopment.announce_retirements(w)
		PlayerDevelopment.process_retirements(w)
		w.year += 1
		PlayerDevelopment.youth_intake(w)
		TransferManager.balance_squads(w)
		PlayerDevelopment.update_talent_drift(w)
		Valuation.refresh_shift(w)
		for p: Player in w.players.values():
			Valuation.update_value(p, w.year)
		for c: Club in w.clubs:
			PlayerGenerator.assign_statuses(w, c)
		_year_line(w)
	_potential(w)
	_ages(w)


func _year_line(w: GameWorld) -> void:
	var all: Array = []
	var st: Array = []
	var t5: Array = []
	var top_v := 0
	var n100 := 0
	for c: Club in w.clubs:
		var xi := _xi(w, c)
		for p: Player in xi:
			if c.league_id in TOP5:
				t5.append(p.ovr_f)
		for p: Player in w.squad(c):
			all.append(p.ovr_f)
			if p.squad_status <= Player.STATUS_STARTER:
				st.append(p.ovr_f)
			top_v = maxi(top_v, p.value)
			if p.value >= 100_000_000:
				n100 += 1
	all.sort()
	print("%d  %10.2f  %13.2f  %7.2f  %6.1f  %3d  %3d  %4d  %4d  %9d  %9s  %5d" % [w.year, _mean(all), _mean(st), _mean(t5), all[all.size() - 1],
		_count(all, 89.5), _count(all, 84.5), _count(all, 79.5), _count(all, 74.5), w.players.size(), Fmt.money(top_v), n100])


func _pos_name(pos: int) -> String:
	return ["GK", "RB", "CB", "LB", "DM", "CM", "AM", "RM", "LM", "RW", "LW", "ST"][pos]


func _count(a: Array, th: float) -> int:
	var n := 0
	for v in a:
		if float(v) >= th:
			n += 1
	return n


func _mean(a: Array) -> float:
	var s := 0.0
	for v in a:
		s += float(v)
	return s / maxf(1.0, a.size())


func _median(a: Array) -> int:
	var b := a.duplicate()
	b.sort()
	return int(b[b.size() / 2]) if not b.is_empty() else 0
