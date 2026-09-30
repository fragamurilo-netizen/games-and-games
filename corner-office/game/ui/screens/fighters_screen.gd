extends Screen
## Roster/profile and separate ranking views; Bible §§4,7,15.
var division_filter:=""
var selected_fighter:=""
var mode:="roster"
var editing:=""  # "" = nada, "new" = criar, id = editar
func title() -> String:return "Lutadores"
func build() -> void:
	var world:=Game.world
	if editing=="new":
		FighterEditorForm.build_create(self,func(id: String):selected_fighter=id;editing=id;refresh(),func():editing="";refresh());return
	if not editing.is_empty():
		FighterEditorForm.build_edit(self,world.fighters[editing],func():editing="";refresh());return
	if not selected_fighter.is_empty():_profile(world.fighters[selected_fighter]);return
	add_button("＋ CRIAR LUTADOR",func():editing="new";feedback="";refresh())
	var modes:=add_select("Visualização",[{"id":"roster","label":"Meu elenco"},{"id":"all","label":"Todos os atletas"},{"id":"official","label":"Ranking oficial"},{"id":"wci","label":"World Combat Index"},{"id":"p4p","label":"Pound-for-pound (WCI)"}],mode)
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
			var alert:="  ·  PROPOSTA RIVAL" if Contracts.best_rival_bid(world,f,world.player_org_id)>0 else "  ·  LESIONADO" if not f.injuries.is_empty() else ""
			_fighter_row(f,"%s  ·  %s\n%s · %d anos%s"%[f.display_name(),f.record_string(),CareerText.division(f.division),f.age_on(world.date),alert])
	elif mode=="all":
		for f: Fighter in world.fighters.values():
			if f.retired or (not division_filter.is_empty() and f.division!=division_filter):continue
			var org: Organization=world.organizations.get(f.organization_id)
			_fighter_row(f,"%s  ·  %s\n%s · %s"%[f.display_name(),f.record_string(),CareerText.division(f.division),org.short_name if org else "agente livre"])
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
		_fighter_row(champ,"C   %s  ·  %s"%[champ.display_name(),champ.record_string()])
	for i in mini(15,ranking.entries.size()):
		var f: Fighter=world.fighters[ranking.entries[i]]
		var line:="%02d  %s  %s  ·  %s"%[i+1,_movement(ranking.changes.get(f.id,{})),f.display_name(),f.record_string()]
		if show_division:line+="\n"+CareerText.division(f.division)
		var why:=_change_text(world,ranking.changes.get(f.id,{}))
		if not why.is_empty():line+="\n"+why
		_fighter_row(f,line)

func _fighter_row(f: Fighter,text: String) -> void:
	add_fighter_row(f,text,func():selected_fighter=f.id;refresh())

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
	add_button("EDITAR LUTADOR",func():editing=f.id;feedback="";refresh())
	add_portrait(f)
	add_heading(f.display_name());add_text(CareerText.division(f.division)+" · "+f.country+" · %d anos"%f.age_on(Game.world.date))
	if f.retired:add_text("Aposentado em "+GameDate.format(f.retired_on),Tokens.MUTED)
	for injury: Dictionary in f.injuries:add_text("Lesionado (%s) até %s"%[CareerText.injury(str(injury.type)),GameDate.format(injury.until)],Tokens.FIGHT_RED)
	add_text("%s · %d cm · alcance %d cm"%[f.record_string(),f.height_cm,f.reach_cm])
	var o:=FighterEditor.options()
	add_text("%d anos · %s · %s%s"%[f.age_on(Game.world.date),_label(o.countries,f.country),FighterGenerator.discipline_name(f),"" if f.fight_style.is_empty() else " · "+_label(o.fight_styles,f.fight_style)],Tokens.MUTED)
	add_text("Guarda %s · %s%s"%[_label(o.stances,f.stance).to_lower(),_label(o.body_types,f.body_type),"" if f.natural_weight_kg<=0 else " · %.1f kg fora do camp"%f.natural_weight_kg],Tokens.MUTED)
	if not f.bio.is_empty():add_text(f.bio,Tokens.MUTED)
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
		if c:add_text("%s por apresentação · %d lutas restantes · vence em %s"%[CareerText.money(c.show_money),c.bouts_remaining,GameDate.format(c.expires_on)])
		for org_id: String in f.rival_interest:
			add_text("%s oferece %s por luta. Renove no Mercado cobrindo a proposta antes do fim do contrato."%[Game.world.organizations[org_id].short_name,CareerText.money(int(f.rival_interest[org_id].show))],Tokens.FIGHT_RED)

func _label(options: Array, id: String) -> String:
	for option: Dictionary in options:
		if option.id==id:return str(option.label)
	return id

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
