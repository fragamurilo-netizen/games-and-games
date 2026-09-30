extends TestCase
## Shared authored replays + deterministic event sampling (Bible §§6,15,17).

func test_all_authored_replays_load_and_preserve_results() -> void:
	var player := FightReplayPlayer.new()
	var fixtures: Array = ContentDB.load_json("replays/index.json")
	fixtures.append_array(ContentDB.load_json("replays/simulated_index.json"))
	for item: Dictionary in fixtures:
		var data: Dictionary = ContentDB.load_json("replays/" + item.file)
		var original := data.duplicate(true)
		check(player.load_replay(data), "Replay %s: %s" % [item.id, player.errors])
		var end := player.seek_ms(player.duration_ms)
		check_eq(end.result, data.result, "Resultado vem do registro")
		check_eq(end.state, data.events[-1].after, "Estado final exato")
		for event: Dictionary in data.events:
			var sample := player.seek_ms(event.at_ms)
			check_eq(sample.event.id, event.id, "Limite do evento")
			check_eq(sample, player.seek_ms(event.at_ms), "Seek determinístico")
		check_eq(data, original, "Apresentação não muta a simulação")

func test_rejects_unknown_moves_and_discontinuous_states() -> void:
	var player := FightReplayPlayer.new()
	var good: Dictionary = ContentDB.load_json("replays/integrated.json")
	var bad := good.duplicate(true)
	bad.events[0].technique_id = "unknown"
	check(not player.load_replay(bad), "Não inventa substituto para técnica desconhecida")
	bad = good.duplicate(true)
	bad.events[1].before.stamina.red = 0.1
	check(not player.load_replay(bad), "Rejeita quebra de continuidade")
	bad = good.duplicate(true)
	bad.events[1].at_ms = 0
	check(not player.load_replay(bad), "Rejeita sobreposição")
	bad = good.duplicate(true)
	bad.events[0].rules_approved = false
	check(not player.load_replay(bad), "Legalidade pertence ao motor")
	check(player.load_replay(good), "Registro válido continua aceito")

func test_arenas_follow_organization_rulesets() -> void:
	var profiles: Dictionary = ContentDB.load_json("arena_profiles.json")
	var orgs: Array = ContentDB.load_json("organizations.json")
	var rules: Array = ContentDB.load_json("rulesets.json")
	check_eq(profiles.arenas.size(), orgs.size(), "Arena para cada organização")
	for org: Dictionary in orgs:
		var found := false
		for arena: Dictionary in profiles.arenas:
			if arena.id == org.id:
				found = true
				for rule: Dictionary in rules:
					if rule.id == org.ruleset_id:
						check_eq(arena.venue, rule.venue, "Shinsei mantém ringue")
		check(found, "Arena existe: " + org.id)

func test_every_clip_has_paired_tracks_and_stable_ids() -> void:
	var catalog: Dictionary = ContentDB.load_json("fight_visuals.json")
	var ids := {}
	for clip: Dictionary in catalog.clips:
		check(not ids.has(clip.id), "ID único")
		ids[clip.id] = true
		for outcome: String in clip.outcomes:
			var frames: Array = clip.tracks[outcome]
			check_eq(frames[0].t, 0, "Início da animação")
			check_eq(frames[-1].t, 1, "Fim da animação")
			for frame: Dictionary in frames:
				check(frame.has("a") and frame.has("b"), "Dois atletas sincronizados")

func test_replay_blood_requires_recorded_cuts_and_is_seek_stable() -> void:
	var replay: Dictionary=ContentDB.load_json("replays/sim_exchange.json")
	var player:=FightReplayPlayer.new()
	check(player.load_replay(replay),"Blood replay validates")
	var marks: Array=player.seek_ms(player.duration_ms).stains
	check(not marks.is_empty(),"Recorded cuts leave mat stains")
	check_eq(player.seek_ms(0).stains.size(),0,"No future blood at initial frame")
	check_eq(player.seek_ms(player.duration_ms).stains,marks,"Seeking reproduces exact marks")
	var dry:=replay.duplicate(true)
	for event: Dictionary in dry.events:
		for state: Dictionary in [event.before,event.after]:
			for id: String in dry.fighter_ids:state.cuts[id]=0.0
	for id: String in dry.fighter_ids:dry.initial_state.cuts[id]=0.0
	check(player.load_replay(dry),"Dry replay validates")
	check_eq(player.seek_ms(player.duration_ms).stains.size(),0,"No blood invented without recorded cuts")


func test_replay_carries_broadcast_presentation() -> void:
	var world := WorldGenerator.generate(4, "regional_promoter")
	var ev: FightEvent = world.events.values().filter(func(e): return e.organization_id != world.player_org_id and e.status == "announced")[0]
	var fight: Fight = world.fights[ev.fight_ids[-1]]
	world.date = ev.date.duplicate()
	WorldSim.new(world).run_event(ev.id)
	var replay := FightReplayBuilder.build(world, fight)
	check_eq(replay.presentation.event_name, ev.name, "Nome do evento na transmissão")
	check_eq(replay.presentation.card_slot, "main_event", "Última luta é a principal")
	for id: String in replay.fighter_ids:
		var info: Dictionary = replay.presentation.fighters[id]
		check(int(info.get("age", 0)) >= 18 and int(info.get("age", 0)) <= 50, "Idade plausível: %s" % info)
	check(FightReplayPlayer.new().load_replay(replay), "Presentation não quebra o contrato do replay")
