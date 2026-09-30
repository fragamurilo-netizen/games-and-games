extends Screen
## Android home: agenda, decisions, factual news; Bible §15.
func title() -> String:return "SUA PRÓXIMA GRANDE NOITE"
func build() -> void:
	var w:=Game.world;var org:=w.player_org()
	add_text(GameDate.format(w.date)+"  /  "+org.name,Tokens.MUTED)
	var banner:=BrandBanner.new();banner.show_art=true;banner.headline="CONSTRUA SEU LEGADO";banner.subtitle="Dentro do cage, cada resultado conta.";banner.custom_minimum_size.y=360;body.add_child(banner)
	add_heading(CareerText.money(org.cash))
	add_text("%d atletas · %s comprometidos com eventos"%[org.roster.size(),CareerText.money(CareerActions.reserved_cash(w))],Tokens.MUTED)
	var next: FightEvent=null
	for ev: FightEvent in w.events.values():
		if ev.organization_id==w.player_org_id and ev.status in ["planned","announced"]:
			if next==null or GameDate.to_unix(ev.date)<GameDate.to_unix(next.date):next=ev
	if next:
		add_heading(next.name)
		add_text("%s · %d lutas · %s"%[GameDate.format(next.date),next.fight_ids.size(),CareerText.event_status(next.status)])
	else:add_text("Sua próxima grande noite começa em Eventos. Monte um card de 6 a 10 lutas.")
	add_button("Avançar 7 dias",func():await run_action("advance_week");refresh())
	add_text("Progresso salvo automaticamente neste aparelho.",Tokens.MUTED)
	add_heading("Agenda do mercado")
	var rivals: Array=[]
	for ev: FightEvent in w.events.values():
		if ev.organization_id!=w.player_org_id and ev.status=="announced":rivals.append(ev)
	rivals.sort_custom(func(a: FightEvent,b: FightEvent):return GameDate.to_unix(a.date)<GameDate.to_unix(b.date))
	for ev: FightEvent in rivals.slice(0,3):
		var main: Fight=w.fights[ev.fight_ids[-1]]
		add_text("%s · %s"%[ev.name,GameDate.format(ev.date)])
		add_text("%s × %s · %s"%[w.fighters[main.fighter_a_id].display_name(),w.fighters[main.fighter_b_id].display_name(),ev.city],Tokens.MUTED)
	if rivals.is_empty():add_text("Nenhuma noite rival anunciada.",Tokens.MUTED)
	add_heading("Noticiário")
	var items:=w.news.values();items.reverse()
	var featured:=items.filter(func(n: NewsItem):return n.channel=="site" and (n.importance>=3 or Media.involves_player(w,n)))
	for item: NewsItem in featured.slice(0,4):
		add_text("%s · %s"%[Media.outlet(item.outlet_id).name.to_upper(),GameDate.format(item.created_at)],Tokens.MUTED)
		add_text(item.headline)
	if items.is_empty():add_text("As manchetes chegam com as próximas noites, suas e das rivais.",Tokens.MUTED)
	var unread:=Media.unread_count(w)
	add_button("Notícias, sites e redes"+(" · %d novas"%unread if unread>0 else ""),func():
		var center:=NewsCenter.new();center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		center.closed.connect(refresh);get_tree().root.add_child(center))
