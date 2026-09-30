extends TestCase
## Agentes, leverage e memória. Game Bible §9; MMA Bible §13, §25.


func _free_agent(world: WorldState, agent_id: String = "") -> Fighter:
	var ids: Array = world.fighters.keys()
	ids.sort()
	for id: String in ids:
		var f: Fighter = world.fighters[id]
		if f.organization_id.is_empty() and not f.retired and (agent_id.is_empty() or f.agent_id == agent_id):
			return f
	return null


func _offer(world: WorldState, f: Fighter, show: int, org_id: String = "") -> Contract:
	var c := Contract.new()
	c.fighter_id = f.id
	c.organization_id = org_id if not org_id.is_empty() else world.player_org_id
	c.show_money = show
	c.bouts_total = 4
	c.bouts_remaining = 4
	c.expires_on = GameDate.add_days(world.date, 540)
	return c


func test_every_fighter_is_represented_by_public_rule() -> void:
	var world := WorldGenerator.generate(7, "regional_promoter")
	var used := {}
	for f: Fighter in world.fighters.values():
		check(world.agents.has(f.agent_id), "Todo atleta tem agência")
		check(world.agents[f.agent_id].client_ids.has(f.id), "Agência lista o cliente")
		check_eq(f.agent_id, Agencies.agency_for(f.country, f.popularity_by_region, f.record), "Regra pública e reprodutível")
		used[f.agent_id] = true
	check_eq(used.size(), 4, "As quatro agências representam atletas: %s" % str(used.keys()))
	var total := 0
	for a: Agent in world.agents.values():
		total += a.client_ids.size()
	check_eq(total, world.fighters.size(), "Cada atleta em exatamente uma agência")


func test_quote_is_pure_and_explained() -> void:
	var world := WorldGenerator.generate(7, "regional_promoter")
	var f := _free_agent(world)
	var before := SaveSystem.encode(world)
	var q := Agencies.quote(world, f, world.player_org_id)
	check_eq(SaveSystem.encode(world), before, "Cotação não altera mundo nem RNG")
	check(q.ask_show > 0 and q.ask_show % 10 == 0, "Pedido arredondado")
	check(q.reasons.any(func(r): return r.code == "AGENT_DEMAND"), "Pedido explica o perfil do agente")


func test_rival_interest_raises_the_ask_by_agency_leverage() -> void:
	var world := WorldGenerator.generate(7, "regional_promoter")
	var f := _free_agent(world, "agt_crownking")
	check(f != null, "Existe agente livre da Crown & King")
	var with_rivals := Agencies.quote(world, f, world.player_org_id)
	check(not with_rivals.rival_ids.is_empty(), "Rivais com vaga e caixa formam o BATNA")
	check(with_rivals.reasons.any(func(r): return r.code == "RIVAL_INTEREST"), "Interesse rival é explicado")
	for org: Organization in world.organizations.values():
		if not org.is_player:
			org.cash = 0
	var alone := Agencies.quote(world, f, world.player_org_id)
	check(alone.rival_ids.is_empty(), "Sem caixa, rival não entra no BATNA")
	check(with_rivals.ask_show > alone.ask_show, "Concorrência encarece: %d > %d" % [with_rivals.ask_show, alone.ask_show])


func test_contracted_fighter_has_no_rival_leverage() -> void:
	var world := WorldGenerator.generate(7, "regional_promoter")
	var own: Fighter = world.fighters[world.player_org().roster[0]]
	check(Agencies.rival_bids(world, own, world.player_org_id).is_empty(), "Contrato longo e exclusivo: sem ofertas rivais")


func test_hostile_offer_hurts_every_client_of_the_agency() -> void:
	var world := WorldGenerator.generate(7, "regional_promoter")
	var f := _free_agent(world)
	var agent: Agent = world.agents[f.agent_id]
	var other_id := ""
	for id: String in agent.client_ids:
		if id != f.id:
			other_id = id
			break
	var other: Fighter = world.fighters[other_id]
	var ask_before: int = Agencies.quote(world, other, world.player_org_id).ask_show
	var rng_before: int = world.rng.get_state()
	var r := CareerActions.perform(world, "negotiate", {"fighter_id": f.id, "show_money": 1})
	check(r.has("counter_show"), "Oferta ridícula recebe contraproposta")
	check_eq(r.stance, "hostile", "Oferta ridícula é hostil")
	check_eq(world.rng.get_state(), rng_before, "Negociação do jogador não consome RNG")
	check(int(agent.relationship[world.player_org_id]) < 0, "Confiança da agência cai")
	check_eq(agent.memory[-1].fighter_id, f.id, "Memória registra a negociação")
	check_eq(agent.memory[-1].outcome, "countered", "Desfecho registrado")
	var ask_after: int = Agencies.quote(world, other, world.player_org_id).ask_show
	check(ask_after > ask_before, "Outro cliente da agência pede mais: %d > %d" % [ask_after, ask_before])
	var rival_id := ""
	for org: Organization in world.organizations.values():
		if not org.is_player:
			rival_id = org.id
			break
	check_eq(int(agent.relationship.get(rival_id, 0)), 0, "Confiança é por organização")


func test_signing_builds_trust_and_guarantees_count() -> void:
	var world := WorldGenerator.generate(7, "regional_promoter")
	var f := _free_agent(world)
	var agent: Agent = world.agents[f.agent_id]
	var ask: int = Agencies.quote(world, f, world.player_org_id).ask_show
	var contracts := Contracts.new()
	var short := _offer(world, f, ask - 400)
	check(not contracts.evaluate_offer(world, short).meets_ask, "Abaixo do pedido não fecha")
	short.signing_bonus = 400 * 4 * 2
	check(contracts.evaluate_offer(world, short).meets_ask, "Luvas compensam a bolsa menor")
	var memory_size := agent.memory.size()
	var r := CareerActions.perform(world, "negotiate", {"fighter_id": f.id, "show_money": ask - 400, "signing_bonus": 400 * 4 * 2})
	check(r.ok and not r.has("counter_show"), "Contrato com luvas assinado")
	check_eq(f.organization_id, world.player_org_id, "Atleta no elenco")
	check_eq(agent.memory.size(), memory_size + 1, "Assinatura entra na memória")
	check_eq(agent.memory[-1].outcome, "signed", "Desfecho assinado")
	check(int(agent.relationship[world.player_org_id]) > 0, "Acordo justo melhora a confiança")


func test_agent_memory_survives_save() -> void:
	var world := WorldGenerator.generate(7, "regional_promoter")
	var f := _free_agent(world)
	CareerActions.perform(world, "negotiate", {"fighter_id": f.id, "show_money": 1})
	var loaded := SaveSystem.decode(SaveSystem.encode(world))
	var a: Agent = world.agents[f.agent_id]
	var b: Agent = loaded.agents[f.agent_id]
	check_eq(b.relationship, a.relationship, "Confiança persiste")
	check_eq(b.memory.size(), a.memory.size(), "Memória persiste")
	check_eq(loaded.fighters[f.id].agent_id, f.agent_id, "Representação persiste")


func test_v1_save_migrates_to_represented_fighters() -> void:
	var world := WorldGenerator.generate(7, "regional_promoter")
	var data: Dictionary = JSON.to_native(JSON.parse_string(SaveSystem.encode(world)))
	data.schema_version = 1
	for id: String in data.fighters:
		data.fighters[id].agent_id = ""
	for id: String in data.agents:
		data.agents[id].client_ids = []
	var migrated := SaveSystem.decode(JSON.stringify(JSON.from_native(data)))
	check(migrated != null, "Save v1 carrega")
	check_eq(migrated.schema_version, WorldState.SCHEMA_VERSION, "Migrado para a versão atual")
	check(migrated.fighters.values().all(func(f): return f.rating > 0.0), "v3: rating estimado")
	for id: String in world.fighters:
		check_eq(migrated.fighters[id].agent_id, world.fighters[id].agent_id, "Migração usa a mesma regra do gerador")
	for id: String in world.agents:
		check_eq(migrated.agents[id].client_ids.size(), world.agents[id].client_ids.size(), "Carteira reconstruída")
