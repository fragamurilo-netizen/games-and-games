class_name PopulationGenerator
extends RefCounted
## Seeded, fictional roster. Game Bible §§4,13,20. Appearance is independent of skill.

static func populate(world: WorldState, mode_id: String) -> void:
	var cfg: Dictionary = ContentDB.load_json("career_tuning.json")
	var mode: Dictionary = ContentDB.load_json("start_modes.json").get(mode_id,{})
	var roster_range: Array = mode.get("roster_size",[30,30])
	var player_count := int((roster_range[0]+roster_range[1])/2)
	var attrs: Dictionary = ContentDB.load_json("attributes.json")
	var profiles: Dictionary = ContentDB.load_json("combat_profiles.json").fighters
	var source_profiles: Array = profiles.values()
	var styles: Array = ContentDB.load_json("fight_tuning.json").styles.keys()
	var org_ids: Array = world.organizations.keys().filter(func(id):return id!=world.player_org_id)
	var used_names := {}
	for old: Fighter in world.fighters.values(): used_names[old.first_name+" "+old.last_name] = true
	for i in int(cfg.population):
		var f := Fighter.new()
		f.id = world.new_id("ftr")
		var region: Dictionary = world.rng.pick(cfg.names)
		f.division = cfg.player_divisions[i%cfg.player_divisions.size()]
		f.sex = Fighter.Sex.FEMALE if f.division.begins_with("w_") else Fighter.Sex.MALE
		for attempt in 200:
			f.first_name = world.rng.pick(region.female if f.sex==Fighter.Sex.FEMALE else region.male)
			f.last_name = world.rng.pick(region.last)
			if not used_names.has(f.first_name+" "+f.last_name): break
		used_names[f.first_name+" "+f.last_name] = true
		f.country = region.country
		f.city = region.city
		f.birth_date = {"year":2027-world.rng.range_i(20,35),"month":world.rng.range_i(1,12),"day":world.rng.range_i(1,28)}
		f.height_cm = int(cfg.division_height.get(f.division,175))+world.rng.range_i(-8,8)
		f.reach_cm = f.height_cm+world.rng.range_i(-3,11)
		f.martial_base = world.rng.pick(styles)
		f.stance = world.rng.weighted({"orthodox":.68,"southpaw":.25,"switch":.07})
		var level := world.rng.range_i(43,72)
		var template: Dictionary = world.rng.pick(source_profiles)
		for group: String in ["striking","grappling","jiu_jitsu","physical","mental"]:
			var values := {}
			for attribute: String in attrs[group]:
				values[attribute] = clampi(level+world.rng.range_i(-13,13)+int(template[group].get(attribute,65))-75,20,90)
			f.set(group,values)
		f.record = {"wins":world.rng.range_i(1,15),"losses":world.rng.range_i(0,6),"draws":0,"nc":0}
		f.popularity_by_region = {region.region:world.rng.range_i(5,35)}
		f.charisma = world.rng.range_i(20,80)
		f.appearance = {"seed":world.rng.range_i(1,2000000000),"sex":"f" if f.sex==Fighter.Sex.FEMALE else "m","pop":"misto"}
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
