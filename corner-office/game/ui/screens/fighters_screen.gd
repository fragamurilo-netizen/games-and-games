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
	var modes:=add_select("Visualização",[{"id":"roster","label":"Meu elenco"},{"id":"all","label":"Todos os atletas"},{"id":"official","label":"Ranking oficial"},{"id":"wci","label":"World Combat Index"}],mode)
	modes.item_selected.connect(func(i):mode=modes.get_item_metadata(i);refresh())
	var options: Array=[{"id":"","label":"Todas as categorias"}]
	for d: Dictionary in ContentDB.load_json("weight_classes.json"):options.append({"id":d.id,"label":CareerText.division(d.id)})
	var selector:=add_select("Categoria",options,division_filter)
	selector.item_selected.connect(func(i):division_filter=selector.get_item_metadata(i);refresh())
	if mode=="roster":
		for id: String in world.player_org().roster:
			var f: Fighter=world.fighters[id]
			if not division_filter.is_empty() and f.division!=division_filter:continue
			var alert:="  ·  PROPOSTA RIVAL" if Contracts.best_rival_bid(world,f,world.player_org_id)>0 else "  ·  LESIONADO" if not f.injuries.is_empty() else ""
			add_button("%s  ·  %s\n%s · %d anos%s"%[f.display_name(),f.record_string(),CareerText.division(f.division),f.age_on(world.date),alert],func():selected_fighter=f.id;refresh())
	elif mode=="all":
		for f: Fighter in world.fighters.values():
			if f.retired or (not division_filter.is_empty() and f.division!=division_filter):continue
			var org: Organization=world.organizations.get(f.organization_id)
			add_button("%s  ·  %s\n%s · %s"%[f.display_name(),f.record_string(),CareerText.division(f.division),org.short_name if org else "agente livre"],func():selected_fighter=f.id;refresh())
	else:
		add_text("Modelo inicial: resultados e oposição. Listas oficial e mundial separadas.",Tokens.MUTED)
		for d: Dictionary in ContentDB.load_json("weight_classes.json"):
			if not division_filter.is_empty() and d.id!=division_filter:continue
			var ranking:=Rankings.new().latest(world,"wci" if mode=="wci" else world.player_org_id,d.id)
			if ranking==null or ranking.entries.is_empty():continue
			add_heading(CareerText.division(d.id))
			for i in mini(15,ranking.entries.size()):
				var f: Fighter=world.fighters[ranking.entries[i]]
				add_button("%02d  %s  ·  %s"%[i+1,f.display_name(),f.record_string()],func():selected_fighter=f.id;refresh())
func _profile(f: Fighter) -> void:
	add_button("← Voltar à lista",func():selected_fighter="";refresh())
	add_button("EDITAR LUTADOR",func():editing=f.id;feedback="";refresh())
	add_heading(f.display_name());add_text(CareerText.division(f.division)+" · "+f.country+" · %d anos"%f.age_on(Game.world.date))
	if f.retired:add_text("Aposentado em "+GameDate.format(f.retired_on),Tokens.MUTED)
	for injury: Dictionary in f.injuries:add_text("Lesionado (%s) até %s"%[CareerText.injury(str(injury.type)),GameDate.format(injury.until)],Tokens.FIGHT_RED)
	add_text("%s · %d cm · alcance %d cm"%[f.record_string(),f.height_cm,f.reach_cm])
	var o:=FighterEditor.options()
	add_text("%d anos · %s · base: %s%s"%[f.age_on(Game.world.date),_label(o.countries,f.country),FighterGenerator.base_name(f.martial_base),"" if f.fight_style.is_empty() else " · "+_label(o.fight_styles,f.fight_style)],Tokens.MUTED)
	add_text("Guarda %s · %s%s"%[_label(o.stances,f.stance).to_lower(),_label(o.body_types,f.body_type),"" if f.natural_weight_kg<=0 else " · %.1f kg fora do camp"%f.natural_weight_kg],Tokens.MUTED)
	if not f.bio.is_empty():add_text(f.bio,Tokens.MUTED)
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
