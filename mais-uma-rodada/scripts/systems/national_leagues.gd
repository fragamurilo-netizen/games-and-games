class_name NationalLeagues
extends RefCounted
## Senior Nations Leagues. Pure career data: groups run in FIFA windows;
## knockout results, promotion and qualification survive saves and season changes.
const IDS := ["UNL", "CNL"]
const SWISS := [[[1,0],[2,3],[5,4]], [[0,2],[4,1],[3,5]], [[3,0],[5,1],[4,2]], [[0,4],[1,3],[2,5]]]


static func states(w: GameWorld) -> Dictionary:
	var d := NationalTeamManager.data(w)
	if not d.has("nations_leagues"):
		d["nations_leagues"] = {}
	return d["nations_leagues"]


static func start(w: GameWorld) -> void:
	var all := states(w)
	for id in IDS:
		var year := w.year + 1
		if NationalTeamManager.next_edition(id, year) != year:
			continue
		var old: Dictionary = all.get(id, {})
		if int(old.get("y", 0)) == year:
			continue
		var cfg := NationalTeamManager.tcfg(id)
		var divisions: Array = old.get("next_divisions", cfg["initial_divisions"]).duplicate(true)
		var st := {"t": id, "y": year, "groups": [], "fx": [], "md": 0, "teams": [], "divisions": divisions, "ko": [], "done": false, "qf_done": false, "finalists": []}
		var rng := RandomNumberGenerator.new()
		rng.seed = RngUtil.hash_i(w.world_seed, year, id.hash())
		for level in divisions.size():
			var teams: Array = divisions[level].duplicate()
			st["teams"].append_array(teams)
			if id != "CNL" or level != 0 or not old.is_empty():
				teams.sort_custom(func(a, b): return NationalTeamManager.elo_of(w, a) > NationalTeamManager.elo_of(w, b))
			if id == "CNL" and level == 0:
				st["byes"] = teams.slice(0, 4)
				teams = teams.slice(4)
			var count: int = (2 if level == 3 else 4) if id == "UNL" else [2, 4, 3][level]
			var groups := NationalTeamManager._draw_groups(rng, teams, count)
			for gi in groups.size():
				var group: Dictionary = groups[gi]
				group["n"] = "%s%d" % ["ABCD"[level], gi + 1]
				group["level"] = level
				var index: int = st["groups"].size()
				st["groups"].append(group)
				var rounds := SWISS if id == "CNL" and level == 0 else NationalTeamManager._rounds(group["teams"].size(), 2)
				for md in rounds.size():
					for pair in rounds[md]:
						st["fx"].append([md, index, group["teams"][pair[0]], group["teams"][pair[1]], -1, -1])
		all[id] = st


static func play_window(w: GameWorld, env: NationalTeamManager.Env) -> Array:
	start(w) # migration of an existing career midway through the cycle
	var results: Array = []
	for id in IDS:
		var st: Dictionary = states(w).get(id, {})
		if st.is_empty() or bool(st["done"]) or int(st["y"]) != w.year + 1:
			continue
		for i in 2:
			results.append_array(_matchday(env, st))
	return results


static func _matchday(env: NationalTeamManager.Env, st: Dictionary) -> Array:
	var out: Array = []
	if int(st["md"]) >= 6:
		return out
	for f in st["fx"]:
		if int(f[0]) != int(st["md"]) or int(f[4]) >= 0:
			continue
		var group: Dictionary = st["groups"][int(f[1])]
		env.tag = "%s — Grupo %s" % [NationalTeamManager.tournament_name(st["t"]), group["n"]]
		var result := NationalTeamManager.play(env, f[2], f[3], true, false)
		f[4] = int(result["ga"])
		f[5] = int(result["gb"])
		NationalTeamManager._apply(group["table"], f[2], f[3], f[4], f[5])
		out.append(result)
	st["md"] = int(st["md"]) + 1
	return out


static func _positions(st: Dictionary, level: int, position: int) -> Array:
	var rows: Array = []
	for group in st["groups"]:
		if int(group["level"]) != level:
			continue
		var order := NationalTeamManager.sort_group(group)
		var idx := position if position >= 0 else order.size() + position
		if idx >= 0 and idx < order.size():
			rows.append([order[idx], group["table"][order[idx]]])
	rows.sort_custom(func(a, b): return NationalTeamManager._better(a[1], b[1]) or (not NationalTeamManager._better(b[1], a[1]) and a[0] < b[0]))
	return rows.map(func(row): return row[0])


static func _row(r: Dictionary, winner: String = "") -> Array:
	return [r["a"], r["b"], r["ga"], r["gb"], r["pa"], r["pb"], r["et"], r["w"] if winner == "" else winner]


## Higher seed hosts the return leg; aggregate equality, never away goals,
## triggers extra time and penalties on that return leg.
static func _tie(env: NationalTeamManager.Env, st: Dictionary, a: String, b: String, label: String) -> String:
	var games: Array = []
	env.tag = NationalTeamManager.tournament_name(st["t"]) + " — " + label + " (ida)"
	var first := NationalTeamManager.play(env, b, a, true, false)
	games.append(_row(first))
	env.tag = NationalTeamManager.tournament_name(st["t"]) + " — " + label + " (volta)"
	var second := NationalTeamManager.play(env, a, b, true, true, [int(first["gb"]), int(first["ga"])])
	var winner: String = second["qualified"]
	games.append(_row(second, winner))
	st["ko"].append({"n": label + " — ida e volta", "m": games})
	return winner


static func _swap_divisions(divisions: Array, upper: int, down: String, up: String) -> void:
	divisions[upper].erase(down)
	divisions[upper + 1].erase(up)
	divisions[upper].append(up)
	divisions[upper + 1].append(down)


static func _promotion(env: NationalTeamManager.Env, st: Dictionary) -> void:
	var divisions: Array = st["divisions"].duplicate(true)
	for upper in divisions.size() - 1:
		var down := _positions(st, upper, -1)
		var up := _positions(st, upper + 1, 0)
		if st["t"] == "CNL":
			if upper == 0:
				down.append_array(_positions(st, 0, -2))
			else:
				up.append_array(_positions(st, 2, 1).slice(0, 1))
		elif upper == 2:
			down = down.slice(2) # only the two worst fourth-place sides go down directly
		for i in mini(down.size(), up.size()):
			_swap_divisions(divisions, upper, down[i], up[i])
		if st["t"] == "UNL":
			var playoff_down := _positions(st, upper, 2) if upper < 2 else _positions(st, upper, 3).slice(0, 2)
			var playoff_up := _positions(st, upper + 1, 1)
			for i in mini(playoff_down.size(), playoff_up.size()):
				var winner := _tie(env, st, playoff_down[i], playoff_up[i], "Acesso %s/%s" % ["ABCD"[upper], "ABCD"[upper + 1]])
				if winner == playoff_up[i]:
					_swap_divisions(divisions, upper, playoff_down[i], playoff_up[i])
	st["next_divisions"] = divisions


static func _quarterfinals(env: NationalTeamManager.Env, st: Dictionary) -> void:
	var first := _positions(st, 0, 0)
	var second := _positions(st, 0, 1)
	var pairs: Array = []
	if st["t"] == "CNL":
		var seeds: Array = st["byes"]
		var challengers := first + second
		for i in 4:
			pairs.append([seeds[3 - i], challengers[i]])
	else:
		# A group winner faces a runner-up from a different group.
		var groups: Array = st["groups"].filter(func(g): return int(g["level"]) == 0)
		for i in 4:
			pairs.append([NationalTeamManager.sort_group(groups[i])[0], NationalTeamManager.sort_group(groups[(i + 1) % 4])[1]])
	var losers: Array = []
	for pair in pairs:
		var winner := _tie(env, st, pair[0], pair[1], "Quartas de final")
		st["finalists"].append(winner)
		losers.append(pair[1] if winner == pair[0] else pair[0])
	if st["t"] == "CNL":
		var direct: Array = st["finalists"].duplicate() + _positions(st, 1, 0)
		var prelims: Array = losers + _positions(st, 0, 2) + _positions(st, 0, 3) + _positions(st, 1, 1).slice(0, 2)
		var low_a := _positions(st, 0, 4) + _positions(st, 0, 5)
		var low_c := _positions(st, 2, 0) + _positions(st, 2, 1).slice(0, 1)
		for i in 4:
			prelims.append(_tie(env, st, low_a[i], low_c[3 - i], "Play-in Copa Ouro"))
		prelims.sort_custom(func(a, b): return NationalTeamManager.elo_of(env.world, a) > NationalTeamManager.elo_of(env.world, b))
		for i in 7:
			direct.append(_tie(env, st, prelims[i], prelims[13 - i], "Preliminares Copa Ouro"))
		st["gold_qualified"] = direct
	_promotion(env, st)
	st["qf_done"] = true


static func _final_four(env: NationalTeamManager.Env, st: Dictionary, teams: Array, suffix: String = "") -> Dictionary:
	var finalists: Array = []
	var losers: Array = []
	var semis: Array = []
	env.tag = NationalTeamManager.tournament_name(st["t"]) + " — Semifinal" + suffix
	for i in 2:
		var a: String = teams[i * 2]
		var b: String = teams[i * 2 + 1]
		var r := NationalTeamManager.play(env, a, b, false, true)
		semis.append(_row(r))
		finalists.append(r["w"])
		losers.append(b if r["w"] == a else a)
	st["ko"].append({"n": "Semifinal" + suffix, "m": semis})
	env.tag = NationalTeamManager.tournament_name(st["t"]) + " — Terceiro lugar" + suffix
	var bronze := NationalTeamManager.play(env, losers[0], losers[1], false, true)
	st["ko"].append({"n": "Terceiro lugar" + suffix, "m": [_row(bronze)]})
	env.tag = NationalTeamManager.tournament_name(st["t"]) + " — Final" + suffix
	var final := NationalTeamManager.play(env, finalists[0], finalists[1], false, true)
	st["ko"].append({"n": "Final" + suffix, "m": [_row(final)]})
	return {"champion": final["w"], "runner_up": finalists[1] if final["w"] == finalists[0] else finalists[0], "semis": losers, "third": bronze["w"]}


static func finish(w: GameWorld, id: String, year: int) -> Dictionary:
	start(w)
	var st: Dictionary = states(w).get(id, {})
	if st.is_empty() or int(st["y"]) != year or bool(st["done"]):
		return {}
	var env := NationalTeamManager._make_env(w, 6000 + id.hash() % 997, 35.0)
	while int(st["md"]) < 6:
		_matchday(env, st)
	if not bool(st["qf_done"]):
		_quarterfinals(env, st)
	env.tournament_finals = true
	var final := _final_four(env, st, st["finalists"])
	var lower := {}
	if id == "CNL":
		for level in [1, 2]:
			var four := _positions(st, level, 0)
			if four.size() < 4:
				four.append_array(_positions(st, level, 1).slice(0, 4 - four.size()))
			lower["ABC"[level]] = _final_four(env, st, four, " — Liga " + "ABC"[level])["champion"]
	var groups: Array = []
	for g in st["groups"]:
		groups.append({"n": g["n"], "order": NationalTeamManager.sort_group(g), "table": g["table"]})
	var rec := {"t": id, "y": year, "name": NationalTeamManager.tournament_name(id), "host": "", "teams": st["teams"], "champion": final["champion"], "runner_up": final["runner_up"], "semis": final["semis"], "third": final["third"], "groups": groups, "ko": st["ko"], "scorer": {}, "lower_champions": lower, "next_divisions": st["next_divisions"], "squad": env.squad(final["champion"]).map(func(p: Player): return p.id)}
	rec["stage"] = NationalTeamManager._stages(st["teams"], groups, st["ko"], final["champion"])
	NationalTeamManager._tournament_effects(w, env, rec)
	NationalCoach.on_tournament(w, rec)
	st["done"] = true
	return rec
