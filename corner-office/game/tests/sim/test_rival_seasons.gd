extends TestCase
## Dois anos de mundo vivo sem o jogador (Game Design Bible §§13,21).
## Checagens amplas de saúde: atividade, caixa, notícias e agentes livres.


func test_two_years_of_rival_activity_stay_healthy() -> void:
	for seed_value in [21, 22]:
		var world := WorldGenerator.generate(seed_value, "regional_promoter")
		var sim := WorldSim.new(world)
		var cash_start := {}
		for org: Organization in world.organizations.values():
			cash_start[org.id] = org.cash
		var start_free := world.fighters.values().filter(func(f): return f.organization_id.is_empty()).size()
		for week in 104:
			sim.advance_week()
		var per_org := {}
		var bouts := 0
		var methods := {}
		for ev: FightEvent in world.events.values():
			if ev.organization_id == world.player_org_id or ev.status != "completed":
				continue
			per_org[ev.organization_id] = int(per_org.get(ev.organization_id, 0)) + 1
			for id: String in ev.fight_ids:
				var f: Fight = world.fights[id]
				bouts += 1
				methods[f.method] = int(methods.get(f.method, 0)) + 1
		for org_id: String in per_org:
			check(per_org[org_id] >= 4 and per_org[org_id] <= 40, "%s: %d noites em 2 anos" % [org_id, per_org[org_id]])
		check(per_org.size() >= 5, "Maioria das rivais ativa: %s" % per_org)
		var free_now := world.fighters.values().filter(func(f): return f.organization_id.is_empty()).size()
		var signings := 0
		for org: Organization in world.organizations.values():
			if org.id == world.player_org_id:
				continue
			signings += int(org.ai_state.get("signings", 0))
			check(org.roster.size() >= 12 and org.roster.size() <= 30, "Elenco rival estável: %s %d" % [org.id, org.roster.size()])
		check(signings >= 10, "Rivais contratam agentes livres: %d" % signings)
		check(world.news.size() >= per_org.values().reduce(func(a, b): return a + b, 0), "Cada noite rival gera notícia")
		for org: Organization in world.organizations.values():
			check(org.cash > -2_000_000, "Sem colapso financeiro descontrolado: %s %d" % [org.id, org.cash])
		# Memória de agentes (Game Bible §9): negociações rivais ficam registradas
		# e a confiança fica dentro dos limites.
		var memory := 0
		var trust_range := [0, 0]
		for a: Agent in world.agents.values():
			memory += a.memory.size()
			for value in a.relationship.values():
				trust_range = [mini(trust_range[0], int(value)), maxi(trust_range[1], int(value))]
		check(memory >= signings, "Toda contratação rival entra na memória: %d ≥ %d" % [memory, signings])
		check(trust_range[0] >= -100 and trust_range[1] <= 100, "Confiança limitada: %s" % str(trust_range))
		print("  Seed %d: %d noites rivais, %d lutas, métodos %s, agentes livres %d → %d, contratações rivais %d, memória de agentes %d, confiança %s" % [seed_value, per_org.values().reduce(func(a, b): return a + b, 0), bouts, methods, start_free, free_now, signings, memory, str(trust_range)])
