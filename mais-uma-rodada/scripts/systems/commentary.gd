class_name Commentary
extends RefCounted
## Narração procedural a partir dos eventos da MatchSimulation.
## Evita repetir a mesma frase em sequência e escolhe variações pelo contexto do gol.

var sim: MatchSimulation
var stadium: String = ""
var rng := RandomNumberGenerator.new()
var _last: Dictionary = {}
var _data: Dictionary = {}


func _init(p_sim: MatchSimulation, p_stadium: String, seed_value: int) -> void:
	sim = p_sim
	stadium = p_stadium
	rng.seed = seed_value
	_data = DatabaseManager.commentary()


func _pick(cat: String) -> String:
	var arr: Array = _data.get(cat, [])
	if arr.is_empty():
		return ""
	var i := rng.randi_range(0, arr.size() - 1)
	if arr.size() > 1 and _last.get(cat, -1) == i:
		i = (i + 1 + rng.randi_range(0, arr.size() - 2)) % arr.size()
	_last[cat] = i
	return arr[i]


func _name(side: int, pid: int) -> String:
	if pid < 0 or side < 0:
		return ""
	for s in [side, 1 - side]:
		var t: MatchTeam = sim.teams[s]
		var mp: MatchPlayer = t.by_id.get(pid, null)
		if mp != null:
			return mp.p.display_name()
	return ""


func _fill(text: String, ev: Dictionary) -> String:
	var side: int = ev.get("s", 0)
	var home: MatchTeam = sim.teams[0]
	var away: MatchTeam = sim.teams[1]
	var team: MatchTeam = sim.teams[side] if side >= 0 else home
	var opp: MatchTeam = sim.teams[1 - side] if side >= 0 else away
	var x: Dictionary = ev.get("x", {})
	var gk_name := ""
	if x.has("gk"):
		gk_name = _name(1 - side, int(x["gk"]))
	if gk_name == "":
		var gk := opp.goalkeeper()
		gk_name = gk.p.display_name() if gk != null else "o goleiro"
	var out := text
	out = out.replace("{p}", _name(side, int(ev.get("p", -1))))
	var p2_side := side
	if int(ev.get("t", -1)) in [MatchSimulation.EV_FOUL, MatchSimulation.EV_PENALTY_AWARDED, MatchSimulation.EV_SKILL, MatchSimulation.EV_TACKLE, MatchSimulation.EV_VAR]:
		p2_side = 1 - side
	out = out.replace("{p2}", _name(p2_side, int(ev.get("p2", -1))))
	out = out.replace("{gk}", gk_name)
	out = out.replace("{culprit}", _name(1 - side, int(x.get("culprit", -1))))
	out = out.replace("{TEAM}", team.club.short_name.to_upper())
	out = out.replace("{team}", team.club.short_name)
	out = out.replace("{opp}", opp.club.short_name)
	out = out.replace("{home}", home.club.short_name)
	out = out.replace("{away}", away.club.short_name)
	out = out.replace("{hs}", str(ev.get("hs", 0)))
	out = out.replace("{as}", str(ev.get("as", 0)))
	out = out.replace("{min}", Fmt.minute(int(ev.get("m", 0)), int(ev.get("h", 1))))
	out = out.replace("{stadium}", stadium)
	out = out.replace("{n}", str(x.get("n", "")))
	out = out.replace("{f}", str(x.get("formation", "")))
	out = out.replace("{line}", _name(1 - side, int(x.get("line", -1))))
	out = out.replace("{txt}", str(x.get("txt", "")))
	if x.has("style"):
		var styles: Array = DatabaseManager.tactics()["styles"]
		var st := int(x["style"])
		out = out.replace("{st}", String(styles[st]["name"]).to_lower() if st >= 0 and st < styles.size() else "")
	return out


static func _build_cat(ct: int, has_assist: bool) -> String:
	match ct:
		MatchSimulation.CH_THROUGH:
			return "build_through" if has_assist else "build_through_solo"
		MatchSimulation.CH_CROSS:
			return "build_cross" if has_assist else "build_cross_solo"
		MatchSimulation.CH_LONG:
			return "build_long"
		MatchSimulation.CH_DRIBBLE:
			return "build_dribble"
		MatchSimulation.CH_COUNTER:
			return "build_counter" if has_assist else "build_through_solo"
		MatchSimulation.CH_SCRAMBLE:
			return "build_scramble"
		MatchSimulation.CH_CORNER:
			return "build_corner" if has_assist else "build_cross_solo"
		MatchSimulation.CH_FREEKICK:
			return "build_freekick"
		MatchSimulation.CH_PENALTY:
			return "build_penalty"
		MatchSimulation.CH_ERROR:
			return "build_error"
	return "build_through_solo"


## Linhas de narração para um evento: [{text, style, side, delay}].
## style: normal | chance | goal | card_y | card_r | info | sub | injury | big
func lines_for(ev: Dictionary) -> Array:
	var out: Array = []
	var t: int = ev["t"]
	var side: int = ev.get("s", -1)
	var x: Dictionary = ev.get("x", {})
	match t:
		MatchSimulation.EV_KICKOFF:
			out.append(_line(_pick("kickoff_derby" if sim.derby else "kickoff"), ev, "info", 0.0))
		MatchSimulation.EV_SECOND_HALF:
			out.append(_line(_pick("second_half"), ev, "info", 0.0))
		MatchSimulation.EV_HALFTIME:
			out.append(_line(_pick("halftime_et" if x.get("et", false) else "halftime"), ev, "big" if x.get("et", false) else "info", 0.0))
		MatchSimulation.EV_EXTRA_TIME:
			out.append(_line(_pick("extra_time"), ev, "info", 0.0))
		MatchSimulation.EV_ET_SECOND:
			out.append(_line(_pick("et_second"), ev, "info", 0.0))
		MatchSimulation.EV_SHOOTOUT:
			out.append(_line(_pick("shootout"), ev, "big", 0.0))
		MatchSimulation.EV_SHOOT_KICK:
			var ps: Array = x.get("ps", [0, 0])
			var txt := _pick("shoot_ok" if x.get("ok", false) else "shoot_miss")
			out.append(_line(txt + "  (%d x %d)" % [int(ps[0]), int(ps[1])], ev, "big", 0.0))
		MatchSimulation.EV_FULLTIME:
			out.append(_line(_pick("fulltime"), ev, "big", 0.0))
		MatchSimulation.EV_POSSESSION:
			out.append(_line(_pick("possession"), ev, "normal", 0.0))
		MatchSimulation.EV_GOAL, MatchSimulation.EV_OWN_GOAL:
			var ct := int(x.get("ct", -1))
			var tags: Array = x.get("tags", [])
			if t == MatchSimulation.EV_GOAL:
				out.append(_line(_pick(_build_cat(ct, int(ev.get("p2", -1)) >= 0)), ev, "chance", 0.0))
			var cat := "goal"
			if t == MatchSimulation.EV_OWN_GOAL:
				cat = "goal_own"
			elif tags.has("hattrick"):
				cat = "goal_hattrick"
			elif tags.has("virada"):
				cat = "goal_virada"
			elif tags.has("late") and not tags.has("blowout"):
				cat = "goal_late"
			elif tags.has("equalizer"):
				cat = "goal_equalizer"
			elif tags.has("winner"):
				cat = "goal_winner"
			elif tags.has("golaco"):
				cat = "goal_golaco"
			elif tags.has("penalty"):
				cat = "goal_penalty"
			elif tags.has("header"):
				cat = "goal_header"
			elif tags.has("blowout"):
				cat = "goal_blowout"
			out.append(_line(_pick(cat), ev, "goal", 0.55))
			if int(ev.get("p2", -1)) >= 0 and t == MatchSimulation.EV_GOAL:
				out.append(_line(_pick("assist"), ev, "info", 0.8))
		MatchSimulation.EV_SAVE, MatchSimulation.EV_MISS, MatchSimulation.EV_POST, MatchSimulation.EV_BLOCK:
			var ct2 := int(x.get("ct", -1))
			out.append(_line(_pick(_build_cat(ct2, int(ev.get("p2", -1)) >= 0)), ev, "chance", 0.0))
			var cat2: String = {MatchSimulation.EV_SAVE: "save", MatchSimulation.EV_MISS: "miss", MatchSimulation.EV_POST: "post", MatchSimulation.EV_BLOCK: "block"}[t]
			if t == MatchSimulation.EV_BLOCK and x.has("line"):
				cat2 = "block_line"
			out.append(_line(_pick(cat2), ev, "chance" if t == MatchSimulation.EV_POST or cat2 == "block_line" else "normal", 0.5))
		MatchSimulation.EV_PEN_SAVE:
			out.append(_line(_pick("build_penalty"), ev, "chance", 0.0))
			out.append(_line(_pick("pen_save"), ev, "big", 0.6))
		MatchSimulation.EV_PEN_MISS:
			out.append(_line(_pick("build_penalty"), ev, "chance", 0.0))
			out.append(_line(_pick("pen_miss"), ev, "big", 0.6))
		MatchSimulation.EV_PENALTY_AWARDED:
			out.append(_line(_pick("penalty_awarded"), ev, "big", 0.0))
		MatchSimulation.EV_FOUL:
			out.append(_line(_pick("foul_danger" if x.get("danger", false) else "foul"), ev, "normal", 0.0))
		MatchSimulation.EV_YELLOW:
			out.append(_line(_pick("yellow"), ev, "card_y", 0.2))
		MatchSimulation.EV_RED:
			out.append(_line(_pick("second_yellow" if x.get("second", false) else "red"), ev, "card_r", 0.2))
		MatchSimulation.EV_INJURY:
			out.append(_line(_pick("injury"), ev, "injury", 0.0))
		MatchSimulation.EV_SUB:
			out.append(_line(_pick("sub"), ev, "sub", 0.0))
		MatchSimulation.EV_OFFSIDE:
			if x.get("goal", false):
				out.append(_line(_pick("offside_goal"), ev, "big", 0.0))
			else:
				out.append(_line(_pick("offside"), ev, "normal", 0.0))
		MatchSimulation.EV_SKILL:
			out.append(_line(_pick("skill"), ev, "normal", 0.0))
		MatchSimulation.EV_TACKLE:
			out.append(_line(_pick("tackle"), ev, "normal", 0.0))
		MatchSimulation.EV_KEEPER:
			out.append(_line(_pick("keeper"), ev, "normal", 0.0))
		MatchSimulation.EV_KNOCK:
			out.append(_line(_pick("knock"), ev, "normal", 0.0))
		MatchSimulation.EV_CROWD:
			out.append(_line(_pick("crowd_" + String(x.get("kind", "home"))), ev, "crowd", 0.0))
		MatchSimulation.EV_VAR:
			var vk := String(x.get("kind", ""))
			out.append(_line(_pick("var_pen" if vk == "pen_ok" else "var_goal"), ev, "var", 1.2 if vk == "goal_ok" else 0.4))
		MatchSimulation.EV_CORNER:
			out.append(_line(_pick("corner"), ev, "normal", 0.0))
		MatchSimulation.EV_FREEKICK:
			out.append(_line(_pick("freekick"), ev, "normal", 0.0))
		MatchSimulation.EV_TACTIC:
			var m := int(x.get("mentality", -1))
			var cat3 := "tactic_other"
			if x.has("formation"):
				cat3 = "tactic_formation"
			elif x.has("style"):
				cat3 = "tactic_style"
			elif m >= 3:
				cat3 = "tactic_attack"
			elif m >= 0 and m <= 1:
				cat3 = "tactic_defend"
			out.append(_line(_pick(cat3), ev, "tactic" if x.has("formation") else "info", 0.0))
	return out


func _line(text: String, ev: Dictionary, style: String, delay: float) -> Dictionary:
	return {
		"text": _fill(text, ev), "style": style, "side": ev.get("s", -1), "delay": delay,
		"minute": Fmt.minute(int(ev.get("m", 0)), int(ev.get("h", 1))) if int(ev.get("t", -1)) not in [MatchSimulation.EV_KICKOFF, MatchSimulation.EV_SECOND_HALF] else "",
	}


## Linha avulsa (clima, troca de lado, gols de outros jogos): {txt} já vem pronto em `extra`.
func extra_line(cat: String, style: String, minute: int, half: int, extra: Dictionary = {}) -> Dictionary:
	var ev := {"t": -1, "m": minute, "h": half, "s": -1, "x": extra}
	var l := _line(_pick(cat), ev, style, 0.0)
	if minute <= 0:
		l["minute"] = ""
	return l


func stoppage_line(n: int, half: int) -> Dictionary:
	var ev := {"t": -1, "m": 45 if half == 1 else 90, "h": half, "s": -1, "x": {"n": n}}
	return _line(_pick("stoppage"), ev, "info", 0.0)
