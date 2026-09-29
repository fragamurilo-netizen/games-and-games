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
