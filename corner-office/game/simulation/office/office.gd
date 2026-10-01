class_name Office
extends RefCounted
## Sede da promotora (Game Design Bible §12, §15 Organização/staff, §19).
## Simulação pura: calcula carga, energia, estresse, moral, relações, folha e o
## efeito de cada função nos sistemas da liga. A cena 2D só representa estes
## estados; nenhuma regra mora na UI. Sorteios usam world.office_rng.

static var _cfg: Dictionary = {}


static func config() -> Dictionary:
	if _cfg.is_empty():
		_cfg = ContentDB.load_json("office.json")
	return _cfg


static func tuning() -> Dictionary:
	return config().tuning


# ------------------------------------------------------------------ consultas

static func active_staff(world: WorldState, org_id: String = "") -> Array:
	var id := org_id if not org_id.is_empty() else world.player_org_id
	var out: Array = []
	for s: StaffMember in world.staff.values():
		if s.organization_id == id and s.is_active():
			out.append(s)
	out.sort_custom(func(a: StaffMember, b: StaffMember): return a.desk < b.desk if a.desk != b.desk else a.id < b.id)
	return out


static func candidates(world: WorldState) -> Array:
	var out: Array = []
	for s: StaffMember in world.staff.values():
		if s.status == "candidate":
			out.append(s)
	out.sort_custom(func(a: StaffMember, b: StaffMember): return a.id < b.id)
	return out


static func level_info(org: Organization) -> Dictionary:
	var levels: Array = config().office_levels
	return levels[clampi(org.office_level - 1, 0, levels.size() - 1)]


static func next_level_info(org: Organization) -> Dictionary:
	var levels: Array = config().office_levels
	return levels[org.office_level] if org.office_level < levels.size() else {}


static func desks(org: Organization) -> int:
	return int(level_info(org).desks)


static func has_room(org: Organization, room: String) -> bool:
	return room in level_info(org).rooms


static func role_label(role: String) -> String:
	return str(config().roles.get(role, {}).get("label", role))


static func department(role: String) -> String:
	return str(config().roles.get(role, {}).get("department", "operations"))


static func department_label(dept: String) -> String:
	return str(config().departments.get(dept, {}).get("label", dept))


static func level_label(level: String) -> String:
	for l: Dictionary in config().levels:
		if l.id == level:
			return str(l.label)
	return level


static func trait_info(t: String) -> Dictionary:
	return config().traits.get(t, {"label": t, "hint": ""})


static func payroll(world: WorldState, org_id: String = "") -> int:
	var total := 0
	for s: StaffMember in active_staff(world, org_id):
		total += s.salary
	return total


## Salário de mercado para a função, nível e habilidade (US$/mês).
static func market_salary(role: String, level: String, skill: float) -> int:
	var base := float(config().roles.get(role, {}).get("base_salary", 7000))
	var mult := 1.0
	for l: Dictionary in config().levels:
		if l.id == level:
			mult = float(l.salary)
	return int(round(base * mult * (0.75 + skill / 200.0) / 50.0)) * 50


## Performance do mês: habilidade útil depois de energia, estresse e moral.
static func performance(s: StaffMember) -> float:
	var out := s.skill * (0.55 + s.energy / 220.0) * (1.1 - s.stress / 250.0) * (0.85 + s.morale / 400.0)
	for t: String in s.traits:
		out *= float(trait_info(t).get("output", 1.0))
	return clampf(out, 0.0, 100.0)


## Efeito da função sobre a liga: 0..max_effect (content/office.json).
## Só a organização do jogador tem sede simulada; rivais retornam 0.
static func effect(world: WorldState, org_id: String, role: String) -> float:
	if org_id != world.player_org_id or world.staff.is_empty():
		return 0.0
	var info: Dictionary = config().roles.get(role, {})
	var best := 0.0
	var extra := 0.0
	for s: StaffMember in active_staff(world, org_id):
		if s.role != role or s.status != "active":
			continue
		var p := performance(s) / 100.0
		if p > best:
			extra += best * 0.35
			best = p
		else:
			extra += p * 0.35
	return float(info.get("max_effect", 0.0)) * clampf(best + extra, 0.0, 1.25)


## Frases curtas: por que a pessoa está como está (ficha de 3 segundos).
static func mood_text(code: String) -> String:
	return {
		"OVERLOADED": "Sobrecarregado com o trabalho do setor.",
		"IDLE": "Com pouca coisa para fazer.",
		"UNDERPAID": "Acha que ganha abaixo do mercado.",
		"WELL_PAID": "Satisfeito com o salário.",
		"TRUSTS_YOU": "Confia na presidência.",
		"DISTRUSTS_YOU": "Anda desconfiado da presidência.",
		"HAS_FRIENDS": "Tem amigos na equipe.",
		"HAS_RIVAL": "Vive às turras com um colega.",
		"EXHAUSTED": "Exausto: precisa de descanso.",
		"STRESSED": "Muito estressado.",
		"WANTS_GROWTH": "Quer crescer de cargo.",
		"RECENT_PRAISE": "Motivado por um elogio recente.",
		"ON_VACATION": "De férias.",
	}.get(code, code)


# ------------------------------------------------------------------ criação

## Garante a sede do jogador: equipe inicial, mesas e candidatos.
static func ensure(world: WorldState) -> void:
	var org := world.player_org()
	if org == null:
		return
	if not org.office_state.has("started"):
		org.office_state.started = world.date.duplicate()
		for role: String in config().start_staff:
			var s := generate(world, role, "pleno", org.id)
			hire(world, s, true)
	if candidates(world).is_empty():
		refresh_candidates(world)


## Gera uma pessoa coerente (nome/país/sexo/aparência/traços) com o office_rng.
static func generate(world: WorldState, role: String, level: String = "", org_id: String = "") -> StaffMember:
	var rng := world.office_rng
	var cfg := config()
	var s := StaffMember.new()
	s.id = world.new_id("staff")
	s.role = role
	s.country = str(rng.pick(cfg.countries))
	if not FighterGenerator.origins().countries.has(s.country):
		s.country = "BR"
	s.sex = "f" if rng.chance(0.42) else "m"
	var name := FighterGenerator.roll_name(rng, FighterGenerator.pick_group(rng, s.country), s.sex == "f")
	s.first_name = str(name[0])
	s.last_name = str(name[1])
	s.age = rng.range_i(23, 58)
	s.experience = clampi(s.age - 22 - rng.range_i(0, 6), 0, 35)
	s.skill = clampf(rng.normal(38.0 + s.experience * 1.4, 9.0), 18.0, 92.0)
	s.potential = clampf(s.skill + maxf(0.0, (45 - s.age) * rng.range_f(0.4, 1.3)) + rng.normal(0, 4), s.skill, 97.0)
	if level.is_empty():
		level = "junior"
		for l: Dictionary in cfg.levels:
			if s.skill >= float(l.min_skill) and l.id != "director":
				level = str(l.id)
	s.level = level
	s.ambition = clampf(rng.normal(52.0 - (s.age - 35) * 0.6, 16.0), 5.0, 98.0)
	s.loyalty = clampf(rng.normal(50.0, 16.0), 5.0, 95.0)
	var pool: Array = cfg.traits.keys()
	pool.sort()
	var count := 1 if rng.chance(0.45) else 2
	while s.traits.size() < count:
		var t: String = rng.pick(pool)
		if t not in s.traits and not (t == "workaholic" and "laid_back" in s.traits) and not (t == "laid_back" and "workaholic" in s.traits):
			s.traits.append(t)
	for t: String in s.traits:
		s.ambition = clampf(s.ambition + float(trait_info(t).get("ambition", 0)), 0.0, 100.0)
		s.loyalty = clampf(s.loyalty + float(trait_info(t).get("loyalty", 0)), 0.0, 100.0)
	s.morale = clampf(rng.normal(66.0, 8.0), 40.0, 90.0)
	s.energy = clampf(rng.normal(82.0, 8.0), 50.0, 100.0)
	s.stress = clampf(rng.normal(22.0, 8.0), 5.0, 50.0)
	var market := market_salary(role, s.level, s.skill)
	s.salary = market
	s.asking_salary = int(round(market * rng.range_f(0.95, 1.18) / 50.0)) * 50
	s.look = {
		"skin": rng.range_i(0, cfg.skin_tones.size() - 1),
		"hair": rng.range_i(0, 5 if s.sex == "f" else 4),
		"hair_color": rng.range_i(0, cfg.hair_colors.size() - 1) if s.age < 50 or rng.chance(0.4) else 5,
		"glasses": rng.chance(0.28),
		"beard": s.sex == "m" and rng.chance(0.35),
		"build": rng.range_i(0, 2),
	}
	s.status = "candidate"
	s.organization_id = org_id
	world.add("staff", s)
	return s


static func refresh_candidates(world: WorldState) -> void:
	var cfg: Dictionary = config().candidates
	for s: StaffMember in candidates(world):
		if not s.expires_on.is_empty() and GameDate.days_between(world.date, s.expires_on) < 0:
			s.status = "gone"
	var roles: Array = config().roles.keys()
	roles.sort()
	var have := candidates(world).size()
	for i in maxi(0, int(cfg.pool) - have):
		var s := generate(world, str(world.office_rng.pick(roles)))
		s.expires_on = GameDate.add_days(world.date, int(cfg.expire_days) + world.office_rng.range_i(0, 10))


static func hire(world: WorldState, s: StaffMember, starting: bool = false) -> void:
	var org := world.player_org()
	s.organization_id = org.id
	s.status = "active"
	s.hired_on = world.date.duplicate()
	s.expires_on = {}
	if not starting:
		s.salary = maxi(s.asking_salary, s.salary)
	s.desk = _free_desk(world, org)
	s.trust = 10.0 if not starting else 20.0
	log_history(world, s, "Contratado como %s %s." % [role_label(s.role), level_label(s.level).to_lower()])
	for other: StaffMember in active_staff(world, org.id):
		if other.id != s.id and not other.relationships.has(s.id):
			_relate(world, s, other, 0.0)


static func _free_desk(world: WorldState, org: Organization) -> int:
	var used := {}
	for s: StaffMember in active_staff(world, org.id):
		used[s.desk] = true
	for i in 64:
		if not used.has(i):
			return i
	return 63


static func log_history(world: WorldState, s: StaffMember, text: String) -> void:
	s.history.append({"date": world.date.duplicate(), "text": text})


static func ledger(world: WorldState, org: Organization, kind: String, amount: int, label: String) -> void:
	org.cash += amount
	org.ledger.append({"date": world.date.duplicate(), "kind": kind, "amount": amount, "label": label})


# ------------------------------------------------------------------ relógio

## Um dia útil da sede: carga, energia, estresse, moral, relações, atividade.
static func daily(world: WorldState) -> void:
	var org := world.player_org()
	if org == null:
		return
	var t := tuning()
	var weekend := GameDate.is_weekend(world.date)
	var team := active_staff(world, org.id)
	var loads := _loads(world, org, team)
	for s: StaffMember in team:
		if s.status == "vacation":
			if GameDate.days_between(world.date, s.vacation_until) <= 0:
				s.status = "active"
				log_history(world, s, "Voltou das férias.")
			else:
				s.energy = minf(100.0, s.energy + float(t.energy_rest_vacation))
				s.stress = maxf(0.0, s.stress - float(t.stress_relief) * 3.0)
				s.activity = "vacation"
				continue
		s.workload = float(loads.get(s.id, 0.0))
		var stress_mult := 1.0
		for tr: String in s.traits:
			stress_mult *= float(trait_info(tr).get("stress", 1.0))
		if weekend:
			s.energy = minf(100.0, s.energy + float(t.energy_rest_weekend))
			s.stress = maxf(0.0, s.stress - float(t.stress_relief))
		else:
			s.energy = clampf(s.energy - float(t.energy_drain) * (0.5 + s.workload), 0.0, 100.0)
			var pressure := (s.workload - 0.85) * float(t.stress_per_load) * stress_mult
			if s.energy < float(t.tired_energy):
				pressure += 1.5
			s.stress = clampf(s.stress + (pressure if pressure > 0 else pressure * 0.8 - 0.4), 0.0, 100.0)
		_drift_relationships(world, s, team)
		_update_morale(world, s)
		# Experiência e mentoria: crescimento lento até o potencial.
		var growth := float(t.skill_growth_year) / 365.0 * (1.0 + maxf(0.0, s.workload - 0.3))
		for other: StaffMember in team:
			if other.id != s.id and "mentor" in other.traits and department(other.role) == department(s.role) and other.skill > s.skill + 8:
				growth *= 1.0 + float(t.mentor_bonus)
				break
		if s.skill < s.potential:
			s.skill = minf(s.potential, s.skill + growth)
		s.activity = _activity(world, org, s, weekend)


## Dia 1º: folha, candidatos, aniversário de casa.
static func monthly(world: WorldState) -> void:
	var org := world.player_org()
	if org == null:
		return
	var total := payroll(world, org.id)
	if total > 0:
		ledger(world, org, "payroll", -total, "Folha da sede (%d pessoas)" % active_staff(world, org.id).size())
	var active_deals: Array = []
	for deal: Dictionary in org.deals:
		if GameDate.days_between(world.date, deal.until) >= 0:
			active_deals.append(deal)
	org.deals = active_deals
	refresh_candidates(world)


## Carga por pessoa: trabalho real do setor dividido pelas pessoas da função.
static func _loads(world: WorldState, org: Organization, team: Array) -> Dictionary:
	# Rotina da casa (card seguinte, redes, exames, contas, vídeos): 0.5–0.6 por
	# setor mesmo sem noite marcada; cada noite próxima soma trabalho de verdade.
	var demand := {"matchmaker": 0.55, "marketing": 0.5, "medical": 0.45, "finance": 0.55, "scout": 0.6, "media": 0.5}
	for ev: FightEvent in world.events.values():
		if ev.organization_id != org.id or ev.status not in ["planned", "announced"]:
			continue
		var days := GameDate.days_between(world.date, ev.date)
		if days < 0 or days > 60:
			continue
		var near := 1.0 if days <= 14 else 0.55
		demand.matchmaker += (0.12 * ev.fight_ids.size() + (0.35 if ev.status == "planned" else 0.1)) * near
		demand.marketing += (0.6 if ev.status == "announced" else 0.15) * near
		demand.media += (0.45 if ev.status == "announced" else 0.1) * near
		demand.finance += 0.25 * near
	var injured := 0
	for id: String in org.roster:
		var f: Fighter = world.fighters.get(id)
		if f and (not f.injuries.is_empty() or (not f.medical_suspension_until.is_empty() and GameDate.days_between(world.date, f.medical_suspension_until) > 0)):
			injured += 1
	demand.medical += injured * 0.09
	demand.scout += maxf(0.0, (30 - org.roster.size()) * 0.03)
	demand.finance += 0.4 if org.cash < 0 else 0.0
	var per_role := {}
	for s: StaffMember in team:
		if s.status == "active":
			per_role[s.role] = int(per_role.get(s.role, 0)) + 1
	var out := {}
	for s: StaffMember in team:
		var share := float(demand.get(s.role, 0.3)) / maxf(1.0, float(per_role.get(s.role, 1)))
		# Nível alto rende mais por pessoa.
		var capacity := {"junior": 0.8, "pleno": 1.0, "senior": 1.15, "director": 1.3}.get(s.level, 1.0) as float
		out[s.id] = share / capacity
	return out


static func _update_morale(world: WorldState, s: StaffMember) -> void:
	var t := tuning()
	var reasons: Array = []
	var target := 62.0
	var market := market_salary(s.role, s.level, s.skill)
	var pay := float(s.salary) / maxf(1.0, market)
	if pay < 0.93:
		target -= (0.93 - pay) * 120.0 * (0.5 + s.ambition / 100.0)
		reasons.append("UNDERPAID")
	elif pay > 1.08:
		target += 6.0
		reasons.append("WELL_PAID")
	target += s.trust * 0.18
	if s.trust > 25:
		reasons.append("TRUSTS_YOU")
	elif s.trust < -15:
		reasons.append("DISTRUSTS_YOU")
	if s.workload > 1.15:
		target -= (s.workload - 1.15) * 30.0
		reasons.append("OVERLOADED")
	elif s.workload < 0.3:
		target -= 4.0 * (s.ambition / 60.0)
		reasons.append("IDLE")
	if s.stress > float(t.overload_stress):
		target -= (s.stress - float(t.overload_stress)) * 0.6
		reasons.append("STRESSED")
	if s.energy < float(t.tired_energy):
		target -= 6.0
		reasons.append("EXHAUSTED")
	var friends := 0
	var rivals := 0
	for other_id: String in s.relationships:
		var other: StaffMember = world.staff.get(other_id)
		if other == null or not other.is_active():
			continue
		var v := float(s.relationships[other_id].value)
		if v > 35:
			friends += 1
		elif v < -35:
			rivals += 1
	target += minf(12.0, friends * 4.0) - rivals * 7.0
	if friends > 0:
		reasons.append("HAS_FRIENDS")
	if rivals > 0:
		reasons.append("HAS_RIVAL")
	if s.ambition > 70 and s.level in ["junior", "pleno"] and s.skill > 55:
		target -= 5.0
		reasons.append("WANTS_GROWTH")
	if not s.last_praise_on.is_empty() and GameDate.days_between(s.last_praise_on, world.date) < 14:
		target += 5.0
		reasons.append("RECENT_PRAISE")
	s.morale = clampf(s.morale + (target - s.morale) * float(t.morale_pull), 0.0, 100.0)
	s.mood_reasons = reasons


## Relações: convivência no mesmo setor aproxima ou afasta conforme o par de
## traços; lealdade e tempo de casa estabilizam (Game Design Bible §19).
static func _drift_relationships(world: WorldState, s: StaffMember, team: Array) -> void:
	var t := tuning()
	for other: StaffMember in team:
		if other.id <= s.id or other.status != "active" or s.status != "active":
			continue
		var same := department(other.role) == department(s.role)
		if not same and not world.office_rng.chance(0.25):
			continue
		var drift := _pair_affinity(s, other) * float(t.relationship_drift) * (1.0 if same else 0.4)
		drift += world.office_rng.normal(0.0, 0.6)
		if s.stress > 70 or other.stress > 70:
			drift -= 0.4
		_relate(world, s, other, drift)


static func _pair_affinity(a: StaffMember, b: StaffMember) -> float:
	var cfg: Dictionary = config().trait_pairs
	var score := 0.15
	for pair: Array in cfg.friends:
		if (pair[0] in a.traits and pair[1] in b.traits) or (pair[1] in a.traits and pair[0] in b.traits):
			score += 0.6
	for pair: Array in cfg.rivals:
		if (pair[0] in a.traits and pair[1] in b.traits) or (pair[1] in a.traits and pair[0] in b.traits):
			score -= 0.8
	if a.role == b.role and a.ambition > 65 and b.ambition > 65:
		score -= 0.5
	for x: StaffMember in [a, b]:
		if "hothead" in x.traits:
			score -= 0.25
		if "sociable" in x.traits:
			score += 0.2
	return score


static func _relate(world: WorldState, a: StaffMember, b: StaffMember, delta: float) -> void:
	var v := clampf(float(a.relationships.get(b.id, {}).get("value", 0.0)) + delta, -100.0, 100.0)
	var kind_a := _kind(a, b, v)
	var kind_b := _kind(b, a, v)
	var before := str(a.relationships.get(b.id, {}).get("kind", "neutral"))
	a.relationships[b.id] = {"value": snappedf(v, 0.1), "kind": kind_a}
	b.relationships[a.id] = {"value": snappedf(v, 0.1), "kind": kind_b}
	if before != kind_a and kind_a in ["friend", "rival"] and not world.date.is_empty():
		log_history(world, a, ("Ficou amigo de %s." if kind_a == "friend" else "Entrou em atrito com %s.") % b.full_name())
		log_history(world, b, ("Ficou amigo de %s." if kind_b == "friend" else "Entrou em atrito com %s.") % a.full_name())


static func _kind(a: StaffMember, b: StaffMember, v: float) -> String:
	if v >= 25 and "mentor" in a.traits and department(a.role) == department(b.role) and a.skill > b.skill + 8:
		return "mentor"
	if v >= 25 and "mentor" in b.traits and department(a.role) == department(b.role) and b.skill > a.skill + 8:
		return "mentee"
	if v >= 35:
		return "friend"
	if v <= -35:
		return "rival"
	return "neutral"


## Estado visual do dia (a cena 2D só lê isto).
static func _activity(world: WorldState, org: Organization, s: StaffMember, weekend: bool) -> String:
	if s.status == "vacation":
		return "vacation"
	if s.stress >= float(tuning().overload_stress) or s.workload > 1.35:
		return "overloaded"
	if s.energy < float(tuning().tired_energy):
		return "tired"
	for ev: FightEvent in world.events.values():
		if ev.organization_id == org.id and ev.status in ["planned", "announced"]:
			var days := GameDate.days_between(world.date, ev.date)
			if days >= 0 and days <= 3 and s.role in ["matchmaker", "marketing", "media", "medical"] and has_room(org, "meeting"):
				return "meeting"
	var friend := false
	for other_id: String in s.relationships:
		if str(s.relationships[other_id].kind) in ["friend", "mentor", "mentee"]:
			friend = true
	if weekend:
		return "break"
	var roll := world.office_rng.range_f(0.0, 1.0)
	if friend and roll < 0.18:
		return "talking"
	if roll > 0.9:
		return "break"
	return "working"


## Resumo de alerta para ícones/badges: "" quando está tudo bem.
static func problem(s: StaffMember) -> String:
	if s.status == "vacation":
		return ""
	if s.stress >= float(tuning().overload_stress):
		return "stress"
	if s.energy < float(tuning().tired_energy):
		return "tired"
	if s.morale < 35:
		return "unhappy"
	for other_id: String in s.relationships:
		if str(s.relationships[other_id].kind) == "rival":
			return "conflict"
	return ""
