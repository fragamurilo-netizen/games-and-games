extends TestCase
## IA rival: agenda, cards válidos, sem informação privilegiada. Bible §§3,19; MMA §26.


func _rival_events(world: WorldState) -> Array:
	return world.events.values().filter(func(ev: FightEvent): return ev.organization_id != world.player_org_id)


func test_rivals_schedule_and_complete_events_on_their_own() -> void:
	var world := WorldGenerator.generate(7, "regional_promoter")
	var sim := WorldSim.new(world)
	for i in 120:
		sim.advance_day()
	var completed := {}
	for ev: FightEvent in _rival_events(world):
		if ev.status == "completed":
			completed[ev.organization_id] = int(completed.get(ev.organization_id, 0)) + 1
			check(ev.name.begins_with(world.organizations[ev.organization_id].short_name), "Nome segue a marca: " + ev.name)
			check(not ev.actual.is_empty(), "Evento rival tem balanço")
	check(completed.size() >= 4, "Ao menos quatro rivais realizaram noites em 120 dias: %s" % completed)
	check(world.player_org().roster.size() >= 30, "Rivais não mexem no elenco contratado do jogador")


func test_rival_cards_respect_booking_rules() -> void:
	var world := WorldGenerator.generate(11, "regional_promoter")
	var sim := WorldSim.new(world)
	for i in 200:
		sim.advance_day()
	var last_fight_day := {}
	var checked := 0
	for ev: FightEvent in _rival_events(world):
		if ev.status not in ["completed", "announced"]:
			continue
		check(ev.fight_ids.size() >= 4 and ev.fight_ids.size() <= 8, "Card rival entre 4 e 8 lutas: %d" % ev.fight_ids.size())
		var seen := {}
		for id: String in ev.fight_ids:
			var f: Fight = world.fights[id]
			for fid: String in [f.fighter_a_id, f.fighter_b_id]:
				check(not seen.has(fid), "Atleta aparece uma vez por card")
				seen[fid] = true
			check_eq(world.fighters[f.fighter_a_id].division, world.fighters[f.fighter_b_id].division, "Mesma categoria")
			checked += 1
	check(checked > 0, "Houve cards rivais para verificar")
	# Nenhum atleta luta duas vezes com menos de 28 dias.
	var by_fighter := {}
	for f: Fight in world.fights.values():
		if f.status != "completed":
			continue
		var day := GameDate.to_unix(world.events[f.event_id].date)
		for fid: String in [f.fighter_a_id, f.fighter_b_id]:
			if by_fighter.has(fid):
				check(absf(day - by_fighter[fid]) >= 28 * 86400, "Intervalo mínimo entre lutas: " + fid)
			by_fighter[fid] = day


func test_rival_ai_ignores_hidden_skill() -> void:
	# Mesma semente, atributos técnicos embaralhados: a agenda rival não pode mudar.
	var a := WorldGenerator.generate(3, "regional_promoter")
	var b := WorldGenerator.generate(3, "regional_promoter")
	for f: Fighter in b.fighters.values():
		for group: String in ["striking", "grappling", "jiu_jitsu"]:
			var values: Dictionary = f.get(group)
			for key: String in values:
				values[key] = 50
		f.hidden = {"potential_secret": 99}
	var oa := OrgAI.new()
	oa.tick(a)
	OrgAI.new().tick(b)
	var cards_a: Array = []
	var cards_b: Array = []
	for pair in [[a, cards_a], [b, cards_b]]:
		var w: WorldState = pair[0]
		for ev: FightEvent in _rival_events(w):
			for id: String in ev.fight_ids:
				pair[1].append(w.fights[id].fighter_a_id + "-" + w.fights[id].fighter_b_id)
	check(not cards_a.is_empty(), "Rivais montaram cards no primeiro dia")
	check_eq(cards_b, cards_a, "Cards dependem só de dados públicos")


func test_postponed_rival_event_is_repaired_or_cancelled() -> void:
	var world := WorldGenerator.generate(5, "regional_promoter")
	var ai := OrgAI.new()
	ai.tick(world)
	var ev: FightEvent = _rival_events(world).filter(func(e): return e.status == "announced")[0]
	var first: Fight = world.fights[ev.fight_ids[0]]
	world.fighters[first.fighter_a_id].injuries = [{"type": "hand", "until": GameDate.add_days(world.date, 200)}]
	ev.status = "postponed"
	ai.tick(world)
	check(ev.status in ["announced", "cancelled"], "Adiamento resolvido: " + ev.status)
	check_eq(first.status, "cancelled", "Luta com atleta lesionado sai do card")
	check(first.id not in ev.fight_ids, "Luta inválida removida do card")
