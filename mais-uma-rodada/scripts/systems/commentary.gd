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
		gk_name = gk.p.display_name() if gk != null else I18n.t("o goleiro")
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
			var pk := "poss_" + String(x.get("kind", ""))
			out.append(_line(_pick(pk if _data.has(pk) else "possession"), ev, "normal", 0.0))
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
			elif ct == MatchSimulation.CH_FREEKICK:
				cat = "goal_freekick"
			elif tags.has("header"):
				cat = "goal_header"
			elif tags.has("counter"):
				cat = "goal_counter"
			elif tags.has("error"):
				cat = "goal_error"
			elif tags.has("blowout"):
				cat = "goal_blowout"
			out.append(_line(_pick(cat), ev, "goal", 0.55))
			if t == MatchSimulation.EV_GOAL and not tags.has("hattrick") and _goals_of(side, int(ev.get("p", -1))) == 2:
				out.append(_line(_pick("brace"), ev, "info", 0.7))
			if int(ev.get("p2", -1)) >= 0 and t == MatchSimulation.EV_GOAL:
				out.append(_line(_pick("assist"), ev, "info", 0.8))
			if rng.randf() < 0.55:
				out.append(_pundit(_pundit_goal_cat(ct, tags), ev, 1.6))
		MatchSimulation.EV_SAVE, MatchSimulation.EV_MISS, MatchSimulation.EV_POST, MatchSimulation.EV_BLOCK:
			var ct2 := int(x.get("ct", -1))
			out.append(_line(_pick(_build_cat(ct2, int(ev.get("p2", -1)) >= 0)), ev, "chance", 0.0))
			var cat2: String = {MatchSimulation.EV_SAVE: "save", MatchSimulation.EV_MISS: "miss", MatchSimulation.EV_POST: "post", MatchSimulation.EV_BLOCK: "block"}[t]
			var big := float(x.get("xg", 0.0)) >= 0.3
			if t == MatchSimulation.EV_BLOCK and x.has("line"):
				cat2 = "block_line"
			elif big and (t == MatchSimulation.EV_SAVE or t == MatchSimulation.EV_MISS):
				cat2 += "_big"
			out.append(_line(_pick(cat2), ev, "chance" if t == MatchSimulation.EV_POST or cat2 == "block_line" or big else "normal", 0.5))
			if big and t == MatchSimulation.EV_MISS and rng.randf() < 0.5:
				out.append(_pundit("pundit_miss", ev, 1.4))
			elif big and t == MatchSimulation.EV_SAVE and rng.randf() < 0.35:
				out.append(_pundit("pundit_save", ev, 1.4))
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
			if rng.randf() < 0.3:
				out.append(_line(_pick("reporter_card"), ev, "reporter", 1.4))
		MatchSimulation.EV_RED:
			out.append(_line(_pick("second_yellow" if x.get("second", false) else "red"), ev, "card_r", 0.2))
			out.append(_line(_pick("reporter_card"), ev, "reporter", 1.4))
		MatchSimulation.EV_INJURY:
			out.append(_line(_pick("injury"), ev, "injury", 0.0))
			out.append(_line(_pick("reporter_injury"), ev, "reporter", 1.2))
		MatchSimulation.EV_SUB:
			out.append(_line(_pick("sub"), ev, "sub", 0.0))
			if rng.randf() < 0.35:
				out.append(_line(_pick("reporter_sub"), ev, "reporter", 1.0))
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
			if x.has("shout"):
				out.append_array(_shout_lines(ev, x))
				return out
			if x.has("talk"):
				out.append_array(_talk_lines(ev, x))
				return out
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
			if (x.has("formation") or x.has("style")) and rng.randf() < 0.4:
				out.append(_line(_pick("reporter_coach"), ev, "reporter", 1.0))
	return out


func _goals_of(side: int, pid: int) -> int:
	if side < 0 or pid < 0:
		return 0
	var mp: MatchPlayer = sim.teams[side].by_id.get(pid, null)
	return mp.goals if mp != null else 0


static func _pundit_goal_cat(ct: int, tags: Array) -> String:
	if tags.has("counter") or ct == MatchSimulation.CH_COUNTER:
		return "pundit_goal_counter"
	if tags.has("error"):
		return "pundit_goal_error"
	if ct == MatchSimulation.CH_PENALTY:
		return "pundit_goal_penalty"
	if ct == MatchSimulation.CH_CORNER or ct == MatchSimulation.CH_FREEKICK:
		return "pundit_goal_setpiece"
	if tags.has("header"):
		return "pundit_goal_header"
	if ct == MatchSimulation.CH_LONG or tags.has("golaco"):
		return "pundit_goal_long"
	return "pundit_goal"


## Fala do comentarista (com o rótulo na frente).
func _pundit(cat: String, ev: Dictionary, delay: float) -> Dictionary:
	var l := _line(_pick(cat), ev, "pundit", delay)
	l["text"] = I18n.t("Comentarista") + ": " + String(l["text"])
	return l


## Análise do comentarista a partir dos números do jogo: posse, finalizações, goleiro que
## brilha, atacante que insiste, jogo pegado ou equilibrado. Vazio se não há o que dizer.
func analysis_line(minute: int, half: int) -> Dictionary:
	var h: MatchTeam = sim.teams[0]
	var a: MatchTeam = sim.teams[1]
	var opts: Array = []
	var ph := sim.possession_pct(0)
	if ph >= 0.6 or ph <= 0.4:
		var dom := 0 if ph >= 0.6 else 1
		opts.append(["pundit_dom", dom, -1, int(round((ph if dom == 0 else 1.0 - ph) * 100.0))])
	if absi(h.shots - a.shots) >= 5:
		var more := 0 if h.shots > a.shots else 1
		opts.append(["pundit_shots", more, -1, maxi(h.shots, a.shots)])
	var xd := h.xg - a.xg
	var sd := sim.score[0] - sim.score[1]
	if absf(xd) >= 0.9 and ((xd > 0.0 and sd <= 0) or (xd < 0.0 and sd >= 0)):
		opts.append(["pundit_unfair", 0 if xd > 0.0 else 1, -1, 0])
	for side in 2:
		var gk := sim.teams[side].goalkeeper()
		if gk != null and gk.saves >= 3:
			opts.append(["pundit_keeper", side, gk.p.id, gk.saves])
		var best: MatchPlayer = null
		for mp: MatchPlayer in sim.teams[side].slots:
			if mp != null and mp.shots >= 3 and mp.goals == 0 and (best == null or mp.shots > best.shots):
				best = mp
		if best != null:
			opts.append(["pundit_striker", side, best.p.id, best.shots])
	var cards := h.yellows + a.yellows
	if cards >= 4:
		opts.append(["pundit_cards", -1, -1, cards])
	if opts.is_empty():
		if absi(h.shots - a.shots) <= 2 and absf(ph - 0.5) < 0.07:
			opts.append(["pundit_even", -1, -1, 0])
		else:
			return {}
	var o: Array = opts[rng.randi_range(0, opts.size() - 1)]
	var ev := {"t": -1, "m": minute, "h": half, "s": int(o[1]), "p": int(o[2]), "x": {"n": int(o[3])}, "hs": sim.score[0], "as": sim.score[1]}
	if int(o[1]) < 0:
		ev["s"] = 0
	var l := _pundit(String(o[0]), ev, 0.0)
	l["side"] = int(o[1])
	return l


## Palestra no vestiário: o tom da conversa e quem saiu mais ligado (ou abatido).
func _talk_lines(ev: Dictionary, x: Dictionary) -> Array:
	var side := int(ev.get("s", 0))
	var cfg: Dictionary = MatchSimulation.TALKS.get(String(x["talk"]), {})
	var lines: Array = [_line(I18n.t("No vestiário do {team}: “%s”") % I18n.t(String(cfg.get("name", ""))), ev, "tactic", 0.0)]
	var up: Array = []
	for pid in x.get("up", []):
		up.append(_name(side, int(pid)))
	var down: Array = []
	for pid in x.get("down", []):
		down.append(_name(side, int(pid)))
	if up.size() >= 3:
		lines.append(_line(I18n.t("O grupo volta a campo ligado. %s parecem outros.") % ", ".join(up.slice(0, 2)), ev, "info", 0.4))
	elif not up.is_empty():
		lines.append(_line(I18n.t("%s sai do vestiário mais confiante.") % ", ".join(up), ev, "info", 0.4))
	if not down.is_empty():
		lines.append(_line(I18n.t("%s não gostou do tom da conversa.") % ", ".join(down.slice(0, 2)), ev, "info", 0.4))
	return lines


## Grito da beira do campo e a reação de quem respondeu (ou sentiu).
func _shout_lines(ev: Dictionary, x: Dictionary) -> Array:
	var side := int(ev.get("s", 0))
	var cfg: Dictionary = MatchSimulation.SHOUTS.get(String(x["shout"]), {})
	var coach := I18n.t("O técnico do {team}")
	var lines: Array = [_line(I18n.t("%s grita da beira do campo: “%s”") % [coach, I18n.t(String(cfg.get("name", "")))], ev, "tactic", 0.0)]
	var good: Array = []
	var bad: Array = []
	for r in x.get("react", []):
		var nm := _name(side, int(r[0]))
		if nm == "":
			continue
		(good if int(r[1]) > 0 else bad).append(nm)
	if not good.is_empty():
		lines.append(_line(I18n.t("%s responde na hora e pede a bola.") % ", ".join(good.slice(0, 3)), ev, "info", 0.4))
	if not bad.is_empty():
		lines.append(_line(I18n.t("%s sente o grito e abaixa a cabeça.") % ", ".join(bad.slice(0, 2)), ev, "info", 0.4))
	return lines


func _line(text: String, ev: Dictionary, style: String, delay: float) -> Dictionary:
	return {
		"text": _fill(I18n.t(text), ev), "style": style, "side": ev.get("s", -1), "delay": delay,
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
