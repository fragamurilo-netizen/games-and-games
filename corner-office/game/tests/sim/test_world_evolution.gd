extends TestCase
## Cinco anos de mundo vivo (Game Design Bible §§3,4,13): atletas envelhecem,
## se aposentam e são repostos; reputações se movem sem colapsar; rivais
## disputam atletas do jogador. O jogador não age (pior caso de reputação).


func test_five_years_keep_population_and_rivals_healthy() -> void:
	var world := WorldGenerator.generate(31, "regional_promoter")
	var sim := WorldSim.new(world)
	var start_active := world.fighters.values().filter(func(f): return not f.retired).size()
	var start_rep := {}
	for org: Organization in world.organizations.values():
		start_rep[org.id] = org.reputation
	var tracked := {}
	for f: Fighter in world.fighters.values():
		if f.age_on(world.date) <= 23 or f.age_on(world.date) >= 33:
			tracked[f.id] = [f.age_on(world.date), _technical(f), float(f.physical.speed)]
	for week in 261:
		sim.advance_week()
	var active := world.fighters.values().filter(func(f): return not f.retired)
	var retired := world.fighters.values().filter(func(f): return f.retired)
	var prospects := world.fighters.values().filter(func(f): return not f.debut_on.is_empty())
	var signed_prospects := prospects.filter(func(f): return not f.organization_id.is_empty())
	check(retired.size() >= 20, "Veteranos se aposentam: %d" % retired.size())
	check(prospects.size() >= retired.size(), "Nova safra repõe aposentadorias: %d/%d" % [prospects.size(), retired.size()])
	check(signed_prospects.size() >= 5, "Rivais contratam novos talentos: %d" % signed_prospects.size())
	check(active.size() >= start_active * .9 and active.size() <= start_active * 1.5, "População estável: %d → %d" % [start_active, active.size()])
	var old := 0
	for f: Fighter in active:
		if f.age_on(world.date) >= 42:
			old += 1
	check(old <= 3, "Quase ninguém luta depois dos 42: %d" % old)
	# Jovens evoluem; veteranos perdem velocidade.
	var young_gain := []
	var vet_speed := []
	for id: String in tracked:
		var f: Fighter = world.fighters[id]
		if tracked[id][0] <= 23:
			young_gain.append(_technical(f) - tracked[id][1])
		else:
			vet_speed.append(float(f.physical.speed) - tracked[id][2])
	check(_mean(young_gain) >= 4.0, "Jovens melhoram em 5 anos: %.1f" % _mean(young_gain))
	check(_mean(vet_speed) <= -3.0, "Veteranos perdem velocidade: %.1f" % _mean(vet_speed))
	for org: Organization in world.organizations.values():
		check(org.standing_history.size() >= 59, "Histórico mensal: %s" % org.id)
		if org.id != world.player_org_id:
			check(org.reputation >= 40, "Rival não colapsa: %s %d" % [org.id, org.reputation])
	var player := world.player_org()
	check(player.reputation < start_rep[player.id], "Promoção parada perde reputação: %d" % player.reputation)
	check_eq(player.season_reviews.size(), 5, "Cinco balanços de temporada")
	var bids := world.news.values().filter(func(n: NewsItem): return n.topic == "rival_bid").size()
	var departed := world.news.values().filter(func(n: NewsItem): return n.topic == "fighter_departed").size()
	check(bids >= 5, "Rivais fazem propostas pelos atletas do jogador: %d" % bids)
	check(departed >= 1, "Sem renovação, atletas trocam de casa: %d" % departed)
	var table := OrgStanding.league_table(world)
	print("  5 anos: ativos %d → %d, aposentados %d, novatos %d (contratados %d), 42+ %d, propostas %d, saídas %d" % [start_active, active.size(), retired.size(), prospects.size(), signed_prospects.size(), old, bids, departed])
	print("  evolução: jovens %+.1f técnica, veteranos %+.1f velocidade" % [_mean(young_gain), _mean(vet_speed)])
	print("  promotoras: %s" % ", ".join(table.map(func(r): return "%s %d (%s)" % [r.short_name, r.reputation, r.tier])))


func _technical(f: Fighter) -> float:
	var total := 0.0
	var n := 0
	for group: String in ["striking", "grappling", "jiu_jitsu"]:
		for v in f.get(group).values():
			total += float(v)
			n += 1
	return total / n


func _mean(values: Array) -> float:
	if values.is_empty():
		return 0.0
	return values.reduce(func(a, b): return a + b, 0.0) / values.size()
