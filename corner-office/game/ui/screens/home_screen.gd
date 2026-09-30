extends Screen
## Android home: agenda, decisions, factual news; Bible §15.
## Painel de carreira: números da promoção, próxima noite, metas e atletas em alta.
func title() -> String:return "SUA PRÓXIMA GRANDE NOITE"
func build() -> void:
	var w:=Game.world;var org:=w.player_org()
	add_text(GameDate.format(w.date)+"  /  "+org.name,Tokens.MUTED)
	var banner:=BrandBanner.new();banner.show_art=true;banner.headline="CONSTRUA SEU LEGADO";banner.subtitle="Dentro do cage, cada resultado conta.";banner.custom_minimum_size.y=300 if get_viewport_rect().size.y>get_viewport_rect().size.x else 180;body.add_child(banner)
	var summary:=CareerStats.org_summary(w)
	var finish_rate:="—" if summary.fights==0 else "%d%%"%roundi(100.0*summary.finishes/summary.fights)
	add_tiles([
		StatWidgets.tile("Caixa",CareerText.money(org.cash),"%s comprometidos"%CareerText.money(CareerActions.reserved_cash(w)) if CareerActions.reserved_cash(w)>0 else "",true),
		StatWidgets.tile("Elenco","%d"%org.roster.size(),"atletas sob contrato"),
		StatWidgets.tile("Noites","%d"%summary.events,"%d lutas realizadas"%summary.fights),
		StatWidgets.tile("Finalizações",finish_rate,"%d por KO ou finalização"%summary.finishes if summary.fights>0 else "nenhuma luta ainda"),
	])
	var next:=CareerStats.next_event(w)
	if add_section("Próxima noite"):
		if next:
			var days:=GameDate.days_between(w.date,next.date)
			add_text("%s · %s"%[next.name,CareerText.event_status(next.status)],Tokens.INK)
			add_text("%s · faltam %d dias"%[GameDate.format(next.date),days] if days>0 else GameDate.format(next.date)+" · é hoje",Tokens.MUTED)
			add_bar("Card montado",next.fight_ids.size(),10,"%d/10"%next.fight_ids.size(),Tokens.FIGHT_RED if next.fight_ids.size()<6 else Tokens.INK)
			if not next.projected.is_empty():add_bar("Margem prevista",maxf(0,float(next.projected.get("margin",0))),maxf(1.0,float(next.projected.get("revenue",1))),CareerText.money(int(next.projected.get("margin",0))).replace("US$ ",""))
			add_button("Abrir card",func():navigate.emit("events",{"event_id":next.id}))
		else:
			add_text("Sua próxima grande noite começa em Eventos. Monte um card de 6 a 10 lutas.")
			add_button("Criar evento",func():navigate.emit("events",{"create":true}))
	add_button("Avançar 7 dias",func():await run_action("advance_week");refresh())
	add_text("Progresso salvo automaticamente neste aparelho.",Tokens.MUTED)
	if add_section("Metas da temporada"):
		var done:=0
		for goal: Dictionary in CareerStats.milestones(w):
			var complete: bool=goal.value>=goal.goal;if complete:done+=1
			var text:="OK" if complete else ("%s"%CareerText.money(int(goal.value)).replace("US$ ","") if goal.get("money") else "%d/%d"%[goal.value,goal.goal])
			add_bar(("✓ " if complete else "")+goal.label,minf(goal.value,goal.goal),goal.goal,text,Tokens.FIGHT_RED if complete else Tokens.INK)
		add_text("%d de 4 metas cumpridas."%done,Tokens.MUTED)
	if add_section("Em alta no seu elenco"):
		for entry: Dictionary in CareerStats.hot_fighters(w):
			var f: Fighter=entry.fighter
			var run:=CareerStats.streak_label(entry.streak)
			add_button("%s  ·  %s\n%s"%[f.display_name(),f.record_string(),run if not run.is_empty() else CareerText.division(f.division)],func():navigate.emit("fighters",{"fighter_id":f.id}))
	if add_section("Agenda do mercado",false):
		var rivals: Array=[]
		for ev: FightEvent in w.events.values():
			if ev.organization_id!=w.player_org_id and ev.status=="announced":rivals.append(ev)
		rivals.sort_custom(func(a: FightEvent,b: FightEvent):return GameDate.to_unix(a.date)<GameDate.to_unix(b.date))
		for ev: FightEvent in rivals.slice(0,3):
			var main: Fight=w.fights[ev.fight_ids[-1]]
			add_text("%s · %s"%[ev.name,GameDate.format(ev.date)])
			add_text("%s × %s · %s"%[w.fighters[main.fighter_a_id].display_name(),w.fighters[main.fighter_b_id].display_name(),ev.city],Tokens.MUTED)
		if rivals.is_empty():add_text("Nenhuma noite rival anunciada.",Tokens.MUTED)
	if add_section("Noticiário"):
		var items:=w.news.values();items.reverse()
		for item: NewsItem in items.slice(0,6):
			add_text(item.headline);add_text(item.body,Tokens.MUTED)
		if items.is_empty():add_text("As manchetes chegam com as próximas noites, suas e das rivais.",Tokens.MUTED)
