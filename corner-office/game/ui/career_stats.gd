class_name CareerStats
extends RefCounted
## Read-only aggregations of recorded history for the stat panels (Bible §15:
## the UI must explain what happened). Counts only what the simulation already
## wrote to Fight/FightEvent; no rule, ranking or economy logic lives here.

const METHOD_LABELS := {"ko_tko":"KO/TKO","submission":"Finalização","decision":"Decisão","draw":"Empate","nc":"Sem resultado","dq":"Desclassificação"}


static func completed_fights(w: WorldState, f: Fighter) -> Array:
	var out: Array=[]
	for id: String in f.fight_ids:
		var fight: Fight=w.fights.get(id)
		if fight and fight.status=="completed":out.append(fight)
	out.sort_custom(func(a: Fight,b: Fight):return _fight_time(w,a)>_fight_time(w,b))
	return out


static func _fight_time(w: WorldState, fight: Fight) -> int:
	var ev: FightEvent=w.events.get(fight.event_id)
	return GameDate.to_unix(ev.date) if ev else 0


## "V", "D" or "E" for each recorded fight, newest first.
static func form(w: WorldState, f: Fighter, count: int=5) -> Array:
	var out: Array=[]
	for fight: Fight in completed_fights(w,f).slice(0,count):
		out.append("E" if fight.winner_id.is_empty() else "V" if fight.winner_id==f.id else "D")
	return out


## Positive = wins in a row, negative = losses in a row.
static func streak(w: WorldState, f: Fighter) -> int:
	var run:=0
	for result: String in form(w,f,50):
		if result=="E":break
		var step:=1 if result=="V" else -1
		if run!=0 and signi(run)!=step:break
		run+=step
	return run


static func streak_label(run: int) -> String:
	if run>=2:return "%d vitórias seguidas"%run
	if run<=-2:return "%d derrotas seguidas"%-run
	return ""


## Wins by method from recorded fights only (generated pre-career records have no method).
static func win_methods(w: WorldState, f: Fighter) -> Dictionary:
	var out:={"ko_tko":0,"submission":0,"decision":0}
	for fight: Fight in completed_fights(w,f):
		if fight.winner_id==f.id and out.has(fight.method):out[fight.method]+=1
	return out


## Per-fight averages from the engine's own counters.
static func fight_averages(w: WorldState, f: Fighter) -> Dictionary:
	var fights:=completed_fights(w,f)
	var sums:={"landed":0.0,"attempted":0.0,"takedowns":0.0,"takedown_attempts":0.0,"knockdowns":0.0,"submission_attempts":0.0}
	var counted:=0
	for fight: Fight in fights:
		var mine: Dictionary=fight.stats.get("fighters",{}).get(f.id,{})
		if mine.is_empty():continue
		counted+=1
		for key: String in sums:sums[key]+=float(mine.get(key,0))
	var out:={"fights":counted}
	if counted==0:return out
	out.landed=sums.landed/counted
	out.accuracy=sums.landed/maxf(1.0,sums.attempted)
	out.takedowns=sums.takedowns/counted
	out.takedown_accuracy=sums.takedowns/maxf(1.0,sums.takedown_attempts)
	out.knockdowns=sums.knockdowns/counted
	out.submission_attempts=sums.submission_attempts/counted
	return out


## Average of one attribute group, for the compact "tale of the tape".
static func group_average(values: Dictionary) -> float:
	if values.is_empty():return 0.0
	var total:=0.0
	for key in values:total+=float(values[key])
	return total/values.size()


## Organization totals across completed events of the player's promotion.
static func org_summary(w: WorldState) -> Dictionary:
	var out:={"events":0,"fights":0,"finishes":0,"revenue":0,"costs":0,"margin":0,"best_event":"","best_margin":0,"attendance":0}
	for ev: FightEvent in w.events.values():
		if ev.organization_id!=w.player_org_id or ev.status!="completed":continue
		out.events+=1
		if not ev.actual.is_empty():
			out.revenue+=int(ev.actual.get("revenue",0));out.costs+=int(ev.actual.get("costs",0))
			var margin:=int(ev.actual.get("margin",0));out.margin+=margin
			if out.best_event=="" or margin>out.best_margin:out.best_event=ev.name;out.best_margin=margin
		for id: String in ev.fight_ids:
			var fight: Fight=w.fights.get(id)
			if fight==null or fight.status!="completed":continue
			out.fights+=1
			if fight.method in ["ko_tko","submission"]:out.finishes+=1
	return out


static func next_event(w: WorldState) -> FightEvent:
	var next: FightEvent=null
	for ev: FightEvent in w.events.values():
		if ev.organization_id==w.player_org_id and ev.status in ["planned","announced"]:
			if next==null or GameDate.to_unix(ev.date)<GameDate.to_unix(next.date):next=ev
	return next


## Hottest fighters on the player's roster: longest current win streak, then wins.
static func hot_fighters(w: WorldState, count: int=3) -> Array:
	var list: Array=[]
	for id: String in w.player_org().roster:
		var f: Fighter=w.fighters[id]
		list.append({"fighter":f,"streak":streak(w,f)})
	list.sort_custom(func(a,b):
		if a.streak!=b.streak:return a.streak>b.streak
		return a.fighter.record.wins>b.fighter.record.wins)
	return list.slice(0,count)


## Season goals for the dashboard. The official goals (with the year-end bonus)
## are OrgStanding.objective_view from PR #67; once that class exists this reads
## it, and the local fallback below should be deleted. Looked up by name so this
## file compiles with or without it.
static func milestones(w: WorldState) -> Array:
	for c: Dictionary in ProjectSettings.get_global_class_list():
		if c["class"]=="OrgStanding":
			var out: Array=[]
			for o: Dictionary in load(c.path).objective_view(w):
				out.append({"label":str(o.label),"value":int(o.progress),"goal":int(o.target),"money":o.id=="profit","official":true})
			return out
	var s:=org_summary(w)
	var best_run:=0
	for id: String in w.player_org().roster:best_run=maxi(best_run,streak(w,w.fighters[id]))
	return [
		{"label":"Realize 4 noites","value":s.events,"goal":4},
		{"label":"Some 10 finalizações","value":s.finishes,"goal":10},
		{"label":"Tenha um atleta com 3 vitórias seguidas","value":best_run,"goal":3},
		{"label":"Lucre US$ 250.000 com eventos","value":maxi(0,s.margin),"goal":250000,"money":true},
	]
