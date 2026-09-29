class_name BoardBudget
extends RefCounted
## A verba do treinador é uma autorização anual, não o saldo bancário do clube.
## Toda compra compromete seu custo fixo total. Parcelar muda o caixa, não libera verba nova.
const KEY := "board_budget_v1"

static func _all(w: GameWorld) -> Dictionary:
	if not w.stats.has(KEY): w.stats[KEY] = {}
	return w.stats[KEY]

static func state(w: GameWorld, c: Club) -> Dictionary:
	var all := _all(w)
	var key := str(c.id)
	if not all.has(key):
		# Migração: respeita a verba que já restava; não reembolsa o que foi gasto no save.
		all[key] = {"year":w.year,"approved":maxi(0,c.transfer_budget),"spent":0,"sales":0,"extra":0,"withheld":0,"reviewed":false,"decisions":[],"grants":{}}
	return all[key]

static func remaining(d: Dictionary) -> int:
	return maxi(0,int(d["approved"])+int(d["sales"])+int(d["extra"])-int(d["spent"])-int(d["withheld"]))

static func sync(w: GameWorld, c: Club) -> void:
	c.transfer_budget = remaining(state(w,c))

static func pending(w: GameWorld, c: Club, due_year: int = -1) -> int:
	var total := 0
	for e: Dictionary in w.stats.get("installments",[]):
		var buyer := int(e.get("buyer",w.user_club_id))
		if buyer == c.id and (due_year < 0 or int(e.get("y",w.year)) <= due_year): total += maxi(0,int(e.get("v",0)))
	return total

static func reserve(w: GameWorld, c: Club) -> int:
	var promised := 0
	for item: Variant in w.stats.get("pre",{}).values():
		if item is Dictionary and int(item.get("club",-1))==c.id:
			promised+=maxi(0,int(item.get("deal",{}).get("bonus",0)))
	return int(FinanceManager.wage_bill(w,c)*2.0 + maxf(0.0,c.cost_upkeep)/6.0 + pending(w,c,w.year)) + promised

static func available_cash(w: GameWorld, c: Club) -> int:
	return maxi(0,c.balance-reserve(w,c))

static func open_year(w: GameWorld, c: Club, proposed: int) -> void:
	var all := _all(w)
	var key := str(c.id)
	if all.has(key) and int(all[key].get("year",-1)) == w.year:
		# Mudança de clube/diretoria/reabertura de painel não refaz a autorização anual.
		sync(w,c)
		return
	var prior: Array = []
	if all.has(key):
		var d: Dictionary = all[key]
		prior = Array(d.get("history",[])).duplicate()
		prior.append({"year":d["year"],"approved":d["approved"],"spent":d["spent"],"unused":remaining(d)})
		if prior.size()>5: prior=prior.slice(prior.size()-5)
	all[key] = {"year":w.year,"approved":maxi(0,proposed),"spent":0,"sales":0,"extra":0,"withheld":0,"reviewed":false,"decisions":[],"grants":{},"history":prior}
	_note(all[key],"Diretoria define a verba da temporada",proposed)
	sync(w,c)

static func spend(w: GameWorld, c: Club, amount: int, reason: String = "Contratação") -> void:
	var d := state(w,c)
	d["spent"] = int(d["spent"])+maxi(0,amount)
	_note(d,reason,-maxi(0,amount))
	sync(w,c)

static func sale_share(c: Club) -> float:
	# Política ligada à situação financeira e ao projeto, igual para usuário e adversários.
	var dr := FinanceManager.debt_ratio(c)
	var share := clampf(0.58+float(c.arch().get("spend_rate",0.35))*0.35-dr*0.15,0.20,0.85)
	return share*0.5 if c.balance<0 else share

static func on_sale(w: GameWorld, c: Club, receipt: int) -> void:
	var d := state(w,c)
	var credit := int(maxi(0,receipt)*sale_share(c))
	d["sales"] = int(d["sales"])+credit
	_note(d,"Parcela da venda liberada pela diretoria",credit)
	sync(w,c)

static func withhold(w: GameWorld, c: Club, amount: int, reason: String) -> void:
	var d := state(w,c)
	var cut := mini(remaining(d),maxi(0,amount))
	d["withheld"] = int(d["withheld"])+cut
	_note(d,reason,-cut)
	sync(w,c)

static func grant(w: GameWorld, c: Club, requested: int, reason: String, key: String = "") -> int:
	var d := state(w,c)
	if key != "" and d["grants"].has(key): return 0
	if key != "": d["grants"][key] = true
	var headroom := maxi(0,available_cash(w,c)-remaining(d))
	var value := mini(maxi(0,requested),headroom)
	d["extra"] = int(d["extra"])+value
	_note(d,reason,value)
	sync(w,c)
	return value

static func review(w: GameWorld, c: Club) -> void:
	var d := state(w,c)
	if bool(d["reviewed"]):
		sync(w,c)
		return
	d["reviewed"] = true
	var forecast := FinanceManager.projected_balance(w,c)-reserve(w,c)-pending(w,c,w.year+1)
	if forecast<0:
		withhold(w,c,mini(remaining(d),-forecast),"Revisão: provisão para compromissos e caixa")
	else:
		grant(w,c,int(minf(forecast*0.15,FinanceManager.expected_revenue(c)*0.08)),"Revisão: excedente autorizado","review")

static func can_commit(w: GameWorld, c: Club, total: int, immediate: int) -> String:
	sync(w,c)
	if total<0 or immediate<0 or immediate>total: return "Condições financeiras inválidas."
	if total>c.transfer_budget:
		return "O custo fixo total (%s) supera a verba autorizada (%s). Parcelar não aumenta o orçamento." % [Fmt.money(total),Fmt.money(c.transfer_budget)]
	if immediate>available_cash(w,c):
		return "A entrada, comissões e luvas comprometem o caixa reservado para salários e despesas. Disponível agora: %s." % Fmt.money(available_cash(w,c))
	return ""

static func _note(d: Dictionary, reason: String, amount: int) -> void:
	var log: Array = d["decisions"]
	log.append({"reason":reason,"amount":amount})
	if log.size()>24: log.pop_front()
