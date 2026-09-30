class_name Agencies
extends RefCounted
## Agentes, leverage e memória de negociação (Game Design Bible §9;
## MMA Bible §13 "Leverage", §25 Contract & Leverage Engine).
##
## - Todo atleta tem uma agência, escolhida por regra pública e determinística
##   (fama, cartel, país) — não consome RNG.
## - O pedido do agente parte do valor de mercado e soma: perfil da agência,
##   reputação de quem oferece, confiança acumulada e o BATNA do atleta
##   (a melhor oferta que uma rival com vaga e caixa faria hoje).
## - O BATNA só usa o que as rivais realmente fariam (elenco, caixa, prêmio de
##   `aggressive_buyer`); nunca atributos ocultos.
## - Cada negociação entra na memória append-only da agência. Ofertas hostis
##   reduzem a confiança na organização para TODOS os clientes da agência.

static var _params_by_id: Dictionary = {}
static var _cfg: Dictionary = {}
static var _ai: Dictionary = {}


static func config() -> Dictionary:
	if _cfg.is_empty():
		_cfg = ContentDB.load_json("career_tuning.json").agencies
	return _cfg


static func ai_config() -> Dictionary:
	if _ai.is_empty():
		_ai = ContentDB.load_json("career_tuning.json").rival_ai
	return _ai


static func params(agent_id: String) -> Dictionary:
	if _params_by_id.is_empty():
		for a: Dictionary in ContentDB.load_json("agencies.json"):
			_params_by_id[a.id] = a
	return _params_by_id.get(agent_id, {})


# ---------------------------------------------------------------- representação

## Regra pública de representação. Recebe campos simples para servir também à
## migração de saves antigos (que trabalha sobre dicionários).
static func agency_for(country: String, popularity_by_region: Dictionary, record: Dictionary) -> String:
	var cfg := config()
	var fame := 0.0
	for value in popularity_by_region.values():
		fame = maxf(fame, float(value))
	var wins := int(record.get("wins", 0))
	var bouts := wins + int(record.get("losses", 0)) + int(record.get("draws", 0))
	if fame >= float(cfg.star_popularity) or wins >= int(cfg.star_wins):
		return "agt_blackstone"
	if country in params("agt_morales").get("home_countries", []):
		return "agt_morales"
	if bouts <= int(cfg.prospect_max_bouts):
		return "agt_northstar"
	return "agt_crownking"


static func assign_all(world: WorldState) -> void:
	var ids: Array = world.fighters.keys()
	ids.sort()
	for id: String in ids:
		var f: Fighter = world.fighters[id]
		if not f.agent_id.is_empty():
			continue
		var agent: Agent = world.agents.get(agency_for(f.country, f.popularity_by_region, f.record))
		if agent == null:
			continue
		f.agent_id = agent.id
		if not agent.client_ids.has(f.id):
			agent.client_ids.append(f.id)


# ---------------------------------------------------------------- leverage

## Oferta que cada rival faria hoje por este atleta (BATNA do lado do atleta).
## Espelha OrgAI._maybe_sign: só quem tem vaga no elenco e caixa livre.
static func rival_bids(world: WorldState, fighter: Fighter, offering_org_id: String) -> Array:
	var bids: Array = []
	if fighter.retired or not _reachable(world, fighter):
		return bids
	var ai_cfg := ai_config()
	var fair := Contracts.market_price(world, fighter)
	var org_ids: Array = world.organizations.keys()
	org_ids.sort()
	for org_id: String in org_ids:
		var org: Organization = world.organizations[org_id]
		if org.is_player or org.id == offering_org_id or org.id == fighter.organization_id:
			continue
		var aggressive := "aggressive_buyer" in org.executive_traits
		var target := int(ai_cfg.roster_target) + (4 if aggressive else 0)
		if org.roster.size() >= target or org.cash - _committed_cash(world, org.id) < int(ai_cfg.minimum_cash_reserve):
			continue
		var premium: float = float(ai_cfg.aggressive_premium) if aggressive else 1.0
		bids.append({"organization_id": org.id, "show": int(fair * premium)})
	bids.sort_custom(func(a, b): return a.show > b.show or (a.show == b.show and a.organization_id < b.organization_id))
	return bids


static func _committed_cash(world: WorldState, org_id: String) -> int:
	var total := 0
	for ev: FightEvent in OrgAI.upcoming(world, org_id):
		if ev.status == "announced":
			total += int(ev.projected.get("costs", 0))
	return total


## Atleta livre ou em fim de contrato pode ouvir outras promotoras.
static func _reachable(world: WorldState, fighter: Fighter) -> bool:
	var c: Contract = world.contracts.get(fighter.contract_id)
	if c == null or not c.active or fighter.organization_id.is_empty():
		return true
	var window := int(ai_config().renewal_window_days)
	return c.bouts_remaining <= 1 or GameDate.days_between(world.date, c.expires_on) <= window


## Pedido do agente para esta organização. Leitura pura: não altera o mundo
## nem consome RNG.
static func quote(world: WorldState, fighter: Fighter, org_id: String) -> Dictionary:
	var cfg := config()
	var fair := Contracts.market_price(world, fighter)
	var org: Organization = world.organizations.get(org_id)
	var agent: Agent = world.agents.get(fighter.agent_id)
	var p := params(fighter.agent_id)
	var reasons: Array = []
	var ask := float(fair)
	var trust := 0
	if agent:
		var demand := float(p.get("demand", 1.0))
		ask *= demand
		reasons.append(Reason.make("AGENT_DEMAND", demand - 1.0, {"agent": agent.name}))
		trust = int(agent.relationship.get(org_id, 0))
		if trust != 0:
			var trust_factor := 1.0 - trust * float(cfg.trust_weight) * float(p.get("trust_sensitivity", 1.0))
			ask *= trust_factor
			reasons.append(Reason.make("AGENT_TRUST", 1.0 - trust_factor, {"agent": agent.name, "trust": trust}))
		if org and org.base_country in p.get("home_countries", []):
			ask *= 1.0 - float(p.get("home_discount", 0.0))
			reasons.append(Reason.make("AGENT_HOME_MARKET", -float(p.get("home_discount", 0.0)), {"agent": agent.name}))
	if org:
		var rep_factor := clampf(1.0 - (org.reputation - float(cfg.reputation_baseline)) * float(cfg.reputation_weight), .85, 1.15)
		ask *= rep_factor
		if not is_equal_approx(rep_factor, 1.0):
			reasons.append(Reason.make("PROMOTION_REPUTATION", rep_factor - 1.0, {"reputation": org.reputation}))
	var current: Contract = world.contracts.get(fighter.contract_id)
	if current and current.active and current.organization_id == org_id and current.show_money > ask:
		ask = current.show_money
		reasons.append(Reason.make("NO_PAY_CUT", 0.0, {"show": current.show_money}))
	var bids := rival_bids(world, fighter, org_id)
	var batna := 0
	if not bids.is_empty():
		batna = int(bids[0].show)
		var target := batna * float(cfg.rival_bid_premium)
		if target > ask:
			var leverage := float(p.get("rival_leverage", 0.0))
			var before := ask
			ask = lerpf(ask, target, leverage)
			if ask > before:
				var names: Array = bids.slice(0, 3).map(func(b): return world.organizations[b.organization_id].name)
				reasons.append(Reason.make("RIVAL_INTEREST", ask / before - 1.0, {"organizations": names, "count": bids.size()}))
	var rounding := maxi(1, int(cfg.counter_rounding))
	var ask_show := int(ceil(ask / rounding)) * rounding
	return {"fair_show": fair, "ask_show": ask_show, "batna_show": batna, "rival_ids": bids.map(func(b): return b.organization_id), "agent_id": fighter.agent_id, "trust": trust, "reasons": reasons}


## Valor percebido pelo agente: bolsa + luvas diluídas nas lutas do contrato.
static func offer_value(offer: Contract, agent_id: String) -> float:
	var weight := float(params(agent_id).get("guarantee_weight", 1.0))
	return offer.show_money + offer.signing_bonus * weight / maxi(1, offer.bouts_total)


# ---------------------------------------------------------------- memória

## Registra o desfecho na memória da agência e ajusta a confiança na
## organização. `outcome`: signed | countered | refused.
static func record(world: WorldState, offer: Contract, ask_show: int, outcome: String) -> Dictionary:
	var fighter: Fighter = world.fighters.get(offer.fighter_id)
	if fighter == null:
		return {}
	var agent: Agent = world.agents.get(fighter.agent_id)
	if agent == null:
		return {}
	var cfg := config()
	var ratio := offer_value(offer, agent.id) / maxf(1.0, ask_show)
	var stance := "signed"
	var delta := int(cfg.trust_signed)
	if outcome != "signed":
		if ratio < float(cfg.hostile_ratio):
			stance = "hostile"
			delta = int(cfg.trust_hostile)
		elif ratio < float(cfg.hard_ratio):
			stance = "hard"
			delta = int(cfg.trust_hard)
		else:
			stance = "close"
			delta = 0
	var trust := clampi(int(agent.relationship.get(offer.organization_id, 0)) + delta, int(cfg.trust_min), int(cfg.trust_max))
	agent.relationship[offer.organization_id] = trust
	var entry := {"date": world.date.duplicate(), "organization_id": offer.organization_id, "fighter_id": fighter.id, "outcome": outcome, "stance": stance, "ratio": snappedf(ratio, .01), "trust": trust}
	agent.memory.append(entry)
	return entry
