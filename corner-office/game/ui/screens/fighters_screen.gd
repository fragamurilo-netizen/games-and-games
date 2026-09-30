extends Screen
## Roster/profile and separate ranking views; Bible §§4,7,15.
## Perfil com ficha de atributos em barras, forma recente, histórico e médias.
var division_filter:=""
var selected_fighter:=""
var mode:="roster"
func title() -> String:return "Lutadores"
func receive(payload: Dictionary) -> void:
	if payload.has("fighter_id"):selected_fighter=str(payload.fighter_id)
func build() -> void:
	var world:=Game.world
	if not selected_fighter.is_empty():_profile(world.fighters[selected_fighter]);return
	add_segments([{"id":"roster","label":"Meu elenco"},{"id":"official","label":"Ranking"},{"id":"wci","label":"Mundial"}],mode,func(id):mode=id;refresh())
	var options: Array=[{"id":"","label":"Todas as categorias"}]
	for d: Dictionary in ContentDB.load_json("weight_classes.json"):options.append({"id":d.id,"label":CareerText.division(d.id)})
	var selector:=add_select("Categoria",options,division_filter)
	selector.item_selected.connect(func(i):division_filter=selector.get_item_metadata(i);refresh())
	if mode=="roster":
		for id: String in world.player_org().roster:
			var f: Fighter=world.fighters[id]
			if not division_filter.is_empty() and f.division!=division_filter:continue
			var run:=CareerStats.streak_label(CareerStats.streak(world,f))
			add_button("%s  ·  %s\n%s"%[f.display_name(),f.record_string(),CareerText.division(f.division)+("  ·  "+run if not run.is_empty() else "")],func():selected_fighter=f.id;refresh())
	else:
		add_text("Modelo inicial: resultados e oposição. Listas oficial e mundial separadas.",Tokens.MUTED)
		for d: Dictionary in ContentDB.load_json("weight_classes.json"):
			if not division_filter.is_empty() and d.id!=division_filter:continue
			var ranking:=Rankings.new().latest(world,"wci" if mode=="wci" else world.player_org_id,d.id)
			if ranking==null or ranking.entries.is_empty():continue
			if not add_section(CareerText.division(d.id),division_filter!="" or d==ContentDB.load_json("weight_classes.json")[0]):continue
			for i in mini(15,ranking.entries.size()):
				var f: Fighter=world.fighters[ranking.entries[i]]
				add_button("%02d  %s  ·  %s"%[i+1,f.display_name(),f.record_string()],func():selected_fighter=f.id;refresh())
func _profile(f: Fighter) -> void:
	var w:=Game.world
	add_button("← Voltar à lista",func():selected_fighter="";refresh())
	add_heading(f.display_name());add_text(CareerText.division(f.division)+" · "+f.country+" · base "+f.martial_base,Tokens.MUTED)
	var run:=CareerStats.streak(w,f)
	var methods:=CareerStats.win_methods(w,f)
	add_tiles([
		StatWidgets.tile("Cartel",f.record_string(),"V-D-E",true),
		StatWidgets.tile("Sequência","%+d"%run if run!=0 else "—",CareerStats.streak_label(run)),
		StatWidgets.tile("Altura / alcance","%d/%d"%[f.height_cm,f.reach_cm],"cm"),
		StatWidgets.tile("Vitórias registradas","%d/%d/%d"%[methods.ko_tko,methods.submission,methods.decision],"KO · finalização · decisão"),
	])
	add_text("FORMA RECENTE",Tokens.MUTED)
	var strip:=StatWidgets.Form.new();strip.results=CareerStats.form(w,f);add_node(strip)
	var groups: Array=[["Trocação",f.striking],["Wrestling",f.grappling],["Jiu-jítsu",f.jiu_jitsu],["Físico",f.physical],["Mental",f.mental]]
	for group: Array in groups:
		var values: Dictionary=group[1]
		if values.is_empty():continue
		if not add_section("%s  %d"%[group[0],roundi(CareerStats.group_average(values))],group[0]=="Trocação"):continue
		for key: String in values:
			var v:=float(values[key])
			add_bar(CareerText.attribute(key),v,100,"",StatWidgets.attribute_color(v))
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
		if c:add_text("%s por apresentação · %d lutas restantes"%[CareerText.money(c.show_money),c.bouts_remaining])
func _watch(fight: Fight) -> void:
	var viewer:=FightReplayView.new()
	viewer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(viewer)
	viewer.open(FightReplayBuilder.build(Game.world,fight))
