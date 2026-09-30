class_name OrgAI
extends RefCounted
## Organizações rivais como agentes autônomos (Game Design Bible §3, §19;
## MMA Bible §19, §26). Cada rival agenda noites, monta cards pelo mesmo
## Matchmaking do jogador, contrata agentes livres e reage a adiamentos.
##
## Regras de informação: a IA só usa dados públicos (cartel, ranking oficial,
## popularidade). Atributos técnicos e ocultos nunca entram nas decisões.
## Estado persistente fica em Organization.ai_state (serializável).

var _cfg: Dictionary = {}
var _bids: Dictionary = {}
var matchmaking := Matchmaking.new()
var economy := Economy.new()
var contracts := Contracts.new()


func _init() -> void:
	_cfg = ContentDB.load_json("career_tuning.json").rival_ai
	_bids = ContentDB.load_json("world_tuning.json").rival_bids


## Chamado uma vez por dia pelo WorldSim, depois dos eventos do dia.
func tick(world: WorldState) -> void:
	for org: Organization in world.organizations.values():
		if org.is_player or org.id == world.player_org_id:
			continue
		_handle_postponed(world, org)
		_renew_contracts(world, org)
		_maybe_sign(world, org)
		_bid_for_player_athletes(world, org)
		_maybe_schedule(world, org)


static func upcoming(world: WorldState, org_id: String) -> Array:
	var out: Array = []
	for ev: FightEvent in world.events.values():
		if ev.organization_id == org_id and ev.status in ["planned", "announced"]:
			out.append(ev)
	return out


func reserved_cash(world: WorldState, org: Organization) -> int:
	var total := 0
	for ev: FightEvent in upcoming(world, org.id):
		if ev.status == "announced":
			total += int(ev.projected.get("costs", 0))
	return total


# ---------------------------------------------------------------- agenda

func _cadence_days(org: Organization) -> Array:
	var base: Array = _cfg.cadence_days.default
	for kind: String in org.executive_traits:
		if _cfg.cadence_days.has(kind):
			base = _cfg.cadence_days[kind]
	return base


func _maybe_schedule(world: WorldState, org: Organization) -> void:
	if not upcoming(world, org.id).is_empty():
		return
	var next_after: Dictionary = org.ai_state.get("next_event_after", {})
	if not next_after.is_empty() and GameDate.days_between(world.date, next_after) > 0:
		return
	var cadence := _cadence_days(org)
	if org.cash - reserved_cash(world, org) < int(_cfg.minimum_cash_reserve):
		org.ai_state.next_event_after = GameDate.add_days(world.date, int(cadence[1]))
		return
	var ev := FightEvent.new()
	ev.id = world.new_id("event")
	ev.organization_id = org.id
	org.event_count += 1
	ev.name = "%s %d" % [org.short_name, org.event_count]
	ev.date = GameDate.add_days(world.date, world.rng.range_i(int(_cfg.notice_days[0]), int(_cfg.notice_days[1])))
	ev.venue = str(_cfg.venue)
	ev.city = org.base_city
	ev.country = org.base_country
	ev.region = _region_of(org.base_country)
	world.add("events", ev)
	_build_card(world, org, ev)
	if ev.fight_ids.size() < int(_cfg.minimum_bouts):
		_cancel(world, ev, "CARD_TOO_SMALL")
		org.event_count -= 1
		org.ai_state.next_event_after = GameDate.add_days(world.date, int(_cfg.retry_days))
		return
	_announce(world, org, ev)
	org.ai_state.next_event_after = GameDate.add_days(ev.date, world.rng.range_i(int(cadence[0]), int(cadence[1])))


func _announce(world: WorldState, org: Organization, ev: FightEvent) -> void:
	# Corta os confrontos menos comerciais até o card caber no caixa.
	ev.projected = economy.project_event(world, ev)
	while ev.fight_ids.size() > int(_cfg.minimum_bouts) and org.cash - reserved_cash(world, org) < int(ev.projected.costs):
		var dropped: Fight = world.fights[ev.fight_ids[0]]
		dropped.status = "cancelled"
		dropped.reasons.append(Reason.make("BUDGET_CUT"))
		ev.fight_ids.remove_at(0)
		ev.projected = economy.project_event(world, ev)
	if org.cash - reserved_cash(world, org) < int(ev.projected.costs):
		_cancel(world, ev, "INSUFFICIENT_CASH")
		return
	for i in ev.fight_ids.size():
		world.fights[ev.fight_ids[i]].card_slot = "main_event" if i == ev.fight_ids.size() - 1 else "co_main" if i == ev.fight_ids.size() - 2 else "main_card" if i >= 2 else "prelims"
	ev.status = "announced"


func _cancel(world: WorldState, ev: FightEvent, code: String) -> void:
	for id: String in ev.fight_ids:
		var f: Fight = world.fights[id]
		if f.status == "booked":
			f.status = "cancelled"
			f.reasons.append(Reason.make(code))
	ev.status = "cancelled"


func _handle_postponed(world: WorldState, org: Organization) -> void:
	for ev: FightEvent in world.events.values():
		if ev.organization_id != org.id or ev.status != "postponed":
			continue
		var new_date := GameDate.add_days(world.date, int(_cfg.reschedule_days))
		ev.date = new_date
		ev.status = "planned"
		var kept: Array = []
		for id: String in ev.fight_ids:
			var f: Fight = world.fights[id]
			if f.status != "booked":
				continue
			if matchmaking.evaluate(world, f.fighter_a_id, f.fighter_b_id, ev.id, 1.0, f.id).eligible:
				kept.append(id)
			else:
				f.status = "cancelled"
				f.reasons.append(Reason.make("REPLACED_AFTER_POSTPONEMENT"))
		ev.fight_ids = kept
		_build_card(world, org, ev)
		if ev.fight_ids.size() < int(_cfg.minimum_bouts):
			_cancel(world, ev, "CARD_TOO_SMALL")
		else:
			_announce(world, org, ev)


# ---------------------------------------------------------------- matchmaking

## Ordem pública da divisão: ranking oficial da organização, ou cartel.
func _public_order(world: WorldState, org: Organization, division: String, pool: Array) -> Array:
	var ranking := Rankings.new().latest(world, org.id, division)
	var position := {}
	if ranking:
		for i in ranking.entries.size():
			position[ranking.entries[i]] = i
	var star := "star_first" in org.executive_traits or "spectacle_first" in org.executive_traits
	var ordered := pool.duplicate()
	ordered.sort_custom(func(a: Fighter, b: Fighter) -> bool:
		if star:
			var fa := _fame(a); var fb := _fame(b)
			if fa != fb: return fa > fb
		var pa: int = position.get(a.id, 999); var pb: int = position.get(b.id, 999)
		if pa != pb: return pa < pb
		if a.record.wins != b.record.wins: return a.record.wins > b.record.wins
		return a.id < b.id)
	return ordered


static func _fame(f: Fighter) -> float:
	var best := 0.0
	for v in f.popularity_by_region.values():
		best = maxf(best, float(v))
	return best + f.charisma * .15


static func _last_opponent(world: WorldState, f: Fighter) -> String:
	if f.fight_ids.is_empty():
		return ""
	var last: Fight = world.fights.get(f.fight_ids[-1])
	if last == null:
		return ""
	return last.fighter_b_id if last.fighter_a_id == f.id else last.fighter_a_id


func _build_card(world: WorldState, org: Organization, ev: FightEvent) -> void:
	var used := {}
	for id: String in ev.fight_ids:
		var f: Fight = world.fights[id]
		used[f.fighter_a_id] = true
		used[f.fighter_b_id] = true
	var by_division := {}
	for id: String in org.roster:
		var f: Fighter = world.fighters[id]
		if used.has(f.id) or f.retired:
			continue
		if not by_division.has(f.division):
			by_division[f.division] = []
		by_division[f.division].append(f)
	var divisions := by_division.keys()
	divisions.sort()
	var candidates: Array = []
	for division: String in divisions:
		var ordered := _public_order(world, org, division, by_division[division])
		var taken := {}
		for i in ordered.size():
			var a: Fighter = ordered[i]
			if taken.has(a.id):
				continue
			for j in range(i + 1, mini(ordered.size(), i + 4)):
				var b: Fighter = ordered[j]
				if taken.has(b.id) or _last_opponent(world, a) == b.id:
					continue
				var quote := matchmaking.evaluate(world, a.id, b.id, ev.id)
				if not quote.eligible:
					continue
				candidates.append({"a": a.id, "b": b.id, "commercial": quote.commercial_fit + quote.sporting_fit * .25})
				taken[a.id] = true
				taken[b.id] = true
				break
	candidates.sort_custom(func(x, y): return x.commercial < y.commercial if x.commercial != y.commercial else x.a < y.a)
	var max_bouts := int(_cfg.maximum_bouts)
	# Os pares mais comerciais ficam; o card é ordenado do prelim ao main event.
	candidates = candidates.slice(maxi(0, candidates.size() - (max_bouts - ev.fight_ids.size())))
	for c: Dictionary in candidates:
		for premium: float in [1.0, float(_cfg.counter_premium)]:
			var fight := Fight.new()
			fight.event_id = ev.id
			fight.fighter_a_id = c.a
			fight.fighter_b_id = c.b
			fight.division = world.fighters[c.a].division
			fight.reasons = [Reason.make("PURSE_OFFER", premium)]
			var response := matchmaking.propose(world, fight)
			if response.outcome == "accepted" or response.outcome == "refused":
				break


# ---------------------------------------------------------------- free agency

## Renova quem está no fim do contrato (última luta ou prazo curto). Atletas em
## má fase são liberados; o atleta também pode recusar e virar agente livre.
func _renew_contracts(world: WorldState, org: Organization) -> void:
	var cfg_c: Dictionary = ContentDB.load_json("career_tuning.json").contracts
	for id: String in org.roster.duplicate():
		var f: Fighter = world.fighters[id]
		var c: Contract = world.contracts.get(f.contract_id)
		if c == null or not c.active or f.retired:
			continue
		if c.bouts_remaining > 1 and GameDate.days_between(world.date, c.expires_on) > int(_cfg.renewal_window_days):
			continue
		if c.ai_renewal_tried:
			continue
		c.ai_renewal_tried = true
		if f.record.losses >= f.record.wins + int(_cfg.release_loss_margin):
			continue
		var offer := Contract.new()
		offer.fighter_id = f.id
		offer.organization_id = org.id
		offer.show_money = maxi(c.show_money, Contracts.market_price(world, f))
		offer.win_bonus = int(offer.show_money * float(cfg_c.win_bonus_ratio))
		offer.bouts_total = int(cfg_c.bouts)
		offer.bouts_remaining = offer.bouts_total + c.bouts_remaining
		offer.bouts_total = offer.bouts_remaining
		offer.expires_on = GameDate.add_days(world.date, int(cfg_c.term_days))
		var response := contracts.evaluate_offer(world, offer)
		if response.eligible and world.rng.chance(float(response.accept_probability)):
			contracts.sign(world, offer)


func _maybe_sign(world: WorldState, org: Organization) -> void:
	var next_after: Dictionary = org.ai_state.get("next_signing_after", {})
	if not next_after.is_empty() and GameDate.days_between(world.date, next_after) > 0:
		return
	org.ai_state.next_signing_after = GameDate.add_days(world.date, int(_cfg.signing_interval_days))
	var target := int(_cfg.roster_target) + (4 if "aggressive_buyer" in org.executive_traits else 0)
	if org.roster.size() >= target or org.cash - reserved_cash(world, org) < int(_cfg.minimum_cash_reserve):
		return
	# Divisão com número ímpar ou menor de atletas é a necessidade mais urgente.
	var counts := {}
	for id: String in org.roster:
		var d: String = world.fighters[id].division
		counts[d] = int(counts.get(d, 0)) + 1
	var best: Fighter = null
	var best_score := -INF
	for f: Fighter in world.fighters.values():
		if not f.organization_id.is_empty() or f.retired:
			continue
		var need: float = 3.0 if int(counts.get(f.division, 0)) % 2 == 1 else 1.0 if counts.has(f.division) else 0.5
		var score: float = need * 10 + f.record.wins - f.record.losses * .5 + _fame(f) * .1
		if "prospect_first" in org.executive_traits:
			score -= (f.record.wins + f.record.losses) * .6
		if score > best_score or (score == best_score and best != null and f.id < best.id):
			best = f
			best_score = score
	if best == null:
		return
	var cfg_c: Dictionary = ContentDB.load_json("career_tuning.json").contracts
	var offer := Contract.new()
	offer.fighter_id = best.id
	offer.organization_id = org.id
	var premium: float = float(_cfg.aggressive_premium) if "aggressive_buyer" in org.executive_traits else 1.0
	offer.show_money = int(Contracts.market_price(world, best) * premium)
	offer.win_bonus = int(offer.show_money * float(cfg_c.win_bonus_ratio))
	offer.bouts_total = int(cfg_c.bouts)
	offer.bouts_remaining = offer.bouts_total
	offer.expires_on = GameDate.add_days(world.date, int(cfg_c.term_days))
	var response := contracts.evaluate_offer(world, offer)
	if response.eligible and world.rng.chance(float(response.accept_probability)):
		contracts.sign(world, offer)
		org.ai_state.signings = int(org.ai_state.get("signings", 0)) + 1
		Rankings.new().update(world, org.id, best.division)


# ---------------------------------------------------------------- disputa com o jogador

## Rivais fazem propostas públicas por atletas do jogador em fim de contrato
## (Game Design Bible §3 "negociam atletas", §9 free agency). Só usam dados
## públicos: cartel, idade, popularidade e prazo do vínculo. A melhor proposta
## vira o piso da renovação (Contracts.evaluate_offer); se o contrato acabar
## sem renovação, o atleta assina com quem pagou mais (WorldSim).
func _bid_for_player_athletes(world: WorldState, org: Organization) -> void:
	var next_after: Dictionary = org.ai_state.get("next_bid_after", {})
	if not next_after.is_empty() and GameDate.days_between(world.date, next_after) > 0:
		return
	org.ai_state.next_bid_after = GameDate.add_days(world.date, int(_bids.interval_days))
	var interested := false
	for t: String in org.executive_traits:
		interested = interested or t in _bids.traits
	var player := world.player_org()
	if not interested or player == null:
		return
	if org.roster.size() >= int(_cfg.roster_target) + int(_bids.roster_slack):
		return
	if org.cash - reserved_cash(world, org) < int(_cfg.minimum_cash_reserve) * 3:
		return
	var best: Fighter = null
	var best_score := float(_bids.minimum_score)
	for id: String in player.roster:
		var f: Fighter = world.fighters[id]
		var c: Contract = world.contracts.get(f.contract_id)
		if f.retired or f.rival_interest.has(org.id) or c == null or not c.active:
			continue
		if c.bouts_remaining > 1 and GameDate.days_between(world.date, c.expires_on) > int(_bids.window_days):
			continue
		var score: float = f.record.wins - f.record.losses * .5 + _fame(f) * .2
		if "prospect_first" in org.executive_traits:
			score += maxf(0.0, 27.0 - f.age_on(world.date)) * .5
		if score > best_score or (best != null and score == best_score and f.id < best.id):
			best = f
			best_score = score
	if best == null:
		return
	var show := int(Contracts.market_price(world, best) * world.rng.range_f(float(_bids.premium[0]), float(_bids.premium[1])))
	best.rival_interest[org.id] = {"show": show, "since": world.date.duplicate(), "until": GameDate.add_days(world.date, int(_bids.valid_days))}
	LifeCycle.story(world, "rival_bid", "bid", {"organization": org.name, "fighter": best.display_name(), "current": player.name, "show": "US$ %d" % show}, [best.id, org.id])


static func _region_of(country: String) -> String:
	for r: Dictionary in ContentDB.load_json("regions.json"):
		if country in r.countries:
			return r.id
	return ""
