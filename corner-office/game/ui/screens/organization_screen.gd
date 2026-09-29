extends Screen
## Native event statements. Bible §12; no economy calculation in the UI.
func title() -> String:return "Organização"
func build() -> void:
	var w:=Game.world;var org:=w.player_org()
	add_heading(org.name);add_text(org.base_city+" / "+org.base_country,Tokens.MUTED)
	add_text("CAIXA  "+CareerText.money(org.cash))
	add_text("Compromissos anunciados: "+CareerText.money(CareerActions.reserved_cash(w)),Tokens.MUTED)
	var events:=w.events.values();events.reverse()
	for ev: FightEvent in events:
		if ev.organization_id!=org.id or ev.actual.is_empty():continue
		add_heading(ev.name);add_text(GameDate.format(ev.date),Tokens.MUTED)
		for group: String in ["revenue","costs"]:
			add_text("RECEITAS" if group=="revenue" else "CUSTOS",Tokens.FIGHT_RED)
			for key: String in ev.actual.lines[group]:
				var label: String={"gate":"Bilheteria","media":"Transmissão","sponsors":"Patrocínios","purses":"Bolsas","production":"Produção","venue":"Arena","travel":"Viagens","officials":"Arbitragem","marketing":"Marketing"}.get(key,key)
				add_text(label+"  "+CareerText.money(int(ev.actual.lines[group][key])))
		add_text("RESULTADO  "+CareerText.money(int(ev.actual.margin)))
	add_button("Salvar carreira agora",func():feedback="Carreira salva." if Game.save_game("autosave")==OK else "Falha ao salvar.";refresh())
