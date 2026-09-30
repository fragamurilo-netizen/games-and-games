extends Screen
## Roster/profile and separate ranking views; Bible §§4,7,15.
var division_filter:=""
var selected_fighter:=""
var mode:="roster"
func title() -> String:return "Lutadores"
func build() -> void:
	var world:=Game.world
	if not selected_fighter.is_empty():_profile(world.fighters[selected_fighter]);return
	var modes:=add_select("Visualização",[{"id":"roster","label":"Meu elenco"},{"id":"official","label":"Ranking oficial"},{"id":"wci","label":"World Combat Index"}],mode)
	modes.item_selected.connect(func(i):mode=modes.get_item_metadata(i);refresh())
	var options: Array=[{"id":"","label":"Todas as categorias"}]
	for d: Dictionary in ContentDB.load_json("weight_classes.json"):options.append({"id":d.id,"label":CareerText.division(d.id)})
	var selector:=add_select("Categoria",options,division_filter)
	selector.item_selected.connect(func(i):division_filter=selector.get_item_metadata(i);refresh())
	if mode=="roster":
		for id: String in world.player_org().roster:
			var f: Fighter=world.fighters[id]
			if not division_filter.is_empty() and f.division!=division_filter:continue
			add_button("%s  ·  %s\n%s"%[f.display_name(),f.record_string(),CareerText.division(f.division)],func():selected_fighter=f.id;refresh())
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
	add_heading(f.display_name());add_text(CareerText.division(f.division)+" · "+f.country)
	add_text("%s · %d cm · alcance %d cm"%[f.record_string(),f.height_cm,f.reach_cm])
	add_text("%d anos · base: %s · %s · %.1f kg fora do camp"%[f.age_on(Game.world.date),FighterGenerator.base_name(f.martial_base),f.body_type,f.natural_weight_kg],Tokens.MUTED)
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
		if c:add_text("%s por apresentação · %d lutas restantes"%[CareerText.money(c.show_money),c.bouts_remaining])
