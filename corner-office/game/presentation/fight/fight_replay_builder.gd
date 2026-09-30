class_name FightReplayBuilder
extends RefCounted
## Adapter from a completed simulation record to the visual replay contract.
## Copies everything: seeking/import/export cannot mutate the world or consume RNG.

static func build(world: WorldState, fight: Fight) -> Dictionary:
	if fight.status != "completed":
		return {}
	var events: Array = []
	for report: Dictionary in fight.round_log:
		events.append_array(report.get("events", []).duplicate(true))
	if events.is_empty():
		return {}
	var ids := [fight.fighter_a_id, fight.fighter_b_id]
	var fighters := {}
	var profiles: Dictionary = ContentDB.load_json("combat_profiles.json").fighters
	for id: String in ids:
		var f: Fighter = world.fighters[id]
		fighters[id] = {"name":f.first_name + " " + f.last_name,"martial_base":f.martial_base,"sex":f.sex,"height_cm":f.height_cm,"reach_cm":f.reach_cm,"record":f.record.duplicate(true),"country":f.country,"division":f.division,"appearance":f.appearance.duplicate(true),"stance":f.stance,"appearance_index":null if f.appearance.has("pop") else profiles.get(id,{}).get("appearance_index",null)}
	var replay: Dictionary = {"version":1,"id":fight.id,"source":"simulation","title":fighters[ids[0]].name+" × "+fighters[ids[1]].name,"seed":world.seed_value,"scheduled_rounds":fight.rounds,"organization_id":fight.stats.organization_id,"ruleset_id":fight.stats.ruleset_id,"fighter_ids":ids,"fighters":fighters,"initial_state":events[0].before.duplicate(true),"events":events,"stats":fight.stats.duplicate(true),"result":{"winner_id":fight.winner_id if not fight.winner_id.is_empty() else null,"method":fight.method,"detail":fight.method_detail,"round":fight.end_round,"time_s":fight.end_time_s,"scorecards":fight.scorecards.duplicate(true)},"reasons":fight.reasons.duplicate(true)}
	replay.presentation = presentation(world, fight)
	if fight.stats.organization_id == world.player_org_id:
		replay.arena_template_id = ContentDB.load_json("career_tuning.json").player_organization.arena_template_id
		replay.organization = {"name":world.player_org().name,"short_name":world.player_org().short_name,"city":world.player_org().base_city}
	return replay


## Broadcast-only facts (walkouts, tale of the tape, announcer). Read-only.
static func presentation(world: WorldState, fight: Fight) -> Dictionary:
	var ev: FightEvent = world.events.get(fight.event_id)
	var org: Organization = world.organizations.get(ev.organization_id) if ev else null
	var out := {"event_name": ev.name if ev else "", "city": ev.city if ev else "", "card_slot": fight.card_slot, "title_stakes": fight.title_stakes, "fighters": {}}
	var ranking := Rankings.new().latest(world, org.id, fight.division) if org else null
	for id: String in [fight.fighter_a_id, fight.fighter_b_id]:
		var f: Fighter = world.fighters[id]
		var info := {"nickname": f.nickname}
		var ref: Dictionary = ev.date if ev and not ev.date.is_empty() else world.date
		if not f.birth_date.is_empty() and not ref.is_empty():
			info.age = int(ref.year) - int(f.birth_date.year) - (1 if int(ref.month) * 100 + int(ref.day) < int(f.birth_date.month) * 100 + int(f.birth_date.day) else 0)
		if ranking and id in ranking.entries:
			info.rank = ranking.entries.find(id) + 1
		if org and org.titles.get(fight.division, {}).get("champion_id", "") == id:
			info.champion = true
		out.fighters[id] = info
	return out
