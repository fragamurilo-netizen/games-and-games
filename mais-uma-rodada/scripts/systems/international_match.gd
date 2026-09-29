class_name InternationalMatch
extends RefCounted
## Full MatchSimulation for the managed national team; no global club IDs or club stats changed.
static func play(env: NationalTeamManager.Env, a: String, b: String, a_home: bool, b_home: bool, knockout: bool) -> Dictionary:
	var world := env.world
	# A player injured in the first fixture cannot start the next one in the same window.
	for code in [a,b]:
		var ids: Array = env.squad(code).map(func(player): return player.id)
		env.squads[code] = NationalTeamManager._from_preset(env,code,ids,InternationalCareer.eligible(world,code))
	var home := _team(world,a,env.squad(a),-1001)
	var away := _team(world,b,env.squad(b),-1002)
	if home.sheet.starters.has(-1) or away.sheet.starters.has(-1): return {}
	var sim := MatchSimulation.new()
	var seed_value := env.rng.randi()
	var managed := InternationalCareer.nation(world)
	# Nominal 'home' need not be the host: reverse both sides for a host listed second.
	var reverse := b_home and not a_home
	var h := away if reverse else home
	var v := home if reverse else away
	sim.setup(world,h,v,h.sheet,v.sheet,{"international":true,"national_user":managed,"neutral":not a_home and not b_home,
		"competition":"INTERNATIONAL","attendance":45000,"ko":knockout,"importance":0.75},seed_value,false)
	sim.run_to_end()
	if not sim.finished: return {}
	var r := sim.to_result()
	var ga := int(r["ag"] if reverse else r["hg"])
	var gb := int(r["hg"] if reverse else r["ag"])
	var pens: Array = r.get("pens",[])
	var pa := -1; var pb := -1
	if pens.size() == 2:
		pa = int(pens[1] if reverse else pens[0]); pb = int(pens[0] if reverse else pens[1])
	var winner := (a if ga > gb else b) if ga != gb else ((a if pa > pb else b) if pa >= 0 else "")
	var result := {"a":a,"b":b,"ga":ga,"gb":gb,"et":r.get("et",false),"pa":pa,"pb":pb,"w":winner,"sc":[],
		"engine":"MatchSimulation","xg":[sim.teams[1 if reverse else 0].xg,sim.teams[0 if reverse else 1].xg],
		"kits":[home.kit_home,away.kit_away],"decisions":sim.coach_log.duplicate(true)}
	for side in 2:
		var nation_code := h.key if side == 0 else v.key
		for line: Array in r["lines"][side]:
			if int(line[QuickMatch.L_MINS]) <= 0: continue
			var p: Player = line[QuickMatch.L_P]
			NationalTeamManager.add_caps(world,p.id,1,int(line[QuickMatch.L_G]),int(line[QuickMatch.L_A]))
			env.called[p.id] = true
			env.native_players[p.id] = true
			env.minutes[p.id] = int(env.minutes.get(p.id,0)) + int(line[QuickMatch.L_MINS])
			env.goals[p.id] = int(env.goals.get(p.id,0))+int(line[QuickMatch.L_G])
			for _g in int(line[QuickMatch.L_G]): result["sc"].append([p.id,nation_code])
			# International minutes leave fatigue, not club appearances or club goals.

			if int(line[QuickMatch.L_INJ]) > 0:
				p.injury_weeks = maxi(p.injury_weeks,int(line[QuickMatch.L_INJ]))
				p.injury_name = InjuryTable.name_for(p.injury_weeks,p.id+world.year)
	return result

static func _team(w: GameWorld, code: String, squad: Array, id: int) -> Club:
	var c := Club.new()
	c.id = id; c.key = code; c.nation = code
	c.name = DatabaseManager.nation_name(code); c.short_name = c.name; c.abbr = code
	c.capacity = 50000; c.cohesion = float(InternationalCareer.plan(w,code)["cohesion"])
	c.player_ids = squad.map(func(p): return p.id)
	c.sheet = InternationalCareer.sheet(w,code,squad)
	c.kit_home = NationalKits.home(w,code)
	c.kit_away = NationalKits.kits(w,code)["away"]
	c.color1 = c.kit_home["c1"]; c.color2 = c.kit_home["c2"]
	return c
