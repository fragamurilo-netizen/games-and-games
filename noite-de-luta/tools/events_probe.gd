extends SceneTree
## Sonda da etapa "montagem dos eventos" (0.4): fama do topo do ranking ao longo do tempo, hype
## das noites, público, contas, rivalidades, cinturão interino, contrato de TV e (no papel de
## empresário) a negociação das propostas.
## godot --headless --path . --script res://tools/events_probe.gd -- --weeks=104 [--role=presidente]


func _arg(name: String, def: String) -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % name):
			return a.split("=")[1]
	return def


func _init() -> void:
	var weeks := int(_arg("weeks", "104"))
	if _arg("role", "empresario") == "presidente":
		_president(weeks)
	else:
		_manager(weeks)
	quit()


func _fame(w: GameWorld) -> String:
	var champs := 0.0
	var nc := 0
	var top := 0.0
	var nt := 0
	var mid := 0.0
	var nm := 0
	for d: Dictionary in DataDB.divisions():
		var div := String(d["id"])
		var c := w.fighter(int(w.champions.get(div, -1)))
		if c != null:
			champs += c.popularity
			nc += 1
		var lst: Array = w.rankings.get(div, [])
		for i in mini(20, lst.size()):
			var f := w.fighter(int(lst[i]))
			if i < 5:
				top += f.popularity
				nt += 1
			elif i >= 10:
				mid += f.popularity
				nm += 1
	return "fama: campeões %.0f, top 5 %.0f, 11º ao 20º %.0f" % [champs / maxf(1, nc), top / maxf(1, nt), mid / maxf(1, nm)]


var interim_tries := 0
var out_weeks := 0
var out_max := 0


func _watch(w: GameWorld) -> void:
	for d: Dictionary in DataDB.divisions():
		var div := String(d["id"])
		if Titles.champion_out(w, div) != "":
			out_weeks += 1
		var c := w.fighter(int(w.champions.get(div, -1)))
		if c != null and not c.injury.is_empty():
			out_max = maxi(out_max, int(c.injury.get("weeks", 0)))


func _world_notes(w: GameWorld) -> void:
	print("campeão fora de combate: %d semanas somadas; maior lesão de campeão vista: %d semanas; interinos marcados pela sonda: %d" % [out_weeks, out_max, interim_tries])
	var hot: Array = []
	for k: String in w.rivalries:
		hot.append([float(w.rivalries[k]["heat"]), k])
	hot.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var named := hot.filter(func(x: Array) -> bool: return x[0] >= Rivalry.NAMED).size()
	print("rivalidades: %d guardadas, %d com nome" % [hot.size(), named])
	for x: Array in hot.slice(0, 5):
		var parts := String(x[1]).split(":")
		var fa := w.fighter(int(parts[0]))
		var fb := w.fighter(int(parts[1]))
		print("  %3.0f  %s × %s · %s · %s" % [x[0], fa.display_name(), fb.display_name(), String(w.rivalries[x[1]]["why"]), Rivalry.h2h_text(fa, fb.id)])
	print("interinos agora: ", w.interim)
	var hist := {"interino": 0, "promovido": 0, "total": 0}
	for div: String in w.title_history:
		for h: Dictionary in w.title_history[div]:
			hist["total"] += 1
			var how := String(h.get("how", ""))
			if how.begins_with("interino, "):
				hist["interino"] += 1
			elif how.contains("promovido"):
				hist["promovido"] += 1
	print("história dos cinturões: ", hist)
	var kinds := {}
	for n: Dictionary in w.news:
		var t := String(n["text"])
		for key: String in ["interino", "Unificação", "unificado", "Nasce uma rivalidade", "provoca", "promovido"]:
			if t.contains(key):
				kinds[key] = int(kinds.get(key, 0)) + 1
	print("notícias (últimas 300): ", kinds)


func _president(weeks: int) -> void:
	var w := Org.new_career("Liga Teste", "LT", "USA", Color("#B3262E"), Color("#F1F0EC"), Org.START_FUNDS[1], 2027)
	print("semana 0 · ", _fame(w))
	var t := w.user_team()
	var hist: Array = []
	for i in weeks:
		# Como um jogador: tenta uma disputa de cinturão na próxima noite com tempo.
		var evs := Org.upcoming_events(w).filter(func(e: FightEvent) -> bool: return e.week - w.week >= 3)
		if not evs.is_empty():
			var ev: FightEvent = evs[0]
			# Campeão fora de combate: disputa de interino entre os dois primeiros.
			for d: Dictionary in DataDB.divisions():
				var div := String(d["id"])
				if Card.has_belt(w, ev) or Org.event_bouts(w, ev).size() >= ev.slots:
					break
				if Titles.champion_out(w, div) == "":
					continue
				var lst: Array = w.rankings.get(div, [])
				if lst.size() < 3:
					continue
				for pair: Array in [[0, 1], [0, 2], [1, 2]]:
					var fa := w.fighter(int(lst[pair[0]]))
					var fb := w.fighter(int(lst[pair[1]]))
					if Titles.interim_reason(w, fa, fb) == "" and Org.book_reason(w, ev, fa, fb) == "" and bool(Org.offer_bout(w, ev, fa, fb, false, true, 1.25, true)["ok"]):
						interim_tries += 1
						break
			for d: Dictionary in DataDB.divisions():
				var div := String(d["id"])
				if Card.has_belt(w, ev) or Org.event_bouts(w, ev).size() >= ev.slots:
					break
				if Org.title_booked(w, div) != null:
					continue
				var champ := w.fighter(int(w.champions.get(div, -1)))
				if champ == null or champ.bout_id >= 0 or not Matchmaker.ready_to_book(w, champ, ev.week - w.week):
					continue
				for cid: int in (w.rankings.get(div, []) as Array).slice(0, 3):
					var c := w.fighter(cid)
					if Org.book_reason(w, ev, champ, c) == "" and Org.title_reason(w, champ, c) == "" and bool(Org.offer_bout(w, ev, champ, c, true, true, 1.25)["ok"]):
						break
		# Contrato de TV: assina a proposta que paga mais por ano.
		if TVDeal.pending(w):
			var best: Dictionary = {}
			for o: Dictionary in w.tv_offers:
				if best.is_empty() or float(o["fee"]) + float(o["fee_ppv"]) > float(best["fee"]) + float(best["fee_ppv"]):
					best = o
			print("  semana %d: propostas de TV %s → assina %s" % [w.week, w.tv_offers.map(func(o: Dictionary) -> String: return "%s %s/%s %dsem" % [o["partner"], Fmt.money(float(o["fee"])), Fmt.money(float(o["fee_ppv"])), int(o["weeks"])]), best["partner"]])
			TVDeal.sign(w, best)
		Career.advance_week(w, true)
		_watch(w)
		for ev2: FightEvent in Org.past_events(w).slice(0, 1):
			if ev2.week == w.week - 1:
				hist.append(ev2)
		if (i + 1) % 26 == 0:
			print("semana %d · caixa %s · reputação %.0f · %s" % [w.week, Fmt.money(t.balance), t.reputation, _fame(w)])
	var buckets := [0, 0, 0, 0, 0]
	var sum_fn := 0.0
	var n_fn := 0
	var sum_ppv := 0.0
	var n_ppv := 0
	for ev: FightEvent in hist:
		var r := ev.report
		buckets[Hype.tone(float(r.get("draw", 0.0)))] += 1
		if ev.ppv:
			sum_ppv += float(r.get("profit", 0.0))
			n_ppv += 1
		else:
			sum_fn += float(r.get("profit", 0.0))
			n_fn += 1
	print("noites: %d · hype frio %d, morno %d, aquecendo %d, quente %d, pegando fogo %d" % [hist.size(), buckets[0], buckets[1], buckets[2], buckets[3], buckets[4]])
	print("lucro médio: Fight Night %s (%d), numerado %s (%d)" % [Fmt.money(sum_fn / maxf(1, n_fn)), n_fn, Fmt.money(sum_ppv / maxf(1, n_ppv)), n_ppv])
	for ev: FightEvent in hist.slice(maxi(0, hist.size() - 8)):
		var r := ev.report
		print("  %-22s %-16s hype %3.0f  público %6d/%6d  ingresso %4.0f  tv %s  ppv %s  lucro %s" % [ev.name, ev.city, float(r.get("draw", 0.0)), int(r.get("crowd", 0)), int(r.get("capacity", 0)), float(r.get("ticket", 0.0)), Fmt.money(float(r.get("tv", 0.0))), Fmt.money(float(r.get("ppv", 0.0))), Fmt.money(float(r.get("profit", 0.0)))])
	print("TV: ", w.tv)
	# Termômetro da próxima noite, com os motivos.
	var ups := Org.upcoming_events(w)
	if not ups.is_empty():
		var h := Hype.event(w, ups[0])
		print("próxima noite %s: hype %.0f (%s)" % [(ups[0] as FightEvent).name, float(h["value"]), Hype.label(float(h["value"]))])
		for r: Array in h["reasons"]:
			print("   %+5.1f  %s" % [float(r[1]), String(r[0])])
		for r: Array in (h["main"] as Dictionary).get("reasons", []):
			print("      principal %+5.1f  %s" % [float(r[1]), String(r[0])])
	_world_notes(w)


func _manager(weeks: int) -> void:
	var w := Career.new_career("Equipe Sonda", "", "BRA", "Recife", Color("#B3262E"), Color("#F1F0EC"), 500000.0, 2027)
	var y := w.year()
	var m := w.month()
	var pros: Array = w.fighters.values().filter(func(f: Fighter) -> bool: return f.team_id < 0 and f.stage(y, m) == "profissional")
	pros.sort_custom(func(a: Fighter, b: Fighter) -> bool: return a.level() > b.level())
	w.user_team().balance += 3000000.0
	for f: Fighter in [pros[0], pros[3], pros[8], pros[20]]:
		f.team_id = w.user_team_id
		f.contract = {"cut": 0.2, "fights": 12}
	print("semana 0 · ", _fame(w))
	var asks := {}
	var answers := {"aceitou": 0, "meio": 0, "nao": 0, "retirou": 0}
	var belt := {"title": 0, "interim": 0}
	var slots := {}
	var hv_sum := 0.0
	var hv_n := 0
	var waited := 0
	for i in weeks:
		for o: Dictionary in w.offers.duplicate():
			if not w.offers.has(o):
				continue
			if bool(o.get("title", false)):
				belt["title"] += 1
			if bool(o.get("interim", false)):
				belt["interim"] += 1
			var f := w.fighter(int(o["fighter"]))
			var opp := w.fighter(int(o["opp"]))
			var ev := w.event(int(o["event"]))
			# Como um jogador: quem está na fila do cinturão espera a proposta certa.
			if not bool(o.get("title", false)) and Matchmaker.shot_promised(w, f):
				waited += 1
				continue
			hv_sum += float(Hype.pair(w, f, opp, bool(o.get("title", false)), bool(o.get("interim", false)), ev.nation)["value"])
			hv_n += 1
			# Negocia como um jogador: pede o que tiver mais de 45% de chance.
			var gone := false
			for key: String in ["bolsa30", "bolsa15", "card"]:
				if Negotiation.block_reason(w, o, key) != "" or Negotiation.chance(w, o, key) < 0.45:
					continue
				asks[key] = int(asks.get(key, 0)) + 1
				var r := Negotiation.ask(w, o, key)
				if bool(r["gone"]):
					answers["retirou"] += 1
					gone = true
					break
				elif String(r["text"]).begins_with("Os organizadores aceitaram"):
					answers["aceitou"] += 1
				elif bool(r["ok"]):
					answers["meio"] += 1
				else:
					answers["nao"] += 1
			if gone:
				continue
			var s := Negotiation.slot_of(w, o)
			slots[s] = int(slots.get(s, 0)) + 1
			Matchmaker.accept_offer(w, o)
		Career.advance_week(w, true)
		_watch(w)
		if (i + 1) % 26 == 0:
			print("semana %d · caixa %s · %s" % [w.week, Fmt.money(w.user_team().balance), _fame(w)])
	print("propostas: hype médio %.0f em %d; de cinturão %s; lugares no card %s" % [hv_sum / maxf(1, hv_n), hv_n, belt, slots])
	print("negociação: pedidos %s, respostas %s; propostas deixadas passar à espera do cinturão: %d" % [asks, answers, waited])
	for f: Fighter in w.user_fighters():
		print("  * %s %s %s fama %.0f moral %.0f rivais %d" % [f.display_name(), f.record_text(), w.rank_text(f), f.popularity, f.morale, Rivalry.of(w, f).size()])
	# Hype das noites da Liga Global que vêm aí.
	var tones := [0, 0, 0, 0, 0]
	for ev: FightEvent in w.events.values():
		if ev.tier == 2 and ev.week >= w.week and not ev.bouts.is_empty():
			tones[Hype.tone(Hype.event_value(w, ev))] += 1
	print("noites da liga à frente: frio %d, morno %d, aquecendo %d, quente %d, pegando fogo %d" % [tones[0], tones[1], tones[2], tones[3], tones[4]])
	_world_notes(w)
