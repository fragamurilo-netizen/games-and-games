extends Screen
## Touch-first fight-card builder, backed only by CareerActions. Bible §§7–8,15.
var selected_event:=""
var red_id:=""
var blue_id:=""
var premium:=1.0
var quote: Dictionary={}
var creating:=false
func title() -> String:return "Eventos"
func build() -> void:
	var w:=Game.world
	var options: Array=[]
	for ev: FightEvent in w.events.values():
		if ev.organization_id==w.player_org_id:options.append({"id":ev.id,"label":ev.name+" / "+GameDate.format(ev.date)})
	add_button("+ Criar evento",func():creating=not creating;refresh())
	if creating or options.is_empty():
		var event_name:=add_input("Nome da noite","Noite de Combate %d"%[options.size()+1]);event_name.max_length=80
		var days:=add_number("Dias de preparação",42,14,120)
		add_button("Criar card",func():
			var result:=await run_action("create_event",{"name":event_name.text,"days":int(days.value)})
			if result.get("ok"):selected_event=result.event_id;creating=false
			refresh())
		return
	if not w.events.has(selected_event):selected_event=options[-1].id
	var select:=add_select("Evento",options,selected_event)
	select.item_selected.connect(func(i):selected_event=select.get_item_metadata(i);quote={};red_id="";blue_id="";refresh())
	var ev: FightEvent=w.events[selected_event]
	add_heading(ev.name)
	add_text("%s · %s · %d lutas"%[GameDate.format(ev.date),CareerText.event_status(ev.status),ev.fight_ids.size()],Tokens.FIGHT_RED)
	for i in ev.fight_ids.size():
		var f: Fight=w.fights[ev.fight_ids[i]]
		var a: Fighter=w.fighters[f.fighter_a_id];var b: Fighter=w.fighters[f.fighter_b_id]
		add_face_off(a,b,"%02d\n%s\n×\n%s\n%s"%[i+1,a.display_name(),b.display_name(),CareerText.division(f.division)])
		if f.status=="completed":
			add_text("%s · %s · R%d %d:%02d"%[w.fighters[f.winner_id].display_name() if not f.winner_id.is_empty() else "Empate",f.method,f.end_round,f.end_time_s/60,f.end_time_s%60])
			add_button("Assistir à luta",func():_watch(f))
		elif ev.status=="planned":add_button("Retirar confronto",func():await run_action("remove_bout",{"fight_id":f.id});quote={};refresh())
	if ev.status=="postponed" or (ev.status=="planned" and GameDate.days_between(w.date,ev.date)<1):
		add_button("Reagendar para daqui a 60 dias",func():await run_action("reschedule",{"event_id":ev.id,"days":60});refresh())
	if ev.status=="planned":_matchmaker(ev)
	var finance: Dictionary=ev.actual if ev.status=="completed" else ev.projected
	if not finance.is_empty():
		add_heading("Balanço" if ev.status=="completed" else "Previsão")
		add_text("Receita  %s\nCustos  %s\nResultado  %s"%[CareerText.money(int(finance.revenue)),CareerText.money(int(finance.costs)),CareerText.money(int(finance.margin))])
	if ev.status=="planned":add_button("ANUNCIAR CARD",func():await run_action("announce",{"event_id":ev.id});refresh())
	elif ev.status=="announced":add_button("REALIZAR EVENTO",func():await run_action("advance_event",{"event_id":ev.id});refresh())
func _matchmaker(ev: FightEvent) -> void:
	add_heading("Negociar confronto")
	var w:=Game.world;var used: Array=[]
	for id: String in ev.fight_ids:
		var f: Fight=w.fights[id];used.append_array([f.fighter_a_id,f.fighter_b_id])
	var red_options: Array=[]
	for id: String in w.player_org().roster:
		if id not in used:red_options.append({"id":id,"label":w.fighters[id].display_name()+" / "+CareerText.division(w.fighters[id].division)})
	if red_options.is_empty():return
	if red_id.is_empty() or red_id in used:red_id=red_options[0].id
	var red:=add_select("Corner vermelho",red_options,red_id)
	red.item_selected.connect(func(i):red_id=red.get_item_metadata(i);blue_id="";quote={};refresh())
	var blue_options: Array=[]
	for option: Dictionary in red_options:
		if option.id!=red_id and w.fighters[option.id].division==w.fighters[red_id].division:blue_options.append(option)
	if blue_options.is_empty():add_text("Nenhum adversário livre nesta categoria.",Tokens.MUTED);return
	if blue_id.is_empty() or blue_id in used:blue_id=blue_options[0].id
	var blue:=add_select("Corner azul",blue_options,blue_id)
	blue.item_selected.connect(func(i):blue_id=blue.get_item_metadata(i);quote={};refresh())
	add_face_off(w.fighters[red_id],w.fighters[blue_id],"%s\n×\n%s"%[w.fighters[red_id].display_name(),w.fighters[blue_id].display_name()])
	var offer:=add_select("Oferta de bolsa",[{"id":"1","label":"Contrato atual · 1×"},{"id":"1.5","label":"Aumentar 50% · 1,5×"},{"id":"2","label":"Dobrar · 2×"}],str(premium))
	offer.item_selected.connect(func(i):premium=float(offer.get_item_metadata(i));quote={};refresh())
	var params:={"event_id":ev.id,"red":red_id,"blue":blue_id,"premium":premium}
	add_button("Avaliar confronto",func():
		var result:=await run_action("evaluate",params);quote=result.get("quote",{});refresh())
	if not quote.is_empty():
		add_text("Esportivo %d/100 · Comercial %d/100\nAceitação: %d%% / %d%%\nBolsas até %s"%[quote.sporting_fit,quote.commercial_fit,float(quote.acceptance.get(red_id,0))*100,float(quote.acceptance.get(blue_id,0))*100,CareerText.money(int(quote.projected_cost))])
		if not quote.eligible:add_text(CareerText.result(quote),Tokens.FIGHT_RED)
	add_button("Enviar proposta",func():await run_action("propose",params);quote={};red_id="";blue_id="";refresh())
func _watch(fight: Fight) -> void:
	var viewer:=FightReplayView.new()
	viewer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(viewer)
	viewer.open(FightReplayBuilder.build(Game.world,fight))
