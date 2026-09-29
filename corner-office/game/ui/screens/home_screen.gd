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
	add_heading("Noticiário")
	var items:=w.news.values();items.reverse()
	for item: NewsItem in items.slice(0,6):
		add_text(item.headline);add_text(item.body,Tokens.MUTED)
	if items.is_empty():add_text("As primeiras manchetes virão dos seus eventos.",Tokens.MUTED)
