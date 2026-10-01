class_name CareerHistory
extends RefCounted
## Carreira fora das câmeras: o passado de cada atleta até jan/2027 e as lutas
## no circuito regional durante o save (Game Design Bible §0, §2 "História
## anterior ao save", §13; MMA Bible §11, §28).
##
## Cartel NÃO é sorteado: é o resultado de lutas abstratas contra adversários
## do nível do circuito em que o atleta estava, usando a curva de idade do
## CareerModel. Por isso prospects têm cartéis inflados (8-0 contra oposição
## fraca), veteranos da liga principal têm derrotas e quem declina perde mais.
## Lutas da liga modelada continuam no FightEngine; aqui só o que o jogo não
## transmite. `history.results` guarda as 10 mais recentes (resumo); o
## histórico append-only de lutas transmitidas continua em `fight_ids`.

const RESULT_LIMIT := 10


static func _c() -> Dictionary:
	return CareerModel.cfg()


static func _normal_clamped(rng: SimRandom, pair: Array, lo: float, hi: float) -> float:
	return clampf(rng.normal(float(pair[0]), float(pair[1])), lo, hi)


## Rating público (tipo Elo) do nível de um adversário do circuito.
static func level_rating(level: float) -> float:
	var elo: Dictionary = _c().elo
	return float(elo.start) + (level - 45.0) * float(elo.level_scale)


static func expected(r_a: float, r_b: float) -> float:
	return 1.0 / (1.0 + pow(10.0, (r_b - r_a) / 400.0))


static func k_factor(f: Fighter) -> float:
	var elo: Dictionary = _c().elo
	return float(elo.k_early) if CareerModel.pro_bouts(f) < 8 else float(elo.k)


## Aplica um resultado (de qualquer origem) ao cartel, rating, sequência e
## resumo recente. `result`: W | L | D | NC; `method`: ko_tko | submission |
## decision | draw | nc.
static func record_result(f: Fighter, date: Dictionary, result: String, method: String, detail: String, round_n: int, opponent_rating: float, entry: Dictionary = {}) -> void:
	var rec: Dictionary = f.record
	var suffix: String = {"ko_tko": "ko", "submission": "sub", "decision": "dec"}.get(method, "")
	match result:
		"W":
			rec["wins"] = int(rec.get("wins", 0)) + 1
			if not suffix.is_empty():
				rec[suffix + "_wins"] = int(rec.get(suffix + "_wins", 0)) + 1
		"L":
			rec["losses"] = int(rec.get("losses", 0)) + 1
			if not suffix.is_empty():
				rec[suffix + "_losses"] = int(rec.get(suffix + "_losses", 0)) + 1
		"D":
			rec["draws"] = int(rec.get("draws", 0)) + 1
		_:
			rec["nc"] = int(rec.get("nc", 0)) + 1
	if result in ["W", "L", "D"]:
		var score: float = {"W": 1.0, "L": 0.0, "D": 0.5}[result]
		f.rating = f.rating + k_factor(f) * (score - expected(f.rating, opponent_rating))
		f.history["peak_rating"] = maxf(float(f.history.get("peak_rating", f.rating)), f.rating)
	var streak := int(f.history.get("streak", 0))
	if result == "W":
		streak = streak + 1 if streak > 0 else 1
	elif result == "L":
		streak = streak - 1 if streak < 0 else -1
	elif result == "D":
		streak = 0
	f.history["streak"] = streak
	f.last_fight_on = date.duplicate()
	var item := {"date": date.duplicate(), "result": result, "method": method, "detail": detail, "round": round_n}
	item.merge(entry)
	var results: Array = f.history.get("results", [])
	results.push_front(item)
	if results.size() > RESULT_LIMIT:
		results.resize(RESULT_LIMIT)
	f.history["results"] = results


## Método de uma luta abstrata a partir da divisão, dos estilos e do queixo.
static func pick_method(rng: SimRandom, division: String, winner_base: String, loser_chin: float, gap: float) -> Dictionary:
	var c := _c()
	var d := CareerModel.division(division)
	if rng.chance(float(c.draw_chance)):
		return {"method": "draw", "detail": "split", "round": 3}
	if rng.chance(float(c.nc_chance)):
		return {"method": "nc", "detail": "overturned", "round": rng.range_i(1, 3)}
	var finish := clampf(float(d.finish) * float(c.style_finish_factor.get(winner_base, 1.0)) * (1.0 + gap / 45.0), 0.12, 0.9)
	if not rng.chance(finish):
		return {"method": "decision", "detail": rng.weighted(c.decision_details), "round": 3}
	var ko := clampf(float(d.ko_share) * float(c.style_ko_factor.get(winner_base, 1.0)) * (1.0 + maxf(0.0, 60.0 - loser_chin) / 80.0), 0.08, 0.95)
	var weights: Array = c.finish_round
	var round_n := int(rng.weighted({1: weights[0], 2: weights[1], 3: weights[2]}))
	if rng.chance(ko):
		return {"method": "ko_tko", "detail": rng.weighted(c.ko_details), "round": round_n}
	return {"method": "submission", "detail": rng.weighted(c.submission_details), "round": round_n}


## Uma luta fora das câmeras contra um adversário de nível `opp_level`.
static func abstract_bout(world: WorldState, rng: SimRandom, f: Fighter, date: Dictionary, opp_level: float, context: String) -> Dictionary:
	var c := _c()
	var age := CareerModel.age_on(f, date)
	var level := CareerModel.ability_at(f, age)
	var p := 1.0 / (1.0 + exp(-(level - opp_level) / float(c.win_scale)))
	var won := rng.chance(p)
	var opp_base: String = rng.weighted(_country(f.country).get("bases", {"mma": 1.0}))
	var chin := level + float(f.hidden.get("attr_noise", {}).get("chin", 0.0)) - CareerModel.wear(f) * 2.4
	var m := pick_method(rng, f.division, f.martial_base if won else opp_base, opp_level if won else chin, absf(level - opp_level))
	var result: String = "D" if m.method == "draw" else "NC" if m.method == "nc" else "W" if won else "L"
	var opponent: String = AthleteFactory.phantom_name(world, rng, f.country if context != "flagship" else "", f.sex)
	record_result(f, date, result, m.method, m.detail, int(m.round), level_rating(opp_level) + rng.normal(0.0, 25.0), {"opponent": opponent, "context": context})
	if result == "L" and m.method == "ko_tko":
		f.damage_history["head"] = float(f.damage_history.get("head", 0.0)) + 0.55
	elif result == "L" and m.method == "decision":
		f.damage_history["head"] = float(f.damage_history.get("head", 0.0)) + 0.18
	return {"result": result, "method": m.method}


static func _country(code: String) -> Dictionary:
	for c: Dictionary in AthleteFactory.countries():
		if c.code == code:
			return c
	return {}


## Simula do debut até `now`. `tier`: flagship | national | circuit.
## Devolve {flagship_debut_on, flagship_bouts, stints}.
static func backstory(world: WorldState, rng: SimRandom, f: Fighter, now: Dictionary, tier: String, current_level: float) -> Dictionary:
	var c := _c()
	var age_now := CareerModel.age_on(f, now)
	var debut_age := _normal_clamped(rng, c.debut_age, 18.0, 31.0) + float(c.debut_shift.get(f.martial_base, 0.0))
	# Grandes ligas contratam com 5–7 lutas profissionais; nacionais com algumas.
	var min_years: float = {"flagship": 2.4, "national": 1.3}.get(tier, rng.range_f(0.0, 0.8))
	debut_age = minf(debut_age, age_now - min_years)
	var info := {"flagship_debut_on": {}, "flagship_bouts": 0, "stints": 0}
	f.history["amateur"] = "%d-%d" % [clampi(roundi(rng.normal(6, 3)), 0, 25), clampi(roundi(rng.normal(1.5, 1.2)), 0, 8)]
	if debut_age >= age_now:
		return info
	var t := GameDate.add_days(f.birth_date, roundi(debut_age * 365.25))
	f.history["debut_on"] = t.duplicate()
	var era := "regional"
	var bouts := 0
	var threshold := float(c.flagship_threshold)
	var flagship_mean := float(c.tiers.flagship.ability[0])
	var circuit_mean := float(c.tiers.circuit.ability[0])
	while GameDate.days_between(t, now) > 0:
		var level := CareerModel.ability_at(f, CareerModel.age_on(f, t))
		var streak := int(f.history.get("streak", 0))
		var wins_so_far := int(f.record.get("wins", 0))
		var signable := streak >= 2 or (bouts >= 8 and wins_so_far >= bouts * 0.7)
		if era == "regional" and bouts >= 4:
			if tier == "flagship" and level >= minf(threshold, current_level - 2.0) and signable:
				era = "flagship"
				if info.flagship_debut_on.is_empty():
					info["flagship_debut_on"] = t.duplicate()
			elif tier != "flagship" and level >= threshold and streak >= 3 and rng.chance(0.3):
				era = "stint"
				info["stints"] += 1
		elif era == "stint" and (streak <= -2 or (streak < 0 and rng.chance(0.35))):
			era = "regional"
		elif era == "flagship" and (streak <= -3 or (streak == -2 and rng.chance(0.4))):
			# Demitido da liga: precisa voltar a vencer no circuito.
			era = "regional"
			info["stints"] += 1
		var opp: float
		if era in ["flagship", "stint"]:
			opp = 0.5 * level + 0.5 * flagship_mean + rng.normal(0.0, 5.0)
			info["flagship_bouts"] += 1
		else:
			# O circuito tem nível próprio: quem é fraco perde e vira journeyman;
			# prospects recebem lutas mais fáceis no início (records construídos).
			opp = 0.6 * level + 0.4 * circuit_mean - (6.0 if bouts < 4 else 1.5) + rng.normal(0.0, 6.0)
		abstract_bout(world, rng, f, t, opp, "flagship" if era != "regional" else "regional")
		bouts += 1
		var gap_cfg: Array = c.months_between_fights.flagship if era != "regional" else c.months_between_fights.early if bouts < 6 else c.months_between_fights.mid
		var months := _normal_clamped(rng, gap_cfg, 1.5, 14.0)
		if rng.chance(float(c.layoff.chance)):
			months += rng.range_f(float(c.layoff.months[0]), float(c.layoff.months[1]))
		t = GameDate.add_days(t, roundi(months * 30.4))
	info["in_league"] = era == "flagship"
	return info


## Atletas autorais (roster canônico) já têm cartel; distribuímos métodos e
## resultados recentes coerentes com ele, sem mudar o cartel.
static func fill_known_record(world: WorldState, rng: SimRandom, f: Fighter, now: Dictionary) -> void:
	var wins := int(f.record.get("wins", 0))
	var losses := int(f.record.get("losses", 0))
	var draws := int(f.record.get("draws", 0))
	var total := wins + losses + draws
	var sequence: Array = []
	for i in wins: sequence.append("W")
	for i in losses: sequence.append("L")
	for i in draws: sequence.append("D")
	# Derrotas de campeões costumam ficar no meio da carreira, não no fim.
	for i in range(sequence.size() - 1, 0, -1):
		var j := rng.range_i(0, i)
		var tmp = sequence[i]
		sequence[i] = sequence[j]
		sequence[j] = tmp
	var level := CareerModel.ability_at(f, CareerModel.age_on(f, now))
	var saved := f.record.duplicate()
	f.record = {"wins": 0, "losses": 0, "draws": 0, "nc": 0}
	var t := GameDate.add_days(now, -roundi(total * 4.6 * 30.4))
	var chin := float(f.physical.get("chin", 60))
	for r: String in sequence:
		var m := {"method": "draw", "detail": "split", "round": 3}
		if r != "D":
			for attempt in 8:
				m = pick_method(rng, f.division, f.martial_base if r == "W" else "mma", level - 6.0 if r == "W" else chin, 6.0)
				if m.method not in ["draw", "nc"]:
					break
		record_result(f, t, r, m.method, m.detail, int(m.round), level_rating(level - 4.0 if r == "W" else level + 2.0), {"opponent": AthleteFactory.phantom_name(world, rng, "", f.sex), "context": "flagship"})
		t = GameDate.add_days(t, rng.range_i(110, 170))
	for key in ["wins", "losses", "draws"]:
		f.record[key] = int(saved.get(key, 0))
	if GameDate.days_between(f.last_fight_on, now) < 30:
		f.last_fight_on = GameDate.add_days(now, -rng.range_i(40, 150))
		f.history.results[0]["date"] = f.last_fight_on.duplicate()
