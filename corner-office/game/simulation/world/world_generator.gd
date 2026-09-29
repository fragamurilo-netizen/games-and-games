class_name WorldGenerator
extends RefCounted
## Gera um novo mundo a partir de content/ (Game Design Bible §2–3, §14).
## Hoje: organizações, academias, agências e roster canônico.
## TODO(M1): gerar 100+ lutadores procedurais coerentes por região (§13).
## TODO(M3): 30–35 anos de história fictícia prévia (§2).


static func generate(seed_value: int, start_mode: String) -> WorldState:
	var w := WorldState.new()
	w.seed_value = seed_value
	w.rng = SimRandom.new(seed_value)

	for o in ContentDB.load_json("organizations.json"):
		var org := Organization.new().load_dict(o) as Organization
		w.add("organizations", org)
	for g in ContentDB.load_json("gyms.json"):
		w.add("gyms", Gym.new().load_dict(g))
	for a in ContentDB.load_json("agencies.json"):
		w.add("agents", Agent.new().load_dict(a))
	for f in ContentDB.load_json("canonical_fighters.json"):
		var fighter := Fighter.new().load_dict(f) as Fighter
		w.add("fighters", fighter)
		var org: Organization = w.organizations.get(fighter.organization_id)
		if org:
			org.roster.append(fighter.id)

	_create_player_org(w, start_mode)
	return w


static func _create_player_org(w: WorldState, start_mode: String) -> void:
	var modes: Dictionary = ContentDB.load_json("start_modes.json")
	var mode: Dictionary = modes.get(start_mode, modes["regional_promoter"])
	var org := Organization.new()
	org.id = "org_player"
	org.name = "Nova Promoção"
	org.short_name = "NP"
	org.is_player = true
	org.tier = "regional"
	org.cash = int(mode.cash)
	org.reputation = int(mode.reputation)
	w.add("organizations", org)
	w.player_org_id = org.id
	# TODO(M1): gerar roster inicial conforme mode.roster_size.
