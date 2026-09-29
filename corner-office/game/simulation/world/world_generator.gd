class_name WorldGenerator
extends RefCounted
## Gera um novo mundo a partir de content/ (Game Design Bible §2–3, §14).
## Organizações, academias, agências, roster canônico e 128 atletas gerados.
## TODO(M3): 30–35 anos de história fictícia prévia (§2).


static func generate(seed_value: int, start_mode: String, include_population: bool = true) -> WorldState:
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
	var combat_profiles: Dictionary = ContentDB.load_json("combat_profiles.json").fighters
	for f in ContentDB.load_json("canonical_fighters.json"):
		var fighter := Fighter.new().load_dict(f) as Fighter
		var profile: Dictionary = combat_profiles.get(fighter.id, {})
		for key: String in ["martial_base", "height_cm", "reach_cm", "striking", "grappling", "jiu_jitsu", "physical", "mental"]:
			if profile.has(key) and not f.has(key):
				fighter.set(key, profile[key])
		w.add("fighters", fighter)
		var org: Organization = w.organizations.get(fighter.organization_id)
		if org:
			org.roster.append(fighter.id)

	_create_player_org(w, start_mode)
	if include_population:
		PopulationGenerator.populate(w,start_mode)
		for division: Dictionary in ContentDB.load_json("weight_classes.json"):
			Rankings.new().update(w,w.player_org_id,division.id)
			Rankings.new().update(w,"wci",division.id)
	return w


static func _create_player_org(w: WorldState, start_mode: String) -> void:
	var modes: Dictionary = ContentDB.load_json("start_modes.json")
	var mode: Dictionary = modes.get(start_mode, modes["regional_promoter"])
	var org := Organization.new()
	org.id = "org_player"
	var identity: Dictionary = ContentDB.load_json("career_tuning.json").player_organization
	org.name = identity.name
	org.short_name = identity.short_name
	org.base_country = identity.base_country
	org.base_city = identity.base_city
	org.is_player = true
	org.tier = "regional"
	org.cash = int(mode.cash)
	org.reputation = int(mode.reputation)
	w.add("organizations", org)
	w.player_org_id = org.id
