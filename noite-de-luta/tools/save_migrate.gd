extends SceneTree
## Teste de migração: abre um save (JSON) de uma versão anterior, confere o que a versão nova
## preenche sozinha e anda N semanas. Gere o save antigo com `tools/save_dump.gd` rodando no
## código antigo (um `git worktree` do commit anterior).
## godot --headless --path . --script res://tools/save_migrate.gd -- --in=/tmp/save.json [--weeks=20]


func _initialize() -> void:
	var path := "/tmp/save.json"
	var weeks := 20
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--in="):
			path = a.substr(5)
		elif a.begins_with("--weeks="):
			weeks = int(a.substr(8))
	var txt := FileAccess.get_file_as_string(path)
	var w := GameWorld.from_dict(JSON.parse_string(txt))
	var with_marks := 0
	var pros := 0
	for f: Fighter in w.fighters.values():
		if f.is_pro() and not f.retired:
			pros += 1
			if not f.marks.is_empty():
				with_marks += 1
	print("aberto: %s, semana %d, %d lutadores; profissionais com marcos %d de %d; notícias %d" % [w.role, w.week, w.fighters.size(), with_marks, pros, w.news.size()])
	print("temporada: %d metas (%s), %s %.0f, conquistas %d (%d pontos, sem aviso: %d na fila), guia %s, dicas pendentes %s" % [Season.items(w).size(),
		"; ".join(Season.items(w).map(func(g: Dictionary) -> String: return String(g["t"]))), Season.meter_short(w), Season.value_of(w), Achievements.count(w), Achievements.points(w), w.pops.size(),
		"ligado" if Tutorial.active(w) else "desligado", str(Tutorial.TIPS.keys().filter(func(k: String) -> bool: return Tutorial.tip_due(w, k)))])
	var news0 := w.news.size()
	var week0 := w.week
	for i in weeks:
		for o: Dictionary in w.offers.duplicate():
			if w.offers.has(o):
				Matchmaker.accept_offer(w, o)
		Career.advance_week(w, true)
		if i == 0:
			var marcos := 0
			for n: Dictionary in w.news:
				if int(n["week"]) >= week0 and String(n["kind"]) == "marco":
					marcos += 1
			print("primeira semana: %d notícias novas, %d de marco" % [w.news.size() - news0, marcos])
	var mine := w.user_fighters()
	for f: Fighter in mine:
		var r := CareerStats.rates(f)
		print("* %s %s moral %.0f (%s) conhecido %.2f potencial %s números em %d lutas (histórico %d) marcos %d curva %d" % [f.display_name(), f.record_text(), f.morale, Morale.label(f), f.known,
			str(Scouting.estimate(w, f).get("lo", "?")), int(r["n"]), f.history.size(), f.marks.size(), CareerStats.curve_points(w, f).size()])
	print("temporada depois: %s %.0f, conquistas %d, metas cumpridas %d, cerimônia %s" % [Season.meter_short(w), Season.value_of(w), Achievements.count(w), int(Season.life(w, "goals_met")), str(w.gala)])
	var js := JSON.stringify(w.to_dict())
	var w2 := GameWorld.from_dict(JSON.parse_string(js))
	print("depois de %d semanas: semana %d, save %d KB (era %d KB), recarregado com %d lutadores" % [weeks, w2.week, js.length() / 1024, txt.length() / 1024, w2.fighters.size()])
	quit()
