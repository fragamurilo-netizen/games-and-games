class_name QuickMatch
extends RefCounted
## Jogo rápido (sem minuto a minuto) para as ~300 partidas de cada rodada em que o usuário não está.
## Usa o mesmo modelo de força do MatchSimulation — setores (defesa, meio, ataque) calculados dos
## atributos e das funções da formação, táticas, mando, finalizadores contra o goleiro — e resolve
## os gols de uma vez (Poisson com a média que o minuto a minuto produziria). Depois distribui os
## lances que importam para a carreira: gols, assistências, cartões, lesões, trocas e notas.
## Calibração contra o motor completo: tests/run_tests.gd → test_quick_calibration.
##
## Resultado (também produzido por MatchSimulation.to_result()):
## {hg, ag, att, goals: [[min, lado, pid, tipo, tempo]], motm, et, pens: [] ou [h, a], derby, importance,
##  yc: [h, a], rc: [h, a], lines: [[linha...], [linha...]]}
## linha = Array com os índices L_* abaixo (arrays em vez de dicionários: ~300 jogos por data).
const L_P := 0
const L_POS := 1
const L_F := 2
const L_DEF := 3
const L_ATT := 4
const L_SHOOT := 5
const L_ASSIST := 6
const L_FOUL := 7
const L_RATING := 8
const L_FIN := 9
const L_ON := 10
const L_START := 11
const L_END := 12
const L_G := 13
const L_A := 14
const L_Y := 15
const L_RED := 16
const L_INJ := 17
const L_PTS := 18
const L_MINS := 19
const L_R := 20
const L_COND := 21
const L_DEFN := 22

## Conversão média de uma chance e ajuste fino (escanteios, faltas e pênaltis do motor completo).
const CONV := 0.118
const CAL := 1.29
## O minuto a minuto dá ao mandante um pouco mais do que as taxas médias sugerem (momento, torcida).
const HOME_BOOST := 1.10
const MINUTES := 93.0
const PENALTY_SHARE := 0.075
const OWN_GOAL_SHARE := 0.035
const ASSIST_SHARE := 0.72

static var _tac_cache: Dictionary = {}


static func _tactics(sheet: TeamSheet) -> Dictionary:
	var key := sheet.mentality * 10000 + sheet.style * 1000 + sheet.intensity * 100 + sheet.line * 10 + sheet.pressing
	if _tac_cache.has(key):
		return _tac_cache[key]
	var t := DatabaseManager.tactics()
	var m: Dictionary = t["mentalities"][clampi(sheet.mentality, 0, 4)]
	var s: Dictionary = t["styles"][clampi(sheet.style, 0, 5)]
	var i: Dictionary = t["intensity"][clampi(sheet.intensity, 0, 2)]
	var l: Dictionary = t["line"][clampi(sheet.line, 0, 2)]
	var p: Dictionary = t["pressing"][clampi(sheet.pressing, 0, 2)]
	var out := {
		"m_att": float(m["att"]), "m_def": float(m["def"]), "m_poss": float(m["poss"]) * MatchSimulation.MOD_DAMP,
		"s_rate": MatchSimulation.damp(float(s["rate"])), "s_quality": MatchSimulation.damp(float(s["quality"])), "s_poss": float(s["poss"]) * MatchSimulation.MOD_DAMP, "s_fatigue": float(s["fatigue"]),
		"ignores_press": bool(s.get("ignores_press", false)),
		"i_perf": float(i["perf"]), "i_fatigue": float(i["fatigue"]), "i_fouls": float(i["fouls"]),
		"l_opp_rate": MatchSimulation.damp(float(l["opp_rate"])), "l_opp_quality": MatchSimulation.damp(float(l["opp_quality"])), "l_poss": float(l["poss"]) * MatchSimulation.MOD_DAMP,
		"pr_poss": float(p["poss"]) * MatchSimulation.MOD_DAMP, "pr_fatigue": float(p["fatigue"]), "pr_opp_rate": MatchSimulation.damp(float(p["opp_rate"])), "pr_fouls": float(p["fouls"]),
	}
	_tac_cache[key] = out
	return out


## Lado da partida: titulares com seus pesos, setores e o banco.
static func _side(world: GameWorld, club: Club, sheet: TeamSheet, home_f: float, big: bool, rng: RandomNumberGenerator) -> Dictionary:
	var tac := _tactics(sheet)
	var slots: Array = DatabaseManager.formation(sheet.formation)["slots"]
	var norms := DatabaseManager.formation_norms()
	var team_f := MatchSimulation.damp(float(tac["i_perf"])) * MatchSimulation.damp((0.96 + clampf(club.cohesion, 0.0, 100.0) / 100.0 * 0.08) * TacticsManager.fam_factor(club, sheet)) * MatchSimulation.damp(home_f)
	# Dia do time (mesmo sorteio do MatchSimulation.DAY_SIGMA).
	team_f *= MatchSimulation.damp(clampf(rng.randfn(1.0, MatchSimulation.DAY_SIGMA), 0.93, 1.07))
	var pl: Array = [] # [Player, slot_pos, f, w_def, w_att, shoot_w, assist_w, foul_w, rating, c_fin]
	var d := 0.0
	var dw := 0.0
	var m := 0.0
	var mw := 0.0
	var a := 0.0
	var aw := 0.0
	var gk := 20.0
	var fin := 0.0
	var fin_n := 0
	var dis := 0.0
	for i in slots.size():
		var pid: int = sheet.starters[i] if i < sheet.starters.size() and sheet.starters[i] != null else -1
		var p: Player = world.players.get(pid, null)
		if p == null:
			continue
		var s: Dictionary = slots[i]
		var pos: int = s["pos"]
		var at := p.attrs
		var c := clampf(p.condition, 0.0, 100.0) / 100.0
		var sigma := 0.015 + (20 - p.consistency) * 0.0025
		var perf := clampf(rng.randfn(1.0, sigma), 0.86, 1.14)
		var ctx := 1.0 + (p.trait_sum("big_game") if big else 0.0)
		var morale_f := 0.96 + p.morale / 100.0 * 0.08
		var form_f := clampf(1.0 + (p.form() - 6.5) * 0.012, 0.97, 1.03)
		var f := Pos.familiarity(p.position, p.secondary, pos) * (0.84 + 0.16 * c * c) * MatchSimulation.damp(morale_f * form_f * perf * ctx) * team_f
		var w_def: float = s["def"]
		var w_mid: float = s["mid"]
		var w_att: float = s["att"]
		var w_wide: float = s["wide"]
		var side: Array = Physique.side_mods(p, pos)
		var heavy := Physique.pace_penalty(p)
		var c_fin: float = at[Attr.FIN] * 0.6 + at[Attr.FRI] * 0.15 + at[Attr.DEC] * 0.1 + at[Attr.TEC] * 0.15 + float(side[1])
		if i == 0:
			gk = (at[Attr.GOL] * 0.4 + at[Attr.REF] * 0.22 + at[Attr.POS] * 0.2 + at[Attr.DEC] * 0.1 + at[Attr.FRI] * 0.08 + Physique.gk_reach(p)) * f
			pl.append([p, pos, f, 1.0, 0.0, 0.0, 0.02, 0.05 * (1.5 - at[Attr.DIS] / 100.0), p.rating_at(pos) * perf, c_fin])
			continue
		d += (at[Attr.MAR] * 0.18 + at[Attr.DES] * 0.14 + at[Attr.POS] * 0.28 + at[Attr.FOR] * 0.1 + at[Attr.CAB] * 0.1 + (at[Attr.VEL] - heavy) * 0.1 + at[Attr.DEC] * 0.1 + Physique.strength(p) * 0.25) * f * w_def
		dw += w_def
		m += (at[Attr.PAS] * 0.3 + at[Attr.VIS] * 0.2 + at[Attr.TEC] * 0.12 + at[Attr.DRI] * 0.08 + at[Attr.DEC] * 0.15 + at[Attr.RES] * 0.15) * f * w_mid
		mw += w_mid
		a += (at[Attr.FIN] * 0.25 + at[Attr.TEC] * 0.1 + at[Attr.DRI] * 0.12 + (at[Attr.VEL] - heavy) * 0.12 + (at[Attr.ACE] - heavy) * 0.08 + at[Attr.DEC] * 0.1 + at[Attr.POS] * 0.13 + at[Attr.FRI] * 0.1) * f * w_att
		aw += w_att
		if w_att >= 0.45:
			fin += c_fin * f
			fin_n += 1
		var c_head: float = at[Attr.CAB] * 0.7 + at[Attr.POS] * 0.2 + at[Attr.FOR] * 0.1 + Physique.aerial(p) * 0.6
		var shoot := (w_att + 0.04) * c_fin * f * (1.6 if pos == Pos.ST else 1.0) + 0.35 * (w_att + (0.35 if pos == Pos.CB else 0.0) + 0.05) * c_head * f
		var assist := (w_mid + w_att * 0.5 + 0.05) * (at[Attr.PAS] + at[Attr.VIS]) * f + (w_wide + 0.05) * (at[Attr.CRU] + float(side[0])) * f * 0.5
		var base_foul := 0.6
		match pos:
			Pos.DM:
				base_foul = 1.5
			Pos.CB:
				base_foul = 1.2
			Pos.CM:
				base_foul = 1.1
			Pos.RB, Pos.LB:
				base_foul = 1.0
			Pos.ST:
				base_foul = 0.8
		var foul := base_foul * p.trait_mult("card_mult") * (1.5 - at[Attr.DIS] / 100.0)
		dis += at[Attr.DIS]
		pl.append([p, pos, f, w_def, w_att, shoot, assist, foul, p.rating_at(pos) * perf, c_fin])
	var n := maxi(1, pl.size() - 1)
	var bench: Array = []
	for pid in sheet.bench:
		var bp: Player = world.players.get(pid, null)
		if bp != null:
			bench.append(bp)
	return {
		"club": club, "sheet": sheet, "tac": tac, "pl": pl, "bench": bench, "gk": gk,
		"def": (d / maxf(0.01, dw)) * sqrt(dw / float(norms["def"])) if dw > 0.0 else 10.0,
		"mid": (m / maxf(0.01, mw)) * sqrt(mw / float(norms["mid"])) if mw > 0.0 else 10.0,
		"att": (a / maxf(0.01, aw)) * sqrt(aw / float(norms["att"])) if aw > 0.0 else 10.0,
		"fin": fin / fin_n if fin_n > 0 else 45.0,
		"discipline": dis / n,
		"count": pl.size(),
	}


## Gols esperados de `att` contra `dfn` (mesmas fórmulas do MatchSimulation).
static func _lambda(att: Dictionary, dfn: Dictionary, poss: float, home: bool, crowd: float) -> float:
	var ta: Dictionary = att["tac"]
	var td: Dictionary = dfn["tac"]
	var diff := float(att["att"]) * MatchSimulation.damp(float(ta["m_att"])) - float(dfn["def"]) * MatchSimulation.damp(float(td["m_def"]))
	var p := MatchSimulation.BASE_CHANCE * MatchSimulation.chance_mult(diff) * float(ta["s_rate"])
	p *= float(td["l_opp_rate"]) * float(td["pr_opp_rate"])
	p *= (1.0 + MatchSimulation.HOME_CHANCE * crowd) if home else (1.0 - MatchSimulation.AWAY_CHANCE * crowd)
	p *= 1.0 + (11 - int(dfn["count"])) * 0.08
	p *= 1.0 - (11 - int(att["count"])) * 0.06
	p = clampf(p, 0.02, 0.6)
	var conv := CONV * clampf(exp(MatchSimulation.DELTA * diff), 0.6, 1.6) * float(ta["s_quality"]) * float(td["l_opp_quality"])
	conv *= exp(MatchSimulation.EPS * (float(att["fin"]) - float(dfn["gk"])))
	return MINUTES * poss * p * conv * CAL


static func play(world: GameWorld, home: Club, away: Club, hs: TeamSheet, as_: TeamSheet, ctx: Dictionary, seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var neutral := bool(ctx.get("neutral", false))
	var att_n := int(ctx.get("attendance", 0))
	var crowd := 0.0 if neutral else 0.6 + 0.4 * clampf(float(att_n) / maxf(1.0, home.capacity), 0.0, 1.0)
	var cul := LeagueCulture.for_match(world, String(ctx.get("competition", "")), home)
	crowd *= float(cul["home"])
	var adv := float(DatabaseManager.tactics().get("home_advantage", 0.05))
	var derby := bool(ctx.get("derby", false))
	var importance := float(ctx.get("importance", 0.3))
	var big := derby or importance >= 0.7
	var sides: Array = [_side(world, home, hs, 1.0 + adv * crowd * 0.5, big, rng), _side(world, away, as_, 1.0, big, rng)]
	var th: Dictionary = sides[0]["tac"]
	var ta: Dictionary = sides[1]["tac"]
	var tilt_h := float(th["m_poss"]) + float(th["s_poss"]) + float(th["l_poss"]) + (0.0 if bool(ta["ignores_press"]) else float(th["pr_poss"]))
	var tilt_a := float(ta["m_poss"]) + float(ta["s_poss"]) + float(ta["l_poss"]) + (0.0 if bool(th["ignores_press"]) else float(ta["pr_poss"]))
	var x := MatchSimulation.GAMMA * (float(sides[0]["mid"]) - float(sides[1]["mid"]))
	var poss := clampf(1.0 / (1.0 + exp(-x)) + (tilt_h - tilt_a) * 0.8 + 0.02 * crowd, 0.25, 0.75)
	var lam: Array = [_lambda(sides[0], sides[1], poss, true, crowd) * (1.0 + (HOME_BOOST - 1.0) * crowd / 0.9) * float(cul["goals"]), _lambda(sides[1], sides[0], 1.0 - poss, false, crowd) * float(cul["goals"])]
	# Estado por jogador: [Player, pos, f, w_def, w_att, shoot, assist, foul, rating, c_fin, on(0/1), start_min, end_min, g, a, y, red, inj, pts]
	var lines: Array = [[], []]
	for s in 2:
		for e in sides[s]["pl"]:
			lines[s].append(e + [1, 0, -1, 0, 0, 0, false, 0, 0.0])
	var timeline: Array = []
	for s in 2:
		for _g in _poisson(rng, lam[s]):
			timeline.append([_goal_minute(rng), 0, s])
		var tac: Dictionary = sides[s]["tac"]
		var fouls_f := (1.3 - float(sides[s]["discipline"]) / 100.0 * 0.6) * float(tac["i_fouls"]) * float(tac["pr_fouls"]) * (1.12 if derby else 1.0) * float(cul["cards"])
		for _y in _poisson(rng, 1.75 * fouls_f):
			timeline.append([rng.randi_range(3, 92), 1, s])
		if rng.randf() < 0.035 * fouls_f:
			timeline.append([rng.randi_range(10, 90), 2, s])
		if rng.randf() < 1.0 - exp(-MatchSimulation.INJURY_RATE * 95.0 * float(tac["i_fatigue"])):
			timeline.append([rng.randi_range(5, 90), 3, s])
		var n_subs := rng.randi_range(3, mini(5, sides[s]["bench"].size()))
		for _k in n_subs:
			timeline.append([rng.randi_range(55, 86), 4, s])
	timeline.sort_custom(func(p, q): return p[0] < q[0] or (p[0] == q[0] and p[1] > q[1]))
	var score: Array = [0, 0]
	var goals: Array = []
	var yc: Array = [0, 0]
	var rc: Array = [0, 0]
	var used_bench: Array = [{}, {}]
	var subs_used: Array = [0, 0]
	for ev in timeline:
		var mnt: int = ev[0]
		var s: int = ev[2]
		match int(ev[1]):
			0:
				_goal(rng, sides, lines, s, mnt, score, goals)
			1:
				var v: Variant = _pick(rng, lines[s], 7)
				if v != null:
					v[15] += 1
					v[18] -= 0.35
					if v[15] >= 2:
						_send_off(v, mnt)
						rc[s] += 1
					else:
						yc[s] += 1
			2:
				var v: Variant = _pick(rng, lines[s], 7)
				if v != null:
					_send_off(v, mnt)
					rc[s] += 1
			3:
				var v: Variant = _pick_injured(rng, lines[s])
				if v != null:
					v[17] = InjuryTable.roll_weeks(rng)
					if subs_used[s] < 5:
						if _substitute(sides[s], lines[s], used_bench[s], v, mnt):
							subs_used[s] += 1
					else:
						v[10] = 0
						v[12] = mnt
			4:
				if subs_used[s] < 5:
					var out: Variant = _tired_starter(lines[s])
					if out != null and _substitute(sides[s], lines[s], used_bench[s], out, mnt):
						subs_used[s] += 1
	var end_min := 90 + rng.randi_range(2, 6)
	var et := false
	var pens: Array = []
	if bool(ctx.get("ko", false)):
		var agg: Array = ctx.get("agg", [0, 0])
		if score[0] + int(agg[0]) == score[1] + int(agg[1]):
			et = true
			var extra: Array = []
			for s in 2:
				for _g in _poisson(rng, lam[s] * 0.3):
					extra.append([rng.randi_range(91, 120), s])
			extra.sort_custom(func(p, q): return p[0] < q[0])
			for g in extra:
				_goal(rng, sides, lines, g[1], g[0], score, goals)
			end_min = 120 + rng.randi_range(0, 2)
			if score[0] + int(agg[0]) == score[1] + int(agg[1]):
				pens = _shootout(rng, sides, lines)
	# Notas, condição e craque do jogo
	var motm_pid := -1
	var motm_v := -1.0
	var out_lines: Array = [[], []]
	for s in 2:
		var diff: int = score[s] - score[1 - s]
		var team_bonus := 0.3 if diff > 0 else (-0.25 if diff < 0 else 0.0)
		var conceded: int = score[1 - s]
		var clean := conceded == 0
		var avg := 0.0
		var cnt := 0
		for v in lines[s]:
			if v[10] == 1 or v[12] >= 0:
				avg += v[8]
				cnt += 1
		avg = avg / maxf(1.0, cnt)
		var tac: Dictionary = sides[s]["tac"]
		var fat := MatchSimulation.FATIGUE_RATE * 18.0 * float(tac["i_fatigue"]) * float(tac["s_fatigue"]) * float(tac["pr_fatigue"])
		var saves := maxf(0.0, lam[1 - s] * 2.2 - conceded)
		for v in lines[s]:
			var p: Player = v[0]
			var start_m: int = v[11]
			var stop_m: int = v[12] if v[12] >= 0 else end_min
			var mins := clampi(stop_m - start_m, 0, 130)
			var pts: float = v[18]
			var gk: bool = int(v[1]) == Pos.GK
			var defn: bool = gk or float(v[3]) >= 0.8
			if gk:
				pts += saves * 0.18 - conceded * 0.35
			elif float(v[3]) >= 0.8:
				pts -= conceded * 0.15
			if clean and mins >= 60:
				pts += 0.8 if gk else (0.45 if float(v[3]) >= 0.8 else 0.0)
			var perf_c := clampf((float(v[8]) / maxf(1.0, avg) - 1.0) * 4.0, -0.5, 0.5)
			var r := 6.0 + pts + team_bonus + perf_c + rng.randfn(0.0, 0.3)
			if mins < 20:
				r = 6.0 + clampf(pts, -1.0, 1.5) + team_bonus * 0.5
			r = clampf(snappedf(r, 0.1), 3.0, 10.0)
			var cond := maxf(5.0, p.condition - fat * (1.25 - p.attrs[Attr.RES] / 100.0 * 0.6) * (0.35 if gk else 1.0) * mins / 90.0)
			v.append(mins)
			v.append(r)
			v.append(cond)
			v.append(defn)
			out_lines[s].append(v)
			var mv := r + (0.05 if diff > 0 else 0.0)
			if mv > motm_v:
				motm_v = mv
				motm_pid = p.id
	return {"hg": score[0], "ag": score[1], "att": att_n, "goals": goals, "motm": motm_pid, "et": et, "pens": pens,
		"derby": derby, "importance": importance, "yc": yc, "rc": rc, "lines": out_lines, "poss": poss}


static func _poisson(rng: RandomNumberGenerator, lam: float) -> int:
	var l := exp(-lam)
	var k := 0
	var p := 1.0
	while true:
		p *= rng.randf()
		if p <= l or k > 12:
			break
		k += 1
	return k


## Minuto de um gol: um pouco mais frequentes no fim de cada tempo (cansaço, pressão).
static func _goal_minute(rng: RandomNumberGenerator) -> int:
	var m := int(floor(pow(rng.randf(), 0.92) * 90.0)) + 1
	if m == 90 and rng.randf() < 0.6:
		m = 90 + rng.randi_range(1, 5)
	return m


## Sorteia um jogador em campo ponderando a coluna `col` (5 chute, 6 passe, 7 falta).
static func _pick(rng: RandomNumberGenerator, lines: Array, col: int, exclude: Variant = null) -> Variant:
	var total := 0.0
	for v in lines:
		if v[10] == 1 and v != exclude:
			total += float(v[col])
	if total <= 0.0:
		return null
	var r := rng.randf() * total
	for v in lines:
		if v[10] != 1 or v == exclude:
			continue
		r -= float(v[col])
		if r <= 0.0:
			return v
	for v in lines:
		if v[10] == 1 and v != exclude:
			return v
	return null


static func _goal(rng: RandomNumberGenerator, sides: Array, lines: Array, s: int, mnt: int, score: Array, goals: Array) -> void:
	var half := 1 if mnt <= 45 else (2 if mnt <= 95 else (3 if mnt <= 105 else 4))
	var r := rng.randf()
	if r < OWN_GOAL_SHARE:
		var og: Variant = _pick(rng, lines[1 - s], 7)
		if og != null:
			og[18] -= 1.0
			score[s] += 1
			goals.append([mnt, s, og[0].id, Fixture.GOAL_OWN, half])
			return
	if r < OWN_GOAL_SHARE + PENALTY_SHARE:
		var sheet: TeamSheet = sides[s]["sheet"]
		var taker: Variant = null
		for v in lines[s]:
			if v[10] == 1 and v[0].id == sheet.penalty_taker:
				taker = v
		if taker == null:
			taker = _pick(rng, lines[s], 5)
		if taker != null:
			taker[13] += 1
			taker[18] += 0.85
			score[s] += 1
			goals.append([mnt, s, taker[0].id, Fixture.GOAL_PENALTY, half])
			return
	var shooter: Variant = _pick(rng, lines[s], 5)
	if shooter == null:
		return
	shooter[13] += 1
	shooter[18] += 1.1
	if rng.randf() < ASSIST_SHARE:
		var assister: Variant = _pick(rng, lines[s], 6, shooter)
		if assister != null:
			assister[14] += 1
			assister[18] += 0.65
	score[s] += 1
	goals.append([mnt, s, shooter[0].id, Fixture.GOAL_NORMAL, half])


static func _send_off(v: Array, mnt: int) -> void:
	v[16] = true
	v[10] = 0
	v[12] = mnt
	v[18] -= 1.5


static func _pick_injured(rng: RandomNumberGenerator, lines: Array) -> Variant:
	var total := 0.0
	for v in lines:
		if v[10] == 1:
			var p: Player = v[0]
			total += (1.0 + p.injury_prone / 10.0) * p.trait_mult("injury_mult") * (0.3 if int(v[1]) == Pos.GK else 1.0)
	if total <= 0.0:
		return null
	var r := rng.randf() * total
	for v in lines:
		if v[10] != 1:
			continue
		var p: Player = v[0]
		r -= (1.0 + p.injury_prone / 10.0) * p.trait_mult("injury_mult") * (0.3 if int(v[1]) == Pos.GK else 1.0)
		if r <= 0.0:
			return v
	return null


## Titular de linha mais desgastado (menor fôlego) ainda em campo desde o início.
static func _tired_starter(lines: Array) -> Variant:
	var best: Variant = null
	var best_v := 1e9
	for v in lines:
		if v[10] != 1 or v[11] != 0 or int(v[1]) == Pos.GK:
			continue
		var p: Player = v[0]
		var val := p.condition * 0.6 + p.attrs[Attr.RES] * 0.4 + float(v[8]) * 0.2
		if val < best_v:
			best_v = val
			best = v
	return best


## Troca `out` pelo melhor reserva do mesmo setor. Retorna se a troca aconteceu.
static func _substitute(side: Dictionary, lines: Array, used: Dictionary, out: Array, mnt: int) -> bool:
	var pos: int = out[1]
	var gk := pos == Pos.GK
	var best: Player = null
	var best_v := -1.0
	for bp: Player in side["bench"]:
		if used.has(bp.id) or not bp.is_available() or (bp.position == Pos.GK) != gk:
			continue
		var v := bp.rating_at(pos) * (0.72 + 0.28 * bp.condition / 100.0)
		if v > best_v:
			best_v = v
			best = bp
	if best == null:
		return false
	used[best.id] = true
	out[10] = 0
	out[12] = mnt
	# Pesos do reserva na mesma função: escala os do titular pela diferença de atributos e de encaixe.
	var op: Player = out[0]
	var c := clampf(best.condition, 0.0, 100.0) / 100.0
	var f_ratio := (Pos.familiarity(best.position, best.secondary, pos) * (0.72 + 0.28 * c * c)) / maxf(0.2, Pos.familiarity(op.position, op.secondary, pos) * 0.95)
	var f: float = float(out[2]) * clampf(f_ratio, 0.5, 1.3)
	var ba := best.attrs
	var oa := op.attrs
	var c_fin: float = ba[Attr.FIN] * 0.6 + ba[Attr.FRI] * 0.15 + ba[Attr.DEC] * 0.1 + ba[Attr.TEC] * 0.15
	var shoot := float(out[5]) * (c_fin / maxf(1.0, float(out[9]))) * (f / maxf(0.01, float(out[2])))
	var assist := float(out[6]) * float(ba[Attr.PAS] + ba[Attr.VIS]) / maxf(1.0, float(oa[Attr.PAS] + oa[Attr.VIS])) * (f / maxf(0.01, float(out[2])))
	var foul := float(out[7]) * (1.5 - ba[Attr.DIS] / 100.0) / maxf(0.1, 1.5 - oa[Attr.DIS] / 100.0)
	lines.append([best, pos, f, out[3], out[4], shoot, assist, foul, best.rating_at(pos), c_fin, 1, mnt, -1, 0, 0, 0, false, 0, 0.0])
	return true


## Disputa de pênaltis: cinco cobranças alternadas e morte súbita. Retorna [gols mandante, gols visitante].
static func _shootout(rng: RandomNumberGenerator, sides: Array, lines: Array) -> Array:
	var kickers: Array = [[], []]
	for s in 2:
		for v in lines[s]:
			if v[10] == 1:
				kickers[s].append(v)
		kickers[s].sort_custom(func(p, q): return float(p[9]) > float(q[9]))
	var ps: Array = [0, 0]
	var taken: Array = [0, 0]
	var guard := 0
	while guard < 40:
		guard += 1
		var s := 0 if taken[0] == taken[1] else 1
		var ks: Array = kickers[s]
		if ks.is_empty():
			break
		var k: Array = ks[taken[s] % ks.size()]
		var p := clampf(0.76 + (float(k[9]) * float(k[2]) - float(sides[1 - s]["gk"])) * 0.004, 0.55, 0.9)
		if taken[s] >= 5:
			p -= 0.03
		taken[s] += 1
		if rng.randf() < p:
			ps[s] += 1
		var a: int = taken[0]
		var b: int = taken[1]
		if a <= 5 and b <= 5:
			if ps[0] > ps[1] + (5 - b) or ps[1] > ps[0] + (5 - a):
				break
		elif a == b and ps[0] != ps[1]:
			break
	return ps
