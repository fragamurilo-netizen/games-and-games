class_name Rankings
extends RefCounted
## Separate official lists and WCI, append-only snapshots. Game Bible §7; MMA §23.
const WCI_ORG_ID:="wci"
static func key(org_id: String,division: String) -> String:return "%s:%s"%[org_id,division]
func latest(world: WorldState,org_id: String,division: String) -> Ranking:
	var history: Array=world.rankings.get(key(org_id,division),[])
	return history.back() if not history.is_empty() else null

func update(world: WorldState,org_id: String,division: String) -> Ranking:
	var scores: Dictionary={}
	for f: Fighter in world.fighters.values():
		if f.retired or f.division!=division or (org_id!=WCI_ORG_ID and f.organization_id!=org_id):continue
		var wins:=float(f.record.wins);var losses:=float(f.record.losses)
		var score:=wins*1.5-losses*.5+30*(wins+1)/(wins+losses+2)
		for fight_id: String in f.fight_ids.slice(-6):
			var fight: Fight=world.fights.get(fight_id)
			if fight==null:continue
			var opponent: Fighter=world.fighters[fight.fighter_b_id if fight.fighter_a_id==f.id else fight.fighter_a_id]
			var opposition:=float(opponent.record.wins+1)/float(opponent.record.wins+opponent.record.losses+2)
			score+=(8+opposition*8) if fight.winner_id==f.id else -5 if not fight.winner_id.is_empty() else 1
		scores[f.id]=score
	var ordered: Array=scores.keys()
	ordered.sort_custom(func(a,b):return scores[a]>scores[b] if scores[a]!=scores[b] else a<b)
	var prev:=latest(world,org_id,division)
	if prev and prev.entries==ordered:return prev
	var snapshot:=Ranking.new()
	snapshot.id=world.new_id("rank")
	snapshot.organization_id=org_id;snapshot.division=division;snapshot.snapshot_date=world.date.duplicate()
	snapshot.model="algorithmic" if org_id==WCI_ORG_ID else "panel"
	snapshot.entries=ordered
	snapshot.explanations=[Reason.make("RESULTS_AND_OPPOSITION",0,{"scores":scores})]
	var k:=key(org_id,division)
	if not world.rankings.has(k):world.rankings[k]=[]
	world.rankings[k].append(snapshot)
	return snapshot
