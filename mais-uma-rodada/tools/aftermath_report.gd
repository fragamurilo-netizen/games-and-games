extends SceneTree
## Marcas que ficam (Aftermath): roda temporadas de uma carreira e mostra as marcas de cada clube,
## o clima da torcida contra o patamar, técnicos que caíram pela ferida, desmanche dos rebaixados
## e as notícias que a imprensa fez com isso.
## godot --headless --path . --script res://tools/aftermath_report.gd -- [--seasons=N] [--league=BRA1] [--cal=ano|eu]

var opt_seasons := 2
var opt_league := "BRA1"
var opt_cal := "ano"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seasons="):
			opt_seasons = int(a.substr(10))
		elif a.begins_with("--league="):
			opt_league = a.substr(9)
		elif a.begins_with("--cal="):
			opt_cal = a.substr(6)
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	w.user_club_id = w.clubs_in_league(opt_league)[0].id
	w.stats["cal"] = "ano" if opt_cal == "ano" else ""
	w.season = SeasonManager.build_season(w)
	SeasonManager.compute_goals(w)
	People.ensure(w)
	print("Clube do usuário: %s" % w.user_club().short_name)
	for s in opt_seasons:
		var guard := 0
		var goals := 0
		var games := 0
		while not w.season.finished and guard < 500:
			var rep := SeasonManager.play_matchday_instant(w)
			guard += 1
		for lid in w.season.leagues:
			var lg: League = w.season.leagues[lid]
			for rd in lg.rounds:
				for f: Fixture in rd:
					if f.played:
						goals += f.hg + f.ag
						games += 1
		print("\n=== Temporada %d: %d jogos de liga, %.2f gols por jogo" % [w.year, games, float(goals) / maxf(1.0, games)])
		_marks(w)
		var log0 := w.transfer_log.size()
		var summary := SeasonManager.end_season(w)
		print("\n--- Virada para %d" % w.year)
		_relegated_sales(w, summary)
		_news(w, w.year - 1)
	quit()


static func _marks(w: GameWorld) -> void:
	var all: Dictionary = w.stats.get("af", {})
	var rows: Array = []
	for key in all:
		var c := w.club(int(key))
		for m: Array in all[key]:
			rows.append([c, m])
	print("Marcas ativas: %d clubes, %d marcas" % [all.size(), rows.size()])
	var u := w.user_club()
	var shown := 0
	for e in rows:
		var c: Club = e[0]
		var m: Array = e[1]
		if c.nation != u.nation or c.tier != 1:
			continue
		var o := w.club(int(m[Aftermath.I_O]))
		print("  %-16s %-14s %d  peso %.2f  agora %.2f  vs %-14s  clima %4.1f  patamar %4.1f" % [c.short_name, m[0], int(m[1]), float(m[4]),
			Aftermath.strength(w, m), o.short_name if o != null else "-", c.fan_mood, Aftermath.mood_target(w, c)])
		shown += 1
	var dr: Array = []
	for c: Club in w.clubs:
		if c.nation == u.nation and c.tier == 1 and Aftermath.drought_pressure(w, c) > 0.0:
			dr.append("%s %d anos (-%.1f)" % [c.short_name, Aftermath.drought_years(w, c), Aftermath.drought_pressure(w, c)])
	print("Jejum pesando: %s" % ", ".join(dr))


static func _relegated_sales(w: GameWorld, summary: Dictionary) -> void:
	for lg in summary.get("leagues", []):
		for cid in lg.get("relegated", []):
			var c := w.club(int(cid))
			var out: Array = []
			for t: Transfer in w.transfer_log:
				if t.from_id == c.id and t.year == w.year:
					out.append("%s (%s)" % [t.player_name, Fmt.money(t.fee)])
			if not out.is_empty() and String(lg.get("nation", "")) == w.user_nation():
				print("  rebaixado %s vendeu nas férias: %s" % [c.short_name, ", ".join(out)])


static func _news(w: GameWorld, y: int) -> void:
	var keys := ["ainda pesa", "ferida", "não sai da cabeça", "reerguer", "ainda vive", "ainda celebra", "repercute", "Um ano", "abre o cofre",
		"Ninguém aqui esqueceu", "sem título", "Fim da fila", "pela primeira vez", "não resistiu"]
	for n: NewsEvent in w.news:
		if n.year < y:
			continue
		for k in keys:
			if n.title.find(k) >= 0 or n.body.find(k) >= 0:
				print("  [%d] %s — %s" % [n.year, n.title, n.body.substr(0, 140)])
				break
