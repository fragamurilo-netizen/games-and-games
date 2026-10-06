extends SceneTree
## Relações no mundo (Relations): quantos laços de cada tipo, irmãos, ídolos, técnicos favoritos,
## brigas da temporada e um exemplo de jogador. Depois de N temporadas.
## godot --headless --path . --script res://tools/relations_report.gd -- [--seasons=N]

func _initialize() -> void:
	var seasons := 1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seasons="):
			seasons = int(a.substr(10))
	var t0 := Time.get_ticks_msec()
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	print("mundo gerado em %.1fs" % ((Time.get_ticks_msec() - t0) / 1000.0))
	w.user_club_id = -1
	_report(w)
	for s in seasons:
		var news0 := w.news.size()
		var guard := 0
		t0 = Time.get_ticks_msec()
		while not w.season.finished and guard < 400:
			SeasonManager.play_matchday_instant(w)
			guard += 1
		var fights := 0
		for n in w.news.slice(news0):
			if String(n.title).contains("brigam") or String(n.title).contains("discutem"):
				fights += 1
		print("temporada em %.1fs · brigas %d, discussões %d" % [(Time.get_ticks_msec() - t0) / 1000.0, int(w.stats.get("fights", 0)), int(w.stats.get("arguments", 0))])
		var tk := SeasonManager.timings.keys()
		tk.sort_custom(func(a, b): return int(SeasonManager.timings[a]) > int(SeasonManager.timings[b]))
		var parts: Array = []
		for k in tk.slice(0, 12):
			parts.append("%s %.1fs" % [k, SeasonManager.timings[k] / 1e6])
		print("   etapas: " + ", ".join(parts))
		SeasonManager.end_season(w)
		_report(w)
	quit()


func _report(w: GameWorld) -> void:
	var by_kind := {}
	var with_fav := 0
	var with_bad := 0
	var idols := 0
	var n := 0
	var sample: Player = null
	for p: Player in w.players.values():
		if p.club_id < 0:
			continue
		n += 1
		for oid in p.bonds:
			var k := String(p.bonds[oid][0])
			by_kind[k] = int(by_kind.get(k, 0)) + 1
		if Relations.fav_coach(p) != -1:
			with_fav += 1
		if Relations.bad_coach(p) != -1:
			with_bad += 1
		if p.idol >= 0:
			idols += 1
		if sample == null and p.bonds.size() >= 4 and p.overall >= 75:
			sample = p
	print("== %d · %d jogadores · laços (dos dois lados): %s · técnico favorito %d · desafeto %d · com ídolo %d" % [w.year, n, str(by_kind), with_fav, with_bad, idols])
	if sample != null:
		var parts: Array = []
		for oid in sample.bonds:
			var q: Player = w.players.get(oid)
			if q != null:
				parts.append("%s %s (%d)" % [Relations.NAMES.get(String(sample.bonds[oid][0]), ""), q.display_name(), int(sample.bonds[oid][1])])
		print("   exemplo: %s (%s): %s" % [sample.display_name(), w.club(sample.club_id).short_name, "; ".join(parts)])
	for c: Club in w.clubs:
		if c.short_name == "Flamengo":
			var txt: Array = []
			for e in Relations.legends(w, c):
				txt.append("%s: %s (%s)" % [e["why"], e["r"]["n"], e["txt"]])
			print("   lendas do Flamengo: %s" % "; ".join(txt))
			break
