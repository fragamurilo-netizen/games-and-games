extends Screen
## Android home: agenda, decisions, factual news; Bible §15.
## Central da promoção: cada cartão é uma porta ao vivo para outra área, como o
## hub de carreira de Undisputed 3. Abaixo, números, metas e atletas em alta.
func title() -> String:return "CENTRAL DA PROMOÇÃO"
func build() -> void:
	var w:=Game.world;var org:=w.player_org()
	var landscape:=get_viewport_rect().size.x>get_viewport_rect().size.y
	add_text(GameDate.format(w.date)+"  /  "+org.name+"  /  "+CareerText.money(org.cash),Tokens.MUTED)
	var next:=CareerStats.next_event(w)
	var advance:=add_button("Avançar 7 dias",func():await run_action("advance_week");refresh(),"Passa uma semana: treinos, notícias, rivais e o calendário andam.")
	advance.add_theme_stylebox_override("normal",Tokens.slanted_box(Tokens.FIGHT_RED))
	advance.add_theme_color_override("font_color",Color.WHITE)
	add_button("Avançar até o próximo mês",func():await run_action("advance_month");refresh(),"Avança até o dia 1º do próximo mês, parando antes da sua próxima noite.")
	add_hub(_cards(w,next),3 if landscape else 2)
	var summary:=CareerStats.org_summary(w)
	var finish_rate:="—" if summary.fights==0 else "%d%%"%roundi(100.0*summary.finishes/summary.fights)
	if add_section("Números da promoção"):
		add_tiles([
			StatWidgets.tile("Caixa",CareerText.money(org.cash),"%s comprometidos"%CareerText.money(CareerActions.reserved_cash(w)) if CareerActions.reserved_cash(w)>0 else "",true),
			StatWidgets.tile("Elenco","%d"%org.roster.size(),"atletas sob contrato"),
			StatWidgets.tile("Noites","%d"%summary.events,"%d lutas realizadas"%summary.fights),
			StatWidgets.tile("Finalizações",finish_rate,"%d por KO ou finalização"%summary.finishes if summary.fights>0 else "nenhuma luta ainda"),
		])
	if add_section("Metas da temporada"):
		var done:=0
		for goal: Dictionary in CareerStats.milestones(w):
			var complete: bool=goal.value>=goal.goal;if complete:done+=1
			var text:="OK" if complete else ("%s"%CareerText.money(int(goal.value)).replace("US$ ","") if goal.get("money") else "%d/%d"%[goal.value,goal.goal])
			add_bar(("✓ " if complete else "")+goal.label,minf(goal.value,goal.goal),goal.goal,text,Tokens.FIGHT_RED if complete else Tokens.INK)
		var goals:=CareerStats.milestones(w)
		add_text("%d de %d metas cumpridas."%[done,goals.size()]+(" Cumprir todas rende bônus no balanço de 1º de janeiro." if not goals.is_empty() and goals[0].get("official",false) else ""),Tokens.MUTED)
	if add_section("Em alta no seu elenco"):
		for entry: Dictionary in CareerStats.hot_fighters(w):
			var f: Fighter=entry.fighter
			var run:=CareerStats.streak_label(entry.streak)
			add_button("%s  ·  %s\n%s"%[f.display_name(),f.record_string(),run if not run.is_empty() else CareerText.division(f.division)],func():navigate.emit("fighters",{"fighter_id":f.id}))
	if add_section("Agenda do mercado",false):
		for ev: FightEvent in _rival_nights(w).slice(0,3):
			var main: Fight=w.fights[ev.fight_ids[-1]]
			var a: Fighter=w.fighters[main.fighter_a_id];var b: Fighter=w.fighters[main.fighter_b_id]
			add_text("%s · %s · %s"%[ev.name,GameDate.format(ev.date),ev.city])
			add_face_off(a,b,"%s\n×\n%s"%[a.display_name(),b.display_name()])
		if _rival_nights(w).is_empty():add_text("Nenhuma noite rival anunciada.",Tokens.MUTED)
	if add_section("Noticiário"):
		var items:=w.news.values();items.reverse()
		var featured:=items.filter(func(n: NewsItem):return n.channel=="site" and (n.importance>=3 or Media.involves_player(w,n)))
		for item: NewsItem in featured.slice(0,4):
			add_text("%s · %s"%[Media.outlet(item.outlet_id).name.to_upper(),GameDate.format(item.created_at)],Tokens.MUTED)
			add_text(item.headline)
		if items.is_empty():add_text("As manchetes chegam com as próximas noites, suas e das rivais.",Tokens.MUTED)
		var unread:=Media.unread_count(w)
		add_button("Notícias, sites e redes"+(" · %d novas"%unread if unread>0 else ""),_open_news)


func _cards(w: WorldState, next: FightEvent) -> Array:
	var org:=w.player_org()
	var cards: Array=[]
	if next:
		var days:=GameDate.days_between(w.date,next.date)
		cards.append([StatWidgets.hub_card("Próxima noite",next.name,"%s · %d/10 lutas · %s"%["hoje" if days<=0 else "em %d dias"%days,next.fight_ids.size(),CareerText.event_status(next.status)]),"events",{"event_id":next.id}])
	else:
		cards.append([StatWidgets.hub_card("Próxima noite","Criar evento","Monte um card de 6 a 10 lutas"),"events",{"create":true}])
	var hot: Array=CareerStats.hot_fighters(w,1)
	var hot_line:="%d atletas sob contrato"%org.roster.size()
	if not hot.is_empty() and hot[0].streak>=2:hot_line="Em alta: %s (%s)"%[hot[0].fighter.last_name,CareerStats.streak_label(hot[0].streak)]
	cards.append([StatWidgets.hub_card("Elenco","%d atletas"%org.roster.size(),hot_line),"fighters",{"mode":"roster"}])
	cards.append([StatWidgets.hub_card("Rankings","Oficial e mundial","O topo de cada categoria"),"fighters",{"mode":"official"}])
	var free:=0
	for f: Fighter in w.fighters.values():
		if f.organization_id.is_empty():free+=1
	cards.append([StatWidgets.hub_card("Mercado","%d livres"%free,"Agentes livres no mercado"),"market",{}])
	var s:=CareerStats.org_summary(w)
	cards.append([StatWidgets.hub_card("Finanças",CareerText.money(s.margin) if s.events>0 else CareerText.money(org.cash),(("lucro em %d noite" if s.events==1 else "lucro em %d noites")%s.events) if s.events>0 else "caixa disponível"),"organization",{}])
	var goals:=CareerStats.milestones(w)
	var done:=goals.filter(func(g):return g.value>=g.goal).size()
	cards.append([StatWidgets.hub_card("Metas","%d/%d"%[done,goals.size()],"metas da temporada cumpridas"),"home",{"open":"Metas da temporada"}])
	var items:=w.news.values()
	cards.append([StatWidgets.hub_card("Notícias",str(items[-1].headline) if not items.is_empty() else "Sem manchetes","%d notícias no ar"%items.size()),"home",{"open":"Noticiário"}])
	var rivals:=_rival_nights(w)
	cards.append([StatWidgets.hub_card("Rivais","%d noites"%rivals.size(),("Próxima: "+rivals[0].name) if not rivals.is_empty() else "Nenhuma anunciada"),"home",{"open":"Agenda do mercado"}])
	var unread:=Media.unread_count(w)
	cards.append([StatWidgets.hub_card("Redes sociais","%d novas"%unread if unread>0 else "Em dia","Sites, feed e repercussão"),_open_news,{}])
	cards.append([StatWidgets.hub_card("Mundo","Universo","História, cinturões e cidades"),func():UniverseView.open_over(get_tree()),{}])
	return cards


func add_hub(cards: Array, columns: int) -> void:
	var grid:=GridContainer.new();grid.columns=columns
	grid.add_theme_constant_override("h_separation",Tokens.SPACE_S);grid.add_theme_constant_override("v_separation",Tokens.SPACE_S)
	for entry: Array in cards:
		var card: StatWidgets.HubCard=entry[0]
		if entry[1] is Callable:card.pressed.connect(entry[1])
		elif entry[1]!="":card.pressed.connect(func():navigate.emit(entry[1],entry[2]))
		describe(card,"%s: %s"%[card.heading,card.detail])
		grid.add_child(card)
	body.add_child(grid)


func _open_news() -> void:
	var center:=NewsCenter.new();center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	center.closed.connect(refresh);get_tree().root.add_child(center)


func hint() -> String:
	return "Central da promoção: toque num cartão para ir direto à área."


func receive(payload: Dictionary) -> void:
	if payload.has("open"):collapsed[str(payload.open)]=false;focus_section=str(payload.open)


func _rival_nights(w: WorldState) -> Array:
	var rivals: Array=[]
	for ev: FightEvent in w.events.values():
		if ev.organization_id!=w.player_org_id and ev.status=="announced":rivals.append(ev)
	rivals.sort_custom(func(a: FightEvent,b: FightEvent):return GameDate.to_unix(a.date)<GameDate.to_unix(b.date))
	return rivals
