extends SceneTree
## Sonda da temporada: joga N anos sozinha nos dois papéis e mostra, ano a ano, as metas (e se
## foram cumpridas), o termômetro (apoio da cidade ou confiança dos sócios), os contadores do
## ano e as conquistas. Serve para calibrar as metas e a pressão.
## godot --headless --path . --script res://tools/season_probe.gd -- --years=5 [--role=presidente] [--seed=2027] [--lazy]


func _initialize() -> void:
	var years := 5
	var role := "empresario"
	var seed_v := 2027
	var lazy := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--years="):
			years = int(a.substr(8))
		elif a.begins_with("--role="):
			role = a.substr(7)
		elif a.begins_with("--seed="):
			seed_v = int(a.substr(7))
		elif a == "--lazy":
			lazy = true
	var w: GameWorld
	if role == "presidente":
		w = Org.new_career("Liga Teste", "LT", "USA", Color("#B3262E"), Color("#F1F0EC"), Org.START_FUNDS[1], seed_v)
	else:
		w = Career.new_career("Equipe Teste", "TST", "BRA", "Recife", Color("#B3262E"), Color("#F1F0EC"), 250000.0, seed_v)
	print("papel %s, semente %d, %s" % [role, seed_v, "jogador parado" if lazy else "jogador ativo"])
	_goals(w)
	var lo := 100.0
	var hi := 0.0
	var feats := 0
	for i in years * 52 + 2:
		if role == "presidente":
			if not lazy:
				_president_turn(w)
		else:
			_manager_turn(w, lazy)
		var y0 := w.year()
		Career.advance_week(w, true)
		var v := Season.value_of(w)
		lo = minf(lo, v)
		hi = maxf(hi, v)
		if w.year() != y0:
			var p: Dictionary = (w.goals["past"] as Array).back()
			var t := w.user_team()
			print("\n== %d: %s (%d de 3) · %s %.0f → %.0f (mín %.0f, máx %.0f) · caixa %s · rep %.1f · conquistas %d (+%d), %d pontos (%s)" % [int(p["year"]), Season.verdict(int(p["met"])), int(p["met"]),
				Season.meter_short(w), float(p["v0"]), float(p["v1"]), lo, hi, Fmt.money(t.balance), t.reputation, Achievements.count(w), Achievements.count(w) - feats, Achievements.points(w), String(Achievements.rank(w)["name"])])
			feats = Achievements.count(w)
			for it: Dictionary in p["items"]:
				print("   [%s] %-46s %s" % ["x" if bool(it["ok"]) else " ", String(it["t"]), String(it["text"])])
			print("   ano: ", p["c"])
			print("   mandato %d, intervenções %d, ultimato %s" % [int(w.support.get("terms", 1)), int(w.support.get("strikes", 0)), str(w.support.get("ult", {}))])
			if role != "presidente":
				print("   equipe: ", ", ".join(w.user_fighters().map(func(f: Fighter) -> String: return "%s %s %s" % [f.short_name(), f.record_text(), w.rank_text(f)])), " · patrocínio/sem ", Season.sponsor(w))
			lo = 100.0
			hi = 0.0
			_goals(w)
	print("\nmotivos recentes:")
	for e: Array in Season.reasons(w, 12):
		print("   sem %d  %+.1f  %s" % [int(e[0]), float(e[1]), String(e[2])])
	print("conquistas: ", ", ".join(Achievements.list(w).filter(func(d: Array) -> bool: return w.feats.has(String(d[0]))).map(func(d: Array) -> String: return String(d[4]))))
	print("carreira: ", w.life)
	print("estrelas da elite: fama 75+ %d, 85+ %d, 90+ %d, 95+ %d; divisões %d" % [Season.stars(w, 75.0), Season.stars(w, 85.0), Season.stars(w, 90.0), Season.stars(w, 95.0), DataDB.divisions().size()])
	var js := JSON.stringify(w.to_dict())
	var w2 := GameWorld.from_dict(JSON.parse_string(js))
	print("save %d KB; recarregado: metas %d, apoio %.1f, conquistas %d" % [js.length() / 1024, Season.items(w2).size(), Season.value_of(w2), w2.feats.size()])
	quit()


func _goals(w: GameWorld) -> void:
	print("   metas de %d:" % int(w.goals["year"]))
	for g: Dictionary in Season.items(w):
		print("     - %s (%s) · %s" % [String(g["t"]), String(g["m"]), Season.reward_text(w, g)])


## Empresário: aceita as propostas; o ativo também contrata (até seis) e monta o staff.
func _manager_turn(w: GameWorld, lazy: bool) -> void:
	var t := w.user_team()
	var mine := w.user_fighters()
	var cap := 3 if lazy else 6
	if mine.size() < cap and (w.week % 6 == 0 or mine.is_empty()):
		var free: Array = w.fighters.values().filter(func(f: Fighter) -> bool: return f.team_id < 0 and not f.retired and Signing.block_reason(w, f) == "")
		free.sort_custom(func(a: Fighter, b: Fighter) -> bool: return Signing.chance(w, a, 0.2, 5, 0.0) * a.level() > Signing.chance(w, b, 0.2, 5, 0.0) * b.level())
		var want := 3 - mine.size() if mine.is_empty() else 1
		for f: Fighter in free.slice(0, want * 2):
			if w.user_fighters().size() >= cap:
				break
			Signing.offer(w, f, 0.2, 5, 0.0)
	# Caixa curto: corta o profissional mais caro (o que um jogador atento faria).
	var idle := Career.student_capacity(w) - Career.student_demand(w) >= 40 and Career.weekly_net(w) < 0.0
	if not lazy and w.week % 8 == 0 and (t.balance < 25000.0 or idle) and not t.staff.is_empty():
		var out: Dictionary = t.staff[0]
		for s: Dictionary in t.staff:
			if float(s["wage"]) > float(out["wage"]):
				out = s
		StaffMarket.fire(w, int(out["id"]))
	if not lazy and w.week % 13 == 1 and t.staff.size() < 3 and t.balance > 60000.0:
		for cand: Dictionary in w.staff_market:
			if t.staff_of(String(cand["role"])).is_empty() and float(cand["wage"]) < 900.0:
				StaffMarket.hire(w, cand)
				break
	for o: Dictionary in w.offers.duplicate():
		if not w.offers.has(o):
			continue
		# O ativo recusa luta contra alguém bem acima (a não ser que valha cinturão ou o lutador
		# esteja parado há meses); o parado aceita tudo.
		var me := w.fighter(int(o["fighter"]))
		var opp := w.fighter(int(o["opp"]))
		var belt := bool(o.get("title", false)) or bool(o.get("interim", false))
		if lazy or belt or me == null or opp == null or opp.level() <= me.level() + 3 or w.week - me.last_fight_week >= 16:
			Matchmaker.accept_offer(w, o)
	for f: Fighter in w.user_fighters():
		if f.contract.has("fights") and int(f.contract["fights"]) <= 0:
			Signing.renew(w, f, 0.2, 5)


## Presidente ativo: marca cinturão e luta principal na próxima noite, resolve metade dos imprevistos.
func _president_turn(w: GameWorld) -> void:
	var evs := Org.upcoming_events(w).filter(func(e: FightEvent) -> bool: return e.week - w.week >= 3)
	if not evs.is_empty():
		var ev: FightEvent = evs[0]
		var belts := Org.event_bouts(w, ev).filter(func(b: Bout) -> bool: return b.title).size()
		for d: Dictionary in DataDB.divisions():
			if belts >= (2 if ev.ppv else 1):
				break
			var div := String(d["id"])
			if Org.title_booked(w, div) != null or Org.event_bouts(w, ev).size() >= ev.slots:
				continue
			var champ := w.fighter(int(w.champions.get(div, -1)))
			if champ == null:
				# Cinturão vago: os dois mais bem colocados que aceitarem.
				var top: Array = (w.rankings.get(div, []) as Array).slice(0, 6)
				var made := false
				for i in top.size():
					for j in range(i + 1, top.size()):
						var fa := w.fighter(int(top[i]))
						var fb := w.fighter(int(top[j]))
						if made or Org.book_reason(w, ev, fa, fb) != "" or Org.title_reason(w, fa, fb) != "":
							continue
						made = bool(Org.offer_bout(w, ev, fa, fb, true, true, 1.25)["ok"])
				if made:
					belts += 1
				continue
			if not Matchmaker.ready_to_book(w, champ, ev.week - w.week) or champ.bout_id >= 0:
				continue
			for cid: int in (w.rankings.get(div, []) as Array).slice(0, 3):
				var c := w.fighter(cid)
				if Org.book_reason(w, ev, champ, c) != "" or Org.title_reason(w, champ, c) != "":
					continue
				if bool(Org.offer_bout(w, ev, champ, c, true, true, 1.25)["ok"]):
					belts += 1
					break
	for inc: Dictionary in FightWeek.pending(w):
		if String(inc["kind"]) == "lesao":
			var done := false
			for s: Fighter in FightWeek.substitutes(w, inc, 3):
				if bool(FightWeek.offer_sub(w, inc, s)["ok"]):
					done = true
					break
			if not done:
				FightWeek.cancel_injury(w, inc, true)
		elif not bool(FightWeek.catchweight(w, inc, true)["ok"]):
			FightWeek.cancel_weight(w, inc)
