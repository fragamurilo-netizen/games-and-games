class_name CareerActions
extends RefCounted
## Application services for the M1 loop. Game Bible §§7–9,12,15,20.
## Both native and web presentation call these methods; no business rules in UI.

static func perform(world: WorldState, action: String, p: Dictionary={}) -> Dictionary:
	var cfg: Dictionary=ContentDB.load_json("career_tuning.json")
	match action:
		"state":return {"ok":true}
		"create_event":
			var ev:=FightEvent.new()
			ev.id=world.new_id("event")
			ev.name=str(p.get("name",cfg.event.name)).strip_edges().left(80)
			if ev.name.is_empty():ev.name=cfg.event.name
			ev.organization_id=world.player_org_id
			ev.date=GameDate.add_days(world.date,clampi(int(p.get("days",cfg.event.notice_days)),14,120))
			ev.venue=cfg.event.venue;ev.city=cfg.event.city;ev.country=cfg.event.country;ev.region=cfg.event.region
			world.add("events",ev)
			return {"ok":true,"event_id":ev.id,"message":"Evento criado. Monte o card antes de anunciar."}
		"evaluate":
			var ev: FightEvent=world.events.get(str(p.get("event_id","")))
			if ev==null or ev.organization_id!=world.player_org_id:return _error("INVALID_EVENT")
			return {"ok":true,"quote":Matchmaking.new().evaluate(world,str(p.get("red","")),str(p.get("blue","")),ev.id,float(p.get("premium",1.0)))}
		"propose":
			var ev: FightEvent=world.events.get(str(p.get("event_id","")))
			if ev==null or ev.organization_id!=world.player_org_id:return _error("INVALID_EVENT")
			if ev.fight_ids.size()>=int(cfg.event.maximum_bouts):return _error("CARD_FULL")
			var fight:=Fight.new()
			fight.event_id=ev.id;fight.fighter_a_id=str(p.get("red",""));fight.fighter_b_id=str(p.get("blue",""))
			fight.division=world.fighters[fight.fighter_a_id].division if world.fighters.has(fight.fighter_a_id) else ""
			fight.reasons=[Reason.make("PURSE_OFFER",clampf(float(p.get("premium",1.0)),1.0,2.0))]
			var response:=Matchmaking.new().propose(world,fight)
			ev.projected=Economy.new().project_event(world,ev)
			return {"ok":true,"proposal":response}
		"remove_bout":
			var fight: Fight=world.fights.get(str(p.get("fight_id","")))
			if fight==null:return _error("INVALID_MATCHUP")
			var ev: FightEvent=world.events[fight.event_id]
			if ev.organization_id!=world.player_org_id or ev.status!="planned":return _error("EVENT_CLOSED")
			fight.status="cancelled";fight.reasons.append(Reason.make("PROMOTER_CANCELLED"))
			ev.fight_ids.erase(fight.id);ev.projected=Economy.new().project_event(world,ev)
			return {"ok":true,"message":"Confronto retirado do card. Histórico preservado."}
		"announce":
			var ev: FightEvent=world.events.get(str(p.get("event_id","")))
			if ev==null or ev.organization_id!=world.player_org_id:return _error("INVALID_EVENT")
			if ev.status!="planned" or GameDate.days_between(world.date,ev.date)<1:return _error("EVENT_CLOSED")
			if ev.fight_ids.size()<int(cfg.event.minimum_bouts):return _error("CARD_TOO_SMALL")
			var seen: Dictionary={}
			for id: String in ev.fight_ids:
				var f: Fight=world.fights[id]
				for fighter_id: String in [f.fighter_a_id,f.fighter_b_id]:
					if seen.has(fighter_id):return _error("ALREADY_BOOKED")
					seen[fighter_id]=true
				var validation:=Matchmaking.new().evaluate(world,f.fighter_a_id,f.fighter_b_id,ev.id,1.0,f.id)
				if not validation.eligible:return {"ok":false,"reasons":validation.reasons}
			ev.projected=Economy.new().project_event(world,ev)
			if world.player_org().cash-reserved_cash(world)<int(ev.projected.costs):return _error("INSUFFICIENT_CASH")
			for i in ev.fight_ids.size():world.fights[ev.fight_ids[i]].card_slot="main_event" if i==ev.fight_ids.size()-1 else "co_main" if i==ev.fight_ids.size()-2 else "main_card" if i>=2 else "prelims"
			ev.status="announced"
			return {"ok":true,"message":"Card anunciado. A noite será simulada na data do evento."}
		"reschedule":
			var ev: FightEvent=world.events.get(str(p.get("event_id","")))
			if ev==null or ev.organization_id!=world.player_org_id or ev.status not in ["planned","postponed"]:return _error("EVENT_CLOSED")
			ev.date=GameDate.add_days(world.date,clampi(int(p.get("days",42)),14,120));ev.status="planned"
			return {"ok":true,"message":"Evento reagendado. Revise o card antes de anunciar novamente."}
		"advance_week":
			WorldSim.new(world).advance_week()
			return {"ok":true,"message":"Semana avançada. Agenda, contratos e eventos atualizados."}
		"advance_event":
			var ev: FightEvent=world.events.get(str(p.get("event_id","")))
			if ev==null or ev.organization_id!=world.player_org_id:return _error("INVALID_EVENT")
			if ev.status!="announced":return _error("EVENT_NOT_ANNOUNCED")
			var sim:=WorldSim.new(world)
			while GameDate.days_between(world.date,ev.date)>0:sim.advance_day()
			sim.run_event(ev.id)
			return {"ok":true,"message":"Evento concluído. Confira resultados, cartões, rankings e finanças." if ev.status=="completed" else "Evento adiado: um atleta ficou indisponível. Revise o card e reagende."}
		"negotiate":
			var id:=str(p.get("fighter_id",""))
			if not world.fighters.has(id):return _error("INVALID_CONTRACT")
			var fighter: Fighter=world.fighters[id]
			var offer:=Contract.new()
			offer.fighter_id=id;offer.organization_id=world.player_org_id
			offer.show_money=int(p.get("show_money",Contracts.market_price(world,fighter)))
			offer.win_bonus=int(offer.show_money*float(cfg.contracts.win_bonus_ratio));offer.bouts_total=int(cfg.contracts.bouts);offer.bouts_remaining=offer.bouts_total
			offer.signing_bonus=int(p.get("signing_bonus",0));offer.expires_on=GameDate.add_days(world.date,int(cfg.contracts.term_days))
			if world.player_org().cash-reserved_cash(world)<offer.signing_bonus:return _error("INSUFFICIENT_CASH")
			var contracts:=Contracts.new();var response:=contracts.evaluate_offer(world,offer)
			if not response.eligible:return {"ok":false,"reasons":response.reasons}
			if offer.show_money<int(response.fair_show):return {"ok":true,"message":"O atleta pede uma bolsa maior.","counter_show":response.counter_show}
			# M1 bargaining uses a clear price floor; agent memory and rival offers remain M2.
			contracts.sign(world,offer)
			Rankings.new().update(world,world.player_org_id,fighter.division)
			return {"ok":true,"message":"Contrato assinado por quatro lutas."}
		# Criador/editor de lutadores (Bible §§4,5,22).
		"create_fighter":return FighterEditor.create(world,p)
		"edit_fighter":return FighterEditor.edit(world,str(p.get("fighter_id","")),p)
		"reroll_fighter":return FighterEditor.reroll(world,str(p.get("fighter_id","")),p)
		"fighter_options":return {"ok":true,"options":FighterEditor.options()}
	return _error("UNKNOWN_ACTION")

static func reserved_cash(world: WorldState) -> int:
	var total:=0
	for ev: FightEvent in world.events.values():
		if ev.organization_id==world.player_org_id and ev.status=="announced":total+=int(ev.projected.get("costs",0))
	return total

static func _error(code: String) -> Dictionary:return {"ok":false,"reasons":[Reason.make(code)]}

static func snapshot(world: WorldState) -> Dictionary:
	var fighters: Array=[];var events: Array=[];var news: Array=[];var tables: Array=[]
	for f: Fighter in world.fighters.values():
		var c: Contract=world.contracts.get(f.contract_id)
		fighters.append({"id":f.id,"name":f.first_name+" "+f.last_name,"sex":f.sex,"country":f.country,"division":f.division,"style":f.martial_base,"record":f.record.duplicate(),"organization_id":f.organization_id,"height_cm":f.height_cm,"reach_cm":f.reach_cm,"appearance":f.appearance.duplicate(true),"show_money":c.show_money if c and c.active else Contracts.market_price(world,f),"bouts_remaining":c.bouts_remaining if c and c.active else 0,"suspension":f.medical_suspension_until.duplicate(),"retired":f.retired,"nickname":f.nickname,"age":f.age_on(world.date),"bio":f.bio,"martial_base":f.martial_base,"discipline":f.discipline,"fight_style":f.fight_style,"stance":f.stance,"body_type":f.body_type,"origin_group":f.origin_group,"personality":f.personality.duplicate()})
	for ev: FightEvent in world.events.values():
		if ev.organization_id!=world.player_org_id:continue
		var item:=ev.to_dict().duplicate(true);item.fights=[]
		for id: String in ev.fight_ids:
			var f: Fight=world.fights[id]
			item.fights.append({"id":f.id,"red":f.fighter_a_id,"blue":f.fighter_b_id,"division":f.division,"slot":f.card_slot,"status":f.status,"winner_id":f.winner_id,"method":f.method,"detail":f.method_detail,"round":f.end_round,"time_s":f.end_time_s,"scorecards":f.scorecards.duplicate(true)})
		events.append(item)
	for item: NewsItem in world.news.values():news.append(item.to_dict())
	for history: Array in world.rankings.values():
		if not history.is_empty() and history[-1].organization_id in [world.player_org_id,"wci"]:tables.append(history[-1].to_dict())
	return {"date":world.date.duplicate(),"seed":world.seed_value,"organization":world.player_org().to_dict().duplicate(true),"reserved_cash":reserved_cash(world),"fighters":fighters,"events":events,"news":news,"rankings":tables,"divisions":ContentDB.load_json("weight_classes.json"),"styles":ContentDB.load_json("fight_visuals.json").styles}
