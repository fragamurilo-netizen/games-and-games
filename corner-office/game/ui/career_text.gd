class_name CareerText
extends RefCounted
## Presentation labels only; services own all calculations (Bible §15).
const REASONS := {"INVALID_MATCHUP":"Escolha dois atletas diferentes.","EVENT_CLOSED":"O evento precisa estar em planejamento e no futuro.","SEX_MISMATCH":"As divisões masculina e feminina são separadas.","DIVISION_MISMATCH":"Escolha atletas da mesma categoria.","INJURED":"Atleta lesionado.","MEDICAL_SUSPENSION":"Atleta em repouso médico na data do evento.","NO_VALID_CONTRACT":"Contrato inválido para esta data.","ALREADY_BOOKED":"Atleta reservado em data próxima.","CARD_TOO_SMALL":"Monte pelo menos seis lutas.","CARD_FULL":"O limite é dez lutas.","INSUFFICIENT_CASH":"Caixa insuficiente após os compromissos já anunciados.","COUNTER_PURSE":"Um atleta pede melhores condições. Aumente a bolsa ou escolha outro confronto.","BOTH_ACCEPTED":"Confronto aceito pelos dois atletas.","OFFER_UNCHANGED":"Melhore os termos para negociar novamente.","EXCLUSIVE_CONTRACT":"Atleta com contrato exclusivo.","INVALID_CONTRACT":"Confira os valores do contrato."}
const ATTRIBUTES := {"boxing":"Boxe","jab":"Jab","combinations":"Combinações","defense":"Defesa","accuracy":"Precisão","power":"Potência","kicks":"Chutes","low_kicks":"Chutes baixos","knees":"Joelhadas","elbows":"Cotoveladas","countering":"Contra-ataque","takedown_offense":"Queda","takedown_defense":"Defesa de queda","clinch":"Clinch","cage_control":"Controle na grade","top_control":"Controle por cima","scramble":"Scramble","ground_and_pound":"Ground and pound","guard":"Guarda","transitions":"Transições","submission_offense":"Finalização","submission_defense":"Defesa de finalização","back_control":"Pegada nas costas","leg_locks":"Chaves de perna","strength":"Força","explosiveness":"Explosão","speed":"Velocidade","cardio":"Cardio","durability":"Resistência","chin":"Queixo","recovery":"Recuperação","mobility":"Mobilidade","fight_iq":"QI de luta","discipline":"Disciplina","adaptation":"Adaptação","composure":"Frieza","aggression":"Agressividade","patience":"Paciência","clutch":"Decisão sob pressão"}
static func attribute(key: String) -> String:
	return ATTRIBUTES.get(key,key.replace("_"," ").capitalize())
static func money(value: int) -> String:
	var source:=str(absi(value));var result:=""
	for i in source.length():
		if i>0 and (source.length()-i)%3==0:result+="."
		result+=source[i]
	return ("−" if value<0 else "")+"US$ "+result
static func division(id: String) -> String:
	for d: Dictionary in ContentDB.load_json("weight_classes.json"):
		if d.id==id:return "%s · %s"%[d.name,"feminino" if d.sex=="F" else "masculino"]
	return id
static func result(data: Dictionary) -> String:
	if data.has("counter_show"):return "Contraproposta: %s por apresentação."%money(int(data.counter_show))
	if data.has("message"):return str(data.message)
	var lines: Array=[]
	for reason: Dictionary in data.get("proposal",data).get("reasons",[]):lines.append(REASONS.get(reason.code,str(reason.code).replace("_"," ")))
	return " ".join(lines)
static func event_status(value: String) -> String:
	return {"planned":"EM MONTAGEM","announced":"ANUNCIADO","completed":"CONCLUÍDO","postponed":"ADIADO"}.get(value,value)
