extends SceneTree
## Sonda da etapa "atletas de verdade": anda N semanas e mostra como ficaram a moral, o camp, o
## olheiro, os marcos e os números de carreira (para calibrar e conferir).
## godot --headless --path . --script res://tools/athletes_probe.gd -- --weeks=104


func _initialize() -> void:
	var weeks := 104
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--weeks="):
			weeks = int(a.substr(8))
	var w := Career.new_career("Equipe Teste", "TST", "BRA", "Recife", Color("#B3262E"), Color("#F1F0EC"), 500000.0, 2027)
	var y := w.year()
	var m := w.month()
	var pros: Array = w.fighters.values().filter(func(f: Fighter) -> bool: return f.team_id < 0 and f.stage(y, m) == "profissional")
	pros.sort_custom(func(a: Fighter, b: Fighter) -> bool: return a.level() > b.level())
	for f: Fighter in [pros[2], pros[5], pros[9]]:
		f.team_id = w.user_team_id
		f.contract = {"cut": 0.2, "fights": 8}
		f.known = 0.45
	for cand: Dictionary in w.staff_market.duplicate():
		if w.user_team().staff_of(String(cand["role"])).is_empty():
			StaffMarket.hire(w, cand)
	print("olheiro: ", Scouting.scout_name(w), " qualidade ", Scouting.quality(w), " limite ", Scouting.cap(w))
	var camp_pts: Array = []
	var talks := {}
	for i in weeks:
		for o: Dictionary in w.offers.duplicate():
			if w.offers.has(o):
				Matchmaker.accept_offer(w, o)
		for f: Fighter in w.user_fighters():
			var b := Camp.bout_of(w, f)
			if b != null and b.week == w.week and int(f.camp.get("bout", -1)) == b.id:
				camp_pts.append("%s %.0f pts em %d sem. (%s) custo %s cond %d" % [f.short_name(), float(f.camp["pts"]), int(f.camp["weeks"]), String(f.camp["focus"]), Fmt.money(float(f.camp["cost"])), int(f.condition)])
			if b != null and not f.camp.is_empty() and int(f.camp["weeks"]) == 0:
				f.camp["focus"] = ["plano", "forte", "folego", "peso"][i % 4]
				f.camp["spar"] = i % 2 == 0
				f.camp["place"] = "fora" if i % 3 == 0 else "casa"
			if Morale.talk_wait(w, f) == 0 and i % 5 == 0:
				var opts := Morale.talk_options(w, f)
				var o: Dictionary = opts[w.rng.randi_range(0, opts.size() - 1)]
				var r := Morale.talk(w, f, String(o["key"]))
				talks[String(o["key"])] = int(talks.get(String(o["key"]), 0)) + 1
				if i < 30:
					print("  conversa (%s) com %s [%s]: %s (%+d)" % [o["key"], f.short_name(), Persona.label(f), r["text"], int(r["delta"])])
		if i == 3:
			var free: Array = w.fighters.values().filter(func(f: Fighter) -> bool: return f.team_id < 0 and not f.retired)
			for f: Fighter in free.slice(0, 2):
				print("  observar ", f.display_name(), ": ", Scouting.assign(w, f), " antes ", _est(w, f), " (real %.0f)" % f.potential)
		Career.advance_week(w, true)
	# Moral
	var hist := {}
	var sum := 0.0
	var n := 0
	for f: Fighter in w.fighters.values():
		if f.retired:
			continue
		hist[Morale.label(f)] = int(hist.get(Morale.label(f), 0)) + 1
		sum += f.morale
		n += 1
	print("moral média %.1f de %d ativos: %s" % [sum / n, n, hist])
	for f: Fighter in w.user_fighters():
		print("* %s %s nível %d moral %.0f (%s, alvo %.0f) conhecido %.2f potencial %s (real %.0f) marcos %d" % [f.display_name(), f.record_text(), f.level(), f.morale, Morale.label(f), Morale.target(w, f), f.known, _est(w, f), f.potential, f.marks.size()])
		for it: Array in Morale.factors(w, f):
			print("     %+.1f %s" % [float(it[1]), it[0]])
		print("     log: ", f.mood_log)
		print("     relatório: ", Scouting.report_lines(w, f))
		var r := CareerStats.rates(f)
		print("     números: %.2f golpes/min, %.0f%% precisão, %.2f sofridos/min, %.0f%% defesa, %.2f quedas/15, %.0f%% def. queda, %.2f fin/15, %d lutas" % [r["slpm"], r["acc"] * 100.0, r["sapm"], r["def"] * 100.0, r["td15"], r["tddef"] * 100.0, r["sub15"], int(r["n"])])
		for h: Dictionary in f.history.slice(maxi(0, f.history.size() - 2)):
			print("     luta: ", h["res"], " ", h["method"], " · ", CareerStats.bout_line(h))
		print("     marcos: ", f.marks.filter(func(mk: Array) -> bool: return int(mk[1]) >= 0), " a seguir: ", CareerStats.next_marks(f))
		print("     curva: ", CareerStats.curve_points(w, f).slice(-5), " tendência ", CareerStats.trend(f))
	print("camps: ")
	for c: String in camp_pts:
		print("   ", c)
	print("conversas: ", talks)
	print("olheiro: obs ", w.scouting.get("jobs", []), " indicações ", Scouting.finds(w).map(func(x: Array) -> String: return "%s %s (real %.0f, nível %d)" % [(x[0] as Fighter).display_name(), _est(w, x[0]), (x[0] as Fighter).potential, (x[0] as Fighter).level()]))
	for nw: Dictionary in w.news:
		if String(nw["kind"]) in ["olheiro", "marco", "mercado"] or String(nw["text"]).contains("infeliz") or String(nw["text"]).contains("prometeu") or String(nw["text"]).contains("camp"):
			if int(nw["week"]) > w.week - 30:
				print("  [%s s%d] %s" % [nw["kind"], int(nw["week"]), nw["text"]])
	var js := JSON.stringify(w.to_dict())
	var w2 := GameWorld.from_dict(JSON.parse_string(js))
	var f0: Fighter = w.user_fighters()[0]
	var f2 := w2.fighter(f0.id)
	print("save %d KB; recarregado: marcos %d/%d, números %s, moral %.1f/%.1f, conhecido %.2f/%.2f" % [js.length() / 1024, f0.marks.size(), f2.marks.size(), str(f2.stats == f0.stats or f2.stats.size() == f0.stats.size()), f0.morale, f2.morale, f0.known, f2.known])
	quit()


func _est(w: GameWorld, f: Fighter) -> String:
	var e := Scouting.estimate(w, f)
	if bool(e.get("none", false)):
		return "?"
	return "%.0f a %.0f" % [float(e["lo"]), float(e["hi"])]
