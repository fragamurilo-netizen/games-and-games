class_name Dilemmas
extends RefCounted
## Decisões contextuais da sede (Game Design Bible §19 Sistema de eventos).
## content/office_events.json declara textos, opções e efeitos; aqui ficam as
## pré-condições (fatos do mundo), o interpretador de efeitos e a agenda de
## desdobramentos. Nada nasce por roleta sem causa: `requires` precisa ser
## verdade antes de a chance ser sorteada. Sorteios usam world.office_rng.

static var _cfg: Dictionary = {}


static func config() -> Dictionary:
	if _cfg.is_empty():
		_cfg = ContentDB.load_json("office_events.json")
	return _cfg


static func definition(id: String) -> Dictionary:
	for d: Dictionary in config().events:
		if d.id == id:
			return d
	return {}


static func open(world: WorldState) -> Array:
	var out: Array = []
	for d: Dilemma in world.dilemmas.values():
		if d.status == "open" and d.organization_id == world.player_org_id:
			out.append(d)
	var rank := {"critical": 0, "high": 1, "medium": 2, "low": 3}
	out.sort_custom(func(a: Dilemma, b: Dilemma): return rank.get(a.priority, 3) < rank.get(b.priority, 3) if a.priority != b.priority else a.id > b.id)
	return out


static func recent(world: WorldState, limit: int = 12) -> Array:
	var out: Array = []
	for d: Dilemma in world.dilemmas.values():
		if d.status != "open" and d.organization_id == world.player_org_id:
			out.append(d)
	out.sort_custom(func(a: Dilemma, b: Dilemma): return a.id > b.id)
	return out.slice(0, limit)


# ------------------------------------------------------------------ relógio

## Um dia: vence decisões ignoradas, dispara desdobramentos e, no máximo, um
## evento novo cuja pré-condição seja fato. Retorna os dilemas criados.
static func tick(world: WorldState) -> Array:
	var org := world.player_org()
	if org == null:
		return []
	var created: Array = []
	for d: Dilemma in open(world):
		if not d.expires_on.is_empty() and GameDate.days_between(world.date, d.expires_on) < 0:
			var def := definition(d.def_id)
			var fallback := ""
			for o: Dictionary in def.get("options", []):
				if o.get("default", false):
					fallback = str(o.id)
			resolve(world, d, fallback, true)
	_check_promises(world, org)
	var due: Array = []
	var later: Array = []
	for f: Dictionary in org.office_state.get("followups", []):
		if GameDate.days_between(world.date, f.due) <= 0:
			due.append(f)
		else:
			later.append(f)
	org.office_state.followups = later
	for f: Dictionary in due:
		var ctx: Dictionary = f.get("context", {}).duplicate(true)
		var fresh := _requirement(world, str(definition(str(f.event)).get("requires", "")), ctx)
		if str(definition(str(f.event)).get("requires", "")) != "followup_only" and fresh.is_empty():
			continue
		for k in fresh:
			if not ctx.has(k):
				ctx[k] = fresh[k]
		var d := create(world, str(f.event), ctx)
		if d:
			created.append(d)
	if open(world).size() >= int(config().max_open) or not created.is_empty():
		return created
	var defs: Array = config().events.duplicate()
	for def: Dictionary in defs:
		if str(def.get("requires", "")) == "followup_only" or float(def.get("chance", 0)) <= 0:
			continue
		var cooldowns: Dictionary = org.office_state.get("cooldowns", {})
		if cooldowns.has(def.id) and GameDate.days_between(world.date, cooldowns[def.id]) > 0:
			continue
		var ctx := _requirement(world, str(def.requires), {})
		if ctx.is_empty():
			continue
		if not world.office_rng.chance(float(def.chance)):
			continue
		var d := create(world, str(def.id), ctx)
		if d:
			created.append(d)
			break
	return created


## Cria o dilema com textos resolvidos a partir do contexto.
static func create(world: WorldState, def_id: String, ctx: Dictionary) -> Dilemma:
	var def := definition(def_id)
	if def.is_empty():
		return null
	var org := world.player_org()
	for id: String in ctx.get("staff_ids", []):
		var s: StaffMember = world.staff.get(id)
		if s == null or (not s.is_active() and s.status != "candidate"):
			return null
	for d: Dilemma in open(world):
		if d.def_id == def_id and d.staff_ids == ctx.get("staff_ids", []) and d.fighter_ids == ctx.get("fighter_ids", []):
			return null
	var d := Dilemma.new()
	d.id = world.new_id("dilemma")
	d.def_id = def_id
	d.organization_id = org.id
	d.category = str(def.get("category", "rh"))
	d.priority = str(def.get("priority", "medium"))
	d.staff_ids = ctx.get("staff_ids", []).duplicate()
	d.fighter_ids = ctx.get("fighter_ids", []).duplicate()
	d.context = ctx.duplicate(true)
	var vars := _vars(world, d)
	d.title = str(def.title).format(vars)
	d.body = str(def.body).format(vars)
	for o: Dictionary in def.options:
		if o.get("requires_other", false) and d.staff_ids.size() < 2:
			continue
		d.options.append({"id": o.id, "label": str(o.label).format(vars), "hint": str(o.get("hint", "")).format(vars)})
	d.created_on = world.date.duplicate()
	d.expires_on = GameDate.add_days(world.date, int(def.get("expires_days", 7)))
	world.add("dilemmas", d)
	var cooldowns: Dictionary = org.office_state.get("cooldowns", {})
	cooldowns[def_id] = GameDate.add_days(world.date, int(def.get("cooldown_days", 0)))
	org.office_state.cooldowns = cooldowns
	return d


## Aplica a opção escolhida. `auto` = venceu o prazo sem resposta.
static func resolve(world: WorldState, d: Dilemma, option_id: String, auto: bool = false) -> Dictionary:
	if d == null or d.status != "open":
		return {"ok": false, "message": "Decisão já tomada.", "tone": "bad"}
	var def := definition(d.def_id)
	var option := {}
	for o: Dictionary in def.get("options", []):
		if o.id == option_id:
			option = o
	if option.is_empty():
		return {"ok": false, "message": "Opção inválida.", "tone": "bad"}
	var result := {"texts": [], "tone": "neutral"}
	_apply(world, d, option.get("effects", []), result)
	d.status = "expired" if auto else "resolved"
	d.choice = option_id
	d.resolved_on = world.date.duplicate()
	d.read = true
	var text := " ".join(result.texts) if not result.texts.is_empty() else "Decisão registrada."
	d.outcome = ("Sem resposta a tempo. " if auto else "") + text
	for id: String in d.staff_ids:
		var s: StaffMember = world.staff.get(id)
		if s:
			Office.log_history(world, s, "%s — %s" % [d.title, d.outcome])
	return {"ok": true, "message": d.outcome, "tone": result.tone}


# ------------------------------------------------------------------ efeitos

static func _apply(world: WorldState, d: Dilemma, effects: Array, result: Dictionary) -> void:
	var org := world.player_org()
	var vars := _vars(world, d)
	for e: Dictionary in effects:
		match str(e.op):
			"stat":
				for s: StaffMember in _who(world, d, str(e.get("who", "staff"))):
					var field := str(e.field)
					var cap := 100.0 if field != "trust" else 100.0
					var low := -100.0 if field == "trust" else 0.0
					s.set(field, clampf(float(s.get(field)) + float(e.delta), low, cap))
					if field == "morale" or field == "stress":
						if (field == "morale" and float(e.delta) > 0) or (field == "stress" and float(e.delta) < 0):
							result.tone = "good" if result.tone == "neutral" else result.tone
						else:
							result.tone = "bad"
			"salary":
				for s: StaffMember in _who(world, d, str(e.get("who", "staff"))):
					var target := int(d.context.get(str(e.get("to_ctx", "")), 0)) if e.has("to_ctx") else int(round(s.salary * (1.0 + float(e.get("pct", 0.0)))))
					s.salary = int(round(maxi(target, s.salary) / 50.0)) * 50
					s.last_raise_on = world.date.duplicate()
			"cash":
				var amount := float(d.context.get(str(e.amount_ctx), 0)) if e.has("amount_ctx") else float(e.get("amount", 0))
				amount *= float(e.get("mult", 1.0))
				var signed := int(round(amount)) * int(e.get("sign", 1))
				Office.ledger(world, org, "decision", signed, str(e.get("label", d.title)).format(vars))
				result.tone = "good" if signed > 0 else result.tone
			"reputation":
				OrgStanding.new().shift(world, org, float(e.delta))
			"relation":
				var people := _who(world, d, "pair")
				if people.size() == 2:
					Office._relate(world, people[0], people[1], float(e.delta))
			"team_bond":
				var team := Office.active_staff(world)
				for i in team.size():
					for j in range(i + 1, team.size()):
						Office._relate(world, team[i], team[j], float(e.delta))
			"vacation":
				for s: StaffMember in _who(world, d, str(e.get("who", "staff"))):
					s.status = "vacation"
					s.activity = "vacation"
					s.vacation_until = GameDate.add_days(world.date, int(e.days))
			"leave":
				for s: StaffMember in _who(world, d, str(e.get("who", "staff"))):
					var dest := str(d.context.get(str(e.get("destination_ctx", "")), ""))
					OfficeActions._leave(world, s, "Deixou a empresa." if dest.is_empty() else "Foi para " + world.organizations[dest].name + ".", dest)
					var topic := "staff_poached" if not dest.is_empty() else "staff_left"
					Media.new().story(world, topic, "staffleft:" + s.id, {"staff": s.full_name(), "role": Office.role_label(s.role), "org": org.name, "rival": world.organizations[dest].name if not dest.is_empty() else ""}, [org.id])
					for m: StaffMember in Office.active_staff(world):
						if str(m.relationships.get(s.id, {}).get("kind", "")) in ["friend", "mentor", "mentee"]:
							m.morale = maxf(0.0, m.morale - 10.0)
					result.tone = "bad"
			"deal":
				var value := float(d.context.get(str(e.value_ctx), 0.0)) if e.has("value_ctx") else float(e.get("value", 0.0))
				value *= float(e.get("mult", 1.0))
				var name := str(d.context.get(str(e.name_ctx), "")) if e.has("name_ctx") else str(e.get("name", ""))
				var until := GameDate.add_days(world.date, int(e.get("days", 30)))
				if e.has("until_ctx") and d.context.has(str(e.until_ctx)):
					until = d.context[str(e.until_ctx)]
				org.deals.append({"kind": str(e.kind), "name": name.format(vars), "value": snappedf(value, 0.001), "until": until})
				d.context.until = GameDate.format(until)
				vars = _vars(world, d)
				result.tone = "good" if value > 0 else "bad"
			"followup":
				var chance := float(e.get("chance", 0.0))
				if e.has("chance_stat"):
					var s: StaffMember = world.staff.get(d.staff_ids[0]) if not d.staff_ids.is_empty() else null
					if s:
						chance = float(s.get(str(e.chance_stat.field))) * float(e.chance_stat.scale)
				if world.office_rng.chance(clampf(chance, 0.0, 1.0)):
					var days: Array = e.get("days", [7, 14])
					var queue: Array = org.office_state.get("followups", [])
					var ctx := d.context.duplicate(true)
					ctx.staff_ids = d.staff_ids.duplicate()
					ctx.fighter_ids = d.fighter_ids.duplicate()
					queue.append({"event": str(e.event), "due": GameDate.add_days(world.date, world.office_rng.range_i(int(days[0]), int(days[1]))), "context": ctx})
					org.office_state.followups = queue
			"roll":
				var p := float(e.get("base", 0.5))
				var s: StaffMember = world.staff.get(d.staff_ids[0]) if not d.staff_ids.is_empty() else null
				for stat: String in e.get("stats", {}):
					if s:
						p += float(s.get(stat)) * float(e.stats[stat])
				for role: String in e.get("role_bonus", {}):
					var info: Dictionary = Office.config().roles.get(role, {})
					var eff := Office.effect(world, org.id, role) / maxf(0.001, float(info.get("max_effect", 1.0)))
					p += eff * 0.25 * float(e.role_bonus[role])
				var ok := world.office_rng.chance(clampf(p, 0.05, 0.95))
				_apply(world, d, e.success if ok else e.fail, result)
				result.tone = "good" if ok else "bad"
			"promote":
				for s: StaffMember in _who(world, d, "staff"):
					var r := OfficeActions.perform(world, "promote", {"staff_id": s.id})
					if not r.ok:
						s.morale = maxf(0.0, s.morale - 6.0)
						result.texts.append(r.message + " A promoção ficou só na promessa.")
						result.tone = "bad"
					else:
						result.texts.append(r.message)
						result.tone = "good"
			"hire":
				for s: StaffMember in _who(world, d, "staff"):
					var r := OfficeActions.perform(world, "hire", {"staff_id": s.id})
					result.texts.append(r.message)
					result.tone = r.tone
			"interview":
				for s: StaffMember in _who(world, d, "staff"):
					s.interviewed = true
			"candidates":
				var role := str(d.context.get(str(e.role_ctx), "matchmaker"))
				for i in int(e.get("count", 1)):
					var c := Office.generate(world, role)
					c.expires_on = GameDate.add_days(world.date, 21)
			"release_fighter":
				for id: String in d.fighter_ids:
					release_fighter(world, id)
			"promise_fighter":
				var promises: Dictionary = org.office_state.get("promises", {})
				for id: String in d.fighter_ids:
					promises[id] = {"since": world.date.duplicate(), "due": GameDate.add_days(world.date, int(e.days))}
				org.office_state.promises = promises
				d.context.until = GameDate.format(GameDate.add_days(world.date, int(e.days)))
				vars = _vars(world, d)
			"fighter_heat":
				for id: String in d.fighter_ids:
					var f: Fighter = world.fighters.get(id)
					var agent: Agent = world.agents.get(f.agent_id) if f else null
					if agent:
						agent.relationship[org.id] = clampi(int(agent.relationship.get(org.id, 0)) + int(e.delta) * 3, -100, 100)
				result.tone = "bad"
			"shortlist":
				var list: Array = org.office_state.get("shortlist", [])
				for id: String in d.context.get("prospect_ids", []):
					if id not in list:
						list.append(id)
				org.office_state.shortlist = list.slice(maxi(0, list.size() - 12))
			"popularity":
				for id: String in d.fighter_ids:
					var f: Fighter = world.fighters.get(id)
					if f:
						for region: String in f.popularity_by_region.keys():
							f.popularity_by_region[region] = clampi(int(f.popularity_by_region[region]) + int(e.delta), 0, 100)
				result.tone = "good"
			"news":
				Media.new().story(world, str(e.topic), "%s:%s" % [e.topic, d.id], vars.merged({"org": org.name}), [org.id])
			"text":
				result.texts.append(str(e.value).format(_vars(world, d)))


static func release_fighter(world: WorldState, id: String) -> void:
	var f: Fighter = world.fighters.get(id)
	if f == null:
		return
	var org := world.player_org()
	var c: Contract = world.contracts.get(f.contract_id)
	if c:
		c.active = false
	org.roster.erase(f.id)
	f.organization_id = ""
	Rankings.new().update(world, org.id, f.division)


static func _who(world: WorldState, d: Dilemma, who: String) -> Array:
	var ids: Array = d.staff_ids
	match who:
		"staff":
			return [world.staff[ids[0]]] if ids.size() >= 1 and world.staff.has(ids[0]) else []
		"other":
			return [world.staff[ids[1]]] if ids.size() >= 2 and world.staff.has(ids[1]) else []
		"pair":
			return [world.staff[ids[0]], world.staff[ids[1]]] if ids.size() >= 2 and world.staff.has(ids[0]) and world.staff.has(ids[1]) else []
		"team":
			return Office.active_staff(world)
	return []


static func _vars(world: WorldState, d: Dilemma) -> Dictionary:
	var v := {}
	for k in d.context:
		if typeof(d.context[k]) in [TYPE_STRING, TYPE_INT, TYPE_FLOAT]:
			v[k] = d.context[k]
	if d.staff_ids.size() >= 1 and world.staff.has(d.staff_ids[0]):
		var s: StaffMember = world.staff[d.staff_ids[0]]
		v.staff = s.full_name()
		v.role = Office.role_label(s.role)
		v.salary = OfficeActions._money(s.salary)
		v.asking = OfficeActions._money(s.asking_salary)
	if d.staff_ids.size() >= 2 and world.staff.has(d.staff_ids[1]):
		v.other = world.staff[d.staff_ids[1]].full_name()
	if not d.fighter_ids.is_empty() and world.fighters.has(d.fighter_ids[0]):
		v.fighter = world.fighters[d.fighter_ids[0]].display_name()
	for k: String in ["market_value", "offer_value", "amount_value", "salary_value", "team_bonus", "cash_value", "payroll_value", "margin_value"]:
		if d.context.has(k):
			v[k.trim_suffix("_value")] = OfficeActions._money(int(d.context[k]))
	if d.context.has("pct_value"):
		v.pct = int(round(float(d.context.pct_value) * 100))
	if d.context.has("role_id"):
		v.role = Office.role_label(str(d.context.role_id))
	return v


# ------------------------------------------------------------------ pré-condições

## Devolve o contexto do fato (pessoas, valores) ou {} se não é verdade hoje.
static func _requirement(world: WorldState, key: String, given: Dictionary) -> Dictionary:
	var org := world.player_org()
	var team := Office.active_staff(world)
	match key:
		"followup_only":
			return given
		"underpaid_ambitious":
			var best: StaffMember = null
			for s: StaffMember in team:
				if s.status != "active" or s.ambition < 55 or s.skill < 48:
					continue
				var market := Office.market_salary(s.role, s.level, s.skill)
				var last := s.last_raise_on if not s.last_raise_on.is_empty() else s.hired_on
				if s.salary < market * 0.97 and GameDate.days_between(last, world.date) > 120:
					if best == null or s.ambition > best.ambition:
						best = s
			if best:
				var mv := Office.market_salary(best.role, best.level, best.skill)
				return {"staff_ids": [best.id], "market_value": int(round(mv * 1.04 / 50.0)) * 50, "salary_value": best.salary}
		"poach_target":
			var rivals := _rivals(world)
			if rivals.is_empty():
				return {}
			for s: StaffMember in team:
				if s.status == "active" and s.skill >= 58 and (s.morale < 55 or s.ambition > 72):
					return _poach_ctx(world, s, rivals)
			if not given.get("staff_ids", []).is_empty():
				var s: StaffMember = world.staff.get(given.staff_ids[0])
				if s and s.is_active():
					return _poach_ctx(world, s, rivals)
		"burning_out":
			for s: StaffMember in team:
				if s.status == "active" and s.stress >= 80:
					var ctx := {"staff_ids": [s.id]}
					for o: StaffMember in team:
						if o.id != s.id and o.status == "active" and Office.department(o.role) == Office.department(s.role) and o.stress < 60:
							ctx.staff_ids.append(o.id)
							break
					return ctx
		"rival_pair":
			for s: StaffMember in team:
				for id: String in s.relationships:
					var o: StaffMember = world.staff.get(id)
					if o and o.is_active() and s.id < o.id and float(s.relationships[id].value) <= -40:
						return {"staff_ids": [s.id, o.id]}
		"mentor_pair":
			for s: StaffMember in team:
				if "mentor" not in s.traits:
					continue
				for o: StaffMember in team:
					if o.id != s.id and Office.department(o.role) == Office.department(s.role) and o.skill + 12 < s.skill and str(s.relationships.get(o.id, {}).get("kind", "")) != "mentor":
						return {"staff_ids": [s.id, o.id]}
		"announced_event_soon":
			for ev: FightEvent in world.events.values():
				var days := GameDate.days_between(world.date, ev.date)
				if ev.organization_id == org.id and ev.status == "announced" and days >= 5 and days <= 40:
					var brands: Array = Office.config().sponsors
					var amount := int(round((12000 + org.reputation * 700 + ev.fight_ids.size() * 1500) * world.office_rng.range_f(0.8, 1.25) / 500.0)) * 500
					return {"event": ev.name, "event_id": ev.id, "brand": str(world.office_rng.pick(brands)), "amount_value": amount}
		"broadcaster_ready":
			if org.reputation < 22:
				return {}
			for deal: Dictionary in org.deals:
				if deal.kind == "media":
					return {}
			return {"brand": str(world.office_rng.pick(Office.config().broadcasters)), "pct_value": snappedf(world.office_rng.range_f(0.15, 0.3), 0.01)}
		"inactive_fighter":
			var promises: Dictionary = org.office_state.get("promises", {})
			var booked := _booked(world)
			for id: String in org.roster:
				var f: Fighter = world.fighters.get(id)
				if f == null or booked.has(id) or promises.has(id) or not f.injuries.is_empty():
					continue
				var c: Contract = world.contracts.get(f.contract_id)
				var since: Dictionary = f.last_fight_on if not f.last_fight_on.is_empty() else (c.signed_on if c else world.date)
				var days := GameDate.days_between(since, world.date)
				if days >= 150:
					return {"fighter_ids": [id], "days": days}
		"no_downturn":
			for deal: Dictionary in org.deals:
				if deal.kind in ["attendance", "ticket_price"]:
					return {}
			return {"market": true}
		"profitable_night":
			for ev: FightEvent in world.events.values():
				if ev.organization_id == org.id and ev.status == "completed" and not ev.actual.is_empty() and int(ev.actual.margin) > 0:
					var days := GameDate.days_between(ev.date, world.date)
					if days >= 0 and days <= 3:
						var bonus := 0
						for s: StaffMember in team:
							bonus += int(s.salary * 0.1)
						return {"event": ev.name, "margin_value": int(ev.actual.margin), "team_bonus": bonus}
		"standout_candidate":
			for s: StaffMember in Office.candidates(world):
				if s.potential >= 78 and not s.interviewed and s.skill >= 50:
					return {"staff_ids": [s.id]}
		"cash_crunch":
			var pay := Office.payroll(world)
			if pay > 0 and org.cash < pay * 2:
				return {"cash_value": org.cash, "payroll_value": pay}
		"campaign_window":
			for s: StaffMember in team:
				if s.status != "active" or s.role not in ["marketing", "media"] or (s.skill < 60 and "creative" not in s.traits):
					continue
				for ev: FightEvent in world.events.values():
					var days := GameDate.days_between(world.date, ev.date)
					if ev.organization_id == org.id and ev.status == "announced" and days >= 10 and days <= 45:
						return {"staff_ids": [s.id], "event": ev.name, "event_id": ev.id, "event_date": ev.date.duplicate()}
		"scout_prospects":
			var scout: StaffMember = null
			for s: StaffMember in team:
				if s.status == "active" and s.role == "scout" and (scout == null or s.skill > scout.skill):
					scout = s
			if scout == null:
				return {}
			var pool: Array = []
			for f: Fighter in world.fighters.values():
				if f.organization_id.is_empty() and not f.retired and f.age_on(world.date) <= 27:
					pool.append(f)
			# Olheiro bom enxerga o potencial; ruim erra (ruído proporcional).
			var noise := (100.0 - scout.skill) * 0.25
			pool.sort_custom(func(a: Fighter, b: Fighter): return float(a.potential.mean) + noise * sin(a.id.hash()) > float(b.potential.mean) + noise * sin(b.id.hash()))
			var picks := pool.slice(0, 3)
			if picks.size() < 3:
				return {}
			return {"staff_ids": [scout.id], "prospect_ids": picks.map(func(f: Fighter): return f.id), "prospects": ", ".join(picks.map(func(f: Fighter): return "%s (%s)" % [f.display_name(), f.record_string()]))}
		"press_target":
			var media: StaffMember = null
			for s: StaffMember in team:
				if s.status == "active" and s.role in ["media", "marketing"]:
					media = s
			if media == null:
				return {}
			var best: Fighter = null
			for id: String in org.roster:
				var f: Fighter = world.fighters.get(id)
				if f and (best == null or f.record.wins > best.record.wins):
					best = f
			if best:
				return {"staff_ids": [media.id], "fighter_ids": [best.id]}
		"finance_idea":
			for s: StaffMember in team:
				if s.status == "active" and s.role == "finance" and s.skill >= 58:
					for deal: Dictionary in org.deals:
						if deal.kind == "costs":
							return {}
					return {"staff_ids": [s.id]}
		"missing_role":
			var has := {}
			for s: StaffMember in team:
				has[s.role] = true
			var impact := {"matchmaker": "Menos atletas aceitam as lutas propostas.", "marketing": "Público e patrocínio das noites caem.", "medical": "Lutadores demoram mais para voltar de suspensões."}
			for role: String in impact:
				if not has.has(role):
					return {"role_id": role, "impact": impact[role]}
	return {}


static func _poach_ctx(world: WorldState, s: StaffMember, rivals: Array) -> Dictionary:
	var rival: Organization = rivals[world.office_rng.range_i(0, rivals.size() - 1)]
	return {"staff_ids": [s.id], "rival": rival.name, "rival_id": rival.id, "offer_value": int(round(s.salary * world.office_rng.range_f(1.2, 1.4) / 50.0)) * 50, "salary_value": s.salary}


static func _rivals(world: WorldState) -> Array:
	var out: Array = []
	for o: Organization in world.organizations.values():
		if o.id != world.player_org_id:
			out.append(o)
	out.sort_custom(func(a: Organization, b: Organization): return a.id < b.id)
	return out


static func _booked(world: WorldState) -> Dictionary:
	var out := {}
	for ev: FightEvent in world.events.values():
		if ev.status in ["planned", "announced"]:
			for id: String in ev.fight_ids:
				var fight: Fight = world.fights[id]
				if fight.status == "booked":
					out[fight.fighter_a_id] = true
					out[fight.fighter_b_id] = true
	return out


## Promessas de luta: cumprida → confiança do empresário sobe; vencida → cobra.
static func _check_promises(world: WorldState, org: Organization) -> void:
	var promises: Dictionary = org.office_state.get("promises", {})
	if promises.is_empty():
		return
	var booked := _booked(world)
	for id: String in promises.keys():
		var p: Dictionary = promises[id]
		var f: Fighter = world.fighters.get(id)
		if f == null or f.organization_id != org.id:
			promises.erase(id)
			continue
		var fought := not f.last_fight_on.is_empty() and GameDate.days_between(p.since, f.last_fight_on) >= 0
		if fought or booked.has(id):
			if fought:
				promises.erase(id)
				var agent: Agent = world.agents.get(f.agent_id)
				if agent:
					agent.relationship[org.id] = clampi(int(agent.relationship.get(org.id, 0)) + 6, -100, 100)
			continue
		if GameDate.days_between(world.date, p.due) < 0:
			promises.erase(id)
			var queue: Array = org.office_state.get("followups", [])
			queue.append({"event": "promise_broken", "due": world.date.duplicate(), "context": {"fighter_ids": [id]}})
			org.office_state.followups = queue
	org.office_state.promises = promises
