class_name PopulationGenerator
extends RefCounted
## Seeded, fictional roster. Game Bible §§4,13,20. Appearance is independent of skill.
## Cada atleta vem do FighterGenerator; aqui só se distribuem divisões e elencos.

static func populate(world: WorldState, mode_id: String) -> void:
	var cfg: Dictionary = ContentDB.load_json("career_tuning.json")
	var generation: Dictionary = ContentDB.load_json(FighterGenerator.CONTENT)
	var mode: Dictionary = ContentDB.load_json("start_modes.json").get(mode_id,{})
	var roster_range: Array = mode.get("roster_size",[30,30])
	var player_count := int((roster_range[0]+roster_range[1])/2)
	var org_ids: Array = world.organizations.keys().filter(func(id):return id!=world.player_org_id)
	var used_names := {}
	for old: Fighter in world.fighters.values(): used_names[old.first_name+" "+old.last_name] = true
	# Rivais globais recebem elencos extras (Bible §2: organizações globais têm elencos profundos).
	var total := int(cfg.population) + int(cfg.get("rival_extra_per_org", 0)) * org_ids.size()
	for i in total:
		var f := FighterGenerator.create(world,{"division":cfg.player_divisions[i%cfg.player_divisions.size()],"used_names":used_names,"cfg":generation})
		f.organization_id = world.player_org_id if i<player_count else "" if i<player_count+36 else org_ids[(i-player_count-36)%org_ids.size()]
		world.add("fighters",f)
		if not f.organization_id.is_empty():
			world.organizations[f.organization_id].roster.append(f.id)
			var offer := Contract.new()
			offer.fighter_id=f.id
			offer.organization_id=f.organization_id
			offer.show_money=Contracts.market_price(world,f)
			offer.win_bonus=int(offer.show_money*cfg.contracts.win_bonus_ratio)
			offer.bouts_total=int(cfg.contracts.bouts)
			offer.bouts_remaining=offer.bouts_total
			offer.expires_on=GameDate.add_days(world.date,int(cfg.contracts.term_days))
			Contracts.new().sign(world,offer)
