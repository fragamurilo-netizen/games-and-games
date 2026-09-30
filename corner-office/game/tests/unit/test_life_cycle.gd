extends TestCase
## Passagem do tempo, progressão das promotoras e disputa rival.
## Game Design Bible §§3,4,9,12,13; MMA Bible §§15,18.


func _fighter(world: WorldState, age: int, potential: float = 50.0) -> Fighter:
	var f := LifeCycle.new().make_prospect(world, "m_lightweight")
	f.birth_date = {"year": int(world.date.year) - age, "month": 1, "day": 1}
	f.potential = {"mean": potential, "spread": 8.0}
	return f


func _technical(f: Fighter) -> float:
	var total := 0.0
	for group: String in ["striking", "grappling", "jiu_jitsu"]:
		for v in f.get(group).values():
			total += float(v)
	return total


func test_age_and_development_follow_the_curve() -> void:
	var world := WorldGenerator.generate(3, "regional_promoter")
	var young := _fighter(world, 19, 85.0)
	var old := _fighter(world, 37)
	check_eq(young.age_on(world.date), 19, "Idade calculada pela data de nascimento")
	check_eq(young.age_on({"year": world.date.year + 1, "month": 1, "day": 1}), 20, "Aniversário vira o ano")
	var young_before := _technical(young)
	var old_speed := int(old.physical.speed)
	var old_aggression := int(old.mental.aggression)
	var lc := LifeCycle.new()
	for month in 24:
		world.date = GameDate.add_days(world.date, 31)
		world.date.day = 1
		lc.monthly(world)
	check(young.retired or _technical(young) > young_before + 60, "Jovem de alto potencial evolui: %.0f → %.0f" % [young_before, _technical(young)])
	check(int(old.physical.speed) < old_speed, "Veterano perde velocidade: %d → %d" % [old_speed, int(old.physical.speed)])
	check_eq(int(old.mental.aggression), old_aggression, "Traço de estilo não envelhece")


func test_injuries_heal_and_block_booking_meanwhile() -> void:
	var world := WorldGenerator.generate(4, "regional_promoter")
	var f: Fighter = world.fighters[world.player_org().roster[0]]
	f.injuries = [{"type": "hand", "until": GameDate.add_days(world.date, 10)}]
	var sim := WorldSim.new(world)
	for i in 9:
		sim.advance_day()
	check_eq(f.injuries.size(), 1, "Lesão ainda ativa antes do prazo")
	sim.advance_day()
	check(f.injuries.is_empty(), "Lesão cicatriza na data prevista")


func test_old_fighters_retire_and_are_replaced() -> void:
	var world := WorldGenerator.generate(5, "regional_promoter")
	var player := world.player_org()
	var vet: Fighter = world.fighters[player.roster[1]]
	vet.birth_date = {"year": int(world.date.year) - 46, "month": 1, "day": 1}
	var contract: Contract = world.contracts[vet.contract_id]
	var before := world.fighters.size()
	var lc := LifeCycle.new()
	var prospects := 0
	for month in 24:
		world.date.month = month % 12 + 1
		var changes := lc.monthly(world)
		prospects += changes.prospects.size()
		if vet.retired:
			break
	check(vet.retired, "Atleta de 46 anos se aposenta")
	check(not player.roster.has(vet.id), "Sai do elenco")
	check(not contract.active, "Contrato encerrado, histórico preservado")
	check(world.contracts.has(contract.id), "Contrato continua no histórico")
	check(not vet.retired_on.is_empty(), "Data da aposentadoria registrada")
	check(prospects >= 1 and world.fighters.size() > before, "Nova safra entra no mundo")
	var names := {}
	for f: Fighter in world.fighters.values():
		check(not names.has(f.first_name + " " + f.last_name), "Nomes continuam únicos")
		names[f.first_name + " " + f.last_name] = true
	var retired_news := world.news.values().filter(func(n: NewsItem): return n.topic == "fighter_retired" and vet.id in n.entity_ids)
	check_eq(retired_news.size(), 1, "Aposentadoria de atleta do jogador vira notícia")


func test_fight_results_move_regional_popularity() -> void:
	var world := WorldGenerator.generate(6, "regional_promoter")
	var ids: Array = world.player_org().roster
	var winner: Fighter = world.fighters[ids[0]]
	var loser: Fighter = world.fighters[ids[4]]
	winner.country = "US"
	winner.popularity_by_region = {"brazil": 10.0}
	loser.popularity_by_region = {"brazil": 10.0}
	var fight := Fight.new()
	fight.fighter_a_id = winner.id
	fight.fighter_b_id = loser.id
	fight.winner_id = winner.id
	fight.method = "ko_tko"
	fight.card_slot = "main_event"
	Popularity.new().apply_fight_result(world, fight, "brazil")
	check_eq(float(winner.popularity_by_region.brazil), 15.5, "Vitória por nocaute no main event")
	check(float(winner.popularity_by_region.get("usa", 0.0)) > 0.0, "Vitória respinga na região natal")
	check_eq(float(loser.popularity_by_region.brazil), 8.0, "Derrota por finalização custa popularidade")


func test_save_migrates_from_v1() -> void:
	var world := WorldGenerator.generate(8, "regional_promoter")
	var data := world.to_dict()
	data.schema_version = 1
	for f: Dictionary in data.fighters.values():
		for key: String in ["retired_on", "debut_on", "rival_interest"]:
			f.erase(key)
	for o: Dictionary in data.organizations.values():
		for key: String in ["reputation_exact", "standing_history", "objectives", "season_reviews"]:
			o.erase(key)
	var restored := SaveSystem.decode(JSON.stringify(JSON.from_native(data)))
	check(restored != null, "Save v1 carrega")
	check_eq(restored.schema_version, WorldState.SCHEMA_VERSION, "Save migrado para a versão atual")
	check_eq(restored.organizations.org_crown.reputation_exact, 94.0, "Reputação exata parte da inteira")
	check_eq(restored.fighters.ftr_carter.rival_interest, {}, "Sem propostas rivais antigas")
	WorldSim.new(restored).advance_day()
	check_eq(restored.player_org().objectives.size(), 4, "Metas da temporada criadas no primeiro dia")


func test_tiers_use_hysteresis() -> void:
	var s := OrgStanding.new()
	check_eq(s.tier_for(25.0, "regional"), "regional", "Regional abaixo de 40")
	check_eq(s.tier_for(41.0, "regional"), "national", "Sobe ao passar do limite")
	check_eq(s.tier_for(38.0, "national"), "national", "Não cai por oscilação pequena")
	check_eq(s.tier_for(35.0, "national"), "regional", "Cai com queda real")
	check_eq(s.tier_for(90.0, "regional"), "global", "Pode subir dois patamares")


func test_good_events_raise_reputation_and_tier_changes_economy() -> void:
	var world := WorldGenerator.generate(9, "regional_promoter")
	var org := world.player_org()
	var ev := FightEvent.new()
	ev.id = "event_test"
	ev.organization_id = org.id
	ev.region = "brazil"
	ev.status = "completed"
	ev.actual = {"attendance": 2600, "margin": 50000, "costs": 200000, "reasons": []}
	world.add("events", ev)
	var before := org.reputation
	OrgStanding.new().after_event(world, ev)
	check(org.reputation > before, "Noite cheia e lucrativa sobe reputação: %d → %d" % [before, org.reputation])
	check(float(org.market_popularity.get("brazil", 0.0)) > 0.0, "Mercado regional cresce com eventos")
	check_eq(ev.actual.reasons[-1].code, "REPUTATION_CHANGE", "Mudança registrada com reason code")
	var regional_capacity := Economy.capacity(org)
	OrgStanding.new().shift(world, org, 45.0 - OrgStanding.exact(org))
	check_eq(org.tier, "national", "Reputação 45 promove a nacional")
	check(Economy.capacity(org) > regional_capacity, "Patamar nacional abre arenas maiores")
	check_eq(world.news.values().filter(func(n: NewsItem): return n.topic == "organization_tier").size(), 1, "Mudança de patamar vira notícia")


func test_season_objectives_close_on_new_year() -> void:
	var world := WorldGenerator.generate(10, "regional_promoter")
	var org := world.player_org()
	check_eq(org.objectives.size(), 4, "Carreira começa com metas")
	check_eq(OrgStanding.objective_view(world).size(), 4, "Metas com progresso para a UI")
	var cash := org.cash
	var sim := WorldSim.new(world)
	while not (int(world.date.year) == 2028 and int(world.date.day) == 2):
		sim.advance_day()
	check_eq(org.season_reviews.size(), 1, "Balanço da temporada 2027")
	check_eq(int(org.season_reviews[0].season), 2027, "Temporada certa")
	check_eq(int(org.objectives[0].season), 2028, "Novas metas para 2028")
	check(world.news.values().any(func(n: NewsItem): return n.topic == "season_review"), "Balanço vira notícia")
	check(org.cash <= cash + 40000 * 4, "Bônus limitado às metas cumpridas")


func test_rivals_bid_for_expiring_player_athletes() -> void:
	var world := WorldGenerator.generate(12, "regional_promoter")
	var org := world.player_org()
	var star: Fighter = world.fighters[org.roster[0]]
	star.record = {"wins": 18, "losses": 1, "draws": 0, "nc": 0}
	star.popularity_by_region = {"brazil": 40.0}
	var c: Contract = world.contracts[star.contract_id]
	c.bouts_remaining = 1
	var ai := OrgAI.new()
	for i in 20:
		world.date = GameDate.add_days(world.date, 1)
		ai.tick(world)
		if not star.rival_interest.is_empty():
			break
	check(not star.rival_interest.is_empty(), "Rival faz proposta por atleta em fim de contrato")
	var bid := Contracts.best_rival_bid(world, star, org.id)
	check(bid > Contracts.market_price(world, star), "Proposta rival acima do preço de mercado")
	var low := CareerActions.perform(world, "negotiate", {"fighter_id": star.id, "show_money": Contracts.market_price(world, star)})
	check(low.has("counter_show") and int(low.counter_show) >= bid, "Renovar exige cobrir a proposta rival")
	var bidder: String = star.rival_interest.keys()[0]
	c.bouts_remaining = 0
	WorldSim.new(world).advance_day()
	check_eq(star.organization_id, bidder, "Sem renovação, atleta assina com a rival")
	check(not org.roster.has(star.id), "Sai do elenco do jogador")
	check(world.news.values().any(func(n: NewsItem): return n.topic == "fighter_departed"), "Saída vira notícia")


func test_matching_the_rival_bid_keeps_the_athlete() -> void:
	var world := WorldGenerator.generate(13, "regional_promoter")
	var org := world.player_org()
	var f: Fighter = world.fighters[org.roster[0]]
	f.rival_interest = {"org_crown": {"show": Contracts.market_price(world, f) * 2, "since": world.date, "until": GameDate.add_days(world.date, 60)}}
	var price := int(Contracts.market_price(world, f) * 2.2)
	var r := CareerActions.perform(world, "negotiate", {"fighter_id": f.id, "show_money": price})
	check(r.ok and f.organization_id == org.id, "Renovação acima da proposta segura o atleta")
	check(f.rival_interest.is_empty(), "Propostas rivais caem após a assinatura")


func test_advance_month_lands_on_first_day_with_digest() -> void:
	var world := WorldGenerator.generate(14, "regional_promoter")
	var r := CareerActions.perform(world, "advance_month")
	check(r.ok, "Avanço mensal")
	check_eq(int(world.date.day), 1, "Para no dia 1º")
	check_eq(int(world.date.month), 2, "Mês seguinte")
	check(r.has("digest"), "Resumo do período")
	var snap := CareerActions.snapshot(world)
	check_eq(snap.organizations.size(), world.organizations.size(), "Quadro das promotoras no snapshot")
	check(snap.fighters[0].has("age"), "Idade exposta à apresentação")
