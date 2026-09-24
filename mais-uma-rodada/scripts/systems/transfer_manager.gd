class_name TransferManager
extends RefCounted
## Mercado: preço pedido, interesse do jogador, negociação do usuário, IA↔IA,
## propostas da IA pelos jogadores do usuário, agentes livres, renovações e rescisões.

const STATUS_ASK: Array[float] = [1.55, 1.25, 1.05, 0.9, 1.3] # estrela, titular, rotação, reserva, promessa
const MAX_BIDS_PER_DAY := 3
const OFFER_DAYS := 2 # prazo das propostas, em jogos do usuário
const BAND := 4.0 # largura das faixas de nível do índice do mercado

# Famílias de posição para carências de elenco: [posições, mínimo]
const FAMILIES: Array = [
	[[Pos.GK], 2],
	[[Pos.CB], 3],
	[[Pos.RB, Pos.LB], 2],
	[[Pos.DM, Pos.CM], 4],
	[[Pos.AM, Pos.RM, Pos.LM, Pos.RW, Pos.LW], 3],
	[[Pos.ST], 2],
]


# ---------------------------------------------------------------------------
# Preço e interesse
# ---------------------------------------------------------------------------

## Quanto o clube dono pede pelo jogador.
static func asking_price(world: GameWorld, p: Player) -> int:
	if p.club_id < 0:
		return 0
	var club := world.club(p.club_id)
	if world.is_user_club(club.id) and p.transfer_listed and p.asking_price > 0:
		return p.asking_price
	var mult := float(club.arch().get("sell_mult", 1.0)) * STATUS_ASK[clampi(p.squad_status, 0, 4)]
	if p.transfer_listed:
		mult *= 0.85
	var years := p.contract_years_left(world.year)
	if years <= 0:
		mult *= 0.7
	elif years == 1:
		mult *= 0.9
	if club.balance < 0:
		mult *= 0.85
	if not world.is_user_club(club.id) and world.has_user():
		mult *= [0.92, 1.0, 1.1][world.difficulty]
	return Valuation.round_value(p.value * mult)


## Probabilidade (0..1) de o jogador topar se mudar para `buyer` com salário justo.
static func interest(world: GameWorld, p: Player, buyer: Club) -> float:
	var cur := world.club(p.club_id) if p.club_id >= 0 else null
	var rep_diff := buyer.reputation - (cur.reputation if cur != null else buyer.reputation - 8.0)
	var amb := 1.0 + p.trait_sum("ambition") / 40.0
	var v := 0.55 + rep_diff * 0.012 * maxf(0.4, amb)
	if cur != null:
		# Liga mais forte atrai; salário menor afasta (ninguém sai da Inglaterra para ganhar metade).
		var lv := PlayerGenerator.league_level(buyer) - PlayerGenerator.league_level(cur)
		v += clampf(lv * 0.025, -0.3, 0.3)
		var ratio := float(Valuation.wage_demand(p, buyer, world.year)) / maxf(1.0, float(p.wage))
		v += clampf((ratio - 1.0) * 0.25, -0.3, 0.2)
		v -= p.trait_sum("loyalty") / 100.0
		if cur.is_rival(buyer.id) or buyer.is_rival(cur.id):
			v -= 0.15 # ninguém gosta de trocar pelo rival
	if buyer.nation == p.nationality:
		v += 0.05 # voltar para casa
	if p.age(world.year) >= 31:
		v += 0.1
	# Minutos: teria espaço no novo time?
	var better := 0
	for q in world.squad(buyer):
		if q.position == p.position and q.ovr_f > p.ovr_f + 2.0:
			better += 1
	v += 0.1 if better == 0 else (-0.08 * better)
	if p.morale < 40.0 and cur != null:
		v += 0.15 # insatisfeito quer sair
	return clampf(v, 0.05, 0.95)


## Salário pedido para assinar com `buyer` (quanto menos interessado, mais caro).
static func wage_ask(world: GameWorld, p: Player, buyer: Club) -> int:
	var base := float(Valuation.wage_demand(p, buyer, world.year))
	var i := interest(world, p, buyer)
	base *= 1.0 + (0.5 - i) * 0.6
	if p.club_id >= 0:
		base = maxf(base, p.wage * 1.05)
	return Valuation.round_wage(base)


static func preferred_years(world: GameWorld, p: Player) -> int:
	var age := p.age(world.year)
	if age <= 23:
		return 4
	if age <= 28:
		return 3
	if age <= 31:
		return 2
	return 1


# ---------------------------------------------------------------------------
# Negociação do usuário
# ---------------------------------------------------------------------------

## Proposta do usuário ao clube dono. Retorna {result: "accepted"|"counter"|"rejected", fee, msg}.
static func user_bid(world: GameWorld, p: Player, fee: int, deal: Dictionary = {}) -> Dictionary:
	var user := world.user_club()
	if p.club_id < 0:
		return {"result": "accepted", "fee": 0, "msg": "Jogador livre: negocie direto com ele."}
	if p.club_id == user.id:
		return {"result": "rejected", "fee": 0, "msg": "Ele já é seu jogador."}
	if not world.transfer_window_open():
		return {"result": "rejected", "fee": 0, "msg": "A janela de transferências está fechada."}
	if p.loan.size() > 0:
		return {"result": "rejected", "fee": 0, "msg": "Ele está emprestado e não pode ser negociado agora."}
	if upfront_cost(fee, deal) > user.transfer_budget:
		return {"result": "rejected", "fee": 0, "msg": "A diretoria não libera esse valor agora. Orçamento: %s." % Fmt.money(user.transfer_budget)}
	var neg: Dictionary = world.stats.get("neg", {})
	var key := str(p.id)
	var n: Dictionary = neg.get(key, {"d": -1, "n": 0})
	if int(n["d"]) == world.current_turn() and int(n["n"]) >= MAX_BIDS_PER_DAY:
		return {"result": "rejected", "fee": 0, "msg": "O clube encerrou as conversas por hoje. Tente depois do próximo jogo."}
	if int(n["d"]) != world.current_turn():
		n = {"d": world.current_turn(), "n": 0}
	n["n"] = int(n["n"]) + 1
	neg[key] = n
	world.stats["neg"] = neg
	var seller := world.club(p.club_id)
	var ask := asking_price(world, p)
	# Clube não vende titular absoluto para rival direto, exceto por muito dinheiro.
	if seller.is_rival(user.id) and p.squad_status <= Player.STATUS_STARTER:
		ask = int(ask * 1.4)
	# Elenco curto na posição: pede mais.
	if _family_count(world, seller, p.position) <= _family_min(p.position):
		ask = int(ask * 1.25)
	var swaps := swap_players(world, deal)
	for sp: Player in swaps:
		if sp.club_id != user.id or not sp.loan.is_empty():
			return {"result": "rejected", "fee": 0, "msg": "%s não pode entrar na troca." % sp.display_name()}
		if interest(world, sp, seller) < 0.2:
			return {"result": "rejected", "fee": 0, "msg": "%s não aceita se mudar para o %s. Tire-o da troca." % [sp.display_name(), seller.short_name]}
	var swap_total := swap_value(world, swaps, seller)
	var value := deal_value(fee, deal) + swap_total
	var with_swap := "" if swaps.is_empty() else " (com a troca)"
	if value >= ask:
		return {"result": "accepted", "fee": fee, "msg": "%s aceitou a proposta%s!" % [seller.short_name, with_swap]}
	if value >= ask * 0.8:
		# Quanto de dinheiro a mais cobre a diferença (a parte da troca já está contada).
		var target := (value + ask) * 0.5 if value >= ask * 0.92 else float(ask)
		var cash_f := maxf(0.5, deal_value(1_000_000, deal) / 1_000_000.0)
		var counter := Valuation.round_value(fee + (target - value) / cash_f)
		counter = maxi(counter, fee + 1000)
		return {"result": "counter", "fee": counter, "msg": "%s pede %s%s." % [seller.short_name, Fmt.money(counter), with_swap]}
	return {"result": "rejected", "fee": 0, "msg": "Proposta recusada: muito abaixo do esperado (%s pediria algo perto de %s%s)." % [seller.short_name, Fmt.money(Valuation.round_value(maxf(0.0, ask * 1.05 - swap_total))), with_swap]}


## Jogadores do usuário oferecidos como parte do pagamento (deal["swap"] = [ids]).
static func swap_players(world: GameWorld, deal: Dictionary) -> Array:
	var out: Array = []
	for pid in deal.get("swap", []):
		var sp := world.player(int(pid))
		if sp != null:
			out.append(sp)
	return out


## Quanto o clube vendedor acha que um jogador oferecido na troca vale para ele.
static func swap_worth(world: GameWorld, sp: Player, seller: Club) -> int:
	var f := 0.85
	if _family_count(world, seller, sp.position) <= _family_min(sp.position):
		f = 1.0 # precisa de alguém na posição
	var level := PlayerGenerator.club_level(seller)
	if sp.ovr_f < level - 8.0:
		f *= 0.4 # não serviria nem de reserva
	elif sp.ovr_f < level - 4.0:
		f *= 0.7
	var age := sp.age(world.year)
	if age >= 32:
		f *= 0.7
	elif age <= 22 and sp.potential >= sp.overall + 6:
		f *= 1.1
	if sp.contract_years_left(world.year) <= 0:
		f *= 0.8
	return Valuation.round_value(sp.value * f)


static func swap_value(world: GameWorld, swaps: Array, seller: Club) -> float:
	var total := 0.0
	for sp: Player in swaps:
		total += swap_worth(world, sp, seller)
	return total


## Termos pessoais. Retorna {result: "accepted"|"counter"|"rejected", wage, msg}.
static func user_terms(world: GameWorld, p: Player, wage: int, years: int, deal: Dictionary = {}) -> Dictionary:
	var user := world.user_club()
	var i := interest(world, p, user)
	if i < 0.18:
		return {"result": "rejected", "wage": 0, "msg": "%s não tem interesse em jogar no %s." % [p.display_name(), user.short_name]}
	var demand := wage_ask(world, p, user)
	var pref := preferred_years(world, p)
	if absi(years - pref) >= 2:
		demand = Valuation.round_wage(demand * 1.1)
	demand = adjust_demand(demand, years, deal)
	if not _wage_fits(world, user, p, wage):
		return {"result": "rejected", "wage": demand, "msg": "Folha salarial estourada: a diretoria limita a %s/mês." % Fmt.money(user.wage_budget)}
	if wage >= demand:
		return {"result": "accepted", "wage": wage, "msg": "%s aceitou os termos!" % p.display_name()}
	if wage >= demand * 0.9 and world.rng.randf() < 0.5:
		return {"result": "accepted", "wage": wage, "msg": "%s aceitou, mesmo pedindo um pouco mais." % p.display_name()}
	return {"result": "counter", "wage": demand, "msg": "%s quer %s por %d ano(s)." % [p.display_name(), Fmt.money_month(demand), years]}


static func _wage_fits(world: GameWorld, club: Club, p: Player, wage: int) -> bool:
	var bill := FinanceManager.wage_bill(world, club)
	if p.club_id == club.id:
		bill -= p.wage
	return bill + wage <= int(club.wage_budget * 1.02)


# ---------------------------------------------------------------------------
# Condições do negócio: parcelas, revenda, luvas e multa rescisória
# ---------------------------------------------------------------------------

const AGENT_FEE := 0.05 # comissão do empresário nas compras do usuário
const CLAUSE_MULTS: Array[int] = [0, 2, 3, 5] # multa = N × valor (0 = sem multa)


## Quanto a proposta vale para o clube vendedor: parcelar desvaloriza, % de revenda valoriza.
static func deal_value(fee: int, deal: Dictionary) -> float:
	var inst := clampi(int(deal.get("inst", 1)), 1, 3)
	var so := clampf(float(deal.get("sell_on", 0.0)), 0.0, 0.3)
	return fee * (1.0 - 0.06 * (inst - 1)) + fee * so * 0.5


## O que sai do caixa agora: primeira parcela + comissão do empresário.
static func upfront_cost(fee: int, deal: Dictionary) -> int:
	var inst := clampi(int(deal.get("inst", 1)), 1, 3)
	return int(ceil(float(fee) / inst)) + int(fee * AGENT_FEE)


## Pedido salarial ajustado por luvas (dinheiro na assinatura) e multa rescisória.
static func adjust_demand(demand: int, years: int, deal: Dictionary) -> int:
	var d := float(demand)
	var bonus := int(deal.get("bonus", 0))
	if bonus > 0:
		d -= bonus / (12.0 * clampi(years, 1, 5)) * 0.85
	# Multa baixa deixa a porta aberta para uma proposta grande: o jogador aceita ganhar menos.
	match int(deal.get("clause", 3)):
		0:
			d *= 1.05
		2:
			d *= 0.95
		3:
			d *= 0.98
		5:
			d *= 1.02
	return Valuation.round_wage(maxf(d, demand * 0.55))


## Aplica as condições depois de fechado o contrato (parcelas, luvas, multa, revenda).
static func apply_deal(world: GameWorld, p: Player, buyer: Club, seller_id: int, fee: int, deal: Dictionary) -> void:
	var inst := clampi(int(deal.get("inst", 1)), 1, 3)
	if fee > 0:
		# Comissão do empresário
		buyer.add_ledger("compras", -int(fee * AGENT_FEE))
		if inst > 1:
			# complete_transfer cobrou tudo; devolve o que fica para as próximas temporadas
			var later := fee - int(ceil(float(fee) / inst))
			buyer.add_ledger("compras", later)
			buyer.transfer_budget += later
			var sched: Array = world.stats.get("installments", [])
			var part := int(later / (inst - 1))
			var seller := world.club(seller_id)
			for k in inst - 1:
				sched.append({"y": world.year + 1 + k, "v": part, "p": p.display_name(), "cn": seller.short_name if seller != null else ""})
			world.stats["installments"] = sched
	var so := float(deal.get("sell_on", 0.0))
	if so > 0.0 and seller_id >= 0:
		p.clauses = {"so": seller_id, "pct": so}
	var bonus := int(deal.get("bonus", 0))
	if bonus > 0:
		buyer.add_ledger("luvas", -bonus)
	var cm := int(deal.get("clause", 0))
	p.release_clause = Valuation.round_value(p.value * cm) if cm > 0 else 0


## Parcelas de compras antigas vencem na virada do ano.
static func pay_installments(world: GameWorld) -> int:
	var sched: Array = world.stats.get("installments", [])
	if sched.is_empty() or not world.has_user():
		return 0
	var total := 0
	var keep: Array = []
	for e in sched:
		if int(e["y"]) <= world.year:
			total += int(e["v"])
		else:
			keep.append(e)
	world.stats["installments"] = keep
	if total > 0:
		world.user_club().add_ledger("compras", -total)
		NewsManager.post_raw(world, "Parcelas de transferências", "O clube pagou %s em parcelas de contratações antigas." % Fmt.money(total), world.user_club_id, -1, NewsEvent.IMP_NORMAL)
	return total


static func pending_installments(world: GameWorld) -> int:
	var total := 0
	for e in world.stats.get("installments", []):
		total += int(e["v"])
	return total


# ---------------------------------------------------------------------------
# Empréstimos
# ---------------------------------------------------------------------------

static func loan_fee(p: Player) -> int:
	return Valuation.round_value(p.value * 0.08)


## O dono aceita emprestar ao usuário? {ok, msg}
static func loan_in_terms(world: GameWorld, p: Player) -> Dictionary:
	var user := world.user_club()
	if not world.transfer_window_open():
		return {"ok": false, "msg": "A janela de transferências está fechada."}
	if p.club_id < 0 or p.club_id == user.id or p.loan.size() > 0:
		return {"ok": false, "msg": "Não dá para pedir esse jogador emprestado."}
	var seller := world.club(p.club_id)
	if p.squad_status <= Player.STATUS_STARTER and p.age(world.year) > 21:
		return {"ok": false, "msg": "%s não empresta um titular." % seller.short_name}
	if seller.is_rival(user.id):
		return {"ok": false, "msg": "%s não empresta jogadores para o rival." % seller.short_name}
	if user.player_ids.size() >= int(DatabaseManager.squad_rules()["max_players"]):
		return {"ok": false, "msg": "Elenco cheio."}
	if interest(world, p, user) < 0.25:
		return {"ok": false, "msg": "%s não quer ir para o %s." % [p.display_name(), user.short_name]}
	if loan_fee(p) > user.transfer_budget:
		return {"ok": false, "msg": "Taxa de empréstimo acima do orçamento."}
	if not _wage_fits(world, user, p, p.wage):
		return {"ok": false, "msg": "O salário dele (%s) estoura a folha." % Fmt.money_month(p.wage)}
	return {"ok": true, "msg": "Empréstimo até o fim da temporada por %s. O %s paga o salário (%s)." % [Fmt.money(loan_fee(p)), user.short_name, Fmt.money_month(p.wage)]}


static func loan_in(world: GameWorld, p: Player) -> Dictionary:
	var r := loan_in_terms(world, p)
	if not r["ok"]:
		return r
	var user := world.user_club()
	var owner := world.club(p.club_id)
	var fee := loan_fee(p)
	user.add_ledger("compras", -fee)
	user.transfer_budget = maxi(0, user.transfer_budget - fee)
	owner.add_ledger("vendas", fee)
	_move_loan(world, p, owner, user)
	NewsManager.post_raw(world, "%s chega emprestado" % p.display_name(), "%s vai defender o %s até o fim da temporada, emprestado pelo %s." % [p.display_name(), user.short_name, owner.short_name], user.id, p.id, NewsEvent.IMP_HIGH, "transferencia")
	return {"ok": true, "msg": "%s chegou por empréstimo!" % p.display_name()}


## Empresta um jogador do usuário a um clube onde ele vai jogar.
static func loan_out(world: GameWorld, p: Player) -> Dictionary:
	var user := world.user_club()
	if not world.transfer_window_open():
		return {"ok": false, "msg": "A janela de transferências está fechada."}
	if p.club_id != user.id or p.loan.size() > 0:
		return {"ok": false, "msg": "Não dá para emprestar esse jogador."}
	if user.player_ids.size() <= int(DatabaseManager.squad_rules()["min_players"]):
		return {"ok": false, "msg": "Elenco curto demais para emprestar."}
	var best: Club = null
	var best_v := -1e9
	for _k in 40:
		var c: Club = world.clubs[world.rng.randi_range(0, world.clubs.size() - 1)]
		if c.id == user.id or c.player_ids.size() >= int(DatabaseManager.squad_rules()["max_players"]):
			continue
		var level := PlayerGenerator.club_level(c)
		if p.ovr_f < level - 3.0 or p.ovr_f > level + 10.0:
			continue
		var v := -absf(p.ovr_f - level - 2.0) + (4.0 if c.nation == user.nation else 0.0) + world.rng.randf_range(0.0, 3.0)
		if v > best_v:
			best_v = v
			best = c
	if best == null:
		return {"ok": false, "msg": "Nenhum clube se interessou pelo empréstimo agora."}
	_move_loan(world, p, user, best)
	p.squad_status = Player.STATUS_STARTER
	NewsManager.post_raw(world, "%s emprestado ao %s" % [p.display_name(), best.short_name], "%s vai ganhar minutos no %s (%s) até o fim da temporada." % [p.display_name(), best.short_name, world.league_short(best.league_id)], user.id, p.id, NewsEvent.IMP_NORMAL, "transferencia")
	return {"ok": true, "msg": "%s foi emprestado ao %s até o fim da temporada." % [p.display_name(), best.short_name]}


static func _move_loan(world: GameWorld, p: Player, owner: Club, borrower: Club) -> void:
	owner.player_ids.erase(p.id)
	borrower.player_ids.append(p.id)
	p.club_id = borrower.id
	p.loan = {"from": owner.id, "until": world.year}
	p.transfer_listed = false
	p.spells.append({"c": borrower.id, "cn": borrower.short_name + " (empr.)", "from": world.year, "to": 0, "a": 0, "g": 0, "as": 0})
	if borrower.sheet != null and world.is_user_club(owner.id):
		pass
	for o: TransferOffer in world.offers:
		if o.player_id == p.id and o.is_pending():
			o.status = TransferOffer.WITHDRAWN


## Fim de temporada: emprestados voltam para casa.
static func return_loans(world: GameWorld) -> Array:
	MarketAI.exercise_loan_options(world)
	var back: Array = []
	for p: Player in world.players.values():
		if p.loan.is_empty() or int(p.loan.get("until", 0)) > world.year:
			continue
		var owner := world.club(int(p.loan["from"]))
		var borrower := world.club(p.club_id)
		if borrower != null:
			borrower.player_ids.erase(p.id)
		_close_spell(world, p)
		p.loan = {}
		if owner == null:
			p.club_id = -1
			continue
		owner.player_ids.append(p.id)
		p.club_id = owner.id
		p.spells.append({"c": owner.id, "cn": owner.short_name, "from": world.year, "to": 0, "a": 0, "g": 0, "as": 0})
		if world.is_user_club(owner.id):
			back.append(p)
	return back


static func loaned_out(world: GameWorld) -> Array:
	var out: Array = []
	for p: Player in world.players.values():
		if not p.loan.is_empty() and world.is_user_club(int(p.loan.get("from", -1))):
			out.append(p)
	return out


## Executa a transferência (qualquer clube). fee pode ser 0 (livre).
static func complete_transfer(world: GameWorld, p: Player, buyer: Club, fee: int, wage: int, years: int) -> Transfer:
	var seller_id := p.club_id
	var seller := world.club(seller_id) if seller_id >= 0 else null
	if seller != null:
		seller.player_ids.erase(p.id)
		seller.add_ledger("vendas", fee)
		FinanceManager.on_sale(world, seller, fee)
		_close_spell(world, p)
		# Percentual de revenda para um ex-clube
		var so_club := world.club(int(p.clauses.get("so", -1)))
		if so_club != null and so_club.id != buyer.id and fee > 0:
			var share := int(fee * float(p.clauses.get("pct", 0.0)))
			seller.add_ledger("vendas", -share)
			so_club.add_ledger("vendas", share)
			if world.is_user_club(so_club.id):
				NewsManager.post_raw(world, "Dinheiro da revenda de %s" % p.display_name(), "O %s recebeu %s pela cláusula de revenda." % [so_club.short_name, Fmt.money(share)], so_club.id, p.id, NewsEvent.IMP_HIGH, "transferencia")
		p.clauses = {}
	buyer.add_ledger("compras", -fee)
	buyer.transfer_budget = maxi(0, buyer.transfer_budget - fee)
	buyer.player_ids.append(p.id)
	buyer.cohesion = maxf(20.0, buyer.cohesion - 2.5)
	p.club_id = buyer.id
	p.wage = wage
	p.contract_end = world.year + clampi(years, 1, 5)
	p.joined_year = world.year
	p.transfer_listed = false
	p.asking_price = 0
	p.release_clause = 0
	p.retiring = false
	p.morale = clampf(p.morale + 10.0, 0.0, 100.0)
	p.spells.append({"c": buyer.id, "cn": buyer.short_name, "from": world.year, "to": 0, "a": 0, "g": 0, "as": 0})
	_set_status_on_arrival(world, p, buyer)
	world.mark_free_agents_dirty()
	Valuation.update_value(p, world.year)
	var kind := Transfer.KIND_BUY if seller != null else Transfer.KIND_FREE
	var t := Transfer.make(world.year, world.current_day(), p, seller_id, buyer.id, fee, kind)
	world.transfer_log.append(t)
	world.stat_add("transfers")
	world.stat_add("transfer_fees", fee)
	# Propostas pendentes por esse jogador perdem o sentido.
	for o: TransferOffer in world.offers:
		if o.player_id == p.id and o.is_pending():
			o.status = TransferOffer.WITHDRAWN
	if world.is_user_club(buyer.id) and buyer.sheet != null:
		pass # a escalação é revalidada antes do próximo jogo
	NewsManager.on_transfer(world, t)
	return t


static func _close_spell(world: GameWorld, p: Player) -> void:
	if not p.spells.is_empty():
		var s: Dictionary = p.spells[p.spells.size() - 1]
		if int(s.get("to", 0)) == 0:
			s["to"] = world.year


static func _set_status_on_arrival(world: GameWorld, p: Player, club: Club) -> void:
	var better := 0
	for q in world.squad(club):
		if q != p and q.position == p.position and q.ovr_f > p.ovr_f:
			better += 1
	var age := p.age(world.year)
	if better == 0:
		p.squad_status = Player.STATUS_STARTER
	elif age <= 21 and p.potential >= p.overall + 6:
		p.squad_status = Player.STATUS_PROSPECT
	elif better == 1:
		p.squad_status = Player.STATUS_ROTATION
	else:
		p.squad_status = Player.STATUS_BACKUP


## Contratação de jogador livre (usuário). Retorna {ok, msg}.
static func user_sign_free(world: GameWorld, p: Player, wage: int, years: int, deal: Dictionary = {}) -> Dictionary:
	var user := world.user_club()
	if p.club_id >= 0:
		return {"ok": false, "msg": "Ele tem contrato com outro clube."}
	if user.player_ids.size() >= int(DatabaseManager.squad_rules()["max_players"]):
		return {"ok": false, "msg": "Elenco cheio (máximo %d)." % int(DatabaseManager.squad_rules()["max_players"])}
	var r := user_terms(world, p, wage, years, deal)
	if r["result"] != "accepted":
		return {"ok": false, "msg": r["msg"], "wage": r.get("wage", 0), "result": r["result"]}
	complete_transfer(world, p, user, 0, wage, years)
	apply_deal(world, p, user, -1, 0, deal)
	return {"ok": true, "msg": "%s assinou com o %s!" % [p.display_name(), user.short_name]}


## Contratação com clube (depois de proposta aceita). Retorna {ok, msg}.
static func user_sign(world: GameWorld, p: Player, fee: int, wage: int, years: int, deal: Dictionary = {}) -> Dictionary:
	var user := world.user_club()
	if upfront_cost(fee, deal) > user.transfer_budget:
		return {"ok": false, "msg": "Orçamento insuficiente."}
	var swaps := swap_players(world, deal)
	if user.player_ids.size() - swaps.size() >= int(DatabaseManager.squad_rules()["max_players"]):
		return {"ok": false, "msg": "Elenco cheio (máximo %d)." % int(DatabaseManager.squad_rules()["max_players"])}
	for sp: Player in swaps:
		if sp.club_id != user.id or not sp.loan.is_empty():
			return {"ok": false, "msg": "%s não está mais disponível para a troca." % sp.display_name()}
	var r := user_terms(world, p, wage, years, deal)
	if r["result"] != "accepted":
		return {"ok": false, "msg": r["msg"], "wage": r.get("wage", 0), "result": r["result"]}
	var seller_id := p.club_id
	var seller := world.club(seller_id)
	complete_transfer(world, p, user, fee, wage, years)
	apply_deal(world, p, user, seller_id, fee, deal)
	var names: Array = []
	for sp: Player in swaps:
		var sw := maxi(sp.wage, Valuation.wage_demand(sp, seller, world.year))
		complete_transfer(world, sp, seller, 0, sw, preferred_years(world, sp))
		names.append(sp.display_name())
	if not names.is_empty():
		return {"ok": true, "msg": "%s é o novo reforço do %s! %s vai para o %s na troca." % [p.display_name(), user.short_name, " e ".join(names), seller.short_name]}
	return {"ok": true, "msg": "%s é o novo reforço do %s!" % [p.display_name(), user.short_name]}


## Renovação de contrato. Retorna {result, wage, msg}.
static func renewal_terms(world: GameWorld, p: Player, wage: int, years: int, deal: Dictionary = {}) -> Dictionary:
	var club := world.club(p.club_id)
	var demand := float(Valuation.wage_demand(p, club, world.year))
	demand *= 1.0 + maxf(0.0, (55.0 - p.morale) / 100.0)
	if p.squad_status == Player.STATUS_STAR:
		demand *= 1.1
	demand = maxf(demand, p.wage * (0.9 if p.age(world.year) >= 32 else 1.0))
	var d := adjust_demand(Valuation.round_wage(demand), years, deal)
	# Ambicioso bom demais para o clube pode recusar.
	var ambition := p.trait_sum("ambition")
	var level := PlayerGenerator.club_level(club)
	if ambition >= 25.0 and p.ovr_f >= level + 6.0 and p.age(world.year) <= 29:
		return {"result": "rejected", "wage": d, "msg": "%s quer jogar num clube maior e não pretende renovar." % p.display_name()}
	if p.morale < 25.0:
		return {"result": "rejected", "wage": d, "msg": "%s está insatisfeito e não quer conversar agora." % p.display_name()}
	if not _wage_fits(world, club, p, wage):
		return {"result": "rejected", "wage": d, "msg": "Esse salário estoura o limite da folha (%s/mês)." % Fmt.money(club.wage_budget)}
	if wage >= d:
		return {"result": "accepted", "wage": wage, "msg": "Renovado até %d!" % (world.year + years)}
	return {"result": "counter", "wage": d, "msg": "%s pede %s." % [p.display_name(), Fmt.money_month(d)]}


static func apply_renewal(world: GameWorld, p: Player, wage: int, years: int) -> void:
	p.wage = wage
	p.contract_end = world.year + clampi(years, 1, 5)
	p.morale = clampf(p.morale + 6.0, 0.0, 100.0)
	Valuation.update_value(p, world.year)


## Custo de rescisão: metade dos salários restantes do contrato.
static func release_cost(world: GameWorld, p: Player) -> int:
	var months := maxi(1, (p.contract_end - world.year) * 12 + 6)
	return int(p.wage * months * 0.5)


static func release(world: GameWorld, p: Player) -> int:
	var club := world.club(p.club_id)
	var cost := release_cost(world, p)
	club.add_ledger("rescisoes", -cost)
	club.player_ids.erase(p.id)
	_close_spell(world, p)
	var t := Transfer.make(world.year, world.current_day(), p, club.id, -1, 0, Transfer.KIND_RELEASE)
	world.transfer_log.append(t)
	p.club_id = -1
	p.wage = 0
	p.transfer_listed = false
	p.contract_end = world.year
	world.mark_free_agents_dirty()
	return cost


# ---------------------------------------------------------------------------
# Propostas recebidas pelo usuário
# ---------------------------------------------------------------------------

static func pending_offers(world: GameWorld) -> Array:
	var out: Array = []
	for o: TransferOffer in world.offers:
		if o.is_pending():
			out.append(o)
	return out


const MAX_COUNTERS := 3 # rodadas de contraproposta antes de o comprador desistir


## Resposta do usuário: "accept", "reject" ou "counter" (pede mais). Retorna mensagem.
## Na contraproposta, o comprador aceita se couber no teto dele; se não, sobe um pouco
## (até MAX_COUNTERS rodadas) ou desiste quando o pedido é absurdo.
static func respond_offer(world: GameWorld, o: TransferOffer, action: String, counter_fee: int = 0) -> String:
	var p := world.player(o.player_id)
	var buyer := world.club(o.buyer_id)
	if p == null or buyer == null or not o.is_pending() or p.club_id != o.seller_id:
		o.status = TransferOffer.WITHDRAWN
		return "Essa proposta não está mais disponível."
	match action:
		"accept":
			if not world.transfer_window_open():
				return "A janela está fechada."
			o.status = TransferOffer.ACCEPTED
			var wage := Valuation.wage_demand(p, buyer, world.year)
			complete_transfer(world, p, buyer, o.fee, wage, preferred_years(world, p))
			return "%s foi vendido ao %s por %s." % [p.display_name(), buyer.short_name, Fmt.money(o.fee)]
		"reject":
			o.status = TransferOffer.REJECTED
			p.morale = clampf(p.morale - (6.0 if p.trait_sum("ambition") >= 25.0 else 1.0), 0.0, 100.0)
			return "Proposta recusada."
		"counter":
			if o.raised or o.rounds >= MAX_COUNTERS:
				o.status = TransferOffer.WITHDRAWN
				return "%s cansou de negociar e desistiu." % buyer.short_name
			o.rounds += 1
			if counter_fee <= o.max_fee:
				o.fee = counter_fee
				o.raised = true
				return "%s aceitou pagar %s. Confirme a venda!" % [buyer.short_name, Fmt.money(counter_fee)]
			if counter_fee > o.max_fee * 1.6:
				o.status = TransferOffer.WITHDRAWN
				return "%s achou o pedido absurdo e desistiu." % buyer.short_name
			# Sobe em direção ao teto, sem revelá-lo de uma vez.
			var step := 0.5 if o.rounds == 1 else 0.8
			var nf := Valuation.round_value(o.fee + (o.max_fee - o.fee) * step)
			if nf <= o.fee:
				o.status = TransferOffer.WITHDRAWN
				return "%s não pode pagar mais e desistiu." % buyer.short_name
			o.fee = nf
			o.expires_day = maxi(o.expires_day, world.current_turn() + 1)
			var last := o.rounds >= MAX_COUNTERS
			return "%s subiu a oferta para %s.%s" % [buyer.short_name, Fmt.money(nf), " É a última palavra deles." if last else ""]
	return ""


# ---------------------------------------------------------------------------
# IA de mercado (a cada dia de jogo)
# ---------------------------------------------------------------------------

## Processa mercado da IA (MarketAI) e as propostas pelo elenco do usuário. Retorna as Transfer feitas.
static func process_matchday(world: GameWorld) -> Array:
	var done := MarketAI.matchday(world)
	if world.transfer_window_open():
		_generate_offers_for_user(world)
	_expire_offers(world)
	return done


## Índices do mercado (reconstruídos por data): por família de posição × faixa de nível e por
## família dentro de cada país (clubes compram muito mais no próprio país).
static func _build_index(world: GameWorld) -> Dictionary:
	var band: Array = []
	for _f in FAMILIES:
		band.append({})
	var nat := {}
	for p: Player in world.players.values():
		if p.retiring or not p.loan.is_empty():
			continue
		var f := _family_of(p.position)
		var b := int(p.ovr_f / BAND)
		if not band[f].has(b):
			band[f][b] = []
		band[f][b].append(p)
		var n: String = world.clubs[p.club_id].nation if p.club_id >= 0 else p.nationality
		if not nat.has(n):
			var arr: Array = []
			for _k in FAMILIES:
				arr.append([])
			nat[n] = arr
		nat[n][f].append(p)
	return {"band": band, "nat": nat}


static func _family_of(pos: int) -> int:
	for i in FAMILIES.size():
		if FAMILIES[i][0].has(pos):
			return i
	return 3


static func _family_min(pos: int) -> int:
	return int(FAMILIES[_family_of(pos)][1])


static func _family_count(world: GameWorld, club: Club, pos: int) -> int:
	var fam := _family_of(pos)
	var n := 0
	for p in world.squad(club):
		if _family_of(p.position) == fam and p.injury_weeks < 6:
			n += 1
	return n


## Carências do elenco: [{fam, urgency, best}] ordenado por urgência.
static func squad_needs(world: GameWorld, club: Club) -> Array:
	var level := PlayerGenerator.club_level(club)
	var counts: Array = []
	var best: Array = []
	for _f in FAMILIES:
		counts.append(0)
		best.append(0.0)
	for p in world.squad(club):
		var f := _family_of(p.position)
		if p.injury_weeks < 6 and not p.retiring:
			counts[f] += 1
		best[f] = maxf(best[f], p.ovr_f)
	var out: Array = []
	for i in FAMILIES.size():
		var urgency := maxf(0.0, float(FAMILIES[i][1] - counts[i])) * 3.0 + maxf(0.0, level - best[i]) / 3.0
		if urgency > 0.5:
			out.append({"fam": i, "urgency": urgency, "best": best[i], "count": counts[i]})
	out.sort_custom(func(a, b): return a["urgency"] > b["urgency"])
	return out


## Vaga do time titular com o pior rendimento (alvo de reforço).
static func _weakest_starter(world: GameWorld, club: Club) -> Dictionary:
	var fname := club.sheet.formation if club.sheet != null else "4-4-2"
	var slots: Array = DatabaseManager.formation(fname)["slots"]
	# A escalação do último jogo já é a melhor disponível; só recalcula se ela estiver incompleta.
	var xi: Array = club.sheet.starters if club.sheet != null and club.sheet.starters.size() == slots.size() else []
	for pid in xi:
		var q := world.player(pid if pid != null else -1)
		if q == null or q.club_id != club.id:
			xi = []
			break
	if xi.is_empty():
		xi = ClubAI.best_eleven(world, club, fname)
	var worst := {}
	for i in slots.size():
		var pos: int = slots[i]["pos"]
		var r := 0.0
		if xi[i] >= 0:
			r = world.player(xi[i]).rating_at(pos)
		if worst.is_empty() or r < float(worst["rating"]):
			worst = {"pos": pos, "rating": r}
	return worst


## Clube endividado anuncia um jogador valioso (mas não insubstituível) à venda.
static func _ai_list_for_sale(world: GameWorld, club: Club) -> void:
	var squad := world.squad(club)
	squad.sort_custom(func(a, b): return a.value > b.value)
	for p in squad:
		if p.transfer_listed:
			return
		if not p.loan.is_empty():
			continue
		if _family_count(world, club, p.position) > _family_min(p.position):
			p.transfer_listed = true
			return


static func _ai_release_weakest(world: GameWorld, club: Club) -> void:
	var squad := world.squad(club)
	squad.sort_custom(func(a, b): return a.ovr_f + (8.0 if a.age(world.year) <= 21 else 0.0) < b.ovr_f + (8.0 if b.age(world.year) <= 21 else 0.0))
	for p in squad:
		if not p.loan.is_empty():
			continue
		if _family_count(world, club, p.position) > _family_min(p.position) + 1:
			release(world, p)
			return


## A IA faz propostas por jogadores do usuário (principalmente os listados e os em boa fase).
static func _generate_offers_for_user(world: GameWorld) -> void:
	if not world.has_user():
		return
	var user := world.user_club()
	var pending := 0
	for o: TransferOffer in world.offers:
		if o.is_pending():
			pending += 1
	if pending >= 4:
		return
	for p in world.squad(user):
		if not p.loan.is_empty():
			continue
		# Multa rescisória: um clube rico pode simplesmente pagar e levar
		if p.release_clause > 0 and world.rng.randf() < 0.06 * (1.6 if p.release_clause <= p.value * 2.2 else 0.5):
			var rich := _find_buyer(world, p)
			if rich != null and rich.transfer_budget >= p.release_clause:
				var clause: int = p.release_clause
				NewsManager.post_raw(world, "%s paga a multa de %s" % [rich.short_name, p.display_name()],
					"O %s depositou %s, o valor da multa rescisória, e levou %s. Não havia o que fazer." % [rich.short_name, Fmt.money(clause), p.display_name()],
					user.id, p.id, NewsEvent.IMP_HEADLINE, "transferencia")
				complete_transfer(world, p, rich, clause, Valuation.wage_demand(p, rich, world.year), preferred_years(world, p))
				return
		var chance := 0.012
		if p.transfer_listed:
			chance += 0.2
		if p.form() >= 7.2:
			chance += 0.04
		if p.squad_status == Player.STATUS_STAR:
			chance += 0.02
		chance += MarketAI.extra_offer_chance(world, p)
		if world.rng.randf() >= chance:
			continue
		var already := false
		for o: TransferOffer in world.offers:
			if o.player_id == p.id and o.is_pending():
				already = true
		if already:
			continue
		var buyer := _find_buyer(world, p)
		if buyer == null:
			continue
		var bids := MarketAI.bids_for_user_player(world, buyer, p)
		var fee: int = bids[0]
		var o := TransferOffer.new()
		o.id = world.next_offer_id
		world.next_offer_id += 1
		o.player_id = p.id
		o.buyer_id = buyer.id
		o.seller_id = user.id
		o.fee = fee
		o.max_fee = bids[1]
		o.created_day = world.current_turn()
		o.expires_day = world.current_turn() + OFFER_DAYS
		world.offers.append(o)
		NewsManager.on_offer_received(world, o)
		pending += 1
		if pending >= 4:
			return


## Usuário oferece um jogador do elenco aos clubes: quem tiver interesse faz proposta na hora.
## Uma vez por jogador a cada rodada. Retorna {ok, n, msg}.
static func shop_player(world: GameWorld, p: Player) -> Dictionary:
	var user := world.user_club()
	if p.club_id != user.id or not p.loan.is_empty():
		return {"ok": false, "n": 0, "msg": "Só dá para oferecer jogadores do seu elenco."}
	if not world.transfer_window_open():
		return {"ok": false, "n": 0, "msg": "A janela de transferências está fechada."}
	var shop: Dictionary = world.stats.get("shop", {})
	if int(shop.get(str(p.id), -99)) == world.current_turn():
		return {"ok": false, "n": 0, "msg": "Você já ofereceu %s nesta rodada. Espere o próximo jogo." % p.display_name()}
	shop[str(p.id)] = world.current_turn()
	world.stats["shop"] = shop
	var tried := {}
	var n := 0
	var base := float(asking_price(world, p)) if p.transfer_listed else float(p.value)
	for _k in 6:
		var buyer := _find_buyer(world, p)
		if buyer == null or tried.has(buyer.id):
			continue
		tried[buyer.id] = true
		var already := false
		for o: TransferOffer in world.offers:
			if o.player_id == p.id and o.buyer_id == buyer.id and o.is_pending():
				already = true
		if already or world.rng.randf() > interest(world, p, buyer) + 0.15:
			continue
		# Quem oferece mostra pressa: as propostas vêm um pouco abaixo do valor.
		var fee := Valuation.round_value(base * world.rng.randf_range(0.7, 0.98))
		var o := TransferOffer.new()
		o.id = world.next_offer_id
		world.next_offer_id += 1
		o.player_id = p.id
		o.buyer_id = buyer.id
		o.seller_id = user.id
		o.fee = fee
		o.max_fee = Valuation.round_value(minf(buyer.transfer_budget, fee * world.rng.randf_range(1.05, 1.3)))
		o.created_day = world.current_turn()
		o.expires_day = world.current_turn() + OFFER_DAYS
		world.offers.append(o)
		n += 1
		if n >= 3:
			break
	if n == 0:
		return {"ok": true, "n": 0, "msg": "Nenhum clube se interessou por %s agora." % p.display_name()}
	return {"ok": true, "n": n, "msg": "%d clube(s) fizeram proposta por %s." % [n, p.display_name()]}


static func _find_buyer(world: GameWorld, p: Player) -> Club:
	return MarketAI.find_buyer_for(world, p)


static func _expire_offers(world: GameWorld) -> void:
	var keep: Array = []
	for o: TransferOffer in world.offers:
		if o.is_pending() and world.current_turn() > o.expires_day:
			o.status = TransferOffer.EXPIRED
		if o.is_pending() or world.current_turn() - o.expires_day <= 3:
			keep.append(o)
	world.offers = keep


# ---------------------------------------------------------------------------
# Fim de temporada: contratos e equilíbrio de elencos
# ---------------------------------------------------------------------------

## Contratos que vencem agora: IA renova quem vale a pena; o resto (e os do usuário não renovados) sai.
## Retorna jogadores que deixaram o clube do usuário.
static func process_expiring_contracts(world: GameWorld) -> Array:
	var left_user: Array = []
	for p: Player in world.players.values().duplicate():
		if p.club_id < 0 or p.contract_end > world.year:
			continue
		var club := world.club(p.club_id)
		if world.is_user_club(club.id):
			left_user.append(p)
			release_free(world, p)
			continue
		var level := PlayerGenerator.club_level(club)
		var age := p.age(world.year)
		var useful := p.ovr_f >= level - 3.0 or p.squad_status <= Player.STATUS_STARTER
		var chance := 0.0
		if p.retiring:
			chance = 0.0
		elif age <= 22 and p.potential >= level - 2:
			chance = 0.9
		elif useful and age <= 31:
			chance = 0.85
		elif useful:
			chance = 0.55
		elif age <= 29:
			chance = 0.6 if club.player_ids.size() <= int(DatabaseManager.squad_rules()["ideal_players"]) else 0.35
		else:
			chance = 0.25
		# Ambicioso bom demais para o clube recusa renovar e sai de graça (lei Bosman).
		if p.trait_sum("ambition") >= 20.0 and p.ovr_f >= level + 5.0 and age <= 30:
			chance *= 0.35
		var wage := Valuation.wage_demand(p, club, world.year)
		# A folha precisa caber no orçamento (clube endividado perde jogadores caros).
		var bill := FinanceManager.wage_bill(world, club) - p.wage + wage
		if bill > club.wage_budget * 1.05:
			chance *= 0.25
		if world.rng.randf() < chance:
			apply_renewal(world, p, wage, preferred_years(world, p))
		else:
			release_free(world, p)
	return left_user


## Saída sem custo (fim de contrato).
static func release_free(world: GameWorld, p: Player) -> void:
	var club := world.club(p.club_id)
	if club != null:
		club.player_ids.erase(p.id)
	_close_spell(world, p)
	p.club_id = -1
	p.wage = 0
	p.transfer_listed = false
	world.mark_free_agents_dirty()


## Garante elencos mínimos (IA contrata livres) e poda excessos. Chamado na virada de temporada.
static func balance_squads(world: GameWorld) -> void:
	var rules := DatabaseManager.squad_rules()
	var free := world.free_agents().duplicate()
	free.sort_custom(func(a, b): return a.ovr_f > b.ovr_f)
	for c: Club in world.clubs:
		if world.is_user_club(c.id):
			continue
		_ai_cut_wages(world, c)
		while c.player_ids.size() > int(rules["max_players"]):
			var before := c.player_ids.size()
			_ai_release_weakest(world, c)
			if c.player_ids.size() == before:
				break
		var guard := 0
		while guard < 12:
			guard += 1
			var needs := squad_needs(world, c)
			var short := c.player_ids.size() < int(rules["min_players"]) + 2
			var urgent: Dictionary = {}
			for n in needs:
				if int(n["count"]) < int(FAMILIES[int(n["fam"])][1]):
					urgent = n
					break
			if urgent.is_empty() and not short:
				break
			var fam: int = urgent["fam"] if not urgent.is_empty() else -1
			var pick: Player = null
			var level := PlayerGenerator.club_level(c)
			for p: Player in free:
				if p.club_id >= 0:
					continue
				if fam >= 0 and _family_of(p.position) != fam:
					continue
				if p.ovr_f > level + 6.0:
					continue
				pick = p
				break
			if pick == null:
				var used := WorldGenerator.used_names_of(world)
				var pos: int = FAMILIES[fam][0][0] if fam >= 0 else Pos.CM
				pick = PlayerGenerator.create(world, world.rng, pos, level - 4.0, world.rng.randi_range(20, 30), PlayerGenerator.pick_nationality(world.rng, c), c.city, used)
				pick.club_id = -1
				world.add_player(pick)
			complete_transfer(world, pick, c, 0, Valuation.wage_demand(pick, c, world.year), world.rng.randi_range(1, 2))


## Folha acima do teto: coloca à venda quem custa muito para o que rende; em crise, libera.
static func _ai_cut_wages(world: GameWorld, c: Club) -> void:
	var bill := FinanceManager.wage_bill(world, c)
	if bill <= c.wage_budget * 1.05:
		return
	var squad := world.squad(c)
	# Pior custo-benefício primeiro: salário alto para o overall.
	squad.sort_custom(func(a, b): return a.wage / maxf(1.0, Valuation.base_wage(a.ovr_f - Valuation.shift)) > b.wage / maxf(1.0, Valuation.base_wage(b.ovr_f - Valuation.shift)))
	var listed := 0
	for p in squad:
		if listed >= 3:
			break
		if _family_count(world, c, p.position) > _family_min(p.position) and not p.transfer_listed and p.loan.is_empty():
			p.transfer_listed = true
			listed += 1
	if bill > c.wage_budget * 1.3 and c.player_ids.size() > int(DatabaseManager.squad_rules()["min_players"]) + 2:
		for p in squad:
			if _family_count(world, c, p.position) > _family_min(p.position) + 1 and p.contract_years_left(world.year) <= 1 and p.loan.is_empty():
				release(world, p)
				break
