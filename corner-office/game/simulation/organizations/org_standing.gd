class_name OrgStanding
extends RefCounted
## Progressão das promotoras (Game Design Bible §3, §12 "Expansão regional",
## §13; MMA Bible §19, §26). Reputação sobe ou cai com a qualidade de cada
## noite (público, resultado financeiro, apelo do card), esfria sem eventos e
## define o patamar (regional → nacional → global), que muda arenas, mídia e
## patrocínio. O jogador recebe metas por temporada; o balanço anual vira
## notícia. Parâmetros em content/world_tuning.json.

const TIER_ORDER := ["regional", "national", "global"]

var _cfg: Dictionary = {}


func _init() -> void:
	_cfg = ContentDB.load_json("world_tuning.json")


# ---------------------------------------------------------------- reputação

static func exact(org: Organization) -> float:
	return org.reputation_exact if org.reputation_exact >= 0.0 else float(org.reputation)


func tier_for(reputation: float, current: String) -> String:
	var s: Dictionary = _cfg.standing
	var idx := maxi(0, TIER_ORDER.find(current))
	while idx < TIER_ORDER.size() - 1 and reputation >= float(s.tiers[TIER_ORDER[idx + 1]]):
		idx += 1
	while idx > 0 and reputation < float(s.tiers[TIER_ORDER[idx]]) - float(s.hysteresis):
		idx -= 1
	return TIER_ORDER[idx]


func shift(world: WorldState, org: Organization, delta: float) -> void:
	org.reputation_exact = clampf(exact(org) + delta, 0.0, 100.0)
	org.reputation = roundi(org.reputation_exact)
	var tier := tier_for(org.reputation_exact, org.tier)
	if tier == org.tier:
		return
	var up := TIER_ORDER.find(tier) > TIER_ORDER.find(org.tier)
	org.tier = tier
	EventBus.organization_tier_changed.emit(org.id, tier)
	LifeCycle.story(world, "organization_tier", "tier_up" if up else "tier_down", {"organization": org.name, "tier": _cfg.labels.tiers.get(tier, tier), "reputation": org.reputation}, [org.id])


## Nota 0–100 da noite; a reputação caminha em direção a ela.
func event_score(world: WorldState, ev: FightEvent) -> float:
	# Público é medido contra a arena de uma promoção global: lotar um ginásio
	# regional ajuda, mas não basta para virar potência.
	var reference := float(ContentDB.load_json("career_tuning.json").event.capacity) * float(_cfg.tier_economy.global.capacity)
	var fame := 0.0
	var athletes := 0
	for id: String in ev.fight_ids:
		var fight: Fight = world.fights[id]
		for fighter_id: String in [fight.fighter_a_id, fight.fighter_b_id]:
			fame += float(world.fighters[fighter_id].popularity_by_region.get(ev.region, 0.0))
			athletes += 1
	var att := clampf(float(ev.actual.get("attendance", 0)) / reference, 0.0, 1.0)
	var margin := clampf(.5 + float(ev.actual.get("margin", 0)) / maxf(1.0, float(ev.actual.get("costs", 1))), 0.0, 1.0)
	var star := clampf(fame / maxf(1.0, athletes) / 40.0, 0.0, 1.0)
	return 45.0 * att + 30.0 * margin + 25.0 * star


func after_event(world: WorldState, ev: FightEvent) -> void:
	if ev.actual.is_empty():
		return
	var s: Dictionary = _cfg.standing
	var org: Organization = world.organizations[ev.organization_id]
	var rate := float(s.event_rate if org.id == world.player_org_id else s.rival_event_rate)
	var delta := clampf((event_score(world, ev) - exact(org)) * rate, -float(s.event_max_delta), float(s.event_max_delta))
	ev.actual.reasons.append(Reason.make("REPUTATION_CHANGE", delta, {"score": event_score(world, ev)}))
	shift(world, org, delta)
	if not ev.region.is_empty():
		org.market_popularity[ev.region] = minf(100.0, float(org.market_popularity.get(ev.region, 0.0)) + float(s.market_gain))


# ---------------------------------------------------------------- mês e temporada

func monthly(world: WorldState) -> void:
	var s: Dictionary = _cfg.standing
	var last := {}
	for ev: FightEvent in world.events.values():
		if ev.status != "completed":
			continue
		if not last.has(ev.organization_id) or GameDate.days_between(last[ev.organization_id], ev.date) > 0:
			last[ev.organization_id] = ev.date
	for org: Organization in world.organizations.values():
		var since: Dictionary = last.get(org.id, GameDate.START)
		if GameDate.days_between(since, world.date) > int(s.idle_days):
			shift(world, org, -float(s.idle_penalty))
		if org.cash < 0:
			shift(world, org, -float(s.negative_cash_penalty))
		for region: String in org.market_popularity.keys():
			org.market_popularity[region] = maxf(0.0, float(org.market_popularity[region]) - float(s.market_decay))
		org.standing_history.append({"date": world.date.duplicate(), "reputation": org.reputation, "tier": org.tier, "cash": org.cash, "roster": org.roster.size()})
	if int(world.date.month) == 1:
		close_season(world, int(world.date.year) - 1)
	ensure_objectives(world)


func ensure_objectives(world: WorldState) -> void:
	var org := world.player_org()
	if org == null:
		return
	var season := int(world.date.year)
	if not org.objectives.is_empty() and int(org.objectives[0].season) == season:
		return
	var goals: Dictionary = _cfg.season.goals[org.tier]
	org.objectives = [
		{"id": "events", "target": int(goals.events), "season": season},
		{"id": "profit", "target": int(goals.profit), "season": season},
		{"id": "reputation", "target": mini(100, org.reputation + int(goals.reputation_gain)), "season": season},
		{"id": "signings", "target": int(goals.signings), "season": season},
	]


static func progress(world: WorldState, org: Organization, objective: Dictionary) -> int:
	var season := int(objective.season)
	match str(objective.id):
		"events", "profit":
			var count := 0
			var profit := 0
			for ev: FightEvent in world.events.values():
				if ev.organization_id == org.id and ev.status == "completed" and int(ev.date.year) == season:
					count += 1
					profit += int(ev.actual.get("margin", 0))
			return count if objective.id == "events" else profit
		"reputation":
			return org.reputation
		"signings":
			var n := 0
			for c: Contract in world.contracts.values():
				if c.organization_id == org.id and not c.signed_on.is_empty() and int(c.signed_on.year) == season and c.signed_on != GameDate.START:
					n += 1
			return n
	return 0


## Lucro só conta se houve ao menos uma noite no ano.
static func is_done(world: WorldState, org: Organization, objective: Dictionary) -> bool:
	if str(objective.id) == "profit" and progress(world, org, {"id": "events", "season": objective.season}) == 0:
		return false
	return progress(world, org, objective) >= int(objective.target)


## Metas da temporada com progresso e texto pronto para a UI.
static func objective_view(world: WorldState) -> Array:
	var org := world.player_org()
	var labels: Dictionary = ContentDB.load_json("world_tuning.json").labels.goals
	var out: Array = []
	for o: Dictionary in org.objectives:
		var value := progress(world, org, o)
		out.append({"id": o.id, "season": o.season, "target": o.target, "progress": value, "done": is_done(world, org, o), "label": str(labels.get(o.id, o.id)).format({"target": o.target})})
	return out


func close_season(world: WorldState, season: int) -> void:
	var org := world.player_org()
	if org == null or org.objectives.is_empty() or int(org.objectives[0].season) != season:
		return
	for review: Dictionary in org.season_reviews:
		if int(review.season) == season:
			return
	var cfg: Dictionary = _cfg.season
	var done := 0
	for o: Dictionary in org.objectives:
		if is_done(world, org, o):
			done += 1
	var rep_delta := done * float(cfg.reward_reputation) - (float(cfg.failure_penalty) if done == 0 else 0.0)
	var cash := done * int(cfg.reward_cash.get(org.tier, 0))
	var before := org.reputation
	org.cash += cash
	shift(world, org, rep_delta)
	org.season_reviews.append({"season": season, "done": done, "total": org.objectives.size(), "reputation_delta": org.reputation - before, "cash": cash, "objectives": org.objectives.duplicate(true)})
	var top: Array = league_table(world).slice(0, 3).map(func(row: Dictionary): return row.short_name)
	LifeCycle.story(world, "season_review", "season", {"season": season, "organization": org.name, "done": done, "total": org.objectives.size(), "reputation_delta": "%+d" % (org.reputation - before), "cash": "US$ %d" % cash, "top": ", ".join(top)}, [org.id])
	EventBus.season_closed.emit(season)


## Quadro das promotoras por reputação, com tendência de 12 meses.
static func league_table(world: WorldState) -> Array:
	var rows: Array = []
	for org: Organization in world.organizations.values():
		var trend := 0
		if org.standing_history.size() >= 2:
			trend = org.reputation - int(org.standing_history[maxi(0, org.standing_history.size() - 13)].reputation)
		rows.append({"id": org.id, "name": org.name, "short_name": org.short_name, "tier": org.tier, "reputation": org.reputation, "trend": trend, "roster": org.roster.size(), "cash": org.cash, "is_player": org.id == world.player_org_id})
	rows.sort_custom(func(a, b): return a.reputation > b.reputation if a.reputation != b.reputation else a.id < b.id)
	return rows
