extends Screen
## Free agency / basic renewal on mobile. Bible §9; full agent BATNA remains M2.
var selected:=""
func title() -> String:return "Mercado"
func receive(payload: Dictionary) -> void:
	if payload.get("reset",false):selected=""
	if payload.has("fighter_id"):selected=str(payload.fighter_id)
func snapshot() -> Dictionary:
	var s:=super.snapshot();s.fighter_id=selected;return s
func build() -> void:
	var w:=Game.world
	if selected.is_empty():
		add_text("AGENTES LIVRES",Tokens.FIGHT_RED)
		add_text("Proponha quatro lutas e construa o próximo nome da sua promoção.",Tokens.MUTED)
		for f: Fighter in w.fighters.values():
			if f.organization_id.is_empty():add_button("%s  /  %s\n%s · %s"%[f.display_name(),f.record_string(),CareerText.division(f.division),CareerText.money(Contracts.market_price(w,f))],func():selected=f.id;refresh())
		return
	var f: Fighter=w.fighters[selected]
	add_button("← Agentes livres",func():selected="";refresh())
	add_heading(f.display_name());add_text(CareerText.division(f.division)+" / "+f.record_string())
	add_button("Ver ficha completa",func():navigate.emit("fighters",{"fighter_id":f.id}))
	var show:=add_number("Bolsa por apresentação · US$",Contracts.market_price(w,f),1,10000000)
	var signing:=add_number("Luvas na assinatura · US$",0,0,10000000)
	add_text("4 lutas · 18 meses · bônus de vitória de 50%",Tokens.MUTED)
	add_button("ENVIAR CONTRATO",func():
		var result:=await run_action("negotiate",{"fighter_id":f.id,"show_money":int(show.value),"signing_bonus":int(signing.value)})
		if result.get("ok") and not result.has("counter_show"):selected=""
		refresh())
