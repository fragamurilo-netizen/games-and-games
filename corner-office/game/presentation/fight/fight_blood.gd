class_name FightBlood
extends RefCounted
## Presentation-only, replay-derived stains. Same FNV hash/geometry as replay.js.
static func hash32(text: String) -> int:
	var value:=2166136261
	for i in text.length():value=((value^text.unicode_at(i))*16777619)&0xffffffff
	return value
static func build(replay: Dictionary,catalog: Dictionary,arena: Dictionary) -> Array:
	var marks: Array=[];var clips: Dictionary={}
	for clip: Dictionary in catalog.clips:clips[clip.id]=clip
	for event: Dictionary in replay.events:
		if event.outcome not in ["landed","knockdown","stoppage"]:continue
		var clip: Dictionary=clips[event.technique_id]
		var id: String=event.target_id
		var cuts:=float(event.after.get("cuts",{}).get(id,0));var prior:=float(event.before.get("cuts",{}).get(id,0))
		if cuts<=0 or (cuts<=prior and clip.target!="head"):continue
		var key: Dictionary=clip.tracks[event.outcome][2]
		for item: Dictionary in clip.tracks[event.outcome]:
			if item.t==clip.contact_t:key=item;break
		var flip: bool=(event.actor_id!=replay.fighter_ids[0])!=(clip.actor_role=="bottom")
		var root_x:=float(key.b.root[0])*(-1 if flip else 1)
		var offset:=0.0 if event.before.location=="center" else float(arena.radius_m)*.53
		var base:=hash32(str(event.id)+id)
		var count:=5+int(floor((cuts-prior)*18)) if cuts>prior else 2
		for i in count:
			var value:=hash32(str(base)+":"+str(i));var u:=float(value%1000)/1000;var w:=float((value>>10)%1000)/1000
			marks.append({"at_ms":event.at_ms+event.duration_ms*float(clip.get("contact_t",.56)),"x":clampf(root_x+offset+(u-.5)*.48,-arena.radius_m*.78,arena.radius_m*.78),"z":(w-.5)*.42,"rx":.007+u*.024,"rz":.012+w*.05,"opacity":.32+w*.22,"source_event":event.id})
	return marks
