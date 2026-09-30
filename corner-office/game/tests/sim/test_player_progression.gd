extends TestCase
## Promotor ativo por três anos (Game Design Bible §§12,13,20): noites a cada
## ~7 semanas, renovações cobrindo propostas rivais e reforços no mercado.
## A reputação precisa crescer, metas anuais precisam ser alcançáveis e o
## caixa não pode explodir para nenhum lado.


func _book(world: WorldState, event_id: String) -> void:
	var ev: FightEvent = world.events[event_id]
	var used := {}
	var by_division := {}
	for id: String in world.player_org().roster:
		var f: Fighter = world.fighters[id]
		if not by_division.has(f.division):
			by_division[f.division] = []
		by_division[f.division].append(id)
	for division: String in by_division:
		var ids: Array = by_division[division]
		for i in ids.size():
			if ev.fight_ids.size() >= 8:
				return
			if used.has(ids[i]):
				continue
			for j in range(i + 1, ids.size()):
				if used.has(ids[j]):
					continue
				if not Matchmaking.new().evaluate(world, ids[i], ids[j], event_id).eligible:
					continue
				var booked := false
				for premium in [1.0, 1.5]:
					var r := CareerActions.perform(world, "propose", {"event_id": event_id, "red": ids[i], "blue": ids[j], "premium": premium})
					if r.get("proposal", {}).get("outcome") == "accepted":
						booked = true
						break
				if booked:
					used[ids[i]] = true
					used[ids[j]] = true
					break


func _manage_roster(world: WorldState) -> void:
	var org := world.player_org()
	for id: String in org.roster.duplicate():
		var f: Fighter = world.fighters[id]
		var c: Contract = world.contracts.get(f.contract_id)
		if c and c.bouts_remaining <= 1 and f.record.wins >= f.record.losses:
			var r := CareerActions.perform(world, "negotiate", {"fighter_id": id, "show_money": Contracts.market_price(world, f)})
			if r.has("counter_show"):
				CareerActions.perform(world, "negotiate", {"fighter_id": id, "show_money": int(r.counter_show)})
	if org.roster.size() >= 28:
		return
	for f: Fighter in world.fighters.values():
		if org.roster.size() >= 30:
			break
		if f.retired or not f.organization_id.is_empty() or f.division not in ["m_lightweight", "m_welterweight", "w_flyweight", "w_bantamweight"]:
			continue
		var r := CareerActions.perform(world, "negotiate", {"fighter_id": f.id, "show_money": int(Contracts.market_price(world, f) * 1.1)})
		# Com agências o pedido pode passar do preço de mercado: o promotor ativo
		# cobre a contraproposta, como já faz nas renovações.
		if r.has("counter_show") and int(r.counter_show) <= int(Contracts.market_price(world, f) * 1.6):
			CareerActions.perform(world, "negotiate", {"fighter_id": f.id, "show_money": int(r.counter_show)})


func test_active_promoter_grows_over_three_years() -> void:
	var world := WorldGenerator.generate(41, "regional_promoter")
	var org := world.player_org()
	var start_rep := org.reputation
	var nights := 0
	var sim := WorldSim.new(world)
	while int(world.date.year) < 2030:
		_manage_roster(world)
		var created := CareerActions.perform(world, "create_event", {"days": 42})
		var id: String = created.event_id
		_book(world, id)
		var ok: bool = world.events[id].fight_ids.size() >= 6 and CareerActions.perform(world, "announce", {"event_id": id}).ok
		if ok:
			CareerActions.perform(world, "advance_event", {"event_id": id})
			if world.events[id].status == "completed":
				nights += 1
		for i in 7:
			sim.advance_day()
		if OS.get_environment("CO_DEBUG") != "":
			print(GameDate.format(world.date), " rep ", org.reputation, " cash ", org.cash, " roster ", org.roster.size(), " nights ", nights, " t ", Time.get_ticks_msec())
	var reviews: Array = org.season_reviews
	check_eq(reviews.size(), 3, "Três temporadas fechadas")
	check(nights >= 15, "Promotor ativo realiza noites: %d" % nights)
	check(org.reputation >= start_rep + 12, "Reputação cresce com noites regulares: %d → %d" % [start_rep, org.reputation])
	check(reviews.any(func(r): return int(r.done) >= 2), "Metas anuais alcançáveis: %s" % str(reviews.map(func(r): return r.done)))
	check(org.cash > -500000 and org.cash < 20000000, "Caixa plausível: %d" % org.cash)
	var history := org.standing_history.map(func(h): return h.reputation)
	print("  3 anos ativo: %d noites, reputação %d → %d (%s), caixa %d, metas %s" % [nights, start_rep, org.reputation, org.tier, org.cash, str(reviews.map(func(r): return "%d/%d" % [r.done, r.total]))])
	print("  reputação mês a mês: %s" % str(history))
