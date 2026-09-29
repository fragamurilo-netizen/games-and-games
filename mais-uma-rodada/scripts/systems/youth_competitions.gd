class_name YouthCompetitions
extends RefCounted
## Additional playable academy competitions. Opponents use lightweight aggregate youth squads.
## Original fictional formats, not claims to reproduce CBF/UEFA regulations.
const KEY := "competitions_v1"
const FORMATS := [
	{"id":"regional_u15","name":"Liga Regional Sub-15","age":15,"teams":8,"kind":"league","region":"nation"},
	{"id":"cup_u20","name":"Copa Nacional de Base Sub-20","age":20,"teams":16,"kind":"cup","region":"nation"},
	{"id":"continental_u19","name":"Torneio Continental de Desenvolvimento Sub-19","age":19,"teams":8,"kind":"cup","region":"confed"}
]

static func competitions(w: GameWorld) -> Array:
	if not w.has_user() or w.season == null: return []
	var d: Dictionary = w.youth.get(KEY,{})
	if int(d.get("year",-1)) != w.year or int(d.get("club",-1)) != w.user_club_id: build(w)
	return w.youth.get(KEY,{}).get("competitions",[])

static func build(w: GameWorld) -> void:
	if not w.has_user() or w.season == null: return
	var old: Dictionary = w.youth.get(KEY,{})
	if not old.is_empty():
		var archive: Array = w.youth.get("competition_archive",[])
		for c in old.get("competitions",[]):
			archive.append({"year":old["year"],"name":c["name"],"champion":c.get("champion",-1)})
		w.youth["competition_archive"] = archive.slice(maxi(0,archive.size()-24))
	var output: Array = []
	var mine := w.user_club()
	var confed := String(DatabaseManager.nation(mine.nation).get("confed",""))
	for spec: Dictionary in FORMATS:
		var candidates: Array = []
		for club: Club in w.clubs:
			if club.id == mine.id: continue
			var allowed := club.nation == mine.nation if spec["region"] == "nation" else String(DatabaseManager.nation(club.nation).get("confed","")) == confed
			if allowed: candidates.append(club)
		candidates.sort_custom(func(a,b): return a.youth_level > b.youth_level or (a.youth_level==b.youth_level and a.id<b.id))
		var ids: Array = [mine.id]
		for club: Club in candidates.slice(0,int(spec["teams"])-1): ids.append(club.id)
		# Knockout brackets require a power of two; smaller databases get smaller tournaments.
		var count := 2
		while count*2 <= ids.size(): count*=2
		if ids.size()<4: continue
		ids = ids.slice(0,count)
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([w.world_seed,w.year,mine.id,spec["id"]])
		RngUtil.shuffle(rng,ids)
		var eligible_slots: Array = []
		for i in range(w.season.day,w.season.calendar.size()):
			var kind := w.season.slot_type(i)
			if kind in ["I","IA"]: continue
			if (spec["kind"]=="league" and kind=="W") or (spec["kind"]=="cup" and kind!="W"): eligible_slots.append(i)
		var stages := (ids.size()-1)*2 if spec["kind"]=="league" else int(round(log(ids.size())/log(2)))
		if eligible_slots.size()<stages: continue # old saves near season end start these next year
		var slots := FixtureManager.spread_rounds(stages,eligible_slots)
		var state := {"id":spec["id"],"name":spec["name"],"age":spec["age"],"kind":spec["kind"],"year":w.year,
			"clubs":ids,"slots":slots,"table":{},"rounds":[],"stage":0,"champion":-1,"records":{},"scorers":{},"str":{}}
		for cid in ids:
			state["table"][cid] = CompetitionManager.empty_row()
			var club := w.club(cid)
			state["str"][cid] = PlayerGenerator.league_level(club)-(26.0 if int(spec["age"])==15 else 18.0)+club.youth_level*0.065+rng.randfn(0.0,2.0)
		if spec["kind"]=="league":
			for pairs in FixtureManager.round_robin(rng,ids,2):
				var fixtures: Array = []
				for pair in pairs: fixtures.append([pair[0],pair[1],-1,-1,-1])
				state["rounds"].append(fixtures)
		else:
			state["rounds"].append(_pair(ids))
		output.append(state)
	w.youth[KEY] = {"year":w.year,"club":mine.id,"competitions":output,"last_played":{}}

static func _pair(ids: Array) -> Array:
	var out: Array = []
	for i in range(0,ids.size()-1,2): out.append([ids[i],ids[i+1],-1,-1,-1])
	return out

static func select(w: GameWorld, age_limit: int, date: int, used: Dictionary = {}) -> Dictionary:
	var pool: Array = []
	var last: Dictionary = w.youth.get("match_rest_v1",{})
	for p: Player in w.academy.values():
		var age := p.age(w.year)
		if age < 14 or age > age_limit or not p.is_available() or used.has(p.id): continue
		if last.has(p.id) and date-int(last[p.id])<3*86400: continue
		pool.append(p)
	pool.sort_custom(func(a,b): return a.id<b.id)
	var selected: Array = []
	var taken := {}
	var level := PlayerGenerator.league_level(w.user_club())-(27.0 if age_limit==15 else 21.0)+w.user_club().youth_level*0.06
	var total := 0.0
	for pos in YouthManager.XI_SHAPE:
		var best: Player = null
		var score := -1000.0
		for p: Player in pool:
			if taken.has(p.id) or ((pos==Pos.GK)!=(p.position==Pos.GK)): continue
			var value := p.rating_at(pos)-float(p.stats[Player.S_STARTS])*0.035
			if value>score: best=p; score=value
		if best!=null:
			selected.append([best,pos]); taken[best.id]=true; total+=best.rating_at(pos)
		else: total+=level
	return {"xi":selected,"bench":[],"str":total/11.0,"fillers":11-selected.size()}

static func play_slot(w: GameWorld, slot: int) -> Array:
	var comps := competitions(w)
	if comps.is_empty(): return []
	var d: Dictionary = w.youth[KEY]
	var date := InternationalCalendar.season_date(w,slot)
	var used: Dictionary = w.youth.get("used_this_slot",{}).get("players",{}).duplicate() if int(w.youth.get("used_this_slot",{}).get("slot",-1))==slot else {}
	var reports: Array = []
	for state: Dictionary in comps:
		if int(state["champion"])>=0: continue
		var round_index: int = state["slots"].find(slot)
		if round_index<0 or round_index>=state["rounds"].size(): continue
		var round: Array = state["rounds"][round_index]
		var winners: Array = []
		for game: Array in round:
			if int(game[2])>=0:
				if int(game[4])>=0: winners.append(game[4])
				continue
			var rng := RandomNumberGenerator.new()
			rng.seed = hash([w.world_seed,w.year,state["id"],round_index,game[0],game[1]])
			var team := {}
			if w.is_user_club(game[0]) or w.is_user_club(game[1]): team=select(w,int(state["age"]),date,used)
			var home: float = team["str"] if w.is_user_club(game[0]) else float(state["str"][game[0]])
			var away: float = team["str"] if w.is_user_club(game[1]) else float(state["str"][game[1]])
			game[2]=YouthManager._poisson(rng,clampf(1.40*exp(clampf(home-away,-25,25)*0.048),0.2,4.6))
			game[3]=YouthManager._poisson(rng,clampf(1.22*exp(clampf(away-home,-25,25)*0.048),0.2,4.6))
			var f := Fixture.new();f.home=game[0];f.away=game[1];f.hg=game[2];f.ag=game[3]
			CompetitionManager.apply_to_table(state["table"],f)
			if state["kind"]=="cup":
				if game[2]!=game[3]: game[4]=game[0] if game[2]>game[3] else game[1]
				else:
					var pa:=0;var pb:=0
					for _i in 5:
						pa+=1 if rng.randf()<0.73 else 0;pb+=1 if rng.randf()<0.73 else 0
					var kicks:=0
					while pa==pb and kicks<40:
						pa+=1 if rng.randf()<0.73 else 0;pb+=1 if rng.randf()<0.73 else 0;kicks+=1
					if pa==pb:
						if rng.randf()<0.5: pa+=1
						else: pb+=1
					game[4]=game[0] if pa>pb else game[1]
					game.append({"pens":[pa,pb]})
				winners.append(game[4])
			if not team.is_empty():
				var mine := int(game[2] if w.is_user_club(game[0]) else game[3])
				var theirs := int(game[3] if w.is_user_club(game[0]) else game[2])
				_credit(w,state,team,mine,theirs,rng)
				for entry in team["xi"]:
					used[entry[0].id]=true;d["last_played"][entry[0].id]=date
					if not w.youth.has("match_rest_v1"): w.youth["match_rest_v1"] = {}
					w.youth["match_rest_v1"][entry[0].id]=date
				reports.append({"competition":state["name"],"home":game[0],"away":game[1],"hg":game[2],"ag":game[3],"fillers":team["fillers"]})
		state["stage"]=round_index+1
		if state["kind"]=="cup" and winners.size()>1 and state["rounds"].size()==round_index+1: state["rounds"].append(_pair(winners))
		if (state["kind"]=="cup" and winners.size()==1) or (state["kind"]=="league" and round_index+1==state["rounds"].size()):
			state["champion"]=winners[0] if state["kind"]=="cup" else standings(state)[0]
			NewsManager.post_raw(w,"%s conquista a %s" % [w.club(state["champion"]).short_name,state["name"]],"A competição de desenvolvimento terminou; resultados e minutos ficam no histórico da base.",state["champion"],-1,NewsEvent.IMP_NORMAL,"base")
			if w.is_user_club(state["champion"]):
				var key := "Y:"+String(state["id"])
				w.user_club().titles[key]=int(w.user_club().titles.get(key,0))+1
	return reports

static func standings(c: Dictionary) -> Array:
	var ids: Array = c["clubs"].duplicate()
	ids.sort_custom(func(a,b):
		var x: Dictionary=c["table"][a];var y: Dictionary=c["table"][b]
		if x["pts"]!=y["pts"]:return x["pts"]>y["pts"]
		if x["gf"]-x["ga"]!=y["gf"]-y["ga"]:return x["gf"]-x["ga"]>y["gf"]-y["ga"]
		return x["gf"]>y["gf"] if x["gf"]!=y["gf"] else int(a)<int(b))
	return ids

static func _credit(w: GameWorld, c: Dictionary, team: Dictionary, goals: int, conceded: int, rng: RandomNumberGenerator) -> void:
	var xi: Array = team["xi"]
	var scorer := {}
	var weights: Array = []
	for entry in xi: weights.append(maxf(1.0,float(entry[0].attrs[Attr.FIN])*(0.06 if int(entry[1])==Pos.GK else (1.0 if Pos.group(entry[1])>=2 else 0.22))))
	for _g in goals:
		if xi.is_empty() or rng.randf()>float(xi.size())/11.0:continue # anonymous academy depth can score too
		var idx := RngUtil.weighted_index(rng,weights)
		if idx>=0: scorer[xi[idx][0].id]=int(scorer.get(xi[idx][0].id,0))+1
	for entry in xi:
		var p: Player=entry[0]
		var g:=int(scorer.get(p.id,0))
		var rating:=clampf(6.3+(0.25 if goals>conceded else (-0.25 if goals<conceded else 0.0))+g*0.7+rng.randfn(0,0.35),4.0,10.0)
		p.stats[Player.S_APPS]+=1;p.stats[Player.S_STARTS]+=1;p.stats[Player.S_MINUTES]+=90
		p.stats[Player.S_GOALS]+=g;p.stats[Player.S_RATING_SUM]+=int(round(rating*10));p.push_rating(rating)
		var record: Dictionary=c["records"].get(p.id,{"name":p.display_name(),"apps":0,"minutes":0,"goals":0})
		record["apps"]+=1;record["minutes"]+=90;record["goals"]+=g;c["records"][p.id]=record
