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
const CAL := 1.12
## O minuto a minuto dá ao mandante um pouco mais do que as taxas médias sugerem (momento, torcida).
const HOME_BOOST := 1.0
const MINUTES := 93.0
const PENALTY_SHARE := 0.075
const OWN_GOAL_SHARE := 0.035
const ASSIST_SHARE := 0.72

## Modos de escolha de quem finaliza / dá o passe (iguais às tabelas do MatchTeam).
const M_SHOOT := 0
const M_HEAD := 1
const M_LONG := 2
const M_DRIBBLE := 3
const M_COUNTER := 4
const M_PASS := 5
const M_CROSS := 6
## O modo rápido gera as mesmas finalizações por jogo que o minuto a minuto (lá escanteios e faltas
## também viram chute): mais lances, cada um um pouco pior; o gol esperado não muda.
const SHOT_F := 1.22
const PEN_P := 0.0125 # pênalti por lance de perigo
## O minuto a minuto amortece a diferença de nível (o técnico do favorito administra, o do azarão
## mexe no time e se fecha); o modo rápido, sem essas decisões, amortece a diferença aqui.
const GAP_F := 0.8

static var _tac_cache: Dictionary = {}


## Pesos de um jogador numa vaga para cada modo (mesmas fórmulas de MatchTeam._rebuild_pick_tables).
static func mode_weights(p: Player, pos: int, w_att: float, w_mid: float, w_wide: float, f: float, ins_shoot: float) -> PackedFloat32Array:
	var at := p.attrs
	var side: Array = Physique.side_mods(p, pos)
	var heavy := Physique.pace_penalty(p)
	var vel: float = at[Attr.VEL] - heavy
	var c_fin: float = at[Attr.FIN] * 0.6 + at[Attr.FRI] * 0.15 + at[Attr.DEC] * 0.1 + at[Attr.TEC] * 0.15 + float(side[1])
	var c_head: float = at[Attr.CAB] * 0.7 + at[Attr.POS] * 0.2 + at[Attr.FOR] * 0.1 + Physique.aerial(p) * 0.6
	var c_long: float = at[Attr.CHL] * 0.6 + at[Attr.FIN] * 0.15 + at[Attr.TEC] * 0.25 + float(side[2])
	var tec_vel: float = at[Attr.TEC] * 0.4 + at[Attr.DRI] * 0.6 + vel * 0.5 + (at[Attr.ACE] - heavy) * 0.5 + float(side[3])
	var out := PackedFloat32Array()
	out.resize(7)
	out[M_SHOOT] = (w_att + 0.04) * c_fin * f * (MatchSimulation.ST_SHOOT if pos == Pos.ST else 1.0) * ins_shoot
	out[M_HEAD] = (w_att + (MatchSimulation.CB_HEAD if pos == Pos.CB else 0.0) + 0.05) * c_head * f
	out[M_LONG] = (w_mid + w_att * 0.6 + 0.05) * c_long * f * ins_shoot
	out[M_DRIBBLE] = (w_att + w_wide * 0.3 + 0.05) * tec_vel * f
	out[M_COUNTER] = (w_att + 0.05) * (vel + at[Attr.FIN]) * f
	out[M_PASS] = (w_mid + w_att * 0.5 + 0.05) * (at[Attr.PAS] + at[Attr.VIS]) * f
	out[M_CROSS] = (w_wide + 0.05) * (at[Attr.CRU] + float(side[0])) * f
	return out


static func _tactics(sheet: TeamSheet) -> Dictionary:
	var dv := sheet.deep_values()
	var key := sheet.mentality * 10000 + sheet.style * 1000 + sheet.intensity * 100 + sheet.line * 10 + sheet.pressing
	for v in dv:
		key = key * 5 + int(v)
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
	# Instruções de equipe (as partes que dependem do elenco e do placar ficam só no minuto a minuto).
	var dm := TacticsManager.deep_mods(dv)
	for f in ["rate", "quality", "opp_rate", "opp_quality", "poss", "fatigue", "fouls"]:
		out["x_" + f] = dm[f]
	out["x_types"] = dm["types"]
	out["x_opp_types"] = dm["opp_types"]
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
	team_f *= TeamEvolution.factor(world, club)
	var pl: Array = [] # [Player, slot_pos, f, w_def, w_att, shoot_w, assist_w, foul_w, rating, c_fin]
	var pw := {} # player_id -> pesos por modo de escolha (os mesmos do MatchTeam: chute, cabeça, de fora...)
	var slot_w := {} # player_id -> [w_mid, w_wide, chute da instrução] da vaga (o reserva herda)
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
	var ptech := 0.0
	var pace := [0.0, 0.0, 0.0, 0.0] # velocidade de quem ataca / de quem defende (soma, quantidade)
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
		w_wide *= [0.7, 1.0, 1.3][clampi(sheet.width, 0, 2)]
		var ins := sheet.instruction_of(p.id)
		if not ins.is_empty() and i > 0:
			w_wide += float(ins.get("wide", 0.0))
			w_def = maxf(0.0, w_def + float(ins["def"]))
			w_mid = maxf(0.0, w_mid + float(ins["mid"]))
			w_att = maxf(0.0, w_att + float(ins["att"]))
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
			pace[0] += at[Attr.VEL] - heavy
			pace[1] += 1.0
		if w_def >= 0.5:
			pace[2] += at[Attr.VEL] - heavy
			pace[3] += 1.0
		var ins_shoot := float(ins["shoot"]) if not ins.is_empty() else 1.0
		var mw_: PackedFloat32Array = mode_weights(p, pos, w_att, w_mid, w_wide, f, ins_shoot)
		pw[p.id] = mw_
		slot_w[p.id] = [w_mid, w_wide, ins_shoot]
		var shoot := float(mw_[M_SHOOT])
		var assist := float(mw_[M_PASS])
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
		var foul := base_foul * p.trait_mult("card_mult") * (1.5 - at[Attr.DIS] / 100.0) * (float(ins["foul"]) if not ins.is_empty() else 1.0)
		dis += at[Attr.DIS]
		ptech += at[Attr.TEC] * 0.45 + (at[Attr.PAS] + at[Attr.VIS]) * 0.175 + at[Attr.DEC] * 0.2
		pl.append([p, pos, f, w_def, w_att, shoot, assist, foul, p.rating_at(pos) * perf, c_fin])
	var n := maxi(1, pl.size() - 1)
	var bench: Array = []
	for pid in sheet.bench:
		var bp: Player = world.players.get(pid, null)
		if bp != null:
			bench.append(bp)
	return {
		"club": club, "sheet": sheet, "tac": tac, "pl": pl, "bench": bench, "gk": gk, "pw": pw, "slot_w": slot_w,
		"def": (d / maxf(0.01, dw)) * sqrt(dw / float(norms["def"])) if dw > 0.0 else 10.0,
		"mid": (m / maxf(0.01, mw)) * sqrt(mw / float(norms["mid"])) if mw > 0.0 else 10.0,
		"att": (a / maxf(0.01, aw)) * sqrt(aw / float(norms["att"])) if aw > 0.0 else 10.0,
		"fin": fin / fin_n if fin_n > 0 else 45.0,
		"discipline": dis / n,
		"count": pl.size(),
		"mu": {"tech": ptech / n, "mid": mw, "pressing": sheet.pressing, "style": sheet.style, "mentality": sheet.mentality, "line": sheet.line, "width": sheet.width},
		"cd": {"passing": sheet.passing, "pressing": sheet.pressing, "line": sheet.line, "marking": sheet.marking, "transition": sheet.transition,
			"tech": ptech / n, "pace_att": pace[0] / pace[1] if pace[1] > 0.0 else 60.0, "pace_def": pace[2] / pace[3] if pace[3] > 0.0 else 60.0},
	}


## Gols esperados de `att` contra `dfn` (mesmas fórmulas do MatchSimulation).
static func _lambda(att: Dictionary, dfn: Dictionary, poss: float, home: bool, crowd: float) -> float:
	var ta: Dictionary = att["tac"]
	var td: Dictionary = dfn["tac"]
	var diff := (float(att["att"]) * MatchSimulation.damp(float(ta["m_att"])) - float(dfn["def"]) * MatchSimulation.damp(float(td["m_def"]))) * GAP_F
	var p := MatchSimulation.BASE_CHANCE * MatchSimulation.chance_mult(diff) * float(ta["s_rate"])
	p *= float(td["l_opp_rate"]) * float(td["pr_opp_rate"]) * float(ta["x_rate"]) * float(td["x_opp_rate"]) * TacticsManager.clash(att["cd"], dfn["cd"])
	p *= (1.0 + MatchSimulation.HOME_CHANCE * crowd) if home else (1.0 - MatchSimulation.AWAY_CHANCE * crowd)
	p *= 1.0 + (11 - int(dfn["count"])) * 0.08
	p *= 1.0 - (11 - int(att["count"])) * 0.06
	p = clampf(p, 0.02, 0.6)
	var conv := CONV * clampf(exp(MatchSimulation.DELTA * diff), 0.6, 1.6) * float(ta["s_quality"]) * float(td["l_opp_quality"]) * float(ta["x_quality"]) * float(td["x_opp_quality"])
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
	var ref: Array = Array(ctx.get("ref", []))
	var rf := Referees.factors(world, ref)
	for sd: Dictionary in sides:
		sd["ref_pens"] = float(rf["pens"])
	var th: Dictionary = sides[0]["tac"]
	var ta: Dictionary = sides[1]["tac"]
	var tilt_h := float(th["m_poss"]) + float(th["s_poss"]) + float(th["l_poss"]) + (0.0 if bool(ta["ignores_press"]) else float(th["pr_poss"])) + float(th["x_poss"])
	var tilt_a := float(ta["m_poss"]) + float(ta["s_poss"]) + float(ta["l_poss"]) + (0.0 if bool(th["ignores_press"]) else float(ta["pr_poss"])) + float(ta["x_poss"])
	var x := MatchSimulation.GAMMA * (float(sides[0]["mid"]) - float(sides[1]["mid"]))
	# Confronto de ideias e estudo do rival (os mesmos do minuto a minuto).
	var mu := TacticalMatchup.edges(sides[0]["mu"], sides[1]["mu"])
	var poss := clampf(1.0 / (1.0 + exp(-x)) + (tilt_h - tilt_a) * 0.8 + 0.02 * crowd + float(mu["poss"]), 0.25, 0.75)
	var wx: Dictionary = ctx.get("wx", {})
	var wfx: Dictionary = wx.get("fx", {}) if not wx.is_empty() else {}
	var lam: Array = [_lambda(sides[0], sides[1], poss, true, crowd) * (1.0 + (HOME_BOOST - 1.0) * crowd / 0.9) * float(cul["goals"]), _lambda(sides[1], sides[0], 1.0 - poss, false, crowd) * float(cul["goals"])]
	# Chances por minuto de cada time (posse × taxa de chance do motor completo) e a conversão média
	# da chance; o produto é o mesmo gol esperado de antes, mas agora cada lance acontece de verdade.
	var rate: Array = [poss * _chance_rate(sides[0], sides[1], true, crowd) * SHOT_F, (1.0 - poss) * _chance_rate(sides[1], sides[0], false, crowd) * SHOT_F]
	# Altitude: o visitante sem costume cansa e o mandante cresce no segundo tempo
	var alt := float(wx.get("away_fatigue", 1.0))
	if alt > 1.0:
		rate[0] *= 1.0 + (alt - 1.0) * 0.5
		rate[1] *= 1.0 - (alt - 1.0) * 0.4
	var conv: Array = [0.0, 0.0]
	var cw: Array = [[], []] # peso de cada tipo de chance
	var cq: Array = [[], []] # qualidade (xG) de cada tipo
	for s in 2:
		var club_s: Club = sides[s]["club"]
		var types := TacticalScout.style_types(int(sides[s]["mu"]["style"]))
		var ex := TacticalScout.exploit(types, TacticalScout.vulnerability(world, sides[1 - s]["club"]), TacticalScout.study(world, club_s))
		lam[s] *= float(ex[2]) * float(mu["rate_a" if s == 0 else "rate_b"]) * float(wfx.get("goals", 1.0))
		for i in 6:
			var w := MatchSimulation.BASE_TYPE_W[i] * types[i] * float(ex[0][i]) * float(sides[s]["tac"]["x_types"][i]) * float(sides[1 - s]["tac"]["x_opp_types"][i])
			if i == MatchSimulation.CH_LONG:
				w *= float(wfx.get("long", 1.0))
			elif i == MatchSimulation.CH_CROSS:
				w *= float(wfx.get("cross", 1.0))
			cw[s].append(w)
			cq[s].append(MatchSimulation.BASE_XG[i] * float(ex[1][i]))
		cw[s].append(0.2) # escanteio que vira chance
		cq[s].append(MatchSimulation.BASE_XG[MatchSimulation.CH_CORNER])
		cw[s].append(0.07) # falta perigosa
		cq[s].append(MatchSimulation.BASE_XG[MatchSimulation.CH_FREEKICK])
		var sw := 0.0
		var sq := 0.0
		for i in cw[s].size():
			sw += float(cw[s][i])
			sq += float(cw[s][i]) * float(cq[s][i])
		# Normaliza a qualidade: a média ponderada vale 1 e a conversão carrega o nível do confronto
		for i in cq[s].size():
			cq[s][i] = float(cq[s][i]) / maxf(0.001, sq / sw)
		conv[s] = lam[s] / maxf(0.001, float(rate[s]) * MINUTES) * 0.97
	# Estado por jogador: [Player, pos, f, w_def, w_att, shoot, assist, foul, rating, c_fin, on(0/1), start_min, end_min, g, a, y, red, inj, pts]
	var lines: Array = [[], []]
	for s in 2:
		for e in sides[s]["pl"]:
			lines[s].append(e + [1, 0, -1, 0, 0, 0, false, 0, 0.0])
	# Lesões e trocas têm hora marcada pelo cansaço; cartões e gols nascem do jogo, minuto a minuto
	var timeline: Array = []
	var card_rate: Array = [0.0, 0.0]
	for s in 2:
		var tac: Dictionary = sides[s]["tac"]
		var fouls_f := (1.3 - float(sides[s]["discipline"]) / 100.0 * 0.6) * float(tac["i_fouls"]) * float(tac["pr_fouls"]) * float(tac["x_fouls"]) * (1.12 if derby else 1.0) * float(cul["cards"]) * float(rf["cards"]) * float(wfx.get("fouls", 1.0))
		card_rate[s] = 1.75 * fouls_f / MINUTES
		if rng.randf() < 1.0 - exp(-MatchSimulation.INJURY_RATE * 95.0 * float(tac["i_fatigue"]) * float(wfx.get("injury", 1.0))):
			timeline.append([rng.randi_range(5, 90), 3, s])
		var n_subs := rng.randi_range(3, mini(5, sides[s]["bench"].size()))
		for _k in n_subs:
			timeline.append([rng.randi_range(55, 86), 4, s])
	timeline.sort_custom(func(p, q): return p[0] < q[0] or (p[0] == q[0] and p[1] > q[1]))
	var st := {"rng": rng, "sides": sides, "lines": lines, "rate": rate, "conv": conv, "cw": cw, "cq": cq, "card": card_rate,
		"score": [0, 0], "goals": [], "yc": [0, 0], "rc": [0, 0], "used": [{}, {}], "subs": [0, 0], "tl": timeline, "ti": 0,
		"xg": [0.0, 0.0], "shots": [0, 0], "cts": [], "pen": PEN_P, "react": [0, 0]}
	var end_min := 90 + rng.randi_range(2, 6)
	_period(st, 1, 45 + rng.randi_range(0, 3), 1)
	_period(st, 46, end_min, 2)
	var score: Array = st["score"]
	var goals: Array = st["goals"]
	var yc: Array = st["yc"]
	var rc: Array = st["rc"]
	var et := false
	var pens: Array = []
	if bool(ctx.get("ko", false)):
		var agg: Array = ctx.get("agg", [0, 0])
		if score[0] + int(agg[0]) == score[1] + int(agg[1]):
			et = true
			_period(st, 91, 105, 3)
			_period(st, 106, 120, 4)
			end_min = 120 + rng.randi_range(0, 2)
			if score[0] + int(agg[0]) == score[1] + int(agg[1]):
				pens = _shootout(rng, sides, lines)
	# Notas, condição e craque do jogo
	var motm_pid := -1
	var motm_v := -1.0
	var out_lines: Array = [[], []]
	for s in 2:
		var diff: int = score[s] - score[1 - s]
		var team_bonus := MatchSimulation.RATING_WIN if diff > 0 else (MatchSimulation.RATING_LOSS if diff < 0 else 0.0)
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
		var fat := MatchSimulation.FATIGUE_RATE * 18.0 * float(tac["i_fatigue"]) * float(tac["s_fatigue"]) * float(tac["pr_fatigue"]) * float(tac["x_fatigue"])
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
			var r := MatchSimulation.rating_from(pts, team_bonus, perf_c, rng.randfn(0.0, 0.3), mins)
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
	# Tipo de jogada de cada gol (diário tático): o lance que de fato aconteceu.
	var cts: Array = st["cts"]
	return {"hg": score[0], "sh": st["shots"], "ag": score[1], "att": att_n, "goals": goals, "motm": motm_pid, "et": et, "pens": pens,
		"derby": derby, "importance": importance, "yc": yc, "rc": rc, "lines": out_lines, "poss": poss, "ref": ref,
		"tac": {"ct": cts, "xg": [snappedf(float(st["xg"][0]), 0.01), snappedf(float(st["xg"][1]), 0.01)]}, "wx": wx}


## Taxa de chance por minuto de posse (a mesma fórmula do MatchSimulation, sem a conversão).
static func _chance_rate(att: Dictionary, dfn: Dictionary, home: bool, crowd: float) -> float:
	var ta: Dictionary = att["tac"]
	var td: Dictionary = dfn["tac"]
	var diff := (float(att["att"]) * MatchSimulation.damp(float(ta["m_att"])) - float(dfn["def"]) * MatchSimulation.damp(float(td["m_def"]))) * GAP_F
	var p := MatchSimulation.BASE_CHANCE * MatchSimulation.chance_mult(diff) * float(ta["s_rate"])
	p *= float(td["l_opp_rate"]) * float(td["pr_opp_rate"]) * float(ta["x_rate"]) * float(td["x_opp_rate"]) * TacticsManager.clash(att["cd"], dfn["cd"])
	p *= (1.0 + MatchSimulation.HOME_CHANCE * crowd) if home else (1.0 - MatchSimulation.AWAY_CHANCE * crowd)
	return clampf(p, 0.02, 0.6)


static func _on_count(lines: Array) -> int:
	var n := 0
	for v in lines:
		if v[10] == 1:
			n += 1
	return n


## Joga um trecho da partida minuto a minuto: a cada minuto cada time pode criar uma chance
## (pela força de ataque contra a defesa, posse, mando, cansaço, placar e expulsões); a chance tem
## um tipo (enfiada, cruzamento, chute de fora, contra-ataque...), um finalizador escolhido pelos
## atributos e uma qualidade; vira gol ou não pelo que o finalizador faz contra o goleiro. Cartões
## saem das faltas do minuto (mais quando o time perde, no clássico e com juiz rigoroso).
static func _period(st: Dictionary, m0: int, m1: int, half: int) -> void:
	var rng: RandomNumberGenerator = st["rng"]
	var sides: Array = st["sides"]
	var lines: Array = st["lines"]
	var score: Array = st["score"]
	var tl: Array = st["tl"]
	for m in range(m0, m1 + 1):
		while int(st["ti"]) < tl.size() and int(tl[int(st["ti"])][0]) <= m:
			_timeline_event(st, tl[int(st["ti"])])
			st["ti"] = int(st["ti"]) + 1
		var t_f := clampf(float(m) / 90.0, 0.0, 1.3)
		var time_f := 1.05 if half >= 3 else 0.86 + 0.28 * minf(t_f, 1.0)
		for s in 2:
			var diff: int = score[s] - score[1 - s]
			var sm := MatchSimulation.state_mods(diff, m, half)
			var rate_m: float = sm[0]
			var qual_m: float = sm[1]
			# Reação: quem acabou de sofrer o gol se lança nos minutos seguintes
			if m < int(st["react"][s]):
				rate_m *= 1.18
			var n_att := _on_count(lines[s])
			var n_def := _on_count(lines[1 - s])
			var p: float = float(st["rate"][s]) * time_f * rate_m * (1.0 + (11 - n_def) * 0.08) * (1.0 - (11 - n_att) * 0.06)
			if rng.randf() < p:
				_chance(st, s, m, half, qual_m)
			# Cartões: faltas do minuto (quem perde se desespera no fim)
			var cr: float = float(st["card"][s]) * (1.25 if diff < 0 and m >= 70 else 1.0)
			if rng.randf() < cr:
				_card(st, s, m)
			elif rng.randf() < cr * 0.015:
				var v: Variant = _pick(rng, lines[s], 7)
				if v != null:
					_send_off(v, m)
					st["rc"][s] += 1


static func _chance(st: Dictionary, s: int, m: int, half: int, qual_m: float) -> void:
	var rng: RandomNumberGenerator = st["rng"]
	var sides: Array = st["sides"]
	var lines: Array = st["lines"]
	var score: Array = st["score"]
	st["shots"][s] += 1
	# Pênalti: falta na área (juiz mais ou menos rigoroso)
	if rng.randf() < float(st["pen"]) * float(sides[s].get("ref_pens", 1.0)):
		var sheet: TeamSheet = sides[s]["sheet"]
		var taker: Variant = null
		for v in lines[s]:
			if v[10] == 1 and v[0].id == sheet.penalty_taker:
				taker = v
		if taker == null:
			taker = _pick(rng, lines[s], 5)
		if taker == null:
			return
		st["xg"][s] += 0.76
		var gk_p: Player = null
		for v in lines[1 - s]:
			if v[10] == 1 and int(v[1]) == Pos.GK:
				gk_p = v[0]
		var pk := PenaltyKick.kick(rng, taker[0], gk_p, {"f": float(taker[2]), "cond": 90.0 - m * 0.3, "pressure": 0.3 + (0.3 if m >= 80 and score[s] <= score[1 - s] else 0.0), "away": s == 1})
		if String(pk["res"]) == "goal":
			taker[13] += 1
			taker[18] += 0.85
			score[s] += 1
			st["react"][1 - s] = m + 10
			st["goals"].append([m, s, taker[0].id, Fixture.GOAL_PENALTY, half])
			st["cts"].append([s, MatchSimulation.CH_PENALTY, m, half])
		else:
			taker[18] -= 0.5
		return
	var k := RngUtil.weighted_index(rng, st["cw"][s])
	var ctype := k if k < 6 else (MatchSimulation.CH_CORNER if k == 6 else MatchSimulation.CH_FREEKICK)
	var pw: Dictionary = sides[s]["pw"]
	var shooter: Variant = null
	match ctype:
		MatchSimulation.CH_CROSS, MatchSimulation.CH_CORNER:
			shooter = _pick_mode(rng, lines[s], pw, M_HEAD)
		MatchSimulation.CH_LONG:
			shooter = _pick_mode(rng, lines[s], pw, M_LONG)
		MatchSimulation.CH_FREEKICK:
			var sheet_fk: TeamSheet = sides[s]["sheet"]
			for v in lines[s]:
				if v[10] == 1 and v[0].id == sheet_fk.freekick_taker:
					shooter = v
			if shooter == null:
				shooter = _pick_mode(rng, lines[s], pw, M_LONG)
		MatchSimulation.CH_DRIBBLE:
			shooter = _pick_mode(rng, lines[s], pw, M_DRIBBLE)
		MatchSimulation.CH_COUNTER:
			shooter = _pick_mode(rng, lines[s], pw, M_COUNTER)
		_:
			shooter = _pick_mode(rng, lines[s], pw, M_SHOOT)
	if shooter == null:
		return
	# Qualidade: o tipo de chance, o confronto (conv) e o finalizador contra a média do time
	var fin_f := clampf(exp(MatchSimulation.EPS * (float(shooter[9]) * float(shooter[2]) - float(sides[s]["fin"]))), 0.7, 1.45)
	var xg := clampf(float(st["conv"][s]) * float(st["cq"][s][k]) * qual_m * fin_f, 0.005, 0.85)
	st["xg"][s] += xg
	if rng.randf() >= xg:
		return
	# Gol contra: cruzamento ou escanteio desviado pela zaga (a mesma chance do minuto a minuto)
	if (ctype == MatchSimulation.CH_CROSS or ctype == MatchSimulation.CH_CORNER) and rng.randf() < MatchSimulation.OWN_GOAL_P:
		var og: Variant = _pick(rng, lines[1 - s], 7)
		if og != null:
			og[18] -= 1.0
			score[s] += 1
			st["react"][1 - s] = m + 10
			st["goals"].append([m, s, og[0].id, Fixture.GOAL_OWN, half])
			st["cts"].append([s, MatchSimulation.CH_CROSS, m, half])
			return
	shooter[13] += 1
	shooter[18] += 1.1
	# Assistência: a mesma chance e o mesmo tipo de passe do minuto a minuto (MatchSimulation._pick_assister)
	var ap: Array = MatchSimulation.assist_profile(ctype)
	if rng.randf() < float(ap[1]):
		var assister: Variant = _pick_mode(rng, lines[s], pw, M_CROSS if int(ap[0]) == MatchSimulation.PK_CROSS else M_PASS, shooter)
		if assister != null:
			assister[14] += 1
			assister[18] += 0.65
	score[s] += 1
	st["react"][1 - s] = m + 10
	st["goals"].append([m, s, shooter[0].id, Fixture.GOAL_NORMAL, half])
	st["cts"].append([s, ctype, m, half])


static func _card(st: Dictionary, s: int, m: int) -> void:
	var rng: RandomNumberGenerator = st["rng"]
	var v: Variant = _pick(rng, st["lines"][s], 7)
	if v == null:
		return
	# Pendurado alivia na dividida e o juiz pensa duas vezes antes do segundo amarelo
	# (como no minuto a minuto: o segundo amarelo é raro).
	if int(v[15]) >= 1 and rng.randf() < 0.82:
		return
	v[15] += 1
	v[18] -= 0.35
	if v[15] >= 2:
		_send_off(v, m)
		st["rc"][s] += 1
	else:
		st["yc"][s] += 1


static func _timeline_event(st: Dictionary, ev: Array) -> void:
	var rng: RandomNumberGenerator = st["rng"]
	var mnt: int = ev[0]
	var s: int = ev[2]
	var lines: Array = st["lines"]
	var subs: Array = st["subs"]
	match int(ev[1]):
		3:
			var v: Variant = _pick_injured(rng, lines[s])
			if v != null:
				v[17] = InjuryTable.roll_weeks(rng)
				if subs[s] < 5:
					if _substitute(st["sides"][s], lines[s], st["used"][s], v, mnt):
						subs[s] += 1
				else:
					v[10] = 0
					v[12] = mnt
		4:
			if subs[s] < 5:
				var out: Variant = _tired_starter(lines[s])
				if out != null and _substitute(st["sides"][s], lines[s], st["used"][s], out, mnt):
					subs[s] += 1


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


## Sorteia um jogador de linha em campo pelo peso do modo (pw: player_id -> pesos de mode_weights).
static func _pick_mode(rng: RandomNumberGenerator, lines: Array, pw: Dictionary, mode: int, exclude: Variant = null) -> Variant:
	var total := 0.0
	for v in lines:
		if v[10] == 1 and v != exclude and pw.has(v[0].id) and int(v[1]) != Pos.GK:
			total += float(pw[v[0].id][mode])
	if total <= 0.0:
		return _pick(rng, lines, 5, exclude)
	var r := rng.randf() * total
	for v in lines:
		if v[10] != 1 or v == exclude or not pw.has(v[0].id) or int(v[1]) == Pos.GK:
			continue
		r -= float(pw[v[0].id][mode])
		if r <= 0.0:
			return v
	return _pick(rng, lines, 5, exclude)


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
	if r < OWN_GOAL_SHARE + PENALTY_SHARE * float(sides[s].get("ref_pens", 1.0)):
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
	var sw: Array = side["slot_w"].get(op.id, [0.3, 0.3, 1.0])
	var bw := mode_weights(best, pos, float(out[4]), float(sw[0]), float(sw[1]), f, float(sw[2]))
	side["pw"][best.id] = bw
	side["slot_w"][best.id] = sw
	shoot = float(bw[M_SHOOT])
	assist = float(bw[M_PASS])
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
		# Ordem escolhida pelo técnico vem na frente.
		var sheet: TeamSheet = sides[s]["sheet"]
		var chosen: Array = []
		for pid in sheet.shootout_order:
			for v in kickers[s]:
				if v[0].id == int(pid):
					chosen.append(v)
					kickers[s].erase(v)
					break
		kickers[s] = chosen + kickers[s]
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
		var gk_p: Player = null
		for v in lines[1 - s]:
			if v[10] == 1 and int(v[1]) == Pos.GK:
				gk_p = v[0]
		var pressure := 0.55 + 0.05 * mini(taken[s], 4) + (0.2 if taken[s] >= 5 else 0.0)
		var pk := PenaltyKick.kick(rng, k[0], gk_p, {"f": float(k[2]), "cond": 60.0, "pressure": pressure, "away": s == 1})
		taken[s] += 1
		if String(pk["res"]) == "goal":
			ps[s] += 1
		var a: int = taken[0]
		var b: int = taken[1]
		if a <= 5 and b <= 5:
			if ps[0] > ps[1] + (5 - b) or ps[1] > ps[0] + (5 - a):
				break
		elif a == b and ps[0] != ps[1]:
			break
	return ps
