extends Screen
## Roster/profile and separate ranking views; Bible §§4,7,15.
## Perfil com ficha de atributos em barras, forma recente, histórico e médias.
var division_filter:=""
var selected_fighter:=""
var mode:="roster"
var editing:=""  # "" = nada, "new" = criar, id = editar
func title() -> String:return "Lutadores"
func receive(payload: Dictionary) -> void:
	if payload.get("reset",false):selected_fighter=""
	if payload.has("fighter_id"):selected_fighter=str(payload.fighter_id)
	if payload.has("mode"):mode=str(payload.mode);selected_fighter=str(payload.get("fighter_id",""))
	if payload.has("division"):division_filter=str(payload.division)
func snapshot() -> Dictionary:
	var s:=super.snapshot();s.merge({"fighter_id":selected_fighter,"mode":mode,"division":division_filter});return s
func build() -> void:
	var world:=Game.world
	if editing=="new":
		FighterEditorForm.build_create(self,func(id: String):selected_fighter=id;editing=id;refresh(),func():editing="";refresh());return
	if not editing.is_empty():
		FighterEditorForm.build_edit(self,world.fighters[editing],func():editing="";refresh());return
	if not selected_fighter.is_empty():_profile(world.fighters[selected_fighter]);return
	add_button("＋ CRIAR LUTADOR",func():editing="new";feedback="";refresh())
	add_segments([{"id":"roster","label":"Meu elenco"},{"id":"all","label":"Todos"},{"id":"official","label":"Ranking"},{"id":"wci","label":"Mundial"},{"id":"p4p","label":"P4P"}],mode,func(id):mode=id;refresh())
	var options: Array=[{"id":"","label":"Todas as categorias"}]
	for d: Dictionary in ContentDB.load_json("weight_classes.json"):options.append({"id":d.id,"label":CareerText.division(d.id)})
	if mode!="p4p":
		var selector:=add_select("Categoria",options,division_filter)
		selector.item_selected.connect(func(i):division_filter=selector.get_item_metadata(i);refresh())
	if mode=="roster":
		for id: String in world.player_org().roster:
			var f: Fighter=world.fighters[id]
			if not division_filter.is_empty() and f.division!=division_filter:continue
			var run:=CareerStats.streak_label(CareerStats.streak(world,f))
			var alert:="  ·  PROPOSTA RIVAL" if Contracts.best_rival_bid(world,f,world.player_org_id)>0 else "  ·  LESIONADO" if not f.injuries.is_empty() else ""
			_fighter_row(f,"%s  ·  %s\n%s · %d anos%s"%[f.display_name(),f.record_string(),CareerText.division(f.division)+("  ·  "+run if not run.is_empty() else ""),f.age_on(world.date),alert])
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
			_ranking_list(world,org_id,d.id,CareerText.division(d.id),false,division_filter!="" or d==ContentDB.load_json("weight_classes.json")[0])

func _ranking_list(world: WorldState,org_id: String,division: String,heading: String,show_division: bool,open: bool=true) -> void:
	var ranking:=Rankings.new().latest(world,org_id,division)
	if ranking==null or (ranking.entries.is_empty() and ranking.champion_id.is_empty()):return
	if not add_section(heading,open):return
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
	var w:=Game.world
	add_button("Editar lutador",func():editing=f.id;feedback="";refresh(),"Muda nome, país, estilo, físico e atributos deste atleta.")
	var run:=CareerStats.streak(w,f)
	var methods:=CareerStats.win_methods(w,f)
	# Foto à esquerda, ficha à direita (quadro de retrato dos menus de 2012).
	var top:=HBoxContainer.new();top.add_theme_constant_override("separation",Tokens.SPACE_M)
	top.add_child(StatWidgets.portrait_frame(f,200))
	var sheet:=VBoxContainer.new();sheet.size_flags_horizontal=SIZE_EXPAND_FILL
	sheet.add_theme_constant_override("separation",Tokens.SPACE_S)
	sheet.add_child(Ud3Chrome.header_bar("Ficha do atleta"))
	var who:=Label.new();who.text="%s\n%s · %d anos"%[f.display_name(),CareerText.division(f.division),f.age_on(w.date)]
	who.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;who.add_theme_font_size_override("font_size",20);sheet.add_child(who)
	sheet.add_child(StatWidgets.tile_row([
		StatWidgets.tile("Cartel",f.record_string(),"V-D-E",true),
		StatWidgets.tile("Sequência","%+d"%run if run!=0 else "—",CareerStats.streak_label(run)),
	],0))
	top.add_child(sheet);add_node(top)
	if f.retired:add_text("Aposentado em "+GameDate.format(f.retired_on),Tokens.MUTED)
	for injury: Dictionary in f.injuries:add_text("Lesionado (%s) até %s"%[CareerText.injury(str(injury.type)),GameDate.format(injury.until)],Tokens.FIGHT_RED)
	var o:=FighterEditor.options()
	add_text("%s · %s%s"%[_label(o.countries,f.country),FighterGenerator.discipline_name(f),"" if f.fight_style.is_empty() else " · "+_label(o.fight_styles,f.fight_style)],Tokens.MUTED)
	add_text("Guarda %s · %s%s"%[_label(o.stances,f.stance).to_lower(),_label(o.body_types,f.body_type),"" if f.natural_weight_kg<=0 else " · %.1f kg fora do camp"%f.natural_weight_kg],Tokens.MUTED)
	if not f.bio.is_empty():add_text(f.bio,Tokens.MUTED)
	_ranking_summary(f)
	add_tiles([
		StatWidgets.tile("Altura / alcance","%d/%d"%[f.height_cm,f.reach_cm],"cm"),
		StatWidgets.tile("Vitórias registradas","%d/%d/%d"%[methods.ko_tko,methods.submission,methods.decision],"KO · finalização · decisão"),
	])
	_links(f)
	add_label("Forma recente")
	var strip:=StatWidgets.Form.new();strip.results=CareerStats.form(w,f);add_node(strip)
	var groups: Array=[["Trocação",f.striking],["Wrestling",f.grappling],["Jiu-jítsu",f.jiu_jitsu],["Físico",f.physical],["Mental",f.mental]]
	for group: Array in groups:
		var values: Dictionary=group[1]
		if values.is_empty():continue
		if not add_section("%s  ·  %d"%[group[0],roundi(CareerStats.group_average(values))],group[0]=="Trocação"):continue
		var rows: Array=[]
		for key: String in values:rows.append([CareerText.attribute(key),str(roundi(float(values[key])))])
		add_node(StatWidgets.table(["Atributo","Nota"],rows,[.75,.25]))
	var avg:=CareerStats.fight_averages(w,f)
	if avg.fights>0 and add_section("Números por luta"):
		add_bar("Golpes conectados",avg.landed,maxf(60.0,avg.landed),"%.1f"%avg.landed)
		add_bar("Precisão",avg.accuracy*100,100,"%d%%"%roundi(avg.accuracy*100),Tokens.FIGHT_RED if avg.accuracy>=.5 else Tokens.INK)
		add_bar("Quedas",avg.takedowns,maxf(4.0,avg.takedowns),"%.1f"%avg.takedowns)
		add_bar("Knockdowns",avg.knockdowns,maxf(2.0,avg.knockdowns),"%.1f"%avg.knockdowns)
		add_bar("Tentativas de finalização",avg.submission_attempts,maxf(3.0,avg.submission_attempts),"%.1f"%avg.submission_attempts)
	var fights:=CareerStats.completed_fights(w,f)
	if not fights.is_empty() and add_section("Histórico"):
		for fight: Fight in fights.slice(0,8):
			var opponent: Fighter=w.fighters[fight.fighter_b_id if fight.fighter_a_id==f.id else fight.fighter_a_id]
			var result:="EMPATE" if fight.winner_id.is_empty() else "VITÓRIA" if fight.winner_id==f.id else "DERROTA"
			var ev: FightEvent=w.events.get(fight.event_id)
			add_button("%s × %s\n%s · R%d %d:%02d · %s"%[result,opponent.display_name(),CareerStats.METHOD_LABELS.get(fight.method,fight.method),fight.end_round,fight.end_time_s/60,fight.end_time_s%60,ev.name if ev else ""],func():_watch(fight))
	if not f.medical_suspension_until.is_empty():add_text("Repouso até "+GameDate.format(f.medical_suspension_until),Tokens.FIGHT_RED)
	if f.organization_id==w.player_org_id:
		var c: Contract=w.contracts.get(f.contract_id)
		if c:add_text("%s por apresentação · %d lutas restantes · vence em %s"%[CareerText.money(c.show_money),c.bouts_remaining,GameDate.format(c.expires_on)])
		for org_id: String in f.rival_interest:
			add_text("%s oferece %s por luta. Renove no Mercado cobrindo a proposta antes do fim do contrato."%[w.organizations[org_id].short_name,CareerText.money(int(f.rival_interest[org_id].show))],Tokens.FIGHT_RED)

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
## Atalhos da ficha para o resto da central.
func _links(f: Fighter) -> void:
	var w:=Game.world
	var booked: FightEvent=null
	for ev: FightEvent in w.events.values():
		if ev.status in ["planned","announced"]:
			for id: String in ev.fight_ids:
				var fight: Fight=w.fights[id]
				if f.id in [fight.fighter_a_id,fight.fighter_b_id]:booked=ev
	if booked and booked.organization_id==w.player_org_id:
		add_button("Próxima luta: %s · %s"%[booked.name,GameDate.format(booked.date)],func():navigate.emit("events",{"event_id":booked.id}))
	elif booked:add_text("Escalado em %s · %s"%[booked.name,GameDate.format(booked.date)],Tokens.MUTED)
	elif f.organization_id==w.player_org_id:
		var next:=CareerStats.next_event(w)
		if next and next.status=="planned":add_button("Escalar em %s"%next.name,func():navigate.emit("events",{"event_id":next.id,"red":f.id}))
	if f.organization_id.is_empty():add_button("Negociar contrato",func():navigate.emit("market",{"fighter_id":f.id}))
	add_button("Ver ranking da categoria",func():navigate.emit("fighters",{"mode":"official","division":f.division}))
func _watch(fight: Fight) -> void:
	var viewer:=FightReplayView.new()
	viewer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(viewer)
	viewer.open(FightReplayBuilder.build(Game.world,fight))
