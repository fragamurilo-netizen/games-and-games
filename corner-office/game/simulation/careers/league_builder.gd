class_name LeagueBuilder
extends RefCounted
## Mundo no molde de uma grande liga (Game Design Bible §0): a nossa liga é a
## principal, com as 12 divisões, campeões e elenco de ~600 atletas; as outras
## organizações viram ligas nacionais (celeiro e concorrência pontual); o
## circuito regional concentra prospects e veteranos sem contrato.


static func populate(world: WorldState, mode: Dictionary) -> void:
	var cm := CareerModel.cfg()
	var roster: Dictionary = cm.roster
	var rng := world.rng
	var used := {}
	for f: Fighter in world.fighters.values():
		used[f.first_name + " " + f.last_name] = true
	var player := world.player_org()
	var rival_ids: Array = world.organizations.keys().filter(func(id): return id != world.player_org_id)
	rival_ids.sort()
	var ai_cfg: Dictionary = ContentDB.load_json("career_tuning.json").rival_ai
	for id: String in rival_ids:
		var org: Organization = world.organizations[id]
		org.tier = "national"
		org.reputation = roundi(org.reputation * float(mode.get("rival_reputation_scale", 0.55)))
		org.cash = roundi(org.reputation * float(ai_cfg.cash_per_reputation))
	# Roster canônico passa a ser da nossa liga.
	var canon_ids: Array = world.fighters.keys()
	canon_ids.sort()
	for id: String in canon_ids:
		var f: Fighter = world.fighters[id]
		if world.organizations.has(f.organization_id):
			world.organizations[f.organization_id].roster.erase(f.id)
		f.organization_id = ""
		adopt(world, rng, f)
		_sign(world, rng, f, player.id)
	# Liga principal: quotas por divisão.
	var total := int(roster.flagship_total) - canon_ids.size()
	var women := roundi(total * 0.2)
	var classes := AthleteFactory.weight_classes()
	for d: Dictionary in classes:
		var pool := women if d.sex == "F" else total - women
		for i in roundi(pool * float(CareerModel.division(d.id).share)):
			var f := AthleteFactory.create(world, rng, {"tier": "flagship", "division": d.id, "used_names": used})
			world.add("fighters", f)
			_sign(world, rng, f, player.id)
	for id: String in rival_ids:
		for i in int(roster.national_per_org):
			var f := AthleteFactory.create(world, rng, {"tier": "national", "used_names": used})
			world.add("fighters", f)
			_sign(world, rng, f, id)
	for i in int(roster.circuit_total):
		world.add("fighters", AthleteFactory.create(world, rng, {"tier": "circuit", "used_names": used}))
	crown_champions(world, player)


## Dá modelo latente e história a um atleta autoral sem mudar seus atributos
## de hoje: o ruído individual absorve a diferença.
static func adopt(world: WorldState, rng: SimRandom, f: Fighter) -> void:
	var cm := CareerModel.cfg()
	var d := CareerModel.division(f.division)
	var authored := {}
	var total := 0.0
	var n := 0
	for group: String in CareerModel.GROUPS:
		authored[group] = f.get(group).duplicate()
		for v in authored[group].values():
			total += float(v)
			n += 1
	var current := total / maxf(1.0, n) if n > 0 else 68.0
	var age := CareerModel.age_on(f, world.date)
	var h := {"prime_age": snappedf(float(d.prime) + float(cm.style_prime_shift.get(f.martial_base, 0.0)) + rng.normal(0.0, 1.0), 0.1),
		"growth_gap": snappedf(rng.normal(21.0, 3.0), 0.1), "decline_rate": snappedf(maxf(0.08, rng.normal(0.18, 0.04)), 0.001)}
	for trait_key: String in CareerModel.attribute_keys().hidden:
		h[trait_key] = clampi(roundi(rng.normal(58.0, 14.0)), 5, 95)
	h["natural_charisma"] = f.charisma
	h["style_bias"] = {}
	f.hidden = h
	h["ability_peak"] = snappedf(clampf(CareerModel.peak_for(f, current, age), 40.0, 98.0), 0.1)
	h["background"] = AthleteFactory.background(rng, f)
	f.potential = {"mean": h.ability_peak, "spread": 4.0}
	f.history = {"background": h.background, "results": [], "streak": 0}
	f.rating = float(cm.elo.start)
	if f.natural_weight_kg <= 0.0:
		f.natural_weight_kg = snappedf(AthleteFactory._limit_kg(f.division) * float(d.weight_ratio), 0.1)
		f.body_type = AthleteFactory._body_type(f, AthleteFactory._limit_kg(f.division))
	if f.appearance.is_empty():
		f.appearance = {"seed": rng.range_i(1, 2000000000), "sex": "f" if f.sex == Fighter.Sex.FEMALE else "m", "pop": _pop_for(rng, f.country)}
	if CareerModel.pro_bouts(f) == 0:
		var info := CareerHistory.backstory(world, rng, f, world.date, "flagship", current)
		f.history["flagship_debut_on"] = info.flagship_debut_on
		f.history["flagship_bouts"] = info.flagship_bouts
	else:
		CareerHistory.fill_known_record(world, rng, f, world.date)
		f.history["flagship_bouts"] = mini(CareerModel.pro_bouts(f), 6 + roundi(age - 24.0))
	h["attr_noise"] = {}
	CareerModel.refresh_attributes(f, world.date)
	var noise := {}
	for group: String in CareerModel.GROUPS:
		var now: Dictionary = f.get(group)
		for key: String in authored[group]:
			noise[key] = float(authored[group][key]) - float(now.get(key, authored[group][key]))
	h["attr_noise"] = noise
	CareerModel.refresh_attributes(f, world.date)


static func _pop_for(rng: SimRandom, code: String) -> String:
	var c := AthleteFactory.country(code)
	var weights := {}
	for g: Dictionary in c.groups:
		weights[g.pop] = float(weights.get(g.pop, 0.0)) + float(g.w)
	return rng.weighted(weights)


## Contratos escalonados: ninguém começa com todos os contratos vencendo juntos.
static func _sign(world: WorldState, rng: SimRandom, f: Fighter, org_id: String) -> void:
	var cfg: Dictionary = ContentDB.load_json("career_tuning.json").contracts
	var offer := Contract.new()
	offer.fighter_id = f.id
	offer.organization_id = org_id
	offer.show_money = Contracts.market_price(world, f)
	offer.win_bonus = int(offer.show_money * float(cfg.win_bonus_ratio))
	offer.bouts_total = rng.range_i(4, 8)
	offer.bouts_remaining = offer.bouts_total
	offer.expires_on = GameDate.add_days(world.date, rng.range_i(240, 900))
	Contracts.new().sign(world, offer)
	if world.contracts.has(offer.id):
		offer.bouts_remaining = rng.range_i(1, offer.bouts_total)
		offer.signed_on = GameDate.add_days(world.date, -rng.range_i(60, 700))


## Campeão = quem o público reconhece como melhor agora: rating e sequência.
static func crown_champions(world: WorldState, org: Organization) -> void:
	for d: Dictionary in AthleteFactory.weight_classes():
		var best: Fighter = null
		var best_score := -INF
		for id: String in org.roster:
			var f: Fighter = world.fighters[id]
			if f.division != d.id or CareerModel.age_on(f, world.date) > 37.5 or int(f.history.get("streak", 0)) < 1:
				continue
			var score := f.rating + 18.0 * mini(int(f.history.streak), 5)
			if score > best_score:
				best = f
				best_score = score
		if best == null:
			continue
		var results: Array = best.history.results
		var defenses := mini(int(best.history.streak) - 1, world.rng.range_i(0, 3))
		defenses = clampi(defenses, 0, results.size() - 1)
		var won_on: Dictionary = results[defenses].date if not results.is_empty() else world.date
		for i in defenses + 1:
			if i < results.size():
				results[i]["title"] = true
		org.titles[d.id] = {"champion_id": best.id, "since": won_on.duplicate(), "defenses": defenses}
		best.titles.append({"organization_id": org.id, "division": d.id, "won_on": won_on.duplicate(), "defenses": defenses})
