extends SceneTree
## Teste do mundo andando sozinho: cria uma carreira e avança N semanas (as lutas da equipe do
## jogador simuladas), mostrando lutas por semana, campeões, cinturões, aposentados e o save.
## godot --headless --path . --script res://tools/world_sim.gd -- --weeks=52 [--role=presidente]


func _initialize() -> void:
	var weeks := 52
	var role := "empresario"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--weeks="):
			weeks = int(a.substr(8))
		elif a.begins_with("--role="):
			role = a.substr(7)
	if role == "presidente":
		_president(weeks)
		quit()
		return
	var t0 := Time.get_ticks_msec()
	var w := Career.new_career("Equipe Teste", "TST", "BRA", "Recife", Color("#B3262E"), Color("#F1F0EC"), 250000.0, 2027)
	print("mundo: %d lutadores, %d equipes, %d eventos, %d lutas marcadas (%d ms)" % [w.fighters.size(), w.teams.size(), w.events.size(), w.bouts.size(), Time.get_ticks_msec() - t0])
	# Contrata três amadores para o jogador.
	var free: Array = w.fighters.values().filter(func(f: Fighter) -> bool: return f.team_id < 0 and not f.is_pro())
	for i in 3:
		var r := Signing.offer(w, free[i], 0.2, 5, 0.0)
		print("contratação: ", r["text"])
	var fights := 0
	var methods := {}
	for i in weeks:
		var before := 0
		for b: Bout in w.bouts.values():
			if b.status == "feita":
				before += 1
		for o: Dictionary in w.offers.duplicate():
			if w.offers.has(o):
				Matchmaker.accept_offer(w, o)
		Career.advance_week(w, true)
		var after := 0
		for b: Bout in w.bouts.values():
			if b.status == "feita":
				after += 1
				if b.week == w.week - 1:
					methods[String(b.result["method"])] = int(methods.get(String(b.result["method"]), 0)) + 1
		fights += after - before
	var ms := Time.get_ticks_msec() - t0
	print("%d semanas, %d lutas (%.1f por semana), %d ms" % [weeks, fights, fights / float(weeks), ms])
	print("métodos: ", methods)
	var retired := 0
	for f: Fighter in w.fighters.values():
		if f.retired:
			retired += 1
	print("aposentados: %d, lutadores: %d" % [retired, w.fighters.size()])
	for div: String in w.champions:
		var c := w.fighter(int(w.champions[div]))
		print("%-5s campeão: %s" % [div, (c.display_name() + " " + c.record_text() + " nível %d" % c.level()) if c != null else "vago"])
	var t := w.user_team()
	print("equipe: caixa %s, reputação %.1f, ofertas %d" % [Fmt.money(t.balance), t.reputation, w.offers.size()])
	for f: Fighter in w.user_fighters():
		print("  * ", f.display_name(), " ", f.record_text(), " nível ", f.level(), " ", w.rank_text(f), " cond ", int(f.condition))
	var js := JSON.stringify(w.to_dict())
	print("save: %d KB" % (js.length() / 1024))
	var w2 := GameWorld.from_dict(JSON.parse_string(js))
	print("recarregado: %d lutadores, semana %d" % [w2.fighters.size(), w2.week])
	for n: Dictionary in w.news.slice(maxi(0, w.news.size() - 12)):
		print("  [", n["kind"], "] ", n["text"])
	quit()



## Presidente: a cada semana tenta marcar uma disputa de cinturão e uma luta principal na próxima
## noite (como um jogador faria); o resto o matchmaker da organização completa. As noites fecham
## sozinhas (bônus sugeridos).
func _president(weeks: int) -> void:
	var t0 := Time.get_ticks_msec()
	var w := Org.new_career("Liga Teste", "LT", "USA", Color("#B3262E"), Color("#F1F0EC"), Org.START_FUNDS[1], 2027)
	print("presidente: %d lutadores, %d eventos da liga à frente (%d ms)" % [w.fighters.size(), Org.upcoming_events(w).size(), Time.get_ticks_msec() - t0])
	var offers := 0
	var accepted := 0
	var titles := 0
	for i in weeks:
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
				if champ == null or not Matchmaker.ready_to_book(w, champ, ev.week - w.week) or champ.bout_id >= 0:
					continue
				for cid: int in (w.rankings.get(div, []) as Array).slice(0, 3):
					var c := w.fighter(cid)
					if Org.book_reason(w, ev, champ, c) != "" or Org.title_reason(w, champ, c) != "":
						continue
					offers += 1
					var r := Org.offer_bout(w, ev, champ, c, true, true, 1.25)
					if bool(r["ok"]):
						accepted += 1
						titles += 1
						belts += 1
						break
		Career.advance_week(w, true)
	var t := w.user_team()
	print("%d semanas em %d ms; ofertas de cinturão %d, aceitas %d" % [weeks, Time.get_ticks_msec() - t0, offers, accepted])
	print("organização: caixa %s, reputação %.1f" % [Fmt.money(t.balance), t.reputation])
	for ev: FightEvent in Org.past_events(w).slice(0, 8):
		var r: Dictionary = ev.report
		print("  %-24s %-14s lutas %2d  público %6d  ppv %7d  lucro %s" % [ev.name, ev.city, Org.event_bouts(w, ev).size(), int(r.get("crowd", 0)), int(r.get("ppv_buys", 0)), Fmt.money(float(r.get("profit", 0.0)))])
	for div: String in w.title_history:
		var hist: Array = w.title_history[div]
		print("  cinturão %-5s %d campeões: %s" % [div, hist.size(), " → ".join(hist.map(func(h: Dictionary) -> String: return String(h["name"])))])
	var js := JSON.stringify(w.to_dict())
	var w2 := GameWorld.from_dict(JSON.parse_string(js))
	print("save %d KB; recarregado como %s, semana %d" % [js.length() / 1024, w2.role, w2.week])
	for n: Dictionary in w.news.slice(maxi(0, w.news.size() - 8)):
		print("  [", n["kind"], "] ", n["text"])
