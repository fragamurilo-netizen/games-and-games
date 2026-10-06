class_name FinanceAI
extends RefCounted
## Conduta financeira dos clubes da IA na virada do ano (depois dos orçamentos), como fazem os
## clubes de verdade:
## - caixa sobrando e dívida: amortiza antes (a dívida brasileira custa caro: juros de 15% ao ano);
## - caixa sobrando sem dívida: o dinheiro vira reforço (verba de contratações), não fica parado;
## - aperto (caixa no vermelho ou dívida acima de um ano e meio de receita): plano de austeridade,
##   com o ativo mais valioso à venda e, se a crise é grave, também a joia da base;
## - folga grande e estrutura atrasada: investimento em CT e base (FinanceManager.yearly_investments).

const CASH_KEEP := 0.35 # reserva de caixa que o clube mantém (fração da receita líquida)
const PREPAY := 0.5 # do que passa da reserva, quanto vai para amortizar a dívida
const SPEND_IDLE := 0.4 # sem dívida: do que passa de 0,9 × receita, quanto vira verba de mercado
const AUSTERITY_DR := 1.5 # dívida em anos de receita bruta que liga a austeridade
const SEVERE_DR := 2.5


static func season_open(world: GameWorld) -> Dictionary:
	var out := {"prepaid": 0, "austerity": [], "idle": 0}
	for c: Club in world.clubs:
		if world.is_user_club(c.id) or c.is_pool():
			continue
		var net := maxf(1.0, FinanceManager.net_revenue(c))
		# 1) Amortização antecipada
		if c.debt > 0 and c.balance > net * CASH_KEEP:
			var pay := mini(c.debt, int((c.balance - net * CASH_KEEP) * PREPAY))
			if pay > 0:
				c.debt -= pay
				c.add_ledger("amortizacao", -pay)
				out["prepaid"] = int(out["prepaid"]) + pay
		# 2) Dinheiro parado vira reforço
		elif c.debt <= 0 and c.balance > net * 0.9:
			var extra := int((c.balance - net * 0.9) * SPEND_IDLE)
			c.transfer_budget = mini(c.transfer_budget + extra, maxi(c.balance, 0))
			out["idle"] = int(out["idle"]) + extra
		# 3) Austeridade
		var dr := FinanceManager.debt_ratio(c)
		if c.balance < 0 or dr > AUSTERITY_DR:
			var sold := _austerity(world, c, dr > SEVERE_DR or c.balance < -int(net * 0.3))
			if not sold.is_empty():
				out["austerity"].append({"club": c.id, "players": sold})
				_news(world, c, sold, dr)
	return out


## Põe à venda o jogador mais valioso (e, na crise grave, a maior promessa). Retorna os ids.
static func _austerity(world: GameWorld, c: Club, severe: bool) -> Array:
	var squad := world.squad(c)
	squad.sort_custom(func(a: Player, b: Player): return a.value > b.value)
	var out: Array = []
	for p: Player in squad:
		if out.size() >= (2 if severe else 1):
			break
		if p.transfer_listed or not p.loan.is_empty() or p.joined_year == world.year or p.retiring:
			continue
		p.transfer_listed = true
		out.append(p.id)
	if severe:
		var kid: Player = null
		for p: Player in squad:
			if p.age(world.year) <= 20 and not out.has(p.id) and not p.transfer_listed and (kid == null or p.potential > kid.potential):
				kid = p
		if kid != null and kid.potential >= 78:
			kid.transfer_listed = true
			out.append(kid.id)
	return out


static func _news(world: GameWorld, c: Club, ids: Array, dr: float) -> void:
	if not world.has_user():
		return
	var u := world.user_club()
	if c.league_id != u.league_id and c.nation != u.nation:
		return
	var names: Array = []
	for id in ids:
		var p := world.player(int(id))
		if p != null:
			names.append(p.display_name())
	if names.is_empty():
		return
	var why := "o caixa fechou no vermelho" if c.balance < 0 else "a dívida passa de %s anos de receita" % String.num(dr, 1).replace(".", ",")
	NewsManager.post_raw(world, "%s anuncia plano de austeridade" % c.short_name,
		"Com %s, a diretoria do %s colocou %s à venda e segurou novas contratações." % [why, c.short_name, " e ".join(PackedStringArray(names))],
		c.id, int(ids[0]), NewsEvent.IMP_NORMAL, "mercado")
