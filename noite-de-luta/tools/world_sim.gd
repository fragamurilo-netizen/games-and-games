extends SceneTree
## Teste do mundo andando sozinho: cria uma carreira e avança N semanas (as lutas da equipe do
## jogador simuladas), mostrando lutas por semana, campeões, cinturões, aposentados e o save.
## godot --headless --path . --script res://tools/world_sim.gd -- --weeks=52


func _initialize() -> void:
	var weeks := 52
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--weeks="):
			weeks = int(a.substr(8))
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
