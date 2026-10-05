class_name Commentary
extends RefCounted
## Narração procedural a partir dos eventos da MatchSimulation.
## Cada categoria é sorteada "de saco": nenhuma frase se repete na partida até a categoria
## inteira ter sido usada. Escolhe variações pelo contexto do lance (placar, minuto, clássico,
## quem marcou, chance perdida antes, como a jogada terminou).

var sim: MatchSimulation
var stadium: String = ""
var rng := RandomNumberGenerator.new()
var _bags: Dictionary = {} # categoria -> índices ainda não usados nesta partida
var _last: Dictionary = {} # categoria -> último índice usado (não repete na virada do saco)
var _data: Dictionary = {}
var _big_miss: Dictionary = {} # player_id -> chances claras perdidas no jogo
var _ok_idx: Dictionary = {} # categoria -> índices com tradução no idioma atual


func _init(p_sim: MatchSimulation, p_stadium: String, seed_value: int) -> void:
	sim = p_sim
	stadium = p_stadium
	rng.seed = seed_value
	_data = DatabaseManager.commentary()


func _pick(cat: String) -> String:
	var arr: Array = _data.get(cat, [])
	if arr.is_empty():
		return ""
	var bag: Array = _bags.get(cat, [])
	if bag.is_empty():
		bag = _allowed(cat, arr).duplicate()
		_bags[cat] = bag
	if bag.is_empty():
		return ""
	var j := rng.randi_range(0, bag.size() - 1)
	if bag.size() > 1 and int(bag[j]) == int(_last.get(cat, -1)):
		j = (j + 1) % bag.size()
	var i := int(bag[j])
	bag.remove_at(j)
	_last[cat] = i
	return arr[i]


## Índices sorteáveis da categoria. Em inglês e espanhol ficam só as frases já traduzidas: as
## falas novas de rádio existem só em português e não podem aparecer no meio do texto traduzido.
func _allowed(cat: String, arr: Array) -> Array:
	if _ok_idx.has(cat):
		return _ok_idx[cat]
	var out: Array = []
	for k in arr.size():
		if I18n.is_pt() or I18n.t(String(arr[k])) != String(arr[k]):
			out.append(k)
	_ok_idx[cat] = out
	return out


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
	if x.has("d"):
		out = out.replace("{d}", _name(1 - side, int(x["d"])))
	if out.contains("{culprit}"):
		var cn := _name(1 - side, int(x.get("culprit", -1)))
		if cn == "":
			# Chance de erro sem autor registrado: um defensor em campo leva a culpa na narração.
			var defs: Array = []
			for mp: MatchPlayer in opp.slots:
				if mp != null and Pos.group(mp.p.position) == Pos.G_DEF:
					defs.append(mp)
			if not defs.is_empty():
				cn = (defs[rng.randi_range(0, defs.size() - 1)] as MatchPlayer).p.display_name()
		out = out.replace("{culprit}", cn)
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
			var kc := "kickoff_derby" if sim.derby else ("kickoff_big" if sim.importance >= 0.7 and _data.has("kickoff_big") else "kickoff")
			out.append(_line(_pick(kc), ev, "info", 0.0))
		MatchSimulation.EV_SECOND_HALF:
			out.append(_line(_pick("second_half"), ev, "info", 0.0))
			var sd := int(ev.get("hs", 0)) - int(ev.get("as", 0))
			var sh_cat := "second_half_level" if sd == 0 else ("second_half_rout" if absi(sd) >= 2 else "second_half_close")
			if _data.has(sh_cat) and rng.randf() < 0.8:
				out.append(_line(_pick(sh_cat), _as_side(ev, -1 if sd == 0 else (0 if sd > 0 else 1)), "info", 0.6))
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
			out.append(_line(txt + pen_detail(x) + "  (%d x %d)" % [int(ps[0]), int(ps[1])], ev, "big", 0.0))
		MatchSimulation.EV_FULLTIME:
			out.append(_line(_pick("fulltime"), ev, "big", 0.0))
			var fc := _fulltime_context(ev)
			if fc != "":
				out.append(_line(_pick(fc), _as_side(ev, _winner_side(ev)), "info", 0.8))
		MatchSimulation.EV_POSSESSION:
			var pk := "poss_" + String(x.get("kind", ""))
			out.append(_line(_pick(pk if _data.has(pk) else "possession"), ev, "normal", 0.0))
		MatchSimulation.EV_GOAL, MatchSimulation.EV_OWN_GOAL:
			var ct := int(x.get("ct", -1))
			var tags: Array = x.get("tags", [])
			var fin := String(x.get("fin", ""))
			if t == MatchSimulation.EV_GOAL:
				var bc := _build_cat(ct, int(ev.get("p2", -1)) >= 0)
				if fin == "solo":
					bc = "build_solo"
				out.append(_line(_pick(bc), ev, "chance", 0.0))
				if rng.randf() < 0.55:
					_radio(out, _tension_cat(ct), ev, "chance", 0.15)
				if fin != "" and _data.has("fin_" + fin):
					out.append(_line(_pick("fin_" + fin), ev, "chance", 0.3))
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
			if rng.randf() < 0.6:
				_radio(out, "radio_goal_score", ev, "info", 1.3)
			var ctx := _goal_context(ev, tags) if t == MatchSimulation.EV_GOAL else ""
			if ctx != "" and rng.randf() < 0.75:
				out.append(_line(_pick(ctx), ev, "info", 1.1))
			if rng.randf() < 0.55:
				out.append(_pundit(_pundit_goal_cat(ct, tags), ev, 1.6))
		MatchSimulation.EV_SAVE, MatchSimulation.EV_MISS, MatchSimulation.EV_POST, MatchSimulation.EV_BLOCK:
			var ct2 := int(x.get("ct", -1))
			out.append(_line(_pick(_build_cat(ct2, int(ev.get("p2", -1)) >= 0)), ev, "chance", 0.0))
			var cat2: String = {MatchSimulation.EV_SAVE: "save", MatchSimulation.EV_MISS: "miss", MatchSimulation.EV_POST: "post", MatchSimulation.EV_BLOCK: "block"}[t]
			var big := float(x.get("xg", 0.0)) >= 0.3
			var fin2 := String(x.get("fin", ""))
			if fin2 == "var_off":
				# A bola entra, a torcida grita, e o VAR anula: no placar, sempre foi para fora.
				out.append(_hl(_line(_pick("var_off_goal"), ev, "big", 0.5), "var_goal"))
				out.append(_hl(_line(_pick("var_off_reason"), ev, "var", 1.6), "var_off"))
				return out
			if t == MatchSimulation.EV_BLOCK and x.has("line"):
				cat2 = "block_line"
			elif fin2 != "" and _data.has(cat2 + "_" + fin2):
				cat2 += "_" + fin2
			elif big and (t == MatchSimulation.EV_SAVE or t == MatchSimulation.EV_MISS):
				cat2 += "_big"
			if t != MatchSimulation.EV_BLOCK and float(x.get("xg", 0.0)) >= 0.15 and rng.randf() < 0.5:
				_radio(out, _tension_cat(ct2), ev, "chance", 0.25)
			var hot := t == MatchSimulation.EV_POST or cat2 == "block_line" or big or fin2 in ["double", "fingertip", "one_on_one", "last_ditch"]
			var ol := _line(_pick(cat2), ev, "chance" if hot else "normal", 0.5)
			if hot:
				ol["hl"] = cat2
			out.append(ol)
			var pid :=int(ev.get("p", -1))
			if big and t == MatchSimulation.EV_MISS:
				_big_miss[pid] = int(_big_miss.get(pid, 0)) + 1
			var ctx2 := _chance_context(ev, t, big)
			if ctx2 != "" and rng.randf() < 0.6:
				out.append(_line(_pick(ctx2), ev, "info", 1.1))
			elif big and t == MatchSimulation.EV_MISS and rng.randf() < 0.5:
				out.append(_pundit("pundit_miss", ev, 1.4))
			elif big and t == MatchSimulation.EV_SAVE and rng.randf() < 0.35:
				out.append(_pundit("pundit_save", ev, 1.4))
		MatchSimulation.EV_PEN_SAVE:
			out.append(_line(_pick("build_penalty"), ev, "chance", 0.0))
			out.append(_hl(_line(_pick("pen_save") + pen_detail(x), ev, "big", 0.6), "pen_save"))
		MatchSimulation.EV_PEN_MISS:
			out.append(_line(_pick("build_penalty"), ev, "chance", 0.0))
			out.append(_hl(_line(_pick("pen_miss") + pen_detail(x), ev, "big", 0.6), "pen_miss"))
		MatchSimulation.EV_PENALTY_AWARDED:
			var how := String(x.get("how", ""))
			if how != "" and _data.has("pen_how_" + how):
				out.append(_line(_pick("pen_how_" + how), ev, "chance", 0.0))
			out.append(_hl(_line(_pick("penalty_awarded"), ev, "big", 0.3 if how != "" else 0.0), "pen"))
		MatchSimulation.EV_FOUL:
			out.append(_line(_pick("foul_danger" if x.get("danger", false) else "foul"), ev, "normal", 0.0))
		MatchSimulation.EV_YELLOW:
			out.append(_line(_pick("yellow"), ev, "card_y", 0.2))
			if rng.randf() < 0.3:
				out.append(_line(_pick("reporter_card"), ev, "reporter", 1.4))
		MatchSimulation.EV_RED:
			out.append(_hl(_line(_pick("second_yellow" if x.get("second", false) else "red"), ev, "card_r", 0.2), "red"))
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
				out.append(_hl(_line(_pick("offside_goal"), ev, "big", 0.0), "offside_goal"))
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
		MatchSimulation.EV_CRAMP:
			out.append(_line(_pick("cramp"), ev, "normal", 0.0))
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
			elif x.has("pressing"):
				cat3 = "tactic_press_up" if int(x["pressing"]) == 2 else "tactic_press_down"
			elif x.has("line"):
				cat3 = "tactic_line_high" if int(x["line"]) == 2 else "tactic_line_low"
			elif x.has("width"):
				cat3 = "tactic_width_open" if int(x["width"]) == 2 else ("tactic_width_closed" if int(x["width"]) == 0 else "tactic_other")
			elif x.has("intensity"):
				cat3 = "tactic_intensity"
			elif x.has("instr"):
				cat3 = "tactic_instr"
			elif m >= 3:
				cat3 = "tactic_attack"
			elif m >= 0 and m <= 1:
				cat3 = "tactic_defend"
			out.append(_line(_pick(cat3), ev, "tactic" if x.has("formation") else "info", 0.0))
			if (x.has("formation") or x.has("style")) and rng.randf() < 0.4:
				out.append(_line(_pick("reporter_coach"), ev, "reporter", 1.0))
	return out


## Linha de rádio (só existe em português): entra só se a categoria tiver o que dizer.
func _radio(out: Array, cat: String, ev: Dictionary, style: String, delay: float) -> void:
	var txt := _pick(cat)
	if txt != "":
		out.append(_line(txt, ev, style, delay))


## Bola aérea ou bate-rebate não tem "ajeitou pra bater": a tensão é outra.
static func _tension_cat(ct: int) -> String:
	if ct in [MatchSimulation.CH_CROSS, MatchSimulation.CH_CORNER, MatchSimulation.CH_SCRAMBLE]:
		return "radio_tension_air"
	return "radio_tension"


## "Tempo e placar" do rádio, com {team} apontando para quem vence. Vazio fora do português.
func clock_line(minute: int, half: int) -> Dictionary:
	var hs := sim.score[0]
	var as_ := sim.score[1]
	var cat := "radio_clock"
	var side := -1
	if rng.randf() < 0.6:
		if hs == as_:
			cat = "radio_clock_level"
		else:
			cat = "radio_clock_lead"
			side = 0 if hs > as_ else 1
	var txt := _pick(cat)
	if txt == "":
		return {}
	var ev := {"t": -1, "m": minute, "h": half, "s": maxi(side, 0), "x": {}, "hs": hs, "as": as_}
	var l := _line(txt, ev, "info", 0.0)
	l["side"] = side
	return l


## Marca a linha como lance de destaque (a tela mostra um letreiro no campo: "NA TRAVE!").
static func _hl(line: Dictionary, kind: String) -> Dictionary:
	line["hl"] = kind
	return line


## Cópia do evento com outro lado (para {team}/{opp} apontarem para quem vence, por exemplo).
static func _as_side(ev: Dictionary, side: int) -> Dictionary:
	var e := ev.duplicate()
	e["s"] = side
	return e


## Frase de contexto depois do grito de gol: quem marcou (garoto, veterano, zagueiro, quem
## saiu do banco, quem tinha perdido uma chance clara), o momento (logo no início, contra a
## corrente do jogo, diminuindo, abrindo dois) e o ambiente (clássico, silêncio na casa rival).
func _goal_context(ev: Dictionary, tags: Array) -> String:
	var side := int(ev.get("s", 0))
	if side < 0:
		return ""
	var pid := int(ev.get("p", -1))
	var mp: MatchPlayer = sim.teams[side].by_id.get(pid, null)
	var opts: Array = []
	if mp != null:
		var age := mp.p.age(sim.year)
		if int(_big_miss.get(pid, 0)) > 0:
			opts.append("ctx_redemption")
			opts.append("ctx_redemption")
		if mp.start_min > 0:
			opts.append("ctx_supersub")
		if age <= 19:
			opts.append("ctx_young")
		elif age >= 34:
			opts.append("ctx_veteran")
		if Pos.group(mp.p.position) == Pos.G_DEF:
			opts.append("ctx_defender")
		if mp.goals == 1 and mp.p.stats.size() > Player.S_GOALS and int(mp.p.stats[Player.S_GOALS]) == 0 and Pos.group(mp.p.position) == Pos.G_ATT:
			opts.append("ctx_first_season")
	var hs := int(ev.get("hs", 0))
	var as_ := int(ev.get("as", 0))
	var diff := (hs - as_) if side == 0 else (as_ - hs)
	if int(ev.get("h", 1)) == 1 and int(ev.get("m", 0)) <= 3:
		opts.append("ctx_early")
	if diff == -1:
		opts.append("ctx_pull_back")
	elif diff == 2 and not tags.has("blowout"):
		opts.append("ctx_two_up")
	var me: MatchTeam = sim.teams[side]
	var op: MatchTeam = sim.teams[1 - side]
	if op.xg - me.xg >= 0.8:
		opts.append("ctx_against_run")
	if sim.derby:
		opts.append("ctx_derby")
	if side == 1 and not sim.neutral and diff >= 0:
		opts.append("ctx_away_silence")
	var valid: Array = []
	for o in opts:
		if _data.has(o):
			valid.append(o)
	if valid.is_empty():
		return ""
	return String(valid[rng.randi_range(0, valid.size() - 1)])


## Contexto de uma chance que não virou gol: o goleiro que pega tudo, o atacante que insiste
## e perde de novo, a chance do empate no fim.
func _chance_context(ev: Dictionary, t: int, big: bool) -> String:
	var side := int(ev.get("s", 0))
	if side < 0:
		return ""
	var pid := int(ev.get("p", -1))
	var hs := int(ev.get("hs", 0))
	var as_ := int(ev.get("as", 0))
	var diff := (hs - as_) if side == 0 else (as_ - hs)
	var late := int(ev.get("h", 1)) >= 2 and int(ev.get("m", 0)) >= 80
	if t == MatchSimulation.EV_SAVE:
		var gk := sim.teams[1 - side].goalkeeper()
		if gk != null and gk.saves >= 4 and _data.has("ctx_keeper_wall"):
			return "ctx_keeper_wall"
	if big and late and diff == -1 and t != MatchSimulation.EV_BLOCK:
		return "ctx_miss_late"
	if big and t == MatchSimulation.EV_MISS and int(_big_miss.get(pid, 0)) >= 2:
		return "ctx_miss_again"
	return ""


static func _winner_side(ev: Dictionary) -> int:
	return 0 if int(ev.get("hs", 0)) >= int(ev.get("as", 0)) else 1


## Fecho do jogo: goleada, virada, empate sem gols, vitória do visitante.
func _fulltime_context(ev: Dictionary) -> String:
	var hs := int(ev.get("hs", 0))
	var as_ := int(ev.get("as", 0))
	var w := _winner_side(ev)
	var cat := "ft_win"
	if hs == as_:
		cat = "ft_nil" if hs == 0 else "ft_draw"
	elif absi(hs - as_) >= 3:
		cat = "ft_rout"
	elif sim.trailed[w]:
		cat = "ft_comeback"
	elif w == 1 and not sim.neutral:
		cat = "ft_away_win"
	return cat if _data.has(cat) else ""


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


## Palestra no vestiário: o que o técnico disse (a fala escolhida na tela) e, na voz do
## repórter de campo, quem saiu mais ligado (ou abatido).
func _talk_lines(ev: Dictionary, x: Dictionary) -> Array:
	var side := int(ev.get("s", 0))
	var cfg: Dictionary = MatchSimulation.TALKS.get(String(x["talk"]), {})
	var say := String(x.get("say", ""))
	var lines: Array = []
	if int(ev.get("m", 0)) <= 0:
		ev = ev.duplicate()
		ev["t"] = MatchSimulation.EV_KICKOFF # antes do jogo: sem minuto na linha
	if say != "" and I18n.is_pt():
		lines.append(_line(_pick_or("radio_talk_open", "No vestiário do {team}, o técnico fala com o grupo:"), ev, "reporter", 0.0))
		lines.append(_raw_line("“%s”" % say, ev, "tactic", 0.3))
	else:
		lines.append(_line(I18n.t("No vestiário do {team}: “%s”") % I18n.t(String(cfg.get("name", ""))), ev, "tactic", 0.0))
	var up: Array = []
	for pid in x.get("up", []):
		up.append(_name(side, int(pid)))
	var down: Array = []
	for pid in x.get("down", []):
		down.append(_name(side, int(pid)))
	if up.size() >= 3:
		lines.append(_line(I18n.t("O grupo volta a campo ligado. %s parecem outros.") % ", ".join(up.slice(0, 2)), ev, "reporter", 0.8))
	elif not up.is_empty():
		lines.append(_line(I18n.t("%s sai do vestiário mais confiante.") % ", ".join(up), ev, "reporter", 0.8))
	if not down.is_empty():
		lines.append(_line(I18n.t("%s não gostou do tom da conversa.") % ", ".join(down.slice(0, 2)), ev, "reporter", 0.9))
	return lines


func _pick_or(cat: String, fallback: String) -> String:
	var txt := _pick(cat)
	return txt if txt != "" else fallback


## Linha com texto pronto (sem tradução nem marcadores).
func _raw_line(text: String, ev: Dictionary, style: String, delay: float) -> Dictionary:
	var l := _line("", ev, style, delay)
	l["text"] = text
	return l


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


## Como foi a cobrança: canto, altura e para onde o goleiro foi.
static func pen_detail(x: Dictionary) -> String:
	if not x.has("dir"):
		return ""
	var d := int(x["dir"])
	var dv := int(x.get("dive", -1))
	var res := String(x.get("res", ""))
	if bool(x.get("panenka", false)):
		return " — de cavadinha!"
	var where := "no meio" if d == 1 else "no canto %s" % ["esquerdo", "", "direito"][d]
	match res:
		"goal":
			if dv < 0 or dv == d:
				return " — %s, sem chance." % where
			return " — %s, goleiro foi para o outro lado." % where
		"save":
			return " — %s, e o goleiro adivinhou." % where
		"post":
			return " — %s, na trave!" % where
		"over":
			return " — por cima do gol."
		"wide":
			return " — %s, para fora." % where
	return ""


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
