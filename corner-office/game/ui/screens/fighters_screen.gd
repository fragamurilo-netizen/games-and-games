extends Screen
## Roster/profile and separate ranking views; Bible §§4,7,15.
var division_filter:=""
var selected_fighter:=""
var mode:="roster"
func title() -> String:return "Lutadores"
func build() -> void:
	var world:=Game.world
	if not selected_fighter.is_empty():_profile(world.fighters[selected_fighter]);return
	var modes:=add_select("Visualização",[{"id":"roster","label":"Meu elenco"},{"id":"official","label":"Ranking oficial"},{"id":"wci","label":"World Combat Index"},{"id":"p4p","label":"Pound-for-pound (WCI)"}],mode)
	modes.item_selected.connect(func(i):mode=modes.get_item_metadata(i);refresh())
	var options: Array=[{"id":"","label":"Todas as categorias"}]
	for d: Dictionary in ContentDB.load_json("weight_classes.json"):options.append({"id":d.id,"label":CareerText.division(d.id)})
	if mode!="p4p":
		var selector:=add_select("Categoria",options,division_filter)
		selector.item_selected.connect(func(i):division_filter=selector.get_item_metadata(i);refresh())
	if mode=="roster":
		for id: String in world.player_org().roster:
			var f: Fighter=world.fighters[id]
			if not division_filter.is_empty() and f.division!=division_filter:continue
			add_button("%s  ·  %s\n%s"%[f.display_name(),f.record_string(),CareerText.division(f.division)],func():selected_fighter=f.id;refresh())
	elif mode=="p4p":
		_ranking_list(world,Rankings.WCI_ORG_ID,Rankings.P4P_DIVISION,"Pound-for-pound",true)
	else:
		var org_id:=Rankings.WCI_ORG_ID if mode=="wci" else world.player_org_id
		add_text("Índice independente e algorítmico: resultados, oposição, recência e atividade." if mode=="wci" else "Painel da organização: resultados, qualidade de oposição, sequência e atividade. Subidas limitadas sem vitória sobre alguém acima.",Tokens.MUTED)
		for d: Dictionary in ContentDB.load_json("weight_classes.json"):
			if not division_filter.is_empty() and d.id!=division_filter:continue
			_ranking_list(world,org_id,d.id,CareerText.division(d.id),false)

func _ranking_list(world: WorldState,org_id: String,division: String,heading: String,show_division: bool) -> void:
	var ranking:=Rankings.new().latest(world,org_id,division)
	if ranking==null or (ranking.entries.is_empty() and ranking.champion_id.is_empty()):return
	add_heading(heading)
	add_text("Atualizado em "+GameDate.format(ranking.snapshot_date),Tokens.MUTED)
	if not ranking.champion_id.is_empty():
		var champ: Fighter=world.fighters[ranking.champion_id]
		add_button("C   %s  ·  %s"%[champ.display_name(),champ.record_string()],func():selected_fighter=champ.id;refresh())
	for i in mini(15,ranking.entries.size()):
		var f: Fighter=world.fighters[ranking.entries[i]]
		var line:="%02d  %s  %s  ·  %s"%[i+1,_movement(ranking.changes.get(f.id,{})),f.display_name(),f.record_string()]
		if show_division:line+="\n"+CareerText.division(f.division)
		var why:=_change_text(world,ranking.changes.get(f.id,{}))
		if not why.is_empty():line+="\n"+why
		add_button(line,func():selected_fighter=f.id;refresh())

## Seta de movimento em relação ao snapshot anterior.
static func _movement(change: Dictionary) -> String:
	if change.is_empty():return "="
	if int(change.from)<0:return "NOVO"
	var delta:=int(change.from)-int(change.to)
	return ("▲%d" if delta>0 else "▼%d")%absi(delta)

## Motivo da última mudança, a partir do reason code do Ranking Engine.
static func _change_text(world: WorldState,change: Dictionary) -> String:
	if change.is_empty():return ""
	var reason: Dictionary=change.reason
	if reason.code in ["NEW_ENTRY","JUMP_CAPPED"] and reason.data.has("cause") and reason.data.cause.code in ["WIN_OVER","LOSS_TO","DRAW_WITH","JUMP_CAPPED"]:
		var prefix:="Estreia na lista. " if reason.code=="NEW_ENTRY" else "Subida limitada a %d posições. "%int(reason.data.limit)
		return prefix+_change_text(world,{"reason":reason.data.cause})
	match reason.code:
		"WIN_OVER","LOSS_TO","DRAW_WITH":
			var opp: Fighter=world.fighters.get(reason.data.opponent_id)
			var name:=opp.display_name() if opp else "?"
			var rank:=int(reason.data.opponent_rank)
			if rank>=0:name+=" (#%d)"%(rank+1)
			var verb: String={"WIN_OVER":"Venceu","LOSS_TO":"Perdeu para","DRAW_WITH":"Empatou com"}[reason.code]
			var method: String={"ko_tko":" por nocaute","submission":" por finalização","decision":" na decisão"}.get(str(reason.data.method),"")
			return "%s %s%s."%[verb,name,method]
		"INACTIVE":return "Inativo há %d meses."%(int(reason.data.days)/30)
		"NEW_ENTRY":return "Estreia na lista."
		"JUMP_CAPPED":return "Subida limitada a %d posições."%int(reason.data.limit)
		"OTHERS_MOVED":return "Movido por resultados de outros."
	return ""

func _profile(f: Fighter) -> void:
	add_button("← Voltar à lista",func():selected_fighter="";refresh())
	add_heading(f.display_name());add_text(CareerText.division(f.division)+" · "+f.country)
	add_text("%s · %d cm · alcance %d cm"%[f.record_string(),f.height_cm,f.reach_cm])
	add_text("Base: "+f.martial_base,Tokens.MUTED)
	_ranking_summary(f)
	var groups: Dictionary={"Trocação":f.striking,"Wrestling":f.grappling,"Jiu-jítsu":f.jiu_jitsu}
	for group: String in groups:
		add_heading(group)
		var line: Array=[]
		for key: String in groups[group]:line.append("%s %d"%[key.replace("_"," "),groups[group][key]])
		add_text(" · ".join(line),Tokens.MUTED)
	if not f.medical_suspension_until.is_empty():add_text("Repouso até "+GameDate.format(f.medical_suspension_until))
	if f.organization_id==Game.world.player_org_id:
		var c: Contract=Game.world.contracts.get(f.contract_id)
		if c:add_text("%s por apresentação · %d lutas restantes"%[CareerText.money(c.show_money),c.bouts_remaining])

func _ranking_summary(f: Fighter) -> void:
	var world:=Game.world;var rankings:=Rankings.new();var parts: Array=[]
	if not f.organization_id.is_empty():
		var official:=rankings.latest(world,f.organization_id,f.division)
		if official and official.champion_id==f.id:parts.append("Campeão")
		else:
			var pos:=rankings.position(world,f.organization_id,f.division,f.id)
			if pos>=0:parts.append("Oficial #%d (melhor #%d)"%[pos+1,rankings.peak(world,f.organization_id,f.division,f.id)+1])
	var wci:=rankings.position(world,Rankings.WCI_ORG_ID,f.division,f.id)
	if wci>=0:parts.append("WCI #%d"%(wci+1))
	var p4p:=rankings.position(world,Rankings.WCI_ORG_ID,Rankings.P4P_DIVISION,f.id)
	if p4p>=0:parts.append("P4P #%d"%(p4p+1))
	add_text(" · ".join(parts) if not parts.is_empty() else "Sem ranking",Tokens.MUTED)
