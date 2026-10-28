class_name NationalSchedule
extends RefCounted
## A mesma agenda persistida alimenta a tela e a simulação. Cada seleção joga
## no máximo uma vez por rodada e duas vezes por janela, incluindo amistosos.

static func ensure(w: GameWorld) -> Dictionary:
	var d := NationalTeamManager.data(w)
	var saved: Dictionary = d.get("calendar", {})
	if int(saved.get("year", -1)) == w.year:
		return saved
	NationalLeagues.start(w)
	var agenda := {"year": w.year, "windows": {}, "played": []}
	var items: Array = []
	for i in d["camps"].size():
		var camp: Dictionary = d["camps"][i]
		if not bool(camp["done"]):
			items.append({"kind": "qual", "index": i, "md": int(camp["md"]), "max": int(camp["mdt"]), "due": int(camp["end"]), "fx": camp["fx"]})
	for id in NationalLeagues.IDS:
		var st: Dictionary = NationalLeagues.states(w).get(id, {})
		if not st.is_empty() and not bool(st["done"]) and int(st["y"]) == w.year + 1:
			items.append({"kind": "nl", "id": id, "md": int(st["md"]), "max": 6, "due": w.year, "fx": st["fx"]})
	items.sort_custom(func(a, b): return int(a["due"]) < int(b["due"]) or (int(a["due"]) == int(b["due"]) and a["kind"] == "nl" and b["kind"] != "nl"))
	var rng := RandomNumberGenerator.new()
	rng.seed = RngUtil.hash_i(w.world_seed, w.year, 87123)
	var previous := {}
	var wins := NationalTeamManager.windows(w)
	for wi in wins.size():
		var win: Dictionary = wins[wi]
		if int(win["slot"]) < w.season.day or wi < int(d.get("fifa", 0)):
			continue
		var rounds: Array = []
		for round_index in 2:
			var round_ := {"day": int(win["from"]) + 1 + round_index * 4, "events": [], "friendlies": []}
			var used := {}
			for item in items:
				if int(item["md"]) >= int(item["max"]):
					continue
				var teams := {}
				for f in item["fx"]:
					if int(f[0]) == int(item["md"]) and int(f[4]) < 0:
						teams[f[2]] = true
						teams[f[3]] = true
				var clash := false
				for code in teams:
					if used.has(code):
						clash = true
				if clash:
					continue
				var event := {"kind": item["kind"], "md": item["md"]}
				if item["kind"] == "qual":
					event["index"] = item["index"]
				else:
					event["id"] = item["id"]
				round_["events"].append(event)
				used.merge(teams)
				item["md"] = int(item["md"]) + 1
			var free: Array = DatabaseManager.nations().keys().filter(func(code): return not used.has(code))
			free.sort()
			RngUtil.shuffle(rng, free)
			while free.size() >= 2:
				var a: String = free.pop_back()
				var bi := free.size() - 1
				if free[bi] == previous.get(a, "") and bi > 0:
					bi -= 1
				var b: String = free[bi]
				free.remove_at(bi)
				round_["friendlies"].append([a, b])
				previous[a] = b
				previous[b] = a
			rounds.append(round_)
		agenda["windows"][str(win["w"])] = rounds
	d["calendar"] = agenda
	return agenda


static func _state(w: GameWorld, event: Dictionary) -> Dictionary:
	if event["kind"] == "nl":
		return NationalLeagues.states(w).get(event["id"], {})
	var camps: Array = NationalTeamManager.data(w)["camps"]
	var index := int(event["index"])
	return camps[index] if index >= 0 and index < camps.size() else {}


static func _tag(state: Dictionary, event: Dictionary) -> String:
	return String(state["name"]) if event["kind"] == "qual" else NationalTeamManager.tournament_name(state["t"])


static func upcoming(w: GameWorld, code: String, limit: int = 12) -> Array:
	var agenda := ensure(w)
	var out: Array = []
	for win in NationalTeamManager.windows(w):
		var key := str(win["w"])
		if agenda["played"].has(key) or int(win["slot"]) < w.season.day:
			continue
		for round_ in agenda["windows"].get(key, []):
			for event in round_["events"]:
				var state := _state(w, event)
				for f in state.get("fx", []):
					if int(f[0]) == int(event["md"]) and (f[2] == code or f[3] == code):
						out.append({"a": String(f[2]), "b": String(f[3]), "day": int(round_["day"]), "tag": _tag(state, event)})
			for pair in round_["friendlies"]:
				if pair.has(code):
					out.append({"a": String(pair[0]), "b": String(pair[1]), "day": int(round_["day"]), "tag": "Amistoso"})
	return out.slice(0, limit)


static func play_window(w: GameWorld, weekend: int, env: NationalTeamManager.Env) -> Array:
	var agenda := ensure(w)
	var key := str(weekend)
	if agenda["played"].has(key):
		return []
	var out: Array = []
	for round_ in agenda["windows"].get(key, []):
		env.day = int(round_["day"])
		for event in round_["events"]:
			var state := _state(w, event)
			if state.is_empty() or int(state["md"]) != int(event["md"]):
				continue
			env.k = 30.0
			env.tag = _tag(state, event)
			if event["kind"] == "nl":
				out.append_array(NationalLeagues._matchday(env, state))
			else:
				out.append_array(NationalTeamManager._play_matchday(env, state))
		env.k = 12.0
		env.tag = "Amistoso"
		for pair in round_["friendlies"]:
			var result := NationalTeamManager.play(env, pair[0], pair[1], true, false)
			result["fr"] = true
			out.append(result)
	agenda["played"].append(key)
	return out
