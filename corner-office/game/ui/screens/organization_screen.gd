extends Screen
## Native event statements. Bible §12; no economy calculation in the UI.
## Painel da empresa: totais, noite a noite em barras e detalhe por evento.
const LINE_LABELS:={"gate":"Bilheteria","media":"Transmissão","sponsors":"Patrocínios","purses":"Bolsas","production":"Produção","venue":"Arena","travel":"Viagens","officials":"Arbitragem","marketing":"Marketing"}
func title() -> String:return "Organização"
func build() -> void:
	var w:=Game.world;var org:=w.player_org()
	add_heading(org.name);add_text(org.base_city+" / "+org.base_country,Tokens.MUTED)
	var s:=CareerStats.org_summary(w)
	add_tiles([
		StatWidgets.tile("Caixa",CareerText.money(org.cash),"%s comprometidos"%CareerText.money(CareerActions.reserved_cash(w)),true),
		StatWidgets.tile("Reputação","%d"%org.reputation,"de 100"),
		StatWidgets.tile("Lucro com eventos",CareerText.money(s.margin),("%d noite" if s.events==1 else "%d noites")%s.events),
		StatWidgets.tile("Melhor noite",s.best_event if not s.best_event.is_empty() else "—",CareerText.money(s.best_margin) if not s.best_event.is_empty() else "realize sua primeira noite"),
	])
	var events: Array=[]
	for ev: FightEvent in w.events.values():
		if ev.organization_id==org.id and not ev.actual.is_empty():events.append(ev)
	events.sort_custom(func(a: FightEvent,b: FightEvent):return GameDate.to_unix(a.date)>GameDate.to_unix(b.date))
	if not events.is_empty() and add_section("Noite a noite"):
		var top:=1.0
		for ev: FightEvent in events:top=maxf(top,float(ev.actual.revenue))
		for ev: FightEvent in events.slice(0,8):
			add_text("%s · %s"%[ev.name,GameDate.format(ev.date)])
			add_bar("Receita",float(ev.actual.revenue),top,_short(int(ev.actual.revenue)),Tokens.INK)
			add_bar("Custos",float(ev.actual.costs),top,_short(int(ev.actual.costs)),Tokens.STEEL)
			add_bar("Resultado",absf(float(ev.actual.margin)),top,_short(int(ev.actual.margin)),Tokens.FIGHT_RED if int(ev.actual.margin)<0 else Tokens.INK)
	for ev: FightEvent in events:
		if not add_section("Balanço · "+ev.name,false):continue
		for group: String in ["revenue","costs"]:
			add_text("RECEITAS" if group=="revenue" else "CUSTOS",Tokens.FIGHT_RED)
			for key: String in ev.actual.lines[group]:
				add_text(LINE_LABELS.get(key,key)+"  "+CareerText.money(int(ev.actual.lines[group][key])))
		add_text("RESULTADO  "+CareerText.money(int(ev.actual.margin)))
	if events.is_empty():add_text("Os balanços aparecem aqui depois da primeira noite.",Tokens.MUTED)
	add_button("Salvar carreira agora",func():feedback="Carreira salva." if Game.save_game("autosave")==OK else "Falha ao salvar.";refresh())
## US$ 1,2 mi / US$ 350 mil, to fit beside a bar.
func _short(value: int) -> String:
	var sign:="−" if value<0 else "";var v:=absi(value)
	if v>=1000000:return "%s%.1f mi"%[sign,v/1000000.0]
	if v>=1000:return "%s%d mil"%[sign,v/1000]
	return sign+str(v)
