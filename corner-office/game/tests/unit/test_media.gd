extends TestCase
## Central de notícias: só fatos, sem repetição, sem mexer no RNG do mundo.
## Game Design Bible §10; MMA Bible §27.


func _run(seed_value: int, days: int) -> WorldState:
	var world := WorldGenerator.generate(seed_value, "regional_promoter")
	var sim := WorldSim.new(world)
	for i in days:
		sim.advance_day()
	return world


func test_world_generates_factual_varied_news() -> void:
	var world := _run(7, 150)
	var topics := {}
	var outlets := {}
	for n: NewsItem in world.news.values():
		topics[n.topic] = true
		outlets[n.outlet_id] = true
		check(not n.headline.is_empty() and not "{" in n.headline, "Manchete preenchida: " + n.headline)
		check(not "{" in n.body, "Texto preenchido: " + n.body)
		check(Media.outlet(n.outlet_id).has("name"), "Veículo conhecido: " + n.outlet_id)
		check(n.importance >= 1 and n.importance <= 3, "Peso válido")
		check(not n.entity_ids.is_empty(), "Notícia aponta para os fatos")
	for topic in ["event_announced", "main_event_result", "event_completed"]:
		check(topics.has(topic), "Tópico publicado: " + topic)
	check(outlets.size() >= 3, "Vários veículos cobrem o mundo: %s" % [outlets.keys()])


func test_no_story_repeats_and_generated_roster_is_not_news() -> void:
	var world := _run(11, 120)
	var keys := {}
	for n: NewsItem in world.news.values():
		if n.key.is_empty():
			continue
		check(not keys.has(n.key), "Fato noticiado uma vez: " + n.key)
		keys[n.key] = true
		if n.key.begins_with("sign:"):
			check(world.contracts[n.key.substr(5)].signed_on != GameDate.START, "Elenco inicial não vira notícia")
	var count := world.news.size()
	var media := Media.new()
	media.scan_triggers(world)
	for ev: FightEvent in world.events.values():
		if ev.status == "completed":
			media.event_report(world, ev)
	check_eq(world.news.size(), count, "Varredura repetida não publica nada novo")


func test_results_match_the_fight_record() -> void:
	var world := _run(21, 150)
	var checked := 0
	for n: NewsItem in world.news.values():
		if n.topic != "main_event_result":
			continue
		var fight: Fight = world.fights[n.key.substr(5)]
		check(world.fighters[fight.winner_id].display_name() in n.headline + n.body, "Vencedor citado corretamente")
		checked += 1
	check(checked > 0, "Houve lutas principais noticiadas")


func test_news_does_not_consume_world_rng() -> void:
	var a := WorldGenerator.generate(5, "regional_promoter")
	var b := WorldGenerator.generate(5, "regional_promoter")
	var sim_a := WorldSim.new(a)
	var sim_b := WorldSim.new(b)
	for i in 60:
		sim_a.advance_day()
		sim_b.advance_day()
		Media.new().scan_triggers(b)
	check_eq(a.rng.get_state(), b.rng.get_state(), "Varreduras extras não alteram o RNG")
	check_eq(a.news.size(), b.news.size(), "Mesmas notícias com ou sem varreduras extras")


func test_read_state_and_old_saves() -> void:
	var world := _run(9, 90)
	check(Media.unread_count(world) == world.news.size(), "Tudo começa como não lido")
	Media.mark_read(world, world.news.keys().slice(0, 2))
	check_eq(Media.unread_count(world), world.news.size() - 2, "Marcar como lido")
	var old := NewsItem.new().load_dict({"id": "news_999999", "topic": "event_completed", "headline": "Antiga", "body": "", "entity_ids": [], "facts": []})
	check_eq(old.key, "", "Notícia de save antigo carrega sem chave")
	check_eq(old.read, false, "Notícia de save antigo carrega como não lida")
	var saved := SaveSystem.decode(SaveSystem.encode(world))
	check_eq(Media.unread_count(saved), world.news.size() - 2, "Leitura sobrevive ao save")


func test_player_signing_is_player_news() -> void:
	var world := WorldGenerator.generate(3, "regional_promoter")
	var sim := WorldSim.new(world)
	sim.advance_day()
	var free: Fighter = null
	for f: Fighter in world.fighters.values():
		if f.organization_id.is_empty() and not f.retired:
			free = f
			break
	var r := CareerActions.perform(world, "negotiate", {"fighter_id": free.id, "show_money": Contracts.market_price(world, free) * 2})
	check(r.ok and free.organization_id == world.player_org_id, "Contratação do jogador")
	sim.advance_day()
	var found := world.news.values().filter(func(n: NewsItem): return n.topic == "signing_player" and free.id in n.entity_ids)
	check_eq(found.size(), 1, "Contratação do jogador vira notícia")
	check(not found.is_empty() and Media.involves_player(world, found[0]), "Filtro 'minha organização' pega a contratação")


func test_social_posts_follow_facts() -> void:
	var world := _run(7, 150)
	var posts: Array = world.news.values().filter(func(n: NewsItem): return n.channel == "social")
	var topics := {}
	for p: NewsItem in posts:
		topics[p.topic] = true
		check(not p.author_id.is_empty(), "Post tem autor")
		check(Media.handle(world, p.author_id).begins_with("@"), "Autor tem @: " + Media.handle(world, p.author_id))
		check(not "{" in p.headline, "Post preenchido: " + p.headline)
		check(p.reach > 0, "Post tem engajamento")
		if p.topic == "social_win":
			var fight: Fight = world.fights[p.key.substr(9)]
			check_eq(p.author_id, fight.winner_id, "Quem comemora é quem venceu")
		if p.topic == "social_callout":
			check(p.entity_ids[1] != p.author_id, "Ninguém desafia a si mesmo")
	for topic in ["social_org_announce", "social_win", "social_loss"]:
		check(topics.has(topic), "Post publicado: " + topic)
	check_eq(Media.compact(12400), "12,4 mil", "Engajamento compacto")
