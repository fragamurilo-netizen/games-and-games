class_name CareerText
extends RefCounted
## Presentation labels only; services own all calculations (Bible §15).
const REASONS := {"INVALID_MATCHUP":"Escolha dois atletas diferentes.","EVENT_CLOSED":"O evento precisa estar em planejamento e no futuro.","SEX_MISMATCH":"As divisões masculina e feminina são separadas.","DIVISION_MISMATCH":"Escolha atletas da mesma categoria.","INJURED":"Atleta lesionado.","MEDICAL_SUSPENSION":"Atleta em repouso médico na data do evento.","NO_VALID_CONTRACT":"Contrato inválido para esta data.","ALREADY_BOOKED":"Atleta reservado em data próxima.","CARD_TOO_SMALL":"Monte pelo menos seis lutas.","CARD_FULL":"O limite é dez lutas.","INSUFFICIENT_CASH":"Caixa insuficiente após os compromissos já anunciados.","COUNTER_PURSE":"Um atleta pede melhores condições. Aumente a bolsa ou escolha outro confronto.","BOTH_ACCEPTED":"Confronto aceito pelos dois atletas.","OFFER_UNCHANGED":"Melhore os termos para negociar novamente.","EXCLUSIVE_CONTRACT":"Atleta com contrato exclusivo.","INVALID_CONTRACT":"Confira os valores do contrato.","INVALID_FIGHTER":"Lutador não encontrado.","INVALID_NAME":"Nome e sobrenome são obrigatórios.","UNKNOWN_COUNTRY":"País fora da lista.","INVALID_DIVISION":"Categoria inválida.","FIGHTER_BOOKED":"Atleta com luta marcada: troque a categoria depois do evento.","INVALID_STYLE":"Base, estilo ou guarda inválidos.","INVALID_BODY":"Biotipo ou traços inválidos.","FIGHTER_HAS_HISTORY":"Atleta já lutou neste save: cartel e sorteio ficam travados."}
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
static func tier(value: String) -> String:
	return {"regional":"regional","national":"nacional","global":"global"}.get(value,value)
static func objective(goal: Dictionary) -> String:
	var mark:="✓ " if goal.done else "○ "
	if goal.id=="profit":return mark+"Fechar o ano com lucro de pelo menos %s · agora %s"%[money(int(goal.target)),money(int(goal.progress))]
	return mark+"%s · agora %d"%[goal.label,int(goal.progress)]
static func injury(kind: String) -> String:
	return {"cut":"corte","hand":"mão","rib":"costela","shoulder":"ombro","knee":"joelho","concussion":"concussão"}.get(kind,kind)
