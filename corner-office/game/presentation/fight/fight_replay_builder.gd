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
		fighters[id] = {"name":f.first_name + " " + f.last_name,"martial_base":f.martial_base,"sex":f.sex,"height_cm":f.height_cm,"reach_cm":f.reach_cm,"record":f.record.duplicate(true),"country":f.country,"division":f.division,"appearance":f.appearance.duplicate(true),"stance":f.stance,"appearance_index":profiles.get(id,{}).get("appearance_index",null)}
	return {"version":1,"id":fight.id,"source":"simulation","title":fighters[ids[0]].name+" × "+fighters[ids[1]].name,"seed":world.seed_value,"scheduled_rounds":fight.rounds,"organization_id":fight.stats.organization_id,"ruleset_id":fight.stats.ruleset_id,"fighter_ids":ids,"fighters":fighters,"initial_state":events[0].before.duplicate(true),"events":events,"stats":fight.stats.duplicate(true),"result":{"winner_id":fight.winner_id if not fight.winner_id.is_empty() else null,"method":fight.method,"detail":fight.method_detail,"round":fight.end_round,"time_s":fight.end_time_s,"scorecards":fight.scorecards.duplicate(true)},"reasons":fight.reasons.duplicate(true)}
