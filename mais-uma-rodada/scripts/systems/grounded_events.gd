class_name GroundedEvents
extends RefCounted
## Informes baseados no estado real do save: não sorteiam dinheiro, talento ou escândalos.
const KEY := "grounded_briefings_v1"
static func after_turn(w: GameWorld) -> void:
	if not w.has_user(): return
	var c:=w.user_club()
	var turn:=w.current_turn()
	var d: Dictionary=w.stats.get(KEY,{"year":w.year,"last":-99,"seen":{}})
	if int(d.get("year",-1))!=w.year:d={"year":w.year,"last":-99,"seen":{}}
	w.stats[KEY]=d
	if turn-int(d["last"])<4: return
	var options:Array=[]
	var fatigued:=0
	var returning:Player=null
	var prospect:Player=null
	for p:Player in w.squad(c):
		if p.condition<68 and p.injury_weeks==0: fatigued+=1
		if p.injury_weeks==1: returning=p
		if p.age(w.year)<=21 and p.minutes_season>=450: prospect=p
	if fatigued>=4: options.append(["load","Comissão alerta para desgaste", "%d jogadores estão abaixo de 68%% de condição. Rodízio e menor pressão podem evitar queda de intensidade; não há penalidade artificial por ignorar este informe." % fatigued,-1])
	if returning!=null: options.append(["return","Retorno exige gestão de minutos", "%s está a uma semana do retorno previsto. A liberação médica não significa condição ideal para 90 minutos." % returning.display_name(),returning.id])
	if BoardBudget.pending(w,c)>0: options.append(["commitments","Diretoria detalha parcelas a pagar", "O clube tem %s em parcelas futuras. A verba autorizada não representa todo o caixa, e as obrigações continuam mesmo se houver troca de treinador." % Fmt.money(BoardBudget.pending(w,c)),-1])
	if prospect!=null: options.append(["youth_minutes","Jovem ganha sequência no profissional", "%s acumulou %d minutos na temporada. A comissão acompanha treino, condição e evolução; sequência não garante atingir o potencial." % [prospect.display_name(),prospect.minutes_season],prospect.id])
	for entry:Array in options:
		if turn-int(d["seen"].get(entry[0],-99))<16: continue
		d["seen"][entry[0]]=turn;d["last"]=turn
		NewsManager.post_raw(w,entry[1],entry[2],c.id,int(entry[3]),NewsEvent.IMP_NORMAL,"clube")
		return
