extends RefCounted
## Helpers for capture_mobile.gd; loaded at runtime because they need autoloads.

static func create_event(world: WorldState, name: String) -> Dictionary:
	return CareerActions.perform(world,"create_event",{"name":name,"days":42})

## Uma noite completa via CareerActions, para as telas terem histórico.
static func play_one_night(world: WorldState) -> String:
	var created:=CareerActions.perform(world,"create_event",{"name":"Noite de Estreia","days":42})
	var id: String=created.event_id
	var groups: Dictionary={}
	for fid: String in world.player_org().roster:
		var f: Fighter=world.fighters[fid]
		if not groups.has(f.division):groups[f.division]=[]
		groups[f.division].append(fid)
	for i in range(0,12,2):
		for ids: Array in groups.values():
			if i+1>=ids.size() or world.events[id].fight_ids.size()>=6:continue
			for premium in [1.0,1.5,2.0]:
				var r:=CareerActions.perform(world,"propose",{"event_id":id,"red":ids[i],"blue":ids[i+1],"premium":premium})
				if r.get("proposal",{}).get("outcome")=="accepted":break
	if not CareerActions.perform(world,"announce",{"event_id":id}).get("ok"):return ""
	CareerActions.perform(world,"advance_event",{"event_id":id})
	var fight: Fight=world.fights[world.events[id].fight_ids[-1]]
	return fight.winner_id if not fight.winner_id.is_empty() else fight.fighter_a_id
