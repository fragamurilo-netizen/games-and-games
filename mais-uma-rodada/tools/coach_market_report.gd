extends SceneTree
## Mercado de técnicos da IA: joga temporadas do mundo e conta, por liga, as trocas de comando
## (no meio do ano e nas férias), interinos, de onde veio o técnico novo (livre, tirado de outro
## clube, efetivado, inventado), estrangeiros no banco e o tempo médio no cargo.
## godot --headless --path . --script res://tools/coach_market_report.gd -- [--seasons=1]

const LEAGUES: Array[String] = ["ENG1", "ESP1", "ITA1", "GER1", "FRA1", "POR1", "NED1", "TUR1", "BRA1", "ARG1", "MEX1", "USA1", "KSA1", "ENG2", "BRA2"]
var opt_seasons := 1


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seasons="):
			opt_seasons = int(a.substr(10))
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	w.user_club_id = -1
	w.season = SeasonManager.build_season(w)
	SeasonManager.compute_goals(w)
	People.ensure(w)
	var max_id0 := 0
	for co: Dictionary in CoachSchools.all_coaches(w):
		max_id0 = maxi(max_id0, int(co.get("id", 0)))
	_foreign(w, "Começo")
	for s in opt_seasons:
		var y := w.year
		var guard := 0
		while not w.season.finished and guard < 500:
			SeasonManager.play_matchday_instant(w)
			guard += 1
		SeasonManager.end_season(w)
		_report(w, y, max_id0)
	_foreign(w, "Fim")
	quit()


static func _league_of_club(w: GameWorld, cid: int) -> String:
	var c := w.club(cid)
	return c.league_id if c != null else ""


static func _report(w: GameWorld, y: int, max_id0: int) -> void:
	var rows := {}
	for lid in LEAGUES:
		rows[lid] = {"mid": 0, "off": 0, "int": 0, "efe": 0, "pool": 0, "poach": 0, "new": 0, "for": 0, "hires": 0}
	var whys := {}
	for m: Dictionary in People.data(w).get("moves", []):
		if int(m["y"]) != y and not (int(m["y"]) == y + 1 and bool(m.get("fim", false))):
			continue
		var lid := _league_of_club(w, int(m["c"]))
		if not rows.has(lid):
			continue
		var r: Dictionary = rows[lid]
		var why := String(m.get("why", ""))
		whys[why] = int(whys.get(why, 0)) + 1
		if why == "efe":
			r["efe"] += 1
			continue
		if bool(m.get("i", false)):
			r["int"] += 1
			continue
		if bool(m.get("fim", false)):
			r["off"] += 1
		else:
			r["mid"] += 1
		r["hires"] += 1
		if int(m.get("fr", -1)) >= 0:
			r["poach"] += 1
		elif int(m.get("ni", 0)) > max_id0:
			r["new"] += 1
		else:
			r["pool"] += 1
	print("\n=== Temporada %d: trocas de técnico por liga" % y)
	print("liga   meio  férias  interinos  efetivados  | de onde: livres  tirados  inventados")
	for lid in LEAGUES:
		var r: Dictionary = rows[lid]
		print("%-6s %4d  %6d  %9d  %10d  |          %6d  %7d  %10d" % [lid, r["mid"], r["off"], r["int"], r["efe"], r["pool"], r["poach"], r["new"]])
	print("motivos: ", whys)


static func _foreign(w: GameWorld, label: String) -> void:
	var pp := People.data(w)
	var line: Array = []
	for lid in LEAGUES:
		var n := 0
		var f := 0
		var tenure := 0.0
		for c: Club in w.clubs_in_league(lid):
			var co: Dictionary = pp["coaches"].get(c.id, {})
			if co.is_empty():
				continue
			n += 1
			if String(co.get("nat", "")) != c.nation:
				f += 1
			tenure += float(w.year - int(co.get("since", w.year)))
		if n > 0:
			line.append("%s %d%% estr." % [lid, int(round(100.0 * f / n))])
	print("%s — estrangeiros no banco: %s" % [label, ", ".join(PackedStringArray(line))])
	print("Técnicos livres: %d" % (pp["free"] as Array).size())
