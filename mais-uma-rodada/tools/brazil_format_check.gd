extends SceneTree
## Uma temporada inteira com os formatos de 2026 das Séries B, C e D: confere playoffs de acesso,
## quadrangulares, mata-mata da Série D, quem sobe e cai e se as divisões mantêm o tamanho.
## godot --headless --path . --script res://tools/brazil_format_check.gd

var fails := 0


func check(cond: bool, msg: String) -> void:
	if not cond:
		fails += 1
		print("   x " + msg)


func _initialize() -> void:
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	w.user_club_id = -1
	var sizes := {}
	for id in ["BRA1", "BRA2", "BRA3", "BRA4"]:
		sizes[id] = w.season.leagues[id].club_ids.size()
	var guard := 0
	while not w.season.finished and guard < 400:
		SeasonManager.play_matchday_instant(w)
		guard += 1
	for id in ["BRA2", "BRA3", "BRA4"]:
		var l: League = w.season.leagues[id]
		var ids := CompetitionManager.sorted_ids(l)
		var unplayed := 0
		for r in l.rounds:
			for f: Fixture in r:
				if not f.played:
					unplayed += 1
		print("== %s (%s) rodadas %d (fase 1: %d) · jogos sem jogar: %d" % [id, LeagueFormat.kind(l), l.rounds.size(), l.regular_rounds, unplayed])
		check(unplayed == 0, "%s com jogos sem data/sem jogar" % id)
		var up := LeagueFormat.promoted(l, ids, l.promoted_count(), w)
		var names: Array = []
		for cid in up:
			names.append("%s(%dº)" % [w.club(cid).short_name, CompetitionManager.sort_table(l.club_ids, l.table).find(cid) + 1])
		print("   sobem: " + ", ".join(PackedStringArray(names)))
		print("   campeão: %s" % w.club(LeagueFormat.champion(l, ids)).short_name)
		check(up.size() == l.promoted_count(), "%s: vagas de acesso incompletas" % id)
		match id:
			"BRA2":
				check(Array(l.po.get("winners", [])).size() == 2, "Série B sem os 2 vencedores dos playoffs")
				for t in l.po.get("ties", []):
					var fx := LeagueFormat._tie_fixtures(l, t)
					check(fx.size() == 2, "Série B: confronto sem ida e volta")
					print("   playoff %s x %s -> %s" % [w.club(int(t["a"])).short_name, w.club(int(t["b"])).short_name, w.club(int(t["w"])).short_name])
			"BRA3":
				check(l.regular_rounds == 19, "Série C deveria ter 19 rodadas na 1ª fase")
				var qg: Array = l.po.get("qg", [])
				check(qg.size() == 2, "Série C sem os dois quadrangulares")
				for gi in qg.size():
					var t := LeagueFormat.quad_table(l, gi)
					var row: Array = []
					for x in t:
						row.append("%s %d" % [w.club(int(x["id"])).short_name, int(x["pts"])])
						check(int(x["pl"]) == 6, "quadrangular com jogos faltando")
					print("   grupo %d: %s" % [gi + 1, ", ".join(PackedStringArray(row))])
				check(int(l.po.get("champ", -1)) >= 0, "Série C sem campeão da final")
			"BRA4":
				check(l.regular_rounds == 19, "Série D deveria ter 19 rodadas na 1ª fase")
				check(Array(l.po.get("ties", [])).size() == 15, "Série D: mata-mata incompleto")
	var col: League = w.season.leagues["COL1"]
	check(Array(col.po.get("qg", [])).size() == 2 and int(col.po.get("champ", -1)) >= 0, "Colômbia sem quadrangulares ou sem campeão")
	print("COL1 campeão: %s" % w.club(LeagueFormat.champion(col, CompetitionManager.sorted_ids(col))).short_name)
	var cdb: Cup = w.season.cups["CDB"]
	print("Copa do Brasil: %s · estreia da Série A: %s · campeão %s" % [cdb.plan, cdb.round_names[3], w.club(cdb.champion).short_name if cdb.champion >= 0 else "-"])
	check(cdb.finished and cdb.champion >= 0, "Copa do Brasil sem campeão")
	for f: Fixture in cdb.fixtures:
		check(f.played, "Copa do Brasil com jogo não disputado")
	SeasonManager.end_season(w)
	for id in sizes:
		var n: int = w.season.leagues[id].club_ids.size()
		print("%s: %d -> %d clubes" % [id, sizes[id], n])
		check(n == sizes[id], "%s mudou de tamanho" % id)
	print("FALHAS: %d" % fails)
	quit(1 if fails > 0 else 0)
