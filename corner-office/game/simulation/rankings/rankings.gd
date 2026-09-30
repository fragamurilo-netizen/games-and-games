class_name Rankings
extends RefCounted
## Ranking Engine (Game Design Bible §7 Rankings; MMA Bible §12, §23).
## Listas oficiais por organização e World Combat Index separados, com
## snapshots append-only. O score considera resultado, qualidade de oposição
## (posição no snapshot anterior), recência, sequência e atividade; o modelo
## "panel" soma um viés subjetivo pequeno e estável por avaliador. Saltos são
## limitados sem vitória excepcional, e cada mudança guarda seu motivo.
const WCI_ORG_ID:="wci"
const P4P_DIVISION:="p4p"
var _cfg: Dictionary=ContentDB.load_json("ranking_tuning.json")

static func key(org_id: String,division: String) -> String:return "%s:%s"%[org_id,division]

func latest(world: WorldState,org_id: String,division: String) -> Ranking:
	var history: Array=world.rankings.get(key(org_id,division),[])
	return history.back() if not history.is_empty() else null

## Posição 0-based do lutador na lista mais recente; -1 se fora dela.
func position(world: WorldState,org_id: String,division: String,fighter_id: String) -> int:
	var ranking:=latest(world,org_id,division)
	return ranking.entries.find(fighter_id) if ranking else -1

## Melhor posição já alcançada (0-based) no histórico da lista; -1 se nunca.
func peak(world: WorldState,org_id: String,division: String,fighter_id: String) -> int:
	var best:=-1
	for r: Ranking in world.rankings.get(key(org_id,division),[]):
		var p:=r.entries.find(fighter_id)
		if p>=0 and (best<0 or p<best):best=p
	return best

func update(world: WorldState,org_id: String,division: String) -> Ranking:
	var prev:=latest(world,org_id,division)
	var champion:=_champion(world,org_id,division)
	var scores: Dictionary={}
	var causes: Dictionary={}
	for f: Fighter in world.fighters.values():
		if f.retired or f.division!=division or f.id==champion:continue
		if org_id!=WCI_ORG_ID and f.organization_id!=org_id:continue
		var result:=_score(world,f,prev,org_id)
		scores[f.id]=result.score;causes[f.id]=result.cause
	var ordered:=_order(scores,prev,causes)
	if prev and prev.entries==ordered and prev.champion_id==champion:return prev
	var snapshot:=_snapshot(world,org_id,division,ordered,scores)
	snapshot.champion_id=champion
	snapshot.changes=_changes(prev,ordered,causes)
	return _append(world,snapshot)

## Pound-for-pound do World Combat Index: melhores de cada divisão comparados
## pelo mesmo score esportivo (Game Design Bible §7).
func update_p4p(world: WorldState) -> Ranking:
	var scores: Dictionary={}
	for d: Dictionary in ContentDB.load_json("weight_classes.json"):
		var ranking:=latest(world,WCI_ORG_ID,d.id)
		if ranking==null:continue
		for i in mini(int(_cfg.p4p_per_division),ranking.entries.size()):
			var id: String=ranking.entries[i]
			# Liderar a própria divisão pesa: o #1 de uma categoria vem antes
			# de um #4 com score parecido.
			scores[id]=float(ranking.scores.get(id,0.0))+float(_cfg.p4p_rank_bonus)*(int(_cfg.p4p_per_division)-i)
	var ordered: Array=scores.keys()
	ordered.sort_custom(func(a,b):return scores[a]>scores[b] if scores[a]!=scores[b] else a<b)
	ordered=ordered.slice(0,int(_cfg.p4p_size))
	var prev:=latest(world,WCI_ORG_ID,P4P_DIVISION)
	if prev and prev.entries==ordered:return prev
	var snapshot:=_snapshot(world,WCI_ORG_ID,P4P_DIVISION,ordered,scores)
	snapshot.changes=_changes(prev,ordered,{})
	return _append(world,snapshot)

# ---------------------------------------------------------------- score

func _score(world: WorldState,f: Fighter,prev: Ranking,org_id: String) -> Dictionary:
	var res: Dictionary=_cfg.resume
	var wins:=float(f.record.wins);var losses:=float(f.record.losses)
	var score:=wins*float(res.win)+losses*float(res.loss)+float(res.win_rate)*(wins+1)/(wins+losses+2)
	var cause:=Reason.make("RESULTS_AND_OPPOSITION")
	var last_date: Dictionary={}
	var streak:=0
	var streak_open:=true
	var recent: Array=f.fight_ids.slice(-int(_cfg.recent_fights))
	recent.reverse()   # mais recente primeiro
	for fight_id: String in recent:
		var fight: Fight=world.fights.get(fight_id)
		if fight==null or fight.status!="completed":continue
		var ev: FightEvent=world.events.get(fight.event_id)
		var date: Dictionary=ev.date if ev else world.date
		if last_date.is_empty():last_date=date
		var age:=maxi(0,GameDate.days_between(date,world.date))
		var weight:=pow(.5,float(age)/float(_cfg.recency_half_life_days))
		var opponent_id:=fight.fighter_b_id if fight.fighter_a_id==f.id else fight.fighter_a_id
		var opp_pos:=prev.entries.find(opponent_id) if prev else -1
		var quality:=_quality(world,opponent_id,opp_pos,prev)
		var finish:=fight.method in ["ko_tko","submission"]
		var won:=fight.winner_id==f.id
		var drew:=fight.winner_id.is_empty()
		var delta:=0.0
		if won:
			var w: Dictionary=_cfg.win
			delta=float(w.base)+quality*float(w.opposition)+(float(w.finish) if finish else 0.0)+(float(w.title) if fight.title_stakes in ["title","interim"] else 0.0)
		elif drew:
			delta=float(_cfg.draw)
		else:
			var l: Dictionary=_cfg.loss
			delta=float(l.base)+quality*float(l.opposition_relief)+(float(l.finished) if finish else 0.0)
		# Sequência atual: resultados iguais consecutivos a partir do mais recente.
		if streak_open:
			if won and streak>=0:streak+=1
			elif not won and not drew and streak<=0:streak-=1
			else:streak_open=false
		score+=delta*weight
		if cause.code=="RESULTS_AND_OPPOSITION":
			cause=Reason.make("WIN_OVER" if won else "DRAW_WITH" if drew else "LOSS_TO",delta*weight,{"opponent_id":opponent_id,"opponent_rank":opp_pos,"method":fight.method,"fight_id":fight.id,"date":date})
	score+=float(_cfg.streak_step)*clampi(streak,-int(_cfg.streak_cap),int(_cfg.streak_cap))
	if not last_date.is_empty():
		var inactivity: Dictionary=_cfg.inactivity
		var idle:=GameDate.days_between(last_date,world.date)-int(inactivity.grace_days)
		if idle>0:
			var penalty:=minf(float(inactivity.cap),float(idle)/30.0*float(inactivity.per_month))
			score-=penalty
			if penalty>=float(inactivity.per_month)*3:cause=Reason.make("INACTIVE",-penalty,{"days":idle+int(inactivity.grace_days)})
	if org_id!=WCI_ORG_ID:score+=_panel_bias(org_id,f.id)
	return {"score":score,"cause":cause,"streak":streak}

## Qualidade 0..1 do oponente: posição no ranking anterior, ou cartel.
func _quality(world: WorldState,opponent_id: String,opp_pos: int,prev: Ranking) -> float:
	if opp_pos>=0:return 1.0-float(opp_pos)/float(maxi(15,prev.entries.size()))
	var opponent: Fighter=world.fighters.get(opponent_id)
	if opponent==null:return 0.0
	var record:=float(opponent.record.wins+1)/float(opponent.record.wins+opponent.record.losses+2)
	return record*float(_cfg.unranked_opposition_scale)

## Viés subjetivo do painel: estável por organização e lutador (não é
## sorteio, então não consome world.rng nem embaralha a lista a cada evento).
func _panel_bias(org_id: String,fighter_id: String) -> float:
	var h:=hash(org_id+"|"+fighter_id)
	return (float(h%2001)/1000.0-1.0)*float(_cfg.panel_bias)

# ---------------------------------------------------------------- ordem

## Ordena por score e limita subidas a `max_climb` posições por snapshot,
## salvo vitória excepcional sobre alguém ranqueado acima (MMA Bible §23.8).
func _order(scores: Dictionary,prev: Ranking,causes: Dictionary) -> Array:
	var raw: Array=scores.keys()
	raw.sort_custom(func(a,b):return scores[a]>scores[b] if scores[a]!=scores[b] else a<b)
	if prev==null or prev.entries.is_empty():return raw
	# Posições anteriores só entre quem continua na lista: saídas (aposentadoria,
	# fim de contrato, cinturão) não contam como salto.
	var kept: Array=prev.entries.filter(func(id):return scores.has(id))
	var floor_of: Dictionary={}
	var climb:=int(_cfg.max_climb)
	for i in raw.size():
		var id: String=raw[i]
		var before:=kept.find(id)
		if before<0:before=kept.size()
		var best:=maxi(0,before-climb)
		var cause: Dictionary=causes.get(id,{})
		# Só a vitória nova (depois do snapshot anterior) libera salto maior.
		if cause.get("code","")=="WIN_OVER" and GameDate.days_between(prev.snapshot_date,cause.data.date)>0:
			var opponent:=kept.find(cause.data.opponent_id)
			if opponent>=0:best=mini(best,opponent)
		floor_of[id]=best
		if best>i:causes[id]=Reason.make("JUMP_CAPPED",0,{"limit":climb,"cause":cause})
	# Posição a posição, o melhor score cujo piso já foi alcançado.
	var ordered: Array=[]
	var remaining:=raw.duplicate()
	while not remaining.is_empty():
		var pick: String=remaining[0]
		for id: String in remaining:
			if int(floor_of[id])<=ordered.size():pick=id;break
			if int(floor_of[id])<int(floor_of[pick]):pick=id
		ordered.append(pick);remaining.erase(pick)
	return ordered

func _changes(prev: Ranking,ordered: Array,causes: Dictionary) -> Dictionary:
	var changes: Dictionary={}
	if prev==null:return changes   # primeira lista: nada a comparar
	for i in ordered.size():
		var id: String=ordered[i]
		var before:=prev.entries.find(id) if prev else -1
		if before==i:continue
		var cause: Dictionary=causes.get(id,Reason.make("RESULTS_AND_OPPOSITION"))
		if before<0:cause=Reason.make("NEW_ENTRY",0,{"cause":cause})
		elif not _explains(cause,prev,i<before):cause=Reason.make("OTHERS_MOVED")
		changes[id]={"from":before,"to":i,"reason":cause}
	if prev:
		for id: String in prev.entries:
			if not id in ordered:changes[id]={"from":prev.entries.find(id),"to":-1,"reason":Reason.make("LEFT_LIST")}
	return changes

## Uma luta só explica a mudança se aconteceu depois do snapshot anterior e
## aponta na mesma direção (vitória sobe, derrota desce).
func _explains(cause: Dictionary,prev: Ranking,moved_up: bool) -> bool:
	match cause.code:
		"INACTIVE":return not moved_up
		"JUMP_CAPPED":return moved_up
		"WIN_OVER","LOSS_TO","DRAW_WITH":
			if GameDate.days_between(prev.snapshot_date,cause.data.date)<=0:return false
			return cause.code=="DRAW_WITH" or moved_up==(cause.code=="WIN_OVER")
	return false

# ---------------------------------------------------------------- snapshot

func _champion(world: WorldState,org_id: String,division: String) -> String:
	var org: Organization=world.organizations.get(org_id)
	if org==null:return ""
	var id:=str(org.titles.get(division,{}).get("champion_id",""))
	var f: Fighter=world.fighters.get(id)
	return id if f and not f.retired and f.organization_id==org_id and f.division==division else ""

func _snapshot(world: WorldState,org_id: String,division: String,ordered: Array,scores: Dictionary) -> Ranking:
	var snapshot:=Ranking.new()
	snapshot.id=world.new_id("rank")
	snapshot.organization_id=org_id;snapshot.division=division;snapshot.snapshot_date=world.date.duplicate()
	snapshot.model="algorithmic" if org_id==WCI_ORG_ID else "panel"
	snapshot.entries=ordered
	for id: String in ordered:snapshot.scores[id]=snappedf(float(scores[id]),.01)
	snapshot.explanations=[Reason.make("RESULTS_AND_OPPOSITION",0,{"scores":snapshot.scores})]
	return snapshot

func _append(world: WorldState,snapshot: Ranking) -> Ranking:
	var k:=key(snapshot.organization_id,snapshot.division)
	if not world.rankings.has(k):world.rankings[k]=[]
	world.rankings[k].append(snapshot)
	# Busca o autoload em tempo de execução: ferramentas de linha de comando
	# (career_session, preview_fight) compilam este script antes dos autoloads.
	var tree:=Engine.get_main_loop() as SceneTree
	var bus:=tree.root.get_node_or_null("EventBus") if tree else null
	if bus:bus.ranking_updated.emit(snapshot.organization_id,snapshot.division)
	return snapshot
